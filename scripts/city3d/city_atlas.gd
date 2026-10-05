class_name CityAtlas3D
extends Node3D

# Gameplay coordinates are deliberately compressed. This is the first continuous
# world layout, not a survey map or a finished street network.
const WORLD_WIDTH := 4600.0
const WORLD_DEPTH := 4200.0
const REGION_SIZE := 128.0
const REGION_SCRIPT := preload("res://scripts/city3d/city_region_chunk.gd")
const WORLD_CENTER := Vector2(-600.0, 0.0)
const HONGKONG_FERRY_PIER_AT := Vector2(720.0, 860.0)
const MACAO_FERRY_PIER_AT := Vector2(-1764.0, 1415.0)
const CITIES := [
	{"id": "zhaoqing", "name": "肇庆", "at": Vector2(-2280, -1510), "tint": Color("#b5b99b"), "height": 37.0},
	{"id": "foshan", "name": "佛山", "at": Vector2(-1510, -1050), "tint": Color("#c6aa91"), "height": 42.0},
	{"id": "guangzhou", "name": "广州", "at": Vector2(-890, -1180), "tint": Color("#aab9b9"), "height": 82.0},
	{"id": "dongguan", "name": "东莞", "at": Vector2(-360, -650), "tint": Color("#b7bda2"), "height": 44.0},
	{"id": "huizhou", "name": "惠州", "at": Vector2(900, -820), "tint": Color("#acc5b6"), "height": 36.0},
	{"id": "shenzhen", "name": "深圳", "at": Vector2(0, 0), "tint": Color("#a4bdc3"), "height": 68.0},
	{"id": "hongkong", "name": "香港", "at": Vector2(720, 1150), "tint": Color("#b5b9c6"), "height": 78.0},
	{"id": "zhongshan", "name": "中山", "at": Vector2(-1180, 170), "tint": Color("#b9c39d"), "height": 31.0},
	{"id": "jiangmen", "name": "江门", "at": Vector2(-2110, 150), "tint": Color("#c5b29e"), "height": 37.0},
	{"id": "zhuhai", "name": "珠海", "at": Vector2(-1550, 1100), "tint": Color("#a8c8c1"), "height": 43.0},
	{"id": "macao", "name": "澳门", "at": Vector2(-1950, 1480), "tint": Color("#d1b7a6"), "height": 52.0}
]
const ROUTES := [
	["zhaoqing", "foshan"], ["foshan", "guangzhou"], ["guangzhou", "dongguan"],
	["dongguan", "huizhou"], ["dongguan", "shenzhen"], ["shenzhen", "hongkong"],
	["foshan", "zhongshan"], ["zhongshan", "jiangmen"], ["zhongshan", "zhuhai"],
	["zhuhai", "macao"], ["zhongshan", "shenzhen"], ["guangzhou", "huizhou"],
	["zhuhai", "hongkong"]
]
const SETTLEMENT_CORRIDORS := [
	["foshan", "guangzhou"], ["guangzhou", "dongguan"],
	["dongguan", "shenzhen"], ["foshan", "zhongshan"],
	["zhongshan", "jiangmen"], ["zhongshan", "zhuhai"]
]

var _macro_city_nodes: Dictionary = {}
var _focused_city := ""
var _macro_routes: Node3D

func _ready() -> void:
	name = "GreaterBayAreaAtlas"
	_build_land()
	_build_green_belt()
	_build_settlement_corridors()
	_macro_routes = Node3D.new()
	_macro_routes.name = "OverviewTransitLinks"
	add_child(_macro_routes)
	for route in ROUTES:
		_add_route(city_position(route[0]), city_position(route[1]))
	for city in CITIES:
		_add_city_mass(city)
		_add_landmark(city)
	_add_ferry_piers()

func city_position(city_id: String) -> Vector2:
	for city in CITIES:
		if city["id"] == city_id:
			return city["at"]
	return Vector2.ZERO

func city_data(city_id: String) -> Dictionary:
	for city in CITIES:
		if city["id"] == city_id:
			return city.duplicate(true)
	return {}

func world_bounds() -> Rect2:
	return Rect2(WORLD_CENTER - Vector2(WORLD_WIDTH, WORLD_DEPTH) * 0.5,
		Vector2(WORLD_WIDTH, WORLD_DEPTH))

func is_water_at(world_position: Vector3) -> bool:
	return _water_score(Vector2(world_position.x, world_position.z)) > 0.0

func get_region_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / REGION_SIZE), floori(world_position.z / REGION_SIZE))

func is_showcase_cell(cell: Vector2i) -> bool:
	return Rect2(Vector2(cell) * REGION_SIZE, Vector2.ONE * REGION_SIZE).intersects(
		Rect2(-34.0, -25.0, 94.0, 50.0))

func create_region_chunk(cell: Vector2i) -> Node3D:
	var chunk = REGION_SCRIPT.new()
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * REGION_SIZE
	var nearest := nearest_city(Vector3(center.x, 0.0, center.y))
	chunk.configure(cell, nearest, city_position(str(nearest["id"])),
		_water_score(center), _corridor_distance(center), Callable(self, "_water_score"))
	return chunk

func set_detail_focus(world_position: Vector3, camera_span: float = 23.0) -> void:
	if is_instance_valid(_macro_routes):
		_macro_routes.visible = camera_span >= 220.0
	var nearest := nearest_city(world_position)
	var at: Vector2 = nearest["at"]
	var distance := Vector2(world_position.x, world_position.z).distance_to(at)
	var next_city := str(nearest["id"]) if distance < 470.0 and camera_span < 220.0 else ""
	if next_city == _focused_city:
		return
	if _macro_city_nodes.has(_focused_city):
		_macro_city_nodes[_focused_city].visible = true
	_focused_city = next_city
	if _macro_city_nodes.has(_focused_city):
		_macro_city_nodes[_focused_city].visible = false

func nearest_city(world_position: Vector3) -> Dictionary:
	var best: Dictionary = CITIES[0]
	var best_distance := INF
	for city in CITIES:
		var distance: float = Vector2(world_position.x, world_position.z).distance_squared_to(city["at"])
		if distance < best_distance:
			best_distance = distance
			best = city
	return best

func _build_land() -> void:
	# A finer single-surface mesh keeps the harbour edge legible at walking zoom
	# without adding separate coast patches or extra terrain draw calls.
	var width_steps := 288
	var depth_steps := 264
	var vertices := PackedVector3Array()
	var water_scores := PackedFloat32Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	var start_x := WORLD_CENTER.x - WORLD_WIDTH * 0.5
	var start_z := WORLD_CENTER.y - WORLD_DEPTH * 0.5
	for iz in range(depth_steps + 1):
		for ix in range(width_steps + 1):
			var p := Vector2(start_x + float(ix) * WORLD_WIDTH / width_steps,
				start_z + float(iz) * WORLD_DEPTH / depth_steps)
			vertices.append(Vector3(p.x, -0.022, p.y))
			var score := _water_score(p)
			water_scores.append(score)
			normals.append(Vector3.UP)
			colors.append(_terrain_color(p, score))
	for iz in range(depth_steps):
		for ix in range(width_steps):
			var a := iz * (width_steps + 1) + ix
			var b := a + 1
			var c := a + width_steps + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
			_append_land_collision_triangle(vertices[a], vertices[c], vertices[b],
				water_scores[a], water_scores[c], water_scores[b], collision_faces)
			_append_land_collision_triangle(vertices[b], vertices[c], vertices[d],
				water_scores[b], water_scores[c], water_scores[d], collision_faces)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := MeshInstance3D.new()
	surface.name = "ContinuousBayTerrain"
	surface.mesh = mesh
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	var shore_body := StaticBody3D.new()
	shore_body.name = "LandAndShoreCollider"
	shore_body.collision_layer = 1
	var shore_shape := ConcavePolygonShape3D.new()
	shore_shape.set_faces(collision_faces)
	shore_shape.backface_collision = true
	var shore_collision := CollisionShape3D.new()
	shore_collision.shape = shore_shape
	shore_body.add_child(shore_collision)
	add_child(shore_body)

func _append_land_collision_triangle(a: Vector3, b: Vector3, c: Vector3,
	sa: float, sb: float, sc: float, faces: PackedVector3Array) -> void:
	var points := [Vector3(a.x, 0.0, a.z), Vector3(b.x, 0.0, b.z), Vector3(c.x, 0.0, c.z)]
	var scores := [sa, sb, sc]
	var land_polygon: Array[Vector3] = []
	var shore_crossings: Array[Vector3] = []
	for i in range(3):
		var next := (i + 1) % 3
		var here_land: bool = float(scores[i]) <= 0.0
		var next_land: bool = float(scores[next]) <= 0.0
		if here_land:
			land_polygon.append(points[i])
		if here_land != next_land:
			var fraction: float = scores[i] / (scores[i] - scores[next])
			var shore_point: Vector3 = points[i].lerp(points[next], fraction)
			land_polygon.append(shore_point)
			shore_crossings.append(shore_point)
	for i in range(1, land_polygon.size() - 1):
		faces.append_array(PackedVector3Array([land_polygon[0], land_polygon[i], land_polygon[i + 1]]))
	if shore_crossings.size() != 2:
		return
	var shoreline_mid := Vector2((shore_crossings[0].x + shore_crossings[1].x) * 0.5,
		(shore_crossings[0].z + shore_crossings[1].z) * 0.5)
	if _shore_has_walkway(shoreline_mid):
		return
	var p := shore_crossings[0] - Vector3(0, 0.25, 0)
	var q := shore_crossings[1] - Vector3(0, 0.25, 0)
	var p_top := p + Vector3(0, 1.85, 0)
	var q_top := q + Vector3(0, 1.85, 0)
	faces.append_array(PackedVector3Array([p, q, p_top, q, q_top, p_top]))

func _shore_has_walkway(p: Vector2) -> bool:
	if p.distance_to(HONGKONG_FERRY_PIER_AT) < 6.2 or p.distance_to(MACAO_FERRY_PIER_AT) < 6.2:
		return true
	for route in ROUTES:
		var a: Vector2 = city_position(str(route[0]))
		var b: Vector2 = city_position(str(route[1]))
		var axis := b - a
		var t := clampf((p - a).dot(axis) / axis.length_squared(), 0.0, 1.0)
		if p.distance_to(a + axis * t) < 6.2:
			return true
	return false

func _terrain_color(p: Vector2, water_score: float) -> Color:
	var noise := sin(p.x * 0.0031 + sin(p.y * 0.0025)) * 0.5 + sin(p.y * 0.0043 - p.x * 0.0017) * 0.35
	var land := Color("#abc2a5")
	land = land.lerp(Color("#c6c69e"), (1.0 - smoothstep(-2100.0, -850.0, p.x)) * 0.32)
	land = land.lerp(Color("#97b9a5"), smoothstep(-100.0, 1100.0, p.x) * (1.0 - smoothstep(50.0, 1100.0, p.y)) * 0.43)
	land = land.lightened(clampf(noise * 0.045, -0.05, 0.05)) if noise > 0 else land.darkened(-noise * 0.035)
	for city in CITIES:
		var city_at: Vector2 = city["at"]
		var radius := 430.0 if city["id"] in ["shenzhen", "guangzhou", "hongkong"] else 355.0
		var d := p.distance_to(city_at)
		var amount := (1.0 - smoothstep(radius * 0.25, radius + 95.0, d)) * 0.34
		land = land.lerp(city["tint"], amount)
	if water_score < 0.0 and water_score > -57.0:
		land = land.lerp(Color("#d5d7b2"), smoothstep(-57.0, -4.0, water_score) * 0.63)
	var water := Color("#5bafbe").lerp(Color("#438fa8"), smoothstep(26.0, 410.0, water_score))
	water = water.lerp(Color("#84cbd0"), clampf(noise * 0.045, 0.0, 0.06))
	return land.lerp(water, smoothstep(-4.0, 6.0, water_score))

func _water_score(p: Vector2) -> float:
	var z := p.y
	var t := clampf((z - 120.0) / 1700.0, 0.0, 1.0)
	var west_coast := -780.0 - 850.0 * t + sin(z * 0.008) * 52.0 + sin(z * 0.019) * 22.0
	var east_coast := -550.0 + 1650.0 * t + sin(z * 0.006 + 1.5) * 78.0
	var estuary := minf(minf(p.x - west_coast, east_coast - p.x), z - 115.0)
	var south_edge := 720.0 + p.x * 0.10 + sin(p.x * 0.006) * 80.0
	# The western shore bends toward Macao instead of cutting the city off from
	# the bay with a straight north-south boundary.
	var west_bay_shore := -1475.0 - 354.0 * smoothstep(1180.0, 1500.0, z)
	var southern_sea := minf(minf(p.x - west_bay_shore, 1660.0 - p.x), z - south_edge)
	var water := maxf(estuary, southern_sea)
	# Three tapered distributaries feed the estuary north of the main bay.
	var branch_a_x := -820.0 + (z + 1180.0) * 0.10 + sin(z * 0.006) * 42.0
	var branch_b_x := -1430.0 + (z + 1050.0) * 0.31 + sin(z * 0.004 + 1.3) * 34.0
	var branch_c_x := -370.0 + (z + 650.0) * 0.07 + sin(z * 0.008) * 38.0
	if z > -1330.0 and z < 440.0:
		water = maxf(water, minf(28.0 + 28.0 * t - absf(p.x - branch_a_x), minf(z + 1330.0, 440.0 - z)))
	if z > -1160.0 and z < 650.0:
		water = maxf(water, minf(20.0 + 20.0 * t - absf(p.x - branch_b_x), minf(z + 1160.0, 650.0 - z)))
	if z > -680.0 and z < 490.0:
		water = maxf(water, minf(18.0 + 24.0 * t - absf(p.x - branch_c_x), minf(z + 680.0, 490.0 - z)))
	# Hong Kong's green islands and smaller estuary islets emerge from the sea.
	var island_angle := atan2(z - 1160.0, p.x - 720.0)
	var hk_radius := 1.0 + sin(island_angle * 5.0) * 0.10 + sin(island_angle * 9.0) * 0.045
	var hk_ellipse := sqrt(pow((p.x - 720.0) / 440.0, 2.0) + pow((z - 1160.0) / 345.0, 2.0))
	water = minf(water, (hk_ellipse - hk_radius) * 170.0)
	for islet in [Vector3(-430, 1260, 115), Vector3(-105, 1370, 80), Vector3(1240, 1600, 110)]:
		var island_distance := p.distance_to(Vector2(islet.x, islet.y))
		water = minf(water, island_distance - islet.z)
	return water

func _build_green_belt() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 921047
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for grove in [
		Vector3(-2520, -1610, 420), Vector3(-2450, 330, 470),
		Vector3(1310, -860, 520), Vector3(1160, -1600, 330),
		Vector3(-650, -1750, 290), Vector3(-1900, 1770, 220)
	]:
		for i in range(225):
			var angle := rng.randf_range(0.0, TAU)
			var radius: float = sqrt(rng.randf()) * grove.z
			var p: Vector2 = Vector2(grove.x + cos(angle) * radius, grove.y + sin(angle) * radius)
			var city: Dictionary = nearest_city(Vector3(p.x, 0, p.y))
			if p.distance_to(city["at"]) < 225.0 or _water_score(p) > -30.0:
				continue
			var canopy := rng.randf_range(7.0, 17.0)
			transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(canopy, canopy * 0.82, canopy)),
				Vector3(p.x, canopy * 0.42, p.y)))
			colors.append(Color("#79a48a") if i % 3 == 0 else (Color("#8fb393") if i % 3 == 1 else Color("#a1bd95")))
	_add_forest_multimesh(transforms, colors)

func _build_settlement_corridors() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 664201
	var facades: Array[Transform3D] = []
	var colors: Array[Color] = []
	var roofs: Array[Transform3D] = []
	var roof_colors: Array[Color] = []
	for pair in SETTLEMENT_CORRIDORS:
		var a: Vector2 = city_position(str(pair[0]))
		var b: Vector2 = city_position(str(pair[1]))
		var axis := (b - a).normalized()
		var across := axis.orthogonal()
		var steps := maxi(3, roundi(a.distance_to(b) / 145.0))
		var palette: Color = city_data(str(pair[0]))["tint"].lerp(city_data(str(pair[1]))["tint"], 0.5)
		for step in range(1, steps):
			var middle := a.lerp(b, float(step) / steps)
			for lot in range(16):
				var side := -1.0 if lot % 2 == 0 else 1.0
				var p := middle + axis * rng.randf_range(-65.0, 65.0) + across * side * rng.randf_range(31.0, 115.0)
				if _water_score(p) > -30.0:
					continue
				var near: Dictionary = nearest_city(Vector3(p.x, 0, p.y))
				if p.distance_to(near["at"]) < 250.0:
					continue
				var height := rng.randf_range(8.0, 22.0)
				var size := Vector3(rng.randf_range(11.0, 20.0), height, rng.randf_range(10.0, 17.0))
				var at := Vector3(p.x, height * 0.5 + 0.08, p.y)
				facades.append(Transform3D(Basis.IDENTITY.scaled(size), at))
				var tint := palette.lightened(rng.randf_range(0.04, 0.22))
				colors.append(tint)
				roofs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size.x + 0.8, 0.8, size.z + 0.8)),
					at + Vector3(0, height * 0.5 + 0.4, 0)))
				roof_colors.append(tint.darkened(0.13))
	_add_multimesh(self, "CorridorNeighborhoods", facades, colors)
	_add_multimesh(self, "CorridorRooflines", roofs, roof_colors)

func _corridor_distance(p: Vector2) -> float:
	var best := INF
	for pair in SETTLEMENT_CORRIDORS:
		var a := city_position(str(pair[0]))
		var b := city_position(str(pair[1]))
		var axis := b - a
		var t := clampf((p - a).dot(axis) / axis.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + axis * t))
	return best

func _add_route(a: Vector2, b: Vector2) -> void:
	_add_ribbon("IntercityCauseway", a, b, 18.0, 0.058, Color("#748d8e"), _macro_routes)
	_add_ribbon("TransitMedian", a, b, 1.2, 0.082, Color("#e0d0a9"), _macro_routes)
	var edge := (b - a).normalized().orthogonal() * 8.3
	_add_ribbon("CausewayEdge", a + edge, b + edge, 0.75, 0.087, Color("#c9d8ca"), _macro_routes)
	_add_water_bridge_spans(a, b)

func _add_water_bridge_spans(a: Vector2, b: Vector2) -> void:
	var segments := maxi(1, ceili(a.distance_to(b) / 12.0))
	var run_start := -1
	for i in range(segments + 1):
		var in_water := false
		if i < segments:
			var sample := a.lerp(b, (float(i) + 0.5) / float(segments))
			in_water = _water_score(sample) > 0.0
		if in_water and run_start < 0:
			run_start = maxi(0, i - 1)
		elif not in_water and run_start >= 0:
			var from := a.lerp(b, float(run_start) / float(segments))
			var to := a.lerp(b, float(mini(segments, i + 1)) / float(segments))
			_add_bridge_span(from, to)
			run_start = -1

func _add_bridge_span(a: Vector2, b: Vector2) -> void:
	var direction := b - a
	if direction.length() < 2.0:
		return
	var middle := (a + b) * 0.5
	var bridge := StaticBody3D.new()
	bridge.name = "WalkableBayBridge"
	bridge.collision_layer = 1
	bridge.position = Vector3(middle.x, -0.06, middle.y)
	bridge.rotation.y = -atan2(direction.y, direction.x)
	var deck_size := Vector3(direction.length() + 0.1, 0.12, 12.4)
	var shape := BoxShape3D.new()
	shape.size = deck_size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	bridge.add_child(collider)
	var visual := MeshInstance3D.new()
	visual.name = "BridgeDeckSurface"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(deck_size.x, 0.07, deck_size.z)
	visual.mesh = mesh
	visual.position.y = 0.025
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#809c9a")
	material.roughness = 0.9
	visual.material_override = material
	bridge.add_child(visual)
	add_child(bridge)

func _add_city_mass(city: Dictionary) -> void:
	var at: Vector2 = city["at"]
	var tint: Color = city["tint"]
	var city_id: String = city["id"]
	var buildings := Node3D.new()
	buildings.name = "DistantCityMass_%s" % city_id
	add_child(buildings)
	_macro_city_nodes[city_id] = buildings
	_add_box("CityPlaza_%s" % city_id, Vector3(at.x, 0.020, at.y),
		Vector3(105, 0.015, 94), Color("#d8cfb8"), buildings)
	for axis in [0, 1]:
		var road_size := Vector3(345, 0.020, 18) if axis == 0 else Vector3(18, 0.020, 320)
		_add_box("CityCrossStreet", Vector3(at.x, 0.031, at.y), road_size, Color("#758e89"), buildings)
	var seed := str(city["id"]).hash() & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var roofs: Array[Transform3D] = []
	var roof_colors: Array[Color] = []
	for ix in range(-11, 12):
		for iz in range(-11, 12):
			if abs(ix) <= 1 and abs(iz) <= 1:
				continue
			var radial := sqrt(pow(float(ix) / 10.7, 2.0) + pow(float(iz) / 10.2, 2.0))
			if radial > 1.0 + rng.randf_range(-0.14, 0.12):
				continue
			var skip_chance := 0.08 + radial * 0.30
			if city_id == "zhaoqing" or city_id == "huizhou":
				skip_chance += 0.18
			if rng.randf() < skip_chance:
				continue
			var height: float = float(city["height"]) * rng.randf_range(0.35, 1.12) * clampf(1.15 - radial * 0.43, 0.42, 1.0)
			if city_id == "zhaoqing" or city_id == "huizhou":
				height *= 0.55
			var footprint := Vector2(rng.randf_range(13, 23), rng.randf_range(12, 21))
			if city_id == "dongguan":
				footprint = Vector2(rng.randf_range(22, 34), rng.randf_range(11, 19))
				height *= 0.72
			elif city_id == "foshan" or city_id == "jiangmen" or city_id == "macao":
				footprint = Vector2(rng.randf_range(18, 29), rng.randf_range(17, 26))
				height *= 0.80
			elif city_id == "zhuhai":
				footprint = Vector2(rng.randf_range(14, 22), rng.randf_range(18, 29))
			var base := Vector3(at.x + ix * 30 + rng.randf_range(-3.8, 3.8),
				height * 0.5 + 0.13, at.y + iz * 27 + rng.randf_range(-3.5, 3.5))
			var color := tint.lightened(rng.randf_range(0.02, 0.19)) if (ix + iz) % 3 == 0 else tint.darkened(rng.randf_range(0.05, 0.23))
			transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(footprint.x, height, footprint.y)), base))
			colors.append(color)
			roofs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(footprint.x + 1.2, 1.0, footprint.y + 1.2)),
				base + Vector3(0, height * 0.5 + 0.5, 0)))
			var roof_color := color.lightened(0.12)
			if city_id in ["foshan", "jiangmen"]:
				roof_color = Color("#71857d").lerp(color, 0.28)
			elif city_id == "macao":
				roof_color = Color("#a98478").lerp(color, 0.25)
			elif city_id == "dongguan":
				roof_color = Color("#8ba7a2").lerp(color, 0.35)
			roof_colors.append(roof_color)
	_add_multimesh(buildings, "DistantFacades", transforms, colors)
	_add_multimesh(buildings, "DistantRooflines", roofs, roof_colors)

func _add_landmark(city: Dictionary) -> void:
	var at: Vector2 = city["at"]
	var anchor_offset := Vector2(100, -95) if city["id"] == "shenzhen" else Vector2(38, -35)
	var root := Node3D.new()
	root.name = "Landmark_%s" % str(city["id"])
	root.position = Vector3(at.x + anchor_offset.x, 0.1, at.y + anchor_offset.y)
	add_child(root)
	match str(city["id"]):
		"shenzhen":
			_add_taper(root, "TaperedGlassTower", Vector3(0, 88, 0), 12, 3, 176, Color("#79aec2"), 6)
			_add_box("TowerCrown", Vector3(0, 179, 0), Vector3(7, 8, 7), Color("#e0ece4"), root)
			_add_box("NorthGlassWing", Vector3(-31, 47, -12), Vector3(20, 94, 19), Color("#a6cad0"), root)
			_add_box("SouthGlassWing", Vector3(34, 38, 10), Vector3(17, 76, 20), Color("#8bb6bf"), root)
		"guangzhou":
			_add_taper(root, "LatticeTower", Vector3(0, 84, 0), 7, 3.1, 168, Color("#d9d7c8"), 12)
			for y in [40.0, 96.0, 143.0]:
				_add_taper(root, "ObservationRing", Vector3(0, y, 0), 13, 13, 3, Color("#8db2b6"), 16)
			_add_taper(root, "TowerBeacon", Vector3(0, 177, 0), 2.5, 0.5, 18, Color("#c9897b"), 9)
		"hongkong":
			_add_box("HarbourClockTower", Vector3(0, 48, 0), Vector3(17, 96, 15), Color("#dfd4bd"), root)
			_add_box("ClockCrown", Vector3(0, 100, 0), Vector3(22, 8, 20), Color("#869c9c"), root)
			_add_taper(root, "ClockSpire", Vector3(0, 111, 0), 7, 1, 18, Color("#d8c6ab"), 4)
			_add_box("HarbourTram", Vector3(29, 7, 7), Vector3(31, 14, 11), Color("#b76f69"), root)
			_add_box("TramUpperDeck", Vector3(29, 17, 7), Vector3(28, 7, 10), Color("#cbd4ca"), root)
			_add_box("FerryTerminalRoof", Vector3(-42, 16, 35), Vector3(58, 5, 30), Color("#e2d9c6"), root)
		"zhuhai":
			for offset in [-20.0, 20.0]:
				_add_sphere(root, "SeasideShell", Vector3(offset, 28, 0), Vector3(28, 52, 18), Color("#ece9d9"))
			_add_box("SeafrontPromenade", Vector3(0, 2, 32), Vector3(95, 4, 15), Color("#d6d0b8"), root)
		"macao":
			_add_box("PastelArcade", Vector3(0, 18, 0), Vector3(54, 36, 25), Color("#e1b2a1"), root)
			for x in [-14.0, 0.0, 14.0]:
				_add_box("ArcadePier", Vector3(x, 9, 15), Vector3(3, 18, 3), Color("#f0d5b7"), root)
			_add_box("ArcadeCornice", Vector3(0, 38, 0), Vector3(58, 3, 29), Color("#f1d7bd"), root)
			_add_box("BellTower", Vector3(34, 49, -8), Vector3(15, 98, 14), Color("#e8cbb6"), root)
			_add_taper(root, "BellRoof", Vector3(34, 101, -8), 11, 2, 14, Color("#a6b5a8"), 4)
		"foshan", "jiangmen":
			_add_box("HeritageHall", Vector3(0, 18, 0), Vector3(58, 36, 33), Color("#d9b69a"), root)
			_add_taper(root, "HeritageRoof", Vector3(0, 39, 0), 36, 23, 11, Color("#6f817c"), 4)
			_add_box("HeritageGate", Vector3(-38, 39, 4), Vector3(15, 78, 15), Color("#c69478"), root)
			_add_taper(root, "GateRoof", Vector3(-38, 83, 4), 13, 4, 13, Color("#718981"), 4)
		"dongguan":
			_add_box("MakerFactory", Vector3(0, 16, 0), Vector3(62, 32, 35), Color("#b5b8aa"), root)
			for x in [-20.0, 0.0, 20.0]:
				_add_box("SawtoothRoof", Vector3(x, 34, 0), Vector3(17, 7, 37), Color("#789c9a"), root)
			_add_taper(root, "WorkshopChimney", Vector3(40, 45, -18), 7, 5, 90, Color("#b18376"), 10)
		"zhongshan":
			_add_box("GardenPavilion", Vector3(0, 18, 0), Vector3(40, 36, 31), Color("#e4d2b4"), root)
			_add_taper(root, "GardenRoof", Vector3(0, 40, 0), 25, 13, 12, Color("#799789"), 8)
			_add_taper(root, "GardenTower", Vector3(28, 37, -12), 9, 5, 74, Color("#b0c1a5"), 8)
		"zhaoqing", "huizhou":
			for x in [-27.0, 0.0, 30.0]:
				_add_taper(root, "GreenHill", Vector3(x, 31, 0), 24, 0.5, 62, Color("#7fa58c"), 7)

func _add_ferry_piers() -> void:
	var scene: PackedScene = load("res://assets/art/models/bay_ferry_pier.glb")
	if scene == null:
		push_error("Bay ferry pier model was not imported")
		return
	_add_ferry_pier(scene, "HongKongNorthShoreFerryPier", HONGKONG_FERRY_PIER_AT,
		0.0, "ferry_pier_hongkong", "香港北岸码头")
	_add_ferry_pier(scene, "MacaoBayShoreFerryPier", MACAO_FERRY_PIER_AT,
		-PI * 0.5, "ferry_pier_macao", "澳门湾岸码头")

func _add_ferry_pier(scene: PackedScene, node_name: String, at: Vector2,
	heading: float, interaction_id: String, display_name: String) -> void:
	# Blender local -Y is shore. In Godot local +Z points landward and -Z
	# points seaward; the Macao instance rotates this axis toward the bay.
	var root := Node3D.new()
	root.name = node_name
	root.position = Vector3(at.x, -0.29, at.y)
	root.rotation.y = heading
	add_child(root)
	var model := scene.instantiate()
	model.name = "BayFerryPierHeroModel"
	root.add_child(model)
	for surface in [
		{"name": "PierWalkableDeck", "center": Vector3(0, 0.20, -0.40), "size": Vector3(8.6, 0.18, 10.8)},
		{"name": "PierShorePath", "center": Vector3(0, 0.20, 8.0), "size": Vector3(6.0, 0.18, 8.8)}
	]:
		var floor_body := StaticBody3D.new()
		floor_body.name = str(surface["name"])
		floor_body.collision_layer = 1
		floor_body.position = surface["center"]
		var floor_shape := BoxShape3D.new()
		floor_shape.size = surface["size"]
		var floor_collision := CollisionShape3D.new()
		floor_collision.shape = floor_shape
		floor_body.add_child(floor_collision)
		root.add_child(floor_body)
	_add_box("PierShoreApproach", Vector3(0, 0.29, 6.8),
		Vector3(6.0, 0.038, 6.2), Color("#aab7ae"), root)
	_add_box("PierQuaysideWalk", Vector3(0, 0.285, 10.5),
		Vector3(10.0, 0.038, 2.5), Color("#a0ada7"), root)
	for side in [-1.0, 1.0]:
		# Two short wall sections frame an open gate to the ticket lane.
		_add_box("ShoreStoneParapet", Vector3(side * 7.35, 0.55, 3.9),
			Vector3(5.0, 0.52, 0.8), Color("#d3c6af"), root)
		_add_box("PromenadePlanter", Vector3(side * 8.2, 0.56, 11.0),
			Vector3(1.6, 0.52, 1.6), Color("#c78e79"), root)
		_add_taper(root, "PromenadeTreeTrunk", Vector3(side * 8.2, 1.8, 11.0),
			0.18, 0.13, 2.5, Color("#937860"), 7)
		_add_sphere(root, "PromenadeTreeCrown", Vector3(side * 8.2, 3.55, 11.0),
			Vector3(1.4, 1.2, 1.4), Color("#86ad91"))
		_add_taper(root, "QuayLampPost", Vector3(side * 9.8, 2.0, 7.4),
			0.09, 0.09, 3.7, Color("#678a85"), 9)
		_add_sphere(root, "QuayLamp", Vector3(side * 9.8, 4.0, 7.4),
			Vector3(0.46, 0.48, 0.46), Color("#f6e6bf"))
	for booth_x in [-2.83, 2.83]:
		var body := StaticBody3D.new()
		body.name = "PierTicketBoothCollision"
		body.collision_layer = 1
		body.position = Vector3(booth_x, 1.52, 1.34)
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.22, 2.62, 2.48)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	var entrance := Area3D.new()
	entrance.name = "Interact_FerryPier"
	entrance.position = Vector3(0, 1.29, 3.8)
	entrance.collision_layer = 2
	entrance.collision_mask = 0
	entrance.set_meta("interaction_id", interaction_id)
	entrance.set_meta("display_name", display_name)
	entrance.add_to_group("city3d_interactable")
	var entry_shape := BoxShape3D.new()
	entry_shape.size = Vector3(2.45, 2.25, 2.15)
	var entry_collision := CollisionShape3D.new()
	entry_collision.shape = entry_shape
	entrance.add_child(entry_collision)
	root.add_child(entrance)

func _add_ribbon(node_name: String, a: Vector2, b: Vector2,
	width: float, y: float, tint: Color, parent: Node3D = null) -> void:
	var direction := b - a
	var visual := _add_box(node_name, Vector3((a.x+b.x)*0.5, y, (a.y+b.y)*0.5),
		Vector3(direction.length(), 0.026, width), tint, parent)
	visual.rotation.y = -atan2(direction.y, direction.x)

func _add_box(node_name: String, at: Vector3, size: Vector3, tint: Color,
	parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	instance.material_override = material
	var container: Node3D = parent if parent != null else self
	container.add_child(instance)
	return instance

func _add_taper(parent: Node3D, node_name: String, at: Vector3, bottom: float,
	top: float, height: float, tint: Color, segments: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	visual.material_override = material
	parent.add_child(visual)

func _add_sphere(parent: Node3D, node_name: String, at: Vector3,
	scale_to: Vector3, tint: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = SphereMesh.new()
	visual.position = at
	visual.scale = scale_to
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	visual.material_override = material
	parent.add_child(visual)

func _add_forest_multimesh(transforms: Array[Transform3D], colors: Array[Color]) -> void:
	var canopy := SphereMesh.new()
	canopy.radial_segments = 8
	canopy.rings = 4
	_add_multimesh(self, "ForestCanopy", transforms, colors, canopy)

func _add_multimesh(parent: Node3D, node_name: String,
	transforms: Array[Transform3D], colors: Array[Color], source_mesh: PrimitiveMesh = null) -> void:
	if transforms.is_empty():
		return
	var geometry: PrimitiveMesh = source_mesh if source_mesh != null else BoxMesh.new()
	if geometry is BoxMesh:
		(geometry as BoxMesh).size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.89
	geometry.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = geometry
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
		multi.set_instance_color(i, colors[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = node_name
	visual.multimesh = multi
	parent.add_child(visual)
