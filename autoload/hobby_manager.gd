extends Node

signal changed
signal hobby_milestone(hobby_id: String, level: int)

var enrolled: Dictionary = {}
var skills: Dictionary = {}
var levels: Dictionary = {}
var sessions: Dictionary = {}

func reset_new_game() -> void:
	enrolled.clear()
	skills.clear()
	levels.clear()
	sessions.clear()
	changed.emit()

func action(hobby_id: String) -> bool:
	var row := ConfigDB.get_row("hobbies", hobby_id)
	if row.is_empty():
		return false
	if not enrolled.has(hobby_id):
		return enroll(hobby_id)
	var energy_cost := float(row.get("energy_cost", "10"))
	if GameState.energy < energy_cost:
		NoticeManager.show_message("今天没有力气练这个，先休息。", "warning", "活动中心管理员")
		return false
	GameState.change_energy(-energy_cost)
	TimeSystem.advance_minutes(int(row.get("session_minutes", "150")))
	sessions[hobby_id] = int(sessions.get(hobby_id, 0)) + 1
	var gain := RandomManager.rng.randf_range(8.0, 16.0)
	if hobby_id == "reading":
		gain += WellbeingManager.get_action_bonus("focus") * 30.0
	skills[hobby_id] = minf(100.0, float(skills.get(hobby_id, 0.0)) + gain)
	WellbeingManager.mood = minf(100.0, WellbeingManager.mood + float(row.get("mood_gain", "0")))
	WellbeingManager.stress = maxf(0.0, WellbeingManager.stress - float(row.get("stress_relief", "0")))
	var new_level := int(float(skills[hobby_id]) / 25.0)
	if new_level > int(levels.get(hobby_id, 0)):
		levels[hobby_id] = new_level
		NoticeManager.show_message("%s有了新进步，老师说你已经能自己练了。" % str(row.get("name", hobby_id)), "positive", "活动中心管理员")
		hobby_milestone.emit(hobby_id, new_level)
	else:
		NoticeManager.show_message("练完一节%s，心里松了些。" % str(row.get("name", hobby_id)), "positive", "活动中心管理员")
	if hobby_id == "photography" and RandomManager.chance(0.25):
		TreasureManager.try_trigger_at("walk", Vector2.ZERO, GameState.current_area)
	SaveManager.request_auto_save("hobby_session")
	changed.emit()
	return true

func enroll(hobby_id: String) -> bool:
	var row := ConfigDB.get_row("hobbies", hobby_id)
	if row.is_empty() or enrolled.has(hobby_id):
		return false
	var cost := int(row.get("entry_cost", "0"))
	if not GameState.spend(cost, "报名%s课程。" % str(row.get("name", hobby_id))):
		return false
	enrolled[hobby_id] = true
	skills[hobby_id] = 0.0
	levels[hobby_id] = 0
	sessions[hobby_id] = 0
	NoticeManager.show_message("报上了%s，先当作生活的一部分慢慢练。" % str(row.get("name", hobby_id)), "positive", "活动中心管理员")
	SaveManager.request_auto_save("hobby_enroll")
	changed.emit()
	return true

func get_level(hobby_id: String) -> int:
	return int(levels.get(hobby_id, 0))

func get_hint(hobby_id: String) -> String:
	var skill := float(skills.get(hobby_id, 0.0))
	if not enrolled.has(hobby_id):
		return "还没报名"
	if skill >= 75.0:
		return "已经很熟，可以带别人一起练"
	if skill >= 50.0:
		return "稳定进步，偶尔能完成小作品"
	if skill >= 25.0:
		return "已经入门，自己练也不慌"
	return "刚起步，先享受过程"

func get_social_bonus() -> float:
	return get_level("music") * 0.02 + get_level("painting") * 0.01

func get_career_bonus(line_id: String) -> float:
	var total := 0.0
	for hobby_id in ConfigDB.get_rows("hobbies"):
		var row := ConfigDB.get_row("hobbies", hobby_id)
		if str(row.get("career_line", "")) == line_id:
			total += float(get_level(hobby_id)) * 0.015
	return total

func get_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hobby_id in ConfigDB.get_rows("hobbies"):
		var row := ConfigDB.get_row("hobbies", hobby_id)
		result.append({
			"id": str(hobby_id),
			"name": str(row.get("name", hobby_id)),
			"entry_cost": int(row.get("entry_cost", "0")),
			"description": str(row.get("description", "")),
			"enrolled": enrolled.has(hobby_id),
			"hint_text": get_hint(str(hobby_id)),
			"level": get_level(str(hobby_id)),
		})
	return result

func get_summary() -> String:
	return "参加 %d 项兴趣 · 已练习 %d 节" % [enrolled.size(), _total_sessions()]

func _total_sessions() -> int:
	var total := 0
	for value in sessions.values():
		total += int(value)
	return total

func get_save_data() -> Dictionary:
	return {
		"enrolled": enrolled.duplicate(true),
		"skills": skills.duplicate(true),
		"levels": levels.duplicate(true),
		"sessions": sessions.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	enrolled = data.get("enrolled", {}).duplicate(true)
	skills = data.get("skills", {}).duplicate(true)
	levels = data.get("levels", {}).duplicate(true)
	sessions = data.get("sessions", {}).duplicate(true)
	changed.emit()
