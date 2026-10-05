extends Node

## 店铺人手：员工有工资期望、诉求、士气、疲劳、欠薪和技能，也会离职。

signal changed
signal employee_resigned(employee_id: String, reason: String)

const CANDIDATE_NAMES := ["阿强", "阿芳", "小勇", "阿霞", "老周", "小琴", "阿杰", "小敏", "阿海", "玲姐", "阿辉", "小兰"]
const TRAIT_NAMES := {
	"save_money": "攒钱寄家",
	"learn_craft": "想学手艺",
	"family_care": "照顾家人",
	"nearby": "想离家近",
	"factory": "想跳去工厂",
	"open_shop": "想自己开店",
	"quick_hands": "手快",
	"steady_fire": "火候稳",
	"early_bird": "起得早",
	"night_owl": "熬得住夜",
	"neat_freak": "爱干净",
	"bargain_hunter": "会砍价",
	"old_neighbor": "老街坊",
}
const REFERRAL_NPCS := ["mei", "wang", "lin", "chen", "huang", "azhen", "qiang", "lan"]
const SPECIAL_TRAITS := {
	"quick_hands": {"effect": "kitchen_speed", "value": 0.06, "skills": {"serve": 10}},
	"steady_fire": {"effect": "kitchen_speed", "value": 0.05, "skills": {"stove": 12}},
	"early_bird": {"effect": "morning_revenue", "value": 0.08, "skills": {"prep": 8}},
	"night_owl": {"effect": "patience", "value": 0.05, "skills": {"serve": 6}},
	"neat_freak": {"effect": "patience", "value": 0.04, "skills": {"serve": 8}},
	"bargain_hunter": {"effect": "buy_discount", "value": 0.04, "skills": {"prep": 6}},
	"old_neighbor": {"effect": "patience", "value": 0.03, "skills": {"serve": 5}},
}

var hired: Dictionary = {}
var candidates: Dictionary = {}
var candidate_counter := 0
var candidate_template_cursor := 0
var village_reputation := 0
var pending_candidate_id := ""
var pending_candidate_stage := 0
var referral_days: Dictionary = {}

func _ready() -> void:
	reset_new_game()

func reset_new_game() -> void:
	hired.clear()
	candidates.clear()
	candidate_counter = 0
	candidate_template_cursor = 0
	village_reputation = 0
	pending_candidate_id = ""
	pending_candidate_stage = 0
	referral_days.clear()
	changed.emit()

func can_hire(npc_id: String) -> bool:
	var row := ConfigDB.get_row("staff", npc_id)
	return not row.is_empty() and not hired.has(npc_id)

func hire(npc_id: String) -> bool:
	var row := ConfigDB.get_row("staff", npc_id)
	if row.is_empty() or hired.has(npc_id):
		return false
	var affinity := int(RelationshipManager.affinity.get(npc_id, 0))
	var needed := int(row.get("unlock_affinity", "20"))
	if affinity < needed:
		NoticeManager.show_message("和%s还不够熟，先多来往几次吧。" % npc_id, "warning")
		return false
	var cost := int(row.get("hire_cost", "0"))
	if not GameState.spend(cost, "%s答应常驻店里帮忙。" % str(row.get("role", npc_id))):
		return false
	hired[npc_id] = _new_profile(npc_id, npc_id, row, "referral", 0.0)
	NoticeManager.show_message("%s来上工了，先看看他的诉求和工资期望。" % str(row.get("role", npc_id)), "positive")
	StoryManager.record_action("first_staff")
	SaveManager.request_auto_save("hire")
	changed.emit()
	return true

func hire_candidate(candidate_id: String) -> bool:
	var candidate := find_candidate(candidate_id)
	if candidate.is_empty() or hired.has(candidate_id):
		return false
	var channel_id := str(candidate.get("channel_id", "labor_market"))
	if channel_id == "referral":
		var base_id := str(candidate.get("base_id", ""))
		if int(RelationshipManager.affinity.get(base_id, 0)) < 20:
			NoticeManager.show_message("熟人还不够熟，这次推荐不成立。", "warning")
			return false
	var cost := int(candidate.get("hire_cost", 0))
	if not GameState.spend(cost, "从%s招到%s。" % [str(candidate.get("channel_name", "招工渠道")), str(candidate.get("role", ""))]):
		return false
	var profile: Dictionary = candidate.duplicate(true)
	profile["source"] = channel_id
	profile["source_npc"] = str(candidate.get("source_npc", ""))
	profile["hired_day"] = TimeSystem.current_day
	profile["morale"] = 72.0
	profile["fatigue"] = 0.0
	profile["unpaid_days"] = 0
	profile["housing"] = bool(candidate.get("housing", false))
	hired[candidate_id] = profile
	RemoveCandidate(candidate_id)
	NoticeManager.show_message("%s来店里了，试用期先观察作息和士气。" % str(profile.get("role", "")), "positive")
	SaveManager.request_auto_save("hire")
	changed.emit()
	return true

func RemoveCandidate(candidate_id: String) -> void:
	for channel_id in candidates:
		var list: Array = candidates[channel_id]
		for index in range(list.size() - 1, -1, -1):
			if str(list[index].get("id", "")) == candidate_id:
				list.remove_at(index)
		candidates[channel_id] = list

func dismiss(npc_id: String) -> bool:
	if not hired.has(npc_id):
		return false
	var profile: Dictionary = hired[npc_id]
	hired.erase(npc_id)
	NoticeManager.show_message("先让%s休息一阵子。" % str(profile.get("role", npc_id)))
	SaveManager.request_auto_save("dismiss")
	changed.emit()
	return true

func get_bonus(effect_type: String) -> float:
	var result := 0.0
	for employee_id in hired:
		var profile := _employee_profile(employee_id)
		var row := ConfigDB.get_row("staff", str(profile.get("base_id", employee_id)))
		if str(row.get("effect_type", "")) != effect_type:
			continue
		var morale := clampf(float(profile.get("morale", 70.0)), 0.0, 100.0)
		var skill_name := _effect_skill(effect_type)
		var skill := float(profile.get("skills", {}).get(skill_name, 50.0))
		var morale_factor := 0.65 + morale / 100.0 * 0.45
		var skill_factor := 0.80 + clampf(skill, 0.0, 100.0) / 100.0 * 0.40
		result += float(row.get("effect_value", "0")) * morale_factor * skill_factor
		result += _trait_effect(profile, effect_type)
	return result

func _trait_effect(profile: Dictionary, effect_type: String) -> float:
	var total := 0.0
	for trait_id in profile.get("traits", []):
		var trait_row: Dictionary = SPECIAL_TRAITS.get(str(trait_id), {})
		if str(trait_row.get("effect", "")) == effect_type:
			total += float(trait_row.get("value", 0.0))
	return total

func get_daily_upkeep() -> int:
	var total := 0
	for employee_id in hired:
		total += int(_employee_profile(employee_id).get("wage", 0))
	return total

func begin_new_day(_day_number: int) -> void:
	var month := CalendarManager.get_month()
	var festival_pressure := 1.0 + (0.12 if month == 1 or month == 2 else 0.0)
	var keys := hired.keys()
	for employee_id in keys:
		if not hired.has(employee_id):
			continue
		var profile := _employee_profile(str(employee_id))
		var wage := int(profile.get("wage", 0))
		var expected := int(profile.get("expected_wage", wage))
		if wage > 0 and GameState.spend(wage, "给%s发了今天的工钱。" % str(profile.get("role", employee_id))):
			profile["unpaid_days"] = maxi(0, int(profile.get("unpaid_days", 0)) - 1)
			profile["morale"] = minf(100.0, float(profile.get("morale", 70.0)) + 2.5)
		else:
			profile["unpaid_days"] = int(profile.get("unpaid_days", 0)) + 1
			profile["morale"] = maxf(0.0, float(profile.get("morale", 70.0)) - 14.0)
		profile["fatigue"] = maxf(0.0, float(profile.get("fatigue", 0.0)) - 20.0)
		if float(profile.get("fatigue", 0.0)) >= 80.0:
			profile["morale"] = maxf(0.0, float(profile.get("morale", 70.0)) - 6.0)
		if wage < int(round(expected * 0.82)):
			profile["morale"] = maxf(0.0, float(profile.get("morale", 70.0)) - 7.0)
		if bool(profile.get("housing", false)):
			profile["morale"] = minf(100.0, float(profile.get("morale", 70.0)) + 4.0)
		if "save_money" in profile.get("traits", []) and month == 12:
			profile["expected_wage"] = int(round(expected * festival_pressure))
		hired[str(employee_id)] = profile
		if str(profile.get("source", "")) == "daily" and TimeSystem.current_day - int(profile.get("hired_day", TimeSystem.current_day)) >= 1 and RandomManager.chance(1.0 - float(profile.get("reliability", 0.55))):
			force_resignation(str(employee_id), "日结工拿了工钱就走")
		else:
			_consider_resignation(str(employee_id))
	SaveManager.request_auto_save("staff_daily")
	changed.emit()

func record_work(station_type: String, duration: float) -> void:
	if hired.is_empty():
		return
	var skill_type := _station_skill(station_type)
	for employee_id in hired:
		var profile := _employee_profile(employee_id)
		profile["fatigue"] = minf(100.0, float(profile.get("fatigue", 0.0)) + maxf(0.15, duration * 0.8))
		var skills: Dictionary = profile.get("skills", {})
		skills[skill_type] = minf(100.0, float(skills.get(skill_type, 40.0)) + maxf(0.01, duration * 0.018))
		profile["skills"] = skills
		if float(profile.get("fatigue", 0.0)) >= 92.0:
			profile["morale"] = maxf(0.0, float(profile.get("morale", 70.0)) - 0.25)
		hired[employee_id] = profile

func adjust_wage(employee_id: String, multiplier: float = 1.1) -> bool:
	if not hired.has(employee_id):
		return false
	var profile := _employee_profile(employee_id)
	profile["wage"] = maxi(int(profile.get("wage", 0)) + 1, int(round(float(profile.get("wage", 0)) * multiplier)))
	profile["morale"] = minf(100.0, float(profile.get("morale", 70.0)) + 12.0)
	hired[employee_id] = profile
	NoticeManager.show_message("%s涨薪到日结 ¥%d。" % [str(profile.get("role", employee_id)), int(profile.get("wage", 0))], "positive")
	SaveManager.request_auto_save("raise_wage")
	changed.emit()
	return true

func give_year_bonus(employee_id: String) -> bool:
	if not hired.has(employee_id):
		return false
	var profile := _employee_profile(employee_id)
	var cost := int(profile.get("wage", 0)) * 20
	if not GameState.spend(cost, "给%s发了年终奖。" % str(profile.get("role", employee_id))):
		return false
	profile["morale"] = minf(100.0, float(profile.get("morale", 70.0)) + 28.0)
	hired[employee_id] = profile
	SaveManager.request_auto_save("year_bonus")
	changed.emit()
	return true

func provide_housing(employee_id: String) -> bool:
	if not hired.has(employee_id):
		return false
	var profile := _employee_profile(employee_id)
	if bool(profile.get("housing", false)):
		NoticeManager.show_message("已经给%s安排了包住。" % str(profile.get("role", employee_id)), "hint")
		return false
	var cost := 320
	if not GameState.spend(cost, "给%s在附近租了床位。" % str(profile.get("role", employee_id))):
		return false
	profile["housing"] = true
	profile["morale"] = minf(100.0, float(profile.get("morale", 70.0)) + 20.0)
	hired[employee_id] = profile
	SaveManager.request_auto_save("provide_housing")
	changed.emit()
	return true

func give_day_off(employee_id: String) -> bool:
	if not hired.has(employee_id):
		return false
	var profile := _employee_profile(employee_id)
	profile["fatigue"] = maxf(0.0, float(profile.get("fatigue", 0.0)) - 55.0)
	profile["morale"] = minf(100.0, float(profile.get("morale", 70.0)) + 18.0)
	hired[employee_id] = profile
	NoticeManager.show_message("%s调休一天，精神缓过来了。" % str(profile.get("role", employee_id)), "positive")
	SaveManager.request_auto_save("day_off")
	changed.emit()
	return true

func teach_skill(employee_id: String) -> bool:
	if not hired.has(employee_id):
		return false
	var cost := 180
	if not GameState.spend(cost, "教%s手艺。" % str(profile_role(employee_id))):
		return false
	var profile := _employee_profile(employee_id)
	var skills: Dictionary = profile.get("skills", {})
	for skill_name in ["prep", "stove", "serve"]:
		skills[skill_name] = minf(100.0, float(skills.get(skill_name, 40.0)) + 8.0)
	profile["skills"] = skills
	profile["morale"] = minf(100.0, float(profile.get("morale", 70.0)) + 10.0)
	profile["trained_days"] = int(profile.get("trained_days", 0)) + 1
	hired[employee_id] = profile
	NoticeManager.show_message("%s手艺涨了，但出师后也可能自己出去闯。" % profile_role(employee_id), "positive")
	SaveManager.request_auto_save("teach_skill")
	changed.emit()
	return true

func advance_travel_fund(employee_id: String) -> bool:
	if not hired.has(employee_id):
		return false
	var cost := 160
	if not GameState.spend(cost, "替%s垫了回家的路费。" % profile_role(employee_id)):
		return false
	var profile := _employee_profile(employee_id)
	profile["morale"] = minf(100.0, float(profile.get("morale", 70.0)) + 24.0)
	hired[employee_id] = profile
	village_reputation = mini(100, village_reputation + 8)
	NoticeManager.show_message("垫了路费，老乡口碑 +8。", "positive")
	SaveManager.request_auto_save("travel_fund")
	changed.emit()
	return true

func force_resignation(employee_id: String, reason: String = "家事") -> bool:
	if not hired.has(employee_id):
		return false
	var profile := _employee_profile(employee_id)
	hired.erase(employee_id)
	var message := "%s因为%s离开了店里。" % [str(profile.get("role", employee_id)), reason]
	NoticeManager.show_message(message, "warning")
	SaveManager.request_auto_save("resignation")
	employee_resigned.emit(employee_id, reason)
	changed.emit()
	return true

func get_recruitment_channels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for channel_id in ConfigDB.get_rows("recruitment_channels"):
		var row := ConfigDB.get_row("recruitment_channels", channel_id)
		result.append({
			"id": str(channel_id),
			"name": str(row.get("name", channel_id)),
			"refresh_cost": int(row.get("refresh_cost", 0)),
			"hire_multiplier": float(row.get("hire_multiplier", 1.0)),
			"skill_bonus": float(row.get("skill_bonus", 0.0)),
			"reliability": float(row.get("reliability", 0.5)),
			"housing_supported": _config_bool(row.get("housing_supported", false)),
			"description": str(row.get("description", "")),
			"candidate_count": int(candidates.get(channel_id, []).size()),
		})
	return result

func receive_npc_referral(npc_id: String) -> String:
	if npc_id not in REFERRAL_NPCS:
		return ""
	if RelationshipManager.get_affinity(npc_id) < 6:
		return ""
	var last_day := int(referral_days.get(npc_id, -999))
	if TimeSystem.current_day - last_day < 3:
		return ""
	referral_days[npc_id] = TimeSystem.current_day
	var generated := refresh_candidates("referral", true, 1, true)
	if generated.is_empty():
		return ""
	var candidate: Dictionary = generated[0]
	pending_candidate_id = str(candidate.get("id", ""))
	pending_candidate_stage = 1
	AchievementManager.record_event("referral_lead")
	StoryManager.record_action("referral_lead")
	SaveManager.request_auto_save("npc_referral")
	return "%s提起%s正想找份工，去工业区劳务市场见见吧。" % [RelationshipManager.get_npc_name(npc_id), str(candidate.get("name", "一个熟人"))]

func has_pending_candidate() -> bool:
	return not pending_candidate_id.is_empty() and not find_candidate(pending_candidate_id).is_empty()

func get_pending_candidate_summary() -> String:
	var candidate := find_candidate(pending_candidate_id)
	if candidate.is_empty():
		return ""
	var lines: Array[String] = [
		"%s · %s · 期望日薪 ¥%d · %s" % [
			str(candidate.get("name", "熟人")),
			str(candidate.get("role", "")),
			int(candidate.get("expected_wage", 0)),
			get_traits_text(candidate.get("traits", [])),
		]
	]
	var biography := str(candidate.get("biography", ""))
	var ability_hint := str(candidate.get("ability_hint", ""))
	if not biography.is_empty():
		lines.append(biography)
	if not ability_hint.is_empty():
		lines.append("能力暗示：" + ability_hint)
	return "\n".join(lines)

func handle_labor_market() -> void:
	if pending_candidate_id.is_empty():
		var generated := refresh_candidates("labor_market", true, 1, true)
		if generated.is_empty():
			return
		pending_candidate_id = str(generated[0].get("id", ""))
		pending_candidate_stage = 1
		var first_candidate: Dictionary = generated[0]
		var first_name := str(first_candidate.get("name", "这人"))
		NoticeManager.show_npc_message("%s。%s" % [str(first_candidate.get("biography", "我最近在找活。")), str(first_candidate.get("ability_hint", ""))], first_name, "hint")
		return
	if pending_candidate_stage <= 0:
		pending_candidate_stage = 1
		var quiet_candidate := find_candidate(pending_candidate_id)
		NoticeManager.show_npc_message("我就住附近，先去看看店里的活合不合适。", str(quiet_candidate.get("name", "候选员工")), "hint")
		return
	var candidate := find_candidate(pending_candidate_id)
	if candidate.is_empty():
		pending_candidate_id = ""
		pending_candidate_stage = 0
		return
	var candidate_name := str(candidate.get("name", "这人"))
	if hire_candidate(pending_candidate_id):
		pending_candidate_id = ""
		pending_candidate_stage = 0
		NoticeManager.show_npc_message("行，我先干几天看看。工钱和住处咱们按刚才说的来。", candidate_name, "positive")
	else:
		var want := int(candidate.get("expected_wage", 0))
		var traits_text := get_traits_text(candidate.get("traits", []))
		var personality := str(candidate.get("personality", "我做事有自己的脾气。"))
		NoticeManager.show_npc_message("我能谈，但期望日薪是 ¥%d。%s。诉求是%s。" % [want, personality, traits_text], candidate_name, "hint")

func refresh_candidates(channel_id: String, free: bool = false, count: int = 3, merge: bool = false) -> Array[Dictionary]:
	var channel := ConfigDB.get_row("recruitment_channels", channel_id)
	if channel.is_empty():
		return []
	var refresh_cost := int(channel.get("refresh_cost", 0))
	if refresh_cost > 0 and not free and not GameState.spend(refresh_cost, "在%s打听可靠的人。" % str(channel.get("name", channel_id))):
		return []
	var base_ids := ConfigDB.get_rows("staff").keys()
	var template_rows := ConfigDB.get_rows("staff_candidates")
	var template_ids := template_rows.keys()
	var generated: Array[Dictionary] = []
	for index in range(maxi(1, count)):
		candidate_counter += 1
		var template_id := ""
		var template: Dictionary = {}
		if not template_ids.is_empty():
			candidate_template_cursor = (candidate_template_cursor + 1) % template_ids.size()
			template_id = str(template_ids[candidate_template_cursor])
			template = template_rows.get(template_id, {})
		var fallback_base := "mei"
		if not base_ids.is_empty():
			fallback_base = str(base_ids[(candidate_counter + index) % base_ids.size()])
		var base_id := str(template.get("base_id", fallback_base))
		var row := ConfigDB.get_row("staff", base_id)
		var skill_bonus := float(channel.get("skill_bonus", 0.0)) * 100.0
		var variance := RandomManager.rng.randf_range(-12.0, 10.0)
		var traits := str(row.get("traits", "")).split("|", false)
		var special_trait := ""
		if RandomManager.chance(0.35):
			var special_keys := SPECIAL_TRAITS.keys()
			special_trait = str(special_keys[RandomManager.rng.randi_range(0, special_keys.size() - 1)])
			if not special_trait in traits:
				traits.append(special_trait)
		var special_data: Dictionary = SPECIAL_TRAITS.get(special_trait, {})
		var special_skills: Dictionary = special_data.get("skills", {})
		var expected := float(row.get("expected_wage", row.get("upkeep", "60")))
		if CalendarManager.get_month() == 1 or CalendarManager.get_month() == 2:
			expected *= 1.12
		elif CalendarManager.get_month() == 12:
			expected *= 1.18
		var candidate_id := "%s_%s_%d" % [channel_id, base_id, candidate_counter]
		var candidate_name := str(template.get("name", CANDIDATE_NAMES[(candidate_counter * 7 + index) % CANDIDATE_NAMES.size()]))
		var portrait_id := template_id if not template_id.is_empty() else base_id
		generated.append({
			"id": candidate_id,
			"base_id": base_id,
			"template_id": template_id,
			"portrait_id": portrait_id,
			"channel_id": channel_id,
			"channel_name": str(channel.get("name", channel_id)),
			"role": str(row.get("role", base_id)),
			"name": candidate_name,
			"biography": str(template.get("biography", row.get("description", ""))),
			"personality": str(template.get("personality", "")),
			"ability_hint": str(template.get("ability_hint", "")),
			"color": str(template.get("color", "#d8c38a")),
			"description": str(row.get("description", "")),
			"traits": traits,
			"special_trait": special_trait,
			"skill_prep": clampf(float(row.get("skill_prep", "50")) + skill_bonus + variance + float(special_skills.get("prep", 0)), 5.0, 100.0),
			"skill_stove": clampf(float(row.get("skill_stove", "50")) + skill_bonus + variance * 0.8 + float(special_skills.get("stove", 0)), 5.0, 100.0),
			"skill_serve": clampf(float(row.get("skill_serve", "50")) + skill_bonus + variance * 0.9 + float(special_skills.get("serve", 0)), 5.0, 100.0),
			"expected_wage": int(round(expected)),
			"wage": int(round(expected)),
			"hire_cost": int(round(float(row.get("hire_cost", "0")) * float(channel.get("hire_multiplier", "1.0")))),
			"housing": _config_bool(channel.get("housing_supported", false)),
			"reliability": float(channel.get("reliability", 0.5)),
			"morale": 72.0,
			"fatigue": 0.0,
			"unpaid_days": 0,
		})
	if merge:
		var existing: Array = candidates.get(channel_id, [])
		existing.append_array(generated)
		candidates[channel_id] = existing
	else:
		candidates[channel_id] = generated
	SaveManager.request_auto_save("recruit_refresh")
	changed.emit()
	return generated

func get_candidates(channel_id: String = "") -> Array[Dictionary]:
	if channel_id.is_empty():
		var all_candidates: Array[Dictionary] = []
		for list in candidates.values():
			for candidate in list:
				all_candidates.append(candidate)
		return all_candidates
	if not candidates.has(channel_id):
		return []
	return candidates.get(channel_id, [])

func find_candidate(candidate_id: String) -> Dictionary:
	for channel_id in candidates:
		for candidate in candidates[channel_id]:
			if str(candidate.get("id", "")) == candidate_id:
				return candidate
	return {}

func get_staff_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for npc_id in ConfigDB.get_rows("staff"):
		var row := ConfigDB.get_row("staff", npc_id)
		result.append({
			"id": str(npc_id),
			"role": row.get("role", npc_id),
			"description": row.get("description", ""),
			"hire_cost": int(row.get("hire_cost", "0")),
			"upkeep": int(row.get("upkeep", "0")),
			"expected_wage": int(row.get("expected_wage", row.get("upkeep", "0"))),
			"traits": str(row.get("traits", "")).split("|", false),
			"effect_type": row.get("effect_type", ""),
			"effect_value": float(row.get("effect_value", "0")),
			"unlock_affinity": int(row.get("unlock_affinity", "0")),
			"hired": hired.has(npc_id),
			"affinity": int(RelationshipManager.affinity.get(npc_id, 0)),
		})
	return result

func get_employee_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for employee_id in hired:
		var profile := _employee_profile(employee_id)
		var skills: Dictionary = profile.get("skills", {})
		var base_id := str(profile.get("base_id", employee_id))
		var base_row := ConfigDB.get_row("staff", base_id)
		var npc_row := ConfigDB.get_row("npcs", base_id)
		result.append({
			"id": str(employee_id),
			"name": str(profile.get("name", npc_row.get("name", profile.get("role", employee_id)))),
			"role": str(profile.get("role", employee_id)),
			"base_id": base_id,
			"portrait_id": str(profile.get("portrait_id", base_id)),
			"biography": str(profile.get("biography", npc_row.get("purpose", base_row.get("description", "")))),
			"personality": str(profile.get("personality", npc_row.get("personality", ""))),
			"ability_hint": str(profile.get("ability_hint", "")),
			"color": str(profile.get("color", npc_row.get("color", "#d8c38a"))),
			"source": str(profile.get("source", "referral")),
			"wage": int(profile.get("wage", 0)),
			"expected_wage": int(profile.get("expected_wage", 0)),
			"morale": float(profile.get("morale", 70.0)),
			"fatigue": float(profile.get("fatigue", 0.0)),
			"unpaid_days": int(profile.get("unpaid_days", 0)),
			"housing": bool(profile.get("housing", false)),
			"traits": profile.get("traits", []),
			"trait_text": get_traits_text(profile.get("traits", [])),
			"portrait_key": PresentationManager.get_portrait_key(str(profile.get("portrait_id", base_id))),
			"skills": skills,
		})
	return result

func get_summary() -> String:
	if hired.is_empty():
		return "还没有人常驻店里。"
	var names: Array[String] = []
	for employee_id in hired:
		names.append(str(_employee_profile(employee_id).get("role", employee_id)))
	return "驻店：%s · 每日工钱 ¥%d · 老乡口碑 %d" % ["、".join(names), get_daily_upkeep(), village_reputation]

func get_skill_text(profile: Dictionary) -> String:
	var skills: Dictionary = profile.get("skills", {})
	var strongest := "prep"
	for skill_name in ["stove", "serve"]:
		if float(skills.get(skill_name, 0.0)) > float(skills.get(strongest, 0.0)):
			strongest = skill_name
	match strongest:
		"stove":
			return "火候稳，适合站在灶台边"
		"serve":
			return "手快嘴勤，招呼客人很自然"
		_:
			return "刀工利落，备料不容易出错"

func get_condition_text(profile: Dictionary) -> String:
	var morale := float(profile.get("morale", 70.0))
	var fatigue := float(profile.get("fatigue", 0.0))
	var unpaid := int(profile.get("unpaid_days", 0))
	if unpaid > 0:
		return "最近总问工钱什么时候结"
	if fatigue >= 80.0:
		return "看起来已经很累了"
	if morale <= 25.0:
		return "话比以前少了很多"
	if morale >= 80.0 and fatigue < 40.0:
		return "状态不错，做事有劲"
	return "还在适应店里的节奏"

func get_traits_text(traits: Array) -> String:
	var names: Array[String] = []
	for trait_id in traits:
		names.append(str(TRAIT_NAMES.get(str(trait_id), str(trait_id))))
	return "、".join(names) if not names.is_empty() else "没有特别诉求"

func _config_bool(value: Variant) -> bool:
	return str(value).strip_edges().to_lower() in ["true", "1", "yes", "on"]

func _employee_profile(employee_id: String) -> Dictionary:
	var value = hired.get(employee_id, {})
	if typeof(value) == TYPE_BOOL:
		var row := ConfigDB.get_row("staff", employee_id)
		value = _new_profile(employee_id, employee_id, row, "referral", 0.0)
		hired[employee_id] = value
	return value

func _new_profile(employee_id: String, base_id: String, row: Dictionary, source: String, skill_bonus: float) -> Dictionary:
	var npc_row := ConfigDB.get_row("npcs", base_id)
	return {
		"id": employee_id,
		"base_id": base_id,
		"portrait_id": base_id,
		"name": str(npc_row.get("name", row.get("role", base_id))),
		"biography": str(npc_row.get("purpose", row.get("description", ""))),
		"personality": str(npc_row.get("personality", "")),
		"ability_hint": str(row.get("description", "")),
		"color": str(npc_row.get("color", "#d8c38a")),
		"role": str(row.get("role", base_id)),
		"source": source,
		"wage": int(row.get("upkeep", row.get("expected_wage", "60"))),
		"expected_wage": int(row.get("expected_wage", row.get("upkeep", "60"))),
		"traits": str(row.get("traits", "")).split("|", false),
		"special_trait": "",
		"morale": 72.0,
		"fatigue": 0.0,
		"unpaid_days": 0,
		"housing": false,
		"skills": {
			"prep": clampf(float(row.get("skill_prep", "50")) + skill_bonus, 5.0, 100.0),
			"stove": clampf(float(row.get("skill_stove", "50")) + skill_bonus, 5.0, 100.0),
			"serve": clampf(float(row.get("skill_serve", "50")) + skill_bonus, 5.0, 100.0),
		},
		"trained_days": 0,
		"hired_day": TimeSystem.current_day,
	}

func _consider_resignation(employee_id: String) -> void:
	if not hired.has(employee_id):
		return
	var profile := _employee_profile(employee_id)
	var unpaid := int(profile.get("unpaid_days", 0))
	var morale := float(profile.get("morale", 70.0))
	var fatigue := float(profile.get("fatigue", 0.0))
	var wage := int(profile.get("wage", 0))
	var expected := int(profile.get("expected_wage", wage))
	var month := CalendarManager.get_month()
	var reason := ""
	if unpaid >= 3:
		reason = "连续欠薪"
	elif wage < int(round(expected * 0.72)) and unpaid >= 1 and RandomManager.chance(0.55):
		reason = "长期低薪"
	elif fatigue >= 92.0 and RandomManager.chance(0.38):
		reason = "长期加班"
	elif morale <= 15.0 and RandomManager.chance(0.55):
		reason = "士气低落"
	elif (month == 1 or month == 2) and RandomManager.chance(0.15):
		reason = "春节返乡潮"
	elif "factory" in profile.get("traits", []) and RandomManager.chance(0.05):
		reason = "被工厂挖走"
	elif "open_shop" in profile.get("traits", []) and _average_skill(profile) >= 75.0 and RandomManager.chance(0.08):
		reason = "徒弟出师"
	elif morale < 40.0 and RandomManager.chance(0.05):
		reason = "被隔壁店挖走"
	elif RandomManager.chance(0.01):
		reason = "家人生病"
	if not reason.is_empty():
		force_resignation(employee_id, reason)

func _average_skill(profile: Dictionary) -> float:
	var skills: Dictionary = profile.get("skills", {})
	return (float(skills.get("prep", 0.0)) + float(skills.get("stove", 0.0)) + float(skills.get("serve", 0.0))) / 3.0

func _effect_skill(effect_type: String) -> String:
	if effect_type in ["kitchen_speed"]:
		return "stove"
	if effect_type in ["morning_revenue"]:
		return "prep"
	if effect_type in ["patience"]:
		return "serve"
	return "prep"

func _station_skill(station_type: String) -> String:
	if station_type == "prep":
		return "prep"
	if station_type == "serve":
		return "serve"
	return "stove"

func profile_role(employee_id: String) -> String:
	return str(_employee_profile(employee_id).get("role", employee_id))

func get_save_data() -> Dictionary:
	return {
		"hired": hired.duplicate(true),
		"candidates": candidates.duplicate(true),
		"candidate_counter": candidate_counter,
		"candidate_template_cursor": candidate_template_cursor,
		"village_reputation": village_reputation,
		"pending_candidate_id": pending_candidate_id,
		"pending_candidate_stage": pending_candidate_stage,
		"referral_days": referral_days.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	hired = data.get("hired", {}).duplicate(true)
	candidates = data.get("candidates", {}).duplicate(true)
	candidate_counter = int(data.get("candidate_counter", 0))
	candidate_template_cursor = int(data.get("candidate_template_cursor", 0))
	village_reputation = int(data.get("village_reputation", 0))
	pending_candidate_id = str(data.get("pending_candidate_id", ""))
	pending_candidate_stage = int(data.get("pending_candidate_stage", 0))
	referral_days = data.get("referral_days", {}).duplicate(true)
	for employee_id in hired.keys():
		if typeof(hired[employee_id]) == TYPE_BOOL:
			hired[employee_id] = _new_profile(str(employee_id), str(employee_id), ConfigDB.get_row("staff", str(employee_id)), "legacy", 0.0)
	changed.emit()
