extends Node

## 美术重构前的表现层接口：场景、角色、物品、UI、字体都通过稳定键访问。

var _bindings: Dictionary = {}
var _texture_cache: Dictionary = {}

func _ready() -> void:
	_rebuild_bindings()

func _rebuild_bindings() -> void:
	_bindings.clear()
	for binding_id in ConfigDB.get_rows("visual_bindings"):
		var row := ConfigDB.get_row("visual_bindings", binding_id)
		var binding_type := str(row.get("binding_type", "misc"))
		var key := "%s:%s" % [binding_type, binding_id]
		_bindings[key] = row.duplicate(true)

func get_binding(binding_type: String, binding_id: String) -> Dictionary:
	return _bindings.get("%s:%s" % [binding_type, binding_id], {})

func get_sprite_key(binding_type: String, binding_id: String) -> String:
	return str(get_binding(binding_type, binding_id).get("sprite_key", ""))

func get_portrait_key(npc_id: String) -> String:
	return str(get_binding("npc", npc_id).get("portrait_key", ""))

func get_icon_key(binding_type: String, binding_id: String) -> String:
	return str(get_binding(binding_type, binding_id).get("icon_key", ""))

func get_font_role(binding_type: String, binding_id: String) -> String:
	return str(get_binding(binding_type, binding_id).get("font_role", "font.body"))

func get_scene_metadata(area_id: String) -> Dictionary:
	return ConfigDB.get_row("scene_metadata", area_id)

func get_scene_background_key(area_id: String) -> String:
	return str(get_scene_metadata(area_id).get("background_key", "scene.%s.background" % area_id))

func get_scene_music_key(area_id: String) -> String:
	return str(get_scene_metadata(area_id).get("music_key", "day_ambient"))

func get_scene_accent(area_id: String, fallback: Color = Color.WHITE) -> Color:
	return Color.from_string(str(get_scene_metadata(area_id).get("ui_accent", "")), fallback)

func get_token(token: String, fallback: String = "") -> String:
	return str(ConfigDB.get_row("theme_tokens", token).get("value", fallback))

func get_color(token: String, fallback: Color = Color.WHITE) -> Color:
	return Color.from_string(get_token(token, ""), fallback)

func get_font_names(font_role: String = "font.body") -> PackedStringArray:
	var raw := get_token(font_role, "Microsoft YaHei UI")
	var names := PackedStringArray()
	for part in raw.split(",", false):
		names.append(part.strip_edges())
	names.append("Noto Sans CJK SC")
	names.append("sans-serif")
	return names

func get_scene_texture(area_id: String) -> Texture2D:
	return _load_texture("res://assets/art/scenes/%s/background.png" % area_id)

func get_npc_world_texture(npc_id: String) -> Texture2D:
	return _load_texture("res://assets/art/characters/%s/world.png" % npc_id)

func get_npc_world_frames(npc_id: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for frame in range(1, 5):
		var texture := _load_texture("res://assets/art/characters/%s/world_%d.png" % [npc_id, frame])
		if texture != null:
			result.append(texture)
	if result.is_empty():
		var fallback := get_npc_world_texture(npc_id)
		if fallback != null:
			result.append(fallback)
	return result

func get_npc_action_frames(npc_id: String, action: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for frame in range(1, 5):
		var texture := _load_texture("res://assets/art/characters/%s/actions/%s_%d.png" % [npc_id, action, frame])
		if texture != null:
			result.append(texture)
	if result.is_empty():
		return get_npc_world_frames(npc_id)
	return result

func get_npc_portrait_texture(npc_id: String, expression: String = "neutral") -> Texture2D:
	var path := "res://assets/art/characters/%s/portrait_%s.png" % [npc_id, expression] if expression != "neutral" else "res://assets/art/characters/%s/portrait.png" % npc_id
	var portrait := _load_texture(path)
	if portrait == null:
		portrait = _load_texture("res://assets/art/characters/%s/portrait.png" % npc_id)
	return portrait

func get_item_icon_texture(item_id: String) -> Texture2D:
	return _load_texture("res://assets/art/items/%s/icon.png" % item_id)

func get_ui_asset(asset_id: String) -> Dictionary:
	return ConfigDB.get_row("ui_assets", asset_id)

func get_ui_texture(binding_id: String) -> Texture2D:
	var asset := get_ui_asset(binding_id)
	if not asset.is_empty():
		var path := str(asset.get("path", ""))
		if not path.is_empty():
			var texture := _load_texture(path)
			if texture != null:
				return texture
		var fallback := str(asset.get("fallback_asset_id", ""))
		if not fallback.is_empty() and fallback != binding_id:
			return get_ui_texture(fallback)
	return _load_texture("res://assets/art/ui/%s.png" % binding_id)

func get_text_style(style_id: String) -> Dictionary:
	return ConfigDB.get_row("ui_text_styles", style_id)

func apply_text_style(control: Control, style_id: String) -> void:
	var style := get_text_style(style_id)
	if style.is_empty():
		return
	var font_role := str(style.get("font_role", "font.body"))
	var font := SystemFont.new()
	font.font_names = get_font_names(font_role)
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", int(style.get("font_size", "18")))
	control.add_theme_color_override("font_color", get_color(str(style.get("color_token", "color.text.primary")), Color("#4A3B2E")))

func _stylebox_from_asset(asset_id: String, fallback_color: Color, border_color: Color) -> StyleBox:
	var texture := get_ui_texture(asset_id)
	if texture != null:
		var style := StyleBoxTexture.new()
		style.texture = texture
		var asset := get_ui_asset(asset_id)
		var slice := int(asset.get("slice", "14"))
		style.texture_margin_left = slice
		style.texture_margin_right = slice
		style.texture_margin_top = slice
		style.texture_margin_bottom = slice
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		return style
	var flat := StyleBoxFlat.new()
	flat.bg_color = fallback_color
	flat.border_color = border_color
	flat.set_border_width_all(1)
	flat.set_corner_radius_all(int(get_token("radius.button", "10")))
	flat.content_margin_left = 16.0
	flat.content_margin_right = 16.0
	flat.content_margin_top = 8.0
	flat.content_margin_bottom = 8.0
	return flat

func build_ui_theme() -> Theme:
	var theme := Theme.new()
	var body_font := SystemFont.new()
	body_font.font_names = get_font_names("font.body")
	var title_font := SystemFont.new()
	title_font.font_names = get_font_names("font.title")
	var numeric_font := SystemFont.new()
	numeric_font.font_names = get_font_names("font.numeric")
	theme.default_font = body_font
	theme.default_font_size = int(get_token("size.body", "18"))
	theme.set_font("font", "Label", body_font)
	theme.set_font("font", "Button", body_font)
	theme.set_font("font", "PanelContainer", body_font)
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", title_font)
	theme.set_font_size("font_size", "TitleLabel", int(get_token("size.title", "30")))
	theme.set_type_variation("NumericLabel", "Label")
	theme.set_font("font", "NumericLabel", numeric_font)
	var panel_color := get_color("color.bg.panel", Color(0.96, 0.91, 0.84, 0.90))
	var border_color := get_color("color.border.soft", Color(0.85, 0.77, 0.66))
	for variation in ["PrimaryButton", "GhostButton"]:
		theme.set_type_variation(variation, "Button")
		theme.set_stylebox("normal", variation, _stylebox_from_asset("button.primary.normal", panel_color, border_color))
		theme.set_stylebox("hover", variation, _stylebox_from_asset("button.primary.hover", panel_color.lightened(0.05), border_color))
		theme.set_stylebox("pressed", variation, _stylebox_from_asset("button.primary.pressed", panel_color.darkened(0.08), border_color))
		theme.set_stylebox("disabled", variation, _stylebox_from_asset("button.primary.disabled", panel_color.darkened(0.05).lerp(Color(0.6, 0.6, 0.6), 0.35), border_color))
	theme.set_type_variation("SoftPanel", "PanelContainer")
	theme.set_stylebox("panel", "SoftPanel", _stylebox_from_asset("panel.paper", panel_color, border_color))
	theme.set_type_variation("DialogPanel", "PanelContainer")
	theme.set_stylebox("panel", "DialogPanel", _stylebox_from_asset("panel.dialog", panel_color, border_color))
	return theme

func find_npc_id_by_name(display_name: String) -> String:
	for npc_id in ConfigDB.get_rows("npcs"):
		if str(ConfigDB.get_row("npcs", npc_id).get("name", "")) == display_name:
			return str(npc_id)
	for candidate_id in ConfigDB.get_rows("staff_candidates"):
		if str(ConfigDB.get_row("staff_candidates", candidate_id).get("name", "")) == display_name:
			return str(candidate_id)
	return ""

func _load_texture(path: String) -> Texture2D:
	var resolved_path := get_resolved_asset_path(path)
	if _texture_cache.has(resolved_path):
		return _texture_cache[resolved_path]
	if not ResourceLoader.exists(resolved_path):
		return null
	var texture := load(resolved_path) as Texture2D
	_texture_cache[resolved_path] = texture
	return texture

## 正式美术放在 assets/art/formal 下即可覆盖程序化基线；业务代码继续使用稳定 key。
func get_resolved_asset_path(path: String) -> String:
	var override_path := _formal_override_path(path)
	if not override_path.is_empty() and ResourceLoader.exists(override_path):
		return override_path
	return path

func _formal_override_path(path: String) -> String:
	const PREFIX := "res://assets/art/"
	if not path.begins_with(PREFIX):
		return ""
	return "res://assets/art/formal/" + path.trim_prefix(PREFIX)

func get_font_size(token: String, fallback: int) -> int:
	return int(get_token(token, str(fallback)))
