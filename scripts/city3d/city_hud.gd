class_name CityHud3D
extends CanvasLayer

const BAY_COIN_ICON := "res://assets/art/ui/city3d/bay_coin.svg"
const ENERGY_LEAF_ICON := "res://assets/art/ui/city3d/energy_leaf.svg"
const COLLECTION_GEM_ICON := "res://assets/art/ui/city3d/collection_gem.svg"
const DISTRICT_PIN_ICON := "res://assets/art/ui/city3d/district_pin.svg"
const MAP_FOLD_ICON := "res://assets/art/ui/city3d/map_fold.svg"
const INTERACT_TOUCH_ICON := "res://assets/art/ui/city3d/interact_touch.svg"

var _district_label: Label
var _prompt_label: Label
var _notice_label: Label
var _notice_timer: Timer
var _day_label: Label
var _cash_label: Label
var _energy_label: Label
var _energy_icon: TextureRect
var _collection_label: Label
var _field_task_panel: PanelContainer
var _field_task_activity: Label
var _field_task_action: Label
var _field_task_progress: Label
var _field_task_active := false
var _modal: PanelContainer
var _modal_header_icon: TextureRect
var _modal_title: Label
var _modal_description: Label
var _modal_choices: GridContainer
var _choice_scroll: ScrollContainer
var _modal_footer: Button
var _choice_callback: Callable
var _is_overview := false
var _icon_cache: Dictionary = {}
var _layout_ticket := 0

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.name = "CityHudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var district_panel := _panel(Color("#f6e8d0"), Color("#b88b68"))
	district_panel.position = Vector2(28, 24)
	district_panel.custom_minimum_size = Vector2(260, 52)
	root.add_child(district_panel)
	var district_row := _row(7)
	district_row.add_child(_icon(DISTRICT_PIN_ICON, 27))
	_district_label = _label("深圳 · 街巷生活区", 19, Color("#4d5b53"))
	district_row.add_child(_district_label)
	district_panel.add_child(_margin(district_row, 13, 9))
	var status_panel := _panel(Color("#f6e8d0"), Color("#b88b68"))
	status_panel.position = Vector2(28, 84)
	status_panel.custom_minimum_size = Vector2(390, 45)
	root.add_child(status_panel)
	var status_row := _row(7)
	_day_label = _label("第 1 天", 15, Color("#4d5b53"))
	status_row.add_child(_day_label)
	status_row.add_child(_icon(BAY_COIN_ICON, 22))
	_cash_label = _label("120 贝", 15, Color("#4d5b53"))
	status_row.add_child(_cash_label)
	_energy_icon = _icon(ENERGY_LEAF_ICON, 22)
	status_row.add_child(_energy_icon)
	_energy_label = _label("精力 100", 15, Color("#4d5b53"))
	status_row.add_child(_energy_label)
	status_row.add_child(_icon(COLLECTION_GEM_ICON, 22))
	_collection_label = _label("藏品 0", 15, Color("#4d5b53"))
	status_row.add_child(_collection_label)
	status_panel.add_child(_margin(status_row, 12, 7))
	var help := _label("WASD 移动   左键互动   滚轮缩放   右键转视角   M 总览   Esc 返回", 16, Color("#4d5b53"))
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.offset_left = -780
	help.offset_right = -25
	help.offset_top = 34
	help.offset_bottom = 63
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(help)
	_build_field_task(root)
	var prompt_panel := _panel(Color(0.98, 0.92, 0.82, 0.94), Color("#b88b68"))
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_top = 1.0
	prompt_panel.anchor_bottom = 1.0
	prompt_panel.offset_left = -250
	prompt_panel.offset_right = 250
	prompt_panel.offset_top = -87
	prompt_panel.offset_bottom = -32
	root.add_child(prompt_panel)
	var prompt_row := _row(7)
	prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_row.add_child(_icon(INTERACT_TOUCH_ICON, 27))
	_prompt_label = _label("沿着街道走走", 18, Color("#465954"))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_row.add_child(_prompt_label)
	prompt_panel.add_child(_margin(prompt_row, 12, 11))
	var notice_panel := _panel(Color(0.23, 0.36, 0.34, 0.95), Color("#d4b58d"))
	notice_panel.anchor_left = 0.5
	notice_panel.anchor_right = 0.5
	notice_panel.anchor_top = 1.0
	notice_panel.anchor_bottom = 1.0
	notice_panel.offset_left = -330
	notice_panel.offset_right = 330
	notice_panel.offset_top = -150
	notice_panel.offset_bottom = -97
	root.add_child(notice_panel)
	_notice_label = _label("", 18, Color("#fff4df"))
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_panel.add_child(_margin(_notice_label, 12, 10))
	notice_panel.visible = false
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.timeout.connect(func() -> void: notice_panel.visible = false)
	add_child(_notice_timer)
	_notice_label.set_meta("panel", notice_panel)
	_build_modal(root)
	get_viewport().size_changed.connect(_layout_modal)

func set_district(value: String) -> void:
	if is_instance_valid(_district_label):
		_district_label.text = value

func set_prompt(value: String) -> void:
	if is_instance_valid(_prompt_label):
		_prompt_label.text = value if not value.is_empty() else "沿着街道走走"

func show_notice(value: String) -> void:
	_notice_label.text = value
	var panel: PanelContainer = _notice_label.get_meta("panel")
	panel.visible = true
	_notice_timer.start(3.4)

func set_status(day: int, cash: int, energy: int, item_count: int) -> void:
	if is_instance_valid(_day_label):
		_energy_icon.show()
		_day_label.text = "第 %d 天" % day
		_cash_label.text = "%d 贝" % cash
		_energy_label.text = "精力 %d" % energy
		_collection_label.text = "藏品 %d" % item_count

func set_market_clock(day: int, cash: int, clock_minutes: int, period: String, item_count: int) -> void:
	if not is_instance_valid(_day_label):
		return
	_energy_icon.hide()
	_day_label.text = "第 %d 天" % day
	_cash_label.text = "%d 贝" % cash
	var period_name: String = str({"morning": "早市", "lunch": "午市", "evening": "晚市"}.get(period, "营业"))
	_energy_label.text = "%02d:%02d %s" % [int(clock_minutes / 60), clock_minutes % 60, period_name]
	_collection_label.text = "藏品 %d" % item_count

func set_field_task(activity: String, action: String, progress: String = "", seconds_left: float = -1.0) -> void:
	_field_task_active = not action.is_empty()
	if not _field_task_active:
		clear_field_task()
		return
	_field_task_activity.text = activity
	_field_task_action.text = action
	var parts: Array[String] = []
	if not progress.is_empty():
		parts.append(progress)
	if seconds_left >= 0.0:
		parts.append("%d 秒" % ceili(seconds_left))
	_field_task_progress.text = "  ·  ".join(parts)
	_field_task_panel.visible = not is_modal_open()

func clear_field_task() -> void:
	_field_task_active = false
	if is_instance_valid(_field_task_panel):
		_field_task_panel.visible = false

func show_choices(title: String, description: String, choices: Array[Dictionary], callback: Callable) -> void:
	_choice_callback = callback
	_is_overview = title == "湾区总览"
	_modal_header_icon.texture = _svg_texture(MAP_FOLD_ICON if _is_overview else INTERACT_TOUCH_ICON)
	_modal_title.text = title
	_modal_description.text = description
	_modal_choices.columns = 3 if _is_overview else 1
	for child in _modal_choices.get_children():
		_modal_choices.remove_child(child)
		child.queue_free()
	_modal_footer.visible = false
	for option in choices:
		var choice_id := str(option.get("id", ""))
		if _is_overview and choice_id == "close":
			_modal_footer.text = str(option.get("text", "返回街道"))
			_modal_footer.visible = true
			continue
		var button := Button.new()
		button.text = str(option.get("text", "继续"))
		button.custom_minimum_size = Vector2(188 if _is_overview else 432, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		_style_button(button, _is_overview)
		button.pressed.connect(_on_choice.bind(choice_id))
		_modal_choices.add_child(button)
	_layout_ticket += 1
	_modal.modulate.a = 0.0
	_layout_modal()
	_modal.visible = true
	_field_task_panel.visible = false
	_settle_modal_layout(_layout_ticket)

func set_modal_description(value: String) -> void:
	if is_instance_valid(_modal_description):
		_modal_description.text = value

func is_modal_open() -> bool:
	return is_instance_valid(_modal) and _modal.visible

func close_modal() -> void:
	_layout_ticket += 1
	if is_instance_valid(_modal):
		_modal.visible = false
		_modal.modulate.a = 1.0
	_choice_callback = Callable()
	_is_overview = false
	if is_instance_valid(_field_task_panel):
		_field_task_panel.visible = _field_task_active

func _on_choice(choice_id: String) -> void:
	var callback := _choice_callback
	if callback.is_valid():
		callback.call(choice_id)

func _build_field_task(root: Control) -> void:
	_field_task_panel = _panel(Color(0.98, 0.96, 0.89, 0.9), Color("#8eafa2"))
	_field_task_panel.name = "FieldTaskHint"
	_field_task_panel.anchor_left = 1.0
	_field_task_panel.anchor_right = 1.0
	_field_task_panel.offset_left = -368
	_field_task_panel.offset_right = -28
	_field_task_panel.offset_top = 82
	_field_task_panel.offset_bottom = 150
	root.add_child(_field_task_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	_field_task_panel.add_child(_margin(body, 12, 7))
	var heading := _row(7)
	heading.add_child(_icon(INTERACT_TOUCH_ICON, 20))
	_field_task_activity = _label("", 13, Color("#56766e"))
	_field_task_activity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_field_task_activity)
	_field_task_progress = _label("", 13, Color("#856b52"))
	heading.add_child(_field_task_progress)
	body.add_child(heading)
	_field_task_action = _label("", 17, Color("#355b58"))
	_field_task_action.clip_text = true
	body.add_child(_field_task_action)
	_field_task_panel.visible = false

func _build_modal(root: Control) -> void:
	_modal = _panel(Color("#fff4df"), Color("#ab8069"))
	_modal.name = "CityActionCard"
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style := _modal.get_theme_stylebox("panel") as StyleBoxFlat
	card_style.shadow_color = Color(0.22, 0.28, 0.25, 0.22)
	card_style.shadow_size = 12
	_modal.custom_minimum_size = Vector2(520, 250)
	root.add_child(_modal)
	var margin := _margin(VBoxContainer.new(), 22, 18)
	_modal.add_child(margin)
	var body := margin.get_child(0) as VBoxContainer
	body.add_theme_constant_override("separation", 10)
	var header := _row(10)
	_modal_header_icon = _icon(INTERACT_TOUCH_ICON, 31)
	header.add_child(_modal_header_icon)
	_modal_title = _label("", 24, Color("#315a56"))
	header.add_child(_modal_title)
	body.add_child(header)
	_modal_description = _label("", 16, Color("#59635b"))
	_modal_description.custom_minimum_size.y = 64
	_modal_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_modal_description)
	_choice_scroll = ScrollContainer.new()
	_choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(_choice_scroll)
	_modal_choices = GridContainer.new()
	_modal_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_choices.add_theme_constant_override("h_separation", 8)
	_modal_choices.add_theme_constant_override("v_separation", 8)
	_choice_scroll.add_child(_modal_choices)
	_modal_footer = Button.new()
	_modal_footer.custom_minimum_size.y = 44
	_modal_footer.pressed.connect(_on_choice.bind("close"))
	_style_button(_modal_footer, false)
	body.add_child(_modal_footer)
	_modal_footer.visible = false
	_modal.visible = false
	_layout_modal()

func _layout_modal() -> void:
	if not is_instance_valid(_modal):
		return
	var screen := get_viewport().get_visible_rect().size
	var width := minf(650.0 if _is_overview else 520.0, screen.x - 48.0)
	var visible_options := _modal_choices.get_child_count()
	var rows := ceili(float(visible_options) / float(_modal_choices.columns))
	var list_height := minf(float(rows * 48 + maxi(rows - 1, 0) * 8),
		260.0 if _is_overview else 320.0)
	_choice_scroll.custom_minimum_size.y = maxf(48.0, list_height)
	var height := minf(screen.y - 64.0,
		maxf(250.0, 175.0 + list_height + (54.0 if _is_overview else 0.0)))
	_modal.custom_minimum_size = Vector2(width, height)
	_modal.size = Vector2(width, height)
	_modal.position = Vector2(screen.x - width - 28.0 if _is_overview else (screen.x - width) * 0.5,
		(screen.y - height) * 0.5)

func _settle_modal_layout(ticket: int) -> void:
	await get_tree().process_frame
	if ticket != _layout_ticket or not is_instance_valid(_modal):
		return
	_layout_modal()
	await get_tree().process_frame
	if ticket != _layout_ticket or not is_instance_valid(_modal):
		return
	_layout_modal()
	_modal.modulate.a = 1.0

func _style_button(button: Button, city: bool) -> void:
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#355b58"))
	button.add_theme_color_override("font_hover_color", Color("#204b48"))
	button.add_theme_color_override("font_pressed_color", Color("#fff7e8"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#edf5e8" if city else "#f5e8d2")
		if state == "hover":
			style.bg_color = Color("#d9ecdd" if city else "#e9d5b8")
		elif state == "pressed":
			style.bg_color = Color("#40786d")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
		style.border_color = Color("#a6c1ac" if city else "#ccae89")
		style.set_border_width_all(1 if state != "focus" else 0)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state, style)

func _label(value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _icon(path: String, edge: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = _svg_texture(path)
	icon.custom_minimum_size = Vector2(edge, edge)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _svg_texture(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path] as Texture2D
	var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
	if texture == null:
		push_error("Failed to render city HUD icon: %s" % path)
		return null
	_icon_cache[path] = texture
	return texture

func _row(separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	return row

func _panel(fill: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _margin(content: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	margin.add_child(content)
	return margin
