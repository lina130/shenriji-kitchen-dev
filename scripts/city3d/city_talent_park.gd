class_name CityTalentPark3D
extends Node3D

# One scene unit is one design metre. The plan is traced proportionally from the
# district's public visitor diagram, not a surveyed GIS or construction plan.
const GROUND_Y := 0.0
const SPAWN_POINT := Vector3(-320.0, 0.5, 150.0)
const RESTAURANT_ANCHOR := Vector3(-310.0, 0.0, 120.0)
const BOOKBAR_ANCHOR := Vector3(-315.0, 0.0, 285.0)
const OVERVIEW_CENTER := Vector3(0.0, 0.0, -10.0)
const OVERVIEW_SPAN := 1700.0
const PARK_BOUNDS := Rect2(Vector2(-420.0, -500.0), Vector2(840.0, 1000.0))
const WORLD_BOUNDS := Rect2(Vector2(-760.0, -850.0), Vector2(1520.0, 1630.0))
const RESTAURANT_CLEAR := Rect2(Vector2(-325.0, 105.0), Vector2(30.0, 30.0))
const PI_BRIDGE_A := Vector2(-74.0, 282.0)
const PI_BRIDGE_B := Vector2(-74.0, 373.0)
const STAR_BRIDGE_A := Vector2(277.0, -215.0)
const STAR_BRIDGE_B := Vector2(277.0, 263.0)

func _ready() -> void:
	name = "ShenzhenTalentPark"
	_build_terrain()
	_build_boundary_streets()
	_build_walks()
	_build_bridges()
	_build_bookbar()
	_build_park_shelters()
	_build_groves()
	_build_houhai_skyline()

func world_bounds() -> Rect2:
	return WORLD_BOUNDS

func is_walkable_position(at: Vector3) -> bool:
	var p := Vector2(at.x, at.z)
	return WORLD_BOUNDS.has_point(p) and (_water_score(p) <= 0.0 or _is_bridge_deck(p))

func _is_bridge_deck(p: Vector2) -> bool:
	for bridge in [[PI_BRIDGE_A, PI_BRIDGE_B], [STAR_BRIDGE_A, STAR_BRIDGE_B]]:
		var a: Vector2 = bridge[0]
		var b: Vector2 = bridge[1]
		var axis := b - a
		var t := clampf((p - a).dot(axis) / axis.length_squared(), 0.0, 1.0)
		if p.distance_to(a + axis * t) <= 3.0:
			return true
	return false

func ground_height_at(at: Vector3) -> float:
	return _height_at(Vector2(at.x, at.z))

func _lake_score(p: Vector2) -> float:
	var angle := atan2(p.y + 5.0, p.x - 5.0)
	var shoreline := 1.0 + sin(angle * 3.0) * 0.052 + sin(angle * 7.0 + 0.7) * 0.024
	var radius := sqrt(pow((p.x - 5.0) / 281.0, 2.0) + pow((p.y + 5.0) / 340.0, 2.0))
	var score := (shoreline - radius) * 180.0
	# A small southern island group is shown in the visitor diagram.
	score = minf(score, p.distance_to(Vector2(-80.0, 253.0)) - 35.0)
	return score

func _water_score(p: Vector2) -> float:
	return maxf(_lake_score(p), p.y - 645.0)

func _height_at(p: Vector2) -> float:
	var east_hill := 8.5 * exp(-p.distance_squared_to(Vector2(265.0, -300.0)) / (2.0 * 105.0 * 105.0))
	var south_lawn := 3.4 * exp(-p.distance_squared_to(Vector2(215.0, 355.0)) / (2.0 * 92.0 * 92.0))
	return east_hill + south_lawn

func _build_terrain() -> void:
	var steps_x := 152
	var steps_z := 163
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var scores := PackedFloat32Array()
	var indices := PackedInt32Array()
	var land_faces := PackedVector3Array()
	for iz in range(steps_z + 1):
		for ix in range(steps_x + 1):
			var p := WORLD_BOUNDS.position + Vector2(
				float(ix) * WORLD_BOUNDS.size.x / float(steps_x),
				float(iz) * WORLD_BOUNDS.size.y / float(steps_z))
			var water := _water_score(p)
			var y := -0.08 if water > 0.0 else _height_at(p) - 0.02
			vertices.append(Vector3(p.x, y, p.y))
			normals.append(Vector3.UP)
			scores.append(water)
			colors.append(_terrain_tint(p, water))
	for iz in range(steps_z):
		for ix in range(steps_x):
			var a := iz * (steps_x + 1) + ix
			var b := a + 1
			var c := a + steps_x + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
			_append_land_triangle(vertices[a], vertices[c], vertices[b], scores[a], scores[c], scores[b], land_faces)
			_append_land_triangle(vertices[b], vertices[c], vertices[d], scores[b], scores[c], scores[d], land_faces)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ground := MeshInstance3D.new()
	ground.name = "ParkLandLakeAndBay"
	ground.mesh = terrain_mesh
	var terrain_material := StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.93
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = terrain_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	var land_body := StaticBody3D.new()
	land_body.name = "WalkableParkLandAndShore"
	land_body.collision_layer = 1
	var land_shape := ConcavePolygonShape3D.new()
	land_shape.set_faces(land_faces)
	land_shape.backface_collision = true
	var land_collision := CollisionShape3D.new()
	land_collision.shape = land_shape
	land_body.add_child(land_collision)
	add_child(land_body)

func _terrain_tint(p: Vector2, water: float) -> Color:
	var land := Color("#a9c5a8")
	if PARK_BOUNDS.has_point(p):
		land = Color("#a9c99d")
		land = land.lerp(Color("#c8d6a5"), smoothstep(1.0, 7.0, _height_at(p)) * 0.43)
	else:
		land = Color("#b9c7b1")
	if water < 0.0 and water > -14.0:
		land = land.lerp(Color("#d8d8b7"), smoothstep(-14.0, 0.0, water) * 0.58)
	var lake := Color("#6ab6c2") if p.y < 645.0 else Color("#64adbf")
	return land.lerp(lake, smoothstep(-3.5, 4.0, water))

func _append_land_triangle(a: Vector3, b: Vector3, c: Vector3,
	sa: float, sb: float, sc: float, faces: PackedVector3Array) -> void:
	var points := [Vector3(a.x, _height_at(Vector2(a.x, a.z)), a.z),
		Vector3(b.x, _height_at(Vector2(b.x, b.z)), b.z),
		Vector3(c.x, _height_at(Vector2(c.x, c.z)), c.z)]
	var scores := [sa, sb, sc]
	var polygon: Array[Vector3] = []
	var shore: Array[Vector3] = []
	for i in range(3):
		var next := (i + 1) % 3
		var dry: bool = float(scores[i]) <= 0.0
		var next_dry: bool = float(scores[next]) <= 0.0
		if dry:
			polygon.append(points[i])
		if dry != next_dry:
			var fraction: float = float(scores[i]) / (float(scores[i]) - float(scores[next]))
			var crossing: Vector3 = points[i].lerp(points[next], fraction)
			polygon.append(crossing)
			shore.append(crossing)
	for i in range(1, polygon.size() - 1):
		faces.append_array(PackedVector3Array([polygon[0], polygon[i], polygon[i + 1]]))
	if shore.size() != 2:
		return
	var midpoint := Vector2((shore[0].x + shore[1].x) * 0.5, (shore[0].z + shore[1].z) * 0.5)
	if _bridge_opening_at(midpoint):
		return
	var p := shore[0] - Vector3(0, 0.25, 0)
	var q := shore[1] - Vector3(0, 0.25, 0)
	faces.append_array(PackedVector3Array([p, q, p + Vector3.UP * 1.9,
		q, q + Vector3.UP * 1.9, p + Vector3.UP * 1.9]))

func _bridge_opening_at(p: Vector2) -> bool:
	for bridge in [[PI_BRIDGE_A, PI_BRIDGE_B], [STAR_BRIDGE_A, STAR_BRIDGE_B]]:
		var a: Vector2 = bridge[0]
		var b: Vector2 = bridge[1]
		var axis := b - a
		var t := clampf((p - a).dot(axis) / axis.length_squared(), 0.0, 1.0)
		if p.distance_to(a + axis * t) < 6.0:
			return true
	return false

func _build_boundary_streets() -> void:
	_add_box("HaideThirdRoad", Vector3(0, 0.035, -535), Vector3(1520, 0.07, 23), Color("#718986"))
	_add_box("DengliangRoad", Vector3(-450, 0.038, 0), Vector3(23, 0.075, 1040), Color("#718986"))
	_add_box("ShaheWestRoad", Vector3(450, 0.038, 0), Vector3(23, 0.075, 1040), Color("#718986"))
	_add_box("DongbinRoad", Vector3(0, 0.035, 535), Vector3(1520, 0.07, 23), Color("#718986"))
	for z in [-563.0, -507.0, 507.0, 563.0]:
		_add_box("StreetWalk", Vector3(0, 0.06, z), Vector3(1520, 0.035, 5.0), Color("#d1cbb6"))
	for x in [-478.0, -422.0, 422.0, 478.0]:
		_add_box("StreetWalk", Vector3(x, 0.06, 0), Vector3(5.0, 0.035, 1040), Color("#d1cbb6"))

func _build_walks() -> void:
	var inner: Array[Vector2] = []
	var outer: Array[Vector2] = []
	for i in range(97):
		var angle := TAU * float(i) / 96.0
		var shore_factor := 1.0 + sin(angle * 3.0) * 0.052 + sin(angle * 7.0 + 0.7) * 0.024
		inner.append(Vector2(5.0 + cos(angle) * 281.0 * (shore_factor + 0.078),
			-5.0 + sin(angle) * 340.0 * (shore_factor + 0.078)))
		outer.append(Vector2(5.0 + cos(angle) * 281.0 * (shore_factor + 0.26),
			-5.0 + sin(angle) * 340.0 * (shore_factor + 0.26)))
	_add_path("InnerLakePromenade", inner, 6.0, Color("#d4cfb8"))
	_add_path("ParkRunningLoop", outer, 4.2, Color("#c9ad9d"))
	_add_path("WestBookbarWalk", [Vector2(-310,-365), Vector2(-328,-180), Vector2(-320,0),
		Vector2(-315,120), Vector2(-315,285), Vector2(-290,365)], 5.8, Color("#d2cbb5"))
	_add_path("EastHillWalk", [Vector2(330,-390), Vector2(270,-300), Vector2(315,-185),
		Vector2(340,-60), Vector2(315,100), Vector2(330,290), Vector2(285,390)], 4.6, Color("#d3cbb2"))
	_add_path("SouthPromenade", [Vector2(-395,410), Vector2(-230,425), Vector2(0,425),
		Vector2(230,425), Vector2(390,410)], 5.5, Color("#d4cbb3"))
	_add_box("RestaurantReservedPaving", Vector3(-310, 0.045, 120),
		Vector3(23, 0.045, 23), Color("#d6c9b1"))
	_add_taper("WestCentralPlaza", Vector3(-332, 0.035, -20), 38, 38, 0.07, Color("#d7ceb7"), 32)
	_add_taper("NorthSunshineTheatreLawn", Vector3(-205, 0.07, -345), 54, 54, 0.12, Color("#b9ce9f"), 32)
	_add_taper("BaijieHillLawn", Vector3(265, 5.6, -300), 45, 45, 0.12, Color("#b3c99c"), 28)

func _add_path(node_name: String, points: Array[Vector2], width: float, tint: Color) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var offset := (b - a).normalized().orthogonal() * width * 0.5
		var first := vertices.size()
		for point in [a + offset, a - offset, b + offset, b - offset]:
			vertices.append(Vector3(point.x, _height_at(point) + 0.055, point.y))
		indices.append_array(PackedInt32Array([first, first + 2, first + 1,
			first + 1, first + 2, first + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var path := MeshInstance3D.new()
	path.name = node_name
	path.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.94
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	path.material_override = mat
	add_child(path)

func _build_bridges() -> void:
	_add_bridge("PiBridge", PI_BRIDGE_A, PI_BRIDGE_B, 6.5, Color("#b9a887"))
	_add_bridge("StarlightBridge", STAR_BRIDGE_A, STAR_BRIDGE_B, 6.5, Color("#a9b5a8"))

func _add_bridge(node_name: String, a: Vector2, b: Vector2, width: float, tint: Color) -> void:
	var direction := b - a
	var middle := (a + b) * 0.5
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = Vector3(middle.x, -0.055, middle.y)
	body.rotation.y = -atan2(direction.y, direction.x)
	body.collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(direction.length() + 0.6, 0.11, width)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var deck := _box_mesh("BridgeDeck", Vector3.ZERO,
		Vector3(direction.length() + 0.6, 0.11, width), tint)
	body.add_child(deck)
	for side in [-1.0, 1.0]:
		var rail := _box_mesh("BridgeRail", Vector3(0, 0.39, side * (width * 0.5 - 0.15)),
			Vector3(direction.length() + 0.6, 0.7, 0.19), Color("#e2dfca"))
		body.add_child(rail)
	add_child(body)

func _build_bookbar() -> void:
	var root := Node3D.new()
	root.name = "QiuxianPavilionBookbar"
	root.position = BOOKBAR_ANCHOR
	add_child(root)
	_add_box("BookbarLowPodium", Vector3(-315, 0.38, 285), Vector3(25, 0.76, 18), Color("#d8d2be"))
	_add_box("BookbarGlassHall", Vector3(-315, 2.2, 285), Vector3(20, 3.7, 14), Color("#87b8b9"))
	_add_box("BookbarRoof", Vector3(-315, 4.35, 285), Vector3(25, 0.48, 17), Color("#e6e4d3"))
	for x in [-323.0, -315.0, -307.0]:
		_add_box("BookbarVerticalFin", Vector3(x, 2.5, 292.1), Vector3(0.24, 3.4, 0.32), Color("#eff0df"))
	var body := StaticBody3D.new()
	body.name = "BookbarColliders"
	body.position = Vector3(-315, 2.0, 285)
	body.collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 4, 14)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_park_shelters() -> void:
	for site in [Vector2(-345,-290), Vector2(300,-80), Vector2(210,370)]:
		var h := _height_at(site)
		_add_taper("GardenShelterRoof", Vector3(site.x, h + 3.7, site.y),
			5.0, 3.7, 0.8, Color("#d8b99b"), 8)
		for offset in [Vector2(-3,-3), Vector2(3,-3), Vector2(-3,3), Vector2(3,3)]:
			_add_box("GardenShelterPost", Vector3(site.x + offset.x, h + 1.85, site.y + offset.y),
				Vector3(0.22, 3.7, 0.22), Color("#9c866d"))
	for position in [Vector2(-270, -40), Vector2(-275, 45), Vector2(-245, 205),
		Vector2(285,-170), Vector2(290,90), Vector2(105,365)]:
		var y := _height_at(position)
		_add_box("GardenBenchSeat", Vector3(position.x, y + 0.52, position.y),
			Vector3(2.7, 0.16, 0.8), Color("#b98969"))
	for position in [Vector2(-310,-120), Vector2(-300,210), Vector2(320,-185),
		Vector2(335,155), Vector2(-20,420)]:
		var y := _height_at(position)
		_add_taper("ParkLampPole", Vector3(position.x, y + 2.2, position.y),
			0.11, 0.11, 4.4, Color("#638684"), 8)
		_add_sphere("ParkLampGlobe", Vector3(position.x, y + 4.5, position.y),
			Vector3(0.42, 0.42, 0.42), Color("#f3eacb"))

func _build_groves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 27112017
	var tree_mesh := CylinderMesh.new()
	tree_mesh.bottom_radius = 0.5
	tree_mesh.top_radius = 0.32
	tree_mesh.height = 4.2
	tree_mesh.radial_segments = 7
	var crown_mesh := SphereMesh.new()
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	var trunks: Array[Transform3D] = []
	var trunk_tints: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_tints: Array[Color] = []
	for i in range(920):
		var p := Vector2(rng.randf_range(-410, 410), rng.randf_range(-490, 490))
		if _water_score(p) > -12.0 or RESTAURANT_CLEAR.grow(8.0).has_point(p):
			continue
		if p.distance_to(Vector2(BOOKBAR_ANCHOR.x, BOOKBAR_ANCHOR.z)) < 21.0:
			continue
		if p.distance_to(Vector2(-332,-20)) < 42.0 or p.distance_to(Vector2(-205,-345)) < 52.0:
			continue
		var lake_radial := sqrt(pow((p.x - 5.0) / 281.0, 2.0) + pow((p.y + 5.0) / 340.0, 2.0))
		if lake_radial > 1.05 and lake_radial < 1.15:
			continue
		var scale := rng.randf_range(0.75, 1.6)
		var y := _height_at(p)
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.8, scale, 0.8)),
			Vector3(p.x, y + 2.1 * scale, p.y)))
		trunk_tints.append(Color("#8a735e"))
		crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(3.0, 2.4, 2.8) * scale),
			Vector3(p.x, y + 5.0 * scale, p.y)))
		var blossom := p.x > 130.0 and p.y > 80.0 and p.y < 430.0 and i % 5 == 0
		crown_tints.append(Color("#d5adad") if blossom else (Color("#7da48b") if i % 3 == 0 else Color("#91b898")))
	_add_multimesh("ParkTreeTrunks", tree_mesh, trunks, trunk_tints)
	_add_multimesh("ParkCanopies", crown_mesh, crowns, crown_tints)

func _build_houhai_skyline() -> void:
	# Monument locations and masses convey the district relationship. Only the
	# Spring Bamboo height is documentary; other footprints/heights are studies.
	_add_taper("ChinaResourcesSpringBamboo", Vector3(-415, 196.25, -670),
		28.0, 7.0, 392.5, Color("#8bbbc4"), 24)
	_add_taper("SpringBambooCrown", Vector3(-415, 388.0, -670),
		8.0, 0.5, 22.0, Color("#d6e8e7"), 24)
	for y in [48.0, 112.0, 176.0, 240.0, 304.0, 355.0]:
		_add_taper("SpringBambooFacadeBand", Vector3(-415, y, -670),
			21.0 - y * 0.031, 21.0 - y * 0.031, 0.9, Color("#d6e7e1"), 24)
	_add_box("SpringCocoonStadiumBase", Vector3(150, 6, -690),
		Vector3(248, 12, 158), Color("#dde5dc"))
	_add_sphere("SpringCocoonStadiumRoof", Vector3(150, 30, -690),
		Vector3(132, 30, 82), Color("#e6ebe1"))
	_add_box("ShenzhenBayMixC", Vector3(-535, 16, -610),
		Vector3(190, 32, 135), Color("#d8cfbf"))
	_add_box("CoastCityMall", Vector3(-625, 15, -215),
		Vector3(180, 30, 120), Color("#cdbfaa"))
	_add_box("PolyCulturePlaza", Vector3(-575, 24, -365),
		Vector3(95, 48, 82), Color("#d5d1c3"))
	for i in range(8):
		var x := -345.0 + float(i % 4) * 76.0
		var z := -760.0 + float(i / 4) * 92.0
		if absf(x + 415.0) < 45.0 and absf(z + 670.0) < 60.0:
			continue
		var height := 88.0 + float((i * 37) % 115)
		_add_box("HouhaiFinanceTower", Vector3(x, height * 0.5, z),
			Vector3(36, height, 35), Color("#a6bec1") if i % 2 == 0 else Color("#b6c6c3"))
		_add_box("FinanceRoof", Vector3(x, height + 1.3, z),
			Vector3(39, 2.6, 38), Color("#e0e8df"))
	for i in range(4):
		var x := 610.0 + float(i % 2) * 66.0
		var z := -90.0 + float(i / 2) * 104.0
		var height := 180.0 + i * 29.0
		_add_box("ShenzhenBayOneTower", Vector3(x, height * 0.5, z),
			Vector3(40, height, 38), Color("#a9c4ca"))
		_add_box("BayOneRoof", Vector3(x, height + 1.1, z),
			Vector3(43, 2.2, 41), Color("#e1e9e1"))

func _add_box(node_name: String, at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var visual := _box_mesh(node_name, at, size, tint)
	add_child(visual)
	return visual

func _box_mesh(node_name: String, at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.89
	visual.material_override = mat
	return visual

func _add_taper(node_name: String, at: Vector3, bottom: float, top: float,
	height: float, tint: Color, segments: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	visual.material_override = mat
	add_child(visual)

func _add_sphere(node_name: String, at: Vector3, scale_to: Vector3, tint: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = SphereMesh.new()
	visual.position = at
	visual.scale = scale_to
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	visual.material_override = mat
	add_child(visual)

func _add_multimesh(node_name: String, source_mesh: PrimitiveMesh,
	transforms: Array[Transform3D], tints: Array[Color]) -> void:
	if transforms.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.93
	source_mesh.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
		multi.set_instance_color(i, tints[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = node_name
	visual.multimesh = multi
	add_child(visual)
