extends Node2D

## 河边浮漂与咬钩提示。正式美术接入前先把钓鱼时机表达清楚。

var elapsed := 0.0

func _ready() -> void:
	FishingManager.changed.connect(_on_fishing_changed)
	queue_redraw()

func _exit_tree() -> void:
	if FishingManager.changed.is_connected(_on_fishing_changed):
		FishingManager.changed.disconnect(_on_fishing_changed)

func _on_fishing_changed() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if FishingManager.active_cast:
		queue_redraw()

func _draw() -> void:
	if GameState.current_area != "riverside":
		return
	var phase := FishingManager.get_cast_phase()
	if phase == "idle":
		_draw_spot(Vector2(760, 560), Color(0.72, 0.88, 0.86, 0.22))
		return
	var bob := sin(elapsed * 5.0) * (7.0 if phase == "bite" else 2.0)
	var center := Vector2(760, 548 + bob)
	var ring_color := Color("#f0c968") if phase == "bite" else Color(0.72, 0.88, 0.86, 0.55)
	_draw_spot(center, ring_color)
	draw_circle(center, 8.0, Color("#f4f0df"))
	draw_circle(center + Vector2(0, 3), 4.0, Color("#b94f46"))
	if phase == "bite":
		draw_circle(center + Vector2(0, -32), 10.0, Color(1.0, 0.82, 0.36, 0.88))
		draw_rect(Rect2(center.x - 2, center.y - 37, 4, 10), Color("#253238"))

func _draw_spot(center: Vector2, color: Color) -> void:
	for index in range(3):
		var radius := 16.0 + float(index) * 14.0 + sin(elapsed * 2.0 + float(index)) * 2.0
		draw_arc(center, radius, 0.0, TAU, 32, Color(color, color.a * (0.55 - float(index) * 0.12)), 3.0)
