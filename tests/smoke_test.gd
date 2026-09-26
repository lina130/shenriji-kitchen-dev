extends Node

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	_run_tests()
	if failures.is_empty():
		print("SMOKE_TEST_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SMOKE_TEST_FAIL: %s" % failure)
		get_tree().quit(1)

func _run_tests() -> void:
	_test_initial_state()
	_test_factory_shift()
	_test_fixed_price_purchase_and_use()
	_test_sleep_and_rent()
	_test_save_and_load()
	_test_three_day_loop()

func _test_initial_state() -> void:
	_check(GameState.money == GameState.STARTING_MONEY, "初始金钱应为 320")
	_check(is_equal_approx(GameState.energy, 100.0), "初始体力应为满值")
	_check(TimeSystem.current_day == 1, "初始日期应为第 1 天")
	_check(TimeSystem.minute_of_day == 420, "初始时间应为 07:00")

func _test_factory_shift() -> void:
	TimeSystem.current_day = 1
	TimeSystem.minute_of_day = 7 * 60
	GameState.money = 320
	GameState.energy = 100.0
	GameState.work_factory_shift()
	_check(GameState.money == 500, "完成一次工厂班次应增加 180")
	_check(is_equal_approx(GameState.energy, 68.0), "完成一次工厂班次应消耗 32 体力")
	_check(TimeSystem.minute_of_day == 15 * 60, "8 小时班次应从 07:00 推进到 15:00")

func _test_fixed_price_purchase_and_use() -> void:
	InventoryManager.items.clear()
	GameState.money = 100
	var meal := InventoryManager.get_item("meal_rice")
	_check(int(meal.get("price", 0)) == 15, "叉烧饭固定价格应为 15")
	_check(GameState.spend(int(meal["price"])), "应能购买叉烧饭")
	InventoryManager.add_item("meal_rice", 1)
	_check(GameState.money == 85, "购买后余额应为 85")
	_check(InventoryManager.get_count("meal_rice") == 1, "背包应自动堆叠 1 份叉烧饭")
	GameState.energy = 40.0
	_check(InventoryManager.use_item("meal_rice"), "叉烧饭应可一键使用")
	_check(InventoryManager.get_count("meal_rice") == 0, "使用后食物数量应减少")
	_check(is_equal_approx(GameState.energy, 78.0), "叉烧饭应恢复 38 体力")

func _test_sleep_and_rent() -> void:
	TimeSystem.current_day = 29
	TimeSystem.minute_of_day = 22 * 60
	GameState.energy = 20.0
	GameState.money = 1000
	GameState.sleep_to_next_day()
	_check(TimeSystem.current_day == 30, "睡觉应进入下一天")
	_check(TimeSystem.minute_of_day == 420, "睡醒时间应为 07:00")
	_check(is_equal_approx(GameState.energy, 100.0), "睡眠应恢复体力")
	_check(GameState.money == 200, "第 30 天应自动扣除 800 房租")

func _test_save_and_load() -> void:
	GameState.money = 777
	GameState.energy = 61.0
	InventoryManager.items.clear()
	InventoryManager.add_item("water", 3)
	TimeSystem.current_day = 12
	TimeSystem.minute_of_day = 18 * 60
	_check(SaveManager.save_game(false), "应能写入测试存档")
	GameState.money = 1
	GameState.energy = 1.0
	InventoryManager.items.clear()
	TimeSystem.current_day = 1
	_check(SaveManager.load_game(false), "应能读取测试存档")
	_check(GameState.money == 777, "读档应恢复金钱")
	_check(is_equal_approx(GameState.energy, 61.0), "读档应恢复体力")
	_check(InventoryManager.get_count("water") == 3, "读档应恢复背包")
	_check(TimeSystem.current_day == 12 and TimeSystem.minute_of_day == 1080, "读档应恢复时间")

func _test_three_day_loop() -> void:
	TimeSystem.current_day = 1
	TimeSystem.minute_of_day = 420
	GameState.money = 320
	GameState.energy = 100.0
	for day_index in range(3):
		GameState.work_factory_shift()
		GameState.energy = 20.0
		TimeSystem.minute_of_day = 22 * 60
		GameState.sleep_to_next_day()
	_check(TimeSystem.current_day == 4, "三次日常循环后应进入第 4 天")
	_check(GameState.money == 860, "三次工厂班次后余额应为 860")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)