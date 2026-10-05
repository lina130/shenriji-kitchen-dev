extends Node

## 出租屋装扮：家具可手动放到具体位置，也支持保存多套搭配。

signal changed

const SLOT_NAMES := {
	"bed": "床铺位",
	"light": "灯光位",
	"rug": "地面位",
	"rug_alt": "窗边位",
	"shelf": "墙架位",
	"plant": "绿植位",
	"table": "饭桌位",
	"appliance": "电器位",
	"aquarium": "水景位",
	"pet": "宠物角",
	"desk": "书桌位",
}

var owned: Dictionary = {}
var placed: Dictionary = {}
var layouts: Dictionary = {}
var active_layout := "日常"
var installed_decor: Dictionary = {}
var manual_positions: Dictionary = {}
var manual_rotations: Dictionary = {}
var renovation_style := ""

func _ready() -> void:
	reset_new_game()

func reset_new_game() -> void:
	owned.clear()
	placed.clear()
	installed_decor.clear()
	manual_positions.clear()
	manual_rotations.clear()
	renovation_style = ""
	layouts = {
		"日常": {},
		"会客": {},
		"宠物角": {},
	}
	active_layout = "日常"
	changed.emit()

func has_owned(fid: String) -> bool:
	return bool(owned.get(fid, false))

func is_placed(fid: String) -> bool:
	return not get_slot_for(fid).is_empty()

func get_slot_for(fid: String) -> String:
	for slot_id in placed:
		if str(placed[slot_id]) == fid:
			return str(slot_id)
	return ""

func auto_place(fid: String) -> void:
	if not has_owned(fid):
		return
	var row := ConfigDB.get_row("furniture", fid)
	var slot_id := str(row.get("category", "misc"))
	place_at(fid, slot_id, false)

func place_at(fid: String, slot_id: String, save_now: bool = true) -> bool:
	if not has_owned(fid):
		NoticeManager.show_message("还没有这件家具，先去家居超市看看。", "warning")
		return false
	for existing_slot in placed.keys():
		if str(placed[existing_slot]) == fid:
			placed.erase(existing_slot)
	placed[slot_id] = fid
	if not manual_positions.has(fid):
		manual_positions[fid] = get_default_slot_position(slot_id)
	manual_rotations[fid] = int(manual_rotations.get(fid, 0))
	if save_now:
		_save_active_layout()
		var nm := str(ConfigDB.get_row("furniture", fid).get("name", fid))
		NoticeManager.show_message("%s摆到了%s。" % [nm, get_slot_name(slot_id)], "positive")
		SaveManager.request_auto_save("furniture_place")
	changed.emit()
	return true

func place(fid: String) -> bool:
	return place_at(fid, str(ConfigDB.get_row("furniture", fid).get("category", "misc")), true)

func unplace(fid: String) -> bool:
	var slot_id := get_slot_for(fid)
	if slot_id.is_empty():
		return false
	placed.erase(slot_id)
	manual_positions.erase(fid)
	manual_rotations.erase(fid)
	_save_active_layout()
	SaveManager.request_auto_save("furniture_unplace")
	changed.emit()
	return true

func buy(fid: String) -> bool:
	var row := ConfigDB.get_row("furniture", fid)
	if row.is_empty() or has_owned(fid):
		NoticeManager.show_message("这件家具已经买过了。", "hint")
		return false
	var price := int(row.get("price", "0"))
	var nm := str(row.get("name", fid))
	if not GameState.spend(price, "买下%s，搬回出租屋。" % nm):
		return false
	owned[fid] = true
	auto_place(fid)
	_save_active_layout()
	NoticeManager.show_message("买下%s并先放进房间，之后可以手动挪位置。" % nm, "positive")
	SaveManager.request_auto_save("furniture_buy")
	changed.emit()
	return true

func nudge_furniture(fid: String, delta: Vector2) -> bool:
	if not is_placed(fid):
		return false
	var current := get_furniture_position(fid)
	manual_positions[fid] = Vector2(clampf(current.x + delta.x, 0.06, 0.94), clampf(current.y + delta.y, 0.08, 0.92))
	_save_active_layout()
	SaveManager.request_auto_save("furniture_move")
	changed.emit()
	return true

func rotate_furniture(fid: String, degrees: int = 15) -> bool:
	if not is_placed(fid):
		return false
	manual_rotations[fid] = posmod(int(manual_rotations.get(fid, 0)) + degrees, 360)
	_save_active_layout()
	SaveManager.request_auto_save("furniture_rotate")
	changed.emit()
	return true

func get_default_slot_position(slot_id: String) -> Vector2:
	match slot_id:
		"bed": return Vector2(0.22, 0.34)
		"light": return Vector2(0.78, 0.24)
		"rug", "rug_alt": return Vector2(0.52, 0.62)
		"shelf": return Vector2(0.75, 0.36)
		"plant": return Vector2(0.86, 0.66)
		"table": return Vector2(0.48, 0.48)
		"appliance": return Vector2(0.24, 0.72)
		"aquarium": return Vector2(0.68, 0.20)
		"pet": return Vector2(0.70, 0.80)
		"desk": return Vector2(0.42, 0.20)
	return Vector2(0.5, 0.5)

func get_furniture_for_slot(slot_id: String) -> String:
	return str(placed.get(slot_id, ""))

func get_owned_for_slot(slot_id: String) -> Array[String]:
	var result: Array[String] = []
	for fid in owned:
		var row := ConfigDB.get_row("furniture", str(fid))
		var category := str(row.get("category", ""))
		if category == slot_id or (slot_id == "rug_alt" and category == "rug"):
			result.append(str(fid))
	return result

func set_furniture_position(fid: String, position: Vector2) -> bool:
	if not is_placed(fid):
		return false
	manual_positions[fid] = Vector2(clampf(position.x, 0.06, 0.94), clampf(position.y, 0.08, 0.92))
	_save_active_layout()
	SaveManager.request_auto_save("furniture_move")
	changed.emit()
	return true

func cycle_slot_furniture(slot_id: String) -> String:
	var candidates := get_owned_for_slot(slot_id)
	if candidates.is_empty():
		return ""
	var current := get_furniture_for_slot(slot_id)
	var current_index := candidates.find(current)
	var next_index := 0 if current_index < 0 else (current_index + 1) % candidates.size()
	var next_id := candidates[next_index]
	place_at(next_id, slot_id)
	return next_id

func get_furniture_position(fid: String) -> Vector2:
	if manual_positions.has(fid):
		return manual_positions[fid]
	var slot_id := get_slot_for(fid)
	if slot_id.is_empty():
		return Vector2.ZERO
	return get_default_slot_position(slot_id)

func get_furniture_rotation(fid: String) -> int:
	return int(manual_rotations.get(fid, 0))

func _ensure_manual_layout() -> void:
	for slot_id in placed:
		var fid := str(placed[slot_id])
		if not manual_positions.has(fid):
			manual_positions[fid] = get_default_slot_position(str(slot_id))
		if not manual_rotations.has(fid):
			manual_rotations[fid] = 0

func _save_active_layout(layout_name: String = "") -> void:
	var target_layout := active_layout if layout_name.is_empty() else layout_name
	layouts[target_layout] = {
		"placed": placed.duplicate(true),
		"positions": manual_positions.duplicate(true),
		"rotations": manual_rotations.duplicate(true),
	}

func save_layout(name: String = "") -> bool:
	var layout_name := active_layout if name.is_empty() else name.strip_edges()
	if layout_name.is_empty():
		return false
	_save_active_layout(layout_name)
	SaveManager.request_auto_save("layout_save")
	NoticeManager.show_message("已保存“%s”这套布置。" % layout_name, "positive")
	changed.emit()
	return true

func load_layout(name: String) -> bool:
	if not layouts.has(name):
		NoticeManager.show_message("还没有保存过这套布置。", "warning")
		return false
	active_layout = name
	_apply_layout_data(layouts[name])
	SaveManager.request_auto_save("layout_load")
	NoticeManager.show_message("换成了“%s”布置。" % name, "positive")
	changed.emit()
	return true

func delete_layout(name: String) -> bool:
	if name in ["日常", "会客", "宠物角"] or not layouts.has(name):
		return false
	layouts.erase(name)
	if active_layout == name:
		active_layout = "日常"
		_apply_layout_data(layouts.get("日常", {}))
	SaveManager.request_auto_save("layout_delete")
	changed.emit()
	return true

func get_layout_names() -> Array[String]:
	var result: Array[String] = []
	for name in layouts:
		result.append(str(name))
	return result

func get_slot_names() -> Array[String]:
	var result: Array[String] = []
	for slot_id in SLOT_NAMES:
		result.append(str(slot_id))
	return result

func get_slot_name(slot_id: String) -> String:
	return str(SLOT_NAMES.get(slot_id, slot_id))

func install_decor(item_id: String) -> bool:
	if installed_decor.has(item_id):
		return false
	match item_id:
		"photo_frame", "warm_blanket":
			installed_decor[item_id] = true
			SaveManager.request_auto_save("decor_install")
			NoticeManager.show_message("把%s安置好了，房间感觉不一样了。" % ("旧相框" if item_id == "photo_frame" else "毛毯"), "positive", "家居店老板")
			changed.emit()
			return true
	return false

func renovate(renovation_id: String) -> bool:
	var row := ConfigDB.get_row("renovations", renovation_id)
	if row.is_empty() or renovation_style == renovation_id:
		return false
	var cost := int(row.get("cost", "0"))
	if not GameState.spend(cost, "给出租屋做了一次%s。" % str(row.get("name", renovation_id))):
		return false
	renovation_style = renovation_id
	NoticeManager.show_message("装修完成了。%s" % str(row.get("description", "")), "positive", "家居店老板")
	SaveManager.request_auto_save("home_renovation")
	changed.emit()
	return true

func get_renovation_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for renovation_id in ConfigDB.get_rows("renovations"):
		var row := ConfigDB.get_row("renovations", renovation_id)
		result.append({
			"id": str(renovation_id),
			"name": str(row.get("name", renovation_id)),
			"cost": int(row.get("cost", "0")),
			"description": str(row.get("description", "")),
			"active": renovation_style == str(renovation_id),
		})
	return result

func get_renovation_summary() -> String:
	if renovation_style.is_empty():
		return "还是原来的白墙和旧灯。"
	var row := ConfigDB.get_row("renovations", renovation_style)
	return "当前装修：%s" % str(row.get("name", renovation_style))

func get_bonus(bonus_type: String) -> float:
	var result := 0.0
	if bonus_type == "study" and bool(installed_decor.get("photo_frame", false)):
		result += 0.05
	if bonus_type == "relax" and bool(installed_decor.get("photo_frame", false)):
		result += 0.03
	if bonus_type == "energy" and bool(installed_decor.get("warm_blanket", false)):
		result += 0.08
	for slot_id in placed:
		var row := ConfigDB.get_row("furniture", str(placed[slot_id]))
		if str(row.get("bonus_type", "")) == bonus_type:
			result += float(row.get("bonus_value", "0"))
	if not renovation_style.is_empty():
		var renovation := ConfigDB.get_row("renovations", renovation_style)
		match bonus_type:
			"energy":
				result += float(renovation.get("energy_bonus", "0"))
			"relax":
				result += float(renovation.get("relax_bonus", "0"))
			"study":
				result += float(renovation.get("study_bonus", "0"))
			"food":
				result += float(renovation.get("food_bonus", "0"))
	return result

func get_room_summary() -> String:
	var names: Array[String] = []
	for slot_id in placed:
		var row := ConfigDB.get_row("furniture", str(placed[slot_id]))
		names.append("%s：%s" % [get_slot_name(str(slot_id)), str(row.get("name", slot_id))])
	if names.is_empty():
		return "房间里还空着，慢慢添置就好。"
	return "“%s”布置 · %s" % [active_layout, "、".join(names)]

func get_bonus_text() -> String:
	var lines: Array[String] = []
	for bt in ["energy", "study", "food", "pet_growth", "relax", "calm", "comfort", "storage", "ambient", "tea"]:
		var value := get_bonus(bt)
		if value <= 0.0:
			continue
		lines.append("%s +%d" % [bt, int(round(value * 100.0))])
	return " · ".join(lines) if not lines.is_empty() else "还没有家具加成。"

func get_placement_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fid in owned:
		var row := ConfigDB.get_row("furniture", str(fid))
		result.append({
			"id": str(fid),
			"name": str(row.get("name", fid)),
			"slot": get_slot_for(str(fid)),
			"slot_name": get_slot_name(get_slot_for(str(fid))) if is_placed(str(fid)) else "未摆放",
			"position": get_furniture_position(str(fid)),
			"rotation": get_furniture_rotation(str(fid)),
		})
	return result

func _apply_layout_data(data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		placed = {}
		manual_positions = {}
		manual_rotations = {}
		return
	if data.has("placed"):
		placed = data.get("placed", {}).duplicate(true)
		manual_positions = data.get("positions", {}).duplicate(true)
		manual_rotations = data.get("rotations", {}).duplicate(true)
		_ensure_manual_layout()
	else:
		placed = data.duplicate(true)
		manual_positions = {}
		manual_rotations = {}
		for slot_id in placed:
			var fid := str(placed[slot_id])
			manual_positions[fid] = get_default_slot_position(str(slot_id))
			manual_rotations[fid] = 0
	_ensure_manual_layout()

func get_save_data() -> Dictionary:
	return {
		"owned": owned.duplicate(true),
		"placed": placed.duplicate(true),
		"layouts": layouts.duplicate(true),
		"active_layout": active_layout,
		"installed_decor": installed_decor.duplicate(true),
		"manual_positions": manual_positions.duplicate(true),
		"manual_rotations": manual_rotations.duplicate(true),
		"renovation_style": renovation_style,
	}

func restore(data: Dictionary) -> void:
	owned = data.get("owned", {}).duplicate(true)
	placed = data.get("placed", {}).duplicate(true)
	layouts = data.get("layouts", {}).duplicate(true)
	active_layout = str(data.get("active_layout", "日常"))
	installed_decor = data.get("installed_decor", {}).duplicate(true)
	manual_positions = data.get("manual_positions", {}).duplicate(true)
	manual_rotations = data.get("manual_rotations", {}).duplicate(true)
	renovation_style = str(data.get("renovation_style", ""))
	_ensure_manual_layout()
	if layouts.is_empty():
		layouts = {"日常": placed.duplicate(true), "会客": {}, "宠物角": {}}
	changed.emit()
