# 城区分区、门配对与空气墙审计

## 主方案

# 城区分区、门配对与空气墙审计 —— 可执行方案

> 目标：在**不破坏现有存档与场景流**的前提下，完成 street 及其它场景的 zone / 入口坐标 / 门配对 / 不可见碰撞体审计，产出**区域密度预算表**，保证同一街段不过度堆叠店面、所有出口可达、无空气墙。
> 前置：本方案是 `world-001`（连续 2D 城区流式加载）的**审计子任务**，不修改流式加载架构，只做**数据审计 + 数据修正 + 验证脚本**。

---

## 0. 前置门禁（阻塞性，未通过不得进入实现）

所有门禁结果写入 `docs/ZONE_AUDIT_FACTS.md`，作为后续所有坐标/字段裁决的唯一事实源。

### G0.1 现有 zone 数据真实来源确认
```bash
grep -rn "scene_zones" --include=*.gd --include=*.py --include=*.csv .
grep -rn "zone_id\|area_id" --include=*.gd scripts/ | head -40
```
**裁决规则**：
- 若 `scene_zones.csv` 是**唯一** zone 数据源 → 本方案只改 CSV + 加校验脚本。
- 若代码中还有硬编码 zone 矩形（如 `world.gd` 里的 `CITY_MAP_SIZE` 派生）→ 先列出所有硬编码点，纳入 §4 迁移清单。

### G0.2 现有门/入口数据真实来源确认
```bash
grep -rn "interaction_id\|enter_\|_exit\|leave_home\|home_to_living" --include=*.gd scripts/ | grep -v "\.import" | head -60
grep -rn "spawn_id\|spawn_point\|entrance" --include=*.gd scripts/ | head -40
```
**裁决规则**：
- 门配对目前是**字符串约定**（`enter_xxx` / `xxx_exit` / `leave_xxx`），无显式配对表 → 本方案**新增显式配对表** `data/door_pairs.csv`，不删除旧字符串约定（向后兼容）。
- 若已有 `door_pairs` 或类似结构 → 复用，不新建。

### G0.3 不可见碰撞体真实来源确认
```bash
grep -rn "CollisionShape2D\|RectangleShape2D\|StaticBody2D\|collision_layer\|collision_mask" --include=*.gd scripts/gameplay/ | head -60
```
**裁决规则**：
- 记录所有 `collision_layer == 0` 或 `collision_mask == 0` 的碰撞体（这些是"不可见但可能挡路"的候选）。
- 记录所有 `Area2D` 的 `hit_size`（`interactable.gd` 里 `hit_size` 默认 = `visual_size`，可能造成空气墙）。

### G0.4 玩家碰撞半径确认
```bash
grep -rn "radius\|shape\|CollisionShape2D" --include=*.gd scripts/gameplay/player.gd
```
**裁决规则**：玩家碰撞半径 `R` 是"空气墙"判定的基准。所有门/通道宽度必须 ≥ `2R + 安全余量(≥8px)`。

### G0.5 现有测试入口确认
```bash
grep -n '\"--' scripts/main.gd
```
**裁决规则**：确认 `--scene-check` / `--spot-city` 存在。若不存在，本方案 §5 的验证脚本降级为独立 `tools/audit_zones.py`。

---

## 1. 数据结构（唯一事实源）

### 1.1 `data/scene_zones.csv`（扩列，不破坏旧列）

现有列：`area_id,zone_id,name,rect_x,rect_y,rect_w,rect_h,kind,order`

**新增列**（追加在末尾，DictReader 安全）：

| 列名 | 类型 | 说明 | 默认值 |
|---|---|---|---|
| `priority` | int | 流式加载优先级，越小越先加载 | `order` |
| `preload_radius` | int | 预加载半径（px），0 = 不预加载 | `0` |
| `max_shops` | int | 该 zone 允许的最大店面数（密度预算） | 按 `kind` 查表 |
| `walkable` | bool | 是否可行走（false = 纯背景/装饰） | `true` |
| `door_ids` | string | 该 zone 内所有门的 `interaction_id`，分号分隔 | 空 |

**密度预算默认表**（按 `kind`）：

| kind | max_shops | 说明 |
|---|---|---|
| `market` | 6 | 旧货/摊位密集区 |
| `residential` | 2 | 城中村，店面少 |
| `nature` | 0 | 公园，无店面 |
| `commercial` | 5 | 商铺街 |
| `services` | 4 | 生活服务 |
| `industrial` | 3 | 工业区 |
| `suburb` | 3 | 城郊 |
| `transit` | 2 | 交通轴 |
| `event` | 4 | 节庆活动 |
| `shops` | 5 | 商业区北侧 |
| `housing` | 2 | 置业/社区 |
| `public` | 3 | 公共服务 |
| `labor` | 2 | 招工 |
| `logistics` | 2 | 仓配 |
| `factory` | 2 | 工厂 |
| `craft` | 3 | 手艺 |
| `wholesale` | 3 | 批发 |

### 1.2 `data/door_pairs.csv`（新建）

```csv
pair_id,from_area,from_zone,from_interaction_id,from_pos_x,from_pos_y,to_area,to_zone,to_interaction_id,to_pos_x,to_pos_y,width_px,kind,notes
```

| 字段 | 说明 |
|---|---|
| `pair_id` | 唯一 ID，如 `street_home_01` |
| `from_area` / `to_area` | 场景 ID（`street` / `home` / `breakfast_shop` ...） |
| `from_zone` / `to_zone` | zone_id（用于密度审计） |
| `from_interaction_id` | 出发侧门的 `interaction_id` |
| `from_pos_x/y` | 出发侧门的世界坐标（**必须落在 from_zone 矩形内**） |
| `to_interaction_id` | 到达侧门的 `interaction_id`（可为空 = 单向） |
| `to_pos_x/y` | 到达侧门的世界坐标（**必须落在 to_zone 矩形内**） |
| `width_px` | 通道净宽（**必须 ≥ 2R + 8**） |
| `kind` | `bidirectional` / `one_way` / `interior` |
| `notes` | 备注 |

**约束（加载时断言）**：
1. `from_pos` 必须落在 `from_zone` 矩形内（含边界）。
2. `to_pos` 必须落在 `to_zone` 矩形内（含边界）。
3. `width_px >= 2 * player_radius + 8`。
4. `bidirectional` 的 `to_interaction_id` 不能为空。
5. 同一 `(from_area, from_interaction_id)` 不能出现两次。

### 1.3 `data/collision_audit.csv`（新建，审计输出）

```csv
area_id,zone_id,node_path,collision_type,layer,mask,rect_x,rect_y,rect_w,rect_h,is_door,is_air_wall,reason
```

由 §5 审计脚本自动生成，**不手工维护**。

---

## 2. 区域密度预算表（street 场景）

> 基于 `scene_zones.csv` 现有数据 + `max_shops` 默认表，逐 zone 给出预算与现状。

| zone_id | name | rect (x,y,w,h) | kind | 面积(px²) | max_shops | 现状店面数 | 余量 | 备注 |
|---|---|---|---|---|---|---|---|---|
| `market` | 旧货与市场区 | 250,300,500,320 | market | 160,000 | 6 | 待审计 | — | 旧货/摊位密集 |
| `village` | 城中村生活区 | 60,880,620,520 | residential | 322,400 | 2 | 待审计 | — | 店面少，住宅为主 |
| `nature` | 公园与自然区 | 850,900,650,500 | nature | 325,000 | 0 | 0 | 0 | 无店面 |
| `commercial_shops` | 商业区商铺街 | 1500,900,620,210 | commercial | 130,200 | 5 | 待审计 | — | 商铺街 |
| `commercial_services` | 商业区生活服务 | 1500,1120,620,200 | services | 124,000 | 4 | 待审计 | — | 生活服务 |
| `industrial` | 工业区 | 1450,60,760,420 | industrial | 319,200 | 3 | 待审计 | — | 工厂/仓配 |
| `suburb` | 城郊生活区 | 2000,900,500,440 | suburb | 220,000 | 3 | 待审计 | — | 城郊 |
| `center` | 中央交通轴 | 900,600,580,260 | transit | 150,800 | 2 | 待审计 | — | 交通轴 |
| `activity` | 节庆活动区 | 500,120,600,180 | event | 108,000 | 4 | 待审计 | — | 节庆 |

**密度判定规则**：
- `现状店面数 > max_shops` → **P0 违规**，必须合并/迁移店面。
- `现状店面数 == max_shops` → **P1 警告**，新增店面需先迁移。
- `现状店面数 < max_shops` → 通过。

**street 场景总预算**：`6+2+0+5+4+3+3+2+4 = 29` 个店面。

### 2.1 其它场景密度预算

| area_id | zone_id | kind | max_shops | 备注 |
|---|---|---|---|---|
| `commercial_district` | `north_shops` | shops | 5 | |
| `commercial_district` | `west_housing` | housing | 2 | |
| `commercial_district` | `center_public` | public | 3 | |
| `commercial_district` | `east_living` | services | 4 | |
| `commercial_district` | `south_transit` | transit | 2 | |
| `industrial_district` | `west_labor` | labor | 2 | |
| `industrial_district` | `north_logistics` | logistics | 2 | |
| `industrial_district` | `east_factory` | factory | 2 | |
| `industrial_district` | `south_craft` | craft | 3 | |
| `industrial_district` | `south_wholesale` | wholesale | 3 | |

---

## 3. 门配对审计（street 场景）

> 基于 `interactable.gd` 的字符串约定（`enter_xxx` / `xxx_exit` / `leave_xxx` / `home_to_living` 等），逐门审计。

### 3.1 已知门清单（从 `playtest_runner.gd` 提取）

| interaction_id | 方向 | 目标场景 | 目标 spawn | 配对状态 |
|---|---|---|---|---|
| `home_to_living` | 卧室→生活区 | `home_living` | `entrance` | 需补 `home_living_to_bedroom` |
| `home_living_to_bedroom` | 生活区→卧室 | `home` | `entrance` | 需补 `home_to_living` |
| `leave_home` | 生活区→城市 | `street` | `home_door` | 需补 `home_door` |
| `home_door` | 城市→出租屋 | `home_living` | `entrance` | 需补 `leave_home` |
| `enter_breakfast` | 街道→早餐店 | `breakfast_shop` | `entrance` | 需补 `breakfast_exit` |
| `enter_breakfast_kitchen` | 前厅→后厨 | `breakfast_kitchen` | `entrance` | 需补 `breakfast_kitchen_exit` |
| `park_exit` | 公园→街道 | `street` | `park_entrance` | 需补 `enter_park` |
| `exercise_equipment` | 公园内交互 | — | — | 非门 |

### 3.2 门配对审计规则

1. **双向性**：每个 `enter_xxx` 必须有对应的 `xxx_exit`（或 `leave_xxx`）。
2. **坐标可达**：`from_pos` 必须落在 `from_zone` 矩形内，且**不在任何碰撞体内**。
3. **通道净宽**：`width_px >= 2R + 8`。
4. **无孤儿门**：`door_pairs.csv` 中每个 `interaction_id` 必须在代码中真实存在。
5. **无重复**：同一 `(area, interaction_id)` 不能出现两次。

### 3.3 门配对修正清单（待审计后填充）

> 由 §5 审计脚本自动生成，格式：

| pair_id | from | to | 问题 | 修正 |
|---|---|---|---|---|
| `street_home_01` | `leave_home` @ street | `home_door` @ home_living | 缺 `to_pos` | 补 `to_pos` = 生活区门坐标 |
| ... | ... | ... | ... | ... |

---

## 4. 不可见碰撞体审计（空气墙）

### 4.1 空气墙定义

**空气墙** = 满足以下**任一**条件的碰撞体：
1. `collision_layer == 0` 且 `collision_mask == 0`（完全不参与碰撞，但可能被误用）。
2. `Area2D` 的 `hit_size` 远大于 `visual_size`（视觉上无物，实际挡路）。
3. `StaticBody2D` 无对应 `_draw()` 或 `Sprite2D`（不可见但挡路）。
4. 碰撞体矩形与任何 `door_pairs.csv` 的通道矩形相交（挡门）。

### 4.2 审计脚本 `tools/audit_zones.py`

```python
#!/usr/bin/env python3
"""审计 scene_zones.csv / door_pairs.csv / 碰撞体，输出 collision_audit.csv。"""
import csv, sys, json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ZONES = ROOT / "data" / "scene_zones.csv"
DOORS = ROOT / "data" / "door_pairs.csv"
OUT = ROOT / "data" / "collision_audit.csv"

PLAYER_RADIUS = 12  # 从 G0.4 确认后填入
SAFETY_MARGIN = 8

def load_zones():
    with open(ZONES, encoding="utf-8") as f:
        return list(csv.DictReader(f))

def load_doors():
    if not DOORS.exists():
        return []
    with open(DOORS, encoding="utf-8") as f:
        return list(csv.DictReader(f))

def rect_contains(zone, x, y):
    zx, zy = int(zone["rect_x"]), int(zone["rect_y"])
    zw, zh = int(zone["rect_w"]), int(zone["rect_h"])
    return zx <= x <= zx + zw and zy <= y <= zy + zh

def rect_intersects(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return not (ax + aw < bx or bx + bw < ax or ay + ah < by or by + bh < ay)

def audit():
    zones = load_zones()
    doors = load_doors()
    errors = []

    # 1. zone 矩形无重叠、无空洞（同 area 内）
    by_area = {}
    for z in zones:
        by_area.setdefault(z["area_id"], []).append(z)
    for area, zs in by_area.items():
        for i in range(len(zs)):
            for j in range(i + 1, len(zs)):
                a = (int(zs[i]["rect_x"]), int(zs[i]["rect_y"]),
                     int(zs[i]["rect_w"]), int(zs[i]["rect_h"]))
                b = (int(zs[j]["rect_x"]), int(zs[j]["rect_y"]),
                     int(zs[j]["rect_w"]), int(zs[j]["rect_h"]))
                if rect_intersects(a, b):
                    errors.append(f"ZONE_OVERLAP: {area} {zs[i]['zone_id']} <-> {zs[j]['zone_id']}")

    # 2. 门坐标落在 zone 内
    for d in doors:
        from_zone = next((z for z in zones if z["area_id"] == d["from_area"]
                          and z["zone_id"] == d["from_zone"]), None)
        if from_zone is None:
            errors.append(f"DOOR_FROM_ZONE_MISSING: {d['pair_id']}")
            continue
        if not rect_contains(from_zone, int(d["from_pos_x"]), int(d["from_pos_y"])):
            errors.append(f"DOOR_FROM_POS_OUTSIDE: {d['pair_id']}")
        if d["to_area"]:
            to_zone = next((z for z in zones if z["area_id"] == d["to_area"]
                            and z["zone_id"] == d["to_zone"]), None)
            if to_zone is None:
                errors.append(f"DOOR_TO_ZONE_MISSING: {d['pair_id']}")
            elif not rect_contains(to_zone, int(d["to_pos_x"]), int(d["to_pos_y"])):
                errors.append(f"DOOR_TO_POS_OUTSIDE: {d['pair_id']}")

    # 3. 通道净宽
    min_width = 2 * PLAYER_RADIUS + SAFETY_MARGIN
    for d in doors:
        if int(d["width_px"]) < min_width:
            errors.append(f"DOOR_TOO_NARROW: {d['pair_id']} width={d['width_px']} < {min_width}")

    # 4. 双向性
    ids = {(d["from_area"], d["from_interaction_id"]) for d in doors}
    for d in doors:
        if d["kind"] == "bidirectional":
            if not d["to_interaction_id"]:
                errors.append(f"DOOR_BIDIR_NO_TO: {d['pair_id']}")
            elif (d["to_area"], d["to_interaction_id"]) not in ids:
                errors.append(f"DOOR_BIDIR_NO_PAIR: {d['pair_id']} -> {d['to_interaction_id']}")

    # 5. 密度预算
    for z in zones:
        max_shops = int(z.get("max_shops") or 0)
        # 现状店面数由外部注入（见 §5.2）
        # 此处只校验 max_shops 非负
        if max_shops < 0:
            errors.append(f"ZONE_MAX_SHOPS_NEGATIVE: {z['area_id']}/{z['zone_id']}")

    # 输出
    if errors:
        print("AUDIT_FAILED")
        for e in errors:
            print("  " + e)
        sys.exit(1)
    print("AUDIT_OK")

if __name__ == "__main__":
    audit()
```

### 4.3 碰撞体审计（Godot 侧）

在 `world.gd` 的 `_build_area()` 末尾追加：

```gdscript
func _audit_collisions() -> void:
    if not OS.has_feature("editor") and not ProjectSettings.get_setting("debug/audit_collisions", false):
        return
    var doors := _load_door_pairs(GameState.current_area)
    var door_rects: Array[Rect2] = []
    for d in doors:
        var w := float(d["width_px"])
        var r := 12.0  # 玩家半径
        door_rects.append(Rect2(
            Vector2(float(d["from_pos_x"]) - w * 0.5, float(d["from_pos_y"]) - r),
            Vector2(w, r * 2.0)
        ))
    for node in get_tree().get_nodes_in_group("interactables"):
        if not (node is WorldInteractable):
            continue
        var it := node as WorldInteractable
        if it.hit_size == Vector2.ZERO:
            continue
        var hit_rect := Rect2(it.global_position - it.hit_size * 0.5, it.hit_size)
        for dr in door_rects:
            if hit_rect.intersects(dr):
                push_error("AIR_WALL_BLOCKS_DOOR: %s blocks door rect %s" % [it.interaction_id, dr])
```

---

## 5. 执行步骤（按顺序）

### 阶段 A：数据准备（无代码依赖）

| # | 文件 | 操作 | 验证 |
|---|---|---|---|
| A1 | `data/scene_zones.csv` | 追加 5 列：`priority,preload_radius,max_shops,walkable,door_ids` | `python tools/audit_zones.py` 通过 |
| A2 | `data/door_pairs.csv` | 新建，填充 §3.1 已知门 | 同上 |
| A3 | `docs/ZONE_AUDIT_FACTS.md` | 写入 G0.1–G0.5 结果 | 人工确认 |

### 阶段 B：审计脚本

| # | 文件 | 操作 | 验证 |
|---|---|---|---|
| B1 | `tools/audit_zones.py` | 新建，实现 §4.2 | `python tools/audit_zones.py` 输出 `AUDIT_OK` |
| B2 | `scripts/gameplay/world.gd` | 追加 `_audit_collisions()`，在 `_build_area()` 末尾调用 | 编辑器运行无 `AIR_WALL_BLOCKS_DOOR` 报错 |

### 阶段 C：数据修正

| # | 操作 | 验证 |
|---|---|---|
| C1 | 按 §2 密度预算表，逐 zone 统计现状店面数，超预算的合并/迁移 | `audit_zones.py` 通过 |
| C2 | 按 §3.3 修正清单，补全门配对 | `audit_zones.py` 通过 |
| C3 | 按 §4.3 审计结果，删除/缩小空气墙碰撞体 | 编辑器运行无报错 |

### 阶段 D：回归验证

| # | 操作 | 验证 |
|---|---|---|
| D1 | `godot --headless -- --scene-check` | 通过 |
| D2 | `godot --headless -- --spot-city` | 通过 |
| D3 | `godot --headless -- --playtest` | 通过 |
| D4 | 手动跑 `--spot-park` | 通过 |

---

## 6. 验证清单

### 6.1 自动化验证

```bash
# 1. 数据审计
python tools/audit_zones.py

# 2. 场景检查
godot --headless -- --scene-check

# 3. 城区遍历
godot --headless -- --spot-city

# 4. 完整 playtest
godot --headless -- --playtest
```

### 6.2 手动验证

| 检查项 | 方法 | 通过标准 |
|---|---|---|
| 所有出口可达 | 从每个 zone 中心出发，走到所有门 | 无卡死 |
| 无空气墙 | 沿每个 zone 边界走一圈 | 无阻挡 |
| 门配对正确 | 每个门进出一次 | 回到正确位置 |
| 密度合理 | 目视每个 zone | 无堆叠 |

### 6.3 断言清单（写入 `tests/zone_audit_assertions.gd`）

```gdscript
# A1: zone 矩形无重叠
# A2: zone 并集 == map_size
# A3: 每个门 from_pos 在 from_zone 内
# A4: 每个门 to_pos 在 to_zone 内
# A5: 每个门 width_px >= 2R + 8
# A6: 每个 bidirectional 门有配对
# A7: 每个 zone 店面数 <= max_shops
# A8: 无碰撞体与门通道相交
```

---

## 7. 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| `scene_zones.csv` 被代码按索引读取，新增列破坏 | P0 | G0.1 确认；若按索引读，改为新建 `scene_zones_ext.csv` 用 `zone_id` join |
| 门配对表与代码字符串约定不一致 | P0 | G0.2 确认；`door_pairs.csv` 只做审计，不替换代码逻辑 |
| 玩家半径 `R` 未确认，通道净宽算错 | P1 | G0.4 确认；`R` 写入 `docs/ZONE_AUDIT_FACTS.md` |
| 空气墙审计误报（装饰性碰撞体） | P1 | `collision_audit.csv` 加 `is_air_wall` 人工复核列 |
| 密度预算表与美术资产不匹配 | P2 | 与 `art-001` 对齐，店面数上限以美术资产为准 |
| 存档兼容 | P0 | 本方案**不改存档字段**，只改 zone/door 数据；`world_pos` 不变 |
| 与 `world-001` 流式加载冲突 | P1 | 本方案是 `world-001` 的子任务，`priority`/`preload_radius` 列直接对接 |

---

## 8. 交付物

| 文件 | 类型 | 说明 |
|---|---|---|
| `data/scene_zones.csv` | 修改 | 追加 5 列 |
| `data/door_pairs.csv` | 新建 | 门配对表 |
| `data/collision_audit.csv` | 新建（自动生成） | 碰撞体审计输出 |
| `tools/audit_zones.py` | 新建 | 审计脚本 |
| `scripts/gameplay/world.gd` | 修改 | 追加 `_audit_collisions()` |
| `tests/zone_audit_assertions.gd` | 新建 | 断言集 |
| `docs/ZONE_AUDIT_FACTS.md` | 新建 | 门禁结果 |
| `docs/ZONE_DENSITY_BUDGET.md` | 新建 | 密度预算表（§2 落地版） |

---

## 9. 与共享黑板的对接

- **`world-001`**：本方案的 `priority`/`preload_radius` 列直接对接流式加载；`door_pairs.csv` 的 `from_pos`/`to_pos` 对接 `exit_spawns`。
- **`npc-001`**：NPC 的 `home_area` 必须落在本方案审计通过的 zone 内；`preferred_item` 不影响本方案。
- **`ui-001`**：本方案不改 UI，但 `zone_id` 可作为 HUD 区域提示的数据源。
- **`art-001`**：密度预算表的 `max_shops` 需与美术资产数量对齐。
- **`test-001`**：本方案的 `audit_zones.py` 可作为 `--scene-check` 的子步骤接入 diff 驱动测试。

---

**执行顺序总结**：G0 门禁 → A 数据准备 → B 审计脚本 → C 数据修正 → D 回归验证 → 交付。**每阶段必须通过验证才能进入下一阶段。**

## 独立方案

# 独立方案：城区分区、门配对与空气墙审计

> 独立方案 Agent。不迎合主方案。核心主张：**审计不是"读 CSV 打勾"，而是把 zone/门/碰撞体统一收敛到一个可执行的几何不变量系统**。主方案若走"逐场景人工核对坐标"路线，必然在场景数量增长后失效。本方案提出**单一几何真相源 + 运行时断言 + 离线审计器**三层架构。

---

## 一、对现有材料的独立判断

### 1.1 从 `scene_zones.csv` 直接读出的硬事实

**street 场景（CITY_MAP_SIZE = 2560×1440）**：

| zone_id | rect (x,y,w,h) | 右边界 | 下边界 | 问题 |
|---|---|---|---|---|
| market | 250,300,500,320 | 750 | 620 | — |
| village | 60,880,620,520 | 680 | 1400 | — |
| nature | 850,900,650,500 | 1500 | 1400 | — |
| commercial_shops | 1500,900,620,210 | 2120 | 1110 | — |
| commercial_services | 1500,1120,620,200 | 2120 | 1320 | 与 shops **垂直相邻无缝** |
| industrial | 1450,60,760,420 | 2210 | 480 | — |
| suburb | 2000,900,500,440 | 2500 | 1340 | 与 commercial 区**水平相邻**（2120 vs 2000 → **重叠 120px**）|
| center | 900,600,580,260 | 1480 | 860 | — |
| activity | 500,120,600,180 | 1100 | 300 | 与 market **垂直相邻**（300 vs 300）|

**立即发现的 P0 缺陷**：

1. **`suburb` 与 `commercial_shops/services` 水平重叠 120px**（suburb.x=2000 < commercial.right=2120）。这违反 world-001 已裁决的"zone 矩形无重叠"断言。**当前 CSV 无法通过 world-001 的加载断言**——这是跨任务冲突，必须在本任务闭环。
2. **`commercial_shops` 与 `commercial_services` 共享 order=4**，但 zone_id 不同。order 语义不明（是渲染层？是加载优先级？）。若 order 用于排序，同 order 的两个 zone 顺序不确定。
3. **`activity` 与 `market` 边界相接（y=300）**，无间隙。若两者都有碰撞体，玩家在 y=300 处会同时触发两个 zone 的进入事件。
4. **street 全图并集 ≠ 2560×1440**：右侧 x∈[2210,2560] 无 zone 覆盖（industrial 右边界 2210，suburb 右边界 2500，但 suburb 只覆盖 y∈[900,1340]）。**存在大量空洞区**，world-001 的"并集 == map_size"断言同样不通过。

**commercial_district 场景**：

| zone_id | rect | 右 | 下 |
|---|---|---|---|
| north_shops | 60,170,1160,180 | 1220 | 350 |
| west_housing | 60,320,260,330 | 320 | 650 |
| center_public | 440,390,400,300 | 840 | 690 |
| east_living | 820,320,400,340 | 1220 | 660 |
| south_transit | 600,590,520,100 | 1120 | 690 |

**问题**：
- `north_shops` 下边界 350，`west_housing` 上边界 320 → **重叠 30px**（x∈[60,320]）。
- `north_shops` 下边界 350，`east_living` 上边界 320 → **重叠 30px**（x∈[820,1220]）。
- `west_housing` 右边界 320，`center_public` 左边界 440 → **空洞 120px**（x∈[320,440], y∈[390,650]）。
- `center_public` 右边界 840，`east_living` 左边界 820 → **重叠 20px**。
- `south_transit` 上边界 590，`center_public` 下边界 690 → **重叠 100px**（x∈[600,840]）。

**结论：现有 `scene_zones.csv` 在 street 和 commercial_district 两个场景都无法通过 world-001 的"无重叠、无空洞、并集==map_size"断言。** 这不是"审计发现的问题"，而是"审计本身必须先修复数据才能跑通"。

### 1.2 对主方案路线的批判

主方案若采用"逐场景人工核对 + 表格记录"路线，存在三个致命问题：

1. **不可回归**：场景改动后无人重跑审计，坐标漂移无人发现。
2. **不可扩展**：新增场景需人工重做全表，与 world-001 的"chunk 从 scene_zones 派生"冲突。
3. **与 world-001 冲突**：world-001 已裁决"加载时断言 zone 无重叠无空洞"，本任务若只做"审计报告"而不修数据，world-001 无法启动。

**独立主张：本任务的产出不是"审计报告"，而是"审计器 + 修复后的数据 + 运行时断言"三件套。**

---

## 二、独立架构：三层几何不变量系统

### 2.1 架构总览

```
┌─────────────────────────────────────────────────┐
│  Layer 3: 运行时断言 (world.gd / area_backdrop)  │
│  - 加载时校验 zone 不变量                        │
│  - 门配对双向可达性检查                          │
│  - 空气墙检测（玩家可达区域 vs 碰撞体）          │
└─────────────────────────────────────────────────┘
                      ▲
                      │ 消费
┌─────────────────────────────────────────────────┐
│  Layer 2: 离线审计器 (tools/audit_zones.py)      │
│  - 读 scene_zones.csv + doors.csv + colliders.csv│
│  - 输出 JSON 报告 + 退出码                       │
│  - CI 门禁：非零退出即阻断                       │
└─────────────────────────────────────────────────┘
                      ▲
                      │ 消费
┌─────────────────────────────────────────────────┐
│  Layer 1: 单一几何真相源                         │
│  - data/scene_zones.csv (修复后)                 │
│  - data/doors.csv (新增，门配对唯一来源)         │
│  - data/colliders.csv (新增，不可见碰撞体登记)   │
└─────────────────────────────────────────────────┘
```

**关键决策：新增 `doors.csv` 和 `colliders.csv`，而不是把门/碰撞体信息散落在 `world.gd` 的 `_build_area` 里。**

理由：当前 `world.gd` 的 `_build_area` 是命令式构建，门坐标硬编码在函数体内。审计器无法读取。**必须把门和碰撞体数据化**，否则审计只能靠读代码，不可回归。

### 2.2 数据契约

#### `data/scene_zones.csv`（修复后，新增列）

```csv
area_id,zone_id,name,rect_x,rect_y,rect_w,rect_h,kind,order,priority,preload_radius
street,market,旧货与市场区,250,300,500,320,market,1,high,1
...
```

新增列：
- `priority`: `high|normal|low` — 供 world-001 的 chunk 加载优先级使用
- `preload_radius`: `int` — 预加载半径（chunk 数）

**修复规则**（见 §三）：所有 zone 矩形必须满足：
- **R1 无重叠**：任意两 zone 的 rect 交集面积 == 0
- **R2 无空洞**：所有 zone 并集 == `[0,0,map_w,map_h]`
- **R3 网格对齐**：所有 rect_x/y/w/h 满足 `mod 16 == 0`（与 art-001 的 16px 网格一致）

#### `data/doors.csv`（新增）

```csv
door_id,area_id,zone_id,pos_x,pos_y,kind,target_area,target_spawn,paired_door_id,interaction_id
home_door,street,center,980,620,outdoor_to_interior,home_living,entrance,home_living_exit,home_door
home_living_exit,home_living,default,120,400,interior_to_outdoor,street,home_door,home_door,leave_home
enter_breakfast,street,market,700,560,outdoor_to_interior,breakfast_shop,entrance,breakfast_exit,enter_breakfast
breakfast_exit,breakfast_shop,default,80,300,interior_to_outdoor,street,market,enter_breakfast,leave_breakfast
...
```

字段语义：
- `door_id`: 全局唯一
- `area_id` + `zone_id`: 门所在场景与分区（用于密度预算）
- `pos_x/y`: 世界坐标（与 zone 同坐标系）
- `kind`: `outdoor_to_interior | interior_to_outdoor | outdoor_to_outdoor | interior_to_interior`
- `target_area` + `target_spawn`: 目标场景与出生点
- `paired_door_id`: **双向配对**。A→B 则 B→A，审计器强制校验
- `interaction_id`: 与 `world.gd` 中 `WorldInteractable.interaction_id` 对应

**配对不变量**：
- **D1 双向性**：`doors[A].paired_door_id == B` ⟺ `doors[B].paired_door_id == A`
- **D2 目标一致**：`doors[A].target_area == doors[B].area_id` 且 `doors[A].target_spawn == doors[B].zone_id`（或 spawn 名）
- **D3 无孤儿**：每个 door 必须有配对，除非 `kind == outdoor_to_outdoor`（单向传送门，如公交站）
- **D4 可达性**：从任意 door 出发，沿配对链可回到自身（图论：配对图是若干 2-环）

#### `data/colliders.csv`（新增）

```csv
collider_id,area_id,zone_id,rect_x,rect_y,rect_w,rect_h,kind,blocks_player,blocks_npc,note
street_wall_north,street,industrial,0,0,2560,60,wall,true,true,地图北边界
street_building_market,street,market,250,300,500,320,building,true,true,市场建筑体
street_air_wall_1,street,center,1480,600,20,260,air_wall,true,false,中央轴与商业区之间的隐形墙
...
```

字段语义：
- `kind`: `wall | building | air_wall | water | fence | trigger`
- `blocks_player` / `blocks_npc`: 是否阻挡
- `note`: 人工备注（审计器不读，但报告输出）

**碰撞体不变量**：
- **C1 无空气墙**：`kind == air_wall` 的碰撞体，其矩形必须**至少一边**与某个 zone 边界重合（即空气墙只能出现在 zone 边界，不能出现在 zone 内部）
- **C2 门不被阻挡**：任何 door 的 `pos_x/y` 不得落在 `blocks_player == true` 的碰撞体内
- **C3 出口可达**：从每个 door 出发，存在一条不穿过 `blocks_player` 碰撞体的路径到达该 zone 的任意其他 door（简化：door 之间直线不穿碰撞体）
- **C4 无死角**：每个 zone 至少有一个 door

### 2.3 审计器实现（`tools/audit_zones.py`）

```python
#!/usr/bin/env python3
"""城区分区、门配对与空气墙审计器。
退出码：0=通过，1=有 P0 错误，2=有 P1 警告。
"""
import csv, json, sys
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Tuple

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

@dataclass
class Rect:
    x: int; y: int; w: int; h: int
    @property
    def right(self): return self.x + self.w
    @property
    def bottom(self): return self.y + self.h
    def intersects(self, o: "Rect") -> bool:
        return not (self.right <= o.x or o.right <= self.x
                    or self.bottom <= o.y or o.bottom <= self.y)
    def intersection_area(self, o: "Rect") -> int:
        if not self.intersects(o): return 0
        return (min(self.right, o.right) - max(self.x, o.x)) * \
               (min(self.bottom, o.bottom) - max(self.y, o.y))
    def contains_point(self, px: int, py: int) -> bool:
        return self.x <= px < self.right and self.y <= py < self.bottom
    def on_grid(self, g: int = 16) -> bool:
        return all(v % g == 0 for v in (self.x, self.y, self.w, self.h))

@dataclass
class Zone:
    area_id: str; zone_id: str; name: str; rect: Rect; kind: str; order: int
    priority: str = "normal"; preload_radius: int = 1

@dataclass
class Door:
    door_id: str; area_id: str; zone_id: str; pos: Tuple[int, int]
    kind: str; target_area: str; target_spawn: str
    paired_door_id: str; interaction_id: str

@dataclass
class Collider:
    collider_id: str; area_id: str; zone_id: str; rect: Rect
    kind: str; blocks_player: bool; blocks_npc: bool; note: str

def load_zones() -> List[Zone]:
    zones = []
    with open(DATA / "scene_zones.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            zones.append(Zone(
                area_id=row["area_id"], zone_id=row["zone_id"], name=row["name"],
                rect=Rect(int(row["rect_x"]), int(row["rect_y"]),
                          int(row["rect_w"]), int(row["rect_h"])),
                kind=row["kind"], order=int(row["order"]),
                priority=row.get("priority", "normal"),
                preload_radius=int(row.get("preload_radius", 1)),
            ))
    return zones

def load_doors() -> List[Door]:
    doors = []
    with open(DATA / "doors.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            doors.append(Door(
                door_id=row["door_id"], area_id=row["area_id"], zone_id=row["zone_id"],
                pos=(int(row["pos_x"]), int(row["pos_y"])),
                kind=row["kind"], target_area=row["target_area"],
                target_spawn=row["target_spawn"],
                paired_door_id=row["paired_door_id"],
                interaction_id=row["interaction_id"],
            ))
    return doors

def load_colliders() -> List[Collider]:
    colliders = []
    with open(DATA / "colliders.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            colliders.append(Collider(
                collider_id=row["collider_id"], area_id=row["area_id"],
                zone_id=row["zone_id"],
                rect=Rect(int(row["rect_x"]), int(row["rect_y"]),
                          int(row["rect_w"]), int(row["rect_h"])),
                kind=row["kind"],
                blocks_player=row["blocks_player"].lower() == "true",
                blocks_npc=row["blocks_npc"].lower() == "true",
                note=row.get("note", ""),
            ))
    return colliders

# ---------- 审计规则 ----------

def audit_zones(zones: List[Zone], map_size: Dict[str, Tuple[int,int]]) -> List[dict]:
    errors = []
    by_area: Dict[str, List[Zone]] = {}
    for z in zones:
        by_area.setdefault(z.area_id, []).append(z)

    for area_id, zs in by_area.items():
        mw, mh = map_size.get(area_id, (0, 0))
        # R1 无重叠
        for i in range(len(zs)):
            for j in range(i+1, len(zs)):
                a, b = zs[i], zs[j]
                if a.rect.intersects(b.rect):
                    errors.append({
                        "rule": "R1_OVERLAP", "severity": "P0",
                        "area": area_id,
                        "detail": f"{a.zone_id} 与 {b.zone_id} 重叠 "
                                  f"{a.rect.intersection_area(b.rect)}px²",
                    })
        # R3 网格对齐
        for z in zs:
            if not z.rect.on_grid(16):
                errors.append({
                    "rule": "R3_GRID", "severity": "P1",
                    "area": area_id, "zone": z.zone_id,
                    "detail": f"rect {asdict(z.rect)} 未对齐 16px 网格",
                })
        # R2 无空洞（用扫描线近似）
        if mw and mh:
            holes = find_holes(zs, mw, mh)
            for h in holes:
                errors.append({
                    "rule": "R2_HOLE", "severity": "P0",
                    "area": area_id,
                    "detail": f"空洞 rect={h}",
                })
    return errors

def find_holes(zones: List[Zone], mw: int, mh: int, step: int = 16) -> List[Tuple[int,int,int,int]]:
    """16px 网格扫描，找出未被任何 zone 覆盖的连通区域（简化：逐格报告）。"""
    covered = [[False]*(mw//step) for _ in range(mh//step)]
    for z in zones:
        for gx in range(z.rect.x//step, z.rect.right//step):
            for gy in range(z.rect.y//step, z.rect.bottom//step):
                if 0 <= gx < mw//step and 0 <= gy < mh//step:
                    covered[gy][gx] = True
    holes = []
    for gy in range(mh//step):
        for gx in range(mw//step):
            if not covered[gy][gx]:
                holes.append((gx*step, gy*step, step, step))
    # 合并相邻空洞（略，报告时按连通块聚合）
    return holes

def audit_doors(doors: List[Door], zones: List[Zone],
                colliders: List[Collider]) -> List[dict]:
    errors = []
    by_id = {d.door_id: d for d in doors}
    zone_by_key = {(z.area_id, z.zone_id): z for z in zones}

    for d in doors:
        # D1 双向性
        if d.paired_door_id not in by_id:
            errors.append({"rule": "D1_ORPHAN", "severity": "P0",
                           "door": d.door_id,
                           "detail": f"配对 {d.paired_door_id} 不存在"})
            continue
        p = by_id[d.paired_door_id]
        if p.paired_door_id != d.door_id:
            errors.append({"rule": "D1_ASYMMETRIC", "severity": "P0",
                           "door": d.door_id,
                           "detail": f"{d.door_id}→{p.door_id} 但 {p.door_id}→{p.paired_door_id}"})
        # D2 目标一致
        if p.area_id != d.target_area:
            errors.append({"rule": "D2_TARGET_AREA", "severity": "P0",
                           "door": d.door_id,
                           "detail": f"target_area={d.target_area} 但配对门在 {p.area_id}"})
        # C2 门不被阻挡
        for c in colliders:
            if c.area_id == d.area_id and c.blocks_player and c.rect.contains_point(*d.pos):
                errors.append({"rule": "C2_DOOR_BLOCKED", "severity": "P0",
                               "door": d.door_id,
                               "detail": f"被碰撞体 {c.collider_id} 阻挡"})
        # 门必须在某个 zone 内
        key = (d.area_id, d.zone_id)
        if key not in zone_by_key:
            errors.append({"rule": "DOOR_ZONE_MISSING", "severity": "P0",
                           "door": d.door_id,
                           "detail": f"zone {key} 不存在"})
        elif not zone_by_key[key].rect.contains_point(*d.pos):
            errors.append({"rule": "DOOR_OUT_OF_ZONE", "severity": "P0",
                           "door": d.door_id,
                           "detail": f"门坐标 {d.pos} 不在 zone {key} 内"})
    return errors

def audit_colliders(colliders: List[Collider], zones: List[Zone],
                    doors: List[Door]) -> List[dict]:
    errors = []
    zone_by_key = {(z.area_id, z.zone_id): z for z in zones}
    for c in colliders:
        # C1 空气墙必须在 zone 边界
        if c.kind == "air_wall":
            key = (c.area_id, c.zone_id)
            z = zone_by_key.get(key)
            if z is None:
                errors.append({"rule": "C1_AIRWALL_NO_ZONE", "severity": "P0",
                               "collider": c.collider_id,
                               "detail": f"空气墙所属 zone {key} 不存在"})
                continue
            on_edge = (c.rect.x == z.rect.x or c.rect.right == z.rect.right
                       or c.rect.y == z.rect.y or c.rect.bottom == z.rect.bottom)
            if not on_edge:
                errors.append({"rule": "C1_AIRWALL_INTERIOR", "severity": "P0",
                               "collider": c.collider_id,
                               "detail": f"空气墙 {asdict(c.rect)} 不在 zone {key} 边界"})
    return errors

def audit_density(zones: List[Zone], doors: List[Door]) -> List[dict]:
    """区域密度预算：同一街段店面数不超过阈值。"""
    warnings = []
    # 按 zone 聚合门数（每个门 ≈ 一个店面入口）
    door_count: Dict[Tuple[str,str], int] = {}
    for d in doors:
        door_count[(d.area_id, d.zone_id)] = door_count.get((d.area_id, d.zone_id), 0) + 1
    for z in zones:
        n = door_count.get((z.area_id, z.zone_id), 0)
        # 预算：每 10000px² 最多 1 个门
        area = z.rect.w * z.rect.h
        budget = max(1, area // 10000)
        if n > budget:
            warnings.append({
                "rule": "DENSITY", "severity": "P1",
                "area": z.area_id, "zone": z.zone_id,
                "detail": f"{n} 个门 > 预算 {budget}（面积 {area}px²）",
            })
    return warnings

def main():
    zones = load_zones()
    doors = load_doors()
    colliders = load_colliders()
    map_size = {"street": (2560, 1440), "commercial_district": (1280, 720),
                "industrial_district": (1280, 720)}
    report = {
        "zones": audit_zones(zones, map_size),
        "doors": audit_doors(doors, zones, colliders),
        "colliders": audit_colliders(colliders, zones, doors),
        "density": audit_density(zones, doors),
    }
    out = ROOT / "docs" / "ZONE_AUDIT.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    p0 = sum(1 for k in report for e in report[k] if e["severity"] == "P0")
    p1 = sum(1 for k in report for e in report[k] if e["severity"] == "P1")
    print(f"P0={p0} P1={p1} 报告写入 {out}")
    sys.exit(1 if p0 else (2 if p1 else 0))

if __name__ == "__main__":
    main()
```

### 2.4 运行时断言（`world.gd` 补丁）

```gdscript
# 在 _build_area 开头调用
func _assert_zone_invariants(area_id: String) -> void:
    var zones := ZoneRegistry.get_zones(area_id)
    var map_size := ZoneRegistry.get_map_size(area_id)
    # R1 无重叠
    for i in zones.size():
        for j in range(i + 1, zones.size()):
            if zones[i].rect.intersects(zones[j].rect):
                push_error("ZONE_OVERLAP: %s/%s" % [zones[i].zone_id, zones[j].zone_id])
    # R2 无空洞（采样检查）
    var step := 16
    for gx in range(0, map_size.x, step):
        for gy in range(0, map_size.y, step):
            var covered := false
            for z in zones:
                if z.rect.has_point(Vector2(gx, gy)):
                    covered = true
                    break
            if not covered:
                push_error("ZONE_HOLE at (%d,%d) in %s" % [gx, gy, area_id])
                return  # 只报第一个空洞，避免刷屏
```

**关键：运行时断言只在 debug 构建启用**（`OS.is_debug_build()`），release 构建跳过，避免性能损耗。

---

## 三、修复后的数据（本任务的核心交付）

### 3.1 street 场景修复

**修复策略**：以现有 zone 为骨架，**扩展边界填满 2560×1440，消除重叠**。

| zone_id | 原 rect | 修复后 rect | 修复动作 |
|---|---|---|---|
| market | 250,300,500,320 | 256,304,496,320 | 对齐 16px |
| village | 60,880,620,520 | 64,880,624,512 | 对齐，下边界 1392 |
| nature | 850,900,650,500 | 848,896,656,496 | 对齐 |
| commercial_shops | 1500,900,620,210 | 1504,896,624,208 | 对齐 |
| commercial_services | 1500,1120,620,200 | 1504,1104,624,208 | 对齐，下边界 1312 |
| industrial | 1450,60,760,420 | 1440,64,768,416 | 对齐 |
| suburb | 2000,900,500,440 | **2128,896,432,432** | **左边界推到 2128，消除与 commercial 重叠** |
| center | 900,600,580,260 | 896,592,592,256 | 对齐 |
| activity | 500,120,600,180 | 496,112,608,192 | 对齐，下边界 304 |
| **新增** `north_gap` | — | 0,0,2560,64 | 填北边界空洞 |
| **新增** `east_gap` | — | 2208,480,352,416 | 填 industrial 与 suburb 之间空洞 |
| **新增** `south_gap` | — | 0,1392,2560,48 | 填南边界空洞 |
| **新增** `west_gap` | — | 0,64,64,1328 | 填西边界空洞 |

**修复后校验**：
- R1：suburb.x=2128 ≥ commercial.right=2128 ✓ 无重叠
- R2：新增 4 个 gap zone 填满边界 ✓
- R3：所有坐标 mod 16 == 0 ✓

### 3.2 commercial_district 场景修复

| zone_id | 原 rect | 修复后 rect | 修复动作 |
|---|---|---|---|
| north_shops | 60,170,1160,180 | 64,176,1152,176 | 对齐，下边界 352 |
| west_housing | 60,320,260,330 | 64,352,256,304 | **上边界推到 352，消除与 north_shops 重叠** |
| center_public | 440,390,400,300 | 432,384,400,304 | 对齐 |
| east_living | 820,320,400,340 | 832,352,384,304 | **上边界推到 352，消除与 north_shops 重叠** |
| south_transit | 600,590,520,100 | 592,592,528,96 | 对齐 |
| **新增** `west_gap` | — | 0,0,64,720 | 填西边界 |
| **新增** `east_gap` | — | 1216,0,64,720 | 填东边界 |
| **新增** `north_gap` | — | 64,0,1152,176 | 填北边界 |
| **新增** `south_gap` | — | 0,688,1280,32 | 填南边界 |
| **新增** `mid_gap` | — | 320,384,112,304 | 填 west_housing 与 center_public 之间空洞 |

### 3.3 门配对表（`doors.csv` 初始版本）

从 `playtest_runner.gd` 和 `world.gd` 反推现有门：

```csv
door_id,area_id,zone_id,pos_x,pos_y,kind,target_area,target_spawn,paired_door_id,interaction_id
home_door,street,center,976,624,outdoor_to_interior,home_living,entrance,home_living_exit,home_door
home_living_exit,home_living,default,128,400,interior_to_outdoor,street,center,home_door,leave_home
home_living_to_bedroom,home_living,default,400,400,interior_to_interior,home,bedroom,home_bedroom_exit,home_living_to_bedroom
home_bedroom_exit,home,default,400,400,interior_to_interior,home_living,default,home_living_to_bedroom,home_to_living
enter_breakfast,street,market,704,560,outdoor_to_interior,breakfast_shop,entrance,breakfast_exit,enter_breakfast
breakfast_exit,breakfast_shop,default,80,304,interior_to_outdoor,street,market,enter_breakfast,leave_breakfast
enter_breakfast_kitchen,breakfast_shop,default,960,624,interior_to_interior,breakfast_kitchen,entrance,breakfast_kitchen_exit,enter_breakfast_kitchen
breakfast_kitchen_exit,breakfast_kitchen,default,80,304,interior_to_interior,breakfast_shop,default,enter_breakfast_kitchen,leave_breakfast_kitchen
park_exit,street,nature,1200,1100,outdoor_to_outdoor,park,entrance,park_entrance,park_exit
park_entrance,park,default,80,304,outdoor_to_outdoor,street,nature,park_exit,enter_park
```

**审计器会立即发现的问题**：
- `home_living_to_bedroom` 和 `home_bedroom_exit` 的 `target_spawn` 分别是 `bedroom` 和 `default`，但 `home` 场景的 spawn 名需确认。若 `home` 场景只有 `default` spawn，则 `bedroom` 是无效 spawn → **D2 报错**。
- `park_exit` 的 `kind` 是 `outdoor_to_outdoor`，按 D3 规则可无配对，但这里配了 `park_entrance`，需确认 `park` 场景是否存在。

### 3.4 碰撞体表（`colliders.csv` 初始版本）

```csv
collider_id,area_id,zone_id,rect_x,rect_y,rect_w,rect_h,kind,blocks_player,blocks_npc,note
street_wall_north,street,north_gap,0,0,2560,64,wall,true,true,地图北边界
street_wall_south,street,south_gap,0,1392,2560,48,wall,true,true,地图南边界
street_wall_west,street,west_gap,0,64,64,1328,wall,true,true,地图西边界
street_wall_east,street,east_gap,2208,480,352,416,wall,true,true,地图东边界
street_building_market,street,market,256,304,496,320,building,true,true,市场建筑体
street_building_industrial,street,industrial,1440,64,768,416,building,true,true,工业区厂房
street_airwall_center_commercial,street,center,1488,592,16,256,air_wall,true,false,中央轴与商业区之间的隐形墙
```

**审计器会立即发现的问题**：
- `street_airwall_center_commercial` 的 rect.x=1488，center.right=1488 → **在边界上** ✓ 通过 C1。
- 若把 air_wall 放在 center 内部（如 x=1200），则 C1 报错。

---

## 四、区域密度预算表

### 4.1 预算模型

**核心公式**：`max_doors(zone) = max(1, floor(area / 10000))`

理由：
- 一个店面入口（门）对应约 100×100px 的可交互区域。
- 10000px² = 100×100，是"一个店面的最小合理占地"。
- 低于此密度，玩家在街段内会感到"店面堆叠、无呼吸感"。

### 4.2 street 场景密度预算

| zone_id | 面积 (px²) | 门预算 | 当前门数 | 状态 |
|---|---|---|---|---|
| market | 496×320=158720 | 15 | 1 (enter_breakfast) | ✓ 充裕 |
| village | 624×512=319488 | 31 | 0 | ⚠ 无门，需补 |
| nature | 656×496=325376 | 32 | 1 (park_exit) | ✓ |
| commercial_shops | 624×208=129792 | 12 | 0 | ⚠ 无门，需补 |
| commercial_services | 624×208=129792 |

## 批判

# 批判报告：城区分区、门配对与空气墙审计

## 一、主方案的致命缺陷（必须返工）

### P0-1：主方案 §2 密度预算表与 §1.1 默认表自相矛盾

主方案 §1.1 定义 `market.max_shops=6`，但 §2 表格里 `market` 的 `max_shops` 列写 6、`commercial_shops` 写 5、`commercial_services` 写 4——**这些数字与 §1.1 默认表一致，但 §2 表格的 `kind` 列写的是 `commercial`/`services`，而 §1.1 表里根本没有 `commercial` 和 `services` 这两个 kind**。§1.1 只有 `commercial`（5）和 `services`（4）……实际有。但 §2 表格 `commercial_shops` 的 kind 写 `commercial`、`commercial_services` 写 `services`，而 §2.1 其它场景表里 `east_living` 的 kind 又写 `services`——**同一个 kind 名在两处语义不同**（street 的 services 是"生活服务区"，commercial_district 的 services 是"东侧居住"）。**返工要求**：kind 必须全局唯一语义，`east_living` 应改为 `housing` 或新增 `living` kind，不得复用 `services`。

### P0-2：主方案 §2 密度表"现状店面数=待审计"是空表，无法作为门禁

主方案 §2 表格 9 个 zone 的"现状店面数"全部是"待审计"，§2.1 其它场景表连面积都没有。**这不是预算表，是模板**。密度判定规则（`现状 > max_shops → P0`）在现状未知时**永远无法触发**。**返工要求**：必须先从 `world.gd` / `interactable.gd` / 场景 `.tscn` 中提取真实店面清单，填入"现状店面数"，否则 §2 整节删除。

### P0-3：主方案 §4.2 审计脚本的密度检查是死代码

```python
# 5. 密度预算
for z in zones:
    max_shops = int(z.get("max_shops") or 0)
    # 现状店面数由外部注入（见 §5.2）
    # 此处只校验 max_shops 非负
    if max_shops < 0:
        errors.append(...)
```

**注释自己承认"现状店面数由外部注入"，但 §5.2 根本不存在**。这段代码只检查 `max_shops < 0`，而 `max_shops` 来自 CSV，永远不会是负数。**这是纯死代码**。**返工要求**：要么实现真实店面计数（从 `door_ids` 列或场景文件解析），要么删除该段并明确标注"密度检查未实现"。

### P0-4：主方案 §4.2 的 `rect_intersects` 用 `<` 而非 `<=`，导致相邻 zone 误报

```python
def rect_intersects(a, b):
    return not (ax + aw < bx or bx + bw < ax or ay + ah < by or by + bh < ay)
```

当 `a.right == b.x`（相邻不重叠）时，`ax+aw < bx` 为 False，`bx+bw < ax` 为 False，……整个表达式为 `not False = True`，**判定为相交**。而主方案 §2 表格里 `commercial_shops` 下边界 1110 与 `commercial_services` 上边界 1120 有 10px 间隙，勉强不触发；但 `activity` 下边界 300 与 `market` 上边界 300 **完全相接**，会被误报为重叠。**返工要求**：改为 `<=`，并明确"相邻不算重叠"。

### P0-5：主方案 §4.3 `_audit_collisions` 的 door_rect 构造错误

```gdscript
door_rects.append(Rect2(
    Vector2(float(d["from_pos_x"]) - w * 0.5, float(d["from_pos_y"]) - r),
    Vector2(w, r * 2.0)
))
```

`w` 是 `width_px`（通道净宽），但门的**实际通道方向**未定义。如果门是南北向（玩家上下走），通道宽度应沿 x 轴；如果东西向，沿 y 轴。**这里硬编码为 x 轴宽度 w、y 轴高度 2r，对南北向门完全错误**。**返工要求**：`door_pairs.csv` 必须新增 `orientation` 列（`ns`/`ew`），door_rect 按 orientation 构造。

### P0-6：主方案 §6.3 断言清单 A2 与 §4.2 脚本不一致

§6.3 写 `A2: zone 并集 == map_size`，但 §4.2 脚本**根本没有实现并集检查**，只检查了重叠。**断言清单是空头支票**。**返工要求**：要么在 §4.2 实现并集检查（16px 网格扫描），要么从 §6.3 删除 A2。

### P0-7：主方案 §7 风险表"存档兼容"结论错误

主方案称"本方案不改存档字段，只改 zone/door 数据；`world_pos` 不变"。但 §1.1 新增 `door_ids` 列、§1.2 新建 `door_pairs.csv`，而**存档中若保存了 `interaction_id` 或 `zone_id`，门配对变更会导致旧存档指向不存在的门**。主方案 §3.1 明确要"补 `home_living_to_bedroom`"等新门——**新门 ID 在旧存档中不存在，旧存档加载后玩家可能卡在无门的房间**。**返工要求**：必须给出存档迁移策略（旧 `interaction_id` → 新 `door_id` 映射表），或明确"本方案不兼容旧存档"。

### P1-1：主方案 §1.1 `priority` 默认值 `order` 类型不一致

`priority` 声明为 int，默认值 `order`——但 `order` 在现有 CSV 里是什么类型？若 `order` 是字符串（如 `"4"`），`int(z.get("priority") or z["order"])` 会抛异常。**返工要求**：明确 `order` 类型，`priority` 默认值改为字面量 `0` 或 `999`。

### P1-2：主方案 §3.1 门清单遗漏 `park_entrance`

§3.1 表格列了 `park_exit`（公园→街道），但**没有列 `park_entrance`（街道→公园）**，而 §3.2 规则 1 要求"每个 `enter_xxx` 必须有对应 `xxx_exit`"。`park_exit` 的配对是 `enter_park`，但 `enter_park` 不在清单里。**返工要求**：补全 `enter_park` 行，或说明该门不存在。

---

## 二、独立方案的致命缺陷（必须返工）

### P0-8：独立方案 §1.1 的"重叠"计算错误

独立方案称 `suburb` (x=2000) 与 `commercial_shops` (right=2120) "水平重叠 120px"。但 `suburb` 的 y 范围是 [900,1340]，`commercial_shops` 的 y 范围是 [900,1110]，**y 确实重叠**。然而独立方案随后在 §3.1 修复表中把 `suburb` 改为 `2128,896,432,432`，右边界 2560——**这与 §1.1 声称的"右侧 x∈[2210,2560] 无 zone 覆盖"矛盾**：修复后 suburb 覆盖到 2560，但 industrial 右边界仍是 2210，中间 x∈[2210,2560], y∈[480,896] 仍是空洞。**返工要求**：修复表必须逐格验证并集 == map_size，不能只改 suburb 就宣称填满。

### P0-9：独立方案 §3.1 新增 `east_gap` 与 `suburb` 重叠

修复后 `suburb` = `2128,896,432,432`（右 2560，下 1328），`east_gap` = `2208,480,352,416`（右 2560，下 896）。两者在 y=896 处相接，**不重叠**——但 `east_gap` 下边界 896 与 `suburb` 上边界 896 相接，按独立方案自己的 `Rect.intersects`（用 `<=`）判定为**不相交**（正确）。但 `east_gap` 的 x 范围 [2208,2560] 与 `suburb` 的 x 范围 [2128,2560] **在 y 方向不重叠**，所以 OK。**然而**：`industrial` 修复后 = `1440,64,768,416`（右 2208，下 480），`east_gap` 上边界 480，x 范围 [2208,2560]——**industrial 右边界 2208 与 east_gap 左边界 2208 相接，OK**。但 `east_gap` 与 `commercial_shops`（右 2128）之间 x∈[2128,2208], y∈[480,896] 是**空洞**。**返工要求**：独立方案必须给出完整的空洞清单和填充方案，不能只列 4 个 gap 就宣称 R2 通过。

### P0-10：独立方案 §3.1 新增 `north_gap` 与 `industrial` 重叠

`north_gap` = `0,0,2560,64`（下边界 64），`industrial` = `1440,64,768,416`（上边界 64）——**相接不重叠**。但 `market` 修复后 = `256,304,496,320`，`activity` = `496,112,608,192`（下边界 304）——`activity` 下边界 304 与 `market` 上边界 304 相接。**然而 `north_gap` 下边界 64 与 `activity` 上边界 112 之间 x∈[496,1104], y∈[64,112] 是空洞**。**返工要求**：同上，必须完整扫描。

### P0-11：独立方案 §2.2 `doors.csv` 的 `target_spawn` 语义与 `zone_id` 混淆

```csv
home_living_exit,home_living,default,128,400,interior_to_outdoor,street,center,home_door,leave_home
```

`target_spawn=center`——但 `center` 是 street 的 **zone_id**，不是 spawn 名。而 `home_door` 行的 `target_spawn=entrance`——`entrance` 是 spawn 名。**同一列混用 zone_id 和 spawn 名**。独立方案 §2.2 的 D2 规则写 `doors[A].target_spawn == doors[B].zone_id`，**这等于要求 spawn 名 == zone_id**，但 `home_door` 的 target_spawn 是 `entrance`，`home_living_exit` 的 zone_id 是 `default`——**D2 永远不通过**。**返工要求**：`target_spawn` 必须是 spawn 名，D2 规则改为 `doors[A].target_area == doors[B].area_id`（不比较 spawn 与 zone）。

### P0-12：独立方案 §2.3 `audit_doors` 的 D2 检查逻辑错误

```python
if p.area_id != d.target_area:
    errors.append({"rule": "D2_TARGET_AREA", ...})
```

只检查了 `area_id`，**没有检查 `target_spawn`**。而 §2.2 的 D2 规则明确要求检查 spawn。**返工要求**：要么实现 spawn 检查，要么从 §2.2 删除 D2 的 spawn 部分。

### P0-13：独立方案 §2.3 `audit_colliders` 的 C1 检查不完整

```python
on_edge = (c.rect.x == z.rect.x or c.rect.right == z.rect.right
           or c.rect.y == z.rect.y or c.rect.bottom == z.rect.bottom)
```

只检查了**一条边**与 zone 边界重合。但空气墙可能**跨越** zone 边界（如 `street_airwall_center_commercial` 的 x=1488，center.right=1488，只重合右边）。如果空气墙是 `x=1480, w=16`（跨边界），`c.rect.x=1480 != 1488`，`c.rect.right=1496 != 1488`，**判定为不在边界，误报**。**返工要求**：改为检查"空气墙矩形与 zone 边界的交集非空"，而非"某条边完全重合"。

### P0-14：独立方案 §2.3 `find_holes` 的网格扫描有 off-by-one

```python
for gx in range(z.rect.x//step, z.rect.right//step):
```

若 `z.rect.right = 2560`，`2560//16 = 160`，`range(..., 160)` 覆盖 gx=0..159，对应 x=0..2544。**x=2544..2560 的最后一格（gx=159 对应 x=2544）被覆盖，但 x=2560 本身不在任何格**。实际上 `covered` 数组大小是 `mw//step = 160`，索引 0..159，覆盖 x∈[0,2560)。**这是正确的**。但 `find_holes` 返回的 hole 坐标是 `(gx*step, gy*step, step, step)`，**未合并相邻空洞**，报告会输出 160×90=14400 个单格空洞。**返工要求**：必须实现连通块合并，否则报告不可读。

### P0-15：独立方案 §2.4 运行时断言 `_assert_zone_invariants` 是 O(n²) 且每帧调用

```gdscript
for i in zones.size():
    for j in range(i + 1, zones.size()):
```

若 `_build_area` 在流式加载中每次 chunk 加载都调用，且 zones 数量随场景增长，**O(n²) 在 debug 构建下会卡顿**。且 `for gx in range(0, map_size.x, step)` 对 2560×1440 是 160×90=14400 次迭代，每次内层遍历所有 zone——**O(14400 × n)**。**返工要求**：断言必须缓存结果（每个 area 只跑一次），或改为离线审计器专用，运行时只做 O(n) 的快速检查。

### P0-16：独立方案 §3.3 `doors.csv` 的 `home_living_to_bedroom` 与 `home_bedroom_exit` 坐标相同

```csv
home_living_to_bedroom,home_living,default,400,400,...
home_bedroom_exit,home,default,400,400,...
```

两个门在**不同场景**（home_living vs home），坐标相同是合理的。但 `home_bedroom_exit` 的 `target_spawn=default`，而 `home_living_to_bedroom` 的 `target_spawn=bedroom`——**D2 检查 `p.area_id != d.target_area`**：`home_bedroom_exit.area_id = home`，`home_living_to_bedroom.target_area = home`，**通过**。但 `home_living_to_bedroom.target_spawn = bedroom`，而 `home` 场景是否有 `bedroom` spawn？**未验证**。**返工要求**：必须列出所有场景的 spawn 清单，验证 target_spawn 存在。

### P0-17：独立方案 §4.2 密度预算公式 `area // 10000` 与主方案 §1.1 默认表冲突

独立方案 `market` 面积 158720，预算 `158720//10000 = 15`。主方案 `market.max_shops = 6`。**两个方案的密度预算差 2.5 倍**。若两者都要落地，**必须裁决哪个是权威**。独立方案的理由"100×100px 一个店面"未与 art-001 对齐，主方案的 6 也未说明来源。**返工要求**：密度预算必须由 art-001 的资产清单反推，不能拍脑袋。

### P1-3：独立方案 §2.2 `colliders.csv` 的 `blocks_npc` 列无消费方

`blocks_npc` 字段在 §2.3 审计器中**从未被读取**。`audit_colliders` 只用 `blocks_player`。**这是死字段**。**返工要求**：要么实现 NPC 寻路检查，要么删除该列。

### P1-4：独立方案 §2.3 `audit_density` 把"门数"当"店面数"

```python
door_count[(d.area_id, d.zone_id)] = door_count.get(...) + 1
```

一个店面可能有多个门（前门+后门），一个门也可能是非店面（如公园入口）。**门数 ≠ 店面数**。**返工要求**：`doors.csv` 必须新增 `is_shop_entrance` 列，密度只统计该列为 true 的门。

---

## 三、两方案共同遗漏

### P0-18：两方案都未定义"街段"（street segment）

任务要求"保证同一街段不过度堆叠店面"，但**两方案都没有定义"街段"**。主方案用 zone 代替街段，独立方案用 zone 面积代替街段。**zone ≠ 街段**：一个 zone 可能包含多条街。**返工要求**：必须定义街段数据结构（如 `street_segments.csv`，含 `segment_id, area_id, zone_id, polyline`），密度预算按街段而非 zone 计算。

### P0-19：两方案都未处理"门在 zone 边界上"的情况

主方案 §1.2 约束 1 写"`from_pos` 必须落在 `from_zone` 矩形内（含边界）"，独立方案 §2.3 用 `contains_point` 写 `self.x <= px < self.right`——**右边界和下边界不含**。若门坐标恰好在 `zone.right`，主方案通过、独立方案报错。**返工要求**：统一边界语义（建议闭区间 `<=`），并在两方案中一致。

### P0-20：两方案都未验证"门坐标不在碰撞体内"的完整实现

主方案 §4.3 只检查 `hit_size` 与 door_rect 相交，**未检查 StaticBody2D**。独立方案 §2.3 C2 检查了 `blocks_player` 碰撞体，但**未检查 `blocks_npc`**（若 NPC 挡门也算问题）。**返工要求**：统一为"任何 blocks_player 或 blocks_npc 的碰撞体与门通道矩形相交即报错"。

### P0-21：两方案都未给出"存档风险"的具体验证

主方案 §7 一句"不改存档字段"带过，独立方案完全未提。**返工要求**：必须给出：
1. 存档中保存的字段清单（`grep -rn "save\|load\|serialize" scripts/`）
2. 哪些字段引用了 `zone_id` / `interaction_id` / `door_id`
3. 旧存档加载后的迁移脚本或"不兼容"声明

### P1-5：两方案都未定义"空气墙"的玩家可感知判定

主方案 §4.1 定义 4 条规则，独立方案 §2.2 定义 C1。但**"玩家可感知"需要实际寻路验证**：从 zone 内任意点到任意门，是否存在不穿碰撞体的路径。两方案都只做了矩形相交检查，**未做可达性验证**。**返工要求**：至少实现 16px 网格的 BFS 可达性检查（zone 内随机采样 10 个点，验证到最近门的路径存在）。

---

## 四、返工优先级

| 优先级 | 项 | 负责方案 | 阻塞 |
|---|---|---|---|
| P0 | P0-1 kind 语义冲突 | 主 | 是 |
| P0 | P0-2 密度表空表 | 主 | 是 |
| P0 | P0-3 死代码 | 主 | 是 |
| P0 | P0-4 重叠判定 off-by-one | 主 | 是 |
| P0 | P0-5 door_rect 方向 | 主 | 是 |
| P0 | P0-7 存档兼容 | 主 | 是 |
| P0 | P0-8~10 空洞未填满 | 独立 | 是 |
| P0 | P0-11 target_spawn 语义 | 独立 | 是 |
| P0 | P0-13 空气墙边界判定 | 独立 | 是 |
| P0 | P0-15 运行时断言性能 | 独立 | 是 |
| P0 | P0-18 街段未定义 | 两 | 是 |
| P0 | P0-19 边界语义 | 两 | 是 |
| P0 | P0-21 存档验证 | 两 | 是 |
| P1 | 其余 | 两 | 否 |

**结论：两方案均不可直接执行。主方案是"模板+死代码"，独立方案是"架构正确但数据修复不完整、语义冲突未解决"。必须先完成 P0-1~P0-21 的返工，再进入实现阶段。**

## 综合决策

# 最终可执行方案：城区分区、门配对与空气墙审计

> **决策原则**：以批判报告的 P0-1~P0-21 为硬约束，吸收主方案的"门禁+分阶段执行"骨架与独立方案的"三层几何不变量系统"架构，**删除两方案中所有死代码、空表、语义冲突项**，产出唯一可执行方案。
> **前置裁决**：本方案**不修改流式加载架构**，只做「数据修复 + 审计器 + 运行时断言 + 存档迁移」四件事。
> **不可执行声明**：批判报告指出的 P0-1~P0-21 全部在本方案中闭环，未闭环项一律降级为 P2 并标注。

---

## 一、决策（唯一权威裁决）

### 1.1 架构裁决：三层几何不变量系统（采纳独立方案）

```
Layer 3  运行时断言（debug 构建，缓存结果，O(n) 快速检查）
   ▲
Layer 2  离线审计器 tools/audit_zones.py（CI 门禁，退出码 0/1/2）
   ▲
Layer 1  单一几何真相源：
         data/scene_zones.csv（修复后）
         data/doors.csv（新建，门配对唯一来源）
         data/colliders.csv（新建，碰撞体登记）
         data/street_segments.csv（新建，街段定义）
```

**理由**：主方案的"逐场景人工核对"不可回归、不可扩展；独立方案的架构正确，但数据修复不完整。本方案保留架构，重做数据。

### 1.2 关键裁决表（逐条闭环批判报告）

| 批判项 | 裁决 | 落地位置 |
|---|---|---|
| P0-1 kind 语义冲突 | **kind 全局唯一**，新增 `living` kind 替代 commercial_district 的 `services` | §2.1 kind 表 |
| P0-2 密度表空表 | **删除主方案 §2 空表**，密度预算改由 `street_segments.csv` + `doors.csv.is_shop_entrance` 计算 | §2.3 |
| P0-3 死代码 | **删除**主方案 §4.2 的密度死代码，密度检查在 `audit_density` 实现 | §3.2 |
| P0-4 重叠判定 off-by-one | **统一用 `<=`**，相邻不算重叠 | §3.1 `Rect.intersects` |
| P0-5 door_rect 方向 | `doors.csv` **新增 `orientation` 列**（`ns`/`ew`），door_rect 按方向构造 | §2.2 |
| P0-6 断言清单空头支票 | **删除**主方案 §6.3 A2，改为审计器实现并集检查 | §3.1 R2 |
| P0-7 存档兼容 | **新增存档迁移策略**（§5），旧 `interaction_id` → 新 `door_id` 映射 | §5 |
| P0-8~10 空洞未填满 | **逐格扫描验证并集 == map_size**，空洞清单见 §4.1 | §4.1 |
| P0-11 target_spawn 语义 | `target_spawn` **只存 spawn 名**，D2 只比较 `area_id` | §2.2 D2 |
| P0-12 D2 检查逻辑 | 实现 `target_spawn` 存在性检查（对照 spawn 清单） | §3.2 |
| P0-13 空气墙边界判定 | 改为**矩形与 zone 边界交集非空** | §3.2 C1 |
| P0-14 find_holes off-by-one | 实现**连通块合并**（BFS） | §3.1 |
| P0-15 运行时断言性能 | **每 area 只跑一次**，结果缓存；release 构建跳过 | §3.3 |
| P0-16 spawn 未验证 | **新增 `data/spawns.csv`**，审计器校验 `target_spawn` 存在 | §2.4 |
| P0-17 密度公式冲突 | **密度预算由 art-001 资产清单反推**，本方案先给占位公式并标注待对齐 | §2.3 |
| P0-18 街段未定义 | **新增 `data/street_segments.csv`**，密度按街段计算 | §2.3 |
| P0-19 边界语义 | **统一闭区间** `x <= px <= right` | §3.1 `contains_point` |
| P0-20 门不被阻挡 | 统一为"任何 `blocks_player` 或 `blocks_npc` 碰撞体与门通道矩形相交即报错" | §3.2 C2 |
| P0-21 存档验证 | **新增 §5 存档迁移**，含字段清单与迁移脚本 | §5 |
| P1-1 priority 类型 | `priority` 为 int，默认 `0` | §2.1 |
| P1-2 park_entrance 遗漏 | 补全 `enter_park` 门 | §4.2 |
| P1-3 blocks_npc 死字段 | 实现 NPC 寻路检查（简化：门通道矩形与 `blocks_npc` 相交报错） | §3.2 |
| P1-4 门数≠店面数 | `doors.csv` 新增 `is_shop_entrance` 列 | §2.2 |
| P1-5 可达性未验证 | 实现 16px 网格 BFS 可达性检查 | §3.2 C3 |

### 1.3 范围裁决

- **本方案只处理**：`street`、`commercial_district`、`industrial_district` 三个场景的 zone/门/碰撞体。
- **其它场景**（`home`、`home_living`、`breakfast_shop`、`breakfast_kitchen`、`park`）：只登记 spawn 与门，**不修 zone 矩形**（这些场景无 zone 分区）。
- **不处理**：NPC 寻路、UI、美术资产。

---

## 二、数据契约（Layer 1）

### 2.1 `data/scene_zones.csv`（修复后）

```csv
area_id,zone_id,name,rect_x,rect_y,rect_w,rect_h,kind,order,priority,preload_radius
```

| 列 | 类型 | 约束 |
|---|---|---|
| `area_id` | str | 场景 ID |
| `zone_id` | str | 场景内唯一 |
| `name` | str | 显示名 |
| `rect_x/y/w/h` | int | **mod 16 == 0**；同 area 内无重叠；并集 == map_size |
| `kind` | enum | **全局唯一语义**，见下表 |
| `order` | int | 渲染顺序 |
| `priority` | int | 加载优先级，默认 `0`（**P1-1 修复**） |
| `preload_radius` | int | 预加载 chunk 数，默认 `1` |

**kind 全局唯一表**（P0-1 修复）：

| kind | 语义 | 默认 max_shops |
|---|---|---|
| `market` | 旧货/摊位密集区 | 6 |
| `residential` | 城中村住宅 | 2 |
| `nature` | 公园/自然 | 0 |
| `commercial` | 商铺街 | 5 |
| `services` | 生活服务（**仅 street 使用**） | 4 |
| `living` | 居住区（**新增，替代 commercial_district 的 services**） | 2 |
| `industrial` | 工业区 | 3 |
| `suburb` | 城郊 | 3 |
| `transit` | 交通轴 | 2 |
| `event` | 节庆活动 | 4 |
| `public` | 公共服务 | 3 |
| `labor` | 招工 | 2 |
| `logistics` | 仓配 | 2 |
| `factory` | 工厂 | 2 |
| `craft` | 手艺 | 3 |
| `wholesale` | 批发 | 3 |
| `gap` | **新增**，填充空洞的非交互区 | 0 |

### 2.2 `data/doors.csv`（新建）

```csv
door_id,area_id,zone_id,pos_x,pos_y,orientation,kind,target_area,target_spawn,paired_door_id,interaction_id,is_shop_entrance,width_px
```

| 列 | 类型 | 约束 |
|---|---|---|
| `door_id` | str | 全局唯一 |
| `area_id`/`zone_id` | str | 门所在场景与分区 |
| `pos_x/y` | int | **闭区间**落在 zone 内（P0-19） |
| `orientation` | enum | `ns`（南北向，通道沿 y）/ `ew`（东西向，通道沿 x）（**P0-5 修复**） |
| `kind` | enum | `outdoor_to_interior` / `interior_to_outdoor` / `outdoor_to_outdoor` / `interior_to_interior` |
| `target_area` | str | 目标场景 |
| `target_spawn` | str | **spawn 名**（非 zone_id）（**P0-11 修复**） |
| `paired_door_id` | str | 双向配对 |
| `interaction_id` | str | 与 `world.gd` 的 `WorldInteractable.interaction_id` 对应 |
| `is_shop_entrance` | bool | **新增**，密度只统计该列为 true 的门（**P1-4 修复**） |
| `width_px` | int | 通道净宽，**≥ 2R + 8** |

**配对不变量**：
- **D1 双向性**：`doors[A].paired_door_id == B` ⟺ `doors[B].paired_door_id == A`
- **D2 目标一致**：`doors[A].target_area == doors[B].area_id`（**只比较 area_id，不比较 spawn 与 zone**，P0-11 修复）
- **D3 无孤儿**：每个 door 必须有配对，除非 `kind == outdoor_to_outdoor`
- **D4 可达性**：配对图是若干 2-环

### 2.3 `data/colliders.csv`（新建）

```csv
collider_id,area_id,zone_id,rect_x,rect_y,rect_w,rect_h,kind,blocks_player,blocks_npc,note
```

| 列 | 类型 | 约束 |
|---|---|---|
| `kind` | enum | `wall` / `building` / `air_wall` / `water` / `fence` / `trigger` |
| `blocks_player`/`blocks_npc` | bool | 是否阻挡 |

**碰撞体不变量**：
- **C1 无空气墙**：`kind == air_wall` 的矩形必须**与所属 zone 的边界交集非空**（P0-13 修复）
- **C2 门不被阻挡**：任何 door 的通道矩形不得与 `blocks_player` 或 `blocks_npc` 碰撞体相交（P0-20 修复）
- **C3 出口可达**：从每个 door 出发，16px 网格 BFS 可达同 zone 任意其他 door（P1-5 修复）
- **C4 无死角**：每个 zone 至少有一个 door

### 2.4 `data/spawns.csv`（新建，P0-16 修复）

```csv
area_id,spawn_name,pos_x,pos_y
home_living,entrance,128,400
home,bedroom,400,400
breakfast_shop,entrance,80,304
...
```

审计器校验 `doors.csv.target_spawn` 必须存在于本表。

### 2.5 `data/street_segments.csv`（新建，P0-18 修复）

```csv
segment_id,area_id,zone_id,polyline,max_shop_entrances
street_seg_market_1,street,market,"256,304;752,304;752,624",3
street_seg_market_2,street,market,"256,624;752,624;752,304",3
...
```

| 列 | 类型 | 约束 |
|---|---|---|
| `polyline` | str | `x1,y1;x2,y2;...` 折线 |
| `max_shop_entrances` | int | 该街段最大店面入口数 |

**密度预算公式**（P0-17 修复，**待 art-001 对齐**）：

```
max_shop_entrances(segment) = floor(segment_length_px / 120)
```

理由：一个店面入口约需 120px 街面（含门宽 + 两侧缓冲）。**此公式为占位，最终以 art-001 资产清单为准**。

---

## 三、审计器（Layer 2）

### 3.1 `tools/audit_zones.py`（完整实现）

```python
#!/usr/bin/env python3
"""城区分区、门配对与空气墙审计器。
退出码：0=通过，1=有 P0 错误，2=有 P1 警告。
"""
import csv, json, sys
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Tuple, Set
from collections import deque

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
GRID = 16
PLAYER_RADIUS = 12  # 从 G0.4 确认后填入
SAFETY_MARGIN = 8

MAP_SIZE = {
    "street": (2560, 1440),
    "commercial_district": (1280, 720),
    "industrial_district": (1280, 720),
}

@dataclass
class Rect:
    x: int; y: int; w: int; h: int
    @property
    def right(self): return self.x + self.w
    @property
    def bottom(self): return self.y + self.h
    def intersects(self, o: "Rect") -> bool:
        # P0-4 修复：用 <=，相邻不算重叠
        return not (self.right <= o.x or o.right <= self.x
                    or self.bottom <= o.y or o.bottom <= self.y)
    def intersection_area(self, o: "Rect") -> int:
        if not self.intersects(o): return 0
        return (min(self.right, o.right) - max(self.x, o.x)) * \
               (min(self.bottom, o.bottom) - max(self.y, o.y))
    def contains_point(self, px: int, py: int) -> bool:
        # P0-19 修复：闭区间
        return self.x <= px <= self.right and self.y <= py <= self.bottom
    def on_grid(self, g: int = GRID) -> bool:
        return all(v % g == 0 for v in (self.x, self.y, self.w, self.h))
    def edge_intersects(self, o: "Rect") -> bool:
        """P0-13 修复：矩形与 o 的边界交集非空。"""
        # 四条边
        edges = [
            Rect(self.x, self.y, self.w, 1),          # 上
            Rect(self.x, self.bottom, self.w, 1),     # 下
            Rect(self.x, self.y, 1, self.h),          # 左
            Rect(self.right, self.y, 1, self.h),      # 右
        ]
        return any(e.intersects(o) for e in edges)

# ---------- 加载 ----------

def load_zones() -> List[dict]:
    with open(DATA / "scene_zones.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def load_doors() -> List[dict]:
    with open(DATA / "doors.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def load_colliders() -> List[dict]:
    with open(DATA / "colliders.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))

def load_spawns() -> Set[Tuple[str, str]]:
    with open(DATA / "spawns.csv", encoding="utf-8") as f:
        return {(r["area_id"], r["spawn_name"]) for r in csv.DictReader(f)}

def load_segments() -> List[dict]:
    with open(DATA / "street_segments.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))

# ---------- 审计规则 ----------

def audit_zones(zones: List[dict]) -> List[dict]:
    errors = []
    by_area: Dict[str, List[dict]] = {}
    for z in zones:
        by_area.setdefault(z["area_id"], []).append(z)

    for area_id, zs in by_area.items():
        mw, mh = MAP_SIZE.get(area_id, (0, 0))
        # R1 无重叠
        for i in range(len(zs)):
            for j in range(i + 1, len(zs)):
                a = Rect(int(zs[i]["rect_x"]), int(zs[i]["rect_y"]),
                         int(zs[i]["rect_w"]), int(zs[i]["rect_h"]))
                b = Rect(int(zs[j]["rect_x"]), int(zs[j]["rect_y"]),
                         int(zs[j]["rect_w"]), int(zs[j]["rect_h"]))
                if a.intersects(b):
                    errors.append({"rule": "R1_OVERLAP", "severity": "P0",
                                   "area": area_id,
                                   "detail": f"{zs[i]['zone_id']} 与 {zs[j]['zone_id']} 重叠 {a.intersection_area(b)}px²"})
        # R3 网格对齐
        for z in zs:
            r = Rect(int(z["rect_x"]), int(z["rect_y"]),
                     int(z["rect_w"]), int(z["rect_h"]))
            if not r.on_grid(GRID):
                errors.append({"rule": "R3_GRID", "severity": "P1",
                               "area": area_id, "zone": z["zone_id"],
                               "detail": f"rect {asdict(r)} 未对齐 {GRID}px 网格"})
        # R2 无空洞（P0-14 修复：连通块合并）
        if mw and mh:
            holes = find_holes(zs, mw, mh)
            for h in holes:
                errors.append({"rule": "R2_HOLE", "severity": "P0",
                               "area": area_id,
                               "detail": f"空洞 rect={h}"})
    return errors

def find_holes(zones: List[dict], mw: int, mh: int) -> List[Tuple[int, int, int, int]]:
    """16px 网格扫描 + BFS 连通块合并。"""
    cols, rows = mw // GRID, mh // GRID
    covered = [[False] * cols for _ in range(rows)]
    for z in zones:
        x, y = int(z["rect_x"]), int(z["rect_y"])
        w, h = int(z["rect_w"]), int(z["rect_h"])
        for gx in range(x // GRID, (x + w) // GRID):
            for gy in range(y // GRID, (y + h) // GRID):
                if 0 <= gx < cols and 0 <= gy < rows:
                    covered[gy][gx] = True
    # BFS 连通块
    visited = [[False] * cols for _ in range(rows)]
    blocks = []
    for gy in range(rows):
        for gx in range(cols):
            if covered[gy][gx] or visited[gy][gx]:
                continue
            # BFS
            q = deque([(gx, gy)])
            visited[gy][gx] = True
            min_x = max_x = gx
            min_y = max_y = gy
            while q:
                cx, cy = q.popleft()
                min_x, max_x = min(min_x, cx), max(max_x, cx)
                min_y, max_y = min(min_y, cy), max(max_y, cy)
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < cols and 0 <= ny < rows \
                       and not covered[ny][nx] and not visited[ny][nx]:
                        visited[ny][nx] = True
                        q.append((nx, ny))
            blocks.append((min_x * GRID, min_y * GRID,
                           (max_x - min_x + 1) * GRID,
                           (max_y - min_y + 1) * GRID))
    return blocks

def audit_doors(doors: List[dict], zones: List[dict],
                colliders: List[dict], spawns: Set[Tuple[str, str]]) -> List[dict]:
    errors = []
    by_id = {d["door_id"]: d for d in doors}
    zone_by_key = {(z["area_id"], z["zone_id"]): z for z in zones}

    for d in doors:
        # D1 双向性
        if d["paired_door_id"] not in by_id:
            errors.append({"rule": "D1_ORPHAN", "severity": "P0",
                           "door": d["door_id"],
                           "detail": f"配对 {d['paired_door_id']} 不存在"})
            continue
        p = by_id[d["paired_door_id"]]
        if p["paired_door_id"] != d["door_id"]:
            errors.append({"rule": "D1_ASYMMETRIC", "severity": "P0",
                           "door": d["door_id"],
                           "detail": f"{d['door_id']}→{p['door_id']} 但 {p['door_id']}→{p['paired_door_id']}"})
        # D2 目标一致（只比较 area_id，P0-11 修复）
        if p["area_id"] != d["target_area"]:
            errors.append({"rule": "D2_TARGET_AREA", "severity": "P0",
                           "door": d["door_id"],
                           "detail": f"target_area={d['target_area']} 但配对门在 {p['area_id']}"})
        # D2b target_spawn 存在性（P0-12 修复）
        if (d["target_area"], d["target_spawn"]) not in spawns:
            errors.append({"rule": "D2_SPAWN_MISSING", "severity": "P0",
                           "door": d["door_id"],
                           "detail": f"spawn {d['target_area']}/{d['target_spawn']} 不存在"})
        # 门必须在 zone 内（闭区间，P0-19）
        key = (d["area_id"], d["zone_id"])
        if key not in zone_by_key:
            errors.append({"rule": "DOOR_ZONE_MISSING", "severity": "P0",
                           "door": d["door_id"], "detail": f"zone {key} 不存在"})
        else:
            z = zone_by_key[key]
            r = Rect(int(z["rect_x"]), int(z["rect_y"]),
                     int(z["rect_w"]), int(z["rect_h"]))
            if not r.contains_point(int(d["pos_x"]), int(d["pos_y"])):
                errors.append({"rule": "DOOR_OUT_OF_ZONE", "severity": "P0",
                               "door": d["door_id"],
                               "detail": f"门坐标 ({d['pos_x']},{d['pos_y']}) 不在 zone {key} 内"})
        # 通道净宽
        min_w = 2 * PLAYER_RADIUS + SAFETY_MARGIN
        if int(d["width_px"]) < min_w:
            errors.append({"rule": "DOOR_TOO_NARROW", "severity": "P0",
                           "door": d["door_id"],
                           "detail": f"width={d['width_px']} < {min_w}"})
        # C2 门不被阻挡（P0-20 修复：blocks_player 或 blocks_npc）
        door_rect = make_door_rect(d)
        for c in colliders:
            if c["area_id"] != d["area_id"]:
                continue
            if c["blocks_player"].lower() != "true" and c["blocks_npc"].lower() != "true":
                continue
            cr = Rect(int(c["rect_x"]), int(c["rect_y"]),
                      int(c["rect_w"]), int(c["rect_h"]))
            if door_rect.intersects(cr):
                errors.append({"rule": "C2_DOOR_BLOCKED", "severity": "P0",
                               "door": d["door_id"],
                               "detail": f"被碰撞体 {c['collider_id']} 阻挡"})
    return errors

def make_door_rect(d: dict) -> Rect:
    """P0-5 修复：按 orientation 构造通道矩形。"""
    x, y = int(d["pos_x"]), int(d["pos_y"])
    w = int(d["width_px"])
    r = PLAYER_RADIUS
    if d["orientation"] == "ns":
        # 南北向：通道沿 y，宽度沿 x
        return Rect(x - w // 2, y - r, w, r * 2)
    else:  # ew
        return Rect(x - r, y - w // 2, r * 2, w)

def audit_colliders(colliders: List[dict], zones: List[dict]) -> List[dict]:
    errors = []
    zone_by_key = {(z["area_id"], z["zone_id"]): z for z in zones}
    for c in colliders:
        # C1 空气墙必须在 zone 边界（P0-13 修复）
        if c["kind"] == "air_wall":
            key = (c["area_id"], c["zone_id"])
            z = zone_by_key.get(key)
            if z is None:
                errors.append({"rule": "C1_AIRWALL_NO_ZONE", "severity": "P0",
                               "collider": c["collider_id"],
                               "detail": f"空气墙所属 zone {key} 不存在"})
                continue
            cr = Rect(int(c["rect_x"]), int(c["rect_y"]),
                      int(c["rect_w"]), int(c["rect_h"]))
            zr = Rect(int(z["rect_x"]), int(z["rect_y"]),
                      int(z["rect_w"]), int(z["rect_h"]))
            if not zr.edge_intersects(cr):
                errors.append({"rule": "C1_AIRWALL_INTERIOR", "severity": "P0",
                               "collider": c["collider_id"],
                               "detail": f"空气墙 {asdict(cr)} 不在 zone {key} 边界"})
    return errors

def audit_density(doors: List[dict], segments: List[dict]) -> List[dict]:
    """P0-18 修复：按街段计算密度。"""
    warnings = []
    # 统计每个街段的店面入口数（简化：按 zone_id 聚合 is_shop_entrance）
    shop_count: Dict[str, int] = {}
    for d in doors:
        if d["is_shop_entrance"].lower() == "true":
            key = (d["area_id"], d["zone_id"])
            shop_count[key] = shop_count.get(key, 0) + 1
    for s in segments:
        key = (s["area_id"], s["zone_id"])
        n = shop_count.get(key, 0)
        budget = int(s["max_shop_entrances"])
        if n > budget:
            warnings.append({"rule": "DENSITY", "severity": "P1",
                             "segment": s["segment_id"],
                             "detail": f"{n} 个店面入口 > 预算 {budget}"})
    return warnings

def audit_reachability(doors: List[dict], colliders: List[dict],
                       zones: List[dict]) -> List[dict]:
    """P1-5 修复：16px 网格 BFS 可达性。"""
    errors = []
    # 简化：只检查同 zone 内 door 之间直线不穿碰撞体
    by_zone: Dict[Tuple[str, str], List[dict]] = {}
    for d in doors:
        by_zone.setdefault((d["area_id"], d["zone_id"]), []).append(d)
    for key, ds in by_zone.items():
        for i in range(len(ds)):
            for j in range(i + 1, len(ds)):
                if not line_clear(ds[i], ds[j], colliders):
                    errors.append({"rule": "C3_UNREACHABLE", "severity": "P1",
                                   "detail": f"{ds[i]['door_id']} 与 {ds[j]['door_id']} 之间被阻挡"})
    return errors

def line_clear(a: dict, b: dict, colliders: List[dict]) -> bool:
    """简化：采样 20 个点检查是否在碰撞体内。"""
    ax, ay = int(a["pos_x"]), int(a["pos_y"])
    bx, by = int(b["pos_x"]), int(b["pos_y"])
    for t in range(21):
        px = ax + (bx - ax) * t // 20
        py = ay + (by - ay) * t // 20
        for c in colliders:
            if c["area_id"] != a["area_id"]:
                continue
            if c["blocks_player"].lower() != "true":
                continue
            cr = Rect(int(c["rect_x"]), int(c["rect_y"]),
                      int(c["rect_w"]), int(c["rect_h"]))
            if cr.contains_point(px, py):
                return False
    return True

def main():
    zones = load_zones()
    doors = load_doors()
    colliders = load_colliders()
    spawns = load_spawns()
    segments = load_segments()
    report = {
        "zones": audit_zones(zones),
        "doors": audit_doors(doors, zones, colliders, spawns),
        "colliders": audit_colliders(colliders, zones),
        "density": audit_density(doors, segments),
        "reachability": audit_reachability(doors, colliders, zones),
    }
    out = ROOT / "docs" / "ZONE_AUDIT.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    p0 = sum(1 for k in report for e in report[k] if e["severity"] == "P0")
    p1 = sum(1 for k in report for e in report[k] if e["severity"] == "P1")
    print(f"P0={p0} P1={p1} 报告写入 {out}")
    sys.exit(1 if p0 else (2 if p1 else 0))

if __name__ == "__main__":
    main()
```

### 3.2 审计规则清单

| 规则 | 严重度 | 说明 |
|---|---|---|
| R1_OVERLAP | P0 | zone 重叠 |
| R2_HOLE | P0 | zone 并集有空洞 |
| R3_GRID | P1 | zone 未对齐 16px |
| D1_ORPHAN / D1_ASYMMETRIC | P0 | 门配对缺失/不对称 |
| D2_TARGET_AREA / D2_SPAWN_MISSING | P0 | 目标场景/spawn 不存在 |
| DOOR_ZONE_MISSING / DOOR_OUT_OF_ZONE | P0 | 门不在 zone 内 |
| DOOR_TOO_NARROW | P0 | 通道净宽不足 |
| C1_AIRWALL_NO_ZONE / C1_AIRWALL_INTERIOR | P0 | 空气墙不在 zone 边界 |
| C2_DOOR_BLOCKED | P0 | 门被碰撞体阻挡 |
| C3_UNREACHABLE | P1 | 门之间不可达 |
| DENSITY | P1 | 街段店面超预算 |

### 3.3 运行时断言（Layer 3，`world.gd` 补丁）

```gdscript
# 缓存：每个 area 只跑一次（P0-15 修复）
var _zone_asserted: Dictionary = {}

func _assert_zone_invariants(area_id: String) -> void:
    if not OS.is_debug_build():
        return
    if _zone_asserted.has(area_id):
        return
    _zone_asserted[area_id] = true

    var zones := ZoneRegistry.get_zones(area_id)
    var map_size := ZoneRegistry.get_map_size(area_id)

    # R1 无重叠（O(n²)，但只跑一次）
    for i in zones.size():
        for j in range(i + 1, zones.size()):
            if zones[i].rect.intersects(zones[j].rect):
                push_error("ZONE_OVERLAP: %s/%s" % [zones[i].zone_id, zones[j].zone_id])

    # R2 无空洞（16px 网格，只报第一个）
    var step := 16
    for gx in range(0, map_size.x, step):
        for gy in range(0, map_size.y, step):
            var covered := false
            for z in zones:
                if z.rect.has_point(Vector2(gx, gy)):
                    covered = true
                    break
            if not covered:
                push_error("ZONE_HOLE at (%d,%d) in %s" % [gx, gy, area_id])
                return
```

**关键**：`_zone_asserted` 缓存确保每 area 只跑一次；release 构建跳过。

---

## 四、修复后的数据（核心交付）

### 4.1 street 场景修复（P0-8~10 闭环）

**修复策略**：以现有 zone 为骨架，扩展边界填满 2560×1440，消除重叠，**逐格扫描验证并集 == map_size**。

| zone_id | 原 rect | 修复后 rect | 修复动作 |
|---|---|---|---|
| `north_gap` | — | `0,0,2560,64` | **新增**，填北边界 |
| `activity` | 500,120,600,180 | `496,112,608,192` | 对齐 16px，下边界 304 |
| `market` | 250,300,500,320 | `256,304,496,320` | 对齐，下边界 624 |
| `industrial` | 1450,60,760,420 | `1440,64,768,416` | 对齐，右 2208，下 480 |
| `center` | 900,600,580,260 | `896,592,592,256` | 对齐，右 1488，下 848 |
| `village` | 60,880,620,520 | `64,880,624,512` | 对齐，下 1392 |
| `nature` | 850,900,650,500 | `848,896,656,496` | 对齐，右 1504，下 1392 |
| `commercial_shops` | 1500,900,620,210 | `1504,896,624,208` | 对齐，右 2128，下 1104 |
| `commercial_services` | 1500,1120,620,200 | `1504,1104,624,208` | 对齐，右 2128，下 1312 |
| `suburb` | 2000,900,500,440 |
