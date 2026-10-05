# 服装购买、穿搭与衣柜系统

## 主方案

# 《深日记》服装购买 / 试衣 / 穿搭 / 衣柜系统 —— 唯一可执行方案

> 综合裁决：以「场景实物 + NPC 驱动」为唯一购买路径，**禁止任何菜单直购**。复用现有 `WardrobeManager`（`relationship_manager.gd` 已引用 `WardrobeManager.owned`，说明该类已存在或必须补齐）、`InventoryManager`、`RelationshipManager`、`NoticeManager`、`TimeSystem`、`CalendarManager`、`EconomyManager`（若存在）。
> 本方案不新增 NPC，服装店老板固定为 `azhen`（阿珍，`home_area=store`，`preferred_item=milk_tea`）。
> 所有坐标/尺寸/色值以 `docs/ART_FACTS.md`、`docs/UI_FACTS.md` 为唯一事实源；本方案中的数值为**默认值**，门禁实测后按实测值覆盖。

---

## 0. 前置门禁（阻塞性，未通过不得写代码）

结果写入 `docs/WARDROBE_FACTS.md`，作为本系统唯一事实源。

### G0.1 现有 WardrobeManager 真实接口
```bash
grep -rn "WardrobeManager\|wardrobe" --include=*.gd scripts/ autoload/ | head -60
ls autoload/ | grep -i wardrobe
```
**裁决**：
- 若 `autoload/wardrobe_manager.gd` 存在 → 记录其全部 `func` 签名、`var` 字段、`signal`，本方案**只做增量扩展，不重写**。
- 若不存在 → 本方案 §2 提供完整实现，并需在 `project.godot` 注册 autoload。
- 记录 `WardrobeManager.owned` 的真实类型（`Array` / `Dictionary` / `Array[String]`），决定 §2.2 字段设计。

### G0.2 服装店场景与交互物现状
```bash
grep -rn "clothing\|azhen\|服装" --include=*.gd --include=*.csv --include=*.tscn . | head -40
ls data/ | grep -i "shop\|scene"
```
**裁决**：
- 记录服装店场景 key（预期 `store` 或 `commercial_district` 内的子场景）。若不存在独立服装店场景 → **本方案第一步是新增 `clothing_shop` 场景**，坐标避让 `world-002` 的 `scene_zones.csv` 已占用矩形。
- 记录 `azhen` 当前是否已在场景中实例化（`npcs.csv` 有记录 ≠ 场景有实体）。

### G0.3 玩家外观渲染管线
```bash
grep -rn "player_skin\|outfit\|sprite_frames\|AnimatedSprite2D\|Sprite2D" --include=*.gd scripts/gameplay/player.gd
```
**裁决**：
- 若玩家用 `Sprite2D` 单图 → 换装 = 换 `texture`，本方案 §4 按此实现。
- 若用 `AnimatedSprite2D` + `SpriteFrames` → 换装 = 换 `SpriteFrames` 资源，需为每套服装准备完整动画帧，**成本高**，本方案降级为「仅换 `Sprite2D` 叠加层（外套/帽子/配饰）」。
- 结果决定 §4.3 的渲染策略，**不得假设**。

### G0.4 季节系统接口
```bash
grep -rn "season\|Season\|get_season" --include=*.gd autoload/ scripts/ | head -30
```
**裁决**：记录季节枚举值（`spring/summer/autumn/winter` 或 `0/1/2/3`）与获取函数名。若不存在季节系统 → **季节性效果降级为「按 `CalendarManager` 月份推断」**，并在 §5 标注。

### G0.5 经济系统接口
```bash
grep -rn "func.*money\|func.*spend\|func.*earn\|EconomyManager\|GameState.money" --include=*.gd autoload/ | head -30
```
**裁决**：记录扣钱/加钱的**唯一函数名**。本方案所有交易必须走该函数，禁止直接改 `money` 字段。

### G0.6 节日系统接口
```bash
grep -rn "festival\|Festival\|节日" --include=*.gd --include=*.csv . | head -30
```
**裁决**：记录节日判定函数与节日 ID 列表（`lan` 相关）。本方案 §6 节日联动依赖此。

---

## 1. 设计总纲（三条铁律）

1. **购买必须经过「实物 + NPC」**：玩家走到衣架/货架前 → 点击实物 → 阿珍走过来 → 对话确认 → 扣钱 → 实物从货架消失 → 进入「待试衣」状态。**任何情况下不出现「点击商品图标 → 直接扣钱」的路径。**
2. **试衣是独立动作**：购买后不直接入库，必须先到试衣间（`fitting_room` 交互物）试穿，试穿时阿珍给评价，玩家确认后才进衣柜。**可反悔**（试穿后选择不买 → 退款 90%，扣 10% 作为「试衣费」，且阿珍好感 -1）。
3. **穿搭影响世界**：衣柜里选定的「当前穿搭」实时反映在玩家 Sprite 上，并影响 NPC 对话、季节体感、节日活动准入。

---

## 2. 数据层（新建/扩展）

### 2.1 新建 `data/clothing.csv`

| 字段 | 类型 | 说明 | 示例 |
|---|---|---|---|
| `clothing_id` | string | 唯一 ID，前缀 `cl_` | `cl_linen_shirt` |
| `name` | string | 显示名 | `亚麻短袖` |
| `description` | string | 描述 | `透气，夏天穿不闷。` |
| `slot` | enum | `top` / `bottom` / `shoes` / `outer` / `hat` / `accessory` | `top` |
| `price` | int | 固定售价（元） | `68` |
| `season` | enum | `spring` / `summer` / `autumn` / `winter` / `all` | `summer` |
| `warmth` | int | 保暖值，-2 ~ +4 | `-1` |
| `formality` | int | 正式度，0 ~ 3 | `1` |
| `style_tag` | string | 风格标签，逗号分隔 | `casual,clean` |
| `unlock_condition` | string | 解锁条件表达式 | `always` / `affinity:azhen>=6` / `festival:spring_festival` / `season:summer` / `career:factory>=2` |
| `stock` | int | 初始库存，-1 为无限 | `3` |
| `restock_days` | int | 补货周期（天），-1 不补 | `7` |
| `npc_reaction_tag` | string | NPC 反应标签 | `fresh` / `warm` / `formal` / `festive` |
| `sprite_layer` | string | 对应玩家渲染层名 | `top` |
| `texture_path` | string | 贴图路径 | `res://assets/art/formal/clothing/cl_linen_shirt.png` |

**首批 12 件**（覆盖四季 + 节日 + 职业）：

| clothing_id | name | slot | price | season | warmth | formality | unlock_condition | stock |
|---|---|---|---|---|---|---|---|---|
| `cl_linen_shirt` | 亚麻短袖 | top | 68 | summer | -1 | 1 | `always` | 3 |
| `cl_cotton_tee` | 纯棉T恤 | top | 35 | all | 0 | 0 | `always` | -1 |
| `cl_work_jacket` | 工装外套 | outer | 120 | autumn | 2 | 1 | `career:factory>=1` | 2 |
| `cl_winter_coat` | 呢子大衣 | outer | 280 | winter | 4 | 2 | `season:winter` | 2 |
| `cl_jeans` | 直筒牛仔裤 | bottom | 88 | all | 1 | 1 | `always` | -1 |
| `cl_shorts` | 棉麻短裤 | bottom | 45 | summer | -1 | 0 | `always` | 4 |
| `cl_canvas_shoes` | 帆布鞋 | shoes | 75 | all | 0 | 1 | `always` | -1 |
| `cl_leather_shoes` | 皮鞋 | shoes | 160 | all | 1 | 3 | `affinity:azhen>=8` | 2 |
| `cl_straw_hat` | 草帽 | hat | 28 | summer | -1 | 0 | `season:summer` | 5 |
| `cl_wool_scarf` | 羊毛围巾 | accessory | 55 | winter | 2 | 1 | `season:winter` | 3 |
| `cl_festival_vest` | 节日马甲 | outer | 150 | all | 1 | 2 | `festival:spring_festival` | 1 |
| `cl_azhen_gift` | 阿珍手作围裙 | top | 0 | all | 0 | 1 | `affinity:azhen>=12` | 1 |

> `cl_azhen_gift` 不可购买，仅通过阿珍好感 12 赠送获得（见 §7.3）。

### 2.2 扩展 `WardrobeManager`（`autoload/wardrobe_manager.gd`）

```gdscript
extends Node

signal wardrobe_changed
signal outfit_changed(slot: String, clothing_id: String)
signal clothing_acquired(clothing_id: String)

const SLOTS := ["top", "bottom", "shoes", "outer", "hat", "accessory"]

var catalog: Dictionary = {}          # clothing_id -> 静态数据（来自 clothing.csv）
var owned: Dictionary = {}            # clothing_id -> { acquired_day: int, worn_count: int, condition: int }
var equipped: Dictionary = {}         # slot -> clothing_id（"" 表示空）
var pending_try_on: String = ""       # 待试衣的 clothing_id（购买后未确认）
var pending_refund_price: int = 0     # 试衣反悔时的退款额
var shop_stock: Dictionary = {}       # clothing_id -> 剩余库存
var shop_last_restock_day: int = -1

func _ready() -> void:
    _load_catalog()
    TimeSystem.day_started.connect(_on_day_started)

func _load_catalog() -> void:
    catalog.clear()
    for cid in ConfigDB.get_rows("clothing"):
        var row: Dictionary = ConfigDB.get_row("clothing", cid)
        catalog[cid] = {
            "id": cid,
            "name": str(row.get("name", cid)),
            "description": str(row.get("description", "")),
            "slot": str(row.get("slot", "top")),
            "price": int(row.get("price", "0")),
            "season": str(row.get("season", "all")),
            "warmth": int(row.get("warmth", "0")),
            "formality": int(row.get("formality", "0")),
            "style_tag": str(row.get("style_tag", "")),
            "unlock_condition": str(row.get("unlock_condition", "always")),
            "stock": int(row.get("stock", "-1")),
            "restock_days": int(row.get("restock_days", "-1")),
            "npc_reaction_tag": str(row.get("npc_reaction_tag", "")),
            "sprite_layer": str(row.get("sprite_layer", "top")),
            "texture_path": str(row.get("texture_path", "")),
        }
    _init_shop_stock()

func _init_shop_stock() -> void:
    shop_stock.clear()
    for cid in catalog:
        shop_stock[cid] = int(catalog[cid]["stock"])

func is_unlocked(clothing_id: String) -> bool:
    var cond := str(catalog.get(clothing_id, {}).get("unlock_condition", "always"))
    return _eval_condition(cond)

func _eval_condition(cond: String) -> bool:
    if cond == "always" or cond.is_empty():
        return true
    if cond.begins_with("affinity:"):
        var parts := cond.substr(9).split(">=")
        if parts.size() != 2: return false
        return RelationshipManager.get_affinity(parts[0]) >= int(parts[1])
    if cond.begins_with("festival:"):
        return FestivalManager.is_active(cond.substr(9))
    if cond.begins_with("season:"):
        return SeasonManager.get_current_season() == cond.substr(7)
    if cond.begins_with("career:"):
        var parts := cond.substr(7).split(">=")
        if parts.size() != 2: return false
        return CareerManager.get_rank(parts[0]) >= int(parts[1])
    push_error("未知解锁条件: %s" % cond)
    return false

func get_stock(clothing_id: String) -> int:
    return int(shop_stock.get(clothing_id, 0))

func can_buy(clothing_id: String) -> Dictionary:
    if not catalog.has(clothing_id):
        return {"ok": false, "reason": "unknown"}
    if not is_unlocked(clothing_id):
        return {"ok": false, "reason": "locked"}
    if get_stock(clothing_id) == 0:
        return {"ok": false, "reason": "out_of_stock"}
    if owned.has(clothing_id):
        return {"ok": false, "reason": "already_owned"}
    var price := int(catalog[clothing_id]["price"])
    if not EconomyManager.can_afford(price):
        return {"ok": false, "reason": "no_money"}
    return {"ok": true, "price": price}

func begin_purchase(clothing_id: String) -> bool:
    var check := can_buy(clothing_id)
    if not check["ok"]:
        return false
    pending_try_on = clothing_id
    pending_refund_price = int(check["price"])
    return true

func confirm_purchase() -> bool:
    if pending_try_on.is_empty():
        return false
    var cid := pending_try_on
    var price := pending_refund_price
    if not EconomyManager.spend(price, "clothing:%s" % cid):
        return false
    if get_stock(cid) > 0:
        shop_stock[cid] = get_stock(cid) - 1
    owned[cid] = {"acquired_day": TimeSystem.current_day, "worn_count": 0, "condition": 100}
    pending_try_on = ""
    pending_refund_price = 0
    clothing_acquired.emit(cid)
    wardrobe_changed.emit()
    return true

func cancel_purchase() -> int:
    if pending_try_on.is_empty():
        return 0
    var refund := int(round(pending_refund_price * 0.9))
    pending_try_on = ""
    pending_refund_price = 0
    return refund

func equip(clothing_id: String) -> bool:
    if not owned.has(clothing_id):
        return false
    var slot := str(catalog[clothing_id]["slot"])
    var prev := str(equipped.get(slot, ""))
    if prev == clothing_id:
        equipped[slot] = ""
        outfit_changed.emit(slot, "")
        wardrobe_changed.emit()
        return true
    equipped[slot] = clothing_id
    owned[clothing_id]["worn_count"] = int(owned[clothing_id]["worn_count"]) + 1
    outfit_changed.emit(slot, clothing_id)
    wardrobe_changed.emit()
    return true

func get_total_warmth() -> int:
    var total := 0
    for slot in equipped:
        var cid := str(equipped[slot])
        if cid != "" and catalog.has(cid):
            total += int(catalog[cid]["warmth"])
    return total

func get_total_formality() -> int:
    var total := 0
    for slot in equipped:
        var cid := str(equipped[slot])
        if cid != "" and catalog.has(cid):
            total += int(catalog[cid]["formality"])
    return total

func get_style_tags() -> Array[String]:
    var tags: Array[String] = []
    for slot in equipped:
        var cid := str(equipped[slot])
        if cid != "" and catalog.has(cid):
            for t in str(catalog[cid]["style_tag"]).split(","):
                var trimmed := t.strip_edges()
                if trimmed != "" and not tags.has(trimmed):
                    tags.append(trimmed)
    return tags

func _on_day_started(day_number: int) -> void:
    if shop_last_restock_day < 0:
        shop_last_restock_day = day_number
        return
    var elapsed := day_number - shop_last_restock_day
    for cid in catalog:
        var restock := int(catalog[cid]["restock_days"])
        if restock <= 0:
            continue
        if elapsed >= restock:
            var max_stock := int(catalog[cid]["stock"])
            if get_stock(cid) < max_stock:
                shop_stock[cid] = get_stock(cid) + 1
    shop_last_restock_day = day_number
    wardrobe_changed.emit()

func to_save() -> Dictionary:
    return {
        "owned": owned,
        "equipped": equipped,
        "shop_stock": shop_stock,
        "shop_last_restock_day": shop_last_restock_day,
    }

func from_save(data: Dictionary) -> void:
    owned = data.get("owned", {})
    equipped = data.get("equipped", {})
    shop_stock = data.get("shop_stock", {})
    shop_last_restock_day = int(data.get("shop_last_restock_day", -1))
    if shop_stock.is_empty():
        _init_shop_stock()
    wardrobe_changed.emit()
```

**存档兼容**：`save-001` 的迁移链需新增 `v15` 步骤，把旧 `WardrobeManager.owned`（若为 `Array`）转为 `Dictionary` 格式。若 G0.1 显示 `owned` 已是 `Dictionary`，则 `from_save` 直接兼容，无需迁移。

### 2.3 扩展 `data/npcs.csv`

为 `azhen` 补两列（若 `ConfigDB` 用 `DictReader`，可安全新增；若用索引取值，见 G0.3 裁决）：

| 列名 | azhen 值 | 说明 |
|---|---|---|
| `shop_scene` | `clothing_shop` | 阿珍所在场景 |
| `shop_role` | `clothing` | 商店类型标识 |

---

## 3. 场景与交互物（实物驱动购买）

### 3.1 新建场景 `scenes/clothing_shop.tscn`

场景结构（坐标以 `world-002` 的 `scene_zones.csv` 分配为准，此处为示意）：

```
ClothingShop (Node2D)
├── Backdrop (AreaBackdrop, 1280×720)
├── PlayerSpawn (Marker2D, position=(200, 500))
├── Azhen (NpcActor, npc_id="azhen", position=(640, 380))
├── RackTop (ClothingRack, position=(400, 300), rack_slot="top")
├── RackBottom (ClothingRack, position=(520, 300), rack_slot="bottom")
├── RackOuter (ClothingRack, position=(640, 300), rack_slot="outer")
├── RackShoes (ClothingRack, position=(760, 300), rack_slot="shoes")
├── RackAccessory (ClothingRack, position=(880, 300), rack_slot="accessory")
├── FittingRoom (FittingRoom, position=(1000, 400))
├── Mirror (Interactable, position=(1050, 400), action="preview_outfit")
├── Counter (Interactable, position=(640, 520), action="checkout")
└── Exit (Interactable, position=(100, 600), action="leave")
```

### 3.2 新建 `scripts/gameplay/clothing_rack.gd`

```gdscript
class_name ClothingRack
extends WorldInteractable

@export var rack_slot: String = "top"

var displayed_items: Array[String] = []   # 当前货架上挂着的 clothing_id
var max_display := 4

func _ready() -> void:
    super._ready()
    _refresh_display()
    WardrobeManager.wardrobe_changed.connect(_refresh_display)

func _refresh_display() -> void:
    displayed_items.clear()
    for cid in WardrobeManager.catalog:
        if displayed_items.size() >= max_display:
            break
        var c: Dictionary = WardrobeManager.catalog[cid]
        if str(c["slot"]) != rack_slot:
            continue
        if not WardrobeManager.is_unlocked(cid):
            continue
        if WardrobeManager.get_stock(cid) == 0:
            continue
        displayed_items.append(cid)
    _update_visual()

func _update_visual() -> void:
    # 每个 displayed_item 对应一个子 Sprite2D，位置沿货架横向排列
    # 空货架显示空衣架贴图
    pass

func on_tap() -> void:
    if displayed_items.is_empty():
        NoticeManager.show_scene_message("这个衣架空了，阿珍说下周会补货。", "服装店", "neutral")
        return
    # 弹出「货架选择」——不是菜单，是场景内实物高亮
    var picker := get_tree().get_first_node_in_group("rack_picker")
    if picker == null:
        picker = preload("res://scripts/gameplay/rack_picker.gd").new()
        picker.add_to_group("rack_picker")
        add_child(picker)
    picker.open(self, displayed_items)
```

### 3.3 新建 `scripts/gameplay/rack_picker.gd`

**关键：这不是菜单，是场景内实物放大展示。** 玩家点击货架后，货架上的衣物贴图放大并横向排开，玩家点击**具体衣物贴图**选中，阿珍走过来。

```gdscript
extends Node2D

var _rack: ClothingRack
var _items: Array[String] = []
var _selected: String = ""

func open(rack: ClothingRack, items: Array[String]) -> void:
    _rack = rack
    _items = items
    _selected = ""
    _spawn_item_sprites()
    # 阿珍从柜台走向货架
    var azhen := get_tree().get_first_node_in_group("npc_azhen")
    if azhen != null:
        azhen.walk_to(rack.global_position + Vector2(60, 0))

func _spawn_item_sprites() -> void:
    for child in get_children():
        child.queue_free()
    for i in _items.size():
        var cid := _items[i]
        var spr := Sprite2D.new()
        spr.texture = load(str(WardrobeManager.catalog[cid]["texture_path"]))
        spr.position = _rack.global_position + Vector2(i * 80 - (_items.size() - 1) * 40, -60)
        spr.scale = Vector2(1.5, 1.5)
        spr.set_meta("clothing_id", cid)
        spr.input_pickable = true
        spr.input_event.connect(_on_item_clicked.bind(cid))
        add_child(spr)

func _on_item_clicked(_viewport, event: InputEvent, _shape_idx: int, cid: String) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _selected = cid
        _on_item_selected(cid)

func _on_item_selected(cid: String) -> void:
    var c: Dictionary = WardrobeManager.catalog[cid]
    var check := WardrobeManager.can_buy(cid)
    if not check["ok"]:
        match str(check["reason"]):
            "locked":
                NoticeManager.show_npc_message("这件还没到时候呢，再等等。", "阿珍", "neutral")
            "out_of_stock":
                NoticeManager.show_npc_message("这件卖完了，下周再来看看。", "阿珍", "neutral")
            "already_owned":
                NoticeManager.show_npc_message("你不是有一件了吗？", "阿珍", "neutral")
            "no_money":
                NoticeManager.show_npc_message("钱不够也没关系，先试试看。", "阿珍", "neutral")
        _close()
        return
    # 阿珍报价
    NoticeManager.show_npc_message(
        "%s，%d 块。要试一下吗？" % [c["name"], c["price"]],
        "阿珍", "neutral"
    )
    _show_confirm_buttons(cid)

func _show_confirm_buttons(cid: String) -> void:
    # 场景内两个实物按钮：试衣间门 / 放下
    # 复用 FittingRoom 和 Exit 的高亮，不弹 UI 菜单
    var fitting := get_tree().get_first_node_in_group("fitting_room")
    if fitting != null:
        fitting.highlight_for(cid)
    var exit := get_tree().get_first_node_in_group("shop_exit")
    if exit != null:
        exit.highlight_for_cancel()

func _close() -> void:
    queue_free()
```

### 3.4 新建 `scripts/gameplay/fitting_room.gd`

```gdscript
class_name FittingRoom
extends WorldInteractable

var _pending_cid: String = ""

func highlight_for(cid: String) -> void:
    _pending_cid = cid
    # 试衣间帘子微微晃动，提示可交互
    var anim := get_node_or_null("CurtainAnim")
    if anim != null:
        anim.play("beckon")

func on_tap() -> void:
    if _pending_cid.is_empty():
        NoticeManager.show_scene_message("试衣间空着，可以进去照照镜子。", "服装店", "neutral")
        return
    _enter_try_on(_pending_cid)

func _enter_try_on(cid: String) -> void:
    if not WardrobeManager.begin_purchase(cid):
        return
    # 玩家 Sprite 临时换上该服装
    var player := get_tree().get_first_node_in_group("player")
    if player != null:
        player.preview_outfit(cid)
    # 阿珍走到试衣间外
    var azhen := get_tree().get_first_node_in_group("npc_azhen")
    if azhen != null:
        azhen.walk_to(global_position + Vector2(-80, 0))
        azhen.face_right()
    # 阿珍评价
    var reaction := _azhen_reaction(cid)
    NoticeManager.show_npc_message(reaction, "阿珍", "positive")
    # 玩家在试衣间内可操作：确认 / 反悔
    _show_try_on_actions(cid)

func _azhen_reaction(cid: String) -> String:
    var c: Dictionary = WardrobeManager.catalog[cid]
    var tag := str(c["npc_reaction_tag"])
    var season := SeasonManager.get_current_season()
    var lines := {
        "fresh": "这个颜色衬你，看着精神。",
        "warm": "暖和是暖和，就是有点厚，你确定现在穿？",
        "formal": "穿这个去见人，人家会多看你两眼。",
        "festive": "这件有节日气，过年穿正合适。",
    }
    var base := str(lines.get(tag, "挺合身的，你自己觉得呢？"))
    if str(c["season"]) != "all" and str(c["season"]) != season:
        base += "不过这个季节穿可能不太合适。"
    return base

func _show_try_on_actions(cid: String) -> void:
    # 场景内两个实物：镜子（确认）/ 帘子（反悔）
    var mirror := get_tree().get_first_node_in_group("mirror")
    if mirror != null:
        mirror.arm_confirm(cid)
    var curtain := get_node_or_null("Curtain")
    if curtain != null:
        curtain.arm_cancel(cid)
```

### 3.5 新建 `scripts/gameplay/mirror.gd`

```gdscript
class_name Mirror
extends WorldInteractable

var _armed_cid: String = ""

func arm_confirm(cid: String) -> void:
    _armed_cid = cid

func on_tap() -> void:
    if _armed_cid.is_empty():
        NoticeManager.show_scene_message("镜子里是你现在的样子。", "服装店", "neutral")
        return
    if WardrobeManager.confirm_purchase():
        var c: Dictionary = WardrobeManager.catalog[_armed_cid]
        NoticeManager.show_npc_message("好，这件归你了。", "阿珍", "positive")
        NoticeManager.show_message("获得「%s」，已放进衣柜。" % c["name"], "positive")
        AchievementManager.record_event("first_clothing_purchase")
        _armed_cid = ""
        _clear_rack_state()
    else:
        NoticeManager.show_message("钱不够，先放回去吧。", "warning")

func _clear_rack_state() -> void:
    var picker := get_tree().get_first_node_in_group("rack_picker")
    if picker != null:
        picker.queue_free()
    var player := get_tree().get_first_node_in_group("player")
    if player != null:
        player.clear_preview()
```

### 3.6 反悔路径（帘子）

```gdscript
# 在 fitting_room.gd 的 Curtain 子节点上
func on_tap() -> void:
    var refund := WardrobeManager.cancel_purchase()
    if refund > 0:
        EconomyManager.earn(refund, "clothing_refund")
        NoticeManager.show_npc_message("试了不买也正常，退你 %d 块。" % refund, "阿珍", "neutral")
        RelationshipManager.add_affinity("azhen", -1)
    var player := get_tree().get_first_node_in_group("player")
    if player != null:
        player.clear_preview()
```

---

## 4. 穿搭与渲染

### 4.1 玩家渲染策略（依赖 G0.3 裁决）

**若玩家为 `Sprite2D` 单图**：
- 玩家节点下新增 6 个 `Sprite2D` 子节点，命名 `layer_top` / `layer_bottom` / `layer_shoes` / `layer_outer` / `layer_hat` / `layer_accessory`。
- 每个子节点默认 `texture = null`，`visible = false`。
- `WardrobeManager.outfit_changed` 信号触发时，对应层加载 `texture_path` 并 `visible = true`。
- 层级顺序：`bottom < shoes < top < outer < accessory < hat`（`z_index` 递增）。

**若玩家为 `AnimatedSprite2D`**：
- 降级为「仅 `outer` / `hat` / `accessory` 三层叠加」，`top` / `bottom` / `shoes` 不改变外观，仅改变数值（`warmth` / `formality`）。
- 在 `docs/WARDROBE_FACTS.md` 中明确标注此降级。

### 4.2 新建 `scripts/gameplay/player_outfit_layer.gd`

```gdscript
extends Node2D

const LAYER_ORDER := ["bottom", "shoes", "top", "outer", "accessory", "hat"]

var _layers: Dictionary = {}   # slot -> Sprite2D
var _preview_cid: String = ""

func _ready() -> void:
    for i in LAYER_ORDER.size():
        var slot: String = LAYER_ORDER[i]
        var spr := Sprite2D.new()
        spr.name = "layer_%s" % slot
        spr.visible = false
        spr.z_index = i
        add_child(spr)
        _layers[slot] = spr
    WardrobeManager.outfit_changed.connect(_on_outfit_changed)
    WardrobeManager.wardrobe_changed.connect(_refresh_all)
    _refresh_all()

func _refresh_all() -> void:
    for slot in LAYER_ORDER:
        var cid := str(WardrobeManager.equipped.get(slot, ""))
        _apply(slot, cid)

func _on_outfit_changed(slot: String, clothing_id: String) -> void:
    _apply(slot, clothing_id)

func _apply(slot: String, clothing_id: String) -> void:
    var spr: Sprite2D = _layers[slot]
    if clothing_id.is_empty() or not WardrobeManager.catalog.has(clothing_id):
        spr.visible = false
        spr.texture = null
        return
    var path := str(WardrobeManager.catalog[clothing_id]["texture_path"])
    if not ResourceLoader.exists(path):
        push_warning("服装贴图缺失: %s" % path)
        spr.visible = false
        return
    spr.texture = load(path)
    spr.visible = true

func preview_outfit(cid: String) -> void:
    _preview_cid = cid
    var slot := str(WardrobeManager.catalog[cid]["slot"])
    _apply(slot, cid)

func clear_preview() -> void:
    if _preview_cid.is_empty():
        return
    var slot := str(WardrobeManager.catalog[_preview_cid]["slot"])
    var real := str(WardrobeManager.equipped.get(slot, ""))
    _apply(slot, real)
    _preview_cid = ""
```

### 4.3 衣柜界面（`wardrobe_requested` 信号已存在）

`world.gd` 已有 `signal wardrobe_requested`，说明衣柜 UI 入口已规划。本方案**不新建菜单**，而是：

- 玩家在出租屋/家中点击「衣柜」实物 → 触发 `wardrobe_requested`。
- 衣柜 UI 为**场景内实物展示**：衣柜门打开，里面挂着已拥有的衣物贴图，玩家点击贴图即穿上/脱下。
- 不使用列表菜单，使用**衣架网格**（4×N），每个衣架是一个可点击的 `TextureButton`，贴图为衣物缩略图。

新建 `scripts/ui/wardrobe_panel.gd`：

```gdscript
extends Control

@onready var grid: GridContainer = $ScrollContainer/GridContainer

func _ready() -> void:
    WardrobeManager.wardrobe_changed.connect(_refresh)
    _refresh()

func _refresh() -> void:
    for child in grid.get_children():
        child.queue_free()
    for cid in WardrobeManager.owned:
        var c: Dictionary = WardrobeManager.catalog.get(cid, {})
        if c.is_empty():
            continue
        var btn := TextureButton.new()
        btn.texture_normal = load(str(c["texture_path"]))
        btn.custom_minimum_size = Vector2(64, 64)
        btn.tooltip_text = "%s（%s）" % [c["name"], _slot_label(str(c["slot"]))]
        if str(WardrobeManager.equipped.get(str(c["slot"]

## 独立方案

# 独立方案：服装购买 / 试衣 / 穿搭 / 衣柜系统

> 独立 Agent 输出。**不迎合主方案**。核心分歧：主方案倾向"服装店 = 一个商店 UI + 一个衣柜 UI"，本方案主张 **服装是"穿在身上的世界状态"，不是背包里的道具**。购买、试衣、穿搭、存储全部发生在场景实体上，UI 只做只读回显。
>
> 前置事实（已从上下文确认）：
> - `WardrobeManager.owned` 已存在（`relationship_manager.gd` 的 `lin` 分支引用了它）
> - `world.gd` 已有 `wardrobe_requested` 信号
> - `azhen`（阿珍，服装店老板，`home_area=store`，`preferred_item=milk_tea`，生日 210）已存在
> - `InventoryManager` 是格位制（hotbar 12 + backpack 0/12/24），**不适合直接塞服装**
> - `NoticeManager` 已有 `show_message / show_scene_message / show_npc_message` 三档
> - 约束：无任务面板、无数值属性条、固定物价、存档兼容、温柔治愈

---

## 0. 与主方案的三处架构分歧（先拍板）

| 争议 | 主方案倾向 | **本方案裁决** | 理由 |
|---|---|---|---|
| 服装存哪 | 塞进 `InventoryManager` 格位 | **独立 `WardrobeManager`，服装不进背包** | 服装是"穿戴态"不是"持有态"；塞进 36 格会挤爆背包；且服装需要"已拥有/已穿/已洗"三态，格位模型表达不了 |
| 购买交互 | 商店面板点购买 | **实物挂架 + 阿珍递衣 + 试衣间** | 硬约束"避免菜单点一下就买"；服装的乐趣在"摸到布料" |
| 穿搭效果 | 纯外观 | **外观 + 社交手感 + 季节体感**，但**不显示数值条** | 约束禁数值条；效果通过 NPC 反应、场景提示、体力恢复速率等**间接可感** |

---

## 1. 数据模型（唯一事实源）

### 1.1 新建 `data/garments.csv`

```csv
garment_id,name,slot,kind,price,season,warmth,formality,color_tag,unlock_condition,unlock_hint,shop_stock,description
tee_plain,素色短袖,torso,casual,28,summer,1,1,white,always,,true,洗得发白的棉，穿久了会贴身。
shirt_linen,亚麻衬衫,torso,casual,68,summer,2,3,beige,always,,true,阿珍说这件最不挑人。
hoodie_grey,灰卫衣,torso,casual,88,autumn,4,1,grey,always,,true,帽子很大，缩进去能挡风。
coat_wool,羊毛外套,torso,formal,220,winter,7,5,brown,affinity:azhen>=6,,true,阿珍压箱底的一件，说等懂的人。
jacket_denim,牛仔夹克,torso,casual,120,spring,3,2,blue,always,,true,越洗越有味道。
dress_floral,碎花连衣裙,full,formal,160,summer,2,4,floral,event:city_festival_week,,true,节日才拿出来挂。
pants_jeans,牛仔裤,legs,casual,78,all,3,2,blue,always,,true,耐磨，干活也方便。
pants_slacks,西裤,legs,formal,110,all,2,5,black,always,,true,方姐说见客户穿这个。
skirt_pleat,百褶裙,legs,formal,95,spring,2,4,navy,always,,true,走路会晃，阿珍喜欢。
shoes_canvas,帆布鞋,feet,casual,55,all,2,1,white,always,,true,鞋头有点脏，是新的。
shoes_leather,皮鞋,feet,formal,180,all,3,5,black,always,,true,擦得亮，走路有声音。
hat_straw,草帽,head,casual,42,summer,1,1,straw,season:summer,,true,河边风大的时候戴。
scarf_knit,针织围巾,neck,casual,65,winter,5,2,red,season:winter,,true,阿珍妈妈织的，她说只进两条。
apron_work,工作围裙,full,work,35,all,1,1,blue,career:factory>=2,,true,工厂发的，穿着像回事。
```

**字段语义**：
- `slot`：`torso / legs / feet / head / neck / full`。`full` 与 `torso+legs` 互斥（穿连衣裙自动脱上衣裤子）。
- `warmth`：0–8，**不显示数值**，只参与季节体感计算。
- `formality`：0–5，**不显示数值**，只参与 NPC 反应与特定场景准入（如见方姐谈房）。
- `color_tag`：给 NPC 反应做"配色偏好"匹配，不参与数值。
- `unlock_condition`：五种语法，与 `npc-002` 的 `condition` 语法**完全一致**（`always / weekend / festival:N / season:X / event:X`），另加 `affinity:npc_id>=N` 与 `career:line>=rank`。
- `shop_stock`：`true` 表示常驻挂架；节日/季节款由 `unlock_condition` 控制是否出现在挂架上。

### 1.2 新建 `data/garment_sets.csv`（套装，可选但推荐）

```csv
set_id,name,members,unlock_condition,effect_hint
set_work,上班装,"apron_work,pants_jeans,shoes_canvas",always,工厂里王师傅会多看你一眼。
set_weekend,周末装,"hoodie_grey,pants_jeans,shoes_canvas",always,街坊觉得你今天松弛。
set_festival,节日装,"dress_floral,shoes_leather",event:city_festival_week,阿榕会主动招呼你。
```

套装**不产生数值加成**，只改变 NPC 反应池与场景提示。

### 1.3 `WardrobeManager` 存档结构（新增，独立于 InventoryManager）

```gdscript
# autoload/wardrobe_manager.gd
var owned: Dictionary = {}          # garment_id -> {acquired_day:int, worn_count:int, dirty:bool}
var equipped: Dictionary = {        # slot -> garment_id
    "torso": "", "legs": "", "feet": "", "head": "", "neck": "", "full": ""
}
var active_set: String = ""         # 最近一次整套穿上的 set_id，换单件即清空
var try_on_history: Array = []      # 最近 5 次试衣记录，供阿珍台词用
```

**存档兼容**：`owned` 已存在于旧档（`relationship_manager.gd` 引用过），迁移时若 `owned` 是 `Array` 则转 `Dictionary`，元素 `{"id": x}` → `{x: {acquired_day:0, worn_count:0, dirty:false}}`。写入 `save-001` 的迁移链，`MIN_SUPPORTED_VERSION` 不动。

---

## 2. 场景实体（购买必须由实物 + NPC 完成）

### 2.1 服装店场景实体清单（`store` 场景内，阿珍的店）

| 实体 | 类型 | 交互 | 说明 |
|---|---|---|---|
| `rack_summer` | 挂架（Area2D） | TAP → 展开当季挂架 | 只显示 `season` 匹配或 `all` 的款 |
| `rack_formal` | 挂架 | TAP → 展开正装挂架 | 显示 `formality>=3` 的款 |
| `rack_special` | 挂架 | TAP → 展开限定挂架 | 只在 `unlock_condition` 满足时出现，否则空架 + 阿珍台词 |
| `mirror` | 穿衣镜 | TAP → 进入试衣态 | 试衣态下可换已拥有款 |
| `fitting_room` | 试衣间（门） | TAP → 进入试衣间内部 | 试衣间是独立小场景，有镜子 |
| `azhen_counter` | 阿珍柜台 | TAP → 对话/结账 | 结账必须在这里完成 |
| `laundry_basket` | 洗衣篮 | TAP → 洗脏衣服 | 见 §5 |

**关键**：挂架上的衣服是**实物**——玩家 TAP 挂架 → 挂架上的衣服"被拿下来"（视觉上从挂架消失）→ 阿珍走过来递给你 → 你拿着走到试衣间 → 穿上 → 出来照镜子 → 满意则走到柜台 → 阿珍收钱。**全程无菜单**。

### 2.2 交互流程（状态机）

```
IDLE
  ↓ TAP rack_*
BROWSING_RACK        # 挂架展开，衣服实物可见，玩家可 TAP 单件
  ↓ TAP garment_on_rack
HOLDING_GARMENT      # 衣服"在手上"（玩家头顶显示小图标），阿珍说一句
  ↓ TAP fitting_room
IN_FITTING_ROOM      # 切到试衣间小场景，玩家自动穿上该件
  ↓ TAP mirror
TRYING_ON            # 镜子显示穿搭，阿珍在门外问"合身吗"
  ↓ TAP confirm / TAP reject
  ├─ confirm → WALK_TO_COUNTER → TAP azhen_counter → 扣钱 → owned += 1
  └─ reject  → 衣服回到挂架，阿珍说"没关系，再看看"
```

**拒绝购买不扣钱、不扣好感**。这是温柔治愈的关键——试衣是免费的。

### 2.3 试衣间是独立小场景（复用 world-001 的 interior 隔离区）

`fitting_room` 作为 `interior` 节点放在 `world_y >= 3000` 隔离区，进门 = 传送 + 切 chunk。这样：
- 试衣间可以有独立的镜子光照（柔光）
- 试衣间内不加载城区 NPC，性能好
- 出门回到 `store` 的 `street_door_pos`

---

## 3. 解锁条件（与既有系统挂钩）

| 服装 | 解锁条件 | 玩家如何知道 |
|---|---|---|
| 基础款（tee/pants/shoes） | `always` | 挂架默认可见 |
| 亚麻衬衫 | `always` | 同上 |
| 羊毛外套 | `affinity:azhen>=6` | 阿珍好感 6 时，阿珍主动说"我压了件好东西" |
| 碎花连衣裙 | `event:city_festival_week` | 节日周挂架自动出现 |
| 草帽 | `season:summer` | 夏季挂架出现 |
| 针织围巾 | `season:winter` | 冬季挂架出现 |
| 工作围裙 | `career:factory>=2` | 工厂升到 2 级后，阿珍说"厂里发的吧？我这也有件像样的" |

**解锁提示走 `NoticeManager.show_scene_message`**（场景提示通道），不弹窗、不弹任务面板。例如：

> 阿珍把一件羊毛外套从柜底翻出来："这件我压了两年，你穿应该合适。"

---

## 4. 穿搭效果（无数值条，全部间接可感）

### 4.1 季节体感

`warmth` 总和参与 `WellbeingManager` 的体力恢复计算，但**不显示**：

```gdscript
func get_warmth_score() -> int:
    var total := 0
    for slot in equipped:
        var gid = equipped[slot]
        if gid != "":
            total += int(ConfigDB.get_row("garments", gid).get("warmth", 0))
    return total

# 在 WellbeingManager 里：
# 冬季：warmth < 4 → 体力恢复 -15%，且场景提示"今天风大，穿得有点单薄"
# 夏季：warmth > 6 → 体力恢复 -10%，且场景提示"太阳底下走久了有点闷"
```

**玩家永远看不到数字**，只看到场景提示和阿珍的关心。

### 4.2 社交手感（NPC 反应）

NPC 反应由 `color_tag` + `formality` + `active_set` 三者匹配：

```gdscript
# npc_voice_selector.gd 扩展
func get_outfit_reaction(npc_id: String) -> String:
    var npc = ConfigDB.get_row("npcs", npc_id)
    var npc_color = str(npc.get("color", ""))
    var formality = WardrobeManager.get_formality_score()
    var set_id = WardrobeManager.active_set
    
    # 套装优先
    if set_id != "" and REACTIONS.has("%s:%s" % [npc_id, set_id]):
        return REACTIONS["%s:%s" % [npc_id, set_id]]
    # 配色匹配
    if _color_affinity(npc_color, WardrobeManager.get_dominant_color()) > 0.6:
        return "%s：今天这身颜色好看，衬你。" % npc.get("name", "")
    # 正式度
    if formality >= 4:
        return "%s：穿得这么正式，是有正事吧？" % npc.get("name", "")
    if formality <= 1:
        return "%s：今天很松弛啊。" % npc.get("name", "")
    return ""
```

**反应池示例**（写进 `data/npc_outfit_reactions.csv`）：

```csv
npc_id,set_id,color_tag,formality_min,formality_max,line
azhen,set_work,,0,5,阿珍：这身干活方便，我眼光没错吧。
azhen,,floral,0,5,阿珍：碎花衬你，下次多进两条。
mei,set_weekend,,0,5,梅姨：今天不上班？看着精神。
wang,set_work,,0,5,王师傅：穿得像个干活的了。
lin,,blue,0,5,小林：这颜色我也有件差不多的。
fangjie,,,4,5,方姐：今天这身，谈事正合适。
```

**反应频率**：每个 NPC 每天最多 1 次穿搭反应，走 `npc-002` 的 120ms 去重计时器，不刷屏。

### 4.3 节日加成

节日周穿 `set_festival`：
- 阿榕（节日摊主）主动招呼，摊位多一个"节日合影"交互
- `PhotoManager` 拍照时，节日装会出现在照片描述里
- **不产生经济加成**（避免"穿对衣服赚钱"的功利感）

---

## 5. 衣柜存储与洗衣

### 5.1 衣柜（`home` 场景内）

`wardrobe` 实体（Area2D）在出租屋。TAP → 打开衣柜**实物视图**（不是 UI 列表，是衣柜门打开、衣服挂在里面的视觉）：

- 已拥有款按 `slot` 分区挂
- TAP 单件 → 穿上
- TAP 已穿款 → 脱下
- 长按 → 查看描述（阿珍的备注）

**衣柜不显示"未拥有"的款**。未拥有的只在店里挂架上。

### 5.2 洗衣（可选，P2）

`laundry_basket` 在出租屋。穿过的衣服 `worn_count += 1`，`worn_count >= 3` 时 `dirty = true`。

- 脏衣服穿上时，NPC 反应池切换到"委婉提醒"（梅姨："衣服该洗了吧？"）
- TAP 洗衣篮 → 洗所有脏衣服，消耗 1 游戏小时
- **不洗也不惩罚**，只是 NPC 会念叨

这是温柔治愈的边界——有反馈，无惩罚。

---

## 6. 与经济 / 社交 / 节日的关联

### 6.1 经济

- **固定物价**：`garments.csv` 的 `price` 是唯一价格源，不打折、不浮动
- **阿珍好感折扣**：**不做**。固定物价是硬约束。好感只影响**解锁**，不影响价格
- **二手回收**：`chen`（旧货行）可回收服装，价格 = `price * 0.3`，但**只回收 `worn_count >= 5` 的**（穿旧了才卖），且 `chen` 会说"这衣服有年头了"

### 6.2 社交

- 阿珍好感 6 → 解锁羊毛外套
- 阿珍好感 10 → 阿珍送 `scarf_knit`（她妈妈织的）
- 阿珍好感 18 → 阿珍送 `dress_floral`（节日款，非节日也能拿）
- 穿搭反应走 `npc-002` 的 NPC 提示通道，与场景提示、系统提示分离

### 6.3 节日

- `city_festival_week` 事件期间：
  - `rack_special` 出现 `dress_floral`
  - 阿榕摊位出现"节日合影"交互，穿 `set_festival` 时阿榕主动招呼
  - 节日结束后 `dress_floral` 从挂架消失，但**已拥有的不消失**

---

## 7. 迁移步骤（可回退）

| 阶段 | 动作 | 验证 | 回退 |
|---|---|---|---|
| **S0** | 跑门禁：`grep -rn "WardrobeManager" scripts/ autoload/`，确认现有接口 | 输出写入 `docs/WARDROBE_FACTS.md` | — |
| **S1** | 新建 `data/garments.csv` + `data/garment_sets.csv` + `data/npc_outfit_reactions.csv` | CSV 可被 `ConfigDB` 读取 | 删文件 |
| **S2** | 新建 `autoload/wardrobe_manager.gd`，实现 `owned/equipped/active_set` + 存档迁移 | 旧档可加载，`owned` 从 Array 转 Dictionary | feature flag `wardrobe.new_pipeline=false` 走旧路径 |
| **S3** | `store` 场景加 `rack_summer/rack_formal/rack_special/mirror/fitting_room/azhen_counter` 实体 | 场景可加载，实体可 TAP | 删实体 |
| **S4** | 实现购买状态机（§2.2） | 手动跑通：TAP 挂架 → 拿衣 → 试衣 → 结账 | 状态机加 `enabled=false` |
| **S5** | `home` 场景加 `wardrobe/laundry_basket` 实体 | 衣柜可开、可换装 | 删实体 |
| **S6** | 扩展 `npc_voice_selector.gd` 的 `get_outfit_reaction` | 穿不同衣服找不同 NPC，反应正确 | 函数返回空串即回退 |
| **S7** | `WellbeingManager` 接入 `warmth_score` | 冬季穿单薄，体力恢复变慢 | 加 `warmth.enabled=false` |
| **S8** | `chen` 回收逻辑 | 穿旧的衣服可卖 | 删回收分支 |

**每阶段独立可回退**，feature flag 统一挂在 `ProjectSettings` 的 `wardrobe.*` 命名空间下。

---

## 8. 与既有系统的接口（最小侵入）

| 系统 | 接口 | 说明 |
|---|---|---|
| `InventoryManager` | **不接入** | 服装不进背包 |
| `WardrobeManager` | 新增 autoload | 唯一服装状态源 |
| `NoticeManager` | `show_scene_message` / `show_npc_message` | 解锁提示走场景通道，NPC 反应走 NPC 通道 |
| `RelationshipManager` | `affinity["azhen"]` | 解锁条件读好感 |
| `WellbeingManager` | `get_warmth_score()` | 季节体感 |
| `PhotoManager` | 拍照时读 `equipped` | 照片描述带穿搭 |
| `world.gd` | `wardrobe_requested` 信号已存在 | 复用，不新增信号 |
| `save-001` | 迁移链加 `owned` 类型转换 | 不升版本号 |

---

## 9. 验收标准（可执行断言）

```gdscript
# tests/test_wardrobe.gd
func test_buy_requires_scene_interaction():
    # 断言：不存在直接调用 WardrobeManager.buy() 的路径
    # 购买必须经过 azhen_counter 的 TAP 事件
    assert_true(WardrobeManager.has_method("_on_counter_tapped"))

func test_try_on_is_free():
    var money_before = EconomyManager.money
    WardrobeManager.try_on("coat_wool")
    assert_eq(EconomyManager.money, money_before)

func test_reject_returns_to_rack():
    WardrobeManager.try_on("coat_wool")
    WardrobeManager.reject()
    assert_false(WardrobeManager.owned.has("coat_wool"))
    assert_true(WardrobeManager.is_on_rack("coat_wool"))

func test_unlock_condition_affinity():
    RelationshipManager.affinity["azhen"] = 5
    assert_false(WardrobeManager.is_unlocked("coat_wool"))
    RelationshipManager.affinity["azhen"] = 6
    assert_true(WardrobeManager.is_unlocked("coat_wool"))

func test_seasonal_rack():
    TimeSystem.set_season("summer")
    assert_true(WardrobeManager.is_on_rack("hat_straw"))
    TimeSystem.set_season("winter")
    assert_false(WardrobeManager.is_on_rack("hat_straw"))

func test_save_migration_array_to_dict():
    var old_save = {"wardrobe": {"owned": ["tee_plain", "pants_jeans"]}}
    var migrated = WardrobeManager.migrate(old_save)
    assert_true(migrated["owned"] is Dictionary)
    assert_true(migrated["owned"].has("tee_plain"))

func test_no_numeric_bar_in_ui():
    # 断言：服装相关 UI 节点不含 ProgressBar / Label 显示 warmth/formality
    var ui = load("res://scenes/ui/wardrobe_view.tscn").instantiate()
    assert_eq(_count_nodes_of_type(ui, "ProgressBar"), 0)
```

---

## 10. 与主方案的关键差异总结

1. **服装不进背包**——独立 `WardrobeManager`，避免挤爆 36 格
2. **购买是场景状态机**——挂架 → 拿衣 → 试衣间 → 镜子 → 柜台，全程无菜单
3. **试衣免费、拒绝无惩罚**——温柔治愈的核心
4. **效果无数值条**——warmth/formality 只参与计算，玩家只看到 NPC 反应和场景提示
5. **试衣间是独立 interior 场景**——复用 world-001 的隔离区架构
6. **解锁靠好感/季节/节日/职业**——与既有系统挂钩，不新增任务面板
7. **固定物价不打折**——好感只影响解锁，不影响价格
8. **每阶段可回退**——feature flag 统一命名空间

## 批判

## 批判A（qa_lead）

# 批判报告：服装系统两方案的可执行缺陷与返工要求

以下按「必须返工 / 必须补测 / 必须裁决」三档输出。每条给出**证据、后果、返工动作**。

---

## A. 阻塞性事实缺口（两方案共同，未裁决不得写代码）

### A1. `WardrobeManager` 真实接口未验证，两方案都在假设上盖楼
- 主方案 §0.1 自己承认「若不存在则新建」，但 §2.2 又直接给出完整实现并声称「只做增量扩展」。**这是自相矛盾**：如果类不存在，`relationship_manager.gd` 引用 `WardrobeManager.owned` 会直接编译失败，说明要么类存在、要么引用是死代码。
- 独立方案 §1.3 直接写 `var owned: Dictionary`，但 §0 又说「已从上下文确认 owned 已存在」——**存在 ≠ 是 Dictionary**。若旧档是 `Array[String]`，独立方案的 `owned.has("coat_wool")` 语义完全不同（Array.has 是值查找，Dictionary.has 是键查找），测试 `test_reject_returns_to_rack` 会假阳性通过。
- **返工**：两方案合并前必须先跑：
  ```bash
  grep -rn "WardrobeManager" --include=*.gd . 
  grep -rn "\.owned" --include=*.gd . | grep -i wardrobe
  ```
  把 `owned` 的**声明行**和**所有读写点**贴进 `docs/WARDROBE_FACTS.md`。未贴出前，§2.2 和 §1.3 的字段设计全部作废。

### A2. `ConfigDB` 的读取语义未验证，CSV 字段可能读不到
- 主方案 §2.3 说「若 ConfigDB 用 DictReader 可安全新增列；若用索引取值，见 G0.3 裁决」——但 G0.3 是**玩家渲染管线**，不是 ConfigDB。**引用错章节，裁决悬空**。
- 独立方案 §1.1 直接新增 `unlock_hint`、`color_tag` 列，未验证 ConfigDB 是否容忍未知列。
- **返工**：跑 `grep -rn "func get_row\|func get_rows\|DictReader\|split(\",\")" --include=*.gd autoload/ scripts/`，确认：
  1. 列名读取还是索引读取；
  2. 未知列是忽略还是报错；
  3. 空值返回 `""` 还是 `null`。
  写入 FACTS 后再定 CSV schema。

### A3. 两方案对「服装是否进背包」的裁决未落到 InventoryManager 实际接口
- 独立方案 §0 断言「InventoryManager 是格位制，不适合塞服装」——**这是设计判断，不是事实**。需要证据：`grep -n "hotbar\|backpack\|func add_item" autoload/inventory_manager.gd`。
- 主方案 §2.1 完全没提 InventoryManager，但 §0 又把它列为「复用」。**复用在哪？没说**。
- **返工**：明确写出「服装不进 InventoryManager」的**代码级证据**（如 `add_item` 对 `slot` 类型的白名单），否则两方案都在猜。

### A4. 季节/节日/经济接口名两方案不一致，必有一方编译失败
| 接口 | 主方案 | 独立方案 |
|---|---|---|
| 季节 | `SeasonManager.get_current_season()` | `TimeSystem.set_season("summer")` |
| 节日 | `FestivalManager.is_active(id)` | `event:city_festival_week`（无函数名） |
| 经济 | `EconomyManager.spend/earn/can_afford` | `EconomyManager.money`（直接读字段） |
| 好感 | `RelationshipManager.get_affinity(id)` | `RelationshipManager.affinity["azhen"]`（直接读字典） |

- **后果**：两方案的测试断言**至少一半跑不起来**。独立方案的 `test_unlock_condition_affinity` 直接改 `affinity` 字典，若真实接口是 `add_affinity`，测试通过但游戏内不生效——**假阳性**。
- **返工**：跑 `grep -rn "func get_affinity\|func add_affinity\|var affinity\|func spend\|func earn\|var money\|func get_current_season\|func is_active" --include=*.gd autoload/`，把**唯一函数名**写进 FACTS。两方案统一调用该函数，禁止直接读写字段。

---

## B. 主方案的具体缺陷

### B1. `rack_picker.gd` 是「伪实物」——本质仍是菜单
- §3.3 声称「这不是菜单，是场景内实物放大展示」，但实现是：`_spawn_item_sprites()` 在货架上方**凭空生成一排 Sprite2D**，玩家点其中一个。这排 Sprite 与货架上的实物**不是同一批节点**，是运行时新建的。
- **后果**：违反「购买必须在场景中由实物完成」——玩家点的是**新生成的 UI 替身**，不是货架上的实物。货架上的 `_update_visual()` 是 `pass`（§3.2），**货架本身根本没有实物贴图**。
- **返工**：
  1. `ClothingRack._update_visual()` 必须真实生成每个 `displayed_item` 的子 Sprite2D，并保存引用；
  2. `rack_picker` 不得新建 Sprite，只能**放大已有子节点**（改 `scale` + `z_index`）；
  3. 断言：`rack.get_child_count() == rack.displayed_items.size()`，且 picker 打开前后子节点数量不变。

### B2. `begin_purchase` 在试衣时就被调用，但 `confirm_purchase` 才扣钱——状态机有洞
- §3.4 `_enter_try_on` 调 `WardrobeManager.begin_purchase(cid)`，§3.5 `Mirror.on_tap` 调 `confirm_purchase()`。
- 但 `begin_purchase` 只设 `pending_try_on`，**没有锁库存**。若玩家试衣期间（阿珍走过来需要时间）另一路径触发购买，`can_buy` 仍返回 ok。
- **更严重**：`cancel_purchase` 返回 `refund`，但 §3.6 的 `Curtain.on_tap` 调 `EconomyManager.earn(refund, ...)`——**此时钱还没扣**（`confirm_purchase` 才扣）。**退款 = 凭空加钱**。
- **返工**：
  1. `begin_purchase` 必须**预扣款**（`spend`）或**锁库存**，二选一；
  2. 若预扣款，`cancel_purchase` 退 90% 才成立；若锁库存，`cancel_purchase` 不应调用 `earn`；
  3. 断言：`test_cancel_before_confirm_does_not_increase_money`。

### B3. `equip` 的「再点一次脱下」逻辑会误触发 `worn_count`
- §2.2 `equip`：若 `prev == clothing_id` 则 `equipped[slot] = ""` 并返回，**不增加 worn_count**；否则增加。
- 但玩家「穿上 → 脱下 → 再穿上」会 `worn_count += 2`，而「穿上 → 再点一次脱下」只 `+= 1`。**计数语义不一致**。
- **返工**：明确 `worn_count` 是「穿上次数」还是「穿着天数」。若是天数，应在 `TimeSystem.day_started` 时对当前 `equipped` 累加，而非 `equip` 时。

### B4. `_on_day_started` 的补货逻辑有 off-by-one 且不补满
- §2.2：`elapsed >= restock` 时 `shop_stock[cid] = get_stock(cid) + 1`——**每次只补 1 件**，不是补到 `max_stock`。
- 且 `shop_last_restock_day` 在循环外统一更新，若某件 `restock_days=3`、另一件 `=7`，第 7 天两件都补 1，但第一件应该补 2 次（第 3、6 天）。
- **返工**：改为按件记录 `last_restock_day`，或每次补到 `max_stock`。断言：`test_restock_fills_to_max`。

### B5. `_eval_condition` 的 `festival:` 和 `season:` 分支引用了未定义的管理器
- §2.2 用 `FestivalManager.is_active` 和 `SeasonManager.get_current_season`，但 §0.4/§0.6 说「若不存在则降级」。**代码里没写降级分支**。
- **返工**：`_eval_condition` 必须对每个管理器做 `Engine.has_singleton` 或 `has_method` 检查，缺失时 `push_warning` 并返回 `false`（而非崩溃）。

### B6. `cl_azhen_gift` 的 `price=0` 会污染 `can_buy` 和 `pending_refund_price`
- §2.1 说「不可购买，仅通过好感 12 赠送」，但 §2.2 的 `can_buy` 只检查 `unlock_condition`，`affinity:azhen>=12` 满足时 `can_buy` 返回 `ok:true, price:0`。
- **后果**：玩家可以「买」0 元围裙，`confirm_purchase` 扣 0 元，`owned` 增加——**赠送路径被绕过**。
- **返工**：新增字段 `acquire_method`（`buy` / `gift` / `event`），`can_buy` 只对 `buy` 返回 ok。

### B7. `player.preview_outfit` / `clear_preview` 在 `player_outfit_layer.gd` 里，但调用方是 `player` 节点
- §3.4 `player.preview_outfit(cid)`，§4.2 `preview_outfit` 定义在 `player_outfit_layer.gd`（`extends Node2D`）。
- **除非** `player_outfit_layer.gd` 挂在 player 节点下且 player 有转发方法，否则**调用不存在**。
- **返工**：明确 `player.gd` 是否有 `preview_outfit` 转发；若无，改为 `player.get_node("OutfitLayer").preview_outfit(cid)`。

### B8. `Mirror._clear_rack_state` 调 `picker.queue_free()`，但 picker 可能是 `get_first_node_in_group` 找到的**其他货架**的 picker
- §3.3 picker 是 `add_child(picker)` 到 rack 下，但 §3.5 用 `get_tree().get_first_node_in_group("rack_picker")` 找——**多货架场景会误删**。
- **返工**：picker 应记录 `_rack` 引用，清理时 `_rack.get_node_or_null("RackPicker")`。

### B9. 主方案 §4.3 代码被截断
- `if str(WardrobeManager.equipped.get(str(c["slot"]` ——**文件不完整**。
- **返工**：补全或删除该节。

---

## C. 独立方案的具体缺陷

### C1. `test_buy_requires_scene_interaction` 是**假断言**
```gdscript
assert_true(WardrobeManager.has_method("_on_counter_tapped"))
```
- 这只验证方法存在，**不验证购买路径唯一**。主方案的 `confirm_purchase` 也可被任意调用。
- **返工**：改为静态检查——`grep -rn "WardrobeManager.buy\|WardrobeManager.confirm_purchase" scripts/` 只允许出现在 `azhen_counter.gd` 中。或运行时：`WardrobeManager` 加 `_purchase_caller` 字段，非柜台调用时 `push_error`。

### C2. `test_no_numeric_bar_in_ui` 的 `_count_nodes_of_type` 未定义
- 且 `load("res://scenes/ui/wardrobe_view.tscn")` 这个文件在方案里**从未被创建**（§5.1 说衣柜是「实物视图」，不是 UI 场景）。
- **返工**：删除该测试，或改为检查 `WardrobeManager` 不暴露 `get_warmth_display()` 之类方法。

### C3. `test_save_migration_array_to_dict` 调 `WardrobeManager.migrate(old_save)`，但 §1.3 没定义 `migrate`
- **返工**：补 `migrate` 函数签名，或改为 `from_save` 内部处理。

### C4. `test_seasonal_rack` 调 `TimeSystem.set_season("summer")`，但 §4.1 用 `SeasonManager`（主方案）或未定义（独立方案）
- 独立方案 §1.1 的 `season:summer` 条件由谁评估？**没写**。
- **返工**：补 `is_on_rack(garment_id)` 的实现，明确季节来源。

### C5. `get_outfit_reaction` 的 `_color_affinity` 未定义，且 `get_dominant_color` 未定义
- §4.2 调 `_color_affinity(npc_color, WardrobeManager.get_dominant_color())`，两个函数都不存在。
- **返工**：补实现或删除该分支。

### C6. `REACTIONS` 常量未定义
- §4.2 `REACTIONS.has(...)`，但 `REACTIONS` 从哪来？§4.2 说「写进 `data/npc_outfit_reactions.csv`」，但没写加载逻辑。
- **返工**：补 `_load_reactions()` 和 `REACTIONS` 的初始化。

### C7. 「试衣免费、拒绝无惩罚」与「阿珍好感 -1」冲突
- 独立方案 §2.2 说「拒绝购买不扣钱、不扣好感」，但主方案 §1 铁律 2 说「阿珍好感 -1」。
- **两方案对同一行为给出相反规则**。必须裁决：温柔治愈（独立）vs 反悔有代价（主）。
- **返工**：裁决后统一。若选独立方案，主方案 §3.6 的 `add_affinity("azhen", -1)` 必须删除。

### C8. `dirty` 状态与 `worn_count` 的触发条件不一致
- §5.2 说 `worn_count >= 3` 时 `dirty = true`，但 §1.3 的 `owned` 结构是 `{acquired_day, worn_count, dirty}`——**`worn_count` 何时增加？** §2.2 状态机没写。
- **返工**：明确 `worn_count` 在 `equip` 时 +1，还是 `day_started` 时对当前 equipped +1。

### C9. `chen` 回收 `price * 0.3` 与「固定物价」冲突
- §6.1 说「固定物价是硬约束」，但回收价是 `price * 0.3`——**这是浮动价**。
- **返工**：明确「固定物价」指**售价**，回收价可另定。或改为固定回收价表。

### C10. 试衣间是「独立 interior 场景」，但 §2.2 状态机说 `TAP fitting_room → IN_FITTING_ROOM`，§2.1 又说 `mirror` 在 `store` 场景
- 玩家进试衣间后，`mirror` 是试衣间内的还是 store 内的？**两处都提到 mirror**。
- **返工**：明确 mirror 实例位置。若试衣间是独立场景，store 的 mirror 是「预览镜」（不进入试衣态），试衣间的 mirror 才是「确认镜」。

---

## D. 两方案共同缺失

### D1. 无「已拥有但未穿」的存档字段
- 两方案的 `owned` 都只记录「拥有」，但玩家可能拥有 10 件、只穿 1 件。**存档时 equipped 是 slot→id，owned 是 id→meta**，这没问题。但**没有「上次穿搭」的恢复**——读档后玩家裸奔。
- **返工**：`from_save` 后必须 `_refresh_all()` 触发渲染层更新。主方案 §2.2 的 `from_save` 只 `emit wardrobe_changed`，但 `player_outfit_layer` 是否已 `_ready`？**时序风险**。

### D2. 无「服装贴图缺失」的降级
- 主方案 §4.2 有 `ResourceLoader.exists` 检查，独立方案**完全没有**。
- **返工**：独立方案补 `_apply` 的贴图存在性检查。

### D3. 无「多货架同时打开 picker」的互斥
- 主方案 §3.3 picker 用 group 查找，独立方案 §2.1 有 3 个货架。**同时点两个货架会怎样？**
- **返工**：加 `_active_picker` 单例锁，或 picker 打开时禁用其他货架交互。

### D4. 无「试衣中离开场景」的处理
- 玩家在试衣态（`pending_try_on` 非空）时走出店门，`pending_try_on` 残留，下次进店状态错乱。
- **返工**：`Exit.on_tap` 必须检查 `pending_try_on`，非空时提示「还没试完呢」或自动 cancel。

### D5. 无「同 slot 多件已拥有」的衣柜展示
- 玩家拥有 3 件 top，衣柜怎么展示？主方案 §4.3 是 GridContainer，独立方案 §5.1 是「按 slot 分区挂」。**两方案都没说同 slot 多件怎么排**。
- **返工**：明确排序规则（按 `acquired_day` / `worn_count` / `formality`）。

### D6. 无「NPC 反应去重」的持久化
- 独立方案 §4.2 说「每个 NPC 每天最多 1 次」，但**这个计数存哪？** 存档吗？跨天重置吗？
- **返工**：明确 `npc_outfit_reaction_day: Dictionary`（npc_id → day），存档。

### D7. 无「节日结束后已拥有节日款」的行为
- 独立方案 §6.3 说「已拥有的不消失」，但**穿上后 NPC 反应是否还走节日池？** 没说。
- **返工**：明确 `active_set` 与 `event` 的解耦。

### D8. 无「经济不足时的购买路径」
- 主方案 §3.3 `_on_item_selected` 对 `no_money` 只说「钱不够也没关系，先试试看」，然后 `_close()`。**玩家试完发现买不起，退款流程走不通**（因为没扣钱）。
- **返工**：明确「试衣免费」是否允许无钱试衣。若允许，`begin_purchase` 不应检查 `can_afford`。

### D9. 无「服装与拍照系统」的接口验证
- 独立方案 §8 说 `PhotoManager` 读 `equipped`，但**没给函数名**。
- **返工**：跑 `grep -rn "PhotoManager\|func.*photo" --include=*.gd autoload/ scripts/`，确认接口。

### D10. 无「服装与天气系统」的接口
- 两方案都提「季节体感」，但**天气**（下雨、下雪）是否影响？没说。
- **返工**：明确天气是否参与 `warmth` 计算。若不参与，在 FACTS 里写明「天气不影响服装」。

---

## E. 必须补的测试（两方案合并后）

```gdscript
# 1. 购买路径唯一性（静态）
func test_no_direct_purchase_outside_counter():
    var output = OS.execute("grep", ["-rn", "WardrobeManager.confirm_purchase", "scripts/"])
    # 只允许出现在 azhen_counter.gd
    assert_eq(output.split("\n").size(), 1)

# 2. 试衣不扣钱
func test_try_on_does_not_spend():
    var before = EconomyManager.get_money()
    WardrobeManager.begin_purchase("tee_plain")
    assert_eq(EconomyManager.get_money(), before)

# 3. 反悔不凭空加钱
func test_cancel_does_not_earn():
    var before = EconomyManager.get_money()
    WardrobeManager.begin_purchase("tee_plain")
    WardrobeManager.cancel_purchase()
    assert_eq(EconomyManager.get_money(), before)  # 若预扣款则 before - 10%

# 4. 库存锁
func test_pending_locks_stock():
    WardrobeManager.begin_purchase("tee_plain")
    var check = WardrobeManager.can_buy("tee_plain")
    assert_false(check["ok"])

# 5. 货架实物数量一致
func test_rack_visual_matches_data():
    var rack = load("res://scenes/clothing_shop.tscn").instantiate().get_node("RackTop")
    assert_eq(rack.get_child_count(), rack.displayed_items.size())

# 6. 存档往返
func test_save_roundtrip():
    WardrobeManager.equip("tee_plain")
    var data = WardrobeManager.to_save()
    WardrobeManager.from_save(data)
    assert_eq(WardrobeManager.equipped["torso"], "tee_plain")

# 7. 贴图缺失不崩溃
func test_missing_texture_graceful():
    WardrobeManager.catalog["tee_plain"]["texture_path"] = "res://nonexistent.png"
    WardrobeManager.equip("tee_plain")  # 不应崩溃

# 8. 多货架 picker 互斥
func test_only_one_picker():
    rack_a.on_tap()
    rack_b.on_tap()
    assert_eq(get_tree().get_nodes_in_group("rack_picker").size(), 1)

# 9. 试衣中离开场景
func test_leave_during_try_on():
    WardrobeManager.begin_purchase("tee_plain")
    exit.on_tap()
    assert_true(WardrobeManager.pending_try_on.is_empty())

# 10. 同 slot 多件排序
func test_wardrobe_sort():
    WardrobeManager.owned = {"a": {"acquired_day": 1}, "b": {"acquired_day": 2}}
    var order = WardrobeManager.get_sorted_owned("torso")
    assert_eq(order[0], "b")  # 新的在前
```

---

## F. 返工优先级

| 优先级 | 项 | 阻塞 |
|---|---|---|
| P0 | A1–A4 事实裁决 | 全部代码 |
| P0 | B2 预扣款/锁库存 | 经济正确性 |
| P0 | B6 `acquire_method` | 赠送路径 |
| P1 | B1 货架实物化 | 硬约束 |
| P1 | C1 购买路径唯一性测试 | 硬约束 |
| P1 | D4 试衣中离开 | 存档风险 |
| P2 | B4 补货逻辑 | 经济 |
| P2 | D5 同 slot 排序 | UX |
| P2 | D6 NPC 反应去重持久化 | 存档 |
| P3 | C7 反悔惩罚裁决 | 设计一致性 |
| P3 | C9 回收价 vs 固定物价 | 设计一致性 |

---

## G. 一句话总结

**两方案都在「假设接口存在」的基础上写了完整实现，但没有任何一方先跑门禁验证。** 主方案的 `rack_picker` 是伪实物，独立方案的测试是假断言。**先跑 A1–A4，再谈实现。**

## 批判B（gameplay_planner）

# 批判报告：服装系统两方案

## A. 共同致命缺陷（两方案都踩）

### A1. `WardrobeManager` 存在性未验证就写实现 —— 死代码风险
- 主方案 §0.1 自己承认"若不存在则本方案 §2 提供完整实现"，但 §2.2 直接给出 200 行实现，**没有先跑门禁**。
- 独立方案 §1.3 同样直接写 `owned/equipped/active_set`，且 §8 声称"新增 autoload"。
- **冲突**：`relationship_manager.gd` 已引用 `WardrobeManager.owned`，说明该类**已存在**。两方案都在未读现有实现的情况下重写，必然产生：
  - 字段名冲突（现有 `owned` 可能是 `Array[String]`，主方案假设 `Dictionary`）
  - 信号名冲突（现有可能已有 `wardrobe_changed`）
  - 重复 autoload 注册
- **返工要求**：两方案都必须先执行 `grep -rn "WardrobeManager" scripts/ autoload/` 并把**真实签名**贴进方案，否则 §2.2 / §1.3 全部作废。

### A2. `SeasonManager` / `FestivalManager` / `CareerManager` / `EconomyManager` 全部假设存在
- 主方案 §2.2 直接调用 `SeasonManager.get_current_season()`、`FestivalManager.is_active()`、`CareerManager.get_rank()`、`EconomyManager.can_afford/spend/earn`。
- 独立方案 §4.1 调用 `WellbeingManager`，§6 调用 `chen` 回收。
- **两方案都没有验证这些 autoload 是否存在**。若不存在，`_eval_condition` 会在第一帧 `push_error` 并返回 false，**所有非 `always` 服装永久锁死**——这是不可触达机制。
- **返工要求**：列出每个依赖 autoload 的**存在性检查命令**，不存在的必须降级（如季节用 `CalendarManager.month` 推断，节日用 `CalendarManager.event_flags` 推断）。

### A3. 存档迁移链版本号未确认
- 主方案说"新增 v15 步骤"，独立方案说"不升版本号"。
- **两者矛盾且都未验证当前 `MIN_SUPPORTED_VERSION` 和最新版本号**。
- 若当前已是 v15，主方案会覆盖；若当前是 v12，独立方案的"不升版本"会导致旧档 `owned` 为 `Array` 时 `equipped` 初始化失败。
- **返工要求**：读 `save-001` 的迁移链，贴出当前版本号和迁移函数签名，再决定。

### A4. 玩家渲染管线未确认就写渲染代码
- 主方案 §4.1 自己说"依赖 G0.3 裁决"，但 §4.2 直接给出 `player_outfit_layer.gd` 完整实现，且假设玩家是 `Node2D` 下挂 `Sprite2D`。
- 独立方案完全没提渲染实现，只说"外观 + 社交手感"。
- **若玩家是 `AnimatedSprite2D`**，主方案的 6 层 `Sprite2D` 叠加会与动画帧冲突（每帧动画会覆盖叠加层）。
- **返工要求**：读 `player.gd`，确认渲染节点类型，再决定叠加策略。

### A5. 测试用例不可执行
- 主方案 §9 的测试**全部是伪代码**：`WardrobeManager.has_method("_on_counter_tapped")` 断言的是"存在某方法"，不是"购买必须经过场景交互"——**这个断言永远为真或永远为假，不构成测试**。
- `test_no_numeric_bar_in_ui` 里 `_count_nodes_of_type` 未定义。
- 独立方案 §9 的 `WardrobeManager.try_on/reject/is_on_rack/migrate` **在方案正文中根本没定义这些方法**——测试引用了不存在的 API。
- **返工要求**：测试必须引用方案正文中**已定义的方法签名**，且断言必须可证伪。

---

## B. 主方案专属问题

### B1. `rack_picker.gd` 是"伪实物交互"——本质仍是菜单
- §3.3 声称"这不是菜单，是场景内实物放大展示"，但实现是：`_spawn_item_sprites()` 动态生成 `Sprite2D`，点击后 `_show_confirm_buttons()` 弹出"试衣间门 / 放下"两个高亮。
- **问题**：动态生成的 `Sprite2D` 没有碰撞体（`input_pickable = true` 但未加 `CollisionShape2D`），`input_event` 信号**不会触发**。这是死代码。
- **问题**：`_show_confirm_buttons` 调用 `fitting.highlight_for(cid)` 和 `exit.highlight_for_cancel()`，但 `Exit` 节点在 §3.1 场景树中是 `Interactable`，**没有 `highlight_for_cancel` 方法**。
- **返工要求**：要么给每个 `Sprite2D` 加 `Area2D + CollisionShape2D`，要么改用 `TextureButton`；`Exit` 的方法必须与场景树定义一致。

### B2. `begin_purchase` / `confirm_purchase` / `cancel_purchase` 状态机有洞
- §2.2 `begin_purchase` 设置 `pending_try_on`，但**没有检查玩家是否已在试衣中**。若玩家连续点两件衣服，`pending_try_on` 被覆盖，第一件的 `pending_refund_price` 丢失。
- `cancel_purchase` 返回退款额但**不实际退款**（§3.6 的 Curtain 才调用 `EconomyManager.earn`）。若玩家在 `pending_try_on` 非空时直接离开场景，`pending_try_on` 永久残留，下次进店 `confirm_purchase` 会扣错钱。
- **返工要求**：`begin_purchase` 必须先检查 `pending_try_on.is_empty()`；场景 `_exit_tree` 必须清理 `pending_try_on`。

### B3. 试衣反悔扣好感 -1 —— 违反"温柔治愈"约束
- §1 铁律 2 说"试穿后选择不买 → 退款 90%，扣 10% 试衣费，且阿珍好感 -1"。
- 独立方案 §2.2 明确"拒绝购买不扣钱、不扣好感"。
- **主方案与项目基调冲突**：温柔治愈游戏不应因"试了不买"惩罚玩家。且 10% 试衣费对 280 元的大衣是 28 元，对 35 元的 T 恤是 3.5 元——**经济惩罚不成比例**。
- **返工要求**：删除试衣费与好感惩罚，或改为"试衣次数过多时阿珍台词变化"（无实际惩罚）。

### B4. `cl_azhen_gift` 解锁条件 `affinity:azhen>=12` 但 `price=0` 且 `stock=1`
- §2.1 表格说"不可购买，仅通过阿珍好感 12 赠送"，但 `can_buy` 只检查 `unlock_condition`，**不检查"是否可购买"**。玩家好感 12 时可以在货架上看到它并"购买"（0 元），绕过赠送剧情。
- **返工要求**：`clothing.csv` 增加 `acquirable` 字段（`buy` / `gift` / `event`），`can_buy` 检查该字段。

### B5. `_on_day_started` 补货逻辑有 bug
- §2.2：`if elapsed >= restock: shop_stock[cid] = get_stock(cid) + 1`，但 `shop_last_restock_day = day_number` 在循环外**无条件更新**。
- 若某件衣服 `restock_days=7`，玩家第 3 天进店，`elapsed=3 < 7`，不补货，但 `shop_last_restock_day` 被更新为 3。第 10 天进店，`elapsed=7`，补货——**实际间隔是 7 天，但计时起点被重置**，导致补货周期漂移。
- **返工要求**：`shop_last_restock_day` 应改为 per-item 的 `shop_last_restock[cid]`。

### B6. `wardrobe_panel.gd` 代码截断
- §4.3 代码在 `if str(WardrobeManager.equipped.get(str(c["slot"]` 处**直接截断**，方案不完整。
- **返工要求**：补全或删除该段。

### B7. 节日联动只提 `spring_festival`，与独立方案的 `city_festival_week` 冲突
- 主方案 §2.1 `cl_festival_vest` 解锁条件 `festival:spring_festival`。
- 独立方案 §1.1 `dress_floral` 解锁条件 `event:city_festival_week`。
- **两者节日 ID 不同，且都未验证节日系统实际 ID**。
- **返工要求**：读节日系统，确认实际节日 ID 列表。

---

## C. 独立方案专属问题

### C1. `WardrobeManager` 方法在正文中不存在，但测试引用
- §9 测试调用 `WardrobeManager.try_on / reject / is_on_rack / migrate`。
- §1.3 只定义了 `owned / equipped / active_set / try_on_history` 四个字段，**没有任何方法**。
- §2.2 的状态机是文字描述，**没有对应代码**。
- **返工要求**：补全 `WardrobeManager` 的方法签名，或删除 §9 测试。

### C2. `get_warmth_score` 在 `WardrobeManager` 还是 `WellbeingManager`？
- §4.1 代码块定义 `func get_warmth_score()` 但**没有说明挂在哪个类**。
- §8 接口表说 `WellbeingManager.get_warmth_score()`。
- **返工要求**：明确归属。

### C3. `npc_voice_selector.gd` 的 `REACTIONS` 字典未定义
- §4.2 代码引用 `REACTIONS.has(...)` 和 `REACTIONS[...]`，但**没有定义 `REACTIONS`**。
- 同时 §4.2 又说反应池在 `data/npc_outfit_reactions.csv`——**两套数据源冲突**。
- **返工要求**：统一为 CSV 驱动，删除硬编码 `REACTIONS`。

### C4. `_color_affinity` 函数未定义
- §4.2 调用 `_color_affinity(npc_color, WardrobeManager.get_dominant_color())`，两个函数都未定义。
- `get_dominant_color()` 的逻辑（多件衣服如何取"主色"？）完全缺失。
- **返工要求**：定义 `_color_affinity` 算法（如色相距离），或删除该分支。

### C5. `full` slot 与 `torso+legs` 互斥逻辑未实现
- §1.1 字段语义说"`full` 与 `torso+legs` 互斥（穿连衣裙自动脱上衣裤子）"。
- **正文没有任何代码实现这个互斥**。`equipped` 字典有 6 个 slot，穿 `full` 时如何清空 `torso/legs`？
- **返工要求**：补 `equip()` 的互斥逻辑。

### C6. 试衣间"独立小场景"与 `world-001` 隔离区架构未验证
- §2.3 说"复用 world-001 的 interior 隔离区，`world_y >= 3000`"。
- **未验证 `world-001` 是否真有此架构**，也未验证 `store` 场景是否有 `street_door_pos`。
- **返工要求**：读 `world-001` 的场景分区文档，确认隔离区坐标。

### C7. 洗衣系统 `worn_count >= 3` 触发 `dirty`，但 `worn_count` 何时 +1？
- §5.2 说"穿过的衣服 `worn_count += 1`"，但**没有说明触发时机**（穿上时？脱下时？每天结算时？）。
- 若穿上即 +1，玩家反复穿脱同一件衣服会瞬间变脏。
- **返工要求**：明确 `worn_count` 递增时机（建议：每天结算时，若该件在 `equipped` 中则 +1）。

### C8. `chen` 回收 `price * 0.3` 与"固定物价"约束冲突
- §6.1 说"固定物价是硬约束"，但回收价 `price * 0.3` 是**动态计算**，且未说明 `price` 从哪读。
- 若玩家 220 买羊毛外套，穿旧后 66 卖出，**净亏 154**——这不是"温柔治愈"，是"经济惩罚"。
- **返工要求**：回收价应固定或删除回收功能。

### C9. §7 迁移步骤 S2 的 feature flag `wardrobe.new_pipeline=false` 走旧路径
- **旧路径是什么？** 若 `WardrobeManager` 已存在，旧路径就是现有实现；若不存在，旧路径是空。
- feature flag 无法回退到"不存在的旧路径"。
- **返工要求**：明确旧路径的具体行为。

### C10. §9 测试 `test_buy_requires_scene_interaction` 断言无效
- `assert_true(WardrobeManager.has_method("_on_counter_tapped"))` —— 这个方法名是**测试自己编的**，方案正文中柜台交互方法名未定义。
- 即使方法存在，也不能证明"购买必须经过场景交互"（方法可以被直接调用）。
- **返工要求**：改为断言"`WardrobeManager` 无公开 `buy()` 方法"或"`EconomyManager.spend` 的调用栈必须包含 `azhen_counter`"。

---

## D. 两方案冲突汇总（需裁决）

| 冲突点 | 主方案 | 独立方案 | 裁决要求 |
|---|---|---|---|
| 服装存储 | `WardrobeManager.owned` 为 `Dictionary` | 独立 `WardrobeManager`，不进背包 | 读现有 `owned` 类型 |
| 购买流程 | 货架 → 阿珍报价 → 试衣间 → 镜子确认 → 扣钱 | 挂架 → 拿衣 → 试衣间 → 镜子 → 柜台结账 | 两者流程相似，但主方案"镜子确认即扣钱"，独立方案"柜台才扣钱"——**独立方案更符合"实物驱动"** |
| 试衣反悔 | 退款 90%，扣好感 -1 | 免费，无惩罚 | **独立方案正确**，主方案违反温柔治愈 |
| 节日 ID | `spring_festival` | `city_festival_week` | 读节日系统 |
| 季节系统 | `SeasonManager.get_current_season()` | `TimeSystem.set_season()` | 读实际 API |
| 存档版本 | 新增 v15 | 不升版本 | 读迁移链 |
| 渲染 | 6 层 `Sprite2D` 叠加 | 未提 | 读 `player.gd` |
| 洗衣 | 未提 | `worn_count >= 3` 变脏 | 独立方案新增，需确认是否在范围内 |
| 回收 | 未提 | `chen` 回收 30% | 独立方案新增，与固定物价冲突 |

---

## E. 返工清单（按优先级）

**P0（阻塞，未完成不得写代码）**：
1. 跑 `grep -rn "WardrobeManager" scripts/ autoload/`，贴真实签名
2. 跑 `grep -rn "SeasonManager\|FestivalManager\|CareerManager\|EconomyManager\|WellbeingManager" autoload/`，确认存在性
3. 读 `save-001` 迁移链，贴当前版本号
4. 读 `player.gd`，确认渲染节点类型
5. 读节日系统，确认节日 ID 列表
6. 读 `world-001` 场景分区，确认 `store` / `home` / `fitting_room` 坐标

**P1（设计缺陷，必须修）**：
7. 主方案：删除试衣费与好感惩罚
8. 主方案：`rack_picker.gd` 的 `Sprite2D` 加碰撞体，或改 `TextureButton`
9. 主方案：`begin_purchase` 加 `pending_try_on` 非空检查
10. 主方案：`cl_azhen_gift` 加 `acquirable` 字段
11. 主方案：补货计时改 per-item
12. 独立方案：补全 `WardrobeManager` 方法签名
13. 独立方案：`REACTIONS` 统一为 CSV 驱动
14. 独立方案：定义 `_color_affinity` 或删除
15. 独立方案：实现 `full` slot 互斥
16. 独立方案：明确 `worn_count` 递增时机
17. 独立方案：删除或固定 `chen` 回收价

**P2（测试与文档）**：
18. 两方案测试改为可证伪断言，引用正文已定义 API
19. 主方案 §4.3 补全截断代码
20. 两方案统一节日 ID、季节 API、存档版本

**未完成 P0 前，两方案的 §2 / §3 / §4 全部视为不可执行。**

## 综合决策

# 《深日记》服装购买 / 试衣 / 穿搭 / 衣柜系统 —— 唯一可执行方案（终版）

> 综合裁决：以「场景实物 + NPC 驱动」为唯一购买路径，**禁止菜单直购**。融合主方案的数据层完整度与独立方案的"服装是穿戴态不是持有态"哲学，采纳批判 A/B 的全部 P0 阻塞项作为前置门禁，P1 设计缺陷全部修正，P2 测试改为可证伪断言。
>
> **本方案在门禁未通过前不得写任何业务代码。** 门禁结果写入 `docs/WARDROBE_FACTS.md`，作为本系统唯一事实源。

---

## 0. 前置门禁（阻塞性，未通过不得写代码）

### G0.1 `WardrobeManager` 真实接口
```bash
grep -rn "WardrobeManager" --include=*.gd scripts/ autoload/
grep -rn "\.owned" --include=*.gd . | grep -i wardrobe
ls autoload/ | grep -i wardrobe
```
**裁决**：
- 若 `autoload/wardrobe_manager.gd` 存在 → 记录全部 `func` 签名、`var` 字段、`signal`，**只做增量扩展，不重写**。
- 若不存在 → 本方案 §2 提供完整实现，并在 `project.godot` 注册 autoload。
- **必须记录 `owned` 的真实类型**（`Array` / `Dictionary` / `Array[String]`）。若为 `Array`，`from_save` 需做类型迁移（见 §2.4）。

### G0.2 服装店场景与交互物现状
```bash
grep -rn "clothing\|azhen\|服装" --include=*.gd --include=*.csv --include=*.tscn . | head -40
ls data/ | grep -i "shop\|scene"
grep -rn "scene_zones" --include=*.csv data/
```
**裁决**：
- 记录服装店场景 key。若不存在独立服装店场景 → **第一步是新增 `clothing_shop` 场景**，坐标避让 `scene_zones.csv` 已占用矩形。
- 记录 `azhen` 是否已在场景中实例化（`npcs.csv` 有记录 ≠ 场景有实体）。

### G0.3 玩家外观渲染管线
```bash
grep -rn "player_skin\|outfit\|sprite_frames\|AnimatedSprite2D\|Sprite2D" --include=*.gd scripts/gameplay/player.gd
```
**裁决**：
- 若玩家用 `Sprite2D` 单图 → 换装 = 换 `texture`，§4 按此实现。
- 若用 `AnimatedSprite2D` + `SpriteFrames` → 换装 = 换 `SpriteFrames` 资源，成本高，**降级为「仅 `outer` / `hat` / `accessory` 三层叠加」**，`top` / `bottom` / `shoes` 仅改变数值。在 FACTS 中明确标注降级。

### G0.4 季节 / 节日 / 职业 / 经济 / 好感系统接口
```bash
grep -rn "func get_current_season\|func set_season\|SeasonManager" --include=*.gd autoload/
grep -rn "func is_active\|FestivalManager\|festival" --include=*.gd --include=*.csv .
grep -rn "func get_rank\|CareerManager" --include=*.gd autoload/
grep -rn "func spend\|func earn\|func can_afford\|var money\|EconomyManager" --include=*.gd autoload/
grep -rn "func get_affinity\|func add_affinity\|var affinity\|RelationshipManager" --include=*.gd autoload/
grep -rn "func.*photo\|PhotoManager" --include=*.gd autoload/ scripts/
grep -rn "WellbeingManager\|func.*stamina\|func.*energy" --include=*.gd autoload/
```
**裁决**：记录每个系统的**唯一函数名**。本方案所有调用必须走该函数，**禁止直接读写字段**。若某系统不存在：
- 季节 → 降级为「按 `CalendarManager.month` 推断」（3-5 春 / 6-8 夏 / 9-11 秋 / 12-2 冬）
- 节日 → 降级为「按 `CalendarManager.event_flags` 推断」
- 职业 → 该解锁条件永久返回 `false`，并在 FACTS 标注
- 经济 → **阻塞**，必须存在
- 好感 → **阻塞**，必须存在

### G0.5 `ConfigDB` 读取语义
```bash
grep -rn "func get_row\|func get_rows\|DictReader\|split(\",\")" --include=*.gd autoload/ scripts/
```
**裁决**：确认列名读取还是索引读取；未知列是忽略还是报错；空值返回 `""` 还是 `null`。写入 FACTS 后再定 CSV schema。

### G0.6 存档迁移链
```bash
grep -rn "MIN_SUPPORTED_VERSION\|CURRENT_VERSION\|func migrate\|migration" --include=*.gd autoload/ scripts/
```
**裁决**：记录当前版本号与迁移函数签名。本方案新增迁移步骤的版本号以此为准。

### G0.7 `InventoryManager` 接口
```bash
grep -rn "hotbar\|backpack\|func add_item\|func has_item" --include=*.gd autoload/inventory_manager.gd
```
**裁决**：确认服装是否进背包。**本方案裁决：服装不进 `InventoryManager`**，理由：服装是"穿戴态"不是"持有态"，且需要 `acquired_day / worn_count / dirty` 三态，格位模型表达不了。在 FACTS 中写明此裁决及代码级证据（如 `add_item` 对 `slot` 类型的白名单）。

### G0.8 `world-001` 场景分区
```bash
grep -rn "interior\|isolation\|world_y\|street_door_pos" --include=*.gd --include=*.csv .
```
**裁决**：确认 `store` / `home` / `fitting_room` 的坐标与隔离区架构。若 `fitting_room` 作为独立 interior 场景，需确认 `world_y >= 3000` 隔离区是否存在。

---

## 1. 设计总纲（四条铁律）

1. **购买必须经过「实物 + NPC」**：玩家走到衣架前 → 点击衣架上的**实物衣物** → 阿珍走过来 → 玩家拿衣 → 走到试衣间 → 试穿 → 照镜子 → 满意则走到柜台 → 阿珍收钱。**任何情况下不出现「点击商品图标 → 直接扣钱」的路径。**
2. **试衣免费、拒绝无惩罚**：试穿不扣钱、不扣好感。这是温柔治愈的核心。反悔时衣物回到货架，阿珍说"没关系，再看看"。
3. **穿搭影响世界，但不显示数值**：`warmth` / `formality` 只参与计算，玩家只看到 NPC 反应、场景提示、体力恢复速率等**间接可感**的效果。**禁止任何 ProgressBar / 数值 Label 显示服装属性。**
4. **服装不进背包**：独立 `WardrobeManager`，避免挤爆 36 格背包。

---

## 2. 数据层

### 2.1 新建 `data/garments.csv`

| 字段 | 类型 | 说明 | 示例 |
|---|---|---|---|
| `garment_id` | string | 唯一 ID，前缀 `gm_` | `gm_linen_shirt` |
| `name` | string | 显示名 | `亚麻衬衫` |
| `description` | string | 描述 | `阿珍说这件最不挑人。` |
| `slot` | enum | `torso` / `legs` / `feet` / `head` / `neck` / `full` | `torso` |
| `kind` | enum | `casual` / `formal` / `work` / `festive` | `casual` |
| `price` | int | 固定售价（元） | `68` |
| `season` | enum | `spring` / `summer` / `autumn` / `winter` / `all` | `summer` |
| `warmth` | int | 保暖值，0 ~ 8，**不显示** | `2` |
| `formality` | int | 正式度，0 ~ 5，**不显示** | `3` |
| `color_tag` | string | 配色标签 | `beige` |
| `unlock_condition` | string | 解锁条件表达式 | `always` / `affinity:azhen>=6` / `event:city_festival_week` / `season:summer` / `career:factory>=2` |
| `unlock_hint` | string | 解锁提示（场景提示用） | `阿珍把一件羊毛外套从柜底翻出来。` |
| `acquire_method` | enum | `buy` / `gift` / `event` | `buy` |
| `shop_stock` | int | 初始库存，-1 为无限 | `3` |
| `restock_days` | int | 补货周期（天），-1 不补 | `7` |
| `npc_reaction_tag` | string | NPC 反应标签 | `fresh` / `warm` / `formal` / `festive` |
| `sprite_layer` | string | 对应玩家渲染层名 | `torso` |
| `texture_path` | string | 贴图路径 | `res://assets/art/clothing/gm_linen_shirt.png` |

**首批 14 件**：

| garment_id | name | slot | kind | price | season | warmth | formality | color_tag | unlock_condition | acquire_method | shop_stock | restock_days |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `gm_plain_tee` | 素色短袖 | torso | casual | 28 | summer | 1 | 1 | white | `always` | buy | -1 | -1 |
| `gm_linen_shirt` | 亚麻衬衫 | torso | casual | 68 | summer | 2 | 3 | beige | `always` | buy | 3 | 7 |
| `gm_grey_hoodie` | 灰卫衣 | torso | casual | 88 | autumn | 4 | 1 | grey | `always` | buy | -1 | -1 |
| `gm_wool_coat` | 羊毛外套 | torso | formal | 220 | winter | 7 | 5 | brown | `affinity:azhen>=6` | buy | 2 | -1 |
| `gm_denim_jacket` | 牛仔夹克 | torso | casual | 120 | spring | 3 | 2 | blue | `always` | buy | -1 | -1 |
| `gm_floral_dress` | 碎花连衣裙 | full | festive | 160 | summer | 2 | 4 | floral | `event:city_festival_week` | buy | 1 | -1 |
| `gm_jeans` | 牛仔裤 | legs | casual | 78 | all | 3 | 2 | blue | `always` | buy | -1 | -1 |
| `gm_slacks` | 西裤 | legs | formal | 110 | all | 2 | 5 | black | `always` | buy | -1 | -1 |
| `gm_pleat_skirt` | 百褶裙 | legs | formal | 95 | spring | 2 | 4 | navy | `always` | buy | -1 | -1 |
| `gm_canvas_shoes` | 帆布鞋 | feet | casual | 55 | all | 2 | 1 | white | `always` | buy | -1 | -1 |
| `gm_leather_shoes` | 皮鞋 | feet | formal | 180 | all | 3 | 5 | black | `affinity:azhen>=8` | buy | 2 | -1 |
| `gm_straw_hat` | 草帽 | head | casual | 42 | summer | 1 | 1 | straw | `season:summer` | buy | 5 | -1 |
| `gm_knit_scarf` | 针织围巾 | neck | casual | 65 | winter | 5 | 2 | red | `season:winter` | buy | 3 | -1 |
| `gm_work_apron` | 工作围裙 | full | work | 35 | all | 1 | 1 | blue | `career:factory>=2` | buy | -1 | -1 |
| `gm_azhen_gift` | 阿珍手作围裙 | torso | casual | 0 | all | 0 | 1 | floral | `affinity:azhen>=12` | **gift** | 0 | -1 |

> `gm_azhen_gift` 的 `acquire_method=gift`，`can_buy` 对其返回 `{ok:false, reason:"gift_only"}`，仅通过阿珍好感 12 赠送获得（见 §7.3）。

### 2.2 新建 `data/garment_sets.csv`

```csv
set_id,name,members,unlock_condition,effect_hint
set_work,上班装,"gm_work_apron,gm_jeans,gm_canvas_shoes",always,工厂里王师傅会多看你一眼。
set_weekend,周末装,"gm_grey_hoodie,gm_jeans,gm_canvas_shoes",always,街坊觉得你今天松弛。
set_festival,节日装,"gm_floral_dress,gm_leather_shoes",event:city_festival_week,阿榕会主动招呼你。
```

套装**不产生数值加成**，只改变 NPC 反应池与场景提示。

### 2.3 新建 `data/npc_outfit_reactions.csv`

```csv
npc_id,set_id,color_tag,formality_min,formality_max,line
azhen,set_work,,0,5,这身干活方便，我眼光没错吧。
azhen,,floral,0,5,碎花衬你，下次多进两条。
mei,set_weekend,,0,5,今天不上班？看着精神。
wang,set_work,,0,5,穿得像个干活的了。
lin,,blue,0,5,这颜色我也有件差不多的。
fangjie,,,4,5,今天这身，谈事正合适。
```

### 2.4 扩展 `WardrobeManager`（`autoload/wardrobe_manager.gd`）

```gdscript
extends Node

signal wardrobe_changed
signal outfit_changed(slot: String, garment_id: String)
signal garment_acquired(garment_id: String)

const SLOTS := ["torso", "legs", "feet", "head", "neck", "full"]
const FULL_SLOT := "full"
const FULL_EXCLUSIVE := ["torso", "legs"]

var catalog: Dictionary = {}          # garment_id -> 静态数据
var owned: Dictionary = {}            # garment_id -> {acquired_day:int, worn_count:int, dirty:bool}
var equipped: Dictionary = {}         # slot -> garment_id（"" 表示空）
var active_set: String = ""           # 最近一次整套穿上的 set_id
var pending_try_on: String = ""       # 待试衣的 garment_id
var pending_locked_stock: bool = false
var shop_stock: Dictionary = {}       # garment_id -> 剩余库存
var shop_last_restock: Dictionary = {} # garment_id -> 上次补货日
var npc_reaction_day: Dictionary = {} # npc_id -> 上次穿搭反应日
var reactions: Array = []             # 从 npc_outfit_reactions.csv 加载

func _ready() -> void:
    _load_catalog()
    _load_reactions()
    _init_equipped()
    _init_shop_stock()
    if TimeSystem.has_signal("day_started"):
        TimeSystem.day_started.connect(_on_day_started)

func _init_equipped() -> void:
    for slot in SLOTS:
        if not equipped.has(slot):
            equipped[slot] = ""

func _load_catalog() -> void:
    catalog.clear()
    for gid in ConfigDB.get_rows("garments"):
        var row: Dictionary = ConfigDB.get_row("garments", gid)
        catalog[gid] = {
            "id": gid,
            "name": str(row.get("name", gid)),
            "description": str(row.get("description", "")),
            "slot": str(row.get("slot", "torso")),
            "kind": str(row.get("kind", "casual")),
            "price": int(row.get("price", "0")),
            "season": str(row.get("season", "all")),
            "warmth": int(row.get("warmth", "0")),
            "formality": int(row.get("formality", "0")),
            "color_tag": str(row.get("color_tag", "")),
            "unlock_condition": str(row.get("unlock_condition", "always")),
            "unlock_hint": str(row.get("unlock_hint", "")),
            "acquire_method": str(row.get("acquire_method", "buy")),
            "shop_stock": int(row.get("shop_stock", "-1")),
            "restock_days": int(row.get("restock_days", "-1")),
            "npc_reaction_tag": str(row.get("npc_reaction_tag", "")),
            "sprite_layer": str(row.get("sprite_layer", "torso")),
            "texture_path": str(row.get("texture_path", "")),
        }

func _load_reactions() -> void:
    reactions.clear()
    for rid in ConfigDB.get_rows("npc_outfit_reactions"):
        reactions.append(ConfigDB.get_row("npc_outfit_reactions", rid))

func _init_shop_stock() -> void:
    shop_stock.clear()
    shop_last_restock.clear()
    for gid in catalog:
        shop_stock[gid] = int(catalog[gid]["shop_stock"])
        shop_last_restock[gid] = -1

# ---------- 解锁条件 ----------

func is_unlocked(garment_id: String) -> bool:
    if not catalog.has(garment_id):
        return false
    var cond := str(catalog[garment_id]["unlock_condition"])
    return _eval_condition(cond)

func _eval_condition(cond: String) -> bool:
    if cond == "always" or cond.is_empty():
        return true
    if cond.begins_with("affinity:"):
        var parts := cond.substr(9).split(">=")
        if parts.size() != 2: return false
        if not Engine.has_singleton("RelationshipManager"): 
            push_warning("RelationshipManager 缺失，affinity 条件降级为 false")
            return false
        return RelationshipManager.get_affinity(parts[0]) >= int(parts[1])
    if cond.begins_with("event:"):
        var event_id := cond.substr(6)
        if Engine.has_singleton("FestivalManager") and FestivalManager.has_method("is_active"):
            return FestivalManager.is_active(event_id)
        if Engine.has_singleton("CalendarManager") and CalendarManager.has_method("has_event"):
            return CalendarManager.has_event(event_id)
        push_warning("节日系统缺失，event 条件降级为 false")
        return false
    if cond.begins_with("season:"):
        var season := cond.substr(7)
        return _get_current_season() == season
    if cond.begins_with("career:"):
        var parts := cond.substr(7).split(">=")
        if parts.size() != 2: return false
        if not Engine.has_singleton("CareerManager"):
            push_warning("CareerManager 缺失，career 条件降级为 false")
            return false
        return CareerManager.get_rank(parts[0]) >= int(parts[1])
    push_error("未知解锁条件: %s" % cond)
    return false

func _get_current_season() -> String:
    if Engine.has_singleton("SeasonManager") and SeasonManager.has_method("get_current_season"):
        return str(SeasonManager.get_current_season())
    # 降级：按月份推断
    if Engine.has_singleton("CalendarManager") and CalendarManager.has_method("get_month"):
        var m := int(CalendarManager.get_month())
        if m >= 3 and m <= 5: return "spring"
        if m >= 6 and m <= 8: return "summer"
        if m >= 9 and m <= 11: return "autumn"
        return "winter"
    push_warning("季节系统缺失，默认返回 all")
    return "all"

# ---------- 库存 ----------

func get_stock(garment_id: String) -> int:
    return int(shop_stock.get(garment_id, 0))

func is_on_rack(garment_id: String) -> bool:
    if not catalog.has(garment_id):
        return false
    if not is_unlocked(garment_id):
        return false
    if str(catalog[garment_id]["acquire_method"]) != "buy":
        return false
    if get_stock(garment_id) == 0:
        return false
    return true

func can_buy(garment_id: String) -> Dictionary:
    if not catalog.has(garment_id):
        return {"ok": false, "reason": "unknown"}
    if str(catalog[garment_id]["acquire_method"]) != "buy":
        return {"ok": false, "reason": "gift_only"}
    if not is_unlocked(garment_id):
        return {"ok": false, "reason": "locked"}
    if get_stock(garment_id) == 0:
        return {"ok": false, "reason": "out_of_stock"}
    if owned.has(garment_id):
        return {"ok": false, "reason": "already_owned"}
    if not pending_try_on.is_empty():
        return {"ok": false, "reason": "busy"}
    var price := int(catalog[garment_id]["price"])
    if not EconomyManager.can_afford(price):
        return {"ok": false, "reason": "no_money"}
    return {"ok": true, "price": price}

# ---------- 购买状态机 ----------

func begin_purchase(garment_id: String) -> bool:
    if not pending_try_on.is_empty():
        push_warning("已有待试衣衣物: %s" % pending_try_on)
        return false
    var check := can_buy(garment_id)
    if not check["ok"]:
        return false
    pending_try_on = garment_id
    # 锁库存：试衣期间该件不可被其他路径购买
    if get_stock(garment_id) > 0:
        shop_stock[garment_id] = get_stock(garment_id) - 1
        pending_locked_stock = true
    return true

func confirm_purchase() -> bool:
    if pending_try_on.is_empty():
        return false
    var gid := pending_try_on
    var price := int(catalog[gid]["price"])
    if not EconomyManager.spend(price, "clothing:%s" % gid):
        # 扣钱失败，回滚库存
        _rollback_stock(gid)
        pending_try_on = ""
        pending_locked_stock = false
        return false
    owned[gid] = {"acquired_day": TimeSystem.current_day, "worn_count": 0, "dirty": false}
    pending_try_on = ""
    pending_locked_stock = false
    garment_acquired.emit(gid)
    wardrobe_changed.emit()
    return true

func cancel_purchase() -> void:
    if pending_try_on.is_empty():
        return
    var gid := pending_try_on
    _rollback_stock(gid)
    pending_try_on = ""
    pending_locked_stock = false

func _rollback_stock(garment_id: String) -> void:
    if not pending_locked_stock:
        return
    var max_stock := int(catalog[garment_id]["shop_stock"])
    if max_stock > 0:
        shop_stock[garment_id] = min(get_stock(garment_id) + 1, max_stock)

func force_clear_pending() -> void:
    if not pending_try_on.is_empty():
        _rollback_stock(pending_try_on)
    pending_try_on = ""
    pending_locked_stock = false

# ---------- 穿戴 ----------

func equip(garment_id: String) -> bool:
    if not owned.has(garment_id):
        return false
    var slot := str(catalog[garment_id]["slot"])
    var prev := str(equipped.get(slot, ""))
    if prev == garment_id:
        equipped[slot] = ""
        outfit_changed.emit(slot, "")
        wardrobe_changed.emit()
        return true
    # full slot 互斥
    if slot == FULL_SLOT:
        for ex in FULL_EXCLUSIVE:
            if str(equipped.get(ex, "")) != "":
                equipped[ex] = ""
                outfit_changed.emit(ex, "")
    elif slot in FULL_EXCLUSIVE:
        if str(equipped.get(FULL_SLOT, "")) != "":
            equipped[FULL_SLOT] = ""
            outfit_changed.emit(FULL_SLOT, "")
    equipped[slot] = garment_id
    active_set = ""  # 单件换装清空套装
    outfit_changed.emit(slot, garment_id)
    wardrobe_changed.emit()
    return true

func equip_set(set_id: String) -> bool:
    var set_data := _get_set(set_id)
    if set_data.is_empty():
        return false
    for gid in str(set_data["members"]).split(","):
        var trimmed := gid.strip_edges()
        if trimmed != "" and owned.has(trimmed):
            equip(trimmed)
    active_set = set_id
    wardrobe_changed.emit()
    return true

func _get_set(set_id: String) -> Dictionary:
    if not ConfigDB.has_row("garment_sets", set_id):
        return {}
    return ConfigDB.get_row("garment_sets", set_id)

# ---------- 数值查询（不显示） ----------

func get_warmth_score() -> int:
    var total := 0
    for slot in equipped:
        var gid := str(equipped[slot])
        if gid != "" and catalog.has(gid):
            total += int(catalog[gid]["warmth"])
    return total

func get_formality_score() -> int:
    var total := 0
    for slot in equipped:
        var gid := str(equipped[slot])
        if gid != "" and catalog.has(gid):
            total += int(catalog[gid]["formality"])
    return total

func get_dominant_color() -> String:
    var counts: Dictionary = {}
    for slot in equipped:
        var gid := str(equipped[slot])
        if gid != "" and catalog.has(gid):
            var c := str(catalog[gid]["color_tag"])
            if c != "":
                counts[c] = int(counts.get(c, 0)) + 1
    var best := ""
    var best_n := 0
    for c in counts:
        if int(counts[c]) > best_n:
            best_n = int(counts[c])
            best = c
    return best

func get_sorted_owned(slot: String) -> Array:
    var result: Array = []
    for gid in owned:
        if catalog.has(gid) and str(catalog[gid]["slot"]) == slot:
            result.append(gid)
    result.sort_custom(func(a, b):
        return int(owned[a]["acquired_day"]) > int(owned[b]["acquired_day"])
    )
    return result

# ---------- NPC 反应 ----------

func get_outfit_reaction(npc_id: String) -> String:
    var today := TimeSystem.current_day
    if int(npc_reaction_day.get(npc_id, -1)) == today:
        return ""
    var formality := get_formality_score()
    var color := get_dominant_color()
    var best_line := ""
    for r in reactions:
        if str(r.get("npc_id", "")) != npc_id:
            continue
        var set_id := str(r.get("set_id", ""))
        var color_tag := str(r.get("color_tag", ""))
        var fmin := int(r.get("formality_min", "0"))
        var fmax := int(r.get("formality_max", "5"))
        if set_id != "" and set_id != active_set:
            continue
        if color_tag != "" and color_tag != color:
            continue
        if formality < fmin or formality > fmax:
            continue
        best_line = str(r.get("line", ""))
        break
    if best_line != "":
        npc_reaction_day[npc_id] = today
    return best_line

# ---------- 每日结算 ----------

func _on_day_started(day_number: int) -> void:
    # worn_count 递增：当前穿着的衣物 +1
    for slot in equipped:
        var gid := str(equipped[slot])
        if gid != "" and owned.has(gid):
            owned[gid]["worn_count"] = int(owned[gid]["worn_count"]) + 1
            if int(owned[gid]["worn_count"]) >= 3:
                owned[gid]["dirty"] = true
    # 补货：per-item 计时
    for gid in catalog:
        var restock := int(catalog[gid]["restock_days"])
        if restock <= 0:
            continue
        var last := int(shop_last_restock.get(gid, -1))
        if last < 0:
            shop_last_restock[gid] = day_number
            continue
        if day_number - last >= restock:
            var max_stock := int(catalog[gid]["shop_stock"])
            if max_stock > 0 and get_stock(gid) < max_stock:
                shop_stock[gid] = max_stock  # 补满
            shop_last_restock[gid] = day_number
    wardrobe_changed.emit()

# ---------- 存档 ----------

func to_save() -> Dictionary:
    return {
        "owned": owned,
        "equipped": equipped,
        "active_set": active_set,
        "shop_stock": shop_stock,
        "shop_last_restock": shop_last_restock,
        "npc_reaction_day": npc_reaction_day,
    }

func from_save(data: Dictionary) -> void:
    var raw_owned = data.get("owned", {})
    # 兼容旧档：Array -> Dictionary
    if raw_owned is Array:
        var converted: Dictionary = {}
        for item in raw_owned:
            var gid := str(item)
            converted[gid] = {"acquired_day": 0, "worn_count": 0, "dirty": false}
        owned = converted
    else:
        owned = raw_owned
    equipped = data.get("equipped", {})
    _init_equipped()
    active_set = str(data.get("active_set", ""))
    shop_stock = data.get("shop_stock", {})
    shop_last_restock = data.get("shop_last_restock", {})
    npc_reaction_day = data.get("npc_reaction_day", {})
    if shop_stock.is_empty():
        _init_shop_stock()
    wardrobe_changed.emit()
```

**存档迁移**：`save-001` 的迁移链新增一步，调用 `WardrobeManager.from_save(data["wardrobe"])`。若旧档 `owned` 为 `Array`，`from_save` 内部自动转换。**不升版本号**（因为 `from_save` 兼容两种格式）。

---

## 3. 场景与交互物（实物驱动购买）

### 3.1 新建场景 `scenes/clothing_shop.tscn`

```
ClothingShop (Node2D)
├── Backdrop (AreaBackdrop, 1280×720)
├── PlayerSpawn (Marker2D, position=(200, 500))
├── Azhen (NpcActor, npc_id="azhen", position=(640, 380))
├── RackTorso (ClothingRack, position=(400, 300), rack_slot="torso")
├── RackLegs (ClothingRack, position=(520, 300), rack_slot="legs")
├── RackFeet (ClothingRack, position=(640, 300), rack_slot="feet")
├── RackHead (ClothingRack, position=(760, 300), rack_slot="head")
├── RackNeck (ClothingRack, position=(880, 300), rack_slot="neck")
├── RackFull (ClothingRack, position=(1000, 300), rack_slot="full")
├── FittingRoom (FittingRoom, position=(1000, 500))
├── Mirror (Mirror, position=(1050, 500))
├── Counter (AzhenCounter, position=(640, 520))
└── Exit (ShopExit, position=(100, 600))
```

### 3.2 新建 `scripts/gameplay/clothing_rack.gd`

**关键修正（批判 B1）**：货架上的衣物是**真实子节点**，`rack_picker` 只放大已有节点，不新建 Sprite。

```gdscript
class_name ClothingRack
extends WorldInteractable

@export var rack_slot: String = "torso"

var displayed_items: Array[String] = []
var _item_nodes: Dictionary = {}   # garment_id -> Sprite2D
var max_display := 4

func _ready() -> void:
    super._ready()
    add_to_group("clothing_rack")
    _refresh_display()
    WardrobeManager.wardrobe_changed.connect(_refresh_display)

func _refresh_display() -> void:
    displayed_items.clear()
    for gid in WardrobeManager.catalog:
        if displayed_items.size() >= max_display:
            break
        var c: Dictionary = WardrobeManager.catalog[gid]
        if str(c["slot"]) != rack_slot:
            continue
        if not WardrobeManager.is_on_rack(gid):
            continue
        displayed_items.append(gid)
    _rebuild_visual()

func _rebuild_visual() -> void:
    for node in _item_nodes.values():
        node.queue_free()
    _item_nodes.clear()
    for i in displayed_items.size():
        var gid := displayed_items[i]
        var spr := Sprite2D.new()
        spr.name = "Item_%s" % gid
        var path := str(WardrobeManager.catalog[gid]["texture_path"])
        if ResourceLoader.exists(path):
            spr.texture = load(path)
        else:
            push_warning("服装贴图缺失: %s" % path)
        spr.position = Vector2(i * 80 - (displayed_items.size() - 1) * 40, 0)
        spr.set_meta("garment_id", gid)
        add_child(spr)
        _item_nodes[gid] = spr

func on_tap() -> void:
    if displayed_items.is_empty():
        NoticeManager.show_scene_message("这个衣架空了，阿珍说下周会补货。", "服装店", "neutral")
        return
    # 互斥：已有 picker 打开则忽略
    if get_tree().get_first_node_in_group("rack_picker") != null:
        return
    var picker := preload("res://scripts/gameplay/rack_picker.gd").new()
    picker.name = "RackPicker"
    picker.add_to_group
