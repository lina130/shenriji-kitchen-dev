class_name TalentParkKitchenView3D
extends Node3D

class DishGlyph:
	extends TextureRect
	var recipe_id := "":
		set(value):
			if recipe_id == value:
				return
			recipe_id = value
			var icon_path := "res://assets/art/ui/tickets_compact/%s.png" % value
			texture = ResourceLoader.load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null

	func _init() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	func _draw() -> void:
		if texture != null:
			return
		var c := size * 0.5
		draw_circle(c + Vector2(1, 2), 39.0, Color("#b7a487"))
		draw_circle(c, 37.0, Color("#f8f1df"))
		draw_arc(c, 35.0, 0.0, TAU, 48, Color("#907860"), 2.8, true)
		match recipe_id:
			"garden_rice_roll":
				for i in range(3):
					var roll := Rect2(c.x - 27 + i * 18, c.y - 20, 16, 40)
					draw_rect(roll, Color("#d9bd8e"))
					draw_rect(roll, Color("#846949"), false, 2.0)
					draw_circle(c + Vector2(-19 + i * 18, -4), 5.0, Color("#5b9b6d"))
					draw_circle(c + Vector2(-19 + i * 18, 8), 4.0, Color("#75af78"))
			"bay_shrimp_roll":
				for i in range(2):
					var roll := Rect2(c.x - 26, c.y - 22 + i * 23, 52, 19)
					draw_rect(roll, Color("#ead7b2"))
					draw_rect(roll, Color("#987554"), false, 2.0)
					draw_arc(c + Vector2(-9 + i * 11, -12 + i * 23), 8.0, -0.5, PI * 1.4, 18, Color("#d86f68"), 5.0, true)
				draw_circle(c + Vector2(19, 14), 4.0, Color("#5f9874"))
			"macao_spice_bun":
				draw_circle(c, 28.0, Color("#8e5c43"))
				draw_circle(c + Vector2(-2, -4), 24.0, Color("#dca875"))
				draw_arc(c, 20.0, -2.5, 0.5, 22, Color("#8d5941"), 4.0, true)
				for p in [Vector2(-11, 8), Vector2(4, 4), Vector2(14, 13)]:
					draw_circle(c + p, 3.5, Color("#5e8264"))
			"morning_egg_bun":
				draw_circle(c, 27.0, Color("#a56e47"))
				draw_circle(c + Vector2(-3, -4), 23.0, Color("#e4b07b"))
				draw_circle(c + Vector2(4, 4), 16.0, Color("#f5ecd0"))
				draw_circle(c + Vector2(5, 3), 9.0, Color("#e7ae3c"))
			"warm_tofu_bowl":
				draw_circle(c, 29.0, Color("#9b7862"))
				draw_circle(c, 25.0, Color("#bb956f"))
				for p in [Vector2(-19, -15), Vector2(1, -17), Vector2(-12, 5), Vector2(8, 3)]:
					draw_rect(Rect2(c + p, Vector2(17, 16)), Color("#f0e9d3"))
				draw_circle(c + Vector2(17, 17), 5.0, Color("#c27d46"))
			"coconut_millet":
				draw_circle(c, 29.0, Color("#a87e5f"))
				draw_circle(c, 25.0, Color("#e6c883"))
				for i in range(13):
					draw_circle(c + Vector2(cos(float(i) * 2.4) * 20.0, sin(float(i) * 2.4) * 19.0), 3.4, Color("#bb8b4f"))
			"harbour_noodles":
				draw_circle(c, 29.0, Color("#6a8178"))
				draw_circle(c, 25.0, Color("#a57455"))
				for i in range(5):
					draw_arc(c + Vector2(0, float(i) * 3 - 6), 20.0 - i * 1.8, 0.3, PI * 1.75, 28, Color("#e1bc79"), 3.5, true)
				draw_circle(c + Vector2(17, -12), 5.0, Color("#5d956a"))
			"chicken_rice":
				draw_circle(c + Vector2(-12, 2), 22.0, Color("#eee6cd"))
				draw_circle(c + Vector2(14, -2), 19.0, Color("#985b3f"))
				draw_circle(c + Vector2(16, -7), 9.0, Color("#c58452"))
				draw_line(c + Vector2(9, 13), c + Vector2(25, 20), Color("#5d865e"), 4.0, true)
			"seaweed_dumpling":
				for i in range(3):
					draw_circle(c + Vector2(-20 + i * 20, 1), 13.0, Color("#d0d39d"))
					draw_arc(c + Vector2(-20 + i * 20, 1), 12.0, 0.0, PI, 20, Color("#5d8d70"), 4.0, true)
			"fruit_ice":
				var cup := PackedVector2Array([c + Vector2(-22, -16), c + Vector2(22, -16), c + Vector2(14, 25), c + Vector2(-14, 25)])
				draw_colored_polygon(cup, Color("#d98996"))
				draw_line(c + Vector2(-22, -16), c + Vector2(22, -16), Color("#815f60"), 4.0, true)
				for p in [Vector2(-15, -18), Vector2(3, -22), Vector2(18, -17)]:
					draw_circle(c + p, 8.0, Color("#df675e") if p.x < 0 else Color("#efb969"))
				draw_line(c + Vector2(13, -31), c + Vector2(21, -3), Color("#609b83"), 3.0, true)
			_:
				draw_circle(c, 25.0, Color("#c19a6e"))

class StationGlyph:
	extends Control
	var action_id := "":
		set(value):
			if action_id == value:
				return
			action_id = value
			var icon_path := "res://assets/art/ui/stations/%s.png" % value
			_icon = ResourceLoader.load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
			queue_redraw()
	var cue := "next"
	var phase := 0.0
	var _icon: Texture2D

	func _process(delta: float) -> void:
		phase += delta
		if visible and cue in ["ready", "waiting", "next"]:
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		if cue == "buffered":
			draw_line(center + Vector2(-7, 0), center + Vector2(-1, 6), Color("#5f8174"), 3.3, true)
			draw_line(center + Vector2(-1, 6), center + Vector2(9, -7), Color("#5f8174"), 3.3, true)
			return
		if _icon == null:
			return
		var scale_factor := 1.0
		if cue == "ready":
			scale_factor += 0.035 * (0.5 + 0.5 * sin(phase * 3.2))
		elif cue == "next":
			scale_factor += 0.018 * (0.5 + 0.5 * sin(phase * 2.3))
		var icon_size := size * scale_factor
		var tint := Color("#fff8e8") if cue == "waiting" else Color.WHITE
		draw_texture_rect(_icon, Rect2(center - icon_size * 0.5, icon_size), false, tint)

class StepRail:
	extends Control
	var steps: Array = []
	var current := 0
	var waiting := false
	var buffered := false
	var phase := 0.0
	var icons: Dictionary = {}
	var _done_tile := StyleBoxFlat.new()
	var _next_tile := StyleBoxFlat.new()
	var _current_tile := StyleBoxFlat.new()

	func _init() -> void:
		for tile in [_done_tile, _next_tile, _current_tile]:
			tile.set_corner_radius_all(7)
		_done_tile.set_border_width_all(1)
		_done_tile.bg_color = Color("#dce9d8")
		_done_tile.border_color = Color("#4a8067")
		_next_tile.set_border_width_all(1)
		_next_tile.bg_color = Color("#e9e4d7")
		_next_tile.border_color = Color("#c9c4b5")
		_current_tile.set_border_width_all(2)
		_current_tile.bg_color = Color("#f9e5b8")

	func set_steps(new_steps: Array, new_current: int, is_waiting: bool, is_buffered: bool) -> void:
		if steps != new_steps:
			steps = new_steps.duplicate()
			icons.clear()
			for action in steps:
				var path := "res://assets/art/ui/stations/%s.png" % str(action)
				if ResourceLoader.exists(path):
					icons[str(action)] = ResourceLoader.load(path) as Texture2D
		current = new_current
		waiting = is_waiting
		buffered = is_buffered
		queue_redraw()

	func _process(delta: float) -> void:
		if visible and not steps.is_empty() and not buffered:
			phase += delta
			queue_redraw()

	func _draw() -> void:
		for i in range(steps.size()):
			var x := float(i) * 41.0
			var done := buffered or i < current
			var now := not buffered and i == current
			var pulse := 0.5 + 0.5 * sin(phase * 3.0)
			var tile := _done_tile if done else (_current_tile if now else _next_tile)
			if now:
				_current_tile.border_color = Color("#b67c48").lerp(Color("#d49b50"), pulse)
			draw_style_box(tile, Rect2(x, 1, 36, 34))
			var icon: Texture2D = icons.get(str(steps[i]))
			if icon != null:
				var tint := Color.WHITE if done or now else Color(0.67, 0.70, 0.67, 0.78)
				draw_texture_rect(icon, Rect2(x + 4, 4, 28, 27), false, tint)
			if done:
				draw_circle(Vector2(x + 31, 7), 5.0, Color("#43755d"))
				draw_line(Vector2(x + 28, 7), Vector2(x + 30, 9), Color.WHITE, 1.5, true)
				draw_line(Vector2(x + 30, 9), Vector2(x + 34, 5), Color.WHITE, 1.5, true)
			if waiting and now:
				draw_circle(Vector2(x + 31, 7), 5.0, Color("#b57342"))
				draw_line(Vector2(x + 31, 7), Vector2(x + 31, 4), Color.WHITE, 1.2, true)
				draw_line(Vector2(x + 31, 7), Vector2(x + 33, 8), Color.WHITE, 1.2, true)
			if i < steps.size() - 1:
				draw_line(Vector2(x + 37, 18), Vector2(x + 40, 18), Color("#a9ad9d"), 1.4, true)

class IngredientCallout:
	extends Control
	var ingredient_id := "":
		set(value):
			if ingredient_id == value:
				return
			ingredient_id = value
			var path := "res://assets/art/ui/ingredients/%s.png" % value
			_icon = ResourceLoader.load(path) as Texture2D if ResourceLoader.exists(path) else null
			queue_redraw()
	var caption := "缺料":
		set(value):
			if caption == value:
				return
			caption = value
			queue_redraw()
	var callout_font: Font
	var _icon: Texture2D

	func _draw() -> void:
		var shell := StyleBoxFlat.new()
		shell.bg_color = Color("#fff6e5")
		shell.border_color = Color("#a96f50")
		shell.set_border_width_all(2)
		shell.set_corner_radius_all(11)
		draw_style_box(shell, Rect2(2, 2, 92, 34))
		draw_colored_polygon(PackedVector2Array([Vector2(42, 35), Vector2(54, 35), Vector2(48, 44)]), Color("#a96f50"))
		draw_colored_polygon(PackedVector2Array([Vector2(44, 34), Vector2(52, 34), Vector2(48, 40)]), Color("#fff6e5"))
		if _icon != null:
			draw_texture_rect(_icon, Rect2(8, 5, 29, 27), false)
		if callout_font != null:
			draw_string(callout_font, Vector2(40, 26), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#744530"))

class RawMark:
	extends Control
	var ingredient_id := "":
		set(value):
			if ingredient_id == value:
				return
			ingredient_id = value
			var icon_path := "res://assets/art/ui/ingredients/%s.png" % value
			_icon = ResourceLoader.load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
			queue_redraw()
	var _icon: Texture2D
	var enough := true
	var used := false
	var via_stock := false
	var warehouse_count := 0
	var count := 0
	var short_name := ""

	func _draw() -> void:
		var c := Vector2(7, 8)
		var needs_fetch := not enough and warehouse_count > 0
		var ink := Color("#71957a") if enough or used else (Color("#b88752") if needs_fetch else Color("#cc775f"))
		var text_ink := Color("#294b3b") if enough or used else (Color("#774526") if needs_fetch else Color("#873c37"))
		var mark_bg := Color("#dce9dc") if used else (Color("#eee2cc") if needs_fetch else Color("#e9e4d4"))
		draw_rect(Rect2(0, 0, 38, 16), mark_bg, true)
		match ingredient_id:
			"leafy_greens", "seaweed", "cucumber":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 3), c + Vector2(-3, -2), c + Vector2(3, -4), c + Vector2(4, 1)]), ink)
				draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), Color("#e4e7c2"), 1.0)
			"fruit", "osmanthus":
				draw_circle(c, 4, Color("#d89969") if enough or used else ink)
				draw_circle(c + Vector2(2, -2), 1.3, Color("#f1d594"))
			"egg", "shrimp", "chicken":
				draw_circle(c, 4.4, Color("#e7d2ad") if enough or used else ink)
				draw_circle(c + Vector2(1, 0), 2.2, Color("#d5956e"))
			"soft_tofu", "yogurt", "ice":
				draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 8)), Color("#e9e5d1") if enough or used else ink, true)
				draw_line(c + Vector2(-3, 1), c + Vector2(3, 1), ink, 1.1)
			"soy_sauce", "spice_oil", "ginger_syrup", "coconut_milk":
				draw_rect(Rect2(c + Vector2(-3, -3), Vector2(6, 8)), Color("#a98b6f") if enough or used else ink, true)
				draw_rect(Rect2(c + Vector2(-2, -5), Vector2(4, 2)), ink, true)
			_:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-4, 3), c + Vector2(-3, -3), c + Vector2(3, -3), c + Vector2(4, 3)]), Color("#d5bb8c") if enough or used else ink)
		if _icon != null:
			draw_rect(Rect2(0, 0, 16, 16), mark_bg, true)
			draw_texture_rect(_icon, Rect2(0, 0, 16, 16), false)
		if used:
			draw_line(c + Vector2(0, 4), c + Vector2(3, 5), Color("#5d9c7d"), 1.6, true)
			draw_line(c + Vector2(3, 5), c + Vector2(6, 0), Color("#5d9c7d"), 1.6, true)
		elif via_stock:
			draw_circle(c + Vector2(4, 4), 2.2, Color("#83b9ac"))
		if not enough and not used:
			draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), ink, 1.6, true)
		var shown := count if not via_stock else maxi(1, count)
		draw_string(get_theme_default_font(), Vector2(17, 12), "%s%d" % [short_name, shown], HORIZONTAL_ALIGNMENT_LEFT, 21, 11, text_ink)

signal action_pressed(action_id: String)
signal ticket_pressed(slot: int)
signal dish_pressed(order_number: int, action_id: String)
signal stock_action_pressed(action_id: String)
signal stock_pressed(stock_id: String)
signal raw_pressed(ingredient_key: String)
signal prep_pressed
signal buffer_pressed(slot: int)
signal shift_requested(mode: String)
signal closing_requested
signal reopen_requested

const INTERACT_LAYER := 1 << 18
const STAGE_Y := 60.0
const FRONT_TABLE_Z := 4.35
const FRONT_TABLE_TOP := 0.722
const GUEST_QUEUE_Z := 5.80
const COMBO_TRAY_X := -0.75
const SINGLE_TRAY_X := 2.20
const HANDOFF_X := 5.18
const STOCK_WELL_X := [-5.65, -3.83]
const TICKET_CARD_WIDTH := 360.0
const SINGLE_TICKET_CARD_WIDTH := 190.0
const TICKET_CARD_HEIGHT := 116.0
const PREP_ACTOR_HOME := Vector3(-7.87, 0, 0.52)
const PREP_ACTOR_AISLE := Vector3(-7.87, 0, -0.45)
const GUEST_SCALES := [0.78, 0.85, 0.93]
const ACTIONS := [
	{"id": "wash", "name": "清洗", "x": -4.2, "z": -2.45, "kind": "wash"},
	{"id": "slice", "name": "切配", "x": 0.0, "z": -2.45, "kind": "slice"},
	{"id": "mix", "name": "搅拌", "x": 4.2, "z": -2.45, "kind": "mix"},
	{"id": "marinate", "name": "腌制", "x": -4.2, "z": -0.10, "kind": "marinate"},
	{"id": "portion", "name": "分装", "x": 0.0, "z": -0.10, "kind": "portion"},
	{"id": "garnish", "name": "点缀", "x": 4.2, "z": -0.10, "kind": "garnish"},
	{"id": "steam", "name": "蒸制", "x": -4.2, "z": 2.25, "kind": "steam"},
	{"id": "fry", "name": "煎制", "x": 0.0, "z": 2.25, "kind": "fry"},
	{"id": "boil", "name": "煮制", "x": 4.2, "z": 2.25, "kind": "boil"},
	{"id": "serve", "name": "交餐", "x": 4.8, "z": 1.55, "kind": "serve"}
]
const HEAT_ACTIONS := ["steam", "fry", "boil"]
const STOCK_FALLBACK := [
	{"id": "rice_batter", "name": "米浆底料", "count": 0},
	{"id": "spice_oil", "name": "香料油", "count": 0},
	{"id": "reserve", "name": "空器皿", "count": 0}
]
const RAW_GROUP_ORDER := ["staples", "fresh", "protein", "pantry"]
const RAW_GROUP_LABELS := {"staples": "米面主食", "fresh": "蔬果鲜料", "protein": "蛋白食材", "pantry": "调味冷藏"}
const RAW_GROUP_COLORS := {"staples": Color("#d4b37b"), "fresh": Color("#8eae7d"), "protein": Color("#cb8f7d"), "pantry": Color("#9db7b4")}
const INGREDIENT_LABELS := {
	"rice_flour": "米粉", "soft_bun": "面包", "millet": "小米", "noodles": "面条", "rice": "米饭",
	"leafy_greens": "青菜", "cucumber": "黄瓜", "fruit": "水果", "seaweed": "海苔", "osmanthus": "桂花",
	"chicken": "鸡肉", "egg": "鸡蛋", "soft_tofu": "豆花", "shrimp": "鲜虾", "yogurt": "酸奶",
	"soy_sauce": "酱油", "spice_oil": "香料油", "ginger_syrup": "姜汁", "coconut_milk": "椰奶", "ice": "冰块"
}
const INGREDIENT_SHORT := {
	"rice_flour": "米", "soft_bun": "包", "millet": "粟", "noodles": "面", "rice": "饭",
	"leafy_greens": "菜", "cucumber": "瓜", "fruit": "果", "seaweed": "苔", "osmanthus": "桂",
	"chicken": "鸡", "egg": "蛋", "soft_tofu": "豆", "shrimp": "虾", "yogurt": "乳",
	"soy_sauce": "酱", "spice_oil": "香", "ginger_syrup": "姜", "coconut_milk": "椰", "ice": "冰"
}
const STAGE_FOOD := {
	"wash": "washed_greens", "slice": "chopped_ingredients",
	"mix": "rice_batter_bowl", "marinate": "spice_jar",
	"portion": "finished_serving_tray", "steam": "steamer_rice_roll",
	"fry": "pan_seared_chicken", "boil": "boiling_noodles",
	"garnish": "garnish_kit"
}
const TICKET_LANE_COLORS := [Color("#74aaa1"), Color("#c78d79"), Color("#b5a45f")]
const STATION_TOP_COLORS := {
	"wash": Color("#bed0c7"), "slice": Color("#d5b990"),
	"mix": Color("#d9cbaa"), "marinate": Color("#cfb7a5"),
	"portion": Color("#c8cdbc"), "steam": Color("#d8c496"),
	"fry": Color("#c9bfaf"), "boil": Color("#bdcbc8"),
	"garnish": Color("#cad2bd"), "serve": Color("#d8c6a8")
}
const STOCK_SLOT_POINTS := [
	Vector2(-0.37, 0.34), Vector2(0.37, 0.34),
	Vector2(-0.37, -0.34), Vector2(0.37, -0.34)
]

var camera: Camera3D
var _camera_focus := Vector3(-1.10, 0.786, -0.146)
var _camera_yaw := 0.0
var _camera_pitch := 1.187
var _camera_distance := 21.13
var _playful_font: Font
var _dragging_kitchen := false
var _left_press_active := false
var _left_press_position := Vector2.ZERO
var _left_press_target: Area3D
var _stage: Node3D
var _hud_root: Control
var _customer_cards: Array[PanelContainer] = []
var _customer_card_contents: Array[Control] = []
var _customer_card_hit_buttons: Array[Button] = []
var _customer_trays: Array[PanelContainer] = []
var _customer_names: Array[Label] = []
var _customer_times: Array[Label] = []
var _customer_bars: Array[ProgressBar] = []
var _customer_food_buttons: Array[Array] = []
var _customer_food_icons: Array[Array] = []
var _customer_food_names: Array[Array] = []
var _customer_food_stage_labels: Array[Array] = []
var _customer_food_marks: Array[Array] = []
var _customer_food_steps: Array[Array] = []
var _customer_food_ingredients: Array[Array] = []
var _customer_food_slots: Array[Array] = []
var _last_ticket_pointer_msec := -1000
var _last_ticket_pointer_slot := -1
var _ticket_visual_stages: Dictionary = {}
var _customer_tray_dividers: Array[ColorRect] = []
var _customer_card_accents: Array[ColorRect] = []
var _ticket_row: HBoxContainer
var _waiting_ticket_row: HBoxContainer
var _stock_areas: Array[Area3D] = []
var _raw_areas: Dictionary = {}
var _pantry_raw_models: Dictionary = {}
var _pantry_prep_models: Dictionary = {}
var _raw_need_viewports: Dictionary = {}
var _pantry_prep_counts: Dictionary = {}
var _pantry_mark_anchors: Dictionary = {}
var _pantry_refill_plaques: Dictionary = {}
var _raw_bin_units: Dictionary = {}
var _raw_bin_lamps: Dictionary = {}
var _raw_bin_pips: Dictionary = {}
var _raw_need_bubbles: Dictionary = {}
var _raw_need_callouts: Dictionary = {}
var _prep_area: Area3D
var _prep_capacity_pegs: Array[MeshInstance3D] = []
var _prep_pickup_lamp: MeshInstance3D
var _prep_slot_models: Array[Node3D] = []
var _prep_slot_wells: Array[MeshInstance3D] = []
var _prep_slot_pips: Array[Array] = []
var _prep_receive_bubble: Node3D
var _prep_receive_goods: Node3D
var _prep_counter_face: MeshInstance3D
var _stock_cargo: Array[Node3D] = []
var _stock_visual_counts: Array[int] = [-1, -1, -1]
var _stock_unit_visuals: Array[Array] = []
var _stock_unit_rings: Array[Array] = []
var _stock_halos: Array[MeshInstance3D] = []
var _station_halos: Dictionary = {}
var _station_focus_props: Dictionary = {}
var _station_focus_lights: Dictionary = {}
var _steam_puffs: Array[MeshInstance3D] = []
var _charred_food: Array[MeshInstance3D] = []
var _guest_pivots: Array[Node3D] = []
var _guest_models: Array[Node3D] = []
var _guest_current_ids: Array[int] = [-1, -1, -1]
var _guest_hats: Array[Array] = []
var _guest_speech: Array[Label3D] = []
var _guest_areas: Array[Area3D] = []
var _guest_order_cards: Array[Node3D] = []
var _guest_card_marks: Array[MeshInstance3D] = []
var _guest_active: Array[bool] = [false, false, false]
var _guest_joy: Array[Node3D] = []
var _guest_frustration: Array[Node3D] = []
var _prep_actor: Node3D
var _pickup_actor: Node3D
var _prep_cargo: Node3D
var _pickup_cargo: Node3D
var _prep_motion: Tween
var _pickup_motion: Tween
var _station_animated: Dictionary = {}
var _station_worktops: Dictionary = {}
var _steam_fixture: Node3D
var _ticket_food: Array[Node3D] = []
var _ticket_food_areas: Array[Area3D] = []
var _stock_food_area: Area3D
var _ticket_food_keys: Array[String] = ["", "", ""]
var _process_hold_slots: Dictionary = {}
var _process_hold_stock: Dictionary = {}
var _process_serial := 0
var _ticket_heat_fx: Array[Node3D] = []
var _ticket_heat_puffs: Array[Array] = []
var _ticket_heat_marks: Array[Array] = []
var _ticket_heat_phase: Array[int] = [0, 0, 0]
var _stock_food: Node3D
var _stock_food_key := ""
var _heat_lights: Dictionary = {}
var _station_ingredients: Dictionary = {}
var _steam_by_station: Dictionary = {}
var _station_status_lamps: Dictionary = {}
var _station_done_until: Dictionary = {}
var _station_wrong_until: Dictionary = {}
var _station_heating: Dictionary = {}
var _fill_lights: Array[OmniLight3D] = []
var _service_lights: Array[OmniLight3D] = []
var _task_lights: Array[OmniLight3D] = []
var _night_side_lights: Array[OmniLight3D] = []
var _pantry_sconce_lights: Array[OmniLight3D] = []
var _pantry_sconce_glows: Array[MeshInstance3D] = []
var _front_station_lights: Array[OmniLight3D] = []
var _prep_table_lights: Array[OmniLight3D] = []
var _front_lamp_glows: Array[MeshInstance3D] = []
var _service_glows: Array[MeshInstance3D] = []
var _window_day: Node3D
var _window_dawn: Node3D
var _window_dusk: Node3D
var _window_evening: Node3D
var _window_meshes: Dictionary = {}
var _sunset_bounce: OmniLight3D
var _night_window_fill: OmniLight3D
var _window_beam: DirectionalLight3D
var _kitchen_environment: Environment
var _buffer_dishes: Array[Node3D] = []
var _buffer_areas: Array[Area3D] = []
var _buffer_rings: Array[MeshInstance3D] = []
var _buffer_keys: Array[String] = ["", "", ""]
var _shift_areas: Array[Area3D] = []
var _shift_halos: Array[MeshInstance3D] = []
var _shift_bells: Array[MeshInstance3D] = []
var _next_shift_mode := "calm"
var _clock_hour_hand: Node3D
var _clock_minute_hand: Node3D
var _period_lamps: Array[MeshInstance3D] = []
var _dish_display: Node3D
var _finished_dish_area: Area3D
var _finished_dish_glow: MeshInstance3D
var _finished_dish_glow_material: ShaderMaterial
var _finished_dish_spot: SpotLight3D
var _finished_dish_bulb: MeshInstance3D
var _finished_dish_sparkles: Array[Node3D] = []
var _finished_dish_arrival := 0.0
var _handoff_display: Node3D
var _handoff_active := false
var _display_recipe_id := ""
var _patience: ProgressBar
var _heat: ProgressBar
var _progress_panel: PanelContainer
var _patience_label: Label
var _heat_label: Label
var _combo_label: Label
var _cash_label: Label
var _volume_slider: HSlider
var _volume_button: Button
var _volume_preview_at := 0
var _register_drawer: Node3D
var _register_lamp: MeshInstance3D
var _register_motion: Tween
var _register_receipt: Node3D
var _closing_sign_area: Area3D
var _closing_sign_label: Label3D
var _settlement_overlay: ColorRect
var _rotate_overlay: ColorRect
var _settlement_title: Label
var _settlement_stats: Label
var _step_count_label: Label
var _step_rail: StepRail
var _step_action_label: Label
var _status_label: Label
var _rush_label: Label
var _rush_bar: ProgressBar
var _serve_bell: MeshInstance3D
var _pause_label: Label
var _tutorial_label: Label
var _tutorial_panel: PanelContainer
var _clock_label: Label
var _state: Dictionary = {}
var _pantry_state_initialized := false
var _last_missing_prep_keys: Array[String] = []
var _box_meshes: Dictionary = {}
var _cylinder_meshes: Dictionary = {}
var _sphere_meshes: Dictionary = {}
var _capsule_meshes: Dictionary = {}
var _pantry_marks_last_camera := Transform3D()
var _pantry_marks_last_viewport := Vector2.ZERO
var _pantry_marks_positioned := false
var _pantry_projection_updates := 0
var _hovered: Area3D
var _cash := 0
var _interaction_enabled := true
var _feedback_serial := 0
var _last_attempted_action := ""
var _steam_clock := 0.0
var _angry_guest_slot := -1
var _angry_left := 0.0


func _ready() -> void:
	name = "TalentParkKitchenView"
	_playful_font = load("res://assets/art/fonts/LXGWWenKaiLite-Medium.ttf") as Font
	_build_stage()
	_build_hud()
	get_window().size_changed.connect(_update_mobile_orientation)
	_update_mobile_orientation()
	show_state({})


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _process(delta: float) -> void:
	_steam_clock += delta
	_angry_left = maxf(0.0, _angry_left - delta)
	if _angry_left <= 0.0:
		_angry_guest_slot = -1
	for i in range(_steam_puffs.size()):
		var puff := _steam_puffs[i]
		if puff.visible:
			puff.position.y = float(puff.get_meta("base_y", puff.position.y)) + sin(_steam_clock * 1.7 + float(i) * 1.8) * 0.075
	for action in _station_heating.keys():
		if not bool(_station_heating[action]):
			continue
		var part = _station_animated.get(action)
		if part is MeshInstance3D:
			(part as MeshInstance3D).rotation.y = sin(_steam_clock * 4.8 + float(action.length())) * 0.035
	for prop in _station_focus_props.values():
		if prop is Node3D:
			var device := prop as Node3D
			var focused := bool(device.get_meta("next_action", false))
			var pulse := 1.13 + sin(_steam_clock * 3.0) * 0.018 if focused else 1.0
			device.scale = Vector3.ONE * pulse
			# Grow around the worktop height so pans and ingredients stay seated in
			# their vessels instead of visibly floating above the counter.
			device.position.y = 0.84 * (1.0 - pulse) + 0.012 + sin(_steam_clock * 3.0) * 0.008 if focused else 0.0
	for focus_light in _station_focus_lights.values():
		if focus_light is OmniLight3D and (focus_light as OmniLight3D).visible:
			(focus_light as OmniLight3D).light_energy = 0.27 + sin(_steam_clock * 3.0) * 0.035
	_finished_dish_arrival = maxf(0.0, _finished_dish_arrival - delta * 2.0)
	if is_instance_valid(_finished_dish_spot):
		_finished_dish_spot.light_energy = (0.43 if _finished_dish_glow.visible else 0.29) + sin(_steam_clock * 2.7) * (0.018 if _finished_dish_glow.visible else 0.006) + _finished_dish_arrival * 0.12
	if is_instance_valid(_finished_dish_glow) and _finished_dish_glow.visible:
		_dish_display.scale = Vector3.ONE * (1.0 + sin(_steam_clock * 2.7) * 0.025 + _finished_dish_arrival * 0.13)
		_finished_dish_glow_material.set_shader_parameter("strength", 0.82 + sin(_steam_clock * 2.7) * 0.08 + _finished_dish_arrival * 0.25)
		for i in range(_finished_dish_sparkles.size()):
			var sparkle := _finished_dish_sparkles[i]
			sparkle.position.y = FRONT_TABLE_TOP + 0.17 + sin(_steam_clock * 2.1 + float(i) * 1.8) * 0.045
			sparkle.scale = Vector3.ONE * (0.76 + sin(_steam_clock * 3.0 + float(i) * 1.6) * 0.16 + _finished_dish_arrival * 0.30)
	for plaque in _pantry_refill_plaques.values():
		var plaque_material := (plaque as MeshInstance3D).material_override as StandardMaterial3D
		if plaque_material.emission_enabled:
			plaque_material.emission_energy_multiplier = 0.16 + 0.07 * sin(_steam_clock * 3.0)
	for i in range(_shift_bells.size()):
		var bell := _shift_bells[i]
		var ready := i < _shift_areas.size() and _shift_areas[i].collision_layer != 0
		var selected := _next_shift_mode == ("calm" if i == 0 else "rush")
		var sway := sin(_steam_clock * 2.0 + float(i) * 0.7) * (0.065 if selected else 0.025)
		bell.scale = Vector3(1.0 + sway, 0.65, 1.0 + sway) if ready else Vector3(1.0, 0.65, 1.0)
	for bubble in _raw_need_bubbles.values():
		if is_instance_valid(bubble) and bubble.visible:
			bubble.scale = Vector3.ONE * (1.0 + 0.045 * sin(_steam_clock * 2.6))
	if is_instance_valid(_prep_receive_bubble) and _prep_receive_bubble.visible:
		_prep_receive_bubble.scale = Vector3.ONE * (1.0 + 0.045 * sin(_steam_clock * 2.6 + 1.2))
	_animate_ticket_heat()
	for i in range(_guest_models.size()):
		var base := float(GUEST_SCALES[i])
		_guest_models[i].scale = Vector3(base * 0.76, base * (1.0 + sin(_steam_clock * 1.8 + float(i) * 1.3) * 0.015), base * 0.80)
	if is_instance_valid(_prep_actor):
		var prep_walking := is_instance_valid(_prep_motion) and _prep_motion.is_running()
		_prep_actor.scale.y = 1.0 + sin(_steam_clock * (12.0 if prep_walking else 1.7)) * (0.035 if prep_walking else 0.012)
		_prep_actor.rotation.z = sin(_steam_clock * 11.0) * 0.035 if prep_walking else 0.0
	if is_instance_valid(_pickup_actor):
		var pickup_walking := is_instance_valid(_pickup_motion) and _pickup_motion.is_running()
		_pickup_actor.scale.y = 1.0 + sin(_steam_clock * (11.4 if pickup_walking else 1.6) + 1.2) * (0.035 if pickup_walking else 0.012)
		_pickup_actor.rotation.z = sin(_steam_clock * 10.4 + 0.7) * 0.035 if pickup_walking else 0.0
	for slot in range(_ticket_food_areas.size()):
		_ticket_food_areas[slot].position = _ticket_food[slot].position + Vector3(0, 0.36, 0)
	if is_instance_valid(_stock_food_area):
		_stock_food_area.position = _stock_food.position + Vector3(0, 0.36, 0)
	_position_pantry_screen_marks()


func show_state(snapshot: Dictionary) -> void:
	# Restaurant.snapshot() already owns a fresh public value tree. Keeping it
	# avoids another deep copy on every displayed second and every click.
	var previous_state := _state
	var pantry_changed: bool = not _pantry_state_initialized or previous_state.get("raw_ingredients", {}) != snapshot.get("raw_ingredients", {}) or previous_state.get("prep_ingredients", {}) != snapshot.get("prep_ingredients", {})
	var service_changed: bool = previous_state.is_empty() or previous_state.get("active", null) != snapshot.get("active", null) or previous_state.get("stage", null) != snapshot.get("stage", null) or previous_state.get("endless", null) != snapshot.get("endless", null)
	_state = snapshot
	var missing_prep_keys := _missing_prep_keys()
	pantry_changed = pantry_changed or missing_prep_keys != _last_missing_prep_keys
	_last_missing_prep_keys = missing_prep_keys
	_refresh_tickets()
	_refresh_stock()
	if pantry_changed:
		_refresh_fixed_pantry()
		_pantry_state_initialized = true
	_refresh_progress()
	_refresh_station_hint()
	_refresh_dish_display()
	_refresh_process_food()
	_refresh_buffer()
	if service_changed:
		_refresh_tutorial()
		_refresh_settlement()
	_refresh_scene_clock()


func set_clock_minutes(minutes: float) -> void:
	# The rules engine only emits a full ticket snapshot when its displayed
	# second changes. Sample its clock more often so lighting also moves while
	# the kitchen is idle and between ticket updates.
	_state["clock_minutes"] = minutes
	_refresh_scene_clock()


func set_cash(value: int) -> void:
	_cash = maxi(0, value)
	if is_instance_valid(_cash_label):
		_cash_label.text = "%d 贝" % _cash


func set_next_shift_mode(mode: String) -> void:
	_next_shift_mode = mode if mode in ["calm", "rush"] else "calm"
	for i in range(_shift_bells.size()):
		var selected := _next_shift_mode == ("calm" if i == 0 else "rush")
		var material := _shift_bells[i].material_override as StandardMaterial3D
		material.albedo_color = (Color("#a8c8a1") if i == 0 else Color("#db9b7c")) if selected else Color("#a8a39a")
		material.emission_enabled = selected
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.18 if selected else 0.0


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if is_instance_valid(_pause_label):
		_pause_label.visible = not enabled
	for i in range(_customer_food_buttons.size()):
		var slots: Array = _customer_food_slots[i]
		for dish_index in range(_customer_food_buttons[i].size()):
			var button: Button = _customer_food_buttons[i][dish_index]
			button.disabled = not enabled or dish_index >= slots.size() or int(slots[dish_index]) < 0
	if not enabled:
		_set_hover(null)


func show_feedback(result: Dictionary) -> void:
	var event := str(result.get("event", ""))
	var earned := maxi(0, int(result.get("earned", 0)))
	var success := bool(result.get("ok", false))
	var message := str(result.get("message", "继续操作"))
	# Keep ingredient guidance inside the meal ticket; native hover tooltips
	# become black system boxes and obscure the kitchen.
	_set_overcooked_visual(event == "overcooked")
	if event == "overcooked":
		_angry_guest_slot = _guest_index_for_customer(int(result.get("customer_id", -1)))
		_angry_left = 2.8
		if _angry_guest_slot >= 0 and _angry_guest_slot < _guest_pivots.size():
			var guest := _guest_pivots[_angry_guest_slot]
			guest.rotation.z = 0.11
			guest.create_tween().tween_property(guest, "rotation", Vector3.ZERO, 0.54).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if earned > 0 and is_instance_valid(_serve_bell):
		_serve_bell.scale = Vector3.ONE * 1.38
		var bell_tween := create_tween()
		bell_tween.tween_property(_serve_bell, "scale", Vector3.ONE, 0.52).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_animate_earnings(earned, 0 if event == "served_combo" else (int(result.get("buffer_slot", -1)) if bool(result.get("from_buffer", false)) else -1))
	if success and event in ["step_done", "heat_ready", "stock_prepared"]:
		var completed_action := str(result.get("action_id", ""))
		if completed_action == "heat_ready":
			completed_action = _last_heating_action(int(result.get("ticket_slot", 0)))
		if completed_action != "":
			_station_done_until[completed_action] = Time.get_ticks_msec() + 1250
			_pulse_station_lamp(completed_action)
	if event in ["wrong_action", "still_heating", "overcooked"]:
		var warning_action := _last_attempted_action if event == "wrong_action" else _last_heating_action(int(result.get("ticket_slot", 0)))
		if event == "overcooked":
			warning_action = str(result.get("action_id", ""))
		if warning_action != "":
			_station_wrong_until[warning_action] = Time.get_ticks_msec() + 1050
			_pulse_station_lamp(warning_action)
			var visible_tickets: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
			_refresh_station_activity(visible_tickets)
	if event in ["choose_food", "start_or_choose_food"]:
		_pulse_station_lamp(_last_attempted_action)
		for slot in range(_ticket_food_areas.size()):
			if str(_ticket_food_areas[slot].get_meta("action", "")) != _last_attempted_action:
				continue
			var food := _ticket_food[slot]
			if not food.visible:
				continue
			var home_scale: Vector3 = food.scale
			food.scale = home_scale * 1.18
			food.create_tween().tween_property(food, "scale", home_scale, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play_world_feedback(result)
	_feedback_serial += 1
	_clear_feedback_later(_feedback_serial)


func _clear_feedback_later(serial: int) -> void:
	await get_tree().create_timer(2.8).timeout
	if serial == _feedback_serial:
		_set_overcooked_visual(false)
		_refresh_progress()
		_refresh_station_hint()


func _last_heating_action(slot: int) -> String:
	var tickets: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
	if slot < 0 or slot >= tickets.size() or not tickets[slot] is Dictionary:
		return ""
	var ticket: Dictionary = tickets[slot]
	var steps: Array = ticket.get("steps", []) if ticket.get("steps", []) is Array else []
	var index := int(ticket.get("step_index", 0)) if float(ticket.get("heat_left", 0.0)) > 0.0 else int(ticket.get("step_index", 0)) - 1
	return str(steps[index]) if index >= 0 and index < steps.size() else ""


func _pulse_station_lamp(action: String) -> void:
	var lamp = _station_status_lamps.get(action)
	if lamp is MeshInstance3D:
		var visual := lamp as MeshInstance3D
		visual.scale = Vector3(1.45, 0.55, 1.45)
		visual.create_tween().tween_property(visual, "scale", Vector3(1.0, 0.42, 1.0), 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_overcooked_visual(active: bool) -> void:
	for puff in _steam_puffs:
		var material := puff.material_override as StandardMaterial3D
		material.albedo_color = Color("#605b57") if active else Color("#d9dfd2")
	for food in _charred_food:
		food.visible = active


func _play_world_feedback(result: Dictionary) -> void:
	var event := str(result.get("event", ""))
	var action := str(result.get("action_id", ""))
	var slot := clampi(int(result.get("ticket_slot", _state.get("selected_slot", 0))), 0, 2)
	if event == "step_done" and action in ["wash", "slice", "mix"]:
		_animate_prep_process(result, action)
	elif _station_animated.has(action):
		_animate_station(action)
	if event in ["step_done", "stock_prepared", "stock_used"] and (str(result.get("target", "")) == "stock" or str(result.get("stock_id", "")) != "" or action in ["wash", "slice", "mix", "marinate", "portion"]):
		_animate_prep_actor(action, str(result.get("stock_id", "")))
	if event in ["stock_prepared", "stock_used"]:
		_animate_stock_transfer(result)
	if event == "raw_restocked":
		_animate_raw_restock(str(result.get("group_id", "")))
	elif event == "raw_staged":
		_animate_raw_staged(str(result.get("ingredient_key", "")))
	elif event == "raw_picked":
		_animate_raw_pick(str(result.get("group_id", "")))
	elif event == "raw_placed":
		_animate_raw_place()
	elif event == "prep_cleared":
		_animate_prep_clear()
	if event == "served_combo":
		var recipe_ids: Array = result.get("recipe_ids", []) if result.get("recipe_ids", []) is Array else []
		_animate_pickup_actor(slot, "", 0, recipe_ids)
	elif event == "served":
		_animate_pickup_actor(slot, str(result.get("recipe_id", "")), int(result.get("buffer_slot", -1)) if bool(result.get("from_buffer", false)) else -1)
	elif event == "buffer_spoiled":
		var spoiled_slot := int(result.get("buffer_slot", -1))
		if spoiled_slot >= 0 and spoiled_slot < _buffer_rings.size():
			var ring := _buffer_rings[spoiled_slot]
			ring.visible = true
			var material := ring.material_override as StandardMaterial3D
			material.albedo_color = Color("#be7767")
			ring.create_tween().tween_property(ring, "scale", Vector3.ONE * 0.35, 0.35).set_trans(Tween.TRANS_BOUNCE)
	elif event in ["wrong_action", "overcooked", "order_expired"]:
		_show_guest_emotion(_guest_index_for_customer(int(result.get("customer_id", -1))), false)
	elif event == "heat_ready":
		for puff in _steam_puffs:
			puff.scale = Vector3.ONE * 1.25
			puff.create_tween().tween_property(puff, "scale", Vector3.ONE, 0.60)


func _animate_station(action: String) -> void:
	var part = _station_animated.get(action)
	if not part is MeshInstance3D:
		return
	var visual := part as MeshInstance3D
	var home_position := visual.position
	var home_rotation := visual.rotation
	var destination := home_position
	var tilt := home_rotation
	match action:
		"wash": destination.y += 0.14
		"slice": tilt.z -= 0.48
		"mix":
			tilt.y += 0.95
			tilt.z -= 0.40
		"marinate": tilt.z += 0.31
		"portion": destination.y += 0.18
		"steam", "boil": destination.y += 0.27
		"fry": tilt.x += 0.23
		"garnish": tilt.y += 0.55
		"serve": destination.y += 0.14
	var motion := visual.create_tween()
	var beats := 3 if action == "slice" else (2 if action in ["wash", "mix", "fry"] else 1)
	for beat in range(beats):
		motion.tween_property(visual, "position", destination, 0.10).set_trans(Tween.TRANS_QUAD)
		motion.parallel().tween_property(visual, "rotation", tilt, 0.10)
		motion.tween_property(visual, "position", home_position, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		motion.parallel().tween_property(visual, "rotation", home_rotation, 0.12)
	_spawn_action_sparks(action)


func _animate_prep_process(result: Dictionary, action: String) -> void:
	var recipe_id := str(result.get("recipe_id", result.get("stock_id", "")))
	if recipe_id.is_empty():
		return
	_process_serial += 1
	var serial := _process_serial
	var stock_job := str(result.get("target", "")) == "stock"
	var slot := clampi(int(result.get("ticket_slot", 0)), 0, 2)
	var overlay := Node3D.new()
	overlay.name = "%sAction_%s" % [action.capitalize(), recipe_id]
	overlay.position = _station_food_point(action, slot if not stock_job else 0)
	_stage.add_child(overlay)
	_load_process_visual(overlay, action, recipe_id, result.get("ingredients", []), slot if not stock_job else -1)
	if stock_job:
		var job: Dictionary = _state.get("stock_job", {}) if _state.get("stock_job", {}) is Dictionary else {}
		_process_hold_stock = {"id": recipe_id, "step_index": int(job.get("step_index", -1)), "serial": serial}
		_stock_food.visible = false
	else:
		var tickets: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
		if slot < tickets.size() and tickets[slot] is Dictionary:
			var ticket: Dictionary = tickets[slot]
			_process_hold_slots[slot] = {"order_number": int(ticket.get("order_number", -1)), "step_index": int(ticket.get("step_index", -1)), "serial": serial}
			_ticket_food[slot].visible = false
	if action == "wash":
		_animate_station("wash")
		var rinse := overlay.create_tween()
		for beat in range(2):
			rinse.tween_property(overlay, "position:y", overlay.position.y + 0.09, 0.13).set_trans(Tween.TRANS_SINE)
			rinse.tween_property(overlay, "position:y", overlay.position.y, 0.15).set_trans(Tween.TRANS_SINE)
		for i in range(7):
			var drop := _sphere(overlay, Vector3(-0.28 + float(i % 4) * 0.18, 0.38 + float(i / 4) * 0.12, -0.10 + float(i % 3) * 0.12), 0.035, Color("#8ec8c3"))
			drop.scale = Vector3(0.64, 1.65, 0.64)
			var fall := drop.create_tween()
			fall.tween_interval(float(i % 3) * 0.10)
			fall.tween_property(drop, "position:y", 0.07, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fall.parallel().tween_property(drop, "scale", Vector3.ONE * 0.10, 0.25)
	elif action == "mix":
		_animate_station("mix")
		var blend := overlay.create_tween()
		var rocking := 0.055 if recipe_id == "fruit_ice" else 0.090
		for beat in range(3):
			blend.tween_property(overlay, "rotation:z", rocking, 0.10).set_trans(Tween.TRANS_SINE)
			blend.tween_property(overlay, "rotation:z", -rocking, 0.10).set_trans(Tween.TRANS_SINE)
		blend.tween_property(overlay, "rotation:z", 0.0, 0.06).set_trans(Tween.TRANS_SINE)
	else:
		var knife_count := 0
		for node in overlay.find_children("*", "MeshInstance3D", true, false):
			var part := node as MeshInstance3D
			if not str(part.name).contains("knife_"):
				continue
			knife_count += 1
			var resting_height := part.position.y
			part.position.y += 0.16
			var chop := part.create_tween()
			for beat in range(3):
				chop.tween_property(part, "position:y", resting_height, 0.085).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				chop.tween_property(part, "position:y", resting_height + 0.16, 0.095).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if knife_count == 0:
			_animate_station("slice")
	var finish := overlay.create_tween()
	finish.tween_interval(0.54)
	finish.tween_property(overlay, "scale", Vector3.ONE * 0.70, 0.12).set_trans(Tween.TRANS_QUAD)
	finish.finished.connect(func() -> void:
		if stock_job and int(_process_hold_stock.get("serial", -1)) == serial:
			_process_hold_stock.clear()
		if not stock_job:
			var hold: Dictionary = _process_hold_slots.get(slot, {}) if _process_hold_slots.get(slot, {}) is Dictionary else {}
			if int(hold.get("serial", -1)) == serial:
				_process_hold_slots.erase(slot)
		_refresh_process_food()
		overlay.queue_free()
	)


func _spawn_action_sparks(action: String) -> void:
	var station := _stage.get_node_or_null("Station_" + action) as Node3D
	if station == null:
		return
	var effect := Node3D.new()
	effect.position = Vector3(0, 1.52 if action == "wash" else 1.22, 0)
	station.add_child(effect)
	var tint := Color("#8ec8c3") if action == "wash" else (Color("#e8bb79") if action in ["steam", "fry", "boil", "serve"] else Color("#86a77b"))
	for i in range(6):
		var particle := _sphere(effect, Vector3(-0.32 + float(i) * 0.13, 0.0, -0.15 + float(i % 2) * 0.22), 0.05, tint, false)
		particle.scale = Vector3(0.55, 1.3, 0.55) if action == "wash" else Vector3.ONE
	var motion := effect.create_tween()
	motion.tween_property(effect, "position:y", 1.04 if action == "wash" else 1.68, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if action == "wash" else Tween.EASE_OUT)
	motion.parallel().tween_property(effect, "scale", Vector3.ONE * 0.05, 0.42)
	motion.finished.connect(effect.queue_free)


func _buffer_x(slot: int) -> float:
	return COMBO_TRAY_X - 0.85 if slot == 0 else (COMBO_TRAY_X + 0.85 if slot == 1 else SINGLE_TRAY_X)


func _animate_earnings(amount: int, buffer_slot: int) -> void:
	AudioManager.play_sfx("kitchen_register")
	# Payment stays at the till: notes and coins appear on its counter,
	# the drawer opens, the money is sorted into separate compartments,
	# then a short receipt comes out. No cash flies across the whole kitchen.
	if is_instance_valid(_register_drawer):
		if is_instance_valid(_register_motion):
			_register_motion.kill()
		_register_drawer.position.z = 0.04
		_register_motion = _register_drawer.create_tween()
		_register_motion.tween_property(_register_drawer, "position:z", 0.31, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_register_motion.tween_interval(0.95)
		_register_motion.tween_property(_register_drawer, "position:z", 0.04, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if is_instance_valid(_register_lamp):
		var lamp_material := _register_lamp.material_override as StandardMaterial3D
		lamp_material.emission_energy_multiplier = 1.9
		_register_lamp.create_tween().tween_property(lamp_material, "emission_energy_multiplier", 0.2, 1.42)
	var notes := clampi(ceili(float(amount) / 95.0), 1, 3)
	for i in range(notes):
		var bill := _make_cash_note(_stage, Vector3(9.53 + float(i) * 0.055, 1.11 + float(i) * 0.005, 2.37))
		bill.rotation.y = -0.18 + float(i) * 0.18
		var bill_motion := bill.create_tween()
		bill_motion.tween_interval(0.18 + float(i) * 0.095)
		bill_motion.tween_property(bill, "position", Vector3(9.81 + float(i) * 0.11, 0.85, 3.02), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		bill_motion.parallel().tween_property(bill, "rotation:y", 0.0, 0.48)
		bill_motion.tween_property(bill, "scale", Vector3.ONE * 0.04, 0.20)
		bill_motion.finished.connect(bill.queue_free)
	for i in range(4):
		var coin := _make_cash_coin(_stage, Vector3(10.33 + float(i % 2) * 0.08, 1.075 + float(i / 2) * 0.025, 2.39), i % 2 == 0)
		var coin_motion := coin.create_tween()
		coin_motion.tween_interval(0.16 + float(i) * 0.09)
		coin_motion.tween_property(coin, "position", Vector3(10.23 + float(i % 2) * 0.075, 0.88, 3.00), 0.37).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		coin_motion.parallel().tween_property(coin, "rotation:z", PI * (1.4 + float(i) * 0.4), 0.37)
		coin_motion.tween_property(coin, "scale", Vector3.ONE * 0.04, 0.18)
		coin_motion.finished.connect(coin.queue_free)
	if is_instance_valid(_register_receipt):
		_register_receipt.scale.z = 0.03
		_register_receipt.create_tween().tween_property(_register_receipt, "scale:z", 1.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_cash_label):
		_cash_label.pivot_offset = _cash_label.size * 0.5
		_cash_label.scale = Vector2.ONE * 1.24
		_cash_label.create_tween().tween_property(_cash_label, "scale", Vector2.ONE, 0.56).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _make_cash_note(parent: Node3D, at: Vector3) -> Node3D:
	var note := Node3D.new()
	note.position = at
	parent.add_child(note)
	_box(note, Vector3.ZERO, Vector3(0.28, 0.007, 0.15), Color("#bad5b0"))
	_box(note, Vector3.ZERO + Vector3(0, 0.005, 0), Vector3(0.23, 0.002, 0.11), Color("#e0e4b5"))
	_box(note, Vector3.ZERO + Vector3(0, 0.007, 0), Vector3(0.043, 0.002, 0.073), Color("#7fa893"))
	for side in [-1, 1]:
		_box(note, Vector3(float(side) * 0.111, 0.008, 0), Vector3(0.008, 0.002, 0.087), Color("#6f9c83"))
	return note


func _make_cash_coin(parent: Node3D, at: Vector3, gold: bool) -> Node3D:
	var coin := Node3D.new()
	coin.position = at
	parent.add_child(coin)
	_cylinder(coin, Vector3.ZERO, 0.064, 0.018, Color("#d8ac60") if gold else Color("#c5c4b0"), true)
	_cylinder(coin, Vector3(0, 0.011, 0), 0.047, 0.002, Color("#eed096") if gold else Color("#e1dfc9"))
	_box(coin, Vector3(0, 0.013, 0), Vector3(0.012, 0.002, 0.045), Color("#b6874c") if gold else Color("#9eaa9d"))
	return coin


func _animate_prep_actor(action: String, stock_id: String) -> void:
	if not is_instance_valid(_prep_actor):
		return
	if is_instance_valid(_prep_motion):
		_prep_motion.kill()
	var idle := PREP_ACTOR_HOME
	# The assistant works at the side pantry. Crossing the central counters reads as
	# floating over the workbench from this camera angle and blocks ticket art.
	var target := Vector3(-7.87, 0, 1.05) if action in ["wash", "mix", "portion"] else Vector3(-7.87, 0, 0.86)
	if stock_id == "spice_oil":
		target = Vector3(-7.87, 0, 0.86)
	_prep_cargo.visible = true
	_prep_actor.rotation.y = -PI * 0.35
	_prep_motion = _prep_actor.create_tween()
	_prep_motion.tween_property(_prep_actor, "position", target, 0.47).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_prep_motion.tween_interval(0.20)
	_prep_motion.tween_callback(func() -> void: _prep_cargo.visible = false)
	_prep_motion.tween_property(_prep_actor, "position", idle, 0.50).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_prep_motion.tween_callback(func() -> void: _prep_actor.rotation.y = 0.0)


func _animate_raw_restock(group_id: String) -> void:
	if not _raw_areas.has(group_id):
		return
	var index := RAW_GROUP_ORDER.find(group_id)
	if index < 0 or not is_instance_valid(_prep_actor):
		return
	if is_instance_valid(_prep_motion):
		_prep_motion.kill()
	var home := PREP_ACTOR_HOME
	var target := Vector3(PREP_ACTOR_HOME.x, 0, -2.35 if index < 2 else -0.95)
	_prep_cargo.visible = true
	_prep_actor.rotation.y = -PI * 0.52
	_prep_motion = _prep_actor.create_tween()
	_prep_motion.tween_property(_prep_actor, "position", PREP_ACTOR_AISLE, 0.18)
	_prep_motion.tween_property(_prep_actor, "position", target, 0.39).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_prep_motion.tween_callback(func() -> void: _prep_cargo.visible = false)
	_prep_motion.tween_interval(0.16)
	_prep_motion.tween_property(_prep_actor, "position", PREP_ACTOR_AISLE, 0.39)
	_prep_motion.tween_property(_prep_actor, "position", home, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_prep_motion.tween_callback(func() -> void: _prep_actor.rotation.y = 0.0)
	var crate := (_raw_areas[group_id] as Area3D).get_parent() as Node3D
	crate.scale = Vector3(1.16, 0.92, 1.12)
	crate.create_tween().tween_property(crate, "scale", Vector3(1.16, 1.0, 1.12), 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _animate_raw_pick(group_id: String) -> void:
	var index := RAW_GROUP_ORDER.find(group_id)
	if index < 0 or not is_instance_valid(_prep_actor):
		return
	if is_instance_valid(_prep_motion):
		_prep_motion.kill()
	var home := PREP_ACTOR_HOME
	var crate := Vector3(PREP_ACTOR_HOME.x, 0, -2.35 if index < 2 else -0.95)
	_prep_cargo.visible = false
	_prep_actor.rotation.y = -PI * 0.52
	_prep_motion = _prep_actor.create_tween()
	_prep_motion.tween_property(_prep_actor, "position", PREP_ACTOR_AISLE, 0.18)
	_prep_motion.tween_property(_prep_actor, "position", crate, 0.37).set_trans(Tween.TRANS_CUBIC)
	_prep_motion.tween_callback(func() -> void: _prep_cargo.visible = true)
	_prep_motion.tween_interval(0.12)
	_prep_motion.tween_property(_prep_actor, "position", PREP_ACTOR_AISLE, 0.32).set_trans(Tween.TRANS_CUBIC)
	_prep_motion.tween_property(_prep_actor, "position", home, 0.18).set_trans(Tween.TRANS_CUBIC)
	_prep_motion.tween_callback(func() -> void: _prep_actor.rotation.y = 0.0)


func _animate_raw_place() -> void:
	if not is_instance_valid(_prep_actor):
		return
	if is_instance_valid(_prep_motion):
		_prep_motion.kill()
	var home := PREP_ACTOR_HOME
	_prep_cargo.visible = true
	_prep_actor.rotation.y = PI
	_prep_motion = _prep_actor.create_tween()
	_prep_motion.tween_property(_prep_actor, "position", Vector3(-7.87, 0, 1.05), 0.30).set_trans(Tween.TRANS_CUBIC)
	_prep_motion.tween_callback(func() -> void: _prep_cargo.visible = false)
	_prep_motion.tween_interval(0.12)
	_prep_motion.tween_property(_prep_actor, "position", home, 0.38).set_trans(Tween.TRANS_CUBIC)
	_prep_motion.tween_callback(func() -> void: _prep_actor.rotation.y = 0.0)


func _animate_prep_clear() -> void:
	if not is_instance_valid(_prep_actor):
		return
	if is_instance_valid(_prep_motion):
		_prep_motion.kill()
	var home := PREP_ACTOR_HOME
	_prep_cargo.visible = false
	_prep_actor.rotation.y = PI
	_prep_motion = _prep_actor.create_tween()
	_prep_motion.tween_property(_prep_actor, "position", Vector3(-7.87, 0, 1.05), 0.32).set_trans(Tween.TRANS_CUBIC)
	_prep_motion.tween_callback(func() -> void: _prep_cargo.visible = true)
	_prep_motion.tween_property(_prep_actor, "position", Vector3(-7.87, 0, 0.75), 0.32).set_trans(Tween.TRANS_CUBIC)
	_prep_motion.tween_callback(func() -> void: _prep_cargo.visible = false)
	_prep_motion.tween_property(_prep_actor, "position", home, 0.26).set_trans(Tween.TRANS_CUBIC)
	_prep_motion.tween_callback(func() -> void: _prep_actor.rotation.y = 0.0)


func _animate_stock_transfer(result: Dictionary) -> void:
	var stock_id := str(result.get("stock_id", ""))
	var shelf := 0 if stock_id == "rice_batter" else (1 if stock_id == "spice_oil" else -1)
	if shelf < 0 or shelf >= _stock_cargo.size():
		return
	# A player may take a newly prepared unit immediately. Retire the earlier
	# delivery so the same bowl never travels toward and away from the shelf.
	for child in _stage.get_children():
		if child is Node3D and str(child.get_meta("stock_transfer_id", "")) == stock_id:
			(child as Node3D).visible = false
			child.queue_free()
	var cargo := _stock_cargo[shelf]
	var event := str(result.get("event", ""))
	if event == "stock_prepared":
		var stock: Array = _state.get("stock", []) if _state.get("stock", []) is Array else []
		if shelf >= stock.size() or not stock[shelf] is Dictionary:
			return
		var portions := int((stock[shelf] as Dictionary).get("count", 0))
		var count := mini(STOCK_SLOT_POINTS.size(), ceili(float(portions) / 2.0))
		for unit in range(maxi(0, count - 2), count):
			var local: Vector2 = STOCK_SLOT_POINTS[unit]
			var destination := _stage.to_local(cargo.to_global(Vector3(local.x, 0.05, local.y)))
			var start := _station_food_point("mix", 0) + Vector3(float(unit % 2) * 0.19 - 0.10, 0.11, 0)
			_fly_stock_model(stock_id, start, destination, float(unit - count + 2) * 0.12)
	elif event == "stock_used":
		var slot := clampi(int(result.get("ticket_slot", 0)), 0, 2)
		var tickets: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
		if slot >= tickets.size() or not tickets[slot] is Dictionary:
			return
		var next_action := str((tickets[slot] as Dictionary).get("next_action", ""))
		var source := _stage.to_local(cargo.to_global(Vector3(STOCK_SLOT_POINTS[0].x, 0.05, STOCK_SLOT_POINTS[0].y)))
		_fly_stock_model(stock_id, source, _station_food_point(next_action, slot) + Vector3(0, 0.09, 0), 0.0)


func _fly_stock_model(stock_id: String, start: Vector3, destination: Vector3, delay: float) -> void:
	var parcel := Node3D.new()
	parcel.set_meta("stock_transfer_id", stock_id)
	parcel.position = start
	_stage.add_child(parcel)
	var asset := "rice_batter_bowl" if stock_id == "rice_batter" else "spice_jar"
	var path := "res://assets/art/models/food_stage/%s.glb" % asset
	var packed = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	if packed is PackedScene:
		var model := (packed as PackedScene).instantiate() as Node3D
		parcel.add_child(model)
		_fit_display_model(model, 0.44)
	else:
		_sphere(parcel, Vector3(0, 0.17, 0), 0.18, Color("#d7c397"))
	var middle := (start + destination) * 0.5 + Vector3(0, 0.84, 0)
	var motion := parcel.create_tween()
	motion.tween_interval(delay)
	motion.tween_property(parcel, "position", middle, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(parcel, "rotation:y", 0.28, 0.28)
	motion.tween_property(parcel, "position", destination, 0.31).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.parallel().tween_property(parcel, "scale", Vector3.ONE * 0.75, 0.31)
	motion.finished.connect(parcel.queue_free)


func _animate_pickup_actor(slot: int, recipe_id: String, buffer_slot: int = -1, recipe_ids: Array = []) -> void:
	if not is_instance_valid(_pickup_actor):
		return
	if is_instance_valid(_pickup_motion):
		_pickup_motion.kill()
	var idle := Vector3(8.90, 0, 3.05)
	var grouped := recipe_ids.size() > 1
	var tray := Vector3(COMBO_TRAY_X, 0, FRONT_TABLE_Z) if grouped else (Vector3(_buffer_x(buffer_slot), 0, FRONT_TABLE_Z) if buffer_slot >= 0 and buffer_slot < 3 else Vector3(HANDOFF_X, 0, FRONT_TABLE_Z))
	var pickup_stance := Vector3(tray.x, 0, FRONT_TABLE_Z + 1.50)
	# The ticket queue refills as soon as a dish is served. Carry it into the
	# dining-side passage, not toward a newly assigned guest in the old slot.
	var service_exit := Vector3(8.48, 0, FRONT_TABLE_Z + 1.50 + float(slot) * 0.08)
	_handoff_active = true
	_handoff_display.position = Vector3(tray.x, FRONT_TABLE_TOP + (0.563 if buffer_slot < 2 else 0.0), tray.z) if buffer_slot >= 0 and buffer_slot < 3 else _dish_display.position
	if grouped:
		_load_meal_pair(_handoff_display, recipe_ids, 0.86)
		_load_meal_pair(_pickup_cargo, recipe_ids, 0.43)
	else:
		_load_food_model(_handoff_display, recipe_id, 1.18)
		_load_food_model(_pickup_cargo, recipe_id, 0.92)
	_handoff_display.visible = true
	_dish_display.visible = false
	_pickup_cargo.visible = false
	_pickup_actor.rotation.y = -PI * 0.50
	_pickup_motion = _pickup_actor.create_tween()
	_pickup_motion.tween_property(_pickup_actor, "position", pickup_stance, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pickup_motion.tween_callback(func() -> void:
		_handoff_display.visible = false
		_pickup_cargo.visible = true
	)
	_pickup_motion.tween_property(_pickup_actor, "position", service_exit, 0.59).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_pickup_motion.tween_callback(func() -> void: _pickup_cargo.visible = false)
	_pickup_motion.tween_property(_pickup_actor, "position", idle, 0.69).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_pickup_motion.tween_callback(func() -> void:
		_pickup_actor.rotation.y = 0.0
		_handoff_active = false
		_refresh_dish_display()
	)


func _show_guest_emotion(slot: int, positive: bool) -> void:
	if slot < 0 or slot >= _guest_pivots.size():
		return
	var icon := _guest_joy[slot] if positive else _guest_frustration[slot]
	icon.visible = true
	icon.scale = Vector3.ONE * 0.15
	var guest := _guest_pivots[slot]
	guest.position.y = 0.08 if positive else -0.05
	guest.create_tween().tween_property(guest, "position:y", -0.02, 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var motion := icon.create_tween()
	motion.tween_property(icon, "scale", Vector3.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_interval(0.92)
	motion.tween_callback(func() -> void: icon.visible = false)


func _guest_index_for_customer(customer_id: int) -> int:
	if customer_id < 0:
		return -1
	var seen := {}
	var raw = _state.get("tickets", [])
	var tickets: Array = raw if raw is Array else []
	for ticket in tickets:
		if not ticket is Dictionary:
			continue
		var entry: Dictionary = ticket
		var id := int(entry.get("customer_id", entry.get("order_number", -1)))
		if seen.has(id):
			continue
		seen[id] = true
		if id == customer_id:
			return seen.size() - 1
	return -1


func _input(event: InputEvent) -> void:
	if is_instance_valid(_rotate_overlay) and _rotate_overlay.visible:
		if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		return
	if not _interaction_enabled:
		return
	if event is InputEventScreenTouch and event.pressed:
		if _press_meal_card_at(event.position):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _left_press_active:
			# Food can finish its short move between touch-down and touch-up.
			# Retry only if the original press hit empty space; never act twice.
			if not is_instance_valid(_left_press_target):
				var release_target := _ray_pick(event.position)
				if is_instance_valid(release_target):
					_left_press_position = event.position
					_activate_pointer_target(release_target)
			_left_press_active = false
			_left_press_target = null
			_dragging_kitchen = false
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME]:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var hovered_control := get_viewport().gui_get_hovered_control()
		if hovered_control == null or not _hud_root.is_ancestor_of(hovered_control):
			_update_hover(event.position)
		else:
			_set_hover(null)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Touchscreen mouse emulation may arrive just after ScreenTouch. Both
		# events must not start the same ticket twice.
		if _press_meal_card_at(event.position):
			get_viewport().set_input_as_handled()
			return
		var hovered_control := get_viewport().gui_get_hovered_control()
		if hovered_control != null and _hud_root.is_ancestor_of(hovered_control):
			return
		_left_press_active = true
		_left_press_position = event.position
		_left_press_target = _ray_pick(event.position)
		_dragging_kitchen = false
		if is_instance_valid(_left_press_target):
			_activate_pointer_target(_left_press_target)
		get_viewport().set_input_as_handled()


func _press_meal_card_at(viewport_position: Vector2) -> bool:
	var target := _meal_card_at_pointer(viewport_position)
	if target.x < 0:
		return false
	var slots: Array = _customer_food_slots[target.x]
	if target.y < 0 or target.y >= slots.size():
		return true
	var slot := int(slots[target.y])
	var now := Time.get_ticks_msec()
	if slot != _last_ticket_pointer_slot or now - _last_ticket_pointer_msec > 180:
		_last_ticket_pointer_slot = slot
		_last_ticket_pointer_msec = now
		_on_meal_food_pressed(target.x, target.y)
	return true


func _meal_card_at_pointer(viewport_position: Vector2) -> Vector2i:
	# Safari can report the raw window point or the post-stretch viewport point
	# depending on whether the event came from touch or mouse emulation.
	var points := [viewport_position, get_viewport().get_final_transform().affine_inverse() * viewport_position]
	for point in points:
		for guest_index in range(_customer_cards.size()):
			var card := _customer_cards[guest_index]
			if not card.is_visible_in_tree() or not card.get_global_rect().has_point(point):
				continue
			for dish_index in range(_customer_food_slots[guest_index].size()):
				var button: Button = _customer_food_buttons[guest_index][dish_index]
				if button.is_visible_in_tree() and button.get_global_rect().has_point(point):
					return Vector2i(guest_index, dish_index)
			return Vector2i(guest_index, 0)
	return Vector2i(-1, -1)


func _activate_pointer_target(target: Area3D) -> void:
	var kind := str(target.get_meta("kind", ""))
	if kind == "action":
		_last_attempted_action = str(target.get_meta("id", ""))
		# A worktop click picks the nearest dish when several foods share one
		# station. This also makes the narrow moving food hitbox forgiving on touch.
		var nearest_order := _closest_food_order_on_station(_last_attempted_action, _left_press_position)
		if nearest_order >= 0:
			dish_pressed.emit(nearest_order, _last_attempted_action)
		else:
			action_pressed.emit(_last_attempted_action)
	elif kind == "ticket_food":
		_last_attempted_action = str(target.get_meta("action", ""))
		dish_pressed.emit(int(target.get_meta("order_number", -1)), _last_attempted_action)
	elif kind == "stock_food":
		_last_attempted_action = str(target.get_meta("action", ""))
		stock_action_pressed.emit(_last_attempted_action)
	elif kind == "stock":
		stock_pressed.emit(str(target.get_meta("id", "")))
	elif kind == "raw":
		raw_pressed.emit(str(target.get_meta("id", "")))
	elif kind == "finished_dish":
		_last_attempted_action = "serve"
		action_pressed.emit("serve")
	elif kind == "prep_table":
		prep_pressed.emit()
	elif kind == "ticket":
		ticket_pressed.emit(int(target.get_meta("id", "0")))
	elif kind == "buffer":
		buffer_pressed.emit(int(target.get_meta("id", "0")))
	elif kind == "shift":
		shift_requested.emit(str(target.get_meta("id", "calm")))
	elif kind == "close_sign":
		closing_requested.emit()


func _closest_food_order_on_station(action_id: String, screen_position: Vector2) -> int:
	if not is_instance_valid(camera):
		return -1
	var closest_order := -1
	var closest_distance := INF
	for slot in range(_ticket_food_areas.size()):
		var area := _ticket_food_areas[slot]
		if area.collision_layer == 0 or str(area.get_meta("action", "")) != action_id:
			continue
		var food := _ticket_food[slot]
		if not food.visible:
			continue
		var distance := screen_position.distance_squared_to(camera.unproject_position(food.global_position))
		if distance < closest_distance:
			closest_distance = distance
			closest_order = int(area.get_meta("order_number", -1))
	return closest_order


func _pan_camera(screen_motion: Vector2) -> void:
	var right := Vector3(camera.basis.x.x, 0.0, camera.basis.x.z).normalized()
	var up := Vector3(camera.basis.y.x, 0.0, camera.basis.y.z).normalized()
	_camera_focus -= right * screen_motion.x
	_camera_focus += up * screen_motion.y
	_camera_focus.x = clampf(_camera_focus.x, -13.0, 10.0)
	_camera_focus.z = clampf(_camera_focus.z, -6.0, 5.5)
	_apply_camera_pose()


func _apply_camera_pose() -> void:
	if not is_instance_valid(camera):
		return
	var cp := cos(_camera_pitch)
	camera.position = _camera_focus + Vector3(sin(_camera_yaw) * cp, sin(_camera_pitch), cos(_camera_yaw) * cp) * _camera_distance
	camera.look_at(_stage.global_position + _camera_focus)


func _build_stage() -> void:
	_stage = Node3D.new()
	_stage.name = "KitchenStage"
	_stage.position.y = STAGE_Y
	add_child(_stage)
	# A raised, solid tabletop scene stays visible even when placed beside the park cafe.
	_box(_stage, Vector3(0, -0.47, 0), Vector3(44, 0.18, 34), Color("#c4d5d0"))
	_box(_stage, Vector3(0, -0.30, 0.72), Vector3(15.0, 0.25, 11.4), Color("#bca88d"))
	_box(_stage, Vector3(0, -0.14, 0.72), Vector3(14.7, 0.09, 11.0), Color("#aa9275"))
	for x in range(12):
		var plank_x := -6.66 + float(x) * 1.21
		_box(_stage, Vector3(plank_x, -0.083, 0.72), Vector3(1.18, 0.006, 10.82), Color("#c2aa88") if x % 3 == 0 else Color("#b9a182"))
	for z in [-2.5, -0.2, 2.1, 4.45]:
		_box(_stage, Vector3(0, -0.078, z), Vector3(14.4, 0.003, 0.025), Color("#9e866b"))
	_build_room_shell()
	_build_front_prep_table()
	_box(_stage, Vector3(0, 0.20, -4.15), Vector3(14.6, 0.58, 0.28), Color("#aa8170"))
	_box(_stage, Vector3(0, 0.55, -4.10), Vector3(14.4, 0.09, 0.62), Color("#eedab5"))
	for x in [-5.8, -3.1, 0.2, 3.4, 5.9]:
		_box(_stage, Vector3(x, 0.62, -4.1), Vector3(0.09, 0.13, 0.66), Color("#a97f6a"))
	# Separate wood cabinets and pale stone tops give every physical station a readable hit area.
	var counter_path := "res://assets/art/models/park_cafe_counter_unit.glb"
	var counter_packed = ResourceLoader.load(counter_path) if ResourceLoader.exists(counter_path) else null
	for action in ACTIONS:
		var id := str(action["id"])
		if id == "serve":
			continue
		var at := Vector3(float(action["x"]), 0, float(action["z"]))
		var unit := Node3D.new()
		unit.name = "Station_" + id
		unit.position = at
		_stage.add_child(unit)
		if counter_packed is PackedScene:
			var counter := (counter_packed as PackedScene).instantiate() as Node3D
			counter.scale.z = 0.74
			unit.add_child(counter)
			_tune_counter_materials(counter, id)
		else:
			_box(unit, Vector3(0, 0.36, 0), Vector3(2.17, 0.72, 1.90), Color("#9b705a"))
			_box(unit, Vector3(0, 0.77, 0), Vector3(2.25, 0.13, 1.97), Color("#d6c7ad"))
			_box(unit, Vector3(0, 0.08, 1.285), Vector3(2.08, 0.08, 0.035), Color("#704d3f"))
			for side in [-1, 1]:
				_box(unit, Vector3(float(side) * 0.98, 0.40, 1.29), Vector3(0.055, 0.62, 0.04), Color("#744f40"))
			_box(unit, Vector3(0, 0.40, 1.30), Vector3(1.4, 0.10, 0.03), Color("#e1c39a"))
			_box(unit, Vector3(0, 0.30, 1.34), Vector3(0.36, 0.045, 0.045), Color("#d9d0bb"))
		var device := Node3D.new()
		device.name = "Station_" + id
		unit.add_child(device)
		_build_prop(device, id)
		_station_focus_props[id] = device
		_cylinder(unit, Vector3(-0.83, 0.874, 0.88), 0.12, 0.025, Color("#8d7860"))
		var status_lamp := _sphere(unit, Vector3(-0.83, 0.905, 0.88), 0.115, Color("#76786f"), true)
		status_lamp.scale.y = 0.42
		_station_status_lamps[id] = status_lamp
		var area := _area(unit, "action", id, str(action["name"]), Vector3(0, 1.08, 0), Vector3(2.23, 1.05, 1.97))
		area.name = "Hotspot_" + id
		var halo := _edge_cue(unit, Vector3(0, 0.84, 1.00), 1.55)
		halo.visible = false
		_station_halos[id] = halo
		var focus_light := OmniLight3D.new()
		focus_light.name = "ActionTaskLight"
		focus_light.position = Vector3(0.0, 2.05, 0.15)
		focus_light.light_color = Color("#fff0cc")
		focus_light.light_energy = 0.27
		focus_light.omni_range = 2.65
		focus_light.shadow_enabled = false
		focus_light.visible = false
		unit.add_child(focus_light)
		_station_focus_lights[id] = focus_light
	# Prepared batches live in the two left wells of the front prep table.
	for i in range(3):
		var stock := Node3D.new()
		stock.name = "Stock_%d" % i
		stock.position = Vector3(STOCK_WELL_X[i], 0, FRONT_TABLE_Z) if i < 2 else Vector3(0, -10, 0)
		_stage.add_child(stock)
		var cargo := Node3D.new()
		cargo.position.y = FRONT_TABLE_TOP
		stock.add_child(cargo)
		_stock_cargo.append(cargo)
		if i < 2:
			_build_stock_slots(cargo, "rice_batter" if i == 0 else "spice_oil")
		else:
			_cylinder(cargo, Vector3(0, 0.025, 0), 0.26, 0.035, Color("#a8876b"))
		var area := _area(stock, "stock", "stock_%d" % i, "半成品库存", Vector3(0, FRONT_TABLE_TOP + 0.28, 0), Vector3(1.48, 0.58, 0.86))
		if i == 2:
			area.collision_layer = 0
		_stock_areas.append(area)
		var stock_halo := _edge_cue(stock, Vector3(0, FRONT_TABLE_TOP + 0.034, 0.42), 1.12)
		stock_halo.visible = false
		_stock_halos.append(stock_halo)
	for x in [-5.8, 5.8]:
		_cylinder(_stage, Vector3(x, 1.08, -4.0), 0.09, 1.05, Color("#769d90"))
		_sphere(_stage, Vector3(x, 1.68, -4.0), 0.19, Color("#fff2d3"), true)
	_build_small_details()
	_build_service_lights()
	_build_front_task_lamps()
	_build_guest_line()
	_build_dish_display()
	_build_buffer_trays()
	_build_process_food()
	_build_heat_lights()
	_build_staff()
	_build_side_rooms()
	_build_fixed_pantry()
	_batch_fixed_pantry_bulk()
	_build_cash_register()
	_build_close_sign()
	_build_scene_clock()
	_box(_stage, Vector3(0, 0.46, 4.55), Vector3(14.6, 0.2, 0.14), Color("#947461"))
	camera = Camera3D.new()
	camera.name = "KitchenCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.1
	camera.near = 0.1
	camera.far = 260.0
	_stage.add_child(camera)
	_apply_camera_pose()
	var room_environment := Environment.new()
	room_environment.background_mode = Environment.BG_COLOR
	room_environment.background_color = Color("#cad2c8")
	room_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room_environment.ambient_light_color = Color("#e8dfd0")
	room_environment.ambient_light_energy = 0.23
	room_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	room_environment.tonemap_exposure = 0.62
	_kitchen_environment = room_environment
	camera.environment = room_environment
	camera.current = true
	var light := DirectionalLight3D.new()
	light.name = "KitchenSoftbox"
	light.rotation_degrees = Vector3(-58, -32, 0)
	light.light_color = Color("#fff0d4")
	light.light_energy = 0.50
	light.shadow_enabled = true
	light.shadow_blur = 4.0
	light.shadow_opacity = 0.35
	_stage.add_child(light)
	for x in [-4.1, 4.1]:
		var fill := OmniLight3D.new()
		fill.name = "WarmCounterFill"
		fill.position = Vector3(x, 4.5, 0.9)
		fill.light_color = Color("#ffe0af")
		fill.light_energy = 0.04
		fill.omni_range = 9.2
		fill.shadow_enabled = false
		_stage.add_child(fill)
		_fill_lights.append(fill)


func _tune_counter_materials(counter: Node3D, action: String) -> void:
	# The wood joinery stays shared, while each wet, prep, heat and handoff surface
	# receives its own quiet glaze. Work and completion tint the surface in place.
	for part in counter.find_children("*", "MeshInstance3D", true, false):
		var mesh_part := part as MeshInstance3D
		if mesh_part == null:
			continue
		var tint := Color.TRANSPARENT
		if str(mesh_part.name).contains("thick_bullnose_stone_top"):
			tint = Color("#c8b798")
		elif str(mesh_part.name).contains("quiet_worktop_field"):
			tint = STATION_TOP_COLORS.get(action, Color("#d4c0a1"))
			var parts: Array = _station_worktops.get(action, [])
			parts.append(mesh_part)
			_station_worktops[action] = parts
		if tint.a <= 0.0:
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = 0.90
		mesh_part.material_override = material


func _build_room_shell() -> void:
	# The blue glazing and low green shoreline orient the kitchen toward Shenzhen Bay.
	_box(_stage, Vector3(0, 1.26, -5.05), Vector3(14.82, 2.75, 0.22), Color("#8fa89d"))
	# The right service bay needs its own continuous rear wall. It joins the
	# central room divider and the side wall, behind the pickup counter; the
	# glazed centre span ends at x=7.4 and remains fully unobstructed.
	_box(_stage, Vector3(9.23, 0.87, -4.95), Vector3(3.48, 1.90, 0.20), Color("#9cb2a7"))
	_box(_stage, Vector3(9.23, 1.78, -4.82), Vector3(3.48, 0.11, 0.20), Color("#9b7359"))
	_box(_stage, Vector3(0, 2.61, -4.89), Vector3(14.72, 0.16, 0.22), Color("#956d55"))
	for variant in ["dawn", "day", "dusk", "evening"]:
		var window_id := "park_kitchen_bay_window_%s" % variant
		var window_path := "res://assets/art/models/kitchen/%s.glb" % window_id
		var packed = ResourceLoader.load(window_path) if ResourceLoader.exists(window_path) else null
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate() as Node3D
			model.position = Vector3(0, 0.77, -4.79)
			model.visible = variant == "dawn"
			_stage.add_child(model)
			_window_meshes[variant] = model.find_children("*", "MeshInstance3D", true, false)
			if variant == "evening":
				_window_evening = model
			elif variant == "dusk":
				_window_dusk = model
			elif variant == "dawn":
				_window_dawn = model
			else:
				_window_day = model
	for side in [-1, 1]:
		_box(_stage, Vector3(float(side) * 7.40, 0.56, -0.07), Vector3(0.19, 1.35, 9.70), Color("#a5b5a2"))
		_box(_stage, Vector3(float(side) * 7.28, 1.22, -0.07), Vector3(0.15, 0.10, 9.68), Color("#9c745b"))
	_box(_stage, Vector3(0, 0.24, 5.02), Vector3(14.65, 0.47, 0.17), Color("#8e6c57"))
	_box(_stage, Vector3(0, 0.51, 5.01), Vector3(14.64, 0.07, 0.22), Color("#d5b68d"))
	for x in [-6.7, 6.7]:
		_cylinder(_stage, Vector3(x, 0.19, 3.84), 0.27, 0.39, Color("#bb8b69"))
		for offset in [-0.18, 0.0, 0.18]:
			_sphere(_stage, Vector3(x + offset, 0.48 + absf(offset) * 0.4, 3.83), 0.24, Color("#759b78"))


func _build_small_details() -> void:
	for i in range(3):
		var x := -2.4 + float(i) * 2.4
		var ticket := _box(_stage, Vector3(x, 1.16, -3.95), Vector3(0.41, 0.60, 0.035), Color("#e8dec9"))
		ticket.rotation_degrees.x = -11
		_box(_stage, Vector3(x, 1.49, -3.94), Vector3(0.16, 0.06, 0.06), Color("#bd9363"))
		for line in range(3):
			_box(_stage, Vector3(x, 1.31 - float(line) * 0.11, -3.91), Vector3(0.27, 0.018, 0.018), Color("#a68e79"))
	for x in [-6.35, 6.35]:
		# Spice jars belong to a narrow service rail, with visible brackets.
		_box(_stage, Vector3(x, 0.84, -1.60), Vector3(0.42, 0.12, 1.72), Color("#b68e6e"))
		for z in [-2.25, -0.95]:
			_box(_stage, Vector3(x, 0.44, z), Vector3(0.11, 0.72, 0.14), Color("#96705b"))
		for i in range(3):
			_cylinder(_stage, Vector3(x, 0.96, -2.1 + float(i) * 0.50), 0.11, 0.23, Color("#abbd92") if i == 0 else Color("#cba17c"))
			_cylinder(_stage, Vector3(x, 1.10, -2.1 + float(i) * 0.50), 0.12, 0.035, Color("#e4d4aa"))


func _build_service_lights() -> void:
	# Under-cabinet lighting keeps the tools legible while the window and room
	# become darker in the evening; the lamps are physically attached to joinery.
	for x in [-4.7, 0.0, 4.7]:
		_box(_stage, Vector3(x, 2.22, -3.81), Vector3(1.72, 0.10, 0.37), Color("#8d7560"))
		var glow := _box(_stage, Vector3(x, 2.15, -3.70), Vector3(1.43, 0.026, 0.14), Color("#e4c894"))
		var glow_material := glow.material_override as StandardMaterial3D
		glow_material.emission_enabled = true
		glow_material.emission = Color("#e4c894")
		_service_glows.append(glow)
		var light := OmniLight3D.new()
		light.position = Vector3(x, 2.05, -3.26)
		light.light_color = Color("#ffdaab")
		light.light_energy = 0.03
		light.omni_range = 4.6
		light.shadow_enabled = true
		light.shadow_blur = 3.5
		light.shadow_opacity = 0.45
		_stage.add_child(light)
		_service_lights.append(light)
	_window_beam = DirectionalLight3D.new()
	_window_beam.name = "KitchenWindowRakingLight"
	_window_beam.rotation_degrees = Vector3(-34.0, -150.0, 0.0)
	_window_beam.light_color = Color("#ffd2a3")
	_window_beam.light_energy = 0.0
	# The raking window key shapes surfaces; local fixtures provide the soft
	# contact shadows. A second directional shadow casts room-sized silhouettes.
	_window_beam.shadow_enabled = false
	_stage.add_child(_window_beam)
	for x in [-4.2, 0.0, 4.2]:
		var task_light := OmniLight3D.new()
		task_light.name = "FrontWorkLamp"
		task_light.position = Vector3(x, 3.25, 1.35)
		task_light.light_color = Color("#ffe2b7")
		task_light.light_energy = 0.0
		task_light.omni_range = 5.8
		task_light.shadow_enabled = false
		_stage.add_child(task_light)
		_task_lights.append(task_light)
	_sunset_bounce = OmniLight3D.new()
	_sunset_bounce.name = "WindowSunsetBounce"
	_sunset_bounce.position = Vector3(-2.4, 2.1, -4.15)
	_sunset_bounce.light_color = Color("#ffae73")
	_sunset_bounce.light_energy = 0.0
	_sunset_bounce.omni_range = 8.2
	_sunset_bounce.shadow_enabled = false
	_stage.add_child(_sunset_bounce)
	_night_window_fill = OmniLight3D.new()
	_night_window_fill.name = "NightWindowFill"
	_night_window_fill.position = Vector3(1.8, 2.3, -4.20)
	_night_window_fill.light_color = Color("#7899bd")
	_night_window_fill.light_energy = 0.0
	_night_window_fill.omni_range = 7.8
	_night_window_fill.shadow_enabled = false
	_stage.add_child(_night_window_fill)
	for x in [-8.8, 8.8]:
		var side_light := OmniLight3D.new()
		side_light.name = "NightSideCabinetLight"
		side_light.position = Vector3(x, 3.25, -0.9)
		side_light.light_color = Color("#ffd1a0")
		side_light.light_energy = 0.0
		side_light.omni_range = 6.1
		side_light.shadow_enabled = false
		_stage.add_child(side_light)
		_night_side_lights.append(side_light)
	for mount: Vector3 in [Vector3(-13.52, 1.52, -0.95), Vector3(-13.52, 1.52, 3.05), Vector3(10.72, 1.55, 2.48)]:
		var facing: float = 1.0 if mount.x < 0.0 else -1.0
		_box(_stage, mount, Vector3(0.10, 0.31, 0.28), Color("#9c775e"))
		_box(_stage, mount + Vector3(facing * 0.14, 0.0, 0.0), Vector3(0.26, 0.055, 0.11), Color("#c5a47d"))
		var shade_at: Vector3 = mount + Vector3(facing * 0.29, -0.015, 0.0)
		var shade := _sphere(_stage, shade_at, 0.135, Color("#f3deba"), true)
		shade.scale = Vector3(0.88, 0.72, 0.88)
		_pantry_sconce_glows.append(shade)
		_cylinder(_stage, shade_at + Vector3(0.0, 0.105, 0.0), 0.125, 0.025, Color("#ad8b68"))
		var sconce := OmniLight3D.new()
		sconce.name = "PantryWallSconce"
		sconce.position = shade_at
		sconce.light_color = Color("#ffe0b4")
		sconce.light_energy = 0.0
		sconce.omni_range = 4.9
		sconce.shadow_enabled = false
		_stage.add_child(sconce)
		_pantry_sconce_lights.append(sconce)


func _build_front_task_lamps() -> void:
	# Compact clamp lamps live on the rear corners of the three heat counters.
	# Their shades differ, and the bulbs add local contact shadows after sunset.
	for i in range(3):
		var x := -4.2 + float(i) * 4.2
		var anchor := Vector3(x - 0.71, 1.03, 1.61)
		_cylinder(_stage, anchor, 0.075, 0.045, Color("#8c6f58"))
		_cylinder(_stage, anchor + Vector3(0, 0.24, 0), 0.026, 0.47, Color("#b99a73"))
		_box(_stage, anchor + Vector3(0.16, 0.47, 0), Vector3(0.32, 0.035, 0.038), Color("#b99a73"))
		var head_at := anchor + Vector3(0.32, 0.45, 0.0)
		if i == 0:
			var bell := CylinderMesh.new()
			bell.top_radius = 0.085
			bell.bottom_radius = 0.19
			bell.height = 0.15
			_mesh(_stage, bell, head_at, Color("#ad8965"))
		elif i == 1:
			var enamel := _sphere(_stage, head_at, 0.18, Color("#748d7f"))
			enamel.scale.y = 0.48
		else:
			_box(_stage, head_at, Vector3(0.32, 0.13, 0.24), Color("#9caeaa"))
		var bulb := _sphere(_stage, head_at + Vector3(0, -0.105, 0), 0.070, Color("#f6dfb8"), true)
		_front_lamp_glows.append(bulb)
		var lamp := OmniLight3D.new()
		lamp.name = "HeatCounterTaskLamp"
		lamp.position = head_at + Vector3(0, -0.16, 0.15)
		lamp.light_color = Color("#ffecd1")
		lamp.light_energy = 0.0
		lamp.omni_range = 3.8
		lamp.shadow_enabled = true
		lamp.shadow_blur = 3.0
		lamp.shadow_opacity = 0.16
		_stage.add_child(lamp)
		_front_station_lights.append(lamp)
	# Two glass light bars are fixed to the back rail of the broad plating table.
	for x in [-3.35, 3.35]:
		var foot := Vector3(x, FRONT_TABLE_TOP + 0.025, FRONT_TABLE_Z - 0.84)
		_box(_stage, foot, Vector3(0.28, 0.05, 0.24), Color("#a48266"))
		_box(_stage, foot + Vector3(0, 0.30, 0), Vector3(0.038, 0.58, 0.038), Color("#aa8d70"))
		_box(_stage, foot + Vector3(0, 0.58, 0.18), Vector3(0.07, 0.04, 0.39), Color("#aa8d70"))
		_box(_stage, foot + Vector3(0, 0.55, 0.39), Vector3(0.50, 0.11, 0.24), Color("#7e9a8d"))
		var diffuser := _box(_stage, foot + Vector3(0, 0.49, 0.39), Vector3(0.40, 0.018, 0.18), Color("#f0dbb4"))
		_front_lamp_glows.append(diffuser)
		var table_lamp := OmniLight3D.new()
		table_lamp.name = "PlatingTableGlassLamp"
		table_lamp.position = foot + Vector3(0, 0.48, 0.52)
		table_lamp.light_color = Color("#fff0d9")
		table_lamp.light_energy = 0.0
		table_lamp.omni_range = 5.2
		table_lamp.shadow_enabled = false
		_stage.add_child(table_lamp)
		_prep_table_lights.append(table_lamp)


func _build_guest_line() -> void:
	_box(_stage, Vector3(0, -0.17, 5.93), Vector3(10.5, 0.13, 1.82), Color("#a7aea0"))
	for x in [-3.5, -1.17, 1.17, 3.5]:
		_box(_stage, Vector3(x, -0.09, 5.93), Vector3(0.022, 0.01, 1.70), Color("#89998d"))
	var packed = load("res://assets/art/models/bay_resident.glb")
	for i in range(3):
		var pivot := Node3D.new()
		pivot.name = "WaitingGuest_%d" % i
		pivot.position = Vector3(-3.0 + float(i) * 3.0, -0.02, GUEST_QUEUE_Z + float(i) * 0.05)
		pivot.scale = Vector3.ONE * 0.02
		_stage.add_child(pivot)
		_guest_pivots.append(pivot)
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate() as Node3D
			model.scale = Vector3.ONE * float(GUEST_SCALES[i])
			pivot.add_child(model)
			_dress_guest(model, i)
			_refine_guest_arms(model, i)
			_simplify_guest(model)
			_guest_models.append(model)
		else:
			var fallback := Node3D.new()
			pivot.add_child(fallback)
			_sphere(fallback, Vector3(0, 1.25, 0), 0.23, Color("#ddb095"))
			_cylinder(fallback, Vector3(0, 0.68, 0), 0.28, 0.85, Color("#8caba3"))
			_guest_models.append(fallback)
		var cap := Node3D.new()
		pivot.add_child(cap)
		_cylinder(cap, Vector3(0, 1.80, 0), 0.27, 0.13, Color("#ce796a"))
		_box(cap, Vector3(0, 1.76, -0.22), Vector3(0.49, 0.055, 0.28), Color("#ce796a"))
		var sun_hat := Node3D.new()
		pivot.add_child(sun_hat)
		_cylinder(sun_hat, Vector3(0, 1.78, 0), 0.38, 0.065, Color("#d7ba7f"))
		_cylinder(sun_hat, Vector3(0, 1.90, 0), 0.25, 0.23, Color("#d7ba7f"))
		cap.visible = false
		sun_hat.visible = false
		_guest_hats.append([cap, sun_hat])
		var speech := Label3D.new()
		speech.position = Vector3(0, 2.25, 0)
		speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		speech.pixel_size = 0.009
		speech.font_size = 30
		speech.modulate = Color("#f6ead1")
		speech.outline_modulate = Color("#53665c")
		speech.outline_size = 6
		speech.visible = false
		pivot.add_child(speech)
		_guest_speech.append(speech)
		var order_card := Node3D.new()
		order_card.position = Vector3(0.31, 0.87, 0.26)
		pivot.add_child(order_card)
		_box(order_card, Vector3.ZERO, Vector3(0.25, 0.29, 0.035), Color("#f1e5cf"))
		var mark := _box(order_card, Vector3(0, 0.105, 0.022), Vector3(0.19, 0.035, 0.009), TICKET_LANE_COLORS[i])
		_guest_order_cards.append(order_card)
		_guest_card_marks.append(mark)
		_guest_joy.append(_make_guest_emotion(pivot, true))
		_guest_frustration.append(_make_guest_emotion(pivot, false))
		var area := _area(pivot, "ticket", str(i), "顾客订单 %d" % (i + 1), Vector3(0, 0.95, 0), Vector3(0.95, 1.95, 0.85))
		area.collision_layer = 0
		_guest_areas.append(area)


func _dress_guest(model: Node3D, index: int) -> void:
	if index == 0:
		return
	var jacket_color := Color("#ce816f") if index == 1 else Color("#bea26d")
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var part_name := str(part.name)
		if not (part_name.begins_with("jacket") or part_name in ["left_sleeve", "right_sleeve", "left_sleeve_cuff", "right_sleeve_cuff"]):
			continue
		var original = (part as MeshInstance3D).get_active_material(0)
		var material := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
		material.albedo_color = jacket_color
		(part as MeshInstance3D).material_override = material


func _apply_guest_variant(slot: int, customer_id: int) -> void:
	var variant := posmod(customer_id - 1, 5)
	var coat_colors := [Color("#79ada0"), Color("#ce816f"), Color("#bea26d"), Color("#91a9b2"), Color("#b391a9")]
	var model := _guest_models[slot]
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var name := str(part.name)
		if not name.begins_with("jacket") and not name.begins_with("GuestSleeve"):
			continue
		var mesh := part as MeshInstance3D
		var old := mesh.material_override as StandardMaterial3D
		var material := old.duplicate() as StandardMaterial3D if old != null else StandardMaterial3D.new()
		material.albedo_color = coat_colors[variant]
		mesh.material_override = material
	var hats: Array = _guest_hats[slot]
	(hats[0] as Node3D).visible = variant in [1, 3]
	(hats[1] as Node3D).visible = variant in [2, 4]
	if customer_id % 3 == 2:
		var lines := ["今天想吃点热的。", "湖边风真舒服。", "再来一份就好。", "闻到香味了。", "今天运气不错。"]
		var speech := _guest_speech[slot]
		speech.text = str(lines[posmod(customer_id, lines.size())])
		speech.modulate = Color("#f6ead1")
		speech.visible = true
		var motion := speech.create_tween()
		motion.tween_interval(1.7)
		motion.tween_property(speech, "modulate:a", 0.0, 0.55)
		motion.tween_callback(func() -> void: speech.visible = false)


func _refine_guest_arms(model: Node3D, index: int) -> void:
	# Replace the source model's separated cuff/hand beads with joined sleeve and palm forms.
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var part_name := str(part.name)
		if part_name.contains("sleeve") or part_name.contains("hand") or part_name.contains("thumb"):
			(part as MeshInstance3D).visible = false
	var sleeve_tint := Color("#79ada0") if index == 0 else (Color("#ce816f") if index == 1 else Color("#bea26d"))
	for side in [-1, 1]:
		var x := float(side) * 0.40
		var z := 0.04 if side < 0 else -0.04
		var sleeve := _capsule(model, Vector3(x, 1.04, z), 0.084, 0.57, sleeve_tint)
		sleeve.name = "GuestSleeve_%d" % side
		_cylinder(model, Vector3(x, 0.81, z + 0.02), 0.073, 0.065, Color("#e6d7bb"))
		_capsule(model, Vector3(x, 0.725, z + 0.05), 0.061, 0.205, Color("#e8b69a"))


func _simplify_guest(model: Node3D) -> void:
	# The source street resident has layered leg beads and many small accessories.
	# Give cafe visitors one clean trouser form and one shoe per foot instead.
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var name := str(part.name)
		if name.begins_with("left_trouser_") or name.begins_with("right_trouser_") or name.begins_with("left_visible_sock") or name.begins_with("right_visible_sock") or name.begins_with("left_sneaker") or name.begins_with("right_sneaker") or name.begins_with("left_shoe_") or name.begins_with("right_shoe_"):
			(part as MeshInstance3D).visible = false
		elif name.begins_with("crossbody_") or name.begins_with("satchel_") or name.begins_with("shirt_woven_") or name.begins_with("jacket_front_seam") or name.begins_with("jacket_patch_pocket") or name.begins_with("jacket_pocket_flap") or name == "zipper_pull" or name == "hair_clip":
			(part as MeshInstance3D).visible = false
	for side in [-1, 1]:
		var x := float(side) * 0.185
		_capsule(model, Vector3(x, 0.43, 0.01), 0.126, 0.75, Color("#4e5d68"))
		var shoe := _cylinder(model, Vector3(x, 0.115, 0.08), 0.122, 0.36, Color("#e8dece"))
		shoe.rotation.x = PI * 0.5
		_box(model, Vector3(x, 0.044, 0.08), Vector3(0.285, 0.037, 0.385), Color("#b7b3a5"))


func _make_guest_emotion(parent: Node3D, positive: bool) -> Node3D:
	var icon := Node3D.new()
	icon.position = Vector3(0, 2.22, 0.05)
	icon.visible = false
	parent.add_child(icon)
	_cylinder(icon, Vector3.ZERO, 0.22, 0.055, Color("#9ccbab") if positive else Color("#d59475"))
	for eye_x in [-0.075, 0.075]:
		_sphere(icon, Vector3(eye_x, 0.043, -0.075), 0.025, Color("#506358"))
	if positive:
		for x in [-0.07, 0.0, 0.07]:
			_sphere(icon, Vector3(x, 0.046, 0.065 + absf(x) * 0.42), 0.018, Color("#506358"))
	else:
		_box(icon, Vector3(0, 0.046, 0.075), Vector3(0.15, 0.018, 0.025), Color("#704c47"))
	return icon


func _build_staff() -> void:
	_prep_actor = _make_staff("res://assets/art/models/park_prep_assistant.glb", PREP_ACTOR_HOME, Color("#88a793"))
	_pickup_actor = _make_staff("res://assets/art/models/park_pickup_clerk.glb", Vector3(8.90, 0, 3.05), Color("#d49e83"))
	_prep_cargo = Node3D.new()
	_prep_cargo.position = Vector3(0, 0.93, 0.29)
	_prep_cargo.visible = false
	_prep_actor.add_child(_prep_cargo)
	_box(_prep_cargo, Vector3.ZERO, Vector3(0.52, 0.055, 0.35), Color("#c59c72"))
	for x in [-0.15, 0.0, 0.15]:
		_sphere(_prep_cargo, Vector3(x, 0.10, 0), 0.085, Color("#82aa7c"))
	_pickup_cargo = Node3D.new()
	_pickup_cargo.position = Vector3(0, 0.96, 0.31)
	_pickup_cargo.visible = false
	_pickup_actor.add_child(_pickup_cargo)


func _make_staff(path: String, at: Vector3, apron: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	_stage.add_child(pivot)
	if ResourceLoader.exists(path):
		var packed = ResourceLoader.load(path)
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate() as Node3D
			model.scale = Vector3(0.86, 1.17, 0.88)
			pivot.add_child(model)
			return pivot
	# The simple stand-in keeps animation and layout usable while a formal GLB imports.
	_cylinder(pivot, Vector3(0, 0.77, 0), 0.30, 0.75, apron)
	_sphere(pivot, Vector3(0, 1.35, 0), 0.28, Color("#e6b89b"))
	_cylinder(pivot, Vector3(0, 1.66, 0), 0.31, 0.15, Color("#f0e5cc"))
	for side in [-1, 1]:
		_cylinder(pivot, Vector3(float(side) * 0.16, 0.24, 0), 0.085, 0.43, Color("#61716d"))
		_capsule(pivot, Vector3(float(side) * 0.32, 0.94, 0.03), 0.11, 0.44, Color("#f1e8d9"))
		_capsule(pivot, Vector3(float(side) * 0.32, 0.69, 0.04), 0.075, 0.20, Color("#e6b89b"))
		_sphere(pivot, Vector3(float(side) * 0.10, 1.39, 0.25), 0.023, Color("#4c524d"))
	return pivot


func _build_side_rooms() -> void:
	# Extra width becomes pantry and pickup seating rather than an empty backdrop.
	_box(_stage, Vector3(-10.55, -0.20, 0.70), Vector3(6.40, 0.17, 11.4), Color("#b7a487"))
	_box(_stage, Vector3(9.25, -0.20, 0.70), Vector3(3.50, 0.17, 11.4), Color("#b7a487"))
	for side in [-1, 1]:
		var x := -13.75 if side < 0 else 10.95
		_box(_stage, Vector3(x, 0.87, 0.52), Vector3(0.16, 1.90, 11.3), Color("#9cb2a7"))
		_box(_stage, Vector3(x - float(side) * 0.08, 1.78, 0.52), Vector3(0.22, 0.11, 11.3), Color("#9b7359"))
	_box(_stage, Vector3(-10.8, 0.62, -4.73), Vector3(4.7, 1.12, 0.45), Color("#9e775d"))
	# The entire left bay is reserved for a readable warehouse-to-prep route.
	_box(_stage, Vector3(-10.8, 1.22, -4.73), Vector3(4.72, 0.08, 0.48), Color("#d8c29b"))
	_place_side_prop("park_kitchen_pantry_staples", Vector3(-10.8, 1.26, -4.73), 0.0, 1.12)
	_box(_stage, Vector3(9.15, 0.43, -2.0), Vector3(2.6, 0.86, 1.08), Color("#94735e"))
	_box(_stage, Vector3(9.15, 0.91, -2.0), Vector3(2.63, 0.10, 1.12), Color("#dfc9a7"))
	_place_side_prop("park_kitchen_pickup_packing", Vector3(9.15, 0.96, -2.0))
	_box(_stage, Vector3(9.0, 0.52, 0.72), Vector3(2.53, 1.02, 1.36), Color("#9f8976"))
	_box(_stage, Vector3(9.0, 1.08, 0.72), Vector3(2.56, 0.10, 1.40), Color("#d5c5a8"))
	_place_side_prop("park_kitchen_pickup_ready", Vector3(9.0, 1.13, 0.72))


func _build_fixed_pantry() -> void:
	# Each ingredient owns one permanent bay. The bulk stack repeats the same
	# portion model that is rendered into its meal-ticket icon.
	for row in range(RAW_GROUP_ORDER.size()):
		var group_id := str(RAW_GROUP_ORDER[row])
		var keys: Array = TalentParkRestaurant3D.RAW_GROUPS[group_id]
		for column in range(keys.size()):
			var key := str(keys[column])
			var bay := Node3D.new()
			bay.name = "IngredientBay_" + key
			bay.position = Vector3(-13.13 + float(column) * 1.06, 0, -3.49 + float(row) * 2.55)
			_stage.add_child(bay)
			_box(bay, Vector3(0, 0.36, 0), Vector3(0.97, 0.72, 1.72), Color("#92765f"))
			_box(bay, Vector3(0, 0.755, 0), Vector3(1.03, 0.08, 1.78), Color("#dcc8a5"))
			_box(bay, Vector3(0, 0.802, -0.39), Vector3(0.88, 0.024, 0.86), RAW_GROUP_COLORS[group_id].lightened(0.30))
			_box(bay, Vector3(0, 0.802, 0.41), Vector3(0.88, 0.024, 0.65), Color("#efe5d2"))
			_box(bay, Vector3(0, 0.82, 0.04), Vector3(0.87, 0.05, 0.035), Color("#ad9172"))
			for side in [-1, 1]:
				_box(bay, Vector3(float(side) * 0.49, 0.51, 0), Vector3(0.035, 0.53, 1.78), Color("#ad8a68"))
			var bulk := Node3D.new()
			bulk.name = "Bulk_" + key
			bulk.position = Vector3(0, 0.83, -0.39)
			bulk.scale = Vector3(2.10, 1.65, 1.20)
			bay.add_child(bulk)
			_add_bulk_ingredient_stack(bulk, key, group_id)
			_pantry_raw_models[key] = bulk
			var plaque := _box(bay, Vector3(0, 0.83, 0.41), Vector3(0.82, 0.018, 0.62), Color("#f2e7cf"))
			_pantry_refill_plaques[key] = plaque
			_box(bay, Vector3(-0.374, 0.843, 0.41), Vector3(0.034, 0.008, 0.58), RAW_GROUP_COLORS[group_id])
			# The identical RawMark is drawn on the screen at the projected plaque
			# position. This avoids blurring a low-resolution ViewportTexture in 3D.
			_pantry_mark_anchors[key] = bay
			var bubble := Node3D.new()
			bubble.name = "RefillBubble_" + key
			bubble.position = Vector3(0, 1.59, -0.25)
			bubble.visible = false
			bay.add_child(bubble)
			var bubble_viewport := SubViewport.new()
			bubble_viewport.size = Vector2i(192, 88)
			bubble_viewport.transparent_bg = true
			bubble_viewport.disable_3d = true
			# The callout is a still image. Its parent bubble breathes in 3D, so
			# redrawing twenty offscreen viewports every frame changes nothing.
			bubble_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			bay.add_child(bubble_viewport)
			_raw_need_viewports[key] = bubble_viewport
			var callout := IngredientCallout.new()
			callout.name = "Callout"
			callout.ingredient_id = key
			callout.callout_font = _playful_font
			callout.size = Vector2(96, 44)
			callout.scale = Vector2(2, 2)
			bubble_viewport.add_child(callout)
			_raw_need_callouts[key] = callout
			var bubble_face := Sprite3D.new()
			bubble_face.texture = bubble_viewport.get_texture()
			bubble_face.pixel_size = 0.005
			bubble_face.rotation.x = -PI * 0.5
			bubble.add_child(bubble_face)
			_raw_need_bubbles[key] = bubble
			var area := _area(bay, "raw", key, "%s · 仓库/备料" % str(INGREDIENT_LABELS[key]), Vector3(0, 1.10, 0), Vector3(0.99, 2.00, 1.74))
			area.name = "IngredientHotspot_" + key
			_raw_areas[key] = area


func _batch_fixed_pantry_bulk() -> void:
	# Three identical portions are stacked in every permanent ingredient bay.
	# Their meshes never move or disappear when stock changes; batch identical
	# mesh/material pairs while leaving hit areas and the changing labels alone.
	var groups: Dictionary = {}
	for bulk_root in _pantry_raw_models.values():
		for entry in (bulk_root as Node3D).find_children("*", "MeshInstance3D", true, false):
			var part := entry as MeshInstance3D
			var material := part.material_override as StandardMaterial3D
			if part.mesh == null or material == null or material.emission_enabled:
				continue
			var tint := material.albedo_color
			var key := "%d:%.8f:%.8f:%.8f:%.8f" % [part.mesh.get_instance_id(), tint.r, tint.g, tint.b, tint.a]
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(part)
	var stage_inverse := _stage.global_transform.affine_inverse()
	var batch_index := 0
	for parts in groups.values():
		var group: Array = parts
		if group.size() < 2:
			continue
		var first := group[0] as MeshInstance3D
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = first.mesh
		multimesh.instance_count = group.size()
		for index in range(group.size()):
			var part := group[index] as MeshInstance3D
			multimesh.set_instance_transform(index, stage_inverse * part.global_transform)
			part.visible = false
		var batch := MultiMeshInstance3D.new()
		batch.name = "BulkBatch_%d" % batch_index
		batch.multimesh = multimesh
		batch.material_override = first.material_override
		batch.cast_shadow = first.cast_shadow
		batch.layers = first.layers
		_stage.add_child(batch)
		batch_index += 1


func _build_pantry_screen_marks() -> void:
	for key in _pantry_mark_anchors.keys():
		var mark := RawMark.new()
		mark.name = "PantryMark_" + str(key)
		mark.ingredient_id = str(key)
		mark.short_name = str(INGREDIENT_SHORT[key])
		mark.count = 1
		mark.size = Vector2(38, 16)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_root.add_child(mark)
		_pantry_prep_models[key] = mark
		_pantry_prep_counts[key] = mark
	_position_pantry_screen_marks()


func _position_pantry_screen_marks() -> void:
	if not is_instance_valid(camera):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var camera_pose := camera.global_transform
	if _pantry_marks_positioned and viewport_size == _pantry_marks_last_viewport and camera_pose == _pantry_marks_last_camera:
		return
	_pantry_marks_last_camera = camera_pose
	_pantry_marks_last_viewport = viewport_size
	_pantry_marks_positioned = true
	_pantry_projection_updates += 1
	for key in _pantry_mark_anchors.keys():
		var bay := _pantry_mark_anchors[key] as Node3D
		var mark := _pantry_prep_counts[key] as RawMark
		var center_3d := bay.to_global(Vector3(0, 0.86, 0.41))
		var center := camera.unproject_position(center_3d)
		var left := camera.unproject_position(bay.to_global(Vector3(-0.39, 0.86, 0.41)))
		var right := camera.unproject_position(bay.to_global(Vector3(0.39, 0.86, 0.41)))
		var front := camera.unproject_position(bay.to_global(Vector3(0, 0.86, 0.11)))
		var back := camera.unproject_position(bay.to_global(Vector3(0, 0.86, 0.71)))
		var scale_factor := minf(left.distance_to(right) / 38.0, front.distance_to(back) / 16.0)
		mark.scale = Vector2.ONE * scale_factor
		mark.position = center - Vector2(19, 8) * scale_factor
		mark.visible = not camera.is_position_behind(center_3d) and center.x >= 0.0 and center.x <= viewport_size.x and center.y >= 0.0 and center.y <= viewport_size.y


func _refresh_fixed_pantry() -> void:
	var raw: Dictionary = _state.get("raw_ingredients", {}) if _state.get("raw_ingredients", {}) is Dictionary else {}
	var prepared: Dictionary = _state.get("prep_ingredients", {}) if _state.get("prep_ingredients", {}) is Dictionary else {}
	var needed := _missing_prep_keys()
	for key in _raw_areas.keys():
		var raw_count := int(raw.get(key, 0))
		var prep_count := int(prepared.get(key, 0))
		var count_chip := _pantry_prep_counts[key] as RawMark
		var chip_changed := count_chip.count != prep_count or count_chip.warehouse_count != raw_count or count_chip.enough != (prep_count > 0)
		count_chip.count = prep_count
		count_chip.warehouse_count = raw_count
		count_chip.enough = prep_count > 0
		if chip_changed:
			count_chip.queue_redraw()
		var plaque := _pantry_refill_plaques[key] as MeshInstance3D
		var plaque_material := plaque.material_override as StandardMaterial3D
		var plaque_color := Color("#f4dfbd") if prep_count <= 0 else Color("#f2e7cf")
		if plaque_material.emission_enabled != (prep_count <= 0) or plaque_material.albedo_color != plaque_color:
			plaque_material.albedo_color = plaque_color
			plaque_material.emission_enabled = prep_count <= 0
			plaque_material.emission = Color("#e3aa6b")
		# The bulk model is the permanent visual identity of this fixed bay.
		# Quantity changes on the chip; hiding the model made full-looking bays
		# suddenly become blank when warehouse stock reached zero.
		(_pantry_raw_models[key] as Node3D).visible = true
		var need_bubble := _raw_need_bubbles[key] as Node3D
		need_bubble.visible = needed.has(key)
		if need_bubble.visible:
			var callout := _raw_need_callouts[key] as IngredientCallout
			var caption := "缺料" if prep_count <= 0 else "补料"
			if callout.caption != caption:
				callout.caption = caption
				(_raw_need_viewports[key] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		var area := _raw_areas[key] as Area3D
		area.set_meta("display_name", "%s · 已备%d · 点击补料" % [str(INGREDIENT_LABELS[key]), prep_count])


func _animate_raw_staged(key: String) -> void:
	if not _raw_areas.has(key):
		return
	var ready := _pantry_prep_models[key] as RawMark
	ready.modulate = Color("#f3d8a2")
	ready.create_tween().tween_property(ready, "modulate", Color.WHITE, 0.30)


func _build_prep_table() -> void:
	# One large counter shows the selected dish's actual staged ingredients.
	var table := Node3D.new()
	table.name = "IngredientPreparationTable"
	table.position = Vector3(-10.25, 0, 1.56)
	_stage.add_child(table)
	_box(table, Vector3(0, 0.42, 0), Vector3(3.90, 0.84, 2.78), Color("#9b775e"))
	_box(table, Vector3(0, 0.85, 0), Vector3(4.06, 0.10, 2.90), Color("#e3d1aa"))
	for side in [-1, 1]:
		_box(table, Vector3(float(side) * 2.00, 0.90, 0), Vector3(0.045, 0.07, 2.88), Color("#b39270"))
	for side in [-1, 1]:
		_box(table, Vector3(0, 0.90, float(side) * 1.425), Vector3(4.04, 0.07, 0.045), Color("#b39270"))
	for side in [-1, 1]:
		_box(table, Vector3(float(side) * 0.96, 0.36, 1.418), Vector3(1.76, 0.55, 0.035), Color("#b18d6f"))
		_cylinder(table, Vector3(float(side) * 0.96, 0.39, 1.45), 0.055, 0.025, Color("#d6bd8f"))
	for index in range(4):
		var slot := Node3D.new()
		slot.name = "PreparedIngredient_%d" % index
		slot.position = Vector3(-1.00 if index % 2 == 0 else 1.00, 0, -0.71 if index < 2 else 0.59)
		table.add_child(slot)
		_cylinder(slot, Vector3(0, 0.924, 0), 0.65, 0.035, Color("#9e7d60"))
		_cylinder(slot, Vector3(0, 1.010, 0), 0.59, 0.108, Color("#d8c6ab"))
		_cylinder(slot, Vector3(0, 1.033, 0), 0.51, 0.012, Color("#b4a390"))
		var well := _cylinder(slot, Vector3(0, 1.043, 0), 0.47, 0.012, Color("#eee6d4"))
		_prep_slot_wells.append(well)
		var pips: Array = []
		for n in range(TalentParkRestaurant3D.PREP_PER_KIND):
			var angle := 0.12 + (PI - 0.24) * float(n) / float(TalentParkRestaurant3D.PREP_PER_KIND - 1)
			var pip := _sphere(slot, Vector3(cos(angle) * 0.535, 1.080, sin(angle) * 0.535), 0.031, Color("#ad9b7e"), true)
			pip.scale = Vector3(0.78, 0.40, 0.78)
			pips.append(pip)
		_prep_slot_pips.append(pips)
		var goods := Node3D.new()
		goods.position = Vector3(0, 1.05, -0.035)
		goods.scale = Vector3.ONE * 1.18
		slot.add_child(goods)
		_prep_slot_models.append(goods)
	_prep_counter_face = _box(table, Vector3(0, 0.55, 1.47), Vector3(3.89, 0.30, 0.045), Color("#ead9b7"))
	for n in range(3):
		_box(table, Vector3(-0.46 + float(n) * 0.46, 0.55, 1.504), Vector3(0.27, 0.055, 0.008), Color("#91a997"))
	for i in range(20):
		var peg := _sphere(table, Vector3(-1.75 + float(i) * 0.184, 0.95, -1.31), 0.033, Color("#b3a58a"), true)
		peg.scale.y = 0.35
		_prep_capacity_pegs.append(peg)
	_prep_pickup_lamp = _sphere(table, Vector3(1.86, 0.96, 1.28), 0.065, Color("#7eab90"), true)
	_prep_receive_bubble = _ingredient_bubble(table, Vector3(0, 2.14, 0.60))
	_prep_receive_goods = Node3D.new()
	_prep_receive_goods.position = Vector3(0, -0.09, 0.19)
	_prep_receive_goods.rotation.x = 0.87
	_prep_receive_bubble.add_child(_prep_receive_goods)
	_prep_area = _area(table, "prep_table", "prep_table", "备料台", Vector3(0, 1.05, 0), Vector3(4.03, 0.47, 2.88))


func _ingredient_bubble(parent: Node3D, at: Vector3) -> Node3D:
	var bubble := Node3D.new()
	bubble.position = at
	bubble.scale = Vector3.ONE * 0.82
	# Face the fixed 45-degree camera so the prompt reads as a speech bubble,
	# rather than a plate lying over the ingredient crate.
	bubble.rotation.x = -0.87
	bubble.visible = false
	parent.add_child(bubble)
	var outer := _sphere(bubble, Vector3.ZERO, 0.43, Color("#c79e6f"))
	outer.scale = Vector3(1.06, 0.82, 0.18)
	var inner := _sphere(bubble, Vector3(0, 0, 0.06), 0.39, Color("#f5ecd5"))
	inner.scale = Vector3(1.05, 0.81, 0.17)
	var tail := _box(bubble, Vector3(-0.17, -0.39, 0.01), Vector3(0.16, 0.19, 0.055), Color("#f5ecd5"))
	tail.rotation.z = -PI * 0.26
	return bubble


func _build_raw_bins() -> void:
	# Four partitioned produce drawers sit beside the preparation counter.
	# Ingredients and physical inventory dots replace written shelf labels.
	_box(_stage, Vector3(-10.25, 1.59, -3.31), Vector3(3.87, 0.29, 0.08), Color("#e8d5b2"))
	for n in range(3):
		var pictogram := Node3D.new()
		pictogram.position = Vector3(-0.47 + float(n) * 0.47 - 10.25, 1.73, -3.24)
		_stage.add_child(pictogram)
		_add_raw_ingredient(pictogram, ["rice_flour", "leafy_greens", "egg"][n], 0.0)
	for i in range(RAW_GROUP_ORDER.size()):
		var group_id := str(RAW_GROUP_ORDER[i])
		var tint: Color = RAW_GROUP_COLORS[group_id]
		var crate := Node3D.new()
		crate.name = "RawIngredientCrate_" + group_id
		crate.position = _raw_crate_point(i)
		crate.scale = Vector3(1.16, 1.0, 1.12)
		_stage.add_child(crate)
		_box(crate, Vector3(0, 0.35, 0), Vector3(1.43, 0.70, 1.13), Color("#92765d"))
		_box(crate, Vector3(0, 0.74, 0), Vector3(1.49, 0.085, 1.18), Color("#d4bd96"))
		_box(crate, Vector3(0, 0.777, -0.12), Vector3(1.34, 0.018, 0.79), Color("#806b55"))
		_box(crate, Vector3(0, 0.79, -0.11), Vector3(1.29, 0.018, 0.75), tint.lightened(0.40))
		for side in [-1, 1]:
			_box(crate, Vector3(float(side) * 0.61, 0.39, 0.58), Vector3(0.07, 0.58, 0.045), Color("#b69370"))
			_box(crate, Vector3(float(side) * 0.70, 0.77, 0), Vector3(0.045, 0.045, 1.10), Color("#b2926e"))
			_box(crate, Vector3(float(side) * 0.59, 0.81, -0.11), Vector3(0.035, 0.065, 0.79), Color("#ead9b7"))
			_cylinder(crate, Vector3(float(side) * 0.58, 0.43, 0.62), 0.028, 0.016, Color("#d5c49e"))
		_box(crate, Vector3(0, 0.81, -0.49), Vector3(1.28, 0.065, 0.035), Color("#ead9b7"))
		var goods: Array = []
		for n in range(5):
			var x := -0.50 + float(n) * 0.25
			var ingredient := Node3D.new()
			ingredient.position = Vector3(x, 0.79, -0.12)
			ingredient.scale.x = 0.84
			crate.add_child(ingredient)
			_add_bulk_warehouse_item(ingredient, group_id, n)
			goods.append(ingredient)
			if n < 4:
				_box(crate, Vector3(x + 0.125, 0.82, -0.12), Vector3(0.022, 0.09, 0.72), Color("#c4aa87"))
		_raw_bin_units[group_id] = goods
		_box(crate, Vector3(0, 0.42, 0.60), Vector3(1.27, 0.46, 0.035), Color("#e7d7b7"))
		_box(crate, Vector3(0, 0.25, 0.635), Vector3(0.43, 0.06, 0.025), Color("#c6ad88"))
		for slat in range(2):
			_box(crate, Vector3(0, 0.55 - float(slat) * 0.15, 0.643), Vector3(1.20, 0.018, 0.022), Color("#ccb693"))
		var pips: Array = []
		for n in range(4):
			var pip := _sphere(crate, Vector3(-0.41 + float(n) * 0.275, 0.40, 0.65), 0.077, tint, true)
			pip.scale = Vector3(0.90, 0.58, 0.24)
			pips.append(pip)
		_raw_bin_pips[group_id] = pips
		var bubble := _ingredient_bubble(crate, Vector3(0, 2.36, 0.13))
		var bubble_food := Node3D.new()
		bubble_food.name = "NeededIngredient"
		bubble_food.position = Vector3(0, -0.09, 0.19)
		bubble_food.rotation.x = 0.87
		bubble.add_child(bubble_food)
		_raw_need_bubbles[group_id] = bubble
		_raw_bin_lamps[group_id] = _sphere(crate, Vector3(0.58, 0.78, 0.35), 0.048, Color("#729f82"), true)
		_raw_areas[group_id] = _area(crate, "raw", group_id, str(RAW_GROUP_LABELS[group_id]), Vector3(0, 0.54, 0), Vector3(1.49, 1.08, 1.20))


func _raw_crate_point(index: int) -> Vector3:
	return Vector3(-11.30 if index % 2 == 0 else -9.20, 0, -2.76 if index < 2 else -1.04)


func _add_bulk_ingredient_stack(holder: Node3D, key: String, group_id: String) -> void:
	_box(holder, Vector3(0, 0.014, -0.02), Vector3(0.39, 0.028, 0.53), RAW_GROUP_COLORS[group_id].darkened(0.18))
	for i in range(3):
		var portion := Node3D.new()
		portion.position = Vector3(-0.115 if i == 0 else 0.115 if i == 1 else 0.0, 0.0, -0.13 if i < 2 else 0.13)
		holder.add_child(portion)
		_add_raw_ingredient(portion, key, 0.0)


func _add_bulk_warehouse_item(holder: Node3D, group_id: String, slot: int) -> void:
	# Each shelf cell represents a bulk carton, not one loose recipe portion.
	# The floating request bubble above it still shows the exact needed item.
	match group_id:
		"staples":
			if slot in [0, 2, 4]:
				var cloth := Color("#e7d7b9") if slot != 2 else Color("#d9c39d")
				_box(holder, Vector3(0, 0.125, -0.02), Vector3(0.248, 0.18, 0.56), cloth)
				var bulge := _sphere(holder, Vector3(0, 0.205, -0.02), 0.145, cloth.lightened(0.08))
				bulge.scale = Vector3(0.83, 0.36, 1.85)
				for fold in [-1, 1]:
					_box(holder, Vector3(0, 0.235, float(fold) * 0.262), Vector3(0.24, 0.015, 0.018), Color("#baa98c"))
				_box(holder, Vector3(0, 0.257, -0.015), Vector3(0.157, 0.010, 0.18), Color("#9caf8e") if slot != 2 else Color("#c8ad73"))
				for grain in range(3):
					_sphere(holder, Vector3(-0.047 + float(grain) * 0.047, 0.268, -0.014), 0.018, Color("#e9d9ab")).scale = Vector3(0.48, 0.24, 0.90)
			elif slot == 1:
				for row in range(3):
					var z := -0.23 + float(row) * 0.20
					_sphere(holder, Vector3(0, 0.135, z), 0.113, Color("#d7ab79")).scale.y = 0.61
					_box(holder, Vector3(0, 0.142, z + 0.085), Vector3(0.13, 0.008, 0.006), Color("#ae7958"))
			else:
				for row in range(3):
					var z := -0.23 + float(row) * 0.20
					_cylinder(holder, Vector3(0, 0.085, z), 0.092, 0.085, Color("#9ab5a4"))
					for strand in range(3):
						_box(holder, Vector3(-0.053 + float(strand) * 0.053, 0.133, z), Vector3(0.014, 0.008, 0.13), Color("#e2c284"))
		"fresh":
			_box(holder, Vector3(0, 0.045, -0.02), Vector3(0.26, 0.055, 0.62), Color("#b4936b"))
			for side in [-1, 1]:
				_box(holder, Vector3(float(side) * 0.13, 0.105, -0.02), Vector3(0.026, 0.14, 0.64), Color("#9f7e59"))
			for row in range(3):
				var z := -0.23 + float(row) * 0.20
				match slot:
					0:
						var leaf := _sphere(holder, Vector3(0, 0.145, z), 0.130, Color("#6d9d68"))
						leaf.scale = Vector3(0.78, 0.53, 0.91)
						_box(holder, Vector3(0, 0.218, z), Vector3(0.015, 0.006, 0.14), Color("#b8ca8d"))
					1:
						var cucumber := _cylinder(holder, Vector3(0, 0.130, z), 0.067, 0.230, Color("#5d9667"))
						cucumber.rotation.z = PI * 0.5
						_box(holder, Vector3(0, 0.190, z), Vector3(0.175, 0.007, 0.013), Color("#84af72"))
					2:
						_sphere(holder, Vector3(0, 0.150, z), 0.098, Color("#d58975") if row < 2 else Color("#dbb36b"))
						_sphere(holder, Vector3(0.042, 0.234, z), 0.035, Color("#71976a")).scale = Vector3(1.20, 0.26, 0.66)
					3:
						_box(holder, Vector3(0, 0.132, z), Vector3(0.202, 0.025, 0.158), Color("#496e61"))
						_box(holder, Vector3(0, 0.148, z), Vector3(0.025, 0.004, 0.125), Color("#83a978"))
					4:
						for petal in range(4):
							_sphere(holder, Vector3(cos(float(petal) * PI * 0.5) * 0.052, 0.125, z + sin(float(petal) * PI * 0.5) * 0.052), 0.037, Color("#e1bb74"))
						_sphere(holder, Vector3(0, 0.146, z), 0.025, Color("#b08353"))
		"protein":
			_box(holder, Vector3(0, 0.045, -0.02), Vector3(0.26, 0.06, 0.62), Color("#b6cbc0"))
			for row in range(3):
				var z := -0.23 + float(row) * 0.20
				_box(holder, Vector3(0, 0.066, z), Vector3(0.18, 0.018, 0.16), Color("#d4e0d5"))
				match slot:
					0:
						var cut := _capsule(holder, Vector3(0, 0.132, z), 0.080, 0.178, Color("#c58771"))
						cut.rotation.z = PI * 0.5
					1:
						_sphere(holder, Vector3(0, 0.132, z), 0.088, Color("#eadcc1")).scale = Vector3(0.82, 0.70, 0.92)
					2:
						_box(holder, Vector3(0, 0.139, z), Vector3(0.170, 0.122, 0.146), Color("#efe4ca"))
						_box(holder, Vector3(0, 0.204, z), Vector3(0.126, 0.007, 0.108), Color("#fff2d9"))
					3:
						for piece in range(3):
							_sphere(holder, Vector3(-0.055 + float(piece) * 0.053, 0.119, z), 0.046, Color("#dc9b84") if piece % 2 == 0 else Color("#edb8a0"))
					4:
						_cylinder(holder, Vector3(0, 0.132, z), 0.076, 0.150, Color("#e1e7d8"))
						_cylinder(holder, Vector3(0, 0.214, z), 0.081, 0.018, Color("#8aafa1"))
		"pantry":
			var bottle_colors: Array[Color] = [Color("#795748"), Color("#b67b52"), Color("#c7995f"), Color("#ddd5bb"), Color("#d3e2df")]
			var bottle_color: Color = bottle_colors[slot]
			for row in range(2):
				var z := -0.20 + float(row) * 0.33
				if slot == 4:
					_box(holder, Vector3(0, 0.120, z), Vector3(0.18, 0.15, 0.22), bottle_color)
					_box(holder, Vector3(0, 0.205, z), Vector3(0.13, 0.018, 0.16), Color("#edf4ec"))
				else:
					_cylinder(holder, Vector3(0, 0.138, z), 0.075, 0.230, bottle_color)
					_cylinder(holder, Vector3(0, 0.264, z), 0.053, 0.035, Color("#adbea4"))
					_box(holder, Vector3(0, 0.147, z + 0.073), Vector3(0.105, 0.075, 0.009), Color("#eadcbd"))


func _refresh_raw_bins() -> void:
	var raw: Dictionary = _state.get("raw_ingredients", {}) if _state.get("raw_ingredients", {}) is Dictionary else {}
	var missing := _missing_prep_keys()
	var carried: Dictionary = _state.get("carried_ingredients", {}) if _state.get("carried_ingredients", {}) is Dictionary else {}
	for group_id in RAW_GROUP_ORDER:
		var keys: Array = TalentParkRestaurant3D.RAW_GROUPS[group_id]
		var total := 0
		var needed_key := ""
		for key in keys:
			var quantity := int(raw.get(str(key), 6))
			total += quantity
			if needed_key.is_empty() and missing.has(str(key)):
				needed_key = str(key)
		var required := not needed_key.is_empty()
		var bubble := _raw_need_bubbles[group_id] as Node3D
		bubble.visible = required and carried.is_empty()
		if bubble.visible and str(bubble.get_meta("ingredient", "")) != needed_key:
			bubble.set_meta("ingredient", needed_key)
			var bubble_food := bubble.get_node("NeededIngredient") as Node3D
			for child in bubble_food.get_children():
				child.free()
			bubble_food.scale = Vector3.ONE * 1.95
			_add_raw_ingredient(bubble_food, needed_key, 0.0)
		(_raw_areas[group_id] as Area3D).set_meta("display_name", "仓库 · %s · %d 份" % [str(RAW_GROUP_LABELS[group_id]), total])
		var lamp := _raw_bin_lamps[group_id] as MeshInstance3D
		var lamp_material := lamp.material_override as StandardMaterial3D
		lamp_material.albedo_color = Color("#d9a16c") if required and carried.is_empty() else Color("#729f82")
		lamp_material.emission = lamp_material.albedo_color
		lamp_material.emission_energy_multiplier = 0.24 if required and carried.is_empty() else 0.08
		for n in range(keys.size()):
			(_raw_bin_units[group_id][n] as Node3D).visible = int(raw.get(str(keys[n]), 0)) > 0
		for n in range(4):
			var pip_material := (_raw_bin_pips[group_id][n] as MeshInstance3D).material_override as StandardMaterial3D
			pip_material.albedo_color = RAW_GROUP_COLORS[group_id] if total > n * 35 else Color("#b6ac98")
			pip_material.emission = pip_material.albedo_color
			pip_material.emission_energy_multiplier = 0.10 if total > n * 15 else 0.0


func _selected_prep_keys() -> Array[String]:
	var keys: Array[String] = []
	if str(_state.get("selected_target", "ticket")) == "stock":
		var job: Dictionary = _state.get("stock_job", {}) if _state.get("stock_job", {}) is Dictionary else {}
		var stock_id := str(job.get("id", ""))
		if TalentParkRestaurant3D.STOCKS.has(stock_id):
			keys.append(str(TalentParkRestaurant3D.STOCKS[stock_id]["ingredient_key"]))
		return keys
	var tickets: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
	var selected := int(_state.get("selected_slot", 0))
	if selected < 0 or selected >= tickets.size() or not tickets[selected] is Dictionary:
		return keys
	var ticket: Dictionary = tickets[selected]
	var recipe: Dictionary = ticket.get("recipe", {}) if ticket.get("recipe", {}) is Dictionary else {}
	for ingredient in recipe.get("ingredients", []):
		keys.append(str(ingredient))
	return keys


func _missing_prep_keys() -> Array[String]:
	var missing: Array[String] = []
	var prep: Dictionary = _state.get("prep_ingredients", {}) if _state.get("prep_ingredients", {}) is Dictionary else {}
	var carried: Dictionary = _state.get("carried_ingredients", {}) if _state.get("carried_ingredients", {}) is Dictionary else {}
	var tickets: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
	var selected := int(_state.get("selected_slot", 0))
	for key in _selected_prep_keys():
		if int(prep.get(key, 0)) < 3 and int(carried.get(key, 0)) <= 0:
			missing.append(key)
	return missing


func _refresh_prep_table() -> void:
	if not is_instance_valid(_prep_area):
		return
	var raw: Dictionary = _state.get("prep_ingredients", {}) if _state.get("prep_ingredients", {}) is Dictionary else {}
	var carried: Dictionary = _state.get("carried_ingredients", {}) if _state.get("carried_ingredients", {}) is Dictionary else {}
	var used := int(_state.get("prep_used", 0))
	var capacity := int(_state.get("prep_capacity", 28))
	var carrying := 0
	for amount in carried.values():
		carrying += int(amount)
	_prep_area.set_meta("display_name", "备料台 · %d/%d · 手持%d" % [used, capacity, carrying])
	var counter_material := _prep_counter_face.material_override as StandardMaterial3D
	counter_material.albedo_color = Color("#f0d7b0") if carrying > 0 else (Color("#d7a78e") if used >= capacity else Color("#ead9b7"))
	_prep_receive_bubble.visible = carrying > 0 or used >= capacity
	if _prep_receive_bubble.visible:
		var bubble_key := str(carried.keys()[0]) if carrying > 0 else "full"
		if str(_prep_receive_bubble.get_meta("ingredient", "")) != bubble_key:
			_prep_receive_bubble.set_meta("ingredient", bubble_key)
			for child in _prep_receive_goods.get_children():
				child.free()
			_prep_receive_goods.scale = Vector3.ONE * 1.95
			if bubble_key == "full":
				for n in range(3):
					_box(_prep_receive_goods, Vector3(-0.11 + float(n) * 0.11, 0.07 + float(n % 2) * 0.09, 0), Vector3(0.11, 0.09, 0.10), Color("#d2ae80"))
			else:
				_add_raw_ingredient(_prep_receive_goods, bubble_key, 0.0)
	var keys := _selected_prep_keys()
	for slot in range(_prep_slot_models.size()):
		var goods := _prep_slot_models[slot]
		var key := keys[slot] if slot < keys.size() else ""
		goods.visible = not key.is_empty()
		var quantity := int(raw.get(key, 0))
		goods.scale = Vector3(1.40, 0.22, 1.40) if quantity <= 0 else Vector3.ONE * (1.45 if quantity == 1 else 1.05)
		var well_material := _prep_slot_wells[slot].material_override as StandardMaterial3D
		well_material.albedo_color = Color("#eee6d4") if key.is_empty() else (Color("#ead6b3") if quantity <= 0 else _ingredient_group_color(key).lightened(0.43))
		for n in range(_prep_slot_pips[slot].size()):
			var pip := _prep_slot_pips[slot][n] as MeshInstance3D
			var pip_material := pip.material_override as StandardMaterial3D
			pip_material.albedo_color = Color("#b3a188") if key.is_empty() else (Color("#d8a26d") if quantity <= 0 else Color("#84a997") if n < quantity else Color("#b3a188"))
			pip_material.emission = pip_material.albedo_color
			pip_material.emission_energy_multiplier = 0.08 if not key.is_empty() and n < quantity else 0.0
		if key.is_empty():
			continue
		var display_key := "%s:%d" % [key, quantity]
		if goods.has_meta("display_key") and str(goods.get_meta("display_key")) == display_key:
			continue
		goods.set_meta("display_key", display_key)
		for child in goods.get_children():
			child.free()
		for n in range(maxi(1, mini(quantity, 3))):
			_add_raw_ingredient(goods, key, 0.0 if quantity <= 1 else -0.22 + float(n) * 0.22)
		if quantity <= 0:
			for mesh in goods.find_children("*", "MeshInstance3D", true, false):
				var ghost_material := (mesh as MeshInstance3D).material_override as StandardMaterial3D
				ghost_material.albedo_color = Color(0.69, 0.66, 0.58, 0.69)
				ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(_prep_capacity_pegs.size()):
		var peg := _prep_capacity_pegs[i]
		var material := peg.material_override as StandardMaterial3D
		material.albedo_color = Color("#80ad92") if used > i * 13 else Color("#b3a58a")
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.10 if used > i * 6 else 0.0
	var lamp_material := _prep_pickup_lamp.material_override as StandardMaterial3D
	lamp_material.albedo_color = Color("#e7b978") if not carried.is_empty() else (Color("#c3836c") if used >= capacity else Color("#7eab90"))
	lamp_material.emission = lamp_material.albedo_color
	lamp_material.emission_energy_multiplier = 0.35 if not carried.is_empty() else 0.08


func _ingredient_group_color(ingredient_key: String) -> Color:
	for group_id in RAW_GROUP_ORDER:
		if (TalentParkRestaurant3D.RAW_GROUPS[group_id] as Array).has(ingredient_key):
			return RAW_GROUP_COLORS[group_id]
	return Color("#d3bc96")


func _build_cash_register() -> void:
	# Revenue lands in a visible till beside the pickup station.
	var till := Node3D.new()
	till.name = "CafeCashRegister"
	till.position = Vector3(10.0, 0, 2.40)
	_stage.add_child(till)
	_box(till, Vector3(0, 0.34, 0), Vector3(1.14, 0.67, 0.84), Color("#95775e"))
	_box(till, Vector3(0, 0.71, 0), Vector3(1.22, 0.08, 0.92), Color("#d8c39e"))
	_box(till, Vector3(0, 0.81, -0.10), Vector3(0.73, 0.19, 0.50), Color("#77998b"))
	_box(till, Vector3(0, 0.96, -0.26), Vector3(0.57, 0.035, 0.22), Color("#b8c3aa"))
	_box(till, Vector3(0, 0.985, -0.24), Vector3(0.41, 0.008, 0.10), Color("#58766c"))
	for row in range(2):
		for col in range(4):
			_box(till, Vector3(-0.23 + float(col) * 0.15, 0.918, -0.01 + float(row) * 0.12), Vector3(0.09, 0.018, 0.07), Color("#dfd0ac"))
	_register_drawer = Node3D.new()
	_register_drawer.name = "CashDrawer"
	_register_drawer.position = Vector3(0, 0, 0.04)
	till.add_child(_register_drawer)
	_box(_register_drawer, Vector3(0, 0.76, 0.35), Vector3(0.77, 0.12, 0.30), Color("#846955"))
	_box(_register_drawer, Vector3(0, 0.82, 0.36), Vector3(0.60, 0.014, 0.20), Color("#453f38"))
	_box(_register_drawer, Vector3(-0.12, 0.825, 0.36), Vector3(0.025, 0.014, 0.19), Color("#a9987e"))
	_box(_register_drawer, Vector3(0.12, 0.825, 0.36), Vector3(0.025, 0.014, 0.19), Color("#a9987e"))
	for i in range(2):
		_make_cash_note(_register_drawer, Vector3(-0.23 + float(i) * 0.07, 0.837, 0.36))
	for i in range(3):
		_make_cash_coin(_register_drawer, Vector3(0.16 + float(i) * 0.075, 0.843, 0.36), i % 2 == 0)
	_box(_register_drawer, Vector3(0, 0.76, 0.515), Vector3(0.17, 0.027, 0.021), Color("#cba776"))
	_register_lamp = _sphere(till, Vector3(0.43, 0.95, -0.13), 0.051, Color("#719f88"), true)
	_register_lamp.scale.y = 0.55
	_box(till, Vector3(-0.44, 0.78, -0.19), Vector3(0.20, 0.16, 0.23), Color("#e8ddc3"))
	_box(till, Vector3(-0.44, 0.87, -0.19), Vector3(0.15, 0.012, 0.065), Color("#514d45"))
	_register_receipt = Node3D.new()
	_register_receipt.position = Vector3(-0.44, 0.89, -0.23)
	till.add_child(_register_receipt)
	_register_receipt.scale.z = 0.03
	_box(_register_receipt, Vector3(0, 0, -0.10), Vector3(0.14, 0.003, 0.24), Color("#f8f1dc"))
	for i in range(3):
		_box(_register_receipt, Vector3(-0.005, 0.003, -0.10 - float(i) * 0.055), Vector3(0.09 - float(i) * 0.012, 0.001, 0.008), Color("#aaa694"))


func _build_close_sign() -> void:
	# A small modeled shutter switch belongs to the cash desk joinery.
	var sign := Node3D.new()
	sign.name = "ClosingSwitch"
	sign.position = Vector3(9.94, 1.57, -0.58)
	_stage.add_child(sign)
	_box(sign, Vector3(0, 0, 0), Vector3(0.76, 0.66, 0.10), Color("#866e57"))
	_box(sign, Vector3(0, 0.01, 0.058), Vector3(0.66, 0.56, 0.017), Color("#e8dabc"))
	_box(sign, Vector3(0, 0.23, 0.078), Vector3(0.72, 0.11, 0.035), Color("#6e8e7a"))
	for stripe in range(5):
		_box(sign, Vector3(-0.27 + float(stripe) * 0.135, 0.18, 0.096), Vector3(0.073, 0.06, 0.012), Color("#d7b481") if stripe % 2 == 0 else Color("#f2e8ce"))
	for side in [-1, 1]:
		_box(sign, Vector3(float(side) * 0.23, -0.11, 0.083), Vector3(0.032, 0.31, 0.018), Color("#8d735d"))
	_box(sign, Vector3(0, -0.08, 0.086), Vector3(0.38, 0.30, 0.012), Color("#becbb7"))
	for slat in range(3):
		_box(sign, Vector3(0, -0.19 + float(slat) * 0.085, 0.098), Vector3(0.35, 0.018, 0.010), Color("#7e9b86"))
	_cylinder(sign, Vector3(0.30, -0.22, 0.10), 0.045, 0.026, Color("#d1ac70"))
	_closing_sign_area = _area(sign, "close_sign", "close_day", "打烊结算", Vector3.ZERO, Vector3(0.82, 0.72, 0.34))


func _place_side_prop(asset_id: String, world_position: Vector3, yaw := 0.0, x_scale := 1.0) -> void:
	var path := "res://assets/art/models/kitchen/%s.glb" % asset_id
	var packed = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	if packed is PackedScene:
		var model := (packed as PackedScene).instantiate() as Node3D
		model.name = asset_id
		model.position = world_position
		model.rotation.y = yaw
		model.scale.x = x_scale
		_stage.add_child(model)


func _build_scene_clock() -> void:
	# The period lamps rest on the side console. The clock's sealed back is set
	# against the solid service-bay rear wall, facing the player.
	_box(_stage, Vector3(9.15, 0.62, -3.22), Vector3(1.68, 1.17, 0.84), Color("#9f826a"))
	_box(_stage, Vector3(9.15, 1.23, -3.22), Vector3(1.76, 0.09, 0.91), Color("#d9c39e"))
	_box(_stage, Vector3(10.23, 1.30, -4.825), Vector3(0.13, 0.13, 0.045), Color("#80654f"))
	var clock_mount := Node3D.new()
	clock_mount.name = "WallClock"
	clock_mount.position = Vector3(10.23, 1.30, -4.820)
	clock_mount.rotation.x = PI * 0.5
	_stage.add_child(clock_mount)
	var packed = ResourceLoader.load("res://assets/art/models/kitchen/park_kitchen_wall_clock.glb")
	if packed is PackedScene:
		clock_mount.add_child((packed as PackedScene).instantiate())
	_clock_hour_hand = Node3D.new()
	_clock_hour_hand.position = Vector3(0, 0.177, 0)
	clock_mount.add_child(_clock_hour_hand)
	_box(_clock_hour_hand, Vector3(0, 0, -0.11), Vector3(0.055, 0.018, 0.24), Color("#655d50"))
	_clock_minute_hand = Node3D.new()
	_clock_minute_hand.position = Vector3(0, 0.190, 0)
	clock_mount.add_child(_clock_minute_hand)
	_box(_clock_minute_hand, Vector3(0, 0, -0.16), Vector3(0.030, 0.016, 0.34), Color("#b97761"))
	_sphere(clock_mount, Vector3(0, 0.205, 0), 0.030, Color("#aa805e"))
	for i in range(3):
		var lamp_x := 8.58 + float(i) * 0.57
		_cylinder(_stage, Vector3(lamp_x, 1.295, -3.12), 0.095, 0.040, Color("#886e57"))
		var lamp := _sphere(_stage, Vector3(lamp_x, 1.365, -3.12), 0.075, Color("#7c7568"), true)
		_period_lamps.append(lamp)


func _build_shift_bells() -> void:
	# The two physical bells let players start another shift without leaving the kitchen.
	for i in range(2):
		var mode := "calm" if i == 0 else "rush"
		var x := -9.89 + float(i) * 1.43
		var plinth := Node3D.new()
		plinth.name = "ShiftBell_" + mode
		plinth.position = Vector3(x, 0, 3.70)
		_stage.add_child(plinth)
		_box(plinth, Vector3(0, 0.25, 0), Vector3(1.08, 0.52, 0.88), Color("#997761"))
		_box(plinth, Vector3(0, 0.54, 0), Vector3(1.15, 0.075, 0.96), Color("#d3bc99"))
		_cylinder(plinth, Vector3(0, 0.66, 0), 0.31, 0.075, Color("#a57a59"))
		var bell := _sphere(plinth, Vector3(0, 0.78, 0), 0.23, Color("#a8b999") if i == 0 else Color("#c88f76"))
		bell.scale.y = 0.65
		_shift_bells.append(bell)
		_cylinder(plinth, Vector3(0, 0.90, 0), 0.055, 0.060, Color("#f0d7a4"))
		var area := _area(plinth, "shift", mode, "开启悠闲班" if i == 0 else "开启忙碌班", Vector3(0, 0.69, 0), Vector3(1.08, 0.83, 0.92))
		_shift_areas.append(area)
		var halo := _edge_cue(plinth, Vector3(0, 0.58, 0.50), 0.77)
		halo.visible = false
		_shift_halos.append(halo)


func _build_front_prep_table() -> void:
	var path := "res://assets/art/models/kitchen/park_kitchen_front_prep_table.glb"
	var packed = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	if packed is PackedScene:
		var table := (packed as PackedScene).instantiate() as Node3D
		table.name = "FrontPrepTable"
		table.position.z = FRONT_TABLE_Z
		_stage.add_child(table)
	else:
		_box(_stage, Vector3(0, 0.38, FRONT_TABLE_Z), Vector3(14.0, 0.76, 2.05), Color("#9b7658"))
		_box(_stage, Vector3(0, FRONT_TABLE_TOP - 0.025, FRONT_TABLE_Z), Vector3(14.0, 0.05, 2.05), Color("#e5cda5"))


func _build_dish_display() -> void:
	# The finished dish rests directly on the modeled handoff board.
	_dish_display = Node3D.new()
	_dish_display.name = "SelectedDishDisplay"
	_dish_display.position = Vector3(HANDOFF_X, FRONT_TABLE_TOP, FRONT_TABLE_Z)
	_dish_display.visible = false
	_stage.add_child(_dish_display)
	_finished_dish_area = _area(_stage, "finished_dish", "serve", "点击成品交餐", Vector3(HANDOFF_X, FRONT_TABLE_TOP + 0.23, FRONT_TABLE_Z), Vector3(1.62, 0.52, 1.08))
	_finished_dish_area.name = "FinishedDishHotspot"
	_finished_dish_area.collision_layer = 0
	# A soft pool sits on the handoff board; the meal retains its normal material.
	var glow_plane := PlaneMesh.new()
	glow_plane.size = Vector2(2.62, 1.44)
	_finished_dish_glow = MeshInstance3D.new()
	_finished_dish_glow.name = "FinishedFoodBoardGlow"
	_finished_dish_glow.mesh = glow_plane
	_finished_dish_glow.position = Vector3(HANDOFF_X, FRONT_TABLE_TOP + 0.018, FRONT_TABLE_Z)
	var glow_shader := Shader.new()
	glow_shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; uniform float strength = 0.82; void fragment() { vec2 p = (UV - vec2(0.5)) * vec2(2.0, 2.0); float fade = pow(1.0 - smoothstep(0.0, 1.0, length(p)), 1.6); ALBEDO = vec3(1.0, 0.95, 0.78); ALPHA = 0.55 * strength * fade; }"
	_finished_dish_glow_material = ShaderMaterial.new()
	_finished_dish_glow_material.shader = glow_shader
	_finished_dish_glow.material_override = _finished_dish_glow_material
	_finished_dish_glow.visible = false
	_stage.add_child(_finished_dish_glow)
	# A small enamel task lamp belongs to the handoff board. It switches on
	# only when the plated meal can be collected; the food keeps its own color.
	var lamp_foot := Vector3(HANDOFF_X + 1.18, FRONT_TABLE_TOP + 0.045, FRONT_TABLE_Z - 0.62)
	_cylinder(_stage, lamp_foot, 0.11, 0.055, Color("#91775e"))
	_cylinder(_stage, lamp_foot + Vector3(0, 0.36, 0), 0.027, 0.70, Color("#b89b79"))
	_box(_stage, lamp_foot + Vector3(-0.30, 0.69, 0.12), Vector3(0.60, 0.035, 0.04), Color("#b89b79"))
	var shade_at := lamp_foot + Vector3(-0.58, 0.63, 0.23)
	var shade := _sphere(_stage, shade_at, 0.21, Color("#809b8b"))
	shade.scale = Vector3(1.0, 0.42, 0.83)
	_finished_dish_bulb = _sphere(_stage, shade_at + Vector3(0, -0.105, 0), 0.074, Color("#fff0c8"), true)
	_finished_dish_bulb.visible = true
	_finished_dish_spot = SpotLight3D.new()
	_finished_dish_spot.name = "FinishedDishTaskLight"
	_finished_dish_spot.position = shade_at + Vector3(0, -0.16, 0.04)
	_finished_dish_spot.rotation.x = -PI * 0.5
	_finished_dish_spot.light_color = Color("#fff0d3")
	_finished_dish_spot.light_energy = 0.29
	_finished_dish_spot.spot_range = 2.85
	_finished_dish_spot.spot_angle = 55.0
	_finished_dish_spot.shadow_enabled = false
	_finished_dish_spot.visible = true
	_stage.add_child(_finished_dish_spot)
	for i in range(4):
		var glint := Node3D.new()
		glint.name = "FinishedDishGlint_%d" % i
		glint.position = Vector3(HANDOFF_X + [-1.08, -0.74, 0.72, 1.04][i], FRONT_TABLE_TOP + 0.17, FRONT_TABLE_Z + [-0.30, 0.51, -0.49, 0.27][i])
		glint.visible = false
		_stage.add_child(glint)
		var bead := _sphere(glint, Vector3.ZERO, 0.047, Color("#fff3d1"), true)
		bead.scale.y = 0.60
		_box(glint, Vector3.ZERO, Vector3(0.12, 0.013, 0.018), Color("#fff1ce"))
		_box(glint, Vector3.ZERO, Vector3(0.018, 0.013, 0.12), Color("#fff1ce"))
		_finished_dish_sparkles.append(glint)
	_handoff_display = Node3D.new()
	_handoff_display.name = "ServedDishHandoff"
	_handoff_display.position = _dish_display.position
	_handoff_display.visible = false
	_stage.add_child(_handoff_display)


func _build_buffer_trays() -> void:
	# A real two-place pickup tray links both courses of one guest's combo.
	# The third, separate well remains free for a simultaneous single order.
	var combo_path := "res://assets/art/models/park_cafe_combo_pickup_tray.glb"
	var combo_packed = ResourceLoader.load(combo_path) if ResourceLoader.exists(combo_path) else null
	if combo_packed is PackedScene:
		var combo := (combo_packed as PackedScene).instantiate() as Node3D
		combo.name = "CustomerComboTray"
		combo.position = Vector3(COMBO_TRAY_X, FRONT_TABLE_TOP, FRONT_TABLE_Z)
		_stage.add_child(combo)
	else:
		_box(_stage, Vector3(COMBO_TRAY_X, FRONT_TABLE_TOP + 0.055, FRONT_TABLE_Z), Vector3(3.3, 0.11, 1.05), Color("#e6d4b4"))
	for slot in range(3):
		var x := _buffer_x(slot)
		var tray := Node3D.new()
		tray.name = "ReadyTray_%d" % slot
		tray.position = Vector3(x, 0, FRONT_TABLE_Z)
		_stage.add_child(tray)
		var dish := Node3D.new()
		dish.position.y = FRONT_TABLE_TOP + (0.563 if slot < 2 else 0.0)
		dish.visible = false
		tray.add_child(dish)
		_buffer_dishes.append(dish)
		var area := _area(tray, "buffer", str(slot), "套餐取餐格" if slot < 2 else "单餐取餐格", Vector3(0, FRONT_TABLE_TOP + (0.56 if slot < 2 else 0.22), 0), Vector3(1.48, 0.58 if slot < 2 else 0.43, 1.03))
		area.name = "BufferHotspot_%d" % slot
		_buffer_areas.append(area)
		var ring := _sphere(tray, Vector3(0.57, FRONT_TABLE_TOP + 0.018, 0.46), 0.052, Color("#7fac8d"), true)
		ring.scale.y = 0.36
		ring.visible = false
		_buffer_rings.append(ring)


func _build_process_food() -> void:
	for slot in range(3):
		var piece := Node3D.new()
		piece.name = "TicketIngredients_%d" % slot
		piece.visible = false
		_stage.add_child(piece)
		_ticket_food.append(piece)
		var food_area := _area(_stage, "ticket_food", str(slot), "点击这份食物继续加工", Vector3.ZERO, Vector3(0.74, 0.72, 0.74))
		food_area.name = "TicketFoodHotspot_%d" % slot
		food_area.collision_layer = 0
		_ticket_food_areas.append(food_area)
		var fx := Node3D.new()
		fx.name = "TicketCookingFeedback_%d" % slot
		fx.visible = false
		_stage.add_child(fx)
		_ticket_heat_fx.append(fx)
		var puffs: Array = []
		for i in range(3):
			var puff := _sphere(fx, Vector3(-0.17 + float(i) * 0.17, 0.39, -0.10), 0.075, Color("#eee9d9"))
			puff.scale = Vector3(0.70, 1.35, 0.65)
			puffs.append(puff)
		_ticket_heat_puffs.append(puffs)
		var marks: Array = []
		for mark_index in range(5):
			var mark := _sphere(fx, Vector3(-0.30 + float(mark_index) * 0.15, 0.025, 0.70), 0.052, Color("#796f60"))
			mark.scale.y = 0.38
			marks.append(mark)
		_ticket_heat_marks.append(marks)
	_stock_food = Node3D.new()
	_stock_food.name = "StockIngredients"
	_stock_food.visible = false
	_stage.add_child(_stock_food)
	_stock_food_area = _area(_stage, "stock_food", "stock", "点击半成品继续备货", Vector3.ZERO, Vector3(0.74, 0.72, 0.74))
	_stock_food_area.collision_layer = 0


func _build_heat_lights() -> void:
	for action in ["steam", "fry", "boil"]:
		var station := _stage.get_node_or_null("Station_" + action) as Node3D
		if station == null:
			continue
		_box(station, Vector3(0, 0.884, 0.84), Vector3(1.31, 0.025, 0.18), Color("#73695b"))
		var lights: Array[MeshInstance3D] = []
		for i in range(6):
			var lamp := _box(station, Vector3(-0.50 + float(i) * 0.20, 0.912, 0.84), Vector3(0.145, 0.045, 0.105), Color("#746c5a"))
			lights.append(lamp)
		_heat_lights[action] = lights


func _refresh_dish_display() -> void:
	if not is_instance_valid(_dish_display):
		return
	var was_ready := _finished_dish_glow.visible
	_dish_display.visible = false
	_finished_dish_area.collision_layer = 0
	_finished_dish_glow.visible = false
	_finished_dish_spot.visible = true
	_finished_dish_bulb.visible = true
	for sparkle in _finished_dish_sparkles:
		sparkle.visible = false
	if _handoff_active:
		return
	var tickets: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
	var ready := false
	for ticket in tickets:
		if ticket is Dictionary and bool(ticket.get("started", false)) and not bool(ticket.get("buffered", false)) and str(ticket.get("next_action", "")) == "serve":
			ready = true
			break
	_finished_dish_glow.visible = ready
	for sparkle in _finished_dish_sparkles:
		sparkle.visible = ready
	if ready and not was_ready:
		_finished_dish_arrival = 1.0


func _load_food_model(holder: Node3D, recipe_id: String, target_width: float) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var path := "res://assets/art/models/food/%s.glb" % recipe_id
	if ResourceLoader.exists(path):
		var packed = ResourceLoader.load(path)
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate() as Node3D
			holder.add_child(model)
			_fit_display_model(model, target_width)
	if holder.get_child_count() == 0:
		_cylinder(holder, Vector3(0, 0.035, 0), target_width * 0.43, 0.07, Color("#efe4ce"))
		for i in range(3):
			_sphere(holder, Vector3((-0.19 + float(i) * 0.19) * target_width, 0.13, 0), 0.075 * target_width, Color("#dba37e") if i == 1 else Color("#85aa7b"))


func _load_meal_pair(holder: Node3D, recipe_ids: Array, dish_width: float) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var tray_width := dish_width * 2.27
	_box(holder, Vector3(0, 0.025, 0), Vector3(tray_width, 0.050, dish_width * 1.18), Color("#b9c7b5"))
	_box(holder, Vector3(0, 0.052, -dish_width * 0.57), Vector3(tray_width, 0.025, 0.032), Color("#8fa89c"))
	_box(holder, Vector3(0, 0.052, dish_width * 0.57), Vector3(tray_width, 0.025, 0.032), Color("#8fa89c"))
	for i in range(mini(2, recipe_ids.size())):
		var dish_holder := Node3D.new()
		dish_holder.position = Vector3((float(i) - 0.5) * dish_width * 1.07, 0.058, 0)
		holder.add_child(dish_holder)
		_load_food_model(dish_holder, str(recipe_ids[i]), dish_width * 0.91)


func _fit_display_model(model: Node3D, target_width: float = 1.79) -> void:
	var bounds: Array[Vector3] = [Vector3(1.0e20, 1.0e20, 1.0e20), Vector3(-1.0e20, -1.0e20, -1.0e20)]
	_scan_display_bounds(model, model, bounds)
	if bounds[0].x > bounds[1].x:
		return
	var size := bounds[1] - bounds[0]
	var width := maxf(maxf(size.x, size.z), size.y)
	var factor := target_width / maxf(width, 0.01)
	model.scale = Vector3.ONE * factor
	var center := (bounds[0] + bounds[1]) * 0.5
	model.position = Vector3(-center.x, -bounds[0].y, -center.z) * factor


func _scan_display_bounds(node: Node, model: Node3D, bounds: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var box := mesh_node.get_aabb()
		var relative := model.global_transform.affine_inverse() * mesh_node.global_transform
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					var point := relative * Vector3(x, y, z)
					bounds[0] = bounds[0].min(point)
					bounds[1] = bounds[1].max(point)
	for child in node.get_children():
		_scan_display_bounds(child, model, bounds)


func _build_prop(parent: Node3D, id: String) -> void:
	match id:
		"wash":
			var basin_path := "res://assets/art/models/park_cafe_wash_basin.glb"
			if ResourceLoader.exists(basin_path):
				var packed = ResourceLoader.load(basin_path)
				if packed is PackedScene:
					var basin := (packed as PackedScene).instantiate() as Node3D
					basin.position.y = 0.835
					parent.add_child(basin)
					for part in basin.find_children("*", "MeshInstance3D", true, false):
						if str(part.name).contains("visible_shallow_water"):
							_station_animated[id] = part
							break
					if not _station_animated.has(id):
						_station_animated[id] = _sphere(parent, Vector3(0, 1.03, 0), 0.10, Color("#80b8b3"))
					return
			_box(parent, Vector3(0, 0.85, 0), Vector3(1.48, 0.11, 1.42), Color("#a3aeb0"))
			_station_animated[id] = _box(parent, Vector3(0, 0.86, 0), Vector3(1.20, 0.025, 1.15), Color("#85c6c3"))
			_cylinder(parent, Vector3(-0.52, 1.15, -0.39), 0.045, 0.56, Color("#c6d0c9"))
			_box(parent, Vector3(-0.22, 1.43, -0.39), Vector3(0.60, 0.06, 0.06), Color("#c6d0c9"))
			for i in range(4):
				_track_station_ingredient(id, _sphere(parent, Vector3(-0.40 + i * 0.25, 0.98, 0.18), 0.13, Color("#73aa80")))
		"slice":
			_box(parent, Vector3(0, 0.91, 0), Vector3(1.49, 0.11, 1.55), Color("#c99d70"))
			_station_animated[id] = _box(parent, Vector3(0.32, 1.00, -0.12), Vector3(0.78, 0.035, 0.12), Color("#d2d9d5"))
			_box(parent, Vector3(0.80, 1.00, -0.12), Vector3(0.22, 0.08, 0.17), Color("#765a4d"))
			for i in range(5):
				_track_station_ingredient(id, _cylinder(parent, Vector3(-0.54 + i * 0.18, 1.00, 0.24), 0.095, 0.04, Color("#98b683")))
		"mix":
			_cylinder(parent, Vector3(0, 0.93, 0), 0.62, 0.17, Color("#e6c090"))
			_cylinder(parent, Vector3(0, 1.04, 0), 0.49, 0.025, Color("#f4dfad"))
			_station_animated[id] = _box(parent, Vector3(0.29, 1.30, -0.1), Vector3(0.045, 0.55, 0.045), Color("#d8dbd0"))
			for i in range(3):
				_track_station_ingredient(id, _sphere(parent, Vector3(-0.25 + i * 0.23, 1.06, 0.12), 0.10, Color("#d2a477")))
		"marinate":
			_box(parent, Vector3(0, 0.91, 0), Vector3(1.39, 0.12, 1.39), Color("#b8c6b7"))
			_box(parent, Vector3(0, 0.99, 0), Vector3(1.19, 0.045, 1.17), Color("#a87955"))
			for side in [-1, 1]:
				_box(parent, Vector3(float(side) * 0.62, 1.08, 0), Vector3(0.075, 0.20, 1.30), Color("#d8dfd0"))
			for side in [-1, 1]:
				_box(parent, Vector3(0, 1.08, float(side) * 0.62), Vector3(1.27, 0.20, 0.075), Color("#d8dfd0"))
			for i in range(4):
				var chicken := _capsule(parent, Vector3(-0.32 + float(i % 2) * 0.56, 1.09, -0.29 + float(i / 2) * 0.50), 0.16, 0.31, Color("#d89473"))
				chicken.rotation.z = PI * 0.5
				# Keep the food visible in the tub even when the station is idle.
				_box(parent, Vector3(chicken.position.x, 1.23, chicken.position.z), Vector3(0.16, 0.012, 0.025), Color("#f0b28a"))
				for dot in range(2):
					_sphere(parent, Vector3(chicken.position.x - 0.05 + float(dot) * 0.10, 1.23, chicken.position.z), 0.025, Color("#705a3d"))
			_station_animated[id] = _box(parent, Vector3(0.45, 1.18, -0.43), Vector3(0.60, 0.055, 0.07), Color("#a07c5b"))
			_box(parent, Vector3(0.14, 1.18, -0.43), Vector3(0.16, 0.11, 0.15), Color("#e5c79b"))
		"portion":
			_box(parent, Vector3(0, 0.90, 0), Vector3(1.47, 0.10, 1.41), Color("#899d98"))
			_box(parent, Vector3(0, 0.96, 0), Vector3(1.30, 0.025, 1.24), Color("#d9ddcf"))
			for i in range(3):
				var x := -0.43 + float(i) * 0.43
				_box(parent, Vector3(x, 1.025, -0.20), Vector3(0.34, 0.085, 0.43), Color("#f1e9d7"))
				_box(parent, Vector3(x, 1.073, -0.27), Vector3(0.28, 0.010, 0.18), Color("#e6d3a9"))
				_sphere(parent, Vector3(x, 1.085, -0.27), 0.10, Color("#f0e2bd")).scale.y = 0.35
				_sphere(parent, Vector3(x + 0.06, 1.084, -0.05), 0.042, Color("#7f9d72"))
				_box(parent, Vector3(x, 0.99, 0.34), Vector3(0.32, 0.025, 0.22), Color("#c6a078"))
			for n in range(5):
				_box(parent, Vector3(-0.49 + float(n) * 0.20, 0.99, -0.52), Vector3(0.07, 0.01, 0.04), Color("#6c8178"))
			_station_animated[id] = _cylinder(parent, Vector3(0.45, 1.24, 0.31), 0.20, 0.035, Color("#bfcbc3"))
			_box(parent, Vector3(0.70, 1.25, 0.31), Vector3(0.49, 0.045, 0.055), Color("#718780"))
		"steam":
			_steam_fixture = Node3D.new()
			_steam_fixture.name = "ClosedSteamerStack"
			parent.add_child(_steam_fixture)
			for i in range(3):
				_cylinder(_steam_fixture, Vector3(0, 0.94 + i * 0.16, 0), 0.65, 0.13, Color("#c6a873"))
			_station_animated[id] = _cylinder(_steam_fixture, Vector3(0, 1.43, 0), 0.67, 0.08, Color("#e0bd81"))
			_sphere(_steam_fixture, Vector3(0, 1.50, 0), 0.09, Color("#a67a50"))
			_add_steam(parent)
			var burned := _cylinder(parent, Vector3(0, 1.56, 0), 0.33, 0.035, Color("#4e4741"))
			burned.visible = false
			_charred_food.append(burned)
		"fry":
			_station_animated[id] = _cylinder(parent, Vector3(0, 0.92, 0), 0.67, 0.15, Color("#566e6c"))
			_cylinder(parent, Vector3(0, 1.02, 0), 0.52, 0.02, Color("#c69962"))
			_box(parent, Vector3(0.87, 0.96, 0), Vector3(0.74, 0.08, 0.15), Color("#544b48"))
			for i in range(3):
				_track_station_ingredient(id, _sphere(parent, Vector3(-0.32 + i * 0.26, 1.08, 0.09), 0.12, Color("#e7d19e")))
		"boil":
			_cylinder(parent, Vector3(0, 1.05, 0), 0.65, 0.35, Color("#7d9c9f"))
			_station_animated[id] = _cylinder(parent, Vector3(0, 1.26, 0), 0.68, 0.035, Color("#a8bec0"))
			_sphere(parent, Vector3(0, 1.32, 0), 0.11, Color("#d7d2b5"))
			for side in [-1, 1]:
				_box(parent, Vector3(float(side) * 0.73, 1.06, 0), Vector3(0.29, 0.10, 0.16), Color("#8a7161"))
			_add_steam(parent)
			var burned := _cylinder(parent, Vector3(0, 1.36, 0), 0.30, 0.036, Color("#4e4741"))
			burned.visible = false
			_charred_food.append(burned)
		"garnish":
			_box(parent, Vector3(0, 0.90, 0), Vector3(1.48, 0.09, 1.39), Color("#ae916e"))
			_cylinder(parent, Vector3(-0.21, 0.98, 0), 0.49, 0.065, Color("#eee7d5"))
			for i in range(4):
				var angle := float(i) * PI * 0.53
				var leaf := _sphere(parent, Vector3(-0.22 + cos(angle) * 0.23, 1.04, sin(angle) * 0.20), 0.10, Color("#769d70"))
				leaf.scale = Vector3(0.66, 0.34, 1.10)
				# Keep fresh herbs on the board while the station is idle.
			_box(parent, Vector3(0.47, 0.99, -0.26), Vector3(0.39, 0.07, 0.36), Color("#d1d8c7"))
			for i in range(3):
				_sphere(parent, Vector3(0.35 + float(i) * 0.10, 1.045, -0.26), 0.055, Color("#e3a475"))
			for i in range(3):
				_sphere(parent, Vector3(0.35 + float(i) * 0.10, 1.044, -0.43), 0.055, Color("#6e9d69")).scale = Vector3(0.82, 0.26, 0.66)
			_station_animated[id] = _box(parent, Vector3(0.43, 1.10, 0.42), Vector3(0.57, 0.045, 0.045), Color("#81958b"))
			_box(parent, Vector3(0.17, 1.10, 0.42), Vector3(0.12, 0.06, 0.08), Color("#d3d9ca"))
		"serve":
			_box(parent, Vector3(0, 0.97, 0), Vector3(1.50, 0.11, 1.30), Color("#b88e6d"))
			_cylinder(parent, Vector3(0.47, 1.10, -0.34), 0.20, 0.09, Color("#dbb878"))
			_serve_bell = _sphere(parent, Vector3(0.47, 1.20, -0.34), 0.09, Color("#e8cc8a"), true)
			_station_animated[id] = _serve_bell
			_cylinder(parent, Vector3(-0.25, 1.07, 0.13), 0.36, 0.045, Color("#eee3cf"))


func _add_steam(parent: Node3D) -> void:
	var station_id := str(parent.name).trim_prefix("Station_")
	var station_puffs: Array[MeshInstance3D] = []
	for i in range(3):
		var puff := _sphere(parent, Vector3(-0.16 + float(i) * 0.15, 1.65 + float(i) * 0.20, -0.11), 0.10 + float(i) * 0.035, Color("#d9dfd2"))
		puff.set_meta("base_y", puff.position.y)
		_steam_puffs.append(puff)
		station_puffs.append(puff)
	_steam_by_station[station_id] = station_puffs


func _track_station_ingredient(action: String, mesh: MeshInstance3D) -> void:
	var items: Array = _station_ingredients.get(action, [])
	items.append(mesh)
	_station_ingredients[action] = items


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "KitchenHudLayer"
	layer.layer = 25
	add_child(layer)
	_hud_root = Control.new()
	_hud_root.name = "KitchenHud"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kitchen_theme := Theme.new()
	kitchen_theme.default_font = _playful_font
	_hud_root.theme = kitchen_theme
	layer.add_child(_hud_root)
	_build_pantry_screen_marks()
	var top := HBoxContainer.new()
	top.anchor_left = 0.0
	top.anchor_right = 0.0
	top.offset_left = 20
	top.offset_right = 1124
	top.offset_top = 12
	top.offset_bottom = 128
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(top)
	_ticket_row = top
	_waiting_ticket_row = HBoxContainer.new()
	_waiting_ticket_row.name = "UnstartedTickets"
	_waiting_ticket_row.anchor_left = 1.0
	_waiting_ticket_row.anchor_right = 1.0
	_waiting_ticket_row.offset_left = -20.0
	_waiting_ticket_row.offset_right = -20.0
	_waiting_ticket_row.offset_top = 12
	_waiting_ticket_row.offset_bottom = 128
	_waiting_ticket_row.add_theme_constant_override("separation", 12)
	_waiting_ticket_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_waiting_ticket_row)
	for i in range(3):
		var card := PanelContainer.new()
		card.name = "CustomerMealCard_%d" % i
		card.custom_minimum_size = Vector2(TICKET_CARD_WIDTH, TICKET_CARD_HEIGHT)
		card.add_theme_stylebox_override("panel", _ticket_shell_style(false, false))
		top.add_child(card)
		_customer_cards.append(card)
		var content := Control.new()
		content.custom_minimum_size = Vector2(TICKET_CARD_WIDTH, TICKET_CARD_HEIGHT)
		card.add_child(content)
		_customer_card_contents.append(content)
		var whole_card := Button.new()
		whole_card.name = "WholeMealCardHit_%d" % i
		whole_card.position = Vector2.ZERO
		whole_card.size = Vector2(TICKET_CARD_WIDTH, TICKET_CARD_HEIGHT)
		whole_card.focus_mode = Control.FOCUS_NONE
		var clear_style := StyleBoxEmpty.new()
		for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			whole_card.add_theme_stylebox_override(style_name, clear_style)
		whole_card.pressed.connect(_on_meal_food_pressed.bind(i, 0))
		content.add_child(whole_card)
		_customer_card_hit_buttons.append(whole_card)
		var accent_rule := ColorRect.new()
		accent_rule.position = Vector2(10, 5)
		accent_rule.size = Vector2(340, 22)
		accent_rule.color = Color("#42655b")
		accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(accent_rule)
		_customer_card_accents.append(accent_rule)
		var customer_name := _label("", 15, Color("#f6f3e9"))
		customer_name.position = Vector2(16, 6)
		customer_name.size = Vector2(275, 21)
		content.add_child(customer_name)
		_customer_names.append(customer_name)
		var time_label := _label("", 15, Color("#f6f3e9"))
		time_label.position = Vector2(297, 6)
		time_label.size = Vector2(47, 21)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		content.add_child(time_label)
		_customer_times.append(time_label)
		var meal_tray := PanelContainer.new()
		meal_tray.position = Vector2(10, 29)
		meal_tray.size = Vector2(340, 71)
		meal_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meal_tray.add_theme_stylebox_override("panel", _ticket_tray_style())
		content.add_child(meal_tray)
		_customer_trays.append(meal_tray)
		var tray_divider := ColorRect.new()
		tray_divider.position = Vector2(179, 36)
		tray_divider.size = Vector2(1, 58)
		tray_divider.color = Color("#d0d5ca")
		tray_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(tray_divider)
		_customer_tray_dividers.append(tray_divider)
		var dish_buttons: Array = []
		var dish_icons: Array = []
		var dish_names: Array = []
		var dish_stage_labels: Array = []
		var dish_marks: Array = []
		var dish_steps: Array = []
		var dish_ingredients: Array = []
		for dish_index in range(2):
			var food_button := Button.new()
			food_button.position = Vector2(12 + dish_index * 166, 30)
			food_button.size = Vector2(166, 68)
			food_button.add_theme_stylebox_override("normal", _tray_food_style(Color(1, 1, 1, 0)))
			food_button.add_theme_stylebox_override("hover", _tray_food_style(Color(1, 1, 1, 0.20)))
			food_button.add_theme_stylebox_override("disabled", _tray_food_style(Color(1, 1, 1, 0)))
			food_button.pressed.connect(_on_meal_food_pressed.bind(i, dish_index))
			content.add_child(food_button)
			dish_buttons.append(food_button)
			var food_icon := DishGlyph.new()
			food_icon.position = Vector2(3, 0)
			food_icon.size = Vector2(78, 37)
			food_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			food_button.add_child(food_icon)
			dish_icons.append(food_icon)
			var stage_label := _label("", 10, Color("#8c8069"))
			stage_label.position = Vector2(2, 55)
			stage_label.size = Vector2(26, 14)
			stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			food_button.add_child(stage_label)
			dish_stage_labels.append(stage_label)
			var food_name := _label("", 12, Color("#536759"))
			food_name.position = Vector2(30, 54)
			food_name.size = Vector2(132, 15)
			food_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			food_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			food_button.add_child(food_name)
			dish_names.append(food_name)
			var step_icon := StationGlyph.new()
			step_icon.position = Vector2(111, 0)
			step_icon.size = Vector2(48, 37)
			step_icon.pivot_offset = Vector2(24, 18)
			step_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			food_button.add_child(step_icon)
			dish_steps.append(step_icon)
			var raw_marks: Array = []
			for n in range(4):
				var mark := RawMark.new()
				mark.position = Vector2(2 + n * 40, 37)
				mark.size = Vector2(38, 16)
				mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
				food_button.add_child(mark)
				raw_marks.append(mark)
			dish_ingredients.append(raw_marks)
			var ready_mark := _label("✓", 17, Color("#4d8a71"))
			ready_mark.position = Vector2(146, 0)
			ready_mark.size = Vector2(17, 18)
			ready_mark.visible = false
			ready_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			food_button.add_child(ready_mark)
			dish_marks.append(ready_mark)
		_customer_food_buttons.append(dish_buttons)
		_customer_food_icons.append(dish_icons)
		_customer_food_names.append(dish_names)
		_customer_food_stage_labels.append(dish_stage_labels)
		_customer_food_marks.append(dish_marks)
		_customer_food_steps.append(dish_steps)
		_customer_food_ingredients.append(dish_ingredients)
		_customer_food_slots.append([])
		var patience := _progress()
		patience.position = Vector2(13, 106)
		patience.size = Vector2(334, 4)
		patience.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(patience)
		_customer_bars.append(patience)
	_rush_label = _label("", 15, Color("#9b6e4f"))
	_rush_label.anchor_left = 1.0
	_rush_label.anchor_right = 1.0
	_rush_label.offset_left = -190
	_rush_label.offset_right = -24
	_rush_label.offset_top = 71
	_rush_label.offset_bottom = 94
	_rush_label.custom_minimum_size = Vector2(155, 23)
	_rush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rush_label.visible = false
	_hud_root.add_child(_rush_label)
	_rush_bar = _progress()
	_rush_bar.anchor_left = 1.0
	_rush_bar.anchor_right = 1.0
	_rush_bar.offset_left = -188
	_rush_bar.offset_right = -26
	_rush_bar.offset_top = 98
	_rush_bar.offset_bottom = 104
	_rush_bar.custom_minimum_size = Vector2(150, 6)
	_rush_bar.visible = false
	_hud_root.add_child(_rush_bar)
	_pause_label = _label("已暂停 · 按 P 继续", 24, Color("#375d55"))
	_pause_label.anchor_left = 0.5
	_pause_label.anchor_right = 0.5
	_pause_label.anchor_top = 0.5
	_pause_label.anchor_bottom = 0.5
	_pause_label.offset_left = -180
	_pause_label.offset_right = 180
	_pause_label.offset_top = -20
	_pause_label.offset_bottom = 20
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.visible = false
	_hud_root.add_child(_pause_label)
	var progress_panel := PanelContainer.new()
	_progress_panel = progress_panel
	progress_panel.position = Vector2(20, 131)
	progress_panel.custom_minimum_size = Vector2(249, 73)
	progress_panel.add_theme_stylebox_override("panel", _card_style(Color(0.96, 0.94, 0.87, 0.94), Color("#b6ac91")))
	_hud_root.add_child(progress_panel)
	var progress_layout := VBoxContainer.new()
	progress_layout.add_theme_constant_override("separation", 4)
	progress_panel.add_child(progress_layout)
	_patience_label = _label("◷  0s", 18, Color("#52685c"))
	progress_layout.add_child(_patience_label)
	_patience = _progress()
	progress_layout.add_child(_patience)
	_heat_label = _label("♨  0%", 18, Color("#52685c"))
	_heat_label.visible = false
	progress_layout.add_child(_heat_label)
	_heat = _progress()
	_heat.visible = false
	progress_layout.add_child(_heat)
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.position = Vector2(20, 218)
	_tutorial_panel.custom_minimum_size = Vector2(249, 50)
	_tutorial_panel.add_theme_stylebox_override("panel", _card_style(Color(0.94, 0.91, 0.82, 0.94), Color("#b9aa8d")))
	_hud_root.add_child(_tutorial_panel)
	_tutorial_label = _label("", 16, Color("#556c60"))
	_tutorial_label.custom_minimum_size = Vector2(224, 33)
	_tutorial_panel.add_child(_tutorial_label)
	var bottom := PanelContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 21
	bottom.offset_right = -21
	bottom.offset_top = -66
	bottom.offset_bottom = -18
	bottom.add_theme_stylebox_override("panel", _card_style(Color(0.96, 0.94, 0.88, 0.94), Color("#b9ad95")))
	_hud_root.add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	bottom.add_child(row)
	_cash_label = _label("0 贝", 18, Color("#8a673d"))
	_cash_label.custom_minimum_size.x = 104
	row.add_child(_cash_label)
	_clock_label = _label("◷ 08:00 · 早市", 17, Color("#756d57"))
	_clock_label.custom_minimum_size.x = 150
	row.add_child(_clock_label)
	_step_count_label = _label("", 15, Color("#365f52"))
	_step_count_label.custom_minimum_size.x = 85
	row.add_child(_step_count_label)
	_step_rail = StepRail.new()
	_step_rail.name = "TicketStepRail"
	_step_rail.custom_minimum_size = Vector2(242, 36)
	_step_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_step_rail)
	_step_action_label = _label("", 16, Color("#6c4e37"))
	_step_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_step_action_label)
	_status_label = _label("", 16, Color("#6a6658"))
	row.add_child(_status_label)
	_combo_label = _label("★ 0", 18, Color("#b57950"))
	row.add_child(_combo_label)
	_volume_button = Button.new()
	_volume_button.name = "KitchenMuteToggle"
	_volume_button.flat = true
	_volume_button.custom_minimum_size = Vector2(34, 30)
	_volume_button.add_theme_font_size_override("font_size", 19)
	_volume_button.pressed.connect(_on_kitchen_volume_button_pressed)
	row.add_child(_volume_button)
	_volume_slider = HSlider.new()
	_volume_slider.name = "KitchenVolume"
	_volume_slider.custom_minimum_size = Vector2(96, 24)
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = SettingsManager.master_volume
	_volume_slider.value_changed.connect(_on_kitchen_volume_changed)
	row.add_child(_volume_slider)
	_update_kitchen_volume_button()
	_build_settlement_overlay()
	_build_rotate_overlay()


func _build_rotate_overlay() -> void:
	_rotate_overlay = ColorRect.new()
	_rotate_overlay.name = "MobileLandscapePrompt"
	_rotate_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_overlay.color = Color("#1e302b")
	_rotate_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate_overlay.visible = false
	_hud_root.add_child(_rotate_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_overlay.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	center.add_child(stack)
	var turn_icon := _label("↻  ▭", 72, Color("#f5dfae"))
	turn_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(turn_icon)
	var hint := _label("请横屏游玩", 28, Color("#f6eedc"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hint)


func _update_mobile_orientation() -> void:
	if not is_instance_valid(_rotate_overlay):
		return
	var is_mobile := OS.has_feature("mobile") or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
	var window_size := get_window().size
	_rotate_overlay.visible = is_mobile and window_size.y > window_size.x


func _on_kitchen_volume_button_pressed() -> void:
	_volume_slider.value = 0.8 if SettingsManager.master_volume <= 0.02 else 0.0


func _on_kitchen_volume_changed(value: float) -> void:
	if is_instance_valid(_volume_slider) and not is_equal_approx(_volume_slider.value, value):
		_volume_slider.set_value_no_signal(value)
	SettingsManager.set_master_volume(value)
	_update_kitchen_volume_button()
	var now := Time.get_ticks_msec()
	if value > 0.02 and now - _volume_preview_at > 240:
		_volume_preview_at = now
		AudioManager.play_sfx("kitchen_ready")


func _update_kitchen_volume_button() -> void:
	if not is_instance_valid(_volume_button):
		return
	var muted := SettingsManager.master_volume <= 0.02
	_volume_button.text = "♪×" if muted else "♫"
	_volume_button.tooltip_text = "点击开启声音" if muted else "点击静音"
	_volume_button.add_theme_color_override("font_color", Color("#b5573f") if muted else Color("#365f52"))


func _build_settlement_overlay() -> void:
	_settlement_overlay = ColorRect.new()
	_settlement_overlay.name = "ClosingSettlement"
	_settlement_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settlement_overlay.color = Color(0.16, 0.24, 0.23, 0.66)
	_settlement_overlay.visible = false
	_settlement_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_root.add_child(_settlement_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settlement_overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(430, 272)
	card.add_theme_stylebox_override("panel", _card_style(Color("#f5ead4"), Color("#9caa91")))
	center.add_child(card)
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 23)
	card.add_child(inset)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	inset.add_child(layout)
	_settlement_title = _label("已打烊", 28, Color("#526d60"))
	_settlement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_settlement_title)
	_settlement_stats = _label("", 20, Color("#6f6858"))
	_settlement_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settlement_stats.custom_minimum_size.y = 115
	layout.add_child(_settlement_stats)
	var reopen := Button.new()
	reopen.text = "继续营业"
	reopen.custom_minimum_size = Vector2(205, 42)
	reopen.add_theme_font_size_override("font_size", 17)
	reopen.add_theme_color_override("font_color", Color("#3f6957"))
	reopen.add_theme_stylebox_override("normal", _card_style(Color("#dce9d3"), Color("#8cae93")))
	reopen.pressed.connect(func() -> void: reopen_requested.emit())
	layout.add_child(reopen)


func _refresh_tickets() -> void:
	if _customer_cards.is_empty():
		return
	var raw = _state.get("tickets", _state.get("orders", []))
	var tickets: Array = raw if raw is Array else []
	if tickets.is_empty() and _state.get("order", {}) is Dictionary and not (_state.get("order", {}) as Dictionary).is_empty():
		tickets = [_state.get("order", {})]
	var selected := int(_state.get("selected_ticket", _state.get("selected_slot", 0)))
	var guests: Array[Dictionary] = []
	for ticket_slot in range(tickets.size()):
		if not tickets[ticket_slot] is Dictionary:
			continue
		var ticket: Dictionary = tickets[ticket_slot]
		var customer_id := int(ticket.get("customer_id", ticket.get("order_number", ticket_slot + 1)))
		guests.append({"id": customer_id,
			"label": str(ticket.get("customer_label", "顾客 %d" % customer_id)),
			"slots": [ticket_slot], "tickets": [ticket],
			"started": bool(ticket.get("started", false))})
	var started_count := 0
	for guest in guests:
		if bool(guest["started"]):
			started_count += 1
	var pending_count := guests.size() - started_count
	_ticket_row.visible = started_count > 0
	_ticket_row.offset_left = 20
	_ticket_row.offset_right = 20 + started_count * int(SINGLE_TICKET_CARD_WIDTH) + maxi(0, started_count - 1) * 12
	_waiting_ticket_row.visible = pending_count > 0
	_waiting_ticket_row.offset_left = -20 - pending_count * int(SINGLE_TICKET_CARD_WIDTH) - maxi(0, pending_count - 1) * 12
	_waiting_ticket_row.offset_right = -20
	var started_position := 0
	var waiting_position := 0
	for i in range(_customer_cards.size()):
		var active := i < guests.size()
		_customer_cards[i].visible = active
		if not active:
			_customer_food_slots[i] = []
			continue
		var guest: Dictionary = guests[i]
		var target_row := _ticket_row if bool(guest["started"]) else _waiting_ticket_row
		if _customer_cards[i].get_parent() != target_row:
			_customer_cards[i].reparent(target_row)
		var target_position := started_position if bool(guest["started"]) else waiting_position
		if _customer_cards[i].get_index() != target_position:
			target_row.move_child(_customer_cards[i], target_position)
		if bool(guest["started"]):
			started_position += 1
		else:
			waiting_position += 1
		var guest_tickets: Array = guest["tickets"]
		var guest_slots: Array = guest["slots"]
		var card_width := SINGLE_TICKET_CARD_WIDTH
		_customer_cards[i].custom_minimum_size.x = card_width
		_customer_card_contents[i].custom_minimum_size.x = card_width
		_customer_card_hit_buttons[i].size.x = card_width
		_customer_card_accents[i].size.x = card_width - 20.0
		_customer_names[i].size.x = card_width - 85.0
		_customer_times[i].position.x = card_width - 63.0
		_customer_trays[i].size.x = card_width - 20.0
		_customer_bars[i].size.x = card_width - 26.0
		_customer_tray_dividers[i].visible = guest_tickets.size() > 1
		_customer_food_slots[i] = guest_slots.duplicate()
		var first: Dictionary = guest_tickets[0]
		var remaining := float(first.get("time_left", first.get("patience", _state.get("time_left", 0.0))))
		var limit := maxf(1.0, float(first.get("patience_total", first.get("patience_max", 55.0))))
		var urgent := bool(first.get("urgent", false))
		for entry in guest_tickets:
			if entry is Dictionary and bool((entry as Dictionary).get("urgent", false)):
				urgent = true
		var accent: Color = Color("#c97b64") if urgent else TICKET_LANE_COLORS[i]
		var selected_here := guest_slots.has(selected) and bool(guest["started"])
		var shell_key := "%d:%d" % [int(selected_here), int(urgent)]
		if str(_customer_cards[i].get_meta("shell_key", "")) != shell_key:
			_customer_cards[i].set_meta("shell_key", shell_key)
			_customer_cards[i].add_theme_stylebox_override("panel", _ticket_shell_style(selected_here, urgent))
		_customer_card_accents[i].color = Color("#965c50") if urgent else (Color("#426c60") if selected_here else Color("#607a70") if bool(guest["started"]) else Color("#9b947d"))
		var staged_count := 0
		for entry in guest_tickets:
			if entry is Dictionary and bool((entry as Dictionary).get("buffered", false)):
				staged_count += 1
		_customer_names[i].text = "%s · %d/%d" % [str(guest["label"]), staged_count, guest_tickets.size()] if guest_tickets.size() > 1 else str(guest["label"])
		_customer_names[i].add_theme_color_override("font_color", Color("#f6f3e9"))
		_customer_times[i].text = "%ds" % ceili(remaining)
		_customer_times[i].add_theme_color_override("font_color", Color("#f6f3e9"))
		_customer_bars[i].value = clampf(remaining / limit * 100.0, 0.0, 100.0)
		for dish_index in range(2):
			var button: Button = _customer_food_buttons[i][dish_index]
			button.visible = dish_index < guest_tickets.size()
			if not button.visible:
				button.disabled = true
				continue
			var item: Dictionary = guest_tickets[dish_index]
			var recipe: Dictionary = item.get("recipe", {}) if item.get("recipe", {}) is Dictionary else item
			var buffered := bool(item.get("buffered", false))
			var dish_selected := int(guest_slots[dish_index]) == selected and bool(item.get("started", false))
			var next_action := str(item.get("next_action", ""))
			var waiting := float(item.get("heat_left", 0.0)) > 0.0
			var ready_to_move := float(item.get("pickup_left", 0.0)) > 0.0
			var reheating_needed := bool(item.get("reheat_needed", false))
			var started := bool(item.get("started", false))
			var ingredient_ids: Array = recipe.get("ingredients", []) if recipe.get("ingredients", []) is Array else []
			var ingredient_counts: Dictionary = item.get("ingredient_counts", {}) if item.get("ingredient_counts", {}) is Dictionary else {}
			var warehouse_counts: Dictionary = item.get("warehouse_counts", {}) if item.get("warehouse_counts", {}) is Dictionary else {}
			var reserved := bool(item.get("ingredients_reserved", false))
			var substitute_key := str(item.get("stock_substitute_key", ""))
			var substitute_count := int(item.get("stock_substitute_count", 0))
			var ticket_missing := false
			if not reserved:
				for ingredient in ingredient_ids:
					var ingredient_key := str(ingredient)
					var supplied_by_stock := ingredient_key == substitute_key and substitute_count > 0
					if int(ingredient_counts.get(ingredient_key, 0)) <= 0 and not supplied_by_stock:
						ticket_missing = true
						break
			button.position.x = 12 + dish_index * 166
			button.disabled = not _interaction_enabled
			button.tooltip_text = ""
			var food_key := "%d:%d:%d:%d" % [int(buffered), int(waiting), int(started), int(dish_selected)]
			if str(button.get_meta("food_key", "")) != food_key:
				button.set_meta("food_key", food_key)
				var food_style := _tray_food_style(Color(0.69, 0.84, 0.71, 0.33) if buffered else (Color(0.91, 0.78, 0.53, 0.30) if waiting else (Color(0.72, 0.85, 0.76, 0.36) if started else (Color(1.0, 0.98, 0.85, 0.34) if dish_selected else Color(1, 1, 1, 0)))))
				button.add_theme_stylebox_override("normal", food_style)
				button.add_theme_stylebox_override("disabled", food_style)
			_customer_food_icons[i][dish_index].recipe_id = str(recipe.get("id", ""))
			var stage_name := "已好" if buffered else ("缺料" if ticket_missing else ("回热" if reheating_needed else ("在做" if started else "未做")))
			_customer_food_stage_labels[i][dish_index].text = stage_name
			_customer_food_stage_labels[i][dish_index].add_theme_color_override("font_color", Color("#5e9576") if buffered else (Color("#b25f4c") if ticket_missing else (Color("#af7950") if started else Color("#8c8069"))))
			_customer_food_names[i][dish_index].text = str(recipe.get("name", "今日餐点"))
			_customer_food_marks[i][dish_index].visible = buffered
			var step_icon := _customer_food_steps[i][dish_index] as StationGlyph
			step_icon.action_id = next_action
			step_icon.cue = "buffered" if buffered else ("waiting" if waiting else ("ready" if ready_to_move or reheating_needed else "next"))
			step_icon.queue_redraw()
			for raw_index in range(4):
				var raw_mark := _customer_food_ingredients[i][dish_index][raw_index] as RawMark
				raw_mark.visible = raw_index < ingredient_ids.size()
				if raw_mark.visible:
					var key := str(ingredient_ids[raw_index])
					var via_stock := key == substitute_key and substitute_count > 0 and int(ingredient_counts.get(key, 0)) <= 0
					var count := substitute_count if via_stock else int(ingredient_counts.get(key, 0))
					var warehouse_count := int(warehouse_counts.get(key, 0))
					var short_name := str(INGREDIENT_SHORT.get(key, "料"))
					var mark_changed := raw_mark.ingredient_id != key or raw_mark.via_stock != via_stock or raw_mark.count != count or raw_mark.warehouse_count != warehouse_count or raw_mark.short_name != short_name or raw_mark.enough != (count > 0) or raw_mark.used != reserved
					raw_mark.ingredient_id = key
					raw_mark.via_stock = via_stock
					raw_mark.count = count
					raw_mark.warehouse_count = warehouse_count
					raw_mark.short_name = short_name
					raw_mark.enough = count > 0
					raw_mark.used = reserved
					if mark_changed:
						raw_mark.queue_redraw()
			var visual_key := str(item.get("order_number", guest_slots[dish_index]))
			var visual_stage := "%d:%d:%d:%d:%d:%d" % [int(item.get("step_index", 0)), int(waiting), int(ready_to_move), int(buffered), int(reheating_needed), int(bool(item.get("reheating", false)))]
			if _ticket_visual_stages.has(visual_key) and str(_ticket_visual_stages[visual_key]) != visual_stage:
				step_icon.scale = Vector2.ONE * 1.22
				step_icon.create_tween().tween_property(step_icon, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_ticket_visual_stages[visual_key] = visual_stage
	_refresh_guests(tickets, selected)
	var rush_left := maxf(0.0, float(_state.get("rush_wave_in", 0.0)))
	var rush_at := maxf(0.1, float(_state.get("rush_wave_at", 10.0)))
	_rush_label.visible = rush_left > 0.0
	_rush_bar.visible = rush_left > 0.0
	_rush_label.text = "●●●  %ds" % ceili(rush_left)
	_rush_bar.value = clampf((rush_at - rush_left) / rush_at * 100.0, 0.0, 100.0)


func _refresh_guests(tickets: Array, selected: int) -> void:
	# A two-dish order belongs to one person in the visible queue. The two
	# recipe tickets remain independent work lanes, but share this guest actor.
	var guests: Array[Dictionary] = []
	var seen_customers := {}
	for ticket_slot in range(tickets.size()):
		if not tickets[ticket_slot] is Dictionary:
			continue
		var ticket: Dictionary = tickets[ticket_slot]
		var customer_id := int(ticket.get("customer_id", ticket.get("order_number", ticket_slot + 1)))
		if seen_customers.has(customer_id):
			continue
		seen_customers[customer_id] = true
		guests.append({"ticket": ticket, "slot": ticket_slot, "customer_id": customer_id})
	var selected_customer := -1
	if selected >= 0 and selected < tickets.size() and tickets[selected] is Dictionary:
		var selected_ticket: Dictionary = tickets[selected]
		selected_customer = int(selected_ticket.get("customer_id", selected_ticket.get("order_number", selected + 1)))
	for i in range(_guest_pivots.size()):
		var active := i < guests.size()
		if active != _guest_active[i]:
			_guest_active[i] = active
			var pivot := _guest_pivots[i]
			var motion := pivot.create_tween()
			motion.tween_property(pivot, "scale", Vector3.ONE if active else Vector3.ONE * 0.02, 0.27).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if active:
				var target_z := GUEST_QUEUE_Z + float(i) * 0.05
				pivot.position.z = target_z + 0.30
				motion.parallel().tween_property(pivot, "position:z", target_z, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_guest_areas[i].collision_layer = INTERACT_LAYER if active else 0
		_guest_order_cards[i].visible = active
		if not active:
			continue
		var guest: Dictionary = guests[i]
		var item: Dictionary = guest["ticket"]
		var customer_id := int(guest["customer_id"])
		if _guest_current_ids[i] != customer_id:
			_guest_current_ids[i] = customer_id
			_apply_guest_variant(i, customer_id)
		_guest_areas[i].set_meta("id", str(guest["slot"]))
		_guest_areas[i].set_meta("display_name", str(item.get("customer_label", "顾客 %d" % int(guest["customer_id"]))))
		var remaining := float(item.get("time_left", 0.0))
		var limit := maxf(1.0, float(item.get("patience_total", 55.0)))
		var ratio := clampf(remaining / limit, 0.0, 1.0)
		var color := Color("#cf7c68") if ratio < 0.25 else (Color("#c9ab68") if ratio < 0.55 else Color("#82b497"))
		if i == _angry_guest_slot and _angry_left > 0.0:
			color = Color("#d17d68")
		elif float(item.get("pickup_left", 0.0)) > 0.0 and float(item.get("pickup_left", 0.0)) < 3.0:
			color = Color("#d69964")
		var card := _guest_order_cards[i]
		card.position.y = 0.96 if int(guest["customer_id"]) == selected_customer else 0.87
		var material := _guest_card_marks[i].material_override as StandardMaterial3D
		material.albedo_color = color if ratio < 0.25 else TICKET_LANE_COLORS[i]


func _on_customer_portrait_pressed(guest_index: int) -> void:
	if not _interaction_enabled or guest_index < 0 or guest_index >= _customer_food_slots.size():
		return
	var slots: Array = _customer_food_slots[guest_index]
	for slot in slots:
		var tickets: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
		if int(slot) < tickets.size() and tickets[int(slot)] is Dictionary and not bool((tickets[int(slot)] as Dictionary).get("buffered", false)):
			ticket_pressed.emit(int(slot))
			return
	if not slots.is_empty():
		ticket_pressed.emit(int(slots[0]))


func _on_meal_food_pressed(guest_index: int, dish_index: int) -> void:
	if not _interaction_enabled or guest_index < 0 or guest_index >= _customer_food_slots.size():
		return
	var slots: Array = _customer_food_slots[guest_index]
	if dish_index >= 0 and dish_index < slots.size():
		ticket_pressed.emit(int(slots[dish_index]))


func _refresh_stock() -> void:
	var raw = _state.get("stock", _state.get("inventory", STOCK_FALLBACK))
	var stock: Array = STOCK_FALLBACK.duplicate(true)
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				for i in range(2):
					if str(entry.get("id", "")) == str(stock[i]["id"]):
						stock[i].merge(entry, true)
	elif raw is Dictionary:
		for i in range(2):
			var stock_id := str(stock[i]["id"])
			if raw.has(stock_id):
				var value = raw[stock_id]
				if value is Dictionary:
					stock[i].merge(value, true)
				else:
					stock[i]["count"] = int(value)
	for i in range(3):
		var entry: Dictionary = stock[i]
		var id := str(entry.get("id", "stock_%d" % i))
		var count := maxi(0, int(entry.get("count", entry.get("amount", 0))))
		var label := str(entry.get("name", id))
		var capacity := maxi(0, int(entry.get("capacity", 0)))
		var freshness := maxf(0.0, float(entry.get("fresh_left", 0.0)))
		_stock_areas[i].set_meta("id", id)
		_stock_areas[i].set_meta("display_name", "%s · %d / %d 份 · 鲜度 %.0f 秒" % [label, count, capacity, freshness] if capacity > 0 else "%s · %d 份" % [label, count])
		if i >= _stock_unit_visuals.size():
			continue
		var previous_count := _stock_visual_counts[i]
		_stock_visual_counts[i] = count
		var units: Array = entry.get("units", []) if entry.get("units", []) is Array else []
		var fresh_total := maxf(0.1, float(entry.get("fresh_total", 92.0 if i == 0 else 78.0)))
		for n in range(_stock_unit_visuals[i].size()):
			var visual := _stock_unit_visuals[i][n] as Node3D
			# One lidded container represents up to two prepared portions. This
			# keeps four readable 3D vessels instead of eight tiny plate icons.
			var occupied := n < ceili(float(count) / 2.0)
			visual.visible = occupied
			if occupied and previous_count >= 0 and n >= ceili(float(previous_count) / 2.0):
				visual.scale = Vector3.ONE * 0.35
				visual.create_tween().tween_property(visual, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var ratio := clampf(float(units[n * 2]) / fresh_total, 0.0, 1.0) if occupied and n * 2 < units.size() else 0.0
			var ring := _stock_unit_rings[i][n] as MeshInstance3D
			ring.visible = occupied
			var material := ring.material_override as StandardMaterial3D
			material.albedo_color = Color("#4eae98") if ratio > 0.55 else (Color("#e4a737") if ratio > 0.22 else (Color("#d46c55") if occupied else Color("#897b69")))
			material.emission = Color.BLACK
			material.emission_energy_multiplier = 0.0


func _build_stock_slots(cargo: Node3D, stock_id: String) -> void:
	var asset := "rice_batter_bowl" if stock_id == "rice_batter" else "spice_jar"
	var path := "res://assets/art/models/food_stage/%s.glb" % asset
	var packed = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
	var visuals: Array = []
	var rings: Array = []
	for n in range(STOCK_SLOT_POINTS.size()):
		var spot: Vector2 = STOCK_SLOT_POINTS[n]
		var position := Vector3(spot.x, 0, spot.y)
		# No empty ceramic disk under every slot: the raised Blender board is
		# the physical support. A small inset pin shows freshness without a
		# full-width luminous click line or an icon-like empty placeholder.
		var ring := _sphere(cargo, position + Vector3(0.25, 0.014, 0), 0.024, Color("#897b69"))
		ring.scale.y = 0.35
		rings.append(ring)
		var visual := Node3D.new()
		visual.position = position
		visual.visible = false
		cargo.add_child(visual)
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate() as Node3D
			visual.add_child(model)
			_fit_display_model(model, 0.50)
		else:
			_sphere(visual, Vector3(0, 0.11, 0), 0.14, Color("#8cae85") if stock_id == "rice_batter" else Color("#d9a97d"))
		visuals.append(visual)
	_stock_unit_visuals.append(visuals)
	_stock_unit_rings.append(rings)


func _refresh_process_food() -> void:
	var raw = _state.get("tickets", [])
	var tickets: Array = raw if raw is Array else []
	var selected := int(_state.get("selected_slot", 0))
	# Every started dish owns a physical lane, including non-heating counters.
	# Its collider follows the food so a click chooses the exact order.
	var action_slots: Dictionary = {}
	for slot in range(mini(_ticket_food.size(), tickets.size())):
		if not tickets[slot] is Dictionary or bool((tickets[slot] as Dictionary).get("buffered", false)) or not bool((tickets[slot] as Dictionary).get("started", false)):
			continue
		var candidate: Dictionary = tickets[slot]
		var candidate_steps: Array = candidate.get("steps", []) if candidate.get("steps", []) is Array else []
		if candidate_steps.is_empty():
			continue
		var candidate_index := clampi(int(candidate.get("step_index", 0)), 0, candidate_steps.size() - 1)
		var candidate_action := str(candidate.get("next_action", candidate_steps[candidate_index]))
		if float(candidate.get("pickup_left", 0.0)) > 0.0 and candidate_index > 0:
			var prior := str(candidate_steps[candidate_index - 1])
			if HEAT_ACTIONS.has(prior):
				candidate_action = prior
		if not action_slots.has(candidate_action):
			action_slots[candidate_action] = []
		(action_slots[candidate_action] as Array).append(slot)
	for slot in range(_ticket_food.size()):
		var holder := _ticket_food[slot]
		var food_area := _ticket_food_areas[slot]
		food_area.collision_layer = 0
		_ticket_heat_phase[slot] = 0
		if slot >= tickets.size() or not tickets[slot] is Dictionary:
			holder.visible = false
			_ticket_food_keys[slot] = ""
			continue
		var ticket: Dictionary = tickets[slot]
		if bool(ticket.get("buffered", false)) or not bool(ticket.get("started", false)):
			holder.visible = false
			continue
		var recipe: Dictionary = ticket.get("recipe", {}) if ticket.get("recipe", {}) is Dictionary else {}
		var recipe_id := str(recipe.get("id", ""))
		var steps: Array = ticket.get("steps", []) if ticket.get("steps", []) is Array else []
		if steps.is_empty() or recipe_id == "":
			holder.visible = false
			continue
		var step_index := clampi(int(ticket.get("step_index", 0)), 0, steps.size() - 1)
		var process_hold: Dictionary = _process_hold_slots.get(slot, {}) if _process_hold_slots.get(slot, {}) is Dictionary else {}
		if not process_hold.is_empty() and (int(process_hold.get("order_number", -1)) != int(ticket.get("order_number", -2)) or int(process_hold.get("step_index", -1)) != step_index):
			_process_hold_slots.erase(slot)
			process_hold = {}
		var needed := str(ticket.get("next_action", steps[step_index]))
		var phase := "serve" if needed == "serve" else ("raw" if step_index == 0 else str(steps[step_index - 1]))
		if float(ticket.get("heat_left", 0.0)) > 0.0:
			_ticket_heat_phase[slot] = 1
			if needed in ["steam", "fry", "boil"]:
				phase = needed
		elif float(ticket.get("pickup_left", 0.0)) > 0.0:
			_ticket_heat_phase[slot] = 2
		var cook_seconds := maxf(0.01, float(ticket.get("heat_total", recipe.get("cook_seconds", 1.0))))
		var heat_ratio := 1.0 - clampf(float(ticket.get("heat_left", 0.0)) / cook_seconds, 0.0, 1.0)
		_ticket_heat_fx[slot].set_meta("heat_ratio", heat_ratio)
		var at_action := needed
		if float(ticket.get("pickup_left", 0.0)) > 0.0 and phase in ["steam", "fry", "boil"]:
			at_action = phase
		var key := "%s:%s:%d" % [recipe_id, phase, step_index]
		var peers: Array = action_slots.get(at_action, []) if action_slots.has(at_action) else []
		var lane_index := peers.find(slot)
		var lane_scale := _heat_lane_scale(peers.size()) if lane_index >= 0 else 1.0
		var destination := _station_food_point(at_action, slot, peers.size(), lane_index)
		var replaced := _ticket_food_keys[slot] != key
		if replaced:
			_ticket_food_keys[slot] = key
			_load_process_visual(holder, phase, recipe_id, recipe.get("ingredients", []), slot)
			if holder.visible:
				var move := holder.create_tween()
				move.tween_property(holder, "position", destination, 0.33).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				move.parallel().tween_property(holder, "scale", Vector3.ONE * lane_scale * 1.12, 0.19).set_trans(Tween.TRANS_BACK)
				move.tween_property(holder, "scale", Vector3.ONE * lane_scale, 0.15)
			else:
				holder.position = destination
				holder.scale = Vector3.ONE * lane_scale * 0.40
				holder.create_tween().tween_property(holder, "scale", Vector3.ONE * lane_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif holder.position.distance_to(destination) > 0.05:
			holder.create_tween().tween_property(holder, "position", destination, 0.25)
		if not replaced and absf(holder.scale.x - lane_scale) > 0.03 and holder.visible:
			holder.scale = Vector3.ONE * lane_scale
		holder.visible = process_hold.is_empty()
		food_area.set_meta("order_number", int(ticket.get("order_number", -1)))
		food_area.set_meta("action", needed)
		food_area.collision_layer = INTERACT_LAYER if holder.visible else 0
	var job = _state.get("stock_job", {})
	if job is Dictionary and not job.is_empty():
		var job_id := str(job.get("id", ""))
		var job_step := maxi(0, int(job.get("step_index", 0)))
		var job_phase := "raw" if job_step == 0 else ("wash" if job_id == "rice_batter" else "slice")
		var job_key := "%s:%s" % [job_id, job_phase]
		if _stock_food_key != job_key:
			_stock_food_key = job_key
			_load_process_visual(_stock_food, job_phase, job_id, ["rice_flour", "leafy_greens"] if job_id == "rice_batter" else ["spice_oil", "ginger_syrup"])
		_stock_food.position = _station_food_point(str(job.get("next_action", "mix")), 0)
		_stock_food.visible = str(_process_hold_stock.get("id", "")) != job_id or int(_process_hold_stock.get("step_index", -1)) != job_step
		_stock_food_area.set_meta("action", str(job.get("next_action", "")))
		_stock_food_area.collision_layer = INTERACT_LAYER if _stock_food.visible else 0
	else:
		_stock_food.visible = false
		_stock_food_key = ""
		_stock_food_area.collision_layer = 0
	_refresh_heat_lights(tickets)
	_refresh_station_activity(tickets)


func _animate_ticket_heat() -> void:
	for slot in range(_ticket_food.size()):
		var holder := _ticket_food[slot]
		var fx := _ticket_heat_fx[slot]
		var phase := _ticket_heat_phase[slot]
		fx.visible = holder.visible and phase > 0
		if not fx.visible:
			holder.rotation.z = 0.0
			continue
		fx.position = holder.position
		fx.scale = holder.scale
		var simmering := phase == 1
		holder.rotation.z = sin(_steam_clock * 7.0 + float(slot) * 1.5) * 0.025 if simmering else 0.0
		var puffs: Array = _ticket_heat_puffs[slot]
		for i in range(puffs.size()):
			var puff := puffs[i] as MeshInstance3D
			var wave := fposmod(_steam_clock * (1.15 if simmering else 0.58) + float(i) * 0.34 + float(slot) * 0.23, 1.0)
			puff.position.y = 0.30 + wave * (0.38 if simmering else 0.23)
			puff.position.x = -0.18 + float(i) * 0.18 + sin(_steam_clock * 2.4 + float(i)) * 0.035
			puff.scale = Vector3(0.55 + wave * 0.25, 0.85 + wave * 0.60, 0.60 + wave * 0.15) * (1.0 if simmering else 0.72)
		var heat_ratio := clampf(float(fx.get_meta("heat_ratio", 0.0)), 0.0, 1.0)
		for mark_index in range(_ticket_heat_marks[slot].size()):
			var mark := _ticket_heat_marks[slot][mark_index] as MeshInstance3D
			var lit := not simmering or float(mark_index + 1) / 5.0 <= heat_ratio
			var material := mark.material_override as StandardMaterial3D
			material.albedo_color = (Color("#77a18a") if not simmering else Color("#d5a267")) if lit else Color("#796f60")


func _refresh_station_activity(tickets: Array) -> void:
	var active: Dictionary = {}
	var completed: Dictionary = {}
	var lane_tints: Dictionary = {}
	var customer_lane: Dictionary = {}
	_station_heating.clear()
	for entry in tickets:
		if not entry is Dictionary:
			continue
		var ticket: Dictionary = entry
		if bool(ticket.get("buffered", false)):
			continue
		var steps: Array = ticket.get("steps", []) if ticket.get("steps", []) is Array else []
		if steps.is_empty():
			continue
		var index := clampi(int(ticket.get("step_index", 0)), 0, steps.size() - 1)
		var action := str(ticket.get("next_action", steps[index]))
		active[action] = true
		var customer_id := int(ticket.get("customer_id", ticket.get("order_number", 0)))
		if not customer_lane.has(customer_id):
			customer_lane[customer_id] = clampi(customer_lane.size(), 0, TICKET_LANE_COLORS.size() - 1)
		var lane := int(customer_lane[customer_id])
		if not lane_tints.has(action) or int(ticket.get("slot", -1)) == int(_state.get("selected_slot", 0)):
			lane_tints[action] = TICKET_LANE_COLORS[lane]
		if action in ["steam", "fry", "boil"] and float(ticket.get("heat_left", 0.0)) > 0.0:
			_station_heating[action] = true
		if index > 0 and float(ticket.get("pickup_left", 0.0)) > 0.0:
			var previous := str(steps[index - 1])
			completed[previous] = true
	var job = _state.get("stock_job", {})
	if job is Dictionary and not job.is_empty():
		active[str(job.get("next_action", ""))] = true
	var guidance := _station_guidance()
	var chosen_action := str(guidance.get("action", ""))
	if bool(guidance.get("waiting", false)):
		chosen_action = ""
	var now := Time.get_ticks_msec()
	for action in _station_status_lamps.keys():
		var lamp := _station_status_lamps[action] as MeshInstance3D
		var done := bool(completed.get(action, false)) or now < int(_station_done_until.get(action, 0))
		var busy := bool(active.get(action, false)) or bool(_station_heating.get(action, false))
		var wrong := now < int(_station_wrong_until.get(action, 0))
		var lane_tint: Color = lane_tints.get(action, Color("#8eb39d"))
		var tint := Color("#ce7765") if wrong else (Color("#78a389") if done else (lane_tint if chosen_action == action else (Color("#d3a572") if bool(_station_heating.get(action, false)) else (lane_tint.darkened(0.13) if busy else Color("#76786f")))))
		var material := lamp.material_override as StandardMaterial3D
		material.albedo_color = tint
		material.emission = tint
		material.emission_energy_multiplier = 0.38 if chosen_action == action else (0.22 if done or busy else 0.02)
		var base: Color = STATION_TOP_COLORS.get(action, Color("#d4c0a1"))
		var surface := base.lerp(Color("#d99a84"), 0.20) if wrong else (base.lerp(Color("#b7d1bd"), 0.17) if done else (base.lerp(Color("#ead5ad"), 0.11) if busy else base))
		for part in _station_worktops.get(action, []):
			if part is MeshInstance3D:
				var top_material := (part as MeshInstance3D).material_override as StandardMaterial3D
				top_material.albedo_color = surface
		for ingredient in _station_ingredients.get(action, []):
			if ingredient is MeshInstance3D:
				(ingredient as MeshInstance3D).visible = busy or done
		for puff in _steam_by_station.get(action, []):
			if puff is MeshInstance3D:
				(puff as MeshInstance3D).visible = bool(_station_heating.get(action, false)) or done
	if is_instance_valid(_steam_fixture):
		_steam_fixture.visible = not bool(active.get("steam", false)) and not bool(completed.get("steam", false))


func _heat_lane_scale(count: int) -> float:
	return 0.54 if count >= 3 else (0.76 if count == 2 else 1.0)


func _station_food_point(action: String, slot: int, heat_count: int = 0, heat_lane: int = -1) -> Vector3:
	var lane_x := 0.0
	if heat_count == 2:
		lane_x = -0.49 if heat_lane == 0 else 0.49
	elif heat_count >= 3:
		lane_x = -0.66 + float(heat_lane) * 0.66
	if action == "serve":
		return Vector3(HANDOFF_X + lane_x, FRONT_TABLE_TOP + 0.09, FRONT_TABLE_Z)
	for entry in ACTIONS:
		if str(entry["id"]) == action:
			if HEAT_ACTIONS.has(action):
				return Vector3(float(entry["x"]) + lane_x, 1.18, float(entry["z"]))
			if action == "wash":
				return Vector3(float(entry["x"]) + lane_x, 1.025, float(entry["z"]) + 0.19)
			return Vector3(float(entry["x"]) + lane_x, 1.08, float(entry["z"]))
	return Vector3(0, 1.06, 0)


func _load_process_visual(holder: Node3D, phase: String, recipe_id: String, raw_ingredients: Variant, lane: int = -1) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	# Food-stage models already own their bowl, colander, board or pan. A second
	# generic plate made every intermediate look identical and float above tools.
	if phase == "raw":
		var ingredients: Array = raw_ingredients if raw_ingredients is Array else []
		for i in range(mini(ingredients.size(), 3)):
			_add_raw_ingredient(holder, str(ingredients[i]), -0.20 + float(i) * 0.20)
		return
	var asset := str(STAGE_FOOD.get(phase, ""))
	if phase == "wash":
		match recipe_id:
			"fruit_ice": asset = "washed_fruit"
			"coconut_millet": asset = "washed_millet"
			"chicken_rice", "rice_batter": asset = "washed_rice"
			"bay_shrimp_roll": asset = "washed_shrimp"
			"seaweed_dumpling": asset = "washed_seaweed"
	if phase == "slice":
		match recipe_id:
			"morning_egg_bun": asset = "sliced_bun_veg"
			"macao_spice_bun": asset = "sliced_chicken_spice"
			"harbour_noodles": asset = "sliced_noodle_greens"
			"fruit_ice": asset = "sliced_fruit"
			"spice_oil": asset = "sliced_spices"
	if phase == "mix":
		match recipe_id:
			"macao_spice_bun", "spice_oil": asset = "spice_jar"
			"harbour_noodles": asset = "mixed_harbour_noodles"
			"bay_shrimp_roll": asset = "mixed_shrimp_batter"
			"seaweed_dumpling": asset = "mixed_seaweed_dough"
			"fruit_ice": asset = "blended_fruit_ice"
	if phase == "marinate" and recipe_id in ["macao_spice_bun", "chicken_rice"]:
		asset = "marinated_chicken"
	if phase == "steam" and recipe_id == "bay_shrimp_roll":
		asset = "steamer_shrimp_roll"
	if phase == "steam" and recipe_id == "seaweed_dumpling":
		asset = "steamer_seaweed_dumpling"
	if phase == "fry" and recipe_id == "morning_egg_bun":
		asset = "fried_egg_pan"
	if phase == "boil" and recipe_id == "warm_tofu_bowl":
		asset = "simmering_tofu_basin"
	if phase == "boil" and recipe_id == "coconut_millet":
		asset = "coconut_millet_simmer"
	if phase == "portion":
		match recipe_id:
			"warm_tofu_bowl": asset = "portioned_tofu"
			"coconut_millet": asset = "portioned_coconut_millet"
			"chicken_rice": asset = "portioned_chicken_rice"
			"bay_shrimp_roll": asset = "portioned_shrimp_roll"
			"seaweed_dumpling": asset = "portioned_seaweed_dumpling"
	if phase in ["garnish", "serve"]:
		var dish_path := "res://assets/art/models/food/%s.glb" % recipe_id
		if ResourceLoader.exists(dish_path):
			var dish_packed = ResourceLoader.load(dish_path)
			if dish_packed is PackedScene:
				var dish := (dish_packed as PackedScene).instantiate() as Node3D
				holder.add_child(dish)
				_fit_display_model(dish, 0.86)
				return
	var path := "res://assets/art/models/food_stage/%s.glb" % asset
	if asset != "" and ResourceLoader.exists(path):
		var packed = ResourceLoader.load(path)
		if packed is PackedScene:
			var model := (packed as PackedScene).instantiate() as Node3D
			holder.add_child(model)
			_fit_display_model(model, 1.12 if phase in ["wash", "steam", "fry", "boil"] else 1.0)
			if phase == "mix":
				var players := model.find_children("*", "AnimationPlayer", true, false)
				if not players.is_empty():
					var animation_player := players[0] as AnimationPlayer
					if animation_player != null and not animation_player.get_animation_list().is_empty():
						animation_player.play(animation_player.get_animation_list()[0])
			return
	_build_process_fallback(holder, phase, recipe_id)


func _add_raw_ingredient(holder: Node3D, ingredient: String, x: float) -> void:
	match ingredient:
		"leafy_greens":
			for n in range(3):
				var leaf := _sphere(holder, Vector3(x - 0.055 + float(n) * 0.054, 0.10, -0.025 + float(n % 2) * 0.05), 0.095, Color("#79aa78") if n == 1 else Color("#5d936b"))
				leaf.scale = Vector3(0.68, 0.28, 1.20)
				leaf.rotation.y = float(n - 1) * 0.48
		"cucumber":
			var cucumber := _cylinder(holder, Vector3(x, 0.10, 0), 0.068, 0.25, Color("#62966b"))
			cucumber.rotation.z = PI * 0.5
			_cylinder(holder, Vector3(x + 0.13, 0.10, 0), 0.057, 0.010, Color("#c4c990")).rotation.z = PI * 0.5
		"seaweed":
			for n in range(2):
				var sheet := _box(holder, Vector3(x - 0.045 + float(n) * 0.09, 0.10, 0), Vector3(0.10, 0.025, 0.19), Color("#496d61"))
				sheet.rotation.y = float(n) * 0.34 - 0.17
				_box(holder, Vector3(x - 0.045 + float(n) * 0.09, 0.116, 0), Vector3(0.025, 0.003, 0.11), Color("#7e9c73"))
		"shrimp":
			for n in range(4):
				_sphere(holder, Vector3(x - 0.07 + float(n) * 0.047, 0.095, float(n % 2) * 0.035), 0.047, Color("#d77f6c") if n % 2 == 0 else Color("#ebb09a"))
			_box(holder, Vector3(x + 0.13, 0.09, -0.02), Vector3(0.055, 0.022, 0.078), Color("#f3c6a8"))
		"egg":
			var egg := _sphere(holder, Vector3(x, 0.12, 0), 0.105, Color("#f0e6cc"))
			egg.scale = Vector3(0.83, 1.12, 0.83)
			_sphere(holder, Vector3(x - 0.028, 0.18, -0.076), 0.017, Color("#fff9e9"))
		"soft_tofu":
			_box(holder, Vector3(x, 0.09, 0), Vector3(0.18, 0.13, 0.18), Color("#eee7d4"))
			_box(holder, Vector3(x, 0.16, 0), Vector3(0.14, 0.009, 0.14), Color("#fff5e2"))
		"fruit":
			_sphere(holder, Vector3(x, 0.105, 0), 0.095, Color("#d98576"))
			var fruit_leaf := _sphere(holder, Vector3(x + 0.044, 0.19, 0), 0.036, Color("#6d9a6d"))
			fruit_leaf.scale = Vector3(1.30, 0.33, 0.67)
		"osmanthus":
			for n in range(4):
				_sphere(holder, Vector3(x + cos(float(n) * PI * 0.5) * 0.054, 0.10, sin(float(n) * PI * 0.5) * 0.054), 0.039, Color("#e4be67"))
			_sphere(holder, Vector3(x, 0.12, 0), 0.025, Color("#d2924e"))
		"chicken":
			var chicken := _capsule(holder, Vector3(x, 0.105, 0), 0.085, 0.20, Color("#bd805e"))
			chicken.rotation.z = PI * 0.5
			for n in range(2):
				_box(holder, Vector3(x - 0.04 + float(n) * 0.08, 0.175, 0), Vector3(0.018, 0.005, 0.11), Color("#e6b27e"))
		"soft_bun":
			var bun := _sphere(holder, Vector3(x, 0.105, 0), 0.12, Color("#d7a477"))
			bun.scale.y = 0.62
			_box(holder, Vector3(x, 0.095, 0.109), Vector3(0.18, 0.012, 0.006), Color("#9a6a4c"))
		"rice_flour":
			var sack := _capsule(holder, Vector3(x, 0.13, 0), 0.086, 0.18, Color("#e9dfc7"))
			sack.scale.z = 0.81
			_cylinder(holder, Vector3(x, 0.245, 0), 0.055, 0.030, Color("#b9a986"))
			_box(holder, Vector3(x, 0.12, 0.072), Vector3(0.075, 0.075, 0.008), Color("#8daa90"))
		"millet", "rice":
			_cylinder(holder, Vector3(x, 0.065, 0), 0.12, 0.095, Color("#a5b3a2"))
			_cylinder(holder, Vector3(x, 0.125, 0), 0.10, 0.019, Color("#e4c174") if ingredient == "millet" else Color("#f0e8d3"))
			for n in range(3):
				_sphere(holder, Vector3(x - 0.06 + float(n) * 0.058, 0.143, 0), 0.027, Color("#d7b66c") if ingredient == "millet" else Color("#faf5e6"))
		"noodles":
			_cylinder(holder, Vector3(x, 0.07, 0), 0.12, 0.095, Color("#87a69b"))
			for n in range(3):
				var strand := _cylinder(holder, Vector3(x - 0.06 + float(n) * 0.06, 0.14, 0), 0.014, 0.16, Color("#e6c381"))
				strand.rotation.z = PI * 0.5
		"yogurt":
			_cylinder(holder, Vector3(x, 0.10, 0), 0.086, 0.15, Color("#d7e4dc"))
			_cylinder(holder, Vector3(x, 0.188, 0), 0.093, 0.024, Color("#8fbaa9"))
		"ice":
			_box(holder, Vector3(x - 0.045, 0.095, 0), Vector3(0.12, 0.12, 0.12), Color("#c4e0dc"))
			_box(holder, Vector3(x + 0.056, 0.11, 0.02), Vector3(0.10, 0.10, 0.10), Color("#e3eeee"))
		"spice_oil", "soy_sauce", "ginger_syrup", "coconut_milk":
			var bottle_color := Color("#d8aa6a") if ingredient == "spice_oil" else Color("#84644f") if ingredient == "soy_sauce" else Color("#c9975d") if ingredient == "ginger_syrup" else Color("#e7e7d6")
			_cylinder(holder, Vector3(x, 0.13, 0), 0.077, 0.20, bottle_color)
			_cylinder(holder, Vector3(x, 0.245, 0), 0.049, 0.042, Color("#b7c2a2"))
			_box(holder, Vector3(x, 0.13, 0.077), Vector3(0.092, 0.06, 0.009), Color("#eee2c1"))
		_:
			_cylinder(holder, Vector3(x, 0.085, 0), 0.10, 0.10, Color("#ead8aa"))


func _build_process_fallback(holder: Node3D, phase: String, recipe_id: String) -> void:
	match phase:
		"wash", "slice":
			for i in range(4):
				_add_raw_ingredient(holder, "leafy_greens" if phase == "wash" else "cucumber", -0.22 + float(i) * 0.14)
		"mix", "boil":
			_cylinder(holder, Vector3(0, 0.13, 0), 0.25, 0.19, Color("#b6a087") if phase == "boil" else Color("#d1ad83"))
			_cylinder(holder, Vector3(0, 0.24, 0), 0.20, 0.025, Color("#e6d3a4"))
			_add_raw_ingredient(holder, "soft_tofu" if recipe_id == "warm_tofu_bowl" else "fruit" if recipe_id == "fruit_ice" else "rice_flour", 0.0)
		"marinate":
			_cylinder(holder, Vector3(0, 0.17, 0), 0.16, 0.27, Color("#af8063"))
			_cylinder(holder, Vector3(0, 0.32, 0), 0.18, 0.035, Color("#e1cfaa"))
		"portion", "garnish", "serve":
			for i in range(3):
				_sphere(holder, Vector3(-0.18 + float(i) * 0.18, 0.11, 0), 0.085, Color("#c59070") if recipe_id in ["chicken_rice", "macao_spice_bun"] else Color("#83a375"))
		"steam":
			_cylinder(holder, Vector3(0, 0.12, 0), 0.28, 0.15, Color("#caa775"))
			_cylinder(holder, Vector3(0, 0.21, 0), 0.29, 0.035, Color("#e2c18b"))
		"fry":
			_cylinder(holder, Vector3(0, 0.09, 0), 0.28, 0.09, Color("#607370"))
			for i in range(3):
				_sphere(holder, Vector3(-0.13 + float(i) * 0.13, 0.17, 0), 0.07, Color("#c69465"))


func _refresh_heat_lights(tickets: Array) -> void:
	for action in _heat_lights.keys():
		var fraction := -1.0
		var ready := false
		for entry in tickets:
			if not entry is Dictionary:
				continue
			var ticket: Dictionary = entry
			var steps: Array = ticket.get("steps", []) if ticket.get("steps", []) is Array else []
			if steps.is_empty():
				continue
			var index := clampi(int(ticket.get("step_index", 0)), 0, steps.size() - 1)
			var heat_left := float(ticket.get("heat_left", 0.0))
			var pickup_left := float(ticket.get("pickup_left", 0.0))
			if heat_left > 0.0 and str(ticket.get("next_action", steps[index])) == str(action):
				fraction = 1.0 - heat_left / maxf(0.1, float(ticket.get("heat_total", 1.0)))
			if pickup_left > 0.0 and index > 0 and str(steps[index - 1]) == str(action):
				fraction = 1.0
				ready = true
		var lights: Array = _heat_lights[action]
		for i in range(lights.size()):
			var lamp := lights[i] as MeshInstance3D
			lamp.visible = fraction >= 0.0
			if not lamp.visible:
				continue
			var lit := float(i + 1) / float(lights.size()) <= fraction
			var material := lamp.material_override as StandardMaterial3D
			material.albedo_color = Color("#75a888") if ready and lit else (Color("#d2a66e") if lit else Color("#756c5c"))


func _refresh_buffer() -> void:
	var raw = _state.get("buffer", [])
	var entries: Array = raw if raw is Array else []
	var combo: Dictionary = _state.get("combo_plate", {}) if _state.get("combo_plate", {}) is Dictionary else {}
	var current_step := str(_state.get("next_action", ""))
	for slot in range(_buffer_dishes.size()):
		var entry: Dictionary = entries[slot] if slot < entries.size() and entries[slot] is Dictionary else {}
		var occupied := bool(entry.get("occupied", false))
		var recipe_id := str(entry.get("recipe_id", "")) if occupied else ""
		var holder := _buffer_dishes[slot]
		if _buffer_keys[slot] != recipe_id:
			_buffer_keys[slot] = recipe_id
			if recipe_id != "":
				_load_food_model(holder, recipe_id, 0.93)
				holder.scale = Vector3.ONE * 0.50
				holder.create_tween().tween_property(holder, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		holder.visible = occupied
		var fresh := maxf(0.0, float(entry.get("fresh_left", 0.0)))
		var fresh_total := maxf(0.1, float(entry.get("fresh_total", 26.0)))
		if slot < 2 and bool(combo.get("active", false)):
			var staged := int(combo.get("staged_count", 0))
			_buffer_areas[slot].set_meta("display_name", "顾客 1 的整餐 · %d/2 道 · %s" % [staged, "点击整盘交餐" if bool(combo.get("ready", false)) else "等另一道装盘"])
		else:
			_buffer_areas[slot].set_meta("display_name", "出餐暂存 %d · 保鲜 %ds" % [slot + 1, ceili(fresh)] if occupied else "空托盘 · 可暂存成品")
		var ring := _buffer_rings[slot]
		ring.visible = occupied or current_step == "serve"
		var material := ring.material_override as StandardMaterial3D
		material.albedo_color = Color("#cd8b70") if occupied and fresh / fresh_total < 0.30 else (Color("#7fac8d") if occupied else Color("#b3aa8d"))
		material.emission = material.albedo_color


func _refresh_tutorial() -> void:
	if not is_instance_valid(_tutorial_panel):
		return
	# Food names stay on meal tickets; actions are taught by real appliance
	# motion and the small step marks in the existing bottom rail.
	_tutorial_panel.visible = false
	for i in range(_shift_areas.size()):
		_shift_areas[i].collision_layer = INTERACT_LAYER
		_shift_areas[i].set_meta("display_name", "切换悠闲节奏" if i == 0 else "切换忙碌节奏")
		_shift_halos[i].visible = false


func _refresh_settlement() -> void:
	if not is_instance_valid(_settlement_overlay):
		return
	var closed := str(_state.get("stage", "")) == "closed" and not bool(_state.get("active", false))
	_settlement_overlay.visible = closed
	if is_instance_valid(_closing_sign_area):
		_closing_sign_area.collision_layer = INTERACT_LAYER if bool(_state.get("active", false)) and bool(_state.get("endless", false)) else 0
	if is_instance_valid(_closing_sign_label):
		_closing_sign_label.text = "已打烊" if closed else "打烊"
	if not closed:
		return
	var summary: Dictionary = _state.get("last_settlement", {}) if _state.get("last_settlement", {}) is Dictionary else {}
	_settlement_stats.text = "完成 %d 道 · 顾客离开 %d 道\n本次收入  %d 贝\n营业 %d 天" % [int(summary.get("served", 0)), int(summary.get("missed", 0)), int(summary.get("earned", 0)), int(summary.get("days", 1))]


func _station_guidance() -> Dictionary:
	var stock_job: Dictionary = _state.get("stock_job", {}) if _state.get("stock_job", {}) is Dictionary else {}
	if str(_state.get("selected_target", "")) == "stock" and not stock_job.is_empty():
		return {"action": str(stock_job.get("next_action", ""))}
	if not bool(_state.get("active", false)):
		return {}
	var raw: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
	if raw.is_empty():
		return {}
	var slot := clampi(int(_state.get("selected_slot", 0)), 0, raw.size() - 1)
	var ticket: Dictionary = raw[slot] if raw[slot] is Dictionary else {}
	if not bool(ticket.get("started", false)):
		return {}
	var combo: Dictionary = _state.get("combo_plate", {}) if _state.get("combo_plate", {}) is Dictionary else {}
	if bool(ticket.get("buffered", false)):
		if bool(combo.get("ready", false)):
			return {"action": "serve"}
		return {}
	var action := str(ticket.get("next_action", ""))
	if action.is_empty():
		return {}
	if float(ticket.get("heat_left", 0.0)) > 0.0:
		return {"action": action, "waiting": true}
	return {"action": action}


func _action_name(action_id: String) -> String:
	for entry in ACTIONS:
		if str(entry["id"]) == action_id:
			return str(entry["name"])
	return action_id


func _refresh_scene_clock() -> void:
	if not is_instance_valid(_clock_hour_hand):
		return
	var sun_minutes := fposmod(float(_state.get("clock_minutes", _state.get("day_minutes", 480))), 1440.0)
	var minutes := int(sun_minutes)
	var hour := float(minutes) / 60.0
	_clock_hour_hand.rotation.y = -TAU * fmod(hour, 12.0) / 12.0
	_clock_minute_hand.rotation.y = -TAU * float(minutes % 60) / 60.0
	var period := str(_state.get("service_period", _state.get("market_phase", "morning")))
	var period_names := {"morning": "早市", "lunch": "午市", "evening": "晚市"}
	if is_instance_valid(_clock_label):
		_clock_label.text = "◷ %02d:%02d · %s" % [minutes / 60, minutes % 60, str(period_names.get(period, "早市"))]
	var active_index := 0 if period == "morning" else (1 if period == "lunch" else 2)
	var hues := [Color("#d0a26b"), Color("#83a88b"), Color("#bd856e")]
	for i in range(_period_lamps.size()):
		var lamp := _period_lamps[i]
		var material := lamp.material_override as StandardMaterial3D
		material.albedo_color = hues[i] if i == active_index else Color("#797b70")
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.16 if i == active_index else 0.02
	var dawn_mix := 1.0 - smoothstep(500.0, 575.0, sun_minutes)
	var dusk_mix := smoothstep(990.0, 1040.0, sun_minutes)
	var night_mix := smoothstep(1110.0, 1200.0, sun_minutes)
	var sunset_peak := dusk_mix * (1.0 - smoothstep(1070.0, 1150.0, sun_minutes))
	var dawn_to_day := smoothstep(540.0, 600.0, sun_minutes)
	var day_to_dusk := smoothstep(960.0, 1020.0, sun_minutes)
	var dusk_to_night := smoothstep(1110.0, 1170.0, sun_minutes)
	var day_key := lerpf(0.25, 0.29, 1.0 - dawn_mix) if period == "morning" else 0.30
	if _kitchen_environment != null:
		_kitchen_environment.background_color = Color("#cad2c8").lerp(Color("#d1b9b3"), dawn_mix).lerp(Color("#ad9495"), dusk_mix).lerp(Color("#344e5d"), night_mix)
		_kitchen_environment.ambient_light_color = Color("#e8dfd0").lerp(Color("#ecd0bb"), dawn_mix).lerp(Color("#cab0aa"), dusk_mix).lerp(Color("#b1b7bf"), night_mix)
		_kitchen_environment.ambient_light_energy = lerpf(lerpf(0.23, 0.21, dusk_mix), 0.20, night_mix)
		_kitchen_environment.tonemap_exposure = lerpf(lerpf(0.62, 0.62, dusk_mix), 0.63, night_mix)
	for fill in _fill_lights:
		fill.light_energy = lerpf(lerpf(0.10 if period == "morning" else 0.09, 0.25, dusk_mix), 0.45, night_mix)
	var key_light := _stage.get_node_or_null("KitchenSoftbox") as DirectionalLight3D
	if is_instance_valid(key_light):
		key_light.light_energy = lerpf(lerpf(day_key + 0.07, 0.30, dusk_mix), 0.22, night_mix)
		key_light.light_color = Color("#fff0d4").lerp(Color("#ffd2a0"), dawn_mix * 0.74).lerp(Color("#ffb377"), sunset_peak * 0.65).lerp(Color("#d7dce0"), night_mix * 0.42)
		var day_progress := clampf((sun_minutes - 480.0) / 660.0, 0.0, 1.0)
		var sun_height := sin(PI * day_progress)
		key_light.rotation_degrees = Vector3(-37.0 - 20.0 * sun_height, lerpf(-55.0, 24.0, day_progress), 0.0)
		# The sun's long evening shadows fade as the cabinet lights take over.
		key_light.shadow_opacity = lerpf(0.34, 0.0, dusk_mix)
	if is_instance_valid(_window_beam):
		_window_beam.light_energy = lerpf(0.08 + 0.06 * dawn_mix + 0.07 * sunset_peak, 0.025, night_mix)
		_window_beam.light_color = Color("#fff0d3").lerp(Color("#ffc590"), dawn_mix * 0.9).lerp(Color("#ffab71"), sunset_peak * 0.92).lerp(Color("#94b0ce"), night_mix)
		_window_beam.rotation_degrees = Vector3(-34.0, lerpf(-145.0, -170.0, sunset_peak), 0.0)
	_set_window_weight(_window_dawn, "dawn", 1.0 - dawn_to_day)
	_set_window_weight(_window_day, "day", dawn_to_day * (1.0 - day_to_dusk))
	_set_window_weight(_window_dusk, "dusk", day_to_dusk * (1.0 - dusk_to_night))
	_set_window_weight(_window_evening, "evening", dusk_to_night)
	if is_instance_valid(_sunset_bounce):
		_sunset_bounce.light_color = Color("#ffd4a3") if dawn_mix > 0.5 else Color("#ffae73")
		_sunset_bounce.position.x = -5.5 if dawn_mix > 0.5 else -2.4
		_sunset_bounce.light_energy = maxf(0.12 * dawn_mix, 0.21 * sunset_peak)
	if is_instance_valid(_night_window_fill):
		_night_window_fill.light_energy = 0.10 * night_mix
	for light in _service_lights:
		light.light_energy = lerpf(lerpf(0.13, 0.43, dusk_mix), 0.55, night_mix)
	for task_light in _task_lights:
		task_light.light_energy = lerpf(lerpf(0.06, 0.16, dusk_mix), 0.35, night_mix)
	for side_light in _night_side_lights:
		side_light.light_energy = 0.45 * night_mix
	for sconce in _pantry_sconce_lights:
		sconce.light_energy = 0.30 * night_mix + 0.07 * dusk_mix
	for shade in _pantry_sconce_glows:
		var material := shade.material_override as StandardMaterial3D
		material.emission_energy_multiplier = 0.04 + 0.42 * night_mix + 0.08 * dusk_mix
	for lamp in _front_station_lights:
		lamp.light_energy = 0.025 + 0.12 * night_mix + 0.05 * dusk_mix
	for lamp in _prep_table_lights:
		lamp.light_energy = 0.025 + 0.13 * night_mix + 0.05 * dusk_mix
	for glow in _front_lamp_glows:
		var material := glow.material_override as StandardMaterial3D
		material.emission_energy_multiplier = 0.04 + 0.42 * night_mix + 0.08 * dusk_mix
	for glow in _service_glows:
		var material := glow.material_override as StandardMaterial3D
		material.emission_energy_multiplier = lerpf(lerpf(0.08, 0.54, dusk_mix), 1.20, night_mix)


func _set_window_weight(model: Node3D, variant: String, weight: float) -> void:
	if not is_instance_valid(model):
		return
	var amount := clampf(weight, 0.0, 1.0)
	model.visible = amount > 0.005
	for mesh in _window_meshes.get(variant, []):
		if mesh is GeometryInstance3D:
			(mesh as GeometryInstance3D).transparency = 1.0 - amount


func _refresh_progress() -> void:
	if not is_instance_valid(_patience):
		return
	# Each ticket carries its patience bar, and cooking progress is attached to
	# the appliance; this separate left overlay needlessly obscured the scene.
	_progress_panel.visible = false
	var time_left := maxf(0.0, float(_state.get("time_left", 0.0)))
	var mode := str(_state.get("mode", "calm"))
	var total := maxf(1.0, float(_state.get("patience_total", 36.0 if mode == "rush" else 55.0)))
	_patience.value = clampf(time_left / total * 100.0, 0.0, 100.0)
	_patience_label.text = "◷  %ds" % ceili(time_left)
	var order: Dictionary = _state.get("order", {}) if _state.get("order", {}) is Dictionary else {}
	var heat_total := maxf(0.1, float(_state.get("heat_total", order.get("cook_seconds", 3.5))))
	var heat_left := maxf(0.0, float(_state.get("heat_left", 0.0)))
	var heating := str(_state.get("stage", "")) == "heating" or heat_left > 0.0
	_heat.value = clampf((heat_total - heat_left) / heat_total * 100.0, 0.0, 100.0) if heating else 0.0
	_heat_label.text = "♨  %d%%" % int(_heat.value)
	_combo_label.text = "★ %d" % maxi(0, int(_state.get("combo", _state.get("streak", 0))))
	var active := bool(_state.get("active", false))
	var order_no := int(_state.get("order_number", 0))
	var total_orders := int(_state.get("total_orders", 0))
	_status_label.text = "备货" if str(_state.get("selected_target", "")) == "stock" else (("第 %d 单" % order_no) if bool(_state.get("endless", false)) else ("%d / %d" % [order_no, total_orders])) if active else ""
	var steps: Array = []
	var step_index := 0
	var next_action := ""
	var waiting := false
	var buffered := false
	var next_text := "点餐票选菜"
	if active and str(_state.get("selected_target", "")) == "stock":
		var job: Dictionary = _state.get("stock_job", {}) if _state.get("stock_job", {}) is Dictionary else {}
		var stock_id := str(job.get("id", ""))
		if TalentParkRestaurant3D.STOCKS.has(stock_id):
			steps = (TalentParkRestaurant3D.STOCKS[stock_id]["steps"] as Array).duplicate()
			step_index = int(job.get("step_index", 0))
			next_action = str(job.get("next_action", ""))
			next_text = "下一步 · %s台" % _action_name(next_action)
	elif active:
		var raw: Array = _state.get("tickets", []) if _state.get("tickets", []) is Array else []
		if not raw.is_empty():
			var slot := clampi(int(_state.get("selected_slot", 0)), 0, raw.size() - 1)
			var ticket: Dictionary = raw[slot] if raw[slot] is Dictionary else {}
			steps = ticket.get("steps", []) if bool(ticket.get("started", false)) and ticket.get("steps", []) is Array else []
			step_index = int(ticket.get("step_index", 0))
			next_action = str(ticket.get("next_action", ""))
			if not bool(ticket.get("started", false)):
				next_text = "点右上餐票开做"
			else:
				next_text = "下一步 · %s台" % _action_name(next_action)
			waiting = float(ticket.get("heat_left", 0.0)) > 0.0
			buffered = bool(ticket.get("buffered", false))
			var prep: Dictionary = _state.get("prep_ingredients", {}) if _state.get("prep_ingredients", {}) is Dictionary else {}
			var recipe: Dictionary = ticket.get("recipe", {}) if ticket.get("recipe", {}) is Dictionary else {}
			var missing := false
			if not bool(ticket.get("ingredients_reserved", false)):
				for key in recipe.get("ingredients", []):
					if int(prep.get(str(key), 0)) <= 0:
						missing = true
						break
			if not bool(ticket.get("started", false)):
				pass
			elif buffered:
				var combo: Dictionary = _state.get("combo_plate", {}) if _state.get("combo_plate", {}) is Dictionary else {}
				next_text = "点成品交餐" if bool(combo.get("ready", false)) else "等同桌另一道"
			elif missing:
				next_text = "缺料 · 点左侧气泡"
			elif bool(ticket.get("reheat_needed", false)):
				next_text = "回到%s台加热" % _action_name(next_action)
			elif waiting:
				next_text = "%s台加热中" % _action_name(next_action)
			elif float(ticket.get("pickup_left", 0.0)) > 0.0:
				next_text = "点%s台取菜" % _action_name(next_action)
			elif next_action == "serve":
				next_text = "点成品交餐"
			else:
				next_text = "下一步 · %s台" % _action_name(next_action)
	_step_count_label.text = "进度 %d/%d" % [mini(step_index, steps.size()), steps.size()] if not steps.is_empty() else "进度"
	_step_rail.visible = active and not steps.is_empty()
	_step_rail.set_steps(steps, step_index, waiting, buffered)
	_step_action_label.text = next_text if active else ""


func _refresh_station_hint() -> void:
	# Move the real utensil and pool a little task light over it. No ring, strip,
	# text, or HUD is drawn over the food or counter.
	for halo in _station_halos.values():
		if halo is MeshInstance3D:
			(halo as MeshInstance3D).visible = false
	for halo in _stock_halos:
		halo.visible = false
	var guidance := _station_guidance()
	var target := str(guidance.get("action", ""))
	var waiting := bool(guidance.get("waiting", false))
	for action in _station_focus_props.keys():
		var focused := str(action) == target and not waiting
		(_station_focus_props[action] as Node3D).set_meta("next_action", focused)
		(_station_focus_lights[action] as OmniLight3D).visible = focused


func _update_hover(screen_position: Vector2) -> void:
	_set_hover(_ray_pick(screen_position))


func _set_hover(area: Area3D) -> void:
	if _hovered == area:
		return
	_hovered = area
	_refresh_station_hint()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if is_instance_valid(area) else Input.CURSOR_ARROW)


func _ray_pick(screen_position: Vector2) -> Area3D:
	if not is_instance_valid(camera):
		return null
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, INTERACT_LAYER)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Area3D if hit.get("collider") is Area3D else null


func _area(parent: Node3D, kind: String, id: String, display_name: String, at: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.position = at
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.set_meta("kind", kind)
	area.set_meta("id", id)
	area.set_meta("display_name", display_name)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
	return area


func _box(parent: Node3D, at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var mesh: BoxMesh = _box_meshes.get(size)
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_box_meshes[size] = mesh
	return _mesh(parent, mesh, at, tint)


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, tint: Color, glow := false) -> MeshInstance3D:
	var key := Vector2(radius, height)
	var mesh: CylinderMesh = _cylinder_meshes.get(key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius * 1.02
		mesh.height = height
		# The fixed kitchen camera projects small handles and jars to only a few
		# pixels. Keep smooth large cookware while avoiding invisible facets.
		mesh.radial_segments = 16 if radius < 0.08 else (32 if radius < 0.34 else 48)
		_cylinder_meshes[key] = mesh
	return _mesh(parent, mesh, at, tint, glow)


func _edge_cue(parent: Node3D, at: Vector3, width: float) -> MeshInstance3D:
	var size := Vector3(width, 0.025, 0.045)
	var mesh: BoxMesh = _box_meshes.get(size)
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_box_meshes[size] = mesh
	return _mesh(parent, mesh, at, Color("#7db99b"), true)


func _sphere(parent: Node3D, at: Vector3, radius: float, tint: Color, glow := false) -> MeshInstance3D:
	var mesh: SphereMesh = _sphere_meshes.get(radius)
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 16 if radius < 0.08 else (32 if radius < 0.34 else 48)
		mesh.rings = 8 if radius < 0.08 else (16 if radius < 0.34 else 24)
		_sphere_meshes[radius] = mesh
	return _mesh(parent, mesh, at, tint, glow)


func _capsule(parent: Node3D, at: Vector3, radius: float, height: float, tint: Color) -> MeshInstance3D:
	var key := Vector2(radius, height)
	var mesh: CapsuleMesh = _capsule_meshes.get(key)
	if mesh == null:
		mesh = CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.radial_segments = 16 if radius < 0.08 else (32 if radius < 0.34 else 48)
		mesh.rings = 8 if radius < 0.08 else (16 if radius < 0.34 else 24)
		_capsule_meshes[key] = mesh
	return _mesh(parent, mesh, at, tint)


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, tint: Color, glow := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.76
	if glow:
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 0.45
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _label(value: String, size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", _playful_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _progress() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(217, 9)
	bar.max_value = 100
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0.18, 0.25, 0.21, 0.15)
	style.shadow_size = 5
	return style


func _meal_card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _card_style(fill, border)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.22, 0.27, 0.22, 0.12)
	style.shadow_size = 3
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _ticket_shell_style(selected: bool, urgent: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f8f7f0") if selected else Color("#ecefe9")
	style.border_color = Color("#b67967") if urgent else (Color("#8da99c") if selected else Color("#b8c3b8"))
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.13, 0.19, 0.16, 0.14)
	style.shadow_size = 3
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _ticket_tray_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f0f2ec")
	style.border_color = Color("#d8dfd5")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _tray_food_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(5)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style
