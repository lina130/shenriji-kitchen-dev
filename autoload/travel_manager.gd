extends Node

signal changed
signal traveled(destination_id: String)

var visited: Dictionary = {}
var postcards: Dictionary = {}

func reset_new_game() -> void:
	visited.clear()
	postcards.clear()
	changed.emit()

func can_travel(destination_id: String) -> bool:
	var row := ConfigDB.get_row("travel_destinations", destination_id)
	if row.is_empty():
		return false
	return TimeSystem.current_day >= int(row.get("min_day", "1"))

func travel_to(destination_id: String) -> bool:
	var row := ConfigDB.get_row("travel_destinations", destination_id)
	if row.is_empty():
		return false
	if not can_travel(destination_id):
		NoticeManager.show_message("这趟线路还没开放，先在城市里站稳脚跟。", "hint", "巴士站售票员")
		return false
	var cost := int(row.get("travel_cost", "0"))
	var energy_cost := float(row.get("energy_cost", "0"))
	if GameState.energy < energy_cost:
		NoticeManager.show_message("今天体力不够，先休息再出发。", "warning", "巴士站售票员")
		return false
	if not GameState.spend(cost, "买去%s的车票。" % str(row.get("name", destination_id))):
		return false
	GameState.change_energy(-energy_cost)
	TimeSystem.advance_minutes(int(row.get("travel_minutes", "360")))
	visited[destination_id] = int(visited.get(destination_id, 0)) + 1
	SaveManager.request_auto_save("travel")
	traveled.emit(destination_id)
	changed.emit()
	SceneRouter.travel_to(str(row.get("scene_id", destination_id)), "entrance")
	return true

func collect_postcard(destination_id: String) -> bool:
	if not visited.has(destination_id):
		NoticeManager.show_message("先真正去过那里，才能把照片放进旅行册。", "hint", "旅行摄影师")
		return false
	if postcards.has(destination_id):
		NoticeManager.show_message("这张风景照已经收进旅行册了。", "hint", "旅行摄影师")
		return false
	postcards[destination_id] = true
	GameState.hidden_luck = minf(100.0, GameState.hidden_luck + 2.0)
	NoticeManager.show_message("拍下了一张%s的照片，旅行见闻又多了一页。" % destination_id, "positive", "旅行摄影师")
	SaveManager.request_auto_save("travel_postcard")
	changed.emit()
	return true

func rest_at_destination(destination_id: String) -> bool:
	if not visited.has(destination_id):
		return false
	GameState.change_energy(22.0)
	TimeSystem.advance_minutes(60)
	NoticeManager.show_message("在%s歇了一会儿，身体松了下来。" % str(ConfigDB.get_row("travel_destinations", destination_id).get("name", destination_id)), "positive", "当地街坊")
	SaveManager.request_auto_save("travel_rest")
	return true

func get_summary() -> String:
	return "去过 %d 个地方 · 旅行照片 %d 张" % [visited.size(), postcards.size()]

func get_destination_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for destination_id in ConfigDB.get_rows("travel_destinations"):
		var row := ConfigDB.get_row("travel_destinations", destination_id)
		result.append({
			"id": str(destination_id),
			"name": str(row.get("name", destination_id)),
			"scene_id": str(row.get("scene_id", destination_id)),
			"cost": int(row.get("travel_cost", "0")),
			"minutes": int(row.get("travel_minutes", "0")),
			"energy": float(row.get("energy_cost", "0")),
			"min_day": int(row.get("min_day", "1")),
			"description": str(row.get("description", "")),
			"visited": visited.has(destination_id),
			"available": can_travel(str(destination_id)) and GameState.money >= int(row.get("travel_cost", "0")) and GameState.energy >= float(row.get("energy_cost", "0")),
		})
	return result

func get_save_data() -> Dictionary:
	return {"visited": visited.duplicate(true), "postcards": postcards.duplicate(true)}

func restore(data: Dictionary) -> void:
	visited = data.get("visited", {}).duplicate(true)
	postcards = data.get("postcards", {}).duplicate(true)
	changed.emit()
