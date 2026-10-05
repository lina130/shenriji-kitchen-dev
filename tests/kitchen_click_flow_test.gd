extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var kitchen := root.get_node_or_null("KitchenManager")
	var business := root.get_node_or_null("BusinessManager")
	var market_phase := root.get_node_or_null("MarketPhaseManager")
	var time_system := root.get_node_or_null("TimeSystem")
	if kitchen == null or business == null or market_phase == null or time_system == null:
		_fail("经营所需 autoload 未加载")
		_finish()
		return

	kitchen.call("reset_new_game")
	time_system.set("minute_of_day", 7 * 60)
	market_phase.call("force_refresh")
	var goods: Dictionary = business.get("goods_stock")
	for goods_id in goods.keys():
		goods[goods_id] = 20
	business.set("goods_stock", goods)
	business.set("labor_stock", 30)
	business.set("brain_stock", 30)

	var started: bool = bool(kitchen.call("start_shift_for", "breakfast_shop"))
	_check(started and bool(kitchen.get("active")), "早市应能开档")
	if not started:
		_finish()
		return
	kitchen.call("set_process", false)

	var orders: Array = kitchen.get("orders")
	_check(not orders.is_empty(), "开档后应有随机顾客队列")
	if orders.is_empty():
		_finish()
		return
	orders[0]["recipe_id"] = "tea_egg"
	orders[0]["state"] = "waiting"
	orders[0]["patience"] = 180.0
	orders[0]["patience_max"] = 180.0

	var picked_order: bool = bool(kitchen.call("handle_order_tap", 0))
	var hand: Dictionary = kitchen.call("get_hand_status")
	_check(picked_order and str(hand.get("kind", "")) == "order", "点顾客应把订单拿在手上")
	_check(str(hand.get("recipe_id", "")) == "tea_egg", "手上订单应保留菜品工序")

	var prep_index := _find_idle_station(kitchen, str(hand.get("station_type", "")))
	_check(prep_index >= 0, "早市应有空闲备料台")
	if prep_index >= 0:
		_check(bool(kitchen.call("handle_station_action", prep_index)), "点对应工位应放下订单并开工")
		_check(bool(kitchen.call("get_hand_status").get("empty", false)), "放下订单后手应空出来")
		_complete_station(kitchen, prep_index)
		_check(bool(kitchen.call("handle_station_action", prep_index)), "备料完成后点工位应把半成品放上托盘")

	var staging_status: Array = kitchen.call("get_staging_status")
	_check(not staging_status.is_empty(), "半成品应进入暂存托盘")
	if not staging_status.is_empty():
		_check(bool(kitchen.call("load_staging", 0, 0)), "点托盘应把半成品拿到手上")
		hand = kitchen.call("get_hand_status")
		_check(str(hand.get("kind", "")) == "staging", "托盘拿起后手上应是半成品")
		var drink_index := _find_idle_station(kitchen, str(hand.get("station_type", "")))
		_check(drink_index >= 0, "早市应有空闲饮品台")
		if drink_index >= 0:
			_check(bool(kitchen.call("handle_station_action", drink_index)), "半成品应能手动放到饮品台")
			_complete_station(kitchen, drink_index)
			_check(bool(kitchen.call("handle_station_action", drink_index)), "饮品完成后应回到托盘")

	staging_status = kitchen.call("get_staging_status")
	if not staging_status.is_empty():
		_check(bool(kitchen.call("load_staging", 0, 0)), "点托盘应拿起出餐前成品")
		hand = kitchen.call("get_hand_status")
		var serve_index := _find_idle_station(kitchen, str(hand.get("station_type", "")))
		_check(serve_index >= 0, "早市应有空闲出餐台")
		if serve_index >= 0:
			_check(bool(kitchen.call("handle_station_action", serve_index)), "成品应能手动放到出餐台")
			_complete_station(kitchen, serve_index)
			_check(bool(kitchen.call("handle_station_action", serve_index)), "点出餐台应交付匹配订单")

	_check(int(kitchen.get("served")) == 1, "完整点击流水线应出餐 1 单")
	_check(bool(kitchen.call("get_hand_status").get("empty", false)), "出餐后手应空出来")
	var failed_before := int(kitchen.get("failed"))
	var remaining_orders: Array = kitchen.get("orders")
	if not remaining_orders.is_empty():
		remaining_orders[0]["patience"] = 0.05
		kitchen.call("_update_orders", 0.1)
		_check(int(kitchen.get("failed")) > failed_before, "顾客耐心归零应离场并计入失败")
	kitchen.call("end_shift", "manual")
	_finish()

func _find_idle_station(kitchen: Object, station_type: String) -> int:
	for station in kitchen.call("get_stations_status"):
		if str(station.get("type", "")) == station_type and str(station.get("state", "")) == "idle":
			return int(station.get("index", -1))
	return -1

func _complete_station(kitchen: Object, station_index: int) -> void:
	var stations: Array = kitchen.get("stations")
	if station_index < 0 or station_index >= stations.size():
		return
	var station: Dictionary = stations[station_index]
	station["progress"] = float(station.get("duration", 1.0))
	kitchen.call("_update_stations", 0.0)

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
		print("KITCHEN_CLICK_FLOW_PASS")
		call_deferred("quit", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("quit", 1)
