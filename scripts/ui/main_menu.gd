class_name MainMenu
extends CanvasLayer

signal city_preview_requested
signal gallery_requested

var _root: Control
var _settings_panel: PanelContainer
var _settings_back_button: Button

func _ready() -> void:
	layer = 30
	NoticeManager.clear_all()
	_build_interface()

func _build_interface() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var background := ColorRect.new()
	background.color = Color("#E8EFEB")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)
	var accent := ColorRect.new()
	accent.color = Color("#DEB96D")
	accent.position = Vector2(83, 100)
	accent.size = Vector2(65, 5)
	_root.add_child(accent)
	var artwork_frame := PanelContainer.new()
	artwork_frame.position = Vector2(594, 78)
	artwork_frame.size = Vector2(608, 546)
	artwork_frame.clip_contents = true
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#D8E4DE")
	frame_style.border_color = Color("#A6C4B9")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(18)
	frame_style.shadow_color = Color(0.19, 0.32, 0.30, 0.16)
	frame_style.shadow_size = 12
	artwork_frame.add_theme_stylebox_override("panel", frame_style)
	_root.add_child(artwork_frame)
	var artwork := TextureRect.new()
	artwork.texture = load("res://assets/art/models/sz_park_bookbar_cafe_preview.png")
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork_frame.add_child(artwork)
	_root.theme = PresentationManager.build_ui_theme()
	var content := VBoxContainer.new()
	content.position = Vector2(83, 125)
	content.size = Vector2(460, 480)
	content.add_theme_constant_override("separation", 12)
	_root.add_child(content)
	var title := Label.new()
	title.text = "深城日常"
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color("#35645F"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "湖畔餐馆 · 独立试玩\n备料、出餐、迎接早午晚三轮客流。"
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", Color("#59746E"))
	content.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	content.add_child(spacer)
	var city_button := _make_menu_button("进入餐馆 · 继续营业")
	city_button.pressed.connect(func() -> void: city_preview_requested.emit())
	content.add_child(city_button)
	var gallery_button := _make_menu_button("查看已完成素材")
	gallery_button.pressed.connect(func() -> void: gallery_requested.emit())
	content.add_child(gallery_button)
	var settings_button := _make_menu_button("设置")
	settings_button.pressed.connect(open_settings)
	content.add_child(settings_button)
	var quit_button := _make_menu_button("离开游戏")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	content.add_child(quit_button)
	var version := Label.new()
	version.text = "湖畔餐馆 · 独立试玩版"
	version.position = Vector2(24, 670)
	version.add_theme_color_override("font_color", Color("#5A7773"))
	_root.add_child(version)
	_build_settings_panel()

func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(350, 58)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("#2D5C55"))
	button.add_theme_color_override("font_hover_color", Color("#183E38"))
	button.add_theme_color_override("font_pressed_color", Color("#183E38"))
	button.add_theme_color_override("font_focus_color", Color("#183E38"))
	button.add_theme_stylebox_override("normal", _menu_button_style(Color("#FBF9F1"), Color("#A5C5B7")))
	button.add_theme_stylebox_override("hover", _menu_button_style(Color("#E3F1E8"), Color("#58A58C")))
	button.add_theme_stylebox_override("pressed", _menu_button_style(Color("#CDE6DA"), Color("#58A58C")))
	button.add_theme_stylebox_override("focus", _menu_button_style(Color(0, 0, 0, 0), Color("#C58E38")))
	return button

func _menu_button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.anchor_left = 0.5
	_settings_panel.anchor_right = 0.5
	_settings_panel.anchor_top = 0.5
	_settings_panel.anchor_bottom = 0.5
	_settings_panel.offset_left = -260
	_settings_panel.offset_right = 260
	_settings_panel.offset_top = -180
	_settings_panel.offset_bottom = 180
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.visible = false
	_style_panel(_settings_panel)
	_root.add_child(_settings_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_settings_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#f1d08b"))
	column.add_child(title)
	var fullscreen := CheckBox.new()
	fullscreen.text = "全屏显示"
	fullscreen.button_pressed = SettingsManager.fullscreen
	fullscreen.toggled.connect(SettingsManager.set_fullscreen)
	column.add_child(fullscreen)
	var resolution_label := Label.new()
	resolution_label.text = "窗口大小"
	column.add_child(resolution_label)
	var resolution := OptionButton.new()
	for index in range(SettingsManager.get_window_presets().size()):
		resolution.add_item(SettingsManager.get_window_preset_label(index), index)
	resolution.selected = SettingsManager.window_preset_index
	resolution.item_selected.connect(func(index: int) -> void: SettingsManager.set_window_preset(index))
	column.add_child(resolution)
	var volume_label := Label.new()
	volume_label.text = "声音大小"
	column.add_child(volume_label)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = SettingsManager.master_volume
	volume.value_changed.connect(SettingsManager.set_master_volume)
	column.add_child(volume)
	var hint := Label.new()
	hint.text = "进入餐馆后按 Esc 返回此界面；F2 可查看已完成素材。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", PresentationManager.get_color("color.text.muted", Color("#A89684")))
	column.add_child(hint)
	_settings_back_button = Button.new()
	_settings_back_button.text = "返回"
	_settings_back_button.custom_minimum_size = Vector2(0, 50)
	_settings_back_button.theme_type_variation = "GhostButton"
	_settings_back_button.pressed.connect(_close_settings)
	column.add_child(_settings_back_button)

func open_settings() -> void:
	_settings_panel.visible = true
	if is_instance_valid(_settings_back_button):
		_settings_back_button.grab_focus()

func _close_settings() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and _settings_panel.is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	_settings_panel.visible = false

func _is_cancel_event(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_cancel"):
		return false
	return not (event is InputEventKey and event.echo)

func _unhandled_input(event: InputEvent) -> void:
	if _is_cancel_event(event) and _settings_panel.visible:
		_close_settings()
		get_viewport().set_input_as_handled()

func _style_panel(panel: PanelContainer) -> void:
	panel.theme_type_variation = "SoftPanel"
