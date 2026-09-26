extends Node

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	_run_tests()
	AudioManager.shutdown()
	await get_tree().process_frame
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
	_test_clerk_shift()
	_test_collection_system()
	_test_weather_system()
	_test_relationship_and_gift()
	_test_study_and_exercise()
	_test_market_economy()
	_test_expedition()
	_test_save_and_load()
	_test_30_day_cycle()

func _test_initial_state() -> void:
	GameState.reset_new_game()
	WeatherSystem.current_weather_id = "sunny"
	_check(GameState.money == GameState.STARTING_MONEY, "初始金钱应为 320")
	_check(is_equal_approx(GameState.energy, 100.0), "初始体力应为满值")
	_check(TimeSystem.current_day == 1, "初始日期应为第 1 天")
	_check(TimeSystem.minute_of_day == 420, "初始时间应为 07:00")
	_check(not CollectionManager.get_area_spawns("street").is_empty(), "街道应生成每日摸金点")
	_check(ConfigDB.get_row("weather", WeatherSystem.current_weather_id).size() > 0, "每日天气应来自配置表")

func _test_factory_shift() -> void:
	GameState.reset_new_game()
	WeatherSystem.current_weather_id = "sunny"
	TimeSystem.current_day = 1
	TimeSystem.minute_of_day = 7 * 60
	GameState.money = 320
	GameState.energy = 100.0
	GameState.work_factory_shift()
	_check(GameState.money == 500, "完成一次工厂班次应增加 180")
	_check(is_equal_approx(GameState.energy, 68.0), "晴天完成工厂班次应消耗 32 体力")
	_check(TimeSystem.minute_of_day == 15 * 60, "8 小时班次应从 07:00 推进到 15:00")

func _test_clerk_shift() -> void:
	GameState.reset_new_game()
	WeatherSystem.current_weather_id = "sunny"
	TimeSystem.minute_of_day = 9 * 60
	GameState.money = 320
	GameState.energy = 100.0
	GameState.work_clerk_shift()
	_check(GameState.money == 415, "便利店兼职应增加 95")
	_check(is_equal_approx(GameState.energy, 80.0), "便利店兼职应消耗 20 体力")
	_check(TimeSystem.minute_of_day == 14 * 60, "便利店兼职应推进 5 小时")

func _test_collection_system() -> void:
	GameState.reset_new_game()
	var spawns := CollectionManager.get_area_spawns("street")
	if spawns.is_empty():
		_check(false, "测试前街道摸金点不应为空")
		return
	var spawn: Dictionary = spawns[0]
	var item_id := str(spawn.get("item_id", ""))
	var spawn_id := str(spawn.get("spawn_id", ""))
	var count_before := InventoryManager.get_count(item_id)
	_check(CollectionManager.collect_spawn("street", spawn_id), "靠近后应能拾取摸金物")
	_check(InventoryManager.get_count(item_id) == count_before + 1, "摸金物应自动堆叠进背包")
	_check(bool(CollectionManager.discovered.get(item_id, false)), "拾取后应记入旧物册")

func _test_weather_system() -> void:
	var row := ConfigDB.get_row("weather", WeatherSystem.current_weather_id)
	_check(not row.is_empty(), "天气 ID 应能在配置中查到")
	_check(WeatherSystem.get_collection_bonus() >= 0.0, "天气摸金加成应为非负数")
	_check(WeatherSystem.get_work_energy_multiplier() >= 1.0, "不同天气应会影响工作体力消耗")

func _test_relationship_and_gift() -> void:
	GameState.reset_new_game()
	InventoryManager.add_item("film_camera", 1)
	var line := RelationshipManager.talk_to("lin")
	_check(not line.is_empty(), "和 NPC 交谈应返回生活化对话")
	var result := RelationshipManager.give_item("lin", "film_camera")
	_check(bool(result.get("ok", false)), "喜欢旧物相机的 NPC 应接受礼物")
	_check(InventoryManager.get_count("film_camera") == 0, "送礼后背包物品应减少")
	_check(RelationshipManager.get_affinity_label("lin") != "", "关系应通过模糊称呼感知")

func _test_study_and_exercise() -> void:
	GameState.reset_new_game()
	TimeSystem.minute_of_day = 10 * 60
	GameState.energy = 100.0
	GameState.study_at_desk()
	_check(is_equal_approx(GameState.energy, 90.0), "学习应消耗体力")
	_check(ProgressionManager.study_sessions == 1, "学习应留下隐藏成长")
	GameState.energy = 100.0
	GameState.exercise_at_park()
	_check(is_equal_approx(GameState.energy, 82.0), "锻炼应消耗体力")
	_check(ProgressionManager.fitness_sessions == 1, "锻炼应留下隐藏成长")


func _test_market_economy() -> void:
	GameState.reset_new_game()
	MarketEconomyManager.hot_category = "photo"
	MarketEconomyManager.cold_category = "metal"
	InventoryManager.add_item("film_camera", 1)
	var hot_price := MarketEconomyManager.get_current_price("film_camera")
	_check(hot_price > int(InventoryManager.get_item("film_camera").get("sell_price", 0)), "热门品类应按基础价偏高成交")
	var money_before := GameState.money
	_check(MarketEconomyManager.sell_now("film_camera"), "旧货应能按当日行情立即出售")
	_check(GameState.money > money_before, "立即出售后应收到现金")
	InventoryManager.add_item("old_radio", 1)
	_check(MarketEconomyManager.consign_item("old_radio"), "旧货应能放进摊位寄卖")
	_check(MarketEconomyManager.consignment_orders.size() == 1, "寄卖柜应记录订单")
	GameState.money = 10000
	_check(MarketEconomyManager.upgrade_stall(), "赚到钱后应能扩大摊位")
	_check(MarketEconomyManager.stall_tier == 1, "摊位应提升到固定摊位")
	_check(MarketEconomyManager.get_consignment_slots() == 4, "固定摊位应增加寄卖容量")
	_check(MarketEconomyManager.is_site_unlocked("sealed_workshop"), "摊位规模应解锁封存车间")

func _test_expedition() -> void:
	GameState.reset_new_game()
	GameState.energy = 100.0
	_check(MarketEconomyManager.is_site_unlocked("alley_basement"), "旧楼地下室应作为免费入口开放")
	_check(ExpeditionManager.start_run("alley_basement"), "应能进入旧址探索")
	_check(ExpeditionManager.active, "进入后探索状态应激活")
	_check(not ExpeditionManager.get_area_spawns().is_empty(), "旧址内应生成旧物点")
	_check(is_equal_approx(TimeSystem.time_scale, 0.05), "探索时应放慢生活时间")
	var spawn: Dictionary = ExpeditionManager.get_area_spawns()[0]
	var item_id := str(spawn.get("item_id", ""))
	_check(ExpeditionManager.collect_spawn(str(spawn.get("spawn_id", ""))), "应能拾取旧址旧物")
	_check(InventoryManager.get_count(item_id) >= 1, "旧址旧物应进入背包")
	ExpeditionManager.end_run("returned")
	_check(not ExpeditionManager.active, "离开旧址后探索状态应结束")
	_check(GameState.current_area == "market", "离开旧址应回到旧货市场")
	_check(is_equal_approx(TimeSystem.time_scale, 1.0), "离开旧址后时间速度应恢复")

func _test_save_and_load() -> void:
	GameState.reset_new_game()
	GameState.money = 777
	GameState.energy = 61.0
	GameState.hidden_luck = 8.0
	InventoryManager.items.clear()
	InventoryManager.add_item("water", 3)
	InventoryManager.add_item("vinyl_record", 1)
	CollectionManager.discovered["vinyl_record"] = true
	CollectionManager.total_collected = 9
	RelationshipManager.affinity["chen"] = 6
	ProgressionManager.study_sessions = 4
	TimeSystem.current_day = 12
	TimeSystem.minute_of_day = 18 * 60
	WeatherSystem.current_weather_id = "rain"
	MarketEconomyManager.total_sales = 1234
	MarketEconomyManager.stall_tier = 1
	ExpeditionManager.active = false
	ExpeditionManager.site_id = "old_pipe"
	_check(SaveManager.save_game(false), "应能写入扩展测试存档")
	GameState.money = 1
	GameState.hidden_luck = 0.0
	InventoryManager.items.clear()
	CollectionManager.discovered.clear()
	RelationshipManager.affinity.clear()
	ProgressionManager.study_sessions = 0
	TimeSystem.current_day = 1
	WeatherSystem.current_weather_id = "sunny"
	_check(SaveManager.load_game(false), "应能读取扩展测试存档")
	_check(GameState.money == 777 and is_equal_approx(GameState.hidden_luck, 8.0), "读档应恢复金钱和隐藏状态")
	_check(InventoryManager.get_count("water") == 3 and InventoryManager.get_count("vinyl_record") == 1, "读档应恢复普通物品和旧物")
	_check(bool(CollectionManager.discovered.get("vinyl_record", false)), "读档应恢复旧物册")
	_check(int(RelationshipManager.affinity.get("chen", 0)) == 6, "读档应恢复人物关系")
	_check(ProgressionManager.study_sessions == 4, "读档应恢复隐藏成长")
	var restored_spawns := CollectionManager.get_area_spawns("street")
	_check(not restored_spawns.is_empty() and typeof(restored_spawns[0].get("position")) == TYPE_VECTOR2, "读档后摸金点坐标应保持 Vector2")
	_check(TimeSystem.current_day == 12 and WeatherSystem.current_weather_id == "rain", "读档应恢复时间与天气")
	_check(MarketEconomyManager.total_sales == 1234 and MarketEconomyManager.stall_tier == 1, "读档应恢复旧货行情进度")
	_check(ExpeditionManager.site_id == "old_pipe", "读档应恢复旧址记录")

func _test_30_day_cycle() -> void:
	GameState.reset_new_game()
	GameState.money = 3200
	for index in range(29):
		TimeSystem.sleep_to_next_morning(7)
	_check(TimeSystem.current_day == 30, "29 次换日后应进入第 30 天")
	_check(GameState.money == 2400, "第 30 天应自动扣除 800 房租")
	_check(GameState.rent_arrears == 0, "余额充足时不应产生欠租")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)