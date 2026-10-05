class_name CityPlayer3D
extends CharacterBody3D

const WALK_SPEED := 5.4
const ARRIVE_DISTANCE := 0.28
const RESIDENT_MODEL := "res://assets/art/models/bay_resident.glb"

var destination := Vector3.ZERO
var has_destination := false
var visual_root: Node3D
var _walk_clock := 0.0
var movement_camera: Camera3D
var input_locked := false
var _walk_animation: AnimationPlayer
var _walk_animation_name := ""

func _ready() -> void:
	name = "CityPlayer3D"
	collision_layer = 1
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.65
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	_build_visual()

func move_toward_point(point: Vector3) -> void:
	destination = Vector3(point.x, global_position.y, point.z)
	has_destination = true

func stop_auto_move() -> void:
	has_destination = false

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO if input_locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if is_instance_valid(movement_camera) and input_vector.length_squared() > 0.001:
		var screen_right := movement_camera.global_transform.basis.x
		var screen_up := -movement_camera.global_transform.basis.z
		screen_right.y = 0.0
		screen_up.y = 0.0
		direction = screen_right.normalized() * input_vector.x - screen_up.normalized() * input_vector.y
	if input_locked:
		has_destination = false
	if direction.length_squared() > 0.001:
		has_destination = false
	elif has_destination:
		var offset := destination - global_position
		offset.y = 0.0
		if offset.length() <= ARRIVE_DISTANCE:
			has_destination = false
		else:
			direction = offset.normalized()
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	velocity.y -= 18.0 * delta if not is_on_floor() else minf(velocity.y, 0.0)
	move_and_slide()
	if direction.length_squared() > 0.01:
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 12.0))
		_walk_clock += delta * 12.0
		visual_root.position.y = sin(_walk_clock) * 0.045
		if is_instance_valid(_walk_animation) and not _walk_animation.is_playing() and not _walk_animation_name.is_empty():
			_walk_animation.play(_walk_animation_name)
	else:
		_walk_clock = 0.0
		visual_root.position.y = lerpf(visual_root.position.y, 0.0, minf(1.0, delta * 10.0))
		if is_instance_valid(_walk_animation) and _walk_animation.is_playing():
			_walk_animation.stop()

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "CharacterVisual"
	add_child(visual_root)
	var model_scene: PackedScene = load(RESIDENT_MODEL)
	if model_scene != null:
		var model := model_scene.instantiate()
		model.name = "BayResidentHeroAsset"
		model.scale = Vector3.ONE * 0.85
		visual_root.add_child(model)
		_walk_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if is_instance_valid(_walk_animation) and not _walk_animation.get_animation_list().is_empty():
			_walk_animation_name = str(_walk_animation.get_animation_list()[0])
		return
	_add_part("Shoes", BoxMesh.new(), Vector3(0, 0.15, 0), Vector3(0.6, 0.26, 0.42), Color("#4c5964"))
	_add_part("Overalls", CapsuleMesh.new(), Vector3(0, 0.83, 0), Vector3(0.75, 0.97, 0.56), Color("#75a5a0"))
	_add_part("Head", SphereMesh.new(), Vector3(0, 1.54, 0), Vector3(0.66, 0.67, 0.63), Color("#f2bc92"))
	_add_part("Hair", SphereMesh.new(), Vector3(0, 1.8, -0.06), Vector3(0.70, 0.34, 0.67), Color("#514442"))
	_add_part("Bag", BoxMesh.new(), Vector3(-0.42, 0.88, -0.05), Vector3(0.23, 0.55, 0.41), Color("#e6a55f"))
	_add_part("EyeLeft", SphereMesh.new(), Vector3(-0.13, 1.57, 0.30), Vector3(0.055, 0.055, 0.055), Color("#344b4d"))
	_add_part("EyeRight", SphereMesh.new(), Vector3(0.13, 1.57, 0.30), Vector3(0.055, 0.055, 0.055), Color("#344b4d"))

func _add_part(part_name: String, mesh: Mesh, at: Vector3, scale_to: Vector3, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale_to
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	instance.material_override = material
	visual_root.add_child(instance)
