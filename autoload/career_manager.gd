extends Node

## 玩家职业线。进度不展示为数值或进度条，只通过领班/师傅的暗示表现。

signal changed
signal job_changed(line_id: String, title: String)
signal promoted(line_id: String, title: String, hint: String)
signal laid_off(line_id: String, title: String, reason: String, severance: int)

var current_line := ""
var current_rank := 0
var shifts_done := 0
var hidden_points := 0.0
var _last_promotion_hint := ""
var _blocked_credential := ""
var low_performance_streak := 0
var layoff_count := 0
var application_line := ""
var application_stage := 0
var trial_progress := 0
var trial_required := 0
var _last_promotion_band := -1
var _last_utility_bill_day := -1
var _runtime_signals_connected := false

func _ready() -> void:
	reset_new_game()
	call_deferred("_connect_runtime_signals")

func reset_new_game() -> void:
	current_line = ""
	current_rank = 0
	shifts_done = 0
	hidden_points = 0.0
	_last_promotion_hint = ""
	_blocked_credential = ""
	low_performance_streak = 0
	layoff_count = 0
	application_line = ""
	application_stage = 0
	trial_progress = 0
	trial_required = 0
	_last_promotion_band = -1
	_last_utility_bill_day = -1
	changed.emit()

func is_employed() -> bool:
	return not current_line.is_empty() and current_rank > 0

func is_employed_in(line_id: String) -> bool:
	return is_employed() and current_line == line_id

func can_work(line_id: String) -> bool:
	return is_employed_in(line_id)

func get_available_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for career_id in ConfigDB.get_rows("careers"):
		var row := ConfigDB.get_row("careers", career_id)
		var line_id := str(row.get("line", ""))
		if line_id.is_empty() or seen.has(line_id):
			continue
		seen[line_id] = true
		var first_row := get_rank_row(line_id, 1)
		result.append({
			"id": line_id,
			"name": get_line_name(line_id),
			"first_title": str(first_row.get("title", "")),
			"description": str(first_row.get("description", "")),
		})
	return result

func register_interest(line_id: String) -> bool:
	if get_rank_row(line_id, 1).is_empty():
		return false
	if is_employed():
		NoticeManager.show_message("已经有正式工作，想换线就先去岗位界面辞职。", "hint", "招工负责人")
		return false
	if application_line != line_id:
		application_line = line_id
		application_stage = 1
		trial_progress = 0
		trial_required = _trial_required_for(line_id)
		NoticeManager.show_message("在%s招聘牌上登记了名字。负责人让你到现场工位试一班。" % get_line_name(line_id), "positive", "招工负责人")
	else:
		application_stage = maxi(application_stage, 1)
	NoticeManager.show_message(get_application_summary(), "hint", _trial_speaker(line_id))
	SaveManager.request_auto_save("career_interest")
	changed.emit()
	return true

func start_trial(line_id: String) -> bool:
	if application_line != line_id or application_stage <= 0:
		NoticeManager.show_message("先去招聘板登记，负责人才能安排试工。", "hint", "招工负责人")
		return false
	if application_stage == 3:
		return true
	application_stage = 2
	trial_progress = 0
	trial_required = _trial_required_for(line_id)
	NoticeManager.show_message("%s把你带到工位旁边，说先按现场要求做几轮。" % _trial_speaker(line_id), "positive", _trial_speaker(line_id))
	SaveManager.request_auto_save("career_trial_start")
	changed.emit()
	return true

func perform_trial_action(line_id: String) -> bool:
	if application_line != line_id or application_stage <= 0:
		NoticeManager.show_message("还没有登记这条路线，先去招聘板写下名字。", "hint", "招工负责人")
		return false
	if application_stage == 3:
		return confirm_application(line_id)
	if application_stage == 1:
		start_trial(line_id)
	if GameState.energy < 4.0:
		NoticeManager.show_message("试工也要体力，先吃点东西再来。", "warning", _trial_speaker(line_id))
		return false
	GameState.change_energy(-4.0)
	TimeSystem.advance_minutes(15)
	if line_id == "factory":
		GameState.earn(maxi(1, int(round(GameState.factory_wage * 0.5))), "试工结了半薪。")
	trial_progress += 1
	if trial_progress >= trial_required:
		application_stage = 3
		NoticeManager.show_message("%s看完几轮操作，说你已经可以正式试班，回去确认入职。" % _trial_speaker(line_id), "positive", _trial_speaker(line_id))
	else:
		NoticeManager.show_message("%s盯着你的动作，说：%s" % [_trial_speaker(line_id), get_trial_progress_hint()], "hint", _trial_speaker(line_id))
	SaveManager.request_auto_save("career_trial_action")
	changed.emit()
	return true

func confirm_application(line_id: String) -> bool:
	if application_line != line_id or application_stage < 3:
		NoticeManager.show_message("试工还没完成，先把现场动作做完。", "hint", _trial_speaker(line_id))
		return false
	if apply_for_job(line_id):
		application_line = ""
		application_stage = 0
		trial_progress = 0
		trial_required = 0
		changed.emit()
		return true
	return false

func get_application_summary() -> String:
	if application_line.is_empty() or application_stage <= 0:
		return "还没有在招聘现场登记。"
	var line_name := get_line_name(application_line)
	if application_stage == 1:
		return "%s：已登记，去现场找工作台开始试工。" % line_name
	if application_stage == 2:
		return "%s试工：负责人还在看你做事，现场动作 %d/%d。" % [line_name, trial_progress, trial_required]
	return "%s：试工完成，回去找负责人确认入职。" % line_name

func _trial_required_for(line_id: String) -> int:
	return 3 if line_id in ["restaurant", "factory"] else 2

func get_trial_progress_hint() -> String:
	if trial_required <= 0:
		return "先按现场要求完成第一轮。"
	var ratio := clampf(float(trial_progress) / float(trial_required), 0.0, 1.0)
	if ratio < 0.34:
		return "第一轮手有点生，先把手势和节奏稳住。"
	if ratio < 0.72:
		return "你比刚才稳了，再练两轮就能接正式班。"
	return "节奏已经跟上了，最后一轮做完就能正式上班。"

func _trial_action_text(line_id: String) -> String:
	match line_id:
		"restaurant": return "备料、下锅、出餐各做一遍"
		"factory": return "跟线、递料、盯机器"
		"logistics": return "分拣、扫码、装车"
		"craft": return "拆件、维修、试机"
		"office": return "整理表格、对接一轮"
		"public": return "跟随巡查、接待一轮"
		"freelance": return "完成一轮拍摄或接单"
		"study": return "完成一节学习或练习"
	return "按现场要求完成一轮"

func _trial_speaker(line_id: String) -> String:
	match line_id:
		"restaurant": return "厨房师傅"
		"factory": return "工厂领班"
		"logistics": return "仓库调度"
		"craft": return "维修师傅"
		"office": return "部门主管"
		"public": return "社区负责人"
		"freelance": return "合作客户"
		"study": return "导师"
	return "招工负责人"

func apply_for_job(line_id: String) -> bool:
	var first_row := get_rank_row(line_id, 1)
	if first_row.is_empty():
		return false
	var required := str(first_row.get("required_credential", ""))
	if not required.is_empty() and not EducationManager.has_credential(required):
		NoticeManager.show_message("负责人说先把%s证明拿到手，再来登记岗位。" % _credential_name(required), "hint", "招工负责人")
		return false
	if is_employed():
		NoticeManager.show_message("现在还有工作，先辞职再考虑别的岗位。", "warning")
		return false
	current_line = line_id
	current_rank = 1
	if get_node_or_null("/root/CollectionManager") != null:
		CollectionManager.record_career_seen(line_id)
	shifts_done = 0
	hidden_points = 0.0
	var row := first_row
	var title := str(row.get("title", "新员工"))
	var line_name := get_line_name(line_id)
	NoticeManager.show_message("已经在%s登记，先从%s做起。" % [line_name, title], "positive")
	application_line = ""
	application_stage = 0
	trial_progress = 0
	trial_required = 0
	job_changed.emit(current_line, title)
	StoryManager.record_action("career_apply")
	SaveManager.request_auto_save("career_apply")
	changed.emit()
	return true

func record_shift(line_id: String, quality: float = 1.0) -> bool:
	if not can_work(line_id):
		return false
	shifts_done += 1
	hidden_points += clampf(quality, 0.25, 1.5)
	_update_performance(line_id, quality)
	if not is_employed_in(line_id):
		return true
	var row := get_current_row()
	var needed := maxi(1, int(row.get("shifts_needed", "5")))
	if shifts_done >= needed and hidden_points >= float(needed) * 0.72:
		_promote()
	else:
		_last_promotion_hint = get_manager_hint()
		_emit_promotion_hint_if_due(line_id)
	SaveManager.request_auto_save("career_shift")
	changed.emit()
	return true

func get_manager_hint() -> String:
	if not is_employed():
		if application_stage > 0:
			return get_application_summary()
		if layoff_count > 0:
			return "待业中。上一次被裁不是终点，城市里还有别的活法。"
		return "还没有正式工作，工厂或餐饮都贴着招工启事。"
	if low_performance_streak >= 2:
		return "负责人说最近这几次状态明显不对，再撑不住就要考虑换班了。"
	if low_performance_streak >= 1:
		return "负责人提醒你先吃好睡好，别把身体和活计一起熬坏。"
	if not _blocked_credential.is_empty():
		return "负责人说路已经铺好了，先把%s证明拿来，称呼就能往前走一步。" % _credential_name(_blocked_credential)
	var ratio := get_hidden_progress_ratio()
	if not _last_promotion_hint.is_empty() and ratio >= 0.65:
		return _last_promotion_hint
	match get_promotion_hint_band():
		0:
			return "师傅还在看你做事稳不稳，暂时没多说什么。"
		1:
			return "师傅最近会多看你两眼，交代的活也开始复杂了。"
		2:
			return "领班说你这阵子比以前稳，保持住。"
		_:
			return "负责人开始让你带新人，话里像是留了位置。"

func get_hidden_progress_ratio() -> float:
	if not is_employed():
		return 0.0
	var row := get_current_row()
	var needed := maxf(1.0, float(row.get("shifts_needed", "5")))
	return clampf(hidden_points / (needed * 0.72), 0.0, 1.25)

func get_promotion_hint_band() -> int:
	var ratio := get_hidden_progress_ratio()
	if ratio < 0.25:
		return 0
	if ratio < 0.55:
		return 1
	if ratio < 0.85:
		return 2
	return 3

func _emit_promotion_hint_if_due(line_id: String) -> void:
	var band := get_promotion_hint_band()
	if band <= 0 or band == _last_promotion_band:
		return
	_last_promotion_band = band
	NoticeManager.show_message(get_manager_hint(), "hint", _career_speaker(line_id))

func evaluate_shift_quality() -> float:
	var quality := 1.0
	if GameState.energy < 25.0:
		quality -= 0.30
	elif GameState.energy < 45.0:
		quality -= 0.12
	if GameState.health < 60.0:
		quality -= 0.22
	if WellbeingManager.stress > 70.0:
		quality -= 0.20
	quality += WardrobeManager.get_bonus("work")
	return clampf(quality, 0.25, 1.2)

func _update_performance(line_id: String, quality: float) -> void:
	if line_id in ["study", "freelance"]:
		low_performance_streak = 0
		return
	if quality >= 0.62:
		low_performance_streak = maxi(0, low_performance_streak - 1)
		return
	low_performance_streak += 1
	if low_performance_streak == 2:
		NoticeManager.show_message("负责人说这两天你的状态不对，先别再硬撑，否则班次会保不住。", "warning", _career_speaker(line_id))
	elif low_performance_streak >= 4:
		_layoff("连续状态不佳，岗位上要换人")

func _layoff(reason: String) -> void:
	if not is_employed():
		return
	var line_id := current_line
	var title := get_current_title()
	var severance := maxi(180, int(round(280.0 * get_shift_wage_multiplier())))
	GameState.earn(severance, "被裁后拿到一笔结算 ¥%d，先让生活缓一口气。" % severance)
	current_line = ""
	current_rank = 0
	shifts_done = 0
	hidden_points = 0.0
	_last_promotion_hint = ""
	_blocked_credential = ""
	low_performance_streak = 0
	layoff_count += 1
	NoticeManager.show_message("%s说：%s。这是最后一班，结算已经发给你了。" % [_career_speaker(line_id), reason], "warning", "岗位负责人")
	laid_off.emit(line_id, title, reason, severance)
	job_changed.emit("", "")
	SaveManager.request_auto_save("career_layoff")
	changed.emit()

func _career_speaker(line_id: String) -> String:
	match line_id:
		"restaurant", "craft":
			return "师傅"
		"factory":
			return "领班"
		"logistics":
			return "调度"
		"public":
			return "科室领导"
		"office":
			return "部门主管"
	return "负责人"

func _promote() -> void:
	var line_id := current_line
	var next_row := get_rank_row(line_id, current_rank + 1)
	if next_row.is_empty():
		_last_promotion_hint = "负责人说这条线暂时到头了。"
		return
	var required := str(next_row.get("required_credential", ""))
	if not required.is_empty() and not EducationManager.has_credential(required):
		_blocked_credential = required
		_last_promotion_hint = "负责人说先把%s证明拿来，位置会给你留着。" % _credential_name(required)
		if shifts_done == maxi(1, int(get_current_row().get("shifts_needed", "5"))):
			NoticeManager.show_message(_last_promotion_hint, "hint", "招工负责人")
		return
	_blocked_credential = ""
	current_rank += 1
	_last_promotion_band = -1
	if get_node_or_null("/root/CollectionManager") != null:
		CollectionManager.record_career_seen(line_id)
	shifts_done = 0
	hidden_points = 0.0
	var row := get_current_row()
	var title := str(row.get("title", "员工"))
	_last_promotion_hint = "负责人让你先跟着学新的安排，称呼也变了。"
	var speaker := "师傅" if line_id in ["restaurant", "craft"] else ("调度" if line_id == "logistics" else "领班")
	NoticeManager.show_message("%s说：以后按%s来安排。" % [speaker, title], "positive")
	promoted.emit(line_id, title, _last_promotion_hint)

func resign(reason: String = "自己想换个活法") -> bool:
	if not is_employed():
		return false
	var old_title := get_current_title()
	low_performance_streak = 0
	current_line = ""
	current_rank = 0
	shifts_done = 0
	hidden_points = 0.0
	_last_promotion_hint = ""
	application_line = ""
	application_stage = 0
	trial_progress = 0
	trial_required = 0
	NoticeManager.show_message("辞去了%s。%s" % [old_title, reason], "warning")
	job_changed.emit("", "")
	SaveManager.request_auto_save("career_resign")
	changed.emit()
	return true

func get_current_title() -> String:
	if not is_employed():
		return "待业"
	return str(get_current_row().get("title", "员工"))

func get_line_name(line_id: String = "") -> String:
	var resolved := current_line if line_id.is_empty() else line_id
	match resolved:
		"restaurant":
			return "餐饮"
		"factory":
			return "工厂"
		"office":
			return "写字楼职场"
		"study":
			return "学业升学"
		"public":
			return "体制稳定"
		"freelance":
			return "自由职业"
		"logistics":
			return "物流仓配"
		"craft":
			return "手艺技工"
	return "待业"

func get_shift_wage_multiplier() -> float:
	if not is_employed():
		return 1.0
	return float(get_current_row().get("wage_multiplier", "1.0"))

func get_current_row() -> Dictionary:
	return get_rank_row(current_line, current_rank)

func get_rank_row(line_id: String, rank: int) -> Dictionary:
	for career_id in ConfigDB.get_rows("careers"):
		var row := ConfigDB.get_row("careers", career_id)
		if str(row.get("line", "")) == line_id and int(row.get("rank", 0)) == rank:
			return row
	return {}

func get_all_ranks(line_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for career_id in ConfigDB.get_rows("careers"):
		var row := ConfigDB.get_row("careers", career_id)
		if str(row.get("line", "")) == line_id:
			result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("rank", 0)) < int(b.get("rank", 0))
	)
	return result

func _credential_name(credential_id: String) -> String:
	for course_id in ConfigDB.get_rows("courses"):
		var row := ConfigDB.get_row("courses", course_id)
		if str(row.get("credential_id", "")) == credential_id:
			return str(row.get("name", credential_id))
	return credential_id

func get_summary() -> String:
	if not is_employed():
		return "待业 · 可以去工厂或餐饮找工作"
	return "%s · %s · %s" % [get_line_name(), get_current_title(), get_manager_hint()]

func _connect_runtime_signals() -> void:
	if _runtime_signals_connected:
		return
	if not GameState.player_action_completed.is_connected(_on_player_action_completed):
		GameState.player_action_completed.connect(_on_player_action_completed)
	if not TimeSystem.day_started.is_connected(_on_day_started):
		TimeSystem.day_started.connect(_on_day_started)
	_runtime_signals_connected = true

func _on_player_action_completed(action_id: String) -> void:
	var line := get_action_feedback_line(action_id)
	if line.is_empty():
		return
	var speaker := "公园教练" if action_id == "exercise" else "导师"
	NoticeManager.show_npc_message(line, speaker, "hint")

func get_action_feedback_line(action_id: String) -> String:
	match action_id:
		"study":
			return "书页已经翻出手感，再练几轮，做题会更快。"
		"exercise":
			return "呼吸稳了，坚持几天，干重活会轻松些。"
	return ""

func _on_day_started(day_number: int) -> void:
	apply_weekly_utility_bill(day_number)

func get_weekly_utility_bill_amount() -> int:
	return maxi(0, int(ConfigDB.get_number("business", "weekly_utility_bill", 200)))

func get_last_utility_bill_day() -> int:
	return _last_utility_bill_day

func apply_weekly_utility_bill(day_number: int, force: bool = false) -> bool:
	var interval := maxi(1, int(ConfigDB.get_number("business", "weekly_utility_bill_day", 7)))
	if not force and day_number % interval != 0:
		return false
	if _last_utility_bill_day == day_number:
		return false
	var amount := get_weekly_utility_bill_amount()
	if amount <= 0:
		return false
	_last_utility_bill_day = day_number
	if GameState.money >= amount:
		GameState.spend(amount, "第%d天水电和小额账单：¥%d" % [day_number, amount])
	else:
		var paid := maxi(0, GameState.money)
		if paid > 0:
			GameState.spend(paid)
		NoticeManager.show_message(
			"第%d天账单 ¥%d，先付了 ¥%d，还差 ¥%d。" % [day_number, amount, paid, amount - paid],
			"warning",
			"房东",
		)
	changed.emit()
	return true

func get_save_data() -> Dictionary:
	return {
		"current_line": current_line,
		"current_rank": current_rank,
		"shifts_done": shifts_done,
		"hidden_points": hidden_points,
		"last_promotion_hint": _last_promotion_hint,
		"blocked_credential": _blocked_credential,
		"low_performance_streak": low_performance_streak,
		"layoff_count": layoff_count,
		"application_line": application_line,
		"application_stage": application_stage,
		"trial_progress": trial_progress,
		"trial_required": trial_required,
		"last_promotion_band": _last_promotion_band,
		"last_utility_bill_day": _last_utility_bill_day,
	}

func restore(data: Dictionary) -> void:
	current_line = str(data.get("current_line", ""))
	current_rank = int(data.get("current_rank", 0))
	shifts_done = int(data.get("shifts_done", 0))
	hidden_points = float(data.get("hidden_points", 0.0))
	_last_promotion_hint = str(data.get("last_promotion_hint", ""))
	_blocked_credential = str(data.get("blocked_credential", ""))
	low_performance_streak = int(data.get("low_performance_streak", 0))
	layoff_count = int(data.get("layoff_count", 0))
	application_line = str(data.get("application_line", ""))
	application_stage = clampi(int(data.get("application_stage", 0)), 0, 3)
	trial_progress = maxi(0, int(data.get("trial_progress", 0)))
	trial_required = maxi(0, int(data.get("trial_required", 0)))
	_last_promotion_band = int(data.get("last_promotion_band", -1))
	_last_utility_bill_day = int(data.get("last_utility_bill_day", -1))
	changed.emit()
