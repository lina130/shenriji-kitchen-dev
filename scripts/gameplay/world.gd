class_name WorldRoot
extends Node2D

signal shop_requested(shop_id: String)
signal inventory_requested(reason: String)

const BackdropScript := preload("res://scripts/gameplay/area_backdrop.gd")
const PlayerScript := preload("res://scripts/gameplay/player.gd")
const InteractableScript := preload("res://scripts/gameplay/interactable.gd")

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
	player = PlayerScript.new()
	player.position = _spawn_position(area_id, spawn_id)
	player.set_input_locked(_player_input_locked)
	_area_root.add_child(player)
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
			_add_wall(Rect2(54, 48, 520, 125))
			_add_wall(Rect2(700, 48, 480, 125))
			_add_wall(Rect2(460, 520, 280, 90))
		"factory":
			_add_wall(Rect2(70, 90, 440, 130))
			_add_wall(Rect2(770, 90, 440, 130))
			_add_wall(Rect2(520, 90, 240, 170))
		"store":
			_add_wall(Rect2(350, 90, 580, 120))
			_add_wall(Rect2(50, 375, 210, 250))
			_add_wall(Rect2(1020, 375, 210, 250))

func _build_interactables(area_id: String) -> void:
	match area_id:
		"home":
			_add_interactable("bed", "上床睡觉", Vector2(235, 180), Vector2(180, 80), Color("#cb7180"), Vector2(260, 190))
			_add_interactable("fridge", "从冰箱找吃的", Vector2(205, 420), Vector2(150, 90), Color("#72b5ad"), Vector2(210, 160))
			_add_interactable("leave_home", "出门去街上", Vector2(1200, 360), Vector2(90, 120), Color("#eebe62"), Vector2(120, 170))
		"street":
			_add_interactable("home_door", "回到出租屋", Vector2(82, 360), Vector2(90, 120), Color("#e8b45e"), Vector2(130, 170))
			_add_interactable("enter_factory", "进工厂看看", Vector2(1040, 142), Vector2(150, 100), Color("#8fc6bf"), Vector2(220, 170))
			_add_interactable("enter_store", "进便利店", Vector2(1110, 560), Vector2(130, 100), Color("#f0c968"), Vector2(220, 160))
		"factory":
			_add_interactable("work_station", "到工位干活", Vector2(640, 190), Vector2(180, 100), Color("#f1bd5a"), Vector2(260, 230))
			_add_interactable("factory_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"store":
			_add_interactable("store_counter", "看看柜台商品", Vector2(640, 185), Vector2(300, 90), Color("#efc761"), Vector2(420, 280))
			_add_interactable("store_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))

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
	match interaction_id:
		"bed":
			GameState.sleep_to_next_day()
		"fridge":
			inventory_requested.emit("冰箱里有什么，看看包里吧。")
		"leave_home":
			SceneRouter.travel_to("street", "home_door")
		"home_door":
			SceneRouter.travel_to("home", "door")
		"enter_factory":
			SceneRouter.travel_to("factory", "entrance")
		"factory_exit":
			SceneRouter.travel_to("street", "factory_exit")
		"enter_store":
			SceneRouter.travel_to("store", "entrance")
		"store_exit":
			SceneRouter.travel_to("street", "store_exit")
		"work_station":
			GameState.work_factory_shift()
		"store_counter":
			shop_requested.emit("convenience_store")

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

func _spawn_position(area_id: String, spawn_id: String) -> Vector2:
	match "%s:%s" % [area_id, spawn_id]:
		"home:door":
			return Vector2(1110, 360)
		"home:start", "home:default":
			return Vector2(420, 400)
		"street:home_door":
			return Vector2(170, 360)
		"street:factory_exit":
			return Vector2(930, 240)
		"street:store_exit":
			return Vector2(990, 570)
		"factory:entrance":
			return Vector2(640, 580)
		"store:entrance":
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
		_:
			return ""