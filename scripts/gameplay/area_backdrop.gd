class_name AreaBackdrop
extends Node2D

var area_id := "home"

func configure(value: String) -> void:
	area_id = value
	queue_redraw()

func _draw() -> void:
	match area_id:
		"home":
			_draw_home()
		"street":
			_draw_street()
		"factory":
			_draw_factory()
		"store":
			_draw_store()
		"recycle":
			_draw_recycle()
		"market":
			_draw_market()
		"park":
			_draw_park()
		"ruins":
			_draw_ruins()
		_:
			draw_rect(Rect2(0, 0, 1280, 720), Color("#17242b"))

func _draw_home() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#c9ad81"))
	_draw_floor_grid(Color("#b89a70"), 64)
	_draw_walls(Color("#4f3f38"))
	draw_rect(Rect2(45, 42, 490, 38), Color("#7d634e"))
	draw_rect(Rect2(74, 62, 250, 6), Color("#dbb886"))
	draw_rect(Rect2(900, 48, 300, 260), Color("#96785e"))
	draw_rect(Rect2(930, 76, 240, 200), Color("#d9c6a5"))
	draw_rect(Rect2(960, 104, 180, 144), Color("#79a7a1"))
	draw_line(Vector2(640, 32), Vector2(640, 688), Color("#8a7158"), 3.0)

func _draw_street() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#5b6262"))
	draw_rect(Rect2(0, 0, 1280, 190), Color("#9b8c78"))
	draw_rect(Rect2(0, 190, 1280, 330), Color("#343c3f"))
	draw_rect(Rect2(0, 520, 1280, 200), Color("#8f8374"))
	for x in range(30, 1280, 92):
		draw_rect(Rect2(x, 342, 48, 8), Color("#d6c387"))
	for x in range(0, 1280, 80):
		draw_line(Vector2(x, 520), Vector2(x, 720), Color(0.25, 0.23, 0.21, 0.35), 2.0)
	draw_rect(Rect2(0, 0, 1280, 34), Color("#263b41"))
	draw_rect(Rect2(0, 686, 1280, 34), Color("#263b41"))
	draw_rect(Rect2(0, 0, 34, 720), Color("#263b41"))
	draw_rect(Rect2(1246, 0, 34, 720), Color("#263b41"))
	for x in range(70, 560, 150):
		draw_rect(Rect2(x, 58, 120, 100), Color("#d3a267"))
		draw_rect(Rect2(x + 16, 82, 88, 76), Color("#42616a"))

func _draw_factory() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#59656a"))
	_draw_floor_grid(Color(0.24, 0.28, 0.30, 0.45), 64)
	_draw_walls(Color("#26383f"))
	for x in range(100, 1180, 240):
		draw_rect(Rect2(x, 110, 130, 90), Color("#77858a"))
		draw_rect(Rect2(x + 18, 130, 94, 50), Color("#2f444c"))
	draw_rect(Rect2(80, 520, 420, 100), Color("#45585e"))
	draw_rect(Rect2(780, 520, 420, 100), Color("#45585e"))
	draw_line(Vector2(90, 150), Vector2(1190, 150), Color("#98a89f"), 4.0)

func _draw_store() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#d5c390"))
	_draw_floor_grid(Color("#c1ad7b"), 64)
	_draw_walls(Color("#25464e"))
	for x in range(60, 1220, 170):
		draw_rect(Rect2(x, 390, 130, 220), Color("#73969a"))
		draw_line(Vector2(x + 16, 420), Vector2(x + 114, 420), Color("#d9eee7"), 5.0)
		draw_line(Vector2(x + 16, 462), Vector2(x + 114, 462), Color("#d9eee7"), 5.0)
		draw_line(Vector2(x + 16, 504), Vector2(x + 114, 504), Color("#d9eee7"), 5.0)
	draw_line(Vector2(34, 200), Vector2(1246, 200), Color("#2f5961"), 4.0)

func _draw_recycle() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#70756c"))
	_draw_floor_grid(Color(0.29, 0.31, 0.29, 0.5), 64)
	_draw_walls(Color("#303b39"))
	for x in range(90, 1160, 260):
		draw_rect(Rect2(x, 100, 150, 110), Color("#62726b"))
		draw_rect(Rect2(x + 18, 118, 110, 72), Color("#384a46"))
	draw_rect(Rect2(70, 410, 300, 180), Color("#59665e"))
	draw_rect(Rect2(910, 410, 300, 180), Color("#59665e"))
	for index in range(6):
		draw_circle(Vector2(125 + index * 48, 465 + (index % 2) * 42), 26.0, Color("#839080"))
	draw_line(Vector2(60, 320), Vector2(1220, 320), Color("#a8aa91"), 4.0)

func _draw_market() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#bc9f78"))
	_draw_floor_grid(Color(0.38, 0.32, 0.25, 0.28), 64)
	_draw_walls(Color("#493c35"))
	for x in range(70, 1240, 220):
		draw_rect(Rect2(x, 70, 170, 110), Color("#d4745f"))
		draw_rect(Rect2(x + 20, 92, 130, 66), Color("#f2d18d"))
	for x in range(100, 1200, 250):
		draw_rect(Rect2(x, 380, 150, 90), Color("#795f45"))
		draw_rect(Rect2(x + 14, 394, 122, 20), Color("#e5bd69"))
	draw_line(Vector2(40, 270), Vector2(1240, 270), Color("#8b6c4d"), 3.0)

func _draw_park() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#5f8666"))
	draw_ellipse(Vector2(640, 390), 270.0, 145.0, Color("#6fa9aa"), true)
	draw_ellipse(Vector2(640, 390), 235.0, 115.0, Color("#82b9b3"), true)
	draw_rect(Rect2(0, 250, 1280, 130), Color("#a7a584"))
	for x in range(80, 1240, 180):
		draw_circle(Vector2(x, 130 + (x % 3) * 30), 44.0, Color("#3e6c52"))
		draw_rect(Rect2(x - 7, 160, 14, 70), Color("#684d39"))
	_draw_walls(Color("#315246"))
func _draw_ruins() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#111b20"))
	_draw_floor_grid(Color(0.18, 0.25, 0.27, 0.35), 72)
	_draw_walls(Color("#081014"))
	for index in range(7):
		var x := 90.0 + index * 180.0
		draw_rect(Rect2(x, 80, 54, 420), Color("#24343a"))
		draw_rect(Rect2(x + 8, 96, 10, 388), Color("#50666b"))
	for index in range(5):
		draw_ellipse(Vector2(170 + index * 250, 610), 82.0, 24.0, Color(0.18, 0.43, 0.48, 0.18), true)
	draw_rect(Rect2(0, 0, 1280, 38), Color("#050b0e"))
	draw_rect(Rect2(0, 682, 1280, 38), Color("#050b0e"))

func _draw_floor_grid(color: Color, step: int) -> void:
	for x in range(0, 1281, step):
		draw_line(Vector2(x, 0), Vector2(x, 720), color, 1.0)
	for y in range(0, 721, step):
		draw_line(Vector2(0, y), Vector2(1280, y), color, 1.0)

func _draw_walls(color: Color) -> void:
	draw_rect(Rect2(0, 0, 1280, 32), color)
	draw_rect(Rect2(0, 688, 1280, 32), color)
	draw_rect(Rect2(0, 0, 32, 720), color)
	draw_rect(Rect2(1248, 0, 32, 720), color)