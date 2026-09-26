class_name MainMenu
extends CanvasLayer

signal new_game_requested
signal continue_requested

const BackdropScript := preload("res://scripts/ui/title_backdrop.gd")
var _root: Control
var _settings_panel: PanelContainer
var _continue_button: Button

func _ready() -> void:
	layer = 30
	_build_interface()

func _build_interface() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var backdrop: TitleBackdrop = BackdropScript.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	_root.theme = theme
	var content := VBoxContainer.new()
	content.position = Vector2(90, 115)
	content.size = Vector2(470, 520)
	content.add_theme_constant_override("separation", 12)
	_root.add_child(content)
	var title := Label.new()
	title.text = "深城日常"
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color("#f1d08b"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "没有强制主线，没有数值面板。\n在城中村把日子慢慢过起来。"
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", Color("#bcd7d0"))
	content.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	content.add_child(spacer)
	var new_button := _make_menu_button("开始新生活")
	new_button.pressed.connect(func() -> void: new_game_requested.emit())
	content.add_child(new_button)
	_continue_button = _make_menu_button("继续上次生活")
	_continue_button.disabled = not SaveManager.has_save()
	_continue_button.pressed.connect(func() -> void:
		if SaveManager.load_game(false):
			continue_requested.emit()
	)
	content.add_child(_continue_button)
	var settings_button := _make_menu_button("设置")
	settings_button.pressed.connect(open_settings)
	content.add_child(settings_button)
	var quit_button := _make_menu_button("离开游戏")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	content.add_child(quit_button)
	var version := Label.new()
	version.text = "旧城经营版 0.2.0  ·  Godot 4.7.2"
	version.position = Vector2(24, 670)
	version.add_theme_color_override("font_color", Color(0.66, 0.75, 0.73, 0.8))
	_root.add_child(version)
	_build_settings_panel()

func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(330, 56)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 22)
	return button

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
	hint.text = "背包、地图和账本打开时，时间仍会继续。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#a8c4be"))
	column.add_child(hint)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(0, 50)
	back.pressed.connect(func() -> void: _settings_panel.visible = false)
	column.add_child(back)

func open_settings() -> void:
	_settings_panel.visible = true

func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.085, 0.98)
	style.border_color = Color(0.96, 0.77, 0.35, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)