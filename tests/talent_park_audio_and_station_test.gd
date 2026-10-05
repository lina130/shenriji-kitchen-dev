extends Node

const Slice := preload("res://scripts/city3d/city_talent_park_slice.gd")
const SAVE := "user://tests/talent_park_audio_station.json"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for sound in ["kitchen_morning", "kitchen_lunch", "kitchen_evening", "kitchen_garnish", "kitchen_ready", "kitchen_register"]:
		if AudioManager.get_resolved_audio_path(sound).is_empty():
			_fail("Missing kitchen audio: " + sound)
			return
	AudioManager.play_kitchen_music(480)
	if AudioManager.get_current_track_id() != "kitchen_morning" or not AudioManager.get("_music_player").playing:
		_fail("Morning music did not start")
		return
	AudioManager.play_kitchen_music(720)
	if AudioManager.get_current_track_id() != "kitchen_lunch":
		_fail("Lunch music did not follow the clock")
		return
	AudioManager.play_kitchen_music(1080)
	if AudioManager.get_current_track_id() != "kitchen_evening":
		_fail("Evening music did not follow the clock")
		return
	AudioManager.play_sfx("kitchen_garnish")
	AudioManager.play_sfx("kitchen_register")
	var voices_playing := 0
	for voice in AudioManager.get("_sfx_players"):
		if voice.playing:
			voices_playing += 1
	if voices_playing < 2:
		_fail("A second effect cut off the first")
		return
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	var city := Slice.new()
	city.save_path = SAVE
	city.start_in_kitchen = true
	add_child(city)
	await get_tree().physics_frame
	var view = city.get("_kitchen")
	if not is_instance_valid(view):
		_fail("Kitchen was not created")
		return
	var projection_count := int(view.get("_pantry_projection_updates"))
	for n in range(30):
		view._position_pantry_screen_marks()
	if int(view.get("_pantry_projection_updates")) != projection_count:
		_fail("Fixed pantry labels were projected again without a camera change")
		return
	view.camera.position.x += 0.1
	view._position_pantry_screen_marks()
	if int(view.get("_pantry_projection_updates")) != projection_count + 1:
		_fail("Pantry labels did not follow the camera after a view change")
		return
	view.camera.position.x -= 0.1
	view._position_pantry_screen_marks()
	var mute_button: Button = view.find_child("KitchenMuteToggle", true, false)
	if not is_instance_valid(mute_button):
		_fail("Kitchen mute control was not created")
		return
	view._on_kitchen_volume_changed(0.0)
	if mute_button.text != "♪×" or not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		_fail("Saved zero volume was not visibly marked as muted")
		return
	mute_button.pressed.emit()
	if SettingsManager.master_volume <= 0.02 or AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		_fail("Kitchen mute button did not restore audible volume")
		return
	var tickets: Array = city.restaurant.get("_tickets")
	if tickets.size() < 2:
		_fail("Two parallel tickets were not created")
		return
	var order_numbers: Array[int] = []
	for slot in range(2):
		var ticket: Dictionary = tickets[slot]
		ticket["recipe_index"] = 0
		ticket["step_index"] = 3
		ticket["started"] = true
		ticket["ingredients_reserved"] = true
		ticket["heat_left"] = 0.0
		ticket["pickup_left"] = 0.0
		tickets[slot] = ticket
		order_numbers.append(int(ticket["order_number"]))
	city.restaurant.set("_tickets", tickets)
	city.restaurant.call("_emit_state")
	await get_tree().physics_frame
	var garnish_area: Area3D = view.get_node("KitchenStage/Station_garnish/Hotspot_garnish") if view.has_node("KitchenStage/Station_garnish/Hotspot_garnish") else null
	if not is_instance_valid(garnish_area):
		for area in view.find_children("*", "Area3D", true, false):
			if str(area.get_meta("kind", "")) == "action" and str(area.get_meta("id", "")) == "garnish":
				garnish_area = area
				break
	if not is_instance_valid(garnish_area):
		_fail("Garnish worktop has no hit area")
		return
	var first_spot: Vector2 = view.camera.unproject_position(view.get("_ticket_food")[0].global_position)
	var second_spot: Vector2 = view.camera.unproject_position(view.get("_ticket_food")[1].global_position)
	if view._closest_food_order_on_station("garnish", first_spot) != order_numbers[0] or view._closest_food_order_on_station("garnish", second_spot) != order_numbers[1]:
		_fail("Garnish worktop did not distinguish the two physical dishes")
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = first_spot
	press.pressed = true
	view._input(press)
	press.pressed = false
	press.position = first_spot + Vector2(24, 5)
	view._input(press)
	if int(city.restaurant.snapshot()["tickets"][0]["step_index"]) != 4:
		_fail("A slightly moving click on the first garnish dish did not advance")
		return
	view.set("_left_press_position", second_spot)
	view._activate_pointer_target(garnish_area)
	if int(city.restaurant.snapshot()["tickets"][1]["step_index"]) != 4:
		_fail("Clicking second garnish dish did not advance in parallel")
		return
	# Heat completion already lights the next station. The ready dish must be
	# usable there without an extra click back on the hot pan or a ticket switch.
	var hot_tickets: Array = city.restaurant.get("_tickets")
	var cooling: Dictionary = hot_tickets[0]
	cooling["step_index"] = 3
	cooling["pickup_left"] = 5.0
	cooling["heat_left"] = 0.0
	hot_tickets[0] = cooling
	city.restaurant.set("_tickets", hot_tickets)
	var next_step: Dictionary = city.restaurant.interact_station("garnish")
	if not bool(next_step.get("ok", false)) or int(city.restaurant.snapshot()["tickets"][0]["step_index"]) != 4:
		_fail("Ready hot food could not continue at the lit next worktop")
		return
	city.set("_closing", true)
	city.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	AudioManager.shutdown()
	print("TALENT_PARK_AUDIO_STATION_PASS")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("TALENT_PARK_AUDIO_STATION_FAIL: " + message)
	get_tree().quit(1)
