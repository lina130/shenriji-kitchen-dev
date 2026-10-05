# 连续 2D 城区流式加载架构

## 主方案

# 连续 2D 城区流式加载架构方案

> 目标：把 `SceneRouter.travel_to()` 的"整区重建"改为 **world_graph 拓扑 + chunk 流式加载**，实现相邻街区连续行走、镜头不重置、门内/街道自然衔接，同时 **100% 兼容现有存档**。

---

## 一、现状诊断（决定迁移策略）

| 现状 | 问题 | 迁移对策 |
|---|---|---|
| `SceneRouter.travel_to()` 直接 `GameState.current_area = area_id` 并 emit `travel_completed` | 每次切换 = `WorldRoot._build_area()` 全量重建，镜头重置 | 保留 `travel_to()` 作为**唯一对外 API**，内部改为"请求流式切换" |
| `WorldRoot._build_area(area, spawn)` 一次性建 backdrop + player + NPC + interactable | 无法局部加载 | 拆成 `_build_static_shell()`（一次）+ `_stream_chunk()`（按需） |
| `CITY_MAP_SIZE = Vector2(2560,1440)` 只对 `street` 生效 | 其他区 1280×720，坐标系不统一 | 引入 **world 坐标系**，所有 area 映射到统一世界坐标 |
| `scene_zones.csv` 已有 zone 矩形 | 可复用为 chunk 划分依据 | 直接作为 chunk 边界来源 |
| `area_backdrop.gd` 按 `area_id` 分支绘制 | 每区独立绘制，无法拼接 | 保留绘制逻辑，但改为**按 chunk 裁剪绘制** |
| 存档只存 `current_area` + `spawn_id` | 无坐标 | **新增可选字段**，旧档缺字段时回退到 spawn 点 |

**关键判断**：不做"真·无缝大地图"（重写所有 backdrop），而是做 **"逻辑连续 + 视觉拼接"**——相邻 area 在 world 坐标里首尾相接，玩家跨边界时只切换 chunk 可见性，不重建节点树。

---

## 二、核心数据结构

### 2.1 `data/world_graph.csv`（新增，拓扑唯一数据源）

```csv
node_id,area_id,kind,world_x,world_y,world_w,world_h,parent_node,entry_spawn,exit_spawns,stream_group
street_main,street,outdoor,0,0,2560,1440,,default,"home_door:120,1320;store_door:640,900;market_gate:250,620",city_core
home_interior,home,interior,120,1320,1280,720,street_main,default,"exit:120,1320",city_core
store_interior,store,interior,640,900,1280,720,street_main,default,"exit:640,900",city_core
market_interior,market,interior,250,620,1280,720,street_main,default,"exit:250,620",city_core
commercial_main,commercial_district,outdoor,2560,0,1280,720,street_main,east_gate,"west_gate:2560,360",city_east
industrial_main,industrial_district,outdoor,0,1440,1280,720,street_main,south_gate,"north_gate:640,1440",city_north
```

**字段语义**：
- `node_id`：全局唯一节点 ID（≠ area_id，因为同一 area 可有多个实例，如 `home` 未来可能有多套）
- `area_id`：对应 `SceneRouter.VALID_AREAS` 里的绘制/逻辑类型
- `kind`：`outdoor`（可连续行走）/ `interior`（门内，进入时切换）
- `world_x/y/w/h`：在**世界坐标系**中的位置（像素）
- `parent_node`：interior 挂在哪个 outdoor 节点下；outdoor 之间用 `exit_spawns` 的坐标相邻
- `entry_spawn`：从外部进入该节点的默认 spawn_id
- `exit_spawns`：`spawn_id:world_x,world_y` 列表，定义"从该节点走出去会落在哪个世界坐标"
- `stream_group`：同一组的节点共享流式加载策略（如 `city_core` 全部常驻）

### 2.2 `data/chunk_layout.csv`（新增，chunk 划分）

```csv
chunk_id,node_id,rect_x,rect_y,rect_w,rect_h,priority,preload_radius
street_main_c0,street_main,0,0,1280,720,0,1
street_main_c1,street_main,1280,0,1280,720,0,1
street_main_c2,street_main,0,720,1280,720,0,1
street_main_c3,street_main,1280,720,1280,720,0,1
home_interior_c0,home_interior,120,1320,1280,720,1,0
store_interior_c0,store_interior,640,900,1280,720,1,0
```

- `priority`：0 = 常驻（outdoor 主干），1 = 按需（interior）
- `preload_radius`：以玩家所在 chunk 为中心，预加载 N 圈

### 2.3 运行时结构（`scripts/gameplay/world_streamer.gd`）

```gdscript
class_name WorldStreamer
extends Node2D

# 世界坐标 → 节点实例
var _loaded_nodes: Dictionary = {}      # node_id -> Node2D
var _loaded_chunks: Dictionary = {}     # chunk_id -> Node2D
var _node_defs: Dictionary = {}         # node_id -> Dictionary (来自 world_graph.csv)
var _chunk_defs: Dictionary = {}        # chunk_id -> Dictionary
var _active_node_id := "street_main"
var _player_world_pos := Vector2.ZERO
var _stream_radius := 1

signal node_entered(node_id: String, spawn_id: String)
signal chunk_loaded(chunk_id: String)
signal chunk_unloaded(chunk_id: String)
```

---

## 三、场景流式加载方案

### 3.1 三层结构

```
WorldRoot (Node2D)
├── WorldStreamer (Node2D)          ← 新增，管理世界坐标与 chunk
│   ├── NodeContainer[street_main]  ← 每个 node 一个容器，内含若干 chunk
│   │   ├── Chunk[street_main_c0]   ← AreaBackdrop 的裁剪实例
│   │   ├── Chunk[street_main_c1]
│   │   └── ...
│   ├── NodeContainer[home_interior]
│   └── ...
├── PlayerActor                     ← 挂到 WorldStreamer 下，用世界坐标
├── NpcLayer                        ← 按 chunk 动态挂载/卸载
└── InteractableLayer
```

### 3.2 加载触发

```gdscript
func _process(_delta: float) -> void:
    if not is_instance_valid(player):
        return
    var new_pos := player.global_position
    if new_pos.distance_to(_player_world_pos) < 64.0:
        return
    _player_world_pos = new_pos
    _update_active_node()
    _update_streaming()
```

`_update_active_node()`：用 `world_graph.csv` 的矩形做**点包含测试**，找到玩家当前所在 node。若跨越 outdoor→interior 边界，emit `node_entered`，由 `WorldRoot` 决定是否切换"门内模式"（隐藏 outdoor chunk，显示 interior chunk）。

`_update_streaming()`：以玩家所在 chunk 为中心，`preload_radius` 内的 chunk 加载，之外的卸载。

### 3.3 门内/街道衔接

**关键设计**：interior 节点在 world 坐标里**物理上就贴在 outdoor 的门口位置**（见 `world_graph.csv` 的 `world_x/y`）。玩家走到门口时：

1. 检测到进入 interior 矩形 → `node_entered("home_interior")`
2. `WorldStreamer` 把 `street_main` 的 chunk 设为 `visible=false`（不卸载，保留状态）
3. 把 `home_interior` 的 chunk 设为 `visible=true`
4. **镜头不重置**：因为玩家 `global_position` 没变，Camera2D 自然跟随
5. 走出时反向操作

这样"门内"和"街道"在数据上是**同一张世界地图的两个图层**，视觉上无缝。

### 3.4 镜头

`PlayerActor` 下挂 `Camera2D`，`position_smoothing_enabled = true`。因为玩家坐标连续，镜头天然连续。**唯一要改的是**：`WorldRoot._build_area()` 里如果有 `camera.reset_smoothing()` 之类的调用，全部删除。

---

## 四、迁移步骤（分 5 阶段，每阶段可独立验证）

### 阶段 0：数据准备（无代码改动）

1. 新建 `data/world_graph.csv`，把现有 33 个 area 全部录入。**先只录 outdoor 主干**：`street`、`commercial_district`、`industrial_district`、`suburb`、`riverside`。
2. 新建 `data/chunk_layout.csv`，按 `scene_zones.csv` 的 zone 矩形切 chunk。
3. 写 `scripts/data/world_graph_loader.gd`，启动时加载两个 CSV 到 `WorldStreamer._node_defs / _chunk_defs`。

**验证**：`DEEP_CITY_DUMP_GRAPH=1` 环境变量下打印所有节点，人工核对坐标无重叠、无空洞。

### 阶段 1：WorldStreamer 骨架（不动现有渲染）

1. 新建 `scripts/gameplay/world_streamer.gd`，实现 `_update_active_node()` 和 `_update_streaming()`，但 **chunk 加载先只做日志**。
2. `WorldRoot._ready()` 里实例化 `WorldStreamer`，把 `player` 挂到它下面。
3. `SceneRouter.travel_to()` 改为：**先查 world_graph，若目标节点已加载则直接移动玩家坐标；否则走旧路径**。

**验证**：在 `street` 里走动，控制台打印当前 node_id 和 chunk_id，确认切换正确。

### 阶段 2：chunk 实例化（真正流式）

1. 把 `AreaBackdrop` 改造成**可指定绘制区域**：新增 `configure_chunk(area_id, chunk_rect)`，`_draw()` 里用 `draw_set_transform` 偏移到 chunk 局部坐标。
2. `WorldStreamer._load_chunk(chunk_id)` 实例化一个 `AreaBackdrop`，`position = chunk_rect.position`，`configure_chunk(area_id, chunk_rect)`。
3. `_unload_chunk()` 里 `queue_free()`。

**验证**：在 `street` 里从 c0 走到 c1，观察 c0 是否被卸载、c1 是否被加载，视觉上无接缝。

### 阶段 3：门内衔接

1. 把 `home`、`store`、`market` 等 interior 录入 `world_graph.csv`，坐标贴在对应 outdoor 门口。
2. `WorldStreamer` 增加 `_enter_interior(node_id)` / `_exit_interior()`，切换 chunk 可见性。
3. `WorldRoot._build_area()` 里所有 `travel_to("home")` 调用改为 `WorldStreamer.request_enter("home_interior")`。

**验证**：从 `street` 走到 `home` 门口，进出门，镜头不重置，玩家坐标连续。

### 阶段 4：存档兼容

1. `SaveManager` 的存档结构新增**可选字段** `world_pos: Vector2` 和 `active_node_id: String`。
2. 读档时：
   - 若有 `world_pos` → 直接 `player.global_position = world_pos`，`WorldStreamer` 按坐标反推 node。
   - 若无（旧档）→ 走旧路径：`SceneRouter.restore(current_area, spawn_id)`，然后 `WorldStreamer` 把玩家放到该 node 的 `entry_spawn` 世界坐标。
3. **不删除** `GameState.current_area / spawn_id`，继续维护，作为旧档回退依据。

**验证**：
- 用旧档（无 world_pos）读档 → 正常进入对应区域。
- 用新档读档 → 精确恢复到世界坐标。
- 旧档读入后存档 → 新档带 world_pos，旧字段仍在。

### 阶段 5：清理与优化

1. 删除 `WorldRoot._build_area()` 里的全量重建逻辑，改为 `WorldStreamer` 驱动。
2. `SceneRouter.travel_to()` 保留为**兼容 API**，内部转调 `WorldStreamer.request_travel()`。
3. 加 chunk 预加载（`preload_radius`）和 LRU 卸载。

---

## 五、验证清单

| 项 | 方法 | 通过标准 |
|---|---|---|
| 连续行走 | 从 `street` 走到 `commercial_district` | 无黑屏、无重建、镜头连续 |
| 门内衔接 | 进 `home` 再出来 | 玩家坐标连续，镜头不跳 |
| 存档兼容 | 旧档读入 | 进入正确区域，无报错 |
| 存档升级 | 旧档读入后存档 | 新档含 world_pos，旧字段保留 |
| 性能 | 在 `street` 走动 60s | chunk 加载/卸载无卡顿，内存稳定 |
| 边界 | 走到 world_graph 未覆盖区域 | 有 fallback，不崩溃 |

---

## 六、风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| `AreaBackdrop._draw()` 改造引入视觉接缝 | 画风破坏 | 阶段 2 先只对 `street` 试点，其他区保留旧路径 |
| 旧档 `current_area` 与新 `active_node_id` 不一致 | 读档错位 | 读档时以 `world_pos` 为准，`current_area` 仅作 fallback |
| chunk 卸载时 NPC/交互物状态丢失 | 任务中断 | NPC 状态存 `NpcManager`，chunk 只负责视觉；交互物状态存 `GameState` |
| `scene_zones.csv` 的 zone 矩形与 chunk 不匹配 | 加载错位 | chunk 划分**直接复用** zone 矩形，不重新设计 |
| 多人 coop 坐标不同步 | 联机错位 | `CoopManager.send_local_state()` 改为发 world_pos，阶段 3 后处理 |
| `WorldRoot._process()` 里的 `_build_area` 定时重建（restaurant/breakfast） | 与新架构冲突 | 改为 `WorldStreamer.refresh_chunk(node_id)`，只重建对应 chunk |

---

## 七、交付物清单

**新增文件**：
- `data/world_graph.csv`
- `data/chunk_layout.csv`
- `scripts/data/world_graph_loader.gd`
- `scripts/gameplay/world_streamer.gd`

**修改文件**：
- `scripts/gameplay/world.gd`（接入 WorldStreamer，删除全量重建）
- `scripts/gameplay/area_backdrop.gd`（新增 `configure_chunk`）
- `autoload/scene_router.gd`（`travel_to` 转调 WorldStreamer）
- `autoload/save_manager.gd`（新增可选字段 + 回退逻辑）

**Feature Flag**：
- `world.streaming.enabled`（默认 false，阶段 2 后逐步开启）
- 关闭时完全走旧路径，保证可回退。

## 独立方案

# 独立方案：world_graph + chunk streaming 连续城区架构

> 立场：**不重建 SceneRouter，而是把它降级为"存档兼容适配层"**。当前 `WorldRoot._build_area()` 每次 travel 全量销毁重建 `_area_root`，是镜头重置、门内外断裂、NPC 重生的根因。本方案引入 `WorldGraph`（静态拓扑）+ `ChunkStreamer`（动态加载）+ `AreaRuntime`（区域实例池），让"相邻街区连续行走"成为默认行为，`travel_to()` 退化为"跨 chunk 传送"的兼容入口。

---

## 一、根因诊断（为什么必须换架构）

| 现象 | 现有代码根因 | 证据 |
|---|---|---|
| 镜头重置 | `_build_area()` 重建 `_area_root`，player 被重新 `add_child` 到新父节点，`Camera2D` 跟随目标丢失 | `world.gd` `_build_area` 全量重建 |
| 门内外断裂 | `home` / `home_living` 是两个独立 area，`travel_to` 触发 `travel_completed` → 全量重建 | `scene_router.gd` `VALID_AREAS` 平铺 34 个 |
| NPC 重生 | NPC 由 `_build_area` 内 `NpcScript` 实例化，无持久化 | `world.gd` 内联创建 |
| 存档兼容脆弱 | `GameState.current_area` 是字符串，无坐标；`restore()` 只恢复 area_id | `scene_router.gd` `restore` |
| 无法连续行走 | 每个 area 是独立 1280×720 或 2560×1440 画布，无世界坐标 | `area_backdrop.gd` `map_size` 硬编码 |

**结论**：不是"优化加载"，而是**坐标系与生命周期模型错误**。必须引入世界坐标 + 实例池。

---

## 二、架构总览

```
WorldRoot (Node2D, 世界坐标系根)
├── WorldGraph (Resource, 静态拓扑, 只读)
├── ChunkStreamer (Node, 管理 chunk 生命周期)
│   ├── Chunk[street_center]   (Node2D, 已加载)
│   ├── Chunk[street_market]   (Node2D, 已加载)
│   └── Chunk[home_interior]   (Node2D, 已加载, 门内)
├── PlayerActor (世界坐标, 唯一实例, 永不重建)
├── CameraRig (Node2D, 跟随 player, 永不重置)
└── AreaRuntimePool (Dictionary[area_id -> AreaRuntime])
```

**核心不变量**：
1. `PlayerActor` 全局唯一，`global_position` 在世界坐标系中连续。
2. `CameraRig` 全局唯一，`position` 由 player 平滑跟随，**永不 snap**。
3. `Chunk` 是加载/卸载单位，`AreaRuntime` 是区域逻辑单位，二者解耦。
4. `GameState.current_area` 降级为**派生值**（由 player 所在 chunk 反查），不再是驱动重建的源。

---

## 三、数据结构

### 3.1 world_graph.tres（静态拓扑，编辑器可编辑）

```gdscript
class_name WorldGraph
extends Resource

# 节点：一个"区域"（逻辑单位，对应现有 area_id）
# 每个节点声明自己的 chunk 归属与门/出口
@export var nodes: Dictionary = {}  # area_id -> AreaNode

class AreaNode:
    var area_id: String
    var chunk_id: String          # 所属 chunk
    var world_rect: Rect2         # 在世界坐标中的占位（用于门连接）
    var interior: bool            # 是否门内（home_living / breakfast_kitchen）
    var parent_area: String       # 门内区域的宿主，如 home_living.parent = home
    var portals: Array[Portal]    # 出口/门
    var spawn_points: Dictionary  # spawn_id -> Vector2 (世界坐标)

class Portal:
    var portal_id: String
    var rect: Rect2               # 触发区（世界坐标）
    var target_area: String
    var target_spawn: String
    var bidirectional: bool
    var transition: String        # "walk" | "door" | "stairs" | "teleport"
```

**关键设计**：`interior` 区域**不占世界坐标**，而是挂在 `parent_area` 的某个 portal 上。玩家走进门 → 不换 chunk，只切换 `AreaRuntime` 的可见层 + 把 player 移到 interior 的局部坐标。这样门内外**共用同一个 CameraRig**，镜头不重置。

### 3.2 chunk 划分（复用现有 scene_zones.csv）

`street` 的 8 个 zone 天然就是 chunk 边界：

| chunk_id | 覆盖 zone | 世界坐标 |
|---|---|---|
| `street_center` | center | (900,600,580,260) |
| `street_market` | market | (250,300,500,320) |
| `street_village` | village | (60,880,620,520) |
| `street_nature` | nature | (850,900,650,500) |
| `street_commercial` | commercial | (1500,900,620,420) |
| `street_industrial` | industrial | (1450,60,760,420) |
| `street_suburb` | suburb | (2000,900,500,440) |
| `street_activity` | activity | (500,120,600,180) |

`commercial_district` / `industrial_district` 同理，各 5 个 chunk。**不新增 CSV，直接读 `scene_zones.csv`**。

### 3.3 存档兼容层

```gdscript
# SaveManager 新增字段（旧档无此字段时走 fallback）
{
  "world_pos": Vector2,        # 新增：世界坐标
  "current_area": String,      # 保留：旧档兼容
  "spawn_id": String,          # 保留
  "schema_version": 2          # 新增
}
```

**迁移规则**：
- 旧档（无 `world_pos`）→ 用 `current_area` + `spawn_id` 查 `WorldGraph.nodes[area_id].spawn_points[spawn_id]` 得到世界坐标，写入 `world_pos`，`schema_version=2`。
- 新档 → 直接读 `world_pos`，`current_area` 由 `WorldGraph.area_at(world_pos)` 反查。
- **`SceneRouter.travel_to()` 保留**，但内部改为：查目标 area 的 spawn 世界坐标 → 设置 player 位置 → 触发 chunk 加载 → 发 `travel_completed`（兼容旧监听者）。

---

## 四、ChunkStreamer 实现

```gdscript
class_name ChunkStreamer
extends Node2D

const LOAD_RADIUS := 1      # 以 chunk 为单位的加载半径
const UNLOAD_RADIUS := 2    # 滞后卸载，避免边界抖动
const PRELOAD_MARGIN := 200.0  # 世界坐标预加载边距

var _graph: WorldGraph
var _loaded: Dictionary = {}      # chunk_id -> Chunk
var _loading: Dictionary = {}     # chunk_id -> bool
var _player_chunk: String = ""

func _process(_delta: float) -> void:
    var player_pos := _player.global_position
    var center_chunk := _graph.chunk_at(player_pos)
    if center_chunk == _player_chunk:
        return
    _player_chunk = center_chunk
    _update_streaming(center_chunk)

func _update_streaming(center: String) -> void:
    var want := _graph.chunks_within(center, LOAD_RADIUS)
    # 异步加载缺失 chunk
    for cid in want:
        if not _loaded.has(cid) and not _loading.has(cid):
            _load_chunk_async(cid)
    # 滞后卸载
    for cid in _loaded.keys():
        if _graph.chunk_distance(center, cid) > UNLOAD_RADIUS:
            _unload_chunk(cid)

func _load_chunk_async(cid: String) -> void:
    _loading[cid] = true
    # 用 ResourceLoader.load_threaded_request 加载 chunk 场景
    var path := "res://scenes/chunks/%s.tscn" % cid
    ResourceLoader.load_threaded_request(path)
    # 轮询在 _process 中，加载完成后实例化并 add_child
```

**Chunk 场景结构**（每个 chunk 一个 .tscn，编辑器可视化摆放）：

```
Chunk[street_market] (Node2D, position = zone.rect.position)
├── Backdrop (AreaBackdrop, 只画本 zone 的地面/建筑)
├── Interactables (Node2D)
├── NPCs (Node2D)
└── Portals (Node2D, Area2D 触发区)
```

**关键**：`AreaBackdrop` 改为**只画自己 chunk 的 rect**，不再画整张 2560×1440。这样 chunk 卸载时视觉自然消失，无需遮罩。

---

## 五、门内外衔接（核心难点）

### 5.1 门内区域不占世界坐标

`home_living` 的 `world_rect` 设为 `Rect2()`（空），`interior=true`，`parent_area="home"`。

### 5.2 进门流程（walk 型）

```gdscript
# Portal 触发（Area2D.body_entered）
func _on_portal_entered(portal: Portal, body: Node2D) -> void:
    if body != _player: return
    if portal.transition == "walk":
        # 连续行走：不切 area，只切 chunk 可见性
        _enter_interior(portal.target_area, portal.target_spawn)

func _enter_interior(area_id: String, spawn_id: String) -> void:
    var node := _graph.nodes[area_id]
    var host := _graph.nodes[node.parent_area]
    # 1. 隐藏宿主 chunk 的室内层（如果有），显示 interior 层
    _area_runtime_pool.get_or_create(area_id).show()
    _area_runtime_pool.get_or_create(node.parent_area).set_interior_visible(false)
    # 2. player 移到 interior 局部坐标（世界坐标不变，只是视觉层切换）
    #    用"虚拟偏移"：interior 有自己的局部坐标系，CameraRig 跟随 player 的局部位置
    _camera_rig.set_coordinate_space(area_id)
    # 3. 不触发 travel_completed，不重建任何东西
```

**CameraRig 双坐标系**：

```gdscript
class_name CameraRig
extends Node2D

var _space: String = "world"   # "world" | area_id
var _target: Node2D

func set_coordinate_space(space: String) -> void:
    _space = space
    # 不 snap，保持当前 position，下一帧平滑过渡到新目标
    _transition_tween = create_tween()
    _transition_tween.tween_method(_lerp_to_target, 0.0, 1.0, 0.35)

func _process(delta: float) -> void:
    if _space == "world":
        global_position = global_position.lerp(_target.global_position, 1.0 - exp(-8.0 * delta))
    else:
        # interior 空间：player 有局部坐标，camera 跟随局部
        var local := _area_runtime_pool.get(_space).player_local_pos()
        global_position = global_position.lerp(local, 1.0 - exp(-8.0 * delta))
```

**效果**：进门时镜头**平滑推近**（0.35s tween），不重置。出门同理反向。

### 5.3 跨 chunk 传送（teleport 型）

`bus_station` → `seaside_resort` 这种远距离，走 `teleport`：
- 触发 `travel_to()` 兼容路径
- 设置 player 世界坐标到目标 spawn
- `ChunkStreamer` 下一帧检测到 chunk 变化，加载新 chunk
- **镜头做一次快速 fade**（0.2s 黑场），因为距离太远，平滑跟随会穿帮

---

## 六、AreaRuntime 实例池

```gdscript
class_name AreaRuntime
extends Node2D

var area_id: String
var _npc_cache: Dictionary = {}   # npc_id -> NpcActor
var _interactable_cache: Dictionary = {}

func get_or_create_npc(npc_id: String) -> NpcActor:
    if _npc_cache.has(npc_id) and is_instance_valid(_npc_cache[npc_id]):
        return _npc_cache[npc_id]
    var npc := NpcScript.new()
    npc.configure(npc_id)
    add_child(npc)
    _npc_cache[npc_id] = npc
    return npc

func set_interior_visible(v: bool) -> void:
    visible = v
    set_process(v)
    set_physics_process(v)
```

**NPC 持久化**：NPC 挂在 `AreaRuntime` 上，chunk 卸载时 `AreaRuntime` 保留在池中（只是 `visible=false`），NPC 状态（位置、对话进度）不丢失。**这修复了"NPC 重生"问题**。

---

## 七、SceneRouter 降级为适配层

```gdscript
# scene_router.gd 改造（保留全部公开 API）
func travel_to(area_id: String, spawn_id: String = "default") -> void:
    if area_id not in VALID_AREAS:
        push_warning("未知区域：%s" % area_id)
        return
    var node := WorldGraph.instance().nodes[area_id]
    var world_pos: Vector2 = node.spawn_points.get(spawn_id, node.world_rect.position)
    # 新路径：设置世界坐标，让 streamer 自然加载
    var world := get_tree().get_first_node_in_group("world")
    if world != null and world.has_method("teleport_player"):
        world.teleport_player(world_pos, area_id)
    else:
        # fallback：旧路径（理论上不会走到）
        GameState.current_area = area_id
        GameState.spawn_id = spawn_id
        travel_completed.emit(area_id, spawn_id)

func restore(area_id: String, spawn_id: String) -> void:
    # 存档恢复：只设 GameState，WorldRoot._ready 会读 world_pos
    if area_id not in VALID_AREAS:
        area_id = "home"
    GameState.current_area = area_id
    GameState.spawn_id = spawn_id
```

**所有现有 `travel_to` 调用点零改动**。`travel_completed` 信号保留，但只在 teleport 型触发。

---

## 八、WorldRoot 改造

```gdscript
func _ready() -> void:
    add_to_group("world")
    _graph = WorldGraph.instance()
    _chunk_streamer = ChunkStreamer.new()
    _chunk_streamer.configure(_graph, player)
    add_child(_chunk_streamer)
    _camera_rig = CameraRig.new()
    _camera_rig.configure(player)
    add_child(_camera_rig)
    # 恢复存档位置
    var world_pos := SaveManager.get_world_pos()
    if world_pos == Vector2.ZERO:
        world_pos = _graph.nodes[GameState.current_area].spawn_points.get(GameState.spawn_id, Vector2.ZERO)
    player.global_position = world_pos
    _chunk_streamer.force_load_around(world_pos)

func teleport_player(world_pos: Vector2, area_id: String) -> void:
    player.global_position = world_pos
    GameState.current_area = area_id
    _chunk_streamer.force_load_around(world_pos)
    travel_completed.emit(area_id, GameState.spawn_id)
```

**删除**：`_build_area()`、`_area_root`、`_on_travel_requested` 的全量重建逻辑。
**保留**：所有 `*_requested` 信号、`_process` 中的 coop 同步、`_unhandled_input` 点击逻辑。

---

## 九、迁移步骤（可增量上线）

| 阶段 | 内容 | 风险 | 回滚 |
|---|---|---|---|
| P0 | 新增 `WorldGraph` + `world_graph.tres`，从 `scene_zones.csv` 生成 | 无 | 删文件 |
| P1 | 新增 `ChunkStreamer` + `CameraRig`，**不接入** | 无 | 删文件 |
| P2 | `WorldRoot` 双路径：feature flag `world.streaming`，false 走旧 `_build_area` | 低 | 关 flag |
| P3 | 拆分 `street` 为 8 个 chunk 场景，逐个迁移 | 中 | 单 chunk 回退 |
| P4 | 迁移 `commercial_district` / `industrial_district` | 中 | 同上 |
| P5 | 迁移门内区域（`home_living` / `breakfast_kitchen`） | 高 | 保留旧路径 |
| P6 | 删除 `_build_area`，`SceneRouter` 完全降级 | 高 | git revert |

**每阶段可独立验证**：P2 后开 flag 跑一遍全图，对比旧路径行为。

---

## 十、与主方案的差异（独立立场）

| 维度 | 主方案（推测） | 本方案 |
|---|---|---|
| SceneRouter | 可能保留为主入口 | **降级为适配层**，只做存档兼容 |
| 坐标系 | 可能按 area 局部坐标 | **世界坐标唯一**，area 是派生 |
| 门内外 | 可能仍走 travel | **不切 area，只切可见层 + 坐标系空间** |
| 镜头 | 可能重建 Camera2D | **CameraRig 全局唯一，双坐标系平滑过渡** |
| NPC | 可能随 chunk 重建 | **AreaRuntime 池化，状态持久** |
| chunk 划分 | 可能新定义 | **复用 scene_zones.csv，零新增数据** |
| 存档 | 可能新增字段 | **schema_version + 迁移函数，旧档无损** |

---

## 十一、验证清单

1. **连续行走**：从 `street_center` 走到 `street_market`，镜头无 snap，NPC 不重生，`GameState.current_area` 保持 `street`。
2. **门内外**：从 `street` 走进 `home`，再进 `home_living`，镜头平滑推近，退出后回到原位。
3. **存档兼容**：加载旧档（schema_version=1），自动迁移到 v2，位置正确。
4. **跨区传送**：`bus_station` → `seaside_resort`，fade 过渡，chunk 正确加载。
5. **性能**：`street` 全图行走，常驻 chunk ≤ 3，内存峰值 ≤ 旧路径 1.2 倍。
6. **回归**：所有 `*_requested` 信号、点击交互、coop 同步行为不变。

---

**一句话总结**：把"区域"从**加载单位**降级为**逻辑标签**，把"chunk"提升为**加载单位**，把"世界坐标"提升为**唯一真相**。SceneRouter 保留 API 但不再驱动重建，存档通过 schema_version 无损迁移。

## 批判

# 批判报告：两份方案的遗漏、冲突与不可执行点

以下按"必须返工"分级。**P0 = 会导致上线即崩或存档损坏；P1 = 会导致功能不可达或测试无法验证；P2 = 死代码/文档冲突。**

---

## P0-1 主方案：`world_graph.csv` 的 `exit_spawns` 坐标与 `world_x/y` 自相矛盾，拓扑不可达

主方案 2.1 中：

```
home_interior,home,interior,120,1320,1280,720,street_main,default,"exit:120,1320",city_core
```

`home_interior` 的 `world_x/y = (120,1320)`，尺寸 1280×720，即占据世界矩形 `(120,1320)-(1400,2040)`。
而 `street_main` 是 `(0,0)-(2560,1440)`。**两者在 y 轴 1320–1440 区间重叠 120px**。

同时 `street_main` 的 `exit_spawns` 写的是 `home_door:120,1320`——这是**街道上的门点**，但 `home_interior` 的矩形原点也放在 `(120,1320)`。这意味着：

- 玩家站在街道门口 `(120,1320)` 时，**同时落在 `street_main` 和 `home_interior` 两个矩形内**。
- `_update_active_node()` 用"点包含测试"找当前 node，**结果依赖字典遍历顺序**，不可确定。
- 主方案 3.3 声称"检测到进入 interior 矩形 → node_entered"，但玩家在门口时**已经在 interior 矩形里**，进门事件永远不会触发（因为从未"进入"）。

**返工要求**：
1. 明确 `interior` 节点的矩形**不得与任何 outdoor 节点矩形相交**。interior 必须放在 outdoor 矩形之外（例如 `home_interior` 放到 `(0, 3000)` 这种隔离区），或引入 `kind` 优先级规则：`_update_active_node()` 必须先测 interior 再测 outdoor，且 interior 命中时**立即返回**，不继续测 outdoor。
2. `exit_spawns` 的坐标语义必须写死：是"街道侧门点"还是"interior 侧落点"？两者不能同值。建议拆成 `street_door_pos` 和 `interior_entry_pos` 两个字段。
3. 补一条断言：`world_graph_loader.gd` 加载后必须校验**任意两个 node 的 world_rect 不相交**（interior 除外，但 interior 必须声明 `parent_node` 且其矩形与 parent 不相交）。校验失败直接 `push_error` 并拒绝启动。

---

## P0-2 独立方案：`interior` 不占世界坐标 + `CameraRig` 双坐标系 = 玩家坐标语义分裂，存档必坏

独立方案 5.1 说 `home_living.world_rect = Rect2()`（空），5.2 说进门时"player 移到 interior 局部坐标（世界坐标不变，只是视觉层切换）"，但 5.2 的 `_enter_interior` 里又写 `_camera_rig.set_coordinate_space(area_id)`，且 `CameraRig._process` 在 `_space != "world"` 时用 `_area_runtime_pool.get(_space).player_local_pos()` 作为相机目标。

**矛盾点**：
- 如果 player 的 `global_position` 不变（仍在世界坐标），那 `player_local_pos()` 是什么？player 没有局部坐标，除非你把 player 重新 parent 到 `AreaRuntime` 下——但 5.2 没写这一步。
- 如果 player 被 reparent 到 interior 的 `AreaRuntime`，那 `global_position` 会因父节点变换而跳变，**镜头必然 snap**，与"镜头不重置"目标直接冲突。
- 存档时 `world_pos` 存的是哪个坐标？进门状态下存的是世界坐标（街道门口），读档后玩家会出现在街道而不是室内。**存档无法表达"我在室内"这个状态**。

**返工要求**：
1. 二选一，写死：
   - **方案 A（推荐）**：interior 也占世界坐标，放在隔离区（如 `(0, 3000)`），进门 = 传送 player 到 interior 世界坐标 + 切换 chunk 可见性。镜头连续（因为传送距离短，或加 fade）。存档 `world_pos` 唯一。
   - **方案 B**：interior 用独立坐标系，但必须显式定义 `player` 的 reparent 时机、`global_position` 的换算公式、以及存档字段 `{space: "world"|area_id, pos: Vector2}`。**不能只存 `world_pos`**。
2. 删除 `CameraRig` 的 `_space` 分支，改为**单一坐标系 + 传送时 fade**。双坐标系是复杂度炸弹，且与"镜头永不 snap"目标自相矛盾。
3. 补断言：存档写入时必须记录 `space` 字段；读档时若 `space != "world"` 且对应 `AreaRuntime` 未加载，必须 fallback 到 `parent_area` 的 spawn 点并 `push_warning`。

---

## P0-3 两份方案都遗漏：`AreaBackdrop` 的 `_draw()` 改造没有定义"裁剪坐标系"

主方案 3.2 说 `configure_chunk(area_id, chunk_rect)` 后用 `draw_set_transform` 偏移到 chunk 局部坐标。独立方案 4 说 `AreaBackdrop` 改为"只画自己 chunk 的 rect"。

**两份都没说清楚**：
- `AreaBackdrop` 现有的 `_draw()` 是按 `area_id` 分支画整张地图（2560×1440 或 1280×720）。改成 chunk 后，**每个 chunk 实例都要重跑一遍完整的 `_draw()` 分支逻辑**，只是把超出 `chunk_rect` 的部分裁掉。这意味着：
  - 如果 `_draw()` 里有 `draw_rect(Rect2(0,0,2560,1440), ...)` 这种全图绘制，裁剪后每个 chunk 仍会执行全图绘制调用，**性能反而更差**（8 个 chunk 各画一遍全图）。
  - `draw_set_transform` 只影响后续绘制调用的坐标变换，**不影响裁剪**。要真正裁剪必须用 `CanvasItem.clip_children` 或 `RenderingServer.canvas_item_set_custom_rect`，或手动 `draw_rect` 时传入裁剪后的矩形。
- 主方案说"阶段 2 先只对 `street` 试点，其他区保留旧路径"——但 `street` 是 2560×1440，其他区是 1280×720，**坐标系不统一**（主方案自己在现状诊断里承认了）。试点 `street` 无法验证其他区的 chunk 划分是否正确。

**返工要求**：
1. 明确 `AreaBackdrop.configure_chunk(area_id, chunk_rect)` 的契约：`_draw()` 必须**只发出与 `chunk_rect` 相交的绘制调用**，而不是画全图再裁剪。给出一个具体例子：`street` 的 `_draw()` 里画道路的 `draw_rect(Rect2(0, 600, 2560, 200))` 必须改成 `draw_rect(chunk_rect.intersection(Rect2(0,600,2560,200)))`。
2. 补一条性能断言：单个 chunk 的 `_draw()` 调用次数 ≤ 全图 `_draw()` 调用次数 / chunk 数量 × 1.5。用 `RenderingServer.get_frame_profile()` 或简单的 `draw_calls` 计数器验证。
3. 试点不能只选 `street`。必须同时选一个 1280×720 的区（如 `commercial_district`），验证坐标系换算。

---

## P0-4 主方案：`SceneRouter.travel_to()` 改为"先查 world_graph，若目标节点已加载则直接移动玩家坐标；否则走旧路径"——旧路径会重建 `_area_root`，导致镜头重置

主方案阶段 1 第 3 条。这是**过渡期的定时炸弹**：玩家在 `street` 走到 `commercial_district` 边界，如果 `commercial_district` 的 chunk 还没加载（预加载半径不够），`travel_to` 会走旧路径 → `_build_area()` → 镜头重置。**"连续行走"在边界处必然失败**。

**返工要求**：
1. 阶段 1 的 `travel_to` 必须**同步阻塞加载**目标 node 的 chunk，而不是 fallback 到旧路径。fallback 只允许在 feature flag 关闭时走。
2. 补一条测试：在 `street` 边缘反复横跳 100 次，断言 `Camera2D.global_position` 的帧间位移 ≤ 玩家位移 × 1.5，且无 `travel_completed` 信号发出。

---

## P1-1 主方案：`chunk_layout.csv` 与 `scene_zones.csv` 的关系未定义，存在双数据源

主方案 2.2 新建 `chunk_layout.csv`，但现状诊断里说"`scene_zones.csv` 已有 zone 矩形，可复用为 chunk 划分依据"。风险表里又说"chunk 划分直接复用 zone 矩形，不重新设计"。

**矛盾**：既然复用，为什么还要新建 `chunk_layout.csv`？如果新建，两份数据不一致时以谁为准？

独立方案 3.2 明确"不新增 CSV，直接读 `scene_zones.csv`"，这是更干净的立场。

**返工要求**：
1. 二选一：
   - **方案 A**：删除 `chunk_layout.csv`，chunk 直接从 `scene_zones.csv` 派生。`priority` 和 `preload_radius` 作为 `scene_zones.csv` 的新增列。
   - **方案 B**：保留 `chunk_layout.csv`，但 `world_graph_loader.gd` 必须校验 `chunk_layout.csv` 的每个 `rect` 与 `scene_zones.csv` 对应 zone 的 `rect` 完全一致，不一致则 `push_error`。
2. 补一条测试：加载后断言 `chunk_layout` 的矩形并集 == `scene_zones` 的矩形并集（允许 chunk 是 zone 的子集，但不得超出）。

---

## P1-2 两份方案都遗漏：`NpcManager` / `InteractableLayer` 的 chunk 归属未定义

主方案风险表说"NPC 状态存 `NpcManager`，chunk 只负责视觉；交互物状态存 `GameState`"。独立方案说"NPC 挂在 `AreaRuntime` 上，chunk 卸载时 `AreaRuntime` 保留在池中"。

**两份都没回答**：
- NPC 的**位置**存在哪？如果 NPC 在 `street` 走动，从 `street_center` chunk 走到 `street_market` chunk，NPC 的 `global_position` 跨 chunk 了，chunk 卸载时 NPC 怎么办？
- 交互物的**碰撞体**在哪个 chunk？如果交互物在 chunk 边界上，两个 chunk 都加载时会不会重复？
- `NpcManager` 和 `AreaRuntime` 的关系是什么？两份方案各说各的，没有统一。

**返工要求**：
1. 明确 NPC 的归属：NPC 属于 **node**（不是 chunk），挂在 `NodeContainer[node_id]` 下，chunk 只负责 backdrop 和静态交互物。NPC 的 `global_position` 用世界坐标，跨 chunk 时**不重新 parent**。
2. 明确交互物的归属：静态交互物（门、招牌）属于 chunk；动态交互物（可拾取物、任务点）属于 node，挂在 `NodeContainer` 下。
3. 补一条测试：NPC 从 `street_center` 走到 `street_market`，断言 NPC 实例 ID 不变、`global_position` 连续、无 `queue_free` 调用。

---

## P1-3 独立方案：`AreaRuntime` 池化 + `visible=false` 不释放内存，与"内存峰值 ≤ 旧路径 1.2 倍"的验证标准冲突

独立方案 6 说 `AreaRuntime` 池化，chunk 卸载时 `AreaRuntime` 保留在池中（只是 `visible=false`）。验证清单第 5 条说"内存峰值 ≤ 旧路径 1.2 倍"。

**冲突**：如果所有访问过的 area 的 `AreaRuntime` 都保留在池中，内存只增不减。走完全图后，池里会有 34 个 `AreaRuntime`，每个含 NPC、交互物、backdrop 引用。**内存必然超过旧路径**（旧路径每次只保留一个 area）。

**返工要求**：
1. 明确 `AreaRuntime` 的**驱逐策略**：LRU，最多保留 N 个（建议 N=3），超出时 `queue_free` 并序列化 NPC 状态到 `NpcManager`。
2. 补一条测试：走完全图 34 个 area，断言 `AreaRuntimePool.size() <= 3`，且内存峰值 ≤ 旧路径 × 1.2。
3. 如果驱逐会导致 NPC 状态丢失，必须定义 NPC 状态的序列化格式（位置、对话进度、任务标记），并在 `AreaRuntime` 重建时恢复。

---

## P1-4 两份方案都遗漏：`WorldRoot._process()` 里的定时重建（restaurant/breakfast）没有具体改造方案

主方案风险表最后一行说"改为 `WorldStreamer.refresh_chunk(node_id)`，只重建对应 chunk"。独立方案完全没提。

**问题**：
- `refresh_chunk` 的语义是什么？重建 backdrop？重建 NPC？重建交互物？
- 如果重建 backdrop，`AreaBackdrop` 的 `_draw()` 会重跑，但 chunk 的 `position` 和 `configure_chunk` 参数要保留。
- 如果重建 NPC，NPC 的对话进度会丢。
- 定时重建的触发条件是什么？`_process` 里怎么判断"该重建了"？

**返工要求**：
1. 明确 `refresh_chunk(chunk_id)` 的契约：只重建 backdrop 的绘制缓存，不重建 NPC 和交互物。
2. 补一条测试：在 restaurant 里待 60s，断言 NPC 实例 ID 不变、对话进度不变、backdrop 重绘次数 ≥ 1。

---

## P1-5 两份方案都遗漏：`scene_zones.csv` 的 zone 矩形是"逻辑区域"还是"视觉区域"？

独立方案 3.2 直接用 `scene_zones.csv` 的 zone 矩形作为 chunk 边界。但 `scene_zones.csv` 的 zone 是**逻辑区域**（用于判断玩家在哪个 zone），不是**视觉区域**。zone 矩形之间可能有重叠、空洞、或不对齐。

**问题**：
- 如果 zone 矩形有空洞，chunk 加载后会出现黑屏。
- 如果 zone 矩形有重叠，两个 chunk 都会加载，backdrop 会重复绘制。
- 如果 zone 矩形不对齐（如 `street_center` 是 `(900,600,580,260)`，`street_market` 是 `(250,300,500,320)`），chunk 之间会有缝隙。

**返工要求**：
1. 补一条数据校验：`scene_zones.csv` 的 zone 矩形必须**无重叠、无空洞、覆盖整个 area 的 map_size**。校验失败则 `push_error`。
2. 如果现有 `scene_zones.csv` 不满足，必须先修正数据，再开始 chunk 划分。
3. 补一条测试：加载 `street` 的所有 chunk，断言 chunk 矩形并集 == `street` 的 map_size，且两两不相交。

---

## P2-1 主方案：`stream_group` 字段定义了但从未使用

主方案 2.1 定义了 `stream_group`（`city_core` / `city_east` / `city_north`），但全文没有任何地方使用它。`WorldStreamer` 的 `_update_streaming()` 用的是 `preload_radius`，不是 `stream_group`。

**返工要求**：删除 `stream_group`，或明确它的用途（如"同组节点共享预加载策略"）并在 `_update_streaming()` 里实现。

---

## P2-2 独立方案：`WorldGraph.instance()` 单例模式与 `Resource` 的加载方式冲突

独立方案 7 的 `SceneRouter.travel_to()` 里写 `WorldGraph.instance().nodes[area_id]`。但 `WorldGraph` 是 `Resource`，`Resource` 没有 `instance()` 方法。如果 `WorldGraph` 是单例，应该用 `WorldGraph.get_singleton()` 或 `Engine.get_singleton()`。

**返工要求**：明确 `WorldGraph` 的加载方式：是 `preload("res://data/world_graph.tres")` 还是 autoload？如果是 autoload，`instance()` 改为 `WorldGraph`（autoload 名）。如果是 `Resource`，改为 `load("res://data/world_graph.tres")` 并缓存。

---

## P2-3 主方案：`DEEP_CITY_DUMP_GRAPH=1` 环境变量在 Godot 里不可用

主方案阶段 0 验证说"`DEEP_CITY_DUMP_GRAPH=1` 环境变量下打印所有节点"。Godot 的 `OS.get_environment()` 可以读环境变量，但**导出后的游戏不会继承 shell 环境变量**（除非用 `--` 参数或 `ProjectSettings`）。而且这个环境变量在代码里**从未被读取**。

**返工要求**：改为 `OS.is_debug_build()` + `ProjectSettings.get_setting("debug/dump_world_graph")`，或命令行参数 `--dump-world-graph`。

---

## P2-4 两份方案都遗漏：`CoopManager` 的坐标同步

主方案风险表说"`CoopManager.send_local_state()` 改为发 world_pos，阶段 3 后处理"。独立方案完全没提。

**问题**：
- 联机时，如果两个玩家在不同的 chunk，`ChunkStreamer` 怎么决定加载哪些 chunk？是取两个玩家的并集？还是只加载房主的？
- 如果玩家 A 在 `street`，玩家 B 在 `home_interior`，`GameState.current_area` 是谁的？
- `travel_completed` 信号在联机时怎么处理？房主触发还是每个客户端都触发？

**返工要求**：
1. 明确联机时的 chunk 加载策略：取所有玩家位置的并集，`preload_radius` 取最大值。
2. 明确 `GameState.current_area` 在联机时的语义：是房主的 area，还是每个客户端各自的？
3. 补一条测试：两个玩家分别在 `street` 和 `home_interior`，断言两个 chunk 都加载，且 `travel_completed` 不重复触发。

---

## P2-5 主方案：`SaveManager` 新增 `world_pos: Vector2` 但 Godot 的 `ConfigFile` / JSON 不直接支持 `Vector2`

主方案阶段 4 说"存档结构新增可选字段 `world_pos: Vector2`"。但 Godot 的 `ConfigFile` 存 `Vector2` 需要 `store_var`，JSON 存 `Vector2` 需要手动序列化为 `{x, y}`。**两份方案都没说存档格式是什么**。

**返工要求**：
1. 明确存档格式：`ConfigFile` 还是 JSON？如果是 `ConfigFile`，用 `store_var("world_pos", pos)`；如果是 JSON，用 `{"x": pos.x, "y": pos.y}`。
2. 补一条测试：写入 `world_pos = Vector2(123.456, 789.012)`，读回后断言 `is_equal_approx`。

---

## 返工优先级汇总

| 优先级 | 问题 | 返工要求 |
|---|---|---|
| P0-1 | 主方案 world_graph 矩形重叠，拓扑不可达 | 校验矩形不相交，拆分 exit_spawns 语义 |
| P0-2 | 独立方案 interior 坐标系分裂，存档必坏 | 二选一：interior 占世界坐标，或存档记录 space |
| P0-3 | AreaBackdrop 裁剪契约未定义 | 明确只画相交部分，补性能断言 |
| P0-4 | 主方案 travel_to fallback 导致镜头重置 | 同步阻塞加载，禁止 fallback |
| P1-1 | chunk_layout 与 scene_zones 双数据源 | 二选一，或加一致性校验 |
| P1-2 | NPC/交互物 chunk 归属未定义 | NPC 属 node，静态交互物属 chunk |
| P1-3 | AreaRuntime 池化内存无上限 | LRU 驱逐，N=3，补内存测试 |
| P1-4 | 定时重建改造方案缺失 | 明确 refresh_chunk 契约 |
| P1-5 | scene_zones 矩形可能重叠/空洞 | 数据校验，补覆盖测试 |
| P2-1 | stream_group 死字段 | 删除或实现 |
| P2-2 | WorldGraph.instance() 不存在 | 明确加载方式 |
| P2-3 | 环境变量在 Godot 不可用 | 改 ProjectSettings 或命令行参数 |
| P2-4 | CoopManager 坐标同步缺失 | 明确联机 chunk 加载策略 |
| P2-5 | Vector2 存档格式未定义 | 明确 ConfigFile/JSON 序列化 |

**结论**：两份方案都**不能直接进入实现**。P0 级问题必须先解决，否则会出现"上线即崩"（主方案拓扑不可达）或"存档损坏"（独立方案坐标系分裂）。建议先做 P0-1 和 P0-2 的数据模型返工，再重新评审。

## 综合决策

# 最终可执行方案：连续 2D 城区流式加载架构

> **决策原则**：以独立方案的"世界坐标唯一真相 + SceneRouter 降级为适配层"为骨架，采纳主方案的"分阶段迁移 + feature flag 可回退"，并按批判报告逐条返工 P0/P1 问题。**不追求真·无缝大地图，追求"逻辑连续 + 视觉拼接 + 存档无损"。**

---

## 一、核心决策（对批判的逐条裁决）

| 批判项 | 裁决 | 落地方式 |
|---|---|---|
| **P0-1** 矩形重叠拓扑不可达 | 采纳 | interior 节点**放在隔离区**（`world_y >= 3000`），与所有 outdoor 矩形不相交；`exit_spawns` 拆为 `street_door_pos` + `interior_entry_pos`；加载时断言矩形不相交 |
| **P0-2** interior 坐标系分裂 | 采纳方案 A | **interior 也占世界坐标**，放在隔离区；进门 = 传送 player 到 interior 世界坐标 + 切 chunk 可见性；存档只存 `world_pos`，**删除 CameraRig 双坐标系** |
| **P0-3** AreaBackdrop 裁剪契约 | 采纳 | `_draw()` 改为**只发出与 chunk_rect 相交的绘制调用**；补 draw_calls 断言；试点同时选 `street`（2560×1440）和 `commercial_district`（1280×720） |
| **P0-4** travel_to fallback 镜头重置 | 采纳 | 阶段 1 起 `travel_to` **同步阻塞加载**目标 node 的 chunk，**禁止 fallback 到旧路径**；旧路径只在 flag 关闭时走 |
| **P1-1** 双数据源 | 采纳方案 A | **删除 `chunk_layout.csv`**，chunk 直接从 `scene_zones.csv` 派生；`priority`/`preload_radius` 作为 `scene_zones.csv` 新增列 |
| **P1-2** NPC/交互物归属 | 采纳 | **NPC 属 node**（挂 `NodeContainer[node_id]`，世界坐标，跨 chunk 不 reparent）；**静态交互物属 chunk**；**动态交互物属 node** |
| **P1-3** AreaRuntime 内存无上限 | 采纳 | LRU 驱逐，**N=3**；驱逐时序列化 NPC 状态到 `NpcManager` |
| **P1-4** 定时重建缺失 | 采纳 | `refresh_chunk(chunk_id)` **只重建 backdrop 绘制缓存**，不重建 NPC/交互物 |
| **P1-5** scene_zones 可能重叠/空洞 | 采纳 | 加载时断言 zone 矩形**无重叠、无空洞、并集 == map_size**；不满足则 `push_error` 拒绝启动 |
| **P2-1** stream_group 死字段 | 采纳 | **删除** `stream_group` |
| **P2-2** WorldGraph.instance() 不存在 | 采纳 | `WorldGraph` 作为 **autoload 单例**（`autoload/world_graph.gd`），`instance()` 改为直接引用 autoload 名 |
| **P2-3** 环境变量不可用 | 采纳 | 改为 `ProjectSettings.get_setting("debug/dump_world_graph")` + 命令行 `--dump-world-graph` |
| **P2-4** CoopManager 坐标同步 | 采纳 | chunk 加载取**所有玩家位置并集**，`preload_radius` 取最大值；`GameState.current_area` 为**本地玩家**的 area；`travel_completed` 只在本地玩家跨 node 时触发 |
| **P2-5** Vector2 存档格式 | 采纳 | 存档用 **ConfigFile**，`store_var("world_pos", pos)`；补 `is_equal_approx` 测试 |

---

## 二、最终架构

```
WorldRoot (Node2D, 世界坐标系根)
├── WorldGraph (autoload, 静态拓扑, 只读)
├── ChunkStreamer (Node2D, 管理 chunk 生命周期)
│   ├── NodeContainer[street_main]      ← 每个 node 一个容器
│   │   ├── Chunk[street_center]        ← AreaBackdrop 裁剪实例
│   │   ├── Chunk[street_market]
│   │   └── ...
│   ├── NodeContainer[home_interior]    ← 隔离区，world_y >= 3000
│   └── ...
├── NpcLayer (Node2D, NPC 属 node, 世界坐标)
├── InteractableLayer (Node2D, 动态交互物属 node)
├── PlayerActor (世界坐标, 唯一实例, 永不重建)
└── CameraRig (Node2D, 跟随 player, 永不 snap, 单一坐标系)
```

**核心不变量**：
1. `PlayerActor` 全局唯一，`global_position` 在世界坐标系中连续。
2. `CameraRig` 全局唯一，**单一世界坐标系**，`position` 平滑跟随，**永不 snap**（传送时用 fade 遮罩）。
3. `Chunk` 是加载/卸载单位，`NodeContainer` 是逻辑单位，二者解耦。
4. `GameState.current_area` 降级为**派生值**（由 player 所在 node 反查）。
5. **所有 node 的 world_rect 两两不相交**（加载时断言）。

---

## 三、数据结构

### 3.1 `data/world_graph.csv`（新增，拓扑唯一数据源）

```csv
node_id,area_id,kind,world_x,world_y,world_w,world_h,parent_node,entry_spawn,street_door_pos,interior_entry_pos
street_main,street,outdoor,0,0,2560,1440,,default,,
home_interior,home,interior,0,3000,1280,720,street_main,default,"120,1320","640,3360"
store_interior,store,interior,0,3800,1280,720,street_main,default,"640,900","640,4160"
market_interior,market,interior,0,4600,1280,720,street_main,default,"250,620","640,4960"
commercial_main,commercial_district,outdoor,2560,0,1280,720,street_main,east_gate,,
industrial_main,industrial_district,outdoor,0,1440,1280,720,street_main,south_gate,,
```

**字段语义（返工后）**：
- `node_id`：全局唯一节点 ID。
- `area_id`：对应 `SceneRouter.VALID_AREAS` 的绘制/逻辑类型。
- `kind`：`outdoor` / `interior`。
- `world_x/y/w/h`：世界坐标矩形。**interior 必须放在隔离区（`world_y >= 3000`），与所有 outdoor 不相交**。
- `parent_node`：interior 挂在哪个 outdoor 节点下。
- `entry_spawn`：从外部进入该节点的默认 spawn_id。
- `street_door_pos`：**街道侧门点**（玩家在街道上走到这里触发进门）。
- `interior_entry_pos`：**interior 侧落点**（玩家进门后传送到的世界坐标）。

**加载时断言**：
```gdscript
# world_graph_loader.gd
func _validate_no_overlap(nodes: Dictionary) -> void:
    var ids := nodes.keys()
    for i in ids.size():
        for j in range(i + 1, ids.size()):
            var a: Rect2 = nodes[ids[i]].world_rect
            var b: Rect2 = nodes[ids[j]].world_rect
            if a.intersects(b):
                push_error("world_graph 矩形重叠: %s vs %s" % [ids[i], ids[j]])
                assert(false)
```

### 3.2 `data/scene_zones.csv`（修改，新增两列）

```csv
zone_id,area_id,rect_x,rect_y,rect_w,rect_h,priority,preload_radius
center,street,900,600,580,260,0,1
market,street,250,300,500,320,0,1
village,street,60,880,620,520,0,1
nature,street,850,900,650,500,0,1
commercial,street,1500,900,620,420,0,1
industrial,street,1450,60,760,420,0,1
suburb,street,2000,900,500,440,0,1
activity,street,500,120,600,180,0,1
home_interior_c0,home,0,3000,1280,720,1,0
store_interior_c0,store,0,3800,1280,720,1,0
```

**加载时断言**：
```gdscript
func _validate_zones_cover_area(area_id: String, zones: Array) -> void:
    var map_size := _get_map_size(area_id)  # street: 2560x1440, 其他: 1280x720
    var union := Rect2()
    for z in zones:
        if union.is_empty():
            union = z.rect
        else:
            union = union.merge(z.rect)
    if not union.encloses(Rect2(Vector2.ZERO, map_size)):
        push_error("zone 未覆盖 %s 的 map_size" % area_id)
        assert(false)
    # 两两不相交
    for i in zones.size():
        for j in range(i + 1, zones.size()):
            if zones[i].rect.intersects(zones[j].rect):
                push_error("zone 重叠: %s vs %s" % [zones[i].id, zones[j].id])
                assert(false)
```

### 3.3 存档结构（ConfigFile）

```gdscript
# SaveManager
{
    "schema_version": 2,
    "world_pos": Vector2,        # 新增，store_var
    "current_area": String,      # 保留，旧档兼容
    "spawn_id": String,          # 保留
}
```

**迁移规则**：
- 旧档（无 `world_pos`）→ 用 `current_area` + `spawn_id` 查 `WorldGraph.nodes[area_id].entry_spawn` 得到世界坐标，写入 `world_pos`，`schema_version=2`。
- 新档 → 直接读 `world_pos`，`current_area` 由 `WorldGraph.node_at(world_pos)` 反查。
- **`SceneRouter.travel_to()` 保留**，内部改为：查目标 node 的 spawn 世界坐标 → 设置 player 位置 → 同步加载 chunk → 发 `travel_completed`（兼容旧监听者）。

---

## 四、ChunkStreamer 实现

```gdscript
class_name ChunkStreamer
extends Node2D

const LOAD_RADIUS := 1
const UNLOAD_RADIUS := 2
const MAX_RUNTIME_POOL := 3   # LRU 驱逐上限

var _loaded_chunks: Dictionary = {}      # chunk_id -> Node2D
var _node_containers: Dictionary = {}    # node_id -> Node2D
var _runtime_pool: Dictionary = {}       # node_id -> NodeContainer (LRU)
var _player_node_id: String = ""

func _process(_delta: float) -> void:
    var player_pos := _player.global_position
    var node_id := WorldGraph.node_at(player_pos)
    if node_id != _player_node_id:
        _player_node_id = node_id
        _update_streaming(node_id)

func _update_streaming(node_id: String) -> void:
    var want := WorldGraph.chunks_within(node_id, LOAD_RADIUS)
    for cid in want:
        if not _loaded_chunks.has(cid):
            _load_chunk(cid)
    for cid in _loaded_chunks.keys():
        if WorldGraph.chunk_distance(node_id, cid) > UNLOAD_RADIUS:
            _unload_chunk(cid)
    _evict_runtime_pool()

func _load_chunk(chunk_id: String) -> void:
    var def := WorldGraph.chunks[chunk_id]
    var container := _get_or_create_container(def.node_id)
    var backdrop := AreaBackdrop.new()
    backdrop.configure_chunk(def.area_id, def.rect)
    backdrop.position = def.rect.position
    container.add_child(backdrop)
    _loaded_chunks[chunk_id] = backdrop

func _unload_chunk(chunk_id: String) -> void:
    if _loaded_chunks.has(chunk_id):
        _loaded_chunks[chunk_id].queue_free()
        _loaded_chunks.erase(chunk_id)

func _evict_runtime_pool() -> void:
    if _runtime_pool.size() <= MAX_RUNTIME_POOL:
        return
    # LRU：驱逐最久未访问的 node
    var oldest := _runtime_pool.keys()[0]
    for nid in _runtime_pool.keys():
        if _runtime_pool[nid].last_access < _runtime_pool[oldest].last_access:
            oldest = nid
    # 序列化 NPC 状态到 NpcManager
    NpcManager.serialize_node(oldest)
    _runtime_pool[oldest].queue_free()
    _runtime_pool.erase(oldest)
```

**Chunk 场景结构**（每个 chunk 一个 .tscn，编辑器可视化摆放）：

```
Chunk[street_market] (Node2D, position = zone.rect.position)
├── Backdrop (AreaBackdrop, 只画本 zone 的地面/建筑)
├── StaticInteractables (Node2D, 门、招牌)
└── Portals (Node2D, Area2D 触发区)
```

**NPC 归属**：NPC 挂在 `NodeContainer[node_id]` 下，**不随 chunk 卸载**。`NodeContainer` 由 LRU 池管理，驱逐时序列化 NPC 状态。

---

## 五、门内外衔接（返工后）

### 5.1 interior 占世界坐标，放在隔离区

`home_interior` 的 `world_rect = (0, 3000, 1280, 720)`，与 `street_main` 的 `(0,0,2560,1440)` **不相交**。

### 5.2 进门流程

```gdscript
# Portal 触发（Area2D.body_entered）
func _on_portal_entered(portal: Portal, body: Node2D) -> void:
    if body != _player: return
    var node := WorldGraph.nodes[portal.target_node]
    # 1. 传送 player 到 interior 世界坐标
    _player.global_position = node.interior_entry_pos
    # 2. 同步加载 interior chunk
    _chunk_streamer.force_load_around(node.interior_entry_pos)
    # 3. 隐藏 outdoor chunk（不卸载，保留状态）
    _chunk_streamer.set_node_visible(portal.parent_node, false)
    # 4. 镜头 fade 遮罩（0.2s），因为传送距离远
    _camera_rig.fade_transition(0.2)
    # 5. 更新 GameState
    GameState.current_area = node.area_id
    GameState.spawn_id = node.entry_spawn
```

**镜头**：`CameraRig` 单一世界坐标系，`position` 平滑跟随 player。传送时用 **fade 遮罩**（0.2s 黑场），避免镜头穿帮。**删除双坐标系分支**。

### 5.3 出门流程

反向操作：传送 player 到 `street_door_pos`，加载 outdoor chunk，隐藏 interior chunk。

---

## 六、AreaBackdrop 裁剪契约（返工后）

```gdscript
class_name AreaBackdrop
extends Node2D

var _area_id: String
var _chunk_rect: Rect2

func configure_chunk(area_id: String, chunk_rect: Rect2) -> void:
    _area_id = area_id
    _chunk_rect = chunk_rect
    queue_redraw()

func _draw() -> void:
    # 只发出与 _chunk_rect 相交的绘制调用
    match _area_id:
        "street":
            _draw_street()
        "home":
            _draw_home()
        # ...

func _draw_street() -> void:
    # 道路：全图 Rect2(0, 600, 2560, 200)
    var road := Rect2(0, 600, 2560, 200)
    var clipped := road.intersection(_chunk_rect)
    if clipped.has_area():
        draw_rect(clipped, Color(0.3, 0.3, 0.3))
    # 建筑：逐个判断相交
    for building in _buildings:
        var b := building.rect.intersection(_chunk_rect)
        if b.has_area():
            draw_rect(b, building.color)
```

**性能断言**：
```gdscript
# 测试：单个 chunk 的 draw_calls <= 全图 draw_calls / chunk 数量 * 1.5
func test_chunk_draw_calls() -> void:
    var full_calls := _count_draw_calls("street", Rect2(0, 0, 2560, 1440))
    var chunk_calls := _count_draw_calls("street", Rect2(0, 0, 1280, 720))
    assert(chunk_calls <= full_calls / 4.0 * 1.5)
```

---

## 七、SceneRouter 降级为适配层

```gdscript
# autoload/scene_router.gd
func travel_to(area_id: String, spawn_id: String = "default") -> void:
    if area_id not in VALID_AREAS:
        push_warning("未知区域：%s" % area_id)
        return
    var node := WorldGraph.node_by_area(area_id)
    var world_pos: Vector2 = node.entry_spawn_pos(spawn_id)
    var world := get_tree().get_first_node_in_group("world")
    if world != null and world.has_method("teleport_player"):
        world.teleport_player(world_pos, area_id)
    else:
        # fallback：只在 feature flag 关闭时走
        GameState.current_area = area_id
        GameState.spawn_id = spawn_id
        travel_completed.emit(area_id, spawn_id)

func restore(area_id: String, spawn_id: String) -> void:
    if area_id not in VALID_AREAS:
        area_id = "home"
    GameState.current_area = area_id
    GameState.spawn_id = spawn_id
```

**所有现有 `travel_to` 调用点零改动**。

---

## 八、WorldRoot 改造

```gdscript
func _ready() -> void:
    add_to_group("world")
    _chunk_streamer = ChunkStreamer.new()
    _chunk_streamer.configure(player)
    add_child(_chunk_streamer)
    _camera_rig = CameraRig.new()
    _camera_rig.configure(player)
    add_child(_camera_rig)
    # 恢复存档位置
    var world_pos := SaveManager.get_world_pos()
    if world_pos == Vector2.ZERO:
        world_pos = WorldGraph.node_by_area(GameState.current_area).entry_spawn_pos(GameState.spawn_id)
    player.global_position = world_pos
    _chunk_streamer.force_load_around(world_pos)

func teleport_player(world_pos: Vector2, area_id: String) -> void:
    player.global_position = world_pos
    GameState.current_area = area_id
    _chunk_streamer.force_load_around(world_pos)
    _camera_rig.fade_transition(0.2)
    travel_completed.emit(area_id, GameState.spawn_id)
```

**删除**：`_build_area()`、`_area_root`、`_on_travel_requested` 的全量重建逻辑。
**保留**：所有 `*_requested` 信号、`_process` 中的 coop 同步、`_unhandled_input` 点击逻辑。

---

## 九、迁移步骤（可增量上线）

| 阶段 | 内容 | 验证 | 回退 |
|---|---|---|---|
| **P0** | 新增 `WorldGraph` autoload + `world_graph.csv`；修正 `scene_zones.csv`（补 priority/preload_radius，校验无重叠/空洞）；新增 `world_graph_loader.gd` 含断言 | `--dump-world-graph` 打印所有节点，人工核对矩形不相交、zone 覆盖完整 | 删文件 |
| **P1** | 新增 `ChunkStreamer` + `CameraRig`，**不接入**；`SceneRouter.travel_to` 改为**同步阻塞加载**，禁止 fallback | 单元测试：`travel_to` 后目标 chunk 已加载 | 关 flag |
| **P2** | `WorldRoot` 双路径：feature flag `world.streaming`，false 走旧 `_build_area`；`AreaBackdrop.configure_chunk` 实现裁剪 | 开 flag 跑全图，对比旧路径行为；draw_calls 断言 | 关 flag |
| **P3** | 拆分 `street` 为 8 个 chunk，逐个迁移；**同时迁移 `commercial_district`（1280×720）验证坐标系** | 从 `street_center` 走到 `street_market`，镜头无 snap，NPC 不重生 | 单 chunk 回退 |
| **P4** | 迁移 `industrial_district` / `suburb` / `riverside` | 同上 | 同上 |
| **P5** | 迁移门内区域（`home_interior` / `store_interior` / `market_interior`），放在隔离区 | 进出门，镜头 fade 过渡，坐标连续 | 保留旧路径 |
| **P6** | 删除 `_build_area`，`SceneRouter` 完全降级；`AreaRuntime` LRU 驱逐（N=3） | 走完全图，`_runtime_pool.size() <= 3`，内存峰值 ≤ 旧路径 × 1.2 | git revert |

**每阶段可独立验证**：P2 后开 flag 跑一遍全图，对比旧路径行为。

---

## 十、验证清单

| 项 | 方法 | 通过标准 |
|---|---|---|
| **拓扑校验** | 加载 `world_graph.csv` | 任意两 node 矩形不相交，interior 在隔离区 |
| **zone 校验** | 加载 `scene_zones.csv` | zone 无重叠、无空洞、并集 == map_size |
| **连续行走** | 从 `street_center` 走到 `street_market` | 镜头无 snap，NPC 实例 ID 不变，`GameState.current_area` 保持 `street` |
| **门内外** | 从 `street` 走进 `home`，再进 `home_interior` | 镜头 fade 过渡，退出后回到原位，坐标连续 |
| **存档兼容** | 加载旧档（schema_version=1） | 自动迁移到 v2，位置正确 |
| **存档精度** | 写入 `world_pos = Vector2(123.456, 789.012)` | 读回 `is_equal_approx` |
| **跨区传送** | `bus_station` → `seaside_resort` | fade 过渡，chunk 正确加载 |
| **性能** | `street` 全图行走 60s | 常驻 chunk ≤ 3，内存峰值 ≤ 旧路径 × 1.2 |
| **draw_calls** | 单 chunk vs 全图 | chunk_calls ≤ full_calls / chunk 数量 × 1.5 |
| **LRU 驱逐** | 走完全图 34 个 area | `_runtime_pool.size() <= 3` |
| **定时重建** | 在 restaurant 待 60s | NPC 实例 ID 不变，对话进度不变，backdrop 重绘 ≥ 1 |
| **联机** | 两玩家分别在 `street` 和 `home_interior` | 两 chunk 都加载，`travel_completed` 不重复触发 |
| **回归** | 所有 `*_requested` 信号、点击交互、coop 同步 | 行为不变 |

---

## 十一、风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| `AreaBackdrop._draw()` 改造引入视觉接缝 | 画风破坏 | P3 先只对 `street` + `commercial_district` 试点，其他区保留旧路径 |
| 旧档 `current_area` 与新 `active_node_id` 不一致 | 读档错位 | 读档时以 `world_pos` 为准，`current_area` 仅作 fallback |
| chunk 卸载时 NPC 状态丢失 | 任务中断 | NPC 属 node，挂 `NodeContainer`，LRU 驱逐时序列化到 `NpcManager` |
| `scene_zones.csv` 的 zone 矩形与 chunk 不匹配 | 加载错位 | 加载时断言无重叠/空洞/覆盖完整，失败拒绝启动 |
| 多人 coop 坐标不同步 | 联机错位 | chunk 加载取所有玩家位置并集，`preload_radius` 取最大值 |
| `WorldRoot._process()` 里的定时重建 | 与新架构冲突 | 改为 `ChunkStreamer.refresh_chunk(node_id)`，只重建 backdrop 绘制缓存 |
| 传送距离远导致镜头穿帮 | 视觉突兀 | `CameraRig.fade_transition(0.2)` 黑场遮罩 |
| `AreaRuntime` 池化内存无上限 | 内存泄漏 | LRU 驱逐，N=3，驱逐时序列化 NPC 状态 |

---

## 十二、回退策略

1. **Feature Flag**：`world.streaming.enabled`（默认 false）。关闭时完全走旧路径 `_build_area()`，保证可回退。
2. **分阶段回退**：每阶段独立可回退（P0-P2 删文件/关 flag，P3-P5 单 chunk 回退，P6 git revert）。
3. **存档双写**：P4 起新档同时写 `world_pos` 和 `current_area`，旧档读入后自动迁移，**不删除旧字段**。
4. **数据校验失败拒绝启动**：`world_graph.csv` / `scene_zones.csv` 校验失败时 `push_error` + `assert(false)`，避免带病运行。

---

## 十三、交付物清单

**新增文件**：
- `data/world_graph.csv`
- `autoload/world_graph.gd`（autoload 单例）
- `scripts/data/world_graph_loader.gd`（含断言）
- `scripts/gameplay/chunk_streamer.gd`
- `scripts/gameplay/camera_rig.gd`
- `scripts/gameplay/node_container.gd`

**修改文件**：
- `data/scene_zones.csv`（新增 priority/preload_radius 列）
- `scripts/gameplay/world.gd`（接入 ChunkStreamer，删除全量重建）
- `scripts/gameplay/area_backdrop.gd`（新增 `configure_chunk`，`_draw()` 裁剪）
- `autoload/scene_router.gd`（`travel_to` 转调 WorldStreamer，同步阻塞加载）
- `autoload/save_manager.gd`（新增 `world_pos` + `schema_version` + 迁移函数）
- `autoload/npc_manager.gd`（新增 `serialize_node` / `deserialize_node`）
- `autoload/coop_manager.gd`（坐标同步改为 world_pos，chunk 加载取并集）

**Feature Flag**：
- `world.streaming.enabled`（默认 false，P2 后逐步开启）
- `debug/dump_world_graph`（ProjectSettings，替代环境变量）

---

**一句话总结**：把"区域"从**加载单位**降级为**逻辑标签**，把"chunk"提升为**加载单位**，把"世界坐标"提升为**唯一真相**。interior 放隔离区避免矩形重叠，SceneRouter 保留 API 但不再驱动重建，存档通过 `schema_version` 无损迁移，所有数据加载时断言校验，feature flag 保证可回退。
