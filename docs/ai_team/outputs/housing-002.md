# 房间装扮与房产购买实物交互

## 主方案

# 《深日记》房间装扮 × 家具购买 × 房产升级 —— 唯一可执行方案

> 综合裁决：以「场景实物 + NPC 驱动」为唯一购买路径，**禁止菜单直购**。骨架取 `wardrobe-001` 的"穿戴态/持有态分离"哲学与 `economy-002` 的"单一状态载体"原则，机制取 `farm-001` 的"实物驱动 + 数据表唯一事实源"，逐条闭环批判报告 P0/P1。
>
> **硬约束**：无任务面板、无数值属性条、场景点击经营、NPC/系统/场景提示分离、固定物价、存档兼容、温柔治愈画风。
>
> **唯一事实源**：`data/furniture.csv`（家具定义）/ `data/furniture_grid.csv`（网格占用）/ `data/housing.csv`（房产档位）/ `data/renovations.csv`（装修）。代码中禁止出现家具名、价格、网格尺寸字面量。
>
> **本方案在门禁未通过前不得写任何业务代码。** 门禁结果写入 `docs/ROOM_FACTS.md`。

---

## 0. 前置门禁（阻塞性，未通过不得写代码）

### G0.1 `RoomManager` 真实接口与存档字段
```bash
grep -n "^func \|^signal \|^var \|^const " autoload/room_manager.gd
grep -rn "room_manager\|RoomManager" --include=*.gd autoload/save_manager.gd scripts/ | head -30
```
**必须回答**：
- `owned` / `placed` / `layouts` / `manual_positions` / `manual_rotations` 的真实类型（`Dictionary` 键类型、值类型）。
- `get_save_data()` / `restore()` 是否存在？若不存在，本方案 §5 提供。
- `manual_positions` 存的是 `Vector2` 还是 `{x,y}`？**存档 JSON 不能直接序列化 `Vector2`**，必须确认现有序列化方式。

**裁决**：
- 若 `manual_positions` 存 `Vector2` 且 `SaveManager` 直接 `JSON.stringify` → **必须改为 `{"x": float, "y": float}`**，并在 `restore` 做兼容读取（旧档 `Vector2` → 新档 dict）。
- 若已用 dict → 沿用。

### G0.2 `ConfigDB` 读取方式
```bash
grep -n "func get_row\|func get_rows" autoload/config_db.gd
grep -rn "ConfigDB.get_row" --include=*.gd autoload/room_manager.gd
```
**裁决**：
- 若 `get_row` 按列名取值 → 可安全新增列。
- 若按索引 → **禁止新增列**，新建 `data/furniture_grid.csv` 用 `furniture_id` join。

### G0.3 现有 `furniture.csv` 字段
```bash
head -1 data/furniture.csv
python -c "import csv; r=list(csv.DictReader(open('data/furniture.csv'))); print(len(r)); print(r[0] if r else 'EMPTY')"
```
**必须输出**：现有列名、行数、`category` 取值集合。
**裁决**：`category` 取值必须与 `RoomManager.SLOT_NAMES` 的键一一对应。若有不匹配（如 `furniture.csv` 有 `decor` 但 `SLOT_NAMES` 无），**以 `SLOT_NAMES` 为准补 `furniture.csv`**，或删除孤儿 slot。

### G0.4 房间场景与渲染管线
```bash
grep -rn "room_furniture_layer\|RoomFurnitureLayer" --include=*.gd scripts/
ls scripts/gameplay/ | grep -i room
grep -rn "current_area == \"home\"\|current_area == \"room\"\|出租屋" --include=*.gd scripts/ autoload/
```
**必须回答**：
- 房间场景 key 是什么？（`home` / `room` / `rental`）
- `room_furniture_layer.gd` 如何渲染家具？用 `Sprite2D` 还是 `_draw()`？
- 家具位置是归一化坐标（0~1）还是像素坐标？

**裁决**：
- 若归一化 → 沿用，网格映射在归一化空间做（见 §2）。
- 若像素 → 必须确认房间基准分辨率，网格按像素对齐。

### G0.5 `HousingManager` 与 `renovations.csv` 关联
```bash
grep -rn "renovation\|installed_decor\|renovation_style" --include=*.gd autoload/ scripts/
```
**必须回答**：`renovations.csv` 是否已被任何代码消费？`RoomManager.installed_decor` / `renovation_style` 是否被读取？

**裁决**：
- 若未被消费 → 本方案 §4 补全装修购买与生效链路。
- 若已消费 → 只做增量，不重写。

### G0.6 生活质量/家庭/社交的现有载体
```bash
grep -rn "quality_of_life\|life_quality\|family\|social\|relax_bonus\|study_bonus" --include=*.gd autoload/ scripts/ | head -30
```
**必须回答**：`HousingManager.get_bonus()` 的 `energy/study/relax` 被谁读取？是否有 `family` / `social` 维度？

**裁决**：
- 若只有 `energy/study/relax` → 本方案**不新增数值维度**（违反"无数值属性条"），改为**场景可见状态**（见 §6）。
- 若已有 `family`/`social` → 复用。

---

## 1. 决策摘要（先拍板）

| # | 争议 | 最终裁决 | 理由 |
|---|---|---|---|
| **D1** | 购买路径 | **三选一，全部实物驱动**：① 家居超市 NPC 导购（`fangjie` 或新驻场）② 样板间点击家具 ③ 旧货市场实物（`chen`） | 硬约束"不是菜单点一下就完成" |
| **D2** | 网格粒度 | **16px 逻辑网格**，房间归一化坐标映射到网格 | 与 `art-001` G0.2 一致 |
| **D3** | 占用模型 | **矩形占用 + 碰撞检测**，同格不可叠放（地毯类除外） | 见 §2.2 |
| **D4** | 旋转 | **15° 步进**（沿用现有 `rotate_furniture`），但**占用矩形按 90° 量化** | 视觉自由旋转，逻辑只认 4 向 |
| **D5** | 收纳 | **未摆放 = 收纳态**，`owned` 保留，`placed` 移除。收纳不消耗空间 | 与 `wardrobe-001` "持有态/穿戴态"一致 |
| **D6** | 房产升级 | **必须通过 `fangjie` NPC 或样板间**，不可菜单直购 | 硬约束 |
| **D7** | 装修（renovation） | **样板间体验后购买**，购买后立即生效，不可撤销 | 见 §4 |
| **D8** | 生活质量关联 | **不新增数值条**，改为**场景可见反馈**（灯光色温、NPC 台词、访客行为） | 硬约束"无数值属性条" |
| **D9** | 存档字段 | `owned` / `placed` / `layouts` / `manual_positions` / `manual_rotations` / `installed_decor` / `renovation_style` / `housing_tier` | 见 §5 |
| **D10** | 多套搭配 | `layouts` 保留，切换 layout 时 `placed` 整体替换 | 沿用现有 |

---

## 2. 家具网格与占用模型

### 2.1 网格定义

**房间逻辑网格**：`16px × 16px`，房间基准 `1280×720` → `80 × 45` 格。

**归一化坐标 ↔ 网格坐标**：
```
grid_x = floor(norm_x * 80)
grid_y = floor(norm_y * 45)
norm_x = (grid_x + 0.5) / 80
norm_y = (grid_y + 0.5) / 45
```

**裁决**：`manual_positions` 存归一化坐标（沿用现有），**但吸附到网格中心**。`nudge_furniture` 的 `delta` 必须量化到 `1/80` 和 `1/45`。

### 2.2 占用模型

新建 `data/furniture_grid.csv`：

```csv
furniture_id,grid_w,grid_h,anchor_x,anchor_y,allow_overlap,rotate_quantize
bed_single,4,6,0.5,0.5,false,90
bed_double,6,6,0.5,0.5,false,90
rug_small,4,3,0.5,0.5,true,90
rug_large,6,4,0.5,0.5,true,90
table_dining,4,4,0.5,0.5,false,90
shelf_wall,3,1,0.5,0.5,false,90
plant_pot,1,1,0.5,0.5,false,0
lamp_floor,1,1,0.5,0.5,false,0
desk_study,4,2,0.5,0.5,false,90
appliance_fridge,2,3,0.5,0.5,false,90
aquarium_small,3,2,0.5,0.5,false,90
pet_corner,2,2,0.5,0.5,false,90
```

**字段说明**：
- `grid_w/grid_h`：未旋转时的占用格数。
- `anchor_x/anchor_y`：家具锚点在自身包围盒内的归一化位置（0.5 = 中心）。
- `allow_overlap`：`true` 时可与其他家具重叠（地毯类）。
- `rotate_quantize`：旋转量化步进（`90` = 只认 4 向，`0` = 不可旋转）。

**占用矩形计算**（旋转后）：
```gdscript
func get_occupancy(fid: String, grid_pos: Vector2i, rotation_deg: int) -> Rect2i:
    var row := ConfigDB.get_row("furniture_grid", fid)
    var w := int(row.get("grid_w", "1"))
    var h := int(row.get("grid_h", "1"))
    var q := int(row.get("rotate_quantize", "90"))
    if q == 90 and (rotation_deg / 90) % 2 == 1:
        var t := w; w = h; h = t
    var ax := float(row.get("anchor_x", "0.5"))
    var ay := float(row.get("anchor_y", "0.5"))
    var origin := Vector2i(
        grid_pos.x - int(floor(w * ax)),
        grid_pos.y - int(floor(h * ay))
    )
    return Rect2i(origin, Vector2i(w, h))
```

### 2.3 碰撞检测

```gdscript
func can_place_at(fid: String, grid_pos: Vector2i, rotation_deg: int) -> bool:
    var occ := get_occupancy(fid, grid_pos, rotation_deg)
    # 边界检查
    if occ.position.x < 0 or occ.position.y < 0:
        return false
    if occ.end.x > ROOM_GRID_W or occ.end.y > ROOM_GRID_H:
        return false
    # 重叠检查
    var self_row := ConfigDB.get_row("furniture_grid", fid)
    var self_overlap := bool(self_row.get("allow_overlap", "false"))
    for slot_id in placed:
        var other_fid := str(placed[slot_id])
        if other_fid == fid:
            continue
        var other_row := ConfigDB.get_row("furniture_grid", other_fid)
        var other_overlap := bool(other_row.get("allow_overlap", "false"))
        if self_overlap and other_overlap:
            continue  # 地毯叠地毯允许
        if self_overlap or other_overlap:
            continue  # 地毯可与家具重叠
        var other_pos := get_grid_position(other_fid)
        var other_rot := int(manual_rotations.get(other_fid, 0))
        var other_occ := get_occupancy(other_fid, other_pos, other_rot)
        if occ.intersects(other_occ):
            return false
    return true
```

**裁决**：`allow_overlap=true` 的家具（地毯）可与任何家具重叠，但**两个 `allow_overlap=false` 的家具不可重叠**。

### 2.4 默认槽位 → 网格坐标映射

现有 `get_default_slot_position` 返回归一化坐标，需补网格版本：

```gdscript
const SLOT_DEFAULT_GRID := {
    "bed": Vector2i(18, 15),
    "light": Vector2i(62, 11),
    "rug": Vector2i(42, 28),
    "rug_alt": Vector2i(42, 28),
    "shelf": Vector2i(60, 16),
    "plant": Vector2i(69, 30),
    "table": Vector2i(38, 22),
    "appliance": Vector2i(19, 32),
    "aquarium": Vector2i(50, 36),
    "pet": Vector2i(60, 34),
    "desk": Vector2i(30, 20),
}
```

**裁决**：`SLOT_DEFAULT_GRID` 是**唯一默认位置事实源**，`get_default_slot_position` 改为从它反算归一化坐标。

---

## 3. 场景点击流程（核心）

### 3.1 购买路径 A：家居超市 NPC 导购

**场景**：`commercial_district` 的 `furniture_shop` 子区（若不存在，见 §7 风险）。

**流程**：
1. 玩家进入家居超市，看到**样板间**（3~4 个家具组合展示区）。
2. 点击样板间中的家具 → 触发 `WorldInteractable.on_tap()` → 弹出**家具信息卡**（名称、价格、占用格数、可放位置）。
3. 信息卡上有两个按钮：**「请导购帮忙」** / **「先看看」**。
4. 点「请导购帮忙」→ 导购 NPC（`fangjie` 或新驻场 `jia_ju`）走近，说一句台词（如"这件放窗边正好，我帮你记下"）。
5. 导购确认后 → 调用 `RoomManager.buy(fid)` → 扣钱 → 家具进入 `owned` → **自动放入收纳态**（不自动摆放）。
6. 提示："买下了 XX，回出租屋再摆吧。"

**关键裁决**：
- **不自动摆放**。现有 `buy()` 里的 `auto_place(fid)` 必须删除，改为 `owned[fid] = true` 后**不调用 `place_at`**。
- 导购 NPC 台词走 `NoticeManager`，`source_kind = "npc"`，`speaker = "方姐"`。

### 3.2 购买路径 B：样板间点击

**场景**：`furniture_shop` 内的样板间区域。

**流程**：
1. 样板间是一个**完整房间布置**（如"小户型客厅"），玩家可点击任意家具。
2. 点击 → 信息卡 → 「照这个买一套」→ 一次性购买样板间内所有家具（打包价 = 单价之和 × 0.9）。
3. 购买后所有家具进入 `owned`，**不自动摆放**。

**裁决**：打包折扣写入 `data/furniture_bundles.csv`：
```csv
bundle_id,name,furniture_ids,discount
living_room_basic,小户型客厅,sofa_small|table_coffee|shelf_wall|rug_small,0.9
study_corner,安静书房角,desk_study|shelf_wall|lamp_floor,0.9
```

### 3.3 购买路径 C：旧货市场实物

**场景**：`market` 的旧货摊（`chen` NPC）。

**流程**：
1. 旧货摊上摆着**实物家具**（低分辨率、有磨损）。
2. 点击 → `chen` 说："这件是别人搬家留下的，便宜给你。"
3. 确认购买 → `RoomManager.buy(fid)`，价格 = `furniture.csv` 的 `price × 0.6`。
4. **旧货家具带 `condition` 标记**（`worn`），影响后续生活质量反馈（见 §6）。

**裁决**：旧货家具在 `owned` 里存 `{"fid": true, "condition": "worn"}`，需扩展 `owned` 值类型为 `Dictionary`。**存档兼容**：旧档 `owned[fid] = true` 读取时视为 `condition = "new"`。

### 3.4 摆放流程（房间内）

**进入编辑模式**：
- 玩家在出租屋点击**门边的工具箱**（`WorldInteractable`）→ `_room_edit_mode = true`。
- 或点击**已摆放的家具** → 直接进入该家具的编辑态。

**编辑模式操作**：
| 手势 | 语义 |
|---|---|
| `TAP` 家具 | 选中，显示占用网格（半透明绿色/红色） |
| `TAP` 空地 | 若已选中家具，尝试移动到该格 |
| `DRAG` 家具 | 拖动，实时显示占用网格 |
| `SECONDARY`（右键） | 取消选中 / 收纳 |
| `HOLD` 家具 | 显示旋转菜单（15° 步进） |
| `TAP` 工具箱 | 退出编辑模式 |

**裁决**：
- **移动时实时碰撞检测**，不可放置时占用网格变红，松手回弹。
- **旋转只改视觉角度**，占用矩形按 `rotate_quantize` 量化。
- **收纳 = `unplace(fid)`**，家具回到收纳态，`owned` 保留。

### 3.5 收纳流程

**收纳入口**：
- 编辑模式下 `SECONDARY` 点击家具 → 收纳。
- 或点击**墙边的收纳柜**（`WorldInteractable`）→ 打开收纳列表（**不是菜单，是场景内的柜子**）→ 点击柜子里的家具 → 取出到编辑模式。

**裁决**：
- 收纳柜是**场景实物**，不是 UI 面板。
- 收纳列表用 `room_furniture_layer` 渲染在柜子旁边，点击取出。

---

## 4. 房产升级流程

### 4.1 升级路径：`fangjie` NPC

**流程**：
1. 玩家在 `commercial_district` 的房产中介找到 `fangjie`。
2. 点击 `fangjie` → 她说："想换个大点的地方？我带你去看看。"
3. **进入样板间场景**（`housing_preview`），玩家可自由走动，看到新房产的布局。
4. 样板间内有**家具占位**（灰色轮廓），提示"这里可以放床"。
5. 玩家点击**样板间中央的租约桌** → `fangjie` 确认 → `HousingManager.upgrade(housing_id)`。
6. 升级后：`current_tier` 更新，`rent_amount` 同步，**房间网格尺寸可能变化**（见 §4.3）。

**裁决**：
- **不可菜单直购**。必须走 `fangjie` + 样板间。
- 样板间场景 key：`housing_preview_{tier}`，若不存在则复用 `home` 场景 + 临时替换 backdrop。

### 4.2 装修（renovation）流程

**流程**：
1. 玩家在样板间内点击**墙面/窗户/书桌角** → 触发装修预览。
2. 预览显示装修后的效果（`renovation_style` 临时切换）。
3. 点击**样板间的确认牌** → `RoomManager.install_renovation(renovation_id)`。
4. 扣钱 → `installed_decor[renovation_id] = true` → `renovation_style` 更新。
5. 装修**立即生效**，不可撤销。

**裁决**：
- `renovations.csv` 的 `energy_bonus` / `relax_bonus` / `study_bonus` / `food_bonus` **不直接加到数值条**（违反硬约束），改为**场景可见反馈**（见 §6）。
- 装修效果通过 `HousingManager.get_bonus()` 间接影响**体力恢复速率**（已有机制），不新增 UI。

### 4.3 房间网格随房产升级变化

| housing_tier | 房间尺寸 | 网格 |
|---|---|---|
| 0（城中村单间） | 1280×720 | 80×45 |
| 1（一室一厅） | 1600×900 | 100×56 |
| 2（两室一厅） | 1920×1080 | 120×67 |
| 3（三室两厅） | 2560×1440 | 160×90 |

**裁决**：
- 升级后**已摆放家具保留**，超出新边界的家具**自动收纳**。
- `manual_positions` 是归一化坐标，**升级后位置会偏移**。必须做**网格坐标迁移**：升级前记录 `grid_pos`，升级后按比例映射到新网格。

**迁移算法**：
```gdscript
func migrate_layout(old_w: int, old_h: int, new_w: int, new_h: int) -> void:
    for fid in manual_positions.keys():
        var old_norm: Vector2 = manual_positions[fid]
        var old_grid := Vector2i(floor(old_norm.x * old_w), floor(old_norm.y * old_h))
        var new_grid := Vector2i(
            int(round(float(old_grid.x) / old_w * new_w)),
            int(round(float(old_grid.y) / old_h * new_h))
        )
        manual_positions[fid] = Vector2(
            (new_grid.x + 0.5) / new_w,
            (new_grid.y + 0.5) / new_h
        )
```

---

## 5. 存档字段

### 5.1 `RoomManager.get_save_data()`

```gdscript
func get_save_data() -> Dictionary:
    var positions := {}
    for fid in manual_positions:
        var p: Vector2 = manual_positions[fid]
        positions[fid] = {"x": p.x, "y": p.y}
    var owned_serialized := {}
    for fid in owned:
        var v = owned[fid]
        if v is Dictionary:
            owned_serialized[fid] = v
        else:
            owned_serialized[fid] = {"owned": true, "condition": "new"}
    return {
        "owned": owned_serialized,
        "placed": placed.duplicate(),
        "layouts": layouts.duplicate(true),
        "active_layout": active_layout,
        "manual_positions": positions,
        "manual_rotations": manual_rotations.duplicate(),
        "installed_decor": installed_decor.duplicate(),
        "renovation_style": renovation_style,
        "schema_version": 2,
    }
```

### 5.2 `RoomManager.restore(data)`

```gdscript
func restore(data: Dictionary) -> void:
    var version := int(data.get("schema_version", 1))
    owned.clear()
    var raw_owned: Dictionary = data.get("owned", {})
    for fid in raw_owned:
        var v = raw_owned[fid]
        if v is Dictionary:
            owned[fid] = v
        else:
            owned[fid] = {"owned": true, "condition": "new"}
    placed = data.get("placed", {}).duplicate()
    layouts = data.get("layouts", {"日常": {}, "会客": {}, "宠物角": {}}).duplicate(true)
    active_layout = str(data.get("active_layout", "日常"))
    manual_positions.clear()
    var raw_pos: Dictionary = data.get("manual_positions", {})
    for fid in raw_pos:
        var v = raw_pos[fid]
        if v is Vector2:
            manual_positions[fid] = v  # 旧档兼容
        elif v is Dictionary:
            manual_positions[fid] = Vector2(float(v.get("x", 0.5)), float(v.get("y", 0.5)))
    manual_rotations = data.get("manual_rotations", {}).duplicate()
    installed_decor = data.get("installed_decor", {}).duplicate()
    renovation_style = str(data.get("renovation_style", ""))
    if version < 2:
        _migrate_v1_to_v2()
    changed.emit()
```

### 5.3 `HousingManager` 存档

现有 `get_save_data()` 只存 `current_tier`，**保持不变**。房间网格尺寸由 `current_tier` 派生，不单独存。

### 5.4 存档兼容矩阵

| 旧字段 | 新字段 | 迁移规则 |
|---|---|---|
| `owned[fid] = true` | `owned[fid] = {"owned": true, "condition": "new"}` | 读取时自动包装 |
| `manual_positions[fid] = Vector2` | `manual_positions[fid] = {"x": float, "y": float}` | 读取时自动转换 |
| 无 `schema_version` | `schema_version = 2` | 视为 v1，触发迁移 |
| 无 `installed_decor` | `{}` | 默认空 |
| 无 `renovation_style` | `""` | 默认空 |

---

## 6. 与生活质量 / 家庭 / 社交的关联

### 6.1 生活质量：场景可见反馈（不新增数值条）

**裁决**：`renovations.csv` 的 bonus **不直接加到 UI 数值条**，改为以下可见反馈：

| 装修 | 可见反馈 |
|---|---|
| `warm_walls` | 房间灯光色温变暖（`room_furniture_layer` 的 `modulate` 从 `#FFFFFF` → `#FFE8C8`） |
| `bright_window` | 窗户区域增加光晕粒子，白天室内亮度提升 |
| `quiet_study` | 书桌区域出现"安静"氛围（背景音效切换，NPC 路过时降低音量） |
| `family_room` | 沙发区域出现"可坐"提示，访客 NPC 会主动坐下 |

**体力恢复**：`HousingManager.get_bonus("energy")` 仍影响 `PlayerActor` 的体力恢复速率（已有机制），**不新增 UI**。

### 6.2 家庭：访客行为

**裁决**：`family_room` 装修后，**访客 NPC 行为变化**：
- `li_ma`（托儿所阿姨）会带小孩来坐。
- `fangjie` 会来喝茶。
- 访客 NPC 在沙发区域停留时，`NoticeManager` 推送台词（`source_kind = "npc"`）。

**触发条件**：`installed_decor["family_room"] == true` 且 `current_tier >= 2`。

### 6.3 社交：家具作为社交道具

**裁决**：部分家具带 `social_tag`，影响 NPC 互动：

```csv
furniture_id,social_tag
aquarium_small,fish_talk
plant_pot,plant_talk
shelf_wall,book_talk
```

**触发**：NPC 到访时，若房间内有对应 `social_tag` 家具，NPC 会主动评论（如 `chen` 看到鱼缸说"这鱼养得不错"）。

**裁决**：`social_tag` 写入 `data/furniture.csv` 新增列，**不新建表**。

### 6.4 宠物角

**裁决**：`pet_corner` 家具是**宠物系统的前置**。若 `pet_manager.gd` 不存在（`gameplay-001` 已裁决宠物系统推迟），则 `pet_corner` 仅作装饰，**不触发宠物逻辑**。

---

## 7. 文件清单与执行步骤

### 7.1 新建文件

| 文件 | 用途 |
|---|---|
| `data/furniture_grid.csv` | 家具网格占用定义 |
| `data/furniture_bundles.csv` | 样板间打包 |
| `docs/ROOM_FACTS.md` | 门禁结果 + 唯一事实源 |
| `scripts/gameplay/room_edit_controller.gd` | 编辑模式手势处理 |
| `scripts/gameplay/furniture_shop_actor.gd` | 家居超市导购 NPC 交互 |

### 7.2 修改文件

| 文件 | 改动 |
|---|---|
| `autoload/room_manager.gd` | ① 删除 `buy()` 里的 `auto_place` ② 新增 `can_place_at` / `get_occupancy` / `get_grid_position` ③ 新增 `get_save_data` / `restore` ④ `nudge_furniture` 量化到网格 ⑤ `owned` 值类型扩展为 Dictionary |
| `autoload/housing_manager.gd` | ① 新增 `get_room_grid_size()` ② 升级时触发 `RoomManager.migrate_layout` |
| `data/furniture.csv` | 新增 `social_tag` 列（若 G0.2 允许） |
| `scripts/gameplay/world.gd` | ① `_room_edit_mode` 手势路由 ② 家具点击 → `room_edit_controller` |
| `scripts/gameplay/room_furniture_layer.gd` | ① 渲染占用网格 ② 装修色温反馈 ③ 收纳柜渲染 |

### 7.3 执行步骤（按顺序）

1. **跑完 G0.1~G0.6 门禁**，结果写入 `docs/ROOM_FACTS.md`。
2. **新建 `data/furniture_grid.csv`**，为现有 `furniture.csv` 每件家具补网格数据。
3. **改造 `RoomManager`**：删除 `auto_place`，新增网格方法，扩展 `owned` 类型。
4. **实现 `room_edit_controller.gd`**：手势 → 移动/旋转/收纳。
5. **改造 `room_furniture_layer.gd`**：占用网格渲染 + 装修反馈。
6. **实现家居超市导购**：`furniture_shop_actor.gd` + 样板间。
7. **实现房产升级样板间**：`fangjie` + `housing_preview`。
8. **补存档迁移**：`get_save_data` / `restore` + v1→v2 迁移。
9. **补社交/家庭反馈**：`social_tag` + 访客行为。

---

## 8. 验证

### 8.1 单元测试

| 测试 | 断言 |
|---|---|
| `test_occupancy_rotation` | 4×6 床旋转 90° 后占用 6×4 |
| `test_collision_reject` | 两件 `allow_overlap=false` 家具重叠时 `can_place_at` 返回 false |
| `test_rug_overlap` | 地毯可与床重叠 |
| `test_boundary_reject` | 家具超出房间边界时返回 false |
| `test_save_roundtrip` | `get_save_data` → `restore` 后 `owned`/`placed`/`manual_positions` 一致 |
| `test_v1_migration` | 旧档 `owned[fid]=true` 读取后为 `{"owned": true, "condition": "new"}` |
| `test_grid_migration` | 80×45 → 100×56 后家具位置按比例映射 |
| `test_buy_no_auto_place` | `buy(fid)` 后 `is_placed(fid)` 返回 false |

### 8.2 场景测试

| 场景 | 步骤 | 预期 |
|---|---|---|
| 家居超市购买 | 点击样板间家具 → 请导购 → 确认 | 扣钱，家具进 `owned`，不自动摆放 |
| 旧货市场购买 | 点击旧货摊家具 → 确认 | 价格 ×0.6，`condition = "worn"` |
| 编辑模式移动 | 拖动家具到空地 | 占用网格绿色，松手后位置更新 |
| 编辑模式碰撞 | 拖动家具到已占用格 | 占用网格红色，松手回弹 |
| 收纳 | 右键家具 | 家具回收纳态，`owned` 保留 |
| 房产升级 | 找 `fangjie` → 样板间 → 确认 | `current_tier` 更新，家具位置迁移 |
| 装修 | 样板间点击墙面 → 确认 | `renovation_style` 更新，灯光色温变化 |

### 8.3 CI 门禁

```bash
# 网格数据完整性
python tools/audit_furniture_grid.py
# 断言：furniture.csv 每件家具在 furniture_grid.csv 有对应行
# 断言：grid_w/grid_h > 0
# 断言：rotate_quantize ∈ {0, 90}

# 存档兼容
godot --headless --script tests/test_room_save_migration.gd
```

---

## 9. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| `furniture_shop` 场景不存在 | P0 | 门禁 G0.4 确认；若不存在，复用 `commercial_district` + 新增子区 |
| `owned` 类型变更破坏旧档 | P0 | `restore` 做类型兼容读取，v1→v2 迁移 |
| `manual_positions` 存 `Vector2` 无法序列化 | P0 | 门禁 G0.1 确认；改为 dict |
| 房间网格尺寸随房产变化导致家具越界 | P1 | `migrate_layout` + 越界自动收纳 |
| `renovations.csv` 未被消费 | P1 | 门禁 G0.5 确认；补全装修链路 |
| `social_tag` 新增列破坏 CSV 读取 | P1 | 门禁 G0.2 确认读取方式；若按索引则新建 join 表 |
| 宠物系统未实现，`pet_corner` 空壳 | P2 | 仅作装饰，不触发逻辑 |
| 编辑模式手势与现有 `world.gd` 冲突 | P1 | 门禁 G0.4 确认现有手势路由；`_room_edit_mode` 优先拦截 |

---

## 10. 与共享黑板的一致性

- **无任务面板**：所有购买/摆放通过场景实物 + NPC，无任务列表。
- **无数值属性条**：生活质量改为场景可见反馈，不新增 UI 数值。
- **场景点击经营**：全部操作在场景内完成。
- **NPC/系统/场景提示分离**：导购台词走 `NoticeManager` 的 `source_kind = "npc"`，系统提示走 `"system"`。
- **固定物价**：家具价格来自 `furniture.csv`，旧货 ×0.6，打包 ×0.9，**不浮动**。
- **存档兼容**：v1→v2 迁移，`owned`/`manual_positions` 类型兼容。


## 独立方案

# 房间装扮与房产购买实物交互 —— 独立方案

> **独立立场**：不沿用 `room_manager.gd` 的"槽位字典 + 归一化坐标"模型。该模型有三个结构性缺陷：(1) `placed` 是 `slot→fid` 反查，无法表达"同一家具多件"和"自由摆放"；(2) `manual_positions` 用 0~1 归一化坐标，与 world-001 的"世界坐标唯一真相"冲突，且无法做网格吸附；(3) `buy()` 直接 `GameState.spend`，违反"购买必须通过 NPC/样板间/实物"。
>
> 本方案提出 **"家具实例（FurnitureInstance）+ 网格占用位图 + 实物购买会话（PurchaseSession）"** 三层架构，与现有 `room_manager` 做**兼容迁移**而非重写。

---

## 0. 前置门禁（阻塞性，未过不得写业务代码）

结果写入 `docs/ROOM_FACTS.md`，作为唯一事实源。

```bash
# G0.1 room_manager 真实调用点（决定迁移面）
grep -rn "RoomManager\." --include=*.gd scripts/ autoload/ | grep -v "room_manager.gd"

# G0.2 家具表真实列
python -c "import csv;print(next(csv.reader(open('data/furniture.csv'))))"
python -c "import csv;[print(r) for r in list(csv.DictReader(open('data/furniture.csv')))[:5]]"

# G0.3 出租屋场景 key 与尺寸
grep -rn "home\|rental\|bedroom\|出租屋" data/scene_zones.csv data/scene_metadata.csv 2>/dev/null
grep -rn "current_area == \"home\"\|current_area == \"rental\"" --include=*.gd scripts/

# G0.4 room_furniture_layer 现有渲染契约
grep -n "^func \|^signal \|^var \|^const " scripts/gameplay/room_furniture_layer.gd

# G0.5 存档字段现状
grep -rn "room_manager\|housing_manager" autoload/save_manager.gd
grep -rn "get_save_data\|restore" autoload/room_manager.gd autoload/housing_manager.gd

# G0.6 生活质量/家庭/社交现有接口
grep -rn "quality_of_life\|life_quality\|family\|social\|affinity" --include=*.gd autoload/ | head -30
```

**裁决规则**：
- G0.1 若调用点 > 20 处 → 保留 `RoomManager` 旧 API 作薄适配层，新逻辑进 `RoomLayoutManager`。
- G0.2 若 `furniture.csv` 无 `grid_w/grid_h` 列 → 本方案新增列（DictReader 安全）；若按索引读 → 新建 `data/furniture_ext.csv` 用 `furniture_id` join。
- G0.3 若出租屋无独立场景 → **本方案第一步是新增 `home` 场景**（1280×720，与 map-003 的 `residence` 对齐）。
- G0.4 若 `room_furniture_layer` 已按归一化坐标绘制 → 本方案提供 `_norm_to_grid()` 转换，不改渲染层签名。

---

## 1. 架构决策（与主方案的关键分歧）

| 维度 | 现有/主方案 | **本方案** | 理由 |
|---|---|---|---|
| 家具数据模型 | `placed: {slot: fid}` | **`instances: Array[FurnitureInstance]`** | 支持同款多件、自由摆放、无槽位限制 |
| 坐标 | 归一化 0~1 | **网格坐标（格）+ 像素派生** | 可做占用检测、吸附、与 world-001 世界坐标对齐 |
| 占用 | 无 | **占用位图 `OccupancyGrid`** | 门/通道/家具互斥，防重叠 |
| 购买 | `buy()` 直接扣钱 | **`PurchaseSession` 状态机** | 强制经过 NPC/样板间/实物 |
| 收纳 | 无 | **`storage: Array[fid]`** | 未摆放 ≠ 丢失 |
| 房产升级 | `HousingManager.upgrade()` 直接扣钱 | **样板间看房 → 方姐签约** | 与 npc-001 `fangjie` 对齐 |
| 存档 | `manual_positions` 归一化 | **`instances` 数组 + `grid_version`** | 可迁移、可校验 |

**核心原则**：
1. **家具是实例不是槽位**。`furniture_id` 是模板，`instance_id` 是实体。
2. **网格是唯一坐标真相**。像素坐标由 `grid * CELL_SIZE + origin` 派生。
3. **购买必须经过场景实体**。`RoomManager.buy()` 降级为内部 API，UI 不可直调。
4. **收纳与摆放分离**。`owned` 拆为 `storage`（未摆放）+ `instances`（已摆放）。

---

## 2. 数据结构

### 2.1 家具模板（`data/furniture.csv` 扩展列）

```csv
furniture_id,name,category,price,grid_w,grid_h,rotatable,stackable,anchor,energy_bonus,relax_bonus,study_bonus,social_bonus,family_bonus,storage_slots,description
wood_bed,原木单人床,bed,680,2,3,true,false,floor,0.05,0.08,0.0,0.0,0.0,0,睡惯了硬床，腰不酸。
floor_lamp,暖光落地灯,light,180,1,1,false,false,floor,0.0,0.06,0.03,0.0,0.0,0,晚上开着不刺眼。
low_table,矮饭桌,table,320,2,2,true,false,floor,0.0,0.04,0.0,0.06,0.08,0,两个人吃饭刚好。
bookshelf,旧木书架,shelf,420,1,2,true,false,wall,0.0,0.02,0.10,0.0,0.0,6,能塞下不少书。
cat_tower,猫爬架,pet,560,2,2,false,false,floor,0.0,0.05,0.0,0.0,0.0,0,阿灰说猫喜欢高的地方。
```

**列语义**：
- `grid_w/grid_h`：占格数（1 格 = 32px，见 §2.4）。
- `rotatable`：是否允许 90° 旋转（旋转后 `grid_w/grid_h` 互换）。
- `stackable`：是否可叠放（如墙上挂画叠在书架上）。
- `anchor`：`floor` / `wall` / `ceiling`，决定可放置层。
- `*_bonus`：与生活质量/家庭/社交的关联（见 §6）。
- `storage_slots`：该家具自带的收纳格数（书架 6 格）。

### 2.2 家具实例（运行时 + 存档）

```gdscript
# scripts/gameplay/furniture_instance.gd
class_name FurnitureInstance
extends RefCounted

var instance_id: String        # "inst_0007"，全局唯一
var furniture_id: String       # 模板 id
var grid_pos: Vector2i         # 左上角格坐标（房间局部）
var rotation: int              # 0 / 90 / 180 / 270
var layer: int                 # 0=地板 1=墙面 2=天花板
var stored_items: Array[String] = []  # 收纳内容（item_id 列表）
var acquired_from: String      # "npc:fangjie" / "showroom:home_tier2" / "shop:home_store"
var acquired_day: int          # 游戏日，用于"新家具"提示

func get_occupied_cells() -> Array[Vector2i]:
    var w := _effective_w()
    var h := _effective_h()
    var cells: Array[Vector2i] = []
    for dx in w:
        for dy in h:
            cells.append(grid_pos + Vector2i(dx, dy))
    return cells

func _effective_w() -> int:
    var t := FurnitureDB.get_template(furniture_id)
    return t.grid_h if rotation in [90, 270] else t.grid_w

func _effective_h() -> int:
    var t := FurnitureDB.get_template(furniture_id)
    return t.grid_w if rotation in [90, 270] else t.grid_h

func to_dict() -> Dictionary:
    return {
        "instance_id": instance_id,
        "furniture_id": furniture_id,
        "grid_pos": [grid_pos.x, grid_pos.y],
        "rotation": rotation,
        "layer": layer,
        "stored_items": stored_items.duplicate(),
        "acquired_from": acquired_from,
        "acquired_day": acquired_day,
    }

static func from_dict(d: Dictionary) -> FurnitureInstance:
    var inst := FurnitureInstance.new()
    inst.instance_id = str(d.get("instance_id", ""))
    inst.furniture_id = str(d.get("furniture_id", ""))
    var gp: Array = d.get("grid_pos", [0, 0])
    inst.grid_pos = Vector2i(int(gp[0]), int(gp[1]))
    inst.rotation = int(d.get("rotation", 0))
    inst.layer = int(d.get("layer", 0))
    inst.stored_items.assign(d.get("stored_items", []))
    inst.acquired_from = str(d.get("acquired_from", ""))
    inst.acquired_day = int(d.get("acquired_day", 0))
    return inst
```

### 2.3 占用位图（`OccupancyGrid`）

```gdscript
# scripts/gameplay/occupancy_grid.gd
class_name OccupancyGrid
extends RefCounted

const EMPTY := 0
const FURNITURE := 1
const DOOR := 2       # 门/通道，永不可占
const WALL := 3       # 墙，不可占
const RESERVED := 4   # 预留（如宠物活动区）

var width: int
var height: int
var _cells: PackedByteArray
var _owner: Dictionary = {}   # cell_index -> instance_id

func _init(w: int, h: int) -> void:
    width = w
    height = h
    _cells.resize(w * h)
    _cells.fill(EMPTY)

func idx(p: Vector2i) -> int:
    return p.y * width + p.x

func in_bounds(p: Vector2i) -> bool:
    return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height

func get_cell(p: Vector2i) -> int:
    return _cells[idx(p)] if in_bounds(p) else WALL

func can_place(inst: FurnitureInstance) -> bool:
    for c in inst.get_occupied_cells():
        if not in_bounds(c):
            return false
        var v := get_cell(c)
        if v == DOOR or v == WALL or v == RESERVED:
            return false
        if v == FURNITURE and _owner.get(idx(c), "") != inst.instance_id:
            return false
    return true

func place(inst: FurnitureInstance) -> void:
    for c in inst.get_occupied_cells():
        _cells[idx(c)] = FURNITURE
        _owner[idx(c)] = inst.instance_id

func remove(inst: FurnitureInstance) -> void:
    for c in inst.get_occupied_cells():
        if _owner.get(idx(c), "") == inst.instance_id:
            _cells[idx(c)] = EMPTY
            _owner.erase(idx(c))

func rebuild(instances: Array[FurnitureInstance]) -> void:
    _cells.fill(EMPTY)
    _owner.clear()
    for inst in instances:
        place(inst)
```

### 2.4 网格常量

```gdscript
# scripts/gameplay/room_grid.gd
class_name RoomGrid
const CELL_SIZE := 32          # 像素
const ROOM_W := 20             # 格（640px）
const ROOM_H := 14             # 格（448px）
const ORIGIN := Vector2(320, 160)  # 房间左上角在场景中的像素位置

static func grid_to_px(g: Vector2i) -> Vector2:
    return ORIGIN + Vector2(g.x * CELL_SIZE, g.y * CELL_SIZE)

static func px_to_grid(p: Vector2) -> Vector2i:
    return Vector2i(floori((p.x - ORIGIN.x) / CELL_SIZE), floori((p.y - ORIGIN.y) / CELL_SIZE))
```

**与 world-001 对齐**：`ORIGIN` 由 `scene_zones.csv` 的 `home` 矩形左上角派生，不硬编码。

---

## 3. 购买流程：`PurchaseSession` 状态机

### 3.1 核心约束

**禁止** `RoomManager.buy(fid)` 被 UI 直接调用。所有购买必须经过以下三条路径之一：

| 路径 | 触发场景 | 交互 |
|---|---|---|
| **NPC 代购** | 家居超市 NPC（新增 `home_store_clerk`） | 点击 NPC → 对话 → 选家具 → 付款 → 次日送达 |
| **样板间实物** | 房产样板间（`showroom` 场景） | 点击样板间家具 → "这套要吗？" → 付款 → 立即搬入 |
| **实物搬运** | 旧货市场/街边 | 点击实物 → 检查 → 付款 → 玩家"搬"回（有搬运动画） |

### 3.2 状态机

```gdscript
# scripts/gameplay/purchase_session.gd
class_name PurchaseSession
extends RefCounted

enum State { IDLE, BROWSING, INSPECTING, NEGOTIATING, PAYING, DELIVERING, DONE, CANCELLED }

var state: State = State.IDLE
var source_kind: String        # "npc" / "showroom" / "physical"
var source_id: String          # npc_id / showroom_id / interactable_id
var candidate_fid: String
var candidate_price: int
var delivery_day: int          # 送达日（NPC 代购为次日）

func begin(kind: String, id: String) -> void:
    source_kind = kind
    source_id = id
    state = State.BROWSING

func inspect(fid: String) -> void:
    candidate_fid = fid
    candidate_price = FurnitureDB.get_template(fid).price
    state = State.INSPECTING

func confirm() -> bool:
    if state != State.INSPECTING:
        return false
    if not GameState.can_afford(candidate_price):
        NoticeManager.show_message("钱不太够，先攒攒。", "hint", _speaker())
        state = State.BROWSING
        return false
    state = State.PAYING
    return true

func pay() -> bool:
    if state != State.PAYING:
        return false
    if not GameState.spend(candidate_price, _pay_reason()):
        state = State.BROWSING
        return false
    state = State.DELIVERING
    return true

func deliver() -> FurnitureInstance:
    var inst := RoomLayoutManager.create_instance(candidate_fid, source_kind, source_id)
    state = State.DONE
    return inst

func _speaker() -> String:
    match source_kind:
        "npc": return NpcDB.get_name(source_id)
        "showroom": return "样板间"
        _: return ""

func _pay_reason() -> String:
    var nm := FurnitureDB.get_template(candidate_fid).name
    match source_kind:
        "npc": return "在%s那儿订了%s。" % [_speaker(), nm]
        "showroom": return "样板间看中%s，直接搬回来。" % nm
        _: return "把%s搬回家。" % nm
```

### 3.3 场景点击流程（三条路径）

**路径 A：NPC 代购（家居超市）**

```
点击 home_store_clerk
  → 对话："看看要点什么？"（NPC 提示通道）
  → 场景内展示 3~5 件实物（WorldInteractable，非菜单）
  → 点击某件实物 → PurchaseSession.inspect(fid)
  → 实物高亮 + 浮动标签"¥680 · 原木单人床"
  → 再次点击 → confirm() → pay()
  → NPC 提示："明天给你送过去。"（delivery_day = today + 1）
  → 次日 day_started 信号 → deliver() → 家具进 storage
  → 场景提示："门口多了个纸箱。"（场景提示通道）
```

**路径 B：样板间实物（房产升级）**

```
进入 showroom 场景（由 fangjie 带看）
  → 场景内是完整布置的样板间（家具全是 WorldInteractable）
  → 点击任意家具 → "这套 ¥320，要吗？"
  → 确认 → 立即 deliver() 到 storage
  → 点击样板间中央的"签约台" → HousingManager.upgrade() 流程
  → fangjie 提示："租约办好了，家具明天搬。"
```

**路径 C：实物搬运（旧货市场）**

```
点击旧货摊上的实物（如旧木书架）
  → chen 提示："这个 ¥420，有点沉。"
  → 确认 → pay()
  → 玩家进入"搬运"状态（移动速度 ×0.6，持续到回房）
  → 回到 home 场景 → 自动 deliver()
  → 若中途进其他场景 → 家具暂存"门口"（storage）
```

### 3.4 与现有 `RoomManager.buy()` 的兼容

```gdscript
# autoload/room_manager.gd 增量改造
func buy(fid: String) -> bool:
    # 旧 API 保留，但降级为内部调用，UI 不可直调
    push_warning("RoomManager.buy() 已废弃，请走 PurchaseSession")
    return _internal_buy(fid, "legacy", "")

func _internal_buy(fid: String, source_kind: String, source_id: String) -> bool:
    var t := FurnitureDB.get_template(fid)
    if t.is_empty():
        return false
    if not GameState.spend(t.price, "买下%s。" % t.name):
        return false
    RoomLayoutManager.add_to_storage(fid, source_kind, source_id)
    SaveManager.request_auto_save("furniture_buy")
    changed.emit()
    return true
```

---

## 4. 摆放 / 旋转 / 收纳

### 4.1 摆放（网格吸附 + 占用检测）

```gdscript
# autoload/room_layout_manager.gd（新增 autoload）
extends Node

signal layout_changed
signal placement_rejected(reason: String)

var instances: Array[FurnitureInstance] = []
var storage: Array[String] = []          # 未摆放的 furniture_id
var occupancy: OccupancyGrid
var _next_instance_seq := 1

func _ready() -> void:
    occupancy = OccupancyGrid.new(RoomGrid.ROOM_W, RoomGrid.ROOM_H)
    _mark_static_obstacles()

func _mark_static_obstacles() -> void:
    # 门/窗/固定墙从 scene_zones.csv 的 home 矩形派生
    for cell in RoomStaticLayout.get_door_cells():
        occupancy._cells[occupancy.idx(cell)] = OccupancyGrid.DOOR
    for cell in RoomStaticLayout.get_wall_cells():
        occupancy._cells[occupancy.idx(cell)] = OccupancyGrid.WALL

func try_place(instance_id: String, target_grid: Vector2i, rotation: int) -> bool:
    var inst := _find(instance_id)
    if inst == null:
        return false
    var old_pos := inst.grid_pos
    var old_rot := inst.rotation
    occupancy.remove(inst)
    inst.grid_pos = target_grid
    inst.rotation = rotation
    if not occupancy.can_place(inst):
        inst.grid_pos = old_pos
        inst.rotation = old_rot
        occupancy.place(inst)
        placement_rejected.emit("这里放不下，换个位置试试。")
        return false
    occupancy.place(inst)
    layout_changed.emit()
    SaveManager.request_auto_save("furniture_move")
    return true

func rotate_instance(instance_id: String, delta: int = 90) -> bool:
    var inst := _find(instance_id)
    if inst == null:
        return false
    var t := FurnitureDB.get_template(inst.furniture_id)
    if not t.rotatable:
        NoticeManager.show_message("%s转不了方向。" % t.name, "hint")
        return false
    return try_place(instance_id, inst.grid_pos, posmod(inst.rotation + delta, 360))

func add_to_storage(fid: String, source_kind: String, source_id: String) -> void:
    storage.append(fid)
    layout_changed.emit()

func place_from_storage(fid: String, target_grid: Vector2i) -> bool:
    var idx := storage.find(fid)
    if idx < 0:
        return false
    var inst := create_instance(fid, "storage", "")
    inst.grid_pos = target_grid
    if not occupancy.can_place(inst):
        placement_rejected.emit("这里放不下。")
        return false
    storage.remove_at(idx)
    instances.append(inst)
    occupancy.place(inst)
    layout_changed.emit()
    SaveManager.request_auto_save("furniture_place")
    return true

func store_instance(instance_id: String) -> bool:
    var inst := _find(instance_id)
    if inst == null:
        return false
    if not inst.stored_items.is_empty():
        NoticeManager.show_message("先把里面的东西拿出来。", "hint")
        return false
    occupancy.remove(inst)
    instances.erase(inst)
    storage.append(inst.furniture_id)
    layout_changed.emit()
    SaveManager.request_auto_save("furniture_store")
    return true

func create_instance(fid: String, source_kind: String, source_id: String) -> FurnitureInstance:
    var inst := FurnitureInstance.new()
    inst.instance_id = "inst_%04d" % _next_instance_seq
    _next_instance_seq += 1
    inst.furniture_id = fid
    inst.acquired_from = "%s:%s" % [source_kind, source_id] if source_id != "" else source_kind
    inst.acquired_day = CalendarManager.current_day
    return inst

func _find(instance_id: String) -> FurnitureInstance:
    for inst in instances:
        if inst.instance_id == instance_id:
            return inst
    return null
```

### 4.2 场景点击交互（`RoomFurnitureLayer` 扩展）

```gdscript
# scripts/gameplay/room_furniture_layer.gd 增量
func _on_furniture_clicked(instance_id: String, event: InputEvent) -> void:
    if not RoomEditMode.active:
        _show_furniture_info(instance_id)
        return
    var inst := RoomLayoutManager._find(instance_id)
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.double_click:
                RoomLayoutManager.rotate_instance(instance_id, 90)
            else:
                _begin_drag(instance_id)
        elif mb.button_index == MOUSE_BUTTON_RIGHT:
            RoomLayoutManager.store_instance(instance_id)

func _on_drag_released(instance_id: String, screen_pos: Vector2) -> void:
    var grid := RoomGrid.px_to_grid(screen_pos)
    RoomLayoutManager.try_place(instance_id, grid, RoomLayoutManager._find(instance_id).rotation)
```

**手势语义**（与 ui-002 对齐）：

| 手势 | 语义 |
|---|---|
| TAP | 查看家具信息 / 选中 |
| DOUBLE_TAP | 旋转 90° |
| DRAG | 移动（网格吸附） |
| SECONDARY（右键） | 收纳 |
| HOLD | 打开收纳内容（书架等） |

### 4.3 收纳

```gdscript
# 家具自带收纳格
func store_item_in_furniture(instance_id: String, item_id: String) -> bool:
    var inst := RoomLayoutManager._find(instance_id)
    if inst == null:
        return false
    var t := FurnitureDB.get_template(inst.furniture_id)
    if t.storage_slots <= 0:
        return false
    if inst.stored_items.size() >= t.storage_slots:
        NoticeManager.show_message("%s塞满了。" % t.name, "hint")
        return false
    if not InventoryManager.remove_item(item_id, 1):
        return false
    inst.stored_items.append(item_id)
    SaveManager.request_auto_save("furniture_store_item")
    return true
```

---

## 5. 房产升级流程

### 5.1 与 `HousingManager` 的兼容

现有 `HousingManager.upgrade()` 直接扣钱。本方案**不改其签名**，但**新增前置门禁**：

```gdscript
# autoload/housing_manager.gd 增量
var _showroom_visited: Dictionary = {}   # housing_id -> bool

func can_upgrade(housing_id: String) -> bool:
    var row := ConfigDB.get_row("housing", housing_id)
    if row.is_empty():
        return false
    if int(row.get("tier", "0")) != current_tier + 1:
        return false
    # 新增：必须看过样板间
    if not _showroom_visited.get(housing_id, false):
        NoticeManager.show_message("先去样板间看看，方姐带你走一趟。", "hint", "方姐")
        return false
    return true

func mark_showroom_visited(housing_id: String) -> void:
    _showroom_visited[housing_id] = true
    changed.emit()
```

### 5.2 场景点击流程

```
1. 在 residence 场景点击 fangjie
   → fangjie 提示："想换大点的地方？我带你去看看。"
   → 触发 SceneRouter.travel_to("showroom", "housing_tier_2")

2. showroom 场景（样板间，完整布置）
   → 场景内家具全是 WorldInteractable
   → 点击任意家具 → PurchaseSession.begin("showroom", "housing_tier_2")
   → 点击"签约台" → HousingManager.mark_showroom_visited("housing_tier_2")
   → fangjie 提示："看好了就签，租约我帮你办。"

3. 点击签约台 → HousingManager.upgrade("housing_tier_2")
   → 成功 → 场景切换回 home（新户型）
   → 旧家具自动进 storage，玩家重新摆放
```

### 5.3 户型与网格尺寸

```csv
# data/housing.csv 扩展列
housing_id,tier,name,price,rent,grid_w,grid_h,energy_bonus,study_bonus,relax_bonus,description
rental_single,0,城中村单间,0,800,20,14,0.0,0.0,0.0,一张床一张桌，够住。
rental_one_bed,1,一室一厅,12000,1200,28,18,0.03,0.02,0.05,多了个客厅，能请人坐坐。
rental_two_bed,2,两室一厅,38000,2000,36,22,0.05,0.06,0.08,有独立书房，家里人来也住得下。
```

**升级时**：`RoomLayoutManager.resize(new_w, new_h)` 重建 `OccupancyGrid`，超出新边界的家具自动进 storage。

---

## 6. 与生活质量 / 家庭 / 社交的关联

### 6.1 生活质量（`QualityOfLife`）

**不新增数值条**。生活质量是**派生量**，由家具 bonus 累加：

```gdscript
# autoload/quality_of_life.gd（新增）
extends Node

func get_room_bonus(bonus_type: String) -> float:
    var total := 0.0
    for inst in RoomLayoutManager.instances:
        var t := FurnitureDB.get_template(inst.furniture_id)
        total += t.get_bonus(bonus_type)
    # 装修风格加成
    total += RenovationManager.get_bonus(bonus_type)
    # 房产加成
    total += HousingManager.get_bonus(bonus_type)
    return total

func get_rest_quality() -> float:
    return 1.0 + get_room_bonus("relax") + get_room_bonus("energy")

func get_study_quality() -> float:
    return 1.0 + get_room_bonus("study")
```

**消费点**：
- `PlayerActor.rest()` 的体力恢复 = `base * get_rest_quality()`。
- `StudyManager` 的学习效率 = `base * get_study_quality()`。

### 6.2 家庭（`Family`）

**触发条件**：`family_bonus` 累计 ≥ 阈值，且 `home` 场景有 `low_table` + `sofa`。

```gdscript
func can_invite_family() -> bool:
    return QualityOfLife.get_room_bonus("family") >= 0.10 \
        and RoomLayoutManager.has_furniture("low_table") \
        and RoomLayoutManager.has_furniture("sofa")

func invite_family() -> void:
    # 触发家庭聚餐事件，li_ma / 家人 NPC 到访
    # 场景提示："家里今天热闹。"
    # 效果：次日体力上限 +10%，持续 3 天
```

### 6.3 社交（`Social`）

**触发条件**：`social_bonus` 累计 ≥ 阈值，且 `home` 场景有 `low_table` + 椅子 ≥ 2。

```gdscript
func can_host_friends() -> bool:
    return QualityOfLife.get_room_bonus("social") >= 0.08 \
        and RoomLayoutManager.count_by_category("chair") >= 2

func host_friends(npc_ids: Array[String]) -> void:
    # 邀请 NPC 到 home，触发对话
    # 效果：每个 NPC affinity +2
```

### 6.4 关联表

| 家具类别 | energy | relax | study | social | family |
|---|---|---|---|---|---|
| bed | +0.05 | +0.08 | — | — | — |
| light | — | +0.06 | +0.03 | — | — |
| table | — | +0.04 | — | +0.06 | +0.08 |
| shelf | — | +0.02 | +0.10 | — | — |
| plant | — | +0.05 | — | — | — |
| appliance | +0.03 | +0.02 | — | — | — |
| pet | — | +0.05 | — | — | — |
| sofa | — | +0.06 | — | +0.08 | +0.06 |
| chair | — | — | — | +0.03 | +0.02 |

---

## 7. 存档字段

### 7.1 新增字段（`GameState` / `SaveManager`）

```gdscript
# autoload/save_manager.gd 增量
func _collect_save_data() -> Dictionary:
    var data := {}
    # ... 现有字段 ...
    data["room_layout"] = RoomLayoutManager.get_save_data()
    data["housing"] = HousingManager.get_save_data()
    data["renovation"] = RenovationManager.get_save_data()
    data["grid_version"] = 2   # 新增：网格版本，用于迁移
    return data
```

### 7.2 `RoomLayoutManager` 存档结构

```gdscript
func get_save_data() -> Dictionary:
    return {
        "instances": instances.map(func(i): return i.to_dict()),
        "storage": storage.duplicate(),
        "next_seq": _next_instance_seq,
        "grid_w": occupancy.width,
        "grid_h": occupancy.height,
    }

func restore(data: Dictionary) -> void:
    instances.clear()
    storage.clear()
    _next_instance_seq = int(data.get("next_seq", 1))
    var w := int(data.get("grid_w", RoomGrid.ROOM_W))
    var h := int(data.get("grid_h", RoomGrid.ROOM_H))
    occupancy = OccupancyGrid.new(w, h)
    _mark_static_obstacles()
    for d in data.get("instances", []):
        var inst := FurnitureInstance.from_dict(d)
        instances.append(inst)
        occupancy.place(inst)
    storage.assign(data.get("storage", []))
    layout_changed.emit()
```

### 7.3 迁移（旧存档 → 新结构）

```gdscript
# scripts/migration/room_layout_v1_to_v2.gd
static func migrate(old: Dictionary) -> Dictionary:
    # 旧结构：placed: {slot: fid}, manual_positions: {fid: [x,y]}, manual_rotations: {fid: deg}
    var instances: Array = []
    var seq := 1
    var placed: Dictionary = old.get("placed", {})
    var positions: Dictionary = old.get("manual_positions", {})
    var rotations: Dictionary = old.get("manual_rotations", {})
    for slot_id in placed:
        var fid := str(placed[slot_id])
        var norm: Array = positions.get(fid, [0.5, 0.5])
        var grid := Vector2i(
            clampi(int(float(norm[0]) * RoomGrid.ROOM_W), 0, RoomGrid.ROOM_W - 1),
            clampi(int(float(norm[1]) * RoomGrid.ROOM_H), 0, RoomGrid.ROOM_H - 1)
        )
        instances.append({
            "instance_id": "inst_%04d" % seq,
            "furniture_id": fid,
            "grid_pos": [grid.x, grid.y],
            "rotation": int(rotations.get(fid, 0)),
            "layer": 0,
            "stored_items": [],
            "acquired_from": "migrated",
            "acquired_day": 0,
        })
        seq += 1
    return {
        "instances": instances,
        "storage": [],
        "next_seq": seq,
        "grid_w": RoomGrid.ROOM_W,
        "grid_h": RoomGrid.ROOM_H,
    }
```

**迁移触发**：`SaveManager._load_failed` 或 `grid_version < 2` 时调用。

---

## 8. 迁移步骤（从现有 `room_manager` 到本方案）

| 阶段 | 动作 | 可回退 |
|---|---|---|
| **M0** | 跑 G0 门禁，写 `docs/ROOM_FACTS.md` | — |
| **M1** | 新增 `FurnitureDB` / `OccupancyGrid` / `RoomGrid` / `FurnitureInstance`，**不改现有代码** | 删文件即可 |
| **M2** | 新增 `RoomLayoutManager` autoload，与 `RoomManager` 并存 | 从 `project.godot` 移除 autoload |
| **M3** | `RoomManager` 旧 API 改为转发到 `RoomLayoutManager` | 恢复旧实现 |
| **M4** | `room_furniture_layer` 

## 批判

## 批判A（qa_lead）

# 批判报告：两份方案的遗漏、冲突、死代码、不可触达机制、存档风险与测试漏洞

> 结论先行：**两份方案都不能直接开工**。主方案在"网格/存档/购买"上看似闭环，但存在**不可触达的购买路径、坐标系自相矛盾、存档字段类型冲突、装修链路空转**；独立方案在**架构上更干净**，但**迁移面被严重低估**，且**购买状态机与现有 `GameState.spend` 契约冲突**、**样板间/旧货市场场景不存在**、**`QualityOfLife` 与硬约束"无数值属性条"边界模糊**。下面逐条给出可执行的返工要求。

---

## 一、主方案（唯一可执行方案）的致命问题

### P0-1 购买路径 A/B/C 全部依赖不存在的场景，且门禁未验证就写进"唯一可执行"

**问题**：
- §3.1 假设 `commercial_district` 有 `furniture_shop` 子区；§3.2 假设样板间存在；§3.3 假设 `market` 有旧货摊。
- §7 风险表自己承认 `furniture_shop` 可能不存在（P0），但 §3 已经把它当作既定事实写流程。
- G0.4 只 grep 了 `room_furniture_layer` 和 `current_area == "home"`，**没有验证 `commercial_district` / `market` / `furniture_shop` 是否存在**。

**返工要求**：
1. G0.4 必须追加：
   ```bash
   grep -rn "commercial_district\|furniture_shop\|market\|旧货\|样板间\|showroom" --include=*.gd --include=*.csv scripts/ data/ autoload/
   ls data/scene_zones.csv && grep -n "home\|market\|commercial\|showroom" data/scene_zones.csv
   ```
2. 若 `furniture_shop` / `showroom` / 旧货摊任一不存在，**§3 三条路径全部标记为"待建场景"**，不得写"流程"。
3. 若 `market` 存在但无旧货摊，路径 C 必须降级为"待建"或删除，**不允许保留一个不可触达的购买路径**。

---

### P0-2 坐标系自相矛盾：归一化 vs 网格 vs 像素，三套并存且互相污染

**问题**：
- §2.1 定义 `16px × 16px` 网格，房间 `1280×720` → `80×45` 格。
- §2.1 又说 `manual_positions` 存归一化坐标，吸附到网格中心。
- §2.4 `SLOT_DEFAULT_GRID` 用 `Vector2i(18,15)` 等网格坐标，但 `get_default_slot_position` 返回归一化。
- §4.3 房产升级时房间尺寸变化（`1280×720` → `1600×900` → ...），但 §2.1 的 `80×45` 是**硬编码**，升级后网格数变了，`SLOT_DEFAULT_GRID` 的 `Vector2i(18,15)` 语义就变了。
- §2.1 说 `nudge_furniture` 的 `delta` 量化到 `1/80` 和 `1/45`，但升级后是 `1/100` 和 `1/56`，**量化分母写死了**。

**返工要求**：
1. **唯一坐标真相必须是网格坐标**（`Vector2i`），归一化只作为**渲染派生量**，不存存档。
2. `manual_positions` 改为 `{fid: {"gx": int, "gy": int}}`，**不存归一化**。
3. `SLOT_DEFAULT_GRID` 改为**按 tier 分档**：
   ```gdscript
   const SLOT_DEFAULT_GRID := {
       0: {"bed": Vector2i(18,15), ...},
       1: {"bed": Vector2i(22,18), ...},
       ...
   }
   ```
   或改为**相对锚点**（如 `bed` 靠左墙 1/4 处），由 `HousingManager.get_room_grid_size()` 派生。
4. `nudge_furniture` 的量化改为 `1` 格，**不写分母**。
5. §2.1 的 `80×45` 必须从 `HousingManager.get_room_grid_size()` 读取，**禁止字面量**。

---

### P0-3 存档字段类型冲突：`owned` 从 `bool` 变 `Dictionary`，但 `placed` 仍是 `{slot: fid}`，两者语义不一致

**问题**：
- §5.1 `owned[fid] = {"owned": true, "condition": "new"}`，但 `placed` 仍是 `{slot_id: fid}`。
- §3.3 旧货家具带 `condition = "worn"`，但 `placed` 里只有 `fid`，**丢失了 condition**。同一 `fid` 买了两件（一件新一件旧），`placed` 无法区分。
- §2.3 `can_place_at` 遍历 `placed` 时用 `placed[slot_id]` 取 `fid`，再 `get_grid_position(other_fid)`，**同一 fid 多件时 `get_grid_position` 返回哪个？**
- §5.2 `restore` 里 `placed = data.get("placed", {}).duplicate()`，**没有做 v1→v2 的 `placed` 迁移**（v1 的 `placed` 是 `{slot: fid}`，v2 应该是什么？方案没说）。

**返工要求**：
1. **`placed` 必须改为 `{instance_id: {"fid": str, "gx": int, "gy": int, "rot": int, "condition": str}}`**，与 `owned` 解耦。
2. 或者**彻底放弃 `placed`**，改为 `instances: Array[Dictionary]`（独立方案的做法），`owned` 只记"拥有过"。
3. §5.2 `restore` 必须补 `placed` 的 v1→v2 迁移：
   ```gdscript
   if version < 2:
       var old_placed: Dictionary = data.get("placed", {})
       var new_placed := {}
       for slot_id in old_placed:
           var fid := str(old_placed[slot_id])
           var pos := manual_positions.get(fid, Vector2(0.5, 0.5))
           var gx := int(floor(pos.x * ROOM_GRID_W))
           var gy := int(floor(pos.y * ROOM_GRID_H))
           var iid := "inst_%s_%s" % [fid, slot_id]
           new_placed[iid] = {"fid": fid, "gx": gx, "gy": gy, "rot": 0, "condition": "new"}
       placed = new_placed
   ```
4. §8.1 `test_save_roundtrip` 必须加断言：**同一 fid 两件（新/旧）roundtrip 后 condition 不丢失**。

---

### P0-4 装修链路空转：`renovations.csv` 的 bonus 被"改为可见反馈"，但 `HousingManager.get_bonus()` 仍读它

**问题**：
- §4.2 说 `renovations.csv` 的 `energy_bonus` / `relax_bonus` / `study_bonus` / `food_bonus` **不直接加到数值条**，改为可见反馈。
- §6.1 又说"体力恢复：`HousingManager.get_bonus("energy")` 仍影响 `PlayerActor` 的体力恢复速率（已有机制）"。
- **这两句直接冲突**：如果 `get_bonus("energy")` 仍被 `PlayerActor` 读取，那 bonus 就是**数值加成**，不是"仅可见反馈"。
- §6.1 的表格里 `warm_walls` / `bright_window` / `quiet_study` / `family_room` 是**装修 id**，但 §4.2 说 `renovation_style` 是**字符串**，`installed_decor` 是 `{renovation_id: true}`。**`renovation_style` 和 `installed_decor` 的关系没定义**。

**返工要求**：
1. **明确二选一**：
   - **A. 装修只做视觉**：`HousingManager.get_bonus()` **不读** `renovations.csv`，`PlayerActor` 体力恢复只读 `housing_tier` 的固定值。`renovations.csv` 的 bonus 列**删除**或标记为"仅用于场景反馈强度"。
   - **B. 装修做数值**：承认违反"无数值属性条"，但**不新增 UI**，只在 `PlayerActor` 内部乘算。此时 §6.1 的"不直接加到数值条"改为"不新增 UI 数值条"。
2. **定义 `renovation_style` 与 `installed_decor` 的关系**：
   - `renovation_style` 是**当前生效的风格 id**（单选），`installed_decor` 是**已购买的装修项集合**（多选）。
   - 或 `renovation_style` 废弃，只用 `installed_decor`。
3. §8.2 场景测试"装修 → 灯光色温变化"必须给出**可验证断言**：`room_furniture_layer.modulate == Color("#FFE8C8")`，而不是"色温变化"。

---

### P0-5 `allow_overlap` 的碰撞逻辑有死代码和逻辑漏洞

**问题**：
```gdscript
if self_overlap and other_overlap:
    continue  # 地毯叠地毯允许
if self_overlap or other_overlap:
    continue  # 地毯可与家具重叠
```
- 第二个 `if` 覆盖了第一个 `if` 的所有情况（`self_overlap and other_overlap` 时，`self_overlap or other_overlap` 也为真）。**第一个 `if` 是死代码**。
- 更严重：`self_overlap or other_overlap` 时 `continue`，意味着**地毯可以叠在任何家具上，任何家具也可以叠在地毯上**。但"床叠在地毯上"和"地毯叠在床上"语义不同——**谁在上层？** 渲染顺序没定义。
- `allow_overlap=true` 的家具（地毯）**不参与碰撞**，但 §2.3 的 `can_place_at` 里 `self_overlap` 为 true 时直接 `continue`，**地毯可以放在门/墙/边界外**（边界检查在 `continue` 之前，但门/墙检查根本没有）。

**返工要求**：
1. 删除第一个 `if`（死代码）。
2. 明确**层级模型**：`layer` 字段（0=地板 1=家具 2=墙面 3=天花板），碰撞只在**同层**做。地毯是 `layer=0`，床是 `layer=1`，**不同层不碰撞**。
3. `can_place_at` 必须加**静态障碍检查**（门/墙/窗），不能只查家具。
4. §8.1 `test_rug_overlap` 改为 `test_layer_no_collision`：地毯（layer=0）与床（layer=1）同格不碰撞；两件 layer=1 家具同格碰撞。

---

### P0-6 `migrate_layout` 的算法在"家具越界"时行为未定义

**问题**：
- §4.3 说"超出新边界的家具自动收纳"，但 `migrate_layout` 只做坐标映射，**没有越界检查**。
- 映射后 `new_grid` 可能为负或超出 `new_w/new_h`，`manual_positions` 仍写入，**下次 `can_place_at` 才失败**，但家具已经在 `placed` 里了。
- §4.3 说"升级后已摆放家具保留"，但 §4.3 又说"超出新边界的家具自动收纳"，**两句冲突**。

**返工要求**：
1. `migrate_layout` 必须**先映射，再检查边界，越界则 `unplace` 并加入 `storage`**：
   ```gdscript
   func migrate_layout(old_w, old_h, new_w, new_h) -> void:
       var to_store: Array[String] = []
       for iid in placed.keys():
           var p = placed[iid]
           var new_gx = int(round(float(p.gx) / old_w * new_w))
           var new_gy = int(round(float(p.gy) / old_h * new_h))
           var occ = get_occupancy(p.fid, Vector2i(new_gx, new_gy), p.rot)
           if occ.position.x < 0 or occ.position.y < 0 or occ.end.x > new_w or occ.end.y > new_h:
               to_store.append(iid)
           else:
               p.gx = new_gx; p.gy = new_gy
       for iid in to_store:
           unplace(iid)
   ```
2. §4.3 的"已摆放家具保留"改为"**在边界内的保留，越界的自动收纳**"。
3. §8.1 `test_grid_migration` 必须加**越界用例**：80×45 右下角的床，升级到 100×56 后仍在边界内；升级到 60×40（缩小）后进 storage。

---

### P1-1 `social_tag` 新增列与 G0.2 的裁决冲突

**问题**：
- §6.3 说 `social_tag` 写入 `data/furniture.csv` 新增列。
- §0 G0.2 裁决："若按索引 → 禁止新增列，新建 `data/furniture_grid.csv` 用 `furniture_id` join"。
- §7.2 修改文件表又说"新增 `social_tag` 列（若 G0.2 允许）"。
- **门禁未跑，就写了"新增列"的修改计划**。

**返工要求**：
1. `social_tag` 必须**独立成表** `data/furniture_social.csv`（`furniture_id, social_tag`），与 `furniture_grid.csv` 同模式。
2. 或明确：G0.2 跑完后，若 `ConfigDB.get_row` 按列名取值，才允许新增列；否则独立表。**不允许在门禁前写"新增列"**。

---

### P1-2 `NoticeManager` 的 `source_kind` 契约未验证

**问题**：
- §3.1 说"导购 NPC 台词走 `NoticeManager`，`source_kind = "npc"`，`speaker = "方姐"`"。
- §6.2 说"访客 NPC 在沙发区域停留时，`NoticeManager` 推送台词（`source_kind = "npc"`）"。
- **`NoticeManager` 是否有 `source_kind` 参数？`speaker` 是参数还是字段？** 门禁没查。

**返工要求**：
1. G0.6 追加：
   ```bash
   grep -n "^func \|^signal \|^var \|^const " autoload/notice_manager.gd
   grep -rn "NoticeManager.show_message\|NoticeManager.push" --include=*.gd scripts/ | head -20
   ```
2. 若 `NoticeManager` 无 `source_kind`，**本方案不得假设**，必须先扩展 `NoticeManager` 或改用现有通道。

---

### P1-3 收纳柜是"场景实物"但渲染在 `room_furniture_layer`，与编辑模式手势冲突

**问题**：
- §3.5 说"收纳柜是场景实物，不是 UI 面板"，"收纳列表用 `room_furniture_layer` 渲染在柜子旁边"。
- §3.4 编辑模式下 `TAP` 家具 = 选中，`TAP` 空地 = 移动。**收纳柜也是家具吗？点击收纳柜是"选中"还是"打开列表"？**
- §3.4 `SECONDARY` = 取消选中/收纳，§3.5 `SECONDARY` 点击家具 = 收纳。**同一手势两种语义**。

**返工要求**：
1. 明确**收纳柜是 `WorldInteractable` 不是 `FurnitureInstance`**，点击走独立 handler，不参与编辑模式选中。
2. `SECONDARY` 语义统一：**编辑模式下 = 收纳；非编辑模式下 = 查看信息**。
3. §8.2 场景测试"收纳"必须区分：右键家具（收纳）vs 右键收纳柜（打开列表）。

---

### P1-4 `test_buy_no_auto_place` 的断言不完整

**问题**：
- §8.1 `test_buy_no_auto_place`：`buy(fid)` 后 `is_placed(fid)` 返回 false。
- 但 §3.1 说 `buy()` 里的 `auto_place` 必须删除。**如果 `buy()` 被删除或改名，测试调什么？**
- 且 §3.1 说购买必须通过 NPC/样板间/实物，**`buy()` 本身应该被废弃**，测试应该测 `PurchaseSession.confirm() → pay() → deliver()` 后 `is_placed` 为 false。

**返工要求**：
1. `test_buy_no_auto_place` 改为 `test_purchase_session_no_auto_place`：
   ```gdscript
   var session = PurchaseSession.new()
   session.begin("npc", "fangjie")
   session.inspect("bed_single")
   assert_true(session.confirm())
   assert_true(session.pay())
   var inst = session.deliver()
   assert_false(RoomManager.is_placed(inst.instance_id))
   assert_true(RoomManager.is_owned("bed_single"))
   ```
2. 若 `buy()` 保留为内部 API，加断言 `buy()` 被调用时 `push_warning` 触发。

---

## 二、独立方案的致命问题

### P0-7 迁移面被严重低估：`RoomManager` 调用点未验证就宣称"兼容迁移"

**问题**：
- §0 G0.1 说"若调用点 > 20 处 → 保留 `RoomManager` 旧 API 作薄适配层"。
- 但 §8 迁移步骤 M3 说"`RoomManager` 旧 API 改为转发到 `RoomLayoutManager`"，**没有说调用点有多少**。
- §1 说"与现有 `room_manager` 做兼容迁移而非重写"，但 §2.2 的 `FurnitureInstance` 和 §2.3 的 `OccupancyGrid` 是**全新数据结构**，`RoomManager` 的 `placed: {slot: fid}` 和 `manual_positions: {fid: Vector2}` **无法无损映射**到 `instances: Array[FurnitureInstance]`。
- §7.3 的 `migrate` 把 `placed` 的每个 slot 转成一个 instance，但**丢失了 `layouts`（多套搭配）**。主方案 §5.1 明确保留 `layouts`，独立方案**完全没提 `layouts`**。

**返工要求**：
1. G0.1 必须**先跑**，输出调用点数量和分布，写入 `docs/ROOM_FACTS.md`。
2. 若调用点 > 20，**M3 必须分阶段**：先双写（`RoomManager` 和 `RoomLayoutManager` 同时更新），再切读，最后删旧。
3. `layouts` 必须迁移：`layouts: {name: {slot: fid}}` → `layouts: {name: Array[instance_dict]}`。§7.3 的 `migrate` 必须补 `layouts` 处理。
4. §8 迁移步骤必须加**回滚验证**：M3 后跑 `test_room_manager_compat`，断言旧 API 返回值与新 API 一致。

---

### P0-8 `PurchaseSession` 与 `GameState.spend` 契约冲突

**问题**：
- §3.2 `pay()` 调 `GameState.spend(candidate_price, _pay_reason())`。
- §3.4 `_internal_buy` 也调 `GameState.spend(t.price, ...)`。
- **`GameState.spend` 的签名是什么？** 第二个参数是 reason 还是别的？门禁没查。
- §3.2 `confirm()` 调 `GameState.can_afford(candidate_price)`，**`can_afford` 是否存在？**
- §3.2 `deliver()` 调 `RoomLayoutManager.create_instance(candidate_fid, source_kind, source_id)`，但 `create_instance` 在 §4.1 定义，**`deliver()` 时家具还没进 `storage`**，`create_instance` 创建的 instance 直接进 `instances` 还是 `storage`？§3.2 说"家具进 storage"，但 `create_instance` 返回 `FurnitureInstance`，**没有 `add_to_storage` 调用**。

**返工要求**：
1. G0.6 追加：
   ```bash
   grep -n "func spend\|func can_afford\|func add_money" autoload/game_state.gd
   ```
2. `deliver()` 必须明确：
   ```gdscript
   func deliver() -> FurnitureInstance:
       var inst := RoomLayoutManager.create_instance(candidate_fid, source_kind, source_id)
       RoomLayoutManager.add_to_storage(inst)  # 或 instances.append
       state = State.DONE
       return inst
   ```
3. §3.2 `confirm()` 的 `can_afford` 若不存在，改用 `GameState.money >= candidate_price`。
4. §8.2 场景测试"家居超市购买"必须断言**钱扣了、家具在 storage、不在 instances**。

---

### P0-9 样板间/旧货市场场景不存在，且 `SceneRouter.travel_to` 未验证

**问题**：
- §5.2 说 `SceneRouter.travel_to("showroom", "housing_tier_2")`。
- **`SceneRouter` 是否存在？`travel_to` 签名是什么？`showroom` 场景是否存在？**
- §3.3 路径 C 说"玩家进入搬运状态，移动速度 ×0.6"，**`PlayerActor` 是否有 `speed_multiplier`？**
- §3.3 说"若中途进其他场景 → 家具暂存门口（storage）"，**"门口"是什么？`storage` 是全局的还是 per-scene 的？**

**返工要求**：
1. G0.3 追加：
   ```bash
   grep -rn "SceneRouter\|travel_to\|change_scene" --include=*.gd autoload/ scripts/ | head -20
   grep -rn "speed_multiplier\|move_speed" --include=*.gd scripts/player* autoload/
   ```
2. 若 `showroom` 场景不存在，§5.2 必须标记为"待建场景"，不得写"流程"。
3. 搬运状态的 `speed_multiplier` 若不存在，必须先扩展 `PlayerActor` 或删除该机制。
4. `storage` 必须是**全局单例**（`RoomLayoutManager.storage`），不随场景切换丢失。

---

### P0-10 `QualityOfLife` 与硬约束"无数值属性条"边界模糊

**问题**：
- §6.1 `QualityOfLife.get_room_bonus("relax")` 返回 float，`get_rest_quality()` 返回 `1.0 + bonus`。
- §6.1 说"不新增数值条"，但 `get_rest_quality()` 是**数值**，被 `PlayerActor.rest()` 乘算。
- **"无数值属性条"是指"不新增 UI 数值条"还是"不新增数值机制"？** 方案没定义。
- §6.2 `can_invite_family()` 用 `family_bonus >= 0.10`，**0.10 是硬编码阈值**，违反"数据表唯一事实源"。
- §6.3 `can_host_friends()` 用 `social_bonus >= 0.08`，同样硬编码。

**返工要求**：
1. 明确"无数值属性条"= **不新增 UI 数值条**，允许内部数值乘算。写入 `docs/ROOM_FACTS.md`。
2. 阈值 `0.10` / `0.08` 必须写入 `data/housing.csv` 或 `data/furniture.csv` 的列（如 `family_threshold` / `social_threshold`），**禁止硬编码**。
3. §6.1 `get_rest_quality()` 的消费点 `PlayerActor.rest()` 必须验证存在：
   ```bash
   grep -n "func rest\|rest_quality\|energy_recover" scripts/player* autoload/
   ```
4. §8 必须加测试 `test_quality_of_life_threshold`：`family_bonus = 0.09` 时 `can_invite_family()` 为 false，`0.10` 时为 true。

---

### P1-5 `OccupancyGrid.can_place` 的 `_owner` 检查有漏洞

**问题**：
```gdscript
if v == FURNITURE and _owner.get(idx(c), "") != inst.instance_id:
    return false
```
- 如果 `inst` 已经在 grid 上（移动场景），`_owner` 是 `inst.instance_id`，**不会返回 false**，正确。
- 但 §4.1 `try_place` 先 `occupancy.remove(inst)` 再 `can_place`，**此时 `_owner` 已清空**，`can_place` 的 `_owner` 检查永远为真（因为 `v` 不会是 `FURNITURE`，除非有其他家具）。**逻辑冗余但不算 bug**。
- 真正的问题：`can_place` **不检查 `inst` 自身是否越界**（`in_bounds` 检查了，但 `get_occupied_cells` 可能返回负坐标，`in_bounds` 返回 false，正确）。
- **`can_place` 不检查 `layer`**。§2.2 有 `layer` 字段，但 `OccupancyGrid` 是**单层位图**，无法表达"地毯和床同格不碰撞"。

**返工要求**：
1. `OccupancyGrid` 改为**多层位图**：`_cells: Array[PackedByteArray]`，按 `layer` 索引。
2. `can_place` 只检查**同层**：
   ```gdscript
   func can_place(inst: FurnitureInstance) -> bool:
       var layer_cells := _cells[inst.layer]
       for c in inst.get_occupied_cells():
           if not in_bounds(c): return false
           var v := layer_cells[idx(c)]
           if v == DOOR or v == WALL or v == RESERVED: return false
           if v == FURNITURE and _owner.get(idx(c), "") != inst.instance_id: return false
       return true
   ```
3. §8 加测试 `test_layer_isolation`：地毯（layer=0）和床（layer=1）同格 `can_place` 都为 true。

---

### P1-6 `store_instance` 的 `stored_items` 检查与"收纳"语义冲突

**问题**：
- §4.1 `store_instance` 说"若 `stored_items` 非空，提示先拿出来"。
- 但 §4.3 `store_item_in_furniture` 把 item 存进家具。**收纳家具时，里面的东西怎么办？**
- 如果强制先拿出来，**用户体验差**（书架 6 格，收纳前要手动清空）。
- 如果自动转移，**转移到哪？** `InventoryManager` 可能满。

**返工要求**：
1. 明确二选一：
   - **A. 强制清空**：`store_instance` 返回 false，提示"先把书架上的书收起来"。
   - **B. 自动转移**：`store_instance` 把 `stored_items` 转移到 `InventoryManager`，若满则拒绝收纳。
2. §8 加测试 `test_store_with_items`：书架有 3 本书时收纳，断言 A 拒绝 / B 书进 inventory。

---

### P1-7 迁移脚本 `room_layout_v1_to_v2.gd` 丢失 `layouts` 和 `installed_decor`

**问题**：
- §7.3 `migrate` 只处理 `placed` / `manual_positions` / `manual_rotations`。
- **`layouts`（多套搭配）完全丢失**。
- **`installed_decor` / `renovation_style` 完全丢失**。
- **`owned`（已购买未摆放）完全丢失**——旧档 `owned[fid] = true` 的家具，迁移后既不在 `instances` 也不在 `storage`，**玩家丢家具**。

**返工要求**：
1. `migrate` 必须补：
   ```gdscript
   # owned → storage
   var owned: Dictionary = old.get("owned", {})
   var placed_fids := {}
   for slot_id in placed:
       placed_fids[str(placed[slot_id])] = true
   for fid in owned:
       if not placed_fids.has(fid):
           storage.append(fid)
   # layouts → 保留为 {name: Array[instance_dict]}
   var layouts: Dictionary = old.get("layouts", {})
   var new_layouts := {}
   for name in layouts:
       new_layouts[name] = _migrate_layout_dict(layouts[name])
   # installed_decor / renovation_style 原样保留
   ```
2. §8 加测试 `test_migration_no_data_loss`：旧档有 `owned` / `layouts` / `installed_decor`，迁移后全部保留。

---

### P1-8 `RoomGrid.ORIGIN` 硬编码 `Vector2(320, 160)`

**问题**：
- §2.4 说 `ORIGIN` 由 `scene_zones.csv` 的 `home` 矩形左上角派生，不硬编码。
- 但代码里 `const ORIGIN := Vector2(320, 160)` **就是硬编码**。
- **`scene_zones.csv` 是否存在？`home` 矩形是否存在？** 门禁没查。

**返工要求**：
1. G0.3 追加：
   ```bash
   ls data/scene_zones.csv && grep -n "home\|residence" data/scene_zones.csv
   ```
2. `ORIGIN` 改为运行时从 `SceneZoneDB.get_rect("home")` 读取，**禁止 const**。
3. §8 加测试 `test_origin_from_zone`：`scene_zones.csv` 改 `home` 矩形后，`RoomGrid.ORIGIN` 同步变化。

---

## 三、两份方案共有的问题

### P0-11 门禁未跑，两份方案都写了"唯一事实源"和"执行步骤"

**问题**：
- 主方案 §0 说"本方案在门禁未通过前不得写任何业务代码"，但 §7.3 已经写了 9 步执行步骤。
- 独立方案 §0 说"未过不得写业务代码"，但 §8 已经写了 M0~M4 迁移步骤。
- **门禁结果 `docs/ROOM_FACTS.md` 不存在，两份方案都假设了门禁结果**（如 `furniture.csv` 有 `category` 列、`RoomManager` 有 `get_save_data`）。

**返工要求**：
1. **先跑门禁，写 `docs/ROOM_FACTS.md`，再评审方案**。
2. 门禁结果必须包含**每个假设的验证结论**（存在/不存在/类型/签名）。
3. 方案中的"执行步骤"必须**引用 `docs/ROOM_FACTS.md` 的具体行**，不得凭空假设。

---

### P0-12 两份方案都没有"购买失败"的回滚路径

**问题**：
- 主方案 §3.1 购买流程：点击 → 信息卡 → 请导购 → 确认 → `buy()` → 扣钱 → `owned`。
- **如果 `buy()` 扣钱成功但 `owned` 写入失败（存档 IO 错误）？**
- **如果 `buy()` 扣钱成功但家具 id 不存在？**
- 独立方案 §3.2 `pay()` 扣钱成功，`deliver()` 创建 instance 失败（`FurnitureDB.get_template` 返回空）？**钱扣了，家具没到**。

**返工要求**：
1. 购买必须**事务化**：
   ```gdscript
   func pay_and_deliver() -> bool:
       var t := FurnitureDB.get_template(candidate_fid)
       if t.is_empty():
           NoticeManager.show_message("这件暂时没货。", "hint")
           return false
       if not GameState.spend(candidate_price, _pay_reason()):
           return false
       var inst := RoomLayoutManager.create_instance(candidate_fid, source_kind, source_id)
       if inst == null:
           GameState.refund(candidate_price, "购买失败，钱退给你。")
           return false
       RoomLayoutManager.add_to_storage(inst)
       return true
   ```
2. §8 加测试 `test_purchase_rollback`：`FurnitureDB.get_template` 返回空时，钱不扣。

---

### P1-9 两份方案都没有"家具 id 不存在"的防御

**问题**：
- 主方案 §2.3 `get_occupancy` 调 `ConfigDB.get_row("furniture_grid", fid)`，**若 fid 不在表里，`row` 为空，`int(row.get("grid_w", "1"))` 返回 1**，家具变成 1×1，**静默错误**。
- 独立方案 §2.2 `_effective_w` 调 `FurnitureDB.get_template(furniture_id)`，**若返回空，`t.grid_h` 报错**。

**返工要求**：
1. `get_occupancy` / `_effective_w` 必须**先检查 fid 存在**，不存在则 `push_error` 并返回安全默认值（1×1）。
2. §8 加测试 `test_unknown_furniture_id`：`get_occupancy("nonexistent", ...)` 返回 1×1 且 `push_error` 触发。

---

### P1-10 两份方案都没有"存档版本降级"处理

**问题**：
- 主方案 §5.2 `restore` 处理 `version < 2` 的迁移。
- **如果玩家用 v2 存档，回退到 v1 客户端？** `schema_version = 2` 被 v1 客户端读取，**v1 不认识 `owned[fid] = {"owned": true}`，会当成 `true` 吗？**
- 独立方案 §7.1 `grid_version = 2`，同样问题。

**返工要求**：
1. `restore` 必须处理 `version > CURRENT_VERSION`：
   ```gdscript
   if version > CURRENT_SCHEMA_VERSION:
       push_error("存档版本 %d 高于客户端 %d，拒绝加载" % [version, CURRENT_SCHEMA_VERSION])
       return
   ```
2. §8 加测试 `test_future

## 批判B（gameplay_planner）

# 批判报告：两份方案的遗漏、冲突、死代码、不可触达机制、存档风险与测试漏洞

---

## 一、主方案（唯一可执行方案）的致命问题

### P0-1【死代码 / 不可触达】§3.1 家居超市场景不存在，整条购买路径 A 悬空

主方案 §3.1 假设 `commercial_district` 有 `furniture_shop` 子区，§7.1 又新建 `furniture_shop_actor.gd`，但 §9 风险表自己承认"`furniture_shop` 场景不存在 → P0"。**门禁 G0.4 只 grep 了 `room_furniture_layer` 和 `current_area == "home"`，根本没验证 `furniture_shop` 是否存在**。若不存在，路径 A 和路径 B（样板间在超市内）全部不可触达，只剩旧货市场一条路——而旧货市场 `chen` 是否卖家具也未验证。

**返工要求**：门禁必须新增 `grep -rn "furniture_shop\|home_store\|样板间\|showroom" data/ scripts/`，输出实际场景 key 清单。若不存在，方案必须给出**新建场景的完整步骤**（场景文件、zone 矩形、入口 NPC 位置），而不是一句"复用 `commercial_district` + 新增子区"。

### P0-2【冲突 / 存档风险】§5.1 `owned` 值类型从 `bool` 改为 `Dictionary`，但 §2.3 碰撞检测仍按 `placed[slot_id]` 取 fid

主方案 §5.1 把 `owned[fid]` 从 `true` 改成 `{"owned": true, "condition": "new"}`，但 §2.3 `can_place_at` 里写的是：

```gdscript
for slot_id in placed:
    var other_fid := str(placed[slot_id])
```

`placed` 是 `slot→fid`，`owned` 是 `fid→dict`，**两套键空间不一致**。§3.4 收纳流程说"收纳 = `unplace(fid)`，`owned` 保留"，但 `unplace` 的签名是 `unplace(slot_id)` 还是 `unplace(fid)`？主方案全程没定义 `placed` 的键到底是 slot 还是 fid。§2.3 用 `slot_id`，§3.4 用 `fid`，**自相矛盾**。

**返工要求**：明确 `placed` 的键类型。若沿用现有 `slot→fid`，则"同一家具多件"不可能（主方案 §1 D10 说 `layouts` 切换时 `placed` 整体替换，暗示仍是 slot 模型）；若改为 `fid→instance`，则 §2.3 的 `placed[slot_id]` 全部要改。**二选一，不能含糊**。

### P0-3【不可触达】§3.5 收纳柜"打开收纳列表"没有定义交互载体

主方案说"点击墙边的收纳柜 → 打开收纳列表（不是菜单，是场景内的柜子）→ 点击柜子里的家具 → 取出到编辑模式"。但：

- 收纳柜是 `WorldInteractable` 还是 `room_furniture_layer` 渲染的家具？
- "收纳列表用 `room_furniture_layer` 渲染在柜子旁边"——渲染在柜子旁边意味着**动态生成一堆 Sprite2D**，这些 Sprite 的点击如何路由？`world.gd` 的手势路由是否支持动态生成的交互物？
- 收纳柜本身占不占网格？如果占，`furniture_grid.csv` 里有没有 `storage_cabinet` 这一行？

**返工要求**：给出收纳柜的 `furniture_id`、网格占用、以及"柜内家具"的点击路由方案（是复用 `WorldInteractable` 还是新开 `StorageSlotInteractable`）。

### P0-4【死代码】§2.4 `SLOT_DEFAULT_GRID` 与 §2.1 归一化坐标互斥

§2.1 说 `manual_positions` 存归一化坐标，§2.4 说 `SLOT_DEFAULT_GRID` 是"唯一默认位置事实源"，`get_default_slot_position` 改为从它反算归一化坐标。但 §2.4 的网格坐标是 `Vector2i(18, 15)` 这种，反算公式是 `(18+0.5)/80`——**这依赖房间固定为 80×45**。§4.3 又说房产升级后房间变 100×56、120×67。**升级后 `SLOT_DEFAULT_GRID` 的硬编码坐标全部失效**，`get_default_slot_position` 反算出的归一化坐标会漂移。

**返工要求**：`SLOT_DEFAULT_GRID` 要么改为归一化常量（如 `Vector2(0.225, 0.333)`），要么明确"仅 tier 0 有效，升级后按比例迁移"。当前写法是**升级即坏**的死代码。

### P0-5【冲突】§4.1 房产升级"房间网格尺寸可能变化"与 §5.3 "HousingManager 存档只存 current_tier" 冲突

§5.3 说"房间网格尺寸由 `current_tier` 派生，不单独存"。但 §4.3 的迁移算法 `migrate_layout(old_w, old_h, new_w, new_h)` 需要知道**升级前的网格尺寸**。如果只存 `current_tier`，升级时 `old_w/old_h` 从哪来？从 `current_tier` 反查 `housing.csv` 的旧 tier 行——但升级瞬间 `current_tier` 已经变了。

**返工要求**：`migrate_layout` 必须在 `current_tier` 更新**之前**调用，且 `old_w/old_h` 从旧 tier 的 `housing.csv` 行读取。主方案 §4.3 的调用时机没写清楚，是**顺序依赖漏洞**。

### P0-6【测试漏洞】§8.1 `test_grid_migration` 断言"80×45 → 100×56 后家具位置按比例映射"，但没测**越界家具自动收纳**

§4.3 说"超出新边界的家具自动收纳"，但 §8.1 测试表里**没有这条**。`migrate_layout` 的代码（§4.3）只做坐标映射，**没有越界检查**，也没调用 `unplace`。这是**代码与文档不符**。

**返工要求**：`migrate_layout` 补越界检查，测试补 `test_migration_overflow_to_storage`。

### P1-1【遗漏】§6.2 家庭访客触发条件 `current_tier >= 2`，但 §4.3 的 tier 2 是"两室一厅 1920×1080"

`li_ma` 带小孩来坐、`fangjie` 来喝茶——这些 NPC 的**寻路**在 1920×1080 的房间里怎么走？主方案没提 NPC 寻路网格。如果房间网格只用于家具占用，NPC 走的是另一套碰撞，那"访客在沙发区域停留"如何判定？

**返工要求**：明确 NPC 是否使用同一 `OccupancyGrid`。若是，`allow_overlap=true` 的地毯会不会挡 NPC？若否，两套碰撞如何同步？

### P1-2【遗漏】§3.3 旧货家具 `condition = "worn"` 影响"生活质量反馈"，但 §6.1 的反馈表里没有 worn 的条目

§3.3 说旧货家具"影响后续生活质量反馈（见 §6）"，但 §6.1 的可见反馈表只有装修（`warm_walls` 等），**没有 worn 家具的任何反馈**。这是**悬空引用**。

**返工要求**：补 worn 家具的可见反馈（如"磨损的床，睡觉时体力恢复 ×0.9"——但这又违反"无数值属性条"）。或者删掉 §3.3 的"影响生活质量"表述，改为纯装饰差异。

### P1-3【死代码】§6.3 `social_tag` 写入 `furniture.csv` 新增列，但 §7.2 说"若 G0.2 按索引则新建 join 表"

§6.3 直接说"写入 `data/furniture.csv` 新增列，不新建表"，§7.2 又说"若 G0.2 按索引则新建 join 表"。**门禁 G0.2 的结果决定了两条互斥路径，但方案只写了其中一条**。如果 `ConfigDB.get_row` 按索引，§6.3 的 `social_tag` 列会破坏所有现有读取。

**返工要求**：门禁 G0.2 必须先跑，结果写入 `ROOM_FACTS.md`，然后**只保留一条路径**。

---

## 二、独立方案的致命问题

### P0-7【冲突 / 破坏现有存档】§7.3 迁移把 `placed: {slot: fid}` 转成 `instances` 数组，但**丢弃了 slot 语义**

独立方案 §7.3 的 `migrate` 把旧 `placed` 的每个 slot 转成一个 instance，`grid_pos` 从 `manual_positions` 的归一化坐标算。但：

- 旧档的 `slot` 是有语义的（`bed`/`light`/`rug`），迁移后 slot 信息**完全丢失**。
- 旧档的 `manual_positions` 可能**只有部分家具**有记录（玩家没手动挪过的用默认位置）。§7.3 的 `positions.get(fid, [0.5, 0.5])` 对没记录的家具**全部塞到房间正中央**——多件家具重叠，`occupancy.place` 会互相覆盖。

**返工要求**：迁移必须处理"无 `manual_positions` 记录"的家具，用 `SLOT_DEFAULT_GRID` 的等价物（但独立方案 §2 没有这个表）。**独立方案缺一张"默认槽位→网格"映射表**，迁移必然产生重叠。

### P0-8【死代码】§2.4 `RoomGrid.ORIGIN` 说"由 `scene_zones.csv` 的 `home` 矩形左上角派生，不硬编码"，但代码里就是硬编码

```gdscript
const ORIGIN := Vector2(320, 160)  # 房间左上角在场景中的像素位置
```

注释说"由 `scene_zones.csv` 派生"，代码是 `const`。**`const` 不可能运行时派生**。这是**自相矛盾的死代码**。

**返工要求**：要么改为 `var ORIGIN` 在 `_ready` 里从 `scene_zones.csv` 读，要么删掉"不硬编码"的注释。当前写法是**注释骗人**。

### P0-9【不可触达】§3.3 路径 C"实物搬运"的"搬运状态"没有定义

独立方案说"玩家进入搬运状态（移动速度 ×0.6，持续到回房）"，但：

- 搬运状态存在哪？`PlayerActor` 的字段？`GameState` 的 flag？
- 如果玩家在搬运途中**存档退出**，重进后搬运状态还在吗？家具在哪？
- "若中途进其他场景 → 家具暂存门口（storage）"——"门口"是 `home` 场景的一个 zone 吗？`scene_zones.csv` 里有吗？

**返工要求**：给出搬运状态的数据载体、存档字段、以及"门口"的 zone 定义。当前是**不可实现的口头描述**。

### P0-10【冲突】§5.1 `can_upgrade` 要求"必须看过样板间"，但 §5.2 的流程里 `mark_showroom_visited` 在"点击签约台"时才调用

§5.2 流程：

```
2. showroom 场景 → 点击"签约台" → HousingManager.mark_showroom_visited(...)
3. 点击签约台 → HousingManager.upgrade(...)
```

**同一个"签约台"点击，先 mark 再 upgrade**。但 §5.1 的 `can_upgrade` 检查 `_showroom_visited`——如果玩家**第一次**点签约台，`mark_showroom_visited` 和 `upgrade` 在同一帧调用，顺序对吗？如果 `upgrade` 先执行，`can_upgrade` 返回 false，玩家被卡住。

**返工要求**：明确"签约台"的点击处理顺序，或把 `mark_showroom_visited` 移到"进入 showroom 场景"时触发。

### P0-11【存档风险】§7.2 `RoomLayoutManager.restore` 里 `occupancy = OccupancyGrid.new(w, h)` 重建，但 `_mark_static_obstacles()` 依赖 `RoomStaticLayout`

`RoomStaticLayout.get_door_cells()` 从哪来？独立方案 §2.4 说"门/窗/固定墙从 `scene_zones.csv` 的 `home` 矩形派生"，但 `scene_zones.csv` 的 `home` 矩形是**整个房间的矩形**，不是门/墙的格子。**门和墙的格子数据不存在**。

**返工要求**：要么新建 `data/room_static_layout.csv` 定义门/墙格子，要么明确"门/墙由 `home` 矩形边界自动生成"（但这样门在哪？）。

### P1-4【遗漏】§6.2 `can_invite_family` 要求 `has_furniture("sofa")`，但 §2.1 的 `furniture.csv` 示例里**没有 sofa**

§2.1 的 CSV 示例有 `wood_bed`/`floor_lamp`/`low_table`/`bookshelf`/`cat_tower`，**没有 sofa**。§6.4 的关联表里有 `sofa` 行。**示例数据与关联表不一致**。

**返工要求**：补全 `furniture.csv` 的 sofa 行，或删掉 §6.2 的 sofa 依赖。

### P1-5【测试漏洞】独立方案 §8 迁移步骤 M4 被截断

> **M4** | `room_furniture_layer` 

**方案正文在这里断了**。M4 之后的内容（M5、M6...）缺失。这是**方案不完整**，无法执行。

**返工要求**：补全 M4 之后的迁移步骤。

### P1-6【冲突】§1 说"`RoomManager.buy()` 降级为内部 API，UI 不可直调"，但 §3.4 的 `buy()` 实现里 `push_warning` 后**仍然执行购买**

```gdscript
func buy(fid: String) -> bool:
    push_warning("RoomManager.buy() 已废弃，请走 PurchaseSession")
    return _internal_buy(fid, "legacy", "")
```

**警告后照常购买**——这不是"降级"，这是"留后门"。任何旧代码调 `buy()` 仍能绕过 `PurchaseSession`。硬约束"购买必须通过 NPC/样板间/实物"被**代码层面违反**。

**返工要求**：`buy()` 必须 `return false` 并 `push_error`，或直接删除。当前写法是**假降级**。

---

## 三、两份方案共同的遗漏

### P0-12【共同遗漏】"旋转"的视觉与逻辑分离没有验证渲染层是否支持

主方案 §1 D4 说"15° 步进，但占用矩形按 90° 量化"，独立方案 §4.1 说"旋转 90°"。两份方案都假设 `room_furniture_layer` 能渲染任意角度的 Sprite2D。但：

- 如果现有渲染是 `Sprite2D` + `rotation_degrees`，15° 步进可行。
- 如果现有渲染是**预烘焙的 4 向贴图**（很多 2D 游戏这么做），15° 步进**根本渲染不出来**。

**门禁 G0.4 必须新增**：`grep -n "rotation\|texture\|Sprite2D\|_draw" scripts/gameplay/room_furniture_layer.gd`，确认渲染方式。

### P0-13【共同遗漏】"固定物价"与"旧货 ×0.6 / 打包 ×0.9"的冲突

硬约束说"固定物价"，主方案 §3.3 旧货 ×0.6、§3.2 打包 ×0.9，独立方案 §3.2 样板间直接按 `furniture.csv` 价格。**"固定物价"到底指"基础价固定"还是"成交价固定"？** 两份方案都没解释。如果指成交价固定，旧货折扣违反约束；如果指基础价固定，折扣合法但需在 `ROOM_FACTS.md` 里写明。

**返工要求**：在 `ROOM_FACTS.md` 里定义"固定物价"的精确语义，并让所有折扣路径符合该语义。

### P0-14【共同遗漏】"NPC/系统/场景提示分离"的具体 API 没有验证

两份方案都提到 `NoticeManager` 的 `source_kind = "npc"/"system"/"scene"`，但**门禁没有验证 `NoticeManager` 是否支持 `source_kind`**。如果现有 `NoticeManager.show_message(text, type)` 只有两个参数，所有 `source_kind` 调用都是**死代码**。

**返工要求**：门禁新增 `grep -n "func show_message\|source_kind\|speaker" autoload/notice_manager.gd`，确认签名。

### P1-7【共同遗漏】"收纳"与"存档"的交互没有测试

两份方案都有收纳机制，但**没有测试**：

- 收纳后存档 → 读档 → 家具还在收纳里吗？
- 收纳柜里的家具 → 存档 → 读档 → 柜子内容还在吗？
- 摆放中的家具（编辑模式未确认）→ 存档 → 读档 → 状态是什么？

**返工要求**：补 `test_storage_save_roundtrip`、`test_storage_cabinet_save_roundtrip`、`test_edit_mode_save`。

### P1-8【共同遗漏】"房产升级后家具位置迁移"的**视觉连续性**没有定义

两份方案都做了坐标迁移，但**玩家看到的是什么**？升级瞬间家具"跳"到新位置？还是有过渡动画？硬约束"温柔治愈画风"下，家具瞬移是**体验事故**。

**返工要求**：定义升级过渡（如黑屏 + "搬家中..." + 新房间淡入），或明确"家具瞬移可接受"。

---

## 四、返工优先级

| 优先级 | 问题 | 返工动作 |
|---|---|---|
| **P0** | 主 P0-1 / 独立 P0-7 | 门禁补场景验证；迁移补默认位置表 |
| **P0** | 主 P0-2 / 独立 P0-11 | 明确 `placed` 键类型；补 `room_static_layout.csv` |
| **P0** | 主 P0-4 / 独立 P0-8 | `SLOT_DEFAULT_GRID` 改归一化；`ORIGIN` 改运行时读 |
| **P0** | 独立 P0-10 / P1-6 | 签约台顺序；`buy()` 真降级 |
| **P0** | 共同 P0-12 / P0-13 / P0-14 | 门禁补渲染/物价/NoticeManager 验证 |
| **P1** | 主 P1-1 / P1-2 / P1-3 | NPC 寻路；worn 反馈；social_tag 路径二选一 |
| **P1** | 独立 P1-4 / P1-5 | 补 sofa 数据；补全 M4 之后步骤 |
| **P1** | 共同 P1-7 / P1-8 | 补收纳存档测试；定义升级过渡 |

---

## 五、结论

**主方案**：骨架完整但**门禁不充分**（场景存在性、渲染方式、NoticeManager 签名均未验证），**内部矛盾**（`placed` 键类型、`SLOT_DEFAULT_GRID` 与升级冲突、`owned` 类型变更与碰撞检测不符），**测试覆盖不足**（越界收纳、收纳存档）。

**独立方案**：架构更干净（实例化 + 占用位图），但**迁移方案会丢数据**（slot 语义、默认位置），**代码自相矛盾**（`ORIGIN` 注释 vs `const`），**方案不完整**（M4 截断），**假降级**（`buy()` 警告后照常执行）。

**两份方案都不能直接执行**。必须先跑完**扩充后的门禁**（新增场景存在性、渲染方式、NoticeManager 签名、`placed` 键类型四项），把结果写入 `ROOM_FACTS.md`，然后**二选一**（建议取独立方案的实例化架构 + 主方案的网格量化与存档兼容矩阵），再补全上述 P0 返工项，才能进入编码。

## 综合决策

# 《深日记》房间装扮 × 家具购买 × 房产升级 —— 最终可执行方案

> **裁决**：取**独立方案的实例化架构**（`FurnitureInstance` + `OccupancyGrid` + `PurchaseSession`）作为数据与流程骨架，取**主方案的网格量化、存档兼容矩阵、装修可见反馈**作为约束层。两份方案的门禁均不充分，**本方案 §0 为扩充后的唯一门禁**，未通过不得写业务代码。
>
> **唯一事实源**：`docs/ROOM_FACTS.md`（门禁结果）+ `data/furniture.csv` / `data/furniture_grid.csv` / `data/furniture_social.csv` / `data/furniture_bundles.csv` / `data/housing.csv` / `data/renovations.csv` / `data/room_static_layout.csv`。代码中禁止出现家具名、价格、网格尺寸、阈值字面量。
>
> **硬约束**：无任务面板、无数值属性条（= 不新增 UI 数值条，允许内部乘算）、场景点击经营、NPC/系统/场景提示分离、固定物价（= 基础价固定，折扣路径白名单）、存档兼容、温柔治愈画风。

---

## 0. 前置门禁（阻塞性，扩充版）

**所有门禁结果写入 `docs/ROOM_FACTS.md`，每条假设标注「存在 / 不存在 / 类型 / 签名」。未通过不得写业务代码。**

### G0.1 RoomManager 真实接口与调用面

```bash
grep -n "^func \|^signal \|^var \|^const " autoload/room_manager.gd
grep -rn "RoomManager\." --include=*.gd scripts/ autoload/ | grep -v "room_manager.gd" | wc -l
grep -rn "RoomManager\." --include=*.gd scripts/ autoload/ | grep -v "room_manager.gd"
```

**必须回答**：
- `owned` / `placed` / `layouts` / `manual_positions` / `manual_rotations` 的真实类型。
- **`placed` 的键是 `slot_id` 还是 `fid`？**（主方案 P0-2 的核心矛盾）
- `get_save_data()` / `restore()` 是否存在？
- `manual_positions` 存 `Vector2` 还是 `{x,y}`？
- **调用点数量**（决定迁移策略）。

**裁决**：
- 调用点 > 20 → 保留 `RoomManager` 旧 API 作**转发层**（不是假降级，见 §3.4）。
- `placed` 键为 `slot_id` → 迁移时 slot 语义**必须保留**为 `slot_hint` 字段（独立方案 P0-7）。
- `manual_positions` 存 `Vector2` → 存档序列化必须转 `{"x","y"}`。

### G0.2 ConfigDB 读取方式

```bash
grep -n "func get_row\|func get_rows" autoload/config_db.gd
grep -rn "ConfigDB.get_row" --include=*.gd autoload/room_manager.gd | head -5
```

**裁决**：
- 按列名取值 → 允许新增列。
- 按索引取值 → **禁止新增列**，`social_tag` 必须独立成 `data/furniture_social.csv`（主方案 P1-1）。

### G0.3 场景存在性与坐标基准

```bash
grep -rn "commercial_district\|furniture_shop\|home_store\|market\|旧货\|showroom\|样板间" --include=*.gd --include=*.csv scripts/ data/ autoload/
ls data/scene_zones.csv && grep -n "home\|residence\|market\|commercial\|showroom" data/scene_zones.csv
grep -rn "SceneRouter\|travel_to\|change_scene" --include=*.gd autoload/ scripts/ | head -20
```

**必须回答**：
- `furniture_shop` / `showroom` / 旧货摊**是否存在**？
- `home` 场景 key 是什么？`scene_zones.csv` 里 `home` 矩形是什么？
- `SceneRouter.travel_to` 签名？

**裁决**：
- 任一场景不存在 → §3 对应路径标记为「**待建场景**」，附完整建场景步骤（场景文件、zone 矩形、入口 NPC 位置），不得写"流程"。
- `RoomGrid.ORIGIN` 必须运行时从 `SceneZoneDB.get_rect("home")` 读取，**禁止 const**（独立方案 P0-8）。

### G0.4 渲染管线与旋转能力

```bash
grep -n "^func \|^signal \|^var \|^const " scripts/gameplay/room_furniture_layer.gd
grep -n "rotation\|texture\|Sprite2D\|_draw\|rotation_degrees" scripts/gameplay/room_furniture_layer.gd
grep -rn "speed_multiplier\|move_speed" --include=*.gd scripts/player* autoload/
```

**必须回答**：
- 家具用 `Sprite2D` 还是 `_draw()`？
- **是否支持任意角度旋转？还是预烘焙 4 向贴图？**（共同 P0-12）
- `PlayerActor` 是否有 `speed_multiplier`？（独立方案 P0-9 搬运状态）

**裁决**：
- 预烘焙 4 向 → **旋转只做 90° 步进**，删除 15° 步进（主方案 D4 作废）。
- 无 `speed_multiplier` → 搬运状态必须先扩展 `PlayerActor` 或删除该机制。

### G0.5 装修链路与 HousingManager

```bash
grep -rn "renovation\|installed_decor\|renovation_style" --include=*.gd autoload/ scripts/
grep -n "func get_bonus\|func upgrade\|func can_upgrade" autoload/housing_manager.gd
grep -rn "get_bonus(" --include=*.gd scripts/ autoload/ | grep -v housing_manager.gd
```

**必须回答**：
- `renovations.csv` 是否被消费？
- `HousingManager.get_bonus()` 被谁读取？
- `renovation_style` 与 `installed_decor` 的关系？

**裁决**：
- `get_bonus("energy")` 被 `PlayerActor` 读取 → **装修做数值**（不新增 UI，仅内部乘算），§6.1 表述改为"不新增 UI 数值条"。
- `renovation_style` = 当前生效风格 id（单选），`installed_decor` = 已购装修项集合（多选）。**两者关系写入 `ROOM_FACTS.md`**。

### G0.6 生活质量 / 家庭 / 社交 / NoticeManager / GameState

```bash
grep -rn "quality_of_life\|life_quality\|family\|social\|affinity" --include=*.gd autoload/ | head -30
grep -n "^func \|^signal \|^var \|^const " autoload/notice_manager.gd
grep -rn "NoticeManager.show_message\|NoticeManager.push" --include=*.gd scripts/ | head -10
grep -n "func spend\|func can_afford\|func refund\|func add_money" autoload/game_state.gd
grep -n "func rest\|rest_quality\|energy_recover" scripts/player* autoload/
```

**必须回答**：
- `NoticeManager.show_message` 签名？是否有 `source_kind` / `speaker`？（共同 P0-14）
- `GameState.spend` / `can_afford` / `refund` 是否存在？（独立方案 P0-8、共同 P0-12）
- `PlayerActor.rest()` 是否存在？

**裁决**：
- `NoticeManager` 无 `source_kind` → **先扩展 `NoticeManager`**，否则所有 `source_kind` 调用是死代码。
- `GameState.can_afford` / `refund` 不存在 → 用 `GameState.money >= price` / 新增 `refund`。

### G0.7 静态布局（门/墙/窗）

```bash
ls data/room_static_layout.csv 2>/dev/null || echo "NOT_EXIST"
grep -rn "door\|wall\|window\|门\|墙\|窗" data/scene_zones.csv 2>/dev/null
```

**裁决**：
- 不存在 → **新建 `data/room_static_layout.csv`**（`housing_tier, cell_x, cell_y, cell_type`，`cell_type ∈ {door, wall, window, reserved}`）。独立方案 P0-11 的 `RoomStaticLayout` 依赖此表。

---

## 1. 决策摘要（最终拍板）

| # | 争议 | 最终裁决 | 依据 |
|---|---|---|---|
| **D1** | 数据模型 | **`FurnitureInstance` 实例化**，`instances: Array[FurnitureInstance]` + `storage: Array[String]` | 独立方案，支持同款多件、自由摆放 |
| **D2** | 坐标真相 | **网格坐标 `Vector2i` 是唯一真相**，像素/归一化均为派生量 | 主 P0-2 + 独立 P0-8 |
| **D3** | 网格粒度 | `CELL_SIZE` 从 `scene_zones.csv` 派生，**禁止字面量** | 主 P0-2 |
| **D4** | 占用模型 | **多层位图**（`layer` 0=地板 1=家具 2=墙面 3=天花板），**同层碰撞** | 主 P0-5 + 独立 P1-5 |
| **D5** | 旋转 | **仅 90° 步进**（若 G0.4 确认预烘焙贴图）；否则 15° 视觉 + 90° 逻辑 | 共同 P0-12 |
| **D6** | 购买路径 | **三选一，全部实物驱动**：NPC 代购 / 样板间实物 / 旧货搬运。**`RoomManager.buy()` 真降级为 `return false` + `push_error`** | 硬约束 + 独立 P1-6 |
| **D7** | 购买事务 | **`pay_and_deliver()` 原子操作**，失败 `refund` | 共同 P0-12 |
| **D8** | 收纳 | `store_instance` 时 `stored_items` **自动转移 `InventoryManager`**，满则拒绝 | 独立 P1-6 |
| **D9** | 房产升级 | **必须 `fangjie` 带看样板间 → 签约台**，`mark_showroom_visited` 在**进入 showroom 时**触发 | 独立 P0-10 |
| **D10** | 装修 | **做数值**（不新增 UI），`renovation_style` 单选 + `installed_decor` 多选 | 主 P0-4 |
| **D11** | 生活质量 | **不新增 UI 数值条**，内部乘算；阈值写入 `data/housing.csv` | 独立 P0-10 |
| **D12** | 存档 | `schema_version = 2`，`grid_version = 2`，**拒绝加载未来版本** | 共同 P1-10 |
| **D13** | 固定物价 | **基础价固定**；折扣白名单：旧货 ×0.6、打包 ×0.9，写入 `ROOM_FACTS.md` | 共同 P0-13 |
| **D14** | 迁移 | **双写 → 切读 → 删旧**，三阶段，每阶段可回滚 | 独立 P0-7 |

---

## 2. 数据结构

### 2.1 家具模板（`data/furniture.csv` 扩展列，若 G0.2 允许）

```csv
furniture_id,name,category,price,grid_w,grid_h,rotatable,layer,anchor,storage_slots,description
wood_bed,原木单人床,bed,680,2,3,true,1,floor,0,睡惯了硬床，腰不酸。
floor_lamp,暖光落地灯,light,180,1,1,false,1,floor,0,晚上开着不刺眼。
low_table,矮饭桌,table,320,2,2,true,1,floor,0,两个人吃饭刚好。
bookshelf,旧木书架,shelf,420,1,2,true,2,wall,6,能塞下不少书。
sofa_small,小沙发,sofa,880,3,2,true,1,floor,0,坐上去就不想起来。
rug_small,小地毯,rug,120,4,3,true,0,floor,0,踩上去软软的。
```

**若 G0.2 按索引** → 新建 `data/furniture_ext.csv`（`furniture_id, grid_w, grid_h, rotatable, layer, anchor, storage_slots`），用 `furniture_id` join。

### 2.2 网格占用（`data/furniture_grid.csv`，与 `furniture_ext` 二选一）

```csv
furniture_id,grid_w,grid_h,rotatable,layer,anchor,storage_slots
wood_bed,2,3,true,1,floor,0
floor_lamp,1,1,false,1,floor,0
low_table,2,2,true,1,floor,0
bookshelf,1,2,true,2,wall,6
sofa_small,3,2,true,1,floor,0
rug_small,4,3,true,0,floor,0
```

### 2.3 社交标签（`data/furniture_social.csv`，独立表，避免 G0.2 冲突）

```csv
furniture_id,social_tag
aquarium_small,fish_talk
plant_pot,plant_talk
bookshelf,book_talk
```

### 2.4 打包（`data/furniture_bundles.csv`）

```csv
bundle_id,name,furniture_ids,discount
living_room_basic,小户型客厅,sofa_small|low_table|bookshelf|rug_small,0.9
study_corner,安静书房角,desk_study|bookshelf|floor_lamp,0.9
```

### 2.5 静态布局（`data/room_static_layout.csv`，新建）

```csv
housing_tier,cell_x,cell_y,cell_type
0,0,0,door
0,0,1,door
0,0,0,wall
0,1,0,wall
...
```

### 2.6 房产（`data/housing.csv` 扩展列）

```csv
housing_id,tier,name,price,rent,grid_w,grid_h,energy_bonus,study_bonus,relax_bonus,family_threshold,social_threshold,description
rental_single,0,城中村单间,0,800,20,14,0.0,0.0,0.0,0.10,0.08,一张床一张桌，够住。
rental_one_bed,1,一室一厅,12000,1200,28,18,0.03,0.02,0.05,0.10,0.08,多了个客厅，能请人坐坐。
rental_two_bed,2,两室一厅,38000,2000,36,22,0.05,0.06,0.08,0.10,0.08,有独立书房，家里人来也住得下。
```

**阈值 `family_threshold` / `social_threshold` 写入表，禁止硬编码**（独立 P0-10）。

### 2.7 家具实例（运行时 + 存档）

```gdscript
# scripts/gameplay/furniture_instance.gd
class_name FurnitureInstance
extends RefCounted

var instance_id: String
var furniture_id: String
var grid_pos: Vector2i
var rotation: int          # 0 / 90 / 180 / 270
var layer: int             # 0=地板 1=家具 2=墙面 3=天花板
var slot_hint: String      # 迁移保留的旧 slot 语义（"bed"/"light"/...），新家具为 ""
var stored_items: Array[String] = []
var acquired_from: String  # "npc:fangjie" / "showroom:tier2" / "physical:chen"
var acquired_day: int
var condition: String      # "new" / "worn"

func get_occupied_cells() -> Array[Vector2i]:
    var t := FurnitureDB.get_template(furniture_id)
    if t.is_empty():
        push_error("Unknown furniture_id: %s" % furniture_id)
        return [grid_pos]
    var w := t.grid_h if rotation in [90, 270] else t.grid_w
    var h := t.grid_w if rotation in [90, 270] else t.grid_h
    var cells: Array[Vector2i] = []
    for dx in w:
        for dy in h:
            cells.append(grid_pos + Vector2i(dx, dy))
    return cells

func to_dict() -> Dictionary:
    return {
        "instance_id": instance_id,
        "furniture_id": furniture_id,
        "grid_pos": [grid_pos.x, grid_pos.y],
        "rotation": rotation,
        "layer": layer,
        "slot_hint": slot_hint,
        "stored_items": stored_items.duplicate(),
        "acquired_from": acquired_from,
        "acquired_day": acquired_day,
        "condition": condition,
    }

static func from_dict(d: Dictionary) -> FurnitureInstance:
    var inst := FurnitureInstance.new()
    inst.instance_id = str(d.get("instance_id", ""))
    inst.furniture_id = str(d.get("furniture_id", ""))
    var gp: Array = d.get("grid_pos", [0, 0])
    inst.grid_pos = Vector2i(int(gp[0]), int(gp[1]))
    inst.rotation = int(d.get("rotation", 0))
    inst.layer = int(d.get("layer", 1))
    inst.slot_hint = str(d.get("slot_hint", ""))
    inst.stored_items.assign(d.get("stored_items", []))
    inst.acquired_from = str(d.get("acquired_from", ""))
    inst.acquired_day = int(d.get("acquired_day", 0))
    inst.condition = str(d.get("condition", "new"))
    return inst
```

### 2.8 占用位图（多层）

```gdscript
# scripts/gameplay/occupancy_grid.gd
class_name OccupancyGrid
extends RefCounted

const EMPTY := 0
const FURNITURE := 1
const DOOR := 2
const WALL := 3
const WINDOW := 4
const RESERVED := 5

var width: int
var height: int
var _layers: Array[PackedByteArray] = []   # 按 layer 索引
var _owner: Array[Dictionary] = []         # 每层 cell_index -> instance_id

func _init(w: int, h: int, layer_count: int = 4) -> void:
    width = w
    height = h
    for i in layer_count:
        var cells := PackedByteArray()
        cells.resize(w * h)
        cells.fill(EMPTY)
        _layers.append(cells)
        _owner.append({})

func idx(p: Vector2i) -> int:
    return p.y * width + p.x

func in_bounds(p: Vector2i) -> bool:
    return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height

func get_cell(p: Vector2i, layer: int) -> int:
    if not in_bounds(p):
        return WALL
    return _layers[layer][idx(p)]

func can_place(inst: FurnitureInstance) -> bool:
    var layer_cells := _layers[inst.layer]
    var layer_owner := _owner[inst.layer]
    for c in inst.get_occupied_cells():
        if not in_bounds(c):
            return false
        var v := layer_cells[idx(c)]
        if v == DOOR or v == WALL or v == WINDOW or v == RESERVED:
            return false
        if v == FURNITURE and layer_owner.get(idx(c), "") != inst.instance_id:
            return false
    return true

func place(inst: FurnitureInstance) -> void:
    var layer_cells := _layers[inst.layer]
    var layer_owner := _owner[inst.layer]
    for c in inst.get_occupied_cells():
        if not in_bounds(c):
            continue
        layer_cells[idx(c)] = FURNITURE
        layer_owner[idx(c)] = inst.instance_id

func remove(inst: FurnitureInstance) -> void:
    var layer_cells := _layers[inst.layer]
    var layer_owner := _owner[inst.layer]
    for c in inst.get_occupied_cells():
        if not in_bounds(c):
            continue
        if layer_owner.get(idx(c), "") == inst.instance_id:
            layer_cells[idx(c)] = EMPTY
            layer_owner.erase(idx(c))

func mark_static(cell: Vector2i, cell_type: int) -> void:
    if not in_bounds(cell):
        return
    # 静态障碍写入所有层
    for i in _layers.size():
        _layers[i][idx(cell)] = cell_type
```

### 2.9 网格常量（运行时派生）

```gdscript
# scripts/gameplay/room_grid.gd
class_name RoomGrid
extends RefCounted

static var CELL_SIZE: int = 32
static var ORIGIN: Vector2 = Vector2.ZERO
static var ROOM_W: int = 20
static var ROOM_H: int = 14

static func init_from_zone(zone_rect: Rect2, cell_size: int) -> void:
    ORIGIN = zone_rect.position
    CELL_SIZE = cell_size
    ROOM_W = int(zone_rect.size.x / cell_size)
    ROOM_H = int(zone_rect.size.y / cell_size)

static func grid_to_px(g: Vector2i) -> Vector2:
    return ORIGIN + Vector2(g.x * CELL_SIZE, g.y * CELL_SIZE)

static func px_to_grid(p: Vector2) -> Vector2i:
    return Vector2i(floori((p.x - ORIGIN.x) / CELL_SIZE), floori((p.y - ORIGIN.y) / CELL_SIZE))
```

**`init_from_zone` 在 `home` 场景 `_ready` 时调用，数据来自 `SceneZoneDB.get_rect("home")`。**

---

## 3. 购买流程：`PurchaseSession` 状态机

### 3.1 三条路径（场景存在性由 G0.3 决定）

| 路径 | 触发场景 | 交互 | 若场景不存在 |
|---|---|---|---|
| **A. NPC 代购** | 家居超市 `home_store_clerk` | 点击 NPC → 场景内实物 → 确认 → 次日送达 | 标记「待建场景」，附建场景步骤 |
| **B. 样板间实物** | `showroom` | 点击样板间家具 → 确认 → 立即搬入 | 同上 |
| **C. 旧货搬运** | 旧货市场 `chen` | 点击实物 → 确认 → 搬运状态 → 回房交付 | 同上 |

### 3.2 状态机（事务化）

```gdscript
# scripts/gameplay/purchase_session.gd
class_name PurchaseSession
extends RefCounted

enum State { IDLE, BROWSING, INSPECTING, PAYING, DELIVERING, DONE, CANCELLED }

var state: State = State.IDLE
var source_kind: String
var source_id: String
var candidate_fid: String
var candidate_price: int
var delivery_day: int

func begin(kind: String, id: String) -> void:
    source_kind = kind
    source_id = id
    state = State.BROWSING

func inspect(fid: String) -> void:
    var t := FurnitureDB.get_template(fid)
    if t.is_empty():
        push_error("Unknown furniture_id: %s" % fid)
        return
    candidate_fid = fid
    candidate_price = t.price
    state = State.INSPECTING

func confirm() -> bool:
    if state != State.INSPECTING:
        return false
    if GameState.money < candidate_price:
        NoticeManager.show_message("钱不太够，先攒攒。", "hint", _speaker())
        state = State.BROWSING
        return false
    state = State.PAYING
    return true

func pay_and_deliver() -> bool:
    if state != State.PAYING:
        return false
    var t := FurnitureDB.get_template(candidate_fid)
    if t.is_empty():
        NoticeManager.show_message("这件暂时没货。", "hint", _speaker())
        state = State.BROWSING
        return false
    if not GameState.spend(candidate_price, _pay_reason()):
        state = State.BROWSING
        return false
    var inst := RoomLayoutManager.create_instance(candidate_fid, source_kind, source_id)
    if inst == null:
        GameState.refund(candidate_price, "购买失败，钱退给你。")
        state = State.BROWSING
        return false
    inst.condition = "worn" if source_kind == "physical" else "new"
    RoomLayoutManager.add_to_storage(inst)
    state = State.DONE
    return true

func _speaker() -> String:
    match source_kind:
        "npc": return NpcDB.get_name(source_id)
        "showroom": return "样板间"
        "physical": return NpcDB.get_name(source_id)
        _: return ""

func _pay_reason() -> String:
    var nm := FurnitureDB.get_template(candidate_fid).name
    match source_kind:
        "npc": return "在%s那儿订了%s。" % [_speaker(), nm]
        "showroom": return "样板间看中%s，直接搬回来。" % nm
        "physical": return "把%s搬回家。" % nm
        _: return "买下%s。" % nm
```

### 3.3 场景点击流程

**路径 A：NPC 代购**
```
点击 home_store_clerk
  → NPC 提示："看看要点什么？"
  → 场景内展示 3~5 件实物（WorldInteractable）
  → 点击实物 → session.inspect(fid) → 浮动标签"¥680 · 原木单人床"
  → 再次点击 → session.confirm() → session.pay_and_deliver()
  → NPC 提示："明天给你送过去。"（delivery_day = today + 1）
  → 次日 day_started → 家具已在 storage
  → 场景提示："门口多了个纸箱。"
```

**路径 B：样板间实物**
```
进入 showroom（由 fangjie 带看）
  → 场景内家具全是 WorldInteractable
  → 点击家具 → session.begin("showroom", showroom_id) → inspect → confirm → pay_and_deliver
  → 立即进 storage
  → 点击签约台 → HousingManager.upgrade()（见 §5）
```

**路径 C：旧货搬运**
```
点击旧货摊实物 → chen 提示："这个 ¥420，有点沉。"
  → session.begin("physical", "chen") → inspect → confirm → pay_and_deliver
  → 家具进 storage，condition = "worn"
  → 玩家进入搬运状态（speed_multiplier = 0.6，若 G0.4 确认存在）
  → 回 home 场景 → 自动解除搬运状态
  → 若中途存档退出 → 搬运状态不持久化，家具已在 storage
```

### 3.4 `RoomManager.buy()` 真降级

```gdscript
# autoload/room_manager.gd
func buy(fid: String) -> bool:
    push_error("RoomManager.buy() 已废弃，请走 PurchaseSession")
    return false   # 真降级，不留后门
```

**若 G0.1 调用点 > 20** → 旧 API 改为**转发层**：
```gdscript
func buy(fid: String) -> bool:
    push_warning("RoomManager.buy() 已废弃，转发到 PurchaseSession")
    var session := PurchaseSession.new()
    session.begin("legacy", "")
    session.inspect(fid)
    if not session.confirm():
        return false
    return session.pay_and_deliver()
```

---

## 4. 摆放 / 旋转 / 收纳

### 4.1 `RoomLayoutManager`（新增 autoload）

```gdscript
# autoload/room_layout_manager.gd
extends Node

signal layout_changed
signal placement_rejected(reason: String)

var instances: Array[FurnitureInstance] = []
var storage: Array[FurnitureInstance] = []   # 收纳态也是实例，保留 condition
var occupancy: OccupancyGrid
var _next_instance_seq := 1

func _ready() -> void:
    occupancy = OccupancyGrid.new(RoomGrid.ROOM_W, RoomGrid.ROOM_H, 4)
    _mark_static_obstacles()

func _mark_static_obstacles() -> void:
    for row in RoomStaticLayoutDB.get_rows_for_tier(HousingManager.current_tier):
        occupancy.mark_static(Vector2i(row.cell_x, row.cell_y), row.cell_type)

func try_place(instance_id: String, target_grid: Vector2i, rotation: int) -> bool:
    var inst := _find(instance_id)
    if inst == null:
        return false
    var old_pos := inst.grid_pos
    var old_rot := inst.rotation
    occupancy.remove(inst)
    inst.grid_pos = target_grid
    inst.rotation = rotation
    if not occupancy.can_place(inst):
        inst.grid_pos = old_pos
        inst.rotation = old_rot
        occupancy.place(inst)
        placement_rejected.emit("这里放不下，换个位置试试。")
        return false
    occupancy.place(inst)
    layout_changed.emit()
    SaveManager.request_auto_save("furniture_move")
    return true

func rotate_instance(instance_id: String, delta: int = 90) -> bool:
    var inst := _find(instance_id)
    if inst == null:
        return false
    var t := FurnitureDB.get_template(inst.furniture_id)
    if not t.rotatable:
        NoticeManager.show_message("%s转不了方向。" % t.name, "hint")
        return false
    return try_place(instance_id, inst.grid_pos, posmod(inst.rotation + delta, 360))

func add_to_storage(inst: FurnitureInstance) -> void:
    storage.append(inst)
    layout_changed.emit()

func place_from_storage(instance_id: String, target_grid: Vector2i) -> bool:
    var idx := _find_storage_index(instance_id)
    if idx < 0:
        return false
    var inst := storage[idx]
    inst.grid_pos = target_grid
    if not occupancy.can_place(inst):
        placement_rejected.emit("这里放不下。")
        return false
    storage.remove_at(idx)
    instances.append(inst)
    occupancy.place(inst)
    layout_changed.emit()
    SaveManager.request_auto_save("furniture_place")
    return true

func store_instance(instance_id: String) -> bool:
    var inst := _find(instance_id)
    if inst == null:
        return false
    # stored_items 自动转移 InventoryManager
    if not inst.stored_items.is_empty():
        for item_id in inst.stored_items:
            if not InventoryManager.add_item(item_id, 1):
                NoticeManager.show_message("背包满了，先把东西拿出来。", "hint")
                return false
        inst.stored_items.clear()
    occupancy.remove(inst)
    instances.erase(inst)
    storage.append(inst)
    layout_changed.emit()
    SaveManager.request_auto_save("furniture_store")
    return true

func create_instance(fid: String, source_kind: String, source_id: String) -> FurnitureInstance:
    var t := FurnitureDB.get_template(fid)
    if t.is_empty():
        push_error("Unknown furniture_id: %s" % fid)
        return null
    var inst := FurnitureInstance.new()
    inst.instance_id = "inst_%04d" % _next_instance_seq
    _next_instance_seq += 1
    inst.furniture_id = fid
    inst.layer = t.layer
    inst.acquired_from = "%s:%s" % [source_kind, source_id] if source_id != "" else source_kind
    inst.acquired_day = CalendarManager.current_day
    inst.condition = "new"
    return inst

func _find(instance_id: String) -> FurnitureInstance:
    for inst in instances:
        if inst.instance_id == instance_id:
            return inst
    return null

func _find_storage_index(instance_id: String) -> int:
    for i in storage.size():
        if storage[i].instance_id == instance_id:
            return i
    return -1
```

### 4.2 场景点击交互

| 手势 | 非编辑模式 | 编辑模式 |
|---|---|---|
| TAP 家具 | 查看信息 | 选中 |
| DOUBLE_TAP 家具 | — | 旋转 90° |
| DRAG 家具 | — | 移动（网格吸附） |
| SECONDARY 家具 | 查看信息 | 收纳 |
| TAP 空地 | — | 移动选中家具到该格 |
| TAP 工具箱 | 进入编辑模式 | 退出编辑模式 |
| TAP 收纳柜 | 打开柜内列表 | 打开柜内列表（独立 handler） |

**收纳柜是 `WorldInteractable`，不参与编辑模式选中**（主 P1-3）。

### 4.3 收纳

- **家具收纳**：`store_instance` → `stored_items` 自动转移 `InventoryManager`，满则拒绝（独立 P1-6 方案 B）。
- **家具内收纳**：`store_item_in_furniture(instance_id, item_id)`，检查 `storage_slots`。

---

## 5. 房产升级流程

### 5.1 前置门禁

```gdscript
# autoload/housing_manager.gd
var _showroom_visited: Dictionary = {}

func can_upgrade(housing_id: String) -> bool:
    var row := ConfigDB.get_row("housing", housing_id)
    if row.is_empty():
        return false
    if int(row.get("tier", "0")) != current_tier + 1:
        return false
    if not _showroom_visited.get(housing_id, false):
        NoticeManager.show_message("先去样板间看看，方姐带你走一趟。", "hint", "方姐")
        return false
    return true

func mark_showroom_visited(housing_id: String) -> void:
    _showroom_visited[housing_id] = true
    changed.emit()
```

### 5.2 场景点击流程（顺序修正）

```
1. 在 residence 点击 fangjie
   → fangjie 提示："想换大点的地方？我带你去看看。"
   → SceneRouter.travel_to("showroom", housing_id)

2. showroom 场景 _ready
   → HousingManager.mark_showroom_visited(housing_id)   ← 进入即标记，不是点签约台
   → 场景内家具全是 WorldInteractable

3. 点击签约台
   → HousingManager.upgrade(housing_id)
   → 成功 → 场景切换回 home（新户型）
   → 旧家具自动进 storage，玩家重新摆放
```

**`mark_showroom_visited`
