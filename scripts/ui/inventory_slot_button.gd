class_name InventorySlotButton
extends Button

signal move_requested(from_scope: String, from_index: int, to_scope: String, to_index: int)
signal stack_transfer_requested(scope: String, index: int, mode: String)

var scope := ""
var slot_index := -1
var item_id := ""
var item_count := 0

func _ready() -> void:
	var texture := PresentationManager.get_ui_texture("slot.normal")
	if texture == null:
		return
	var normal := StyleBoxTexture.new()
	normal.texture = texture
	normal.texture_margin_left = 14
	normal.texture_margin_right = 14
	normal.texture_margin_top = 14
	normal.texture_margin_bottom = 14
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 5.0
	normal.content_margin_bottom = 5.0
	add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate(true) as StyleBoxTexture
	hover.modulate_color = Color(1.12, 1.08, 0.92, 1.0)
	add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate(true) as StyleBoxTexture
	pressed.modulate_color = Color(0.82, 0.86, 0.84, 1.0)
	add_theme_stylebox_override("pressed", pressed)

func configure(new_scope: String, new_index: int, slot: Dictionary) -> void:
	scope = new_scope
	slot_index = new_index
	item_id = str(slot.get("item_id", slot.get("id", "")))
	item_count = int(slot.get("count", 0))
	disabled = false
	focus_mode = Control.FOCUS_NONE
	if item_id.is_empty() or item_count <= 0:
		text = "空"
		tooltip_text = "空位 · 可以把物品拖到这里"
		modulate = Color(0.82, 0.86, 0.84, 0.78)
		return
	text = "%s\n×%d" % [str(slot.get("name", item_id)), item_count]
	var hint := str(slot.get("use_hint", slot.get("description", "")))
	tooltip_text = "%s\n%s\n拖动整理；右键拆半，Shift+右键整叠转移，Ctrl+右键转移 1 件" % [str(slot.get("name", item_id)), hint]
	modulate = Color.WHITE

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or item_count <= 0:
		return null
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(104, 48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.12, 0.13, 0.96)
	style.border_color = Color(0.95, 0.78, 0.38, 0.78)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	preview.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "%s ×%d" % [str(tooltip_text.get_slice("\n", 0)), item_count]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#ffe7a6"))
	preview.add_child(label)
	set_drag_preview(preview)
	return {"scope": scope, "index": slot_index, "item_id": item_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return not str(data.get("scope", "")).is_empty() and int(data.get("index", -1)) >= 0

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	move_requested.emit(str(data.get("scope", "")), int(data.get("index", -1)), scope, slot_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var mode := "half"
		if event.shift_pressed:
			mode = "whole"
		elif event.ctrl_pressed:
			mode = "one"
		stack_transfer_requested.emit(scope, slot_index, mode)
		accept_event()
