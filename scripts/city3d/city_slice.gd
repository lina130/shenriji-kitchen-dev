class_name CitySlice3D
extends Node3D

signal return_to_menu_requested

const PlayerScript := preload("res://scripts/city3d/city_player.gd")
const ChunkScript := preload("res://scripts/city3d/city_chunk.gd")
const HudScript := preload("res://scripts/city3d/city_hud.gd")
const LifeStateScript := preload("res://scripts/city3d/city_life_state.gd")
const AtlasScript := preload("res://scripts/city3d/city_atlas.gd")
const CAMERA_DISTANCE := 34.0
const INTERACT_DISTANCE := 2.55
const CHUNK_LENGTH := 24.0
const FERRY_FARE := 12
const FERRY_DOCKS := {
	"ferry_pier_hongkong": {"arrival": Vector3(-1767.8, 0.5, 1415.0), "name": "澳门"},
	"ferry_pier_macao": {"arrival": Vector3(720.0, 0.5, 863.8), "name": "香港"}
}
const RESTAURANT_ORDERS := [
	{"request": "肠粉", "station": "restaurant_steam"},
	{"request": "热茶", "station": "restaurant_tea"},
	{"request": "椰香糕", "station": "restaurant_cake"},
	{"request": "蒸点", "station": "restaurant_steam"},
	{"request": "凉茶", "station": "restaurant_tea"}
]
const COURIER_STOPS := [
	{"id": "delivery_nantou", "name": "南头旧巷"},
	{"id": "delivery_studio", "name": "湾岸工作室"},
	{"id": "delivery_hongkong", "name": "香港街市"},
	{"id": "delivery_nantou", "name": "南头旧巷"},
	{"id": "delivery_hongkong", "name": "香港街市"}
]
const CREATIVE_SITES := [
	{"id": "creative_inspiration_shenzhen", "name": "深圳街头色彩"},
	{"id": "creative_inspiration_nantou", "name": "南头旧巷纹样"},
	{"id": "creative_inspiration_hongkong", "name": "香港电车街景"},
	{"id": "creative_inspiration_shenzhen", "name": "深圳街头色彩"},
	{"id": "creative_inspiration_hongkong", "name": "香港电车街景"}
]

var player
var camera: Camera3D
var hud
var life_state
var atlas
var preview_save_path := "user://city3d_preview.json"
var _chunks: Dictionary = {}
var _regions: Dictionary = {}
var _pending_area: Area3D
var _last_district := ""
var _chunk_clock := 0.0
var _autosave_clock := 0.0
var _shift: Dictionary = {}
var _camera_yaw := deg_to_rad(45.0)
var _camera_pitch := deg_to_rad(42.0)
var _target_zoom := 23.0
var _orbiting := false
var _overview := false
var _held_food: Node3D

func _ready() -> void:
	name = "CitySlice3D"
	_build_world_environment()
	atlas = AtlasScript.new()
	add_child(atlas)
	_build_sun()
	_build_player()
	_build_camera()
	hud = HudScript.new()
	add_child(hud)
	life_state = LifeStateScript.new()
	life_state.load_from_disk(preview_save_path)
	player.global_position = life_state.player_position
	_restore_active_shift()
	_refresh_status()
	_update_chunks()

func _process(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var focus: Vector3 = Vector3(-600, 0, 0) if _overview else player.global_position + Vector3(0, 0.8, 0)
	var camera_distance := maxf(CAMERA_DISTANCE, camera.size * 1.35)
	var horizontal := camera_distance * cos(_camera_pitch)
	var offset := Vector3(sin(_camera_yaw) * horizontal, sin(_camera_pitch) * camera_distance, cos(_camera_yaw) * horizontal)
	var desired: Vector3 = focus + offset
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 7.0))
	camera.look_at(focus)
	camera.size = lerpf(camera.size, _target_zoom, minf(1.0, delta * 8.0))
	_tick_shift(delta)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	player.input_locked = hud.is_modal_open() or _overview
	_autosave_clock += delta
	if _autosave_clock >= 10.0:
		_autosave_clock = 0.0
		if not _overview and (not _shift.is_empty() or player.global_position.distance_to(life_state.player_position) > 1.0):
			_commit_state()
	_chunk_clock += delta
	if _chunk_clock > 0.35:
		_chunk_clock = 0.0
		_update_chunks()
	var district: String
	if absf(player.global_position.z) < 12.0 and player.global_position.x >= -24.0 and player.global_position.x < 48.0:
		district = "深圳 · 南头旧巷" if player.global_position.x < 0.0 else ("深圳 · 创意商业街" if player.global_position.x < 24.0 else "香港 · 电车街市")
	else:
		district = "%s · 城市总览区" % str(atlas.nearest_city(player.global_position)["name"])
	if district != _last_district:
		_last_district = district
		hud.set_district(district)
	if _overview:
		hud.set_prompt("")
		return
	if is_instance_valid(_pending_area):
		if _horizontal_distance(player.global_position, _pending_area.global_position) <= INTERACT_DISTANCE:
			player.stop_auto_move()
			_interact(_pending_area)
			_pending_area = null
	var nearest := _nearest_interactable(INTERACT_DISTANCE)
	if is_instance_valid(nearest):
		hud.set_prompt("E  与%s互动" % str(nearest.get_meta("display_name", "街坊")))
	elif is_instance_valid(_pending_area):
		hud.set_prompt("正在走向%s" % str(_pending_area.get_meta("display_name", "目标")))
	else:
		hud.set_prompt("")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_toggle_overview()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not (event is InputEventKey and event.echo):
		if _overview:
			_toggle_overview()
			get_viewport().set_input_as_handled()
			return
		if hud.is_modal_open():
			if not _shift.is_empty():
				_finish_shift()
			else:
				hud.close_modal()
			get_viewport().set_input_as_handled()
			return
		if not _shift.is_empty():
			_finish_shift()
			get_viewport().set_input_as_handled()
			return
		return_to_menu_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mouse.pressed
			get_viewport().set_input_as_handled()
			return
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP and (not hud.is_modal_open() or _overview):
			_target_zoom = maxf(12.0, _target_zoom / 1.27)
			get_viewport().set_input_as_handled()
			return
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and (not hud.is_modal_open() or _overview):
			_target_zoom = minf(5700.0, _target_zoom * 1.27)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _orbiting and (not hud.is_modal_open() or _overview):
		var motion := event as InputEventMouseMotion
		_camera_yaw += motion.relative.x * 0.008
		_camera_pitch = clampf(_camera_pitch - motion.relative.y * 0.006, deg_to_rad(28.0), deg_to_rad(70.0))
		get_viewport().set_input_as_handled()
		return
	if hud.is_modal_open():
		return
	if event.is_action_pressed("interact") and not (event is InputEventKey and event.echo):
		var nearest := _nearest_interactable(INTERACT_DISTANCE)
		if is_instance_valid(nearest):
			_interact(nearest)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_click_world(click.position)
			get_viewport().set_input_as_handled()

func _click_world(screen_position: Vector2) -> void:
	if camera.size > 100.0:
		return
	var ray_start := camera.project_ray_origin(screen_position)
	var ray_end := ray_start + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 3)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider is Area3D and collider.is_in_group("city3d_interactable"):
		var area := collider as Area3D
		if _horizontal_distance(player.global_position, area.global_position) <= INTERACT_DISTANCE:
			_interact(area)
		else:
			_pending_area = area
			player.move_toward_point(area.global_position + Vector3(0, 0, 0.78))
		return
	_pending_area = null
	player.move_toward_point(hit.position)

func _interact(area: Area3D) -> void:
	if not is_instance_valid(area):
		return
	var interaction_id := str(area.get_meta("interaction_id", ""))
	if not _shift.is_empty():
		var allowed: Array[String] = []
		match str(_shift.get("career", "")):
			"restaurant": allowed = ["restaurant_steam", "restaurant_tea", "restaurant_cake", "restaurant_customer"]
			"courier": allowed = ["courier_pickup", "delivery_nantou", "delivery_studio", "delivery_hongkong"]
			"creative": allowed = ["creative_inspiration_nantou", "creative_inspiration_shenzhen", "creative_inspiration_hongkong", "creative_workbench", "creative_client"]
		if interaction_id not in allowed:
			hud.show_notice(_field_hint())
			return
	match interaction_id:
		"tea_house":
			_start_restaurant_shift("relaxed")
		"breakfast":
			_start_restaurant_shift("relaxed")
		"restaurant_rush":
			_start_restaurant_shift("rush")
		"restaurant_steam", "restaurant_tea", "restaurant_cake":
			_prepare_restaurant_food(interaction_id)
		"restaurant_customer":
			_serve_restaurant_food()
		"courier_hub":
			_start_field_shift("courier", "relaxed")
		"courier_rush":
			_start_field_shift("courier", "rush")
		"courier_pickup", "delivery_nantou", "delivery_studio", "delivery_hongkong":
			_interact_courier_station(interaction_id)
		"creative_studio":
			_start_field_shift("creative", "relaxed")
		"creative_rush":
			_start_field_shift("creative", "rush")
		"creative_inspiration_nantou", "creative_inspiration_shenzhen", "creative_inspiration_hongkong", "creative_workbench", "creative_client":
			_interact_creative_station(interaction_id)
		"rest_home":
			life_state.rest_day()
			_commit_state()
			hud.show_notice("好好睡了一觉。新的一天慢慢来。")
		"collector":
			_open_collector()
		"ferry_pier_hongkong", "ferry_pier_macao":
			_board_ferry(interaction_id)
		"neighbor":
			var memento: Dictionary = life_state.discover_neighbor_memento()
			if memento.is_empty():
				hud.show_notice("陈伯：最近茶铺热闹了不少，有空来坐坐。")
			else:
				_commit_state()
				hud.show_notice("陈伯翻出一本旧电影票册，说起当年街坊看露天电影的夜晚。他把票册送给了你。")
		"artist":
			hud.show_notice("小林：拐角的墙面刚刷好颜色，想不想看看？")
		_:
			hud.show_notice("你和%s打了个招呼。" % str(area.get_meta("display_name", "街坊")))

func _start_restaurant_shift(mode: String) -> void:
	if not _shift.is_empty():
		hud.show_notice("先完成正在进行的工作。")
		return
	if not life_state.begin_shift(mode):
		hud.show_notice("精力不足，先回家休息。")
		return
	_shift = {"career": "restaurant", "mode": mode, "step": 0, "correct": 0,
		"total": 3 if mode == "relaxed" else 5, "seconds": 30.0 if mode == "relaxed" else 17.0,
		"phase": "prepare", "held_station": ""}
	_commit_state()
	hud.show_notice("开始%s：看看订单，到对应台面亲手制作，再走到街坊身边交付。" % ("悠闲班" if mode == "relaxed" else "忙碌班"))

func _start_field_shift(career: String, mode: String) -> void:
	if not _shift.is_empty():
		hud.show_notice("先完成正在进行的工作。")
		return
	if not life_state.begin_shift(mode):
		hud.show_notice("精力不足，先回家休息。")
		return
	_shift = {"career": career, "mode": mode, "step": 0, "correct": 0,
		"total": 3 if mode == "relaxed" else 5,
		"seconds": _field_order_seconds(career, mode),
		"phase": "pickup" if career == "courier" else "inspiration"}
	_commit_state()
	hud.show_notice("%s开始：跟着场景里的物件完成每一步。" % ("跑单" if career == "courier" else "创意委托"))

func _field_order_seconds(career: String, mode: String) -> float:
	if career == "courier":
		return 65.0 if mode == "relaxed" else 38.0
	return 75.0 if mode == "relaxed" else 45.0

func _interact_courier_station(station_id: String) -> void:
	if _shift.is_empty() or str(_shift.get("career", "")) != "courier":
		hud.show_notice("先去跑单驿站接班。")
		return
	var phase := str(_shift["phase"])
	if phase == "pickup" and station_id == "courier_pickup":
		_shift["phase"] = "deliver"
		_show_held_parcel(Color("#c99b72"))
		_commit_state()
		hud.show_notice("包裹已取好。按目的地走到收件台交付。")
		return
	var target: Dictionary = COURIER_STOPS[int(_shift["step"])]
	if phase == "deliver" and station_id == str(target["id"]):
		_shift["correct"] = int(_shift["correct"]) + 1
		_clear_held_food()
		hud.show_notice("安全送达%s，签收完成。" % str(target["name"]))
		_next_field_order()
		_commit_state()
	elif phase == "deliver":
		hud.show_notice("这不是本单地址，目的地是%s。" % str(target["name"]))
	else:
		hud.show_notice("先从驿站取件架拿起本单包裹。")

func _interact_creative_station(station_id: String) -> void:
	if _shift.is_empty() or str(_shift.get("career", "")) != "creative":
		hud.show_notice("先去湾岸工作室接委托。")
		return
	var phase := str(_shift["phase"])
	var target: Dictionary = CREATIVE_SITES[int(_shift["step"])]
	if phase == "inspiration" and station_id == str(target["id"]):
		_shift["phase"] = "make"
		_commit_state()
		hud.show_notice("已经观察到%s的细节。带着灵感回创作台。" % str(target["name"]))
	elif phase == "make" and station_id == "creative_workbench":
		_shift["phase"] = "deliver"
		_show_held_parcel(Color("#eadfc9"))
		_commit_state()
		hud.show_notice("作品完成。把画稿亲手交给委托人。")
	elif phase == "deliver" and station_id == "creative_client":
		_shift["correct"] = int(_shift["correct"]) + 1
		_clear_held_food()
		hud.show_notice("委托人收下作品，完成这一单。")
		_next_field_order()
		_commit_state()
	else:
		hud.show_notice(_field_hint())

func _next_field_order() -> void:
	_shift["step"] = int(_shift["step"]) + 1
	if int(_shift["step"]) >= int(_shift["total"]):
		_finish_shift()
		return
	_shift["phase"] = "pickup" if _shift["career"] == "courier" else "inspiration"
	_shift["seconds"] = _field_order_seconds(str(_shift["career"]), str(_shift["mode"]))

func _field_hint() -> String:
	if _shift.is_empty():
		return ""
	if str(_shift["career"]) == "restaurant":
		return _restaurant_hint()
	var step := int(_shift["step"])
	var total := int(_shift["total"])
	var remaining := maxi(0, ceili(float(_shift["seconds"])))
	var action := ""
	if str(_shift["career"]) == "courier":
		action = "从驿站取件" if _shift["phase"] == "pickup" else "送往%s" % str(COURIER_STOPS[step]["name"])
	else:
		match str(_shift["phase"]):
			"inspiration": action = "观察%s" % str(CREATIVE_SITES[step]["name"])
			"make": action = "回工作室创作"
			"deliver": action = "把画稿交给委托人"
	return "第 %d/%d 单 · %s · %d 秒" % [step + 1, total, action, remaining]

func _field_action() -> String:
	if _shift.is_empty():
		return ""
	var step := int(_shift["step"])
	if str(_shift["career"]) == "courier":
		return "从驿站取件" if _shift["phase"] == "pickup" else "送往%s" % str(COURIER_STOPS[step]["name"])
	match str(_shift["phase"]):
		"inspiration": return "观察%s" % str(CREATIVE_SITES[step]["name"])
		"make": return "回工作室创作"
		"deliver": return "把画稿交给委托人"
	return "继续委托"

func _show_held_parcel(tint: Color) -> void:
	_clear_held_food()
	_held_food = Node3D.new()
	_held_food.name = "CarriedWork"
	_held_food.position = Vector3(0.42, 1.02, -0.33)
	player.add_child(_held_food)
	var parcel := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.48, 0.28, 0.37)
	parcel.mesh = shape
	parcel.material_override = _food_material(tint)
	_held_food.add_child(parcel)

func _prepare_restaurant_food(station_id: String) -> void:
	if _shift.is_empty() or str(_shift.get("career", "")) != "restaurant":
		hud.show_notice("先到茶铺接班。")
		return
	if str(_shift.get("phase", "")) != "prepare":
		hud.show_notice("手上已经有一份餐点，先交给等餐街坊。")
		return
	_shift["phase"] = "serve"
	_shift["held_station"] = station_id
	_show_held_food(station_id)
	_commit_state()
	hud.show_notice("餐点做好了。端给等餐的街坊。")

func _serve_restaurant_food() -> void:
	if _shift.is_empty() or str(_shift.get("career", "")) != "restaurant":
		hud.show_notice("街坊正在等茶铺出餐。")
		return
	if str(_shift.get("phase", "")) != "serve":
		hud.show_notice("先到对应台面制作这一单。")
		return
	var order: Dictionary = RESTAURANT_ORDERS[int(_shift["step"])]
	var right_dish := str(_shift.get("held_station", "")) == str(order["station"])
	_clear_held_food()
	if right_dish:
		_shift["correct"] = int(_shift["correct"]) + 1
		hud.show_notice("餐点合意，这单收入记入本班结算。")
	else:
		hud.show_notice("送错餐了。这单没有收入，下一单继续。")
	_next_restaurant_order()
	_commit_state()

func _next_restaurant_order() -> void:
	_shift["step"] = int(_shift["step"]) + 1
	if int(_shift["step"]) >= int(_shift["total"]):
		_finish_shift()
		return
	_shift["phase"] = "prepare"
	_shift["held_station"] = ""
	_shift["seconds"] = 30.0 if _shift["mode"] == "relaxed" else 17.0

func _restaurant_hint() -> String:
	if _shift.is_empty() or str(_shift.get("career", "")) != "restaurant":
		return ""
	var order: Dictionary = RESTAURANT_ORDERS[int(_shift["step"])]
	var remaining := maxi(0, ceili(float(_shift["seconds"])))
	if str(_shift.get("phase", "")) == "serve":
		return "第 %d/%d 单 · 端%s给街坊 · %d 秒" % [int(_shift["step"]) + 1, int(_shift["total"]), str(order["request"]), remaining]
	return "第 %d/%d 单 · 制作%s · %d 秒" % [int(_shift["step"]) + 1, int(_shift["total"]), str(order["request"]), remaining]

func _show_held_food(station_id: String) -> void:
	_clear_held_food()
	_held_food = Node3D.new()
	_held_food.name = "CarriedMeal"
	_held_food.position = Vector3(0.45, 1.0, -0.35)
	player.add_child(_held_food)
	var tray := MeshInstance3D.new()
	var tray_mesh := CylinderMesh.new()
	tray_mesh.top_radius = 0.32
	tray_mesh.bottom_radius = 0.30
	tray_mesh.height = 0.07
	tray.mesh = tray_mesh
	tray.material_override = _food_material(Color("#f4dfb4"))
	_held_food.add_child(tray)
	var dish := MeshInstance3D.new()
	var dish_mesh := SphereMesh.new()
	dish_mesh.radius = 0.20
	dish_mesh.height = 0.25
	dish.mesh = dish_mesh
	dish.position.y = 0.12
	dish.material_override = _food_material({"restaurant_steam": Color("#e9e3cb"), "restaurant_tea": Color("#b98d63"), "restaurant_cake": Color("#e8a7a1")}.get(station_id, Color.WHITE))
	_held_food.add_child(dish)

func _food_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.75
	return material

func _clear_held_food() -> void:
	if is_instance_valid(_held_food):
		_held_food.queue_free()
	_held_food = null

func _tick_shift(delta: float) -> void:
	if _shift.is_empty() or _overview:
		return
	_shift["seconds"] = float(_shift["seconds"]) - delta
	if str(_shift.get("career", "")) == "restaurant":
		var order: Dictionary = RESTAURANT_ORDERS[int(_shift["step"])]
		var action := "端%s给等餐街坊" % str(order["request"]) if str(_shift.get("phase", "")) == "serve" else "到对应台面制作%s" % str(order["request"])
		hud.set_field_task("阿婆茶铺", action, "%d / %d 单" % [int(_shift["step"]) + 1, int(_shift["total"])], float(_shift["seconds"]))
		if float(_shift["seconds"]) <= 0.0:
			_clear_held_food()
			hud.show_notice("这单超时了，街坊先离开。下一单继续。")
			_next_restaurant_order()
			_commit_state()
		return
	if str(_shift.get("career", "")) == "courier" or str(_shift.get("career", "")) == "creative":
		var title := "城市跑单" if str(_shift["career"]) == "courier" else "创意委托"
		var progress := "%d / %d 单" % [int(_shift["step"]) + 1, int(_shift["total"])]
		hud.set_field_task(title, _field_action(), progress, float(_shift["seconds"]))
		if float(_shift["seconds"]) <= 0.0:
			_clear_held_food()
			hud.show_notice("这单超时了。沿街继续做下一单。")
			_next_field_order()
			_commit_state()
		return

func _finish_shift() -> void:
	if _shift.is_empty():
		return
	var earned: int = life_state.finish_shift(str(_shift["career"]), str(_shift["mode"]), int(_shift["correct"]), int(_shift["total"]))
	var result := "本班完成 %d / %d 单，获得 %d 贝。" % [int(_shift["correct"]), int(_shift["total"]), earned]
	_shift.clear()
	_clear_held_food()
	hud.clear_field_task()
	hud.close_modal()
	_commit_state()
	hud.show_notice(result)

func _open_collector() -> void:
	if life_state.items.is_empty():
		hud.show_notice("旧物铺老板：带发现的藏品来吧。稀有物可珍藏，也能换一笔钱。")
		return
	var options: Array[Dictionary] = []
	for i in range(life_state.items.size()):
		var item: Dictionary = life_state.items[i]
		options.append({"id": str(i), "text": "%s【%s】 · 卖出 %d 贝" % [str(item["name"]), _rarity_name(str(item["rarity"])), int(item["value"])]})
	options.append({"id": "leave", "text": "都留下收藏"})
	hud.show_choices("旧物铺 · 藏品收购", "每件可自由决定保留或出售。首次发现会永久记入图鉴。", options,
		func(choice_id: String) -> void:
			hud.close_modal()
			if choice_id == "leave":
				return
			var earned: int = life_state.sell_item(int(choice_id))
			_commit_state()
			hud.show_notice("交易完成，获得 %d 贝。" % earned)
	)

func _board_ferry(dock_id: String) -> void:
	if not FERRY_DOCKS.has(dock_id):
		return
	if not life_state.spend_cash(FERRY_FARE):
		hud.show_notice("船票需要 %d 贝，手头暂时不够。" % FERRY_FARE)
		return
	var destination: Dictionary = FERRY_DOCKS[dock_id]
	player.stop_auto_move()
	_pending_area = null
	player.global_position = destination["arrival"]
	_snap_camera_to_player()
	_update_chunks()
	_commit_state()
	hud.show_notice("乘轮渡抵达%s码头，船票 %d 贝。" % [str(destination["name"]), FERRY_FARE])

func _rarity_name(rarity: String) -> String:
	return {"common": "常见", "uncommon": "少见", "rare": "稀有", "legendary": "传世"}.get(rarity, rarity)

func _refresh_status() -> void:
	hud.set_status(life_state.day, life_state.cash, life_state.energy, life_state.items.size())

func _commit_state() -> void:
	life_state.active_shift = _shift.duplicate(true)
	life_state.player_position = player.global_position
	_refresh_status()
	life_state.save_to_disk(preview_save_path)

func _restore_active_shift() -> void:
	var saved: Dictionary = life_state.active_shift
	if saved.is_empty():
		return
	var career := str(saved.get("career", ""))
	var mode := str(saved.get("mode", ""))
	var step := int(saved.get("step", -1))
	var total := int(saved.get("total", 0))
	if career not in ["restaurant", "courier", "creative"] or mode not in ["relaxed", "rush"] or step < 0 or total < 1 or step >= total:
		life_state.active_shift = {}
		return
	_shift = saved.duplicate(true)
	_shift["seconds"] = maxf(5.0, float(saved.get("seconds", 30.0)))
	if career == "restaurant" and str(_shift.get("phase", "")) == "serve":
		_show_held_food(str(_shift.get("held_station", "")))
	elif career == "courier" and str(_shift.get("phase", "")) == "deliver":
		_show_held_parcel(Color("#c99b72"))
	elif career == "creative" and str(_shift.get("phase", "")) == "deliver":
		_show_held_parcel(Color("#eadfc9"))

func _toggle_overview() -> void:
	_overview = not _overview
	if not _overview:
		_target_zoom = 23.0
		hud.close_modal()
		return
	_target_zoom = 5700.0
	var choices: Array[Dictionary] = []
	if _shift.is_empty():
		for city in atlas.CITIES:
			choices.append({"id": str(city["id"]), "text": str(city["name"])})
	choices.append({"id": "close", "text": "返回街道"})
	var description := "工作中的路线预览：滚轮缩放，右键转动视角；关闭后继续本单。" if not _shift.is_empty() else "滚轮缩放，按住右键转动视角。选择城市可在开发预览中前往；名称只显示在界面。"
	hud.show_choices("湾区总览", description, choices,
		func(city_id: String) -> void:
			if city_id == "close":
				_toggle_overview()
			else:
				_travel_to_city(city_id)
	)

func _travel_to_city(city_id: String) -> void:
	var at: Vector2 = atlas.city_position(city_id)
	player.stop_auto_move()
	player.global_position = Vector3(at.x, 0.5, at.y)
	_pending_area = null
	_overview = false
	_target_zoom = 23.0
	camera.size = 23.0
	_snap_camera_to_player()
	hud.close_modal()
	_update_chunks()
	_commit_state()
	hud.show_notice("抵达%s。周边街道和可玩内容仍在持续制作。" % str(atlas.nearest_city(player.global_position)["name"]))

func _nearest_interactable(max_distance: float) -> Area3D:
	var best: Area3D
	var best_distance := max_distance
	for candidate in get_tree().get_nodes_in_group("city3d_interactable"):
		if not candidate is Area3D or not is_instance_valid(candidate):
			continue
		var area := candidate as Area3D
		var distance := _horizontal_distance(player.global_position, area.global_position)
		if distance < best_distance:
			best_distance = distance
			best = area
	return best

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _snap_camera_to_player() -> void:
	var focus: Vector3 = player.global_position + Vector3(0, 0.8, 0)
	var distance := maxf(CAMERA_DISTANCE, camera.size * 1.35)
	var horizontal := distance * cos(_camera_pitch)
	camera.global_position = focus + Vector3(sin(_camera_yaw) * horizontal, sin(_camera_pitch) * distance, cos(_camera_yaw) * horizontal)
	camera.look_at(focus)

func _update_chunks() -> void:
	atlas.set_detail_focus(player.global_position, camera.size)
	for index in [-1, 0, 1]:
		var center_x := (float(index) + 0.5) * CHUNK_LENGTH
		var distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(center_x, 0))
		if distance < 30.0 and not _chunks.has(index):
			var chunk = ChunkScript.new()
			chunk.configure(index)
			add_child(chunk)
			_chunks[index] = chunk
		elif distance > 34.0 and _chunks.has(index):
			var old_chunk = _chunks[index]
			_chunks.erase(index)
			if is_instance_valid(_pending_area) and old_chunk.is_ancestor_of(_pending_area):
				_pending_area = null
			old_chunk.queue_free()
	var center_cell: Vector2i = atlas.get_region_cell(player.global_position)
	var bounds: Rect2 = atlas.world_bounds()
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := center_cell + Vector2i(dx, dz)
			var cell_center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * atlas.REGION_SIZE
			if not bounds.has_point(cell_center) or _regions.has(cell):
				continue
			var region: Node3D = atlas.create_region_chunk(cell)
			add_child(region)
			_regions[cell] = region
	for cell in _regions.keys():
		if absi(cell.x - center_cell.x) <= 1 and absi(cell.y - center_cell.y) <= 1:
			continue
		var old_region: Node3D = _regions[cell]
		_regions.erase(cell)
		old_region.queue_free()

func _build_player() -> void:
	player = PlayerScript.new()
	player.position = Vector3(-1.8, 0.5, 0.6)
	add_child(player)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.0
	camera.near = 0.15
	camera.far = 20000.0
	camera.current = true
	add_child(camera)
	var horizontal := CAMERA_DISTANCE * cos(_camera_pitch)
	camera.global_position = player.global_position + Vector3(sin(_camera_yaw) * horizontal, sin(_camera_pitch) * CAMERA_DISTANCE, cos(_camera_yaw) * horizontal)
	camera.look_at(player.global_position + Vector3(0, 0.8, 0))
	player.movement_camera = camera

func _build_world_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#bfd6d0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e6ddcf")
	environment.ambient_light_energy = 0.26
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = environment
	add_child(world)

func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -28, 0)
	sun.light_color = Color("#fff0d7")
	sun.light_energy = 0.38
	sun.shadow_enabled = true
	add_child(sun)

