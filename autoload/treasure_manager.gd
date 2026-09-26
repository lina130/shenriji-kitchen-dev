extends Node

## 摸金彩蛋系统
## 不再把旧物洒满地图或单独开一个摸金场景。
## 只在日常动作（出餐、卖货、上班、街上闲逛、旧巷探索）里
## 低概率地触发一次“偶然发现”，带有独立的叙事文案。

signal treasure_found(item_id: String, rarity: String, context_id: String)

const TRIGGER_RULES := {
	"serve_dish": {"chance": 0.016, "cooldown": 90.0, "texts": [
		"收拾桌子时，你在椅子缝里摸到一件东西。",
		"餐盘下压着一件不知道谁落下的旧物。",
		"收档时，柜台背面滚出一小件东西。",
	]},
	"sell_goods": {"chance": 0.014, "cooldown": 90.0, "texts": [
		"对账时，你发现货箱底压着一件旧物。",
		"批发档口的旧木板下面，多出了一件东西。",
	]},
	"work_shift": {"chance": 0.012, "cooldown": 150.0, "texts": [
		"下班前打扫工位，你在机柜底下发现一件旧物。",
		"老工人挪开柜子，里面留下一件旧东西。",
	]},
	"walk": {"chance": 0.05, "cooldown": 5.0, "texts": [
		"你走在街上，眼角扫到路边一小块反光的东西。",
		"路过老城墙时，你蹲下去拨开了一些碎石。",
		"树根缝里卡着一件时间久了的旧物。",
		"雨后的石板路上，一件东西被水冲了出来。",
	]},
	"ruins": {"chance": 0.16, "cooldown": 18.0, "texts": [
		"灯光扫过断墙，你看见一件旧物的轮廓。",
		"脚下踩到一块松动的砖，下面压着一件东西。",
	]},
}

var last_trigger_at: Dictionary = {}
var _found_today := 0

func _ready() -> void:
	TimeSystem.day_started.connect(_on_day_started)

func try_trigger(context_id: String, chance_multiplier: float = 1.0) -> String:
	return try_trigger_at(context_id, Vector2.ZERO, "", chance_multiplier)

func try_trigger_at(context_id: String, world_position: Vector2, area_id: String = "", chance_multiplier: float = 1.0) -> String:
	var rule: Dictionary = TRIGGER_RULES.get(context_id, {})
	if rule.is_empty():
		return ""
	if _found_today >= 2:
		return ""
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := float(rule.get("cooldown", 60.0))
	if now - float(last_trigger_at.get(context_id, -9999.0)) < cooldown:
		return ""
	var chance := float(rule.get("chance", 0.0)) * maxf(0.1, chance_multiplier)
	if context_id != "ruins":
		chance *= _activity_multiplier()
	if RandomManager.rng.randf() > chance:
		return ""
	return _reveal(context_id, world_position, area_id, rule)

func force_find(area_id: String = "street", rarity: String = "") -> String:
	## 仅有测试与调试会用到：清掉每日上限与冷却，便于重复触发。
	clear_daily_limit()
	var rule: Dictionary = TRIGGER_RULES.get("walk", {})
	return _reveal("walk", Vector2.ZERO, area_id, rule, rarity)

func clear_daily_limit() -> void:
	_found_today = 0
	last_trigger_at.clear()

## 测试用：必定摸到一件，但仍受当日上限与冷却约束。
func force_find_once(area_id: String = "street") -> String:
	var context_id := "ruins" if area_id == "ruins" else "walk"
	var rule: Dictionary = TRIGGER_RULES.get(context_id, {})
	return _reveal(context_id, Vector2.ZERO, area_id, rule)

func _activity_multiplier() -> float:
	var multiplier := 1.0 + CalendarManager.get_collection_bonus()
	var period := TimeSystem.get_period_name()
	if period == "夜晚" or period == "深夜":
		multiplier += 0.35
	multiplier += GameState.get_collection_luck_bonus()
	return multiplier

func _reveal(context_id: String, _world_position: Vector2, _area_id: String, rule: Dictionary, forced_rarity: String = "") -> String:
	var rarity := forced_rarity if not forced_rarity.is_empty() else _roll_rarity(context_id)
	var item_id := _pick_uncollected_item(rarity)
	if item_id.is_empty():
		item_id = _pick_uncollected_item("")
	if item_id.is_empty():
		item_id = _pick_item_for_rarity(rarity)
	if item_id.is_empty():
		item_id = _pick_any_item()
	if item_id.is_empty():
		return ""
	var item := InventoryManager.get_item(item_id)
	InventoryManager.add_item(item_id, 1)
	CollectionManager.discovered[item_id] = true
	GameState.on_collection_collected(item_id, rarity)
	CollectionManager.changed.emit()
	_found_today += 1
	last_trigger_at[context_id] = Time.get_ticks_msec() / 1000.0
	var texts: Array = rule.get("texts", [])
	var flavor := str(RandomManager.pick(texts)) if not texts.is_empty() else "你偶然发现一件旧物。"
	var rarity_name := CollectionManager.get_rarity_name(rarity)
	var suffix := "！" if rarity == "legendary" else "。"
	NoticeManager.show_message("%s摸到【%s】（%s）%s" % [flavor, item.get("name", item_id), rarity_name, suffix], "positive")
	treasure_found.emit(item_id, rarity, context_id)
	return item_id

func _roll_rarity(context_id: String) -> String:
	var luck := GameState.get_collection_luck_bonus() + CalendarManager.get_collection_bonus() + WeatherSystem.get_collection_bonus()
	var legendary := 1.2 * (1.0 + luck)
	var rare := legendary + 6.0 * (1.0 + luck * 0.5)
	var uncommon := rare + 22.0
	if context_id == "ruins":
		legendary *= 1.8
		rare *= 1.3
	else:
		legendary *= 0.55
		rare *= 0.7
	var roll := RandomManager.rng.randf() * 100.0
	if roll < legendary:
		return "legendary"
	if roll < rare:
		return "rare"
	if roll < uncommon:
		return "uncommon"
	return "common"

func _pick_uncollected_item(rarity: String) -> String:
	var candidates: Array[String] = []
	for row_key in ConfigDB.get_rows("collectibles"):
		if not rarity.is_empty() and str(ConfigDB.get_row("collectibles", row_key).get("rarity", "common")) != rarity:
			continue
		if bool(CollectionManager.discovered.get(row_key, false)):
			continue
		if InventoryManager.get_count(row_key) > 0:
			continue
		candidates.append(row_key)
	if candidates.is_empty():
		return ""
	return str(RandomManager.pick(candidates))

func _pick_any_item() -> String:
	var ids := ConfigDB.get_rows("collectibles").keys()
	if ids.is_empty():
		return ""
	return str(RandomManager.pick(ids))

func _pick_item_for_rarity(rarity: String) -> String:
	var candidates: Array[String] = []
	for row_key in ConfigDB.get_rows("collectibles"):
		if str(ConfigDB.get_row("collectibles", row_key).get("rarity", "common")) == rarity:
			candidates.append(row_key)
	if candidates.is_empty():
		return ""
	return str(RandomManager.pick(candidates))

func get_today_count() -> int:
	return _found_today

func get_hint() -> String:
	return "旧物难得碰见，它们藏在平常的一天里。"

func _on_day_started(_day_number: int) -> void:
	_found_today = 0

func get_save_data() -> Dictionary:
	return {"last_trigger_at": last_trigger_at.duplicate(true), "found_today": _found_today}

func restore(data: Dictionary) -> void:
	last_trigger_at = data.get("last_trigger_at", {}).duplicate(true)
	_found_today = int(data.get("found_today", 0))

func reset_new_game() -> void:
	last_trigger_at.clear()
	_found_today = 0
