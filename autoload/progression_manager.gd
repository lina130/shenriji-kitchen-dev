extends Node

signal changed

var factory_days := 0
var clerk_days := 0
var study_sessions := 0
var fitness_sessions := 0
var month_earned := 0
var month_spent := 0
var month_collected := 0
var month_workdays := 0
var month_social_actions := 0

func record_work(job_id: String) -> void:
	if job_id == "factory":
		factory_days += 1
	elif job_id == "clerk":
		clerk_days += 1
	month_workdays += 1
	changed.emit()

func record_study() -> String:
	study_sessions += 1
	changed.emit()
	if study_sessions % 5 == 0:
		return "最近做题越来越顺，脑子里的路也清楚了些。"
	return "书页翻过去，时间安静地走了一会儿。"

func record_exercise() -> String:
	fitness_sessions += 1
	changed.emit()
	if fitness_sessions == 7:
		return "身上的劲儿比以前足了，走路也没那么沉。"
	return "出了一身汗，整个人松快下来。"

func record_collection(rarity: String) -> void:
	month_collected += 1
	if rarity == "legendary":
		changed.emit()

func record_money(amount: int, is_income: bool) -> void:
	if is_income:
		month_earned += maxi(0, amount)
	else:
		month_spent += maxi(0, amount)
	changed.emit()

func record_social_action() -> void:
	month_social_actions += 1
	changed.emit()

func get_factory_wage_bonus() -> int:
	return (factory_days / 5) * 10

func get_clerk_wage_bonus() -> int:
	return (clerk_days / 5) * 6

func get_work_energy_multiplier() -> float:
	var total_days := factory_days + clerk_days
	return maxf(0.72, 1.0 - float(total_days) * 0.025)

func get_speed_bonus() -> float:
	return minf(0.12, float(fitness_sessions) * 0.006)

func begin_new_month() -> void:
	month_earned = 0
	month_spent = 0
	month_collected = 0
	month_workdays = 0
	month_social_actions = 0
	changed.emit()

func get_save_data() -> Dictionary:
	return {
		"factory_days": factory_days,
		"clerk_days": clerk_days,
		"study_sessions": study_sessions,
		"fitness_sessions": fitness_sessions,
		"month_earned": month_earned,
		"month_spent": month_spent,
		"month_collected": month_collected,
		"month_workdays": month_workdays,
		"month_social_actions": month_social_actions,
	}

func restore(data: Dictionary) -> void:
	factory_days = int(data.get("factory_days", 0))
	clerk_days = int(data.get("clerk_days", 0))
	study_sessions = int(data.get("study_sessions", 0))
	fitness_sessions = int(data.get("fitness_sessions", 0))
	month_earned = int(data.get("month_earned", 0))
	month_spent = int(data.get("month_spent", 0))
	month_collected = int(data.get("month_collected", 0))
	month_workdays = int(data.get("month_workdays", 0))
	month_social_actions = int(data.get("month_social_actions", 0))
	changed.emit()

func reset_new_game() -> void:
	factory_days = 0
	clerk_days = 0
	study_sessions = 0
	fitness_sessions = 0
	begin_new_month()