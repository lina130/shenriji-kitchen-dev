# 飞机大厨式早餐店点击经营与流水线融合

## 主方案

# 早餐店点击经营 × 多工序流水线融合 —— 唯一可执行方案

> 综合裁决：以现有 `kitchen_manager.gd` 的**多工序 pipeline 数据**为唯一事实源，新增**场景内点击经营层**（`breakfast_shop_layer.gd`），HUD 只做只读回显。所有经营操作在场景内完成，`hud.gd` 的 `_modal_state` 在经营流程中保持 `NONE`。
> 硬约束：无下拉菜单、无真实人走来走去、无任务面板、无数值属性条、固定物价、存档兼容、温柔治愈画风。

---

## 0. 前置门禁（阻塞性，未通过不得进入实现）

所有结果写入 `docs/BREAKFAST_FACTS.md`，作为后续所有字段/尺寸的唯一事实源。

### G0.1 确认 kitchen_manager 现有 API 签名
```bash
grep -n "^func \|^signal \|^var \|^const " autoload/kitchen_manager.gd
```
**裁决**：记录 `_new_station` / `_update_stations` / `_update_orders` / `_update_customer_flow` / `_spawn_order` / `end_shift` / `get_order_target` 的真实签名。本方案所有新增方法必须与现有签名兼容，**不得重命名现有方法**。

### G0.2 确认 breakfast_shop 场景与现有顾客节点
```bash
grep -rn "breakfast_shop\|_breakfast_customer_nodes\|_restaurant_cu" scripts/ --include=*.gd
ls scenes/ | grep -i breakfast
```
**裁决**：
- 若 `_breakfast_customer_nodes` 已存在 → 复用其数组，本方案只新增状态字段。
- 若 `scenes/breakfast_shop.tscn` 不存在 → **本方案降级为"仅实现 kitchen_manager 内的点击经营状态机 + 信号"**，场景层由 world-002 补齐后再接入。
- 结果写入 `docs/BREAKFAST_FACTS.md`。

### G0.3 确认 recipes.csv 早餐条目
```bash
grep -E "morning" data/recipes.csv
```
**预期**：`red_bean_bun / soy_milk / pork_bun / rice_noodle_soup / youtiao / porridge / tea_egg` 共 7 条。
**裁决**：早餐店菜单 = 上述 7 条，**不新增 recipe**。pipeline 字段直接复用。

### G0.4 确认 ConfigDB breakfast 段
```bash
grep -n "breakfast" data/config.csv
```
**裁决**：记录 `shift_duration`（默认 75.0）、`order_target`、`customer_spawn_interval` 等现有键。本方案新增键必须带默认值，缺失时走 fallback。

### G0.5 确认 ClickGestureRouter 是否存在（ui-002 产物）
```bash
ls scripts/ | grep -i "click_gesture\|gesture_router"
```
**裁决**：
- 若存在 → 本方案所有工位/托盘/出餐台实体继承 `WorldInteractable`，手势由 router 分发。
- 若不存在 → **本方案先实现 `breakfast_shop_layer.gd` 内部的手势解析**（TAP/SECONDARY/HOLD/DRAG），并在文件头注释标注"待 ui-002 落地后迁移到 ClickGestureRouter"。

---

## 1. 核心决策（逐条裁决）

| # | 争议点 | 最终裁决 | 理由 |
|---|---|---|---|
| D1 | 顾客是否"走来走去" | **不移动**。顾客以**排队槽位**形式出现在出餐台前的固定队列 UI 上，每个槽位是一个 `WorldInteractable` | 硬约束"避免真实人走来走去" |
| D2 | 点餐交互 | **点击顾客槽位 = 接单**，订单进入 `orders` 数组，顾客槽位变为"等待中"状态 | 无下拉菜单 |
| D3 | 工位点击语义 | **TAP = 投入半成品/启动工序**；**SECONDARY = 取消当前工序**（退回半成品到托盘） | 与 ui-002 手势语义表一致 |
| D4 | 半成品暂存 | **托盘（tray）是唯一暂存区**，容量 6，超出时拒绝新产出并提示 | 避免无限缓存破坏流水线节奏 |
| D5 | 手动搬运 | **DRAG 半成品从托盘到工位**；**DRAG 成品从工位到出餐台**。不自动流转 | 硬约束"手动搬运" |
| D6 | 出餐台 | **TAP 出餐台 = 交付当前手持成品**；匹配订单则 `served++`，否则 `failed++` | 无下拉菜单 |
| D7 | 顾客耐心 | **每顾客一个 `patience` 浮点数**，随时间递减；归零则该顾客离场，`failed++` | 无数值属性条 → 用**槽位颜色渐变 + 图标**表达 |
| D8 | 随机客流 | **泊松近似**：`_spawn_timer` 到期后按 `rush_active` 调整间隔，`randf()` 决定是否生成 | 复用现有 `_spawn_timer` |
| D9 | 失败条件 | ① 顾客耐心归零 ② 出餐错误 ③ 托盘溢出 ④ 时间耗尽未达 target | 四条独立，全部计入 `failed` |
| D10 | 与 pipeline 融合 | **工位类型 = STAGE_STATION_MAP 的 value**；每个工位只处理自己类型的工序 | 复用现有映射，不新增 |
| D11 | 存档 | 只存 `location_id / active_phase_id / served / failed / shift_earned`；**不存中间态**（半成品/托盘/顾客队列） | 存档兼容，中途退出即放弃本班 |
| D12 | 画风 | 槽位用**暖色圆角卡片**，耐心用**卡片边缘暖色→灰白渐变**，不用进度条 | 低饱和暖色、柔光 |

---

## 2. 节点结构（场景层）

```
BreakfastShopLayer (Node2D)          # 新增，挂 breakfast_shop.tscn 根下
├── CustomerQueue (Node2D)           # 顾客排队区（固定槽位，不移动）
│   ├── QueueSlot_0 (WorldInteractable)   # 槽位 0，最靠前
│   ├── QueueSlot_1 (WorldInteractable)
│   ├── QueueSlot_2 (WorldInteractable)
│   └── QueueSlot_3 (WorldInteractable)   # 最多 4 位
├── StationRow (Node2D)              # 工位区
│   ├── Station_prep (WorldInteractable)
│   ├── Station_steamer (WorldInteractable)
│   ├── Station_fryer (WorldInteractable)
│   ├── Station_soup_pot (WorldInteractable)
│   └── Station_drink (WorldInteractable)
├── TrayArea (WorldInteractable)     # 托盘，容量 6
├── ServeCounter (WorldInteractable) # 出餐台
└── KitchenEffectLayer (Node2D)      # 复用现有 KitchenEffectLayerScript
```

**坐标来源**：全部由 `data/breakfast_layout.csv` 提供（新增），`.tscn` 里 `position = Vector2.ZERO`，由 layer 在 `_ready` 设置。**CSV 为唯一事实源**（与 ui-002 C3 裁决一致）。

`data/breakfast_layout.csv` 字段：
```csv
node_id,kind,anchor_x,anchor_y,slot_index
queue_0,queue_slot,320,880,0
queue_1,queue_slot,420,880,1
queue_2,queue_slot,520,880,2
queue_3,queue_slot,620,880,3
station_prep,station,180,420,
station_steamer,station,380,420,
station_fryer,station,580,420,
station_soup_pot,station,780,420,
station_drink,station,980,420,
tray,tray,1180,640,
serve_counter,serve,1180,880,
```

---

## 3. 数据结构（kitchen_manager 内新增）

```gdscript
# 顾客（排队槽位）
class Customer:
    var slot_index: int          # 0..3
    var recipe_id: String        # 点单的 recipe
    var patience: float          # 剩余耐心秒数
    var patience_max: float      # 初始耐心（用于计算比例）
    var state: String            # "waiting" | "served" | "left"
    var order_id: int            # 关联 orders 里的订单

# 订单（与顾客一一对应）
class Order:
    var order_id: int
    var recipe_id: String
    var stages: Array[String]    # 从 pipeline 解析出的工序序列
    var current_stage: int       # 已完成到第几道
    var assigned_station: String # 当前占用的工位类型（空串=未占用）
    var state: String            # "pending" | "cooking" | "ready" | "done" | "failed"

# 工位
class Station:
    var station_type: String     # prep/steamer/fryer/soup_pot/drink
    var state: String            # "idle" | "busy" | "blocked"
    var current_order_id: int    # -1 = 空闲
    var progress: float          # 0..1
    var duration: float          # 当前工序总时长

# 半成品（托盘里的物品）
class StagedItem:
    var order_id: int
    var recipe_id: String
    var next_stage: String       # 下一道工序类型
    var ready: bool              # true=已完成当前工序，等待搬运
```

**新增成员变量**（kitchen_manager）：
```gdscript
var customers: Array = []        # Array[Customer]
var tray: Array = []             # Array[StagedItem]，容量上限 6
var held_item: StagedItem = null # 玩家 DRAG 时手持的半成品
var _customer_id_counter := 0
const TRAY_CAPACITY := 6
const QUEUE_SLOTS := 4
```

---

## 4. 信号（新增，全部 emit 到 changed 之外）

```gdscript
signal customer_arrived(customer: Dictionary)      # 新顾客入队
signal customer_left(customer: Dictionary)         # 顾客耐心归零离场
signal order_accepted(order: Dictionary)           # 接单成功
signal station_started(station_type: String, order_id: int)
signal station_finished(station_type: String, order_id: int)
signal item_staged(item: Dictionary)               # 半成品进托盘
signal item_picked(item: Dictionary)               # 从托盘拿起
signal item_dropped(item: Dictionary, station_type: String)  # 放到工位
signal served_ok(order: Dictionary, earned: int)
signal served_wrong(order: Dictionary)             # 出餐错误
signal tray_full()                                 # 托盘溢出
```

**HUD 只读回显**：HUD 订阅 `customer_arrived / customer_left / served_ok / served_wrong`，更新槽位卡片颜色和计数。**HUD 不发起任何经营操作**。

---

## 5. 工位状态机

```
        ┌─────────┐
        │  idle   │◄────────────────┐
        └────┬────┘                 │
             │ TAP + 托盘有匹配半成品 │
             ▼                      │
        ┌─────────┐                 │
        │  busy   │──progress≥1.0──►│
        └────┬────┘                 │
             │ SECONDARY            │
             ▼                      │
        ┌─────────┐                 │
        │ blocked │──TAP 清空───────┘
        └─────────┘
```

- **idle → busy**：玩家 DRAG 半成品到工位，且 `item.next_stage` 的 station 类型 == 工位类型。启动 `duration = pipeline[stage]`。
- **busy → idle**：`progress >= 1.0`，产出新半成品（`next_stage` 前进一位）或成品（最后一道），自动放入托盘（若托盘满则 `blocked`）。
- **busy → blocked**：SECONDARY 取消，半成品退回托盘；若托盘满则 `blocked`。
- **blocked → idle**：玩家 TAP 工位，把退回的半成品放回托盘（托盘有空位时）。

**关键约束**：工位**不自动流转**。`busy` 完成后产物进托盘，玩家必须手动 DRAG 到下一工位。这是"手动搬运"的核心。

---

## 6. 完整操作流（玩家视角）

```
1. 顾客入队（自动，随机客流）
   → QueueSlot_N 出现暖色卡片，显示 recipe 名 + 耐心环

2. 点击顾客槽位（TAP）
   → order_accepted，订单进入 orders，顾客 state="waiting"
   → 槽位卡片变为"已接单"样式

3. 查看订单工序（HUD 只读显示）
   → 例如 pork_bun: prep → steam → serve
   → HUD 显示 3 个小圆点，当前工序高亮

4. 从托盘 DRAG 半成品到工位（或从工位 DRAG 成品到出餐台）
   → 若托盘为空，需先 TAP 工位启动第一道工序（prep）
   → prep 完成后产物进托盘

5. 工位 TAP 启动 / SECONDARY 取消
   → station_started / station_finished

6. 出餐台 TAP 交付
   → 匹配订单 → served_ok，served++，combo++
   → 不匹配 → served_wrong，failed++，combo=0

7. 顾客耐心归零
   → customer_left，failed++，槽位清空

8. 时间耗尽或 served >= target
   → end_shift("complete")
```

**无下拉菜单**：所有选择通过**点击具体实体**完成。订单工序通过 HUD 只读显示，玩家自己记住下一步。

---

## 7. 顾客耐心

```gdscript
func _update_customers(delta: float) -> void:
    for customer in customers:
        if customer.state != "waiting":
            continue
        customer.patience -= delta
        if customer.patience <= 0.0:
            customer.state = "left"
            failed += 1
            combo = 0
            customer_left.emit(_customer_to_dict(customer))
            _remove_customer(customer)
```

**耐心初始值**（按 recipe 复杂度）：
```gdscript
func _patience_for(recipe_id: String) -> float:
    var stages := _parse_pipeline(recipe_id)
    var base := float(ConfigDB.get_number("breakfast", "patience_base", 45.0))
    var per_stage := float(ConfigDB.get_number("breakfast", "patience_per_stage", 12.0))
    return base + per_stage * stages.size()
```

**视觉表达**（无数值条）：
- 槽位卡片边缘颜色：`Color(0.85,0.65,0.45)` → `Color(0.75,0.72,0.68)` 线性插值，比例 = `patience / patience_max`。
- 比例 < 0.3 时卡片轻微脉动（`sin` 调制 alpha），不显示数字。

---

## 8. 随机客流

```gdscript
func _update_customer_flow(delta: float) -> void:
    if customers.size() >= QUEUE_SLOTS:
        return
    _spawn_timer -= delta
    if _spawn_timer > 0.0:
        return
    var interval := float(ConfigDB.get_number("breakfast", "customer_interval", 6.0))
    if rush_active:
        interval *= 0.6
    _spawn_timer = interval * randf_range(0.8, 1.2)
    if randf() < float(ConfigDB.get_number("breakfast", "spawn_chance", 0.85)):
        _spawn_customer()
```

**规则**：
- 队列满（4 位）时不再生成。
- `rush_active` 时间隔 ×0.6。
- 生成时从当前 phase 的 recipe 池随机选一个（`morning` 只选 `phases` 含 `morning` 的 recipe）。
- **不生成重复 recipe 的顾客**（同一时刻队列内 recipe 唯一），避免玩家混淆。

---

## 9. 失败条件（四条独立）

| # | 条件 | 触发点 | 后果 |
|---|---|---|---|
| F1 | 顾客耐心归零 | `_update_customers` | `failed++`，`combo=0`，`customer_left` |
| F2 | 出餐错误 | `ServeCounter` TAP 时 `held_item.recipe_id != order.recipe_id` | `failed++`，`combo=0`，`served_wrong` |
| F3 | 托盘溢出 | `_stage_item` 时 `tray.size() >= TRAY_CAPACITY` | 工位进入 `blocked`，`tray_full`，**不计 failed**（可恢复） |
| F4 | 时间耗尽未达 target | `_process` 中 `time_left <= 0` | `end_shift("timeout")`，`failed += (target - served)` |

**F3 是软失败**：玩家可以 TAP 工位把退回的半成品放回托盘（托盘有空位时），或等待出餐腾出空间。**不扣分**，但阻塞流水线。

---

## 10. 与现有 pipeline 的融合

**复用点**：
- `STAGE_STATION_MAP`：工序 → 工位类型映射，**不改**。
- `STAGE_NAMES` / `STATION_NAMES`：显示名，**不改**。
- `recipes.csv` 的 `pipeline` 字段：`prep:2.4|fry:3.2|serve:0.8` 格式，**不改**。
- `_build_stations_for_phase`：改为按 `breakfast_layout.csv` 的 station 行构建，**不新增工位类型**。

**新增点**：
- `_parse_pipeline(recipe_id) -> Array[String]`：解析 `pipeline` 字段为工序数组。
- `_stage_item(order_id, recipe_id, next_stage)`：产物进托盘。
- `_pick_item(index)` / `_drop_item(station_type)`：DRAG 搬运。
- `_serve(order_id)`：出餐台交付。

**兼容性**：现有 `_update_stations` / `_update_orders` 保留，新增逻辑在 `_update_customers` / `_update_customer_flow` 中，**不修改现有函数签名**。

---

## 11. 文件清单（按执行顺序）

| # | 文件 | 操作 | 关键内容 |
|---|---|---|---|
| A1 | `docs/BREAKFAST_FACTS.md` | 新建 | G0.1–G0.5 门禁结果 |
| A2 | `data/breakfast_layout.csv` | 新建 | 节点坐标（§2） |
| A3 | `data/config.csv` | 追加 | `breakfast.patience_base / patience_per_stage / customer_interval / spawn_chance / tray_capacity` |
| B1 | `autoload/kitchen_manager.gd` | 修改 | 新增 Customer/Order/Station/StagedItem 类、信号、`_update_customers` / `_update_customer_flow` / `_stage_item` / `_pick_item` / `_drop_item` / `_serve` |
| B2 | `scripts/gameplay/breakfast_shop_layer.gd` | 新建 | 场景层，读 CSV 建节点，手势分发 |
| B3 | `scripts/gameplay/breakfast_queue_slot.gd` | 新建 | 槽位实体，继承 WorldInteractable |
| B4 | `scripts/gameplay/breakfast_station.gd` | 新建 | 工位实体 |
| B5 | `scripts/gameplay/breakfast_tray.gd` | 新建 | 托盘实体 |
| B6 | `scripts/gameplay/breakfast_serve_counter.gd` | 新建 | 出餐台实体 |
| C1 | `scenes/breakfast_shop.tscn` | 修改 | 挂 BreakfastShopLayer |
| C2 | `scripts/ui/hud.gd` | 修改 | 订阅信号，只读回显槽位卡片 |

---

## 12. 验证步骤

### V1. 单元验证（kitchen_manager 内）
```gdscript
# 在 main.gd 新增 --breakfast-check
func run_breakfast_check() -> void:
    KitchenManager.start_shift_for("breakfast_shop")
    assert(KitchenManager.customers.size() == 2)  # 初始 2 单
    assert(KitchenManager.tray.size() == 0)
    # 模拟接单
    var c = KitchenManager.customers[0]
    KitchenManager.accept_order(c.slot_index)
    assert(KitchenManager.orders.size() == 1)
    # 模拟工序完成
    KitchenManager._stage_item(0, c.recipe_id, "steam")
    assert(KitchenManager.tray.size() == 1)
    # 模拟托盘溢出
    for i in range(6):
        KitchenManager._stage_item(0, c.recipe_id, "steam")
    assert(KitchenManager.tray.size() == 6)
    KitchenManager._stage_item(0, c.recipe_id, "steam")
    assert(KitchenManager.tray.size() == 6)  # 未溢出
    print("breakfast-check OK")
```

### V2. 场景验证
```bash
godot --headless --scene-check scenes/breakfast_shop.tscn
```
断言：`BreakfastShopLayer` 下节点数量 == 12（4 槽位 + 5 工位 + 托盘 + 出餐台 + effect layer）。

### V3. 手动验证清单
- [ ] 顾客入队，槽位卡片出现
- [ ] TAP 槽位接单，卡片样式变化
- [ ] TAP 工位启动 prep，progress 推进
- [ ] prep 完成，产物进托盘
- [ ] DRAG 托盘产物到 steamer，工序继续
- [ ] 出餐台 TAP 交付，served++
- [ ] 交付错误 recipe，failed++
- [ ] 顾客耐心归零，槽位清空
- [ ] 托盘满时工位 blocked
- [ ] 时间耗尽，end_shift("timeout")

### V4. 存档兼容
```bash
godot --headless --save-check
```
断言：存档中**不含** `customers / tray / held_item` 字段；读档后 `start_shift_for` 可正常启动。

---

## 13. 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| `breakfast_shop.tscn` 不存在 | P0 | G0.2 门禁；不存在则降级为纯 kitchen_manager 实现 |
| ClickGestureRouter 未落地 | P1 | G0.5 门禁；不存在则 layer 内部实现手势，标注待迁移 |
| 托盘容量 6 过小导致频繁 blocked | P1 | 首周观察，若 blocked 率 > 30% 则调至 8 |
| 顾客耐心初始值过短导致 F1 频发 | P1 | 首周观察，若 F1 > 20% 则 `patience_base` +10 |
| HUD 只读回显与现有 `_modal_state` 冲突 | P2 | 经营流程中强制 `_modal_state = NONE`，HUD 只订阅信号 |
| 存档中途退出丢失进度 | P2 | 明确设计：中途退出即放弃本班，不存中间态 |
| 与 world-002 场景分区冲突 | P2 | `breakfast_shop` 场景坐标由 world-002 提供，本方案只读 |

---

## 14. 不做的事（明确边界）

- **不做**顾客真实移动动画（硬约束）。
- **不做**下拉菜单选择 recipe（硬约束）。
- **不做**自动流转（硬约束"手动搬运"）。
- **不做**数值属性条显示耐心（硬约束）。
- **不做**新增 recipe（复用现有 7 条早餐）。
- **不做**新增工位类型（复用 STAGE_STATION_MAP）。
- **不做**中途存档（存档兼容）。
- **不做**夜宵摊（gameplay-001 已降级 P2）。

---

**执行顺序**：G0 门禁 → A1–A3 数据层 → B1 kitchen_manager → B2–B6 场景层 → C1–C2 接入 → V1–V4 验证。

**唯一事实源**：`docs/BREAKFAST_FACTS.md` + `data/breakfast_layout.csv` + `data/recipes.csv`。执行者不得引用本方案之外的任何字段/坐标/数值。

## 独立方案

# 早餐店点击经营 × 多工序流水线融合 —— 独立可执行方案

> 独立方案 Agent 输出。**不迎合主方案**。核心主张：**放弃"顾客实体 + 工位实体 + 托盘实体"三套对象模型，改用「订单卡 = 唯一状态载体 + 工位 = 纯函数处理器 + 托盘 = 订单卡插槽」的单数据流架构**。所有交互都是对订单卡的指针操作，零 NPC 寻路、零下拉菜单、零数值条。

---

## 0. 与主方案的架构分歧（先拍板）

| 维度 | 主方案倾向 | **本方案** | 理由 |
|---|---|---|---|
| 顾客表现 | 顾客节点排队、耐心条 | **顾客 = 订单卡上的头像 + 环形耐心刻度**，无独立 Actor | 约束"避免真实人走来走去"；省掉寻路/碰撞/动画三套系统 |
| 工位模型 | 工位持有 `current_order` 状态机 | **工位无状态**，只持有 `slot: OrderCard` 引用；进度存在 OrderCard 上 | 工位可复用、可热插拔、可并行升级；状态机收敛到一处 |
| 搬运 | 拖拽半成品实体 | **拖拽 = 移动 OrderCard 的 stage 指针**，视觉上卡片从工位 A 飞到工位 B | 无中间实体、无物理、无丢失 bug |
| 半成品暂存 | 独立 staging 数组 | **staging 是 OrderCard 的 `parked_at` 字段**，视觉上停在暂存台 | 单一数据源 |
| 出餐 | 出餐台接收成品 | **出餐台是"结算触发器"**，卡片进入即结算，不持有状态 | 避免出餐台成为第二个状态机 |
| 顾客耐心 | 独立计时器 | **耐心 = OrderCard.deadline**，与工序进度共用同一时钟 | 单时钟，无同步问题 |
| 随机客流 | 定时 spawn 顾客 | **泊松过程 + 时段权重表**，spawn 的是订单卡不是人 | 可调、可测、可回放 |

**一句话**：整个早餐店只有一种可变对象 —— `OrderCard`。工位、暂存台、出餐台都是它的"位置"。

---

## 1. 节点结构（场景树）

```
BreakfastShop (Node2D)                      # 场景根，挂 BreakfastShopController
├── Backdrop (AreaBackdrop)                 # 复用 world-001 的 chunk 绘制
├── CounterLayer (Node2D)                   # 柜台视觉层（静态）
│   ├── QueueRail (Node2D)                  # 排队轨道：只画 5 个卡位底纹
│   └── StationRail (Node2D)                # 工位轨道：只画工位底纹
├── CardLayer (Node2D)                      # ★ 唯一动态层：所有 OrderCard 的视觉节点
│   └── (OrderCardView 实例，运行时增删)
├── StagingLayer (Node2D)                   # 暂存台：3 个插槽底纹
├── ServeLayer (Node2D)                     # 出餐台：1 个插槽底纹
├── ClickRouter (ClickGestureRouter)        # 复用 ui-002 的手势路由
├── KitchenEffectLayer (Node2D)             # 复用现有，蒸汽/油花粒子
└── HUD (CanvasLayer)                       # 只读回显：时段、剩余时间、连击、营收
```

**关键**：`CardLayer` 是唯一会增删子节点的层。工位、暂存、出餐台都是**静态底纹 + 命中区**，不持有视觉子节点。

---

## 2. 核心数据结构

### 2.1 OrderCard（唯一状态载体）

```gdscript
class_name OrderCard
extends RefCounted

# --- 身份 ---
var card_id: int                    # 自增
var recipe_id: String               # 指向 recipes.csv
var customer_face: int              # 头像索引（0-7，纯视觉）
var customer_name: String           # "赶地铁的姑娘" 之类，纯文案

# --- 流水线状态 ---
var stages: Array[String]           # 从 recipes.csv pipeline 解析，如 ["prep","steam","serve"]
var stage_index: int = 0            # 当前应执行的工序下标
var stage_progress: float = 0.0     # 当前工序已耗时（秒）
var stage_duration: float = 0.0     # 当前工序总耗时（秒）

# --- 位置状态（互斥）---
enum Loc { QUEUE, STATION, STAGING, HAND, SERVE, DONE }
var loc: Loc = Loc.QUEUE
var loc_ref: String = ""            # 工位 id / 暂存槽 id / "" 
var queue_slot: int = -1            # 排队位（0 = 最前）

# --- 耐心 ---
var patience_total: float = 0.0     # 总耐心（秒），由时段 + 菜品决定
var patience_left: float = 0.0
var patience_state: int = 0         # 0=平静 1=张望 2=皱眉 3=要走

# --- 结算 ---
var price: int = 0                  # 固定物价，来自 recipes.csv sale_price
var is_rush: bool = false           # 是否快单（rush 时段加成）
var spawned_at: float = 0.0         # 用于统计

func current_stage() -> String:
    return stages[stage_index] if stage_index < stages.size() else ""

func is_ready_to_serve() -> bool:
    return stage_index >= stages.size() - 1 and stages[-1] == "serve"

func advance_stage() -> void:
    stage_index += 1
    stage_progress = 0.0
    if stage_index < stages.size():
        stage_duration = _lookup_duration(stages[stage_index])
```

### 2.2 Station（无状态处理器）

```gdscript
class_name Station
extends RefCounted

var station_id: String          # "prep_1" / "steamer_1" / "fryer_2"
var station_type: String        # "prep" / "steamer" / "fryer" / "soup_pot" / "drink" / "serve"
var slot: OrderCard = null      # 当前占用的卡片，null = 空闲
var level: int = 1              # 升级等级，影响 speed_multiplier
var speed_multiplier: float = 1.0
var accepts_stages: Array[String] = []   # 从 STAGE_STATION_MAP 反查

func can_accept(card: OrderCard) -> bool:
    if slot != null: return false
    return card.current_stage() in accepts_stages

func tick(delta: float) -> Dictionary:
    # 返回 {completed: bool, card: OrderCard}
    if slot == null: return {"completed": false}
    slot.stage_progress += delta * speed_multiplier
    if slot.stage_progress >= slot.stage_duration:
        slot.advance_stage()
        return {"completed": true, "card": slot}
    return {"completed": false}
```

### 2.3 BreakfastShopController（唯一管理器）

```gdscript
extends Node2D

signal card_spawned(card: OrderCard)
signal card_moved(card: OrderCard, from_loc: int, to_loc: int)
signal card_served(card: OrderCard, earned: int)
signal card_lost(card: OrderCard, reason: String)
signal combo_changed(combo: int)
signal shift_ended(summary: Dictionary)

const QUEUE_SLOTS := 5
const STAGING_SLOTS := 3

var cards: Dictionary = {}          # card_id -> OrderCard
var queue: Array[int] = []          # 排队中的 card_id，[0] 是最前
var stations: Dictionary = {}       # station_id -> Station
var staging: Array[int] = []        # 暂存槽 -> card_id，-1 表示空
var serve_slot: int = -1            # 出餐台上的 card_id

var held_card: int = -1             # 玩家手上拿的 card_id（-1 = 空手）

var shift_active := false
var shift_time_left := 0.0
var combo := 0
var combo_window := 3.0
var last_serve_at := -999.0
var served_count := 0
var lost_count := 0
var earned_total := 0
```

---

## 3. 工位状态机（收敛到 OrderCard）

**工位本身无状态机**。状态机在 OrderCard 上，只有 4 个状态：

```
        spawn
          │
          ▼
    ┌──────────┐  玩家拖到工位   ┌──────────┐
    │  QUEUE   │ ──────────────▶ │ STATION  │
    │ (排队中) │                 │ (加工中) │
    └──────────┘                 └──────────┘
          │                            │
          │ 耐心耗尽                    │ 工序完成
          ▼                            ▼
    ┌──────────┐                 ┌──────────┐
    │   LOST   │                 │ STAGING  │◀──┐
    └──────────┘                 │ (暂存)   │   │ 玩家拖回
                                 └──────────┘   │
                                       │        │
                                       │ 玩家拖到下一工位
                                       ▼        │
                                 ┌──────────┐   │
                                 │ STATION  │───┘
                                 └──────────┘
                                       │
                                       │ 最后一道工序完成
                                       ▼
                                 ┌──────────┐
                                 │  SERVE   │──▶ 结算 ──▶ DONE
                                 └──────────┘
```

**转移规则表**：

| 从 | 到 | 触发 | 条件 |
|---|---|---|---|
| QUEUE | STATION | 玩家拖拽 | `station.can_accept(card)` |
| QUEUE | LOST | 自动 | `patience_left <= 0` |
| STATION | STAGING | 自动 | 工序完成且非最后一道 |
| STATION | SERVE | 自动 | 工序完成且是最后一道 |
| STAGING | STATION | 玩家拖拽 | `station.can_accept(card)` |
| STAGING | LOST | 自动 | `patience_left <= 0` |
| SERVE | DONE | 自动 | 结算完成 |

**关键约束**：卡片在 STATION 时**不能被拖走**（防止半成品丢失）。玩家只能等它完成。这是"温柔治愈"的体现 —— 不惩罚手速。

---

## 4. 完整操作流（点击 → 信号 → 状态变更）

### 4.1 顾客排队（无实体）

- 排队区有 5 个**卡位底纹**（`QueueRail` 的子节点，纯视觉）。
- 每 spawn 一张 OrderCard，它占据 `queue` 数组的一个位置，视觉上 `OrderCardView` 出现在对应卡位。
- **顾客头像 + 环形耐心刻度**画在卡片上。耐心刻度是环形进度，不是数值条（符合约束）。
- 耐心状态用**头像表情**表达：平静 → 张望 → 皱眉 → 要走。4 档，无数字。

### 4.2 点餐（自动，非玩家操作）

- 顾客 spawn 时**自动点餐**（从当前时段可用菜品池随机）。
- 玩家看到的是"这张卡要做成什么" —— 卡片上显示菜品图标 + 工序链图标（如 `🥟 → 蒸 → 出`）。
- **无下拉菜单**：玩家不需要选菜，只需要按卡片指示操作。

### 4.3 工位点击（核心交互）

**手势语义**（复用 ui-002 的 ClickGestureRouter）：

| 手势 | 目标 | 行为 |
|---|---|---|
| TAP | 排队卡片 | 拾起卡片（`held_card = card_id`），卡片跟随鼠标 |
| TAP | 工位 | 若手上有卡且 `can_accept` → 放入；若工位有完成的卡 → 拾起 |
| TAP | 暂存槽 | 若手上有卡 → 放入；若槽有卡 → 拾起 |
| TAP | 出餐台 | 若手上有卡且 `is_ready_to_serve` → 结算 |
| SECONDARY | 手上卡片 | 放回原位置（取消拾起） |
| HOLD | 工位 | 显示该工位可接受的工序提示（场景提示，非菜单） |

**关键**：拾起卡片时，卡片**不离开 CardLayer**，只是 `held_card` 指向它，视觉上跟随鼠标。放下时更新 `loc` 和 `loc_ref`。

### 4.4 半成品暂存

- 3 个暂存槽。玩家可以把完成的半成品拖到暂存槽，腾出工位。
- 暂存槽**不消耗耐心**（这是设计上的"喘息空间"）。
- 暂存槽有容量上限 3，满了就不能再放。

### 4.5 手动搬运

- 搬运 = 拾起 + 放下。**无路径、无动画阻塞**。
- 搬运过程中卡片仍占用原位置（防止并发 bug）。
- 视觉上卡片从 A 飞到 B 用 Tween，0.15 秒，不阻塞输入。

### 4.6 出餐台

- 出餐台是**结算触发器**，不持有状态。
- 卡片进入 → 立即结算 → 卡片消失 → 连击 +1 → 播放"叮"音效。
- 结算金额 = `card.price`，rush 时段 ×1.5。

---

## 5. 信号清单（唯一事实源）

```gdscript
# BreakfastShopController 发出
signal card_spawned(card: OrderCard)           # 新顾客点餐
signal card_moved(card: OrderCard, from_loc: int, to_loc: int)  # 卡片位置变更
signal card_served(card: OrderCard, earned: int)  # 出餐结算
signal card_lost(card: OrderCard, reason: String) # 顾客离开
signal combo_changed(combo: int)               # 连击变化
signal shift_ended(summary: Dictionary)        # 打烊

# 内部信号（不对外）
signal _station_completed(station_id: String, card: OrderCard)
signal _patience_tick(card: OrderCard, state: int)
```

**HUD 只监听** `card_served` / `combo_changed` / `shift_ended`，不监听内部信号。

---

## 6. 顾客耐心模型

### 6.1 耐心时长公式

```
patience_total = base_patience × phase_multiplier × recipe_multiplier × rush_multiplier

base_patience = 45.0 秒
phase_multiplier:
  morning: 1.0
  lunch:   0.85   # 午市赶时间
  dinner:  1.1    # 晚市悠闲
recipe_multiplier = 1.0 + (stages.size() - 2) × 0.15   # 工序越多，耐心越长
rush_multiplier = 0.7 if is_rush else 1.0
```

### 6.2 耐心状态（4 档，无数字）

| 状态 | 阈值 | 视觉 | 音效 |
|---|---|---|---|
| 平静 | > 60% | 头像微笑，环形刻度绿色 | 无 |
| 张望 | 30%-60% | 头像左右看，刻度黄色 | 轻微"嗯？" |
| 皱眉 | 10%-30% | 头像皱眉，刻度橙色 | 叹气 |
| 要走 | < 10% | 头像转身，刻度红色闪烁 | 椅子摩擦声 |

**耐心只在 QUEUE 和 STAGING 状态消耗**。在 STATION 状态**暂停消耗**（玩家正在处理，不惩罚）。

### 6.3 耐心耗尽

- 卡片进入 LOST 状态，从 queue/staging 移除。
- `lost_count += 1`，`combo = 0`。
- 播放"顾客走了"的温柔提示（不是失败音效）。
- **不扣钱**，只损失潜在收入。

---

## 7. 随机客流模型

### 7.1 泊松过程

```gdscript
# 每帧调用
func _update_spawn(delta: float) -> void:
    if queue.size() >= QUEUE_SLOTS: return
    var lambda := _current_lambda()   # 每秒期望到达数
    if randf() < lambda * delta:
        _spawn_order()
```

### 7.2 时段权重表（数据驱动）

```csv
# data/breakfast_flow.csv
phase,base_lambda,rush_lambda,recipe_pool,patience_bonus
morning,0.35,0.8,"soy_milk|pork_bun|youtiao|porridge|tea_egg|rice_noodle_soup",0
lunch,0.5,1.2,"egg_rice|beef_noodles|lemon_tea|canteen_combo|chicken_rice",-5
dinner,0.4,0.9,"beef_noodles|roast_skewer|fried_noodles|sweet_soup|steamed_tilapia",5
```

### 7.3 难度曲线

- 每服务 5 位顾客，`lambda` 增加 5%，上限 2 倍。
- 每丢失 1 位顾客，`lambda` 减少 10%，下限 0.5 倍（温柔治愈，不惩罚）。
- rush 时段（07:30-08:30）`lambda` 直接切到 `rush_lambda`。

---

## 8. 失败条件

**本方案无"游戏失败"**。只有"打烊结算"。

| 情况 | 处理 |
|---|---|
| 顾客耐心耗尽 | 卡片消失，combo 归零，不扣钱 |
| 打烊时仍有卡片 | 自动结算为"未完成"，不扣钱 |
| 工位全部占用 | 新卡片继续排队，玩家自己调度 |
| 暂存槽满 | 无法再放，玩家必须处理 |
| 时间耗尽 | 正常打烊，结算 |

**唯一的"失败"是营收低于预期**，但这是玩家自己的目标，不是系统惩罚。

---

## 9. 与现有 KitchenManager 的融合

### 9.1 复用点

- `recipes.csv` 的 `pipeline` 字段直接解析为 `OrderCard.stages`。
- `STAGE_STATION_MAP` 直接用于 `Station.accepts_stages`。
- `MarketPhaseManager` 的时段判断直接复用。
- `BusinessManager` 的 `labor_stock` / `brain_stock` 作为开档门槛。

### 9.2 替换点

- **删除** `KitchenManager.orders` / `stations` / `staging` 三个数组。
- **删除** `_update_stations` / `_update_orders` / `_update_customer_flow` 三个方法。
- **新增** `BreakfastShopController` 作为早餐店专用控制器。
- `KitchenManager` 降级为**通用流水线引擎**，早餐店只是它的一个消费者。

### 9.3 迁移步骤

1. **阶段 1**：新建 `BreakfastShopController`，与 `KitchenManager` 并行运行，feature flag `breakfast.new_flow` 控制。
2. **阶段 2**：早餐店场景切换到新控制器，`KitchenManager` 只服务午市/晚市。
3. **阶段 3**：验证午市/晚市也可用新模型后，删除 `KitchenManager` 的旧数组。
4. **阶段 4**：存档迁移 —— 旧存档的 `orders` 数组转换为 `OrderCard` 列表。

---

## 10. 存档兼容

```gdscript
# 存档结构
{
    "breakfast": {
        "version": 2,
        "cards": [
            {
                "card_id": 12,
                "recipe_id": "pork_bun",
                "stage_index": 1,
                "stage_progress": 1.2,
                "loc": 1,
                "loc_ref": "steamer_1",
                "patience_left": 28.5,
                "price": 12
            }
        ],
        "stations": {"prep_1": 1, "steamer_1": 1},
        "combo": 3,
        "served_count": 8,
        "earned_total": 156
    }
}
```

**迁移规则**：
- 旧存档无 `breakfast` 字段 → 初始化空。
- 旧存档 `version: 1` → 把 `orders` 数组转换为 `cards`，`stages` 从 `recipe_id` 重新解析。
- 新存档 `version: 2` → 直接读取。

---

## 11. 性能预算

| 项 | 预算 | 说明 |
|---|---|---|
| OrderCard 数量 | ≤ 12 | 5 排队 + 6 工位 + 3 暂存 + 1 出餐 |
| 每帧计算 | ≤ 0.5ms | 12 张卡的 tick + 1 次 spawn 判定 |
| 信号发射 | ≤ 20/秒 | 用 0.12s 累加器节流（复用现有） |
| 视觉节点 | ≤ 12 | CardLayer 子节点数 = 卡片数 |
| 内存 | ≤ 50KB | 12 张卡 × 4KB |

---

## 12. 与主方案的关键差异总结

1. **无顾客实体** —— 顾客是卡片上的头像，不是 Actor。省掉寻路、碰撞、动画。
2. **无工位状态机** —— 状态机在 OrderCard 上，工位是纯函数。
3. **无独立暂存数组** —— 暂存是 OrderCard 的 `loc` 字段。
4. **无失败惩罚** —— 只有"顾客走了"，不扣钱。
5. **无下拉菜单** —— 所有操作是 TAP/SECONDARY/HOLD 三种手势。
6. **单时钟** —— 耐心和工序进度共用 `_process(delta)`。
7. **数据驱动** —— 客流、耐心、工序全部走 CSV。

**这套架构的核心优势**：整个早餐店只有一种可变对象，所有 bug 都收敛到 `OrderCard` 的状态转移上，可单测、可回放、可存档。

## 批判

## 批判A（qa_lead）

# 批判报告：两份方案的遗漏、冲突、死代码与测试漏洞

> 结论先行：**两份方案都不能直接执行**。主方案有 3 处 P0 阻塞（存档字段名冲突、`_stage_item` 语义自相矛盾、`_update_customer_flow` 与现有函数重名），独立方案有 2 处 P0 阻塞（`KitchenManager` 删除策略会破坏午市/晚市、`OrderCard` 无 `stages` 空数组保护）。以下逐条给出**可验证的返工要求**。

---

## A. 主方案（`breakfast_shop_layer.gd` 路线）的致命问题

### A1【P0｜死代码】`_update_customer_flow` 与现有函数重名

主方案 §10 声称"新增逻辑在 `_update_customers` / `_update_customer_flow` 中，**不修改现有函数签名**"，但 §0.1 门禁清单里明确列出 `_update_customer_flow` **已存在于 `kitchen_manager.gd`**。

**返工要求**：
- 执行 `grep -n "func _update_customer_flow" autoload/kitchen_manager.gd` 确认。
- 若存在：新函数**必须重命名**为 `_update_breakfast_customer_flow`，并在 `docs/BREAKFAST_FACTS.md` 记录旧函数行号与调用点。
- 若不存在：主方案 §0.1 的 grep 清单本身是错的，需修正门禁脚本。
- **断言**：`grep -c "func _update_customer_flow" autoload/kitchen_manager.gd` 返回值必须为 `0` 或 `1`，且新函数名与旧函数名不相等。

### A2【P0｜语义冲突】`_stage_item` 的 `next_stage` 参数自相矛盾

主方案 §3 定义 `StagedItem.next_stage` 为"下一道工序类型"，但 §12 V1 测试里写：

```gdscript
KitchenManager._stage_item(0, c.recipe_id, "steam")
```

这里传的是 `"steam"`（工序名），而 §5 状态机说"`item.next_stage` 的 station 类型 == 工位类型"。`STAGE_STATION_MAP` 的 key 是工序名（`prep`/`steam`/`fry`/`serve`），value 是工位类型（`prep`/`steamer`/`fryer`/`serve`）。**`"steam"` 是工序名，不是工位类型**。

**返工要求**：
- 明确 `_stage_item(order_id, recipe_id, next_stage)` 的第三个参数是**工序名**还是**工位类型**。
- 若为工序名：`_drop_item(station_type)` 内部必须做 `STAGE_STATION_MAP[next_stage] == station_type` 的映射比较。
- 若为工位类型：`StagedItem.next_stage` 字段名应改为 `next_station_type`。
- **断言**：写一个单测 `test_stage_item_semantics`，传入 `"steam"` 后 `tray[0].next_stage == "steam"`，且 `STAGE_STATION_MAP[tray[0].next_stage] == "steamer"`。

### A3【P0｜存档风险】`held_item` 未定义序列化行为

主方案 §11 D11 说"只存 `location_id / active_phase_id / served / failed / shift_earned`，**不存中间态**"，但 §3 定义了 `var held_item: StagedItem = null`。若玩家在 DRAG 中途退出，`held_item` 非空，读档后该引用悬空。

**返工要求**：
- 在 `end_shift` 和 `_save` 路径中显式 `held_item = null`。
- 在 `_load` 路径中显式 `held_item = null` 并清空 `tray` / `customers` / `orders`。
- **断言**：`godot --headless --save-check` 后，读档立即 `assert(KitchenManager.held_item == null and KitchenManager.tray.is_empty() and KitchenManager.customers.is_empty())`。

### A4【P1｜不可触达机制】`blocked` 状态的"TAP 清空"路径不成立

主方案 §5 状态机写：`blocked → idle` 通过"玩家 TAP 工位，把退回的半成品放回托盘（托盘有空位时）"。但 `blocked` 的**成因**就是托盘满。若托盘仍满，TAP 工位无处可放，状态机死锁。

**返工要求**：
- 明确 `blocked` 的退出条件：**必须托盘有空位**，否则 TAP 无效。
- 增加 `blocked` 状态下的视觉提示（工位闪烁 + 托盘高亮）。
- **断言**：单测 `test_blocked_deadlock`：托盘满 → 工位 blocked → TAP 工位 → 仍 blocked → 清空托盘一格 → TAP 工位 → idle。

### A5【P1｜测试漏洞】V1 的 `assert(KitchenManager.customers.size() == 2)` 无依据

主方案 §12 V1 断言"初始 2 单"，但 §8 随机客流是泊松过程，`start_shift_for` 后**不保证**恰好 2 个顾客。这个断言会 flaky。

**返工要求**：
- 改为 `assert(KitchenManager.customers.size() >= 0 and KitchenManager.customers.size() <= QUEUE_SLOTS)`。
- 或提供 `start_shift_for(seed: int)` 重载，测试时固定 seed。
- **断言**：连续跑 100 次 `start_shift_for`，`customers.size()` 的方差必须为 0（固定 seed 时）。

### A6【P1｜冲突】HUD 只读回显 vs `_modal_state = NONE` 强制

主方案 §0 说"HUD 只做只读回显"，§13 说"经营流程中强制 `_modal_state = NONE`"。但 `hud.gd` 的 `_modal_state` 是**HUD 内部状态**，`kitchen_manager` 无权强制。若 HUD 正在显示某个 modal（如结算面板），强制置 NONE 会破坏 HUD 自身状态机。

**返工要求**：
- 改为：`breakfast_shop_layer.gd` 在 `_ready` 时 emit `hud.set_modal_locked(true)`，`_exit_tree` 时 `false`。
- HUD 收到 `locked` 后**拒绝**打开新 modal，但**不强制关闭**已打开的。
- **断言**：`test_hud_lock`：locked 时调用 `hud.open_modal("x")` 返回 `false`，`_modal_state` 不变。

### A7【P2｜遗漏】`combo` 变量未在数据结构中声明

主方案 §6 操作流提到 `combo++` / `combo=0`，§7 耐心归零时 `combo = 0`，但 §3 新增成员变量清单里**没有 `combo`**。

**返工要求**：
- 在 §3 新增 `var combo: int = 0` 和 `var combo_window: float = 3.0`。
- 明确 `combo` 的衰减规则（是否随时间归零？还是仅出错归零？）。
- **断言**：`grep -n "var combo" autoload/kitchen_manager.gd` 必须命中。

### A8【P2｜遗漏】`_spawn_timer` 未声明

§8 用了 `_spawn_timer`，§3 未声明。若 `kitchen_manager.gd` 已有，需在 `docs/BREAKFAST_FACTS.md` 记录；若无，需新增。

**返工要求**：
- `grep -n "_spawn_timer" autoload/kitchen_manager.gd`。
- 结果写入 FACTS。

---

## B. 独立方案（`BreakfastShopController` 路线）的致命问题

### B1【P0｜破坏性】"删除 `KitchenManager.orders/stations/staging`"会打断午市/晚市

§9.2 写"**删除** `KitchenManager.orders` / `stations` / `staging` 三个数组"，§9.3 阶段 3 才"验证午市/晚市也可用新模型后删除"。但 §9.2 是**当前就要删**，§9.3 是**未来才删**，自相矛盾。

**返工要求**：
- §9.2 改为"**标记 deprecated**，不删除"。
- 删除动作推迟到 §9.3 阶段 3 之后，且必须有 `feature flag breakfast.new_flow` 保护。
- **断言**：`grep -n "var orders" autoload/kitchen_manager.gd` 在阶段 1/2 必须仍命中。

### B2【P0｜崩溃风险】`OrderCard.stages` 可能为空数组

§2.1 `current_stage()` 写 `return stages[stage_index] if stage_index < stages.size() else ""`，但 `is_ready_to_serve()` 写 `stages[-1] == "serve"`。若 `stages` 为空（`recipes.csv` 的 `pipeline` 字段缺失或格式错误），`stages[-1]` 会**越界崩溃**。

**返工要求**：
- `is_ready_to_serve()` 改为 `return stages.size() > 0 and stage_index >= stages.size() - 1 and stages[-1] == "serve"`。
- `_lookup_duration` 在 `stages` 为空时返回 `0.0` 并 emit `card_lost(card, "invalid_pipeline")`。
- **断言**：单测 `test_empty_pipeline`：构造 `stages = []` 的 OrderCard，调用 `is_ready_to_serve()` 不崩溃，返回 `false`。

### B3【P0｜存档风险】`loc_ref` 是字符串，读档后无法解析

§10 存档结构里 `"loc_ref": "steamer_1"`，但读档时 `stations` 字典的 key 是 `"steamer_1"`。若读档时 `stations` 尚未初始化（顺序问题），`loc_ref` 会指向不存在的工位。

**返工要求**：
- 读档顺序：先建 `stations`，再恢复 `cards`。
- 恢复 `cards` 时校验 `loc_ref` 是否在 `stations` 中，不在则 `card_lost(card, "orphan_loc_ref")`。
- **断言**：单测 `test_orphan_loc_ref`：构造 `loc_ref = "nonexistent"` 的存档，读档后该卡被 lost，不崩溃。

### B4【P1｜死代码】`Station.level` / `speed_multiplier` 无升级入口

§2.2 定义了 `level` 和 `speed_multiplier`，但全文**没有任何地方修改它们**。这是死代码。

**返工要求**：
- 要么删除这两个字段，要么在 §4.3 增加"TAP 工位 + 长按 = 升级"的交互。
- 若保留，需在 `data/config.csv` 增加 `station_upgrade_cost` 等键。
- **断言**：`grep -rn "speed_multiplier" scripts/` 必须至少有一处**写入**（非初始化）。

### B5【P1｜不可触达】`HOLD` 手势的"显示可接受工序提示"无实现路径

§4.3 写 `HOLD | 工位 | 显示该工位可接受的工序提示（场景提示，非菜单）`，但 §1 节点结构里**没有提示层**。`CardLayer` 只放卡片，`CounterLayer` 只放底纹。

**返工要求**：
- 在 §1 增加 `HintLayer (Node2D)`，或在 `StationRail` 下增加提示子节点。
- 明确提示的显示时长（HOLD 持续期间）和消失条件（松手）。
- **断言**：`test_hold_hint`：HOLD 工位 0.5s 后 `HintLayer.get_child_count() > 0`，松手后归零。

### B6【P1｜测试漏洞】§11 性能预算"每帧 ≤ 0.5ms"无测量方法

"12 张卡的 tick + 1 次 spawn 判定 ≤ 0.5ms"是拍脑袋数字，没有 benchmark 脚本。

**返工要求**：
- 提供 `bench_breakfast.gd`，用 `Time.get_ticks_usec()` 测量 1000 帧平均耗时。
- **断言**：`bench_breakfast.gd` 输出 `avg_frame_us < 500`。

### B7【P1｜冲突】"耐心只在 QUEUE 和 STAGING 消耗"vs"STATION 暂停消耗"

§6.2 写"耐心只在 QUEUE 和 STAGING 状态消耗。在 STATION 状态暂停消耗"，但 §3 状态机图里 `STATION → STAGING` 是**自动**转移（工序完成），玩家无法在 STATION 停留。这意味着玩家把卡放进工位后，耐心**立即暂停**，直到工序完成回到 STAGING 才恢复消耗。这会导致**玩家故意把卡塞进工位来冻结耐心**的 exploit。

**返工要求**：
- 改为：耐心在 QUEUE / STATION / STAGING **全部消耗**，但 STATION 状态下消耗速率 ×0.5（温柔但不 exploit）。
- 或：STATION 状态耐心暂停，但**工位有最大占用时间**（如 2× stage_duration），超时强制弹出到 STAGING。
- **断言**：单测 `test_patience_freeze_exploit`：把卡放进工位 60s，耐心值必须下降（或卡被强制弹出）。

### B8【P2｜遗漏】`card_moved` 信号的 `from_loc` / `to_loc` 是 int，但 `Loc` 枚举是 int，HUD 无法区分

§5 信号 `card_moved(card, from_loc: int, to_loc: int)`，§2.1 `enum Loc { QUEUE, STATION, STAGING, HAND, SERVE, DONE }`。HUD 收到 int 后需要自己映射回枚举，但 HUD 不应该知道 `Loc` 枚举（耦合）。

**返工要求**：
- 信号改为 `card_moved(card, from_loc_name: String, to_loc_name: String)`，或提供 `Loc.keys()[from_loc]`。
- **断言**：`test_card_moved_signal`：emit 后 HUD 收到的字符串是 `"QUEUE"` / `"STATION"` 等。

### B9【P2｜遗漏】`data/breakfast_flow.csv` 的 `recipe_pool` 含午市/晚市菜品

§7.2 的 `lunch` 行 `recipe_pool` 含 `egg_rice|beef_noodles|...`，但早餐店场景**不应该**出现午市菜品。这是数据污染。

**返工要求**：
- `breakfast_flow.csv` 只保留 `morning` 行，或明确 `lunch`/`dinner` 行由午市/晚市场景读取。
- **断言**：`grep "lunch" data/breakfast_flow.csv` 在早餐店场景加载时**不被读取**。

---

## C. 两份方案的共同漏洞

### C1【P0｜测试漏洞】都没有"存档中途退出"的端到端测试

主方案 §12 V4 只断言"存档中不含 `customers/tray/held_item`"，独立方案 §10 只给结构。**都没有测试**：玩家在 DRAG 中途、工位 busy 中途、顾客耐心剩 1s 时退出，读档后是否崩溃。

**返工要求**：
- 新增 `test_save_mid_action`：模拟 5 种中途状态，保存 → 读档 → 断言不崩溃且状态一致。
- **断言**：`godot --headless --test-save-mid-action` 退出码为 0。

### C2【P0｜测试漏洞】都没有"随机客流可复现"的测试

两份方案都用 `randf()`，但**都没有 seed 注入**。CI 上跑测试会 flaky。

**返工要求**：
- `start_shift_for(location_id, seed: int = -1)`，seed >= 0 时 `seed(seed)`。
- **断言**：同 seed 跑两次，`customers` 序列完全一致。

### C3【P1｜冲突】主方案"托盘容量 6"vs 独立方案"暂存槽 3"

主方案 §3 `TRAY_CAPACITY := 6`，独立方案 §2.3 `STAGING_SLOTS := 3`。若两个方案都要落地（feature flag 切换），玩家体验不一致。

**返工要求**：
- 统一为 `ConfigDB.get_number("breakfast", "staging_capacity", 6)`。
- 两个方案都从 ConfigDB 读，不硬编码。
- **断言**：`grep -rn "TRAY_CAPACITY\|STAGING_SLOTS" scripts/` 必须命中 ConfigDB 读取，不能是 `const`。

### C4【P1｜遗漏】都没有"点击穿透"处理

`CardLayer` 的卡片和 `StationRail` 的底纹重叠时，TAP 应该命中谁？两份方案都没说。

**返工要求**：
- 明确 z-order：`CardLayer.z_index > CounterLayer.z_index`。
- 明确 `ClickGestureRouter` 的命中优先级：卡片 > 工位 > 底纹。
- **断言**：`test_click_priority`：卡片覆盖工位时 TAP 命中卡片。

### C5【P1｜遗漏】都没有"暂停/恢复"处理

玩家按 ESC 暂停时，`_process(delta)` 是否继续？耐心是否继续消耗？

**返工要求**：
- 明确 `get_tree().paused` 时 `_process` 不执行，耐心冻结。
- **断言**：`test_pause`：暂停 10s 后恢复，耐心值不变。

### C6【P2｜遗漏】都没有"多语言/文案"处理

`customer_name`（独立方案 §2.1）是硬编码中文。主方案 §7 用颜色表达耐心，无文案。若项目要 i18n，需预留 key。

**返工要求**：
- `customer_name` 改为 `customer_name_key: String`，由 HUD 查表。
- **断言**：`grep -rn "customer_name = \"" scripts/` 必须为空。

---

## D. 返工优先级与执行顺序

| 优先级 | 编号 | 阻塞性 | 预计工时 |
|---|---|---|---|
| P0 | A1, A2, A3 | 是 | 0.5d |
| P0 | B1, B2, B3 | 是 | 0.5d |
| P0 | C1, C2 | 是 | 1d |
| P1 | A4, A5, A6, B4, B5, B6, B7, C3, C4, C5 | 否 | 2d |
| P2 | A7, A8, B8, B9, C6 | 否 | 0.5d |

**执行顺序**：
1. 先修 P0（A1–A3, B1–B3, C1–C2），否则任何实现都会引入不可测 bug。
2. 再修 P1，否则测试覆盖率不达标。
3. P2 可延后到首周观察期。

**最终门禁**：所有 P0 修复后，必须通过：
```bash
godot --headless --test-save-mid-action
godot --headless --test-seed-reproducibility
godot --headless --test-empty-pipeline
godot --headless --test-orphan-loc-ref
godot --headless --test-blocked-deadlock
```
退出码全为 0 才允许进入实现阶段。

## 批判B（gameplay_planner）

# 批判 Agent 裁决书

> 对两份方案逐条审查。**主方案**（下称 M）与**独立方案**（下称 I）。只输出可执行批判与返工要求，不做方案选型建议。

---

## 一、致命冲突（必须先裁决，否则无法开工）

### C1. 两份方案的"唯一状态载体"互斥，且都声称自己是事实源

- M：`kitchen_manager.gd` 内的 `Customer/Order/Station/StagedItem` 四套类 + `customers/tray/held_item` 三个数组。
- I：`OrderCard` 单一类 + `cards/queue/stations/staging/serve_slot/held_card` 六个容器。

**冲突点**：M 的 `Station` 持有 `current_order_id` 和 `progress`；I 的 `Station` 无状态，进度在 `OrderCard.stage_progress`。两者对"工位进度存在哪"给出相反答案。

**返工要求**：
- 两份方案各自在 §0 增加一节 **"状态归属表"**，逐字段列出：字段名 / 归属对象 / 生命周期 / 谁写谁读。M 必须解释为什么 `progress` 在 Station 而不在 Order；I 必须解释为什么 `Station.slot` 是引用而非拷贝。
- 两份方案各自声明：**若与本表冲突，以本表为准**。否则后续实现者无法判断 `station.progress` 和 `card.stage_progress` 哪个是真的。

---

### C2. 存档策略正面冲突，且都未覆盖"读档后正在加工的工序"

- M §D11：**不存中间态**，中途退出即放弃本班。
- I §10：**存全部卡片**，含 `stage_index/stage_progress/loc/loc_ref`。

**冲突点**：M 的"放弃本班"与 I 的"完整恢复"是两种产品行为，不能同时成立。更严重的是：**两份方案都没定义"读档时 `stage_progress` 处于 `[0, duration)` 区间"的恢复语义**——是继续、重置、还是立即完成？

**返工要求**：
- M 必须回答：玩家在 shift 中途按 ESC 退出，再进入，看到什么？空店？还是"本班已作废"提示？**必须给出具体 UI 文案和状态机入口**。
- I 必须回答：读档时 `stage_progress=1.2, stage_duration=3.0`，恢复后是 `1.2` 继续跑，还是 `0` 重跑？如果是 `1.2`，`_process` 第一帧的 `delta` 如何避免跳变？给出伪代码。
- 两份方案都必须处理：**读档时 `loc=STATION` 但 `loc_ref` 指向的工位在存档中不存在**（工位被删/改名）的降级路径。

---

### C3. 顾客耐心的"暂停语义"只有 I 定义了，M 未定义

- I §6.2：**耐心只在 QUEUE 和 STAGING 消耗，STATION 暂停**。
- M §7：`_update_customers` 对所有 `state=="waiting"` 的顾客无条件 `patience -= delta`。

**冲突点**：M 的顾客一旦接单就持续掉耐心，即使玩家正在加工。这会导致"玩家越努力做，顾客越容易走"的悖论。I 的设计避免了这点，但 I 没定义"卡片在 HAND（玩家手持）时耐心是否消耗"。

**返工要求**：
- M 必须明确：接单后（`state="waiting"`）耐心是否继续掉？如果掉，玩家把订单拖到工位加工时，顾客耐心和工序进度是**两个独立倒计时**，玩家无法通过操作影响耐心——这是设计意图还是漏洞？
- I 必须补充：`loc=HAND` 时耐心是否消耗？如果消耗，玩家把卡片拿在手上发呆就能耗死顾客，是否合理？如果不消耗，玩家可以把卡片拿在手上无限拖延——是否要加"手持超时"？
- 两份方案都必须给出**耐心消耗的状态白名单**（哪些 `loc/state` 消耗，哪些不消耗），并说明理由。

---

### C4. 失败条件的定义域不同，且 M 的 F3 自相矛盾

- M §9：四条失败条件，其中 F3"托盘溢出"**不计 failed**，但 §D9 又把"托盘溢出"列为失败条件之一。
- I §8：**无游戏失败**，只有打烊结算。

**冲突点**：M 内部自相矛盾（D9 vs F3）。I 的"无失败"与 M 的"四条失败"是产品级分歧。

**返工要求**：
- M 必须删除 D9 中的"托盘溢出"或修改 F3 使其计入 failed，二者只能留一个。给出裁决理由。
- M 的 F4"时间耗尽未达 target，`failed += (target - served)`"——**`failed` 是计数器还是分数？** 如果是计数器，`failed += 5` 意味着什么？如果是分数，为什么和 F1/F2 的 `failed++` 共用同一变量？**必须拆成两个变量**（`lost_count` 和 `shortfall`），否则 HUD 无法正确显示。
- I 必须回答：如果"无失败"，那么 `combo` 归零的惩罚是什么？玩家为什么要在意顾客走掉？给出**非惩罚性的负反馈设计**（如：走掉的顾客不再出现在本班、影响打烊评价文案）。

---

### C5. 与现有 `kitchen_manager.gd` 的融合方式互斥

- M §10：**保留** `_update_stations/_update_orders/_update_customer_flow`，新增逻辑并行。
- I §9.2：**删除** `orders/stations/staging` 三个数组和 `_update_stations/_update_orders/_update_customer_flow` 三个方法。

**冲突点**：M 是增量改造，I 是替换重写。两者对"现有代码是否保留"给出相反指令。更严重的是：**两份方案都没有验证 `kitchen_manager.gd` 当前是否真的被午市/晚市使用**——如果午市/晚市也依赖这些数组，I 的删除会直接破坏午市。

**返工要求**：
- 两份方案都必须先执行 G0.1 门禁，并在 `docs/BREAKFAST_FACTS.md` 中记录：**`orders/stations/staging` 三个数组当前被哪些场景/脚本引用**（用 `grep -rn "\.orders\|\.stations\|\.staging" scripts/`）。
- I 必须补充：如果午市/晚市也引用这些数组，§9.2 的"删除"如何不破坏它们？给出**兼容层方案**（如：保留数组但标记 deprecated，新代码不读）。
- M 必须补充：新增的 `customers/tray/held_item` 与现有 `orders/stations` 是否会有**同一订单被两个数组同时引用**的情况？如果有，谁是事实源？

---

## 二、死代码与不可触达机制

### D1. M 的 `Station.blocked` 状态不可达

M §5 状态机：`busy → blocked` 的触发是"SECONDARY 取消，半成品退回托盘；若托盘满则 blocked"。但 §5 又写 `blocked → idle` 的触发是"玩家 TAP 工位，把退回的半成品放回托盘（托盘有空位时）"。

**问题**：如果托盘满导致 blocked，而解除 blocked 又需要托盘有空位——**玩家如何让托盘有空位？** 只能通过出餐腾出空间。但出餐需要成品，成品需要工位加工，工位 blocked 无法加工。**死锁**。

**返工要求**：M 必须给出 blocked 状态的**唯一解除路径**，并证明该路径在托盘满时可达。可选方案：
- (a) blocked 时允许玩家 TAP 工位**丢弃**半成品（有惩罚）；
- (b) blocked 时允许玩家把半成品**放回原订单**（回退 stage_index）；
- (c) 托盘容量动态扩展。
必须选一个并写入状态机。

---

### D2. M 的 `held_item` 在存档中不存在，但 §D11 又说"不存中间态"

M §3 定义 `var held_item: StagedItem = null`，§D11 说"不存中间态（半成品/托盘/顾客队列）"。

**问题**：如果玩家在手持半成品时退出，`held_item` 丢失，但该半成品对应的 `order_id` 仍在 `orders` 中，`current_stage` 已推进。**读档后订单状态与实物不一致**。

**返工要求**：M 必须明确：`held_item` 非空时是否允许退出？如果不允许，给出拦截逻辑；如果允许，给出读档后的订单状态回滚规则。

---

### D3. I 的 `Station.tick` 返回值 `{completed: bool, card: OrderCard}` 中 `card` 字段在 `completed=false` 时未定义

I §2.2：
```gdscript
func tick(delta: float) -> Dictionary:
    if slot == null: return {"completed": false}
    ...
    return {"completed": false}
```
两个 `false` 分支都没返回 `card` 键。调用方如果写 `var c = result.card` 会崩。

**返工要求**：I 必须统一返回结构，或在文档中明确"`completed=false` 时 `card` 键不存在，调用方必须先判 `completed`"。**推荐前者**（返回 `{"completed": false, "card": null}`），因为 GDScript 的 Dictionary 访问不存在的键会报错。

---

### D4. I 的 `OrderCard.is_ready_to_serve()` 逻辑错误

```gdscript
func is_ready_to_serve() -> bool:
    return stage_index >= stages.size() - 1 and stages[-1] == "serve"
```

**问题**：`stage_index >= stages.size() - 1` 在 `stage_index == stages.size() - 1` 时为真，此时 `current_stage()` 返回 `stages[-1]`（即 `"serve"`），但 `"serve"` 工序**还没执行**。`is_ready_to_serve()` 应该判断"所有工序已完成"，即 `stage_index >= stages.size()`。

**返工要求**：I 必须修正为 `stage_index >= stages.size()`，并检查 `advance_stage()` 在 `stage_index == stages.size()` 时的行为（`current_stage()` 返回 `""`，`stage_duration` 不更新——是否正确？）。

---

### D5. I 的 `Station.accepts_stages` 从 `STAGE_STATION_MAP` 反查，但未定义反查方向

I §2.2：`accepts_stages: Array[String] = []  # 从 STAGE_STATION_MAP 反查`。

**问题**：`STAGE_STATION_MAP` 是 `stage → station_type` 的正向映射（M §10 确认）。反查得到的是 `station_type → [stages]`。但 I 的 `can_accept` 判断 `card.current_stage() in accepts_stages`——这里 `accepts_stages` 是 stage 列表还是 station_type 列表？**语义不清**。

**返工要求**：I 必须明确 `accepts_stages` 存的是**工序名列表**（如 `["prep"]`）还是**工位类型列表**（如 `["prep_station"]`），并给出 `STAGE_STATION_MAP` 反查的具体代码。

---

### D6. M 的 `_spawn_customer` 与 `_update_customer_flow` 的调用关系未定义

M §8 的 `_update_customer_flow` 调用 `_spawn_customer()`，但 §3 的数据结构中 `Customer` 类没有 `spawn` 相关字段，§4 的信号列表也没有 `customer_spawned`（只有 `customer_arrived`）。

**问题**：`_spawn_customer` 是私有方法还是公开方法？它 emit 哪个信号？`customer_arrived` 的参数是 `Dictionary` 还是 `Customer`？M §4 写 `signal customer_arrived(customer: Dictionary)`，但 §3 定义的是 `class Customer`。**类型不一致**。

**返工要求**：M 必须统一：信号参数用 `Dictionary` 还是 `Customer` 对象？如果用 `Dictionary`，给出 `_customer_to_dict` 的字段列表；如果用 `Customer`，修改信号签名。**不能两套并存**。

---

## 三、测试漏洞

### T1. M 的 V1 单元测试断言 `customers.size() == 2`，但 §8 的 spawn 逻辑是随机的

M §12 V1：
```gdscript
KitchenManager.start_shift_for("breakfast_shop")
assert(KitchenManager.customers.size() == 2)  # 初始 2 单
```

**问题**：§8 的 `_update_customer_flow` 用 `randf() < spawn_chance` 决定是否生成，且 `_spawn_timer` 初始值未定义。**"初始 2 单"从哪来？** 如果 `start_shift_for` 不预生成，断言必失败。

**返工要求**：M 必须明确 `start_shift_for` 是否预生成顾客。如果预生成，给出预生成数量和 recipe 选择规则；如果不预生成，修改 V1 断言为"初始 0 单，手动调用 `_spawn_customer` 两次后为 2 单"。

---

### T2. M 的 V1 测试直接调用 `_stage_item` 和 `_update_customers` 等私有方法

M §12 V1 调用 `KitchenManager._stage_item(0, c.recipe_id, "steam")`。

**问题**：GDScript 中下划线前缀是约定，不是访问控制。但**测试直接调用私有方法意味着测试与实现耦合**——如果实现重构（如 I 方案替换），测试全废。

**返工要求**：M 必须为测试提供**公开的测试钩子**（如 `debug_stage_item`）或**事件注入接口**（如 `simulate_station_complete(station_type)`）。V1 测试不得直接调用 `_` 前缀方法。

---

### T3. I 的测试方案完全缺失

I 全文没有 §12 验证步骤，没有单元测试，没有场景验证，没有手动清单。

**返工要求**：I 必须补充与 M §12 对等的验证章节，至少包含：
- 单元测试：`OrderCard` 状态转移（QUEUE→STATION→STAGING→STATION→SERVE→DONE）的每条边。
- 边界测试：`stage_index == stages.size()` 时的 `current_stage()` 返回值。
- 存档测试：`version:1 → version:2` 迁移的往返一致性。
- 性能测试：12 张卡同时 tick 的帧时间。

---

### T4. 两份方案都未测试"顾客耐心归零时卡片正在 STATION 加工"

- M：`_update_customers` 遍历 `customers`，但 `Customer.state` 只有 `"waiting"|"served"|"left"`，**没有"加工中"状态**。如果顾客耐心归零时订单正在工位加工，`customer_left` 发出，但 `orders` 中的订单和工位上的半成品如何处理？**未定义**。
- I：§6.2 说"耐心只在 QUEUE 和 STAGING 消耗"，所以 STATION 时不会归零。但**如果卡片从 STATION 完成回到 STAGING 时耐心已经很低**，下一帧就归零——此时卡片在 STAGING，`loc_ref` 指向暂存槽，`card_lost` 发出后暂存槽是否清空？**未定义**。

**返工要求**：
- M 必须补充：顾客耐心归零时，如果其订单正在工位加工，是**立即中断工位**还是**等工序完成再离场**？给出裁决和代码路径。
- I 必须补充：`card_lost` 发出时，如果 `loc=STAGING`，`staging` 数组中对应的槽位是否置 `-1`？如果 `loc=STATION`（理论上不会，但防御性编程），`station.slot` 是否置 `null`？

---

### T5. 两份方案都未测试"同一 recipe 的多个订单同时存在"

- M §8：**不生成重复 recipe 的顾客**（同一时刻队列内 recipe 唯一）。但**托盘中的半成品和工位上的订单可能来自不同顾客的同一 recipe**。玩家 DRAG 半成品到工位时，如何区分是哪个订单的？
- I：`OrderCard` 有 `card_id`，理论上可区分。但 `Station.can_accept` 只判断 `card.current_stage() in accepts_stages`，**不判断 recipe**。如果两个 `pork_bun` 订单都在做，玩家把 A 的半成品拖到 B 的工位，会发生什么？

**返工要求**：
- M 必须明确：`StagedItem` 的 `order_id` 在 DRAG 到工位时是否校验？如果工位已有同 recipe 的订单，是否允许合并？
- I 必须明确：`Station.slot` 是单个 `OrderCard`，如果玩家把 B 的卡片拖到已有 A 卡片的工位，`can_accept` 返回 `false`（因为 `slot != null`），但**玩家如何知道是"工位忙"还是"工序不匹配"**？给出视觉反馈方案。

---

## 四、数据与配置漏洞

### F1. M 的 `data/breakfast_layout.csv` 坐标与 `world-002` 的场景分区冲突未验证

M §2 给出硬编码坐标（如 `queue_0,320,880`），§13 风险表说"与 world-002 场景分区冲突"是 P2，缓解措施是"坐标由 world-002 提供，本方案只读"。

**问题**：§2 又写"坐标来源：全部由 `data/breakfast_layout.csv` 提供（新增）"。**到底是 world-002 提供还是本方案新增？** 如果是本方案新增，P2 风险的缓解措施是假的。

**返工要求**：M 必须明确 `breakfast_layout.csv` 的**所有权**：是本方案创建并维护，还是 world-002 创建本方案只读？如果是前者，删除 §13 的 P2 风险行；如果是后者，§2 的 CSV 内容改为"占位，实际由 world-002 填充"。

---

### F2. I 的 `data/breakfast_flow.csv` 中 `recipe_pool` 包含非早餐 recipe

I §7.2：
```csv
lunch,0.5,1.2,"egg_rice|beef_noodles|lemon_tea|canteen_combo|chicken_rice",-5
dinner,0.4,0.9,"beef_noodles|roast_skewer|fried_noodles|sweet_soup|steamed_tilapia",5
```

**问题**：M §G0.3 确认早餐店菜单只有 7 条（`red_bean_bun/soy_milk/pork_bun/rice_noodle_soup/youtiao/porridge/tea_egg`）。I 的 `lunch/dinner` 池包含 `egg_rice/beef_noodles` 等**非早餐 recipe**。如果早餐店只营业早晨，这些池永远不会被使用——**死配置**。

**返工要求**：I 必须明确：早餐店是否只跑 `morning` 时段？如果是，删除 `lunch/dinner` 行；如果否，说明早餐店如何切换到午市/晚市，以及 `BreakfastShopController` 如何与 `MarketPhaseManager` 同步。

---

### F3. M 的 `ConfigDB.get_number("breakfast", "patience_base", 45.0)` 与 §G0.4 的"新增键必须带默认值"一致，但 §A3 的追加清单未列出 `patience_base`

M §11 A3：追加 `breakfast.patience_base / patience_per_stage / customer_interval / spawn_chance / tray_capacity`。
M §7 代码：`ConfigDB.get_number("breakfast", "patience_base", 45.0)`。
M §8 代码：`ConfigDB.get_number("breakfast", "customer_interval", 6.0)`。

**问题**：§8 用的是 `customer_interval`，§A3 也是 `customer_interval`，但 §G0.4 提到的是 `customer_spawn_interval`。**三个名字**。

**返工要求**：M 必须统一配置键名，并在 `docs/BREAKFAST_FACTS.md` 中列出**最终键名表**（键名 / 类型 / 默认值 / 用途）。所有代码引用必须与此表一致。

---

### F4. I 的 `patience_total` 公式中 `recipe_multiplier` 在 `stages.size() < 2` 时为负

I §6.1：
```
recipe_multiplier = 1.0 + (stages.size() - 2) × 0.15
```

**问题**：如果某 recipe 只有 1 道工序（`stages.size() == 1`），`recipe_multiplier = 1.0 + (-1) × 0.15 = 0.85`。如果只有 0 道（异常数据），`recipe_multiplier = 0.7`。**耐心被缩短**，与"工序越多耐心越长"的设计意图相反。

**返工要求**：I 必须加 `max(0, stages.size() - 2)` 或改为 `1.0 + stages.size() × 0.15`，并说明早餐 7 条 recipe 的实际 `stages.size()` 分布。

---

## 五、不可触达机制

### U1. M 的 `Station.blocked` 状态在 UI 上无表达

M §5 定义 `blocked` 状态，§D12 说"槽位用暖色圆角卡片"，但**没有定义 blocked 工位的视觉表达**。玩家如何知道工位被阻塞？

**返工要求**：M 必须为 `idle/busy/blocked` 三态各定义**视觉表达**（颜色/图标/粒子），并说明 blocked 时玩家 TAP 工位的反馈。

---

### U2. I 的 `HOLD` 手势"显示该工位可接受的工序提示"未定义提示形式

I §4.3：`HOLD | 工位 | 显示该工位可接受的工序提示（场景提示，非菜单）`。

**问题**："场景提示"是什么？气泡？高亮？粒子？如果是气泡，气泡内容是什么？如果是高亮，高亮哪些元素？**未定义**。

**返工要求**：I 必须给出 HOLD 的具体视觉方案，并说明**如何避免与"下拉菜单"约束冲突**（提示是只读的，不可点击选择）。

---

### U3. I 的 `SECONDARY | 手上卡片 | 放回原位置（取消拾起）` 中"原位置"未定义

I §4.3：`SECONDARY | 手上卡片 | 放回原位置（取消拾起）`。

**问题**：如果玩家从 QUEUE 拾起卡片，然后走到工位区，按 SECONDARY——"原位置"是 QUEUE 的哪个槽？如果原槽已被新卡片占用怎么办？

**返工要求**：I 必须定义 `OrderCard` 的 `origin_loc` 和 `origin_ref` 字段，并说明原位置被占用时的降级路径（如：放到最近的空暂存槽，或拒绝 SECONDARY）。

---

### U4. M 的 `held_item` 在 DRAG 过程中如果玩家松开鼠标到无效区域，行为未定义

M §D5：`DRAG 半成品从托盘到工位`。但**如果玩家拖到空白区域松开**，`held_item` 是回到托盘、留在手上、还是消失？

**返工要求**：M 必须定义 DRAG 的**有效落点集合**和**无效落点的回退行为**。

---

## 六、返工优先级

| 优先级 | 条目 | 阻塞对象 |
|---|---|---|
| P0 | C1, C2, C5 | 两份方案都无法开工 |
| P0 | D1（M 的 blocked 死锁） | M 无法实现 |
| P0 | D4（I 的 is_ready_to_serve 逻辑错误） | I 无法出餐 |
| P1 | C3, C4, D2, D3, D5, D6 | 实现后必出 bug |
| P1 | T1, T2, T3, T4, T5 | 测试无效 |
| P1 | F1, F2, F3, F4 | 配置错误 |
| P2 | U1, U2, U3, U4 | 体验缺陷 |

---

## 七、返工交付物清单

两份方案各自补充以下内容后重新提交：

1. **状态归属表**（C1）
2. **存档语义定义**（C2），含读档时 `stage_progress` 的恢复规则
3. **耐心消耗状态白名单**（C3）
4. **失败条件最终版**（C4），M 需拆分 `failed` 变量
5. **现有代码引用清单**（C5），基于 `grep` 结果
6. **blocked 状态解除路径**（D1）
7. **`held_item` 退出处理**（D2）
8. **`tick` 返回值统一**（D3）
9. **`is_ready_to_serve` 修正**（D4）
10. **`accepts_stages` 语义明确**（D5）
11. **信号参数类型统一**（D6）
12. **测试钩子接口**（T2）
13. **I 的完整验证章节**（T3）
14. **耐心归零时加工中订单的处理**（T4）
15. **同 recipe 多订单的区分机制**（T5）
16. **`breakfast_layout.csv` 所有权**（F1）
17. **I 的时段范围明确**（F2）
18. **配置键名统一表**（F3）
19. **`recipe_multiplier` 修正**（F4）
20. **blocked 视觉表达**（U1）
21. **HOLD 提示方案**（U2）
22. **SECONDARY 原位置定义**（U3）
23. **DRAG 无效落点回退**（U4）

**未完成以上 23 项返工前，两份方案均不得进入实现阶段。**

## 综合决策

# 早餐店点击经营 × 多工序流水线融合 —— 最终可执行方案

> **综合裁决 Agent 输出**。本方案是主方案（M）、独立方案（I）、批判 A（qa_lead）、批判 B（gameplay_planner）的唯一合并结果。
> **裁决原则**：以 M 的"增量改造 + 复用 kitchen_manager"为骨架（避免 I 的破坏性删除），吸收 I 的"OrderCard 单一状态载体"（消除 M 的四套类冗余），强制通过批判 A/B 的全部 P0 返工项。
> **唯一事实源**：`docs/BREAKFAST_FACTS.md`（门禁结果）+ `data/breakfast_layout.csv`（坐标）+ `data/recipes.csv`（工序）+ `data/config.csv`（数值）。执行者不得引用本方案之外的任何字段/坐标/数值。

---

## 0. 决策摘要（逐条裁决）

| # | 争议 | 最终裁决 | 依据 |
|---|---|---|---|
| **D1** | 状态载体：M 四套类 vs I 单 OrderCard | **采用 I 的 OrderCard 单一状态载体**，但**保留 M 的增量改造路径**（不删除 kitchen_manager 现有数组） | 批判 A/B 均指出 M 四套类冗余；I 的破坏性删除被 B1 否决 |
| **D2** | 工位状态：M 有状态机 vs I 无状态 | **工位无状态**，进度存在 `OrderCard.stage_progress`；工位只持有 `slot: OrderCard` 引用 | 批判 C1 要求状态归属表，单载体消除歧义 |
| **D3** | 顾客表现 | **无 Actor**。顾客 = OrderCard 上的头像 + 环形耐心刻度，占据 QueueRail 的固定卡位 | 硬约束"避免真实人走来走去" |
| **D4** | 点餐 | **自动点餐**（spawn 时从时段池随机），玩家不选菜。卡片显示菜品图标 + 工序链 | 硬约束"无下拉菜单" |
| **D5** | 交互手势 | **TAP 拾起/放下**、**SECONDARY 取消拾起**、**HOLD 显示工序提示**。无 DRAG（用 TAP 拾起 + TAP 放下替代，避免 U4 的无效落点问题） | 批判 U4 要求定义 DRAG 无效落点；TAP-TAP 模式天然无此问题 |
| **D6** | 半成品暂存 | **暂存槽 3 个**（采纳 I），容量从 `ConfigDB.get_number("breakfast", "staging_capacity", 3)` 读取，**不硬编码** | 批判 C3 要求统一从 ConfigDB 读 |
| **D7** | 出餐台 | **结算触发器**，不持有状态。卡片进入即结算 | I §4.6 |
| **D8** | 顾客耐心 | **消耗白名单**：QUEUE 消耗 ×1.0，STATION 消耗 ×0.5，STAGING 消耗 ×1.0，HAND 消耗 ×1.0，SERVE/DONE 不消耗 | 批判 C3 要求白名单；批判 B7 否决 I 的"STATION 暂停"exploit |
| **D9** | 随机客流 | **泊松过程**，`lambda` 从 `data/breakfast_flow.csv` 读，**只保留 morning 行**（批判 F2） | I §7.1 + 批判 F2 |
| **D10** | 失败条件 | **无游戏失败**（采纳 I）。只有 `lost_count`（顾客走掉）和 `shortfall`（打烊未达 target）两个**独立计数器**，不共用 `failed` | 批判 C4 要求拆分变量 |
| **D11** | 存档 | **存全部 OrderCard**（采纳 I），但**读档时 `stage_progress` 重置为 0**（避免 delta 跳变，批判 C2） | 批判 C2 要求明确恢复语义 |
| **D12** | 与 kitchen_manager 融合 | **增量改造**：保留现有 `orders/stations/staging` 数组（标记 deprecated），新增 `BreakfastShopController` 并行运行，feature flag `breakfast.new_flow` 控制 | 批判 B1 否决删除；批判 C5 要求引用清单 |
| **D13** | 画风 | 暖色圆角卡片，耐心用环形刻度 + 头像表情 4 档，无进度条 | 硬约束 + I §6.2 |
| **D14** | 配置键名 | 统一为 `breakfast.patience_base / patience_per_stage / customer_interval / spawn_chance / staging_capacity / station_speed_multiplier` | 批判 F3 要求统一表 |

---

## 1. 前置门禁（阻塞性，未通过不得进入实现）

所有结果写入 `docs/BREAKFAST_FACTS.md`。

### G0.1 现有 API 与引用清单
```bash
grep -n "^func \|^signal \|^var \|^const " autoload/kitchen_manager.gd
grep -rn "\.orders\|\.stations\|\.staging" scripts/ --include=*.gd
grep -n "func _update_customer_flow" autoload/kitchen_manager.gd
grep -n "_spawn_timer" autoload/kitchen_manager.gd
```
**裁决**：
- 记录 `orders/stations/staging` 三个数组的**所有引用点**（批判 C5）。
- 若 `_update_customer_flow` 已存在 → 新函数命名为 `_update_breakfast_customer_flow`（批判 A1）。
- 若 `_spawn_timer` 已存在 → 复用；否则新增。

### G0.2 场景与顾客节点
```bash
grep -rn "breakfast_shop\|_breakfast_customer_nodes" scripts/ --include=*.gd
ls scenes/ | grep -i breakfast
```
**裁决**：
- 若 `scenes/breakfast_shop.tscn` 不存在 → 本方案**降级为纯 controller 实现**，场景层由 world-002 补齐后接入。
- 若 `_breakfast_customer_nodes` 已存在 → 复用其数组，本方案只新增 `OrderCard` 状态字段。

### G0.3 recipes.csv 早餐条目
```bash
grep -E "morning" data/recipes.csv
```
**预期**：7 条（`red_bean_bun / soy_milk / pork_bun / rice_noodle_soup / youtiao / porridge / tea_egg`）。
**裁决**：早餐店菜单 = 上述 7 条，**不新增 recipe**。

### G0.4 ConfigDB breakfast 段
```bash
grep -n "breakfast" data/config.csv
```
**裁决**：记录现有键。新增键必须带默认值（见 §7 键名表）。

### G0.5 ClickGestureRouter
```bash
ls scripts/ | grep -i "click_gesture\|gesture_router"
```
**裁决**：
- 若存在 → 所有实体继承 `WorldInteractable`，手势由 router 分发。
- 若不存在 → `BreakfastShopController` 内部实现 TAP/SECONDARY/HOLD 解析，文件头注释标注"待 ui-002 落地后迁移"。

### G0.6 STAGE_STATION_MAP 方向确认
```bash
grep -n "STAGE_STATION_MAP" autoload/kitchen_manager.gd
```
**裁决**：确认是 `stage → station_type` 正向映射。反查代码必须显式构建 `station_type → [stages]`（批判 D5）。

---

## 2. 状态归属表（批判 C1 强制交付物）

| 字段 | 归属对象 | 生命周期 | 谁写 | 谁读 |
|---|---|---|---|---|
| `card_id` | OrderCard | spawn→DONE | Controller | 全部 |
| `recipe_id` | OrderCard | spawn→DONE | Controller | Station/HUD |
| `stages` | OrderCard | spawn→DONE | Controller（解析 pipeline） | Station |
| `stage_index` | OrderCard | spawn→DONE | Station.tick | Station/HUD |
| `stage_progress` | OrderCard | spawn→DONE | Station.tick | Station/HUD |
| `stage_duration` | OrderCard | spawn→DONE | Controller（查 pipeline） | Station |
| `loc` | OrderCard | spawn→DONE | Controller | 全部 |
| `loc_ref` | OrderCard | spawn→DONE | Controller | Controller |
| `origin_loc` | OrderCard | 拾起时记录 | Controller | Controller（SECONDARY 回退） |
| `origin_ref` | OrderCard | 拾起时记录 | Controller | Controller |
| `patience_total` | OrderCard | spawn 时固定 | Controller | HUD |
| `patience_left` | OrderCard | spawn→DONE | Controller._update_patience | HUD |
| `patience_state` | OrderCard | spawn→DONE | Controller._update_patience | HUD |
| `price` | OrderCard | spawn 时固定 | Controller | Controller（结算） |
| `slot` | Station | 场景生命周期 | Controller | Station.tick |
| `accepts_stages` | Station | 场景生命周期 | Controller（反查 STAGE_STATION_MAP） | Station.can_accept |
| `speed_multiplier` | Station | 场景生命周期 | Controller（读 ConfigDB） | Station.tick |
| `held_card` | Controller | 拾起→放下 | Controller | 全部 |
| `queue` | Controller | shift 生命周期 | Controller | 全部 |
| `staging` | Controller | shift 生命周期 | Controller | 全部 |
| `serve_slot` | Controller | shift 生命周期 | Controller | 全部 |

**冲突裁决**：`stage_progress` **只在 OrderCard 上**，Station **无** `progress` 字段。若实现中出现 `station.progress`，视为 bug。

---

## 3. 节点结构（场景层）

```
BreakfastShop (Node2D)                      # 场景根，挂 BreakfastShopController
├── Backdrop (Node2D)                       # 复用 world-001 chunk 绘制
├── CounterLayer (Node2D)                   # 静态底纹层
│   ├── QueueRail (Node2D)                  # 5 个卡位底纹
│   ├── StationRail (Node2D)                # 5 个工位底纹
│   ├── StagingRail (Node2D)                # 3 个暂存槽底纹
│   └── ServeRail (Node2D)                  # 1 个出餐台底纹
├── CardLayer (Node2D)                      # ★ 唯一动态层，z_index=10
│   └── (OrderCardView 实例，运行时增删)
├── HintLayer (Node2D)                      # HOLD 提示层，z_index=20（批判 B5/U2）
├── ClickRouter (ClickGestureRouter)        # 复用 ui-002
├── KitchenEffectLayer (Node2D)             # 复用现有粒子
└── HUD (CanvasLayer)                       # 只读回显
```

**坐标来源**：`data/breakfast_layout.csv`（**本方案创建并维护**，批判 F1 裁决）。`.tscn` 里 `position = Vector2.ZERO`，由 controller 在 `_ready` 设置。

```csv
node_id,kind,anchor_x,anchor_y,slot_index
queue_0,queue_slot,320,880,0
queue_1,queue_slot,420,880,1
queue_2,queue_slot,520,880,2
queue_3,queue_slot,620,880,3
queue_4,queue_slot,720,880,4
station_prep,station,180,420,
station_steamer,station,380,420,
station_fryer,station,580,420,
station_soup_pot,station,780,420,
station_drink,station,980,420,
staging_0,staging,1180,540,0
staging_1,staging,1180,640,1
staging_2,staging,1180,740,2
serve_counter,serve,1180,880,
```

---

## 4. 核心数据结构

### 4.1 OrderCard（唯一状态载体）

```gdscript
class_name OrderCard
extends RefCounted

# --- 身份 ---
var card_id: int
var recipe_id: String
var customer_face: int              # 0-7 头像索引
var customer_name_key: String       # i18n key（批判 C6）

# --- 流水线 ---
var stages: Array[String] = []      # 从 recipes.csv pipeline 解析
var stage_index: int = 0
var stage_progress: float = 0.0
var stage_duration: float = 0.0

# --- 位置 ---
enum Loc { QUEUE, STATION, STAGING, HAND, SERVE, DONE }
var loc: Loc = Loc.QUEUE
var loc_ref: String = ""            # station_id / staging_slot_id / ""
var origin_loc: Loc = Loc.QUEUE     # 拾起前位置（SECONDARY 回退用）
var origin_ref: String = ""

# --- 耐心 ---
var patience_total: float = 0.0
var patience_left: float = 0.0
var patience_state: int = 0         # 0=平静 1=张望 2=皱眉 3=要走

# --- 结算 ---
var price: int = 0
var spawned_at: float = 0.0

func current_stage() -> String:
    if stages.is_empty() or stage_index >= stages.size():
        return ""
    return stages[stage_index]

func is_ready_to_serve() -> bool:
    # 批判 D4 修正：必须所有工序完成
    return stages.size() > 0 and stage_index >= stages.size()

func advance_stage() -> void:
    stage_index += 1
    stage_progress = 0.0
    if stage_index < stages.size():
        stage_duration = _lookup_duration(stages[stage_index])
    else:
        stage_duration = 0.0
```

### 4.2 Station（无状态处理器）

```gdscript
class_name Station
extends RefCounted

var station_id: String
var station_type: String            # prep/steamer/fryer/soup_pot/drink/serve
var slot: OrderCard = null          # null = 空闲
var speed_multiplier: float = 1.0
var accepts_stages: Array[String] = []   # 工序名列表（批判 D5 明确）

func can_accept(card: OrderCard) -> bool:
    if slot != null:
        return false
    var stage := card.current_stage()
    if stage == "":
        return false
    return stage in accepts_stages

func tick(delta: float) -> Dictionary:
    # 批判 D3 修正：统一返回结构
    if slot == null:
        return {"completed": false, "card": null}
    slot.stage_progress += delta * speed_multiplier
    if slot.stage_progress >= slot.stage_duration:
        slot.advance_stage()
        return {"completed": true, "card": slot}
    return {"completed": false, "card": slot}
```

### 4.3 BreakfastShopController

```gdscript
extends Node2D

signal card_spawned(card: OrderCard)
signal card_moved(card: OrderCard, from_loc_name: String, to_loc_name: String)  # 批判 B8
signal card_served(card: OrderCard, earned: int)
signal card_lost(card: OrderCard, reason: String)
signal combo_changed(combo: int)
signal shift_ended(summary: Dictionary)

const QUEUE_SLOTS := 5

var cards: Dictionary = {}          # card_id -> OrderCard
var queue: Array[int] = []          # 排队 card_id，[0] 最前
var stations: Dictionary = {}       # station_id -> Station
var staging: Array[int] = []        # 暂存槽 -> card_id，-1 空
var serve_slot: int = -1
var held_card: int = -1

var shift_active := false
var shift_time_left := 0.0
var combo := 0
var combo_window := 3.0
var last_serve_at := -999.0
var served_count := 0
var lost_count := 0                 # 批判 C4：独立计数器
var shortfall := 0                  # 批判 C4：独立计数器
var earned_total := 0
var _spawn_accumulator := 0.0
var _rng := RandomNumberGenerator.new()
```

---

## 5. 工位状态机（收敛到 OrderCard）

**工位无状态机**。状态机在 OrderCard 上：

```
        spawn
          │
          ▼
    ┌──────────┐  TAP 拾起 + TAP 工位  ┌──────────┐
    │  QUEUE   │ ────────────────────▶ │ STATION  │
    └──────────┘                       └──────────┘
          │                                  │
          │ 耐心归零                          │ 工序完成
          ▼                                  ▼
    ┌──────────┐                       ┌──────────┐
    │   LOST   │                       │ STAGING  │◀──┐
    └──────────┘                       └──────────┘   │
                                             │        │
                                             │ TAP 拾起 + TAP 工位
                                             ▼        │
                                       ┌──────────┐   │
                                       │ STATION  │───┘
                                       └──────────┘
                                             │
                                             │ 最后一道完成
                                             ▼
                                       ┌──────────┐
                                       │  SERVE   │──▶ 结算 ──▶ DONE
                                       └──────────┘
```

**转移规则表**：

| 从 | 到 | 触发 | 条件 |
|---|---|---|---|
| QUEUE | HAND | TAP 卡片 | 无 |
| HAND | STATION | TAP 工位 | `station.can_accept(card)` |
| HAND | STAGING | TAP 暂存槽 | 槽空 |
| HAND | QUEUE | SECONDARY | `origin_ref` 槽仍空 |
| HAND | 最近空槽 | SECONDARY | `origin_ref` 被占（批判 U3 降级） |
| STATION | STAGING | 自动 | 工序完成且非最后一道 |
| STATION | SERVE | 自动 | 工序完成且最后一道 |
| STAGING | HAND | TAP 卡片 | 无 |
| STAGING | LOST | 自动 | 耐心归零 |
| SERVE | DONE | 自动 | 结算完成 |

**关键约束**：
- 卡片在 STATION 时**不能被拾起**（防止半成品丢失）。
- 卡片在 HAND 时**耐心继续消耗**（防止无限拖延，批判 C3）。
- **无 blocked 状态**（批判 D1 死锁被消除）：暂存槽满时，TAP 暂存槽无效，卡片留在 HAND，玩家必须另找位置。

---

## 6. 完整操作流

```
1. 顾客入队（自动，泊松过程）
   → QueueRail 卡位出现 OrderCardView，显示菜品图标 + 头像 + 环形耐心刻度

2. TAP 卡片拾起
   → held_card = card_id，卡片跟随鼠标，origin_loc/origin_ref 记录

3. TAP 工位放下
   → station.can_accept(card) 为真 → card.loc = STATION，station.slot = card
   → 为假 → 卡片留在 HAND，工位闪烁红色（视觉反馈，批判 T5）

4. 工序自动推进
   → station.tick(delta) 推进 card.stage_progress
   → 完成 → card.advance_stage()
     - 非最后一道 → card.loc = STAGING，找空暂存槽
     - 最后一道 → card.loc = SERVE，serve_slot = card_id

5. TAP 暂存槽拾起 → TAP 下一工位放下
   → 手动搬运的核心

6. TAP 出餐台
   → 若 held_card 的 is_ready_to_serve() → 结算
   → 若 serve_slot 有卡 → 结算
   → 结算：earned = card.price，served_count++，combo++，card.loc = DONE

7. 顾客耐心归零
   → card_lost，lost_count++，combo = 0
   → 若卡片在 STATION → 等工序完成再离场（批判 T4 裁决）

8. 时间耗尽
   → shift_ended，shortfall = max(0, target - served_count)
```

**无下拉菜单**：所有选择通过 TAP 具体实体完成。

---

## 7. 配置键名统一表（批判 F3 强制交付物）

| 键名 | 类型 | 默认值 | 用途 |
|---|---|---|---|
| `breakfast.patience_base` | float | 45.0 | 耐心基础秒数 |
| `breakfast.patience_per_stage` | float | 12.0 | 每道工序追加耐心 |
| `breakfast.customer_interval` | float | 6.0 | 顾客生成基础间隔 |
| `breakfast.spawn_chance` | float | 0.85 | 生成概率 |
| `breakfast.staging_capacity` | int | 3 | 暂存槽容量 |
| `breakfast.station_speed_multiplier` | float | 1.0 | 工位速度倍率 |
| `breakfast.shift_duration` | float | 75.0 | 班次时长 |
| `breakfast.order_target` | int | 12 | 目标出餐数 |

**所有代码引用必须与此表一致**。`grep -rn "TRAY_CAPACITY\|STAGING_SLOTS" scripts/` 必须为空（批判 C3）。

---

## 8. 顾客耐心模型

### 8.1 耐心时长公式

```
patience_total = patience_base + patience_per_stage × stages.size()
```

**批判 F4 修正**：不使用 `recipe_multiplier` 乘法，改用加法，避免 `stages.size() < 2` 时耐心被缩短。

### 8.2 耐心消耗白名单（批判 C3 强制交付物）

| loc | 消耗速率 | 理由 |
|---|---|---|
| QUEUE | ×1.0 | 等待中，正常消耗 |
| STATION | ×0.5 | 加工中，温柔减速但不冻结（防 exploit） |
| STAGING | ×1.0 | 暂存中，正常消耗 |
| HAND | ×1.0 | 手持中，防止无限拖延 |
| SERVE | ×0.0 | 已出餐，不消耗 |
| DONE | ×0.0 | 已结算，不消耗 |

### 8.3 耐心状态（4 档，无数字）

| 状态 | 阈值 | 视觉 | 音效 |
|---|---|---|---|
| 平静 | > 60% | 头像微笑，环形刻度绿色 | 无 |
| 张望 | 30%-60% | 头像左右看，刻度黄色 | 轻微"嗯？" |
| 皱眉 | 10%-30% | 头像皱眉，刻度橙色 | 叹气 |
| 要走 | < 10% | 头像转身，刻度红色闪烁 | 椅子摩擦声 |

### 8.4 耐心归零时卡片在 STATION 的处理（批判 T4 裁决）

**裁决**：等工序完成再离场。`card_lost` 信号**延迟到工序完成时**发出。理由：温柔治愈，不惩罚玩家正在进行的操作。

```gdscript
func _update_patience(delta: float) -> void:
    for card in cards.values():
        if card.loc == OrderCard.Loc.DONE or card.loc == OrderCard.Loc.SERVE:
            continue
        var rate := 1.0
        if card.loc == OrderCard.Loc.STATION:
            rate = 0.5
        card.patience_left -= delta * rate
        if card.patience_left <= 0.0:
            if card.loc == OrderCard.Loc.STATION:
                card.patience_left = 0.0  # 冻结，等工序完成
                card.patience_state = 3
            else:
                _lose_card(card, "patience")
```

---

## 9. 随机客流模型

### 9.1 泊松过程

```gdscript
func _update_spawn(delta: float) -> void:
    if queue.size() >= QUEUE_SLOTS:
        return
    var lambda := _current_lambda()
    _spawn_accumulator += lambda * delta
    while _spawn_accumulator >= 1.0 and queue.size() < QUEUE_SLOTS:
        _spawn_accumulator -= 1.0
        _spawn_order()
```

### 9.2 时段权重表（只保留 morning，批判 F2）

```csv
# data/breakfast_flow.csv
phase,base_lambda,rush_lambda,recipe_pool,patience_bonus
morning,0.35,0.8,"soy_milk|pork_bun|youtiao|porridge|tea_egg|rice_noodle_soup|red_bean_bun",0
```

### 9.3 难度曲线

- 每服务 5 位顾客，`lambda` ×1.05，上限 ×2.0。
- 每丢失 1 位顾客，`lambda` ×0.9，下限 ×0.5（温柔治愈）。
- rush 时段（07:30-08:30）`lambda` 切到 `rush_lambda`。

### 9.4 Seed 注入（批判 C2）

```gdscript
func start_shift(location_id: String, seed: int = -1) -> void:
    if seed >= 0:
        _rng.seed = seed
    else:
        _rng.randomize()
    ...
```

**断言**：同 seed 跑两次，`queue` 序列完全一致。

---

## 10. 失败条件（批判 C4 裁决）

**无游戏失败**。只有两个独立计数器：

| 计数器 | 触发 | 后果 |
|---|---|---|
| `lost_count` | 顾客耐心归零 | `combo = 0`，不扣钱 |
| `shortfall` | 打烊时 `served_count < target` | `shortfall = target - served_count` |

**负反馈设计**（批判 C4 要求）：
- 走掉的顾客**不再出现在本班**（`recipe_id` 加入 `_lost_recipes` 黑名单，本班不再 spawn）。
- 打烊评价文案根据 `lost_count` 变化（0 = "完美早晨"，1-2 = "忙碌但温馨"，3+ = "明天会更好"）。

---

## 11. 存档语义（批判 C2 强制交付物）

### 11.1 存档结构

```gdscript
{
    "breakfast": {
        "version": 2,
        "cards": [
            {
                "card_id": 12,
                "recipe_id": "pork_bun",
                "stage_index": 1,
                "stage_progress": 0.0,   # 读档时强制重置为 0
                "loc": 1,
                "loc_ref": "steamer_1",
                "patience_left": 28.5,
                "price": 12
            }
        ],
        "stations": {"prep_1": 1, "steamer_1": 1},
        "combo": 3,
        "served_count": 8,
        "lost_count": 1,
        "earned_total": 156,
        "shift_time_left": 42.3
    }
}
```

### 11.2 读档语义（批判 C2 裁决）

- **`stage_progress` 强制重置为 0**：避免 delta 跳变。读档后工序从头跑。
- **读档顺序**：先建 `stations`，再恢复 `cards`。
- **`loc_ref` 校验**：若 `loc_ref` 不在 `stations` 中 → `card_lost(card, "orphan_loc_ref")`（批判 B3）。
- **`held_card` 不存**：读档时 `held_card = -1`，`HAND` 状态的卡片回退到 `origin_loc`（批判 D2）。
- **`stages` 空数组保护**：若 `recipe_id` 解析失败 → `card_lost(card, "invalid_pipeline")`（批判 B2）。

### 11.3 中途退出

- 玩家按 ESC 退出 → 存档写入 → 读档后**继续本班**（采纳 I，否决 M 的"放弃本班"）。
- 理由：温柔治愈，不惩罚玩家。

---

## 12. 与现有 kitchen_manager 的融合（批判 C5 裁决）

### 12.1 增量改造路径

- **保留** `orders/stations/staging` 三个数组，标记 `@deprecated`。
- **保留** `_update_stations/_update_orders/_update_customer_flow` 三个方法，标记 `@deprecated`。
- **新增** `BreakfastShopController` 作为早餐店专用控制器。
- **Feature flag** `breakfast.new_flow` 控制：
  - `true` → 早餐店用 `BreakfastShopController`，午市/晚市用 `KitchenManager`。
  - `false` → 全部用 `KitchenManager`（回退路径）。

### 12.2 迁移步骤

1. **阶段 1**：新建 `BreakfastShopController`，与 `KitchenManager` 并行运行，flag 默认 `false`。
2. **阶段 2**：早餐店场景切到新控制器，flag 默认 `true`。
3. **阶段 3**：验证午市/晚市也可用新模型后，删除 `KitchenManager` 的旧数组（**不在本方案范围**）。
4. **阶段 4**：存档迁移 —— 旧存档无 `breakfast` 字段 → 初始化空。

### 12.3 引用清单（G0.1 门禁产出）

执行 `grep -rn "\.orders\|\.stations\|\.staging" scripts/`，结果写入 `docs/BREAKFAST_FACTS.md`。**若午市/晚市引用这些数组，阶段 1/2 不得删除**。

---

## 13. 文件清单（按执行顺序）

| # | 文件 | 操作 | 关键内容 |
|---|---|---|---|
| A1 | `docs/BREAKFAST_FACTS.md` | 新建 | G0.1–G0.6 门禁结果 + 引用清单 |
| A2 | `data/breakfast_layout.csv` | 新建 | 节点坐标（§3） |
| A3 | `data/breakfast_flow.csv` | 新建 | 客流权重（§9.2，只 morning 行） |
| A4 | `data/config.csv` | 追加 | §7 键名表全部键 |
| B1 | `scripts/gameplay/order_card.gd` | 新建 | OrderCard 类（§4.1） |
| B2 | `scripts/gameplay/station.gd` | 新建 | Station 类（§4.2） |
| B3 | `scripts/gameplay/breakfast_shop_controller.gd` | 新建 | Controller（§4.3） |
| B4 | `scripts/gameplay/order_card_view.gd` | 新建 | 卡片视觉节点 |
| B5 | `scripts/gameplay/breakfast_hint_layer.gd` | 新建 | HOLD 提示层（批判 B5/U2） |
| B6 | `scripts/gameplay/breakfast_shop_layer.gd` | 新建 | 场景层，读 CSV 建节点 |
| C1 | `scenes/breakfast_shop.tscn` | 修改 | 挂 BreakfastShopController |
| C2 | `scripts/ui/hud.gd` | 修改 | 订阅信号，只读回显 |
| C3 | `autoload/kitchen_manager.gd` | 修改 | 标记 deprecated，不删除 |

---

## 14. 验证步骤

### V1. 单元测试（批判 T2：不直接调用私有方法）

```gdscript
# 公开测试钩子
func debug_spawn_card(recipe_id: String) -> int
func debug_force_station_complete(station_id: String) -> void
func debug_get_card(card_id: int) -> OrderCard
```

**测试用例**：
- `test_card_state_transitions`：QUEUE→HAND→STATION→STAGING→HAND→STATION→SERVE→DONE 每条边。
- `test_empty_pipeline`：`stages = []` 时 `is_ready_to_serve()` 返回 `false`，不崩溃（批判 B2）。
- `test_is_ready_to_serve`：`stage_index == stages.size()` 时为 `true`（批判 D4）。
- `test_orphan_loc_ref`：`loc_ref = "nonexistent"` 读档后卡片 lost（批判 B3）。
- `test_patience_freeze_exploit`：卡片在 STATION 60s，耐心必须下降（批判 B7）。
- `test_save_mid_action`：5 种中途状态保存→读档→不崩溃（批判 C1）。
- `test_seed_reproducibility`：同 seed 跑两次，queue 序列一致（批判 C2）。
- `test_click_priority`：卡片覆盖工位时 TAP 命中卡片（批判 C4）。
- `test_pause`：暂停 10s 后恢复，耐心不变（批判 C5）。
- `test_hold_hint`：HOLD 工位 0.5s 后 HintLayer 有子节点，松手归零（批判 B5）。
- `test_secondary_origin_occupied`：原位置被占时 SECONDARY 降级到最近空槽（批判 U3）。

### V2. 场景验证

```bash
godot --headless --scene-check scenes/breakfast_shop.tscn
```
断言：`BreakfastShop` 下节点数量 == 8（Backdrop + CounterLayer + CardLayer + HintLayer + ClickRouter + KitchenEffectLayer + HUD + Controller）。

### V3. 性能验证（批判 B6）

```bash
godot --headless --bench-breakfast
```
断言：12 张卡同时 tick，`avg_frame_us < 500`。

### V4. 手动验证清单

- [ ] 顾客入队，卡片出现
- [ ] TAP 卡片拾起，跟随鼠标
- [ ] TAP 工位放下，工序推进
- [ ] 工序完成，卡片进暂存槽
- [ ] TAP 暂存槽拾起，TAP 下一工位
- [ ] TAP 出餐台结算，combo++
- [ ] 顾客耐心归零，卡片消失
- [ ] 暂存槽满时 TAP 无效，卡片留 HAND
- [ ] HOLD 工位显示提示
- [ ] SECONDARY 取消拾起
- [ ] 时间耗尽，shift_ended

### V5. 存档验证

```bash
godot --headless --test-save-mid-action
godot --headless --test-seed-reproducibility
godot --headless --test-empty-pipeline
godot --headless --test-orphan-loc-ref
```
退出码全为 0 才允许进入实现阶段。

---

## 15. 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| `breakfast_shop.ts
