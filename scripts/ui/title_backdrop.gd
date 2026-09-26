class_name TitleBackdrop
extends Control

var _phase := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	var canvas := size
	draw_rect(Rect2(Vector2.ZERO, canvas), Color("#0b171c"))
	draw_rect(Rect2(0, canvas.y * 0.58, canvas.x, canvas.y * 0.42), Color("#10252a"))
	for band in range(10):
		var ratio := float(band) / 10.0
		draw_rect(Rect2(0, canvas.y * ratio, canvas.x, canvas.y / 9.0 + 1.0), Color(0.04 + ratio * 0.08, 0.09 + ratio * 0.05, 0.12 + ratio * 0.02, 0.38))
	for index in range(18):
		var width := 58.0 + float((index * 37) % 72)
		var height := 130.0 + float((index * 83) % 210)
		var x := float(index) * 78.0 - 34.0
		var y := canvas.y * 0.64 - height
		var shade := Color("#152b32").lightened(float(index % 3) * 0.035)
		draw_rect(Rect2(x, y, width, height), shade)
		for row in range(3):
			for column in range(2):
				var lit := fmod(float(index * 7 + row * 3 + column), 5.0) > 1.0
				var window_color := Color(1.0, 0.79, 0.38, 0.8 if lit else 0.12)
				draw_rect(Rect2(x + 12 + column * 24, y + 22 + row * 34, 10, 14), window_color)
	draw_rect(Rect2(0, canvas.y * 0.64, canvas.x, 5), Color("#e7b75f"))
	draw_rect(Rect2(0, canvas.y * 0.65, canvas.x, 3), Color(0.91, 0.47, 0.32, 0.72))
	var glow := 0.18 + sin(_phase * 1.2) * 0.04
	draw_circle(Vector2(canvas.x * 0.79, canvas.y * 0.24), 150.0, Color(1.0, 0.68, 0.30, glow))