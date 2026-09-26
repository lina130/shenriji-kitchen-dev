class_name GameHUD
extends CanvasLayer

signal modal_changed(is_open: bool)

enum ModalState { NONE, INVENTORY, SHOP, PAUSE }

var _root: Control
var _ambient_overlay: ColorRect
var _status_panel: PanelContainer
var _money_label: Label
var _time_label: Label
var _context_panel: PanelContainer
var _context_label: Label
var _notice_panel: PanelContainer
var _notice_label: Label
var _modal_panel: PanelContainer
var _modal_title: Label
var _modal_subtitle: Label
var _modal_items: VBoxContainer
var _notice_time_left := 0.0
var _clock_accumulator := 0.0
var _modal_state := ModalState.NONE
var _modal_shop_id := ""

func _ready() -> void:
	layer = 20
	add_to_group("hud")
	_build_interface()
	GameState.money_changed.connect(_on_money_changed)
	NoticeManager.notice_requested.connect(show_notice)
	TimeSystem.paused_changed.connect(_on_pause_changed)
	_on_money_changed(GameState.money)
	_update_clock()
	_apply_ambient_state()

func _process(delta: float) -> void:
	_clock_accumulator += delta
	if _clock_accumulator >= 0.2:
		_clock_accumulator = 0.0
		_update_clock()
	_apply_ambient_state()
	if _notice_time_left > 0.0:
		_notice_time_left -= delta
		if _notice_time_left <= 0.0:
			_notice_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if _modal_state == ModalState.SHOP:
			_close_modal()
		elif _modal_state == ModalState.INVENTORY:
			_close_modal()
		else:
			open_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _modal_state != ModalState.NONE:
			_close_modal()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
		return

func set_context_prompt(text: String) -> void:
	_context_label.text = text
	_context_panel.visible = not text.is_empty() and _modal_state == ModalState.NONE

func show_notice(message: String, tone: String = "normal") -> void:
	if message.is_empty():
		return
	_notice_label.text = message
	_notice_label.add_theme_color_override("font_color", _notice_color(tone))
	_notice_panel.visible = true
	_notice_time_left = 2.8

func open_inventory(intro: String = "") -> void:
	_build_inventory_content(intro)
	_set_modal(ModalState.INVENTORY, "随身的包", intro if not intro.is_empty() else "东西都塞在一起，拿起来就能用。")

func open_shop(shop_id: String) -> void:
	_modal_shop_id = shop_id
	_build_shop_content()
	_set_modal(ModalState.SHOP, "街角便利店", "柜台上都写着固定价格。")

func _build_interface() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 19
	_root.theme = theme

	_ambient_overlay = ColorRect.new()
	_ambient_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ambient_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_overlay.color = Color(0.02, 0.05, 0.08, 0.0)
	_root.add_child(_ambient_overlay)

	_status_panel = PanelContainer.new()
	_status_panel.position = Vector2(24, 20)
	_status_panel.size = Vector2(430, 58)
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(_status_panel, Color(0.04, 0.09, 0.11, 0.84), Color(0.56, 0.88, 0.79, 0.32))
	_root.add_child(_status_panel)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 26)
	_status_panel.add_child(status_row)
	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 23)
	_money_label.add_theme_color_override("font_color", Color("#f2cf73"))
	status_row.add_child(_money_label)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 20)
	_time_label.add_theme_color_override("font_color", Color("#d9eee7"))
	status_row.add_child(_time_label)

	_context_panel = PanelContainer.new()
	_context_panel.anchor_left = 0.5
	_context_panel.anchor_right = 0.5
	_context_panel.anchor_top = 1.0
	_context_panel.anchor_bottom = 1.0
	_context_panel.offset_left = -260
	_context_panel.offset_right = 260
	_context_panel.offset_top = -104
	_context_panel.offset_bottom = -48
	_context_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(_context_panel, Color(0.03, 0.07, 0.08, 0.88), Color(1.0, 0.86, 0.45, 0.45))
	_root.add_child(_context_panel)
	_context_label = Label.new()
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context_label.add_theme_color_override("font_color", Color("#ffe8a8"))
	_context_panel.add_child(_context_label)
	_context_panel.visible = false

	_notice_panel = PanelContainer.new()
	_notice_panel.anchor_left = 0.5
	_notice_panel.anchor_right = 0.5
	_notice_panel.anchor_top = 1.0
	_notice_panel.anchor_bottom = 1.0
	_notice_panel.offset_left = -350
	_notice_panel.offset_right = 350
	_notice_panel.offset_top = -172
	_notice_panel.offset_bottom = -118
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(_notice_panel, Color(0.025, 0.055, 0.064, 0.94), Color(0.97, 0.78, 0.35, 0.55))
	_root.add_child(_notice_panel)
	_notice_label = Label.new()
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.add_theme_font_size_override("font_size", 20)
	_notice_panel.add_child(_notice_label)
	_notice_panel.visible = false

	_modal_panel = PanelContainer.new()
	_modal_panel.anchor_left = 0.5
	_modal_panel.anchor_right = 0.5
	_modal_panel.anchor_top = 0.5
	_modal_panel.anchor_bottom = 0.5
	_modal_panel.offset_left = -330
	_modal_panel.offset_right = 330
	_modal_panel.offset_top = -250
	_modal_panel.offset_bottom = 250
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(_modal_panel, Color(0.035, 0.075, 0.085, 0.98), Color(0.96, 0.77, 0.35, 0.7), 18)
	_root.add_child(_modal_panel)

	var modal_margin := MarginContainer.new()
	modal_margin.add_theme_constant_override("margin_left", 26)
	modal_margin.add_theme_constant_override("margin_right", 26)
	modal_margin.add_theme_constant_override("margin_top", 22)
	modal_margin.add_theme_constant_override("margin_bottom", 22)
	_modal_panel.add_child(modal_margin)
	var modal_column := VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 12)
	modal_margin.add_child(modal_column)
	_modal_title = Label.new()
	_modal_title.add_theme_font_size_override("font_size", 30)
	_modal_title.add_theme_color_override("font_color", Color("#f5d895"))
	modal_column.add_child(_modal_title)
	_modal_subtitle = Label.new()
	_modal_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_subtitle.add_theme_color_override("font_color", Color("#afc9c4"))
	modal_column.add_child(_modal_subtitle)
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.75, 0.62, 0.34, 0.38))
	modal_column.add_child(separator)
	_modal_items = VBoxContainer.new()
	_modal_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_items.add_theme_constant_override("separation", 9)
	modal_column.add_child(_modal_items)
	var close_button := Button.new()
	close_button.text = "收起（Esc）"
	close_button.custom_minimum_size = Vector2(0, 46)
	close_button.pressed.connect(_close_modal)
	modal_column.add_child(close_button)

func _build_inventory_content(intro: String) -> void:
	_clear_modal_items()
	var entries := InventoryManager.get_inventory_lines()
	if entries.is_empty():
		_modal_items.add_child(_make_empty_label("包里暂时空着。"))
		return
	for entry in entries:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  ×%d" % [entry["name"], entry["count"]]
		button.tooltip_text = str(entry["description"])
		if bool(entry["usable"]):
			button.pressed.connect(_on_inventory_use.bind(str(entry["id"])))
		else:
			button.disabled = true
		_modal_items.add_child(button)

func _build_shop_content() -> void:
	_clear_modal_items()
	var ids := ["meal_rice", "bread", "water", "coffee"]
	for item_id in ids:
		var item := InventoryManager.get_item(item_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s    ¥%d" % [item.get("name", item_id), int(item.get("price", 0))]
		button.tooltip_text = str(item.get("description", ""))
		button.pressed.connect(_on_shop_buy.bind(item_id))
		_modal_items.add_child(button)
	var hint := _make_empty_label("放进包里就能随身带着。")
	hint.add_theme_color_override("font_color", Color("#9eb8b3"))
	_modal_items.add_child(hint)

func _on_inventory_use(item_id: String) -> void:
	if InventoryManager.use_item(item_id):
		_build_inventory_content("")
		_modal_subtitle.text = "东西都塞在一起，拿起来就能用。"

func _on_shop_buy(item_id: String) -> void:
	var item := InventoryManager.get_item(item_id)
	if item.is_empty():
		return
	var price := int(item.get("price", 0))
	if GameState.spend(price):
		InventoryManager.add_item(item_id, 1)
		show_notice("买到%s，装进包里了。" % item.get("name", item_id), "positive")

func open_pause() -> void:
	_build_pause_content()
	_set_modal(ModalState.PAUSE, "先歇一下", "时间停在这里，外面暂时不会往前走。", true)

func _build_pause_content() -> void:
	_clear_modal_items()
	var resume := Button.new()
	resume.text = "继续生活"
	resume.custom_minimum_size = Vector2(0, 54)
	resume.pressed.connect(_close_modal)
	_modal_items.add_child(resume)
	var save_button := Button.new()
	save_button.text = "保存进度"
	save_button.custom_minimum_size = Vector2(0, 54)
	save_button.pressed.connect(func() -> void: SaveManager.save_game(true))
	_modal_items.add_child(save_button)
	var quit_button := Button.new()
	quit_button.text = "保存并回到桌面"
	quit_button.custom_minimum_size = Vector2(0, 54)
	quit_button.pressed.connect(func() -> void:
		SaveManager.save_game(false)
		get_tree().quit()
	)
	_modal_items.add_child(quit_button)

func _set_modal(state: ModalState, title: String, subtitle: String, pause_clock: bool = false) -> void:
	_modal_state = state
	_modal_title.text = title
	_modal_subtitle.text = subtitle
	_modal_panel.visible = true
	_context_panel.visible = false
	GameState.input_locked = true
	TimeSystem.set_paused(pause_clock)
	modal_changed.emit(true)

func _close_modal() -> void:
	var was_pause := _modal_state == ModalState.PAUSE
	if _modal_state == ModalState.NONE:
		return
	_modal_state = ModalState.NONE
	_modal_shop_id = ""
	_modal_panel.visible = false
	GameState.input_locked = false
	if was_pause:
		TimeSystem.set_paused(false)
	modal_changed.emit(false)
	_clear_modal_items()

func _clear_modal_items() -> void:
	for child in _modal_items.get_children():
		child.queue_free()

func _make_empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#c9d8d4"))
	return label

func _on_money_changed(amount: int) -> void:
	_money_label.text = "¥ %d" % amount

func _update_clock() -> void:
	_time_label.text = "%s · %s" % [TimeSystem.get_day_name(), TimeSystem.get_time_text()]

func _apply_ambient_state() -> void:
	var sleep_dim := GameState.get_visual_dim() * 0.46
	var night_dim := (1.0 - TimeSystem.get_daylight()) * 0.22
	_ambient_overlay.color = Color(0.025, 0.06, 0.09, clampf(sleep_dim + night_dim, 0.0, 0.58))

func _on_pause_changed(is_paused: bool) -> void:
	if is_paused:
		_context_panel.visible = false
	elif not _context_label.text.is_empty():
		_context_panel.visible = true

func _notice_color(tone: String) -> Color:
	match tone:
		"positive":
			return Color("#a9e4b4")
		"warning":
			return Color("#ffc076")
		"hint":
			return Color("#a9d7df")
		_:
			return Color("#f4e4bd")

func _style_panel(panel: PanelContainer, background: Color, border: Color, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)