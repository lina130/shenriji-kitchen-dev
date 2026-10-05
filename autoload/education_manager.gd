extends Node

signal changed
signal credential_earned(credential_id: String)

var enrolled: Dictionary = {}
var progress: Dictionary = {}
var credentials: Dictionary = {}

func reset_new_game() -> void:
	enrolled.clear()
	progress.clear()
	credentials.clear()
	changed.emit()

func enroll(course_id: String) -> bool:
	var row := ConfigDB.get_row("courses", course_id)
	if row.is_empty():
		return false
	if enrolled.has(course_id) or credentials.has(str(row.get("credential_id", course_id))):
		return false
	var cost := int(row.get("cost", "0"))
	if not GameState.spend(cost, "报名%s。" % str(row.get("name", course_id))):
		return false
	enrolled[course_id] = true
	progress[course_id] = 0.0
	NoticeManager.show_message("报名了%s，有空就去校区上课。" % str(row.get("name", course_id)), "positive", "夜校老师")
	SaveManager.request_auto_save("course_enroll")
	changed.emit()
	return true

func study(course_id: String) -> bool:
	var row := ConfigDB.get_row("courses", course_id)
	if row.is_empty() or not enrolled.has(course_id):
		NoticeManager.show_message("先报名再上课。", "hint", "夜校老师")
		return false
	var minutes := int(row.get("study_minutes", "240"))
	var energy_cost := float(row.get("energy_cost", "16"))
	if GameState.energy < energy_cost:
		NoticeManager.show_message("今天没精神坐进教室，先休息。", "warning", "夜校老师")
		return false
	GameState.change_energy(-energy_cost)
	TimeSystem.advance_minutes(minutes)
	progress[course_id] = minf(100.0, float(progress.get(course_id, 0.0)) + RandomManager.rng.randf_range(28.0, 44.0))
	if is_exam_ready(course_id):
		NoticeManager.show_message("%s的课已经学完，老师说下次来参加结业考核。" % str(row.get("name", course_id)), "positive", "夜校老师")
	else:
		NoticeManager.show_message("今天的内容学完了，老师让你回去再练几次。", "positive", "夜校老师")
	SaveManager.request_auto_save("course_study")
	changed.emit()
	return true

func is_exam_ready(course_id: String) -> bool:
	return enrolled.has(course_id) and float(progress.get(course_id, 0.0)) >= 100.0

func take_exam(course_id: String) -> bool:
	var row := ConfigDB.get_row("courses", course_id)
	if row.is_empty() or not is_exam_ready(course_id):
		NoticeManager.show_message("这门课还没到结业考核的时候。", "hint", "夜校老师")
		return false
	var exam_energy := maxf(8.0, float(row.get("energy_cost", "16")) * 0.45)
	if GameState.energy < exam_energy:
		NoticeManager.show_message("考核前状态太差，先休息或吃点东西。", "warning", "夜校老师")
		return false
	GameState.change_energy(-exam_energy)
	TimeSystem.advance_minutes(120)
	var credential_id := str(row.get("credential_id", course_id))
	credentials[credential_id] = true
	enrolled.erase(course_id)
	progress.erase(course_id)
	NoticeManager.show_message("结业考核通过，拿到了%s证明。老师说以后找工作可以把它带上。" % credential_id, "positive", "夜校老师")
	credential_earned.emit(credential_id)
	SaveManager.request_auto_save("course_exam")
	changed.emit()
	return true

func has_credential(credential_id: String) -> bool:
	return credentials.has(credential_id)

func get_course_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for course_id in ConfigDB.get_rows("courses"):
		var row := ConfigDB.get_row("courses", course_id)
		var credential_id := str(row.get("credential_id", course_id))
		var is_ready := is_exam_ready(str(course_id))
		result.append({
			"id": str(course_id),
			"name": str(row.get("name", course_id)),
			"cost": int(row.get("cost", "0")),
			"credential_id": credential_id,
			"career_line": str(row.get("career_line", "")),
			"description": str(row.get("description", "")),
			"enrolled": enrolled.has(course_id),
			"completed": credentials.has(credential_id),
			"exam_ready": is_ready,
			"hint_text": "已拿证" if credentials.has(credential_id) else ("老师等你参加考核" if is_ready else ("课程进行中" if enrolled.has(course_id) else "报名后可上课")),
		})
	return result

func get_career_bonus(line_id: String) -> float:
	var total := 0.0
	for course_id in ConfigDB.get_rows("courses"):
		var row := ConfigDB.get_row("courses", course_id)
		if str(row.get("career_line", "")) == line_id and credentials.has(str(row.get("credential_id", ""))):
			total += 0.06
	return total

func get_summary() -> String:
	var ready_count := 0
	for course_id in enrolled:
		if is_exam_ready(str(course_id)):
			ready_count += 1
	return "课程报名 %d 门 · 待结业考核 %d 门 · 已取得证书 %d 项" % [enrolled.size(), ready_count, credentials.size()]

func get_save_data() -> Dictionary:
	return {
		"enrolled": enrolled.duplicate(true),
		"progress": progress.duplicate(true),
		"credentials": credentials.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	enrolled = data.get("enrolled", {}).duplicate(true)
	progress = data.get("progress", {}).duplicate(true)
	credentials = data.get("credentials", {}).duplicate(true)
	changed.emit()
