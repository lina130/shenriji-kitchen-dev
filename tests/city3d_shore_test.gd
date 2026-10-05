extends Node

const CityScript := preload("res://scripts/city3d/city_slice.gd")
const TEST_SAVE := "user://city3d_shore_test.json"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var city = CityScript.new()
	city.preview_save_path = TEST_SAVE
	add_child(city)
	for frame in range(3):
		await get_tree().physics_frame
	var atlas = city.atlas
	var dry := Vector3(0, 0, 0)
	var open_sea := Vector3(-600, 0, 1600)
	if atlas.is_water_at(dry) or not atlas.is_water_at(open_sea):
		_fail("Reference land or open-sea sample changed")
		return
	if not _has_floor(city, dry) or _has_floor(city, open_sea):
		_fail("Land collision is missing or the open sea still has a walkable floor")
		return
	var coast_x := INF
	var was_land := not atlas.is_water_at(Vector3(-2100, 0, 1700))
	for x in range(-2098, -1300, 2):
		var now_water: bool = atlas.is_water_at(Vector3(float(x), 0, 1700))
		if was_land and now_water:
			coast_x = float(x)
			break
		was_land = not now_water
	if is_inf(coast_x):
		_fail("Could not find the Macao-area shoreline")
		return
	city.player.global_position = Vector3(coast_x - 6.0, 0.5, 1700)
	city._update_chunks()
	for frame in range(3):
		await get_tree().physics_frame
	city.player.move_toward_point(Vector3(coast_x + 25.0, 0.5, 1700))
	for frame in range(260):
		await get_tree().physics_frame
	if atlas.is_water_at(city.player.global_position) or city.player.global_position.y < -0.25:
		_fail("The player walked into open water or fell through the coast")
		return
	var bridge := Vector3(-415, 0, 1125)
	if not atlas.is_water_at(bridge) or not _has_floor(city, bridge):
		_fail("The Zhuhai–Hong Kong crossing has no walkable bridge deck")
		return
	if not _has_floor(city, Vector3(720, 0, 863.8)) or not _has_floor(city, Vector3(-1767.8, 0, 1415)):
		_fail("A ferry entrance lost its walkable deck")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("CITY3D_SHORE_PASS")
	get_tree().quit(0)

func _has_floor(city, at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 25, 0), at + Vector3(0, -8, 0), 1)
	var hit: Dictionary = city.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty()

func _fail(reason: String) -> void:
	push_error("CITY3D_SHORE_FAIL: " + reason)
	get_tree().quit(1)
