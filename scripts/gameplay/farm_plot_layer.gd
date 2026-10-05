extends Node2D

## 农场地块表现层：展示生长阶段、浇水和成熟状态。

func _ready() -> void:
	FarmManager.changed.connect(_on_farm_changed)
	queue_redraw()

func _exit_tree() -> void:
	if FarmManager.changed.is_connected(_on_farm_changed):
		FarmManager.changed.disconnect(_on_farm_changed)

func _on_farm_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if GameState.current_area != "farm":
		return
	var plots := FarmManager.get_all_plots()
	for index in range(plots.size()):
		var plot: Dictionary = plots[index]
		var col := index % 3
		var row := int(index / 3)
		var center := Vector2(600.0 + float(col) * 240.0, 300.0 + float(row) * 170.0)
		_draw_plot(center, plot)

func _draw_plot(center: Vector2, plot: Dictionary) -> void:
	var watered := bool(plot.get("watered", false))
	var stage := str(plot.get("stage", FarmManager.STAGE_EMPTY))
	var soil := Color("#7c5a40") if not watered else Color("#5e4838")
	draw_rect(Rect2(center - Vector2(90, 50), Vector2(180, 100)), soil)
	draw_rect(Rect2(center - Vector2(84, 44), Vector2(168, 88)), Color(0.28, 0.20, 0.15, 0.38), true)
	for line_index in range(5):
		draw_line(center + Vector2(-70, -32 + line_index * 16), center + Vector2(70, -32 + line_index * 16), Color(0.18, 0.13, 0.10, 0.35), 2.0)
	if watered:
		for drop in range(5):
			draw_circle(center + Vector2(-54 + drop * 27, 30), 4.0, Color(0.52, 0.78, 0.90, 0.55))
	if stage == FarmManager.STAGE_EMPTY:
		draw_string(ThemeDB.fallback_font, center + Vector2(-28, 6), "空地", HORIZONTAL_ALIGNMENT_CENTER, 56, 12, Color(0.92, 0.87, 0.72, 0.70))
		return
	var crop_id := str(plot.get("crop_id", ""))
	var progress := float(plot.get("progress", 0.0))
	var ripe := stage == FarmManager.STAGE_RIPE
	var plant_color := _crop_color(crop_id)
	var height := 18.0 + progress * 38.0
	for plant_index in range(4):
		var x := -45.0 + float(plant_index) * 30.0
		draw_line(center + Vector2(x, 24), center + Vector2(x * 0.86, 24 - height), Color("#4f7a45"), 4.0)
		draw_circle(center + Vector2(x * 0.86, 24 - height), 8.0 + progress * 5.0, plant_color)
	if ripe:
		for fruit_index in range(3):
			draw_circle(center + Vector2(-34 + fruit_index * 34, -18), 8.0, Color("#f0c968"))
			draw_circle(center + Vector2(-34 + fruit_index * 34, -18), 3.0, Color(1.0, 0.94, 0.66, 0.85))

func _crop_color(crop_id: String) -> Color:
	match crop_id:
		"tomato_crop":
			return Color("#d66b58")
		"lemon_crop":
			return Color("#e8d05a")
		"tea_crop":
			return Color("#6fa66a")
		"corn_crop":
			return Color("#d8b95d")
		"red_bean_crop":
			return Color("#a76561")
		"flour_wheat":
			return Color("#d8c27a")
	return Color("#70a95d")
