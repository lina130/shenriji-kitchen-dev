class_name CityAssetGallery3D
extends Node3D

signal close_requested

const ASSETS := [
	{"name": "人才公园书吧餐馆", "path": "res://assets/art/models/sz_park_bookbar_cafe.glb"},
	{"name": "湾区居民", "path": "res://assets/art/models/bay_resident.glb"},
	{"name": "南头茶铺", "path": "res://assets/art/models/nantou_tea_house.glb"},
	{"name": "香港电车", "path": "res://assets/art/models/hk_tram.glb"},
	{"name": "街市摊位", "path": "res://assets/art/models/hk_market_stall.glb"},
	{"name": "轮渡码头", "path": "res://assets/art/models/bay_ferry_pier.glb"},
	{"name": "深圳湾步道桥", "path": "res://assets/art/models/baywalk_bridge_span.glb"},
	{"name": "青园蔬香米卷", "path": "res://assets/art/models/food/garden_rice_roll.glb"},
	{"name": "香料海风包", "path": "res://assets/art/models/food/macao_spice_bun.glb"},
	{"name": "晨光鸡蛋包", "path": "res://assets/art/models/food/morning_egg_bun.glb"},
	{"name": "暖姜豆花碗", "path": "res://assets/art/models/food/warm_tofu_bowl.glb"},
	{"name": "椰香小米盅", "path": "res://assets/art/models/food/coconut_millet.glb"},
	{"name": "港湾拌面", "path": "res://assets/art/models/food/harbour_noodles.glb"},
	{"name": "香煎鸡肉饭", "path": "res://assets/art/models/food/chicken_rice.glb"},
	{"name": "湾畔鲜虾肠粉", "path": "res://assets/art/models/food/bay_shrimp_roll.glb"},
	{"name": "海苔青蔬饺", "path": "res://assets/art/models/food/seaweed_dumpling.glb"},
	{"name": "果香冰沙杯", "path": "res://assets/art/models/food/fruit_ice.glb"},
	{"name": "餐馆备料助手", "path": "res://assets/art/models/park_prep_assistant.glb"},
	{"name": "餐馆取餐店员", "path": "res://assets/art/models/park_pickup_clerk.glb"},
	{"name": "厨房圆角柜台", "path": "res://assets/art/models/park_cafe_counter_unit.glb"},
	{"name": "厨房洗菜盆", "path": "res://assets/art/models/park_cafe_wash_basin.glb"},
	{"name": "过程食材 · 洗净青菜", "path": "res://assets/art/models/food_stage/washed_greens.glb"},
	{"name": "过程食材 · 切配蔬果", "path": "res://assets/art/models/food_stage/chopped_ingredients.glb"},
	{"name": "过程食材 · 切开鸡蛋包", "path": "res://assets/art/models/food_stage/sliced_bun_veg.glb"},
	{"name": "过程食材 · 切配香料鸡肉", "path": "res://assets/art/models/food_stage/sliced_chicken_spice.glb"},
	{"name": "过程食材 · 切配拌面青菜", "path": "res://assets/art/models/food_stage/sliced_noodle_greens.glb"},
	{"name": "过程食材 · 切配冰沙水果", "path": "res://assets/art/models/food_stage/sliced_fruit.glb"},
	{"name": "过程食材 · 切配备货香料", "path": "res://assets/art/models/food_stage/sliced_spices.glb"},
	{"name": "过程食材 · 米浆碗", "path": "res://assets/art/models/food_stage/rice_batter_bowl.glb"},
	{"name": "过程食材 · 香料油", "path": "res://assets/art/models/food_stage/spice_jar.glb"},
	{"name": "过程食材 · 分装餐盘", "path": "res://assets/art/models/food_stage/finished_serving_tray.glb"},
	{"name": "过程食材 · 蒸米卷", "path": "res://assets/art/models/food_stage/steamer_rice_roll.glb"},
	{"name": "过程食材 · 腌制鸡肉", "path": "res://assets/art/models/food_stage/marinated_chicken.glb"},
	{"name": "过程食材 · 香煎鸡肉", "path": "res://assets/art/models/food_stage/pan_seared_chicken.glb"},
	{"name": "过程食材 · 汤锅煮面", "path": "res://assets/art/models/food_stage/boiling_noodles.glb"},
	{"name": "过程食材 · 豆花分装", "path": "res://assets/art/models/food_stage/portioned_tofu.glb"},
	{"name": "过程食材 · 点缀拼盘", "path": "res://assets/art/models/food_stage/garnish_kit.glb"},
	{"name": "过程食材 · 冰沙搅拌", "path": "res://assets/art/models/food_stage/blended_fruit_ice.glb"},
	{"name": "过程食材 · 煎蛋", "path": "res://assets/art/models/food_stage/fried_egg_pan.glb"},
	{"name": "过程食材 · 椰香小米煮制", "path": "res://assets/art/models/food_stage/coconut_millet_simmer.glb"},
	{"name": "过程食材 · 鲜虾肠粉蒸制", "path": "res://assets/art/models/food_stage/steamer_shrimp_roll.glb"},
	{"name": "过程食材 · 海苔青蔬饺蒸制", "path": "res://assets/art/models/food_stage/steamer_seaweed_dumpling.glb"},
	{"name": "过程食材 · 清洗水果", "path": "res://assets/art/models/food_stage/washed_fruit.glb"},
	{"name": "过程食材 · 清洗小米", "path": "res://assets/art/models/food_stage/washed_millet.glb"},
	{"name": "过程食材 · 清洗白米", "path": "res://assets/art/models/food_stage/washed_rice.glb"},
	{"name": "过程食材 · 清洗鲜虾", "path": "res://assets/art/models/food_stage/washed_shrimp.glb"},
	{"name": "过程食材 · 清洗海苔", "path": "res://assets/art/models/food_stage/washed_seaweed.glb"}
]

var current_index := 0
var _viewport: SubViewport
var _model_holder: Node3D
var _camera: Camera3D
var _item_label: Label
var _yaw := deg_to_rad(36.0)
var _pitch := deg_to_rad(28.0)
var _zoom := 16.0
var _orbiting := false


func _ready() -> void:
	name = "CityAssetGallery"
	_build_stage()
	_build_toolbar()
	_show_asset(0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_F2]:
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom = clampf(_zoom * (0.83 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.20), 7.0, 38.0)
			_update_camera()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _orbiting:
		_yaw += event.relative.x * 0.008
		_pitch = clampf(_pitch - event.relative.y * 0.006, deg_to_rad(8.0), deg_to_rad(70.0))
		_update_camera()
		get_viewport().set_input_as_handled()


func show_asset(index: int) -> void:
	_show_asset(index)


func _build_stage() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "CanvasLayer"
	canvas.layer = 30
	add_child(canvas)
	var root := Control.new()
	root.name = "GalleryOverlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	root.set_meta("gallery_root", true)
	var display := SubViewportContainer.new()
	display.name = "GalleryViewportContainer"
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.stretch = true
	display.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(display)
	_viewport = SubViewport.new()
	_viewport.name = "GalleryViewport"
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	display.add_child(_viewport)
	var stage := Node3D.new()
	stage.name = "GalleryStage"
	_viewport.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#dfeae3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#fff6e6")
	environment.ambient_light_energy = 0.25
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff1d5")
	sun.light_energy = 0.35
	sun.rotation = Vector3(deg_to_rad(-54.0), deg_to_rad(32.0), 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 5.45
	pedestal_mesh.bottom_radius = 5.65
	pedestal_mesh.height = 0.24
	var pedestal := MeshInstance3D.new()
	pedestal.name = "DisplayPedestal"
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = -0.17
	var pedestal_material := StandardMaterial3D.new()
	pedestal_material.albedo_color = Color("#e9dcca")
	pedestal_material.roughness = 0.9
	pedestal.material_override = pedestal_material
	stage.add_child(pedestal)
	_model_holder = Node3D.new()
	_model_holder.name = "CurrentAsset"
	stage.add_child(_model_holder)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _zoom
	_camera.near = 0.05
	_camera.far = 300.0
	_camera.current = true
	stage.add_child(_camera)
	_update_camera()


func _build_toolbar() -> void:
	var root := get_node("CanvasLayer/GalleryOverlay") as Control
	var bar := PanelContainer.new()
	bar.name = "GalleryToolbar"
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_left = -383
	bar.offset_right = 383
	bar.offset_top = 18
	bar.offset_bottom = 70
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.95, 0.88, 0.96)
	style.border_color = Color("#a98d73")
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(0.18, 0.28, 0.24, 0.18)
	style.shadow_size = 8
	bar.add_theme_stylebox_override("panel", style)
	root.add_child(bar)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	bar.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var title := _label("已完成素材", 16, Color("#355b58"))
	row.add_child(title)
	_item_label = _label("", 15, Color("#685b4e"))
	_item_label.custom_minimum_size.x = 230
	_item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_item_label)
	var previous := _button("上一件")
	previous.pressed.connect(func() -> void: _show_asset(current_index - 1))
	row.add_child(previous)
	var next := _button("下一件")
	next.pressed.connect(func() -> void: _show_asset(current_index + 1))
	row.add_child(next)
	var close := _button("返回试玩")
	close.pressed.connect(func() -> void: close_requested.emit())
	row.add_child(close)
	var help := _label("右键旋转  ·  滚轮缩放  ·  Esc 返回", 15, Color("#3c625e"))
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = -385
	help.offset_right = -22
	help.offset_top = -42
	help.offset_bottom = -14
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(help)


func _show_asset(index: int) -> void:
	if not is_instance_valid(_model_holder):
		current_index = posmod(index, ASSETS.size())
		return
	current_index = posmod(index, ASSETS.size())
	for child in _model_holder.get_children():
		_model_holder.remove_child(child)
		child.queue_free()
	var definition: Dictionary = ASSETS[current_index]
	var packed = ResourceLoader.load(str(definition["path"]))
	if packed is PackedScene:
		var asset := (packed as PackedScene).instantiate()
		_model_holder.add_child(asset)
		_fit_asset(asset)
		_item_label.text = "%d / %d  %s" % [current_index + 1, ASSETS.size(), str(definition["name"])]
	else:
		_item_label.text = "%d / %d  %s · 资源未导入" % [current_index + 1, ASSETS.size(), str(definition["name"])]
	_yaw = deg_to_rad(36.0)
	_pitch = deg_to_rad(28.0)
	_zoom = 16.0
	_update_camera()


func _fit_asset(asset: Node) -> void:
	if not asset is Node3D:
		return
	var spatial := asset as Node3D
	var minimum := Vector3(1.0e20, 1.0e20, 1.0e20)
	var maximum := Vector3(-1.0e20, -1.0e20, -1.0e20)
	var bounds: Array[Vector3] = [minimum, maximum]
	_scan_mesh_bounds(asset, bounds)
	if bounds[0].x > bounds[1].x:
		return
	var size := bounds[1] - bounds[0]
	var longest := maxf(maxf(size.x, size.z), size.y * 1.12)
	var factor := 8.6 / maxf(longest, 0.01)
	spatial.scale = Vector3.ONE * factor
	var center := (bounds[0] + bounds[1]) * 0.5
	spatial.position = Vector3(-center.x, -bounds[0].y, -center.z) * factor


func _scan_mesh_bounds(node: Node, bounds: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var box := mesh_node.get_aabb()
		var relative := _model_holder.global_transform.affine_inverse() * mesh_node.global_transform
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					var point := relative * Vector3(x, y, z)
					bounds[0] = bounds[0].min(point)
					bounds[1] = bounds[1].max(point)
	for child in node.get_children():
		_scan_mesh_bounds(child, bounds)


func _update_camera() -> void:
	if not is_instance_valid(_camera):
		return
	var focus := Vector3(0, 2.4, 0)
	var distance := 23.0
	var horizontal := cos(_pitch) * distance
	_camera.position = focus + Vector3(sin(_yaw) * horizontal, sin(_pitch) * distance, cos(_yaw) * horizontal)
	_camera.look_at(focus)
	_camera.size = _zoom


func _label(value: String, size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(86, 37)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#355b58"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#e4eee4")
	normal.border_color = Color("#9eb8aa")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#d1e6d5")
	button.add_theme_stylebox_override("hover", hover)
	return button
