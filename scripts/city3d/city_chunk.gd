class_name CityChunk3D
extends Node3D

const CHUNK_LENGTH := 24.0

var chunk_index := 0
var district_name := ""

func configure(index: int) -> void:
	chunk_index = index
	position.x = (float(index) + 0.5) * CHUNK_LENGTH
	district_name = "南头旧巷" if index == -1 else ("创意商业街" if index == 0 else "香港电车街市")

func _ready() -> void:
	name = "CityChunk_%d" % chunk_index
	_build_ground()
	if chunk_index == -1:
		_build_village()
	elif chunk_index == 0:
		_build_creative_street()
	else:
		_build_hongkong_market()
	_build_shared_details()

func _build_ground() -> void:
	_add_box("Terrain", Vector3(0, -0.16, 0), Vector3(24, 0.3, 20), Color("#a6bba8"), true)
	_add_box("Road", Vector3(0, 0.015, 0), Vector3(24, 0.045, 5.0), Color("#657f7f"))
	_add_box("BackWalk", Vector3(0, 0.045, -3.72), Vector3(24, 0.11, 2.45), Color("#ddcfb9"))
	_add_box("FrontWalk", Vector3(0, 0.045, 3.72), Vector3(24, 0.11, 2.45), Color("#ddcfb9"))
	_add_box("BackCurb", Vector3(0, 0.12, -2.53), Vector3(24, 0.15, 0.16), Color("#d4b79d"))
	_add_box("FrontCurb", Vector3(0, 0.12, 2.53), Vector3(24, 0.15, 0.16), Color("#d4b79d"))
	for i in range(6):
		_add_box("RoadDash", Vector3(-10.0 + i * 4.0, 0.05, 0), Vector3(1.6, 0.014, 0.075), Color("#f4dfb1"))

func _build_village() -> void:
	_add_tea_house()
	_add_restaurant_stations()
	_add_delivery_point("delivery_nantou", "南头收件台", Vector3(-6.0, 0.12, 4.45))
	_add_inspiration("creative_inspiration_nantou", "旧巷纹样", Vector3(-10.6, 0.12, 6.1))
	_add_shop("Breakfast", Vector3(2.5, 0, -7.1), Vector3(8.0, 5.2, 4.7), Color("#f0d6b1"), Color("#e6a36d"), "街角早餐", "breakfast")
	_add_shop("Home", Vector3(9.2, 0, -7.1), Vector3(4.5, 5.9, 4.7), Color("#cfb59e"), Color("#b1b6a5"), "我的小屋", "rest_home")
	_add_box("OldTownStoneGateLeft", Vector3(-11.65, 1.8, -4.65), Vector3(0.55, 3.5, 0.55), Color("#b4a18a"))
	_add_box("OldTownStoneGateTop", Vector3(-10.85, 3.52, -4.65), Vector3(2.1, 0.42, 0.72), Color("#a99880"))
	_add_npc("陈伯", "neighbor", Vector3(-4.4, 0.14, 4.05), Color("#7c9e92"))
	_add_planter(Vector3(-1.3, 0.17, 4.2), Color("#85a585"))
	_add_bench(Vector3(-7.7, 0.2, 4.3))
	_add_heritage_tiles()

func _build_creative_street() -> void:
	_add_shop("CourierHub", Vector3(-5.5, 0, -7.0), Vector3(8.2, 5.6, 4.8), Color("#d6d8b3"), Color("#7daeba"), "跑单驿站", "courier_hub")
	_add_shop("CreativeStudio", Vector3(5.0, 0, -7.15), Vector3(9.0, 6.6, 4.7), Color("#e4b7a0"), Color("#b786a2"), "湾岸工作室", "creative_studio")
	_add_box("CourierRushBoard", Vector3(-8.8, 1.15, -3.65), Vector3(0.85, 1.8, 0.32), Color("#628b94"))
	_add_interaction("courier_rush", "急件接单牌", Vector3(-8.8, 1.15, -3.45), Vector3(1.1, 2.1, 0.8))
	_add_box("CreativeRushBoard", Vector3(8.4, 1.15, -3.65), Vector3(0.85, 1.8, 0.32), Color("#aa7895"))
	_add_interaction("creative_rush", "加急委托牌", Vector3(8.4, 1.15, -3.45), Vector3(1.1, 2.1, 0.8))
	_add_delivery_point("courier_pickup", "驿站取件架", Vector3(-6.7, 0.12, 5.65))
	_add_delivery_point("delivery_studio", "工作室收件台", Vector3(1.2, 0.12, 5.55))
	_add_inspiration("creative_inspiration_shenzhen", "街头色彩", Vector3(-0.1, 0.12, 7.15))
	_add_box("CreativeWorkbench", Vector3(7.0, 0.62, 5.72), Vector3(1.9, 0.92, 1.0), Color("#ad8a78"))
	_add_box("CreativeSketchSheet", Vector3(7.0, 1.11, 5.72), Vector3(1.25, 0.025, 0.68), Color("#f4e7d0"))
	_add_interaction("creative_workbench", "创作台", Vector3(7.0, 1.0, 5.72), Vector3(2.0, 1.9, 1.5))
	_add_npc("委托人", "creative_client", Vector3(9.3, 0.14, 6.45), Color("#8a9eb7"))
	_add_npc("小林", "artist", Vector3(5.0, 0.15, 4.0), Color("#bd90a5"))
	_add_planter(Vector3(-0.1, 0.17, 4.1), Color("#a7b987"))
	_add_bench(Vector3(8.9, 0.2, 4.3))
	_add_collector_stall()
	_add_box("MetroWayfindingPost", Vector3(-10.1, 1.47, 4.2), Vector3(0.16, 2.7, 0.16), Color("#5d7775"))
	_add_box("MetroWayfindingPlate", Vector3(-10.1, 2.67, 4.2), Vector3(1.45, 0.52, 0.18), Color("#477b86"))
	for i in range(4):
		_add_box("Crosswalk", Vector3(-11.3 + i * 0.65, 0.052, 0), Vector3(0.35, 0.018, 4.35), Color("#f7e8cd"))

func _build_hongkong_market() -> void:
	_add_shop("HongKongMarket", Vector3(-6.0, 0, -7.1), Vector3(9.4, 8.4, 4.75), Color("#d8c1a6"), Color("#cc8069"), "春秧街市", "market_greeter")
	_add_shop("HongKongBakery", Vector3(5.2, 0, -7.1), Vector3(8.9, 7.3, 4.75), Color("#e2c7a0"), Color("#83a6a0"), "叮叮茶记", "market_bakery")
	for rail_z in [-0.86, 0.86]:
		_add_box("TramRail", Vector3(0, 0.065, rail_z), Vector3(24, 0.045, 0.085), Color("#eadbc2"))
		for i in range(10):
			_add_box("RailTie", Vector3(-11.0 + i * 2.2, 0.052, rail_z), Vector3(0.13, 0.03, 0.32), Color("#b19d86"))
	_add_tram(Vector3(6.15, 0.13, 0))
	_add_market_stall_hero(Vector3(-6.8, 0.10, 5.55))
	_add_delivery_point("delivery_hongkong", "街市收件台", Vector3(4.25, 0.12, 5.65))
	_add_inspiration("creative_inspiration_hongkong", "电车街景", Vector3(9.3, 0.12, 7.05))
	_add_npc("莲姐", "market_neighbor", Vector3(1.6, 0.14, 4.05), Color("#a980a6"))
	_add_vertical_sign("街市", Vector3(-10.15, 5.3, -4.16), Color("#b66562"))
	_add_vertical_sign("茶记", Vector3(9.6, 5.05, -4.16), Color("#5c958d"))

func _build_shared_details() -> void:
	for x in [-10.7, 10.7]:
		_add_lamp(Vector3(x, 0.16, 4.65))
	for x in [-9.9, 9.9]:
		_add_tree(Vector3(x, 0.16, 7.1))
	for i in range(7):
		var x := -10.5 + i * 3.35
		_add_box("PavingJoint", Vector3(x, 0.109, 3.72), Vector3(0.035, 0.008, 2.45), Color("#d8bea3"))
	for x in [-8.8, -0.8, 7.2]:
		_add_box("DrainCover", Vector3(x, 0.107, 2.74), Vector3(0.55, 0.015, 0.23), Color("#738c87"))
		for slot in range(4):
			_add_box("DrainSlot", Vector3(x - 0.19 + slot * 0.12, 0.119, 2.74), Vector3(0.025, 0.003, 0.16), Color("#4a6867"))

func _add_shop(node_name: String, base: Vector3, size: Vector3, wall_color: Color, awning_color: Color, display_name: String, interaction_id: String) -> void:
	var center := base + Vector3(0, size.y * 0.5 + 0.12, 0)
	_add_box(node_name, center, size, wall_color, true)
	_add_box(node_name + "Roof", center + Vector3(0, size.y * 0.5 + 0.20, 0), Vector3(size.x + 0.6, 0.35, size.z + 0.35), wall_color.darkened(0.19))
	_add_box(node_name + "RoofCap", center + Vector3(0, size.y * 0.5 + 0.42, 0), Vector3(size.x + 0.85, 0.12, size.z + 0.6), Color("#a77869"))
	_add_box(node_name + "FacadeBand", Vector3(base.x, size.y - 2.1, -4.58), Vector3(size.x * 0.96, 0.13, 0.16), wall_color.darkened(0.17))
	_add_box(node_name + "Awning", Vector3(base.x, 2.88, -4.25), Vector3(size.x * 0.85, 0.18, 1.34), awning_color)
	_add_box(node_name + "AwningTrim", Vector3(base.x, 2.70, -3.60), Vector3(size.x * 0.85, 0.22, 0.12), awning_color.darkened(0.23))
	for stripe_index in range(5):
		var stripe_x := base.x - size.x * 0.34 + stripe_index * size.x * 0.17
		_add_box(node_name + "AwningStripe", Vector3(stripe_x, 2.70, -3.515), Vector3(size.x * 0.085, 0.22, 0.02), Color("#f7ebd2"))
	_add_box(node_name + "Door", Vector3(base.x, 1.18, -4.52), Vector3(1.48, 2.16, 0.09), Color("#526e70"))
	_add_box(node_name + "DoorFrameTop", Vector3(base.x, 2.27, -4.46), Vector3(1.68, 0.12, 0.15), Color("#f4e4c9"))
	_add_box(node_name + "Glass", Vector3(base.x + size.x * 0.28, 1.50, -4.51), Vector3(size.x * 0.25, 1.48, 0.09), Color("#9abfbe"))
	for window_x in [base.x - size.x * 0.26, base.x + size.x * 0.26]:
		_add_box(node_name + "UpperWindow", Vector3(window_x, size.y - 1.27, base.z + size.z * 0.5 + 0.065), Vector3(1.25, 1.05, 0.11), Color("#84aeb4"))
		_add_box(node_name + "UpperWindowTop", Vector3(window_x, size.y - 0.71, base.z + size.z * 0.5 + 0.105), Vector3(1.42, 0.11, 0.16), Color("#f7e9d3"))
		_add_box(node_name + "UpperWindowSill", Vector3(window_x, size.y - 1.83, base.z + size.z * 0.5 + 0.12), Vector3(1.55, 0.13, 0.25), wall_color.darkened(0.13))
		_add_box(node_name + "WindowDivider", Vector3(window_x, size.y - 1.27, -4.50), Vector3(0.08, 1.04, 0.16), Color("#f6e7d3"))
	_add_box(node_name + "AirConditioner", Vector3(base.x + size.x * 0.40, size.y - 2.08, -4.42), Vector3(0.82, 0.55, 0.46), Color("#ddd9ca"))
	for vent in range(3):
		_add_box(node_name + "ACVent", Vector3(base.x + size.x * 0.40, size.y - 2.25 + vent * 0.12, -4.17), Vector3(0.57, 0.025, 0.018), Color("#8d9b93"))
	_add_box(node_name + "BalconyRail", Vector3(base.x - size.x * 0.26, size.y - 1.94, -4.22), Vector3(1.7, 0.10, 0.10), Color("#647b75"))
	for rail_x in [-0.65, -0.22, 0.22, 0.65]:
		_add_box(node_name + "BalconyPost", Vector3(base.x - size.x * 0.26 + rail_x, size.y - 1.72, -4.22), Vector3(0.06, 0.45, 0.08), Color("#647b75"))
	_add_box(node_name + "Step", Vector3(base.x, 0.16, -4.06), Vector3(2.2, 0.22, 0.75), Color("#d8c4a7"))
	_add_planter(Vector3(base.x - size.x * 0.25, 0.14, -3.90), awning_color.lightened(0.13))
	_add_sign(display_name, Vector3(base.x, 3.58, -4.31), awning_color.darkened(0.42))
	_add_interaction(interaction_id, display_name, Vector3(base.x, 1.2, -3.85), Vector3(2.35, 2.35, 1.35))

func _add_tea_house() -> void:
	var scene: PackedScene = load("res://assets/art/models/nantou_tea_house.glb")
	if scene == null:
		push_error("Nantou tea house model was not imported")
		return
	var shop := scene.instantiate()
	shop.name = "Nantou_TeaHouse_Hero_Asset"
	shop.position = Vector3(-7.2, 0.12, -7.05)
	add_child(shop)
	var body := StaticBody3D.new()
	body.name = "Nantou_TeaHouse_Collision"
	body.position = Vector3(-7.2, 3.05, -7.05)
	body.collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.35, 5.9, 4.75)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_add_interaction("tea_house", "阿婆茶铺", Vector3(-7.2, 1.22, -3.65), Vector3(2.3, 2.35, 1.5))
	_add_box("RushShiftBoard", Vector3(-10.45, 1.17, -3.75), Vector3(0.95, 1.9, 0.35), Color("#bd826b"))
	_add_box("RushShiftBell", Vector3(-10.45, 2.18, -3.57), Vector3(0.46, 0.25, 0.28), Color("#e8bf73"))
	_add_interaction("restaurant_rush", "忙碌班铃", Vector3(-10.45, 1.15, -3.53), Vector3(1.25, 2.15, 0.85))

func _add_restaurant_stations() -> void:
	var stations := [
		["restaurant_steam", "蒸笼台", -8.9, Color("#c18c70")],
		["restaurant_tea", "茶炉台", -6.5, Color("#789c91")],
		["restaurant_cake", "点心台", -4.1, Color("#c9979a")]
	]
	for station in stations:
		var x: float = station[2]
		var tint: Color = station[3]
		_add_box("FoodCounter", Vector3(x, 0.62, 5.65), Vector3(1.55, 0.89, 0.9), tint)
		_add_box("FoodCounterTop", Vector3(x, 1.10, 5.65), Vector3(1.72, 0.10, 1.04), tint.lightened(0.28))
		_add_cylinder("FoodVessel", Vector3(x, 1.25, 5.65), 0.31, 0.22, Color("#e9d4b3"))
		_add_interaction(station[0], station[1], Vector3(x, 1.0, 5.55), Vector3(1.65, 1.9, 1.5))
	_add_npc("等餐街坊", "restaurant_customer", Vector3(-1.0, 0.14, 6.42), Color("#d49970"))

func _add_heritage_tiles() -> void:
	for row in range(3):
		for col in range(13):
			var tint := Color("#e7d5b9") if (row + col) % 3 == 0 else Color("#d9c4a7")
			_add_box("OldTownStone", Vector3(-11.4 + col * 0.85, 0.111, 3.05 + row * 0.72), Vector3(0.76, 0.012, 0.63), tint)

func _add_delivery_point(interaction_id: String, display_name: String, at: Vector3) -> void:
	_add_box("ParcelShelf", at + Vector3(0, 0.45, 0), Vector3(1.16, 0.75, 0.76), Color("#899b91"))
	_add_box("Parcel", at + Vector3(0, 0.89, 0), Vector3(0.58, 0.27, 0.44), Color("#c99b72"))
	_add_box("ParcelTape", at + Vector3(0, 1.04, 0), Vector3(0.11, 0.02, 0.45), Color("#eddbb6"))
	_add_interaction(interaction_id, display_name, at + Vector3(0, 0.8, 0), Vector3(1.4, 1.55, 1.15))

func _add_inspiration(interaction_id: String, display_name: String, at: Vector3) -> void:
	_add_box("SketchStand", at + Vector3(0, 0.65, 0), Vector3(0.68, 1.1, 0.26), Color("#a77f68"))
	_add_box("SketchPaper", at + Vector3(0, 0.75, 0.15), Vector3(0.52, 0.70, 0.025), Color("#f1e1c3"))
	_add_box("SketchMark", at + Vector3(0, 0.85, 0.175), Vector3(0.25, 0.08, 0.01), Color("#77a7a1"))
	_add_interaction(interaction_id, display_name, at + Vector3(0, 0.75, 0), Vector3(0.95, 1.4, 0.8))

func _add_collector_stall() -> void:
	var at := Vector3(10.6, 0.13, 5.15)
	_add_box("CollectorCounter", at + Vector3(0, 0.53, 0), Vector3(2.1, 0.95, 1.18), Color("#a77961"))
	_add_box("CollectorCounterTop", at + Vector3(0, 1.06, 0), Vector3(2.3, 0.12, 1.35), Color("#c19370"))
	for i in range(3):
		_add_box("CollectorObject", at + Vector3(-0.65 + i * 0.63, 1.19, 0), Vector3(0.25, 0.22 + 0.07 * i, 0.25), Color("#d8b779"))
	_add_box("CollectorCanopy", at + Vector3(0, 2.5, 0), Vector3(2.55, 0.14, 1.55), Color("#9e7170"))
	_add_interaction("collector", "旧物铺", at + Vector3(0, 1.0, -0.2), Vector3(2.6, 2.0, 1.7))

func _add_market_stall_hero(at: Vector3) -> void:
	var scene: PackedScene = load("res://assets/art/models/hk_market_stall.glb")
	if scene == null:
		push_error("Hong Kong market stall model was not imported")
		return
	var stall := scene.instantiate()
	stall.name = "HK_MarketStall_Hero_Asset"
	stall.position = at
	stall.rotation.y = PI
	add_child(stall)
	var body := StaticBody3D.new()
	body.name = "HK_MarketStall_Collision"
	body.position = at + Vector3(0, 1.47, 0)
	body.collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.2, 2.95, 3.85)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_add_interaction("market_stall", "街市鲜果档", at + Vector3(0, 1.2, -2.15), Vector3(4.4, 2.3, 1.25))

func _add_tram(at: Vector3) -> void:
	var scene: PackedScene = load("res://assets/art/models/hk_tram.glb")
	if scene == null:
		push_error("Hong Kong tram model was not imported")
		return
	var tram := scene.instantiate()
	tram.name = "HK_Tram_Hero_Asset"
	tram.position = at
	add_child(tram)
	var body := StaticBody3D.new()
	body.name = "HK_Tram_Collision"
	body.position = at + Vector3(0, 1.48, 0)
	body.collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.45, 2.85, 1.82)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_vertical_sign(text: String, at: Vector3, tint: Color) -> void:
	_add_box("VerticalSign", at, Vector3(0.8, 2.35, 0.32), tint)
	_add_box("VerticalSignInset", at + Vector3(0, 0, 0.18), Vector3(0.34, 1.8, 0.025), tint.lightened(0.36))

func _add_npc(display_name: String, interaction_id: String, at: Vector3, outfit: Color) -> void:
	_add_sphere(display_name + "Head", at + Vector3(0, 1.25, 0), Vector3(0.52, 0.52, 0.52), Color("#efbd9b"))
	_add_capsule(display_name + "Body", at + Vector3(0, 0.67, 0), Vector3(0.64, 0.94, 0.52), outfit)
	_add_sphere(display_name + "Hair", at + Vector3(0, 1.49, -0.03), Vector3(0.55, 0.24, 0.55), Color("#514845"))
	_add_interaction(interaction_id, display_name, at + Vector3(0, 0.9, 0), Vector3(1.25, 1.8, 1.25))

func _add_planter(at: Vector3, leaf_color: Color) -> void:
	_add_box("Planter", at + Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 1.2), Color("#d69b79"))
	for offset in [Vector3(-0.28, 0.82, 0), Vector3(0.18, 1.02, 0.1), Vector3(0.34, 0.75, -0.16)]:
		_add_sphere("PlanterLeaf", at + offset, Vector3(0.62, 0.66, 0.6), leaf_color)

func _add_bench(at: Vector3) -> void:
	_add_box("BenchSeat", at + Vector3(0, 0.44, 0), Vector3(2.0, 0.14, 0.64), Color("#af8064"))
	_add_box("BenchBack", at + Vector3(0, 0.78, 0.28), Vector3(2.0, 0.72, 0.12), Color("#ba9074"))
	for x in [-0.76, 0.76]:
		_add_box("BenchLeg", at + Vector3(x, 0.21, 0), Vector3(0.12, 0.43, 0.55), Color("#677d75"))

func _add_tree(at: Vector3) -> void:
	_add_cylinder("TreeTrunk", at + Vector3(0, 1.2, 0), 0.20, 2.4, Color("#9d7d64"))
	_add_sphere("TreeCrownCore", at + Vector3(0, 2.86, 0), Vector3(1.65, 1.25, 1.55), Color("#7fa886"))
	for lobe in [
		[Vector3(-0.58, 3.05, 0.2), Vector3(1.0, 0.97, 0.93), Color("#94b88c")],
		[Vector3(0.58, 2.98, 0.0), Vector3(1.06, 1.01, 0.96), Color("#86ae83")],
		[Vector3(-0.1, 3.38, -0.35), Vector3(1.12, 0.95, 1.0), Color("#a8c49a")],
		[Vector3(0.14, 2.66, 0.62), Vector3(1.02, 0.82, 0.96), Color("#83a981")]
	]:
		_add_sphere("TreeCanopyLobe", at + lobe[0], lobe[1], lobe[2])

func _add_lamp(at: Vector3) -> void:
	_add_cylinder("LampPost", at + Vector3(0, 1.75, 0), 0.07, 3.5, Color("#536c6e"))
	_add_sphere("LampBulb", at + Vector3(0, 3.53, 0), Vector3(0.47, 0.28, 0.47), Color("#f8d6a0"))
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 3.3, 0)
	light.light_color = Color("#ffdcb0")
	light.light_energy = 0.07
	light.omni_range = 5.8
	add_child(light)

func _add_sign(_text: String, at: Vector3, tint: Color) -> void:
	var plate := _add_box("ShopSignPlate", at, Vector3(4.3, 0.79, 0.13), tint)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_box("SignInset", at + Vector3(0, 0, 0.083), Vector3(3.96, 0.53, 0.025), tint.lightened(0.13))
	_add_box("SignAccent", at + Vector3(-1.58, 0, 0.105), Vector3(0.13, 0.34, 0.026), Color("#f4dfb9"))

func _add_interaction(interaction_id: String, display_name: String, at: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Interact_%s" % interaction_id
	area.position = at
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_meta("interaction_id", interaction_id)
	area.set_meta("display_name", display_name)
	area.add_to_group("city3d_interactable")
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)

func _add_box(node_name: String, at: Vector3, size: Vector3, tint: Color, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(tint)
	add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		body.collision_layer = 1
		var box := BoxShape3D.new()
		box.size = size
		var shape := CollisionShape3D.new()
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	return instance

func _add_sphere(node_name: String, at: Vector3, size: Vector3, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = SphereMesh.new()
	instance.position = at
	instance.scale = size
	instance.material_override = _material(tint)
	add_child(instance)

func _add_capsule(node_name: String, at: Vector3, size: Vector3, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = CapsuleMesh.new()
	instance.position = at
	instance.scale = size
	instance.material_override = _material(tint)
	add_child(instance)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, tint: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.2
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(tint)
	add_child(instance)

func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.91
	return material
