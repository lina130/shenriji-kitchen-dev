class_name AreaBackdrop
extends Node2D

const ROOM_MAP_SIZE := Vector2(1280, 720)
const CITY_MAP_SIZE := Vector2(3840, 2160)
# The city texture draws a dark frame exactly at these rects; street collisions must use this list only.
const CITY_BOUNDARY_COLLISIONS := [
	Rect2(0.0, 0.0, 3840.0, 44.0),
	Rect2(0.0, 2116.0, 3840.0, 44.0),
	Rect2(0.0, 0.0, 40.0, 2160.0),
	Rect2(3800.0, 0.0, 40.0, 2160.0),
]

var area_id := "home"

var _last_season := ""
var _last_festival := ""
var _background_texture: Texture2D

func configure(value: String) -> void:
	area_id = value
	_background_texture = PresentationManager.get_scene_texture(area_id)
	if not TimeSystem.minute_changed.is_connected(_on_minute_changed):
		TimeSystem.minute_changed.connect(_on_minute_changed)
	queue_redraw()

func _on_minute_changed(_minute_of_day: int) -> void:
	var season := CalendarManager.get_season_id()
	var festival := str(CalendarManager.get_day_of_year()) if CalendarManager.is_festival() else ""
	if season != _last_season or festival != _last_festival:
		_last_season = season
		_last_festival = festival
		queue_redraw()

func _draw() -> void:
	_last_season = CalendarManager.get_season_id()
	_last_festival = str(CalendarManager.get_day_of_year()) if CalendarManager.is_festival() else ""
	if _background_texture != null:
		var map_size := CITY_MAP_SIZE if area_id == "street" else ROOM_MAP_SIZE
		draw_texture_rect(_background_texture, Rect2(Vector2.ZERO, map_size), false)
		if area_id == "home":
			_draw_home_renovation_overlay()
		if area_id == "street":
			_draw_city_continuity_overlay()
		_draw_scene_zones()
		_draw_season_overlay()
		_draw_festival_overlay()
		return
	match area_id:
		"home", "home_living":
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
		"bank":
			_draw_bank()
		"farm":
			_draw_farm()
		"pet_store":
			_draw_pet_store()
		"furniture_store":
			_draw_furniture_store()
		"restaurant":
			_draw_restaurant()
		"wholesale":
			_draw_wholesale()
		"breakfast_shop":
			_draw_breakfast_shoppe()
		"breakfast_kitchen":
			_draw_breakfast_shoppe()
		"commercial_district":
			_draw_commercial_district()
		"industrial_district":
			_draw_industrial_district()
		"suburb":
			_draw_suburb()
		"clothing_store":
			_draw_clothing_store()
		"riverside":
			_draw_riverside()
		_:
			draw_rect(Rect2(0, 0, 1280, 720), Color("#17242b"))
	_draw_season_overlay()
	_draw_festival_overlay()

func _draw_city_continuity_overlay() -> void:
	# Lower-alpha district cues keep the continuous map readable without hiding the base art.
	draw_rect(Rect2(0, 900, 3840, 360), Color(0.06, 0.08, 0.09, 0.14), true)
	draw_rect(Rect2(1560, 0, 260, 2160), Color(0.06, 0.08, 0.09, 0.13), true)
	for x in range(1588, 1810, 52):
		draw_rect(Rect2(x, 0, 22, 2160), Color(0.78, 0.72, 0.52, 0.08), true)
	for y in range(948, 1228, 44):
		draw_rect(Rect2(0, y, 3840, 16), Color(0.78, 0.72, 0.52, 0.07), true)
	draw_rect(Rect2(0, 1800, 3840, 150), Color(0.08, 0.30, 0.40, 0.32), true)
	draw_line(Vector2(0, 1800), Vector2(3840, 1800), Color(0.72, 0.91, 0.88, 0.26), 5.0)
	draw_line(Vector2(0, 1950), Vector2(3840, 1950), Color(0.10, 0.20, 0.22, 0.28), 5.0)
	draw_rect(Rect2(1200, 1320, 900, 780), Color(0.16, 0.48, 0.25, 0.16), true)
	draw_rect(Rect2(2760, 1200, 960, 900), Color(0.22, 0.50, 0.28, 0.12), true)
	for x in range(2200, 3360, 180):
		draw_line(Vector2(x, 100), Vector2(x, 720), Color(0.74, 0.78, 0.74, 0.24), 3.0)
		draw_circle(Vector2(x, 100), 7.0, Color(0.88, 0.82, 0.58, 0.42))
	for y in range(160, 720, 110):
		draw_line(Vector2(2180, y), Vector2(3380, y), Color(0.74, 0.78, 0.74, 0.18), 2.0)
	for index in range(7):
		var x := 1320.0 + float(index) * 150.0
		draw_circle(Vector2(x, 1450.0 + float(index % 2) * 54.0), 32.0, Color(0.24, 0.60, 0.30, 0.22))
		draw_rect(Rect2(x - 5, 1475.0 + float(index % 2) * 54.0, 10, 70), Color(0.33, 0.24, 0.16, 0.34))

func _draw_scene_zones() -> void:
	if OS.get_environment("DEEP_CITY_SHOW_ZONES") != "1":
		return
	if not SceneLayoutManager.has_zones(area_id):
		return
	var font_size := 18 if area_id == "street" else 14
	for zone in SceneLayoutManager.get_zones(area_id):
		var rect: Rect2 = zone.get("rect", Rect2())
		var color := SceneLayoutManager.get_zone_color(str(zone.get("kind", "misc")))
		draw_rect(rect, Color(color.r, color.g, color.b, 0.035), true)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.34), false, 3.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 24), str(zone.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.r, color.g, color.b, 0.78))

func _draw_home_renovation_overlay() -> void:
	match RoomManager.renovation_style:
		"warm_walls":
			draw_rect(Rect2(36, 36, 1208, 648), Color(0.96, 0.58, 0.35, 0.08), true)
			draw_rect(Rect2(54, 48, 1172, 570), Color(1.0, 0.76, 0.42, 0.06), true)
		"bright_window":
			draw_rect(Rect2(60, 60, 1160, 200), Color(0.64, 0.84, 0.94, 0.10), true)
			draw_rect(Rect2(82, 82, 360, 110), Color(0.83, 0.94, 1.0, 0.16), true)
		"quiet_study":
			draw_rect(Rect2(36, 36, 420, 648), Color(0.22, 0.28, 0.38, 0.12), true)
			draw_rect(Rect2(58, 58, 360, 360), Color(0.62, 0.74, 0.84, 0.09), true)
		"family_room":
			draw_rect(Rect2(36, 36, 1208, 648), Color(0.93, 0.62, 0.38, 0.07), true)
			draw_rect(Rect2(470, 310, 520, 330), Color(0.88, 0.42, 0.38, 0.09), true)
			draw_circle(Vector2(640, 500), 150.0, Color(0.98, 0.74, 0.40, 0.05))

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
		if x == 570 or x == 740:
			continue
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
		if x == 600:
			continue
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

func _draw_bank() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#b8c6c5"))
	_draw_floor_grid(Color("#a6b5b5"), 64)
	_draw_walls(Color("#294852"))
	draw_rect(Rect2(80, 80, 260, 80), Color("#527d8d"))
	draw_rect(Rect2(940, 80, 260, 80), Color("#527d8d"))
	draw_rect(Rect2(260, 215, 260, 90), Color("#385f6d"))
	draw_rect(Rect2(760, 215, 260, 90), Color("#8d6a37"))
	draw_rect(Rect2(500, 100, 280, 7), Color("#d6cb83"))
	draw_circle(Vector2(640, 390), 52.0, Color("#7ea6a8"))

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

func _draw_farm() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#5f7d55"))
	_draw_floor_grid(Color(0.28, 0.38, 0.24, 0.32), 64)
	_draw_walls(Color("#2f4a2c"))
	draw_rect(Rect2(80, 90, 340, 90), Color("#7d9c6b"))
	draw_rect(Rect2(860, 90, 340, 90), Color("#7d9c6b"))
	draw_rect(Rect2(80, 560, 420, 90), Color("#4a6b3f"))
	draw_rect(Rect2(780, 560, 420, 90), Color("#4a6b3f"))
	for index in range(FarmManager.PLOT_COUNT):
		var col := index % 3
		var rowi := int(index / 3)
		draw_rect(Rect2(230 + col * 320, 245 + rowi * 180, 180, 110), Color("#8a6242"))

func _draw_pet_store() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#d8c4a6"))
	_draw_floor_grid(Color("#c7b092"), 64)
	_draw_walls(Color("#5a4640"))
	draw_rect(Rect2(90, 120, 300, 100), Color("#c99e8f"))
	draw_rect(Rect2(890, 120, 300, 100), Color("#c99e8f"))
	draw_rect(Rect2(90, 520, 300, 100), Color("#c99e8f"))
	draw_rect(Rect2(890, 520, 300, 100), Color("#c99e8f"))
	for index in range(6):
		draw_rect(Rect2(110 + index * 180, 280, 140, 90), Color("#e6cdb6"))

func _draw_furniture_store() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#cfd4dd"))
	_draw_floor_grid(Color("#bdc4cf"), 64)
	_draw_walls(Color("#3f4a5c"))
	for x in range(120, 1160, 260):
		draw_rect(Rect2(x, 120, 180, 90), Color("#9aa6bb"))
		draw_rect(Rect2(x, 510, 180, 90), Color("#9aa6bb"))
	draw_rect(Rect2(520, 330, 240, 70), Color("#8b95ab"))

func _draw_breakfast_shoppe() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#e7d4ae"))
	_draw_floor_grid(Color("#d6c29c"), 64)
	_draw_walls(Color("#5a4034"))
	draw_rect(Rect2(240, 40, 800, 54), Color("#b8794f"))
	draw_rect(Rect2(60, 420, 250, 110), Color("#c38a55"))
	draw_rect(Rect2(430, 480, 420, 60), Color("#d8b070"))
	draw_circle(Vector2(640, 300), 46.0, Color("#f0e2c2"))

func _draw_commercial_district() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#727b83"))
	draw_rect(Rect2(0, 180, 1280, 360), Color("#3d464d"))
	draw_rect(Rect2(0, 520, 1280, 200), Color("#a68e74"))
	for x in range(40, 1240, 220):
		draw_rect(Rect2(x, 48, 170, 112), Color("#bd7b64"))
		draw_rect(Rect2(x + 18, 72, 134, 64), Color("#e9c17c"))
	for x in range(80, 1240, 180):
		draw_circle(Vector2(x, 120), 18.0, Color("#f0dda2"))
	_draw_walls(Color("#26373f"))

func _draw_industrial_district() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#596168"))
	_draw_floor_grid(Color(0.25, 0.27, 0.29, 0.40), 64)
	draw_rect(Rect2(0, 80, 1280, 140), Color("#394950"))
	for x in range(80, 1220, 260):
		draw_rect(Rect2(x, 100, 180, 90), Color("#7f8b8f"))
		draw_line(Vector2(x + 90, 30), Vector2(x + 90, 100), Color("#3c4a50"), 12.0)
	draw_rect(Rect2(420, 360, 440, 120), Color("#33474f"))
	_draw_walls(Color("#24363d"))

func _draw_suburb() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#80966d"))
	draw_rect(Rect2(0, 200, 1280, 320), Color("#b5aa85"))
	draw_rect(Rect2(0, 520, 1280, 200), Color("#6d8b5d"))
	for index in range(8):
		draw_circle(Vector2(90 + index * 170, 120 + (index % 2) * 36), 48.0, Color("#466b4d"))
		draw_rect(Rect2(83 + index * 170, 150 + (index % 2) * 36, 14, 90), Color("#654a36"))
	_draw_walls(Color("#3f5c42"))

func _draw_clothing_store() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#d8c4be"))
	_draw_floor_grid(Color("#c7b1ad"), 64)
	draw_rect(Rect2(160, 70, 960, 80), Color("#845f66"))
	for x in range(180, 1080, 220):
		draw_rect(Rect2(x, 180, 140, 230), Color("#b7928e"))
		draw_line(Vector2(x + 70, 180), Vector2(x + 70, 410), Color("#e5d6ca"), 4.0)
		draw_circle(Vector2(x + 70, 205), 16.0, Color("#e9d7a4"))
	for index in range(6):
		draw_rect(Rect2(170 + index * 170, 480, 120, 90), Color("#9b8580"))
	_draw_walls(Color("#4b3c41"))

func _draw_wholesale() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#9e9b88"))
	_draw_floor_grid(Color("#898674"), 64)
	_draw_walls(Color("#3f4a49"))
	draw_rect(Rect2(60, 40, 1160, 46), Color("#5e6e6a"))
	draw_rect(Rect2(60, 632, 480, 52), Color("#5e6e6a"))
	draw_rect(Rect2(740, 632, 480, 52), Color("#5e6e6a"))
	for row in range(3):
		for col in range(4):
			var x := 100.0 + float(col) * 290.0
			var y := 120.0 + float(row) * 190.0
			draw_rect(Rect2(x, y, 140, 86), Color("#b88d5f"))
			draw_rect(Rect2(x + 12, y + 12, 116, 62), Color("#d9b574"))

func _draw_restaurant() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#e0c69b"))
	_draw_floor_grid(Color("#cdb185"), 64)
	_draw_walls(Color("#5a4034"))
	draw_rect(Rect2(240, 40, 800, 54), Color("#9d5c45"))
	draw_rect(Rect2(60, 120, 250, 110), Color("#b97958"))
	draw_rect(Rect2(60, 420, 250, 110), Color("#b97958"))
	for index in range(7):
		draw_rect(Rect2(105 + index * 170, 415, 150, 80), Color("#8d6a55"))
	draw_rect(Rect2(510, 525, 260, 70), Color("#d19b5a"))

func _draw_riverside() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#719464"))
	draw_rect(Rect2(0, 300, 1280, 210), Color("#5f9da3"))
	for index in range(10):
		draw_line(Vector2(40 + index * 135, 340 + (index % 3) * 44), Vector2(150 + index * 135, 340 + (index % 3) * 44), Color(0.82, 0.94, 0.91, 0.28), 3.0)
	draw_rect(Rect2(0, 510, 1280, 210), Color("#8d9f6f"))
	for index in range(6):
		var x := 180.0 + float(index) * 190.0
		draw_circle(Vector2(x, 210 + (index % 2) * 70), 58.0, Color("#416b49"))
		draw_rect(Rect2(x - 8, 245 + (index % 2) * 70, 16, 90), Color("#5c4634"))
	draw_rect(Rect2(520, 480, 180, 42), Color("#715b43"))
	draw_rect(Rect2(880, 440, 160, 60), Color("#7d8f8b"))
	draw_line(Vector2(0, 510), Vector2(1280, 510), Color("#d7d3a5"), 5.0)

func _draw_festival_overlay() -> void:
	var decoration := FestivalManager.get_today_decoration()
	if decoration.is_empty():
		return
	match decoration:
		"lanterns", "fireworks", "clock_fireworks":
			_draw_festival_lights(decoration)
		"rain_ribbons":
			for index in range(18):
				var x := float((index * 97 + 40) % 1240)
				var y := float((index * 61 + 50) % 360)
				draw_line(Vector2(x, y), Vector2(x - 22, y + 44), Color(0.62, 0.78, 0.88, 0.32), 2.0)
		"work_flags", "holiday_flags":
			for index in range(10):
				var x := 70.0 + float(index) * 124.0
				draw_line(Vector2(x, 42), Vector2(x, 112), Color(0.61, 0.58, 0.46, 0.72), 3.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x, 48), Vector2(x + 46, 62), Vector2(x, 82)]), Color(0.82, 0.27, 0.23, 0.82))
		"zongzi_leaves":
			for index in range(14):
				var x := 60.0 + float(index) * 88.0
				var y := 90.0 + float(index % 3) * 26.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 34, y + 10), Vector2(x + 10, y + 42)]), Color(0.30, 0.55, 0.31, 0.48))
		"pinwheels":
			for index in range(12):
				var c := Vector2(90.0 + float(index) * 100.0, 95.0 + float(index % 4) * 38.0)
				for petal in range(4):
					var angle := float(petal) * PI * 0.5 + float(index) * 0.07
					draw_line(c, c + Vector2(cos(angle), sin(angle)) * 18.0, Color(0.94, 0.71, 0.21, 0.62), 4.0)
		"sun_coolers":
			draw_circle(Vector2(1080, 110), 74.0, Color(1.0, 0.83, 0.38, 0.16))
			for index in range(8):
				var x := 70.0 + float(index) * 170.0
				draw_rect(Rect2(x, 570, 84, 28), Color(0.39, 0.75, 0.83, 0.42))
				draw_line(Vector2(x + 16, 584), Vector2(x + 68, 584), Color(0.88, 0.98, 1.0, 0.58), 3.0)
		"moon":
			draw_circle(Vector2(1090, 105), 66.0, Color(0.95, 0.91, 0.73, 0.72))
			draw_circle(Vector2(1120, 88), 62.0, Color(0.12, 0.16, 0.21, 0.92))
		"chrysanthemum":
			for index in range(18):
				var c := Vector2(72.0 + float(index) * 70.0, 82.0 + float(index % 4) * 30.0)
				for petal in range(6):
					var angle := float(petal) * PI / 3.0
					draw_circle(c + Vector2(cos(angle), sin(angle)) * 8.0, 5.0, Color(0.95, 0.88, 0.47, 0.56))
				draw_circle(c, 4.0, Color(0.74, 0.53, 0.21, 0.76))
		"shopping":
			for index in range(8):
				var x := 70.0 + float(index) * 160.0
				draw_rect(Rect2(x, 60, 70, 84), Color(0.95, 0.32, 0.52, 0.16), true)
				draw_rect(Rect2(x, 60, 70, 84), Color(0.98, 0.67, 0.83, 0.42), false, 3.0)
		"soup_steam":
			for index in range(10):
				var x := 90.0 + float(index) * 124.0
				draw_arc(Vector2(x, 150), 22.0, PI * 0.85, PI * 1.75, 16, Color(0.91, 0.94, 0.88, 0.30), 3.0)
				draw_arc(Vector2(x + 8, 128), 17.0, PI * 0.75, PI * 1.65, 16, Color(0.91, 0.94, 0.88, 0.22), 2.0)
		_:
			for index in range(16):
				var x := float((index * 83 + 30) % 1240)
				var y := float((index * 47 + 30) % 180)
				draw_circle(Vector2(x, y), 3.0, Color(0.94, 0.78, 0.47, 0.45))

func _draw_festival_lights(decoration: String) -> void:
	for index in range(12):
		var x := 60.0 + float(index) * 108.0
		var y := 54.0 + float(index % 3) * 28.0
		draw_line(Vector2(x, 24), Vector2(x, y), Color(0.55, 0.35, 0.28, 0.55), 2.0)
		draw_circle(Vector2(x, y + 8), 13.0, Color(0.86, 0.24, 0.21, 0.72))
		draw_rect(Rect2(x - 4, y + 19, 8, 13), Color(0.94, 0.71, 0.28, 0.68))
	if decoration != "lanterns":
		for burst in range(5):
			var center := Vector2(160.0 + float(burst) * 245.0, 110.0 + float(burst % 2) * 50.0)
			for ray in range(10):
				var angle := float(ray) * TAU / 10.0
				draw_line(center, center + Vector2(cos(angle), sin(angle)) * 30.0, Color(0.98, 0.78, 0.38, 0.52), 2.0)

func _draw_season_overlay() -> void:
	if area_id == "ruins":
		return
	match CalendarManager.get_season_id():
		"spring":
			for index in range(26):
				var x := float((index * 137 + 40) % 1240)
				var y := float((index * 211 + 70) % 640)
				draw_circle(Vector2(x, y), 3.0, Color(0.98, 0.78, 0.86, 0.55))
		"summer":
			for index in range(6):
				var x := 120.0 + float(index) * 200.0
				draw_circle(Vector2(x, 120.0), 46.0, Color(1.0, 0.94, 0.68, 0.10))
		"autumn":
			for index in range(22):
				var x := float((index * 173 + 60) % 1220)
				var y := float((index * 149 + 180) % 520)
				draw_rect(Rect2(x, y, 9, 5), Color(0.85, 0.52, 0.22, 0.55))
		"winter":
			for index in range(34):
				var x := float((index * 191 + 30) % 1250)
				var y := float((index * 233 + 50) % 660)
				draw_circle(Vector2(x, y), 2.4, Color(0.92, 0.96, 1.0, 0.62))

