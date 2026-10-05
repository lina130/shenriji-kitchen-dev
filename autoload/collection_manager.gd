extends Node

signal changed
signal item_collected(item_id: String, rarity: String)

const RARITY_NAMES := {
	"common": "普通",
	"uncommon": "少见",
	"rare": "稀有",
	"legendary": "传说",
}
const RARITY_WEIGHTS := {
	"common": 60.0,
	"uncommon": 25.0,
	"rare": 12.0,
	"legendary": 3.0,
}
const AREA_POINTS := {
	"street": [
		Vector2(330, 275), Vector2(600, 620), Vector2(860, 310),
		Vector2(350, 615), Vector2(1120, 420), Vector2(730, 320),
	],
	"recycle": [
		Vector2(180, 180), Vector2(970, 220), Vector2(620, 300),
		Vector2(280, 520), Vector2(900, 520),
	],
	"market": [
		Vector2(280, 280), Vector2(560, 380), Vector2(860, 260),
		Vector2(1010, 500), Vector2(460, 520),
	],
}

var daily_spawns: Dictionary = {}
var discovered: Dictionary = {}
var seen_items: Dictionary = {}
var seen_recipes: Dictionary = {}
var seen_areas: Dictionary = {}
var seen_careers: Dictionary = {}
var total_collected := 0
var daily_collected := 0

func refresh_for_day(_day_number: int) -> void:
	## 摸金改为彩蛋式偶遇，由 TreasureManager 掌管，地图上不再固定刷新旧物点。
	daily_spawns.clear()
	daily_collected = 0
	changed.emit()

func get_area_spawns(_area_id: String) -> Array:
	return []

func collect_spawn(_area_id: String, _spawn_id: String) -> bool:
	return false

func sell_collectible(item_id: String) -> bool:
	var item := InventoryManager.get_item(item_id)
	if item.is_empty() or str(item.get("category", "")) != "collectible":
		return false
	if not InventoryManager.remove_item(item_id, 1):
		return false
	var price := int(item.get("sell_price", 0))
	GameState.earn(price, "%s换成了 ¥%d，钱不多，但日子能松一点。" % [item.get("name", item_id), price])
	return true

func record_item_seen(item_id: String) -> void:
	if item_id.is_empty() or seen_items.has(item_id):
		return
	seen_items[item_id] = true
	changed.emit()

func record_recipe_seen(recipe_id: String) -> void:
	if recipe_id.is_empty() or seen_recipes.has(recipe_id):
		return
	seen_recipes[recipe_id] = true
	changed.emit()

func record_area_visited(area_id: String) -> void:
	if area_id.is_empty() or seen_areas.has(area_id):
		return
	seen_areas[area_id] = true
	changed.emit()

func record_career_seen(line_id: String) -> void:
	if line_id.is_empty() or seen_careers.has(line_id):
		return
	seen_careers[line_id] = true
	changed.emit()

func has_seen_item(item_id: String) -> bool:
	return seen_items.has(item_id) or InventoryManager.get_count(item_id) > 0

func has_seen_recipe(recipe_id: String) -> bool:
	return seen_recipes.has(recipe_id)

func has_seen_area(area_id: String) -> bool:
	return seen_areas.has(area_id) or GameState.current_area == area_id

func has_seen_career(line_id: String) -> bool:
	return seen_careers.has(line_id) or CareerManager.current_line == line_id

func get_log_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item_id in discovered:
		var item := InventoryManager.get_item(item_id)
		if not item.is_empty():
			entries.append(item)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _rarity_order(str(a.get("rarity", "common"))) < _rarity_order(str(b.get("rarity", "common")))
	)
	return entries

func get_rarity_name(rarity: String) -> String:
	return RARITY_NAMES.get(rarity, rarity)

func get_save_data() -> Dictionary:
	return {
		"discovered": discovered.duplicate(true),
		"seen_items": seen_items.duplicate(true),
		"seen_recipes": seen_recipes.duplicate(true),
		"seen_areas": seen_areas.duplicate(true),
		"seen_careers": seen_careers.duplicate(true),
		"total_collected": total_collected,
		"daily_collected": daily_collected,
	}

func restore(data: Dictionary) -> void:
	daily_spawns.clear()
	discovered = data.get("discovered", {}).duplicate(true)
	seen_items = data.get("seen_items", {}).duplicate(true)
	seen_recipes = data.get("seen_recipes", {}).duplicate(true)
	seen_areas = data.get("seen_areas", {}).duplicate(true)
	seen_careers = data.get("seen_careers", {}).duplicate(true)
	total_collected = int(data.get("total_collected", 0))
	daily_collected = int(data.get("daily_collected", 0))
	changed.emit()

func reset_new_game() -> void:
	daily_spawns.clear()
	discovered.clear()
	seen_items.clear()
	seen_recipes.clear()
	seen_areas.clear()
	seen_careers.clear()
	total_collected = 0
	daily_collected = 0
	changed.emit()

func _roll_rarity() -> String:
	var luck_bonus := GameState.get_collection_luck_bonus() + CalendarManager.get_collection_bonus()
	var roll := RandomManager.rng.randf() * 100.0
	var legendary_threshold := RARITY_WEIGHTS["legendary"] * (1.0 + luck_bonus)
	var rare_threshold := legendary_threshold + RARITY_WEIGHTS["rare"] * (1.0 + luck_bonus * 0.65)
	var uncommon_threshold := rare_threshold + RARITY_WEIGHTS["uncommon"]
	if roll < legendary_threshold:
		return "legendary"
	if roll < rare_threshold:
		return "rare"
	if roll < uncommon_threshold:
		return "uncommon"
	return "common"

func _pick_item_for_rarity(rarity: String) -> String:
	var candidates: Array[String] = []
	for row_key in ConfigDB.get_rows("collectibles"):
		var row: Dictionary = ConfigDB.get_row("collectibles", row_key)
		if str(row.get("rarity", "common")) == rarity:
			candidates.append(row_key)
	if candidates.is_empty():
		return ""
	return str(RandomManager.pick(candidates))

func _rarity_order(rarity: String) -> int:
	match rarity:
		"legendary":
			return 0
		"rare":
			return 1
		"uncommon":
			return 2
		_:
			return 3