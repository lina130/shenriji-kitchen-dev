extends Node

## 场景分区数据。用于规范店面、公共服务、自然区等的边界与视觉标识。

var _zones_by_area: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	_zones_by_area.clear()
	for zone_id in ConfigDB.get_rows("scene_zones"):
		var row := ConfigDB.get_row("scene_zones", zone_id)
		var area_id := str(row.get("area_id", ""))
		if area_id.is_empty():
			continue
		var zone := {
			"id": zone_id,
			"area_id": area_id,
			"name": str(row.get("name", zone_id)),
			"rect": Rect2(
				float(row.get("rect_x", "0")),
				float(row.get("rect_y", "0")),
				float(row.get("rect_w", "0")),
				float(row.get("rect_h", "0"))
			),
			"kind": str(row.get("kind", "misc")),
			"order": int(row.get("order", "0")),
		}
		if not _zones_by_area.has(area_id):
			_zones_by_area[area_id] = []
		_zones_by_area[area_id].append(zone)
	for area_id in _zones_by_area:
		_zones_by_area[area_id].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("order", 0)) < int(b.get("order", 0))
		)

func _zones_for(area_id: String):
	var key := area_id.strip_edges()
	if _zones_by_area.has(key):
		return _zones_by_area[key]
	for candidate in _zones_by_area.keys():
		if str(candidate).strip_edges() == key:
			return _zones_by_area[candidate]
	return []

func has_zones(area_id: String) -> bool:
	return not _zones_for(area_id).is_empty()

func get_zones(area_id: String):
	return _zones_for(area_id)

func get_zone(area_id: String, zone_id: String) -> Dictionary:
	for zone in _zones_for(area_id):
		if str(zone.get("id", "")) == zone_id:
			return zone
	return {}

func find_zone(area_id: String, world_position: Vector2) -> Dictionary:
	for zone in _zones_for(area_id):
		var rect: Rect2 = zone.get("rect", Rect2())
		if rect.has_point(world_position):
			return zone
	return {}

func get_zone_color(kind: String) -> Color:
	match kind:
		"residential", "housing":
			return Color(0.86, 0.66, 0.42, 0.44)
		"commercial", "shops", "services":
			return Color(0.86, 0.45, 0.40, 0.42)
		"industrial", "factory", "logistics", "wholesale":
			return Color(0.40, 0.68, 0.72, 0.42)
		"nature", "suburb":
			return Color(0.42, 0.72, 0.48, 0.42)
		"transit":
			return Color(0.78, 0.72, 0.42, 0.42)
		"event":
			return Color(0.78, 0.48, 0.72, 0.46)
		_:
			return Color(0.70, 0.70, 0.70, 0.36)
