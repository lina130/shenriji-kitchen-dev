extends Node

const TARGET_ASSETS := 50000
const MAX_DAYS := 365
var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_new_game()
	var business_once := false
	for day_index in range(MAX_DAYS):
		_run_day(day_index)
		if not business_once and BusinessManager.can_sell_business():
			BusinessManager.sell_business()
			business_once = true
		if _all_items_collected() and _total_assets() >= TARGET_ASSETS:
			break
		TimeSystem.sleep_to_next_morning(7)
	AudioManager.shutdown()
	await get_tree().process_frame
	_check(_all_items_collected(), "模拟结束仍未收集齐全部旧物")
	_check(_total_assets() >= TARGET_ASSETS, "模拟结束总资产未达到目标")
	_check(FinanceManager.total_interest > 0, "银行应实际产生并结算利息")
	_check(FinanceManager.lottery_spent > 0, "彩票系统应实际产生消费")
	_check(BusinessManager.customers_served > 0, "经营系统应实际服务客人")
	_check(BusinessManager.trade_profit != 0, "商品买卖系统应产生真实盈亏")
	var missing: Array[String] = []
	for item_id in ConfigDB.get_rows("collectibles"):
		if not bool(CollectionManager.discovered.get(item_id, false)):
			missing.append(item_id)
	if failures.is_empty():
		print("FULL_PROGRESSION_PASS days=%d assets=%d interest=%d served=%d items=%d" % [
			TimeSystem.current_day, _total_assets(), FinanceManager.total_interest,
			BusinessManager.customers_served, CollectionManager.discovered.size(),
		])
		get_tree().quit(0)
	else:
		if not missing.is_empty():
			print("MISSING_ITEMS=%s" % ",".join(missing))
		for failure in failures:
			push_error("FULL_PROGRESSION_FAIL: %s" % failure)
		get_tree().quit(1)

func _run_day(day_index: int) -> void:
	GameState.energy = GameState.max_energy
	TimeSystem.minute_of_day = 7 * 60
	GameState.work_factory_shift()
	_ensure_kitchen_stock()
	BusinessManager.labor_stock = BusinessManager.get_labor_capacity()
	BusinessManager.brain_stock = BusinessManager.get_brain_capacity()
	_run_kitchen_shift()
	_run_trade_cycle(day_index)
	_collect_all_daily_items()
	_run_bank_cycle(day_index)
	if BusinessManager.can_upgrade_business() and GameState.money >= BusinessManager.get_upgrade_cost():
		BusinessManager.upgrade_business()

func _ensure_kitchen_stock() -> void:
	for goods_id in ConfigDB.get_rows("goods"):
		var missing := 16 - BusinessManager.get_stock(goods_id)
		if missing > 0:
			BusinessManager.buy_goods(goods_id, missing)

func _run_kitchen_shift() -> void:
	if not KitchenManager.start_shift():
		return
	var guard := 0
	while KitchenManager.active and guard < 100:
		guard += 1
		if BusinessManager.labor_stock <= 0:
			BusinessManager.restock_labor()
		if BusinessManager.brain_stock <= 0:
			BusinessManager.restock_brain()
		if KitchenManager.orders.is_empty():
			KitchenManager._spawn_order()
		if KitchenManager.orders.is_empty():
			break
		var recipe_id := str(KitchenManager.orders[0].get("recipe_id", ""))
		if not BusinessManager.can_prepare_recipe(recipe_id):
			_ensure_kitchen_stock()
		if not KitchenManager.place_recipe(recipe_id, 0):
			break
		var station: Dictionary = KitchenManager.stations[0]
		station["progress"] = station["duration"]
		KitchenManager._update_stations(0.0)
		KitchenManager.advance_station(0)
		station["progress"] = station["duration"]
		KitchenManager._update_stations(0.0)
		KitchenManager.advance_station(0)
		KitchenManager.advance_station(0)
	KitchenManager.end_shift()

func _run_trade_cycle(day_index: int) -> void:
	if day_index % 2 == 0:
		BusinessManager.price_modifiers["flour"] = -0.18
		BusinessManager.buy_goods("flour", 5)
	else:
		BusinessManager.price_modifiers["flour"] = 0.18
		BusinessManager.sell_goods("flour", mini(5, BusinessManager.get_stock("flour")))

func _collect_all_daily_items() -> void:
	GameState.energy = GameState.max_energy
	for item_id in ConfigDB.get_rows("collectibles"):
		if bool(CollectionManager.discovered.get(item_id, false)):
			continue
		TreasureManager.force_find("street")

func _run_bank_cycle(day_index: int) -> void:
	if day_index % 5 == 0 and GameState.money > 3000:
		FinanceManager.deposit(1000)
	if day_index % 17 == 0 and FinanceManager.savings > 500:
		FinanceManager.withdraw(300)
	if day_index % 10 == 0 and GameState.money >= 10:
		FinanceManager.buy_lottery(1)

func _all_items_collected() -> bool:
	for item_id in ConfigDB.get_rows("collectibles"):
		if not bool(CollectionManager.discovered.get(item_id, false)):
			return false
	return true

func _total_assets() -> int:
	return GameState.money + FinanceManager.savings + BusinessManager.get_stock_value()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)