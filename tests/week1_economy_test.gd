extends SceneTree

var _failures: Array[String] = []
var _market: Object
var _weather: Object
var _time_system: Object
var _game_state: Object
var _business: Object
var _career: Object

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var career := root.get_node_or_null("CareerManager")
	var game_state := root.get_node_or_null("GameState")
	var business := root.get_node_or_null("BusinessManager")
	var market_phase := root.get_node_or_null("MarketPhaseManager")
	var weather := root.get_node_or_null("WeatherSystem")
	var time_system := root.get_node_or_null("TimeSystem")
	var save_manager := root.get_node_or_null("SaveManager")
	if career == null or game_state == null or business == null or market_phase == null or weather == null or time_system == null:
		_fail("首周经济检查所需 autoload 未加载")
		_finish()
		return
	if save_manager != null and save_manager.has_method("set_auto_save_enabled"):
		save_manager.call("set_auto_save_enabled", false)

	_market = market_phase
	_weather = weather
	_time_system = time_system
	_game_state = game_state
	_business = business
	_career = career
	_career.call("_connect_runtime_signals")

	_test_trial_half_pay()
	_test_trial_dialogue_progression()
	_test_immediate_action_hints()
	_test_promotion_hints()
	_test_week_loop_and_bill()
	_finish()

func _test_trial_half_pay() -> void:
	_career.call("reset_new_game")
	_game_state.set("money", 320)
	_game_state.set("energy", 100.0)
	_check(bool(_career.call("register_interest", "factory")), "工厂招聘应能登记")
	_check(bool(_career.call("start_trial", "factory")), "工厂试工应能开始")
	var before := int(_game_state.get("money"))
	var accepted: bool = bool(_career.call("perform_trial_action", "factory"))
	var after := int(_game_state.get("money"))
	_check(accepted, "工厂试工动作应成功")
	_check(after - before == 90, "工厂试工应结算半薪 90")

func _test_trial_dialogue_progression() -> void:
	_career.set("trial_required", 3)
	_career.set("trial_progress", 1)
	var first := str(_career.call("get_trial_progress_hint"))
	_career.set("trial_progress", 2)
	var second := str(_career.call("get_trial_progress_hint"))
	_career.set("trial_progress", 3)
	var third := str(_career.call("get_trial_progress_hint"))
	_check(first != second and second != third, "试工台词应至少递进 3 段")

func _test_immediate_action_hints() -> void:
	var study_hint := str(_career.call("get_action_feedback_line", "study"))
	var exercise_hint := str(_career.call("get_action_feedback_line", "exercise"))
	_check(not study_hint.is_empty(), "学习后应有即时 NPC 暗示")
	_check(not exercise_hint.is_empty(), "锻炼后应有即时 NPC 暗示")
	_check(study_hint != exercise_hint, "学习和锻炼的暗示应分别贴合行为")
	var action_callback := Callable(_career, "_on_player_action_completed")
	_check(_game_state.player_action_completed.is_connected(action_callback), "学习/锻炼信号应接入 CareerManager")

func _test_promotion_hints() -> void:
	_career.call("reset_new_game")
	_career.set("current_line", "factory")
	_career.set("current_rank", 1)
	_career.set("shifts_done", 0)
	_career.set("_last_promotion_hint", "")
	_career.set("_last_promotion_band", -1)
	var row: Dictionary = _career.call("get_current_row")
	var needed := maxf(1.0, float(row.get("shifts_needed", "5")))
	var threshold := needed * 0.72
	_career.set("hidden_points", threshold * 0.30)
	_check(int(_career.call("get_promotion_hint_band")) == 1, "晋升暗示应出现第一档")
	_career.set("hidden_points", threshold * 0.60)
	_check(int(_career.call("get_promotion_hint_band")) == 2, "晋升暗示应出现第二档")
	_career.set("hidden_points", threshold * 0.90)
	_check(int(_career.call("get_promotion_hint_band")) == 3, "晋升暗示应出现第三档")
	_career.set("hidden_points", 0.0)
	_career.set("shifts_done", 0)
	_career.set("_last_promotion_band", -1)
	_career.set("_last_promotion_hint", "")
	_check(bool(_career.call("record_shift", "factory", 1.0)), "正式班次应能触发晋升暗示检查")
	_check(int(_career.get("_last_promotion_band")) > 0, "正式班次后应留下可见晋升暗示档位")

func _test_week_loop_and_bill() -> void:
	_career.call("reset_new_game")
	_game_state.set("money", 410)
	_time_system.set("current_day", 2)
	_market.set("current_phase_id", "morning")
	_weather.set("current_weather_id", "sunny")
	_business.set("business_level", 1)
	var week_revenue := 0
	for _day in range(7):
		for _order in range(12):
			week_revenue += int(_business.call("register_recipe_sale", "tea_egg", 1))
	_check(week_revenue > 0, "七天的早餐订单应产生正收益")
	var money_before_bill := int(_game_state.get("money"))
	_career.set("_last_utility_bill_day", -1)
	var billed: bool = bool(_career.call("apply_weekly_utility_bill", 7))
	var money_after_bill := int(_game_state.get("money"))
	_check(billed and money_before_bill - money_after_bill == int(_career.call("get_weekly_utility_bill_amount")), "Day7 小额账单应只扣一次")
	var second_bill: bool = bool(_career.call("apply_weekly_utility_bill", 7))
	_check(not second_bill, "同一天账单不能重复触发")
	var final_money := int(_game_state.get("money"))
	_check(final_money >= 500, "首周经济终态现金不应低于 500")
	_check(final_money <= 1800, "首周经济终态现金不应高于 1800")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	var audio_node := root.get_node_or_null("AudioManager")
	if audio_node != null and audio_node.has_method("shutdown"):
		audio_node.call("shutdown")
	if _failures.is_empty():
		print("WEEK1_ECONOMY_PASS")
		call_deferred("quit", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("quit", 1)
