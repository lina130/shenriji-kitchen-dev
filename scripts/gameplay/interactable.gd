class_name WorldInteractable
extends Area2D

const WALK_TRIGGER_SIZE_SCALE := 0.22
const WALK_TRIGGER_RADIUS_MIN := 24.0
const WALK_TRIGGER_RADIUS_MAX := 34.0

signal interaction_requested(interaction_id: String)

var interaction_id := ""
var prompt_text := ""
var accent_color := Color.WHITE
var visual_size := Vector2(80, 80)
var hit_size := Vector2.ZERO
var available := true
var mystery_mode := false
var walk_trigger := false
var _walk_trigger_armed := false
var _pending_walk_trigger := false
var _walk_trigger_fired := false
var status_ratio := -1.0
var status_color := Color.WHITE
var hovered := false
var caption := ""
var caption_color := Color("#f4e4b0")
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

func set_walk_trigger(value: bool) -> void:
	walk_trigger = value
	_walk_trigger_armed = false
	queue_redraw()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	add_to_group("interactables")
	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	var actual_hit_size := hit_size
	if walk_trigger:
		actual_hit_size = visual_size * WALK_TRIGGER_SIZE_SCALE
	elif actual_hit_size == Vector2.ZERO:
		actual_hit_size = visual_size
	rectangle.size = actual_hit_size
	shape_node.shape = rectangle
	add_child(shape_node)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if walk_trigger:
		var arm_timer := Timer.new()
		arm_timer.one_shot = true
		arm_timer.wait_time = 0.45
		arm_timer.timeout.connect(_arm_walk_trigger)
		add_child(arm_timer)
		arm_timer.start()
	queue_redraw()

func set_mystery(value: bool) -> void:
	mystery_mode = value
	queue_redraw()

func set_available(value: bool) -> void:
	available = value
	queue_redraw()

func set_status(ratio: float, color: Color) -> void:
	status_ratio = clampf(ratio, 0.0, 1.0)
	status_color = color
	queue_redraw()

func clear_status() -> void:
	status_ratio = -1.0
	queue_redraw()

func set_hovered(value: bool) -> void:
	if hovered == value:
		return
	hovered = value
	queue_redraw()

func set_caption(text: String, color: Color = Color("#f4e4b0")) -> void:
	caption = text
	caption_color = color
	queue_redraw()

func clear_caption() -> void:
	caption = ""
	queue_redraw()

func _is_door_like() -> bool:
	return interaction_id.contains("door") or interaction_id.begins_with("enter_") or interaction_id.ends_with("_exit") or interaction_id in ["leave_home", "home_to_living", "home_living_to_bedroom"]

func _is_route_marker() -> bool:
	return interaction_id.begins_with("go_")

func _draw_door(alpha: float, center_color: Color) -> void:
	var panel_size := Vector2(maxf(34.0, visual_size.x * 0.54), maxf(42.0, visual_size.y * 0.78))
	var panel := Rect2(-panel_size * 0.5 + Vector2(0, 3), panel_size)
	draw_rect(panel, Color(accent_color.darkened(0.52), alpha), true)
	draw_rect(panel.grow(-3.0), Color(accent_color.darkened(0.30), alpha), true)
	draw_line(panel.position + Vector2(panel.size.x * 0.5, 0), panel.position + Vector2(panel.size.x * 0.5, panel.size.y), Color(0.03, 0.05, 0.06, alpha), 2.0)
	draw_circle(panel.position + Vector2(panel.size.x * 0.76, panel.size.y * 0.53), 3.4, Color(1.0, 0.88, 0.46, alpha))
	draw_arc(Vector2.ZERO, panel_size.y * 0.72, PI, TAU, 18, Color(center_color, 0.42), 3.0)

func _draw_route_marker(alpha: float, center_color: Color) -> void:
	var y := 2.0
	draw_line(Vector2(-22, y), Vector2(18, y), Color(center_color, alpha), 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(16, y - 10), Vector2(30, y), Vector2(16, y + 10)]), Color(center_color, alpha))
	draw_circle(Vector2(0, -visual_size.y * 0.5 + 16), 8.0, Color(center_color, alpha))

func _arm_walk_trigger() -> void:
	_walk_trigger_armed = true
	if _pending_walk_trigger and _nearby_player != null and not _walk_trigger_fired:
		_pending_walk_trigger = false
		_walk_trigger_fired = true
		interact.call_deferred()

func _on_body_entered(body: Node) -> void:
	if body.has_method("register_interactable"):
		_nearby_player = body
		body.register_interactable(self)
		queue_redraw()
		if interaction_id == "enter_bus_station":
			print("BUS_TRIGGER_ENTER door=%s player=%s armed=%s" % [global_position, body.global_position, _walk_trigger_armed])
		if walk_trigger:
			if _walk_trigger_armed and not _walk_trigger_fired:
				_walk_trigger_fired = true
				interact.call_deferred()
			else:
				_pending_walk_trigger = true

func _physics_process(_delta: float) -> void:
	if not walk_trigger or not _walk_trigger_armed or _walk_trigger_fired:
		return
	# Only the player belonging to the current area may fire this door trigger.
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player) or player.get_parent() != get_parent():
		return
	var trigger_radius := _walk_trigger_radius()
	if global_position.distance_to(player.global_position) <= trigger_radius:
		_walk_trigger_fired = true
		interact.call_deferred()

func _walk_trigger_radius() -> float:
	var longest_side := maxf(maxf(visual_size.x, 1.0), maxf(visual_size.y, 1.0))
	return clampf(longest_side * 0.14 + 10.0, WALK_TRIGGER_RADIUS_MIN, WALK_TRIGGER_RADIUS_MAX)

func _on_body_exited(body: Node) -> void:
	if body.has_method("unregister_interactable"):
		if _nearby_player == body:
			_nearby_player = null
			_pending_walk_trigger = false
		body.unregister_interactable(self)
		queue_redraw()

func interact() -> void:
	if available:
		interaction_requested.emit(interaction_id)

func _draw() -> void:
	if mystery_mode and _nearby_player == null:
		return
	var alpha := 0.95 if available else 0.25
	var center_color := Color(accent_color, alpha)
	draw_rect(Rect2(-visual_size * 0.5, visual_size), Color(0.05, 0.08, 0.1, 0.92), true)
	draw_rect(Rect2(-visual_size * 0.5 + Vector2(4, 4), visual_size - Vector2(8, 8)), Color(accent_color.darkened(0.55), alpha), true)
	if _is_door_like():
		_draw_door(alpha, center_color)
	elif _is_route_marker():
		_draw_route_marker(alpha, center_color)
	else:
		draw_circle(Vector2(0, -visual_size.y * 0.5 + 18), 9.0, center_color)
		draw_circle(Vector2(0, -visual_size.y * 0.5 + 18), 4.0, Color(1, 1, 1, alpha))
	if available:
		draw_arc(Vector2.ZERO, maxf(visual_size.x, visual_size.y) * 0.42, 0.0, TAU, 32, Color(1, 0.88, 0.55, 0.18), 5.0)
	if status_ratio >= 0.0:
		var ring_radius := maxf(visual_size.x, visual_size.y) * 0.54 + 5.0
		draw_arc(Vector2.ZERO, ring_radius, -PI * 0.5, TAU - PI * 0.5, 36, Color(0.08, 0.11, 0.12, 0.78), 7.0)
		draw_arc(Vector2.ZERO, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * status_ratio, 36, Color(status_color, alpha), 5.0)
	if hovered and available:
		draw_rect(Rect2(-visual_size * 0.5 - Vector2(4, 4), visual_size + Vector2(8, 8)), Color(1.0, 0.88, 0.48, 0.92), false, 3.0)
		draw_arc(Vector2.ZERO, maxf(visual_size.x, visual_size.y) * 0.58, 0.0, TAU, 36, Color(1.0, 0.82, 0.36, 0.28), 6.0)
	if not caption.is_empty() and available:
		var caption_width := maxf(visual_size.x, 112.0)
		var caption_rect := Rect2(Vector2(-caption_width * 0.5, -visual_size.y * 0.5 - 28.0), Vector2(caption_width, 23.0))
		draw_rect(caption_rect, Color(0.03, 0.06, 0.07, 0.88), true)
		draw_rect(caption_rect, Color(caption_color, 0.72), false, 2.0)
		draw_string(ThemeDB.fallback_font, caption_rect.position + Vector2(0, 17), caption, HORIZONTAL_ALIGNMENT_CENTER, caption_width, 13, caption_color)