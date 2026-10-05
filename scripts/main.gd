extends Node

const MenuScript := preload("res://scripts/ui/main_menu.gd")
const TalentParkSliceScript := preload("res://scripts/city3d/city_talent_park_slice.gd")

var menu: CanvasLayer
var hud
var world
var city_slice: Node3D
var in_game := false
var _legacy_mode := false
var _preview_save_path := ""

func _ready() -> void:
	if OS.has_feature("mobile") and not OS.has_feature("web"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if "--entry-route-test" in OS.get_cmdline_user_args():
		_enter_talent_park("user://entry_route_test_unused.json")
		_check_entry_route.call_deferred()
		return
	if "--talent-park-test" in OS.get_cmdline_user_args():
		add_child(load("res://tests/talent_park_kitchen_integration_test.gd").new())
		return
	if "--talent-park-audio-test" in OS.get_cmdline_user_args():
		add_child(load("res://tests/talent_park_audio_and_station_test.gd").new())
		return
	if "--talent-park-parallel-stress" in OS.get_cmdline_user_args():
		add_child(load("res://tests/talent_park_parallel_stress_test.gd").new())
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-new-menu="):
			_show_main_menu()
			_capture_preview.call_deferred(argument.trim_prefix("--capture-new-menu="))
			return
		if argument.begins_with("--capture-talent-park="):
			_preview_save_path = "user://tests/talent_park_preview_%d.json" % Time.get_ticks_usec()
			_enter_talent_park(_preview_save_path, false)
			if "--park-wide" in OS.get_cmdline_user_args():
				get_window().size = Vector2i(1920, 1080)
			for preview_argument in OS.get_cmdline_user_args():
				if preview_argument.begins_with("--park-clock="):
					var preview_minutes := clampi(int(preview_argument.trim_prefix("--park-clock=")), 480, 1319)
					city_slice.restaurant.tick(float(preview_minutes - 480))
					city_slice._update_service_lighting()
			if "--park-overview" in OS.get_cmdline_user_args():
				city_slice.set("_overview", true)
				city_slice.set("_zoom", city_slice.park.OVERVIEW_SPAN)
				city_slice._update_camera(1.0, true)
			if "--park-shift" in OS.get_cmdline_user_args():
				city_slice._interact(city_slice.get_node("ParkInteract_calm"))
			if "--park-endless-preview" in OS.get_cmdline_user_args() or "--park-closed-preview" in OS.get_cmdline_user_args():
				city_slice.restaurant.start_shift("calm", true)
				city_slice._enter_kitchen()
				if "--park-closed-preview" in OS.get_cmdline_user_args():
					city_slice.restaurant.close_day()
				if "--park-prep-shortage-demo" in OS.get_cmdline_user_args():
					var shortage_preview: Dictionary = city_slice.restaurant.snapshot()
					for ingredient_key in ["rice_flour", "leafy_greens", "soy_sauce"]:
						(shortage_preview["prep_ingredients"] as Dictionary)[ingredient_key] = 0
					(shortage_preview["raw_ingredients"] as Dictionary)["rice_flour"] = 0
					city_slice.restaurant.restore(shortage_preview)
				if "--park-single-ticket-preview" in OS.get_cmdline_user_args():
					var single_tickets: Array = city_slice.restaurant.get("_tickets")
					single_tickets.resize(1)
					city_slice.restaurant.set("_tickets", single_tickets)
					city_slice.restaurant.call("_emit_state")
				if "--park-prep-loaded-demo" in OS.get_cmdline_user_args():
					var loaded_preview: Dictionary = city_slice.restaurant.snapshot()
					for ingredient_key in ["rice_flour", "leafy_greens", "soy_sauce"]:
						(loaded_preview["prep_ingredients"] as Dictionary)[ingredient_key] = TalentParkRestaurant3D.PREP_BATCH_TARGET
					city_slice.restaurant.restore(loaded_preview)
				if "--park-raw-pick-demo" in OS.get_cmdline_user_args():
					city_slice.restaurant.take_raw_group("staples")
			if "--park-stock-substitute-demo" in OS.get_cmdline_user_args():
				city_slice._interact(city_slice.get_node("ParkInteract_calm"))
				var substitute_preview: Dictionary = city_slice.restaurant.snapshot()
				(substitute_preview["raw_ingredients"] as Dictionary)["rice_flour"] = 0
				(substitute_preview["stock_units"] as Dictionary)["rice_batter"] = [90.0, 90.0, 90.0]
				city_slice.restaurant.restore(substitute_preview)
			if "--park-rush-wave" in OS.get_cmdline_user_args():
				city_slice._interact(city_slice.get_node("ParkInteract_rush"))
				city_slice.restaurant.tick(float(city_slice.restaurant.snapshot().get("rush_wave_at", 10.0)) + 0.1)
			if "--park-parallel-heat-demo" in OS.get_cmdline_user_args():
				city_slice._interact(city_slice.get_node("ParkInteract_rush"))
				city_slice.restaurant.tick(float(city_slice.restaurant.snapshot().get("rush_wave_at", 10.0)) + 0.1)
				var parallel_tickets: Array = city_slice.restaurant.get("_tickets")
				for lane in range(mini(3, parallel_tickets.size())):
					var parallel_ticket: Dictionary = parallel_tickets[lane]
					var parallel_recipe_index: int = [0, 7, 8][lane]
					var parallel_recipe: Dictionary = TalentParkRestaurant3D.RECIPES[parallel_recipe_index]
					parallel_ticket["recipe_index"] = parallel_recipe_index
					parallel_ticket["started"] = true
					parallel_ticket["step_index"] = (parallel_recipe["steps"] as Array).find("steam")
					parallel_ticket["heat_left"] = 1.6
					parallel_ticket["pickup_left"] = 0.0
					parallel_tickets[lane] = parallel_ticket
				city_slice.restaurant.set("_tickets", parallel_tickets)
				city_slice.restaurant.call("_emit_state")
			if "--park-ticket-queue-demo" in OS.get_cmdline_user_args():
				city_slice._interact(city_slice.get_node("ParkInteract_rush"))
				city_slice.restaurant.tick(float(city_slice.restaurant.snapshot().get("rush_wave_at", 10.0)) + 0.1)
				city_slice.restaurant.select_order(0)
				city_slice.restaurant.select_order(1)
			if "--park-ticket-shortage-demo" in OS.get_cmdline_user_args():
				city_slice._interact(city_slice.get_node("ParkInteract_calm"))
				city_slice.restaurant.select_order(0)
				var ticket_prep: Dictionary = city_slice.restaurant.get("_prep_ingredients")
				for ingredient_key in ["rice_flour", "leafy_greens", "soy_sauce"]:
					ticket_prep[ingredient_key] = 0
				city_slice.restaurant.set("_prep_ingredients", ticket_prep)
				city_slice.restaurant.call("_emit_state")
			for preview_argument in OS.get_cmdline_user_args():
				if not preview_argument.begins_with("--park-stage-demo="):
					continue
				var parts := preview_argument.trim_prefix("--park-stage-demo=").split(":")
				if parts.size() != 2:
					continue
				var recipe_index := -1
				var next_index := -1
				for index in range(TalentParkRestaurant3D.RECIPES.size()):
					var recipe: Dictionary = TalentParkRestaurant3D.RECIPES[index]
					if str(recipe["id"]) == parts[0]:
						recipe_index = index
						next_index = (recipe["steps"] as Array).find(parts[1]) + 1
						break
				if recipe_index < 0 or next_index < 1:
					continue
				city_slice._interact(city_slice.get_node("ParkInteract_calm"))
				var demo_tickets: Array = city_slice.restaurant.get("_tickets")
				var demo_ticket: Dictionary = demo_tickets[0]
				demo_ticket["recipe_index"] = recipe_index
				demo_ticket["step_index"] = next_index
				demo_tickets[0] = demo_ticket
				city_slice.restaurant.set("_tickets", demo_tickets)
				city_slice.restaurant.call("_emit_state")
			if "--park-combo-preview" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				if not bool(city_slice.restaurant.snapshot().get("active", false)):
					city_slice.restaurant.start_shift("calm")
				for order_number in [1, 2]:
					var combo_tickets: Array = city_slice.restaurant.get("_tickets")
					for combo_slot in range(combo_tickets.size()):
						var combo_ticket: Dictionary = combo_tickets[combo_slot]
						if int(combo_ticket.get("order_number", 0)) != order_number:
							continue
						city_slice.restaurant.select_order(combo_slot)
						var combo_recipe: Dictionary = TalentParkRestaurant3D.RECIPES[int(combo_ticket["recipe_index"])]
						combo_ticket["step_index"] = (combo_recipe["steps"] as Array).size() - 1
						combo_tickets[combo_slot] = combo_ticket
						city_slice.restaurant.set("_tickets", combo_tickets)
						city_slice.restaurant.interact("serve")
						break
			if "--park-cash-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.get("_kitchen").show_feedback({"ok": true, "event": "served_combo", "earned": 168, "customer_id": 1})
			if "--park-dish" in OS.get_cmdline_user_args():
				city_slice._interact(city_slice.get_node("ParkInteract_calm"))
				city_slice.restaurant.interact("wash")
				city_slice.restaurant.interact("mix")
				city_slice.restaurant.interact("steam")
				city_slice.restaurant.tick(3.1)
				city_slice.restaurant.interact("garnish")
				if "--park-serve" in OS.get_cmdline_user_args():
					city_slice.restaurant.interact("serve")
			if "--park-heat-demo" in OS.get_cmdline_user_args() or "--park-heat-ready-demo" in OS.get_cmdline_user_args():
				city_slice._interact(city_slice.get_node("ParkInteract_calm"))
				city_slice.restaurant.interact("wash")
				city_slice.restaurant.interact("mix")
				city_slice.restaurant.interact("steam")
				city_slice.restaurant.tick(3.1 if "--park-heat-ready-demo" in OS.get_cmdline_user_args() else 0.5)
			if "--park-stock-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.restaurant.prepare_stock("rice_batter")
				city_slice.restaurant.interact("wash")
				city_slice.restaurant.interact("mix")
				city_slice.restaurant.tick(60.0)
				city_slice.restaurant.prepare_stock("spice_oil")
				city_slice.restaurant.interact("slice")
				city_slice.restaurant.interact("mix")
			if "--park-stock-handoff-demo" in OS.get_cmdline_user_args() or "--park-stock-take-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.restaurant.prepare_stock("rice_batter")
				city_slice.restaurant.interact("wash")
				city_slice.restaurant.interact("mix")
				if "--park-stock-take-demo" in OS.get_cmdline_user_args():
					city_slice.restaurant.start_shift("calm")
					city_slice.restaurant.prepare_stock("rice_batter")
			if "--park-slice-action-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.restaurant.start_shift("calm")
				city_slice.restaurant.select_order(1)
				city_slice.restaurant.interact("slice")
			if "--park-wash-action-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.restaurant.start_shift("calm")
				city_slice.restaurant.interact("wash")
			if "--park-rice-wash-action-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.restaurant.prepare_stock("rice_batter")
				city_slice.restaurant.interact("wash")
			if "--park-mix-action-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.restaurant.start_shift("calm")
				city_slice.restaurant.interact("wash")
				await get_tree().create_timer(0.75).timeout
				city_slice.restaurant.interact("mix")
			if "--park-spice-mix-action-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.restaurant.tick(1080.0 - 480.0)
				city_slice.restaurant.start_shift("calm")
				city_slice.restaurant.select_order(1)
				city_slice.restaurant.interact("slice")
				await get_tree().create_timer(0.75).timeout
				city_slice.restaurant.interact("mix")
			if "--park-spice-slice-action-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				city_slice.restaurant.prepare_stock("spice_oil")
				city_slice.restaurant.interact("slice")
			if "--park-gallery" in OS.get_cmdline_user_args():
				city_slice._open_gallery()
				if "--park-food-gallery" in OS.get_cmdline_user_args():
					city_slice.get("_gallery").show_asset(7)
				if "--park-staff-gallery" in OS.get_cmdline_user_args():
					city_slice.get("_gallery").show_asset(17)
				for gallery_argument in OS.get_cmdline_user_args():
					if gallery_argument.begins_with("--park-gallery-index="):
						city_slice.get("_gallery").show_asset(int(gallery_argument.trim_prefix("--park-gallery-index=")))
			if "--park-paused" in OS.get_cmdline_user_args():
				var pause_event := InputEventKey.new()
				pause_event.keycode = KEY_P
				pause_event.pressed = true
				city_slice._unhandled_input(pause_event)
			if "--park-food-stage-demo" in OS.get_cmdline_user_args() or "--park-three-lanes-demo" in OS.get_cmdline_user_args() or "--park-steam-stage-demo" in OS.get_cmdline_user_args() or "--park-wash-stage-demo" in OS.get_cmdline_user_args() or "--park-slice-stage-demo" in OS.get_cmdline_user_args():
				city_slice._enter_kitchen()
				var kitchen: Node3D = city_slice.get("_kitchen")
				var holders: Array = kitchen.get("_ticket_food")
				var stage_samples := [
					["mix", "fruit_ice", "mix", 0],
					["fry", "morning_egg_bun", "fry", 1],
					["boil", "coconut_millet", "boil", 2]
				]
				if "--park-three-lanes-demo" in OS.get_cmdline_user_args():
					stage_samples = [
						["mix", "fruit_ice", "mix", 0],
						["mix", "garden_rice_roll", "mix", 1],
						["mix", "spice_oil", "mix", 2]
					]
				if "--park-steam-stage-demo" in OS.get_cmdline_user_args():
					stage_samples = [
						["steam", "garden_rice_roll", "steam", 0],
						["steam", "bay_shrimp_roll", "steam", 1],
						["steam", "seaweed_dumpling", "steam", 2]
					]
					var closed_steamer: Node3D = kitchen.get("_steam_fixture")
					closed_steamer.visible = false
				if "--park-wash-stage-demo" in OS.get_cmdline_user_args():
					stage_samples = [
						["wash", "fruit_ice", "slice", 0],
						["wash", "coconut_millet", "boil", 1],
						["wash", "bay_shrimp_roll", "mix", 2]
					]
				if "--park-slice-stage-demo" in OS.get_cmdline_user_args():
					stage_samples = [
						["slice", "morning_egg_bun", "slice", 0],
						["slice", "macao_spice_bun", "slice", 1],
						["slice", "fruit_ice", "slice", 2]
					]
				for sample_index in range(stage_samples.size()):
					var sample: Array = stage_samples[sample_index]
					var holder: Node3D = holders[sample_index]
					kitchen.call("_load_process_visual", holder, sample[0], sample[1], [], sample_index)
					if "--park-steam-stage-demo" in OS.get_cmdline_user_args():
						holder.position = kitchen.call("_station_food_point", sample[2], sample[3], stage_samples.size(), sample_index)
						holder.scale = Vector3.ONE * float(kitchen.call("_heat_lane_scale", stage_samples.size()))
					else:
						holder.position = kitchen.call("_station_food_point", sample[2], sample[3])
					holder.visible = true
			var preview_kitchen = city_slice.get("_kitchen") if is_instance_valid(city_slice) else null
			if is_instance_valid(preview_kitchen):
				for camera_argument in OS.get_cmdline_user_args():
					if camera_argument.begins_with("--park-camera-pitch="):
						preview_kitchen.set("_camera_pitch", deg_to_rad(float(camera_argument.trim_prefix("--park-camera-pitch="))))
					elif camera_argument.begins_with("--park-camera-yaw="):
						preview_kitchen.set("_camera_yaw", deg_to_rad(float(camera_argument.trim_prefix("--park-camera-yaw="))))
				preview_kitchen.call("_apply_camera_pose")
			_capture_preview.call_deferred(argument.trim_prefix("--capture-talent-park="))
			return
	if "--talent-park" in OS.get_cmdline_user_args():
		_enter_talent_park()
		return
	if "--city3d-feature-test" in OS.get_cmdline_user_args():
		var feature_test := load("res://tests/city3d_feature_test.gd")
		add_child(feature_test.new())
		return
	if "--city3d-shore-test" in OS.get_cmdline_user_args():
		var shore_test := load("res://tests/city3d_shore_test.gd")
		add_child(shore_test.new())
		return
	if "--city3d-smoke" in OS.get_cmdline_user_args():
		var city_test := load("res://tests/city3d_smoke_test.gd")
		add_child(city_test.new())
		return
	if "--full-simulation" in OS.get_cmdline_user_args():
		var simulation_script := load("res://tests/full_progression_test.gd")
		add_child(simulation_script.new())
		return
	if "--playtest" in OS.get_cmdline_user_args():
		get_tree().auto_accept_quit = false
		var playtest_script := load("res://tests/playtest_runner.gd")
		add_child(playtest_script.new())
		return
	if "--economy-check" in OS.get_cmdline_user_args():
		var economy_check_script := load("res://tests/economy_check.gd")
		add_child(economy_check_script.new())
		return
	if "--scene-check" in OS.get_cmdline_user_args():
		var scene_check_script := load("res://tests/scene_check.gd")
		add_child(scene_check_script.new())
		return
	if "--stress-test" in OS.get_cmdline_user_args():
		var stress_script := load("res://tests/stress_test.gd")
		add_child(stress_script.new())
		return
	if "--world-systems" in OS.get_cmdline_user_args():
		var ws := load("res://tests/world_systems_test.gd")
		add_child(ws.new())
		return
	if "--smoke-test" in OS.get_cmdline_user_args():
		var test_script := load("res://tests/smoke_test.gd")
		add_child(test_script.new())
		return
	get_tree().auto_accept_quit = false
	var capture_path := OS.get_environment("DEEP_CITY_CAPTURE_PREVIEW")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-preview="):
			capture_path = argument.trim_prefix("--capture-preview=")
	var capture_area := ""
	var capture_city3d := ""
	var capture_city3d_x := -1.8
	var capture_city3d_overview := false
	var capture_city3d_job := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-area="):
			capture_area = argument.trim_prefix("--capture-area=")
		if argument.begins_with("--capture-city3d="):
			capture_city3d = argument.trim_prefix("--capture-city3d=")
		if argument.begins_with("--capture-city3d-x="):
			capture_city3d_x = float(argument.trim_prefix("--capture-city3d-x="))
		if argument == "--capture-city3d-overview":
			capture_city3d_overview = true
		if argument.begins_with("--capture-city3d-job="):
			capture_city3d_job = argument.trim_prefix("--capture-city3d-job=")
	if not capture_city3d.is_empty():
		_enter_city_preview()
		city_slice.player.global_position.x = capture_city3d_x
		city_slice._update_chunks()
		city_slice.camera.global_position = city_slice.player.global_position + Vector3(18.0, 23.0, 18.0)
		city_slice.camera.look_at(city_slice.player.global_position + Vector3(0, 0.8, 0))
		if capture_city3d_job in ["restaurant", "courier", "creative"]:
			city_slice.set("_shift", {"career": capture_city3d_job, "mode": "relaxed", "step": 0,
				"correct": 0, "total": 3, "seconds": 45.0,
				"phase": "prepare" if capture_city3d_job == "restaurant" else ("pickup" if capture_city3d_job == "courier" else "inspiration")})
		if capture_city3d_overview:
			city_slice.set("_overview", true)
			city_slice.set("_target_zoom", 5700.0)
			city_slice.camera.size = 5700.0
			city_slice.camera.global_position = Vector3(-600, 0, 0) + Vector3(18.0, 23.0, 18.0).normalized() * 7695.0
			city_slice.camera.look_at(Vector3(-600, 0, 0))
			city_slice._update_chunks()
		_capture_preview.call_deferred(capture_city3d)
		return
	if not capture_path.is_empty():
		_start_new_game()
		if not capture_area.is_empty():
			SceneRouter.travel_to(capture_area, "entrance")
		_capture_preview.call_deferred(capture_path)
		return
	if "--legacy-2d" in OS.get_cmdline_user_args():
		_legacy_mode = true
		_show_legacy_menu()
		return
	_enter_talent_park()

func _show_main_menu() -> void:
	if _legacy_mode:
		_show_legacy_menu()
		return
	in_game = false
	_clear_game_nodes()
	TimeSystem.set_paused(true)
	AudioManager.play_music("menu_ambient")
	menu = MenuScript.new()
	add_child(menu)
	menu.connect("city_preview_requested", _enter_talent_park)
	menu.connect("gallery_requested", _enter_talent_park_gallery)

func _show_legacy_menu() -> void:
	in_game = false
	_clear_game_nodes()
	TimeSystem.set_paused(true)
	AudioManager.play_music("menu_ambient")
	menu = load("res://scripts/ui/legacy_main_menu.gd").new()
	add_child(menu)
	menu.connect("new_game_requested", _start_new_game)
	menu.connect("continue_requested", _enter_game)

func _check_entry_route() -> void:
	await get_tree().process_frame
	if not is_instance_valid(city_slice) or city_slice.name != "TalentParkPlayable" or not is_instance_valid(city_slice.get("_kitchen")):
		push_error("ENTRY_ROUTE_TEST_FAIL: direct restaurant entry")
		get_tree().quit(1)
		return
	var restaurant_state: Dictionary = city_slice.restaurant.snapshot()
	if not bool(restaurant_state.get("active", false)) or not bool(restaurant_state.get("endless", false)):
		push_error("ENTRY_ROUTE_TEST_FAIL: kitchen did not start endless service")
		get_tree().quit(1)
		return
	city_slice.set("_closing", true)
	city_slice.emit_signal("return_to_menu_requested")
	await get_tree().process_frame
	if not is_instance_valid(menu) or not menu is MainMenu or is_instance_valid(city_slice):
		push_error("ENTRY_ROUTE_TEST_FAIL: new-only return menu")
		get_tree().quit(1)
		return
	print("ENTRY_ROUTE_TEST_PASS: direct endless restaurant entry and new-only return")
	get_tree().quit(0)

func _enter_talent_park_gallery() -> void:
	_enter_talent_park()
	city_slice.call_deferred("_open_gallery")

func _enter_talent_park(custom_save_path: String = "user://talent_park_mvp.json", direct_kitchen: bool = true) -> void:
	_clear_game_nodes()
	in_game = false
	TimeSystem.set_paused(true)
	city_slice = TalentParkSliceScript.new()
	city_slice.save_path = custom_save_path
	city_slice.start_in_kitchen = direct_kitchen
	add_child(city_slice)
	city_slice.connect("return_to_menu_requested", _show_main_menu)

func _enter_city_preview() -> void:
	_clear_game_nodes()
	in_game = false
	TimeSystem.set_paused(true)
	city_slice = load("res://scripts/city3d/city_slice.gd").new()
	add_child(city_slice)
	city_slice.connect("return_to_menu_requested", _show_main_menu)

func _start_new_game() -> void:
	GameState.reset_new_game()
	_enter_game()
	StoryManager.begin_new_story.call_deferred()

func _enter_game() -> void:
	_clear_game_nodes()
	in_game = true
	TimeSystem.set_paused(false)
	hud = load("res://scripts/ui/hud.gd").new()
	add_child(hud)
	world = load("res://scripts/gameplay/world.gd").new()
	add_child(world)
	world.shop_requested.connect(hud.open_shop)
	world.inventory_requested.connect(hud.open_inventory)
	world.npc_requested.connect(hud.open_dialogue)
	world.market_requested.connect(hud.open_market)
	world.expedition_map_requested.connect(hud.open_expedition_map)
	world.bank_requested.connect(hud.open_bank_service)
	world.farm_requested.connect(func(_plot_index: int) -> void: hud.open_farm())
	world.pet_shop_requested.connect(hud.open_pets)
	world.furniture_requested.connect(hud.open_room)
	world.kitchen_requested.connect(hud.open_kitchen)
	world.staff_requested.connect(hud.open_staff)
	world.career_requested.connect(func(line_id: String) -> void: hud.open_career(line_id))
	world.wardrobe_requested.connect(hud.open_wardrobe)
	world.storage_requested.connect(hud.open_storage)
	world.shipping_requested.connect(hud.open_shipping_bin)
	hud.modal_changed.connect(_on_modal_changed)
	hud.return_to_menu_requested.connect(_show_main_menu)
	GameState.monthly_summary_ready.connect(hud.show_month_summary)
	AudioManager._refresh_ambient_track()
	if SaveManager.has_save():
		NoticeManager.show_message("F1 图鉴 · F2 工作 · F3 服装 · H 招工 · F5/F9 存读档 · F6 合作房间", "hint")

func _clear_game_nodes() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
		menu = null
	if is_instance_valid(world):
		world.queue_free()
		world = null
	if is_instance_valid(hud):
		hud.queue_free()
		hud = null
	if is_instance_valid(city_slice):
		city_slice.queue_free()
		city_slice = null

func _unhandled_input(event: InputEvent) -> void:
	if not in_game:
		return
	if event.is_action_pressed("save_game"):
		SaveManager.save_game(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("load_game"):
		SaveManager.load_game(true)
		get_viewport().set_input_as_handled()

func _on_modal_changed(is_open: bool) -> void:
	if is_instance_valid(world):
		world.set_player_input_locked(is_open)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if in_game:
			SaveManager.save_game(false)
		elif is_instance_valid(city_slice) and city_slice.has_method("_save_state"):
			city_slice._save_state()
		get_tree().quit()

func _capture_preview(output_path: String) -> void:
	var capture_frames := 8
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-frames="):
			capture_frames = clampi(int(argument.trim_prefix("--preview-frames=")), 1, 180)
	for frame in range(capture_frames):
		await get_tree().process_frame
	if "--perf-stats" in OS.get_cmdline_user_args() and is_instance_valid(city_slice) and is_instance_valid(city_slice.get("_kitchen")):
		var kitchen_view: Node = city_slice.get("_kitchen")
		var mesh_nodes := kitchen_view.find_children("*", "MeshInstance3D", true, false)
		var unique_meshes: Dictionary = {}
		for mesh_node in mesh_nodes:
			var mesh: Mesh = (mesh_node as MeshInstance3D).mesh
			if mesh != null:
				unique_meshes[mesh.get_instance_id()] = true
		print("KITCHEN_PERF: meshes=%d unique_meshes=%d draw_calls=%d primitives=%d process_ms=%.3f" % [mesh_nodes.size(), unique_meshes.size(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), 1000.0 * Performance.get_monitor(Performance.TIME_PROCESS)])
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	if error == OK:
		print("PREVIEW_SAVED:" + output_path)
	else:
		push_error("PREVIEW_SAVE_FAILED:%d" % error)
	if not _preview_save_path.is_empty():
		if is_instance_valid(city_slice):
			city_slice.set("_closing", true)
			_clear_game_nodes()
			await get_tree().process_frame
		for suffix in ["", ".bak", ".tmp"]:
			var filename: String = _preview_save_path + str(suffix)
			if FileAccess.file_exists(filename):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
		_preview_save_path = ""
	AudioManager.shutdown()
	await get_tree().process_frame
	get_tree().quit(error)
