extends Node

const Slice := preload("res://scripts/city3d/city_talent_park_slice.gd")
const Store := preload("res://scripts/city3d/talent_park_save.gd")
const TEST_SAVE := "user://tests/talent_park_playable_test.json"
var city

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE + suffix))
	city = Slice.new()
	city.save_path = TEST_SAVE
	add_child(city)
	for i in range(20):
		await get_tree().physics_frame
	if not city.player.is_on_floor() or city.player.position.y < -0.5:
		_fail("Cafe spawn is not on walkable ground")
		return
	if not city.find_children("*", "Label3D", true, false).is_empty():
		_fail("Floating map text remains")
		return
	_activate("calm")
	if not city.restaurant.snapshot()["active"] or int(city.state["energy"]) != 82:
		_fail("Physical calm bell did not start the shift")
		return
	# Exercise click-to-approach and the reach trigger once, including real movement.
	var prep := _area("prep")
	city.player.position = prep.position + Vector3(0, -0.8, 3.5)
	city.set("_pending", prep)
	city.player.move_toward_point(prep.position + Vector3(0, 0, 0.85))
	for i in range(100):
		await get_tree().physics_frame
		if city.restaurant.snapshot()["stage"] == "heat":
			break
	if city.restaurant.snapshot()["stage"] != "heat":
		_fail("Click-to-approach did not reach and use the prep counter")
		return
	_activate("heat")
	var restored: Dictionary = Store.new().load_state(TEST_SAVE)
	if restored["restaurant"].get("stage") != "heating":
		_fail("The current cooking phase was not saved")
		return
	city.restaurant.restore(restored["restaurant"])
	city.restaurant.tick(4.0)
	_activate("plate")
	_activate("serve")
	for order in range(2):
		_activate("prep")
		_activate("heat")
		city.restaurant.tick(4.0)
		_activate("plate")
		_activate("serve")
	if city.restaurant.snapshot()["active"] or int(city.state["cash"]) != 228:
		_fail("Three completed meals did not settle exactly once")
		return
	_activate("drink")
	_activate("souvenir")
	if int(city.state["cash"]) != 153 or int(city.state["energy"]) != 100 or not city.state["purchases"].get("bay_mug", false):
		_fail("Simple spending did not charge cash and apply purchases")
		return
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	city._unhandled_input(key)
	if not city.get("_overview") or city.hud.is_modal_open():
		_fail("Park overview still depends on a menu")
		return
	city._unhandled_input(key)
	city._save_state()
	var original_position: Vector3 = city.player.position
	city.queue_free()
	await get_tree().process_frame
	city = Slice.new()
	city.save_path = TEST_SAVE
	add_child(city)
	await get_tree().process_frame
	if int(city.state["cash"]) != 153 or not city.state["purchases"].get("bay_mug", false) or city.player.position.distance_to(original_position) > 0.5:
		_fail("Closing and reopening lost money, purchase, or player position")
		return
	city.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE + suffix))
	print("TALENT_PARK_PLAYABLE_OK: walking, cooking, income, spending, resume")
	get_tree().quit(0)

func _area(id: String) -> Area3D:
	return city.get_node("ParkInteract_" + id) as Area3D

func _activate(id: String) -> void:
	var area := _area(id)
	city.player.position = area.position + Vector3(0, -0.8, 0.55)
	city.player.stop_auto_move()
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	city._unhandled_input(event)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
