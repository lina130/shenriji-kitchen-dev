class_name CityLifeState
extends RefCounted

const SAVE_PATH := "user://city3d_preview.json"
const MAX_ENERGY := 100
const SHIFT_ENERGY := {"relaxed": 18, "rush": 42}

var day := 1
var cash := 120
var energy := MAX_ENERGY
var items: Array[Dictionary] = []
var discovered: Dictionary = {}
var found_secrets: Dictionary = {}
var career_shifts: Dictionary = {}
var active_shift: Dictionary = {}
var player_position := Vector3(-1.8, 0.5, 0.6)

func can_start_shift(mode: String) -> bool:
	return SHIFT_ENERGY.has(mode) and energy >= int(SHIFT_ENERGY[mode])

func begin_shift(mode: String) -> bool:
	if not can_start_shift(mode):
		return false
	energy -= int(SHIFT_ENERGY[mode])
	return true

func finish_shift(career: String, mode: String, correct: int, total: int) -> int:
	if not SHIFT_ENERGY.has(mode) or total <= 0:
		return 0
	var per_order := 18 if mode == "relaxed" else 37
	var bonus := 10 if mode == "relaxed" else 55
	var earned := correct * per_order + (bonus if correct == total else 0)
	cash += earned
	career_shifts[career] = int(career_shifts.get(career, 0)) + 1
	return earned

func discover_neighbor_memento() -> Dictionary:
	# A quiet one-time story beat from getting to know the old street.
	# The player is never directed to a cache or given a repeatable loot action.
	if found_secrets.has("nantou_neighbor") or day < 2 or int(career_shifts.get("restaurant", 0)) < 2:
		return {}
	found_secrets["nantou_neighbor"] = true
	var item := {
		"id": "nantou_neighbor_memento", "site": "nantou",
		"name": "老巷电影票册", "rarity": "rare", "value": 420
	}
	items.append(item)
	discovered[item["name"]] = true
	return item

func sell_item(index: int) -> int:
	if index < 0 or index >= items.size():
		return 0
	var value := int(items[index].get("value", 0))
	cash += value
	items.remove_at(index)
	return value

func spend_cash(amount: int) -> bool:
	if amount < 0 or cash < amount:
		return false
	cash -= amount
	return true

func rest_day() -> void:
	day += 1
	energy = MAX_ENERGY

func save_to_disk(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save city life preview: %s" % path)
		return false
	file.store_string(JSON.stringify({
		"version": 1, "day": day, "cash": cash, "energy": energy,
		"items": items, "discovered": discovered,
		"found_secrets": found_secrets, "career_shifts": career_shifts,
		"active_shift": active_shift,
		"player_position": [player_position.x, player_position.y, player_position.z]
	}))
	return true

func load_from_disk(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var decoded = JSON.parse_string(file.get_as_text())
	if not decoded is Dictionary or int(decoded.get("version", 0)) != 1:
		return false
	day = maxi(1, int(decoded.get("day", 1)))
	cash = maxi(0, int(decoded.get("cash", 120)))
	energy = clampi(int(decoded.get("energy", MAX_ENERGY)), 0, MAX_ENERGY)
	items.clear()
	for entry in decoded.get("items", []):
		if entry is Dictionary and entry.has("name") and entry.has("value"):
			items.append(entry)
	discovered = decoded.get("discovered", {}) if decoded.get("discovered", {}) is Dictionary else {}
	found_secrets = decoded.get("found_secrets", {}) if decoded.get("found_secrets", {}) is Dictionary else {}
	# Older preview saves could obtain this same item from a daily cache.
	# Honor that discovery so a one-time keepsake cannot be awarded twice.
	if discovered.has("老巷电影票册"):
		found_secrets["nantou_neighbor"] = true
	career_shifts = decoded.get("career_shifts", {}) if decoded.get("career_shifts", {}) is Dictionary else {}
	active_shift = decoded.get("active_shift", {}) if decoded.get("active_shift", {}) is Dictionary else {}
	var position_data = decoded.get("player_position", [])
	if position_data is Array and position_data.size() == 3:
		player_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	return true
