extends Node

const Slice := preload("res://scripts/city3d/city_talent_park_slice.gd")
const SAVE := "user://tests/talent_park_kitchen_integration.json"
const DIRECT_SAVE := "user://tests/talent_park_endless_entry.json"
var city

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	city = Slice.new()
	city.save_path = SAVE
	add_child(city)
	await get_tree().physics_frame
	city._interact(city.get_node("ParkInteract_kitchen"))
	if not is_instance_valid(city.get("_kitchen")) or city.restaurant.snapshot()["active"]:
		_fail("Idle prep counter did not open the fixed kitchen view")
		return
	var active_kitchen = city.get("_kitchen")
	var stock_area: Area3D
	for area in active_kitchen.find_children("*", "Area3D", true, false):
		if str(area.get_meta("kind", "")) == "stock" and str(area.get_meta("id", "")) == "rice_batter":
			stock_area = area
			break
	if not is_instance_valid(stock_area):
		_fail("The front prep table has no clickable batter stock well")
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = active_kitchen.camera.unproject_position(stock_area.global_position)
	active_kitchen._input(click)
	_release_click(active_kitchen, click)
	await get_tree().physics_frame
	var kitchen = city.get("_kitchen")
	var wash_area: Area3D
	for area in kitchen.find_children("*", "Area3D", true, false):
		if str(area.get_meta("kind", "")) == "action" and str(area.get_meta("id", "")) == "wash":
			wash_area = area
			break
	if not is_instance_valid(wash_area):
		_fail("The wash ingredient has no clickable 3D area")
		return
	var wash_at: Vector2 = kitchen.camera.unproject_position(wash_area.global_position)
	click.position = wash_at
	kitchen._input(click)
	_release_click(kitchen, click)
	if int(city.restaurant.snapshot()["stock_job"].get("step_index", 0)) != 1:
		_fail("A real 3D mouse click did not advance stock preparation")
		return
	city.get("_kitchen").action_pressed.emit("mix")
	if int(city.restaurant.snapshot()["stock"][0]["count"]) != 3:
		_fail("Physical stock tray actions did not create three portions")
		return
	var raw_area: Area3D
	for area in kitchen.find_children("*", "Area3D", true, false):
		if str(area.get_meta("kind", "")) == "raw" and str(area.get_meta("id", "")) == "rice_flour":
			raw_area = area
	if not is_instance_valid(raw_area):
		_fail("Rice flour has no fixed physical preparation bay")
		return
	var raw_click: Vector2 = kitchen.camera.unproject_position(raw_area.global_position)
	if kitchen._ray_pick(raw_click) != raw_area:
		_fail("Fixed ingredient bay is obscured in the mouse picking view")
		return
	var before_stage := int(city.restaurant.snapshot()["prep_ingredients"]["rice_flour"])
	click.position = raw_click
	kitchen._input(click)
	_release_click(kitchen, click)
	if not (city.restaurant.snapshot()["carried_ingredients"] as Dictionary).is_empty() or int(city.restaurant.snapshot()["prep_ingredients"]["rice_flour"]) <= before_stage:
		_fail("A single ingredient click did not prepare rice flour directly")
		return
	city._exit_kitchen()
	await get_tree().process_frame
	city._interact(city.get_node("ParkInteract_calm"))
	var started: Dictionary = city.restaurant.snapshot()
	if not is_instance_valid(city.get("_kitchen")) or not started["active"] or int(city.state["energy"]) != 100:
		_fail("Starting a shift still blocked or charged energy")
		return
	city.get("_kitchen").ticket_pressed.emit(1)
	city.get("_kitchen").ticket_pressed.emit(0)
	city.get("_kitchen").stock_pressed.emit("rice_batter")
	var used: Dictionary = city.restaurant.snapshot()
	if int(used["tickets"][0]["step_index"]) != 2 or int(used["stock"][0]["count"]) != 2:
		_fail("Stored batter did not skip two on-demand preparation steps")
		return
	var buffered_once := false
	for i in range(28):
		var snapshot: Dictionary = city.restaurant.snapshot()
		if int(snapshot["served"]) >= 2:
			break
		if bool(snapshot["combo_plate"]["ready"]):
			var combo_area: Area3D
			for area in city.get("_kitchen").find_children("*", "Area3D", true, false):
				if str(area.get_meta("kind", "")) == "buffer" and str(area.get_meta("id", "")) == "0":
					combo_area = area
					break
			if not is_instance_valid(combo_area):
				_fail("The physical two-dish pickup tray has no clickable area")
				return
			click.position = city.get("_kitchen").camera.unproject_position(combo_area.global_position)
			city.get("_kitchen")._input(click)
			_release_click(city.get("_kitchen"), click)
		elif bool(snapshot["tickets"][int(snapshot["selected_slot"])]["buffered"]):
			var other: Dictionary = snapshot["tickets"][1]
			city.get("_kitchen").dish_pressed.emit(int(other["order_number"]), str(other["next_action"]))
		elif float(snapshot["heat_left"]) > 0.0:
			city._process(float(snapshot["heat_left"]) + 0.1)
		elif str(snapshot["next_action"]) == "serve":
			var finished_area: Area3D = city.get("_kitchen").get("_ticket_food_areas")[int(snapshot["selected_slot"])]
			if not is_instance_valid(finished_area) or finished_area.collision_layer == 0:
				_fail("Finished food has no active physical click area")
				return
			var food_spot := city.get("_kitchen").get("_finished_dish_spot") as SpotLight3D
			if not is_instance_valid(food_spot) or not food_spot.visible:
				_fail("Completed food did not turn on its dedicated handoff light")
				return
			await get_tree().physics_frame
			click.position = city.get("_kitchen").camera.unproject_position(finished_area.global_position)
			city.get("_kitchen")._input(click)
			_release_click(city.get("_kitchen"), click)
			if not buffered_once:
				if not bool(city.restaurant.snapshot()["buffer"][0]["occupied"]):
					_fail("Clicking the completed food did not put the first dish in the buffer")
					return
				buffered_once = true
		else:
			var selected_ticket: Dictionary = snapshot["tickets"][int(snapshot["selected_slot"])]
			city.get("_kitchen").dish_pressed.emit(int(selected_ticket["order_number"]), str(snapshot["next_action"]))
	var settled: Dictionary = city.restaurant.snapshot()
	if int(settled["served"]) != 2 or int(city.state["cash"]) <= 120 or int(settled["combo"]) <= 0 or not buffered_once:
		_fail("Buffered service did not settle money and a correct-action combo: served=%s cash=%s combo=%s buffered=%s next=%s stage=%s" % [settled.get("served"), city.state.get("cash"), settled.get("combo"), buffered_once, settled.get("next_action"), settled.get("stage")])
		return
	var earned_cash: int = int(city.state["cash"])
	city._save_state()
	city.queue_free()
	await get_tree().process_frame
	city = Slice.new()
	city.save_path = SAVE
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	var resumed: Dictionary = city.restaurant.snapshot()
	if not is_instance_valid(city.get("_kitchen")) or int(city.state["cash"]) != earned_cash or int(resumed["served"]) != 2 or int(resumed["stock"][0]["count"]) != 2:
		_fail("Reload lost the working view, money, completed ticket, or stock")
		return
	city.restaurant.cancel_shift()
	await get_tree().process_frame
	if not is_instance_valid(city.get("_kitchen")):
		_fail("Finishing a shift forced the player out of the kitchen")
		return
	city.get("_kitchen").shift_requested.emit("rush")
	if not bool(city.restaurant.snapshot()["active"]) or int(city.state["energy"]) != 100:
		_fail("The kitchen shift bell did not start another shift without stamina")
		return
	city.restaurant.tick(float(city.restaurant.snapshot().get("rush_wave_at", 10.0)) + 0.1)
	var heat_tickets: Array = city.restaurant.get("_tickets")
	if heat_tickets.size() < 3:
		_fail("Rush wave did not provide three parallel kitchen tickets")
		return
	for lane in range(3):
		var heat_ticket: Dictionary = heat_tickets[lane]
		var recipe_index: int = [0, 7, 8][lane]
		var heat_recipe: Dictionary = TalentParkRestaurant3D.RECIPES[recipe_index]
		heat_ticket["recipe_index"] = recipe_index
		heat_ticket["started"] = true
		heat_ticket["step_index"] = (heat_recipe["steps"] as Array).find("steam")
		heat_ticket["heat_left"] = 1.6
		heat_ticket["pickup_left"] = 0.0
		heat_tickets[lane] = heat_ticket
	city.restaurant.set("_tickets", heat_tickets)
	city.restaurant.call("_emit_state")
	await get_tree().create_timer(0.42).timeout
	var heat_holders: Array = city.get("_kitchen").get("_ticket_food")
	if not (heat_holders[0].visible and heat_holders[1].visible and heat_holders[2].visible):
		_fail("Three simultaneously heated dishes were not all visible")
		return
	if not (heat_holders[1].position.x - heat_holders[0].position.x > 0.55 and heat_holders[2].position.x - heat_holders[1].position.x > 0.55):
		_fail("Three steam dishes overlapped instead of occupying separate heat lanes")
		return
	var heat_areas: Array = city.get("_kitchen").get("_ticket_food_areas")
	for lane in range(3):
		var lane_area := heat_areas[lane] as Area3D
		if lane_area.collision_layer == 0 or city.get("_kitchen")._ray_pick(city.get("_kitchen").camera.unproject_position(lane_area.global_position)) != lane_area:
			_fail("Three parallel dishes cannot each be clicked at their own food position")
			return
	for shared_action in ["slice", "serve"]:
		for lane in range(3):
			var shared_ticket: Dictionary = heat_tickets[lane]
			var shared_recipe_index: int = [1, 2, 5][lane]
			var shared_recipe: Dictionary = TalentParkRestaurant3D.RECIPES[shared_recipe_index]
			shared_ticket["recipe_index"] = shared_recipe_index
			shared_ticket["step_index"] = (shared_recipe["steps"] as Array).find(shared_action)
			shared_ticket["heat_left"] = 0.0
			shared_ticket["pickup_left"] = 0.0
			heat_tickets[lane] = shared_ticket
		city.restaurant.set("_tickets", heat_tickets)
		city.restaurant.call("_emit_state")
		await get_tree().create_timer(0.40).timeout
		for lane in range(3):
			var shared_area := heat_areas[lane] as Area3D
			if shared_area.collision_layer == 0 or city.get("_kitchen")._ray_pick(city.get("_kitchen").camera.unproject_position(shared_area.global_position)) != shared_area:
				_fail("Three dishes at %s cannot be clicked independently" % shared_action)
				return
	city.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(DIRECT_SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIRECT_SAVE + suffix))
	var direct := Slice.new()
	direct.save_path = DIRECT_SAVE
	direct.start_in_kitchen = true
	add_child(direct)
	await get_tree().physics_frame
	if not bool(direct.restaurant.snapshot().get("active", false)) or not bool(direct.restaurant.snapshot().get("endless", false)) or not is_instance_valid(direct.get("_kitchen")):
		_fail("Direct entry did not open an already running endless kitchen")
		return
	var direct_kitchen = direct.get("_kitchen")
	await get_tree().create_timer(0.39).timeout
	var queued_guests: Array = direct_kitchen.get("_guest_pivots")
	if queued_guests.is_empty() or (queued_guests[0] as Node3D).position.z < 5.75:
		_fail("Customer queue stepped through the solid front serving table")
		return
	var pantry_chips: Dictionary = direct_kitchen.get("_pantry_prep_models")
	if not pantry_chips.has("rice_flour") or not (pantry_chips["rice_flour"] is Control) or (pantry_chips["rice_flour"] as Control).get_parent() != direct_kitchen.get("_hud_root"):
		_fail("Pantry label is not drawn directly with the same screen-space ingredient chip as the meal ticket")
		return
	var bulk_models: Dictionary = direct_kitchen.get("_pantry_raw_models")
	var raw_store: Dictionary = direct.restaurant.get("_raw_ingredients")
	for depleted in ["rice_flour", "noodles", "soy_sauce"]:
		raw_store[depleted] = 0
	direct.restaurant.set("_raw_ingredients", raw_store)
	direct.restaurant.call("_emit_state")
	for key in bulk_models.keys():
		if not (bulk_models[key] as Node3D).visible:
			_fail("A fixed pantry ingredient icon vanished when warehouse stock reached zero: " + str(key))
			return
	var handoff_spot := direct_kitchen.get("_finished_dish_spot") as SpotLight3D
	if not is_instance_valid(handoff_spot) or not handoff_spot.visible or handoff_spot.light_energy < 0.25:
		_fail("The handoff board has no persistent working light before a dish is ready")
		return
	var step_rail: Control = direct_kitchen.get("_step_rail")
	direct_kitchen.ticket_pressed.emit(0)
	if not is_instance_valid(step_rail) or not step_rail.visible or str(direct_kitchen.get("_step_action_label").text).is_empty():
		_fail("Bottom rail does not explain the selected dish's current step")
		return
	var prep_store: Dictionary = direct.restaurant.get("_prep_ingredients")
	for key in ["rice_flour", "leafy_greens", "soy_sauce"]:
		prep_store[key] = 0
	direct.restaurant.set("_prep_ingredients", prep_store)
	direct.restaurant.call("_emit_state")
	var ticket_stages: Array = direct_kitchen.get("_customer_food_stage_labels")
	if str(ticket_stages[0][0].text) != "缺料":
		_fail("Meal ticket did not announce missing ingredients beside the zero-count icons")
		return
	for key in ["rice_flour", "leafy_greens", "soy_sauce"]:
		if not bool(direct.restaurant.stage_raw_ingredient(key).get("ok", false)):
			_fail("Missing ingredient could not be replenished from the pantry: " + key)
			return
	if str(ticket_stages[0][0].text) != "在做":
		_fail("Meal ticket shortage badge did not clear after the pantry was replenished")
		return
	var single_snapshot: Dictionary = direct.restaurant.snapshot()
	var single_tickets: Array = single_snapshot["tickets"]
	single_snapshot["tickets"] = [single_tickets[0]]
	direct_kitchen.show_state(single_snapshot)
	var whole_card: Button = (direct_kitchen.get("_customer_card_hit_buttons") as Array)[0]
	if absf((direct_kitchen.get("_customer_cards") as Array)[0].custom_minimum_size.x - 190.0) > 0.1 or absf(whole_card.size.x - 190.0) > 0.1 or whole_card.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Single-dish meal card retains non-clickable side gutters")
		return
	direct_kitchen.show_state(direct.restaurant.snapshot())
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	var original_size: float = direct_kitchen.camera.size
	direct_kitchen._input(zoom)
	if absf(direct_kitchen.camera.size - original_size) > 0.01:
		_fail("Fixed kitchen camera still zooms with the mouse wheel")
		return
	var pan := InputEventKey.new()
	pan.keycode = KEY_RIGHT
	pan.pressed = true
	var original_focus: Vector3 = direct_kitchen.get("_camera_focus")
	direct_kitchen._input(pan)
	if (direct_kitchen.get("_camera_focus") as Vector3).distance_to(original_focus) > 0.01:
		_fail("Fixed kitchen camera still pans with arrow keys")
		return
	pan.keycode = KEY_HOME
	direct_kitchen._input(pan)
	if absf(direct_kitchen.camera.size - original_size) > 0.01:
		_fail("Fixed kitchen camera changed on Home")
		return
	if absf(float(direct_kitchen.get("_camera_yaw"))) > 0.001 or float(direct_kitchen.get("_camera_pitch")) < 1.15:
		_fail("Kitchen Home key did not restore the straight overhead view")
		return
	var drag_start := Vector2(640, 420)
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	drag_press.position = drag_start
	direct_kitchen._input(drag_press)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag_motion.position = drag_start + Vector2(95, 0)
	drag_motion.relative = Vector2(95, 0)
	direct_kitchen._input(drag_motion)
	var drag_end_focus: Vector3 = direct_kitchen.get("_camera_focus")
	_release_click(direct_kitchen, drag_press, drag_motion.position)
	if drag_end_focus.distance_to(direct_kitchen.get("_camera_focus")) > 0.01 or drag_end_focus.distance_to(original_focus) > 0.01:
		_fail("Fixed kitchen camera still moves when dragging")
		return
	var yaw_before: float = direct_kitchen.get("_camera_yaw")
	var pitch_before: float = direct_kitchen.get("_camera_pitch")
	var rotate_motion := InputEventMouseMotion.new()
	rotate_motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	rotate_motion.relative = Vector2(90, 55)
	direct_kitchen._input(rotate_motion)
	if absf(float(direct_kitchen.get("_camera_yaw")) - yaw_before) > 0.001 or absf(float(direct_kitchen.get("_camera_pitch")) - pitch_before) > 0.001:
		_fail("Fixed kitchen camera still rotates on right drag")
		return
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	direct_kitchen._input(escape)
	if not is_instance_valid(direct.get("_kitchen")):
		_fail("Escape left the standalone kitchen")
		return
	direct_kitchen._input(pan)
	var bottom_ingredient: Area3D
	for area in direct_kitchen.find_children("*", "Area3D", true, false):
		if str(area.get_meta("kind", "")) == "raw" and str(area.get_meta("id", "")) == "ice":
			bottom_ingredient = area
			break
	if not is_instance_valid(bottom_ingredient) or direct_kitchen._ray_pick(direct_kitchen.camera.unproject_position(bottom_ingredient.global_position)) != bottom_ingredient:
		_fail("Expanded bottom pantry row cannot be clicked")
		return
	var sign_area: Area3D
	for area in direct_kitchen.find_children("*", "Area3D", true, false):
		if str(area.get_meta("kind", "")) == "close_sign":
			sign_area = area
			break
	if not is_instance_valid(sign_area):
		_fail("Hanging closing sign has no physical click area")
		return
	var closing_click := InputEventMouseButton.new()
	closing_click.button_index = MOUSE_BUTTON_LEFT
	closing_click.pressed = true
	closing_click.position = direct_kitchen.camera.unproject_position(sign_area.global_position)
	if direct_kitchen._ray_pick(closing_click.position) != sign_area:
		_fail("Hanging closing sign is visually occluded by another click area")
		return
	direct_kitchen._input(closing_click)
	_release_click(direct_kitchen, closing_click)
	if str(direct.restaurant.snapshot().get("stage", "")) != "closed" or not direct_kitchen.get("_settlement_overlay").visible:
		_fail("Physical closing sign did not open settlement")
		return
	direct_kitchen.reopen_requested.emit()
	if not bool(direct.restaurant.snapshot().get("active", false)) or not bool(direct.restaurant.snapshot().get("endless", false)):
		_fail("Settlement continue control did not resume endless service")
		return
	direct._on_kitchen_close()
	direct._save_state()
	direct.queue_free()
	await get_tree().process_frame
	direct = Slice.new()
	direct.save_path = DIRECT_SAVE
	direct.start_in_kitchen = true
	add_child(direct)
	await get_tree().physics_frame
	if not bool(direct.restaurant.snapshot().get("active", false)) or not bool(direct.restaurant.snapshot().get("endless", false)):
		_fail("Saved closing state did not directly reopen endless service")
		return
	if direct.get("_kitchen").get("_settlement_overlay").visible:
		_fail("Settlement obscured the kitchen after relaunch")
		return
	direct.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
		if FileAccess.file_exists(DIRECT_SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIRECT_SAVE + suffix))
	AudioManager.shutdown()
	print("TALENT_PARK_KITCHEN_OK: direct endless entry, physical prep and closing, settlement save resume, parallel heat lanes")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)


func _release_click(view: Node, click: InputEventMouseButton, release_position := Vector2.INF) -> void:
	click.pressed = false
	if release_position != Vector2.INF:
		click.position = release_position
	view._input(click)
	click.pressed = true
