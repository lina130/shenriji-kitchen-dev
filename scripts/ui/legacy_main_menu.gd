extends CanvasLayer

signal new_game_requested
signal continue_requested

const BackdropScript := preload("res://scripts/ui/title_backdrop.gd")


func _ready() -> void:
	layer = 30
	NoticeManager.clear_all()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = PresentationManager.build_ui_theme()
	add_child(root)
	var backdrop: TitleBackdrop = BackdropScript.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var content := VBoxContainer.new()
	content.position = Vector2(94, 132)
	content.size = Vector2(525, 470)
	content.add_theme_constant_override("separation", 15)
	root.add_child(content)
	var title := Label.new()
	title.text = "深城日常 · 旧版 2D"
	title.add_theme_font_size_override("font_size", 49)
	title.add_theme_color_override("font_color", Color("#E8BE7A"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "原街巷生活版本 · 使用独立的旧版存档"
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_color", Color("#BCD2CF"))
	content.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	content.add_child(gap)
	var new_button := _button("开始旧版新游戏")
	new_button.pressed.connect(func() -> void: new_game_requested.emit())
	content.add_child(new_button)
	var continue_button := _button("继续旧版存档")
	continue_button.disabled = not SaveManager.has_save()
	continue_button.pressed.connect(func() -> void:
		if SaveManager.load_game(false):
			continue_requested.emit()
	)
	content.add_child(continue_button)
	var quit_button := _button("退出")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	content.add_child(quit_button)


func _button(label: String) -> Button:
	var result := Button.new()
	result.text = label
	result.custom_minimum_size = Vector2(350, 56)
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_size_override("font_size", 21)
	result.theme_type_variation = "PrimaryButton"
	return result
