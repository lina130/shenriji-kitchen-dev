extends Node2D

## 后厨工位的程序化表现层：蒸汽、火光、气泡、进度环和完成闪光。
## 正式美术接入前，先把工位状态通过场景画面明确表达出来。

var area_id := ""
var elapsed := 0.0

func configure(value: String) -> void:
	area_id = value
	queue_redraw()

func _ready() -> void:
	KitchenManager.changed.connect(_on_kitchen_changed)
	queue_redraw()

func _exit_tree() -> void:
	if KitchenManager.changed.is_connected(_on_kitchen_changed):
		KitchenManager.changed.disconnect(_on_kitchen_changed)

func _on_kitchen_changed() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if not _location_matches():
		return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if not KitchenManager.active or not _location_matches():
		return
	var stations := KitchenManager.get_stations_status()
	for index in range(stations.size()):
		var station: Dictionary = stations[index]
		var center := Vector2(150.0 + float(index) * 135.0, 455.0)
		var state := str(station.get("state", "idle"))
		if state == "processing":
			_draw_progress_ring(center, float(station.get("progress_ratio", 0.0)), str(station.get("type", "")))
			_draw_station_motion(center, str(station.get("type", "")))
		elif state == "stage_ready":
			_draw_ready_flash(center, Color("#e8c26a"))
		elif state == "ready":
			_draw_ready_flash(center, Color("#73c78a"))
		_draw_upgrade_pips(center, int(station.get("level", 0)), str(station.get("type", "")))
	_draw_combo_trail()

func _draw_upgrade_pips(center: Vector2, level: int, station_type: String) -> void:
	if level <= 0:
		return
	var color := _station_color(station_type)
	var start_x := center.x - 13.0
	for index in range(mini(level, 3)):
		var pip_center := Vector2(start_x + float(index) * 13.0, center.y + 52.0)
		draw_circle(pip_center, 4.5, Color(color, 0.88))
		draw_circle(pip_center, 2.2, Color(1.0, 0.96, 0.74, 0.92))

func _draw_combo_trail() -> void:
	if KitchenManager.combo < 2:
		return
	var visible_combo := mini(KitchenManager.combo, 8)
	var spacing := 24.0
	var start_x := 640.0 - float(visible_combo - 1) * spacing * 0.5
	for index in range(visible_combo):
		var center := Vector2(start_x + float(index) * spacing, 518.0)
		var pulse := 0.55 + 0.45 * sin(elapsed * 6.0 + float(index) * 0.8)
		draw_circle(center, 10.0, Color(0.98, 0.72, 0.28, 0.16 + pulse * 0.12))
		draw_circle(center, 6.0, Color(1.0, 0.88, 0.54, 0.68 + pulse * 0.22))
		draw_circle(center, 2.5, Color(1.0, 0.98, 0.84, 0.92))

func _location_matches() -> bool:
	if area_id == "restaurant":
		return KitchenManager.location_id == "restaurant"
	if area_id == "breakfast_kitchen":
		return KitchenManager.location_id == "breakfast_shop"
	return false

func _draw_progress_ring(center: Vector2, ratio: float, station_type: String) -> void:
	var color := _station_color(station_type)
	draw_arc(center, 76.0, -PI * 0.5, TAU - PI * 0.5, 40, Color(0.04, 0.06, 0.07, 0.62), 9.0)
	draw_arc(center, 76.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 40, color, 7.0)

func _draw_station_motion(center: Vector2, station_type: String) -> void:
	match station_type:
		"steamer":
			for index in range(3):
				var rise := fmod(elapsed * 34.0 + float(index) * 18.0, 54.0)
				var alpha := 0.22 + 0.16 * sin(elapsed * 4.0 + float(index))
				draw_circle(center + Vector2(-16.0 + float(index) * 16.0, -48.0 - rise), 7.0, Color(0.88, 0.96, 0.94, alpha))
		"fryer":
			for index in range(4):
				var sway := sin(elapsed * 8.0 + float(index) * 1.7) * 8.0
				var flame := center + Vector2(-24.0 + float(index) * 16.0 + sway, -6.0 - float((index % 2) * 8))
				draw_colored_polygon(PackedVector2Array([flame + Vector2(-8, 18), flame + Vector2(0, -18), flame + Vector2(8, 18)]), Color(1.0, 0.54, 0.18, 0.55))
		"soup_pot":
			for index in range(2):
				var rise := fmod(elapsed * 26.0 + float(index) * 22.0, 42.0)
				draw_arc(center + Vector2(-14.0 + float(index) * 28.0, -40.0 - rise), 11.0, PI * 0.85, PI * 1.9, 12, Color(0.9, 0.95, 0.86, 0.36), 3.0)
		"drink":
			for index in range(5):
				var bubble_y := fmod(elapsed * 30.0 + float(index) * 11.0, 46.0)
				draw_circle(center + Vector2(-22.0 + float(index) * 11.0, 18.0 - bubble_y), 3.0 + float(index % 2), Color(0.86, 0.96, 1.0, 0.44))
		"prep":
			for index in range(3):
				var slide := sin(elapsed * 7.0 + float(index)) * 14.0
				draw_line(center + Vector2(-30.0 + slide, -18.0 + float(index) * 14.0), center + Vector2(30.0 + slide, -18.0 + float(index) * 14.0), Color(0.95, 0.9, 0.67, 0.34), 3.0)
		"serve":
			draw_circle(center, 48.0 + sin(elapsed * 5.0) * 4.0, Color(1.0, 0.82, 0.42, 0.12))

func _draw_ready_flash(center: Vector2, color: Color) -> void:
	var pulse := 0.5 + 0.5 * sin(elapsed * 7.0)
	draw_circle(center, 45.0 + pulse * 13.0, Color(color, 0.16 + pulse * 0.12))
	draw_arc(center, 62.0, 0.0, TAU, 36, Color(color, 0.72), 4.0)

func _station_color(station_type: String) -> Color:
	match station_type:
		"steamer":
			return Color("#8fd0c3")
		"fryer":
			return Color("#ef8a52")
		"soup_pot":
			return Color("#d2a56e")
		"drink":
			return Color("#7fc4dc")
		"serve":
			return Color("#f0c968")
	return Color("#b9a78a")
