extends Node

signal travel_completed(area_id: String, spawn_id: String)

const VALID_AREAS := ["home", "home_living", "street", "factory", "store", "recycle", "market", "night_market", "park", "ruins", "bank", "restaurant", "wholesale", "farm", "farm_livestock", "pet_store", "furniture_store", "breakfast_shop", "commercial_district", "high_end_district", "industrial_district", "logistics_port", "craft_workshop", "suburb", "clothing_store", "riverside", "breakfast_kitchen", "bus_station", "seaside_resort", "ancient_village", "mountain_spring", "clinic", "university", "community_center"]

func travel_to(area_id: String, spawn_id: String = "default") -> void:
	if area_id not in VALID_AREAS:
		push_warning("未知区域：%s" % area_id)
		return
	GameState.current_area = area_id
	GameState.spawn_id = spawn_id
	if get_node_or_null("/root/CollectionManager") != null:
		CollectionManager.record_area_visited(area_id)
	if get_node_or_null("/root/CollectionManager") != null:
		CollectionManager.record_area_visited(area_id)
	travel_completed.emit(area_id, spawn_id)

func restore(area_id: String, spawn_id: String) -> void:
	if area_id not in VALID_AREAS:
		area_id = "home"
	GameState.current_area = area_id
	GameState.spawn_id = spawn_id