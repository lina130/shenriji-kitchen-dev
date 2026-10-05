class_name CityInteractionFx3D
extends Node3D

## A ground halo for the currently reachable Area3D. It has no collision or text.

var _target: Area3D
var _halo: MeshInstance3D
var _halo_material: StandardMaterial3D
var _radius := 1.0
var _phase := 0.0


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.87
	torus.outer_radius = 1.0
	torus.ring_segments = 12
	torus.rings = 40
	_halo_material = StandardMaterial3D.new()
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_material.albedo_color = Color(0.98, 0.79, 0.52, 0.68)
	_halo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo = MeshInstance3D.new()
	_halo.name = "ReachableObjectHalo"
	_halo.mesh = torus
	_halo.material_override = _halo_material
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.visible = false
	add_child(_halo)
	if is_instance_valid(_target):
		_sync_target()


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		if _target != null:
			clear_target()
		return
	if not is_instance_valid(_halo):
		return
	_phase += delta * 3.0
	_sync_target()
	var pulse := 1.0 + 0.045 * sin(_phase)
	_halo.scale = Vector3(_radius * pulse, 1.0, _radius * pulse)
	_halo_material.albedo_color.a = 0.60 + 0.12 * sin(_phase)


func mark_target(area: Area3D) -> void:
	if not is_instance_valid(area):
		clear_target()
		return
	if _target == area:
		return
	_target = area
	_radius = _footprint_radius(area)
	_phase = 0.0
	if is_instance_valid(_halo):
		_halo.visible = true
		_sync_target()


func clear_target() -> void:
	_target = null
	if is_instance_valid(_halo):
		_halo.visible = false


func _sync_target() -> void:
	var ground_y := _target.global_position.y
	for child in _target.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			ground_y -= (child.shape as BoxShape3D).size.y * 0.5
			break
	_halo.global_position = Vector3(_target.global_position.x, ground_y + 0.055,
		_target.global_position.z)


func _footprint_radius(area: Area3D) -> float:
	for child in area.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var bounds := (child.shape as BoxShape3D).size
			return clampf(maxf(bounds.x, bounds.z) * 0.58, 0.64, 2.5)
	return 0.9
