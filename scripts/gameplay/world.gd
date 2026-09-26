class_name WorldRoot
extends Node2D

signal shop_requested(shop_id: String)
signal inventory_requested(reason: String)
signal npc_requested(npc_id: String)
signal market_requested(market_id: String)
signal collection_log_requested
signal expedition_map_requested
signal bank_requested(service_id: String)

const BackdropScript := preload("res://scripts/gameplay/area_backdrop.gd")
const PlayerScript := preload("res://scripts/gameplay/player.gd")
const InteractableScript := preload("res://scripts/gameplay/interactable.gd")
const NpcScript := preload("res://scripts/gameplay/npc_actor.gd")
const WeatherScript := preload("res://scripts/gameplay/weather_effect.gd")

var player: PlayerActor
var _area_root: Node2D
var _player_input_locked := false
var _map_zoom := 1.0
var _last_business_level := -1

func _ready() -> void:
	add_to_group("world")
	SceneRouter.travel_completed.connect(_on_travel_requested)
	SaveManager.game_loaded.connect(_on_game_loaded)
	_build_area(GameState.current_area, GameState.spawn_id)

func _process(_delta: float) -> void:
	if GameState.current_area == "restaurant" and BusinessManager.business_level != _last_business_level:
		_build_area("restaurant", "entrance")

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
	_last_business_level = BusinessManager.business_level
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
			_add_wall(Rect2(145, 140, 180, 80))
			_add_wall(Rect2(130, 375, 150, 90))
			_add_wall(Rect2(450, 105, 220, 90))
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
			for x in range(100, 1210, 250):
				if x == 600:
					continue
				_add_wall(Rect2(x, 380, 150, 90))
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
			_add_wall(Rect2(60, 120, 250, 110))
			_add_wall(Rect2(60, 420, 250, 110))
		"wholesale":
			_add_wall(Rect2(60, 40, 1160, 46))
			_add_wall(Rect2(60, 632, 1160, 52))

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
			_add_interactable("enter_bank", "进银行和彩票站", Vector2(1195, 355), Vector2(100, 130), Color("#79a9c8"), Vector2(130, 190))
			_add_interactable("enter_restaurant", "去夜市餐馆", Vector2(920, 360), Vector2(140, 100), Color("#db7658"), Vector2(210, 170))
			_add_interactable("enter_wholesale", "去批发市场", Vector2(360, 360), Vector2(140, 100), Color("#8fb09b"), Vector2(210, 170))
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
			_add_interactable("expedition_board", "打听旧楼入口", Vector2(250, 300), Vector2(170, 95), Color("#7f9fb0"), Vector2(260, 180))
			_add_interactable("market_exit", "回到街上", Vector2(640, 668), Vector2(120, 80), Color("#91a9a2"), Vector2(160, 130))
		"park":
			_add_interactable("exercise_equipment", "活动一下身体", Vector2(240, 520), Vector2(260, 100), Color("#72a97c"), Vector2(430, 250))
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


func _build_restaurant_interactables() -> void:
	_add_interactable("restaurant_open", "开档营业", Vector2(640, 590), Vector2(180, 74), Color("#e07a52"), Vector2(260, 140))
	var station_count := 2 + mini(2, BusinessManager.business_level)
	for index in range(station_count):
		var station_x := 330.0 + float(index) * 200.0
		_add_interactable("restaurant_station|%d" % index, "点一下照看这个灶台", Vector2(station_x, 338), Vector2(120, 84), Color("#d9704f"), Vector2(190, 160))
	_add_interactable("restaurant_counter", "把做好的菜端出去", Vector2(640, 498), Vector2(260, 80), Color("#e9b65a"), Vector2(420, 170))
	_add_interactable("restaurant_eat", "坐下吃一顿", Vector2(220, 600), Vector2(170, 76), Color("#8fbf9a"), Vector2(280, 150))
	_add_interactable("restaurant_upgrade", "看看扩店告示", Vector2(1050, 600), Vector2(170, 82), Color("#a992db"), Vector2(280, 160))
	_add_interactable("restaurant_exit", "回到街上", Vector2(1080, 600), Vector2(140, 80), Color("#8ba7af"), Vector2(200, 140))

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
	) -> WorldInteractable:
	var interactable: WorldInteractable = InteractableScript.new()
	interactable.configure(id, prompt, position_on_map, visual_size, color, hit_size)
	interactable.interaction_requested.connect(_on_interaction_requested)
	_area_root.add_child(interactable)
	return interactable

func _on_interaction_requested(interaction_id: String) -> void:
	var parts := interaction_id.split("|", false)
	if parts.size() >= 2 and parts[0] == "npc":
		npc_requested.emit(parts[1])
		return
	if parts.size() == 2 and parts[0] == "restaurant_station":
		var station_index := int(parts[1])
		if not KitchenManager.active:
			KitchenManager.start_shift()
		KitchenManager.handle_station_action(station_index)
		return
	if parts.size() == 2 and parts[0] == "wholesale_buy":
		BusinessManager.buy_goods(parts[1], 1)
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
		"restaurant_exit":
			SceneRouter.travel_to("street", "restaurant_exit")
		"wholesale_exit":
			SceneRouter.travel_to("street", "wholesale_exit")
		"lottery_counter":
			bank_requested.emit("lottery")
		"restaurant_open":
			KitchenManager.start_shift()
		"restaurant_counter":
			KitchenManager.serve_ready_station()
		"restaurant_upgrade":
			BusinessManager.upgrade_business()
		"restaurant_eat":
			InventoryManager.eat_at_table()
		"wholesale_sell_counter":
			_sell_first_stock_goods()
		"work_station":
			GameState.work_factory_shift()
		"clerk_shift":
			GameState.work_clerk_shift()
		"store_counter":
			shop_requested.emit("convenience_store")
		"recycle_search":
			TreasureManager.try_trigger("walk", 2.2)
		"market_stall":
			market_requested.emit("old_market")
		"expedition_board":
			expedition_map_requested.emit()
		"ruins_exit":
			ExpeditionManager.end_run("returned")
		"exercise_equipment":
			GameState.exercise_at_park()

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
		"street:bank_exit":
			return Vector2(1130, 355)
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
			return Vector2(640, 580)
		"restaurant:entrance":
			return Vector2(640, 610)
		"wholesale:entrance":
			return Vector2(640, 650)
		"street:restaurant_exit":
			return Vector2(870, 360)
		"street:wholesale_exit":
			return Vector2(430, 360)
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
		_:
			return ""