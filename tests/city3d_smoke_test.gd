extends Node

const CitySliceScript := preload("res://scripts/city3d/city_slice.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var city = CitySliceScript.new()
	add_child(city)
	for frame in range(4):
		await get_tree().process_frame
	if not is_instance_valid(city.player) or not is_instance_valid(city.camera) or not is_instance_valid(city.hud):
		_fail("3D player, camera or HUD missing")
		return
	var chunks: Dictionary = city.get("_chunks")
	if chunks.size() != 2:
		_fail("Expected both adjacent city chunks")
		return
	if get_tree().get_nodes_in_group("city3d_interactable").size() < 6:
		_fail("Expected visible district interactions")
		return
	var tea_area: Area3D
	for candidate in get_tree().get_nodes_in_group("city3d_interactable"):
		if candidate.get_meta("interaction_id", "") == "tea_house":
			tea_area = candidate
			break
	if not is_instance_valid(tea_area):
		_fail("Tea house interaction missing")
		return
	var screen_point: Vector2 = city.camera.unproject_position(tea_area.global_position)
	city._click_world(screen_point)
	if city.get("_pending_area") != tea_area:
		_fail("Clicking the visible tea house did not select the same action as E")
		return
	city.player.stop_auto_move()
	city.set("_pending_area", null)
	city.player.move_toward_point(Vector3(1.2, 0.5, 0.6))
	for frame in range(50):
		await get_tree().physics_frame
	if city.get("_last_district") != "创意商业街":
		_fail("Crossing the chunk seam did not change district")
		return
	print("CITY3D_SMOKE_PASS")
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("CITY3D_SMOKE_FAIL: " + reason)
	get_tree().quit(1)
