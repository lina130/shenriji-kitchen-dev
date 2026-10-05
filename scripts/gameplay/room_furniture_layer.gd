extends Node2D

## 出租屋里的已摆家具。位置和朝向由 RoomManager 保存，场景只负责表现。

var edit_mode := false
var selected_slot := ""

func set_edit_mode(value: bool) -> void:
	edit_mode = value
	queue_redraw()

func set_selected_slot(slot_id: String) -> void:
	selected_slot = slot_id
	queue_redraw()

func _ready() -> void:
	RoomManager.changed.connect(_on_room_changed)
	queue_redraw()

func _exit_tree() -> void:
	if RoomManager.changed.is_connected(_on_room_changed):
		RoomManager.changed.disconnect(_on_room_changed)

func _on_room_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if GameState.current_area != "home":
		return
	for placement in RoomManager.get_placement_lines():
		if str(placement.get("slot", "")).is_empty():
			continue
		var normalized: Vector2 = placement.get("position", Vector2.ZERO)
		var draw_position := Vector2(96.0 + normalized.x * 1088.0, 142.0 + normalized.y * 430.0)
		var rotation := deg_to_rad(float(placement.get("rotation", 0)))
		draw_set_transform(draw_position, rotation, Vector2.ONE)
		_draw_furniture(str(placement.get("id", "")), str(placement.get("name", "")))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if edit_mode:
		_draw_edit_overlay()

func _draw_edit_overlay() -> void:
	for slot_id in RoomManager.get_slot_names():
		if RoomManager.get_owned_for_slot(str(slot_id)).is_empty():
			continue
		var fid := RoomManager.get_furniture_for_slot(str(slot_id))
		var normalized := RoomManager.get_furniture_position(fid) if not fid.is_empty() else RoomManager.get_default_slot_position(str(slot_id))
		var draw_position := Vector2(96.0 + normalized.x * 1088.0, 142.0 + normalized.y * 430.0)
		var selected := selected_slot == str(slot_id)
		var color := Color("#f0c968") if selected else Color(0.74, 0.82, 0.70, 0.62)
		draw_circle(draw_position, 25.0 if selected else 18.0, Color(color, 0.18))
		draw_arc(draw_position, 25.0 if selected else 18.0, 0.0, TAU, 28, color, 3.0)
		draw_circle(draw_position, 5.0, Color(color, 0.9))
		draw_string(ThemeDB.fallback_font, draw_position + Vector2(-40, 36), RoomManager.get_slot_name(str(slot_id)), HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(0.96, 0.93, 0.82, 0.88))

func _draw_furniture(fid: String, display_name: String) -> void:
	match fid:
		"bed_soft":
			_draw_bed()
		"lamp_warm":
			_draw_lamp()
		"rug_wool":
			_draw_rug()
		"shelf_wood":
			_draw_shelf()
		"plant_green":
			_draw_plant()
		"eat_table_small":
			_draw_table()
		"tv_old":
			_draw_tv()
		"aquarium_glass":
			_draw_aquarium()
		"kettle_tea":
			_draw_kettle()
		"cat_tree":
			_draw_cat_tree()
		"desk_old":
			_draw_desk()
		"coffee_table":
			_draw_coffee_table()
		"reading_chair":
			_draw_reading_chair()
		"small_fridge":
			_draw_small_fridge()
		"desk_lamp":
			_draw_desk_lamp()
		"pet_bed":
			_draw_pet_bed()
		"display_cabinet":
			_draw_display_cabinet()
		_:
			_draw_default(display_name)

func _draw_bed() -> void:
	draw_rect(Rect2(-58, -34, 116, 68), Color("#6f4e3d"))
	draw_rect(Rect2(-53, -29, 106, 58), Color("#d9c6a5"))
	draw_rect(Rect2(-47, -23, 42, 36), Color("#f1e1c4"))
	draw_rect(Rect2(6, -23, 36, 46), Color("#9f5d58"))
	draw_line(Vector2(-46, 18), Vector2(45, 18), Color("#c39a77"), 3.0)
	draw_rect(Rect2(-58, 30, 8, 10), Color("#4a352e"))
	draw_rect(Rect2(50, 30, 8, 10), Color("#4a352e"))

func _draw_lamp() -> void:
	draw_circle(Vector2(0, 10), 18.0, Color(1.0, 0.74, 0.36, 0.16))
	draw_line(Vector2(0, 8), Vector2(0, -28), Color("#735343"), 4.0)
	draw_rect(Rect2(-22, -39, 44, 18), Color("#f0b85d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -21), Vector2(20, -21), Vector2(13, -35), Vector2(-13, -35)]), Color("#e8a951"))
	draw_rect(Rect2(-14, -41, 28, 4), Color("#fff0bd"))

func _draw_rug() -> void:
	_draw_ellipse(Vector2.ZERO, Vector2(74, 28), Color("#a76d59"))
	_draw_ellipse(Vector2.ZERO, Vector2(62, 21), Color("#cf9873"))
	draw_line(Vector2(-45, 0), Vector2(45, 0), Color("#f0c993"), 3.0)
	draw_line(Vector2(0, -15), Vector2(0, 15), Color("#f0c993"), 3.0)

func _draw_shelf() -> void:
	draw_rect(Rect2(-34, -48, 68, 96), Color("#664632"))
	draw_rect(Rect2(-28, -42, 56, 24), Color("#d4ad76"))
	draw_rect(Rect2(-28, -8, 56, 20), Color("#d4ad76"))
	draw_rect(Rect2(-28, 22, 56, 18), Color("#d4ad76"))
	draw_rect(Rect2(-18, -36, 11, 18), Color("#6e8c87"))
	draw_rect(Rect2(8, -36, 12, 18), Color("#b36a5b"))
	draw_rect(Rect2(-12, 1, 8, 18), Color("#8e6f9e"))
	draw_rect(Rect2(10, 1, 8, 18), Color("#d4a34b"))

func _draw_plant() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 24), Vector2(22, 24), Vector2(15, 50), Vector2(-15, 50)]), Color("#9a6246"))
	for index in range(5):
		var angle := -1.9 + float(index) * 0.72
		draw_line(Vector2.ZERO, Vector2(cos(angle) * 36.0, sin(angle) * 26.0 - 12.0), Color("#4b8a55"), 7.0)
	draw_circle(Vector2(-12, -30), 12.0, Color("#67a95f"))
	draw_circle(Vector2(14, -34), 11.0, Color("#57934e"))
	draw_circle(Vector2(0, -45), 10.0, Color("#73b66e"))

func _draw_table() -> void:
	draw_rect(Rect2(-50, -24, 100, 44), Color("#8e6848"))
	draw_rect(Rect2(-44, -18, 88, 32), Color("#c79b68"))
	draw_line(Vector2(-40, 20), Vector2(-35, 42), Color("#624a38"), 7.0)
	draw_line(Vector2(40, 20), Vector2(35, 42), Color("#624a38"), 7.0)
	draw_circle(Vector2(0, -2), 12.0, Color("#e3d3ad"))
	draw_circle(Vector2(0, -2), 7.0, Color("#b95e50"))

func _draw_tv() -> void:
	draw_rect(Rect2(-54, -38, 108, 72), Color("#3a4950"))
	draw_rect(Rect2(-45, -30, 90, 52), Color("#547b86"))
	draw_rect(Rect2(-38, -24, 76, 40), Color("#87b3b3"))
	draw_circle(Vector2(36, 21), 4.0, Color("#efb34c"))
	draw_rect(Rect2(-28, 34, 56, 10), Color("#5b4a3e"))

func _draw_aquarium() -> void:
	draw_rect(Rect2(-52, -32, 104, 64), Color("#5d8996"))
	draw_rect(Rect2(-47, -27, 94, 54), Color(0.56, 0.85, 0.91, 0.72))
	draw_circle(Vector2(-22, 5), 7.0, Color("#e7a55d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-22, 5), Vector2(-34, -5), Vector2(-32, 10)]), Color("#e7a55d"))
	draw_circle(Vector2(22, -10), 3.0, Color(0.92, 0.98, 1.0, 0.7))
	draw_circle(Vector2(30, 2), 2.0, Color(0.92, 0.98, 1.0, 0.7))
	draw_line(Vector2(-40, 27), Vector2(40, 27), Color("#a57d5c"), 5.0)

func _draw_kettle() -> void:
	draw_circle(Vector2(0, 8), 28.0, Color("#b36d4d"))
	draw_circle(Vector2(0, 8), 20.0, Color("#d99462"))
	draw_rect(Rect2(-16, -22, 32, 18), Color("#8c5c45"))
	draw_line(Vector2(15, -2), Vector2(39, -13), Color("#8c5c45"), 6.0)
	draw_arc(Vector2(0, -5), 20.0, PI * 0.3, PI * 1.45, 16, Color("#704a39"), 5.0)
	draw_circle(Vector2(0, -27), 3.0, Color(0.98, 0.9, 0.62, 0.78))

func _draw_cat_tree() -> void:
	draw_rect(Rect2(-38, 36, 76, 12), Color("#70513c"))
	draw_rect(Rect2(-8, -30, 16, 66), Color("#c79a68"))
	draw_rect(Rect2(-34, -33, 68, 14), Color("#9f7451"))
	draw_rect(Rect2(-26, 2, 52, 13), Color("#9f7451"))
	draw_circle(Vector2(-22, -26), 9.0, Color("#d7b174"))
	draw_line(Vector2(9, 18), Vector2(9, 38), Color("#d9c69d"), 2.0)

func _draw_desk() -> void:
	draw_rect(Rect2(-54, -20, 108, 38), Color("#8b765b"))
	draw_rect(Rect2(-48, -14, 96, 26), Color("#c5a77b"))
	draw_line(Vector2(-42, 18), Vector2(-39, 42), Color("#614f43"), 7.0)
	draw_line(Vector2(42, 18), Vector2(39, 42), Color("#614f43"), 7.0)
	draw_rect(Rect2(-28, -34, 40, 24), Color("#dcd1ae"))
	draw_line(Vector2(-18, -25), Vector2(2, -25), Color("#55727f"), 2.0)
	draw_line(Vector2(-18, -19), Vector2(-5, -19), Color("#55727f"), 2.0)

func _draw_coffee_table() -> void:
	draw_rect(Rect2(-48, -22, 96, 40), Color("#8c6848"))
	draw_rect(Rect2(-42, -17, 84, 30), Color("#c49a68"))
	draw_line(Vector2(-38, 18), Vector2(-34, 38), Color("#624a38"), 6.0)
	draw_line(Vector2(38, 18), Vector2(34, 38), Color("#624a38"), 6.0)
	draw_circle(Vector2(0, -2), 11.0, Color("#e7d5ae"))
	draw_circle(Vector2(0, -2), 6.0, Color("#a96b4f"))

func _draw_reading_chair() -> void:
	draw_rect(Rect2(-38, -18, 76, 48), Color("#8f6747"))
	draw_rect(Rect2(-32, -13, 64, 36), Color("#c89a6a"))
	draw_rect(Rect2(-42, -52, 84, 38), Color("#7e5a3f"))
	draw_rect(Rect2(-36, -47, 72, 28), Color("#d2aa76"))
	draw_rect(Rect2(-31, 28, 8, 14), Color("#5c4334"))
	draw_rect(Rect2(23, 28, 8, 14), Color("#5c4334"))

func _draw_small_fridge() -> void:
	draw_rect(Rect2(-34, -46, 68, 92), Color("#b9c7c9"))
	draw_rect(Rect2(-29, -41, 58, 82), Color("#e2ece8"))
	draw_line(Vector2(-29, -8), Vector2(29, -8), Color("#6d7f83"), 3.0)
	draw_line(Vector2(19, -35), Vector2(19, -16), Color("#71868b"), 4.0)
	draw_line(Vector2(19, 4), Vector2(19, 28), Color("#71868b"), 4.0)
	draw_rect(Rect2(-25, 30, 20, 9), Color("#79a9c8"))

func _draw_desk_lamp() -> void:
	draw_circle(Vector2(0, 14), 18.0, Color(1.0, 0.75, 0.36, 0.16))
	draw_rect(Rect2(-16, 12, 32, 8), Color("#6a5142"))
	draw_line(Vector2(0, 12), Vector2(0, -30), Color("#735343"), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -24), Vector2(20, -24), Vector2(12, -42), Vector2(-12, -42)]), Color("#f0b85d"))

func _draw_pet_bed() -> void:
	_draw_ellipse(Vector2.ZERO, Vector2(52, 28), Color("#9f7557"))
	_draw_ellipse(Vector2.ZERO, Vector2(43, 21), Color("#e0bea0"))
	draw_circle(Vector2(-16, -2), 7.0, Color("#7f5b49"))
	draw_circle(Vector2(16, -2), 7.0, Color("#7f5b49"))
	draw_circle(Vector2(0, 4), 11.0, Color("#b88768"))

func _draw_display_cabinet() -> void:
	draw_rect(Rect2(-34, -52, 68, 104), Color("#6e5848"))
	draw_rect(Rect2(-28, -46, 56, 42), Color(0.55, 0.74, 0.78, 0.72))
	draw_rect(Rect2(-28, 2, 56, 42), Color(0.55, 0.74, 0.78, 0.72))
	draw_rect(Rect2(-20, -38, 16, 24), Color("#d5aa58"))
	draw_circle(Vector2(12, -24), 10.0, Color("#b46f64"))
	draw_rect(Rect2(-18, 10, 22, 20), Color("#7f9fb0"))
	draw_rect(Rect2(8, 12, 13, 18), Color("#8fbf8f"))

func _draw_default(display_name: String) -> void:
	draw_rect(Rect2(-34, -24, 68, 48), Color("#8c789a"))
	draw_line(Vector2(-25, -14), Vector2(25, -14), Color("#d7c6df"), 3.0)
	if not display_name.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-34, 42), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.96, 0.93, 0.84, 0.78))

func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
