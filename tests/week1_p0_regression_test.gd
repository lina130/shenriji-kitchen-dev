extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := root.get_node_or_null("ConfigDB")
	var game_state := root.get_node_or_null("GameState")
	var treasure := root.get_node_or_null("TreasureManager")
	var business := root.get_node_or_null("BusinessManager")
	var kitchen := root.get_node_or_null("KitchenManager")
	var market := root.get_node_or_null("MarketPhaseManager")
	var weather := root.get_node_or_null("WeatherSystem")
	var time_system := root.get_node_or_null("TimeSystem")
	var calendar := root.get_node_or_null("CalendarManager")
	var wardrobe := root.get_node_or_null("WardrobeManager")
	var save_manager := root.get_node_or_null("SaveManager")
	if config == null or game_state == null or treasure == null or business == null or kitchen == null or market == null or weather == null or time_system == null or calendar == null or wardrobe == null:
		_fail("P0-2/P0-4 测试所需 autoload 未加载")
		_finish()
		return
	if save_manager != null and save_manager.has_method("set_auto_save_enabled"):
		save_manager.call("set_auto_save_enabled", false)

	_test_collection_budget(config, game_state, treasure, time_system)
	_test_order_income_formula(config, business, kitchen, market, weather, time_system, calendar, wardrobe)
	_finish()

func _test_collection_budget(config: Object, game_state: Object, treasure: Object, time_system: Object) -> void:
	var daily_limit := int(config.call("get_number", "balance", "daily_collection_points", 6))
	var energy_cost := float(config.call("get_number", "balance", "collection_energy_cost", 2.0))
	_check(daily_limit == 6, "P0-2.1 daily_collection_points 应读取为 6")
	_check(is_equal_approx(energy_cost, 2.0), "P0-2.2 collection_energy_cost 应读取为 2")

	game_state.set("energy", 100.0)
	treasure.call("reset_new_game")
	_check(int(treasure.call("get_daily_collection_limit")) == daily_limit, "P0-2.3 每日上限应来自 balance.csv")
	_check(int(treasure.call("get_remaining_collection_points")) == daily_limit, "P0-2.4 满体力时可用摸金点应为每日上限")

	game_state.set("energy", 3.0)
	_check(int(treasure.call("get_remaining_collection_points")) == 1, "P0-2.5 体力 3 时只应有 1 次摸金机会")
	game_state.set("energy", 1.0)
	_check(int(treasure.call("get_remaining_collection_points")) == 0, "P0-2.6 体力不足时不应有摸金机会")
	var blocked := str(treasure.call("force_find_once", "street"))
	_check(blocked.is_empty(), "P0-2.7 体力不足时不应发现旧物")

	game_state.set("energy", daily_limit * energy_cost)
	treasure.call("reset_new_game")
	for index in range(daily_limit):
		var found := str(treasure.call("force_find_once", "street"))
		_check(not found.is_empty(), "P0-2.8 第 %d 次摸金应成功" % (index + 1))
	_check(int(treasure.call("get_today_count")) == daily_limit, "P0-2.9 当日发现次数应达到配置上限")
	_check(is_equal_approx(float(game_state.get("energy")), 0.0), "P0-2.10 每次成功发现应扣除 collection_energy_cost")
	var exhausted := str(treasure.call("force_find_once", "street"))
	_check(exhausted.is_empty(), "P0-2.11 达到每日上限后不应继续发现")

	time_system.set("current_day", 2)
	time_system.emit_signal("day_started", 2)
	_check(int(treasure.call("get_today_count")) == 0, "P0-2.12 每日刷新应清空发现次数")
	var restored: Dictionary = treasure.call("get_save_data")
	restored["found_today"] = 999
	treasure.call("restore", restored)
	_check(int(treasure.call("get_today_count")) == daily_limit, "P0-2.13 存档恢复应把发现次数限制在每日上限内")
	treasure.call("reset_new_game")

func _test_order_income_formula(config: Object, business: Object, kitchen: Object, market: Object, weather: Object, time_system: Object, calendar: Object, wardrobe: Object) -> void:
	var order_base_income := float(config.call("get_number", "business", "order_base_income", 6))
	var income_per_level := float(config.call("get_number", "business", "order_income_per_equipment_level", 2))
	_check(is_equal_approx(order_base_income, 6.0), "P0-4.1 order_base_income 应读取为 6")
	_check(is_equal_approx(income_per_level, 2.0), "P0-4.2 order_income_per_equipment_level 应读取为 2")

	time_system.set("current_day", 2)
	weather.set("current_weather_id", "sunny")
	market.set("current_phase_id", "lunch")
	business.set("business_level", 1)
	kitchen.set("equipment_levels", {"prep": 1, "steamer": 2})
	var equipment_total := 3
	var actual := int(business.call("register_recipe_sale", "tea_egg", 3))
	var expected := _expected_order_income("tea_egg", equipment_total, 3, 1, config, market, weather, calendar, wardrobe)
	_check(actual == expected, "P0-4.3 订单收益应包含配方售价、基础收益和设备等级收益，并保留原有倍率：actual=%d expected=%d" % [actual, expected])

func _expected_order_income(recipe_id: String, equipment_total: int, combo: int, business_level: int, config: Object, market: Object, weather: Object, calendar: Object, wardrobe: Object) -> int:
	var recipe: Dictionary = config.call("get_row", "recipes", recipe_id)
	var recipe_sale_price := float(recipe.get("sale_price", 0))
	var order_base_income := float(config.call("get_number", "business", "order_base_income", 6))
	var income_per_level := float(config.call("get_number", "business", "order_income_per_equipment_level", 2))
	var base_income := recipe_sale_price + order_base_income + float(equipment_total) * income_per_level
	var combo_multiplier := 1.0 + maxf(0.0, float(combo - 1)) * 0.06
	var level_multiplier := 1.0 + float(business_level) * 0.05
	var weather_multiplier := 1.0 + maxf(0.0, float(weather.call("get_store_sales_bonus")) - 1.0) * 0.25
	var festival_multiplier := 1.0 + float(calendar.call("get_business_bonus"))
	var phase_multiplier := float(market.call("get_price_multiplier"))
	var wardrobe_tip := 1.0 + float(wardrobe.call("get_bonus", "social"))
	var festival_special := 1.0 + float(market.call("get_festival_bonus", recipe_id))
	return int(round(base_income * combo_multiplier * level_multiplier * weather_multiplier * festival_multiplier * phase_multiplier * wardrobe_tip * festival_special))

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _fail(message: String) -> void:
	failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("WEEK1_P0_REGRESSION_PASS")
		call_deferred("quit", 0)
	else:
		for failure in failures:
			push_error(failure)
		call_deferred("quit", 1)
