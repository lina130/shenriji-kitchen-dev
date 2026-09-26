extends Node

signal changed

var ITEMS: Dictionary = {}
var items: Dictionary = {}

func _ready() -> void:
	_load_catalog()

func _load_catalog() -> void:
	ITEMS.clear()
	for item_id in ConfigDB.get_rows("items"):
		var row: Dictionary = ConfigDB.get_row("items", item_id)
		ITEMS[item_id] = {
			"id": item_id,
			"name": str(row.get("name", item_id)),
			"description": str(row.get("description", "")),
			"kind": str(row.get("kind", "misc")),
			"category": "consumable",
			"price": int(row.get("price", "0")),
			"usable": str(row.get("usable", "false")).to_lower() == "true",
			"energy": float(row.get("energy", "0")),
			"rarity": "common",
			"sell_price": 0,
			"gift_npc": "",
			"displayable": false,
		}
	for item_id in ConfigDB.get_rows("collectibles"):
		var row: Dictionary = ConfigDB.get_row("collectibles", item_id)
		ITEMS[item_id] = {
			"id": item_id,
			"name": str(row.get("name", item_id)),
			"description": str(row.get("description", "")),
			"kind": "collectible",
			"category": "collectible",
			"price": 0,
			"usable": float(row.get("energy", "0")) > 0.0,
			"energy": float(row.get("energy", "0")),
			"rarity": str(row.get("rarity", "common")),
			"sell_price": int(row.get("sell_price", "0")),
			"gift_npc": str(row.get("gift_npc", "")),
			"displayable": str(row.get("displayable", "false")).to_lower() == "true",
			"market_category": str(row.get("market_category", "daily")),
		}

func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

func add_item(item_id: String, amount: int = 1) -> void:
	if not ITEMS.has(item_id) or amount <= 0:
		return
	items[item_id] = int(items.get(item_id, 0)) + amount
	changed.emit()

func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_count(item_id) < amount:
		return false
	var remaining := get_count(item_id) - amount
	if remaining <= 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining
	changed.emit()
	return true

func get_count(item_id: String) -> int:
	return int(items.get(item_id, 0))

func use_item(item_id: String) -> bool:
	var item := get_item(item_id)
	if item.is_empty() or not bool(item.get("usable", false)):
		return false
	if str(item.get("category", "")) == "collectible":
		return false
	if not remove_item(item_id, 1):
		return false
	GameState.on_item_used(item)
	return true

func get_inventory_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in items:
		if get_count(item_id) <= 0:
			continue
		var item: Dictionary = get_item(item_id)
		result.append({
			"id": item_id,
			"name": item.get("name", item_id),
			"description": item.get("description", ""),
			"count": get_count(item_id),
			"usable": bool(item.get("usable", false)),
			"category": item.get("category", "consumable"),
			"rarity": item.get("rarity", "common"),
			"sell_price": int(item.get("sell_price", 0)),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_collectible: bool = a.get("category") == "collectible"
		var b_collectible: bool = b.get("category") == "collectible"
		if a_collectible != b_collectible:
			return not a_collectible
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result

func get_giftable_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in get_inventory_lines():
		if str(entry.get("category", "")) == "collectible":
			result.append(entry)
	return result

func get_save_data() -> Dictionary:
	return {"items": items.duplicate(true)}

func restore(data: Dictionary) -> void:
	items.clear()
	var saved_items: Dictionary = data.get("items", {})
	for item_id in saved_items:
		if ITEMS.has(item_id):
			items[item_id] = maxi(0, int(saved_items[item_id]))
	changed.emit()

func reset_new_game() -> void:
	items.clear()
	changed.emit()