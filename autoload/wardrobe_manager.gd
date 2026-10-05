extends Node

## 服装购买与穿着。只表现生活状态，不做装备属性面板。

signal changed

var owned: Dictionary = {}
var wearing: Dictionary = {}

func _ready() -> void:
	reset_new_game()

func reset_new_game() -> void:
	owned.clear()
	wearing.clear()
	changed.emit()

func has_owned(clothing_id: String) -> bool:
	return bool(owned.get(clothing_id, false))

func buy(clothing_id: String) -> bool:
	var row := ConfigDB.get_row("clothing", clothing_id)
	if row.is_empty() or has_owned(clothing_id):
		return false
	var price := int(row.get("price", "0"))
	if not GameState.spend(price, "买下%s。" % str(row.get("name", clothing_id))):
		return false
	owned[clothing_id] = true
	wear(clothing_id, false)
	NoticeManager.show_message("%s买下了，穿上后生活里会有人注意到。" % str(row.get("name", clothing_id)), "positive")
	SaveManager.request_auto_save("clothing_buy")
	changed.emit()
	return true

func wear(clothing_id: String, show_notice: bool = true) -> bool:
	if not has_owned(clothing_id):
		return false
	var row := ConfigDB.get_row("clothing", clothing_id)
	if row.is_empty():
		return false
	var slot := str(row.get("slot", "top"))
	wearing[slot] = clothing_id
	if show_notice:
		NoticeManager.show_message("换上了%s。" % str(row.get("name", clothing_id)), "positive")
		SaveManager.request_auto_save("clothing_wear")
	changed.emit()
	return true

func is_wearing(clothing_id: String) -> bool:
	for slot in wearing:
		if str(wearing[slot]) == clothing_id:
			return true
	return false

func take_off(slot: String) -> bool:
	if not wearing.has(slot):
		return false
	wearing.erase(slot)
	SaveManager.request_auto_save("clothing_take_off")
	changed.emit()
	return true

func get_bonus(bonus_type: String) -> float:
	var total := 0.0
	for clothing_id in wearing:
		var row := ConfigDB.get_row("clothing", str(wearing[clothing_id]))
		if bonus_type == "social":
			total += float(row.get("social_bonus", "0"))
		elif bonus_type == "work":
			total += float(row.get("work_bonus", "0"))
	return total

func get_color(slot: String, fallback: Color = Color.WHITE) -> Color:
	if not wearing.has(slot):
		return fallback
	var row := ConfigDB.get_row("clothing", str(wearing[slot]))
	return Color.from_string(str(row.get("color", "")), fallback)

func get_outfit_summary() -> String:
	if wearing.is_empty():
		return "穿着普通旧衣，适合继续攒钱。"
	var names: Array[String] = []
	for slot in wearing:
		names.append(str(ConfigDB.get_row("clothing", str(wearing[slot])).get("name", wearing[slot])))
	return "当前穿着：" + "、".join(names)

func get_clothing_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for clothing_id in ConfigDB.get_rows("clothing"):
		var row := ConfigDB.get_row("clothing", clothing_id)
		var slot := str(row.get("slot", "top"))
		result.append({
			"id": str(clothing_id),
			"name": str(row.get("name", clothing_id)),
			"price": int(row.get("price", "0")),
			"slot": slot,
			"slot_name": "上衣" if slot == "top" else ("帽子" if slot == "hat" else "鞋"),
			"color": str(row.get("color", "#ffffff")),
			"social_bonus": float(row.get("social_bonus", "0")),
			"work_bonus": float(row.get("work_bonus", "0")),
			"description": str(row.get("description", "")),
			"owned": has_owned(str(clothing_id)),
			"wearing": str(wearing.get(slot, "")) == str(clothing_id),
		})
	return result

func get_save_data() -> Dictionary:
	return {"owned": owned.duplicate(true), "wearing": wearing.duplicate(true)}

func restore(data: Dictionary) -> void:
	owned = data.get("owned", {}).duplicate(true)
	wearing = data.get("wearing", {}).duplicate(true)
	changed.emit()
