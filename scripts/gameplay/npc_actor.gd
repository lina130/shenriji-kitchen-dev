class_name NPCActor
extends CharacterBody2D

const InteractableScript := preload("res://scripts/gameplay/interactable.gd")

var npc_id := ""
var display_name := ""
var accent_color := Color.WHITE
var patrol_start := Vector2.ZERO
var patrol_end := Vector2.ZERO
var patrol_speed := 26.0
var _direction := 1.0
var _phase := 0.0

func configure(id: String, actor_name: String, start: Vector2, end: Vector2, color: Color, speed: float = 26.0) -> void:
	npc_id = id
	display_name = actor_name
	position = start
	patrol_start = start
	patrol_end = end
	accent_color = color
	patrol_speed = speed

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("npcs")
	var interactable: WorldInteractable = InteractableScript.new()
	interactable.configure("npc|%s" % npc_id, "和%s说话" % display_name, Vector2.ZERO, Vector2(64, 78), accent_color, Vector2(110, 120))
	interactable.interaction_requested.connect(func(interaction_id: String) -> void: interaction_requested.emit(interaction_id))
	add_child(interactable)
	queue_redraw()

signal interaction_requested(interaction_id: String)

func _physics_process(delta: float) -> void:
	_phase += delta * 3.0
	var direction_vector := patrol_end - patrol_start
	if direction_vector.length_squared() <= 1.0:
		queue_redraw()
		return
	var axis := direction_vector.normalized()
	position += axis * _direction * patrol_speed * delta
	if global_position.distance_to(patrol_start) < 4.0:
		_direction = 1.0
	elif global_position.distance_to(patrol_end) < 4.0:
		_direction = -1.0
	queue_redraw()

func _draw() -> void:
	var bob := sin(_phase) * 1.4
	draw_ellipse(Vector2(0, 23), 17.0, 7.0, Color(0.02, 0.04, 0.05, 0.36), true)
	draw_rect(Rect2(Vector2(-10, -18 + bob), Vector2(20, 34)), accent_color.darkened(0.25), true)
	draw_circle(Vector2(0, -25 + bob), 10.0, Color("#e4b17c"))
	draw_arc(Vector2(0, -26 + bob), 11.0, PI, TAU, 16, Color("#283a40"), 6.0)
	draw_circle(Vector2(-3, -26 + bob), 1.7, Color("#17242b"))
	draw_circle(Vector2(3, -26 + bob), 1.7, Color("#17242b"))