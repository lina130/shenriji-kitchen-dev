class_name CityTalentParkSlice3D
extends Node3D

signal return_to_menu_requested

const PlayerScript := preload("res://scripts/city3d/city_player.gd")
const HudScript := preload("res://scripts/city3d/city_hud.gd")
const RestaurantScript := preload("res://scripts/city3d/talent_park_restaurant.gd")
const SaveScript := preload("res://scripts/city3d/talent_park_save.gd")
const FxScript := preload("res://scripts/city3d/city_interaction_fx.gd")
const CAFE_MODEL := "res://assets/art/models/sz_park_bookbar_cafe.glb"
const REACH := 1.8
const STATIONS := {
	"kitchen": [Vector3(0.0, 0.8, 3.2), "进入湖畔餐馆"],
	"calm": [Vector3(-3.2, 0.8, 4.2), "悠闲班铃"],
	"rush": [Vector3(-1.8, 0.8, 4.2), "忙碌班铃"],
	"drink": [Vector3(4.8, 0.8, 3.5), "买杯果茶 · 15贝"],
	"souvenir": [Vector3(5.0, 0.8, 5.2), "海风马克杯 · 60贝"],
	"rest": [Vector3(-5.8, 0.8, 6.0), "长椅休息 · 新的一天"]
}

var player: CharacterBody3D
var camera: Camera3D
var hud
var park
var restaurant
var save_path := "user://talent_park_mvp.json"
var start_in_kitchen := false
var state: Dictionary = {}
var _save_store = SaveScript.new()
var _anchor := Vector3(-310, 0, 120)
var _yaw := deg_to_rad(12.0)
var _pitch := deg_to_rad(46.0)
var _zoom := 22.0
var _overview := false
var _orbiting := false
var _pending: Area3D
var _fx
var _held: Node3D
var _cook_visual: Node3D
var _souvenir_visual: Node3D
var _customer: Node3D
var _gallery: Node3D
var _kitchen: Node3D
var _roof_parts: Array[Node3D] = []
var _autosave_clock := 0.0
var _save_pending := false
var _save_delay := 0.0
var _critical_save_queued := false
var _last_stage := ""
var _closing := false
var _window_focused := true
var _manual_pause := false
var _lighting_environment: Environment
var _sun_light: DirectionalLight3D
var _cafe_lamp: OmniLight3D
var _lighting_elapsed := 0.0
var _next_shift_mode := "calm"

func _ready() -> void:
	name = "TalentParkPlayable"
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web") and not OS.has_feature("mobile"):
		if SettingsManager.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
			DisplayServer.window_set_min_size(Vector2i(960, 600))
			var window_size: Vector2i = SettingsManager.get_window_presets()[SettingsManager.window_preset_index]
			DisplayServer.window_set_size(window_size)
			var screen := DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(screen.position + (screen.size - window_size) / 2)
			var previewing := false
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--capture-talent-park=") and not OS.get_cmdline_user_args().has("--park-maximized-preview"):
					previewing = true
			if not previewing:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		DisplayServer.window_set_title("深日记 · 人才公园餐馆试玩")
	_build_lighting()
	AudioManager.play_music("park_ambient")
	park = load("res://scripts/city3d/city_talent_park.gd").new()
	add_child(park)
	_anchor = park.RESTAURANT_ANCHOR
	_build_cafe()
	state = _save_store.load_state(save_path)
	player = PlayerScript.new()
	player.position = _anchor + Vector3(0, 0.35, 5.5)
	var saved: Array = state.get("position", [])
	if saved.size() == 3:
		var at := Vector3(float(saved[0]), float(saved[1]), float(saved[2]))
		if at.y > -1.0 and at.y < 12.0 and park.is_walkable_position(at):
			player.position = at + Vector3(0, 0.08, 0)
	add_child(player)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom
	camera.far = 15000.0
	camera.current = true
	add_child(camera)
	player.movement_camera = camera
	_update_camera(1.0, true)
	hud = HudScript.new()
	add_child(hud)
	hud.set_district("深圳湾 · 人才公园")
	var gallery_button := Button.new()
	gallery_button.text = "已完成素材 · F2"
	gallery_button.position = Vector2(28, 141)
	gallery_button.custom_minimum_size = Vector2(184, 34)
	gallery_button.pressed.connect(_open_gallery)
	hud.get_node("CityHudRoot").add_child(gallery_button)
	_fx = FxScript.new()
	add_child(_fx)
	restaurant = RestaurantScript.new()
	add_child(restaurant)
	restaurant.state_changed.connect(_on_order_changed)
	restaurant.event_happened.connect(_on_order_event)
	restaurant.shift_finished.connect(_on_shift_finished)
	restaurant.restore(state.get("restaurant", {}))
	restaurant.align_day(int(state["day"]))
	_next_shift_mode = str(state.get("next_shift_mode", "calm"))
	if not RestaurantScript.MODES.has(_next_shift_mode):
		_next_shift_mode = "calm"
	if start_in_kitchen:
		var restored_service: Dictionary = restaurant.snapshot()
		if not bool(restored_service.get("active", false)):
			restaurant.start_shift(_next_shift_mode, true)
		elif not bool(restored_service.get("endless", false)):
			restaurant.make_endless()
	_update_service_lighting()
	_refresh_status()
	hud.show_notice("湖畔餐馆开门了，欢迎来坐坐。")
	if start_in_kitchen or bool(restaurant.snapshot().get("active", false)):
		_enter_kitchen.call_deferred()
	if DisplayServer.get_name() != "headless":
		get_window().focus_entered.connect(_on_window_focus_changed.bind(true))
		get_window().focus_exited.connect(_on_window_focus_changed.bind(false))
	set_process(true)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(restaurant):
		return
	if DisplayServer.get_name() != "headless" and _window_focused != get_window().has_focus():
		_on_window_focus_changed(get_window().has_focus())
	_update_camera(delta)
	if not _actions_paused():
		restaurant.tick(delta)
		_autosave_clock += delta
		_lighting_elapsed += delta
		if _lighting_elapsed >= 0.5:
			_lighting_elapsed = 0.0
			_update_service_lighting()
			if is_instance_valid(_kitchen):
				var kitchen_minutes: float = restaurant.clock_minutes()
				_kitchen.set_clock_minutes(kitchen_minutes)
				AudioManager.play_kitchen_music(kitchen_minutes)
	if _save_pending:
		_save_delay -= delta
		if _save_delay <= 0.0:
			_save_state()
	if _autosave_clock >= 10.0:
		_autosave_clock = 0.0
		_save_state()
	if is_instance_valid(_cook_visual) and not _actions_paused():
		_cook_visual.rotation.y += delta * 0.5
	if player.global_position.y < -4.0:
		player.global_position = _anchor + Vector3(0, 0.4, 5.5)
		player.velocity = Vector3.ZERO
		player.stop_auto_move()
		hud.show_notice("回到了店前的步道。")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(hud):
		return
	player.input_locked = _actions_paused() or is_instance_valid(_kitchen)
	if is_instance_valid(_gallery):
		return
	if is_instance_valid(_kitchen):
		_fx.clear_target()
		return
	if _manual_pause or not _window_focused:
		_fx.clear_target()
		hud.set_prompt("已暂停 · 按 P 继续" if _manual_pause else "已暂停 · 返回游戏窗口继续")
		return
	if _overview:
		_fx.clear_target()
		hud.set_prompt("M 返回店前视角 · 右键转动 · 滚轮缩放")
		return
	if Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.001:
		_cancel_pending()
	if is_instance_valid(_pending) and _distance(_pending) < REACH:
		player.stop_auto_move()
		_interact(_pending)
		_pending = null
	var target := _nearest()
	if is_instance_valid(target):
		_fx.mark_target(target)
		hud.set_prompt("E / 左键  " + str(target.get_meta("display_name")))
	else:
		_fx.clear_target()
		hud.set_prompt("沿湖走走，或回餐馆开一班")

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_gallery):
		return
	if is_instance_valid(_kitchen):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_P:
				_manual_pause = not _manual_pause
				_kitchen.set_interaction_enabled(not _actions_paused())
				if _manual_pause:
					_save_state()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F5:
				_save_state()
				get_viewport().set_input_as_handled()
				return
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_manual_pause = not _manual_pause
			_cancel_pending()
			player.input_locked = _actions_paused()
			if _manual_pause:
				_save_state()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F2:
			_open_gallery()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_M:
			_overview = not _overview
			_zoom = park.OVERVIEW_SPAN if _overview else 22.0
			_cancel_pending()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F5:
			_save_state()
			hud.show_notice("进度已保存。")
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		if _overview:
			_overview = false
			_zoom = 22.0
		else:
			_save_state()
			_closing = true
			return_to_menu_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom = clampf(_zoom * (0.80 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25), 12.0, 2700.0)
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _actions_paused():
			_click(event.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _orbiting:
		_yaw += event.relative.x * 0.007
		_pitch = clampf(_pitch - event.relative.y * 0.005, deg_to_rad(25.0), deg_to_rad(78.0))
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and not _actions_paused():
		_cancel_pending()
		var target := _nearest()
		if is_instance_valid(target):
			_interact(target)
		get_viewport().set_input_as_handled()

func _actions_paused() -> bool:
	return _manual_pause or not _window_focused or _overview or is_instance_valid(_gallery)

func _cancel_pending() -> void:
	_pending = null
	if is_instance_valid(player):
		player.stop_auto_move()

func _on_window_focus_changed(focused: bool) -> void:
	_window_focused = focused
	if not focused:
		_orbiting = false
		_cancel_pending()
		_save_state()
	if is_instance_valid(player):
		player.input_locked = _actions_paused() or is_instance_valid(_kitchen)
	if is_instance_valid(_kitchen):
		_kitchen.set_interaction_enabled(not _actions_paused())

func _click(screen_at: Vector2) -> void:
	if camera.size > 100.0:
		return
	var start := camera.project_ray_origin(screen_at)
	var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(screen_at) * 600.0, 3)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	if hit.collider is Area3D and hit.collider.is_in_group("talent_park_interactable"):
		_pending = hit.collider
		if _distance(_pending) < REACH:
			_interact(_pending)
			_pending = null
		else:
			player.move_toward_point(_pending.global_position + Vector3(0, 0, 0.85))
	else:
		_pending = null
		player.move_toward_point(hit.position)

func _interact(area: Area3D) -> void:
	var id := str(area.get_meta("interaction_id"))
	var order: Dictionary = restaurant.snapshot()
	if id in ["calm", "rush"]:
		if bool(order["active"]):
			_enter_kitchen()
		elif restaurant.start_shift(id, true):
			_zoom = 18.0
			_enter_kitchen()
			_save_state()
	elif id == "kitchen":
		_enter_kitchen()
	elif id == "drink":
		if _spend(15):
			state["purchases"]["fruit_tea_count"] = int(state["purchases"].get("fruit_tea_count", 0)) + 1
			_save_state()
			hud.show_notice("买了一杯冰果茶，坐在湖边慢慢喝。")
	elif id == "souvenir":
		if bool(state["purchases"].get("bay_mug", false)):
			hud.show_notice("海风杯已经摆在店里了。")
		elif _spend(60):
			state["purchases"]["bay_mug"] = true
			_save_state()
			hud.show_notice("买下海风马克杯，摆到店前的小桌上。")
	elif id == "rest":
		if bool(order["active"]):
			hud.show_notice("先挂上打烊牌，再来湖边休息吧。")
		else:
			restaurant.advance_to_next_day()
			state["day"] = int(restaurant.snapshot().get("service_day", int(state["day"]) + 1))
			state["energy"] = 100
			_update_service_lighting()
			_save_state()
			hud.show_notice("吹吹海风，休息好了。又是新的一天。")

func _spend(amount: int) -> bool:
	if int(state["cash"]) < amount:
		hud.show_notice("钱还不够，营业赚些贝再来。")
		return false
	state["cash"] = int(state["cash"]) - amount
	return true

func _on_order_event(result: Dictionary) -> void:
	var event_id := str(result.get("event", ""))
	var action_id := str(result.get("action_id", ""))
	if event_id in ["served", "served_combo"]:
		AudioManager.play_sfx("kitchen_serve")
	elif event_id in ["overcooked", "order_expired", "wrong_action", "dish_cooled", "ingredient_shortage", "buffer_spoiled"]:
		AudioManager.play_sfx("kitchen_warning")
	elif event_id == "rush_wave":
		AudioManager.play_sfx("kitchen_rush")
	elif event_id in ["raw_restocked", "raw_picked"]:
		AudioManager.play_sfx("kitchen_pantry")
	elif event_id in ["raw_staged", "raw_placed", "prep_cleared", "stock_used"]:
		AudioManager.play_sfx("kitchen_place")
	elif event_id in ["heating", "reheating"]:
		AudioManager.play_sfx("kitchen_" + action_id if action_id in ["steam", "fry", "boil"] else "kitchen_steam")
	elif event_id in ["heat_ready", "reheat_ready"]:
		AudioManager.play_sfx("kitchen_ready")
	elif event_id == "step_done":
		if action_id in ["wash", "slice", "mix", "marinate", "portion", "garnish"]:
			AudioManager.play_sfx("kitchen_" + action_id)
	elif event_id == "stock_prepared":
		AudioManager.play_sfx("kitchen_ready")
	elif event_id == "dish_buffered":
		AudioManager.play_sfx("kitchen_portion")
	state["cash"] = int(state["cash"]) + int(result.get("earned", 0))
	if int(result.get("earned", 0)) > 0 or event_id == "day_closed":
		_queue_critical_save()
	else:
		_queue_save()
	if is_instance_valid(_kitchen):
		_kitchen.set_cash(int(state["cash"]))
		_kitchen.show_feedback(result)
	else:
		hud.show_notice(str(result.get("message", "")))

func _on_shift_finished(summary: Dictionary) -> void:
	if str(summary.get("stage", "")) == "closed":
		hud.show_notice("餐馆打烊，已收入 %d 贝。" % int(summary["earned_total"]))
	else:
		hud.show_notice("本班完成 %d 单，收入 %d 贝。" % [int(summary["served"]), int(summary["earned_total"])])
	_queue_critical_save()
	if is_instance_valid(_kitchen) and str(summary.get("stage", "")) != "closed":
		_kitchen.show_feedback({"ok": true, "event": "shift_finished",
			"message": "本班完成 %d 单，收入 %d 贝。" % [int(summary["served"]), int(summary["earned_total"])]})

func _on_order_changed(order: Dictionary) -> void:
	if is_instance_valid(_kitchen):
		_kitchen.show_state(order)
	_customer.visible = bool(order.get("active", false))
	for roof in _roof_parts:
		roof.visible = not bool(order.get("active", false))
	if bool(order.get("active", false)):
		var stage := str(order["stage"])
		var action: String = str(order.get("next_action", {"prep": "取食材", "heat": "放到加热台", "heating": "等加热完成", "plate": "到装盘台配好", "serve": "端到出餐窗"}.get(stage, "")))
		hud.set_field_task(str(order["order"].get("name", "今日订单")), action,
			"%d / %d" % [int(order["order_number"]), int(order["total_orders"])], float(order["time_left"]))
	else:
		hud.clear_field_task()
	var stage := str(order.get("stage", "idle"))
	if stage != _last_stage:
		_last_stage = stage
	_update_food(stage)

func _enter_kitchen() -> void:
	if is_instance_valid(_kitchen):
		_kitchen.show_state(restaurant.snapshot())
		return
	_cancel_pending()
	# The park sun is global; its low evening angle casts park geometry across
	# the separate kitchen set. Let the kitchen's own lamps light this interior.
	if is_instance_valid(_sun_light):
		_sun_light.visible = false
	AudioManager.warm_kitchen_audio()
	AudioManager.play_kitchen_music(restaurant.clock_minutes())
	player.input_locked = true
	_fx.clear_target()
	hud.hide()
	_kitchen = load("res://scripts/city3d/talent_park_kitchen_view.gd").new()
	_kitchen.position = Vector3(6000, 0, 0)
	add_child(_kitchen)
	_kitchen.action_pressed.connect(_on_kitchen_action)
	_kitchen.dish_pressed.connect(_on_kitchen_dish)
	_kitchen.stock_action_pressed.connect(_on_kitchen_stock_action)
	_kitchen.ticket_pressed.connect(_on_kitchen_ticket)
	_kitchen.stock_pressed.connect(_on_kitchen_stock)
	_kitchen.raw_pressed.connect(_on_kitchen_raw)
	_kitchen.prep_pressed.connect(_on_kitchen_prep)
	_kitchen.buffer_pressed.connect(_on_kitchen_buffer)
	_kitchen.shift_requested.connect(_on_kitchen_shift)
	_kitchen.closing_requested.connect(_on_kitchen_close)
	_kitchen.reopen_requested.connect(_on_kitchen_reopen)
	_kitchen.set_cash(int(state["cash"]))
	_kitchen.show_state(restaurant.snapshot())
	_kitchen.set_next_shift_mode(_next_shift_mode)
	_kitchen.set_interaction_enabled(not _actions_paused())

func _exit_kitchen() -> void:
	if not is_instance_valid(_kitchen):
		return
	_kitchen.queue_free()
	_kitchen = null
	if is_instance_valid(_sun_light):
		_sun_light.visible = true
	AudioManager.play_music("park_ambient")
	camera.current = true
	hud.show()
	player.input_locked = _actions_paused()
	_save_state()

func _on_kitchen_action(action_id: String) -> void:
	if _actions_paused():
		return
	var result: Dictionary = restaurant.interact_station(action_id)
	if not bool(result.get("ok", false)) and str(result.get("event", "")) in ["still_heating", "not_working", "choose_food", "start_or_choose_food"] and is_instance_valid(_kitchen):
		_kitchen.show_feedback(result)
		AudioManager.play_sfx("kitchen_warning")


func _on_kitchen_dish(order_number: int, action_id: String) -> void:
	if _actions_paused():
		return
	var result: Dictionary = restaurant.interact_order(order_number, action_id)
	if not bool(result.get("ok", false)) and str(result.get("event", "")) in ["still_heating", "not_working", "ticket_not_started", "no_ticket"] and is_instance_valid(_kitchen):
		_kitchen.show_feedback(result)
		AudioManager.play_sfx("kitchen_warning")


func _on_kitchen_stock_action(action_id: String) -> void:
	if _actions_paused():
		return
	var result: Dictionary = restaurant.interact_stock_action(action_id)
	if not bool(result.get("ok", false)) and is_instance_valid(_kitchen):
		_kitchen.show_feedback(result)

func _on_kitchen_ticket(slot: int) -> void:
	if _actions_paused():
		return
	if restaurant.has_method("select_order"):
		var result: Dictionary = restaurant.select_order(slot)
		if bool(result.get("ok", false)):
			AudioManager.play_sfx("kitchen_ticket")
		_queue_save()

func _on_kitchen_stock(stock_id: String) -> void:
	if _actions_paused():
		return
	if restaurant.has_method("prepare_stock"):
		restaurant.prepare_stock(stock_id)
		_queue_save()

func _on_kitchen_raw(ingredient_key: String) -> void:
	if _actions_paused():
		return
	if restaurant.has_method("stage_raw_ingredient"):
		var result: Dictionary = restaurant.stage_raw_ingredient(ingredient_key)
		if not bool(result.get("ok", false)) and is_instance_valid(_kitchen):
			_kitchen.show_feedback(result)
			AudioManager.play_sfx("soft_warning")
		_queue_save()

func _on_kitchen_prep() -> void:
	if _actions_paused():
		return
	if restaurant.has_method("place_carried_ingredients"):
		var result: Dictionary = restaurant.place_carried_ingredients()
		if not bool(result.get("ok", false)) and is_instance_valid(_kitchen):
			_kitchen.show_feedback(result)
			AudioManager.play_sfx("soft_warning")
		_queue_save()

func _on_kitchen_buffer(slot: int) -> void:
	if _actions_paused():
		return
	var result: Dictionary = restaurant.buffer_interact(slot)
	if not bool(result.get("ok", false)) and is_instance_valid(_kitchen):
		_kitchen.show_feedback(result)
	_queue_save()

func _on_kitchen_shift(mode: String) -> void:
	if _actions_paused() or not RestaurantScript.MODES.has(mode):
		return
	_next_shift_mode = mode
	if is_instance_valid(_kitchen):
		_kitchen.set_next_shift_mode(mode)
	if bool(restaurant.snapshot().get("active", false)):
		restaurant.set_service_mode(mode)
	else:
		restaurant.start_shift(mode, true)
	_save_state()


func _on_kitchen_close() -> void:
	if _actions_paused():
		return
	restaurant.close_day()
	_queue_critical_save()


func _on_kitchen_reopen() -> void:
	if _actions_paused() or bool(restaurant.snapshot().get("active", false)):
		return
	restaurant.start_shift(_next_shift_mode, true)
	_save_state()

func _update_food(stage: String) -> void:
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null
	_cook_visual.visible = stage in ["heating", "plate"]
	if stage not in ["heat", "serve"]:
		return
	_held = _dish(stage == "serve")
	player.visual_root.add_child(_held)
	_held.position = Vector3(0, 0.87, 0.58)

func _dish(cooked: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "CarriedMeal"
	var plate := CylinderMesh.new()
	plate.top_radius = 0.35
	plate.bottom_radius = 0.30
	plate.height = 0.055
	_mesh(root, plate, Vector3.ZERO, Color("#f4e8ce"))
	for i in range(3):
		var food := CapsuleMesh.new()
		food.radius = 0.055
		food.height = 0.30
		var part := _mesh(root, food, Vector3(-0.15 + i * 0.15, 0.085, 0), Color("#efddb4") if cooked else Color("#96ba88"))
		part.rotation.x = PI * 0.5
	return root

func _build_cafe() -> void:
	var model: PackedScene = load(CAFE_MODEL)
	var building := model.instantiate()
	building.name = "TalentParkCafeHero"
	building.position = _anchor + Vector3(0, -0.20, 0)
	add_child(building)
	_cafe_lamp = OmniLight3D.new()
	_cafe_lamp.name = "CafeEveningLantern"
	_cafe_lamp.position = _anchor + Vector3(0, 2.15, 1.45)
	_cafe_lamp.light_color = Color("#ffd29a")
	_cafe_lamp.light_energy = 0.0
	_cafe_lamp.omni_range = 8.0
	add_child(_cafe_lamp)
	for part in building.find_children("*", "MeshInstance3D", true, false):
		if "roof" in str(part.name) or "sunshade_slat" in str(part.name):
			_roof_parts.append(part)
	_customer = load("res://assets/art/models/bay_resident.glb").instantiate()
	_customer.position = _anchor + Vector3(3.5, 0, 3.8)
	_customer.scale = Vector3.ONE * 0.85
	_customer.rotation.y = PI
	_customer.visible = false
	add_child(_customer)
	# Simple collision hulls follow the back and side walls, keeping the service aisle open.
	_collision(_anchor + Vector3(0, 1.6, -3.42), Vector3(9.4, 3.2, 0.3))
	_collision(_anchor + Vector3(-4.55, 1.6, -0.4), Vector3(0.22, 3.2, 5.8))
	_collision(_anchor + Vector3(4.55, 1.6, -0.4), Vector3(0.22, 3.2, 5.8))
	for id in STATIONS:
		var area := Area3D.new()
		area.name = "ParkInteract_" + id
		area.position = _anchor + STATIONS[id][0]
		area.collision_layer = 2
		area.collision_mask = 0
		area.set_meta("interaction_id", id)
		area.set_meta("display_name", STATIONS[id][1])
		area.add_to_group("talent_park_interactable")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.6, 0.8)
		shape.shape = box
		area.add_child(shape)
		add_child(area)
	for at in [Vector3(-3.2, 0.42, 4.2), Vector3(-1.8, 0.42, 4.2)]:
		var post := CylinderMesh.new()
		post.top_radius = 0.18
		post.bottom_radius = 0.21
		post.height = 0.85
		_mesh(self, post, _anchor + at, Color("#809d94"))
		var bell := SphereMesh.new()
		bell.radius = 0.20
		bell.height = 0.28
		_mesh(self, bell, _anchor + at + Vector3(0, 0.48, 0), Color("#e5bd71") if at.x < -2.0 else Color("#d67e68"))
	var table := BoxMesh.new()
	table.size = Vector3(1.0, 0.75, 1.0)
	_mesh(self, table, _anchor + Vector3(5.0, 0.375, 4.5), Color("#ad8d73"))
	var drink := CylinderMesh.new()
	drink.top_radius = 0.18
	drink.bottom_radius = 0.14
	drink.height = 0.40
	_mesh(self, drink, _anchor + Vector3(4.8, 1.0, 4.25), Color("#eabc79"))
	_souvenir_visual = Node3D.new()
	_souvenir_visual.position = _anchor + Vector3(5.3, 1.0, 4.65)
	add_child(_souvenir_visual)
	_mesh(_souvenir_visual, drink, Vector3.ZERO, Color("#77acae"))
	var bench := BoxMesh.new()
	bench.size = Vector3(2.2, 0.16, 0.7)
	_mesh(self, bench, _anchor + Vector3(-5.8, 0.5, 6.0), Color("#ac876b"))
	var back := BoxMesh.new()
	back.size = Vector3(2.2, 0.6, 0.12)
	_mesh(self, back, _anchor + Vector3(-5.8, 0.85, 6.3), Color("#ac876b"))
	_cook_visual = _dish(true)
	_cook_visual.position = _anchor + Vector3(-0.39, 1.15, 0.65)
	_cook_visual.visible = false
	add_child(_cook_visual)

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, tint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.62
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _collision(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

func _nearest() -> Area3D:
	var best: Area3D
	var distance := REACH
	for area in get_tree().get_nodes_in_group("talent_park_interactable"):
		if is_ancestor_of(area) and _distance(area) < distance:
			distance = _distance(area)
			best = area
	return best

func _distance(area: Area3D) -> float:
	return Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(area.global_position.x, area.global_position.z))

func _update_camera(delta: float, snap := false) -> void:
	var focus: Vector3 = park.OVERVIEW_CENTER if _overview else player.global_position + Vector3(0, 0.8, 0)
	camera.size = _zoom if snap else lerpf(camera.size, _zoom, minf(delta * 7, 1))
	var distance := maxf(35, camera.size * 1.6)
	var horizontal := distance * cos(_pitch)
	var desired := focus + Vector3(sin(_yaw) * horizontal, sin(_pitch) * distance, cos(_yaw) * horizontal)
	camera.global_position = desired if snap else camera.global_position.lerp(desired, minf(delta * 7, 1))
	camera.look_at(focus)

func _refresh_status() -> void:
	if not is_instance_valid(hud) or not is_instance_valid(restaurant):
		return
	hud.set_market_clock(int(state["day"]), int(state["cash"]), int(restaurant.clock_minutes()),
		restaurant.service_period(), int(bool(state["purchases"].get("bay_mug", false))))
	_souvenir_visual.visible = bool(state["purchases"].get("bay_mug", false))

func _save_state() -> bool:
	if state.is_empty() or not is_instance_valid(player) or not is_instance_valid(restaurant):
		return false
	_save_pending = false
	_critical_save_queued = false
	state["position"] = [player.position.x, player.position.y, player.position.z]
	state["restaurant"] = restaurant.snapshot()
	state["next_shift_mode"] = _next_shift_mode
	_refresh_status()
	var success: bool = _save_store.save_state(state, save_path)
	if not success and is_instance_valid(hud):
		hud.show_notice("保存失败，当前进度仍在游戏中。请勿退出。")
	return success

func _queue_save() -> void:
	# Keep the full verified primary+backup write off the click path. Cash,
	# closing, focus loss and explicit F5 still call _save_state immediately.
	_save_pending = true
	_save_delay = 0.8

func _queue_critical_save() -> void:
	# The money animation and scene feedback render before the verified disk
	# write. Loss of focus and tree exit still save synchronously.
	if _critical_save_queued:
		return
	_critical_save_queued = true
	_flush_critical_save.call_deferred()

func _flush_critical_save() -> void:
	if _critical_save_queued:
		_save_state()

func _open_gallery() -> void:
	if is_instance_valid(_kitchen):
		_exit_kitchen()
	_cancel_pending()
	_save_state()
	_gallery = load("res://scripts/city3d/city_asset_gallery.gd").new()
	_gallery.position = Vector3(5000, 0, 0)
	add_child(_gallery)
	_gallery.close_requested.connect(_close_gallery)
	hud.hide()
	_fx.clear_target()
	player.stop_auto_move()

func _close_gallery() -> void:
	if is_instance_valid(_gallery):
		_gallery.queue_free()
	_gallery = null
	camera.current = true
	hud.show()

func _exit_tree() -> void:
	if not _closing:
		_save_state()

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#bbd2d0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e8dfd0")
	environment.ambient_light_energy = 0.24
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.60
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.08
	world.environment = environment
	_lighting_environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -38, 0)
	sun.light_color = Color("#ffdfbf")
	sun.light_energy = 0.32
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	_sun_light = sun
	add_child(sun)

func _update_service_lighting() -> void:
	if not is_instance_valid(restaurant) or _lighting_environment == null or not is_instance_valid(_sun_light):
		return
	state["day"] = maxi(int(state["day"]), restaurant.service_day())
	var minutes := clampf(restaurant.clock_minutes(), 480.0, 1320.0)
	var profiles: Array[Dictionary] = [
		{"minute": 480.0, "sky": Color("#d2b7b8"), "ambient": Color("#e8d3bf"), "ambient_energy": 0.22, "sun": Color("#ffd09b"), "sun_energy": 0.33, "exposure": 0.57, "pitch": -15.0, "yaw": -58.0},
		{"minute": 570.0, "sky": Color("#b5cbd0"), "ambient": Color("#ead8bd"), "ambient_energy": 0.24, "sun": Color("#ffdfba"), "sun_energy": 0.34, "exposure": 0.59, "pitch": -28.0, "yaw": -38.0},
		{"minute": 720.0, "sky": Color("#bbd9d7"), "ambient": Color("#e1e0d3"), "ambient_energy": 0.22, "sun": Color("#fff0d9"), "sun_energy": 0.38, "exposure": 0.54, "pitch": -51.0, "yaw": -15.0},
		{"minute": 990.0, "sky": Color("#d3c5b7"), "ambient": Color("#e6d6be"), "ambient_energy": 0.22, "sun": Color("#ffdbad"), "sun_energy": 0.33, "exposure": 0.55, "pitch": -30.0, "yaw": 25.0},
		{"minute": 1038.0, "sky": Color("#bb8588"), "ambient": Color("#b8acb4"), "ambient_energy": 0.25, "sun": Color("#ffa76f"), "sun_energy": 0.35, "exposure": 0.58, "pitch": -14.0, "yaw": 42.0},
		{"minute": 1110.0, "sky": Color("#67657d"), "ambient": Color("#b8a7a7"), "ambient_energy": 0.20, "sun": Color("#ec997c"), "sun_energy": 0.15, "exposure": 0.57, "pitch": -8.0, "yaw": 55.0},
		{"minute": 1210.0, "sky": Color("#2d4056"), "ambient": Color("#9eb4c9"), "ambient_energy": 0.23, "sun": Color("#a8bdd9"), "sun_energy": 0.14, "exposure": 0.58, "pitch": -24.0, "yaw": 68.0},
		{"minute": 1320.0, "sky": Color("#26394f"), "ambient": Color("#99b0c6"), "ambient_energy": 0.21, "sun": Color("#a8bdd9"), "sun_energy": 0.11, "exposure": 0.57, "pitch": -25.0, "yaw": 68.0}
	]
	var earlier: Dictionary = profiles[0]
	var later: Dictionary = profiles[profiles.size() - 1]
	for index in range(profiles.size() - 1):
		if minutes <= float(profiles[index + 1]["minute"]):
			earlier = profiles[index]
			later = profiles[index + 1]
			break
	var span := maxf(1.0, float(later["minute"]) - float(earlier["minute"]))
	var blend := clampf((minutes - float(earlier["minute"])) / span, 0.0, 1.0)
	_lighting_environment.background_color = (earlier["sky"] as Color).lerp(later["sky"] as Color, blend)
	_lighting_environment.ambient_light_color = (earlier["ambient"] as Color).lerp(later["ambient"] as Color, blend)
	_lighting_environment.ambient_light_energy = lerpf(float(earlier["ambient_energy"]), float(later["ambient_energy"]), blend)
	_lighting_environment.tonemap_exposure = lerpf(float(earlier["exposure"]), float(later["exposure"]), blend)
	_sun_light.light_color = (earlier["sun"] as Color).lerp(later["sun"] as Color, blend)
	_sun_light.light_energy = lerpf(float(earlier["sun_energy"]), float(later["sun_energy"]), blend)
	_sun_light.rotation_degrees = Vector3(lerpf(float(earlier["pitch"]), float(later["pitch"]), blend), lerpf(float(earlier["yaw"]), float(later["yaw"]), blend), 0.0)
	if is_instance_valid(_cafe_lamp):
		_cafe_lamp.light_energy = 0.62 * smoothstep(990.0, 1080.0, minutes)
	_refresh_status()
