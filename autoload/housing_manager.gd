extends Node

signal changed

var current_tier := 0

func reset_new_game() -> void:
	current_tier = 0
	_sync_rent()
	changed.emit()

func get_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for housing_id in ConfigDB.get_rows("housing"):
		var row := ConfigDB.get_row("housing", housing_id)
		result.append({
			"id": str(housing_id),
			"tier": int(row.get("tier", "0")),
			"name": str(row.get("name", housing_id)),
			"price": int(row.get("price", "0")),
			"rent": int(row.get("rent", "800")),
			"description": str(row.get("description", "")),
			"current": int(row.get("tier", "0")) == current_tier,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["tier"]) < int(b["tier"]))
	return result

func can_upgrade(housing_id: String) -> bool:
	var row := ConfigDB.get_row("housing", housing_id)
	if row.is_empty():
		return false
	return int(row.get("tier", "0")) == current_tier + 1

func upgrade(housing_id: String) -> bool:
	var row := ConfigDB.get_row("housing", housing_id)
	if row.is_empty():
		return false
	var tier := int(row.get("tier", "0"))
	if tier <= current_tier:
		NoticeManager.show_message("现在住的地方已经不比这里差了。", "hint", "方姐")
		return false
	if tier > current_tier + 1:
		NoticeManager.show_message("先从更近的一档住起，别一下把生活压得太紧。", "hint", "方姐")
		return false
	var price := int(row.get("price", "0"))
	if not GameState.spend(price, "搬去%s，先付了搬家和新租约的钱。" % str(row.get("name", housing_id))):
		return false
	current_tier = tier
	_sync_rent()
	NoticeManager.show_message("租约办好了，搬进%s。房租每月 ¥%d，通了勤再回来看我。" % [str(row.get("name", housing_id)), int(row.get("rent", "800"))], "positive", "方姐")
	SaveManager.request_auto_save("housing_upgrade")
	changed.emit()
	return true

func get_bonus(bonus_type: String) -> float:
	var row := get_current_row()
	if row.is_empty():
		return 0.0
	match bonus_type:
		"energy":
			return float(row.get("energy_bonus", "0"))
		"study":
			return float(row.get("study_bonus", "0"))
		"relax":
			return float(row.get("relax_bonus", "0"))
	return 0.0

func get_summary() -> String:
	var row := get_current_row()
	if row.is_empty():
		return "住在城中村单间。"
	return "住在%s · 每月房租 ¥%d" % [str(row.get("name", "城中村单间")), int(row.get("rent", "800"))]

func get_current_row() -> Dictionary:
	for housing_id in ConfigDB.get_rows("housing"):
		var row := ConfigDB.get_row("housing", housing_id)
		if int(row.get("tier", "0")) == current_tier:
			return row
	return {}

func _sync_rent() -> void:
	var row := get_current_row()
	if not row.is_empty():
		GameState.rent_amount = int(row.get("rent", "800"))

func get_save_data() -> Dictionary:
	return {"current_tier": current_tier}

func restore(data: Dictionary) -> void:
	current_tier = int(data.get("current_tier", 0))
	_sync_rent()
	changed.emit()
