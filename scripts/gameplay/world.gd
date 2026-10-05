class_name WorldRoot
extends Node2D

signal shop_requested(shop_id: String)
signal inventory_requested(reason: String)
signal npc_requested(npc_id: String)
signal market_requested(market_id: String)
signal collection_log_requested
signal expedition_map_requested
signal bank_requested(service_id: String)
signal farm_requested(plot_index: int)
signal pet_shop_requested
signal furniture_requested
signal kitchen_requested
signal staff_requested
signal career_requested(line_id: String)
signal wardrobe_requested
signal storage_requested
signal shipping_requested

const BackdropScript := preload("res://scripts/gameplay/area_backdrop.gd")
const PlayerScript := preload("res://scripts/gameplay/player.gd")
const InteractableScript := preload("res://scripts/gameplay/interactable.gd")
const NpcScript := preload("res://scripts/gameplay/npc_actor.gd")
const WeatherScript := preload("res://scripts/gameplay/weather_effect.gd")
const RemotePlayerScript := preload("res://scripts/gameplay/remote_player_actor.gd")
const RoomFurnitureLayerScript := preload("res://scripts/gameplay/room_furniture_layer.gd")
const FishingEffectLayerScript := preload("res://scripts/gameplay/fishing_effect_layer.gd")
const FarmPlotLayerScript := preload("res://scripts/gameplay/farm_plot_layer.gd")
const KitchenEffectLayerScript := preload("res://scripts/gameplay/kitchen_effect_layer.gd")
const CITY_MAP_SIZE := BackdropScript.CITY_MAP_SIZE
const CITY_LAYOUT_SCALE := 1.5

var player: PlayerActor
var _area_root: Node2D
var _player_input_locked := false
var _map_zoom := 1.0
var _last_business_level := -1
var _last_phase_id := ""
var _selected_market_item := ""
var _room_edit_mode := false
var _selected_room_slot := ""
var _room_furniture_layer: Node2D
var _housing_advisor_met := false
var _remote_players: Dictionary = {}
var _coop_sync_elapsed := 0.0
var _breakfast_customer_nodes: Array[WorldInteractable] = []
var _restaurant_customer_nodes: Array[WorldInteractable] = []

func _ready() -> void:
	add_to_group("world")
	SceneRouter.travel_completed.connect(_on_travel_requested)
	MarketPhaseManager.phase_changed.connect(_on_market_phase_changed)
	SaveManager.game_loaded.connect(_on_game_loaded)
	if not UnlockManager.changed.is_connected(_on_unlock_changed):
		UnlockManager.changed.connect(_on_unlock_changed)
	CoopManager.remote_player_updated.connect(_on_remote_player_updated)
	CoopManager.remote_player_removed.connect(_on_remote_player_removed)
	KitchenManager.changed.connect(_on_kitchen_changed)
	_build_area(GameState.current_area, GameState.spawn_id)

func _process(delta: float) -> void:
	_coop_sync_elapsed += delta
	if _coop_sync_elapsed >= 0.1:
		_coop_sync_elapsed = 0.0
		if CoopManager.is_coop_active() and is_instance_valid(player):
			CoopManager.send_local_state(GameState.current_area, player.global_position, player.get_facing())
	if GameState.current_area == "restaurant" and (BusinessManager.business_level != _last_business_level or MarketPhaseManager.current_phase_id != _last_phase_id):
		_build_area("restaurant", "entrance")
	elif GameState.current_area in ["breakfast_shop", "breakfast_kitchen"] and MarketPhaseManager.current_phase_id != _last_phase_id:
		_build_area(GameState.current_area, "entrance")

func _unhandled_input(event: InputEvent) -> void:
	if _player_input_locked or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if _room_edit_mode and GameState.current_area == "home":
		_handle_room_edit_input(mouse_event)
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		var direct_target := _find_click_target(mouse_event.position)
		if direct_target != null:
			direct_target.interact()
			get_viewport().set_input_as_handled()
			return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_map_zoom(_map_zoom + 0.08)
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_map_zoom(_map_zoom - 0.08)
		get_viewport().set_input_as_handled()

func _is_click_operation_area() -> bool:
	return GameState.current_area in ["restaurant", "breakfast_shop", "breakfast_kitchen"]

func _handle_room_edit_input(mouse_event: InputEventMouseButton) -> void:
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		var target := _find_click_target(mouse_event.position)
		if target != null and (target.interaction_id.begins_with("room_slot|") or target.interaction_id.begins_with("room_renovation|") or target.interaction_id == "home_room"):
			target.interact()
			return
		if not _selected_room_slot.is_empty():
			var fid := RoomManager.get_furniture_for_slot(_selected_room_slot)
			if not fid.is_empty():
				RoomManager.set_furniture_position(fid, _normalized_room_position(_screen_to_area_local(mouse_event.position)))
				if is_instance_valid(_room_furniture_layer):
					_room_furniture_layer.queue_redraw()
		return
	if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not _selected_room_slot.is_empty():
		var fid := RoomManager.get_furniture_for_slot(_selected_room_slot)
		if not fid.is_empty():
			RoomManager.rotate_furniture(fid, 15 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else -15)
		if is_instance_valid(_room_furniture_layer):
			_room_furniture_layer.queue_redraw()

func _screen_to_area_local(screen_position: Vector2) -> Vector2:
	if not is_instance_valid(_area_root):
		return screen_position
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	return _area_root.to_local(world_position)

func _normalized_room_position(local_position: Vector2) -> Vector2:
	return Vector2(
		clampf((local_position.x - 96.0) / 1088.0, 0.06, 0.94),
		clampf((local_position.y - 142.0) / 430.0, 0.08, 0.92)
	)

func _find_click_target(screen_position: Vector2) -> WorldInteractable:
	var canvas_transform := get_viewport().get_canvas_transform()
	var world_position := canvas_transform.affine_inverse() * screen_position
	return _find_interactable_at_world(world_position)

func _find_interactable_at_world(world_position: Vector2) -> WorldInteractable:
	if not is_instance_valid(_area_root):
		return null
	return _find_click_target_recursive(_area_root, _area_root.to_local(world_position))

func _find_click_target_recursive(node: Node, local_mouse: Vector2) -> WorldInteractable:
	for index in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(index)
		if child is WorldInteractable and child.available:
			var center := _area_root.to_local(child.global_position)
			var rect := Rect2(center - child.visual_size * 0.5, child.visual_size).grow(8.0)
			if rect.has_point(local_mouse):
				return child
		var found := _find_click_target_recursive(child, local_mouse)
		if found != null:
			return found
	return null

func _on_travel_requested(area_id: String, spawn_id: String) -> void:
	print("TRAVEL_REQUEST area=%s spawn=%s" % [area_id, spawn_id])
	_build_area(area_id, spawn_id)
	print("TRAVEL_POS area=%s player=%s" % [area_id, player.global_position])

func _on_market_phase_changed(_phase_id: String, _previous_phase_id: String) -> void:
	if GameState.current_area == "restaurant" or GameState.current_area == "breakfast_shop":
		_build_area(GameState.current_area, "entrance")

func _on_game_loaded() -> void:
	_build_area(GameState.current_area, GameState.spawn_id)

func _on_unlock_changed() -> void:
	if is_instance_valid(_area_root) and GameState.current_area == "street":
		_refresh_city_gate_availability()

func _refresh_city_gate_availability() -> void:
	if not is_instance_valid(_area_root):
		return
	for child in _area_root.get_children():
		_refresh_city_gate_availability_recursive(child)

func _refresh_city_gate_availability_recursive(node: Node) -> void:
	if node is WorldInteractable:
		node.set_available(_city_gate_is_available(node.interaction_id))
	for child in node.get_children():
		_refresh_city_gate_availability_recursive(child)

func _city_gate_is_available(interaction_id: String) -> bool:
	match interaction_id:
		"enter_bus_station":
			return UnlockManager.can_access("bus_station")
		"enter_university":
			return UnlockManager.current_level >= 1 or UnlockManager.force_unlock_all
		"housing_model|studio":
			return UnlockManager.current_level >= 2 or UnlockManager.force_unlock_all
		"enter_factory":
			return CareerManager.application_line == "factory" or CareerManager.is_employed_in("factory") or UnlockManager.force_unlock_all
		"enter_logistics_port":
			return CareerManager.application_line == "logistics" or UnlockManager.current_level >= 1 or UnlockManager.force_unlock_all
		"enter_craft_workshop":
			return CareerManager.application_line == "craft" or UnlockManager.current_level >= 1 or UnlockManager.force_unlock_all
		"enter_wholesale":
			return BusinessManager.business_level >= 1 or UnlockManager.current_level >= 1 or UnlockManager.force_unlock_all
		"enter_farm", "enter_pet_store":
			return UnlockManager.can_access("suburb")
	return true

func set_player_input_locked(value: bool) -> void:
	_player_input_locked = value
	if is_instance_valid(player):
		player.set_input_locked(value)

func _build_area(area_id: String, spawn_id: String) -> void:
	if is_instance_valid(_area_root):
		remove_child(_area_root)
		_area_root.queue_free()
	if area_id != "home":
		_room_edit_mode = false
		_selected_room_slot = ""
	_area_root = Node2D.new()
	_area_root.name = "Area_%s" % area_id
	_area_root.set_meta("area_id", area_id)
	_breakfast_customer_nodes.clear()
	_restaurant_customer_nodes.clear()
	add_child(_area_root)
	var backdrop: AreaBackdrop = BackdropScript.new()
	backdrop.configure(area_id)
	_area_root.add_child(backdrop)
	if area_id == "farm":
		var farm_plots: Node2D = FarmPlotLayerScript.new()
		farm_plots.name = "FarmPlots"
		_area_root.add_child(farm_plots)
	if area_id == "riverside":
		var fishing_effects: Node2D = FishingEffectLayerScript.new()
		fishing_effects.name = "FishingEffects"
		_area_root.add_child(fishing_effects)
	if area_id == "home":
		_room_furniture_layer = RoomFurnitureLayerScript.new()
		_room_furniture_layer.name = "RoomFurniture"
		_area_root.add_child(_room_furniture_layer)
		_room_furniture_layer.set_edit_mode(_room_edit_mode)
		_room_furniture_layer.set_selected_slot(_selected_room_slot)
	_build_collisions(area_id)
	_build_interactables(area_id)
	_build_festival_activity(area_id)
	if area_id in ["restaurant", "breakfast_kitchen"]:
		var kitchen_effects: Node2D = KitchenEffectLayerScript.new()
		kitchen_effects.configure(area_id)
		_area_root.add_child(kitchen_effects)
	_build_npcs(area_id)
	_last_business_level = BusinessManager.business_level
	_last_phase_id = MarketPhaseManager.current_phase_id
	player = PlayerScript.new()
	player.position = _spawn_position(area_id, spawn_id)
	player.set_input_locked(_player_input_locked)
	_area_root.add_child(player)
	_rebuild_remote_players()
	var weather: WeatherEffect = WeatherScript.new()
	_area_root.add_child(weather)
	_apply_map_zoom()
	var scene_name := str(PresentationManager.get_scene_metadata(area_id).get("display_name", area_id))
	NoticeManager.show_scene_message(_arrival_text(area_id), scene_name, "hint")

func _exit_tree() -> void:
	if CoopManager.remote_player_updated.is_connected(_on_remote_player_updated):
		CoopManager.remote_player_updated.disconnect(_on_remote_player_updated)
	if CoopManager.remote_player_removed.is_connected(_on_remote_player_removed):
		CoopManager.remote_player_removed.disconnect(_on_remote_player_removed)
	if KitchenManager.changed.is_connected(_on_kitchen_changed):
		KitchenManager.changed.disconnect(_on_kitchen_changed)
	if UnlockManager.changed.is_connected(_on_unlock_changed):
		UnlockManager.changed.disconnect(_on_unlock_changed)

func _rebuild_remote_players() -> void:
	_remote_players.clear()
	for peer_id in CoopManager.get_remote_states():
		var state: Dictionary = CoopManager.get_remote_states()[peer_id]
		_on_remote_player_updated(int(peer_id), state)

func _on_remote_player_updated(peer_id: int, state: Dictionary) -> void:
	if not is_instance_valid(_area_root):
		return
	if str(state.get("area_id", "")) != GameState.current_area:
		_remove_remote_player(peer_id)
		return
	var actor = _remote_players.get(peer_id, null)
	if actor == null or not is_instance_valid(actor):
		actor = RemotePlayerScript.new()
		actor.configure(peer_id, CoopManager.get_peer_display_name(peer_id))
		_area_root.add_child(actor)
		_remote_players[peer_id] = actor
	actor.update_state(Vector2(state.get("position", Vector2.ZERO)), Vector2(state.get("facing", Vector2.DOWN)))

func _on_remote_player_removed(peer_id: int) -> void:
	_remove_remote_player(peer_id)

func _remove_remote_player(peer_id: int) -> void:
	if not _remote_players.has(peer_id):
		return
	var actor = _remote_players[peer_id]
	if is_instance_valid(actor):
		actor.queue_free()
	_remote_players.erase(peer_id)

func _set_map_zoom(value: float) -> void:
	_map_zoom = clampf(value, 0.72, 1.5)
	_apply_map_zoom()

func _apply_map_zoom() -> void:
	if not is_instance_valid(player):
		return
	var is_city_map := GameState.current_area == "street"
	var area_size := CITY_MAP_SIZE if is_city_map else Vector2(1280, 720)
	_area_root.scale = Vector2.ONE
	_area_root.position = Vector2.ZERO
	player.set_camera_limits(area_size)
	player.set_camera_zoom(_map_zoom)

func _build_collisions(area_id: String) -> void:
	if area_id == "street":
		_build_city_map_collisions()
		return
	_add_wall(Rect2(0, 0, 1280, 36))
	_add_wall(Rect2(0, 684, 1280, 36))
	_add_wall(Rect2(0, 0, 36, 720))
	_add_wall(Rect2(1244, 0, 36, 720))
	match area_id:
		"home":
			_add_wall(Rect2(145, 140, 180, 80))
			_add_wall(Rect2(450, 105, 220, 90))
		"home_living":
			_add_wall(Rect2(130, 140, 180, 90))
			_add_wall(Rect2(450, 360, 260, 100))
			_add_wall(Rect2(800, 120, 260, 90))
		"street":
			for x in range(70, 560, 150):
				_add_wall(Rect2(x, 58, 120, 100))
			for x in range(700, 1200, 160):
				_add_wall(Rect2(x, 58, 140, 100))
		"factory":
			for x in range(100, 1200, 240):
				_add_wall(Rect2(x, 110, 130, 90))
			_add_wall(Rect2(80, 520, 420, 100))
			_add_wall(Rect2(780, 520, 420, 100))
		"store":
			for x in range(60, 1230, 170):
				if x == 570 or x == 740:
					continue
				_add_wall(Rect2(x, 390, 130, 220))
		"recycle":
			for x in range(90, 1170, 260):
				_add_wall(Rect2(x, 100, 150, 110))
			_add_wall(Rect2(70, 410, 300, 180))
			_add_wall(Rect2(910, 410, 300, 180))
		"market":
			_add_wall(Rect2(70, 70, 1140, 110))
		"park":
			_add_wall(Rect2(40, 40, 120, 120))
			_add_wall(Rect2(1120, 40, 120, 120))
			for index in range(5):
				_add_circle_obstacle(Vector2(400 + index * 120, 390), 118.0)
		"ruins":
			_add_wall(Rect2(100, 80, 320, 120))
			_add_wall(Rect2(860, 80, 320, 120))
			_add_wall(Rect2(100, 500, 250, 100))
			_add_wall(Rect2(930, 500, 250, 100))
			_add_wall(Rect2(480, 240, 320, 100))
		"bank":
			_add_wall(Rect2(260, 215, 260, 90))
			_add_wall(Rect2(760, 215, 260, 90))
			_add_wall(Rect2(80, 80, 260, 80))
			_add_wall(Rect2(940, 80, 260, 80))
		"restaurant":
			_add_wall(Rect2(240, 40, 800, 54))
		"wholesale":
			_add_wall(Rect2(60, 40, 1160, 46))
			_add_wall(Rect2(60, 632, 480, 52))
			_add_wall(Rect2(740, 632, 480, 52))
		"farm":
			_add_wall(Rect2(80, 90, 340, 90))
			_add_wall(Rect2(860, 90, 340, 90))
			_add_wall(Rect2(80, 560, 420, 90))
			_add_wall(Rect2(780, 560, 420, 90))
		"pet_store":
			_add_wall(Rect2(90, 120, 300, 100))
			_add_wall(Rect2(890, 120, 300, 100))
			_add_wall(Rect2(90, 520, 300, 100))
			_add_wall(Rect2(890, 520, 300, 100))
		"furniture_store":
			for x in range(120, 1160, 260):
				_add_wall(Rect2(x, 120, 180, 90))
				_add_wall(Rect2(x, 510, 180, 90))
		"breakfast_shop":
			_add_wall(Rect2(240, 40, 800, 54))
		"breakfast_kitchen":
			_add_wall(Rect2(240, 40, 800, 54))
		"commercial_district":
			_add_wall(Rect2(60, 60, 1160, 100))
		"bus_station":
			_add_wall(Rect2(60, 50, 1160, 90))
		"seaside_resort", "ancient_village", "mountain_spring":
			_add_wall(Rect2(60, 50, 1160, 80))
		"high_end_district":
			_add_wall(Rect2(60, 60, 340, 115))
			_add_wall(Rect2(470, 55, 340, 110))
			_add_wall(Rect2(880, 60, 340, 115))
		"industrial_district":
			_add_wall(Rect2(60, 80, 350, 120))
			_add_wall(Rect2(870, 80, 350, 120))
		"suburb":
			_add_wall(Rect2(80, 80, 400, 100))
			_add_wall(Rect2(800, 80, 400, 100))
			_add_wall(Rect2(80, 540, 420, 100))
			_add_wall(Rect2(780, 540, 420, 100))
		"clothing_store":
			_add_wall(Rect2(160, 70, 960, 80))
		"clinic":
			_add_wall(Rect2(90, 70, 1100, 80))
		"community_center":
			_add_wall(Rect2(80, 60, 1120, 90))
		"university":
			_add_wall(Rect2(70, 60, 1140, 90))
		"riverside":
			for index in range(6):
				_add_circle_obstacle(Vector2(180 + index * 190, 210 + (index % 2) * 70), 58.0)

func _build_city_map_collisions() -> void:
	# Collisions and the visible city frame share one source of truth.
	for boundary in BackdropScript.CITY_BOUNDARY_COLLISIONS:
		_add_wall(boundary)
	# The painted city blocks are open public plazas; scene entrances provide the navigation.

func _build_interactables(area_id: String) -> void:
	match area_id:
		"home":
			_add_interactable("bed", "上床睡觉", Vector2(235, 180), Vector2(180, 80), Color("#cb7180"), Vector2(320, 240))
			_add_interactable("study_desk", "在书桌前学习", Vector2(560, 150), Vector2(220, 90), Color("#8ba8c4"), Vector2(300, 180))
			_add_interactable("home_room", "收起装修" if _room_edit_mode else "布置房间", Vector2(760, 470), Vector2(150, 90), Color("#9f8fcc"), Vector2(220, 170))
			_add_interactable("home_to_living", "推开卧室门去生活区", Vector2(1160, 360), Vector2(100, 120), Color("#eebe62"), Vector2(150, 170))
			if _room_edit_mode:
				var renovation_lines := RoomManager.get_renovation_lines()
				for renovation_index in range(renovation_lines.size()):
					var renovation: Dictionary = renovation_lines[renovation_index]
					var renovation_id := str(renovation.get("id", ""))
					var renovation_prompt := "当前装修・%s" % str(renovation.get("name", renovation_id)) if bool(renovation.get("active", false)) else "做%s ¥%d" % [str(renovation.get("name", renovation_id)), int(renovation.get("cost", 0))]
					_add_interactable("room_renovation|%s" % renovation_id, renovation_prompt, Vector2(250.0 + float(renovation_index) * 250.0, 70), Vector2(190, 52), Color("#c8b58c"), Vector2(220, 100))
				for slot_id in ["bed", "light", "rug", "shelf", "plant", "table", "appliance", "aquarium", "pet", "desk"]:
					if RoomManager.get_owned_for_slot(slot_id).is_empty():
						continue
					var slot_normalized := RoomManager.get_default_slot_position(slot_id)
					var slot_pos := Vector2(96.0 + slot_normalized.x * 1088.0, 142.0 + slot_normalized.y * 430.0)
					var current_fid := RoomManager.get_furniture_for_slot(slot_id)
					var current_name := "未摆放" if current_fid.is_empty() else str(ConfigDB.get_row("furniture", current_fid).get("name", current_fid))
					_add_interactable("room_slot|%s" % slot_id, "%s · %s" % [RoomManager.get_slot_name(slot_id), current_name], slot_pos, Vector2(120, 48), Color("#9f8fcc"), Vector2(145, 95))
		"home_living":
			_add_interactable("home_living_to_bedroom", "回卧室", Vector2(170, 620), Vector2(100, 120), Color("#eebe62"), Vector2(150, 170))
			_add_interactable("fridge", "从冰箱找吃的", Vector2(330, 230), Vector2(160, 88), Color("#72b5ad"), Vector2(220, 150))
			_add_interactable("home_storage", "打开生活区木箱", Vector2(620, 540), Vector2(170, 72), Color("#b58f63"), Vector2(240, 135))
			_add_interactable("home_shipping", "把东西放进门口收购箱", Vector2(910, 540), Vector2(180, 72), Color("#c99b70"), Vector2(250, 135))
			_add_interactable("home_radio", "听今天的天气和运气", Vector2(300, 540), Vector2(170, 72), Color("#8ba8c4"), Vector2(240, 135))
			_add_interactable("leave_home", "出门去城市", Vector2(1120, 620), Vector2(100, 120), Color("#eebe62"), Vector2(150, 170))
			if not PetManager.adopted.is_empty():
				_add_interactable("home_pet", "照看宠物", Vector2(800, 210), Vector2(150, 90), Color("#d99a8f"), Vector2(220, 170))
			if FamilyManager.stage_id == "family":
				_add_interactable("home_child", FamilyManager.get_child_action_hint(), Vector2(500, 420), Vector2(150, 90), Color("#e8b45e"), Vector2(220, 170))
			if FamilyManager.has_partner():
				_add_interactable("home_partner", "和%s过一晚" % RelationshipManager.get_npc_name(FamilyManager.partner_id), Vector2(880, 420), Vector2(170, 80), Color("#d98a83"), Vector2(240, 160))
			_add_interactable("home_move|studio", "看独立小单间", Vector2(1050, 210), Vector2(160, 62), Color("#8ba8c4"), Vector2(220, 130))
			_add_interactable("home_move|one_bed", "看一室一厅", Vector2(1050, 300), Vector2(160, 62), Color("#9f8fcc"), Vector2(220, 130))
			_add_interactable("home_move|river_apartment", "看河边公寓", Vector2(1050, 390), Vector2(160, 62), Color("#79a9c8"), Vector2(220, 130))
		"street":
			_build_city_map_interactables()
		"factory":
			_add_interactable("work_station", "到工位干活", Vector2(640, 190), Vector2(180, 100), Color("#f1bd5a"), Vector2(260, 230))
			_add_interactable("factory_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"store":
			_add_interactable("store_counter", "看看柜台商品", Vector2(640, 185), Vector2(300, 90), Color("#efc761"), Vector2(420, 280))
			_add_interactable("store_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"recycle":
			_add_interactable("recycle_search", "翻找废品堆", Vector2(640, 300), Vector2(230, 110), Color("#b7b38a"), Vector2(410, 260))
			_add_interactable("recycle_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"market":
			_build_market_interactables()
		"night_market":
			_build_night_market_interactables()
		"park":
			_add_interactable("exercise_equipment", "活动一下身体", Vector2(240, 520), Vector2(260, 100), Color("#72a97c"), Vector2(430, 250))
			_add_interactable("career_board|study", "看夜校和升学信息", Vector2(900, 180), Vector2(190, 80), Color("#9f8fcc"), Vector2(260, 160))
			_add_interactable("career_work|study", "去夜校上课", Vector2(900, 300), Vector2(170, 70), Color("#8ba8c4"), Vector2(240, 140))
			_add_interactable("enter_community_center", "去社区活动中心", Vector2(1100, 580), Vector2(180, 70), Color("#7f9fb0"), Vector2(250, 140))
			if FamilyManager.has_partner():
				_add_interactable("partner_date|park", "和%s在公园坐一会儿" % RelationshipManager.get_npc_name(FamilyManager.partner_id), Vector2(640, 250), Vector2(210, 76), Color("#d98a83"), Vector2(280, 150))
			_add_interactable("park_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"ruins":
			_add_interactable("ruins_exit", "顺着灯光回到地面", Vector2(640, 640), Vector2(150, 90), Color("#f0c968"), Vector2(220, 160))
		"bank":
			_add_interactable("bank_counter", "到银行柜台办业务", Vector2(390, 260), Vector2(260, 90), Color("#6b9db4"), Vector2(360, 220))
			_add_interactable("lottery_counter", "买一张彩票", Vector2(890, 260), Vector2(260, 90), Color("#d7a957"), Vector2(360, 220))
			_add_interactable("bank_exit", "离开银行", Vector2(640, 640), Vector2(150, 85), Color("#8ba7af"), Vector2(210, 150))
		"restaurant":
			_build_restaurant_interactables()
		"wholesale":
			_add_interactable("wholesale_exit", "离开批发市场", Vector2(640, 650), Vector2(150, 85), Color("#8ba7af"), Vector2(210, 150))
			_add_interactable("wholesale_sell_counter", "把库存卖给收购台", Vector2(640, 510), Vector2(280, 80), Color("#c08b54"), Vector2(420, 150))
			_build_wholesale_crates()
		"farm":
			_build_farm_interactables()
		"farm_livestock":
			_build_livestock_interactables()
		"logistics_port":
			_build_logistics_port_interactables()
		"craft_workshop":
			_build_craft_workshop_interactables()
		"pet_store":
			_build_pet_interactables()
		"furniture_store":
			_build_furniture_interactables()
		"breakfast_shop":
			_build_breakfast_interactables()
		"breakfast_kitchen":
			_build_breakfast_kitchen_interactables()
		"commercial_district":
			_add_interactable("street_exit", "坐公交回城中村", Vector2(640, 650), Vector2(160, 84), Color("#8ba7af"), Vector2(220, 150))
			_add_interactable("enter_restaurant", "去餐馆", Vector2(300, 260), Vector2(170, 96), Color("#db7658"), Vector2(230, 170))
			_add_interactable("enter_bank", "去银行和彩票站", Vector2(540, 260), Vector2(170, 96), Color("#79a9c8"), Vector2(230, 170))
			_add_interactable("enter_store", "进便利店", Vector2(780, 260), Vector2(170, 96), Color("#f0c968"), Vector2(230, 170))
			_add_interactable("enter_furniture", "逛家居超市", Vector2(1020, 260), Vector2(170, 96), Color("#9f8fcc"), Vector2(230, 170))
			_add_interactable("enter_clothing", "进服装店", Vector2(900, 380), Vector2(170, 96), Color("#d68d90"), Vector2(230, 170))
			_add_interactable("career_board|office", "看写字楼招聘板", Vector2(1020, 500), Vector2(170, 76), Color("#79a9c8"), Vector2(240, 150))
			_add_interactable("career_work|office", "进写字楼上班", Vector2(1020, 580), Vector2(170, 70), Color("#6b9db4"), Vector2(240, 140))
			_add_interactable("career_board|public", "看社区和体制招聘", Vector2(640, 500), Vector2(170, 76), Color("#8ba8c4"), Vector2(240, 150))
			_add_interactable("career_work|public", "去社区值班", Vector2(640, 580), Vector2(170, 70), Color("#79a9c8"), Vector2(240, 140))
			_add_interactable("enter_bus_station", "去长途巴士站", Vector2(1120, 520), Vector2(180, 70), Color("#d8a75c"), Vector2(250, 140))
			_add_interactable("enter_clinic", "去社区诊所", Vector2(1020, 620), Vector2(170, 70), Color("#8fc6bf"), Vector2(240, 140))
			_add_interactable("enter_university", "去城市夜校和大学校区", Vector2(200, 600), Vector2(200, 70), Color("#9f8fcc"), Vector2(270, 140))
			_add_interactable("enter_high_end", "去高端住宅区", Vector2(200, 260), Vector2(180, 90), Color("#c8b58c"), Vector2(250, 170))
			_add_interactable("housing_model|studio", "看独立小单间模型", Vector2(150, 350), Vector2(150, 64), Color("#8ba8c4"), Vector2(190, 100))
			_add_interactable("housing_model|one_bed", "看一室一厅模型", Vector2(150, 430), Vector2(150, 64), Color("#9f8fcc"), Vector2(190, 100))
			_add_interactable("housing_model|river_apartment", "看河边公寓模型", Vector2(150, 510), Vector2(150, 64), Color("#79a9c8"), Vector2(190, 100))
			if FamilyManager.has_partner():
				_add_interactable("partner_date|commercial_district", "和%s逛一圈商业区" % RelationshipManager.get_npc_name(FamilyManager.partner_id), Vector2(640, 380), Vector2(210, 76), Color("#d98a83"), Vector2(280, 150))
			_add_enterprise_interactables("snack_drink", Vector2(220, 500), Vector2(220, 580))
			_add_enterprise_interactables("retail_shop", Vector2(860, 500), Vector2(860, 580))
		"bus_station":
			_build_bus_station_interactables()
		"seaside_resort", "ancient_village", "mountain_spring":
			_build_travel_destination_interactables(area_id)
		"industrial_district":
			_add_interactable("street_exit", "坐公交回城中村", Vector2(640, 650), Vector2(160, 84), Color("#8ba7af"), Vector2(220, 150))
			_add_interactable("career_board|factory", "看工厂招工与试工", Vector2(800, 520), Vector2(190, 72), Color("#c99b70"), Vector2(250, 145))
			_add_interactable("enter_factory", "进工厂看看", Vector2(950, 280), Vector2(190, 100), Color("#8fc6bf"), Vector2(250, 180))
			_add_interactable("labor_market", "去城中村劳务市场招人", Vector2(330, 280), Vector2(200, 100), Color("#c99b70"), Vector2(260, 180))
			_add_interactable("career_board|logistics", "看物流仓配招聘", Vector2(640, 260), Vector2(190, 70), Color("#79a9c8"), Vector2(260, 140))
			_add_interactable("enter_logistics_port", "去物流港仓", Vector2(640, 330), Vector2(190, 70), Color("#6b9db4"), Vector2(260, 140))
			_add_interactable("career_board|craft", "看手艺工坊招聘", Vector2(1000, 500), Vector2(190, 70), Color("#c49a69"), Vector2(260, 140))
			_add_interactable("enter_craft_workshop", "去手艺工坊", Vector2(1000, 580), Vector2(190, 70), Color("#b88d5f"), Vector2(260, 140))
			_add_interactable("enter_wholesale", "去批发仓库", Vector2(640, 470), Vector2(200, 100), Color("#8fb09b"), Vector2(260, 180))
			_add_enterprise_interactables("small_factory", Vector2(300, 480), Vector2(540, 480))
		"high_end_district":
			_build_high_end_interactables()
		"suburb":
			_add_interactable("street_exit", "坐公交回城中村", Vector2(640, 650), Vector2(160, 84), Color("#8ba7af"), Vector2(220, 150))
			_add_interactable("enter_farm", "去城郊农场", Vector2(390, 330), Vector2(200, 110), Color("#7fae7a"), Vector2(270, 190))
			_add_interactable("enter_pet_store", "去宠物商店", Vector2(890, 330), Vector2(200, 110), Color("#d99a8f"), Vector2(270, 190))
		"clothing_store":
			_add_interactable("wardrobe_counter", "看搭配和已买下的衣服", Vector2(640, 190), Vector2(320, 90), Color("#d68d90"), Vector2(460, 200))
			_add_interactable("sewing_machine", "在阿珍的缝纫机前加固背包", Vector2(1020, 420), Vector2(180, 72), Color("#b58f63"), Vector2(220, 130))
			var clothing_ids := ConfigDB.get_rows("clothing").keys()
			for index in range(clothing_ids.size()):
				var clothing_id := str(clothing_ids[index])
				var clothing_row := ConfigDB.get_row("clothing", clothing_id)
				var col := index % 3
				var row_index := int(index / 3)
				var rack_pos := Vector2(220.0 + float(col) * 420.0, 340.0 + float(row_index) * 180.0)
				var rack_state := "买下" if not WardrobeManager.has_owned(clothing_id) else ("穿着中" if WardrobeManager.is_wearing(clothing_id) else "换上")
				var rack := _add_interactable("clothing_rack|%s" % clothing_id, "%s · %s · ¥%d" % [str(clothing_row.get("name", clothing_id)), rack_state, int(clothing_row.get("price", "0"))], rack_pos, Vector2(190, 92), Color.from_string(str(clothing_row.get("color", "#d68d90")), Color("#d68d90")), Vector2(230, 150))
				rack.set_caption(str(clothing_row.get("name", clothing_id)), Color.from_string(str(clothing_row.get("color", "#d68d90")), Color("#d68d90")))
			_add_interactable("clothing_exit", "离开服装店", Vector2(640, 650), Vector2(150, 84), Color("#8ba7af"), Vector2(220, 150))
		"community_center":
			_add_interactable("community_center_exit", "离开活动中心", Vector2(1180, 650), Vector2(150, 70), Color("#8ba7af"), Vector2(220, 140))
			for index in range(HobbyManager.get_lines().size()):
				var hobby: Dictionary = HobbyManager.get_lines()[index]
				var col := index % 3
				var row_index := int(index / 3)
				_add_interactable("hobby_action|%s" % str(hobby["id"]), "%s · %s" % [str(hobby["name"]), str(hobby["hint_text"])], Vector2(230.0 + float(col) * 410.0, 250.0 + float(row_index) * 190.0), Vector2(310, 100), Color("#7f9fb0"), Vector2(410, 210))
			_add_interactable("hobby_summary", "看兴趣课程记录", Vector2(640, 600), Vector2(260, 70), Color("#8ba8c4"), Vector2(360, 140))
		"university":
			_add_interactable("university_exit", "离开校区", Vector2(1180, 650), Vector2(150, 70), Color("#8ba7af"), Vector2(220, 140))
			for index in range(EducationManager.get_course_lines().size()):
				var course: Dictionary = EducationManager.get_course_lines()[index]
				var col := index % 3
				var row_index := int(index / 3)
				_add_interactable("course_action|%s" % str(course["id"]), "%s · %s" % [str(course["name"]), str(course["hint_text"])], Vector2(230.0 + float(col) * 410.0, 230.0 + float(row_index) * 190.0), Vector2(320, 110), Color("#9f8fcc"), Vector2(410, 210))
			_add_interactable("education_summary", "看课程与证书记录", Vector2(640, 600), Vector2(260, 70), Color("#8ba8c4"), Vector2(360, 140))
		"clinic":
			_add_interactable("clinic_exit", "离开诊所", Vector2(1180, 650), Vector2(150, 70), Color("#8ba7af"), Vector2(220, 140))
			for index in range(MedicalManager.get_service_lines().size()):
				var service: Dictionary = MedicalManager.get_service_lines()[index]
				_add_interactable("clinic_service|%s" % str(service["id"]), "做%s" % str(service["name"]), Vector2(260.0 + float(index % 3) * 380.0, 250.0 + float(int(index / 3)) * 190.0), Vector2(300, 110), Color("#8fc6bf"), Vector2(390, 210))
		"riverside":
			_add_interactable("nature_walk", "沿水边慢慢走一段", Vector2(250, 520), Vector2(220, 80), Color("#6faa8d"), Vector2(290, 160))
			_add_interactable("nature_sit", "在长椅坐一会儿", Vector2(610, 500), Vector2(180, 72), Color("#78a88a"), Vector2(250, 150))
			_add_interactable("nature_photo", "在观景台拍照", Vector2(960, 470), Vector2(190, 76), Color("#8eb6c5"), Vector2(270, 150))
			_add_interactable("nature_collect", "翻看岸边留下的东西", Vector2(500, 360), Vector2(220, 80), Color("#b3a06f"), Vector2(290, 160))
			_add_interactable("nature_fish", "下竿钓鱼 / 浮漂动了就再点一次", Vector2(760, 560), Vector2(260, 80), Color("#5f9da3"), Vector2(350, 160))
			_add_interactable("fishing_rod_upgrade", "找强叔换鱼竿或升级", Vector2(930, 330), Vector2(220, 76), Color("#8eb6c5"), Vector2(300, 150))
			_add_interactable("career_board|freelance", "看自由职业接单板", Vector2(1080, 520), Vector2(190, 76), Color("#b79bcf"), Vector2(260, 150))
			_add_interactable("career_work|freelance", "在河边接一单拍摄", Vector2(1080, 610), Vector2(190, 70), Color("#b79bcf"), Vector2(260, 140))
			if FamilyManager.has_partner():
				_add_interactable("partner_date|riverside", "和%s沿河走一段" % RelationshipManager.get_npc_name(FamilyManager.partner_id), Vector2(360, 260), Vector2(210, 76), Color("#d98a83"), Vector2(280, 150))
			_add_interactable("nature_exit", "回到城中村绿道", Vector2(640, 660), Vector2(180, 80), Color("#8ba7af"), Vector2(260, 150))


func _build_restaurant_interactables() -> void:
	_build_kitchen_scene_interactables(false)

func _build_breakfast_interactables() -> void:
	_add_interactable("breakfast_open", "门口挂上营业牌", Vector2(150, 650), Vector2(180, 72), Color("#e8c26a"), Vector2(250, 140))
	_add_interactable("kitchen_close", "提前收档", Vector2(350, 650), Vector2(140, 72), Color("#b9785d"), Vector2(210, 140))
	for index in range(3):
		var customer_node := _add_interactable("breakfast_customer|%d" % index, "招呼门口排队的客人", Vector2(360.0 + float(index) * 180.0, 330), Vector2(128, 82), Color("#d9b48f"), Vector2(170, 150))
		_breakfast_customer_nodes.append(customer_node)
	_refresh_breakfast_queue()
	_add_interactable("breakfast_counter", "点餐台，把后厨成品端给客人", Vector2(640, 520), Vector2(300, 82), Color("#e9b65a"), Vector2(430, 170))
	_add_interactable("enter_breakfast_kitchen", "进后厨安排锅灶和托盘", Vector2(980, 430), Vector2(190, 72), Color("#d9704f"), Vector2(270, 140))
	_add_interactable("breakfast_eat", "坐下吃一碗", Vector2(1040, 520), Vector2(160, 66), Color("#8fbf9a"), Vector2(230, 140))
	_add_interactable("breakfast_exit", "回到街上", Vector2(1080, 620), Vector2(140, 70), Color("#8ba7af"), Vector2(210, 140))

func _build_breakfast_kitchen_interactables() -> void:
	_add_interactable("kitchen_close", "提前收档", Vector2(120, 650), Vector2(140, 72), Color("#b9785d"), Vector2(210, 140))
	var station_types := KitchenManager.get_station_definitions(MarketPhaseManager.current_phase_id)
	for index in range(station_types.size()):
		var station_x := 150.0 + float(index) * 135.0
		_add_interactable("restaurant_station|%d" % index, "点击操作%s" % KitchenManager.get_station_name(str(station_types[index])), Vector2(station_x, 455), Vector2(142, 78), Color("#d9704f"), Vector2(180, 150))
	for tray_index in range(6):
		_add_interactable("kitchen_tray|%d" % tray_index, "点击托盘，把半成品送到下一工位", Vector2(300.0 + float(tray_index) * 135.0, 620), Vector2(112, 52), Color("#caa56f"), Vector2(150, 110))
	var recipe_ids: Array[String] = MarketPhaseManager.get_current_recipe_ids()
	for special_id in MarketPhaseManager.get_festival_recipe_ids():
		if special_id not in recipe_ids:
			recipe_ids.append(special_id)
	for index in range(mini(7, recipe_ids.size())):
		var recipe_id := str(recipe_ids[index])
		var recipe := ConfigDB.get_row("recipes", recipe_id)
		_add_interactable("recipe_order|%s" % recipe_id, "让后厨开始做%s" % str(recipe.get("name", recipe_id)), Vector2(130, 92.0 + float(index) * 46.0), Vector2(190, 42), Color("#78a886"), Vector2(220, 86))
	var equipment_lines := KitchenManager.get_equipment_lines()
	for index in range(equipment_lines.size()):
		var equipment: Dictionary = equipment_lines[index]
		_add_interactable("equipment_upgrade|%s" % str(equipment["type"]), "升级%s，只加快这一种工位" % str(equipment["name"]), Vector2(1120, 125.0 + float(index) * 64.0), Vector2(190, 50), Color("#9d82c6"), Vector2(220, 100))
	_add_interactable("breakfast_kitchen_exit", "回早餐店前厅", Vector2(1180, 650), Vector2(160, 70), Color("#8ba7af"), Vector2(240, 140))

func _build_kitchen_scene_interactables(is_breakfast: bool) -> void:
	var location := "breakfast_shop" if is_breakfast else "restaurant"
	_add_interactable("breakfast_open" if is_breakfast else "restaurant_open", "走到门口挂牌开档", Vector2(120, 650), Vector2(150, 72), Color("#e8c26a"), Vector2(220, 140))
	_add_interactable("kitchen_close", "提前收档", Vector2(310, 650), Vector2(130, 72), Color("#b9785d"), Vector2(200, 140))
	var station_types := KitchenManager.get_station_definitions(MarketPhaseManager.current_phase_id)
	for index in range(station_types.size()):
		var station_x := 150.0 + float(index) * 135.0
		_add_interactable("restaurant_station|%d" % index, "点击操作%s" % KitchenManager.get_station_name(str(station_types[index])), Vector2(station_x, 455), Vector2(142, 78), Color("#d9704f"), Vector2(180, 150))
	_add_interactable("restaurant_counter", "把做好的成品递给客人", Vector2(640, 560), Vector2(260, 72), Color("#e9b65a"), Vector2(420, 160))
	for tray_index in range(6):
		_add_interactable("kitchen_tray|%d" % tray_index, "点击托盘，把半成品送到下一工位", Vector2(300.0 + float(tray_index) * 135.0, 620), Vector2(112, 52), Color("#caa56f"), Vector2(150, 110))
	var recipe_ids: Array[String] = MarketPhaseManager.get_current_recipe_ids()
	for special_id in MarketPhaseManager.get_festival_recipe_ids():
		if special_id not in recipe_ids:
			recipe_ids.append(special_id)
	for index in range(mini(7, recipe_ids.size())):
		var recipe_id := str(recipe_ids[index])
		var recipe := ConfigDB.get_row("recipes", recipe_id)
		_add_interactable("recipe_order|%s" % recipe_id, "让师傅开始做%s" % str(recipe.get("name", recipe_id)), Vector2(130, 92.0 + float(index) * 46.0), Vector2(190, 42), Color("#78a886"), Vector2(220, 86))
	for index in range(KitchenManager.get_equipment_lines().size()):
		var equipment: Dictionary = KitchenManager.get_equipment_lines()[index]
		_add_interactable("equipment_upgrade|%s" % str(equipment["type"]), "升级%s，只加快这一种工位" % str(equipment["name"]), Vector2(1120, 125.0 + float(index) * 64.0), Vector2(190, 50), Color("#9d82c6"), Vector2(220, 100))
	if is_breakfast:
		for index in range(3):
			var breakfast_node := _add_interactable("breakfast_customer|%d" % index, "接待第%d位排队客人" % (index + 1), Vector2(400.0 + float(index) * 165.0, 340), Vector2(112, 74), Color("#d9b48f"), Vector2(150, 140))
			_breakfast_customer_nodes.append(breakfast_node)
		_add_interactable("breakfast_eat", "坐下吃一碗", Vector2(980, 620), Vector2(150, 62), Color("#8fbf9a"), Vector2(220, 130))
		_add_interactable("breakfast_exit", "回到街上", Vector2(1180, 650), Vector2(130, 70), Color("#8ba7af"), Vector2(200, 140))
		_refresh_breakfast_queue()
	else:
		for index in range(3):
			var restaurant_node := _add_interactable("restaurant_customer|%d" % index, "招呼第%d位客人" % (index + 1), Vector2(430.0 + float(index) * 170.0, 300), Vector2(120, 76), Color("#d9b48f"), Vector2(160, 145))
			_restaurant_customer_nodes.append(restaurant_node)
		_refresh_restaurant_queue()
		_add_interactable("restaurant_eat", "坐下吃一顿", Vector2(900, 540), Vector2(150, 62), Color("#8fbf9a"), Vector2(220, 130))
		_add_interactable("restaurant_upgrade", "看扩店告示", Vector2(1120, 540), Vector2(150, 62), Color("#a992db"), Vector2(220, 130))
		_add_interactable("restaurant_staff_board", "看餐馆招工与晋升", Vector2(1120, 610), Vector2(150, 62), Color("#d8a75c"), Vector2(220, 130))
		_add_interactable("restaurant_exit", "回到主街", Vector2(1180, 680), Vector2(130, 70), Color("#8ba7af"), Vector2(200, 140))

func _build_high_end_interactables() -> void:
	_add_interactable("high_end_exit", "回商业区", Vector2(1180, 650), Vector2(150, 70), Color("#8ba7af"), Vector2(220, 140))
	_add_interactable("high_end_rooftop", "在楼顶花园歇一会儿", Vector2(640, 520), Vector2(220, 80), Color("#7fae7a"), Vector2(300, 160))
	_add_interactable("high_end_cafe", "在街角咖啡店坐一会儿", Vector2(980, 250), Vector2(190, 80), Color("#c49a69"), Vector2(260, 160))
	_add_interactable("high_end_gallery", "去社区画廊看看照片", Vector2(300, 250), Vector2(190, 80), Color("#9f8fcc"), Vector2(260, 160))
	for index in range(HousingManager.get_options().size()):
		var option: Dictionary = HousingManager.get_options()[index]
		if int(option.get("tier", 0)) < 4:
			continue
		var housing_id := str(option.get("id", ""))
		_add_interactable("high_home|%s" % housing_id, "看%s" % str(option.get("name", housing_id)), Vector2(360.0 + float(index) * 160.0, 370), Vector2(145, 78), Color("#c8b58c"), Vector2(210, 150))

func _build_logistics_port_interactables() -> void:
	_add_interactable("logistics_port_exit", "回工业区", Vector2(1180, 650), Vector2(150, 70), Color("#8ba7af"), Vector2(220, 140))
	_add_interactable("career_work|logistics", "去物流仓库上班", Vector2(640, 280), Vector2(210, 90), Color("#79a9c8"), Vector2(290, 170))
	_add_interactable("port_loading", "帮忙装卸一车货", Vector2(300, 430), Vector2(210, 90), Color("#c49a69"), Vector2(290, 170))
	_add_interactable("port_dispatch", "看线路调度台", Vector2(980, 430), Vector2(210, 90), Color("#8fbf9a"), Vector2(290, 170))

func _build_craft_workshop_interactables() -> void:
	_add_interactable("craft_workshop_exit", "回工业区", Vector2(1180, 650), Vector2(150, 70), Color("#8ba7af"), Vector2(220, 140))
	_add_interactable("career_work|craft", "去手艺工坊上班", Vector2(640, 280), Vector2(210, 90), Color("#c49a69"), Vector2(290, 170))
	_add_interactable("craft_repair", "接一件家电维修", Vector2(300, 430), Vector2(210, 90), Color("#b88d5f"), Vector2(290, 170))
	_add_interactable("craft_practice", "练一会儿木工和修补", Vector2(980, 430), Vector2(210, 90), Color("#9f8fcc"), Vector2(290, 170))

func _build_bus_station_interactables() -> void:
	_add_interactable("bus_station_exit", "回商业区", Vector2(1180, 650), Vector2(150, 70), Color("#8ba7af"), Vector2(220, 140))
	var destinations := TravelManager.get_destination_lines()
	for index in range(destinations.size()):
		var destination: Dictionary = destinations[index]
		var col := index % 2
		var row_index := int(index / 2)
		var pos := Vector2(360.0 + float(col) * 520.0, 260.0 + float(row_index) * 150.0)
		_add_interactable("travel_destination|%s" % str(destination["id"]), "买票去%s" % str(destination["name"]), pos, Vector2(330, 90), Color("#d8a75c"), Vector2(430, 180))

func _build_travel_destination_interactables(area_id: String) -> void:
	_add_interactable("destination_exit", "回长途巴士站", Vector2(1180, 650), Vector2(170, 70), Color("#8ba7af"), Vector2(250, 140))
	_add_interactable("travel_photo|%s" % area_id, "拍一张当地风景照", Vector2(340, 330), Vector2(220, 80), Color("#b79bcf"), Vector2(300, 160))
	_add_interactable("travel_rest|%s" % area_id, "在当地坐下歇一会儿", Vector2(760, 420), Vector2(220, 80), Color("#78a88a"), Vector2(300, 160))
	_add_interactable("travel_souvenir|%s" % area_id, "看看当地小摊", Vector2(980, 250), Vector2(220, 80), Color("#c49a69"), Vector2(300, 160))

func _build_wholesale_crates() -> void:
	var goods_rows := ConfigDB.get_rows("goods")
	var index := 0
	for goods_id in goods_rows:
		var column := index % 4
		var row := int(index / 4)
		var crate_pos := Vector2(210.0 + float(column) * 290.0, 200.0 + float(row) * 190.0)
		var crate := _add_interactable(
			"wholesale_buy|%s" % str(goods_id),
			"买一箱%s" % str(ConfigDB.get_row("goods", goods_id).get("name", goods_id)),
			crate_pos,
			Vector2(130, 88),
			Color("#c29a63"),
			Vector2(180, 150)
		)
		crate.set_mystery(false)
		index += 1

func _build_market_interactables() -> void:
	var items := InventoryManager.get_giftable_lines()
	if _selected_market_item.is_empty() and not items.is_empty():
		_selected_market_item = str(items[0].get("id", ""))
	for index in range(mini(8, items.size())):
		var entry: Dictionary = items[index]
		var item_id := str(entry.get("id", ""))
		var col := index % 4
		var row_index := int(index / 4)
		var prompt := "选中%s" % str(entry.get("name", item_id))
		if item_id == _selected_market_item:
			prompt = "已选中%s" % str(entry.get("name", item_id))
		_add_interactable("market_select|%s" % item_id, prompt, Vector2(120.0 + float(col) * 220.0, 220.0 + float(row_index) * 82.0), Vector2(220, 70), Color("#d97865"), Vector2(250, 130))
	_add_interactable("market_sell", "把选中的旧物立即卖出", Vector2(520, 560), Vector2(260, 80), Color("#c08b54"), Vector2(360, 160))
	_add_interactable("market_consign", "把选中的旧物寄卖", Vector2(780, 560), Vector2(230, 80), Color("#b88762"), Vector2(330, 160))
	_add_interactable("market_upgrade", "把摊位做大一点", Vector2(320, 620), Vector2(260, 80), Color("#a992db"), Vector2(360, 160))
	_add_interactable("expedition_board", "打听旧楼入口", Vector2(220, 290), Vector2(180, 76), Color("#7f9fb0"), Vector2(270, 150))
	_add_interactable("market_exit", "回到街上", Vector2(640, 668), Vector2(150, 76), Color("#91a9a2"), Vector2(220, 140))

func _build_city_map_interactables() -> void:
	# One continuous city map: each district has a physical approach instead of a row of doors.
	var home_door := _add_interactable("home_door", "回到出租屋", Vector2(170, 1350), Vector2(100, 72), Color("#e8b45e"), Vector2(150, 120))
	home_door.set_caption("城中村生活区", Color("#f0c968"))
	var breakfast := _add_interactable("enter_breakfast", "走进楼下早餐店", Vector2(250, 1040), Vector2(150, 76), Color("#e8c26a"), Vector2(210, 140))
	breakfast.set_caption("早餐店", Color("#f0c968"))
	_add_interactable("enter_recycle", "走进废品回收站", Vector2(520, 1360), Vector2(150, 76), Color("#8e9d8d"), Vector2(210, 140))
	_add_interactable("enter_market", "走进旧货市场", Vector2(430, 460), Vector2(160, 78), Color("#d97865"), Vector2(220, 145))
	_add_interactable("enter_park", "进社区公园走走", Vector2(880, 1080), Vector2(160, 80), Color("#7eb08a"), Vector2(220, 145))
	_add_interactable("park_exit", "沿小路回主街", Vector2(900, 1180), Vector2(140, 68), Color("#8fbf82"), Vector2(200, 120))
	_add_interactable("go_nature", "沿河畔绿道走一段", Vector2(950, 920), Vector2(220, 76), Color("#6faa8d"), Vector2(290, 140))
	# Commercial district buildings are physically present on the same city map.
	_add_interactable("enter_store", "走进便利店", Vector2(1600, 980), Vector2(150, 72), Color("#E8C26A"), Vector2(190, 125)).set_caption("便利店", Color("#E8A85C"))
	_add_interactable("enter_bank", "走进银行与彩票站", Vector2(1740, 980), Vector2(150, 72), Color("#79A9C8"), Vector2(190, 125)).set_caption("银行", Color("#A8C4B8"))
	_add_interactable("enter_restaurant", "走进餐馆", Vector2(1880, 980), Vector2(150, 72), Color("#D98C7A"), Vector2(190, 125)).set_caption("餐馆", Color("#E8A85C"))
	_add_interactable("enter_furniture", "走进家居超市", Vector2(2020, 980), Vector2(150, 72), Color("#B8A6D8"), Vector2(190, 125)).set_caption("家居", Color("#C9B6E0"))
	_add_interactable("enter_clothing", "走进服装店", Vector2(1600, 1200), Vector2(150, 72), Color("#D98C9A"), Vector2(190, 125)).set_caption("服装店", Color("#D98C9A"))
	var bus_station_door := _add_interactable("enter_bus_station", "走进长途巴士站", Vector2(1780, 1200), Vector2(150, 72), Color("#D8A75C"), Vector2(190, 125))
	bus_station_door.set_caption("巴士站", Color("#E8A85C"))
	bus_station_door.set_available(UnlockManager.can_access("bus_station"))
	_add_interactable("enter_clinic", "走进社区诊所", Vector2(1960, 1200), Vector2(150, 72), Color("#8FC6BF"), Vector2(190, 125)).set_caption("诊所", Color("#8FC6BF"))
	var university_door := _add_interactable("enter_university", "走进城市夜校", Vector2(1540, 1060), Vector2(150, 72), Color("#B8A6D8"), Vector2(190, 125))
	university_door.set_caption("夜校", Color("#C9B6E0"))
	university_door.set_available(UnlockManager.current_level >= 1 or UnlockManager.force_unlock_all)
	var housing_model := _add_interactable("housing_model|studio", "看独立小单间模型", Vector2(2100, 1200), Vector2(150, 60), Color("#8BA8C4"), Vector2(180, 95))
	housing_model.set_caption("置业处", Color("#A8C4B8"))
	housing_model.set_available(UnlockManager.current_level >= 2 or UnlockManager.force_unlock_all)
	# Industrial district is also part of the same walkable city map.
	_add_interactable("career_board|factory", "看工厂招工与试工", Vector2(1540, 120), Vector2(170, 68), Color("#C99B70"), Vector2(220, 120)).set_caption("工厂招聘", Color("#E8A85C"))
	var factory_door := _add_interactable("enter_factory", "走进工厂", Vector2(1680, 165), Vector2(150, 72), Color("#8FC6BF"), Vector2(190, 125))
	factory_door.set_caption("工厂", Color("#8FC6BF"))
	factory_door.set_available(CareerManager.application_line == "factory" or CareerManager.is_employed_in("factory") or UnlockManager.force_unlock_all)
	_add_interactable("labor_market", "去劳务市场看看", Vector2(1840, 130), Vector2(160, 66), Color("#C99B70"), Vector2(210, 120)).set_caption("劳务市场", Color("#E8A85C"))
	_add_interactable("career_board|logistics", "看物流仓配招聘", Vector2(1580, 300), Vector2(170, 66), Color("#79A9C8"), Vector2(220, 120)).set_caption("物流招聘", Color("#A8C4B8"))
	# Keep this door off the factory-to-farm diagonal so a straight walk through the industrial district cannot clip it.
	var logistics_door := _add_interactable("enter_logistics_port", "走进物流港仓", Vector2(1600, 430), Vector2(160, 72), Color("#6B9DB4"), Vector2(200, 125))
	logistics_door.set_caption("物流港", Color("#8FC6BF"))
	logistics_door.set_available(CareerManager.application_line == "logistics" or UnlockManager.current_level >= 1 or UnlockManager.force_unlock_all)
	_add_interactable("career_board|craft", "看手艺工坊招聘", Vector2(1980, 300), Vector2(170, 66), Color("#C49A69"), Vector2(220, 120)).set_caption("工坊招聘", Color("#E8A85C"))
	var craft_door := _add_interactable("enter_craft_workshop", "走进手艺工坊", Vector2(2050, 380), Vector2(160, 72), Color("#B88D5F"), Vector2(200, 125))
	craft_door.set_caption("手艺工坊", Color("#C89C5A"))
	craft_door.set_available(CareerManager.application_line == "craft" or UnlockManager.current_level >= 1 or UnlockManager.force_unlock_all)
	var wholesale_door := _add_interactable("enter_wholesale", "走进批发仓库", Vector2(1880, 370), Vector2(160, 72), Color("#8FB09B"), Vector2(200, 125))
	wholesale_door.set_caption("批发仓库", Color("#9BBF8A"))
	wholesale_door.set_available(BusinessManager.business_level >= 1 or UnlockManager.current_level >= 1 or UnlockManager.force_unlock_all)
	# Suburb buildings are at the far east edge of the same map.
	var farm_door := _add_interactable("enter_farm", "走进城郊农场", Vector2(2160, 1050), Vector2(160, 76), Color("#7FAE7A"), Vector2(210, 135))
	farm_door.set_caption("城郊农场", Color("#9BBF8A"))
	farm_door.set_available(UnlockManager.can_access("suburb"))
	var pet_door := _add_interactable("enter_pet_store", "走进宠物商店", Vector2(2340, 1050), Vector2(160, 76), Color("#D99A8F"), Vector2(210, 135))
	pet_door.set_caption("宠物商店", Color("#D98C9A"))
	pet_door.set_available(UnlockManager.can_access("suburb"))
	_add_interactable("enter_night_market", "夜里去逛城中村夜市", Vector2(1420, 1360), Vector2(180, 72), Color("#e8b45e"), Vector2(250, 135))
	# Street activities are physical, repeatable parts of the continuous city.
	_add_interactable("street_food_stall", "在路边摊买一份热食", Vector2(650, 1150), Vector2(150, 68), Color("#D9A45F"), Vector2(210, 120)).set_caption("街头摊", Color("#F0C968"))
	_add_interactable("street_delivery_gig", "接一单跑腿兼职", Vector2(1180, 760), Vector2(170, 68), Color("#79A9C8"), Vector2(230, 120)).set_caption("跑腿驿站", Color("#A8C4B8"))
	_add_interactable("street_photo_spot", "拍一张城市照片", Vector2(1300, 1250), Vector2(150, 68), Color("#B8A6D8"), Vector2(210, 120)).set_caption("拍照点", Color("#C9B6E0"))
	_add_interactable("street_recycle_bin", "翻找可回收物", Vector2(600, 1300), Vector2(140, 68), Color("#8E9D8D"), Vector2(200, 120)).set_caption("回收箱", Color("#A8C4B8"))
	_add_interactable("street_performance", "在街角表演", Vector2(900, 1100), Vector2(150, 68), Color("#D98C9A"), Vector2(210, 120)).set_caption("街头舞台", Color("#E8A85C"))
	_add_interactable("street_event_point", "看看路边发生了什么", Vector2(1250, 1390), Vector2(160, 68), Color("#E8B45E"), Vector2(220, 120)).set_caption("街角事件", Color("#F0C968"))
	_add_enterprise_interactables("street_stall", Vector2(980, 760), Vector2(1200, 760))

func _add_enterprise_interactables(enterprise_id: String, operate_position: Vector2, upgrade_position: Vector2) -> void:
	var row := ConfigDB.get_row("enterprises", enterprise_id)
	if row.is_empty():
		return
	var name := str(row.get("name", enterprise_id))
	if not EnterpriseManager.is_owned(enterprise_id):
		_add_interactable("enterprise_license|%s" % enterprise_id, "盘下%s" % name, operate_position, Vector2(180, 70), Color("#c49a69"), Vector2(250, 140))
		return
	_add_interactable("enterprise_operate|%s" % enterprise_id, EnterpriseManager.get_operation_hint(enterprise_id), operate_position, Vector2(200, 76), Color("#c49a69"), Vector2(280, 150))
	if EnterpriseManager.get_level(enterprise_id) < int(row.get("max_level", "3")):
		_add_interactable("enterprise_upgrade|%s" % enterprise_id, "升级%s ¥%d" % [name, EnterpriseManager.get_upgrade_cost(enterprise_id)], upgrade_position, Vector2(190, 70), Color("#d0b56e"), Vector2(270, 140))

func _build_farm_interactables() -> void:
	_add_interactable("farm_exit", "回到城郊", Vector2(720, 650), Vector2(140, 70), Color("#8ba7af"), Vector2(210, 140))
	_add_interactable("farm_weather", "听农场主说天气和行情", Vector2(600, 590), Vector2(220, 70), Color("#7f9fb0"), Vector2(290, 140))
	if not FarmManager.has_farm:
		_add_interactable("farm_rent", "和农场主租下这块地（¥1200）", Vector2(640, 220), Vector2(300, 100), Color("#7fae7a"), Vector2(400, 200))
	var crops := FarmManager.get_available_crops()
	for index in range(mini(6, crops.size())):
		var crop_id := str(crops[index])
		var row := FarmManager.get_crop_row(crop_id)
		var col := index % 2
		var row_index := int(index / 2)
		_add_interactable("farm_crop|%s" % crop_id, "选种%s" % str(row.get("name", crop_id)), Vector2(120.0 + float(col) * 190.0, 250.0 + float(row_index) * 90.0), Vector2(190, 62), Color("#78a886"), Vector2(220, 120))
	for index in range(FarmManager.get_tool_lines().size()):
		var tool: Dictionary = FarmManager.get_tool_lines()[index]
		_add_interactable("farm_tool|%s" % str(tool["id"]), "升级%s" % str(tool["name"]), Vector2(500.0 + float(index) * 115.0, 115), Vector2(105, 56), Color("#9d82c6"), Vector2(170, 110))
	if FarmManager.has_farm:
		_add_interactable("enter_farm_livestock", "去农场圈舍看看", Vector2(1190, 420), Vector2(130, 70), Color("#c49a69"), Vector2(200, 140))
	for index in range(FarmManager.PLOT_COUNT):
		var col := index % 3
		var row_index := int(index / 3)
		var pos := Vector2(600.0 + float(col) * 240.0, 300.0 + float(row_index) * 170.0)
		_add_interactable("farm_plot|%d" % index, "点击照看这块地", pos, Vector2(180, 105), Color("#7fae7a"), Vector2(220, 160))

func _build_livestock_interactables() -> void:
	_add_interactable("farm_livestock_exit", "回到农场田边", Vector2(640, 650), Vector2(160, 70), Color("#8ba7af"), Vector2(230, 140))
	var animal_lines := FarmManager.get_animal_lines()
	for index in range(animal_lines.size()):
		var animal: Dictionary = animal_lines[index]
		var animal_id := str(animal.get("id", ""))
		_add_interactable("farm_animal|%s" % animal_id, FarmManager.get_animal_prompt(animal_id), Vector2(320.0 + float(index) * 320.0, 300), Vector2(210, 100), Color("#c49a69"), Vector2(300, 180))

func _build_night_market_interactables() -> void:
	_add_interactable("night_market_exit", "回城中村主街", Vector2(1180, 650), Vector2(140, 70), Color("#8ba7af"), Vector2(210, 140))
	_add_interactable("night_market_work", "帮摊主守一小时", Vector2(640, 560), Vector2(170, 70), Color("#8fbf9a"), Vector2(250, 140))
	if FamilyManager.has_partner():
		_add_interactable("partner_date|night_market", "和%s逛夜市" % RelationshipManager.get_npc_name(FamilyManager.partner_id), Vector2(980, 520), Vector2(190, 72), Color("#d98a83"), Vector2(260, 145))
	var stalls := NightMarketManager.get_available_stalls()
	for index in range(stalls.size()):
		var stall: Dictionary = stalls[index]
		var col := index % 3
		var row_index := int(index / 3)
		var stall_id := str(stall.get("id", ""))
		_add_interactable("night_market_stall|%s" % stall_id, NightMarketManager.get_stall_prompt(stall_id), Vector2(260.0 + float(col) * 380.0, 220.0 + float(row_index) * 190.0), Vector2(250, 100), Color("#d58b67"), Vector2(330, 180))

func _build_pet_interactables() -> void:
	_add_interactable("pet_store_exit", "离开宠物商店", Vector2(640, 650), Vector2(130, 80), Color("#8ba7af"), Vector2(200, 140))
	var pet_keys := ConfigDB.get_rows("pets").keys()
	for idx in range(pet_keys.size()):
		var pet_id := str(pet_keys[idx])
		var row := ConfigDB.get_row("pets", pet_id)
		var pos := Vector2(180.0 + float(idx) * 180.0, 320.0)
		_add_interactable("pet_adopt|%s" % pet_id, "看看%s" % str(row.get("name", pet_id)), pos, Vector2(140, 100), Color("#d99a8f"), Vector2(170, 150))

func _build_furniture_interactables() -> void:
	_add_interactable("furniture_exit", "离开家居超市", Vector2(1130, 650), Vector2(130, 80), Color("#8ba7af"), Vector2(200, 140))
	var fur_keys := ConfigDB.get_rows("furniture").keys()
	for idx in range(fur_keys.size()):
		var fid := str(fur_keys[idx])
		var row := ConfigDB.get_row("furniture", fid)
		var col := idx % 4
		var rowi := int(idx / 4)
		var pos := Vector2(200.0 + float(col) * 300.0, 250.0 + float(rowi) * 150.0)
		_add_interactable("furniture_buy|%s" % fid, "看%s" % str(row.get("name", fid)), pos, Vector2(160, 90), Color("#9f8fcc"), Vector2(220, 160))

func _build_npcs(area_id: String) -> void:
	var hour := TimeSystem.minute_of_day / 60
	var schedule_rows := ConfigDB.get_rows("npc_schedule")
	var npc_parent: Node = _area_root
	if area_id == "street":
		var street_npc_root := Node2D.new()
		street_npc_root.name = "StreetNpcs"
		street_npc_root.scale = Vector2.ONE * CITY_LAYOUT_SCALE
		_area_root.add_child(street_npc_root)
		npc_parent = street_npc_root
	for npc_id in schedule_rows:
		var rows: Variant = schedule_rows.get(npc_id, [])
		if typeof(rows) != TYPE_ARRAY:
			rows = [rows]
		for schedule in rows:
			if str(schedule.get("area_id", "")) != area_id:
				continue
			if hour < int(schedule.get("start_hour", "0")) or hour >= int(schedule.get("end_hour", "24")):
				continue
			if not _schedule_condition_ok(str(schedule.get("condition", "always"))):
				continue
			var row := ConfigDB.get_row("npcs", npc_id)
			var npc: NPCActor = NpcScript.new()
			var color := Color.from_string(str(row.get("color", "#ffffff")), Color.WHITE)
			var pos := Vector2(float(schedule.get("pos_x", "640")), float(schedule.get("pos_y", "360")))
			var patrol := pos + Vector2(120, 0)
			var patrol_speed := 0.0 if area_id in ["restaurant", "breakfast_shop", "breakfast_kitchen"] else 26.0
			npc.configure(npc_id, str(row.get("name", npc_id)), pos, patrol, color, patrol_speed)
			npc.interaction_requested.connect(_on_interaction_requested)
			if area_id == "street":
				npc.scale = Vector2.ONE / CITY_LAYOUT_SCALE
			npc_parent.add_child(npc)
			break

func _build_festival_activity(area_id: String) -> void:
	if FestivalManager.get_today_scene_id() != area_id:
		return
	var title := FestivalManager.get_today_activity_title()
	if title.is_empty():
		return
	var positions := {
		"street": Vector2(640, 260),
		"market": Vector2(940, 300),
		"riverside": Vector2(640, 270),
		"commercial_district": Vector2(640, 380),
		"industrial_district": Vector2(640, 360),
		"park": Vector2(500, 300),
		"university": Vector2(640, 330),
	}
	if not positions.has(area_id):
		return
	var activity := _add_interactable("festival_activity", "参加%s" % title, positions[area_id], Vector2(190, 78), Color("#d68d90"), Vector2(260, 150))
	activity.set_caption(title, Color("#f0c968"))

func _schedule_condition_ok(condition: String) -> bool:
	if condition.begins_with("festival:"):
		return CalendarManager.get_day_of_year() == int(condition.trim_prefix("festival:"))
	match condition:
		"festival":
			return CalendarManager.is_festival()
		"weekend":
			return TimeSystem.get_day_name() in ["周六", "周日"]
		"always", "":
			return true
	return true

func _is_walk_trigger_id(id: String) -> bool:
	# Interior doors stay deliberate interactions; walk-through triggers are for city entrances and exits.
	if id in ["leave_home", "home_to_living", "home_living_to_bedroom"]:
		return false
	return id.ends_with("_exit") or id.begins_with("enter_") or id.begins_with("go_") or id.contains("door")

func _add_interactable(
		id: String,
		prompt: String,
		position_on_map: Vector2,
		visual_size: Vector2,
		color: Color,
		hit_size: Vector2 = Vector2.ZERO
	) -> WorldInteractable:
	if is_instance_valid(_area_root) and str(_area_root.get_meta("area_id", "")) == "street":
		position_on_map *= CITY_LAYOUT_SCALE
	var interactable: WorldInteractable = InteractableScript.new()
	interactable.configure(id, prompt, position_on_map, visual_size, color, hit_size)
	if _is_walk_trigger_id(id):
		interactable.set_walk_trigger(true)
	interactable.interaction_requested.connect(_on_interaction_requested)
	_area_root.add_child(interactable)
	return interactable

func _on_kitchen_changed() -> void:
	_refresh_breakfast_queue()
	_refresh_restaurant_queue()

func _refresh_breakfast_queue() -> void:
	_refresh_customer_queue(_breakfast_customer_nodes, "breakfast_shop")

func _refresh_restaurant_queue() -> void:
	_refresh_customer_queue(_restaurant_customer_nodes, "restaurant")

func _refresh_customer_queue(nodes: Array[WorldInteractable], expected_area: String) -> void:
	if GameState.current_area != expected_area or nodes.is_empty():
		return
	var statuses := KitchenManager.get_orders_status()
	for index in range(nodes.size()):
		var customer_node: WorldInteractable = nodes[index]
		if not is_instance_valid(customer_node):
			continue
		if not KitchenManager.active:
			customer_node.set_available(true)
			customer_node.clear_status()
			customer_node.prompt_text = "招呼门口排队的客人"
			customer_node.accent_color = Color("#d9b48f")
			customer_node.queue_redraw()
			continue
		if index < statuses.size():
			var order: Dictionary = statuses[index]
			var ratio := float(order.get("patience_ratio", 0.0))
			customer_node.set_available(true)
			customer_node.set_status(ratio, _patience_color(ratio))
			customer_node.prompt_text = "%s：%s · %s" % [
				str(order.get("customer_name", "客人")),
				str(order.get("name", "点单")),
				KitchenManager.get_patience_text(ratio),
			]
			customer_node.accent_color = _customer_color(str(order.get("customer_id", "regular")))
		else:
			customer_node.set_available(false)
			customer_node.clear_status()
			customer_node.prompt_text = "这个位置暂时空着"
			customer_node.accent_color = Color("#6f6b62")
		customer_node.queue_redraw()

func _patience_color(ratio: float) -> Color:
	if ratio >= 0.72:
		return Color("#73c78a")
	if ratio >= 0.42:
		return Color("#e8c26a")
	return Color("#df7b67")

func _customer_color(customer_id: String) -> Color:
	match customer_id:
		"office_worker":
			return Color("#d9b48f")
		"student":
			return Color("#8fb6c8")
		"elder":
			return Color("#c6a06f")
		"courier":
			return Color("#e28a5f")
		"night_worker":
			return Color("#8f9fc3")
		"tourist":
			return Color("#d98fa4")
	return Color("#d9b48f")

func _on_interaction_requested(interaction_id: String) -> void:
	var parts := interaction_id.split("|", false)
	if parts.size() >= 2 and parts[0] == "npc":
		if parts[1] == "fangjie":
			_housing_advisor_met = true
		if parts[1] == "wang" and CareerManager.application_line == "factory" and CareerManager.application_stage == 3:
			CareerManager.confirm_application("factory")
		npc_requested.emit(parts[1])
		return
	if parts.size() == 2 and parts[0] == "restaurant_station":
		var station_index := int(parts[1])
		if not KitchenManager.active:
			_ensure_kitchen_shift()
		KitchenManager.handle_station_action(station_index)
		return
	if parts.size() == 2 and parts[0] == "recipe_order":
		if not KitchenManager.active and not _ensure_kitchen_shift():
			return
		_start_recipe_at_first_station(parts[1])
		return
	if parts.size() == 2 and parts[0] == "kitchen_tray":
		_move_tray_to_first_station(int(parts[1]))
		return
	if parts.size() == 2 and parts[0] == "equipment_upgrade":
		KitchenManager.upgrade_station(parts[1])
		return
	if parts.size() == 2 and parts[0] == "wholesale_buy":
		BusinessManager.buy_goods(parts[1], 1)
		return
	if parts.size() == 2 and parts[0] == "travel_destination":
		TravelManager.travel_to(parts[1])
		return
	if parts.size() == 2 and parts[0] == "travel_souvenir":
		TreasureManager.try_trigger_at("walk", Vector2(980, 250), GameState.current_area)
		return
	if parts.size() == 2 and parts[0] == "travel_photo":
		PhotoManager.take_photo(GameState.current_area)
		TravelManager.collect_postcard(parts[1])
		return
	if parts.size() == 2 and parts[0] == "travel_rest":
		TravelManager.rest_at_destination(parts[1])
		return
	if parts.size() == 2 and parts[0] == "hobby_action":
		HobbyManager.action(parts[1])
		_build_area("community_center", "entrance")
		return
	if parts.size() == 2 and parts[0] == "course_action":
		var course_id := parts[1]
		if EducationManager.is_exam_ready(course_id):
			EducationManager.take_exam(course_id)
		elif EducationManager.enrolled.has(course_id):
			EducationManager.study(course_id)
		else:
			EducationManager.enroll(course_id)
		_build_area("university", "entrance")
		return
	if parts.size() == 2 and parts[0] == "clinic_service":
		MedicalManager.visit_service(parts[1])
		return
	if parts.size() == 2 and parts[0] == "enterprise_license":
		EnterpriseManager.buy(parts[1])
		_build_area(GameState.current_area, "entrance")
		return
	if parts.size() == 2 and parts[0] == "enterprise_operate":
		EnterpriseManager.operate(parts[1])
		_build_area(GameState.current_area, "entrance")
		return
	if parts.size() == 2 and parts[0] == "enterprise_upgrade":
		EnterpriseManager.upgrade(parts[1])
		_build_area(GameState.current_area, "entrance")
		return
	if parts.size() == 2 and parts[0] == "career_board":
		CareerManager.register_interest(parts[1])
		_build_area(GameState.current_area, "entrance")
		return
	if parts.size() == 2 and parts[0] == "career_work":
		if CareerManager.is_employed_in(parts[1]):
			GameState.work_career_shift(parts[1])
		elif CareerManager.application_line == parts[1]:
			CareerManager.perform_trial_action(parts[1])
		else:
			NoticeManager.show_message("先去对应的招聘板登记，负责人才能安排试工。", "hint", "招工负责人")
		return
	if parts.size() == 2 and parts[0] == "market_select":
		_selected_market_item = parts[1]
		_build_area("market", "entrance")
		return
	if parts.size() == 2 and parts[0] == "market_sell":
		if MarketEconomyManager.sell_now(_selected_market_item):
			_build_area("market", "entrance")
		return
	if parts.size() == 2 and parts[0] == "market_consign":
		if MarketEconomyManager.consign_item(_selected_market_item):
			_build_area("market", "entrance")
		return
	if parts.size() >= 3 and parts[0] == "collect":
		var collected := false
		if parts[1] == "ruins":
			collected = ExpeditionManager.collect_spawn(parts[2])
		else:
			collected = CollectionManager.collect_spawn(parts[1], parts[2])
		if collected:
			_remove_interactable(interaction_id)
		return
	if parts.size() == 2 and parts[0] == "housing_model":
		if not _housing_advisor_met and not UnlockManager.force_unlock_all:
			NoticeManager.show_npc_message("先和我聊两句，房子不是看个模型就能定的。", "方姐", "hint")
		elif HousingManager.upgrade(parts[1]):
			_build_area(GameState.current_area, "entrance")
		return
	if parts.size() == 2 and parts[0] == "high_home":
		if not _housing_advisor_met:
			NoticeManager.show_npc_message("想看高层房源，先去商业区找方姐登记。", "物业前台", "hint")
		elif HousingManager.upgrade(parts[1]):
			_build_area(GameState.current_area, "entrance")
		return
	if parts.size() == 2 and parts[0] == "home_move":
		NoticeManager.show_npc_message("要搬家就去商业区找方姐，先看模型和通勤，再谈租约。", "梅姨", "hint")
		return
	if parts.size() == 2 and parts[0] == "farm_plot":
		FarmManager.interact_plot(int(parts[1]))
		return
	if parts.size() == 2 and parts[0] == "farm_crop":
		FarmManager.select_crop(parts[1])
		return
	if parts.size() == 2 and parts[0] == "farm_tool":
		FarmManager.upgrade_tool(parts[1])
		return
	if parts.size() == 2 and parts[0] == "night_market_stall":
		NightMarketManager.buy_stall(parts[1])
		_build_area("night_market", "entrance")
		return
	if parts.size() == 2 and parts[0] == "farm_animal":
		FarmManager.interact_animal(parts[1])
		_build_area(GameState.current_area, "entrance")
		return
	if parts.size() == 2 and parts[0] == "pet_adopt":
		PetManager.adopt(parts[1])
		return
	if parts.size() == 2 and parts[0] == "partner_date":
		var location_id := parts[1]
		if FamilyManager.go_on_date(location_id):
			_build_area(GameState.current_area, "entrance")
		return
	if interaction_id == "festival_activity":
		var activity_line := FestivalManager.join_today_activity()
		if not activity_line.is_empty():
			NoticeManager.show_npc_message(activity_line, "阿榕", "positive")
			if GameState.current_area == FestivalManager.get_today_scene_id():
				_build_area(GameState.current_area, "entrance")
		return
	if parts.size() == 2 and parts[0] == "clothing_rack":
		var clothing_id := parts[1]
		if not WardrobeManager.has_owned(clothing_id):
			if WardrobeManager.buy(clothing_id):
				_build_area("clothing_store", "entrance")
		elif not WardrobeManager.is_wearing(clothing_id):
			if WardrobeManager.wear(clothing_id):
				_build_area("clothing_store", "entrance")
		else:
			NoticeManager.show_npc_message("这件已经穿在身上了，想换别的就点旁边那排。", "阿珍", "hint")
		return
	if parts.size() == 2 and parts[0] == "furniture_buy":
		RoomManager.buy(parts[1])
		return
	if parts.size() == 2 and parts[0] == "breakfast_customer":
		if not KitchenManager.active and not KitchenManager.start_shift_for("breakfast_shop"):
			return
		KitchenManager.handle_order_tap(int(parts[1]))
		return
	if parts.size() == 2 and parts[0] == "restaurant_customer":
		if not KitchenManager.active and not KitchenManager.start_shift_for("restaurant"):
			return
		KitchenManager.handle_order_tap(int(parts[1]))
		return
	if interaction_id == "port_loading":
		if GameState.energy < 18.0:
			NoticeManager.show_npc_message("先歇口气，装卸货不是硬撑出来的。", "仓库调度", "warning")
		else:
			GameState.change_energy(-18.0)
			TimeSystem.advance_minutes(180)
			var port_wage := 90 + CareerManager.current_rank * 6
			GameState.earn(port_wage, "装完一车货，临时工钱结了 ¥%d。" % port_wage)
			NoticeManager.show_npc_message("手脚挺利索，晚上还有一车。", "仓库调度", "positive")
		return
	if interaction_id == "port_dispatch":
		NoticeManager.show_npc_message("线路表上每个名字都压着一段时间，先学会看天气和路况。", "物流调度", "hint")
		return
	if interaction_id == "craft_repair":
		if GameState.energy < 16.0:
			NoticeManager.show_npc_message("眼睛和手都需要休息，别把螺丝拧坏了。", "维修师傅", "warning")
		else:
			GameState.change_energy(-16.0)
			TimeSystem.advance_minutes(150)
			var craft_wage := 85 + CareerManager.current_rank * 7
			GameState.earn(craft_wage, "修好一台旧家电，收了 ¥%d。" % craft_wage)
			NoticeManager.show_npc_message("能修好，也要能装回去。下次让你碰更难的东西。", "维修师傅", "positive")
		return
	if interaction_id == "craft_practice":
		HobbyManager.action("painting")
		return
	if parts.size() == 2 and parts[0] == "room_slot":
		var slot_id := parts[1]
		if _selected_room_slot != slot_id:
			_selected_room_slot = slot_id
			if is_instance_valid(_room_furniture_layer):
				_room_furniture_layer.set_selected_slot(slot_id)
			NoticeManager.show_scene_message("选中了%s。点地面移动，滚轮旋转，再点一次切换家具。" % RoomManager.get_slot_name(slot_id), "出租屋", "hint")
		elif not RoomManager.cycle_slot_furniture(slot_id).is_empty():
			_build_area("home", "entrance")
		return
	if parts.size() == 2 and parts[0] == "room_renovation":
		if RoomManager.renovate(parts[1]):
			_build_area("home", "entrance")
		return
	match interaction_id:
		"bed":
			GameState.sleep_to_next_day()
		"fridge":
			inventory_requested.emit("冰箱里有什么，看看包里吧。")
		"study_desk":
			GameState.study_at_desk()
		"leave_home":
			SceneRouter.travel_to("street", "home_door")
		"home_to_living":
			SceneRouter.travel_to("home_living", "bedroom_door")
		"home_living_to_bedroom":
			SceneRouter.travel_to("home", "living_door")
		"home_door":
			SceneRouter.travel_to("home_living", "exit_door")
		"go_commercial":
			SceneRouter.travel_to("commercial_district", "entrance")
		"go_industrial":
			SceneRouter.travel_to("industrial_district", "entrance")
		"go_suburb":
			if UnlockManager.can_access("suburb"):
				SceneRouter.travel_to("suburb", "entrance")
			else:
				NoticeManager.show_message(UnlockManager.get_hint("suburb"), "hint", "巴士司机")
		"go_nature":
			GameState.change_energy(6.0)
			TimeSystem.advance_minutes(60)
			NoticeManager.show_scene_message("沿着河畔绿道走了一段，水声把城里的噪音压低了。", "河畔绿道", "positive")
		"nature_exit":
			SceneRouter.travel_to("street", "nature_exit")
		"enter_clinic":
			SceneRouter.travel_to("clinic", "entrance")
		"enter_university":
			SceneRouter.travel_to("university", "entrance")
		"street_food_stall":
			if GameState.spend(10, "在路边摊买了一份热乎的吃食。"):
				GameState.change_energy(12.0)
				TimeSystem.advance_minutes(20)
		"street_delivery_gig":
			if GameState.energy < 12.0:
				NoticeManager.show_scene_message("腿还有点软，先在路边歇一会儿再接单。", "跑腿驿站", "hint")
			else:
				GameState.change_energy(-12.0)
				TimeSystem.advance_minutes(90)
				GameState.earn(60 + CareerManager.current_rank * 3, "替街坊送完一单，跑腿钱到手。")
		"street_photo_spot":
			PhotoManager.take_photo("street")
			TreasureManager.try_trigger_at("walk", Vector2(1300, 1250) * CITY_LAYOUT_SCALE, "street")
		"street_recycle_bin":
			GameState.change_energy(-4.0)
			TimeSystem.advance_minutes(20)
			GameState.earn(12, "在回收箱里整理出一小捆废纸。")
			if RandomManager.chance(0.2):
				TreasureManager.try_trigger_at("walk", Vector2(600, 1300) * CITY_LAYOUT_SCALE, "street")
		"street_performance":
			GameState.change_energy(-8.0)
			TimeSystem.advance_minutes(45)
			GameState.earn(35, "街角表演引来一阵掌声，收到一点零钱。")
			GameState.hidden_reputation += 1.0
			NoticeManager.show_scene_message("有人停下来听完了这一段。", "街头舞台", "positive")
		"street_event_point":
			NoticeManager.show_scene_message("路边有人围成一圈，似乎有件小事正在发生。", "街角事件", "hint")
			TreasureManager.try_trigger_at("walk", Vector2(1250, 1390) * CITY_LAYOUT_SCALE, "street")
		"enter_community_center":
			SceneRouter.travel_to("community_center", "entrance")
		"community_center_exit":
			SceneRouter.travel_to("park", "community_center_exit")
		"university_exit":
			SceneRouter.travel_to("street", "university_exit")
		"clinic_exit":
			SceneRouter.travel_to("street", "clinic_exit")
		"enter_bus_station":
			if UnlockManager.can_access("bus_station"):
				SceneRouter.travel_to("bus_station", "entrance")
			else:
				NoticeManager.show_message(UnlockManager.get_hint("bus_station"), "hint", "巴士售票员")
		"bus_station_exit":
			SceneRouter.travel_to("street", "bus_station_exit")
		"destination_exit":
			SceneRouter.travel_to("bus_station", "destination_exit")
		"enter_clothing":
			SceneRouter.travel_to("clothing_store", "entrance")
		"clothing_exit":
			SceneRouter.travel_to("street", "clothing_exit")
		"enter_market":
			SceneRouter.travel_to("market", "entrance")
		"market_exit":
			SceneRouter.travel_to("street", "market_exit")
		"enter_factory":
			SceneRouter.travel_to("factory", "entrance")
		"factory_exit":
			SceneRouter.travel_to("street", "factory_exit")
		"enter_recycle":
			SceneRouter.travel_to("recycle", "entrance")
		"recycle_exit":
			SceneRouter.travel_to("street", "recycle_exit")
		"enter_park":
			GameState.exercise_at_park()
			NoticeManager.show_scene_message("走进公园，沿着树荫慢慢活动一下。", "社区公园", "positive")
		"park_exit":
			NoticeManager.show_scene_message("沿小路走回主街，公园还在身后。", "社区公园", "hint")
		"enter_store":
			SceneRouter.travel_to("store", "entrance")
		"enter_bank":
			SceneRouter.travel_to("bank", "entrance")
		"store_exit":
			SceneRouter.travel_to("street", "store_exit")
		"bank_exit":
			SceneRouter.travel_to("street", "bank_exit")
		"bank_counter":
			bank_requested.emit("bank")
		"enter_restaurant":
			SceneRouter.travel_to("restaurant", "entrance")
		"enter_wholesale":
			SceneRouter.travel_to("wholesale", "entrance")
		"enter_logistics_port":
			SceneRouter.travel_to("logistics_port", "entrance")
		"logistics_port_exit":
			SceneRouter.travel_to("street", "logistics_port_exit")
		"enter_craft_workshop":
			SceneRouter.travel_to("craft_workshop", "entrance")
		"craft_workshop_exit":
			SceneRouter.travel_to("street", "craft_workshop_exit")
		"enter_night_market":
			if NightMarketManager.can_enter():
				SceneRouter.travel_to("night_market", "entrance")
			else:
				NoticeManager.show_npc_message("夜市要等天黑以后才摆开，晚点再来。", "夜市摊主", "hint")
		"night_market_exit":
			SceneRouter.travel_to("street", "night_market_exit")
		"night_market_work":
			if NightMarketManager.work_stall():
				_build_area("night_market", "entrance")
		"enter_high_end":
			SceneRouter.travel_to("high_end_district", "entrance")
		"high_end_exit":
			SceneRouter.travel_to("street", "high_end_exit")
		"high_end_rooftop":
			GameState.change_energy(12.0)
			TimeSystem.advance_minutes(45)
			NoticeManager.show_scene_message("风吹过楼顶花园，城市的噪音在下面。", "云端花园", "positive")
		"high_end_cafe":
			if GameState.spend(18, "在街角咖啡店买了一杯咖啡。"):
				InventoryManager.add_item("coffee", 1)
		"high_end_gallery":
			HobbyManager.action("photography")
			_build_area("high_end_district", "entrance")
		"enter_farm":
			SceneRouter.travel_to("farm", "entrance")
		"enter_pet_store":
			SceneRouter.travel_to("pet_store", "entrance")
		"enter_furniture":
			SceneRouter.travel_to("furniture_store", "entrance")
		"nature_walk":
			GameState.exercise_at_park()
		"nature_sit":
			GameState.change_energy(10.0)
			TimeSystem.advance_minutes(30)
			NoticeManager.show_scene_message("水面反着光，坐一会儿心里松了些。", "河边长椅", "positive")
		"nature_photo":
			PhotoManager.take_photo("riverside")
			TreasureManager.try_trigger_at("walk", Vector2(960, 470), "riverside")
		"nature_collect":
			TreasureManager.try_trigger_at("walk", Vector2(500, 360), "riverside")
		"nature_fish":
			FishingManager.cast_or_reel()
		"fishing_rod_upgrade":
			FishingManager.upgrade_rod()
		"farm_weather":
			NoticeManager.show_message(FarmManager.get_weather_farm_hint(), "hint", "农场主")
		"farm_rent":
			if GameState.spend(1200, "在城郊租下了一小块农场。"):
				FarmManager.unlock_farm()
				_build_area("farm", "entrance")
		"enter_farm_livestock":
			SceneRouter.travel_to("farm_livestock", "entrance")
		"farm_livestock_exit":
			SceneRouter.travel_to("farm", "livestock_exit")
		"farm_exit":
			SceneRouter.travel_to("street", "farm_exit")
		"pet_store_exit":
			SceneRouter.travel_to("street", "pet_exit")
		"furniture_exit":
			SceneRouter.travel_to("street", "furniture_exit")
		"sewing_machine":
			if InventoryManager.backpack_level >= InventoryManager.BACKPACK_MAX_LEVEL:
				NoticeManager.show_npc_message("这背包已经缝到最结实了，再装就该把你压弯了。", "阿珍", "hint")
			elif InventoryManager.upgrade_backpack():
				_build_area("clothing_store", "entrance")
		"home_pet":
			pet_shop_requested.emit()
		"home_child":
			FamilyManager.interact_child()
			_build_area("home", "entrance")
		"home_partner":
			FamilyManager.share_evening()
			_build_area("home", "entrance")
		"home_storage":
			storage_requested.emit()
		"home_shipping", "farm_shipping":
			shipping_requested.emit()
		"home_room":
			if _room_edit_mode:
				_room_edit_mode = false
				_selected_room_slot = ""
				_build_area("home", "entrance")
				NoticeManager.show_scene_message("把布置收起来了，屋子还是原来的样子。", "出租屋", "hint")
			else:
				_room_edit_mode = true
				_selected_room_slot = ""
				_build_area("home", "entrance")
				NoticeManager.show_scene_message("装修模式：点空位换家具，点地面移动，滚轮旋转。", "出租屋", "hint")
		"enter_breakfast":
			SceneRouter.travel_to("breakfast_shop", "entrance")
		"enter_breakfast_kitchen":
			SceneRouter.travel_to("breakfast_kitchen", "entrance")
		"breakfast_kitchen_exit":
			SceneRouter.travel_to("breakfast_shop", "kitchen_exit")
		"breakfast_exit":
			SceneRouter.travel_to("street", "breakfast_exit")
		"breakfast_open":
			KitchenManager.start_shift_for("breakfast_shop")
		"kitchen_close":
			KitchenManager.end_shift()
		"breakfast_counter":
			KitchenManager.serve_ready_station()
		"breakfast_eat":
			InventoryManager.eat_at_table()
		"restaurant_exit":
			SceneRouter.travel_to("street", "restaurant_exit")
		"wholesale_exit":
			SceneRouter.travel_to("street", "wholesale_exit")
		"street_exit":
			match GameState.current_area:
				"commercial_district", "industrial_district", "suburb":
					SceneRouter.travel_to("street", "%s_exit" % GameState.current_area)
		"lottery_counter":
			bank_requested.emit("lottery")
		"restaurant_open":
			if CareerManager.application_line == "restaurant" and not CareerManager.is_employed():
				CareerManager.perform_trial_action("restaurant")
			else:
				KitchenManager.start_shift()
		"restaurant_counter":
			KitchenManager.serve_ready_station()
		"restaurant_upgrade":
			BusinessManager.upgrade_business()
		"restaurant_staff_board":
			CareerManager.register_interest("restaurant")
		"wardrobe_counter":
			wardrobe_requested.emit()
		"labor_market":
			StaffManager.handle_labor_market()
		"restaurant_eat":
			InventoryManager.eat_at_table()
		"wholesale_sell_counter":
			_sell_first_stock_goods()
		"work_station":
			if CareerManager.is_employed_in("factory"):
				GameState.work_factory_shift()
			elif CareerManager.application_line == "factory":
				CareerManager.perform_trial_action("factory")
			else:
				NoticeManager.show_message("先去工业区招聘板登记，领班才能安排试工。", "hint", "工厂领班")
		"clerk_shift":
			GameState.work_clerk_shift()
		"store_counter":
			shop_requested.emit("convenience_store")
		"recycle_search":
			TreasureManager.try_trigger("walk", 2.2)
		"market_upgrade":
			MarketEconomyManager.upgrade_stall()
		"expedition_board":
			expedition_map_requested.emit()
		"ruins_exit":
			ExpeditionManager.end_run("returned")
		"exercise_equipment":
			GameState.exercise_at_park()

func _ensure_kitchen_shift() -> bool:
	var location := "breakfast_shop" if GameState.current_area in ["breakfast_shop", "breakfast_kitchen"] else "restaurant"
	return KitchenManager.start_shift_for(location)

func _start_recipe_at_first_station(recipe_id: String) -> bool:
	var station_type := KitchenManager.get_first_station_type(recipe_id)
	for station in KitchenManager.get_stations_status():
		if str(station.get("type", "")) == station_type and str(station.get("state", "")) == "idle":
			return KitchenManager.place_recipe(recipe_id, int(station["index"]))
	NoticeManager.show_message("对应的第一道工位还占着，先把手上的半成品挪开。", "hint")
	return false

func _move_tray_to_first_station(tray_index: int) -> bool:
	var trays := KitchenManager.get_staging_status()
	if tray_index < 0 or tray_index >= trays.size():
		NoticeManager.show_message("这个托盘现在是空的。", "hint")
		return false
	var station_type := str(trays[tray_index].get("station_type", ""))
	for station in KitchenManager.get_stations_status():
		if str(station.get("type", "")) == station_type and str(station.get("state", "")) == "idle":
			return KitchenManager.load_staging(tray_index, int(station["index"]))
	NoticeManager.show_message("下一道工位正忙，先把托盘放在这里等一等。", "hint")
	return false

func _sell_first_stock_goods() -> void:
	var lines := BusinessManager.get_goods_lines()
	for line in lines:
		if int(line.get("stock", 0)) > 0:
			BusinessManager.sell_goods(str(line.get("id", "")), 1)
			return
	NoticeManager.show_message("仓库里还没有可以出手的货，先去批发区进一批吧。", "hint")

func _remove_interactable(interaction_id: String) -> void:
	if not is_instance_valid(_area_root):
		return
	for child in _area_root.get_children():
		if child is WorldInteractable and child.interaction_id == interaction_id:
			child.queue_free()


func _add_circle_obstacle(center: Vector2, radius: float) -> void:
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = 2
	obstacle.collision_mask = 1
	obstacle.position = center
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	obstacle.add_child(collision)
	_area_root.add_child(obstacle)

func _add_wall(rect: Rect2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.collision_mask = 1
	wall.position = rect.position + rect.size * 0.5
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	wall.add_child(collision)
	_area_root.add_child(wall)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color("#ffd36b")
		"rare":
			return Color("#8dd9e8")
		"uncommon":
			return Color("#a8d58e")
		_:
			return Color("#d8d2bb")

func _spawn_position(area_id: String, spawn_id: String) -> Vector2:
	var result := _spawn_position_raw(area_id, spawn_id)
	return result * CITY_LAYOUT_SCALE if area_id == "street" else result

func _spawn_position_raw(area_id: String, spawn_id: String) -> Vector2:
	match "%s:%s" % [area_id, spawn_id]:
		"home:living_door":
			return Vector2(1020, 360)
		"home_living:entrance", "home_living:bedroom_door":
			return Vector2(240, 620)
		"home_living:exit_door":
			return Vector2(1040, 620)
		"home:start", "home:default":
			return Vector2(420, 400)
		"street:entrance", "street:default", "street:start":
			return Vector2(1180, 740)
		"street:clothing_exit":
			return Vector2(1600, 1320)
		"street:clinic_exit":
			return Vector2(1960, 1260)
		"street:bus_station_exit":
			return Vector2(1780, 1260)
		"street:logistics_port_exit":
			return Vector2(1600, 520)
		"street:craft_workshop_exit":
			return Vector2(2050, 450)
		"street:university_exit":
			return Vector2(2100, 1160)
		"street:home_door":
			return Vector2(170, 1250)
		"street:market_exit":
			return Vector2(430, 600)
		"street:factory_exit":
			return Vector2(1680, 240)
		"street:recycle_exit":
			return Vector2(520, 1260)
		"street:park_exit":
			return Vector2(880, 1180)
		"street:store_exit":
			return Vector2(1600, 1150)
		"street:bank_exit":
			return Vector2(1740, 1150)
		"factory:entrance":
			return Vector2(640, 580)
		"store:entrance":
			return Vector2(640, 580)
		"recycle:entrance":
			return Vector2(640, 580)
		"market:entrance":
			return Vector2(640, 580)
		"park:entrance":
			return Vector2(640, 580)
		"ruins:default":
			return Vector2(640, 580)
		"bank:entrance":
			return Vector2(640, 530)
		"restaurant:entrance":
			return Vector2(640, 610)
		"wholesale:entrance":
			return Vector2(640, 540)
		"farm:entrance", "pet_store:entrance":
			return Vector2(640, 520)
		"furniture_store:entrance", "breakfast_shop:entrance":
			return Vector2(640, 650)
		"night_market:entrance":
			return Vector2(640, 520)
		"logistics_port:entrance", "craft_workshop:entrance":
			return Vector2(640, 620)
		"industrial_district:logistics_port_exit":
			return Vector2(640, 460)
		"industrial_district:craft_workshop_exit":
			return Vector2(1000, 680)
		"high_end_district:entrance":
			return Vector2(640, 620)
		"commercial_district:high_end_exit":
			return Vector2(200, 400)
		"street:breakfast_exit":
			return Vector2(160, 1260)
		"street:night_market_exit":
			return Vector2(1420, 1260)
		"street:farm_exit":
			return Vector2(2160, 1130)
		"street:pet_exit":
			return Vector2(2340, 1130)
		"street:furniture_exit":
			return Vector2(2020, 1150)
		"street:restaurant_exit":
			return Vector2(1880, 1150)
		"street:wholesale_exit":
			return Vector2(1880, 440)
		"street:commercial_district_exit":
			return Vector2(1740, 1320)
		"street:industrial_district_exit":
			return Vector2(2180, 540)
		"street:suburb_exit":
			return Vector2(2260, 1340)
		"street:nature_exit":
			return Vector2(950, 1020)
		"riverside:entrance":
			return Vector2(640, 540)
		"clinic:entrance":
			return Vector2(640, 540)
		"university:entrance":
			return Vector2(640, 540)
		"community_center:entrance":
			return Vector2(640, 540)
		"park:community_center_exit":
			return Vector2(1100, 520)
		"commercial_district:university_exit":
			return Vector2(200, 480)
		"commercial_district:clinic_exit":
			return Vector2(1020, 500)
		"commercial_district:bus_station_exit":
			return Vector2(1120, 430)
		"bus_station:entrance":
			return Vector2(640, 650)
		"bus_station:destination_exit":
			return Vector2(640, 600)
		"seaside_resort:entrance", "ancient_village:entrance", "mountain_spring:entrance":
			return Vector2(640, 650)
		"commercial_district:entrance":
			return Vector2(640, 520)
		"commercial_district:restaurant_exit":
			return Vector2(300, 400)
		"commercial_district:bank_exit":
			return Vector2(540, 400)
		"commercial_district:store_exit":
			return Vector2(780, 400)
		"commercial_district:furniture_exit":
			return Vector2(1020, 400)
		"commercial_district:clothing_exit":
			return Vector2(900, 470)
		"industrial_district:entrance":
			return Vector2(640, 580)
		"industrial_district:factory_exit":
			return Vector2(950, 430)
		"industrial_district:wholesale_exit":
			return Vector2(640, 620)
		"suburb:entrance":
			return Vector2(640, 520)
		"suburb:farm_exit":
			return Vector2(390, 470)
		"suburb:pet_exit":
			return Vector2(890, 470)
		"clothing_store:entrance":
			return Vector2(640, 540)
		"breakfast_kitchen:entrance":
			return Vector2(640, 540)
		"breakfast_shop:kitchen_exit":
			return Vector2(980, 590)
		_:
			return Vector2(420, 400)

func _arrival_text(area_id: String) -> String:
	match area_id:
		"home":
			return "出租屋不大，但总算有个能歇脚的地方。"
		"street":
			return "街上人来人往，今天也得自己安排。"
		"factory":
			return "机器声一阵接一阵，工位就在前面。"
		"store":
			return "便利店灯很亮，货架摆得满满当当。"
		"recycle":
			return "废品堆里不知道藏着什么，慢慢翻总会有发现。"
		"market":
			return "旧货市场晒着太阳，每件旧东西都有自己的来历。"
		"park":
			return "公园里树影晃来晃去，走一走心里会松快些。"
		"ruins":
			return "%s里静得能听见水滴，灯光只够照亮脚边。" % ExpeditionManager.get_site_name()
		"bank":
			return "银行大厅很安静，旁边就是亮着灯的彩票站。"
		"restaurant":
			return "夜市档口的炉火亮着，工位越多，今晚能接的订单也越多。"
		"wholesale":
			return "批发市场一箱箱食材堆到门口，价格每天都不一样。"
		"farm":
			return "城郊小农场风吹过菜叶，自己种的菜能直接送进餐馆。"
		"pet_store":
			return "宠物商店里猫狗兔子各有脾气，挑一只带回家吧。"
		"furniture_store":
			return "家居超市的样板间看着温馨，慢慢把出租屋变成家。"
		"breakfast_shop":
			return "楼下早餐店前厅只负责排队、点餐和取餐，后厨在里间。"
		"breakfast_kitchen":
			return "早餐后厨被分成备料、蒸、炸、煮、饮品和出餐几个工位，比前厅安静也宽敞。"
		"commercial_district":
			return "商业区霓虹亮得早，银行、餐馆、服装店和家居店各在一栋楼里。"
		"industrial_district":
			return "工业区的货车一辆接一辆，工厂、劳务市场和批发仓库都在这边。"
		"suburb":
			return "城郊路一下宽了，农场和宠物商店隔着一片空地。"
		"riverside":
			return "河边风比城里慢，水声把街道的噪声压了下去。"
		"clinic":
			return "社区诊所不大，消毒水味和低声交谈混在一起。"
		"university":
			return "夜校和大学共用一栋楼，走廊里贴着课程表和考试通知。"
		"community_center":
			return "社区活动中心里有琴声、画架和跑步机的动静，谁都能来待一会儿。"
		"bus_station":
			return "长途巴士站播着班次信息，几个背包客坐在塑料椅上等车。"
		"seaside_resort":
			return "海风带着咸味，远处有人在沙滩上放风筝。"
		"ancient_village":
			return "古镇街巷窄而深，木门后飘出糖水和茶香。"
		"mountain_spring":
			return "山雾贴着树林走，温泉热气从石头缝里升起来。"
		"clothing_store":
			return "服装店挂着各种耐穿的衣服，镜子前没人催你。"
		_:
			return ""