class_name PlayerActor
extends CharacterBody2D

const BASE_SPEED := 185.0

var nearby_interactables: Array[WorldInteractable] = []
var _facing := Vector2.DOWN
var _walk_phase := 0.0
var _input_locked := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	add_to_group("player")
	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 13.0
	shape.height = 30.0
	collision.shape = shape
	collision.position = Vector2(0, 8)
	add_child(collision)
	queue_redraw()

func set_input_locked(value: bool) -> void:
	_input_locked = value
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if _input_locked:
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 0.01:
		_facing = direction.normalized()
		_walk_phase += delta * 12.0
	else:
		_walk_phase = 0.0
	velocity = direction * BASE_SPEED * GameState.get_speed_multiplier()
	move_and_slide()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		return
	var wants_interact := event.is_action_pressed("interact")
	if event is InputEventMouseButton:
		wants_interact = wants_interact or (event.button_index == MOUSE_BUTTON_RIGHT and event.pressed)
	if wants_interact and not nearby_interactables.is_empty():
		_interact_with_nearest()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func register_interactable(interactable: WorldInteractable) -> void:
	if interactable not in nearby_interactables:
		nearby_interactables.append(interactable)
	_refresh_context()

func unregister_interactable(interactable: WorldInteractable) -> void:
	nearby_interactables.erase(interactable)
	_refresh_context()

func _interact_with_nearest() -> void:
	nearby_interactables.sort_custom(func(a: WorldInteractable, b: WorldInteractable) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	nearby_interactables[0].interact()

func _refresh_context() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if nearby_interactables.is_empty():
		hud.set_context_prompt("")
	else:
		nearby_interactables.sort_custom(func(a: WorldInteractable, b: WorldInteractable) -> bool:
			return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
		)
		hud.set_context_prompt("右键 · %s" % nearby_interactables[0].prompt_text)

func _draw() -> void:
	var bob := sin(_walk_phase) * 1.8
	var shadow := Color(0.02, 0.04, 0.05, 0.42)
	_draw_shadow_ellipse(Vector2(0, 24), Vector2(18, 8), shadow)
	var body_rect := Rect2(Vector2(-11, -22 + bob), Vector2(22, 35))
	draw_rect(body_rect, Color("#e9b45d"), true)
	draw_rect(Rect2(Vector2(-12, -24 + bob), Vector2(24, 10)), Color("#213238"), true)
	draw_rect(Rect2(Vector2(-12, -22 + bob), Vector2(24, 4)), Color("#f5d898"), true)
	var face_x := _facing.x * 4.0
	draw_circle(Vector2(-5 + face_x, -9 + bob), 2.2, Color("#17242b"))
	draw_circle(Vector2(5 + face_x, -9 + bob), 2.2, Color("#17242b"))
	draw_line(Vector2(-8, 12 + bob), Vector2(-13, 25 + bob), Color("#37505c"), 5.0)
	draw_line(Vector2(8, 12 + bob), Vector2(13, 25 + bob), Color("#37505c"), 5.0)

func _draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)