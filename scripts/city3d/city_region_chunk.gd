class_name CityRegionChunk3D
extends Node3D

# A deterministic 128 m detail tile, loaded only around the player.
const SIZE := 128.0
const SHOWCASE_CLEAR := Rect2(-34.0, -25.0, 94.0, 50.0)
const FERRY_PIER_CLEAR := [Vector2(720.0, 860.0), Vector2(-1764.0, 1415.0)]

var cell := Vector2i.ZERO
var city: Dictionary = {}
var city_center := Vector2.ZERO
var region_kind := ""
var _rng := RandomNumberGenerator.new()
var _box_transforms: Array[Transform3D] = []
var _box_colors: Array[Color] = []
var _leaf_transforms: Array[Transform3D] = []
var _leaf_colors: Array[Color] = []
var _building_body: StaticBody3D
var _water_sampler: Callable

func configure(region_cell: Vector2i, nearest: Dictionary, city_at: Vector2,
	water_score: float = -999.0, corridor_distance: float = INF,
	water_sampler: Callable = Callable()) -> void:
	cell = region_cell
	city = nearest.duplicate(true)
	city_center = city_at
	_water_sampler = water_sampler
	position = Vector3(cell.x * SIZE, 0, cell.y * SIZE)
	var center := Vector2(cell) * SIZE + Vector2.ONE * SIZE * 0.5
	var distance := center.distance_to(city_at)
	if water_score > 20.0 and distance > 330.0:
		region_kind = "water"
	elif distance < 430.0:
		region_kind = "urban"
	elif distance < 830.0 or corridor_distance < 135.0:
		region_kind = "suburban"
	else:
		region_kind = "greenbelt"
	_rng.seed = (str(city.get("id", "bay")) + ":%d:%d" % [cell.x, cell.y]).hash() & 0x7fffffff

func _ready() -> void:
	name = "Region_%d_%d_%s" % [cell.x, cell.y, str(city.get("id", "bay"))]
	if region_kind == "water":
		return
	if region_kind == "greenbelt":
		_build_greenbelt()
	else:
		_build_streets()
		_build_blocks()
		_build_street_furniture()
	_flush_multimeshes()

func _build_streets() -> void:
	var asphalt := Color("#718a89")
	# Clip each road and footpath to dry sites so a shore tile never paints
	# asphalt and street furniture into the estuary.
	for segment in range(16):
		var p := 4.0 + float(segment) * 8.0
		if _is_dry_site(Vector2(p, 64), -5.0):
			_queue_box(Vector3(p, 0.041, 64), Vector3(8.03, 0.036, 12), asphalt)
		if _is_dry_site(Vector2(64, p), -5.0):
			_queue_box(Vector3(64, 0.042, p), Vector3(12, 0.036, 8.03), asphalt)
	for stripe in range(6):
		var offset := -5.0 + stripe * 2.0
		if _is_dry_site(Vector2(64 + offset, 54), -5.0):
			_queue_box(Vector3(64 + offset, 0.065, 54), Vector3(0.9, 0.012, 4.0), Color("#ece6d0"))
		if _is_dry_site(Vector2(54, 64 + offset), -5.0):
			_queue_box(Vector3(54, 0.065, 64 + offset), Vector3(4.0, 0.012, 0.9), Color("#ece6d0"))
	for side in [55.0, 73.0]:
		for segment in range(16):
			var p := 4.0 + float(segment) * 8.0
			if _is_dry_site(Vector2(p, side), -5.0):
				_queue_box(Vector3(p, 0.050, side), Vector3(8.03, 0.02, 3.6), Color("#c8c4ae"))
			if _is_dry_site(Vector2(side, p), -5.0):
				_queue_box(Vector3(side, 0.050, p), Vector3(3.6, 0.02, 8.03), Color("#c8c4ae"))
	# Kerb rhythm and drainage detail are built into the geometry, not map labels.
	for i in range(8):
		var p := 8.0 + i * 16.0
		if _is_dry_site(Vector2(p, 54.6), -5.0):
			_queue_box(Vector3(p, 0.063, 54.6), Vector3(0.7, 0.012, 0.14), Color("#a0a79d"))
		if _is_dry_site(Vector2(73.4, p), -5.0):
			_queue_box(Vector3(73.4, 0.063, p), Vector3(0.14, 0.012, 0.7), Color("#a0a79d"))

func _is_dry_site(local_point: Vector2, max_water_score: float) -> bool:
	if not _water_sampler.is_valid():
		return true
	var global_point := Vector2(position.x + local_point.x, position.z + local_point.y)
	return float(_water_sampler.call(global_point)) <= max_water_score

func _build_blocks() -> void:
	var city_id := str(city.get("id", "bay"))
	var highrise := city_id in ["shenzhen", "guangzhou", "hongkong"]
	var industrial := city_id == "dongguan"
	var heritage := city_id in ["foshan", "jiangmen", "macao"]
	var coast := city_id in ["zhuhai", "hongkong"]
	_building_body = StaticBody3D.new()
	_building_body.name = "BuildingColliders"
	_building_body.collision_layer = 1
	add_child(_building_body)
	for gx in range(4):
		for gz in range(4):
			var x := 17.0 + gx * 31.0
			var z := 17.0 + gz * 31.0
			if gx == 1:
				x -= 1.8
			if gx == 2:
				x += 1.8
			if gz == 1:
				z -= 1.8
			if gz == 2:
				z += 1.8
			var global_point := Vector2(position.x + x, position.z + z)
			var landmark_offset := Vector2(100, -95) if city_id == "shenzhen" else Vector2(38, -35)
			if SHOWCASE_CLEAR.has_point(global_point) or global_point.distance_to(city_center) < 28.0 or global_point.distance_to(city_center + landmark_offset) < 29.0:
				continue
			var in_pier_approach := false
			for pier_at in FERRY_PIER_CLEAR:
				if global_point.distance_to(pier_at) < 34.0:
					in_pier_approach = true
					break
			if in_pier_approach:
				continue
			if _water_sampler.is_valid() and float(_water_sampler.call(global_point)) > -24.0:
				continue
			var skip_chance := 0.13 if region_kind == "urban" else 0.48
			if _rng.randf() < skip_chance:
				_add_garden(Vector3(x, 0, z))
				continue
			var footprint := Vector2(_rng.randf_range(15.0, 22.0), _rng.randf_range(15.0, 22.0))
			var floors := _rng.randi_range(2, 5)
			if highrise:
				floors = _rng.randi_range(5, 11)
			elif industrial:
				floors = _rng.randi_range(2, 4)
			elif heritage:
				floors = _rng.randi_range(2, 4)
			if region_kind == "suburban":
				floors = mini(floors, 4)
			var height := float(floors) * (3.2 if highrise else 2.8)
			var center := Vector3(x, height * 0.5 + 0.06, z)
			var tint: Color = city.get("tint", Color("#b9b9aa"))
			var facade := tint.lightened(_rng.randf_range(0.02, 0.22)) if (gx+gz) % 2 == 0 else tint.darkened(_rng.randf_range(0.04, 0.13))
			_queue_box(center, Vector3(footprint.x, height, footprint.y), facade)
			_add_collision(center, Vector3(footprint.x, height, footprint.y))
			var roof_color := Color("#77918b") if heritage else (Color("#8faeb3") if highrise else facade.lightened(0.18))
			_queue_box(center + Vector3(0, height * 0.5 + 0.42, 0),
				Vector3(footprint.x + 0.9, 0.8, footprint.y + 0.9), roof_color)
			if industrial:
				_queue_box(center + Vector3(0, height * 0.5 + 1.0, 0),
					Vector3(footprint.x * 0.68, 0.35, footprint.y * 0.64), Color("#cad4c5"))
			if heritage:
				_queue_box(center + Vector3(0, 1.8, footprint.y * 0.5 + 0.25),
					Vector3(footprint.x + 1.8, 0.25, 2.0), Color("#b67c6a"))
			elif coast:
				_queue_box(center + Vector3(0, 1.8, footprint.y * 0.5 + 0.25),
					Vector3(footprint.x * 0.72, 0.20, 1.45), Color("#e5d1b3"))
			_add_windows(center, footprint, floors, highrise)
			if _rng.randf() < 0.4:
				_add_tree(Vector3(x + footprint.x * 0.55 + 2.6, 0, z + footprint.y * 0.55 + 1.3))

func _add_windows(center: Vector3, footprint: Vector2, floors: int, highrise: bool) -> void:
	var floor_height := center.y * 2.0 / float(floors)
	for floor_index in range(1, floors):
		var y := floor_index * floor_height + 0.8
		for slot in [-1, 0, 1]:
			var x: float = center.x + slot * footprint.x * 0.25
			var color := Color("#6d9fae") if highrise else Color("#8ba9a3")
			_queue_box(Vector3(x, y, center.z + footprint.y * 0.5 + 0.025),
				Vector3(footprint.x * 0.17, 1.0, 0.09), color)
			_queue_box(Vector3(center.x + footprint.x * 0.5 + 0.025, y, center.z + slot * footprint.y * 0.25),
				Vector3(0.09, 1.0, footprint.y * 0.17), color)
	if not highrise:
		_queue_box(Vector3(center.x, 1.9, center.z + footprint.y * 0.5 + 0.16),
			Vector3(footprint.x * 0.62, 2.2, 0.16), Color("#6b9d9c"))
		_queue_box(Vector3(center.x, 3.2, center.z + footprint.y * 0.5 + 0.37),
			Vector3(footprint.x * 0.69, 0.28, 0.8), Color("#c7816e"))

func _build_street_furniture() -> void:
	for side in [38.0, 90.0]:
		for row in [39.0, 89.0]:
			if SHOWCASE_CLEAR.has_point(Vector2(position.x + side, position.z + row)):
				continue
			if not _is_dry_site(Vector2(side, row), -7.0):
				continue
			_add_tree(Vector3(side, 0, row))
	for p in [24.0, 104.0]:
		if _is_dry_site(Vector2(p, 53), -7.0):
			_queue_box(Vector3(p, 0.51, 53), Vector3(3.0, 0.18, 0.85), Color("#a57f65"))
			for x in [-1.1, 1.1]:
				_queue_box(Vector3(p + x, 0.27, 53), Vector3(0.15, 0.5, 0.7), Color("#657d78"))
		if _is_dry_site(Vector2(53, p), -7.0):
			_queue_box(Vector3(53, 2.2, p), Vector3(0.11, 4.2, 0.11), Color("#60777a"))
			_add_leaf(Vector3(53, 4.3, p), Vector3(0.53, 0.35, 0.53), Color("#f1d8a9"))

func _build_greenbelt() -> void:
	for i in range(45):
		var p := Vector3(_rng.randf_range(4, 124), 0, _rng.randf_range(4, 124))
		var global_point := Vector2(position.x + p.x, position.z + p.z)
		if SHOWCASE_CLEAR.has_point(global_point):
			continue
		if _water_sampler.is_valid() and float(_water_sampler.call(global_point)) > -8.0:
			continue
		if i % 6 == 0:
			_queue_box(p + Vector3(0, 0.08, 0), Vector3(2.1, 0.16, 1.4), Color("#c1c5aa"))
		else:
			_add_tree(p, _rng.randf_range(0.7, 1.4))

func _add_garden(at: Vector3) -> void:
	_queue_box(at + Vector3(0, 0.06, 0), Vector3(20, 0.08, 20), Color("#94b49a"))
	for i in range(3):
		_add_tree(at + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), 0.8)

func _add_tree(at: Vector3, size: float = 1.0) -> void:
	_queue_box(at + Vector3(0, 1.7 * size, 0), Vector3(0.38, 3.4, 0.38) * size, Color("#91765f"))
	_add_leaf(at + Vector3(0, 3.6 * size, 0), Vector3(2.0, 1.45, 1.85) * size, Color("#80a98c"))
	_add_leaf(at + Vector3(-0.65 * size, 3.85 * size, 0), Vector3(1.2, 1.1, 1.1) * size, Color("#9fbd92"))

func _add_collision(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	_building_body.add_child(collision)

func _queue_box(at: Vector3, size: Vector3, tint: Color) -> void:
	_box_transforms.append(Transform3D(Basis.IDENTITY.scaled(size), at))
	_box_colors.append(tint)

func _add_leaf(at: Vector3, scale_to: Vector3, tint: Color) -> void:
	_leaf_transforms.append(Transform3D(Basis.IDENTITY.scaled(scale_to), at))
	_leaf_colors.append(tint)

func _flush_multimeshes() -> void:
	_add_multimesh("DistrictArchitecture", BoxMesh.new(), _box_transforms, _box_colors)
	_add_multimesh("DistrictFoliage", SphereMesh.new(), _leaf_transforms, _leaf_colors)

func _add_multimesh(node_name: String, source_mesh: PrimitiveMesh,
	transforms: Array[Transform3D], colors: Array[Color]) -> void:
	if transforms.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.89
	source_mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
		multi.set_instance_color(i, colors[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = node_name
	visual.multimesh = multi
	add_child(visual)
