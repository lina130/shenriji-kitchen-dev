extends SceneTree

const Slice := preload("res://scripts/city3d/city_talent_park_slice.gd")
const Store := preload("res://scripts/city3d/talent_park_save.gd")
var city
var failures: Array[String] = []
var test_save := "user://tests/talent_park_controls_%s.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	city = Slice.new()
	city.save_path = test_save
	root.add_child(city)
	city.set_process(false)
	city.set_physics_process(false)
	city.player.set_physics_process(false)
	city._interact(city.get_node("ParkInteract_calm"))
	city.restaurant.interact("wash")
	city.restaurant.interact("mix")
	city.restaurant.interact("steam")
	city._process(1.0)
	var running: Dictionary = city.restaurant.snapshot()
	_check(float(running["time_left"]) < 88.0, "Focused game must advance orders")
	_key(KEY_P)
	city._process(10.0)
	city._physics_process(0.016)
	_check(city.restaurant.snapshot() == running, "Manual pause advanced cooking or customer patience")
	_check(city.player.input_locked, "Paused character is not locked")
	city.player.position = city.get_node("ParkInteract_kitchen").position
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	city._unhandled_input(interact)
	_check(city.restaurant.snapshot() == running, "Paused E interaction changed the order")
	city._on_window_focus_changed(false)
	city._on_window_focus_changed(true)
	city._process(5.0)
	_check(city.restaurant.snapshot() == running, "Focus restored through an explicit manual pause")
	_key(KEY_P)
	city._process(0.5)
	_check(float(city.restaurant.snapshot()["time_left"]) < float(running["time_left"]), "Unpause did not resume the order")
	city._exit_kitchen()
	_queue_prep()
	var before_cancel: Dictionary = city.restaurant.snapshot()
	Input.action_press("move_up")
	city._physics_process(0.016)
	Input.action_release("move_up")
	_check(city.get("_pending") == null and not city.player.has_destination, "Manual walking retained an old click action")
	_check(city.restaurant.snapshot() == before_cancel, "Old click action fired before manual cancellation")
	_queue_prep()
	city.set("_orbiting", true)
	city._on_window_focus_changed(false)
	city._process(60.0)
	_check(city.restaurant.snapshot() == before_cancel, "An unfocused window advanced the order")
	_check(city.player.input_locked and not city.get("_orbiting"), "Focus loss retained character or camera input")
	_check(city.get("_pending") == null and not city.player.has_destination, "Focus loss retained an old click action")
	var saved: Dictionary = Store.new().load_state(test_save)
	var restored = Slice.RestaurantScript.new()
	restored.restore(saved["restaurant"])
	_check(restored.snapshot() == before_cancel, "Focus loss failed to preserve cooking progress in the save")
	restored.free()
	city._on_window_focus_changed(true)
	_check(not city.player.input_locked, "Returning to the window did not unlock movement")
	_queue_prep()
	_key(KEY_M)
	city._process(10.0)
	_check(city.restaurant.snapshot() == before_cancel and city.get("_pending") == null, "Overview failed to pause or cancel queued input")
	_key(KEY_P)
	_key(KEY_M)
	_check(city._actions_paused(), "Leaving overview cleared the player's manual pause")
	city.queue_free()
	await process_frame
	root.get_node("AudioManager").shutdown()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_save + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save + suffix))
	if failures.is_empty():
		print("TALENT_PARK_CONTROLS_OK: pause, focus, input cancellation, saved cooking")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)

func _queue_prep() -> void:
	var kitchen: Area3D = city.get_node("ParkInteract_kitchen")
	city.player.position = kitchen.position + Vector3(0, -0.8, 0.5)
	city.set("_pending", kitchen)
	city.player.move_toward_point(kitchen.position)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	city._unhandled_input(event)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
