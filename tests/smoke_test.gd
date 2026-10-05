extends Node

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	StoryManager.set_random_events_enabled(false)
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
	_test_calendar_and_seasons()
	_test_relationship_and_gift()
	_test_study_and_exercise()
	_test_market_economy()
	_test_expedition()
	_test_business_trade()
	_test_business_recipes_and_upgrade()
	_test_kitchen_shift()
	_test_bank_and_lottery()
	_test_temp_hire_and_relationship_effects()
	_test_save_and_load()
	_test_30_day_cycle()

func _test_initial_state() -> void:
	GameState.reset_new_game()
	WeatherSystem.current_weather_id = "sunny"
	_check(GameState.money == GameState.STARTING_MONEY, "初始金钱应为 320")
	_check(is_equal_approx(GameState.energy, 100.0), "初始体力应为满值")
	_check(TimeSystem.current_day == 1, "初始日期应为第 1 天")
	_check(TimeSystem.minute_of_day == 420, "初始时间应为 07:00")
	_check(CollectionManager.total_collected == 0, "开局不应预置彩蛋旧物")
	_check(not TreasureManager.get_hint().is_empty(), "旧物册应提示彩蛋是低频相遇")
	_check(ConfigDB.get_row("weather", WeatherSystem.current_weather_id).size() > 0, "每日天气应来自配置表")

func _test_factory_shift() -> void:
	GameState.reset_new_game()
	WeatherSystem.current_weather_id = "sunny"
	TimeSystem.current_day = 1
	TimeSystem.minute_of_day = 7 * 60
	GameState.money = 320
	GameState.energy = 100.0
	_check(CareerManager.apply_for_job("factory"), "应聘工厂后应进入工厂职业线")
	GameState.work_factory_shift()
	_check(GameState.money >= 500, "完成一次工厂班次应获得工资和状态加成")
	_check(is_equal_approx(GameState.energy, 88.0), "晴天完成工厂班次应消耗 12 体力")
	_check(TimeSystem.minute_of_day == 10 * 60, "3 小时班次应从 07:00 推进到 10:00")

func _test_clerk_shift() -> void:
	GameState.reset_new_game()
	var money_before := GameState.money
	GameState.work_clerk_shift()
	_check(GameState.money == money_before, "便利店不应再提供第三条长期职业线")

func _test_collection_system() -> void:
	GameState.reset_new_game()
	_check(_total_collection_spawns() == 0, "城里不应再有固定刷新的摸金点")
	var item_id := TreasureManager.force_find_once("street")
	_check(not item_id.is_empty(), "低概率彩蛋应能在街头偶遇一件旧物")
	_check(InventoryManager.get_count(item_id) >= 1, "偶遇的旧物应自动收进背包")
	_check(bool(CollectionManager.discovered.get(item_id, false)), "偶遇后应记入旧物册")
	_check(TreasureManager.get_today_count() == 1, "同一天内彩蛋应被计数")
	_check(TreasureManager.get_today_count() >= 1, "同一天彩蛋应被计数")


func _total_collection_spawns() -> int:
	var total := 0
	for area_id in CollectionManager.AREA_POINTS:
		total += CollectionManager.get_area_spawns(area_id).size()
	return total

func _test_weather_system() -> void:
	var row := ConfigDB.get_row("weather", WeatherSystem.current_weather_id)
	_check(not row.is_empty(), "天气 ID 应能在配置中查到")
	_check(WeatherSystem.get_collection_bonus() >= 0.0, "天气摸金加成应为非负数")
	_check(WeatherSystem.get_work_energy_multiplier() >= 1.0, "不同天气应会影响工作体力消耗")


func _test_calendar_and_seasons() -> void:
	TimeSystem.current_day = 1
	_check(CalendarManager.get_date_text() == "2026年1月1日", "游戏第一天应为 2026 年 1 月 1 日")
	_check(CalendarManager.get_season_id() == "winter", "一月应属于冬季")
	_check(CalendarManager.get_festival_name() == "元旦", "第一天应是元旦节日")
	TimeSystem.current_day = 34
	_check(CalendarManager.get_festival_name() == "清明节", "第 34 个年历日应为清明节")
	_check(CalendarManager.get_collection_bonus() > 0.0, "节日应提高彩蛋出现机会")
	TimeSystem.current_day = 151
	_check(CalendarManager.get_season_id() == "summer", "六月应属于夏季")
	_check(is_equal_approx(TimeSystem.real_seconds_per_game_minute, 2.0), "默认时间流速应放缓到每 2 秒一分钟")

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
	_check(not TreasureManager.get_hint().is_empty(), "旧址偶遇应受彩蛋系统控制")
	_check(is_equal_approx(TimeSystem.time_scale, 0.05), "探索时应放慢生活时间")
	var item_id := TreasureManager.force_find("ruins", "uncommon")
	_check(not item_id.is_empty(), "旧址偶遇应能摸到一件旧物")
	_check(InventoryManager.get_count(item_id) >= 1, "旧址旧物应进入背包")
	ExpeditionManager.end_run("returned")
	_check(not ExpeditionManager.active, "离开旧址后探索状态应结束")
	_check(GameState.current_area == "market", "离开旧址应回到旧货市场")
	_check(is_equal_approx(TimeSystem.time_scale, 1.0), "离开旧址后时间速度应恢复")


func _test_business_trade() -> void:
	GameState.reset_new_game()
	BusinessManager.price_modifiers["egg"] = -0.15
	var buy_price := BusinessManager.get_buy_price("egg")
	GameState.money = 1000
	_check(BusinessManager.buy_goods("egg", 5), "低价时应该能买入鸡蛋")
	_check(BusinessManager.get_stock("egg") == 9, "买入后鸡蛋库存应增加")
	BusinessManager.price_modifiers["egg"] = 0.15
	var money_before_sale := GameState.money
	_check(BusinessManager.sell_goods("egg", 5), "高价时应该能卖出库存鸡蛋")
	_check(GameState.money > money_before_sale, "买低卖高应产生现金收益")
	_check(BusinessManager.trade_profit > 0, "价差交易应记录正收益")
	BusinessManager.goods_stock.clear()
	BusinessManager.average_cost.clear()
	BusinessManager.price_modifiers["egg"] = 0.18
	BusinessManager.buy_goods("egg", 5)
	BusinessManager.price_modifiers["egg"] = -0.18
	var profit_before_loss := BusinessManager.trade_profit
	BusinessManager.sell_goods("egg", 5)
	_check(BusinessManager.trade_profit < profit_before_loss, "高位买入后低位卖出应产生亏损可能")

func _test_business_recipes_and_upgrade() -> void:
	GameState.reset_new_game()
	BusinessManager.labor_stock = 10
	BusinessManager.brain_stock = 10
	BusinessManager.goods_stock = {"rice": 3, "egg": 4}
	_check(BusinessManager.consume_recipe_inputs("egg_rice"), "蛋炒饭应能消耗食材、劳力和脑力")
	_check(BusinessManager.get_stock("rice") == 2 and BusinessManager.get_stock("egg") == 2, "做菜应按配方扣减库存")
	_check(BusinessManager.labor_stock == 9 and BusinessManager.brain_stock == 9, "做菜应扣减劳力和脑力")
	var revenue := BusinessManager.register_recipe_sale("egg_rice", 2)
	_check(revenue > 0, "出餐应产生销售收入")
	BusinessManager.customers_served = 12
	GameState.money = 2000
	_check(BusinessManager.upgrade_business(), "达到客流条件后应能扩大店面")
	_check(BusinessManager.business_level == 1, "店面应升级到固定档口")

func _test_kitchen_shift() -> void:
	GameState.reset_new_game()
	TimeSystem.minute_of_day = 12 * 60
	MarketPhaseManager.force_refresh()
	BusinessManager.goods_stock = {"rice": 8, "egg": 12, "greens": 8, "tea": 4, "lemon": 6, "ice": 4, "noodles": 4, "beef": 4}
	BusinessManager.labor_stock = 12
	BusinessManager.brain_stock = 12
	var money_before := GameState.money
	_check(KitchenManager.start_shift(), "午市有库存时应能开始营业")
	_check(KitchenManager.active and KitchenManager.orders.size() >= 2, "营业开始时应有订单")
	KitchenManager.orders[0]["recipe_id"] = "egg_rice"
	_check(KitchenManager.place_recipe("egg_rice", 0), "菜单应能放进备料台并消耗库存")
	var prep_station: Dictionary = KitchenManager.stations[0]
	prep_station["progress"] = prep_station["duration"]
	KitchenManager._update_stations(0.0)
	_check(str(prep_station["state"]) == "stage_ready", "备料完成后应停在半成品状态")
	_check(KitchenManager.advance_station(0), "点击备料台应把半成品移到托盘")
	_check(KitchenManager.staging.size() == 1, "半成品应可暂存等待手动搬运")
	var fryer_index := _first_station_of_type("fryer")
	_check(fryer_index >= 0 and KitchenManager.load_staging(0, fryer_index), "半成品应能手动移到油锅")
	var fryer: Dictionary = KitchenManager.stations[fryer_index]
	fryer["progress"] = fryer["duration"]
	KitchenManager._update_stations(0.0)
	_check(str(fryer["state"]) == "stage_ready", "下锅完成后应等待挪到出餐台")
	_check(KitchenManager.advance_station(fryer_index), "点击油锅应把半成品移回托盘")
	var serve_index := _first_station_of_type("serve")
	_check(serve_index >= 0 and KitchenManager.load_staging(0, serve_index), "半成品应能手动移到出餐台")
	var serve_station: Dictionary = KitchenManager.stations[serve_index]
	serve_station["progress"] = serve_station["duration"]
	KitchenManager._update_stations(0.0)
	_check(str(serve_station["state"]) == "ready", "出餐台完成后应等待递菜")
	_check(KitchenManager.advance_station(serve_index), "有匹配订单时应能出餐")
	_check(GameState.money > money_before, "完成出餐后应收到营业收入")
	var speed_before := KitchenManager.get_station_speed_multiplier("fryer")
	GameState.money = 5000
	_check(KitchenManager.upgrade_station("fryer"), "设备升级应能单独升级油锅")
	_check(KitchenManager.get_station_speed_multiplier("fryer") > speed_before, "升级油锅应只加快油锅")
	_check(KitchenManager.get_station_speed_multiplier("steamer") == 1.0, "升级油锅不应加快蒸笼")
	KitchenManager.end_shift()

func _first_station_of_type(station_type: String) -> int:
	for index in range(KitchenManager.stations.size()):
		if str(KitchenManager.stations[index].get("type", "")) == station_type:
			return index
	return -1

func _test_bank_and_lottery() -> void:
	GameState.reset_new_game()
	GameState.money = 1000
	_check(FinanceManager.deposit(300), "应能把现金存进银行")
	_check(FinanceManager.savings == 300 and GameState.money == 700, "存款后银行余额和现金应同步变化")
	var interest_before := FinanceManager.total_interest
	FinanceManager.begin_new_day(TimeSystem.current_day + 1)
	_check(FinanceManager.total_interest > interest_before, "过一天后银行存款应产生利息")
	var savings_before_withdraw := FinanceManager.savings
	_check(FinanceManager.withdraw(100), "应能从银行取回资金")
	_check(FinanceManager.savings == savings_before_withdraw - 100, "取款后银行余额应减少")
	var money_before_ticket := GameState.money
	var lottery := FinanceManager.buy_lottery(1)
	_check(int(lottery["spent"]) == 10, "一张彩票应固定花费 10 元")
	_check(GameState.money == money_before_ticket - 10 + int(lottery["won"]), "彩票扣款和中奖应正确入账")


func _test_temp_hire_and_relationship_effects() -> void:
	GameState.reset_new_game()
	GameState.money = 1000
	BusinessManager.labor_stock = BusinessManager.get_labor_capacity()
	var labor_before := BusinessManager.labor_stock
	var capacity_before := BusinessManager.get_labor_capacity()
	_check(BusinessManager.restock_labor(), "满劳力时仍应能花钱招临时帮手")
	_check(BusinessManager.labor_stock == labor_before + 3, "临时帮手应立刻增加劳力库存")
	_check(BusinessManager.get_labor_capacity() == capacity_before + 3, "临时帮手应增加当天劳力上限")
	RelationshipManager.affinity["mei"] = 10
	RelationshipManager.affinity["lin"] = 18
	_check(RelationshipManager.get_supplier_discount() > 0.0, "熟人关系应提供进货折扣")
	_check(RelationshipManager.get_market_bonus() > 0.0, "熟客网络应改善旧货成交价")
	_check(RelationshipManager.get_patience_bonus() > 0.0, "熟客网络应增加订单耐心")
	_check(RelationshipManager.get_effect_text("lin").contains("老朋友"), "老朋友关系应显示明确经营效果")
	RelationshipManager.affinity["chen"] = 17
	RelationshipManager.talked_today.clear()
	InventoryManager.reset_new_game()
	RelationshipManager.talk_to("chen")
	_check(RelationshipManager.get_affinity("chen") == 18, "持续交谈应达到老朋友阶段")
	_check(InventoryManager.get_count("brass_compass") == 1, "老朋友阶段应赠送对应稀有旧物")

func _test_save_and_load() -> void:
	GameState.reset_new_game()
	GameState.money = 777
	GameState.energy = 61.0
	InventoryManager.reset_new_game()
	TreasureManager.restore({})
	var saved_treasure := TreasureManager.force_find("street", "uncommon")
	GameState.hidden_luck = 8.0
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
	BusinessManager.total_revenue = 3456
	BusinessManager.labor_stock = 7
	FinanceManager.savings = 789
	ExpeditionManager.active = false
	ExpeditionManager.site_id = "old_pipe"
	_check(SaveManager.save_game(false), "应能写入扩展测试存档")
	GameState.money = 1
	GameState.hidden_luck = 0.0
	InventoryManager.reset_new_game()
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
	_check(TreasureManager.get_today_count() == 1, "读档后应恢复当日彩蛋计数")
	_check(not saved_treasure.is_empty() and bool(CollectionManager.discovered.get(saved_treasure, false)), "读档后应恢复彩蛋旧物")
	_check(TimeSystem.current_day == 12 and WeatherSystem.current_weather_id == "rain", "读档应恢复时间与天气")
	_check(MarketEconomyManager.total_sales == 1234 and MarketEconomyManager.stall_tier == 1, "读档应恢复旧货行情进度")
	_check(ExpeditionManager.site_id == "old_pipe", "读档应恢复旧址记录")
	_check(BusinessManager.total_revenue == 3456 and BusinessManager.labor_stock == 7, "读档应恢复经营与库存数据")
	_check(FinanceManager.savings == 789, "读档应恢复银行存款")

func _test_30_day_cycle() -> void:
	StoryManager.set_random_events_enabled(false)
	GameState.reset_new_game()
	GameState.money = 3200
	for index in range(29):
		TimeSystem.sleep_to_next_morning(7)
	_check(TimeSystem.current_day == 30, "29 次换日后应进入第 30 天")
	_check(GameState.money == 1600, "第 30 天应扣除 800 房租和 4 次 200 周账单后剩 1600")
	_check(GameState.rent_arrears == 0, "余额充足时不应产生欠租")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
