class_name WorldInteractable
extends Area2D

signal interaction_requested(interaction_id: String)

var interaction_id := ""
var prompt_text := ""
var accent_color := Color.WHITE
var visual_size := Vector2(80, 80)
var hit_size := Vector2.ZERO
var available := true
var _nearby_player: Node

func configure(
		id: String,
		prompt: String,
		position_on_map: Vector2,
		visual_dimensions: Vector2,
		color: Color,
		hit_dimensions: Vector2 = Vector2.ZERO
	) -> void:
	interaction_id = id
	prompt_text = prompt
	position = position_on_map
	visual_size = visual_dimensions
	accent_color = color
	hit_size = hit_dimensions

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	add_to_group("interactables")
	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	var actual_hit_size := hit_size
	if actual_hit_size == Vector2.ZERO:
		actual_hit_size = visual_size
	rectangle.size = actual_hit_size
	shape_node.shape = rectangle
	add_child(shape_node)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func set_available(value: bool) -> void:
	available = value
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.has_method("register_interactable"):
		_nearby_player = body
		body.register_interactable(self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("unregister_interactable"):
		if _nearby_player == body:
			_nearby_player = null
		body.unregister_interactable(self)

func interact() -> void:
	if available:
		interaction_requested.emit(interaction_id)

func _draw() -> void:
	var alpha := 0.95 if available else 0.25
	var center_color := Color(accent_color, alpha)
	draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.05, 0.08, 0.1, 0.92), true)
	draw_rect(Rect2(-visual_size * 0.5 + Vector2(4, 4), visual_size - Vector2(8, 8)), Color(accent_color.darkened(0.55), alpha), true)
	draw_circle(Vector2(0, -visual_size.y * 0.5 + 18), 9.0, center_color)
	draw_circle(Vector2(0, -visual_size.y * 0.5 + 18), 4.0, Color(1, 1, 1, alpha))
	if available:
		draw_arc(Vector2.ZERO, maxf(visual_size.x, visual_size.y) * 0.42, 0.0, TAU, 32, Color(1, 0.88, 0.55, 0.18), 5.0)