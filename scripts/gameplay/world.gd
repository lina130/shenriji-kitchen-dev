class_name WorldRoot
extends Node2D

signal shop_requested(shop_id: String)
signal inventory_requested(reason: String)
signal npc_requested(npc_id: String)
signal market_requested(market_id: String)
signal collection_log_requested

const BackdropScript := preload("res://scripts/gameplay/area_backdrop.gd")
const PlayerScript := preload("res://scripts/gameplay/player.gd")
const InteractableScript := preload("res://scripts/gameplay/interactable.gd")
const NpcScript := preload("res://scripts/gameplay/npc_actor.gd")
const WeatherScript := preload("res://scripts/gameplay/weather_effect.gd")

var player: PlayerActor
var _area_root: Node2D
var _player_input_locked := false
var _map_zoom := 1.0

func _ready() -> void:
	SceneRouter.travel_completed.connect(_on_travel_requested)
	SaveManager.game_loaded.connect(_on_game_loaded)
	_build_area(GameState.current_area, GameState.spawn_id)

func _unhandled_input(event: InputEvent) -> void:
	if _player_input_locked or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_map_zoom(_map_zoom + 0.08)
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_map_zoom(_map_zoom - 0.08)
		get_viewport().set_input_as_handled()

func _on_travel_requested(area_id: String, spawn_id: String) -> void:
	_build_area(area_id, spawn_id)

func _on_game_loaded() -> void:
	_build_area(GameState.current_area, GameState.spawn_id)

func set_player_input_locked(value: bool) -> void:
	_player_input_locked = value
	if is_instance_valid(player):
		player.set_input_locked(value)

func _build_area(area_id: String, spawn_id: String) -> void:
	if is_instance_valid(_area_root):
		remove_child(_area_root)
		_area_root.queue_free()
	_area_root = Node2D.new()
	_area_root.name = "Area_%s" % area_id
	add_child(_area_root)
	var backdrop: AreaBackdrop = BackdropScript.new()
	backdrop.configure(area_id)
	_area_root.add_child(backdrop)
	_build_collisions(area_id)
	_build_interactables(area_id)
	_build_npcs(area_id)
	_build_collection_nodes(area_id)
	player = PlayerScript.new()
	player.position = _spawn_position(area_id, spawn_id)
	player.set_input_locked(_player_input_locked)
	_area_root.add_child(player)
	var weather: WeatherEffect = WeatherScript.new()
	_area_root.add_child(weather)
	_apply_map_zoom()
	NoticeManager.show_message(_arrival_text(area_id), "hint")

func _set_map_zoom(value: float) -> void:
	_map_zoom = clampf(value, 0.86, 1.36)
	_apply_map_zoom()

func _apply_map_zoom() -> void:
	if not is_instance_valid(_area_root):
		return
	var viewport_center := Vector2(640, 360)
	_area_root.scale = Vector2.ONE * _map_zoom
	_area_root.position = viewport_center * (1.0 - _map_zoom)

func _build_collisions(area_id: String) -> void:
	_add_wall(Rect2(0, 0, 1280, 36))
	_add_wall(Rect2(0, 684, 1280, 36))
	_add_wall(Rect2(0, 0, 36, 720))
	_add_wall(Rect2(1244, 0, 36, 720))
	match area_id:
		"home":
			_add_wall(Rect2(130, 105, 220, 150))
			_add_wall(Rect2(110, 360, 190, 120))
			_add_wall(Rect2(420, 90, 300, 110))
		"street":
			_add_wall(Rect2(54, 48, 420, 125))
			_add_wall(Rect2(600, 48, 580, 125))
			_add_wall(Rect2(460, 520, 160, 90))
			_add_wall(Rect2(840, 520, 250, 90))
		"factory":
			_add_wall(Rect2(70, 90, 440, 130))
			_add_wall(Rect2(770, 90, 440, 130))
			_add_wall(Rect2(520, 90, 240, 170))
		"store":
			_add_wall(Rect2(350, 90, 580, 120))
			_add_wall(Rect2(50, 375, 210, 250))
			_add_wall(Rect2(1020, 375, 210, 250))
		"recycle":
			_add_wall(Rect2(70, 90, 310, 150))
			_add_wall(Rect2(900, 90, 310, 150))
			_add_wall(Rect2(70, 400, 300, 190))
			_add_wall(Rect2(910, 400, 300, 190))
		"market":
			_add_wall(Rect2(60, 60, 1160, 110))
			_add_wall(Rect2(70, 370, 300, 120))
			_add_wall(Rect2(910, 370, 300, 120))
		"park":
			_add_wall(Rect2(330, 340, 580, 130))
			_add_wall(Rect2(40, 40, 120, 120))
			_add_wall(Rect2(1120, 40, 120, 120))
func _build_interactables(area_id: String) -> void:
	match area_id:
		"home":
			_add_interactable("bed", "上床睡觉", Vector2(235, 180), Vector2(180, 80), Color("#cb7180"), Vector2(260, 190))
			_add_interactable("fridge", "从冰箱找吃的", Vector2(205, 420), Vector2(150, 90), Color("#72b5ad"), Vector2(210, 160))
			_add_interactable("study_desk", "在书桌前学习", Vector2(560, 150), Vector2(220, 90), Color("#8ba8c4"), Vector2(300, 180))
			_add_interactable("leave_home", "出门去街上", Vector2(1200, 360), Vector2(90, 120), Color("#eebe62"), Vector2(120, 170))
		"street":
			_add_interactable("home_door", "回到出租屋", Vector2(82, 360), Vector2(90, 120), Color("#e8b45e"), Vector2(130, 170))
			_add_interactable("enter_market", "去旧货市场", Vector2(260, 142), Vector2(150, 100), Color("#d97865"), Vector2(220, 170))
			_add_interactable("enter_factory", "进工厂看看", Vector2(1040, 142), Vector2(150, 100), Color("#8fc6bf"), Vector2(220, 170))
			_add_interactable("enter_recycle", "去废品回收站", Vector2(245, 632), Vector2(150, 95), Color("#8e9d8d"), Vector2(220, 160))
			_add_interactable("enter_park", "去社区公园", Vector2(760, 632), Vector2(150, 95), Color("#7eb08a"), Vector2(220, 160))
			_add_interactable("enter_store", "进便利店", Vector2(1110, 560), Vector2(130, 100), Color("#f0c968"), Vector2(220, 160))
		"factory":
			_add_interactable("work_station", "到工位干活", Vector2(640, 190), Vector2(180, 100), Color("#f1bd5a"), Vector2(260, 230))
			_add_interactable("factory_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"store":
			_add_interactable("store_counter", "看看柜台商品", Vector2(640, 185), Vector2(300, 90), Color("#efc761"), Vector2(420, 280))
			_add_interactable("clerk_shift", "问小林要不要兼职", Vector2(900, 260), Vector2(180, 90), Color("#8fc6bf"), Vector2(260, 180))
			_add_interactable("store_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"recycle":
			_add_interactable("recycle_search", "翻找废品堆", Vector2(640, 300), Vector2(230, 110), Color("#b7b38a"), Vector2(410, 260))
			_add_interactable("recycle_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"market":
			_add_interactable("market_stall", "看看能换什么", Vector2(640, 300), Vector2(260, 100), Color("#dc8a68"), Vector2(430, 250))
			_add_interactable("market_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"park":
			_add_interactable("exercise_equipment", "活动一下身体", Vector2(640, 305), Vector2(260, 100), Color("#72a97c"), Vector2(430, 250))
			_add_interactable("park_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))

func _build_collection_nodes(area_id: String) -> void:
	for spawn in CollectionManager.get_area_spawns(area_id):
		var rarity := str(spawn.get("rarity", "common"))
		var marker_color := _rarity_color(rarity)
		var point: Vector2 = spawn.get("position", Vector2.ZERO)
		_add_interactable(
			"collect|%s|%s" % [area_id, str(spawn.get("spawn_id", ""))],
			"看看微光里的东西",
			point,
			Vector2(44, 44),
			marker_color,
			Vector2(92, 92)
		)

func _build_npcs(area_id: String) -> void:
	var definitions := {
		"home": ["mei", Vector2(900, 525), Vector2(1090, 525)],
		"factory": ["wang", Vector2(300, 370), Vector2(510, 370)],
		"store": ["lin", Vector2(850, 330), Vector2(1030, 330)],
		"market": ["chen", Vector2(330, 300), Vector2(530, 300)],
	}
	if not definitions.has(area_id):
		return
	var definition: Array = definitions[area_id]
	var npc_id := str(definition[0])
	var row := ConfigDB.get_row("npcs", npc_id)
	var npc: NPCActor = NpcScript.new()
	var color := Color.from_string(str(row.get("color", "#ffffff")), Color.WHITE)
	npc.configure(npc_id, str(row.get("name", npc_id)), definition[1], definition[2], color)
	npc.interaction_requested.connect(_on_interaction_requested)
	_area_root.add_child(npc)
func _add_interactable(
		id: String,
		prompt: String,
		position_on_map: Vector2,
		visual_size: Vector2,
		color: Color,
		hit_size: Vector2 = Vector2.ZERO
	) -> void:
	var interactable: WorldInteractable = InteractableScript.new()
	interactable.configure(id, prompt, position_on_map, visual_size, color, hit_size)
	interactable.interaction_requested.connect(_on_interaction_requested)
	_area_root.add_child(interactable)

func _on_interaction_requested(interaction_id: String) -> void:
	var parts := interaction_id.split("|", false)
	if parts.size() >= 2 and parts[0] == "npc":
		npc_requested.emit(parts[1])
		return
	if parts.size() >= 3 and parts[0] == "collect":
		if CollectionManager.collect_spawn(parts[1], parts[2]):
			_remove_interactable(interaction_id)
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
		"home_door":
			SceneRouter.travel_to("home", "door")
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
			SceneRouter.travel_to("park", "entrance")
		"park_exit":
			SceneRouter.travel_to("street", "park_exit")
		"enter_store":
			SceneRouter.travel_to("store", "entrance")
		"store_exit":
			SceneRouter.travel_to("street", "store_exit")
		"work_station":
			GameState.work_factory_shift()
		"clerk_shift":
			GameState.work_clerk_shift()
		"store_counter":
			shop_requested.emit("convenience_store")
		"recycle_search":
			_search_recycling()
		"market_stall":
			market_requested.emit("old_market")
		"exercise_equipment":
			GameState.exercise_at_park()

func _search_recycling() -> void:
	var spawns := CollectionManager.get_area_spawns("recycle")
	if spawns.is_empty():
		NoticeManager.show_message("今天能翻出来的东西都被整理过了。", "hint")
		return
	var spawn: Dictionary = spawns[0]
	var spawn_id := str(spawn.get("spawn_id", ""))
	CollectionManager.collect_spawn("recycle", spawn_id)
	_remove_interactable("collect|recycle|%s" % spawn_id)

func _remove_interactable(interaction_id: String) -> void:
	if not is_instance_valid(_area_root):
		return
	for child in _area_root.get_children():
		if child is WorldInteractable and child.interaction_id == interaction_id:
			child.queue_free()

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
	match "%s:%s" % [area_id, spawn_id]:
		"home:door":
			return Vector2(1110, 360)
		"home:start", "home:default":
			return Vector2(420, 400)
		"street:home_door":
			return Vector2(170, 360)
		"street:market_exit":
			return Vector2(350, 205)
		"street:factory_exit":
			return Vector2(930, 240)
		"street:recycle_exit":
			return Vector2(350, 575)
		"street:park_exit":
			return Vector2(760, 570)
		"street:store_exit":
			return Vector2(990, 570)
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
		_:
			return ""