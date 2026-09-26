class_name WeatherEffect
extends Node2D

var _phase := 0.0

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	match WeatherSystem.current_weather_id:
		"rain":
			_draw_rain(Color(0.68, 0.83, 0.9, 0.34))
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.20, 0.27, 0.08))
		"humid":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.45, 0.65, 0.61, 0.055))
			_draw_droplets()
		"heat":
			draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.52, 0.18, 0.07))
			draw_circle(Vector2(1120, 95), 100.0, Color(1.0, 0.73, 0.31, 0.08))
		"overcast":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.20, 0.27, 0.30, 0.07))
		_:
			draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.88, 0.55, 0.018))

func _draw_rain(color: Color) -> void:
	var travel := int(_phase * 520.0)
	for index in range(54):
		var x := float((index * 173 + 37) % 1360) - 40.0
		var y := float((index * 97 + travel) % 820) - 40.0
		draw_line(Vector2(x, y), Vector2(x - 7, y + 18), color, 1.4)
func _draw_droplets() -> void:
	for index in range(28):
		var x := float((index * 211 + 43) % 1230) + 20.0
		var y := float((index * 137 + 61) % 650) + 25.0
		draw_circle(Vector2(x, y), 2.2, Color(0.83, 0.95, 0.92, 0.24))
		draw_line(Vector2(x + 2, y + 3), Vector2(x + 7, y + 10), Color(0.83, 0.95, 0.92, 0.16), 1.0)