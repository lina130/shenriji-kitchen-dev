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
var total_collected := 0
var daily_collected := 0

func refresh_for_day(day_number: int) -> void:
	daily_spawns.clear()
	daily_collected = 0
	var roll_index := 0
	for area_id in AREA_POINTS:
		var area_spawns: Array = []
		for point in AREA_POINTS[area_id]:
			var rarity := _roll_rarity()
			var item_id := _pick_item_for_rarity(rarity)
			if item_id.is_empty():
				continue
			area_spawns.append({
				"spawn_id": "%s_%d_%d_%d" % [area_id, day_number, roll_index, int(point.x)],
				"item_id": item_id,
				"rarity": rarity,
				"position": point,
				"collected": false,
			})
			roll_index += 1
		daily_spawns[area_id] = area_spawns
	changed.emit()

func get_area_spawns(area_id: String) -> Array:
	var result: Array = []
	for spawn in daily_spawns.get(area_id, []):
		if not bool(spawn.get("collected", false)):
			result.append(spawn)
	return result

func collect_spawn(area_id: String, spawn_id: String) -> bool:
	var spawns: Array = daily_spawns.get(area_id, [])
	for spawn in spawns:
		if str(spawn.get("spawn_id", "")) != spawn_id or bool(spawn.get("collected", false)):
			continue
		var energy_cost := ConfigDB.get_number("balance", "collection_energy_cost", 2.0)
		if GameState.energy < energy_cost:
			NoticeManager.show_message("现在连弯腰翻找的力气都没有了。", "warning")
			return false
		GameState.change_energy(-energy_cost)
		spawn["collected"] = true
		var item_id := str(spawn.get("item_id", ""))
		var rarity := str(spawn.get("rarity", "common"))
		InventoryManager.add_item(item_id, 1)
		discovered[item_id] = true
		total_collected += 1
		daily_collected += 1
		GameState.on_collection_collected(item_id, rarity)
		item_collected.emit(item_id, rarity)
		changed.emit()
		return true
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
		"daily_spawns": _serialize_spawns(),
		"discovered": discovered.duplicate(true),
		"total_collected": total_collected,
		"daily_collected": daily_collected,
	}

func restore(data: Dictionary) -> void:
	daily_spawns = _deserialize_spawns(data.get("daily_spawns", {}))
	discovered = data.get("discovered", {}).duplicate(true)
	total_collected = int(data.get("total_collected", 0))
	daily_collected = int(data.get("daily_collected", 0))
	changed.emit()


func _serialize_spawns() -> Dictionary:
	var result: Dictionary = {}
	for area_id in daily_spawns:
		var serialized_area: Array = []
		for spawn in daily_spawns[area_id]:
			var copy: Dictionary = spawn.duplicate(true)
			var point: Vector2 = copy.get("position", Vector2.ZERO)
			copy["position"] = {"x": point.x, "y": point.y}
			serialized_area.append(copy)
		result[area_id] = serialized_area
	return result

func _deserialize_spawns(saved: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for area_id in saved:
		var restored_area: Array = []
		for saved_spawn in saved[area_id]:
			var spawn: Dictionary = saved_spawn.duplicate(true)
			var raw_position = spawn.get("position", {"x": 0.0, "y": 0.0})
			if typeof(raw_position) == TYPE_DICTIONARY:
				spawn["position"] = Vector2(float(raw_position.get("x", 0.0)), float(raw_position.get("y", 0.0)))
			else:
				spawn["position"] = Vector2.ZERO
			restored_area.append(spawn)
		result[area_id] = restored_area
	return result
func reset_new_game() -> void:
	daily_spawns.clear()
	discovered.clear()
	total_collected = 0
	daily_collected = 0
	refresh_for_day(TimeSystem.current_day)

func _roll_rarity() -> String:
	var luck_bonus := GameState.get_collection_luck_bonus()
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