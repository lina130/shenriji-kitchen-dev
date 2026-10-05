extends Node

signal changed
signal family_stage_changed(stage_id: String, partner_id: String)
signal child_stage_changed(stage_id: String, child_name: String)

var stage_id := "single"
var partner_id := ""
var child_name := ""
var child_days := 0
var child_stage := "baby"
var child_bond := 40.0
var child_mood := 70.0
var married_day := 0
var married_days := 0
var last_anniversary_year := -1
var last_evening_day := 0
var last_date_day := 0

func reset_new_game() -> void:
	stage_id = "single"
	partner_id = ""
	child_name = ""
	child_days = 0
	child_stage = "baby"
	child_bond = 40.0
	child_mood = 70.0
	married_day = 0
	married_days = 0
	last_anniversary_year = -1
	last_evening_day = 0
	last_date_day = 0
	changed.emit()

func has_partner() -> bool:
	return not partner_id.is_empty() and stage_id != "single"

func get_stage_row(stage_id_override: String = "") -> Dictionary:
	var resolved := stage_id if stage_id_override.is_empty() else stage_id_override
	return ConfigDB.get_row("family_stages", resolved)

func can_confess(npc_id: String) -> bool:
	return not has_partner() and int(RelationshipManager.affinity.get(npc_id, 0)) >= 35 and CareerManager.is_employed() and HousingManager.current_tier >= 1

func confess(npc_id: String) -> bool:
	if not can_confess(npc_id):
		NoticeManager.show_message("现在还不是说这句话的时候，先多相处一阵。", "hint", RelationshipManager.get_npc_name(npc_id))
		return false
	partner_id = npc_id
	stage_id = "partner"
	NoticeManager.show_message("%s想了一会儿，说以后可以一起试着过日子。" % RelationshipManager.get_npc_name(npc_id), "positive", RelationshipManager.get_npc_name(npc_id))
	SaveManager.request_auto_save("family_confess")
	family_stage_changed.emit(stage_id, partner_id)
	changed.emit()
	return true

func can_marry(npc_id: String) -> bool:
	return stage_id == "partner" and partner_id == npc_id and int(RelationshipManager.affinity.get(npc_id, 0)) >= 60 and HousingManager.current_tier >= 2 and CareerManager.is_employed() and WellbeingManager.stress < 85.0

func marry(npc_id: String) -> bool:
	if not can_marry(npc_id):
		NoticeManager.show_message("要有稳定的住处，也要两个人都想清楚了再谈成家。", "hint", RelationshipManager.get_npc_name(npc_id))
		return false
	var cost := int(get_stage_row("married").get("cost", "2800"))
	if not GameState.spend(cost, "为成家准备了一点积蓄。"):
		return false
	stage_id = "married"
	married_day = TimeSystem.current_day
	married_days = 0
	last_anniversary_year = -1
	StoryManager.record_action("family_marry")
	NoticeManager.show_message("%s和你把两边的日子正式接到了一起。" % RelationshipManager.get_npc_name(npc_id), "positive", RelationshipManager.get_npc_name(npc_id))
	SaveManager.request_auto_save("family_marry")
	family_stage_changed.emit(stage_id, partner_id)
	changed.emit()
	return true

func can_start_family() -> bool:
	return stage_id == "married" and HousingManager.current_tier >= 3 and int(RelationshipManager.affinity.get(partner_id, 0)) >= 75

func start_family() -> bool:
	if not can_start_family():
		NoticeManager.show_message("家里现在还没准备好迎接新成员。", "hint", "梅姨")
		return false
	var cost := int(get_stage_row("family").get("cost", "5000"))
	if not GameState.spend(cost, "为家里添置新的生活用品。"):
		return false
	stage_id = "family"
	child_name = str(RandomManager.pick(["小满", "安安", "乐乐", "小禾", "阿星"]))
	child_days = 0
	child_stage = "baby"
	child_bond = 40.0
	child_mood = 70.0
	NoticeManager.show_message("家里多了一双小鞋，%s成了家里新的小成员。" % child_name, "positive", "梅姨")
	SaveManager.request_auto_save("family_start")
	family_stage_changed.emit(stage_id, partner_id)
	changed.emit()
	return true

func begin_new_day(_day_number: int) -> void:
	if stage_id in ["married", "family"] and married_day > 0:
		married_days += 1
		var anniversary_year := CalendarManager.get_year()
		if CalendarManager.get_day_of_year() == CalendarManager.get_day_of_year(married_day) and last_anniversary_year != anniversary_year:
			last_anniversary_year = anniversary_year
			RelationshipManager.affinity[partner_id] = int(RelationshipManager.affinity.get(partner_id, 0)) + 4
			GameState.change_energy(5.0)
			NoticeManager.show_npc_message("又到了我们的纪念日。先把今天过好，再说明年。", RelationshipManager.get_npc_name(partner_id), "positive")
	if stage_id != "family" or child_name.is_empty():
		return
	child_days += 1
	child_mood = clampf(child_mood - 0.35 + WellbeingManager.get_action_bonus("social") * 1.2, 0.0, 100.0)
	var next_stage := _get_stage_for_days(child_days)
	if next_stage != child_stage:
		child_stage = next_stage
		var row := get_child_stage_row()
		NoticeManager.show_npc_message("%s已经%s了。%s" % [child_name, str(row.get("name", "长大")), str(row.get("description", ""))], "梅姨", "positive")
		child_stage_changed.emit(child_stage, child_name)
	SaveManager.request_auto_save("child_growth")
	changed.emit()

func care_for_child(action_id: String = "") -> bool:
	if stage_id != "family" or child_name.is_empty():
		return false
	var action := action_id if not action_id.is_empty() else get_recommended_child_action()
	match action:
		"feed":
			if not GameState.spend(18, "给孩子买了点吃的。"):
				return false
			child_mood = clampf(child_mood + 10.0, 0.0, 100.0)
			child_bond = clampf(child_bond + 2.0, 0.0, 100.0)
			NoticeManager.show_npc_message("%s吃得认真，碗底都刮干净了。" % child_name, "梅姨", "positive")
		"play":
			if GameState.energy < 8.0:
				NoticeManager.show_npc_message("今天太累了，先歇一会儿再陪%s。" % child_name, "梅姨", "hint")
				return false
			GameState.change_energy(-8.0)
			TimeSystem.advance_minutes(30)
			child_mood = clampf(child_mood + 8.0, 0.0, 100.0)
			child_bond = clampf(child_bond + 5.0, 0.0, 100.0)
			NoticeManager.show_npc_message("你陪%s玩了一会儿，屋里一直有笑声。" % child_name, "梅姨", "positive")
		"teach":
			if GameState.energy < 6.0:
				NoticeManager.show_npc_message("脑子转不动了，明天再教也不迟。", "梅姨", "hint")
				return false
			GameState.change_energy(-6.0)
			TimeSystem.advance_minutes(45)
			child_mood = clampf(child_mood + 3.0, 0.0, 100.0)
			child_bond = clampf(child_bond + 4.0, 0.0, 100.0)
			NoticeManager.show_npc_message("%s学得很慢，但最后自己弄明白了。" % child_name, "梅姨", "positive")
		"outing":
			if GameState.energy < 12.0:
				NoticeManager.show_npc_message("出门要照顾孩子，也得先有精神。", "梅姨", "warning")
				return false
			GameState.change_energy(-12.0)
			TimeSystem.advance_minutes(120)
			child_mood = clampf(child_mood + 15.0, 0.0, 100.0)
			child_bond = clampf(child_bond + 7.0, 0.0, 100.0)
			NoticeManager.show_npc_message("你们在河边和公园走了一圈，%s记住了路边的小店。" % child_name, "梅姨", "positive")
		_:
			return false
	SaveManager.request_auto_save("child_care")
	changed.emit()
	return true

func interact_child() -> bool:
	return care_for_child(get_recommended_child_action())

func get_recommended_child_action() -> String:
	if child_mood < 50.0:
		return "feed"
	if child_bond < 65.0:
		return "play"
	if TimeSystem.get_day_name() in ["周六", "周日"]:
		return "outing"
	return "teach"

func get_child_action_hint() -> String:
	match get_recommended_child_action():
		"feed":
			return "先给孩子添点吃的"
		"play":
			return "陪孩子玩一会儿"
		"outing":
			return "带孩子出去走走"
		_:
			return "教孩子做一件小事"

func share_evening() -> bool:
	if not has_partner():
		return false
	if last_evening_day == TimeSystem.current_day:
		NoticeManager.show_npc_message("今天已经一起待过了，日子还长，不急这一晚。", RelationshipManager.get_npc_name(partner_id), "hint")
		return false
	if GameState.energy < 10.0:
		NoticeManager.show_npc_message("今天太累了，坐着说会儿话就好。", RelationshipManager.get_npc_name(partner_id), "hint")
		return false
	GameState.change_energy(-10.0)
	TimeSystem.advance_minutes(90)
	last_evening_day = TimeSystem.current_day
	RelationshipManager.affinity[partner_id] = int(RelationshipManager.affinity.get(partner_id, 0)) + 2
	WellbeingManager.stress = clampf(WellbeingManager.stress - 8.0, 0.0, 100.0)
	if stage_id == "family":
		child_mood = clampf(child_mood + 4.0, 0.0, 100.0)
	AchievementManager.record_event("shared_evening")
	NoticeManager.show_npc_message("两个人把今天的事慢慢说了一遍，屋里安稳下来。", RelationshipManager.get_npc_name(partner_id), "positive")
	SaveManager.request_auto_save("family_evening")
	changed.emit()
	return true

func go_on_date(location_id: String) -> bool:
	if not has_partner():
		return false
	if last_date_day == TimeSystem.current_day:
		NoticeManager.show_npc_message("今天已经出去过了，明天再约。", RelationshipManager.get_npc_name(partner_id), "hint")
		return false
	if GameState.energy < 12.0:
		NoticeManager.show_npc_message("今天走不动了，先在家歇着吧。", RelationshipManager.get_npc_name(partner_id), "hint")
		return false
	GameState.change_energy(-12.0)
	TimeSystem.advance_minutes(120)
	last_date_day = TimeSystem.current_day
	RelationshipManager.affinity[partner_id] = int(RelationshipManager.affinity.get(partner_id, 0)) + 2
	WellbeingManager.stress = clampf(WellbeingManager.stress - 10.0, 0.0, 100.0)
	var line := "两个人在%s走了一圈，慢慢把最近的事说开了。" % location_id
	match location_id:
		"riverside":
			WellbeingManager.stress = clampf(WellbeingManager.stress - 4.0, 0.0, 100.0)
			line = "河边的风把话说得很慢，回去时心里轻了不少。"
		"park":
			GameState.change_energy(4.0)
			line = "公园里坐了一会儿，晒到太阳，人也没那么累了。"
		"night_market":
			line = "夜市的灯一盏盏亮着，你们分吃了一碗热乎的。"
		"commercial_district":
			line = "商业区逛了一圈，没买什么，但两个人走得很近。"
	AchievementManager.record_event("partner_date")
	NoticeManager.show_npc_message(line, RelationshipManager.get_npc_name(partner_id), "positive")
	SaveManager.request_auto_save("family_date")
	changed.emit()
	return true

func get_child_stage_row() -> Dictionary:
	return ConfigDB.get_row("child_stages", child_stage)

func get_child_summary() -> String:
	if stage_id != "family" or child_name.is_empty():
		return ""
	var row := get_child_stage_row()
	return "%s · %s · 和你很亲近 · 今天看着挺开心" % [child_name, str(row.get("name", "长大中"))]

func can_divorce() -> bool:
	return stage_id != "single" and not partner_id.is_empty()

func divorce() -> bool:
	if not can_divorce():
		NoticeManager.show_npc_message("现在没有需要结束的关系。", "梅姨", "hint")
		return false
	var former_partner := partner_id
	var settlement := 1200 if stage_id in ["married", "family"] else 300
	if GameState.money >= settlement:
		GameState.spend(settlement, "处理分开后的房租和生活安排。")
	WellbeingManager.stress = clampf(WellbeingManager.stress + 15.0, 0.0, 100.0)
	GameState.change_energy(-10.0)
	stage_id = "single"
	partner_id = ""
	child_name = ""
	child_days = 0
	child_stage = "baby"
	child_bond = 40.0
	child_mood = 70.0
	married_day = 0
	married_days = 0
	last_anniversary_year = -1
	AchievementManager.record_event("divorce")
	NoticeManager.show_npc_message("有些话说完，往后的路就各走各的了。日子还得往前。", RelationshipManager.get_npc_name(former_partner), "warning")
	SaveManager.request_auto_save("family_divorce")
	family_stage_changed.emit(stage_id, "")
	changed.emit()
	return true

func _get_stage_for_days(days: int) -> String:
	var result := "baby"
	for stage_id in ConfigDB.get_rows("child_stages"):
		var row := ConfigDB.get_row("child_stages", stage_id)
		if days >= int(row.get("days_required", "0")):
			result = str(stage_id)
	return result

func get_bonus(bonus_type: String) -> float:
	var row := get_stage_row()
	var total := 0.0
	match bonus_type:
		"energy":
			total += float(row.get("energy_bonus", "0"))
		"relax":
			total += float(row.get("relax_bonus", "0"))
		"study":
			total += float(row.get("study_bonus", "0"))
	if stage_id == "family":
		var child_row := get_child_stage_row()
		if bonus_type == "energy":
			total += float(child_row.get("energy_bonus", "0")) * 0.5
		elif bonus_type == "relax":
			total += float(child_row.get("relax_bonus", "0"))
		elif bonus_type == "study":
			total += float(child_row.get("study_bonus", "0"))
	return total

func get_summary() -> String:
	var row := get_stage_row()
	if partner_id.is_empty():
		return str(row.get("description", "一个人也可以把生活过好。"))
	var summary := "%s · %s" % [str(row.get("name", "确定关系")), RelationshipManager.get_npc_name(partner_id)]
	if married_days > 0:
		summary += " · 一起生活 %d 天" % married_days
	return summary

func get_save_data() -> Dictionary:
	return {
		"stage_id": stage_id,
		"partner_id": partner_id,
		"child_name": child_name,
		"child_days": child_days,
		"child_stage": child_stage,
		"child_bond": child_bond,
		"child_mood": child_mood,
		"married_day": married_day,
		"married_days": married_days,
		"last_anniversary_year": last_anniversary_year,
		"last_evening_day": last_evening_day,
		"last_date_day": last_date_day,
	}

func restore(data: Dictionary) -> void:
	stage_id = str(data.get("stage_id", "single"))
	partner_id = str(data.get("partner_id", ""))
	child_name = str(data.get("child_name", ""))
	child_days = int(data.get("child_days", 0))
	child_stage = str(data.get("child_stage", "baby"))
	child_bond = float(data.get("child_bond", 40.0))
	child_mood = float(data.get("child_mood", 70.0))
	married_day = int(data.get("married_day", 0))
	married_days = int(data.get("married_days", 0))
	last_anniversary_year = int(data.get("last_anniversary_year", -1))
	last_evening_day = int(data.get("last_evening_day", 0))
	last_date_day = int(data.get("last_date_day", 0))
	changed.emit()
