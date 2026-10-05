class_name NPCActor
extends CharacterBody2D

const InteractableScript := preload("res://scripts/gameplay/interactable.gd")

signal interaction_requested(interaction_id: String)

var npc_id := ""
var display_name := ""
var accent_color := Color.WHITE
var patrol_start := Vector2.ZERO
var patrol_end := Vector2.ZERO
var patrol_speed := 26.0
var _direction := 1.0
var _phase := 0.0
var _schedule_checked_hour := -1
var _world_frames: Array[Texture2D] = []
var _action_frames: Array[Texture2D] = []
var _action_id := ""

func configure(id: String, actor_name: String, start: Vector2, end: Vector2, color: Color, speed: float = 26.0) -> void:
	npc_id = id
	display_name = actor_name
	position = start
	patrol_start = start
	patrol_end = end
	accent_color = color
	patrol_speed = speed
	_world_frames = PresentationManager.get_npc_world_frames(npc_id)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("npcs")
	var interactable: WorldInteractable = InteractableScript.new()
	interactable.configure("npc|%s" % npc_id, "和%s说话" % display_name, Vector2.ZERO, Vector2(64, 78), accent_color, Vector2(110, 120))
	interactable.interaction_requested.connect(func(interaction_id: String) -> void: interaction_requested.emit(interaction_id))
	add_child(interactable)
	_apply_schedule()
	queue_redraw()

func _physics_process(delta: float) -> void:
	var hour := int(TimeSystem.minute_of_day / 60)
	if hour != _schedule_checked_hour:
		_schedule_checked_hour = hour
		_apply_schedule()
	_refresh_action_frames()
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

func _apply_schedule() -> void:
	var rows := ConfigDB.get_rows("npc_schedule")
	if not rows.has(npc_id):
		return
	var hour := int(TimeSystem.minute_of_day / 60)
	var entries = rows[npc_id]
	if typeof(entries) != TYPE_ARRAY:
		entries = [entries]
	for entry in entries:
		var row: Dictionary = entry
		if str(row.get("area_id", "")) != GameState.current_area:
			continue
		var start_h := int(row.get("start_hour", "0"))
		var end_h := int(row.get("end_hour", "24"))
		if hour < start_h or hour >= end_h:
			continue
		var point := Vector2(float(row.get("pos_x", "0")), float(row.get("pos_y", "0")))
		position = point
		patrol_start = point - Vector2(35, 0)
		patrol_end = point + Vector2(35, 0)
		return

func _refresh_action_frames() -> void:
	var action := _action_for_activity(get_activity())
	if action == _action_id and not _action_frames.is_empty():
		return
	_action_id = action
	_action_frames = PresentationManager.get_npc_action_frames(npc_id, action)

func _action_for_activity(activity: String) -> String:
	if activity.contains("睡") or activity.contains("收摊回家"):
		return "sleep"
	if activity.contains("吃") or activity.contains("早饭") or activity.contains("晚饭"):
		return "eat"
	if activity.contains("翻") or activity.contains("淘") or activity.contains("补货") or activity.contains("看货"):
		return "pickup"
	if activity.contains("招呼") or activity.contains("聊天") or activity.contains("讲") or activity.contains("散步"):
		return "interact"
	if activity.contains("看店") or activity.contains("带班") or activity.contains("掌勺") or activity.contains("守摊") or activity.contains("摆摊") or activity.contains("帮工") or activity.contains("拍照") or activity.contains("看夜色"):
		return "work"
	return "walk"

func get_activity() -> String:
	var rows := ConfigDB.get_rows("npc_schedule")
	if not rows.has(npc_id):
		return ""
	var hour := int(TimeSystem.minute_of_day / 60)
	var entries = rows[npc_id]
	if typeof(entries) != TYPE_ARRAY:
		entries = [entries]
	for entry in entries:
		var row: Dictionary = entry
		if str(row.get("area_id", "")) == GameState.current_area and hour >= int(row.get("start_hour", "0")) and hour < int(row.get("end_hour", "24")):
			return str(row.get("activity", ""))
	return ""

func _draw() -> void:
	var frames := _action_frames if not _action_frames.is_empty() else _world_frames
	if not frames.is_empty():
		var frame_index := int(floor(_phase / (PI * 0.5))) % frames.size()
		draw_texture_rect(frames[frame_index], Rect2(-16, -42, 32, 48), false)
		return
	var bob := sin(_phase) * 1.4
	draw_ellipse(Vector2(0, 23), 17.0, 7.0, Color(0.02, 0.04, 0.05, 0.36), true)
	draw_rect(Rect2(Vector2(-10, -18 + bob), Vector2(20, 34)), accent_color.darkened(0.25), true)
	draw_circle(Vector2(0, -25 + bob), 10.0, Color("#e4b17c"))
	draw_arc(Vector2(0, -26 + bob), 11.0, PI, TAU, 16, Color("#283a40"), 6.0)
	draw_circle(Vector2(-3, -26 + bob), 1.7, Color("#17242b"))
	draw_circle(Vector2(3, -26 + bob), 1.7, Color("#17242b"))
