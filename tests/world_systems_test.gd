extends Node

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	StoryManager.set_random_events_enabled(false)
	_test_farm()
	_test_night_market()
	_test_mod_interface()
	_test_pet()
	_test_room()
	_test_inventory_storage()
	_test_staff()
	_test_content_reachability()
	_test_breakfast()
	_test_pipeline_phases()
	_test_recruitment_and_resignation()
	_test_auto_save_fallback()
	_test_career_and_clothing()
	_test_festival_and_passive_business()
	_test_map_hubs()
	_test_story_and_random_events()
	_test_collectible_catalog()
	_test_presentation_interfaces()
	_test_fishing_loop()
	_test_housing_upgrades()
	_test_travel_and_postcards()
	_test_enterprise_routes()
	_test_hidden_achievements()
	_test_family_route()
	_test_wellbeing_state()
	_test_unlock_levels()
	_test_medical_services()
	_test_education_courses()
	_test_career_performance_layoff()
	_test_job_trial_flow()
	_test_life_endings()
	_test_hobbies()
	_test_photo_album()
	_test_coop_and_platform_interfaces()
	_test_npc_schedule()
	_test_areas()
	_test_art_and_audio_pipeline()
	AudioManager.shutdown()
	await get_tree().process_frame
	if failures.is_empty():
		print("WORLD_SYSTEMS_PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("WORLD_SYSTEMS_FAIL: %s" % f)
		get_tree().quit(1)

func _test_farm() -> void:
	GameState.reset_new_game()
	TimeSystem.current_day = 75
	GameState.money = 5000
	_check(FarmManager.unlock_farm(), "应能租下农场")
	_check(FarmManager.has_farm, "租下后农场应可用")
	var crops := FarmManager.get_available_crops()
	_check(not crops.is_empty(), "当季应有可种作物")
	var crop_id := str(crops[0])
	_check(FarmManager.plant(0, crop_id), "应能种下当季作物")
	var before := BusinessManager.get_stock(str(FarmManager.get_crop_row(crop_id).get("goods_id", "")))
	FarmManager.water(0)
	for i in range(6):
		FarmManager.begin_new_day(2 + i)
		if str(FarmManager.get_plot_status(0).get("stage", "")) == "ripe":
			break
	_check(str(FarmManager.get_plot_status(0).get("stage", "")) == "ripe", "浇过水的作物应能成熟")
	_check(FarmManager.harvest(0), "成熟后应能收割")
	var gid := str(FarmManager.get_crop_row(crop_id).get("goods_id", ""))
	_check(BusinessManager.get_stock(gid) > before, "收割的原料应直接进餐馆仓库")
	GameState.money = 5000
	_check(FarmManager.upgrade_tool("hoe"), "农场工具应能用现金升级")
	BusinessManager.price_modifiers["greens"] = 0.0
	WeatherSystem.current_weather_id = "sunny"
	var sunny_price := BusinessManager.get_sell_price("greens")
	WeatherSystem.current_weather_id = "rain"
	_check(BusinessManager.get_sell_price("greens") > sunny_price, "雨天应提高叶菜收购价，农场与市场联动")
	FarmManager.select_crop(crop_id)
	_check(FarmManager.plant(1, crop_id), "应能用当前选中作物继续种植")
	FarmManager.begin_new_day(TimeSystem.current_day + 1)
	_check(bool(FarmManager.plots[1].get("watered", false)), "雨天应在次日自动浇灌作物")
	GameState.money = 3000
	_check(FarmManager.buy_animal("chicken_house"), "农场应能买下鸡舍")
	_check(FarmManager.feed_animal("chicken_house"), "鸡舍应能消耗或购买饲料喂养")
	var egg_before := BusinessManager.get_stock("egg")
	FarmManager.begin_new_day(TimeSystem.current_day + 2)
	_check(bool(FarmManager.animal_product_ready.get("chicken_house", false)), "喂养后的家畜应在新一天产出")
	_check(FarmManager.collect_animal_product("chicken_house"), "家畜产物应能收取")
	_check(BusinessManager.get_stock("egg") > egg_before, "鸡蛋应直接进入餐馆仓库")

func _test_night_market() -> void:
	GameState.reset_new_game()
	GameState.money = 800
	GameState.energy = 100.0
	TimeSystem.minute_of_day = 19 * 60
	var chicken_before := BusinessManager.get_stock("chicken")
	_check(NightMarketManager.buy_stall("bbq_skewer"), "夜市应能用现金补充餐馆食材")
	_check(BusinessManager.get_stock("chicken") >= chicken_before + 2, "夜市食材应直接进入仓库")
	var money_before := GameState.money
	_check(NightMarketManager.work_stall(), "夜市应能帮摊主守一小时")
	_check(GameState.money > money_before and NightMarketManager.worked_today, "夜市帮工应结算工钱且每天一次")
	TimeSystem.minute_of_day = 10 * 60
	_check(not NightMarketManager.is_open(), "白天夜市应处于关闭状态")

func _test_mod_interface() -> void:
	_remove_test_mod()
	var mod_dir := ProjectSettings.globalize_path("user://mods/__codex_test_mod__")
	var data_dir := mod_dir.path_join("data")
	DirAccess.make_dir_recursive_absolute(data_dir)
	var manifest := FileAccess.open(mod_dir.path_join("mod.json"), FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(JSON.stringify({"id": "__codex_test_mod__", "name": "测试模组", "version": "1.0.0", "game_version": "0.5.0", "description": "自动化测试"}))
		manifest.close()
	var csv := FileAccess.open(data_dir.path_join("items.csv"), FileAccess.WRITE)
	if csv != null:
		csv.store_string("item_id,name,description,kind,price,usable,energy,use_hint\ntest_mod_item,模组饭,来自本地模组的一份测试食物。,food,3,true,12,只在模组测试里使用。\n")
		csv.close()
	ModManager.reload()
	_check(not ConfigDB.get_row("items", "test_mod_item").is_empty(), "模组 CSV 应能覆盖或新增配置行")
	_check(not InventoryManager.get_item("test_mod_item").is_empty(), "模组物品应刷新到运行时目录")
	_check(ModManager.get_mod_lines().size() == 1, "模组管理器应记录已加载模组")
	_remove_test_mod()
	ModManager.reload()
	_check(ConfigDB.get_row("items", "test_mod_item").is_empty(), "移除模组后应恢复基础配置")

func _remove_test_mod() -> void:
	var mod_dir := ProjectSettings.globalize_path("user://mods/__codex_test_mod__")
	var data_dir := mod_dir.path_join("data")
	for file_name in ["mod.json"]:
		var file_path := mod_dir.path_join(file_name)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	var csv_path := data_dir.path_join("items.csv")
	if FileAccess.file_exists(csv_path):
		DirAccess.remove_absolute(csv_path)
	if DirAccess.dir_exists_absolute(data_dir):
		DirAccess.remove_absolute(data_dir)
	if DirAccess.dir_exists_absolute(mod_dir):
		DirAccess.remove_absolute(mod_dir)

func _test_pet() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	InventoryManager.add_item("pet_feed", 5)
	InventoryManager.add_item("pet_toy", 2)
	InventoryManager.add_item("pet_medicine", 2)
	_check(PetManager.adopt("cat_huang"), "应能收养宠物")
	_check(PetManager.has_pet("cat_huang"), "收养后应记录宠物")
	var before_food := InventoryManager.get_count("pet_feed")
	_check(PetManager.feed("cat_huang"), "应能喂食")
	_check(InventoryManager.get_count("pet_feed") == before_food - 1, "喂食应消耗宠物粮")
	_check(PetManager.play("cat_huang"), "应能陪宠物玩")
	_check(InventoryManager.get_count("pet_toy") == 1, "陪玩应消耗逗猫棒")
	_check(PetManager.help("cat_huang"), "宠物没精神时应能用营养膏")
	PetManager.adopted["cat_huang"]["growth"] = 100.0
	PetManager.adopted["cat_huang"]["fullness"] = 100.0
	PetManager.adopted["cat_huang"]["energy"] = 100.0
	PetManager.adopted["cat_huang"]["mood"] = 100.0
	PetManager.adopted["cat_huang"]["clean"] = 100.0
	_check(PetManager.get_bonus("patience") > 0.0, "受照顾的宠物应带来经营加成")

func _test_room() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	var ok := RoomManager.buy("lamp_warm")
	_check(ok, "应能买家具")
	_check(RoomManager.has_owned("lamp_warm"), "买下后应拥有家具")
	_check(RoomManager.is_placed("lamp_warm"), "买下后应立即摆放")
	_check(RoomManager.get_bonus("study") > 0.0, "家具应带来加成")
	_check(RoomManager.place_at("lamp_warm", "rug_alt"), "应能手动把家具挪到指定位置")
	_check(RoomManager.get_slot_for("lamp_warm") == "rug_alt", "手动位置应被记录")
	var before_move := RoomManager.get_furniture_position("lamp_warm")
	_check(RoomManager.nudge_furniture("lamp_warm", Vector2(0.04, 0.02)), "应能微调家具位置")
	var after_move := RoomManager.get_furniture_position("lamp_warm")
	_check(after_move.x > before_move.x and after_move.y > before_move.y, "微调后位置应真实变化")
	_check(RoomManager.set_furniture_position("lamp_warm", Vector2(0.5, 0.5)), "应能在房间里直接点地面移动家具")
	_check(RoomManager.get_furniture_position("lamp_warm").is_equal_approx(Vector2(0.5, 0.5)), "场景移动应写入家具坐标")
	_check(RoomManager.rotate_furniture("lamp_warm", 30), "应能旋转家具")
	_check(RoomManager.get_furniture_rotation("lamp_warm") == 30, "旋转角度应被记录")
	_check(RoomManager.save_layout("夜读"), "应能保存一套布置")
	var saved_position := RoomManager.get_furniture_position("lamp_warm")
	var saved_rotation := RoomManager.get_furniture_rotation("lamp_warm")
	RoomManager.buy("bed_soft")
	_check(RoomManager.nudge_furniture("lamp_warm", Vector2(-0.08, -0.08)), "切换布置前应能继续调整家具")
	_check(RoomManager.rotate_furniture("lamp_warm", 60), "切换布置前应能继续调整朝向")
	_check(RoomManager.load_layout("夜读"), "应能切换回保存过的布置")
	_check(RoomManager.get_slot_for("lamp_warm") == "rug_alt", "切换布置应恢复家具位置")
	_check(RoomManager.get_furniture_position("lamp_warm").is_equal_approx(saved_position), "切换布置应恢复自由摆放坐标")
	_check(RoomManager.get_furniture_rotation("lamp_warm") == saved_rotation, "切换布置应恢复家具朝向")
	var study_bonus_before := RoomManager.get_bonus("study")
	_check(RoomManager.renovate("quiet_study"), "应能花钱做房间装修")
	_check(RoomManager.get_bonus("study") > study_bonus_before, "装修应提供真实生活加成")
	_check(RoomManager.get_save_data().has("renovation_style"), "装修风格应进入存档")

func _test_inventory_storage() -> void:
	GameState.reset_new_game()
	InventoryManager.add_item("bread", 5)
	_check(CollectionManager.has_seen_item("bread"), "拿到的物品应进入城市图鉴的物品记录")
	SceneRouter.travel_to("street", "encyclopedia_test")
	_check(CollectionManager.has_seen_area("street"), "走过的场景应进入城市图鉴")
	SceneRouter.travel_to("home", "default")
	CollectionManager.record_recipe_seen("egg_rice")
	_check(CollectionManager.has_seen_recipe("egg_rice"), "做过的菜应进入美食图鉴")
	_check(InventoryManager.get_count("bread") == 5, "背包应能正常堆叠物品")
	_check(InventoryManager.get_hotbar_lines().size() == InventoryManager.HOTBAR_SIZE, "快捷栏应固定格数")
	_check(InventoryManager.get_backpack_slots().size() == InventoryManager.BACKPACK_BASE, "初始不应额外赠送背包格")
	_check(InventoryManager.get_unlocked_inventory_size() == InventoryManager.HOTBAR_SIZE, "新游戏应只有星露谷式首行 12 格")
	InventoryManager.add_item("water", 1)
	_check(InventoryManager.move_slot("inventory", 0, "inventory", 1), "应能拖动整理背包格位")
	_check(str(InventoryManager.get_slot("inventory", 1).get("item_id", "")) == "bread", "拖动后物品应稳定停留在目标格")
	_check(InventoryManager.move_slot("inventory", 0, "inventory", 1), "应能把格位换回")
	InventoryManager.remove_item("water", 1)
	_check(InventoryManager.split_stack("inventory", 0), "右键应能把一叠物品拆半")
	_check(InventoryManager.get_slot("inventory", 0).get("count", 0) == 3 and InventoryManager.get_slot("inventory", 1).get("count", 0) == 2, "拆半后两格数量应正确")
	_check(InventoryManager.move_slot("inventory", 0, "inventory", 1), "同类物品拖到一起应合并堆叠")
	_check(InventoryManager.get_slot("inventory", 0).get("count", 0) == 0 and InventoryManager.get_slot("inventory", 1).get("count", 0) == 5, "合并后应保留目标格并清空来源格")
	_check(InventoryManager.STORAGE_SIZE == 36, "出租屋木箱应对齐星露谷 36 格")
	_check(InventoryManager.deposit_to_storage("bread", 2), "应能把物品存进出租屋木箱")
	_check(InventoryManager.get_count("bread") == 3, "存入木箱后背包数量应减少")
	_check(int(InventoryManager.get_storage_lines()[0].get("count", 0)) == 2, "木箱应记录存放数量")
	_check(InventoryManager.transfer_slot_to("storage", 0, "inventory"), "应能整叠从木箱取回")
	_check(InventoryManager.get_count("bread") == 5, "整叠取回后背包数量应恢复")
	_check(InventoryManager.deposit_to_storage("bread", 2), "整叠测试后应能再次存入")
	_check(InventoryManager.withdraw_from_storage("bread", 1), "应能从木箱取回单件物品")
	_check(InventoryManager.get_count("bread") == 4, "取出后背包数量应恢复")
	GameState.money = 12000
	_check(InventoryManager.upgrade_backpack(), "应能花钱扩容背包")
	_check(InventoryManager.get_backpack_slots().size() == InventoryManager.BACKPACK_BASE + InventoryManager.BACKPACK_STEP, "扩容后背包格数应增加")
	var money_before_shipping := GameState.money
	_check(InventoryManager.deposit_to_shipping("bread", 1), "应能把物品放进门口收购箱")
	var shipped_count := InventoryManager.get_count("bread")
	_check(not InventoryManager.withdraw_from_shipping("bread", 1), "收购箱放进去后不应允许取回")
	_check(InventoryManager.get_count("bread") == shipped_count, "拒绝取回应保持背包数量不变")
	_check(InventoryManager.get_shipping_estimate() > 0, "收购箱应估算次日收入")
	var sold := InventoryManager.sell_shipping_bin()
	_check(sold > 0 and GameState.money == money_before_shipping + sold, "收购箱应在次日自动结算")
	_check(AchievementManager.unlocked.has("shipping_sale"), "第一次收购箱结算应留下见闻")

func _test_staff() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	RelationshipManager.affinity["mei"] = 30
	_check(StaffManager.hire("mei"), "好感够时应能雇人")
	_check(StaffManager.get_bonus("kitchen_speed") > 0.0, "驻店帮手应带来经营增益")
	_check(StaffManager.get_daily_upkeep() > 0, "驻店帮手应有每日工钱")
	var generated := StaffManager.refresh_candidates("labor_market")
	_check(generated.size() == 3, "招人渠道应一次给出多名不同候选")
	_check(generated[0].has("special_trait"), "候选员工应有额外能力字段")
	_check(str(generated[0].get("biography", "")).length() > 8, "候选员工应有独立人物来历")
	_check(str(generated[0].get("portrait_id", "")).begins_with("candidate_"), "候选员工应绑定独立立绘资源")
	var candidate_names: Array[String] = []
	for candidate in generated:
		candidate_names.append(str(candidate.get("name", "")))
	_check(candidate_names.size() == 3 and candidate_names[0] != candidate_names[1] and candidate_names[1] != candidate_names[2] and candidate_names[0] != candidate_names[2], "同一批候选应避免同名")
	_check(PresentationManager.find_npc_id_by_name(str(generated[0].get("name", ""))) == str(generated[0].get("portrait_id", "")), "候选姓名应能自然映射到独立头像")
	_check(StaffManager._trait_effect({"traits": ["quick_hands"]}, "kitchen_speed") > 0.0, "候选员工额外能力应真实影响经营")
	_check(StaffManager.get_traits_text(["quick_hands"]) == "手快", "额外能力应能用生活化文字说明")
	TimeSystem.current_day = 12
	var referral_line := StaffManager.receive_npc_referral("mei")
	_check(not referral_line.is_empty(), "熟人聊天应能自然带出招工线索")
	_check(StaffManager.has_pending_candidate(), "招工线索应指向具体候选")
	_check(AchievementManager.unlocked.has("referral_lead"), "自然发现招工线索应留下见闻")
	var pending_id := StaffManager.pending_candidate_id
	StaffManager.handle_labor_market()
	_check(StaffManager.hired.has(pending_id), "劳务市场场景点击应能直接谈成候选")
	_check(AchievementManager.unlocked.has("referral_trusted"), "通过熟人推荐招人应解锁隐藏见闻")

func _test_content_reachability() -> void:
	StaffManager.reset_new_game()
	var template_ids: Array = ConfigDB.get_rows("staff_candidates").keys()
	var generated := StaffManager.refresh_candidates("labor_market", true, template_ids.size())
	var seen_templates: Dictionary = {}
	for candidate in generated:
		seen_templates[str(candidate.get("template_id", ""))] = true
	_check(seen_templates.size() == template_ids.size(), "所有候选模板都应能通过招工轮换到")
	HousingManager.reset_new_game()
	GameState.money = 999999
	var housing_ok := true
	for option in HousingManager.get_options():
		var tier := int(option.get("tier", 0))
		if tier <= 0:
			continue
		if not HousingManager.upgrade(str(option.get("id", ""))):
			housing_ok = false
	_check(housing_ok and HousingManager.current_tier >= 5, "所有住房档位都应能依次购买并触发")
	InventoryManager.reset_new_game()
	GameState.money = 999999
	var first_expand := InventoryManager.upgrade_backpack()
	var second_expand := InventoryManager.upgrade_backpack()
	_check(first_expand and second_expand, "背包两次扩容都应能通过现场机制触发")
	_check(InventoryManager.backpack_level == InventoryManager.BACKPACK_MAX_LEVEL, "背包扩容应能到达上限")
	for npc_id in ["fangjie", "ake", "teacher_yu"]:
		_check(not ConfigDB.get_row("npcs", npc_id).is_empty(), "%s 应进入常驻 NPC 表" % npc_id)
		_check(ConfigDB.get_rows("npc_schedule").has(npc_id), "%s 应有可达日程" % npc_id)
		_check(ConfigDB.get_rows("npc_dialogue").has(npc_id), "%s 应有可触发对话" % npc_id)

func _test_breakfast() -> void:
	GameState.reset_new_game()
	GameState.money = 3000
	TimeSystem.minute_of_day = 7 * 60
	for gid in ConfigDB.get_rows("goods"):
		BusinessManager.goods_stock[gid] = 20
	BusinessManager.labor_stock = 12
	BusinessManager.brain_stock = 10
	_check(KitchenManager.start_shift_for("breakfast_shop"), "清晨应能开早餐档")
	_check(KitchenManager.location_id == "breakfast_shop", "早餐档应记录地点")
	var breakfast_orders := 0
	for order in KitchenManager.orders:
		if "morning" in str(ConfigDB.get_row("recipes", order.get("recipe_id", "")).get("phases", "")).split("|", false):
			breakfast_orders += 1
	_check(breakfast_orders > 0, "早餐档应只派早餐订单")
	var first_order: Dictionary = KitchenManager.orders[0]
	_check(not str(first_order.get("customer_name", "")).is_empty(), "排队客人应有具体身份")
	_check(float(first_order.get("tip_rate", 0.0)) > 0.0, "不同客人应有小费倾向")
	_check(not str(first_order.get("leave_line", "")).is_empty(), "客人离开时应有符合身份的台词")
	var order_status: Dictionary = KitchenManager.get_orders_status()[0]
	_check(order_status.has("customer_name") and order_status.has("tip_rate"), "订单状态应携带客人信息")
	_check(order_status.has("patience_ratio"), "订单状态应提供可视化的耐心比例")
	_check(not KitchenManager.get_patience_text(float(order_status.get("patience_ratio", 0.0))).is_empty(), "耐心应用生活化文字表达")
	var customer_rows := ConfigDB.get_rows("customer_types")
	_check(customer_rows.size() >= 6, "应有足够多的顾客原型")
	for customer_id in customer_rows:
		var preferred := str(ConfigDB.get_row("customer_types", customer_id).get("preferred_recipe_ids", "")).split("|", false)
		_check(not preferred.is_empty(), "顾客原型应带菜品偏好")
		for preferred_recipe in preferred:
			_check(not ConfigDB.get_row("recipes", str(preferred_recipe)).is_empty(), "顾客偏好应指向真实菜谱")
	var office_customer := ConfigDB.get_row("customer_types", "office_worker")
	_check(KitchenManager._pick_customer_recipe(office_customer, ["soy_milk"]) == "soy_milk", "上班族应会按偏好点快捷早餐")
	_check(MarketPhaseManager.is_rush_minute(480, "morning"), "早高峰时间窗口应能识别")
	_check(KitchenManager.rush_active, "高峰开门时经营应进入客流高压状态")
	_check(MarketPhaseManager.get_rush_spawn_multiplier("morning") > 1.0, "高峰期应加快客人生成")
	_check(MarketPhaseManager.get_rush_tip_bonus("morning") > 0.0, "高峰期应提高顾客消费意愿")
	KitchenManager.max_combo = 5
	KitchenManager.end_shift()
	_check(AchievementManager.unlocked.has("rush_shift"), "顶住高峰应留下见闻")
	_check(AchievementManager.unlocked.has("combo_five"), "五连出餐应留下隐藏见闻")


func _test_pipeline_phases() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	for gid in ConfigDB.get_rows("goods"):
		BusinessManager.goods_stock[gid] = 20
	BusinessManager.labor_stock = 20
	BusinessManager.brain_stock = 20
	TimeSystem.minute_of_day = 7 * 60
	MarketPhaseManager.force_refresh()
	_check(KitchenManager.start_shift_for("breakfast_shop"), "早市应能开早餐店")
	var morning_menu := KitchenManager._candidate_recipes()
	_check("pork_bun" in morning_menu and "soy_milk" in morning_menu, "早市应有包子和豆浆")
	_check("egg_rice" not in morning_menu, "早市不应卖午市蛋炒饭")
	_check(KitchenManager.get_pipeline_text("pork_bun") != KitchenManager.get_pipeline_text("lemon_tea"), "不同商品应有不同工序链")
	var station_status := KitchenManager.get_stations_status()
	_check(not station_status.is_empty() and station_status[0].has("level"), "工位状态应提供可见升级等级")
	var first_station_type := str(station_status[0].get("type", ""))
	_check(KitchenManager.upgrade_station(first_station_type), "设备升级应只作用于对应工位")
	_check(int(KitchenManager.get_stations_status()[0].get("level", 0)) == 1, "升级后工位状态应同步等级")
	TimeSystem.minute_of_day = 12 * 60
	MarketPhaseManager.force_refresh()
	_check(not KitchenManager.active, "换市过渡应结束旧时段营业")
	_check(KitchenManager.orders.is_empty() and KitchenManager.staging.is_empty(), "换市应清空未完成订单和半成品")
	_check(KitchenManager.start_shift(), "午市应能开餐馆")
	var lunch_menu := KitchenManager._candidate_recipes()
	_check("egg_rice" in lunch_menu and "canteen_combo" in lunch_menu, "午市应有快餐菜单")
	KitchenManager.end_shift()
	TimeSystem.minute_of_day = 18 * 60
	MarketPhaseManager.force_refresh()
	_check(KitchenManager.start_shift(), "晚市应能开餐馆")
	var dinner_menu := KitchenManager._candidate_recipes()
	_check("roast_skewer" in dinner_menu and "sweet_soup" in dinner_menu, "晚市应有夜市菜单")
	KitchenManager.end_shift()

func _test_recruitment_and_resignation() -> void:
	GameState.reset_new_game()
	GameState.money = 10000
	var candidates := StaffManager.refresh_candidates("labor_market")
	_check(not candidates.is_empty(), "劳务市场应能刷出候选员工")
	var candidate_id := str(candidates[0].get("id", ""))
	_check(StaffManager.hire_candidate(candidate_id), "应能从招工渠道雇人")
	_check(StaffManager.hired.has(candidate_id), "雇人后应建立员工档案")
	var profile: Dictionary = StaffManager.hired[candidate_id]
	var skill_before := float(profile.get("skills", {}).get("prep", 0.0))
	StaffManager.record_work("prep", 10.0)
	_check(float(StaffManager.hired[candidate_id].get("skills", {}).get("prep", 0.0)) > skill_before, "干活应提升对应技能")
	_check(StaffManager.adjust_wage(candidate_id), "应能加薪留人")
	_check(StaffManager.give_day_off(candidate_id), "应能调休降低疲劳")
	_check(StaffManager.provide_housing(candidate_id), "应能包住留人")
	profile = StaffManager.hired[candidate_id]
	profile["wage"] = 0
	profile["unpaid_days"] = 3
	profile["morale"] = 20.0
	StaffManager.hired[candidate_id] = profile
	StaffManager.begin_new_day(TimeSystem.current_day + 1)
	_check(not StaffManager.hired.has(candidate_id), "连续欠薪应触发离职")

func _test_auto_save_fallback() -> void:
	GameState.reset_new_game()
	GameState.money = 12345
	_check(SaveManager.save_game(false), "自动存档测试前应能写入手动档")
	GameState.money = 54321
	_check(SaveManager.save_game(false), "第二次保存应轮转出备份")
	_check(SaveManager.request_auto_save("test"), "关键节点应能写自动存档")
	var paths := SaveManager.get_save_paths()
	var manual_path := ProjectSettings.globalize_path(str(paths["manual"]))
	var backup_path := ProjectSettings.globalize_path(str(paths["manual_backups"][0]))
	_check(FileAccess.file_exists(backup_path), "应保留手动存档备份")
	var broken := FileAccess.open(manual_path, FileAccess.WRITE)
	if broken != null:
		broken.store_string("{broken")
		broken.close()
	_check(SaveManager.load_game(false), "主档损坏时应自动回退到备份")
	_check(GameState.money == 12345, "回退读档应恢复上一份有效存档")
	var migrated := SaveManager._migrate_save({"version": 10, "inventory": {}, "room": {}, "relationships": {}, "family": {}, "staff": {}, "festival": {}})
	_check(int(migrated.get("version", 0)) == SaveManager.SAVE_VERSION, "旧档应迁移到当前存档版本")
	_check(dictionary_has_all(migrated.get("inventory", {}), ["storage_items", "shipping_items", "inventory_slots", "storage_slots", "shipping_slots", "backpack_level", "selected_hotbar_index"]), "旧背包应补齐固定格位和收纳字段")
	_check(dictionary_has_all(migrated.get("family", {}), ["married_day", "married_days", "last_anniversary_year", "last_evening_day", "last_date_day"]), "旧家庭档应补齐婚后字段")
	_check(dictionary_has_all(migrated.get("staff", {}), ["pending_candidate_id", "pending_candidate_stage", "referral_days"]), "旧员工档应补齐自然招聘字段")
	_check(dictionary_has_all(migrated.get("career", {}), ["low_performance_streak", "layoff_count", "application_line", "application_stage", "trial_progress", "trial_required"]), "旧职业档应补齐绩效、裁员与试工字段")
	_check(dictionary_has_all(migrated.get("festival", {}), ["activities_done"]), "旧节日档应补齐活动记录")
	_check(dictionary_has_all(migrated.get("collection", {}), ["seen_items", "seen_recipes", "seen_areas", "seen_careers"]), "旧图鉴档应补齐六类发现记录")

func _test_career_and_clothing() -> void:
	GameState.reset_new_game()
	_check(not CareerManager.is_employed(), "角色开局不应自带工作")
	var wang_hint := RelationshipManager.talk_to("wang")
	_check("工业区" in wang_hint or "工厂" in wang_hint, "找工作时王师傅应自然提到工业区招聘")
	_check(CareerManager.apply_for_job("factory"), "应能应聘工厂职业线")
	_check(CollectionManager.has_seen_career("factory"), "接触过的职业路线应进入城市图鉴")
	var first_title := CareerManager.get_current_title()
	GameState.energy = 100.0
	TimeSystem.minute_of_day = 8 * 60
	GameState.work_factory_shift()
	_check(GameState.money > GameState.starting_money, "工厂上班后应拿到工钱")
	for _index in range(12):
		CareerManager.record_shift("factory", 1.0)
	_check(CareerManager.get_current_title() != first_title, "表现稳定后应获得岗位晋升")
	_check(CareerManager.get_manager_hint().find("师傅") >= 0 or CareerManager.get_manager_hint().find("领班") >= 0 or CareerManager.get_manager_hint().find("负责") >= 0, "晋升应以 NPC 暗示表达而不是进度条")
	_check(CareerManager.resign(), "应能辞职")
	_check(CareerManager.apply_for_job("restaurant"), "辞职后应能改投餐饮职业线")
	for line_id in ["office", "study", "public", "freelance", "logistics", "craft"]:
		CareerManager.resign("测试换线")
		_check(CareerManager.apply_for_job(str(line_id)), "应能应聘%s路线" % line_id)
		GameState.energy = 100.0
		TimeSystem.minute_of_day = 10 * 60
		GameState.work_career_shift(str(line_id))
		_check(CareerManager.shifts_done >= 1, "%s路线上班或上课应推进岗位经验" % line_id)
	GameState.money = 2000
	_check(WardrobeManager.buy("work_jacket"), "应能买服装")
	_check(WardrobeManager.get_bonus("work") > 0.0, "工作服应带来干活加成")
	_check(WardrobeManager.get_color("top", Color.WHITE) != Color.WHITE, "穿上的衣服应改变角色外观颜色")

func _test_festival_and_passive_business() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	TimeSystem.current_day = 15
	TimeSystem.minute_of_day = 12 * 60
	MarketPhaseManager.force_refresh()
	_check("tangyuan" in MarketPhaseManager.get_festival_recipe_ids(), "元宵节应解锁节日汤圆")
	FestivalManager.reset_new_game()
	CalendarManager.announce_today()
	_check(FestivalManager.get_today_event_id() == "lantern_riddle", "元宵节应有独立节日事件")
	_check(FestivalManager.is_festival_npc("lan"), "节日事件应绑定限定 NPC")
	var activity_line := FestivalManager.join_today_activity()
	_check(not activity_line.is_empty(), "每个节日都应有可参加的限时活动")
	_check(AchievementManager.unlocked.has("festival_activity"), "参加节日活动应留下见闻")
	TimeSystem.current_day = 177
	FestivalManager.reset_new_game()
	CalendarManager.announce_today()
	_check(FestivalManager.get_today_event_id() == "pink_valentine", "六月二十七日应是粉色情人节")
	TimeSystem.current_day = 274
	FestivalManager.reset_new_game()
	CalendarManager.announce_today()
	_check(FestivalManager.get_today_event_id() == "white_valentine", "十月四日应是白色情人节")
	TimeSystem.current_day = 15
	FestivalManager.reset_new_game()
	CalendarManager.announce_today()
	var reward_id := str(FestivalManager.get_today_event().get("reward_item_id", ""))
	_check(not reward_id.is_empty(), "节日事件应配置限定纪念品")
	var first_line := FestivalManager.claim_gift("lan")
	_check(first_line.contains("灯谜签"), "节日 NPC 应自然说明纪念品来处")
	_check(InventoryManager.get_count(reward_id) == 1, "节日纪念品应进入背包")
	_check(CollectionManager.discovered.has(reward_id), "节日纪念品应记入图鉴")
	_check(AchievementManager.unlocked.has("first_festival"), "第一次领取节日纪念品应留下见闻")
	FestivalManager.claim_gift("lan")
	_check(InventoryManager.get_count(reward_id) == 1, "同一年同一节日不应重复领取纪念品")
	_check(TreasureManager.is_collectible_available(reward_id), "节日当天应能发现对应限定旧物")
	TimeSystem.current_day = 16
	_check(not TreasureManager.is_collectible_available(reward_id), "节日限定旧物不应在普通日期混入随机池")
	TimeSystem.current_day = 15
	for calendar_day in ConfigDB.get_rows("calendar"):
		var festival_event := ConfigDB.get_row("festival_events", str(calendar_day))
		_check(not festival_event.is_empty(), "每个节日都应有 NPC 事件：%s" % str(calendar_day))
		var event_item := str(festival_event.get("reward_item_id", ""))
		_check(not InventoryManager.get_item(event_item).is_empty(), "节日事件纪念品应真实存在：%s" % event_item)
		var collectible_row := ConfigDB.get_row("collectibles", event_item)
		_check(str(collectible_row.get("availability_day", "")) == str(calendar_day), "节日收集物应绑定正确日期：%s" % event_item)
	for gid in ConfigDB.get_rows("goods"):
		BusinessManager.goods_stock[gid] = 20
	BusinessManager.labor_stock = 20
	BusinessManager.brain_stock = 20
	_check(KitchenManager.start_shift(), "节日午市应能开档")
	_check("tangyuan" in KitchenManager._candidate_recipes(), "节日特殊商品应进入随机客流菜单")
	KitchenManager.end_shift()
	GameState.reset_new_game()
	GameState.money = 5000
	BusinessManager.business_level = 1
	RelationshipManager.affinity["mei"] = 30
	_check(StaffManager.hire("mei"), "被动经营前应先雇到店员")
	BusinessManager.begin_new_day(2)
	_check(BusinessManager.last_passive_income > 0, "有店员时自己不经营也应有少量被动收入")

func _test_map_hubs() -> void:
	for area_id in ["commercial_district", "high_end_district", "industrial_district", "logistics_port", "craft_workshop", "suburb", "clothing_store"]:
		SceneRouter.travel_to(area_id, "entrance")
		_check(GameState.current_area == area_id, "地图应能前往%s" % area_id)

func _test_story_and_random_events() -> void:
	GameState.reset_new_game()
	StoryManager.begin_new_story()
	_check(StoryManager.chapter == 0, "新游戏应从初到城中村章节开始")
	for action in ["career_apply", "first_serve", "first_staff", "farm_unlock", "pet_adopt", "business_owned"]:
		_check(StoryManager.record_action(str(action)), "剧情节点应由玩家行为推进：%s" % action)
	_check(StoryManager.record_action("referral_lead"), "熟人招工线索应自然推进后续剧情")
	_check(StoryManager.chapter == 7, "剧情应能由生活行为而不是任务面板推进")
	var event_id := StoryManager.trigger_random_event("neighbor_soup")
	_check(event_id == "neighbor_soup" and StoryManager.last_event_id == "neighbor_soup", "应能触发城内偶发事件")
	_check(not StoryManager.get_story_hint().is_empty(), "剧情章节应持续给出 NPC 暗示")
	_check(ConfigDB.get_rows("random_events").size() >= 50, "城中偶发事件应有足够内容量")
	WellbeingManager.stress = 50.0
	_check(StoryManager.trigger_random_event("night_river") == "night_river", "应能触发新的生活偶发事件")
	_check(WellbeingManager.stress < 50.0, "新的偶发事件效果应真实影响隐藏状态")
	CareerManager.apply_for_job("factory")
	RelationshipManager.affinity["mei"] = 2
	var bread_before := InventoryManager.get_count("bread")
	var npc_story := NpcStoryManager.try_advance("mei")
	_check(not npc_story.is_empty() and str(npc_story.get("title", "")) == "门口的钥匙", "NPC 关系和生活条件满足时应推进个人支线")
	_check(InventoryManager.get_count("bread") == bread_before + 1, "NPC 支线奖励应进入真实背包")
	_check(AchievementManager.unlocked.has("first_npc_story"), "完成第一段 NPC 支线应留下见闻")
	for story_id in ConfigDB.get_rows("npc_stories"):
		var story_row := ConfigDB.get_row("npc_stories", str(story_id))
		_check(not str(story_row.get("npc_id", "")).is_empty(), "NPC 支线应绑定人物：%s" % str(story_id))
		_check(not str(story_row.get("line", "")).is_empty(), "NPC 支线应有符合人物的台词：%s" % str(story_id))

func _test_collectible_catalog() -> void:
	_check(ConfigDB.get_rows("collectibles").size() >= 100, "城市场景应有至少一百件收藏物")
	for item_id in ConfigDB.get_rows("collectibles"):
		var row := ConfigDB.get_row("collectibles", str(item_id))
		_check(not str(row.get("name", "")).is_empty(), "收藏物应有名称：%s" % str(item_id))
		_check(not str(row.get("description", "")).is_empty(), "收藏物应有来路描述：%s" % str(item_id))
		_check(str(row.get("market_category", "")) in ["metal", "ceramic", "paper", "photo", "daily"], "收藏物行情分类应有效：%s" % str(item_id))
		var gift_npc := str(row.get("gift_npc", ""))
		if not gift_npc.is_empty():
			_check(not ConfigDB.get_row("npcs", gift_npc).is_empty(), "收藏物应送给真实 NPC：%s" % str(item_id))

func _test_presentation_interfaces() -> void:
	_check(PresentationManager.get_scene_background_key("breakfast_kitchen") != "", "早餐后厨应有独立场景资源键")
	_check(PresentationManager.get_portrait_key("qiang") != "", "新增 NPC 应有肖像资源键")
	_check(PresentationManager.get_icon_key("item", "meal_rice") != "", "物品应有图标资源键")
	_check(PresentationManager.get_font_names("font.body").size() > 0, "字体应通过表现层 token 获取")
	_check(PresentationManager.get_scene_texture("riverside") != null, "河边场景应加载像素背景")
	_check(PresentationManager.get_npc_world_frames("qiang").size() >= 4, "NPC 应加载四帧行走动画")
	_check(PresentationManager.get_npc_action_frames("qiang", "work").size() >= 4, "NPC 应加载工作动作帧")
	_check(PresentationManager.get_npc_world_frames("lan").size() >= 2, "节日限定 NPC 也应有表现资源")
	_check(PresentationManager.get_item_icon_texture("meal_rice") != null, "物品应加载像素图标")
	_check(PresentationManager.get_ui_texture("panel") != null, "UI 应加载像素面板纹理")
	_check(NoticeManager.infer_source_kind("生活进度已保存。") == "system", "系统消息不应伪装成 NPC")
	_check(NoticeManager.infer_source_kind("随便聊聊。", "梅姨") == "npc", "人物台词应标记为 NPC 来源")
	_check(not NoticeManager.get_speaker("到了河边。", "hint", "", "scene").is_empty(), "场景反馈应能独立标记来源")

func _test_fishing_loop() -> void:
	GameState.reset_new_game()
	GameState.current_area = "riverside"
	GameState.money = 5000
	TimeSystem.minute_of_day = 20 * 60
	WeatherSystem.current_weather_id = "sunny"
	_check(FishingManager.upgrade_rod("carbon_rod"), "应能购买更好的鱼竿")
	_check(FishingManager.current_rod_id == "carbon_rod", "鱼竿更换应被记录")
	_check(FishingManager.upgrade_rod(), "鱼竿应能继续升级")
	_check(FishingManager.upgrade_rod(), "鱼竿应能升到夜钓级别")
	_check(FishingManager.cast_or_reel(), "河边应能下竿")
	var before := BusinessManager.get_stock("tilapia")
	_check(FishingManager.resolve_cast("river_carp"), "收线应能钓到鱼")
	_check(BusinessManager.get_stock("tilapia") > before, "鱼获应直接进入餐馆仓库")
	_check(int(FishingManager.catches.get("river_carp", 0)) > 0, "钓鱼记录应保存捕获数量")
	_check(FishingManager.cast_or_reel(), "应能再次下竿")
	_check(not FishingManager.cast_or_reel(), "浮漂未动时不应能收线")
	FishingManager.bite_delay = 0.01
	_check(FishingManager.cast_or_reel(), "浮漂咬钩窗口内应收线成功")

func _test_housing_upgrades() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	_check(HousingManager.upgrade("studio"), "应能搬进独立小单间")
	_check(GameState.rent_amount == 1050, "搬家后房租应同步更新")
	_check(HousingManager.get_bonus("energy") > 0.0, "更好的住房应改善睡眠恢复")
	GameState.money = 10000
	_check(HousingManager.upgrade("one_bed"), "收入足够后应能继续升级住房")
	_check(HousingManager.current_tier == 2, "住房成长应记录为阶段提升")
	GameState.money = 20000
	_check(HousingManager.upgrade("river_apartment"), "应能继续升级河边公寓")
	GameState.money = 50000
	_check(HousingManager.upgrade("highrise_apartment"), "高端住宅区应能继续升级住房")
	GameState.money = 100000
	_check(HousingManager.upgrade("sky_garden_house"), "云端花园住宅应能完成住房线")

func _test_travel_and_postcards() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	GameState.energy = 100.0
	TimeSystem.current_day = 20
	_check(TravelManager.travel_to("seaside_resort"), "开放日期后应能买票去海边")
	_check(TravelManager.visited.has("seaside_resort"), "旅行记录应保存目的地")
	_check(GameState.current_area == "seaside_resort", "旅游应切换到对应场景")
	var energy_before := GameState.energy
	_check(TravelManager.rest_at_destination("seaside_resort") and GameState.energy > energy_before, "旅游目的地应能休息恢复体力")
	_check(TravelManager.collect_postcard("seaside_resort"), "旅游后应能收集风景照片")
	_check(TravelManager.postcards.has("seaside_resort"), "旅行照片应进入旅行册")

func _test_enterprise_routes() -> void:
	GameState.reset_new_game()
	GameState.money = 60000
	for enterprise_id in ["street_stall", "snack_drink", "retail_shop", "small_factory"]:
		_check(EnterpriseManager.buy(str(enterprise_id)), "应能盘下%s" % enterprise_id)
	_check(EnterpriseManager.upgrade("street_stall"), "已拥有的生意应能继续升级")
	_check(EnterpriseManager.get_level("street_stall") == 2, "生意升级应记录等级")
	BusinessManager.goods_stock = {"egg": 2, "greens": 2}
	BusinessManager.labor_stock = 6
	BusinessManager.brain_stock = 6
	GameState.energy = 100.0
	TimeSystem.minute_of_day = 9 * 60
	var money_before_operate := GameState.money
	_check(EnterpriseManager.can_operate("street_stall"), "四种业态应有可实际经营的现场操作")
	_check(EnterpriseManager.operate("street_stall"), "现场照看地摊应消耗备货和劳力并结算收入")
	_check(EnterpriseManager.last_active_income > 0 and GameState.money > money_before_operate, "现场经营收入应真实到账")
	_check(BusinessManager.get_stock("egg") == 1 and BusinessManager.get_stock("greens") == 1, "现场经营应消耗对应业态原料")
	BusinessManager.goods_stock.clear()
	_check(not EnterpriseManager.can_operate("street_stall"), "备货不足时不应允许直接经营")
	BusinessManager.goods_stock = {"egg": 3, "greens": 3}
	EnterpriseManager.begin_new_day(TimeSystem.current_day + 1)
	_check(EnterpriseManager.last_daily_income > 0, "名下生意应在每日结算产生收入")

func _test_hidden_achievements() -> void:
	GameState.reset_new_game()
	AchievementManager.record_event("farm_harvest")
	_check(AchievementManager.unlocked.has("farm_harvest"), "收成行为应解锁隐藏见闻")
	for line_id in ["restaurant", "factory", "office", "study", "public", "freelance"]:
		AchievementManager.record_event("career_route:" + str(line_id))
	_check(AchievementManager.unlocked.has("six_lives"), "六条人生线应通过行为自然解锁")
	AchievementManager._unlock("first_wage")
	AchievementManager._unlock("first_serve")
	AchievementManager._unlock("first_catch")
	_check(AchievementManager.unlocked.has("three_marks"), "三条见闻应形成阶段性记录")
	_check(StoryManager.flags.has("achievement_milestone"), "见闻积累应为后续剧情留下自然触发节点")
	_check(not AchievementManager.get_natural_hint().is_empty(), "未解锁见闻应能作为 NPC 随口线索出现")
	_check(AchievementManager.get_hint_lines().size() > 0, "未解锁见闻应保留可回溯文字")

func _test_family_route() -> void:
	GameState.reset_new_game()
	GameState.money = 20000
	RelationshipManager.affinity["mei"] = 80
	HousingManager.current_tier = 1
	CareerManager.apply_for_job("factory")
	_check(FamilyManager.confess("mei"), "关系、工作和住处稳定后才应能确认恋爱关系")
	HousingManager.current_tier = 2
	_check(FamilyManager.marry("mei"), "住房稳定后应能成家")
	FamilyManager.last_anniversary_year = -1
	FamilyManager.begin_new_day(TimeSystem.current_day)
	_check(FamilyManager.last_anniversary_year == CalendarManager.get_year(), "成家纪念日应自然触发日常反馈")
	GameState.energy = 100.0
	var stress_before_evening := WellbeingManager.stress
	_check(FamilyManager.share_evening(), "成家后应能和伴侣过共同夜晚")
	_check(WellbeingManager.stress < stress_before_evening, "共同夜晚应真实缓解压力")
	_check(AchievementManager.unlocked.has("shared_evening"), "共同夜晚应留下见闻")
	HousingManager.current_tier = 3
	_check(FamilyManager.start_family(), "成家后应能迎接新的家庭成员")
	_check(not FamilyManager.child_name.is_empty(), "新家庭成员应有名字")
	GameState.energy = 100.0
	var child_mood_before := FamilyManager.child_mood
	_check(FamilyManager.care_for_child("play"), "应能陪孩子玩耍")
	_check(FamilyManager.child_mood > child_mood_before, "陪伴应改善孩子情绪")
	FamilyManager.child_days = 89
	FamilyManager.begin_new_day(TimeSystem.current_day + 1)
	_check(FamilyManager.child_stage == "child", "孩子应按天数进入新的成长阶段")
	_check(FamilyManager.get_bonus("energy") > 0.0, "家庭状态应改善睡眠恢复")
	_check(FamilyManager.can_divorce(), "成家后应允许玩家认真处理分开")
	_check(FamilyManager.divorce(), "离婚应能真实结束关系并保留人生记录")
	_check(not FamilyManager.has_partner(), "离婚后应回到独自生活状态")
	_check(AchievementManager.unlocked.has("new_chapter"), "离婚应留下重新开始的见闻")

func _test_wellbeing_state() -> void:
	GameState.reset_new_game()
	GameState.energy = 20.0
	WellbeingManager._reevaluate()
	_check(WellbeingManager.condition_id == "worn_out", "低体力应形成疲惫体感状态")
	var stress_before := WellbeingManager.stress
	WellbeingManager.consume_item("herbal_tea")
	_check(WellbeingManager.stress < stress_before, "凉茶应降低隐藏压力")
	WellbeingManager.stress = 80.0
	WellbeingManager._reevaluate()
	_check(WellbeingManager.condition_id == "stressed", "高压状态应影响提示和效率")
	WeatherSystem.current_weather_id = "heat"
	WellbeingManager.begin_new_day(TimeSystem.current_day + 1)
	_check(WellbeingManager.condition_id == "heat_tired", "酷暑应形成天气相关体感")

func _test_unlock_levels() -> void:
	UnlockManager.force_unlock_all = false
	UnlockManager.current_level = 0
	_check(not UnlockManager.can_access("suburb"), "城郊初始应处于锁定状态")
	TimeSystem.current_day = 3
	UnlockManager._evaluate()
	_check(UnlockManager.can_access("suburb"), "稳定几天后城郊路线应开放")
	StoryManager.chapter = 2
	UnlockManager._evaluate()
	_check(UnlockManager.can_access("riverside"), "开始经营后河边应开放")
	BusinessManager.business_level = 1
	UnlockManager._evaluate()
	_check(UnlockManager.can_access("bus_station"), "店铺成型后旅行线路应开放")
	TimeSystem.current_day = 14
	UnlockManager._evaluate()
	_check(UnlockManager.can_access("mountain_spring"), "长线天数后山林温泉应开放")
	UnlockManager.force_unlock_all = true

func _test_medical_services() -> void:
	GameState.reset_new_game()
	GameState.money = 2000
	GameState.health = 45.0
	WellbeingManager.stress = 65.0
	var before := GameState.health
	_check(MedicalManager.visit_service("cold_care"), "应能在社区诊所就医")
	_check(GameState.health > before, "就医应改善健康状态")
	_check(WellbeingManager.stress < 65.0, "治疗和休息应降低压力")

func _test_education_courses() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	_check(EducationManager.enroll("office_excel"), "应能报名办公软件课程")
	for _index in range(5):
		GameState.energy = 100.0
		if EducationManager.is_exam_ready("office_excel"):
			break
		EducationManager.study("office_excel")
	_check(EducationManager.is_exam_ready("office_excel"), "课程学完后应进入结业考核")
	GameState.energy = 100.0
	_check(EducationManager.take_exam("office_excel"), "应能参加结业考核并取得证书")
	_check(EducationManager.has_credential("excel_cert"), "通过考核后应取得办公证书")
	_check(EducationManager.get_career_bonus("office") > 0.0, "证书应提高对应职业收入")
	CareerManager.apply_for_job("office")
	for _index in range(10):
		CareerManager.record_shift("office", 1.0)
	_check(CareerManager.current_rank == 1 and CareerManager.get_manager_hint().find("证明") >= 0, "缺少销售证时应卡在岗位门槛，并由负责人用对话暗示")
	EducationManager.credentials["sales_cert"] = true
	for _index in range(8):
		CareerManager.record_shift("office", 1.0)
	_check(CareerManager.current_rank > 1, "补上证书后应重新获得晋升机会")

func _test_life_endings() -> void:
	GameState.reset_new_game()
	GameState.money = 100000
	EndingManager.evaluate()
	_check(ConfigDB.get_rows("life_endings").size() >= 100, "人生结局表应扩展到更多生活路线")
	_check(EndingManager.endings.has("millionaire"), "累计资产达标应留下第一桶金结局")
	CareerManager.current_line = "logistics"
	CareerManager.current_rank = 4
	EndingManager.evaluate()
	_check(EndingManager.endings.has("logistics_lead"), "数据条件应能判定新职业结局")
	var count_before := EndingManager.endings.size()
	EndingManager.evaluate()
	_check(EndingManager.endings.size() == count_before, "重复评估不应重复记录同一个人生结局")

func _test_hobbies() -> void:
	GameState.reset_new_game()
	GameState.money = 5000
	_check(HobbyManager.action("photography"), "首次兴趣操作应完成报名")
	for _index in range(5):
		GameState.energy = 100.0
		HobbyManager.action("photography")
	_check(HobbyManager.get_level("photography") >= 1, "持续练习应提高兴趣水平")
	_check(HobbyManager.get_career_bonus("freelance") > 0.0, "兴趣应给对应职业带来收入加成")

func _test_photo_album() -> void:
	GameState.reset_new_game()
	GameState.current_area = "riverside"
	PhotoManager.reset_new_game()
	_check(PhotoManager.take_photo("riverside"), "应能拍下当前场景照片")
	var typed_photos: Array[Dictionary] = PhotoManager.get_photos()
	_check(typed_photos.size() == 1, "照片应通过强类型相册接口返回")
	_check(PhotoManager.photos.size() == 1, "照片应进入相册记录")
	var path := ProjectSettings.globalize_path(str(PhotoManager.photos[0].get("path", "")))
	_check(FileAccess.file_exists(path), "相册照片应实际写入磁盘")

func _test_coop_and_platform_interfaces() -> void:
	_check(CoopManager.can_start_session(4), "合作模式应允许 4 人")
	_check(not CoopManager.can_start_session(5), "合作模式不应超过 4 人")
	_check(CoopManager.create_host(0, 4), "应能创建本地合作主机接口")
	_check(CoopManager.is_coop_active() and CoopManager.is_host, "合作主机状态应正确")
	var economy_snapshot := CoopManager._build_economy_snapshot()
	_check(economy_snapshot.has("money") and economy_snapshot.has("business") and economy_snapshot.has("inventory") and economy_snapshot.has("kitchen"), "合作房间应能生成共同经济与厨房快照")
	var snapshot_money := int(economy_snapshot.get("money", 0))
	GameState.money = snapshot_money + 999
	CoopManager._apply_economy_snapshot(economy_snapshot)
	_check(GameState.money == snapshot_money, "访客经济快照应以房主状态覆盖本地状态")
	CoopManager.is_host = false
	_check(CoopManager.is_client_view_only(), "房主之外的房间成员应识别为共同账本访客")
	CoopManager.is_host = true
	GameState.money = 10000
	var goods_before := BusinessManager.get_stock("rice")
	_check(CoopManager._execute_shared_action("buy_goods", {"goods_id": "rice", "quantity": 1}), "房主应能执行访客提交的共同交易")
	_check(BusinessManager.get_stock("rice") == goods_before + 1, "房主执行后共同库存应真实变化")
	TimeSystem.minute_of_day = 12 * 60
	MarketPhaseManager.force_refresh()
	BusinessManager.labor_stock = 5
	BusinessManager.brain_stock = 5
	_check(CoopManager._execute_shared_action("kitchen_start", {"location": "restaurant"}), "房主应能执行访客提交的厨房开档请求")
	_check(KitchenManager.active, "远程厨房请求应真实开启班次")
	CoopManager._execute_shared_action("kitchen_end", {"reason": "test"})
	CoopManager._apply_remote_state(2, "street", Vector2(320, 360), Vector2.RIGHT)
	_check(CoopManager.remote_states.has(2), "好友位置状态应进入合作会话")
	_check(CoopManager.get_slot_lines().size() >= 2, "合作房间应显示好友槽位")
	var remote_actor = load("res://scripts/gameplay/remote_player_actor.gd").new()
	remote_actor.configure(2, "好友2")
	remote_actor.update_state(Vector2(320, 360), Vector2.RIGHT)
	_check(remote_actor.peer_id == 2, "远程玩家表现节点应记录 peer id")
	remote_actor.free()
	CoopManager._remove_remote_state(2)
	CoopManager.leave_session()
	_check(not CoopManager.is_coop_active(), "离房后合作状态应清理")
	PlatformIntegrationManager.set_stat("test_progress", 2.0)
	_check(PlatformIntegrationManager.get_stat("test_progress") == 2.0, "平台统计接口应保存本地回退数据")
	_check(PlatformIntegrationManager.unlock_achievement("test_achievement"), "成就接口应能调用平台回退")

func _test_npc_schedule() -> void:
	var rows = ConfigDB.get_rows("npc_schedule").get("lin", [])
	_check(typeof(rows) == TYPE_ARRAY and rows.size() >= 2, "NPC 作息表应有多段安排")
	GameState.reset_new_game()
	TimeSystem.current_day = 40
	RelationshipManager.affinity["mei"] = 10
	var birthday_line := RelationshipManager.talk_to("mei")
	_check("生日" in birthday_line, "NPC 生日当天应出现专属对话")
	_check(AchievementManager.unlocked.has("birthday_friend"), "记得 NPC 生日应留下见闻")
	InventoryManager.add_item("sea_glass", 1)
	var birthday_gift := RelationshipManager.give_item("mei", "sea_glass")
	_check(bool(birthday_gift.get("ok", false)), "生日当天应能送出礼物")
	_check(AchievementManager.unlocked.has("birthday_gift"), "生日礼物应留下见闻")

func _test_areas() -> void:
	for area in ["farm", "pet_store", "furniture_store"]:
		SceneRouter.travel_to(area, "entrance")
		_check(GameState.current_area == area, "应能前往%s" % area)

func dictionary_has_all(value, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func _test_art_and_audio_pipeline() -> void:
	var scene_resolved := PresentationManager.get_resolved_asset_path("res://assets/art/scenes/home/background.png")
	_check(ResourceLoader.exists(scene_resolved), "场景美术应能通过表现层稳定路径解析")
	var audio_path := AudioManager.get_resolved_audio_path("night_market_ambient")
	_check(not audio_path.is_empty() and ResourceLoader.exists(audio_path), "场景环境音应能通过 AudioManager 稳定路径解析")
	_check(str(ConfigDB.get_row("scene_metadata", "night_market").get("music_key", "")) == "night_market_ambient", "夜市应绑定独立环境音")
	_check(str(ConfigDB.get_row("scene_metadata", "farm").get("music_key", "")) == "farm_ambient", "农场应绑定独立环境音")

func _test_career_performance_layoff() -> void:
	GameState.reset_new_game()
	_check(CareerManager.apply_for_job("factory"), "绩效测试前应能入职工厂")
	var money_before := GameState.money
	for _index in range(4):
		CareerManager.record_shift("factory", 0.2)
	_check(not CareerManager.is_employed(), "连续低绩效应由负责人暗示后触发裁员")
	_check(CareerManager.layoff_count == 1, "裁员应只记一次")
	_check(GameState.money > money_before, "被裁员后应拿到结算补偿")
	_check(CareerManager.get_manager_hint().find("别的活法") >= 0, "裁员后应通过 NPC 暗示重新择业，而不是生成任务清单")
	_check(CareerManager.apply_for_job("restaurant"), "被裁员后应能重新选择其他职业线")

func _test_job_trial_flow() -> void:
	GameState.reset_new_game()
	_check(CareerManager.register_interest("factory"), "招聘应先在工作现场登记")
	_check(CareerManager.application_line == "factory" and CareerManager.application_stage == 1, "登记后应进入等待试工状态")
	for _index in range(CareerManager._trial_required_for("factory")):
		GameState.energy = 100.0
		_check(CareerManager.perform_trial_action("factory"), "每次现场试工动作都应被记录")
	_check(CareerManager.application_stage == 3, "完成试工动作后应进入负责人确认阶段")
	_check(CareerManager.confirm_application("factory"), "负责人确认后才应正式入职")
	_check(CareerManager.is_employed_in("factory"), "确认入职后应进入工厂职业线")
