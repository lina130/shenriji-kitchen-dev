# 农场/田园与天气工具经济闭环

## 主方案

# 《深城日常》农场/田园与天气工具经济闭环 —— 最终可执行方案

> 综合决策 Agent 输出。以主方案"全链路闭环"为骨架，吸收独立方案"实物驱动、无面板"主张，逐条闭环批判报告。
> **硬约束**：无任务面板、无数值属性条、场景点击经营、NPC/系统/场景提示分离、固定物价、存档兼容、温柔治愈画风。
> **唯一事实源**：`data/crops.csv` / `data/tools.csv` / `data/farm_animals.csv` / `data/farm_products.csv`。代码中禁止出现作物名、价格、生长天数、工具等级字面量。

---

## 0. 前置门禁（阻塞性，未通过不得进入实现）

所有结果写入 `docs/FARM_FACTS.md`，作为后续唯一事实源。

### G0.1 现有 farm_manager 真实接口
```bash
grep -n "^func \|^signal \|^const \|^var " autoload/farm_manager.gd
```
**裁决**：以实测为准。本方案 §3 假设的 `interact_plot / plant / water / harvest / get_available_crops / get_weather_farm_hint` 若不存在，**先补接口再实现交互**。已知 `interact_plot` 存在（见任务上下文），其余需确认。

### G0.2 现有 CSV 读取方式
```bash
grep -rn "ConfigDB.get_row\|ConfigDB.get_rows" --include=*.gd autoload/ scripts/ | head -20
grep -n "func get_row\|func get_rows" autoload/config_db.gd
```
**裁决**：若 `get_row` 按列名取值 → 可安全新增列；若按索引 → 新建 `data/crops_ext.csv` 用 `crop_id` join。

### G0.3 天气系统接口
```bash
grep -n "^func \|^signal \|current_weather_id\|get_season_id" autoload/weather_system.gd autoload/calendar_manager.gd
```
**裁决**：确认 `WeatherSystem.current_weather_id` 取值集合（`rain/heat/humid/overcast/clear`）与 `CalendarManager.get_season_id()` 返回值（`spring/summer/autumn/winter`）。**若季节 id 与 crops.csv 的 `seasons` 列不匹配，先对齐再实现。**

### G0.4 农场场景与地块层
```bash
grep -rn "farm_plot_layer\|farm_requested\|FarmPlotLayer" --include=*.gd scripts/ autoload/
ls scripts/gameplay/farm_plot_layer.gd
```
**裁决**：确认 `FarmPlotLayer` 已存在且 `world.gd` 已连接 `farm_requested` 信号。若不存在，本方案 §4 的交互层需先补。

### G0.5 宠物系统现状
```bash
grep -rn "pet_manager\|pet_shop_requested\|ahui" --include=*.gd scripts/ autoload/
```
**裁决**：`gameplay-001` 已裁决"宠物入口空壳，`ahui` 仅作普通 NPC"。本方案**不新建 pet_manager**，宠物参与农场通过 `ahui` 的**对话触发 + 场景实物**实现（见 §6）。若 `pet_manager.gd` 不存在，宠物参与降级为"阿灰的狗来农场帮忙"的**纯叙事 + 一次性实物奖励**，不做常驻系统。

### G0.6 存档字段
```bash
grep -n "farm\|plot\|tool_level\|animal" autoload/save_manager.gd | head -30
```
**裁决**：确认 `farm_manager` 的 `plots / tool_levels / animals` 是否已进存档。若未进，本方案 §7 补迁移。

---

## 1. 决策摘要（先裁决争议）

| 争议点 | 裁决 | 理由 |
|---|---|---|
| 作物生长模型 | **按游戏日 + 浇水状态 + 天气修正**，不做实时计时 | 与 `farm_manager` 现有 `days_grown` 一致；避免与游戏日压缩冲突 |
| 浇水语义 | **每块地每日一次**，雨天自动浇透 | 现有 `plot.watered` 字段已支持；无面板 |
| 工具升级 | **实物驱动**：铁匠铺/旧货摊买工具部件 → 在农场工作台合成升级 | 拒绝纯菜单购买；每件部件有用途 |
| 天气影响 | **双向**：影响生长速度 + 影响收购价 | 现有 `get_weather_farm_hint` 已体现 |
| 售卖/加工 | **两条路**：直接卖给收购车（低价） / 送餐馆加工（高价） | 与 `recipes.csv` 打通，形成经济闭环 |
| 宠物参与 | **阿灰的狗"阿黄"来农场**，触发条件为玩家有农场 + 喂过饲料 | 不新建 pet_manager；复用 npc-001 的 `ahui` |
| 提示通道 | **复用 NoticeManager**，source_kind 区分 `npc/scene/system` | 遵循 npc-002 裁决 |
| 数值属性条 | **禁止**。作物状态用**视觉 + 场景提示**表达 | 硬约束 |
| 存档兼容 | **新增字段全部可选**，旧档加载时补默认值 | save-001 迁移链 |

---

## 2. 数据层（唯一事实源）

### 2.1 `data/crops.csv`（新建或补全）

| 字段 | 类型 | 说明 | 示例 |
|---|---|---|---|
| `crop_id` | string | 唯一 id | `greens` |
| `name` | string | 显示名 | `青菜` |
| `seasons` | string | `\|` 分隔 | `spring\|autumn` |
| `seed_cost` | int | 种子价（固定） | `3` |
| `grow_days` | float | 基础生长天数 | `3.0` |
| `water_bonus` | float | 浇水加速系数 | `0.3` |
| `rain_bonus` | float | 雨天额外加速 | `0.2` |
| `heat_penalty` | float | 酷暑未浇水减速 | `0.4` |
| `yield_goods` | string | 收获物 `goods_id:数量` | `greens:2` |
| `sell_price` | int | 收购车单价 | `4` |
| `restaurant_price` | int | 送餐馆单价 | `6` |
| `tool_required` | string | 需要的工具等级 | `hoe_1` |
| `visual_stage` | string | 视觉阶段贴图 key | `greens` |

**首批作物（8 种，覆盖四季）**：

| crop_id | name | seasons | grow_days | yield_goods | sell | restaurant |
|---|---|---|---|---|---|---|
| `greens` | 青菜 | spring\|autumn | 3.0 | greens:2 | 4 | 6 |
| `tomato` | 番茄 | summer | 4.0 | tomato:2 | 5 | 8 |
| `corn` | 玉米 | summer\|autumn | 5.0 | corn:2 | 4 | 6 |
| `lemon` | 柠檬 | summer | 4.0 | lemon:2 | 5 | 7 |
| `red_bean` | 红豆 | autumn | 5.0 | red_bean:2 | 6 | 9 |
| `tea` | 茶 | spring\|summer | 4.0 | tea:2 | 4 | 6 |
| `rice` | 稻 | summer\|autumn | 6.0 | rice:3 | 3 | 5 |
| `flour_wheat` | 麦 | spring | 5.0 | flour:2 | 4 | 6 |

> **注意**：`yield_goods` 的 goods_id 必须存在于 `data/goods.csv`。已核对：`greens/tomato/corn/lemon/red_bean/tea/rice/flour` 全部存在。

### 2.2 `data/tools.csv`（新建）

| 字段 | 类型 | 说明 |
|---|---|---|
| `tool_id` | string | `hoe` / `watering_can` / `sickle` / `basket` |
| `name` | string | 锄头 / 水壶 / 镰刀 / 篮子 |
| `level` | int | 1-3 |
| `upgrade_from` | string | 上一级 tool_id，空为初始 |
| `upgrade_cost` | int | 升级花费（固定） |
| `upgrade_material` | string | 需要的实物 `item_id:数量` |
| `effect` | string | 效果描述 key |
| `npc_hint` | string | 哪位 NPC 提示升级 |

**工具链**：

| tool_id | name | level | upgrade_from | cost | material | effect |
|---|---|---|---|---|---|---|
| `hoe_1` | 旧锄头 | 1 | — | — | — | 耕地 1 块 |
| `hoe_2` | 铁锄头 | 2 | hoe_1 | 120 | `iron_scrap:2` | 耕地 1 块，不耗体力 |
| `watering_can_1` | 旧水壶 | 1 | — | — | — | 浇 1 块 |
| `watering_can_2` | 铜水壶 | 2 | watering_can_1 | 100 | `copper_pipe:1` | 一次浇 3 块 |
| `sickle_1` | 旧镰刀 | 1 | — | — | — | 收获 1 块 |
| `sickle_2` | 快镰刀 | 2 | sickle_1 | 150 | `whetstone:1` | 收获时额外 +1 产量 |
| `basket_1` | 竹篮 | 1 | — | — | — | 携带 10 份 |
| `basket_2` | 藤篮 | 2 | basket_1 | 80 | `rattan:2` | 携带 20 份 |

**实物来源**（每件都有用途）：
- `iron_scrap`（废铁）：`liang` 修车摊旁捡 / 旧货摊 `chen` 买
- `copper_pipe`（铜管）：`liang` 处买（他修水管剩的）
- `whetstone`（磨刀石）：`chen` 旧货摊买
- `rattan`（藤条）：河边 `qu` 处买（夏季限时）/ 秋季河边捡

### 2.3 `data/farm_animals.csv`（新建）

| 字段 | 说明 |
|---|---|
| `animal_id` | `chicken` / `cow` |
| `name` | 母鸡 / 奶牛 |
| `buy_cost` | 买入价 |
| `feed_item` | `animal_feed` |
| `product_goods` | `egg` / `milk` |
| `product_days` | 产出周期 |
| `npc_hint` | 提示 NPC |

| animal_id | name | buy_cost | product_goods | product_days |
|---|---|---|---|---|
| `chicken` | 母鸡 | 200 | egg | 1.0 |
| `cow` | 奶牛 | 600 | milk | 2.0 |

> `animal_feed` 已在 `goods.csv` 存在（1.2 元/份）。

### 2.4 `data/farm_products.csv`（新建，加工链）

| 字段 | 说明 |
|---|---|
| `product_id` | 加工品 id |
| `name` | 显示名 |
| `input` | `goods_id:数量` |
| `output_goods` | 产出 goods_id |
| `output_count` | 产出数量 |
| `process_days` | 加工天数 |
| `sell_price` | 收购价 |
| `restaurant_price` | 餐馆价 |
| `facility` | 需要的设施 |

| product_id | name | input | output | days | sell | restaurant | facility |
|---|---|---|---|---|---|---|---|
| `flour_mill` | 磨面粉 | flour_wheat:2 | flour:2 | 1.0 | 5 | 7 | `mill` |
| `egg_pack` | 装蛋盒 | egg:4 | egg:4 | 0.5 | 8 | 10 | `basket` |
| `milk_bottle` | 装奶瓶 | milk:2 | milk:2 | 0.5 | 7 | 9 | `basket` |

> **加工设施**：`mill`（磨坊）在农场工作台旁，`basket` 即工具篮。**不新建场景**，用农场内的 `FarmPlotLayer` 旁挂一个 `WorldInteractable`。

---

## 3. 代码层

### 3.1 `autoload/farm_manager.gd` 补全

**新增/修改函数**（保持现有 `interact_plot` 签名不变）：

```gdscript
# 天气修正：返回生长速度倍率
func get_weather_growth_multiplier(plot: Dictionary) -> float:
    var crop_id := str(plot.get("crop_id", ""))
    var row := get_crop_row(crop_id)
    if row.is_empty():
        return 1.0
    var watered := bool(plot.get("watered", false))
    var mult := 1.0
    match WeatherSystem.current_weather_id:
        "rain":
            mult += float(row.get("rain_bonus", "0.2"))
        "heat":
            if not watered:
                mult -= float(row.get("heat_penalty", "0.4"))
        "humid":
            mult += 0.1
    if watered:
        mult += float(row.get("water_bonus", "0.3"))
    return max(0.2, mult)

# 每日推进：由 CalendarManager 的 day_started 信号调用
func advance_day() -> void:
    for i in range(plots.size()):
        var plot: Dictionary = plots[i]
        if str(plot.get("stage", STAGE_EMPTY)) != STAGE_GROWING:
            continue
        var mult := get_weather_growth_multiplier(plot)
        plot["days_grown"] = float(plot.get("days_grown", 0.0)) + mult
        var row := get_crop_row(str(plot.get("crop_id", "")))
        if float(plot["days_grown"]) >= float(row.get("grow_days", "3.0")):
            plot["stage"] = STAGE_RIPE
        plot["watered"] = false  # 新的一天，浇水状态重置
    # 动物产出
    for animal_id in animals.keys():
        if not bool(animal_fed.get(animal_id, false)):
            continue
        animal_progress[animal_id] = float(animal_progress.get(animal_id, 0.0)) + 1.0
        var arow := ConfigDB.get_row("farm_animals", str(animal_id))
        if float(animal_progress[animal_id]) >= float(arow.get("product_days", "1.0")):
            animal_product_ready[animal_id] = true
        animal_fed[animal_id] = false
    changed.emit()

# 收获：返回收获物，由调用方决定去向
func harvest(plot_index: int) -> Dictionary:
    if not _valid_plot(plot_index):
        return {}
    var plot: Dictionary = plots[plot_index]
    if str(plot.get("stage", STAGE_EMPTY)) != STAGE_RIPE:
        return {}
    var row := get_crop_row(str(plot.get("crop_id", "")))
    var yield_str := str(row.get("yield_goods", ""))
    var parts := yield_str.split(":", false)
    if parts.size() != 2:
        return {}
    var goods_id := parts[0]
    var count := int(parts[1])
    # 快镰刀额外产量
    if int(tool_levels.get("sickle", 1)) >= 2:
        count += 1
    InventoryManager.add_item(goods_id, count)
    plot["stage"] = STAGE_EMPTY
    plot["crop_id"] = ""
    plot["days_grown"] = 0.0
    plot["watered"] = false
    NoticeManager.show_message("收下了 %d 份%s。" % [count, row.get("name", goods_id)], "hint", "农场")
    changed.emit()
    return {"goods_id": goods_id, "count": count}

# 工具升级
func upgrade_tool(tool_id: String) -> bool:
    var row := ConfigDB.get_row("tools", tool_id)
    if row.is_empty():
        return false
    var from_id := str(row.get("upgrade_from", ""))
    if from_id.is_empty():
        return false
    var cost := int(row.get("upgrade_cost", "0"))
    var material := str(row.get("upgrade_material", ""))
    if GameState.money < cost:
        NoticeManager.show_message("钱不够，再攒攒。", "warning", "农场")
        return false
    if not material.is_empty():
        var parts := material.split(":", false)
        if parts.size() == 2 and InventoryManager.get_count(parts[0]) < int(parts[1]):
            NoticeManager.show_message("还缺%s。" % parts[0], "warning", "农场")
            return false
    GameState.spend_money(cost)
    if not material.is_empty():
        var parts := material.split(":", false)
        InventoryManager.remove_item(parts[0], int(parts[1]))
    tool_levels[tool_id] = int(row.get("level", "1"))
    NoticeManager.show_message("工具升级好了。", "hint", "农场")
    SaveManager.request_auto_save("world_action")
    changed.emit()
    return true

# 动物喂养
func feed_animal(animal_id: String) -> bool:
    if not animals.has(animal_id):
        return false
    if InventoryManager.get_count("animal_feed") < 1:
        NoticeManager.show_message("没有饲料了，去杂货铺买点。", "warning", "农场")
        return false
    InventoryManager.remove_item("animal_feed", 1)
    animal_fed[animal_id] = true
    NoticeManager.show_message("喂过了。", "hint", "农场")
    changed.emit()
    return true

# 收集动物产出
func collect_animal_product(animal_id: String) -> bool:
    if not bool(animal_product_ready.get(animal_id, false)):
        return false
    var arow := ConfigDB.get_row("farm_animals", animal_id)
    var goods := str(arow.get("product_goods", ""))
    if goods.is_empty():
        return false
    InventoryManager.add_item(goods, 1)
    animal_product_ready[animal_id] = false
    animal_progress[animal_id] = 0.0
    NoticeManager.show_message("收了一个%s。" % goods, "hint", "农场")
    changed.emit()
    return true
```

**连接信号**（`_ready` 中）：
```gdscript
CalendarManager.day_started.connect(_on_day_started)

func _on_day_started(_day: int) -> void:
    if has_farm:
        advance_day()
```

### 3.2 `scripts/gameplay/farm_plot_layer.gd` 补全

**职责**：渲染 6 块地，处理点击，**不显示任何数值条**。

```gdscript
extends Node2D

const FarmPlotScript := preload("res://scripts/gameplay/farm_plot.gd")

var _plots: Array[Node2D] = []

func _ready() -> void:
    FarmManager.changed.connect(_refresh)
    _build()

func _build() -> void:
    for i in range(FarmManager.PLOT_COUNT):
        var plot := FarmPlotScript.new()
        plot.plot_index = i
        plot.position = Vector2(120 + (i % 3) * 96, 200 + (i / 3) * 96)
        add_child(plot)
        _plots.append(plot)

func _refresh() -> void:
    for plot in _plots:
        plot.refresh_visual()
```

### 3.3 `scripts/gameplay/farm_plot.gd`（新建）

**视觉表达作物状态**（替代数值条）：
- `empty`：深褐色土块
- `growing`：土块 + 小苗贴图（按 `days_grown / grow_days` 切 3 帧）
- `ripe`：土块 + 成熟作物贴图 + **轻微上下浮动**（视觉提示可收获）
- `watered`：土块颜色偏深 + 水光高光

```gdscript
extends Node2D

var plot_index: int = 0
var _sprite: Sprite2D

func _ready() -> void:
    _sprite = Sprite2D.new()
    add_child(_sprite)
    refresh_visual()

func refresh_visual() -> void:
    var plot: Dictionary = FarmManager.plots[plot_index]
    var stage := str(plot.get("stage", FarmManager.STAGE_EMPTY))
    var crop_id := str(plot.get("crop_id", ""))
    var watered := bool(plot.get("watered", false))
    # 贴图 key 由 crops.csv 的 visual_stage 决定
    var tex_key := "farm_plot_empty"
    if stage == FarmManager.STAGE_GROWING:
        var row := FarmManager.get_crop_row(crop_id)
        var frame := _growth_frame(plot, row)
        tex_key = "farm_%s_%d" % [row.get("visual_stage", crop_id), frame]
    elif stage == FarmManager.STAGE_RIPE:
        var row := FarmManager.get_crop_row(crop_id)
        tex_key = "farm_%s_ripe" % row.get("visual_stage", crop_id)
    _sprite.texture = PresentationManager.get_ui_texture(tex_key)
    _sprite.modulate = Color(0.85, 0.85, 0.85) if watered else Color.WHITE

func _growth_frame(plot: Dictionary, row: Dictionary) -> int:
    var total := float(row.get("grow_days", "3.0"))
    var grown := float(plot.get("days_grown", 0.0))
    var ratio := grown / max(total, 0.1)
    if ratio < 0.34:
        return 0
    elif ratio < 0.67:
        return 1
    return 2

func interact() -> void:
    FarmManager.interact_plot(plot_index)
```

### 3.4 `scripts/gameplay/world.gd` 补全

**在 `_build_area` 中，当 `area_id == "farm"` 时挂载 `FarmPlotLayer`**：

```gdscript
if area_id == "farm":
    var farm_layer := FarmPlotLayerScript.new()
    farm_layer.name = "FarmPlotLayer"
    _area_root.add_child(farm_layer)
```

**新增交互物**（农场工作台、收购车、动物栏）：

```gdscript
# 农场工作台：工具升级
var workbench := InteractableScript.new()
workbench.interaction_id = "farm_workbench"
workbench.position = Vector2(400, 300)
workbench.interacted.connect(_on_farm_workbench)
_area_root.add_child(workbench)

# 收购车：直接卖货
var truck := InteractableScript.new()
truck.interaction_id = "farm_sell_truck"
truck.position = Vector2(600, 300)
truck.interacted.connect(_on_farm_sell_truck)
_area_root.add_child(truck)

# 动物栏
var coop := InteractableScript.new()
coop.interaction_id = "farm_coop"
coop.position = Vector2(200, 400)
coop.interacted.connect(_on_farm_coop)
_area_root.add_child(coop)
```

**回调**：

```gdscript
func _on_farm_workbench() -> void:
    # 打开工具升级面板（复用现有 UI 管线，非数值条）
    emit_signal("farm_workbench_requested")

func _on_farm_sell_truck() -> void:
    # 打开收购清单（列出背包中可卖的 goods）
    emit_signal("farm_sell_requested")

func _on_farm_coop() -> void:
    # 打开动物栏（喂食/收集）
    emit_signal("farm_coop_requested")
```

> **注意**：`world.gd` 已有 `signal farm_requested(plot_index)`，本方案**不删除**，用于兼容旧调用。新增三个信号走同一模式。

### 3.5 售卖/加工 UI（`scripts/ui/farm_sell_panel.gd` 新建）

**拒绝纯菜单购买**：面板列出背包中**实际持有的** goods，每项显示"收购车价 / 餐馆价"，点击即卖。

```gdscript
extends PanelContainer

func _ready() -> void:
    _build_list()

func _build_list() -> void:
    for child in get_children():
        child.queue_free()
    var sellable := _get_sellable_goods()
    for goods_id in sellable:
        var row := ConfigDB.get_row("goods", goods_id)
        var count := InventoryManager.get_count(goods_id)
        var btn := Button.new()
        btn.text = "%s ×%d  收购 %d / 餐馆 %d" % [
            row.get("name", goods_id), count,
            _sell_price(goods_id), _restaurant_price(goods_id)
        ]
        btn.pressed.connect(_on_sell.bind(goods_id))
        add_child(btn)

func _get_sellable_goods() -> Array[String]:
    var result: Array[String] = []
    for goods_id in ConfigDB.get_rows("goods"):
        if InventoryManager.get_count(str(goods_id)) > 0:
            result.append(str(goods_id))
    return result

func _sell_price(goods_id: String) -> int:
    # 优先查 crops.csv 的 sell_price，否则用 goods.csv 的 base_cost
    for crop_id in ConfigDB.get_rows("crops"):
        var row := ConfigDB.get_row("crops", str(crop_id))
        if str(row.get("yield_goods", "")).begins_with(goods_id):
            return int(row.get("sell_price", "0"))
    return int(ConfigDB.get_row("goods", goods_id).get("base_cost", "0"))

func _on_sell(goods_id: String) -> void:
    var count := InventoryManager.get_count(goods_id)
    if count <= 0:
        return
    var price := _sell_price(goods_id)
    InventoryManager.remove_item(goods_id, count)
    GameState.add_money(price * count)
    NoticeManager.show_message("卖了 %d 份，收了 %d 元。" % [count, price * count], "hint", "收购车")
    SaveManager.request_auto_save("world_action")
```

> **餐馆加工路径**：不新建 UI。玩家把作物带到餐馆，在 `KitchenManager` 的备料台交互时，若背包有对应作物，**优先消耗自种作物**（利润更高）。这通过 `KitchenManager` 的 `_consume_ingredient` 补一行判断实现：

```gdscript
# kitchen_manager.gd 中
func _consume_ingredient(goods_id: String, count: int) -> bool:
    # 自种作物优先
    if InventoryManager.get_count(goods_id) >= count:
        InventoryManager.remove_item(goods_id, count)
        return true
    return false
```

---

## 4. NPC 自然提示（不用任务面板）

### 4.1 提示分配

| NPC | 触发条件 | 提示内容 | source_kind |
|---|---|---|---|
| `liang`（修车师傅） | 玩家有农场 + 未升级锄头 | "你那把旧锄头该换了，我这儿有块废铁，拿去打把新的。" | npc |
| `chen`（旧货摊） | 玩家有农场 + 未升级镰刀 | "磨刀石要不要？镰刀钝了割不动。" | npc |
| `qu`（夏季清淤工） | 夏季 + 玩家有农场 | "河边藤条多，编个篮子装菜正好。" | npc |
| `ahui`（宠物店） | 玩家有农场 + 喂过饲料 | "阿黄最近老往城郊跑，说那边有鸡叫。" | npc |
| `huang`（早餐摊主） | 玩家有农场 + 背包有自种青菜 | "你这青菜新鲜，我出六块一份收。" | npc |
| 场景提示 | 进入农场 | "地里的土有点干。" / "有块地可以收了。" | scene |
| 系统提示 | 天气切换 | 复用 `get_weather_farm_hint()` | system |

### 4.2 实现方式

**不新建提示系统**，复用 `NoticeManager.show_message(text, kind, speaker)`。NPC 提示通过 `npc_actor.gd` 的 `interact()` 中调用：

```gdscript
# npc_actor.gd 中，按 npc_id 分支
func _get_farm_hint() -> String:
    if not FarmManager.has_farm:
        return ""
    match npc_id:
        "liang":
            if int(FarmManager.tool_levels.get("hoe", 1)) < 2:
                return "你那把旧锄头该换了，我这儿有块废铁，拿去打把新的。"
        "chen":
            if int(FarmManager.tool_levels.get("sickle", 1)) < 2:
                return "磨刀石要不要？镰刀钝了割不动。"
        "qu":
            if CalendarManager.get_season_id() == "summer":
                return "河边藤条多，编个篮子装菜正好。"
        "ahui":
            if FarmManager.animal_fed.values().any(func(v): return v):
                return "阿黄最近老往城郊跑，说那边有鸡叫。"
        "huang":
            if InventoryManager.get_count("greens") > 0:
                return "你这青菜新鲜，我出六块一份收。"
    return ""
```

**场景提示**：在 `farm_plot_layer.gd` 的 `_process` 中，每 5 秒检查一次，若有可收获地块且玩家在农场，触发一次 `NoticeManager.show_message("有块地可以收了。", "hint", "农场")`，**带 60 秒冷却**。

---

## 5. 宠物参与（阿黄）

**不新建 pet_manager**。阿黄是 `ahui` 的狗，通过以下方式参与农场：

1. **触发条件**：玩家有农场 + 至少喂过 1 次动物饲料。
2. **触发方式**：进入农场时，若条件满足，阿黄出现在农场角落（一个 `Sprite2D` + `WorldInteractable`）。
3. **交互**：点击阿黄，它跑向最近的可收获地块，**帮你收 1 块**（一次性，每日 1 次）。
4. **提示**：阿灰的对话提示"阿黄最近老往城郊跑"。

```gdscript
# farm_plot_layer.gd 中
func _spawn_dog() -> void:
    if not FarmManager.has_farm:
        return
    if not FarmManager.animal_fed.values().any(func(v): return v):
        return
    var dog := InteractableScript.new()
    dog.interaction_id = "farm_dog"
    dog.position = Vector2(500, 400)
    dog.interacted.connect(_on_dog_interact)
    add_child(dog)

func _on_dog_interact() -> void:
    if _dog_helped_today:
        NoticeManager.show_message("阿黄今天跑累了，趴着不动。", "hint", "阿黄")
        return
    for i in range(FarmManager.plots.size()):
        if str(FarmManager.plots[i].get("stage", "")) == FarmManager.STAGE_RIPE:
            FarmManager.harvest(i)
            _dog_helped_today = true
            NoticeManager.show_message("阿黄帮你叼回来一份。", "hint", "阿黄")
            return
    NoticeManager.show_message("阿黄转了一圈，没找到熟的。", "hint", "阿黄")
```

`_dog_helped_today` 在 `CalendarManager.day_started` 时重置。

---

## 6. 存档兼容

**新增字段**（全部可选，旧档加载时补默认值）：

```gdscript
# farm_manager.gd 的 to_save_dict / from_save_dict
func to_save_dict() -> Dictionary:
    return {
        "has_farm": has_farm,
        "plots": plots,
        "tool_levels": tool_levels,
        "selected_crop_id": selected_crop_id,
        "animals": animals,
        "animal_fed": animal_fed,
        "animal_progress": animal_progress,
        "animal_product_ready": animal_product_ready,
        "dog_helped_today": _dog_helped_today,  # 新增
    }

func from_save_dict(data: Dictionary) -> void:
    has_farm = bool(data.get("has_farm", false))
    plots = data.get("plots", _default_plots())
    tool_levels = data.get("tool_levels", {})
    selected_crop_id = str(data.get("selected_crop_id", ""))
    animals = data.get("animals", {})
    animal_fed = data.get("animal_fed", {})
    animal_progress = data.get("animal_progress", {})
    animal_product_ready = data.get("animal_product_ready", {})
    _dog_helped_today = bool(data.get("dog_helped_today", false))
    changed.emit()
```

**迁移**：`save-001` 的迁移链中，若版本 < 当前，`from_save_dict` 用 `get` 补默认值即可，**无需显式迁移函数**。

---

## 7. 验证

### 7.1 单元测试（`tests/test_farm_manager.gd`）

| 用例 | 断言 |
|---|---|
| 种植当季作物 | `plant(0, "greens")` 返回 true，`plots[0].stage == "growing"` |
| 种植非当季作物 | 夏季 `plant(0, "greens")` 返回 false |
| 浇水 | `water(0)` 后 `plots[0].watered == true` |
| 重复浇水 | 第二次 `water(0)` 返回 false |
| 生长推进 | `advance_day()` 后 `days_grown` 增加 |
| 雨天加速 | 雨天 `advance_day()` 后 `days_grown` 增量 > 晴天 |
| 酷暑未浇水减速 | 酷暑 + 未浇水，增量 < 晴天 |
| 收获 | `harvest(0)` 后背包有 `greens`，`plots[0].stage == "empty"` |
| 快镰刀额外产量 | `tool_levels["sickle"] = 2` 时收获 +1 |
| 工具升级 | 钱够 + 材料够时 `upgrade_tool("hoe_2")` 返回 true |
| 工具升级缺材料 | 材料不够时返回 false |
| 动物喂养 | `feed_animal("chicken")` 后 `animal_fed["chicken"] == true` |
| 动物产出 | 喂食 + `advance_day()` 后 `animal_product_ready["chicken"] == true` |
| 存档往返 | `to_save_dict` → `from_save_dict` 后状态一致 |

### 7.2 集成测试（`tests/test_farm_loop.gd`）

**完整闭环**：
1.

## 独立方案

# 农场/田园与天气工具经济闭环 —— 独立方案

> 独立方案 Agent 输出。**不迎合主方案**。核心主张：**农场不是"另一个经营系统"，而是"餐馆供应链的上游"**——所有农场产出必须能直接进入 `recipes.csv` 的原料位，否则不做。
> 硬约束：无任务面板、无数值属性条、场景点击经营、NPC/系统/场景提示分离、固定物价、存档兼容、温柔治愈画风。

---

## 0. 与主方案的根本分歧（先说清楚）

| 议题 | 主方案倾向 | **本方案** | 理由 |
|---|---|---|---|
| 农场定位 | 独立田园玩法 | **餐馆供应链上游** | 已有 `recipes.csv` 20 道菜，农场产出必须能填 `goods_id` 位，否则是孤岛 |
| 生长模型 | 按游戏日整数推进 | **按"浇水次数 + 天气系数"累积生长点** | 星露谷式"日结算"在《深城日常》的分钟制日历下会与营业时段冲突 |
| 工具升级 | 独立工具等级表 | **工具 = 消耗品 + 磨损，升级 = 换新工具** | 避免新增 `tool_levels` 数值条；磨损用视觉表现（锈迹/缺口） |
| 天气影响 | 全局系数 | **天气只影响"未浇水地块"和"特定作物收购价"** | 避免玩家算不清；天气提示由 NPC 自然说出 |
| 宠物参与 | 独立宠物系统 | **宠物 = 农场的"活体提示器" + 驱鸟** | 不新增宠物数值；宠物行为即提示 |
| 售卖 | 新增售卖 UI | **产出直接进餐馆库存，餐馆卖菜时消耗** | 复用现有 `InventoryManager` + `KitchenManager`，零新增 UI |
| 加工 | 新增加工台 | **加工 = 餐馆菜谱本身** | 番茄→番茄炒蛋，不需要"果酱机"这种新实体 |

**一句话**：农场是餐馆的"前置仓库"，不是"平行小游戏"。

---

## 1. 数据结构（唯一事实源）

### 1.1 新增 CSV：`data/crops.csv`

```csv
crop_id,name,seed_cost,seasons,grow_points,water_per_stage,yield_goods,yield_count,weather_bonus,weather_penalty,harvest_hint
greens_farm,小青菜,3,spring|autumn,4,1,greens,2,rain:1.5,heat:0.6,叶子有点蔫就该收了
tomato_farm,番茄,5,summer,6,1,tomato,3,heat:1.4,rain:0.7,红透了才甜
corn_farm,玉米,4,summer|autumn,5,1,corn,2,clear:1.2,rain:0.8,须子变褐就熟了
lemon_farm,柠檬,6,summer,7,1,lemon,4,heat:1.5,humid:0.8,黄了就能摘
red_bean_farm,红豆,4,autumn,5,1,red_bean,3,overcast:1.1,heat:0.7,豆荚鼓起来就收
tea_farm,茶青,5,spring|summer,6,1,tea,3,humid:1.3,heat:0.8,一芽两叶最好
```

**关键设计**：
- `grow_points` 是**累积生长点**，不是天数。每次浇水 +1 点，天气系数乘算。
- `yield_goods` 必须**已存在于 `goods.csv`**（`greens/tomato/corn/lemon/red_bean/tea` 全部已存在）。**不新增 goods**。
- `weather_bonus/penalty` 格式 `weather_id:multiplier`，只影响**未浇水地块**的当日生长点。

### 1.2 新增 CSV：`data/tools.csv`

```csv
tool_id,name,durability,cost,use_on,wear_per_use,broken_hint
hoe_wood,木锄,20,0,plot_empty,1,锄头松了，该换把新的
hoe_iron,铁锄,60,80,plot_empty,1,铁锄还能用很久
can_wood,木水壶,30,0,plot_growing,1,水壶漏水了
can_iron,铁水壶,90,120,plot_growing,1,铁水壶沉是沉，但省心
basket,竹篮,999,40,plot_ripe,0,竹篮结实，能用一辈子
```

**关键设计**：
- **工具是消耗品**，`durability` 归零后 `broken`，需在 `liang`（修车/修理师傅，npc-001 已定义）处换新。
- **不新增 `tool_levels` 字典**。`FarmManager.tool_levels` 改为 `FarmManager.tools: Dictionary`，值为 `{tool_id, durability}`。
- `basket` 是**收获必需**——没有篮子不能收获。这是"每件实物都有用途"的硬保证。

### 1.3 修改 `FarmManager` 状态结构

```gdscript
# 替换原 plots 结构
var plots: Array = []  # 每项: {stage, crop_id, grow_points, watered_today, weather_applied}
var tools: Dictionary = {}  # tool_id -> {durability: int}
var selected_crop_id := ""
var selected_tool_id := ""
var animals: Dictionary = {}  # 保留，但语义改为"宠物"
```

**删除**：`tool_levels`、`animal_fed`、`animal_progress`、`animal_product_ready`（宠物不产奶，只驱鸟）。

### 1.4 宠物数据（复用 `animals`）

```gdscript
# animals: {pet_id: {name, species, hunger, last_fed_day, bird_scared_today}}
# 宠物不产产品，只做两件事：
#   1. 驱鸟：每天首次喂食后，当天所有地块免于"鸟啄"事件
#   2. 提示：宠物在农场时，靠近地块会冒出气泡提示（"这块地渴了"）
```

**鸟啄事件**：未驱鸟且地块 `stage == ripe` 时，每天有 1 次机会被鸟啄掉 1 个产量。宠物驱鸟后免疫。

---

## 2. 核心循环（可触发，无面板）

### 2.1 触发链（全部场景点击）

```
[城郊农场入口] --点击--> FarmManager.unlock_farm()
     ↓ 首次解锁，NPC 老曲（qu，夏季河道清淤工）在河边说：
       "城郊那片荒地没人管，你要真想种，去跟社区说一声。"
     ↓ 玩家点击社区服务中心（cai）→ 解锁
     ↓
[农场场景] 6 块地，每块地是一个 WorldInteractable
     ↓ 点击空地 → 若 selected_tool_id == hoe_* → 耕地（stage: empty → tilled）
     ↓ 点击已耕地 → 若 selected_crop_id 非空 → 播种（stage: tilled → growing）
     ↓ 点击生长中地块 → 若 selected_tool_id == can_* → 浇水（watered_today = true）
     ↓ 点击成熟地块 → 若 selected_tool_id == basket → 收获（产出进 InventoryManager）
     ↓
[餐馆] 菜谱消耗农场产出（greens/tomato/corn/lemon/red_bean/tea）
     ↓ 玩家在餐馆点菜 → KitchenManager 检查库存 → 有则做，无则提示
```

**关键**：**没有"农场 UI"**。所有操作在场景里点击地块完成。工具切换通过**点击工具栏实体**（场景里的锄头架/水壶架/篮子架）。

### 2.2 生长推进（分钟制适配）

```gdscript
# FarmManager._on_minute_changed(minute):
#   每 60 游戏分钟检查一次
#   若地块 watered_today == true 且未结算：
#       grow_points += 1 * weather_multiplier(crop_id, weather_id)
#       watered_today = false
#       weather_applied = true
#   若 grow_points >= crop.grow_points: stage = ripe
```

**天气系数**（只对未浇水地块生效，已浇水地块固定 +1）：

```gdscript
func _weather_multiplier(crop_id: String, weather_id: String) -> float:
    var row := get_crop_row(crop_id)
    var bonus := str(row.get("weather_bonus", ""))
    var penalty := str(row.get("weather_penalty", ""))
    if bonus.begins_with(weather_id + ":"):
        return float(bonus.split(":")[1])
    if penalty.begins_with(weather_id + ":"):
        return float(penalty.split(":")[1])
    return 1.0
```

**为什么这样设计**：
- 星露谷是"日结算"，但《深城日常》是分钟制，玩家可能一天内多次进出农场。
- 用"浇水次数"而非"天数"，玩家**每次浇水都有即时反馈**（地块视觉变化：土色变深）。
- 天气系数只影响**未浇水**地块，逼玩家看天气决定浇不浇——这就是"天气影响"的可玩性。

### 2.3 天气提示（NPC 自然说出，不用面板）

**不新增天气 UI**。天气提示由**农场场景里的 NPC** 说出：

| 天气 | NPC | 台词（成品句，非模板） |
|---|---|---|
| rain | 老曲（qu，河边） | "今天这雨，地不用浇了，叶菜还能多长一截。" |
| heat | 阿青（qing_jie，环卫） | "热得柏油都软了，你那番茄倒是欢喜。" |
| humid | 李妈（li_ma，托儿所） | "回南天，衣服晾不干，菜倒是长得快。" |
| overcast | 阿良（liang，修理） | "阴天不晒，该浇还得浇。" |
| clear | 老宋（song，夜宵摊） | "天好，晚上来吃碗面？" |

**实现**：`FarmManager.get_weather_farm_hint()` 已存在，改为**返回 NPC 台词**，由 `NpcVoiceSelector` 在玩家靠近对应 NPC 时触发。

**约束**：天气提示**只在农场场景或河边场景**触发，不在餐馆触发（避免干扰经营）。

---

## 3. 工具升级（无等级条）

### 3.1 磨损可视化

- `durability` 归零 → 工具图标变灰 + 裂纹贴图（`art-002` 的九宫格规范复用）。
- **不显示数字**。玩家看到裂纹就知道该换了。

### 3.2 换新路径

```
[农场] 点击锄头架 → 若当前锄头 broken → 提示"去阿良那儿看看"
[街道] 找阿良（liang）→ 点击 → 弹出换新对话（非面板，是 NPC 对话）
     ↓ 阿良："木锄 20 块，铁锄 80 块，你要哪个？"
     ↓ 玩家点击对话选项（复用现有对话系统）
     ↓ 扣钱，换新工具
```

**关键**：**不新增商店 UI**。复用 `liang` 的现有对话系统，加一个 `tool_shop` 分支。

### 3.3 工具升级的经济意义

| 工具 | 成本 | 耐久 | 单次成本 |
|---|---|---|---|
| 木锄 | 0（初始） | 20 | 0 |
| 铁锄 | 80 | 60 | 1.33 |
| 木水壶 | 0（初始） | 30 | 0 |
| 铁水壶 | 120 | 90 | 1.33 |
| 竹篮 | 40 | ∞ | 0 |

**设计意图**：铁工具单次成本与木工具持平，但**减少换新频率**。玩家在 Day 7 左右会自然需要换新，形成"农场收入 → 工具投资 → 更高效率"的闭环。

---

## 4. 售卖/加工（复用餐馆）

### 4.1 产出直接进餐馆库存

```gdscript
# FarmManager.harvest(plot_index):
#   var goods_id := crop.yield_goods
#   var count := crop.yield_count
#   InventoryManager.add_item(goods_id, count)
#   NoticeManager.show_message("收了 %d 份%s。" % [count, goods_name], "hint", "农场")
```

**不新增售卖 UI**。产出进 `InventoryManager` 后，餐馆做菜时自动消耗。

### 4.2 加工 = 菜谱

| 农场产出 | 可做的菜 | 利润 |
|---|---|---|
| greens | 蛋炒饭、牛肉面、汤河粉 | 18/36/15 |
| tomato | （需新增菜谱？） | — |
| corn | （需新增菜谱？） | — |
| lemon | 手打柠檬茶 | 20 |
| red_bean | 红豆包、广式糖水 | 26/16 |
| tea | 手打柠檬茶、茶叶蛋 | 20/5 |

**问题**：`tomato` 和 `corn` 在 `recipes.csv` 里**没有对应菜谱**。这是硬伤。

**解决方案**（二选一）：
- **方案 A**：新增 2 道菜谱 `tomato_egg`（番茄炒蛋）和 `corn_soup`（玉米排骨汤），消耗 `tomato`/`corn`。
- **方案 B**：把 `tomato`/`corn` 从 `crops.csv` 移除，只保留有菜谱的作物。

**本方案选 A**，因为：
- 番茄炒蛋是"温柔治愈"的典型家常菜，符合画风。
- 玉米排骨汤同理。
- 新增菜谱成本低（`recipes.csv` 加 2 行）。

```csv
tomato_egg,番茄炒蛋,tomato:2|egg:2,1,1,3.0,22,主食,lunch|dinner,prep:1.5|fry:2.8|serve:0.5
corn_soup,玉米排骨汤,corn:2|pork:1,1,1,4.0,28,汤品,lunch|dinner,prep:1.2|boil:3.5|serve:0.5
```

### 4.3 固定物价

**所有农场产出不单独定价**。产出价值 = 它在菜谱里的贡献。例如：
- `greens` 批发价 2 元，农场自产成本 = 种子 3 元 / 2 份 = 1.5 元/份。
- 玩家自产比批发**便宜 0.5 元/份**，这就是农场的经济意义。

**不新增"农场售卖"**。玩家不能直接卖菜，只能通过餐馆卖菜。这保证**农场不脱离餐馆经济**。

---

## 5. 宠物参与（无数值）

### 5.1 宠物 = 活体提示器

```gdscript
# PetActor（复用 NpcActor 或新建轻量 Actor）
# 行为：
#   1. 跟随玩家在农场场景移动
#   2. 靠近未浇水地块时，头顶冒气泡 "💧"（视觉提示，非文字）
#   3. 靠近成熟地块时，头顶冒气泡 "🌾"
#   4. 每天首次喂食后，bird_scared_today = true
```

**关键**：**宠物不显示饥饿值**。饥饿用**行为**表现：
- 饿了 → 宠物趴下不动，不冒气泡。
- 喂了 → 宠物站起来，冒气泡。

### 5.2 驱鸟机制

```gdscript
# FarmManager._on_day_started():
#   for plot in plots:
#       if plot.stage == ripe and not pet.bird_scared_today:
#           if randf() < 0.3:
#               plot.yield_count -= 1
#               NoticeManager.show_message("有鸟啄了你的%s。" % crop_name, "hint", "农场")
```

**宠物驱鸟后**：当天所有地块免疫鸟啄。这是宠物唯一的"功能"，但足够。

### 5.3 宠物获取

**复用 `ahui`（阿灰，宠物店/流浪动物照料，npc-001 已定义）**：
- 玩家在 `ahui` 处领养宠物（免费或小额）。
- `ahui` 台词："这只小猫在门口蹲了三天了，你要不要带回去？农场有它，鸟就不敢来了。"

**不新增宠物系统**。`ahui` 的现有对话加一个 `adopt_pet` 分支。

---

## 6. NPC 自然提示（无任务面板）

### 6.1 提示分布

| NPC | 位置 | 提示内容 | 触发条件 |
|---|---|---|---|
| 老曲（qu） | 河边 | 农场解锁 | 玩家首次到河边 |
| 小蔡（cai） | 社区服务中心 | 农场手续 | 玩家点击社区窗口 |
| 阿良（liang） | 街道 | 工具换新 | 玩家工具 broken |
| 阿灰（ahui） | 宠物店 | 领养宠物 | 玩家首次进宠物店 |
| 李妈（li_ma） | 托儿所 | 天气提示（humid） | 回南天 |
| 阿青（qing_jie） | 街道 | 天气提示（heat） | 酷暑 |
| 老宋（song） | 夜宵摊 | 天气提示（clear） | 晴天 |

### 6.2 提示实现（复用 `npc-002` 的 `NpcVoiceSelector`）

```gdscript
# npc_voice_selector.gd 新增分支
func get_farm_hint(npc_id: String, context: Dictionary) -> String:
    match npc_id:
        "qu":
            if not FarmManager.has_farm:
                return "城郊那片荒地没人管，你要真想种，去跟社区说一声。"
        "cai":
            if not FarmManager.has_farm:
                return "想租城郊那块地？填个表就行，不收费。"
        "liang":
            if _has_broken_tool():
                return "锄头松了？木的 20，铁的 80，你要哪个？"
        "ahui":
            if not _has_pet():
                return "这只小猫在门口蹲了三天了，你要不要带回去？农场有它，鸟就不敢来了。"
    return ""
```

**约束**：提示**只在玩家靠近 NPC 时触发**，不主动弹出。**不排队**（`npc-002` D7 已定）。

---

## 7. 存档兼容

### 7.1 新增字段

```gdscript
# SaveManager 新增
"farm": {
    "has_farm": bool,
    "plots": Array,  # 新结构
    "tools": Dictionary,  # 新结构
    "selected_crop_id": String,
    "selected_tool_id": String,
    "animals": Dictionary,  # 语义变更
}
```

### 7.2 迁移策略

```gdscript
# save-001 的迁移链新增 v15 -> v16
func _migrate_v15_to_v16(data: Dictionary) -> Dictionary:
    var farm := data.get("farm", {})
    # 旧 plots: {stage, crop_id, days_grown, watered}
    # 新 plots: {stage, crop_id, grow_points, watered_today, weather_applied}
    var old_plots := farm.get("plots", [])
    var new_plots := []
    for old in old_plots:
        new_plots.append({
            "stage": old.get("stage", "empty"),
            "crop_id": old.get("crop_id", ""),
            "grow_points": int(old.get("days_grown", 0)) * 2,  # 旧天数 * 2 = 新生长点
            "watered_today": old.get("watered", false),
            "weather_applied": false,
        })
    farm["plots"] = new_plots
    # 旧 tool_levels -> 新 tools
    var old_levels := farm.get("tool_levels", {})
    var new_tools := {}
    for tool_id in old_levels:
        var level := int(old_levels[tool_id])
        new_tools[tool_id] = {"durability": 20 + level * 20}
    farm["tools"] = new_tools
    farm.erase("tool_levels")
    data["farm"] = farm
    return data
```

**关键**：旧存档的 `days_grown` 按 2 倍转 `grow_points`，保证玩家不会因迁移损失进度。

---

## 8. 迁移步骤（可执行）

### 阶段 0：门禁（阻塞）

```bash
# 确认现有 FarmManager 接口
grep -n "func " autoload/farm_manager.gd
# 确认 recipes.csv 是否有 tomato/corn 菜谱
grep -n "tomato\|corn" data/recipes.csv
# 确认 goods.csv 是否有全部产出
grep -n "greens\|tomato\|corn\|lemon\|red_bean\|tea" data/goods.csv
# 确认 liang/ahui/qu/cai 是否已在 npcs.csv
grep -n "liang\|ahui\|qu\|cai" data/npcs.csv
```

**未通过不得进入阶段 1**。

### 阶段 1：数据层（无代码依赖）

1. 新建 `data/crops.csv`（6 行）
2. 新建 `data/tools.csv`（5 行）
3. 修改 `data/recipes.csv`（+2 行：`tomato_egg`、`corn_soup`）
4. 修改 `data/npcs.csv`（+4 行：`liang/ahui/qu/cai` 的农场提示字段）

### 阶段 2：FarmManager 重构

1. 替换 `plots` 结构
2. 替换 `tool_levels` → `tools`
3. 新增 `_weather_multiplier()`
4. 新增 `_on_minute_changed()` 生长推进
5. 新增 `harvest()` 产出进 `InventoryManager`
6. 删除 `animal_fed/animal_progress/animal_product_ready`

### 阶段 3：场景层

1. `farm_plot_layer.gd` 适配新 `plots` 结构
2. 新增 `tool_rack.gd`（工具栏实体，点击切换工具）
3. 新增 `pet_actor.gd`（宠物，复用 `NpcActor`）
4. `world.gd` 新增 `farm_requested` 信号处理

### 阶段 4：NPC 提示

1. `npc_voice_selector.gd` 新增 `get_farm_hint()`
2. `liang` 对话加 `tool_shop` 分支
3. `ahui` 对话加 `adopt_pet` 分支
4. `qu/cai` 对话加 `farm_unlock` 分支

### 阶段 5：存档迁移

1. `save-001` 迁移链加 `v15 -> v16`
2. 测试旧存档加载

### 阶段 6：验收

```bash
# 农场解锁
godot --headless --script test_farm_unlock.gd
# 生长推进
godot --headless --script test_farm_growth.gd
# 工具磨损
godot --headless --script test_tool_wear.gd
# 存档迁移
godot --headless --script test_save_migration_v15_v16.gd
```

---

## 9. 与主方案的关键差异总结

| 维度 | 主方案 | 本方案 | 优势 |
|---|---|---|---|
| 生长模型 | 按天 | 按浇水次数 | 分钟制适配，即时反馈 |
| 工具 | 等级表 | 消耗品 + 磨损 | 无数值条，视觉表现 |
| 售卖 | 新增售卖 UI | 直接进餐馆库存 | 零新增 UI |
| 加工 | 新增加工台 | 复用菜谱 | 零新增实体 |
| 宠物 | 独立系统 | 活体提示器 + 驱鸟 | 零新增数值 |
| 天气 | 全局系数 | 只影响未浇水地块 | 玩家算得清 |
| 提示 | 任务面板 | NPC 自然说出 | 符合硬约束 |

**核心洞察**：**农场不需要"新系统"，只需要"新数据 + 新场景 + 新提示"**。所有机制复用现有 `InventoryManager`/`KitchenManager`/`NpcVoiceSelector`/`SaveManager`。这是最省工、最符合"温柔治愈"约束的实现路径。

## 批判

## 批判A（qa_lead）

# 批判报告：两份方案的遗漏、冲突、死代码与返工要求

## A. 阻塞性冲突（必须先裁决，否则两份都不可实现）

### A1. 生长模型互斥，且都未验证日历粒度
- 主方案：`advance_day()` 按游戏日推进，`days_grown += mult`。
- 独立方案：`_on_minute_changed()` 每 60 分钟结算一次，`grow_points += mult`。
- **冲突**：`CalendarManager` 到底有没有 `day_started` 信号？有没有 `minute_changed`？两者是否同时存在？主方案 §3.1 直接 `CalendarManager.day_started.connect(...)`，独立方案 §2.2 直接 `_on_minute_changed`，**都没有在 G0 门禁里 grep 过**。
- **返工要求**：
  ```bash
  grep -n "^signal \|^func " autoload/calendar_manager.gd
  grep -n "day_started\|minute_changed\|hour_changed" -r autoload/ scripts/
  ```
  若只有 `day_started` → 独立方案的分钟制生长**不可触达**，必须改日结算或新增信号（新增信号要评估对现有系统的影响）。若两者都有 → 必须明确**同一地块不能双结算**，否则生长速度翻倍。

### A2. 存档结构互斥，且独立方案的迁移是**破坏性**的
- 主方案：保留 `tool_levels`（int 等级），新增 `animals/animal_fed/animal_progress/animal_product_ready/dog_helped_today`。
- 独立方案：**删除** `tool_levels`，改为 `tools: {tool_id: {durability}}`；**删除** `animal_fed/animal_progress/animal_product_ready`；`plots` 结构从 `{stage,crop_id,days_grown,watered}` 改为 `{stage,crop_id,grow_points,watered_today,weather_applied}`。
- **风险**：独立方案 §7.2 的 `_migrate_v15_to_v16` 把 `days_grown * 2` 转 `grow_points`，但**没有说明 v16 之后 `advance_day` 是否还写 `days_grown`**。如果 `farm_plot.gd` 的 `_growth_frame` 仍读 `days_grown`（主方案 §3.3 就是这么写的），迁移后 `days_grown` 字段消失 → **读档后所有作物视觉帧归零**。
- **返工要求**：
  1. 先 grep 现有存档版本号与迁移链：
     ```bash
     grep -n "SAVE_VERSION\|_migrate_v\|version" autoload/save_manager.gd | head -40
     ```
  2. 二选一，**不允许两套 plots 结构并存**。若选独立方案，必须同步改 `farm_plot.gd` 的 `_growth_frame` 读 `grow_points`；若选主方案，独立方案的 `tools` 结构作废。
  3. 迁移函数必须**幂等**：连续加载两次不改变结果。独立方案的 `days_grown * 2` 若旧档已是 v16 结构（无 `days_grown`），`int(old.get("days_grown", 0)) * 2 = 0` → **进度清零**。必须加 `if old.has("grow_points"): continue`。

### A3. 工具模型互斥，且主方案的 `upgrade_tool` 有死代码
- 主方案：`tool_levels[tool_id] = int(row.get("level","1"))`，`upgrade_tool("hoe_2")` 直接写 level。
- 独立方案：工具是消耗品，`durability` 归零换新，**没有 level 概念**。
- **主方案死代码**：`upgrade_tool` 里 `var from_id := str(row.get("upgrade_from", ""))`，但**从未校验玩家当前是否持有 `from_id`**。玩家可以直接 `upgrade_tool("hoe_2")` 而不拥有 `hoe_1`，白嫖升级。且 `tool_levels` 里存的是 `tool_id`（如 `hoe_2`）还是 `tool`（如 `hoe`）？主方案 §3.1 写 `tool_levels[tool_id] = level`，但 §3.1 的 `harvest` 读 `tool_levels.get("sickle", 1)` —— **key 不一致**（`sickle` vs `sickle_2`）。这是**必然崩溃**的 bug。
- **返工要求**：
  - 主方案：`upgrade_tool` 必须校验 `InventoryManager` 或 `tool_levels` 中持有 `from_id`；`tool_levels` 的 key 统一为**工具类别**（`hoe/watering_can/sickle/basket`），value 为 level。`harvest` 读 `tool_levels.get("sickle",1)` 才对。
  - 独立方案：`tools` 的 key 是 `tool_id`（`hoe_wood/hoe_iron`），`harvest` 必须查"当前装备的 tool 是否 `basket`"，否则**不能收获**。但独立方案 §4.1 的 `harvest` 直接 `InventoryManager.add_item`，**没有校验 basket**，与 §1.2 "没有篮子不能收获"矛盾。

---

## B. 不可触达机制（设计了但玩家到不了）

### B1. 主方案：`farm_workbench` / `farm_sell_truck` / `farm_coop` 三个交互物**没有触发入口**
- §3.4 在 `world.gd` 里 `InteractableScript.new()` 并 `interacted.connect(...)`，但**没有说明 `InteractableScript` 的 `interacted` 信号是否已存在**，也没有说明 `interaction_id` 如何被点击系统识别。
- 更严重：`_on_farm_workbench` 只 `emit_signal("farm_workbench_requested")`，**谁监听这个信号？** 主方案 §3.5 只写了 `farm_sell_panel.gd`，**没有 workbench 面板、没有 coop 面板**。三个信号里两个是死信号。
- **返工要求**：
  ```bash
  grep -n "interacted\|interaction_id" scripts/gameplay/interactable.gd
  grep -rn "farm_workbench_requested\|farm_sell_requested\|farm_coop_requested" --include=*.gd .
  ```
  若无人监听 → 要么补 UI，要么删信号。**不允许留死信号**。

### B2. 独立方案：`tool_rack.gd` 是"工具栏实体"，但**没有定义点击后如何切换工具**
- §2.1 说"工具切换通过点击工具栏实体"，§阶段3 说"新增 `tool_rack.gd`"，但**全文没有 `tool_rack.gd` 的实现**，也没有 `selected_tool_id` 的赋值逻辑。
- 结果：`selected_tool_id` 永远是空字符串 → 耕地/浇水/收获**全部不可触发**。
- **返工要求**：补 `tool_rack.gd` 的 `interact()`，明确点击后 `FarmManager.selected_tool_id = tool_id`，并给出视觉反馈（当前工具高亮）。

### B3. 独立方案：宠物"跟随玩家"但**没有寻路**
- §5.1 "跟随玩家在农场场景移动"，但**没有说明用 `NavigationAgent2D` 还是简单 lerp**。若农场场景没有导航网格，宠物会卡在障碍物。
- **返工要求**：明确宠物移动方式。若用简单 lerp，必须声明"农场无障碍物"或"宠物可穿墙"。

### B4. 主方案：`_spawn_dog()` 被定义但**从未调用**
- §5 定义了 `_spawn_dog()`，但 §3.2 的 `farm_plot_layer.gd` `_ready` 里只调 `_build()`，**没有调 `_spawn_dog()`**。
- **返工要求**：在 `_ready` 或 `_refresh` 中调用，且加"只 spawn 一次"的守卫（否则每次 `changed` 都 spawn 一只狗）。

### B5. 主方案：`_dog_helped_today` 重置逻辑**没有实现**
- §5 说"`_dog_helped_today` 在 `CalendarManager.day_started` 时重置"，但 §3.1 的 `_on_day_started` 只调 `advance_day()`，**没有重置 `_dog_helped_today`**。
- 且 `_dog_helped_today` 是 `farm_plot_layer.gd` 的成员，`_on_day_started` 在 `farm_manager.gd`，**跨对象**。主方案 §6 的 `to_save_dict` 却把它当 `farm_manager` 的字段存 —— **归属混乱**。
- **返工要求**：明确 `_dog_helped_today` 归属 `FarmManager`，`advance_day()` 里重置，`farm_plot_layer` 只读。

---

## C. 经济闭环断裂

### C1. 主方案：`_sell_price` 用 `begins_with` 匹配 goods_id，**必然误匹配**
```gdscript
if str(row.get("yield_goods", "")).begins_with(goods_id):
```
- `yield_goods` 格式是 `greens:2`，`goods_id` 是 `greens`。`"greens:2".begins_with("greens")` → true，**碰巧对**。
- 但 `flour_wheat` 的 `yield_goods` 是 `flour:2`，而 `goods.csv` 里还有 `flour` 和 `flour_wheat` 两个 goods？若 `goods_id = "flour"`，`"flour:2".begins_with("flour")` → true，**但 `flour_wheat` 的 `yield_goods` 也是 `flour:2`**，会返回 `flour_wheat` 的 `sell_price`。若未来有 `flour_rice`，误匹配更严重。
- **返工要求**：改为 `yield_goods.split(":")[0] == goods_id`，或建 `goods_id -> crop_id` 反查表。

### C2. 主方案：`restaurant_price` 字段**定义了但从未使用**
- §2.1 定义了 `restaurant_price`，§3.5 的 `_build_list` 显示"餐馆价"，但 `_on_sell` **只按 `_sell_price` 结算**。玩家看到"餐馆 6"却只能卖 4。
- 且 §3.5 注释说"餐馆加工路径：不新建 UI，玩家把作物带到餐馆"，但**没有实现"带作物到餐馆"的交互**。`KitchenManager._consume_ingredient` 的补丁只是"优先消耗自种作物"，**没有给玩家更高的钱**。
- **返工要求**：要么实现"送餐馆"交互（点击餐馆备料台 → 按 `restaurant_price` 结算），要么删 `restaurant_price` 字段。**不允许 UI 显示一个玩家拿不到的价格**。

### C3. 独立方案：`tomato`/`corn` 无菜谱，方案 A 新增菜谱但**没有验证 `pork`/`egg` 是否存在**
- §4.2 新增 `tomato_egg`（`tomato:2|egg:2`）和 `corn_soup`（`corn:2|pork:1`）。
- `egg` 在 `goods.csv` 存在（主方案 §2.3 提到 `egg`），但 `pork` **两份方案都没验证**。
- **返工要求**：
  ```bash
  grep -n "^pork\|,pork," data/goods.csv
  grep -n "pork" data/recipes.csv
  ```
  若 `pork` 不存在 → `corn_soup` 不可做，必须换原料或删菜谱。

### C4. 独立方案：`greens` 批发价 2 元 vs 种子 3 元/2 份 = 1.5 元/份，**但没算浇水/工具成本**
- §4.3 说"自产比批发便宜 0.5 元/份"，但：
  - 木锄耐久 20，铁锄 80 元/60 次 = 1.33 元/次耕地。
  - 木水壶耐久 30，铁水壶 120 元/90 次 = 1.33 元/次浇水。
  - 一茬 `greens` 至少 1 次耕地 + 4 次浇水（`grow_points=4`）= 1.33 + 5.33 = 6.66 元工具成本。
  - 种子 3 元 + 工具 6.66 元 = 9.66 元 / 2 份 = **4.83 元/份**，**比批发 2 元贵一倍**。
- **返工要求**：重算经济模型。要么降低工具成本，要么提高 `yield_count`，要么承认"农场不省钱，只是好玩"。**不允许用错误的算术支撑设计决策**。

### C5. 主方案：动物产出 `egg`/`milk` 的**售价未定义**
- §2.3 定义 `product_goods = egg/milk`，§3.1 `collect_animal_product` 直接 `InventoryManager.add_item(goods, 1)`。
- 但 `egg`/`milk` 在 `goods.csv` 的 `base_cost` 是多少？`chicken` 买入 200，`product_days=1.0`，若 `egg` 卖 5 元，40 天回本；若卖 2 元，100 天回本。**方案没有给出数字**。
- **返工要求**：补 `egg`/`milk` 的 `base_cost`，并验证回本周期 ≤ 15 游戏日（否则动物系统是负收益，玩家不会碰）。

---

## D. 测试漏洞

### D1. 主方案 §7.1 测试用例**没有覆盖存档迁移**
- 用例有"存档往返"，但**没有"旧档（无 `dog_helped_today`）加载"**。§6 说"旧档加载时补默认值"，但没测。
- **返工要求**：加用例 `test_load_legacy_save_without_new_fields`，构造一个不含 `dog_helped_today/animals/animal_fed` 的 dict，`from_save_dict` 后断言不崩溃且默认值正确。

### D2. 主方案 §7.1 "雨天加速"用例**不可靠**
- `advance_day()` 里 `mult` 依赖 `WeatherSystem.current_weather_id`，测试必须 mock 天气。方案**没有说明如何 mock**。
- **返工要求**：给出 mock 方式（如 `WeatherSystem.current_weather_id = "rain"` 直接赋值，或注入 `weather_provider`）。若 `current_weather_id` 是只读属性，测试不可写。

### D3. 独立方案 §8 验收脚本**不存在**
- `godot --headless --script test_farm_unlock.gd` 等 4 个脚本**没有给出内容**。
- **返工要求**：补 4 个脚本的最小实现，或改为 GUT 测试用例。

### D4. 两份方案都**没有测"工具 broken 后不能使用"**
- 独立方案 §1.2 说 `durability` 归零后 `broken`，但**没有测试**"broken 工具点击地块不生效"。
- **返工要求**：加用例 `test_broken_tool_cannot_till`。

### D5. 两份方案都**没有测"非当季作物不能种"**
- 主方案 §7.1 有"种植非当季作物"用例，但独立方案**没有**。
- **返工要求**：独立方案补 `test_plant_out_of_season_fails`。

### D6. 主方案 §7.2 集成测试**被截断**
- 原文到"1."就没了。**必须补全**，否则无法验收。

---

## E. 死代码与冗余

| 位置 | 问题 | 返工 |
|---|---|---|
| 主方案 §3.1 `upgrade_tool` | `from_id` 读取后未使用 | 加持有校验或删变量 |
| 主方案 §3.4 `farm_requested` | "不删除，用于兼容旧调用"，但**没有说明谁还在调** | grep 确认，无人调则删 |
| 主方案 §3.5 `_get_sellable_goods` | 遍历 `ConfigDB.get_rows("goods")`，但 `get_rows` 返回的是 id 列表还是 dict？ | 确认 API，否则遍历出错 |
| 主方案 §4.2 `_get_farm_hint` | `FarmManager.animal_fed.values().any(...)` 在 GDScript 4 中 `any` 是 `Array.any()`，**GDScript 3 没有** | 确认 Godot 版本，否则语法错误 |
| 独立方案 §1.3 | "删除 `animal_fed/animal_progress/animal_product_ready`"，但 §1.4 又用 `animals: {pet_id: {hunger, last_fed_day, bird_scared_today}}` | 语义混乱：`animals` 到底是家畜还是宠物？ |
| 独立方案 §5.1 | "复用 NpcActor 或新建轻量 Actor" | 二选一，不允许"或" |
| 独立方案 §6.2 | `_has_broken_tool()` / `_has_pet()` 未定义 | 补实现或删 |

---

## F. 存档风险清单

1. **主方案**：`plots` 是 `Array[Dictionary]`，`from_save_dict` 直接 `data.get("plots", _default_plots())`。若旧档 `plots` 长度 ≠ `PLOT_COUNT`（如旧版 4 块，新版 6 块），**索引越界**。必须补长度对齐。
2. **主方案**：`tool_levels` 若旧档存的是 `{"hoe": 1}`，新代码读 `tool_levels.get("sickle", 1)` → 默认 1，**旧档玩家白得 sickle 1**。可接受，但要声明。
3. **独立方案**：`_migrate_v15_to_v16` 把 `days_grown * 2` 转 `grow_points`，但**没有处理 `stage == "ripe"` 的地块**。ripe 地块 `grow_points` 应为 `grow_points` 上限，否则迁移后 ripe 变 growing。
4. **独立方案**：`tools` 迁移 `durability = 20 + level * 20`，但旧档 `tool_levels` 的 key 是 `hoe`，新 `tools` 的 key 是 `hoe_wood/hoe_iron`。**key 不匹配** → 迁移后玩家没有工具 → 不能耕地。
5. **两份方案**：都没有处理"存档中途退出"（`request_auto_save` 是否原子写）。若写一半崩溃，存档损坏。

---

## G. 返工优先级（按阻塞程度）

**P0（不解决无法开工）**：
1. A1 日历信号确认
2. A2 存档结构二选一 + 幂等迁移
3. A3 工具 key 统一
4. B1 死信号清理
5. B2 `tool_rack.gd` 补实现
6. C1 `begins_with` 误匹配修复

**P1（不解决经济闭环断裂）**：
7. C2 `restaurant_price` 落地或删除
8. C3 `pork` 存在性验证
9. C4 经济模型重算
10. C5 `egg/milk` 定价

**P2（不解决测试不可信）**：
11. D1-D6 测试补全
12. B4/B5 狗 spawn 与重置
13. E 死代码清理

**P3（文档）**：
14. F 存档风险清单写入 `docs/FARM_FACTS.md`
15. 主方案 §7.2 补全

---

## H. 一句话裁决

**两份方案都不能直接实现**。主方案有 3 处必然崩溃的 bug（tool_levels key 不一致、`begins_with` 误匹配、死信号），独立方案有 2 处不可触达（`tool_rack` 无实现、宠物无寻路）和 1 处经济算术错误（工具成本 > 批发价）。**先做 P0 的 6 项门禁与修复，再谈实现**。

## 批判B（gameplay_planner）

# 批判报告：农场/田园与天气工具经济闭环

> 只列**可执行的返工要求**。每条给出：问题定位 → 证据 → 返工动作 → 验收标准。

---

## A. 阻塞性冲突（两份方案互斥，必须先裁决）

### A1. 生长模型互斥，且都未验证日历粒度
- **冲突**：主方案 §1「按游戏日 + 浇水」vs 独立方案 §2.2「按浇水次数累积生长点」。
- **证据**：主方案 `advance_day()` 挂在 `CalendarManager.day_started`；独立方案挂在 `_on_minute_changed`。两者对「一天内多次浇水」行为完全不同。
- **返工**：
  1. 先执行门禁 `grep -n "day_started\|minute_changed\|hour_changed" autoload/calendar_manager.gd`，确认**实际存在的信号**。
  2. 若只有 `day_started` → 独立方案的分钟制生长**不可实现**，必须降级为日结算。
  3. 若两者都有 → 裁决：**农场生长用日结算**（与 `farm_manager` 现有 `days_grown` 一致，迁移成本最低），独立方案的「浇水即时反馈」改为**视觉反馈**（土色变深）而非生长推进。
- **验收**：`docs/FARM_FACTS.md` 写明「生长推进信号 = X，粒度 = Y」，两份方案统一。

### A2. 工具模型互斥，且独立方案的「工具是消耗品」与主方案「工具等级」不能共存
- **冲突**：主方案 `tool_levels: {hoe: 2}` vs 独立方案 `tools: {hoe_iron: {durability: 60}}`。
- **证据**：主方案 §3.1 `upgrade_tool()` 写 `tool_levels[tool_id] = level`；独立方案 §1.3 明确「删除 tool_levels」。
- **返工**：
  1. **裁决为消耗品模型**（独立方案），理由：主方案的「等级」是数值属性条的变体，违反硬约束「无数值属性条」。
  2. 但**保留主方案的实物升级路径**（铁匠铺买部件 → 工作台合成），只是产物从「等级 +1」改为「新工具实体 + 满耐久」。
  3. 删除主方案 §2.2 的 `level` 列，改为 `durability` 列。
- **验收**：`data/tools.csv` 无 `level` 列；`FarmManager` 无 `tool_levels` 字段。

### A3. 售卖路径互斥
- **冲突**：主方案「收购车 UI + 餐馆双价」vs 独立方案「产出直接进餐馆库存，不新增售卖 UI」。
- **证据**：主方案 §3.5 新建 `farm_sell_panel.gd`；独立方案 §4.1 明确「不新增售卖 UI」。
- **返工**：
  1. **裁决为独立方案**（产出进 `InventoryManager`，餐馆消耗），理由：主方案的收购车 UI 是「纯菜单购买」的变体，违反硬约束。
  2. 但**保留主方案的「餐馆价 > 收购价」经济激励**，实现方式改为：`KitchenManager` 做菜时，若用自种作物，菜品售价 +10%（通过 `recipes.csv` 新增 `homegrown_bonus` 列）。
- **验收**：无 `farm_sell_panel.gd`；`recipes.csv` 有 `homegrown_bonus` 列。

### A4. 宠物模型互斥
- **冲突**：主方案「阿黄帮你收 1 块」vs 独立方案「宠物驱鸟 + 气泡提示」。
- **证据**：主方案 §5 `_on_dog_interact()` 调用 `FarmManager.harvest(i)`；独立方案 §5.1 宠物只冒气泡。
- **返工**：
  1. **裁决为独立方案**（驱鸟 + 提示），理由：主方案的「宠物帮你收获」是**自动化脚本**，违反「动作驱动」硬约束。
  2. 但**保留主方案的触发条件**（有农场 + 喂过饲料），作为宠物出现的条件。
- **验收**：宠物无 `harvest()` 调用；有 `bird_scared_today` 字段。

---

## B. 死代码与不可触达机制

### B1. 主方案 §3.5 `_sell_price()` 逻辑错误
- **问题**：`str(row.get("yield_goods", "")).begins_with(goods_id)` —— `yield_goods` 格式是 `greens:2`，`begins_with("greens")` 为 true，但若 `goods_id = "green"` 也会误匹配。
- **返工**：改为 `str(row.get("yield_goods", "")).split(":")[0] == goods_id`。
- **验收**：单元测试覆盖 `goods_id = "green"` 不匹配 `greens:2`。

### B2. 主方案 §3.1 `advance_day()` 中 `plot["watered"] = false` 位置错误
- **问题**：在 `continue` 分支后重置，但 `STAGE_EMPTY` 的地块也会被重置（无害），而 `STAGE_RIPE` 的地块**不会**被重置（因为 `continue` 跳过了）。但成熟地块的 `watered` 状态无意义，**这是死状态**。
- **返工**：`watered` 重置移到循环外，或只在 `STAGE_GROWING` 时重置。
- **验收**：`STAGE_RIPE` 地块的 `watered` 字段不参与任何逻辑。

### B3. 主方案 §4.2 `ahui` 提示条件 `FarmManager.animal_fed.values().any(...)` 不可达
- **问题**：`animal_fed` 是 `Dictionary`，`.values()` 返回 `Array`，`.any()` 是 `Array` 方法，但 GDScript 的 `Array.any()` 需要 `Callable`。写法 `func(v): return v` 在 GDScript 4 中合法，但**若 `animal_fed` 为空字典，`.any()` 返回 false，提示不触发**——这是预期行为，但**玩家永远喂不了动物**（因为动物系统未实现）。
- **返工**：门禁 G0.5 确认 `animals` 是否已实现。若未实现，**删除所有动物相关代码**，宠物参与降级为「阿灰的狗来农场」纯叙事。
- **验收**：`docs/FARM_FACTS.md` 写明「动物系统 = 已实现 / 未实现，宠物参与 = 常驻 / 一次性」。

### B4. 独立方案 §2.2 `_on_minute_changed` 与 `watered_today` 语义冲突
- **问题**：`watered_today` 在分钟制下，玩家一天内可能浇水多次，但 `watered_today` 是布尔值，**第二次浇水无效果**。而独立方案 §2.1 说「点击生长中地块 → 浇水」，玩家会困惑「为什么浇了没反应」。
- **返工**：改为 `watered_count: int`，每次浇水 +1，生长点 = `watered_count * weather_multiplier`。或明确「每地块每日只能浇一次」，用视觉提示（土色已深）阻止重复浇水。
- **验收**：单元测试覆盖「同日二次浇水」行为。

### B5. 独立方案 §4.2 新增菜谱 `tomato_egg` / `corn_soup` 未验证 `recipes.csv` 列结构
- **问题**：独立方案给的 CSV 行有 11 列，但未验证现有 `recipes.csv` 的列数。
- **返工**：门禁 `head -1 data/recipes.csv` 确认列名，再写新行。
- **验收**：`recipes.csv` 列数一致，`ConfigDB.get_row("recipes", "tomato_egg")` 返回非空。

### B6. 主方案 §3.4 `world.gd` 新增三个信号，但未定义信号
- **问题**：`emit_signal("farm_workbench_requested")` 需要 `signal farm_workbench_requested` 声明，主方案未给出。
- **返工**：在 `world.gd` 顶部补 `signal farm_workbench_requested` / `farm_sell_requested` / `farm_coop_requested`。
- **验收**：`grep -n "signal farm_" scripts/gameplay/world.gd` 返回 4 个信号（含原有 `farm_requested`）。

### B7. 主方案 §3.3 `farm_plot.gd` 的 `_growth_frame()` 用 `row.get("visual_stage", crop_id)`
- **问题**：`row` 是 `Dictionary`，`get()` 第二参数是默认值，但 `crop_id` 是 `String`，`visual_stage` 列若不存在，返回 `crop_id`，贴图 key 变成 `farm_greens_0`，但实际贴图可能是 `farm_greens_seedling_0`。**贴图 key 未验证存在**。
- **返工**：门禁 `ls assets/farm/` 确认贴图命名规范，`visual_stage` 列必须与贴图 key 一致。
- **验收**：`PresentationManager.get_ui_texture("farm_greens_0")` 返回非空。

---

## C. 存档风险

### C1. 主方案 §6 `to_save_dict` 新增 `dog_helped_today`，但 `from_save_dict` 未处理旧档
- **问题**：旧档无 `dog_helped_today` 字段，`data.get("dog_helped_today", false)` 返回 false，**正确**。但 `plots` 结构若旧档是 `{stage, crop_id, days_grown, watered}`，新代码读 `plot.get("watered", false)` 仍可用，**但 `days_grown` 语义未变**——主方案未改生长模型，所以兼容。
- **返工**：若裁决为独立方案的 `grow_points` 模型，**必须写迁移函数**（独立方案 §7.2 已给，但 `days_grown * 2` 的系数是拍脑袋，需验证：旧档 `days_grown = 3` 的作物，迁移后 `grow_points = 6`，若 `grow_points` 阈值是 4，则**直接成熟**，玩家白赚）。
- **验收**：迁移测试覆盖「旧档 `days_grown = grow_days - 1` 的作物，迁移后未成熟」。

### C2. 独立方案 §7.2 迁移 `tool_levels` → `tools` 的 `durability = 20 + level * 20`
- **问题**：旧档 `tool_levels = {hoe: 1}` → `durability = 40`，但新 `tools.csv` 中 `hoe_wood` 的 `durability = 20`。**迁移后耐久超过上限**。
- **返工**：迁移时 `durability = min(20 + level * 20, tools_csv[tool_id].durability)`。
- **验收**：迁移测试覆盖「旧档 level 3 的工具，迁移后耐久不超上限」。

### C3. 两份方案都未处理「存档中途崩溃」
- **问题**：`SaveManager.request_auto_save("world_action")` 是异步的，若玩家在收获后立即退出，**可能丢失收获物**。
- **返工**：`harvest()` / `upgrade_tool()` / `feed_animal()` 后**同步写存档**，或 `request_auto_save` 改为 `save_now`。
- **验收**：模拟「收获后立即杀进程」，重启后背包有收获物。

### C4. 独立方案 §1.3 删除 `animal_fed` 等字段，但未处理旧档
- **问题**：旧档有 `animal_fed`，新代码不读，**数据丢失但不报错**。若玩家旧档有动物，迁移后动物消失。
- **返工**：迁移时 `animals` 字段保留，`animal_fed` 转为 `pet.last_fed_day`。
- **验收**：旧档加载后，宠物仍在。

---

## D. 测试漏洞

### D1. 主方案 §7.1 测试用例「雨天加速」未定义「晴天基线」
- **问题**：`advance_day()` 后 `days_grown` 增量 > 晴天，但**晴天增量是多少**？未定义。
- **返工**：测试用例改为「雨天增量 = 晴天增量 * (1 + rain_bonus)」，用 `crops.csv` 的 `rain_bonus` 计算期望值。
- **验收**：测试断言用 `crops.csv` 的值，不硬编码。

### D2. 主方案 §7.1 测试用例「快镰刀额外产量」未覆盖「sickle 未升级」
- **问题**：只测了 `sickle = 2` 时 +1，未测 `sickle = 1` 时不 +1。
- **返工**：补测试用例。
- **验收**：`tool_levels["sickle"] = 1` 时收获数量 = `yield_goods` 的数量。

### D3. 独立方案 §8 验收脚本 `test_farm_growth.gd` 未定义「分钟制 vs 日结算」
- **问题**：若裁决为日结算，`test_farm_growth.gd` 需调用 `advance_day()`，而非 `_on_minute_changed()`。
- **返工**：验收脚本按 A1 裁决写。
- **验收**：脚本可运行，断言通过。

### D4. 两份方案都未测试「非当季作物」
- **问题**：主方案 §7.1 有「种植非当季作物」用例，但独立方案无。
- **返工**：独立方案补测试用例。
- **验收**：夏季 `plant(0, "greens_farm")` 返回 false。

### D5. 两份方案都未测试「天气切换时的生长点结算」
- **问题**：若玩家在雨天浇水，然后天气切晴天，生长点如何结算？
- **返工**：明确「天气系数在浇水时锁定」，或「天气系数在日结算时读取当前天气」。
- **验收**：测试用例覆盖「浇水后天气切换」。

### D6. 主方案 §7.2 集成测试「完整闭环」未写完
- **问题**：主方案 §7.2 只有「1.」就断了。
- **返工**：补完集成测试步骤。
- **验收**：集成测试可运行。

---

## E. 数据层遗漏

### E1. 主方案 §2.1 `crops.csv` 的 `tool_required` 列未在代码中使用
- **问题**：`tool_required: hoe_1` 定义了但 `plant()` 未检查。
- **返工**：`plant()` 中检查 `tool_levels["hoe"] >= tool_required`，或删除该列。
- **验收**：`grep -n "tool_required" autoload/farm_manager.gd` 有使用。

### E2. 主方案 §2.4 `farm_products.csv` 的 `facility` 列未在代码中使用
- **问题**：`mill` / `basket` 定义了但无设施实体。
- **返工**：要么实现设施实体，要么删除该列。
- **验收**：`grep -n "facility" autoload/farm_manager.gd` 有使用。

### E3. 独立方案 §1.1 `crops.csv` 的 `harvest_hint` 列未在代码中使用
- **问题**：`叶子有点蔫就该收了` 定义了但无提示触发。
- **返工**：在 `farm_plot.gd` 的 `refresh_visual()` 中，`stage == ripe` 时显示 `harvest_hint`。
- **验收**：成熟地块点击时显示 `harvest_hint`。

### E4. 两份方案都未定义 `goods.csv` 的 `base_cost` 与 `crops.csv` 的 `sell_price` 关系
- **问题**：若 `goods.csv` 已有 `greens` 的 `base_cost = 2`，`crops.csv` 的 `sell_price = 4`，**冲突**。
- **返工**：明确「农场产出不单独定价，用 `goods.csv` 的 `base_cost`」，或「`crops.csv` 的 `sell_price` 覆盖 `goods.csv`」。
- **验收**：`docs/FARM_FACTS.md` 写明优先级。

### E5. 独立方案 §1.2 `tools.csv` 的 `use_on` 列未在代码中使用
- **问题**：`plot_empty` / `plot_growing` / `plot_ripe` 定义了但 `interact_plot()` 未检查。
- **返工**：`interact_plot()` 中检查当前工具 `use_on` 与地块 `stage` 匹配。
- **验收**：用锄头点成熟地块，提示「锄头不能收菜」。

---

## F. NPC 提示遗漏

### F1. 主方案 §4.1 `huang` 提示「你这青菜新鲜，我出六块一份收」与 §3.5 收购车价冲突
- **问题**：`huang` 出 6 块，收购车出 4 块，餐馆出 6 块。**玩家会困惑**。
- **返工**：`huang` 的提示改为「你这青菜新鲜，我出六块一份收」→ 实际触发**餐馆价**，而非独立价格。
- **验收**：`huang` 提示的「六块」与 `crops.csv` 的 `restaurant_price` 一致。

### F2. 独立方案 §2.3 天气提示 NPC 与 `npcs.csv` 未验证
- **问题**：`qing_jie` / `li_ma` / `song` 是否已在 `npcs.csv`？
- **返工**：门禁 `grep -n "qing_jie\|li_ma\|song" data/npcs.csv`。
- **验收**：所有天气提示 NPC 存在。

### F3. 两份方案都未定义「提示冷却」
- **问题**：玩家反复靠近 NPC，提示会刷屏。
- **返工**：`NpcVoiceSelector` 加 `last_hint_time`，同一 NPC 同一提示 60 秒冷却。
- **验收**：连续点击 NPC，第二次不触发。

### F4. 主方案 §4.2 场景提示「每 5 秒检查一次」性能问题
- **问题**：`_process` 每帧调用，5 秒检查一次需计时器。
- **返工**：用 `Timer` 节点，而非 `_process` 计数。
- **验收**：`farm_plot_layer.gd` 无 `_process` 中的时间累积。

---

## G. 返工优先级

| 优先级 | 条目 | 阻塞 |
|---|---|---|
| P0 | A1, A2, A3, A4 | 是，未裁决不得进入实现 |
| P0 | B1, B2, B6 | 是，代码错误 |
| P1 | C1, C2, C3, C4 | 是，存档风险 |
| P1 | D1-D6 | 是，测试漏洞 |
| P2 | E1-E5 | 否，但影响可玩性 |
| P2 | F1-F4 | 否，但影响体验 |

---

## H. 验收清单（返工后必须通过）

1. `docs/FARM_FACTS.md` 存在，写明：生长信号、粒度、工具模型、售卖路径、宠物模型。
2. `data/crops.csv` / `tools.csv` / `farm_animals.csv` / `farm_products.csv` 存在，列名与代码一致。
3. `autoload/farm_manager.gd` 无 `tool_levels` 字段（若裁决为消耗品）。
4. `scripts/gameplay/world.gd` 有 4 个 `farm_*` 信号。
5. `tests/test_farm_manager.gd` 覆盖 A1-A4 裁决后的行为。
6. `tests/test_save_migration.gd` 覆盖 C1-C4。
7. `grep -rn "tool_required\|facility\|harvest_hint\|use_on" --include=*.gd` 每列都有使用或已删除。
8. 所有 NPC 提示有 60 秒冷却。
9. 无 `farm_sell_panel.gd`（若裁决为独立方案）。
10. 宠物无 `harvest()` 调用（若裁决为独立方案）。

## 综合决策

# 《深城日常》农场/田园与天气工具经济闭环 —— 最终可执行方案

> 综合决策 Agent 输出。骨架取主方案"全链路闭环"，机制取独立方案"实物驱动、复用餐馆、无数值条"，逐条闭环批判 A/B 的 P0 阻塞项。
> **硬约束**：无任务面板、无数值属性条、场景点击经营、NPC/系统/场景提示分离、固定物价、存档兼容、温柔治愈画风。
> **唯一事实源**：`data/crops.csv` / `data/tools.csv` / `data/farm_animals.csv` / `data/farm_products.csv`。代码中禁止出现作物名、价格、生长天数、工具等级字面量。

---

## 0. 前置门禁（阻塞性，未通过不得进入实现）

所有结果写入 `docs/FARM_FACTS.md`，作为后续唯一事实源。**批判 A/B 一致指出：两份原方案都跳过了门禁直接写代码，这是最大风险源。**

### G0.1 日历信号（裁决 A1）
```bash
grep -n "^signal \|^func " autoload/calendar_manager.gd
grep -rn "day_started\|minute_changed\|hour_changed" --include=*.gd autoload/ scripts/
```
**裁决规则**：
- 只有 `day_started` → **生长模型 = 日结算**（主方案），独立方案的"浇水即时反馈"降级为**视觉反馈**（土色变深），不推进生长。
- 两者都有 → **仍选日结算**，理由：与现有 `days_grown` 一致，迁移成本最低，且分钟制会让玩家一天内反复进出农场刷生长。
- 都没有 → 先补 `day_started` 信号，再实现。

**写入 `docs/FARM_FACTS.md`**：`生长推进信号 = day_started，粒度 = 1 游戏日`。

### G0.2 现有 farm_manager 真实接口
```bash
grep -n "^func \|^signal \|^const \|^var " autoload/farm_manager.gd
```
**裁决**：以实测为准。本方案 §3 假设的 `interact_plot / plant / water / harvest / get_available_crops / get_weather_farm_hint` 若不存在，**先补接口再实现交互**。

### G0.3 现有 CSV 读取方式
```bash
grep -n "func get_row\|func get_rows" autoload/config_db.gd
grep -rn "ConfigDB.get_row\|ConfigDB.get_rows" --include=*.gd autoload/ scripts/ | head -20
```
**裁决**：若 `get_row` 按列名取值 → 可安全新增列；若按索引 → 新建 `data/crops_ext.csv` 用 `crop_id` join。**同时确认 `get_rows` 返回的是 id 列表还是 dict**（批判 A E 表指出主方案 §3.5 遍历方式未验证）。

### G0.4 天气系统接口
```bash
grep -n "^func \|^signal \|current_weather_id\|get_season_id" autoload/weather_system.gd autoload/calendar_manager.gd
```
**裁决**：确认 `WeatherSystem.current_weather_id` 取值集合（`rain/heat/humid/overcast/clear`）与 `CalendarManager.get_season_id()` 返回值（`spring/summer/autumn/winter`）。**若季节 id 与 crops.csv 的 `seasons` 列不匹配，先对齐再实现。**
**同时确认 `current_weather_id` 是否可写**（批判 A D2：测试需要 mock 天气）。

### G0.5 农场场景与地块层
```bash
grep -rn "farm_plot_layer\|farm_requested\|FarmPlotLayer" --include=*.gd scripts/ autoload/
ls scripts/gameplay/farm_plot_layer.gd
grep -n "interacted\|interaction_id" scripts/gameplay/interactable.gd
```
**裁决**：确认 `FarmPlotLayer` 已存在且 `world.gd` 已连接 `farm_requested` 信号。**同时确认 `InteractableScript.interacted` 信号与 `interaction_id` 的识别机制**（批判 A B1：主方案三个交互物没有触发入口）。

### G0.6 宠物/动物系统现状（裁决 A4、B3）
```bash
grep -rn "pet_manager\|pet_shop_requested\|ahui" --include=*.gd scripts/ autoload/
grep -n "ahui\|liang\|qu\|cai\|qing_jie\|li_ma\|song" data/npcs.csv
```
**裁决**：`gameplay-001` 已裁决"宠物入口空壳，`ahui` 仅作普通 NPC"。
- **不新建 pet_manager**。
- **动物系统（chicken/cow）若未实现 → 本方案删除 `farm_animals.csv` 与所有动物代码**，宠物参与降级为"阿灰的狗来农场"纯叙事 + 一次性实物奖励。
- **若动物系统已实现 → 保留，但宠物与家畜分离**：`animals` = 家畜（产蛋/奶），`pet` = 阿黄（驱鸟 + 提示）。

### G0.7 存档字段与版本
```bash
grep -n "farm\|plot\|tool_level\|animal\|SAVE_VERSION\|_migrate_v" autoload/save_manager.gd | head -40
```
**裁决**：确认 `farm_manager` 的 `plots / tool_levels / animals` 是否已进存档，以及当前存档版本号与迁移链结构（批判 A A2、F 表）。

### G0.8 经济数据存在性（裁决 C3、C5）
```bash
grep -n "greens\|tomato\|corn\|lemon\|red_bean\|tea\|rice\|flour\|egg\|milk\|pork\|animal_feed" data/goods.csv
grep -n "tomato\|corn\|pork" data/recipes.csv
head -1 data/recipes.csv
```
**裁决**：
- `pork` 不存在 → `corn_soup` 换原料或删除。
- `egg/milk` 的 `base_cost` 未定义 → 先补定价，验证回本周期 ≤ 15 游戏日。
- `recipes.csv` 列结构确认后再写新行。

### G0.9 贴图资源
```bash
ls assets/farm/ 2>/dev/null || echo "NO_FARM_ASSETS"
```
**裁决**：`crops.csv` 的 `visual_stage` 列必须与贴图 key 一致（批判 B B7）。若资源不存在，先用占位色块，但 key 命名规范先定。

---

## 1. 决策摘要（先裁决争议）

| 争议点 | 裁决 | 理由 | 批判来源 |
|---|---|---|---|
| **生长模型** | **按游戏日 + 浇水状态 + 天气修正**，不做实时计时 | 与 `farm_manager` 现有 `days_grown` 一致；避免与游戏日压缩冲突；分钟制会让玩家刷生长 | A1 / A1 |
| **浇水语义** | **每块地每日一次**，雨天自动浇透；重复浇水用**视觉反馈**（土色已深）阻止，不弹提示 | 现有 `plot.watered` 字段已支持；无面板 | B4 |
| **工具模型** | **消耗品 + 磨损**（独立方案），但**保留实物升级路径**（铁匠铺买部件 → 工作台换新工具 + 满耐久） | 拒绝"等级"这种数值属性条变体；每件部件有用途 | A2 / A2 |
| **工具 key** | 统一为**工具类别**（`hoe/watering_can/sickle/basket`），value 为 `{tool_id, durability}` | 修复主方案 `tool_levels.get("sickle")` vs `tool_levels["sickle_2"]` 的必然崩溃 | A3 |
| **天气影响** | **双向**：影响生长速度（只对未浇水地块）+ 影响餐馆菜品售价（`homegrown_bonus`） | 现有 `get_weather_farm_hint` 已体现；玩家算得清 | A1 / A1 |
| **售卖/加工** | **不新增售卖 UI**。产出进 `InventoryManager`，餐馆做菜时消耗；用自种作物做菜，菜品售价 +10% | 拒绝"纯菜单购买"变体；复用餐馆经济 | A3 / A3 |
| **宠物参与** | **阿黄 = 活体提示器 + 驱鸟**，不帮你收获 | 拒绝自动化脚本；宠物行为即提示 | A4 / A4 |
| **提示通道** | **复用 NoticeManager**，source_kind 区分 `npc/scene/system`；同一 NPC 同一提示 **60 秒冷却** | 遵循 npc-002 裁决；防刷屏 | F3 |
| **数值属性条** | **禁止**。作物状态用**视觉 + 场景提示**表达 | 硬约束 | — |
| **存档兼容** | **新增字段全部可选**，旧档加载时补默认值；迁移函数**幂等** | save-001 迁移链 | A2 / C1-C4 |

---

## 2. 数据层（唯一事实源）

### 2.1 `data/crops.csv`（新建或补全）

| 字段 | 类型 | 说明 | 示例 |
|---|---|---|---|
| `crop_id` | string | 唯一 id | `greens` |
| `name` | string | 显示名 | `青菜` |
| `seasons` | string | `\|` 分隔 | `spring\|autumn` |
| `seed_cost` | int | 种子价（固定） | `3` |
| `grow_days` | float | 基础生长天数 | `3.0` |
| `water_bonus` | float | 浇水加速系数 | `0.3` |
| `rain_bonus` | float | 雨天额外加速 | `0.2` |
| `heat_penalty` | float | 酷暑未浇水减速 | `0.4` |
| `yield_goods` | string | 收获物 `goods_id:数量` | `greens:2` |
| `tool_required` | string | 需要的工具类别 | `hoe` |
| `visual_stage` | string | 视觉阶段贴图 key 前缀 | `greens` |
| `harvest_hint` | string | 成熟时的场景提示 | `叶子有点蔫就该收了` |

> **删除** `sell_price` / `restaurant_price` 列（裁决：不新增售卖 UI，产出价值由餐馆菜谱决定）。**批判 E4 的冲突由此消解**：goods 定价唯一来源是 `goods.csv` 的 `base_cost`。

**首批作物（8 种，覆盖四季）**：

| crop_id | name | seasons | grow_days | yield_goods | tool_required | visual_stage |
|---|---|---|---|---|---|---|
| `greens` | 青菜 | spring\|autumn | 3.0 | greens:2 | hoe | greens |
| `tomato` | 番茄 | summer | 4.0 | tomato:2 | hoe | tomato |
| `corn` | 玉米 | summer\|autumn | 5.0 | corn:2 | hoe | corn |
| `lemon` | 柠檬 | summer | 4.0 | lemon:2 | hoe | lemon |
| `red_bean` | 红豆 | autumn | 5.0 | red_bean:2 | hoe | red_bean |
| `tea` | 茶 | spring\|summer | 4.0 | tea:2 | hoe | tea |
| `rice` | 稻 | summer\|autumn | 6.0 | rice:3 | hoe | rice |
| `flour_wheat` | 麦 | spring | 5.0 | flour:2 | hoe | flour_wheat |

> **注意**：`yield_goods` 的 goods_id 必须存在于 `data/goods.csv`（门禁 G0.8 验证）。`tool_required` 列**必须在 `plant()` 中实际使用**（批判 E1），否则删除。

### 2.2 `data/tools.csv`（新建，消耗品模型）

| 字段 | 类型 | 说明 |
|---|---|---|
| `tool_id` | string | `hoe_wood` / `hoe_iron` / `can_wood` / `can_iron` / `sickle_wood` / `sickle_iron` / `basket` |
| `category` | string | `hoe` / `watering_can` / `sickle` / `basket`（**统一 key**，裁决 A3） |
| `name` | string | 显示名 |
| `durability` | int | 耐久（`basket` 为 9999） |
| `cost` | int | 换新花费（固定） |
| `upgrade_material` | string | 需要的实物 `item_id:数量`（空为直接买） |
| `use_on` | string | `plot_empty` / `plot_growing` / `plot_ripe` |
| `wear_per_use` | int | 每次使用磨损 |
| `broken_hint` | string | 损坏时的提示 |
| `npc_hint` | string | 哪位 NPC 提示换新 |

**工具链**：

| tool_id | category | name | durability | cost | upgrade_material | use_on |
|---|---|---|---|---|---|---|
| `hoe_wood` | hoe | 木锄 | 20 | 0 | — | plot_empty |
| `hoe_iron` | hoe | 铁锄 | 60 | 80 | `iron_scrap:2` | plot_empty |
| `can_wood` | watering_can | 木水壶 | 30 | 0 | — | plot_growing |
| `can_iron` | watering_can | 铁水壶 | 90 | 120 | `copper_pipe:1` | plot_growing |
| `sickle_wood` | sickle | 旧镰刀 | 20 | 0 | — | plot_ripe |
| `sickle_iron` | sickle | 快镰刀 | 60 | 150 | `whetstone:1` | plot_ripe |
| `basket` | basket | 竹篮 | 9999 | 40 | — | plot_ripe |

> **`basket` 是收获必需**（独立方案 §1.2）。没有篮子不能收获——这是"每件实物都有用途"的硬保证。**批判 A A3 指出独立方案 §4.1 的 `harvest` 没校验 basket，本方案在 §3.1 补上。**

**实物来源**（每件都有用途）：
- `iron_scrap`（废铁）：`liang` 修车摊旁捡 / 旧货摊 `chen` 买
- `copper_pipe`（铜管）：`liang` 处买（他修水管剩的）
- `whetstone`（磨刀石）：`chen` 旧货摊买
- `rattan`（藤条）：河边 `qu` 处买（夏季限时）/ 秋季河边捡

### 2.3 `data/farm_animals.csv`（**仅当 G0.6 确认动物系统已实现时创建**）

| animal_id | name | buy_cost | feed_item | product_goods | product_days |
|---|---|---|---|---|---|
| `chicken` | 母鸡 | 200 | animal_feed | egg | 1.0 |
| `cow` | 奶牛 | 600 | animal_feed | milk | 2.0 |

> **门禁 G0.8 必须先确认 `egg`/`milk` 的 `base_cost`**（批判 C5）。若 `egg` 卖 5 元，40 天回本；若卖 2 元，100 天回本。**回本周期 > 15 游戏日则动物系统是负收益，直接删除**。

### 2.4 `data/farm_products.csv`（**删除**）

> **裁决**：加工 = 餐馆菜谱本身（独立方案 §4.2）。不新建 `farm_products.csv`，不新建加工设施。**批判 E2 的 `facility` 列死代码由此消解。**

### 2.5 `data/recipes.csv` 补丁

**新增 2 道菜谱**（仅当门禁 G0.8 确认 `pork` 存在，否则 `corn_soup` 换原料）：

```csv
tomato_egg,番茄炒蛋,tomato:2|egg:2,1,1,3.0,22,主食,lunch|dinner,prep:1.5|fry:2.8|serve:0.5
corn_soup,玉米排骨汤,corn:2|pork:1,1,1,4.0,28,汤品,lunch|dinner,prep:1.2|boil:3.5|serve:0.5
```

**新增列 `homegrown_bonus`**（裁决 A3：自种作物做菜，菜品售价 +10%）：

```csv
recipe_id,name,ingredients,...
tomato_egg,番茄炒蛋,tomato:2|egg:2,...,homegrown_bonus:0.1
```

> **列结构以门禁 G0.8 的 `head -1 data/recipes.csv` 实测为准**（批判 B B5）。

---

## 3. 代码层

### 3.1 `autoload/farm_manager.gd` 重构

**状态结构**（裁决 A2、A3）：

```gdscript
var has_farm := false
var plots: Array = []  # 每项: {stage, crop_id, days_grown, watered}
var tools: Dictionary = {}  # category -> {tool_id, durability}
var selected_crop_id := ""
var selected_tool_category := "hoe"  # 当前装备的工具类别
var animals: Dictionary = {}  # 家畜（仅当 G0.6 确认已实现）
var animal_fed: Dictionary = {}
var animal_progress: Dictionary = {}
var animal_product_ready: Dictionary = {}
var pet: Dictionary = {}  # {pet_id, last_fed_day, bird_scared_today}
var dog_helped_today := false  # 归属 FarmManager（裁决 B5）
```

**删除**：`tool_levels`（改为 `tools`）。

**核心函数**：

```gdscript
# 天气修正：返回生长速度倍率
func get_weather_growth_multiplier(plot: Dictionary) -> float:
    var crop_id := str(plot.get("crop_id", ""))
    var row := get_crop_row(crop_id)
    if row.is_empty():
        return 1.0
    var watered := bool(plot.get("watered", false))
    var mult := 1.0
    match WeatherSystem.current_weather_id:
        "rain":
            mult += float(row.get("rain_bonus", "0.2"))
        "heat":
            if not watered:
                mult -= float(row.get("heat_penalty", "0.4"))
        "humid":
            mult += 0.1
    if watered:
        mult += float(row.get("water_bonus", "0.3"))
    return max(0.2, mult)

# 每日推进：由 CalendarManager 的 day_started 信号调用
func advance_day() -> void:
    for i in range(plots.size()):
        var plot: Dictionary = plots[i]
        if str(plot.get("stage", STAGE_EMPTY)) != STAGE_GROWING:
            continue
        var mult := get_weather_growth_multiplier(plot)
        plot["days_grown"] = float(plot.get("days_grown", 0.0)) + mult
        var row := get_crop_row(str(plot.get("crop_id", "")))
        if float(plot["days_grown"]) >= float(row.get("grow_days", "3.0")):
            plot["stage"] = STAGE_RIPE
        plot["watered"] = false  # 新的一天，浇水状态重置
    # 动物产出（仅当 animals 非空）
    for animal_id in animals.keys():
        if not bool(animal_fed.get(animal_id, false)):
            continue
        animal_progress[animal_id] = float(animal_progress.get(animal_id, 0.0)) + 1.0
        var arow := ConfigDB.get_row("farm_animals", str(animal_id))
        if float(animal_progress[animal_id]) >= float(arow.get("product_days", "1.0")):
            animal_product_ready[animal_id] = true
        animal_fed[animal_id] = false
    # 宠物驱鸟标记重置
    pet["bird_scared_today"] = false
    dog_helped_today = false
    changed.emit()

# 耕地：校验工具类别 + 耐久
func till(plot_index: int) -> bool:
    if not _valid_plot(plot_index):
        return false
    var plot: Dictionary = plots[plot_index]
    if str(plot.get("stage", STAGE_EMPTY)) != STAGE_EMPTY:
        return false
    var tool := _get_equipped_tool("hoe")
    if tool.is_empty():
        NoticeManager.show_message("需要一把锄头。", "warning", "农场")
        return false
    if int(tool.get("durability", 0)) <= 0:
        NoticeManager.show_message("锄头松了，该换把新的。", "warning", "农场")
        return false
    _wear_tool("hoe")
    plot["stage"] = STAGE_TILLED
    changed.emit()
    return true

# 播种：校验季节 + 工具
func plant(plot_index: int, crop_id: String) -> bool:
    if not _valid_plot(plot_index):
        return false
    var plot: Dictionary = plots[plot_index]
    if str(plot.get("stage", "")) != STAGE_TILLED:
        return false
    var row := get_crop_row(crop_id)
    if row.is_empty():
        return false
    # 季节校验
    var seasons := str(row.get("seasons", "")).split("|", false)
    if not seasons.has(CalendarManager.get_season_id()):
        NoticeManager.show_message("这个季节种不了%s。" % row.get("name", crop_id), "warning", "农场")
        return false
    # 工具校验（批判 E1：tool_required 必须使用）
    var required := str(row.get("tool_required", ""))
    if not required.is_empty() and _get_equipped_tool(required).is_empty():
        NoticeManager.show_message("需要%s。" % required, "warning", "农场")
        return false
    if InventoryManager.get_count(crop_id + "_seed") < 1:
        NoticeManager.show_message("没有%s种子。" % row.get("name", crop_id), "warning", "农场")
        return false
    InventoryManager.remove_item(crop_id + "_seed", 1)
    plot["stage"] = STAGE_GROWING
    plot["crop_id"] = crop_id
    plot["days_grown"] = 0.0
    plot["watered"] = false
    changed.emit()
    return true

# 浇水：每块地每日一次
func water(plot_index: int) -> bool:
    if not _valid_plot(plot_index):
        return false
    var plot: Dictionary = plots[plot_index]
    if str(plot.get("stage", "")) != STAGE_GROWING:
        return false
    if bool(plot.get("watered", false)):
        return false  # 已浇过，视觉上土色已深
    var tool := _get_equipped_tool("watering_can")
    if tool.is_empty():
        NoticeManager.show_message("需要水壶。", "warning", "农场")
        return false
    if int(tool.get("durability", 0)) <= 0:
        NoticeManager.show_message("水壶漏水了。", "warning", "农场")
        return false
    _wear_tool("watering_can")
    plot["watered"] = true
    changed.emit()
    return true

# 收获：校验 basket（批判 A A3）
func harvest(plot_index: int) -> Dictionary:
    if not _valid_plot(plot_index):
        return {}
    var plot: Dictionary = plots[plot_index]
    if str(plot.get("stage", STAGE_EMPTY)) != STAGE_RIPE:
        return {}
    var basket := _get_equipped_tool("basket")
    if basket.is_empty():
        NoticeManager.show_message("没有篮子装不下。", "warning", "农场")
        return {}
    var row := get_crop_row(str(plot.get("crop_id", "")))
    var yield_str := str(row.get("yield_goods", ""))
    var parts := yield_str.split(":", false)
    if parts.size() != 2:
        return {}
    var goods_id := parts[0]
    var count := int(parts[1])
    # 快镰刀额外产量
    var sickle := _get_equipped_tool("sickle")
    if not sickle.is_empty() and str(sickle.get("tool_id", "")) == "sickle_iron":
        count += 1
    InventoryManager.add_item(goods_id, count)
    plot["stage"] = STAGE_EMPTY
    plot["crop_id"] = ""
    plot["days_grown"] = 0.0
    plot["watered"] = false
    NoticeManager.show_message("收下了 %d 份%s。" % [count, row.get("name", goods_id)], "hint", "农场")
    SaveManager.save_now("farm_harvest")  # 批判 C3：同步写存档
    changed.emit()
    return {"goods_id": goods_id, "count": count}

# 工具换新（消耗品模型 + 实物升级路径）
func replace_tool(new_tool_id: String) -> bool:
    var row := ConfigDB.get_row("tools", new_tool_id)
    if row.is_empty():
        return false
    var cost := int(row.get("cost", "0"))
    var material := str(row.get("upgrade_material", ""))
    if GameState.money < cost:
        NoticeManager.show_message("钱不够，再攒攒。", "warning", "农场")
        return false
    if not material.is_empty():
        var parts := material.split(":", false)
        if parts.size() == 2 and InventoryManager.get_count(parts[0]) < int(parts[1]):
            NoticeManager.show_message("还缺%s。" % parts[0], "warning", "农场")
            return false
    GameState.spend_money(cost)
    if not material.is_empty():
        var parts := material.split(":", false)
        InventoryManager.remove_item(parts[0], int(parts[1]))
    var category := str(row.get("category", ""))
    tools[category] = {"tool_id": new_tool_id, "durability": int(row.get("durability", "20"))}
    NoticeManager.show_message("工具换好了。", "hint", "农场")
    SaveManager.save_now("farm_tool")  # 批判 C3
    changed.emit()
    return true

# 内部：获取当前装备的工具
func _get_equipped_tool(category: String) -> Dictionary:
    return tools.get(category, {})

# 内部：磨损工具
func _wear_tool(category: String) -> void:
    var tool: Dictionary = tools.get(category, {})
    if tool.is_empty():
        return
    var row := ConfigDB.get_row("tools", str(tool.get("tool_id", "")))
    var wear := int(row.get("wear_per_use", "1"))
    tool["durability"] = max(0, int(tool.get("durability", 0)) - wear)
    tools[category] = tool
```

**连接信号**（`_ready` 中）：

```gdscript
CalendarManager.day_started.connect(_on_day_started)

func _on_day_started(_day: int) -> void:
    if has_farm:
        advance_day()
```

### 3.2 `scripts/gameplay/farm_plot_layer.gd` 补全

**职责**：渲染 6 块地，处理点击，**不显示任何数值条**。

```gdscript
extends Node2D

const FarmPlotScript := preload("res://scripts/gameplay/farm_plot.gd")

var _plots: Array[Node2D] = []
var _dog_spawned := false  # 批判 B4：只 spawn 一次
var _hint_timer: Timer

func _ready() -> void:
    FarmManager.changed.connect(_refresh)
    _build()
    _spawn_dog()
    _hint_timer = Timer.new()
    _hint_timer.wait_time = 5.0
    _hint_timer.timeout.connect(_check_scene_hint)
    _hint_timer.start()
    add_child(_hint_timer)

func _build() -> void:
    for i in range(FarmManager.PLOT_COUNT):
        var plot := FarmPlotScript.new()
        plot.plot_index = i
        plot.position = Vector2(120 + (i % 3) * 96, 200 + (i / 3) * 96)
        add_child(plot)
        _plots.append(plot)

func _refresh() -> void:
    for plot in _plots:
        plot.refresh_visual()

func _check_scene_hint() -> void:
    # 场景提示：有可收获地块时提示一次（60 秒冷却由 NoticeManager 内部处理）
    for i in range(FarmManager.plots.size()):
        if str(FarmManager.plots[i].get("stage", "")) == FarmManager.STAGE_RIPE:
            NoticeManager.show_message("有块地可以收了。", "hint", "农场", 60.0)
            return

func _spawn_dog() -> void:
    if _dog_spawned:
        return
    if not FarmManager.has_farm:
        return
    if FarmManager.pet.is_empty():
        return
    _dog_spawned = true
    var dog := InteractableScript.new()
    dog.interaction_id = "farm_dog"
    dog.position = Vector2(500, 400)
    dog.interacted.connect(_on_dog_interact)
    add_child(dog)

func _on_dog_interact() -> void:
    # 宠物 = 活体提示器 + 驱鸟（裁决 A4）
    if FarmManager.pet.is_empty():
        return
    if not bool(FarmManager.pet.get("bird_scared_today", false)):
        FarmManager.pet["bird_scared_today"] = true
        NoticeManager.show_message("阿黄在田边转了一圈，鸟不敢下来了。", "hint", "阿黄")
    else:
        NoticeManager.show_message("阿黄趴着晒太阳。", "hint", "阿黄")
```

### 3.3 `scripts/gameplay/farm_plot.gd`（新建）

**视觉表达作物状态**（替代数值条）：

- `empty`：深褐色土块
- `tilled`：翻过的土（浅褐色，有纹理）
- `growing`：土块 + 小苗贴图（按 `days_grown / grow_days` 切 3 帧）
- `ripe`：土块 + 成熟作物贴图 + **轻微上下浮动**（视觉提示可收获）
- `watered`：土块颜色偏深 + 水光高光

```gdscript
extends Node2D

var plot_index: int = 0
var _sprite: Sprite2D

func _ready() -> void:
    _sprite = Sprite2D.new()
    add_child(_sprite)
    refresh_visual()

func refresh_visual() -> void:
    var plot: Dictionary = FarmManager.plots[plot_index]
    var stage := str(plot.get("stage", FarmManager.STAGE_EMPTY))
    var crop_id := str(plot.get("crop_id", ""))
    var watered := bool(plot.get("watered", false))
    var tex_key := "farm_plot_empty"
    match stage:
        FarmManager.STAGE_TILLED:
            tex_key = "farm_plot_tilled"
        FarmManager.STAGE_GROWING:
            var row := FarmManager.get_crop_row(crop_id)
            var frame := _growth_frame(plot, row)
            tex_key = "farm_%s_%d" % [row.get("visual_stage", crop_id), frame]
        FarmManager.STAGE_RIPE:
            var row := FarmManager.get_crop_row(crop_id)
            tex_key = "farm_%s_ripe" % row.get("visual_stage", crop_id)
    _sprite.texture = PresentationManager.get_ui_texture(tex_key)
    _sprite.modulate = Color(0.85, 0.85, 0.85) if watered else Color.WHITE

func _growth_frame(plot: Dictionary, row: Dictionary) -> int:
    var total := float(row.get("grow_days", "3.0"))
    var grown := float(plot.get("days_grown", 0.0))
    var ratio := grown / max(total, 0.1)
    if ratio < 0.34:
        return 0
    elif ratio < 0.67:
        return 1
    return 2

func interact() -> void:
    # 按当前装备的工具类别决定动作
    var category := FarmManager.selected_tool_category
    match category:
        "hoe":
            FarmManager.till(plot_index)
        "watering_can":
            FarmManager.water(plot_index)
        "sickle", "basket":
            FarmManager.harvest(plot_index)
```

### 3.4 `scripts/gameplay/tool_rack.gd`（新建，批判 B2）

**工具栏实体**：点击切换当前工具类别。

```gdscript
extends Node2D

@export var category: String = "hoe"

func interact() -> void:
    FarmManager.selected_tool_category = category
    var tool: Dictionary = FarmManager.tools.get(category, {})
    var tool_name := "空手"
    if not tool.is_empty():
        var row := ConfigDB.get_row("tools", str(tool.get("tool_id", "")))
        tool_name = str(row.get("name", tool.get("tool_id", "")))
    NoticeManager.show_message("拿起了%s。" % tool_name, "hint", "农场")
    # 视觉反馈：当前工具高亮
    modulate = Color(1.2, 1.2, 1.2)
```

### 3.5 `scripts/gameplay/world.gd` 补全

**在 `_build_area` 中，当 `area_id == "farm"` 时挂载 `FarmPlotLayer` + 工具栏 + 动物栏**：

```gdscript
# 信号声明（批判 B6）
signal farm_requested(plot_index: int)  # 保留，兼容旧调用
signal farm_workbench_requested
signal farm_coop_requested

if area_id == "farm":
    var farm_layer := FarmPlotLayerScript.new()
    farm_layer.name = "FarmPlotLayer"
    _area_root.add_child(farm_layer)

    # 工具栏：锄头架 / 水壶架 / 镰刀架 / 篮子架
    for cat in ["hoe", "watering_can", "sickle", "basket"]:
        var rack := ToolRackScript.new()
        rack.category = cat
        rack.position = Vector2(100 + ["hoe", "watering_can", "sickle", "basket"].find(cat) * 64, 100)
        _area_root.add_child(rack)

    # 工作台：工具换新
    var workbench := InteractableScript.new()
    workbench.interaction_id = "farm_workbench"
    workbench.position = Vector2(400, 300)
    workbench.interacted.connect(_on_farm_workbench)
    _area_root
