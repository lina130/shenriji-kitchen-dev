extends Node

signal travel_completed(area_id: String, spawn_id: String)

const VALID_AREAS := ["home", "street", "factory", "store", "recycle", "market", "park", "ruins", "bank", "restaurant", "wholesale"]

func travel_to(area_id: String, spawn_id: String = "default") -> void:
	if area_id not in VALID_AREAS:
		push_warning("未知区域：%s" % area_id)
		return
	GameState.current_area = area_id
	GameState.spawn_id = spawn_id
	travel_completed.emit(area_id, spawn_id)

func restore(area_id: String, spawn_id: String) -> void:
	if area_id not in VALID_AREAS:
		area_id = "home"
	GameState.current_area = area_id
	GameState.spawn_id = spawn_id