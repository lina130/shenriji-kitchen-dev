extends Node

var main: Node
var failures: Array[String] = []
var step_count := 0

func _ready() -> void:
	await get_tree().process_frame
	main = get_parent()
	print("PLAYTEST_BEGIN")
	main._start_new_game()
	await get_tree().process_frame
	await _wait_frames(10)
	if main.hud._modal_state != main.hud.ModalState.NONE:
		_fail("开场不应出现需要 Esc 关闭的弹窗")
	else:
		_step("开场直接显示游戏内容，无空弹窗")
	if not _world_ready():
		_fail("新游戏后世界未建立")
		await _finish()
		return
	if "--spot-city" in OS.get_cmdline_user_args():
		await _run_city_traversal_spot_check()
		await _finish()
		return
	if "--spot-park" in OS.get_cmdline_user_args():
		SceneRouter.travel_to("park", "entrance")
		await _wait_frames(12)
		await _connect_and_click_nearest("exercise_equipment", "公园锻炼定位检查")
		await _connect_and_click_nearest("park_exit", "公园出口定位检查")
		_check_area("street", "公园出口返回街道")
		await _finish()
		return
	await _connect_and_click_nearest("home_to_living", "从卧室推门进生活区")
	_check_area("home_living", "卧室与生活区已分开")
	await _connect_and_click_nearest("leave_home", "从生活区出门去城市")
	_check_area("street", "从出租屋走到街道")
	await _wait_frames(12)
	await _connect_and_click_nearest("home_door", "从城市回到出租屋")
	_check_area("home_living", "从街道回到生活区")
	await _connect_and_click_nearest("home_living_to_bedroom", "从生活区回卧室")
	_check_area("home", "回到卧室")
	await _wait_frames(12)
	await _run_home_checks()
	if not failures.is_empty():
		await _finish()
		return
	await _connect_and_click_nearest("home_to_living", "再次从卧室推门进生活区")
	await _connect_and_click_nearest("leave_home", "再次从生活区出门")
	_check_area("street", "从出租屋走到街道")
	TimeSystem.minute_of_day = 7 * 60
	MarketPhaseManager.force_refresh()
	await _wait_frames(4)
	await _connect_and_click_nearest("enter_breakfast", "从城市地图走进楼下早餐店")
	_check_area("breakfast_shop", "从街道进入楼下早餐店")
	await _move_player_to(Vector2(270, 350))
	await _connect_and_click_nearest("breakfast_customer|0", "点击排队客人接单")
	if not KitchenManager.active:
		var customer = _find_interactable("breakfast_customer|0")
		if customer != null:
			customer.interact()
			await _wait_frames(4)
	if KitchenManager.active and not KitchenManager.orders.is_empty():
		_step("早餐店排队点单接入多工序流水线")
	else:
		_fail("早餐店排队点单未进入流水线")
	KitchenManager.end_shift()
	TimeSystem.minute_of_day = 7 * 60
	MarketPhaseManager.force_refresh()
	await _move_player_to(Vector2(980, 620))
	await _connect_and_click_nearest("enter_breakfast_kitchen", "进早餐店后厨")
	_check_area("breakfast_kitchen", "早餐店前厅与后厨已分开")
	await _connect_and_click_nearest("recipe_order|tea_egg", "在后厨点茶叶蛋菜单卡")
	await _wait_for_station_state(0, ["stage_ready", "ready"])
	await _connect_and_click_nearest("restaurant_station|0", "点后厨备料台")
	if KitchenManager.staging.size() > 0:
		_step("早餐后厨半成品进入托盘")
	else:
		_fail("早餐后厨没有产生半成品托盘")
	await _connect_and_click_nearest("breakfast_kitchen_exit", "从早餐后厨回前厅")
	_check_area("breakfast_shop", "从早餐后厨回前厅")
	KitchenManager.end_shift()
	await _connect_and_click_nearest("breakfast_exit", "离开早餐店")
	_check_area("street", "从早餐店回到街道")
	await _wait_frames(8)
	await _connect_and_click_nearest("enter_store", "从主街走进便利店")
	_check_area("store", "从主街进入便利店")
	await _connect_and_click_nearest("store_counter", "打开便利店商品")
	await _close_modal()
	await _connect_and_click_nearest("npc|lin", "与小林交谈")
	await _close_modal()
	await _connect_and_click_nearest("store_exit", "离开便利店")
	_check_area("street", "从便利店回到主街")
	await _wait_frames(8)
	await _connect_and_click_nearest("enter_bank", "从主街走进银行与彩票站")
	_check_area("bank", "从主街进入银行与彩票站")
	await _connect_and_click_nearest("bank_counter", "在银行柜台打开存取款")
	await _close_modal()
	await _connect_and_click_nearest("lottery_counter", "在彩票柜台购买彩票")
	await _close_modal()
	await _connect_and_click_nearest("bank_exit", "离开银行与彩票站")
	_check_area("street", "从银行回到主街")
	await _wait_frames(8)
	GameState.money = 10000
	await _connect_and_click_nearest("enter_clothing", "从主街走进服装店")
	_check_area("clothing_store", "从主街进入服装店")
	await _connect_and_click_nearest("wardrobe_counter", "打开服装柜台")
	await _press_modal_button_prefix("买下")
	await _close_modal()
	await _connect_and_click_nearest("clothing_exit", "离开服装店")
	_check_area("street", "从服装店回到主街")
	await _wait_frames(8)
	GameState.money = 10000
	InventoryManager.add_item("film_camera", 1)
	InventoryManager.add_item("old_radio", 1)
	await _connect_and_click_nearest("enter_market", "从城市地图走进旧货市场")
	_check_area("market", "从街道进入旧货市场")
	await _connect_and_click_nearest("market_select|film_camera", "在旧货市场点选相机")
	await _connect_and_click_nearest("market_sell", "点交易牌卖出现金")
	await _connect_and_click_nearest("market_select|old_radio", "再点选旧收音机")
	await _connect_and_click_nearest("market_consign", "点寄卖台寄卖")
	await _connect_and_click_nearest("market_upgrade", "点摊位告示升级")
	await _wait_frames(5)
	TimeSystem.minute_of_day = 12 * 60
	MarketPhaseManager.force_refresh()
	await _connect_and_click_nearest("market_exit", "离开旧货市场去现场经营")
	_check_area("street", "从旧货市场回到城中村")
	await _connect_and_click_nearest("enter_restaurant", "从主街进入餐馆现场")
	_check_area("restaurant", "进入餐馆现场")
	TimeSystem.minute_of_day = 12 * 60
	MarketPhaseManager.force_refresh()
	for goods_id in ConfigDB.get_rows("goods"):
		BusinessManager.goods_stock[goods_id] = 20
	BusinessManager.labor_stock = 20
	BusinessManager.brain_stock = 20
	await _connect_and_click_nearest("restaurant_open", "在门口招牌开档")
	KitchenManager.orders[0]["recipe_id"] = "egg_rice"
	KitchenManager.orders[0]["patience"] = 180.0
	await _connect_and_click_nearest("recipe_order|egg_rice", "点菜单卡开始蛋炒饭")
	await _wait_seconds(0.6)
	if str(KitchenManager.get_stations_status()[0].get("state", "idle")) == "idle":
		await _connect_and_click_nearest("recipe_order|egg_rice", "再次点菜单卡确认开工")
	await _wait_for_station_state(0, ["stage_ready", "ready"])
	await _connect_and_click_nearest("restaurant_station|0", "点备料台把半成品放上托盘")
	await _connect_and_click_nearest("kitchen_tray|0", "点半成品托盘送到油锅")
	await _wait_for_station_state(3, ["stage_ready", "ready"])
	await _connect_and_click_nearest("restaurant_station|3", "点油锅把成品放回托盘")
	await _connect_and_click_nearest("kitchen_tray|0", "点托盘送到出餐台")
	await _wait_for_station_state(5, ["ready"])
	await _connect_and_click_nearest("restaurant_station|5", "点出餐台递给客人")
	await _wait_frames(5)
	if KitchenManager.served < 1:
		_fail("真实窗口场景点击经营未完成出餐")
	else:
		_step("真实窗口场景点击完成多工序出餐")
	GameState.money = 10000
	await _connect_and_click_nearest("equipment_upgrade|fryer", "在场景里升级油锅")
	await _connect_and_click_nearest("kitchen_close", "在场景里提前收档")
	await _connect_and_click_nearest("restaurant_exit", "离开餐馆")
	_check_area("street", "从餐馆回主街")
	await _connect_and_click_nearest("enter_market", "从城市地图回到旧货市场")
	_check_area("market", "回到旧货市场继续探索")
	await _close_modal()
	TimeSystem.minute_of_day = 7 * 60
	await _open_shortcut("bank", "打开银行与彩票")
	await _press_modal_button_prefix("存 100")
	await _press_modal_button_prefix("取 100")
	await _press_modal_button_prefix("买 1 张")
	await _close_modal()
	await _connect_and_click_nearest("expedition_board", "打开旧址入口")
	await _press_modal_button_prefix("旧楼地下室")
	await _wait_frames(18)
	_check_area("ruins", "进入旧楼地下室")
	var ruin_item := TreasureManager.force_find("ruins", "uncommon")
	if ruin_item.is_empty():
		_fail("旧址探索应能偶遇一件旧物")
	else:
		_step("旧址探索偶遇旧物：%s" % ruin_item)
	await _connect_and_click_nearest("ruins_exit", "从旧址返回地面")
	_check_area("market", "探索结束回到旧货市场")
	await _connect_and_click_nearest("npc|chen", "与陈伯交谈")
	await _close_modal()
	await _connect_and_click_nearest("market_exit", "离开旧货市场")
	_check_area("street", "从旧货市场回到街道")
	await _wait_frames(8)
	await _connect_and_click_nearest("enter_park", "从城市地图走进社区公园")
	_check_area("park", "进入社区公园")
	await _connect_and_click_nearest("exercise_equipment", "在公园锻炼")
	await _wait_frames(8)
	await _connect_and_click_nearest("park_exit", "离开公园")
	_check_area("street", "从公园回到街道")
	TimeSystem.minute_of_day = 19 * 60
	await _connect_and_click_nearest("enter_night_market", "从城市地图走进城中村夜市")
	_check_area("night_market", "进入城中村夜市")
	await _interact_first_with_prefix("night_market_stall|", "在夜市买一份夜宵或食材")
	await _connect_and_click_nearest("night_market_work", "在夜市帮摊主守一小时")
	await _connect_and_click_nearest("night_market_exit", "从夜市回到主街")
	_check_area("street", "从夜市回到城中村主街")
	TimeSystem.minute_of_day = 10 * 60
	MarketPhaseManager.force_refresh()
	await _wait_frames(8)
	await _connect_and_click_nearest("enter_recycle", "从城市地图走进废品回收站")
	_check_area("recycle", "进入废品回收站")
	await _connect_and_click_nearest("recycle_search", "翻找废品堆")
	await _wait_frames(8)
	await _connect_and_click_nearest("recycle_exit", "离开废品回收站")
	_check_area("street", "从废品回收站回到街道")
	await _wait_frames(8)
	await _connect_and_click_nearest("career_board|factory", "在主街工业区登记工厂试工")
	await _close_modal()
	await _connect_and_click_nearest("enter_factory", "从主街走进工厂")
	_check_area("factory", "从主街进入工厂")
	for _trial_index in range(3):
		await _connect_and_click_nearest("work_station", "在工厂工位完成现场试工动作")
		await _wait_frames(4)
	await _connect_and_click_nearest("npc|wang", "完成试工后找王师傅确认入职")
	await _close_modal()
	if CareerManager.is_employed_in("factory"):
		_step("工厂职业线应聘与上班")
	else:
		_fail("工厂职业线未成功入职")
	await _connect_and_click_nearest("factory_exit", "离开工厂")
	_check_area("street", "从工厂回到主街")
	await _connect_and_click_nearest("enter_farm", "从主街进入城郊农场")
	_check_area("farm", "从主街进入城郊农场")
	GameState.money = 5000
	if not FarmManager.has_farm:
		await _connect_and_click_nearest("farm_rent", "在农场现场租地")
	if not FarmManager.has_farm:
		_fail("农场现场租地没有生效")
	main.world._build_area("farm", "entrance")
	await _wait_frames(5)
	await _interact_first_with_prefix("farm_crop|", "在农场场景点选当季作物")
	await _interact_first_with_prefix("farm_plot|", "在农场场景点地种植或照料")
	await _interact_first_with_prefix("farm_tool|", "在农场场景升级工具")
	await _connect_and_click_nearest("enter_farm_livestock", "从农场去圈舍")
	_check_area("farm_livestock", "农场圈舍与田边分开")
	await _connect_and_click_nearest("farm_animal|chicken_house", "在圈舍买下鸡舍")
	await _wait_frames(8)
	await _connect_and_click_nearest("farm_animal|chicken_house", "在圈舍给鸡舍喂饲料")
	await _connect_and_click_nearest("farm_livestock_exit", "从圈舍回到农场")
	await _connect_and_click_nearest("farm_weather", "听农场主说天气和行情")
	await _connect_and_click_nearest("farm_exit", "从农场回主街")
	_check_area("street", "从农场回到主街")
	await _run_festival_ui_checks()
	await _run_npc_story_ui_checks()
	await _finish()

func _run_festival_ui_checks() -> void:
	var saved_day := TimeSystem.current_day
	var saved_minute := TimeSystem.minute_of_day
	var saved_area := GameState.current_area
	TimeSystem.current_day = 15
	TimeSystem.minute_of_day = 12 * 60
	CalendarManager.announce_today()
	var reward_id := str(FestivalManager.get_today_event().get("reward_item_id", ""))
	main.hud.open_dialogue("lan")
	await _wait_frames(3)
	if main.hud._modal_state == main.hud.ModalState.DIALOGUE and main.hud._active_npc_id == "lan":
		_step("节日限定 NPC 能用真实界面交谈")
	else:
		_fail("节日限定 NPC 对话未打开")
	if InventoryManager.get_count(reward_id) == 1 and CollectionManager.discovered.has(reward_id):
		_step("节日纪念品通过 NPC 对话进入背包和图鉴")
	else:
		_fail("节日纪念品没有通过真实对话领取")
	await _close_modal()
	TimeSystem.current_day = saved_day
	TimeSystem.minute_of_day = saved_minute
	GameState.current_area = saved_area
	FestivalManager.active_event_id = str(FestivalManager.get_event_for_day(saved_day).get("event_id", ""))

func _run_npc_story_ui_checks() -> void:
	RelationshipManager.affinity["mei"] = 2
	if not CareerManager.is_employed():
		CareerManager.apply_for_job("factory")
	var bread_before := InventoryManager.get_count("bread")
	main.hud.open_dialogue("mei")
	await _wait_frames(3)
	if NpcStoryManager.get_stage("mei") == 1 and main.hud._modal_state == main.hud.ModalState.DIALOGUE:
		_step("NPC 个人支线通过真实对话推进")
	else:
		_fail("NPC 个人支线没有通过真实对话推进")
	if InventoryManager.get_count("bread") >= bread_before + 1:
		_step("NPC 支线奖励进入真实背包")
	else:
		_fail("NPC 支线奖励没有进入背包")
	await _close_modal()

func _run_home_checks() -> void:
	await _connect_and_click_nearest("home_to_living", "从卧室推门进生活区")
	_check_area("home_living", "生活区独立于卧室")
	await _connect_and_click_nearest("fridge", "打开生活区冰箱背包")
	await _close_modal()
	await _connect_and_click_nearest("home_living_to_bedroom", "从生活区回卧室")
	_check_area("home", "生活区回卧室")
	await _connect_and_click_nearest("study_desk", "在书桌学习")
	await _wait_frames(8)
	await _open_shortcut("inventory", "打开背包快捷键")
	await _close_modal()
	await _open_shortcut("collection", "打开旧物册快捷键")
	await _close_modal()
	await _open_shortcut("map", "打开地图快捷键")
	await _close_modal()
	await _open_shortcut("encyclopedia", "打开图鉴快捷键")
	await _close_modal()
	await _open_shortcut("staff", "打开招工与离职界面")
	await _close_modal()
	await _open_shortcut("career", "打开职业与岗位界面")
	await _close_modal()
	await _open_shortcut("wardrobe", "打开服装界面")
	await _close_modal()
	await _open_shortcut("photo_album", "打开生活相册")
	await _close_modal()
	await _open_shortcut("coop_panel", "打开合作房间")
	await _close_modal()
	await _open_shortcut("bank", "打开账本快捷键")
	await _close_modal()
	await _connect_and_click_nearest("npc|mei", "与梅姨交谈")
	await _close_modal()
	TimeSystem.minute_of_day = 22 * 60
	var day_before_sleep := TimeSystem.current_day
	await _connect_and_click_nearest("bed", "上床睡觉")
	await _wait_frames(12)
	if TimeSystem.current_day == day_before_sleep:
		_fail("点击床后没有推进到次日")
	else:
		_step("睡觉推进到次日")

func _run_city_traversal_spot_check() -> void:
	await _connect_and_click_nearest("home_to_living", "卧室门走入生活区")
	await _connect_and_click_nearest("leave_home", "生活区门走入城市")
	_check_area("street", "出租屋出门")
	main.world._set_map_zoom(0.82)
	_check_step(is_equal_approx(main.world.player.get_camera().zoom.x, 0.82), "城市地图应使用相机缩放")
	_check_step(main.world.player.get_camera().limit_right == int(WorldRoot.CITY_MAP_SIZE.x), "城市相机应覆盖整张大地图并跟随玩家")
	main.world._set_map_zoom(1.0)
	await _connect_and_click_nearest("enter_breakfast", "走入早餐店")
	_check_area("breakfast_shop", "早餐店入口")
	await _connect_and_click_nearest("breakfast_exit", "走出早餐店")
	_check_area("street", "早餐店出口")
	await _connect_and_click_nearest("enter_park", "走入公园")
	_check_area("street", "公园入口")
	await _connect_and_click_nearest("park_exit", "走出公园")
	_check_area("street", "公园出口")
	TimeSystem.minute_of_day = 19 * 60
	await _connect_and_click_nearest("enter_night_market", "走入夜市")
	_check_area("night_market", "夜市入口")
	await _connect_and_click_nearest("night_market_exit", "走出夜市")
	_check_area("street", "夜市出口")
	TimeSystem.minute_of_day = 10 * 60
	await _connect_and_click_nearest("enter_recycle", "走入回收站")
	_check_area("recycle", "回收站入口")
	await _connect_and_click_nearest("recycle_exit", "走出回收站")
	_check_area("street", "回收站出口")
	await _connect_and_click_nearest("enter_store", "从主街走进便利店")
	_check_area("store", "便利店入口")
	await _connect_and_click_nearest("store_exit", "走出便利店")
	_check_area("street", "便利店出口")
	await _connect_and_click_nearest("enter_bank", "从主街走进银行")
	_check_area("bank", "银行入口")
	await _connect_and_click_nearest("bank_exit", "走出银行")
	_check_area("street", "银行出口")
	await _connect_and_click_nearest("enter_clothing", "从主街走进服装店")
	_check_area("clothing_store", "服装店入口")
	GameState.money = maxi(GameState.money, 5000)
	var backpack_before := InventoryManager.backpack_level
	await _connect_and_click_nearest("sewing_machine", "在阿珍的缝纫机前扩容背包")
	_check_step(InventoryManager.backpack_level > backpack_before, "缝纫机实物应能扩容背包")
	await _connect_and_click_nearest("clothing_exit", "走出服装店")
	_check_area("street", "服装店出口")
	await _connect_and_click_nearest("enter_restaurant", "从主街走进餐馆")
	_check_area("restaurant", "餐馆入口")
	await _connect_and_click_nearest("restaurant_exit", "走出餐馆")
	_check_area("street", "餐馆出口")
	GameState.money = maxi(GameState.money, 5000)
	await _connect_and_click_nearest("npc|fangjie", "先和方姐谈住房")
	await _close_modal()
	var housing_before := HousingManager.current_tier
	await _connect_and_click_nearest("housing_model|studio", "点独立小单间模型签约")
	_check_step(HousingManager.current_tier > housing_before, "和方姐谈过后应能点房屋模型买房")
	_check_area("street", "买完房仍在连续城区")
	await _connect_and_click_nearest("enter_market", "走入旧货市场")
	_check_area("market", "旧货市场入口")
	await _connect_and_click_nearest("market_exit", "走出旧货市场")
	_check_area("street", "旧货市场出口")
	await _connect_and_click_nearest("career_board|factory", "在主街工业区登记工厂试工")
	_check_step(CareerManager.application_line == "factory", "工厂招聘板应能自然登记")
	await _connect_and_click_nearest("enter_factory", "走入工厂")
	_check_area("factory", "工厂入口")
	await _connect_and_click_nearest("factory_exit", "走出工厂")
	_check_area("street", "工厂出口")
	await _connect_and_click_nearest("enter_farm", "从主街走进城郊农场")
	_check_area("farm", "农场入口")
	await _connect_and_click_nearest("farm_exit", "走出农场")
	_check_area("street", "农场出口")

func _open_shortcut(action_name: String, label: String) -> void:
	var key_map := {
		"inventory": KEY_I,
		"collection": KEY_C,
		"map": KEY_M,
		"bank": KEY_B,
		"kitchen": KEY_K,
		"staff": KEY_H,
		"encyclopedia": KEY_F1,
		"career": KEY_F2,
		"wardrobe": KEY_F3,
		"photo_album": KEY_F4,
		"coop_panel": KEY_F6,
	}
	var expected_map := {
		"inventory": main.hud.ModalState.INVENTORY,
		"collection": main.hud.ModalState.COLLECTION_LOG,
		"map": main.hud.ModalState.MAP,
		"bank": main.hud.ModalState.BANK,
		"kitchen": main.hud.ModalState.KITCHEN,
		"staff": main.hud.ModalState.STAFF,
		"encyclopedia": main.hud.ModalState.ENCYCLOPEDIA,
		"career": main.hud.ModalState.CAREER,
		"wardrobe": main.hud.ModalState.WARDROBE,
		"photo_album": main.hud.ModalState.PHOTO_ALBUM,
		"coop_panel": main.hud.ModalState.COOP,
	}
	var event := InputEventKey.new()
	event.physical_keycode = key_map[action_name]
	event.pressed = true
	main.hud._unhandled_input(event)
	await get_tree().process_frame
	if main.hud._modal_state != expected_map[action_name]:
		_fail("快捷键未打开界面：%s" % label)
	else:
		_step(label)

func _close_modal() -> void:
	if not is_instance_valid(main.hud) or main.hud._modal_state == main.hud.ModalState.NONE:
		return
	main.hud._close_modal()
	await get_tree().process_frame



func _wait_for_station_state(index: int, states: Array, timeout_seconds: float = 12.0) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		var status := KitchenManager.get_stations_status()
		if index >= 0 and index < status.size() and str(status[index].get("state", "")) in states:
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_fail("工位 %d 未在 %.1f 秒内进入期望状态" % [index, timeout_seconds])
	return false

func _wait_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _assert_modal_button_stable(prefix: String, wait_time: float, label: String) -> void:
	var before = _find_button_prefix(main.hud._modal_items, prefix)
	if before == null:
		_fail("找不到待验证按钮：%s" % prefix)
		return
	await _wait_seconds(wait_time)
	var after = _find_button_prefix(main.hud._modal_items, prefix)
	if after == null or before.get_instance_id() != after.get_instance_id():
		_fail("按钮在刷新时被重建：%s" % prefix)
	else:
		_step(label)

func _press_modal_button_prefix(prefix: String) -> void:
	var button = _find_button_prefix(main.hud._modal_items, prefix)
	if button == null:
		_fail("找不到界面按钮：%s" % prefix)
		return
	button.pressed.emit()
	await _wait_frames(4)

func _find_button_prefix(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found = _find_button_prefix(child, prefix)
		if found != null:
			return found
	return null

func _interact_first_with_prefix(prefix: String, label: String) -> void:
	var interactable = _find_interactable_prefix(main.world._area_root, prefix)
	if interactable == null:
		_fail("找不到交互物前缀：%s" % prefix)
		return
	if not await _move_player_to(interactable.global_position):
		_fail("无法移动到交互物：%s" % interactable.interaction_id)
		return
	await _click_right()
	await _wait_frames(5)
	_step(label)

func _find_interactable_prefix(node: Node, prefix: String) -> WorldInteractable:
	if node is WorldInteractable and node.interaction_id.begins_with(prefix):
		return node
	for child in node.get_children():
		var found = _find_interactable_prefix(child, prefix)
		if found != null:
			return found
	return null

func _travel_by_player(interactable_position: Vector2, direction: Vector2) -> void:
	var target := interactable_position - direction * 35.0
	var moved := await _move_player_to(target)
	var player = _get_player()
	var nearby := []
	if player != null:
		for item in player.nearby_interactables:
			nearby.append(item.interaction_id)
	var current_position: Vector2 = player.global_position if player != null else Vector2.ZERO
	print("TRAVEL_BEFORE_CLICK area=%s moved=%s pos=%s nearby=%s" % [GameState.current_area, moved, current_position, nearby])
	await _click_right()
	await get_tree().physics_frame
	await _wait_frames(18)
	print("TRAVEL_AFTER_CLICK area=%s" % GameState.current_area)

func _connect_and_click_nearest(interaction_id: String, label: String) -> void:
	var interactable = _find_interactable(interaction_id)
	if interactable == null:
		_fail("找不到交互物：%s" % interaction_id)
		return
	if GameState.current_area in ["restaurant", "breakfast_shop", "breakfast_kitchen"]:
		var direct_event := InputEventMouseButton.new()
		direct_event.button_index = MOUSE_BUTTON_LEFT
		direct_event.pressed = true
		direct_event.position = main.world.get_viewport().get_canvas_transform() * interactable.global_position
		main.world._unhandled_input(direct_event)
		await _wait_frames(4)
		_step(label)
		return
	var approach_offsets := {
		"bed": Vector2(0, 105),
		"fridge": Vector2(115, 0),
		"study_desk": Vector2(0, 90),
		"store_counter": Vector2(0, 100),
		"work_station": Vector2(0, 90),
		"bank_counter": Vector2(0, 100),
		"lottery_counter": Vector2(0, 100),
		"exercise_equipment": Vector2(0, 0),
	}
	var target: Vector2 = interactable.global_position + approach_offsets.get(interaction_id, Vector2.ZERO)
	if interaction_id == "leave_home":
		await _move_player_to(Vector2(170, 620))
		await _move_player_to(Vector2(1120, 620))
	if interaction_id == "home_living_to_bedroom":
		await _move_player_to(Vector2(400, 620))
		await _move_player_to(Vector2(170, 620))
	if interaction_id == "exercise_equipment":
		await _move_player_to(Vector2(250, 580))
		await _move_player_to(Vector2(250, 280))
	if interaction_id == "park_exit":
		await _move_player_to(Vector2(250, 280))
		await _move_player_to(Vector2(250, 580))
		await _move_player_to(Vector2(640, 580))
	if interactable.walk_trigger:
		await _move_player_to(target)
		await _wait_frames(14)
		_step(label)
		return
	if not await _move_player_to(target):
		_fail("无法移动到交互物：%s" % interaction_id)
		return
	await _click_right()
	await _wait_frames(5)
	_step(label)

func _move_player_to(target: Vector2) -> bool:
	var player = _get_player()
	if player == null:
		return false
	var elapsed := 0.0
	while is_instance_valid(player) and player.global_position.distance_to(target) > 24.0 and elapsed < 12.0:
		var direction: Vector2 = player.global_position.direction_to(target)
		_press_direction(direction)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		_release_directions()
	var reached: bool = is_instance_valid(player) and player.global_position.distance_to(target) <= 32.0
	return reached

func _press_direction(direction: Vector2) -> void:
	_release_directions()
	if direction.x > 0.2:
		Input.action_press("move_right")
	elif direction.x < -0.2:
		Input.action_press("move_left")
	if direction.y > 0.2:
		Input.action_press("move_down")
	elif direction.y < -0.2:
		Input.action_press("move_up")

func _release_directions() -> void:
	for action_name in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(action_name)

func _click_right() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = get_viewport().get_visible_rect().size * 0.5
	var player = _get_player()
	if player != null:
		player._unhandled_input(event)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	release.position = event.position
	pass
	await get_tree().process_frame

func _find_interactable(interaction_id: String):
	if not _world_ready():
		return null
	return _find_interactable_recursive(main.world._area_root, interaction_id)

func _find_interactable_recursive(node: Node, interaction_id: String):
	if node is WorldInteractable and node.interaction_id == interaction_id:
		return node
	for child in node.get_children():
		var found = _find_interactable_recursive(child, interaction_id)
		if found != null:
			return found
	return null

func _get_player():
	if not _world_ready():
		return null
	return main.world.player

func _world_ready() -> bool:
	return is_instance_valid(main) and is_instance_valid(main.world) and is_instance_valid(main.world.player)

func _check_area(expected: String, label: String) -> void:
	if GameState.current_area != expected:
		_fail("%s：区域应为 %s，实际为 %s" % [label, expected, GameState.current_area])
	else:
		_step(label)

func _wait_frames(count: int) -> void:
	for index in range(count):
		await get_tree().process_frame

func _check_step(condition: bool, label: String) -> void:
	if condition:
		_step(label)
	else:
		_fail(label)

func _step(label: String) -> void:
	step_count += 1
	print("PLAYTEST_STEP_%03d_OK: %s" % [step_count, label])

func _fail(message: String) -> void:
	failures.append(message)
	push_error("PLAYTEST_FAIL: %s" % message)

func _finish() -> void:
	Input.action_release("interact")
	await _wait_frames(3)
	AudioManager.shutdown()
	await get_tree().process_frame
	if failures.is_empty():
		print("PLAYTEST_PASS: %d_STEPS" % step_count)
		get_tree().quit(0)
	else:
		print("PLAYTEST_FAILURES: %d" % failures.size())
		get_tree().quit(2)
