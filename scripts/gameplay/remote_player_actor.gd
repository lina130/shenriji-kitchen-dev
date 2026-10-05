class_name RemotePlayerActor
extends Node2D

var peer_id := 0
var display_name := ""
var _frames: Array[Texture2D] = []
var _facing := Vector2.DOWN
var _phase := 0.0
var _accent := Color("#79a9c8")

func configure(id: int, actor_name: String) -> void:
	peer_id = id
	display_name = actor_name
	_accent = Color.from_hsv(fmod(float(id) * 0.19, 1.0), 0.55, 0.88)
	_frames = PresentationManager.get_npc_world_frames("player")
	queue_redraw()

func update_state(world_position: Vector2, facing: Vector2) -> void:
	position = world_position
	_facing = facing
	_phase += 0.35
	queue_redraw()

func _process(delta: float) -> void:
	_phase += delta * 6.0
	queue_redraw()

func _draw() -> void:
	draw_ellipse(Vector2(0, 24), 17.0, 7.0, Color(0.02, 0.04, 0.05, 0.30), true)
	if not _frames.is_empty():
		var frame_index := int(floor(_phase)) % _frames.size()
		draw_texture_rect(_frames[frame_index], Rect2(-16, -42, 32, 48), false, Color(1.0, 1.0, 1.0, 0.92))
	else:
		draw_circle(Vector2(0, -12), 19.0, _accent)
	draw_circle(Vector2(0, -54), 11.0, Color(0.04, 0.08, 0.09, 0.84))
	draw_string(ThemeDB.fallback_font, Vector2(-36, -68), display_name, HORIZONTAL_ALIGNMENT_CENTER, 72, 13, Color("#e9f1ed"))
	if _facing.x < -0.1:
		draw_line(Vector2(-19, -36), Vector2(-25, -36), _accent, 3.0)
	elif _facing.x > 0.1:
		draw_line(Vector2(19, -36), Vector2(25, -36), _accent, 3.0)
