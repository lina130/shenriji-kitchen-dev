extends Node

## 多工序流水线厨房。每个工位只处理自己类型的工序，
## 半成品完成后进入托盘，玩家再把它送到下一类工位。

signal changed
signal shift_ended(summary: Dictionary)
signal pipeline_changed

const STAGE_STATION_MAP := {
	"prep": "prep",
	"mix": "prep",
	"wrap": "prep",
	"steam": "steamer",
	"fry": "fryer",
	"stove": "fryer",
	"boil": "soup_pot",
	"soup": "soup_pot",
	"drink": "drink",
	"serve": "serve",
	"plate": "serve",
}
const STAGE_NAMES := {
	"prep": "备料",
	"mix": "和面",
	"wrap": "包馅",
	"steam": "上笼蒸",
	"fry": "下锅",
	"stove": "炒制",
	"boil": "慢熬",
	"soup": "熬汤",
	"drink": "饮品调制",
	"serve": "装盘出餐",
	"plate": "装盘",
}
const STATION_NAMES := {
	"prep": "备料台",
	"steamer": "蒸笼",
	"fryer": "油锅",
	"soup_pot": "汤锅",
	"drink": "饮品台",
	"serve": "出餐台",
}

var active := false
var time_left := 0.0
var orders: Array = []
var stations: Array = []
var staging: Array = []
var hand: Dictionary = {}
var combo := 0
var max_combo := 0
var served := 0
var failed := 0
var last_serve_time := 0.0
var shift_earned := 0
var _order_counter := 0
var _sync_accumulator := 0.0
var _spawn_timer := 0.0
var location_id := "restaurant"
var active_phase_id := ""
var equipment_levels: Dictionary = {}
var rush_active := false
var rush_name := ""

func _ready() -> void:
	set_process(true)
	reset_new_game()

func _process(delta: float) -> void:
	if not active:
		return
	if not MarketPhaseManager.is_location_open(location_id, active_phase_id):
		on_market_phase_changed(MarketPhaseManager.current_phase_id, active_phase_id)
		return
	_update_rush_state()
	time_left = maxf(0.0, time_left - delta)
	_update_stations(delta)
	_update_orders(delta)
	_update_customer_flow(delta)
	_sync_accumulator += delta
	if _sync_accumulator >= 0.12:
		_sync_accumulator = 0.0
		changed.emit()
	if time_left <= 0.0 or served >= get_order_target():
		end_shift("complete")

func start_shift() -> bool:
	return start_shift_for("restaurant")

func start_shift_for(location: String) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("kitchen_start", {"location": location})
	if active:
		return false
	MarketPhaseManager.force_refresh()
	var phase_id := MarketPhaseManager.current_phase_id
	if not MarketPhaseManager.is_location_open(location, phase_id):
		if location == "breakfast_shop":
			NoticeManager.show_message("早餐店只在 06:00–10:30 的早市营业，错过就等明天。", "warning")
		else:
			NoticeManager.show_message("现在不是午市或晚市，门口还挂着休息牌。", "warning")
		return false
	if BusinessManager.labor_stock <= 0 or BusinessManager.brain_stock <= 0:
		NoticeManager.show_message("今天没有足够劳力或脑力，先休息或补库存。", "warning")
		return false
	location_id = location
	active_phase_id = phase_id
	active = true
	rush_active = MarketPhaseManager.is_rush_minute(TimeSystem.minute_of_day, active_phase_id)
	rush_name = MarketPhaseManager.get_rush_name(active_phase_id) if rush_active else ""
	time_left = float(ConfigDB.get_number("breakfast", "shift_duration", 75.0)) if location == "breakfast_shop" else float(ConfigDB.get_number("business", "shift_duration", 120.0))
	orders.clear()
	staging.clear()
	hand.clear()
	stations.clear()
	combo = 0
	max_combo = 0
	served = 0
	failed = 0
	last_serve_time = 0.0
	shift_earned = 0
	_build_stations_for_phase(phase_id)
	for _index in range(2):
		_spawn_order()
	_spawn_timer = 1.1
	NoticeManager.show_message(_opening_text(), "positive")
	if rush_active:
		NoticeManager.show_npc_message("%s来了，先把快单顶住。" % rush_name, "厨房师傅", "warning")
	SaveManager.request_auto_save("shift_open")
	changed.emit()
	return true

func _opening_text() -> String:
	match active_phase_id:
		"morning":
			return "早市开档，包子、豆浆、油条各有自己的工序。"
		"lunch":
			return "午市开档，快菜和套餐要趁客人还多的时候做。"
		"dinner":
			return "晚市开档，工序更长，先看订单再安排工位。"
	return "档口开张。"

func _build_stations_for_phase(phase_id: String) -> void:
	stations.clear()
	for station_type in get_station_definitions(phase_id):
		stations.append(_new_station(station_type))
	changed.emit()

func get_station_definitions(phase_id: String = "") -> Array[String]:
	var resolved := phase_id if not phase_id.is_empty() else MarketPhaseManager.current_phase_id
	if resolved == "morning":
		return ["prep", "prep", "steamer", "fryer", "soup_pot", "drink", "serve"]
	if resolved == "lunch":
		return ["prep", "prep", "soup_pot", "fryer", "drink", "serve"]
	if resolved == "dinner":
		return ["prep", "prep", "fryer", "soup_pot", "drink", "serve"]
	return ["prep", "prep", "fryer", "serve"]

func _new_station(station_type: String) -> Dictionary:
	return {
		"type": station_type,
		"state": "idle",
		"recipe_id": "",
		"job": {},
		"progress": 0.0,
		"duration": 0.0,
	}

func place_recipe(recipe_id: String, station_index: int) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("kitchen_recipe", {"recipe_id": recipe_id, "station_index": station_index})
	if not active or station_index < 0 or station_index >= stations.size():
		return false
	var station: Dictionary = stations[station_index]
	if str(station.get("state", "idle")) != "idle":
		NoticeManager.show_message("这个工位正忙着。", "hint")
		return false
	if not recipe_id in _candidate_recipes():
		NoticeManager.show_message("这道菜不在当前时段的菜单里。", "warning")
		return false
	var pipeline := _parse_pipeline(recipe_id)
	if pipeline.is_empty():
		return false
	var first_stage: Dictionary = pipeline[0]
	if str(station.get("type", "")) != str(first_stage.get("station_type", "")):
		NoticeManager.show_message("这道菜要先从%s开始。" % get_station_name(str(first_stage.get("station_type", ""))), "hint")
		return false
	if not BusinessManager.consume_recipe_inputs(recipe_id):
		return false
	if(get_node_or_null("/root/CollectionManager") != null):
		CollectionManager.record_recipe_seen(recipe_id)
	_assign_job(station_index, recipe_id, 0, pipeline)
	changed.emit()
	return true

func _assign_job(station_index: int, recipe_id: String, stage_index: int, pipeline: Array) -> void:
	var stage: Dictionary = pipeline[stage_index]
	var station: Dictionary = stations[station_index]
	station["recipe_id"] = recipe_id
	station["state"] = "processing"
	station["progress"] = 0.0
	station["duration"] = maxf(0.15, float(stage.get("duration", 1.0)))
	station["job"] = {
		"recipe_id": recipe_id,
		"stage_index": stage_index,
		"stage_id": str(stage.get("stage_id", "")),
		"station_type": str(stage.get("station_type", "")),
	}

func handle_order_tap(order_index: int = -1) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("kitchen_order_tap", {"order_index": order_index})
	if not active or orders.is_empty():
		NoticeManager.show_message("门口还没有客人，先开门等一会儿。", "hint")
		return false
	var resolved_index := order_index
	if resolved_index < 0:
		resolved_index = _first_waiting_order_index()
	if resolved_index < 0 or resolved_index >= orders.size():
		NoticeManager.show_message("这张订单已经不在队列里了。", "hint")
		return false
	var order: Dictionary = orders[resolved_index]
	if str(order.get("state", "waiting")) != "waiting":
		NoticeManager.show_message("这张单已经在手上或工位上了。", "hint")
		return false
	var order_id := int(order.get("id", -1))
	if not hand.is_empty():
		if str(hand.get("kind", "")) == "order" and int(hand.get("order_id", -1)) == order_id:
			cancel_hand()
			NoticeManager.show_message("订单放回队列，先做别的。", "hint")
			return true
		NoticeManager.show_message("手里还拿着%s，先放到对应工位。" % str(hand.get("display_name", "东西")), "hint")
		return false
	var recipe_id := str(order.get("recipe_id", ""))
	var pipeline := _parse_pipeline(recipe_id)
	if pipeline.is_empty():
		NoticeManager.show_message("这道菜还没有可以执行的工序。", "warning")
		return false
	var first_stage: Dictionary = pipeline[0]
	var station_type := str(first_stage.get("station_type", "prep"))
	order["state"] = "hand"
	orders[resolved_index] = order
	hand = {
		"kind": "order",
		"order_id": order_id,
		"recipe_id": recipe_id,
		"stage_index": 0,
		"stage_id": str(first_stage.get("stage_id", "")),
		"station_type": station_type,
		"display_name": get_recipe_name(recipe_id),
	}
	NoticeManager.show_message("拿起了%s的订单，去%s开第一道工序。" % [
		str(hand.get("display_name", recipe_id)),
		get_station_name(station_type),
	], "positive")
	changed.emit()
	return true

func handle_tray_tap(staging_index: int) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("kitchen_tray_tap", {"staging_index": staging_index})
	if not active or staging_index < 0 or staging_index >= staging.size():
		NoticeManager.show_message("这个托盘现在是空的。", "hint")
		return false
	if not hand.is_empty():
		if str(hand.get("kind", "")) == "staging" and int(hand.get("source_index", -1)) == staging_index:
			cancel_hand()
			NoticeManager.show_message("半成品放回托盘。", "hint")
			return true
		NoticeManager.show_message("手里还拿着%s，先放到对应工位。" % str(hand.get("display_name", "东西")), "hint")
		return false
	var tray: Dictionary = staging[staging_index]
	var station_type := str(tray.get("station_type", ""))
	hand = {
		"kind": "staging",
		"recipe_id": str(tray.get("recipe_id", "")),
		"stage_index": int(tray.get("stage_index", 0)),
		"stage_id": str(tray.get("stage_id", "")),
		"station_type": station_type,
		"display_name": get_recipe_name(str(tray.get("recipe_id", ""))),
		"source_index": staging_index,
	}
	staging.remove_at(staging_index)
	NoticeManager.show_message("拿起%s的半成品，点%s继续。" % [
		str(hand.get("display_name", "")),
		get_station_name(station_type),
	], "positive")
	changed.emit()
	return true

func cancel_hand() -> bool:
	if hand.is_empty():
		return false
	var kind := str(hand.get("kind", ""))
	if kind == "order":
		var order_index := _find_order_index_by_id(int(hand.get("order_id", -1)))
		if order_index >= 0:
			orders[order_index]["state"] = "waiting"
	elif kind == "staging":
		staging.append({
			"recipe_id": str(hand.get("recipe_id", "")),
			"stage_index": int(hand.get("stage_index", 0)),
			"stage_id": str(hand.get("stage_id", "")),
			"station_type": str(hand.get("station_type", "")),
		})
	hand.clear()
	changed.emit()
	return true

func get_hand_status() -> Dictionary:
	if hand.is_empty():
		return {
			"empty": true,
			"prompt": "点顾客拿起订单，或点托盘拿起半成品。",
		}
	var result: Dictionary = hand.duplicate(true)
	result["empty"] = false
	result["name"] = str(hand.get("display_name", ""))
	result["stage_name"] = get_stage_name(str(hand.get("stage_id", "")))
	result["station_name"] = get_station_name(str(hand.get("station_type", "")))
	result["prompt"] = "去%s" % str(result["station_name"])
	return result

func _place_hand_at_station(station_index: int) -> bool:
	if hand.is_empty() or station_index < 0 or station_index >= stations.size():
		return false
	var station: Dictionary = stations[station_index]
	if str(station.get("state", "idle")) != "idle":
		return false
	var station_type := str(station.get("type", ""))
	if str(hand.get("station_type", "")) != station_type:
		NoticeManager.show_message("手上的%s要放到%s。" % [
			str(hand.get("display_name", "东西")),
			get_station_name(str(hand.get("station_type", ""))),
		], "hint")
		return false
	var recipe_id := str(hand.get("recipe_id", ""))
	var stage_index := int(hand.get("stage_index", 0))
	var pipeline := _parse_pipeline(recipe_id)
	if pipeline.is_empty() or stage_index >= pipeline.size():
		cancel_hand()
		NoticeManager.show_message("这份东西的工序已经不对，先放回托盘。", "warning")
		return false
	var kind := str(hand.get("kind", ""))
	var order_index := -1
	if kind == "order":
		order_index = _find_order_index_by_id(int(hand.get("order_id", -1)))
		if order_index < 0:
			hand.clear()
			NoticeManager.show_message("这位客人已经走了，订单失效。", "warning")
			changed.emit()
			return false
		if not BusinessManager.consume_recipe_inputs(recipe_id):
			return false
		if get_node_or_null("/root/CollectionManager") != null:
			CollectionManager.record_recipe_seen(recipe_id)
		orders[order_index]["state"] = "processing"
	elif kind != "staging":
		return false
	_assign_job(station_index, recipe_id, stage_index, pipeline)
	hand.clear()
	NoticeManager.show_message("把%s放上%s，开始%s。" % [
		get_recipe_name(recipe_id),
		get_station_name(station_type),
		get_stage_name(str(pipeline[stage_index].get("stage_id", ""))),
	], "positive")
	changed.emit()
	return true

func _first_waiting_order_index() -> int:
	for index in range(orders.size()):
		if str(orders[index].get("state", "waiting")) == "waiting":
			return index
	return -1

func _find_order_index_by_id(order_id: int) -> int:
	for index in range(orders.size()):
		if int(orders[index].get("id", -1)) == order_id:
			return index
	return -1

func prepare_next_order(station_index: int) -> bool:
	if not active or station_index < 0 or station_index >= stations.size():
		return false
	var station_type := str(stations[station_index].get("type", ""))
	for order in orders:
		var recipe_id := str(order.get("recipe_id", ""))
		var pipeline := _parse_pipeline(recipe_id)
		if not pipeline.is_empty() and str(pipeline[0].get("station_type", "")) == station_type:
			return place_recipe(recipe_id, station_index)
	NoticeManager.show_message("当前订单没有适合这个工位的工序。", "hint")
	return false

func advance_station(station_index: int) -> bool:
	return handle_station_action(station_index)

func handle_station_action(station_index: int) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("kitchen_station", {"station_index": station_index})
	if not active or station_index < 0 or station_index >= stations.size():
		NoticeManager.show_message("档口还没开张。", "warning")
		return false
	var station: Dictionary = stations[station_index]
	var state := str(station.get("state", "idle"))
	if state == "idle":
		if not hand.is_empty():
			return _place_hand_at_station(station_index)
		if _load_best_staging(station_index):
			return true
		return prepare_next_order(station_index)
	if state == "processing":
		NoticeManager.show_message("工序还在进行，记得盯火候。", "hint")
		return false
	if state == "stage_ready":
		return _release_station_output(station_index)
	if state == "ready":
		return _serve_station(station_index)
	return false

func _release_station_output(station_index: int) -> bool:
	var station: Dictionary = stations[station_index]
	var job: Dictionary = station.get("job", {})
	var recipe_id := str(job.get("recipe_id", ""))
	var pipeline := _parse_pipeline(recipe_id)
	var stage_index := int(job.get("stage_index", 0))
	if stage_index + 1 >= pipeline.size():
		station["state"] = "ready"
		return _serve_station(station_index)
	var next_stage: Dictionary = pipeline[stage_index + 1]
	staging.append({
		"recipe_id": recipe_id,
		"stage_index": stage_index + 1,
		"stage_id": str(next_stage.get("stage_id", "")),
		"station_type": str(next_stage.get("station_type", "")),
	})
	_clear_station(station_index)
	NoticeManager.show_message("半成品放上托盘，送到%s继续。" % get_station_name(str(next_stage.get("station_type", ""))), "hint")
	changed.emit()
	return true

func load_staging(staging_index: int, station_index: int) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("kitchen_load_staging", {"staging_index": staging_index, "station_index": station_index})
	if station_index < 0 or location_id == "breakfast_shop":
		return handle_tray_tap(staging_index)
	if not active or staging_index < 0 or staging_index >= staging.size():
		return false
	if station_index < 0 or station_index >= stations.size():
		return false
	var tray: Dictionary = staging[staging_index]
	var station: Dictionary = stations[station_index]
	if str(station.get("state", "idle")) != "idle":
		return false
	if str(station.get("type", "")) != str(tray.get("station_type", "")):
		NoticeManager.show_message("托盘里的半成品不能放到这个工位。", "hint")
		return false
	var recipe_id := str(tray.get("recipe_id", ""))
	var stage_index := int(tray.get("stage_index", 0))
	var pipeline := _parse_pipeline(recipe_id)
	if pipeline.is_empty() or stage_index >= pipeline.size():
		staging.remove_at(staging_index)
		return false
	staging.remove_at(staging_index)
	_assign_job(station_index, recipe_id, stage_index, pipeline)
	changed.emit()
	return true

func _load_best_staging(station_index: int) -> bool:
	var station_type := str(stations[station_index].get("type", ""))
	for index in range(staging.size()):
		if str(staging[index].get("station_type", "")) == station_type:
			return load_staging(index, station_index)
	return false

func serve_ready_station() -> bool:
	for index in range(stations.size()):
		if str(stations[index].get("state", "idle")) == "ready":
			return _serve_station(index)
	NoticeManager.show_message("还没有走到出餐台的成品。", "hint")
	return false

func _serve_station(station_index: int) -> bool:
	var station: Dictionary = stations[station_index]
	var recipe_id := str(station.get("recipe_id", ""))
	var order_index := _find_matching_order(recipe_id)
	if order_index < 0:
		failed += 1
		combo = 0
		BusinessManager.register_failed_order()
		_clear_station(station_index)
		NoticeManager.show_message("端错了单，这道%s只能算损耗。" % get_recipe_name(recipe_id), "warning")
		changed.emit()
		return false
	var now := Time.get_ticks_msec() / 1000.0
	combo = combo + 1 if now - last_serve_time <= 6.0 else 1
	max_combo = maxi(max_combo, combo)
	last_serve_time = now
	var order: Dictionary = orders[order_index]
	var customer_name := str(order.get("customer_name", "客人"))
	var revenue := BusinessManager.register_recipe_sale(recipe_id, combo)
	var tip := int(round(float(revenue) * float(order.get("tip_rate", 0.0))))
	if tip > 0:
		GameState.earn(tip)
		shift_earned += tip
	var recipe_name := str(ConfigDB.get_row("recipes", recipe_id).get("name", recipe_id))
	NoticeManager.show_npc_message("把%s端给我吧，这单 ¥%d%s。" % [
		recipe_name,
		revenue + tip,
		" · 连击 ×%d" % combo if combo > 1 else "",
	], customer_name, "positive")
	orders.remove_at(order_index)
	_clear_station(station_index)
	served += 1
	if served == 1:
		StoryManager.record_action("first_serve")
	StaffManager.record_work("serve", 1.0)
	TreasureManager.try_trigger("serve_dish")
	_spawn_order()
	if served >= get_order_target():
		end_shift("complete")
	changed.emit()
	return true

func _clear_station(station_index: int) -> void:
	var station: Dictionary = stations[station_index]
	station["state"] = "idle"
	station["recipe_id"] = ""
	station["job"] = {}
	station["progress"] = 0.0
	station["duration"] = 0.0

func end_shift(reason: String = "manual") -> void:
	if CoopManager.is_client_view_only():
		CoopManager.request_shared_action("kitchen_end", {"reason": reason})
		return
	if not active:
		return
	active = false
	var lost := orders.size()
	failed += lost
	for _index in range(lost):
		BusinessManager.register_failed_order()
	orders.clear()
	staging.clear()
	hand.clear()
	for station_index in range(stations.size()):
		_clear_station(station_index)
	TimeSystem.advance_minutes(210 if location_id == "breakfast_shop" else 300)
	var summary := {
		"earned": shift_earned,
		"served": served,
		"failed": failed,
		"lost": lost,
		"combo": combo,
		"max_combo": max_combo,
		"rush_active": rush_active,
		"phase": active_phase_id,
		"reason": reason,
	}
	if reason != "transition":
		var label := "早餐收档" if location_id == "breakfast_shop" else "夜市打烊"
		NoticeManager.show_message("%s，卖了 %d 单，进账 ¥%d。" % [label, served, shift_earned], "positive")
	if CareerManager.is_employed_in("restaurant"):
		AchievementManager.record_event("career_route:restaurant")
		var quality := clampf(float(served) / maxf(1.0, float(served + failed)), 0.25, 1.35)
		CareerManager.record_shift("restaurant", quality)
	SaveManager.request_auto_save("shift_end")
	shift_ended.emit(summary)
	changed.emit()

func on_market_phase_changed(new_phase_id: String, previous_phase_id: String) -> void:
	if not active:
		pipeline_changed.emit()
		return
	var lost := orders.size()
	failed += lost
	for _index in range(lost):
		BusinessManager.register_failed_order()
	active = false
	orders.clear()
	staging.clear()
	hand.clear()
	for station_index in range(stations.size()):
		_clear_station(station_index)
	NoticeManager.show_message("%s结束，未完成的备料和设备都清场了，错过客流不补。" % MarketPhaseManager.get_phase_name(previous_phase_id), "warning")
	SaveManager.request_auto_save("market_transition")
	shift_ended.emit({
		"earned": shift_earned,
		"served": served,
		"failed": failed,
		"lost": lost,
		"combo": combo,
		"phase": previous_phase_id,
		"next_phase": new_phase_id,
		"reason": "transition",
	})
	changed.emit()

func _update_stations(delta: float) -> void:
	for station in stations:
		if str(station.get("state", "idle")) != "processing":
			continue
		var speed := get_station_speed_multiplier(str(station.get("type", "")))
		station["progress"] = float(station.get("progress", 0.0)) + delta * speed
		if float(station["progress"]) >= float(station.get("duration", 1.0)):
			station["progress"] = float(station.get("duration", 1.0))
			var job: Dictionary = station.get("job", {})
			var pipeline := _parse_pipeline(str(job.get("recipe_id", "")))
			var stage_index := int(job.get("stage_index", 0))
			station["state"] = "ready" if stage_index + 1 >= pipeline.size() else "stage_ready"
			StaffManager.record_work(str(station.get("type", "prep")), float(station.get("duration", 1.0)))

func _update_orders(delta: float) -> void:
	var remaining: Array = []
	for order in orders:
		order["patience"] = float(order.get("patience", 0.0)) - delta
		if float(order["patience"]) <= 0.0:
			failed += 1
			combo = 0
			BusinessManager.register_failed_order()
			var customer_name := str(order.get("customer_name", "客人"))
			var leave_line := str(order.get("leave_line", "等太久了，先走了。"))
			NoticeManager.show_npc_message("%s（连击断了）" % leave_line, customer_name, "warning")
		else:
			remaining.append(order)
	orders = remaining

func _update_rush_state() -> void:
	if not active:
		rush_active = false
		rush_name = ""
		return
	var next_rush := MarketPhaseManager.is_rush_minute(TimeSystem.minute_of_day, active_phase_id)
	if next_rush == rush_active:
		return
	rush_active = next_rush
	rush_name = MarketPhaseManager.get_rush_name(active_phase_id) if rush_active else ""
	if rush_active:
		NoticeManager.show_npc_message("%s来了，门口一下排起来了。" % rush_name, "厨房师傅", "warning")
	else:
		NoticeManager.show_npc_message("这一波过去了，门口能喘口气。", "厨房师傅", "positive")

func get_rush_status_text() -> String:
	return "客流高峰：%s" % rush_name if rush_active else ""

func _update_customer_flow(delta: float) -> void:
	var capacity := maxi(1, int(ConfigDB.get_number("business", "queue_capacity", 5)))
	if served + orders.size() >= get_order_target():
		return
	_spawn_timer = maxf(0.0, _spawn_timer - delta)
	if orders.size() >= capacity or _spawn_timer > 0.0:
		return
	_spawn_order()
	var demand := maxf(0.65, MarketPhaseManager.get_demand_multiplier(active_phase_id))
	var hurry := 1.0 + maxf(0.0, 1.0 - demand) * 0.30
	var rush_multiplier := MarketPhaseManager.get_rush_spawn_multiplier(active_phase_id) if rush_active else 1.0
	_spawn_timer = RandomManager.rng.randf_range(2.2, 5.0) * hurry / demand / rush_multiplier


func _spawn_order() -> void:
	var candidates := _candidate_recipes()
	if candidates.is_empty():
		return
	_order_counter += 1
	var customer := _pick_customer()
	var recipe_id := _pick_customer_recipe(customer, candidates)
	var customer_name := str(customer.get("name", "客人"))
	var phase_row := MarketPhaseManager.get_phase_row(active_phase_id)
	var patience_multiplier := float(phase_row.get("patience_multiplier", "1.0"))
	var customer_patience := float(customer.get("patience_multiplier", "1.0"))
	var rush_patience := MarketPhaseManager.get_rush_patience_multiplier(active_phase_id) if rush_active else 1.0
	var rush_tip := MarketPhaseManager.get_rush_tip_bonus(active_phase_id) if rush_active else 0.0
	var patience_value := (maxf(8.0, 22.0 - float(_order_counter) * 0.25) * patience_multiplier * customer_patience * rush_patience) + RelationshipManager.get_patience_bonus()
	orders.append({
		"id": _order_counter,
		"recipe_id": recipe_id,
		"customer_id": str(customer.get("customer_id", "regular")),
		"customer_name": customer_name,
		"customer_line": str(customer.get("line", "")),
		"leave_line": str(customer.get("leave_line", "等太久了，先走了。")),
		"tip_rate": float(customer.get("tip_rate", "0.0")) + rush_tip,
		"patience": patience_value,
		"patience_max": patience_value,
		"queue_position": orders.size() + 1,
		"state": "waiting",
	})
	if _order_counter <= 2 or RandomManager.rng.randf() < 0.18:
		NoticeManager.show_npc_message(str(customer.get("line", "慢慢来，不急。")), customer_name, "hint")

func _pick_customer_recipe(customer: Dictionary, candidates: Array[String]) -> String:
	var preferred: Array[String] = []
	for recipe_id in str(customer.get("preferred_recipe_ids", "")).split("|", false):
		if str(recipe_id) in candidates:
			preferred.append(str(recipe_id))
	if not preferred.is_empty() and RandomManager.rng.randf() < 0.72:
		return str(RandomManager.pick(preferred))
	return str(RandomManager.pick(candidates))

func _pick_customer() -> Dictionary:
	var rows := ConfigDB.get_rows("customer_types")
	if rows.is_empty():
		return {
			"customer_id": "regular",
			"name": "熟客",
			"patience_multiplier": "1.0",
			"tip_rate": "0.0",
			"line": "慢慢来，不急。",
			"leave_line": "等太久了，先走了。",
		}
	var entries: Array[Dictionary] = []
	var total := 0.0
	for customer_id in rows:
		var row: Dictionary = rows[customer_id]
		var effective := maxf(0.05, float(row.get("weight", "1.0")) * _customer_phase_bonus(str(row.get("phase_bonus", "")), active_phase_id))
		entries.append({"row": row, "weight": effective})
		total += effective
	var roll := RandomManager.rng.randf_range(0.0, maxf(0.001, total))
	var cursor := 0.0
	for entry in entries:
		cursor += float(entry.get("weight", 0.0))
		if roll <= cursor:
			return entry.get("row", {})
	return entries[0].get("row", {})

func _customer_phase_bonus(text: String, phase_id: String) -> float:
	if text.is_empty():
		return 1.0
	for part in text.split("|", false):
		var pieces := part.split(":", false)
		if pieces.size() == 2 and (pieces[0] == "any" or pieces[0] == phase_id):
			return float(pieces[1])
	return 0.35

func _candidate_recipes() -> Array[String]:
	var result: Array[String] = []
	for recipe_id in BusinessManager.get_unlocked_recipe_ids():
		var row := ConfigDB.get_row("recipes", recipe_id)
		var phases := str(row.get("phases", "")).split("|", false)
		if active_phase_id in phases or str(recipe_id) in MarketPhaseManager.get_festival_recipe_ids():
			result.append(str(recipe_id))
	return result

func _find_matching_order(recipe_id: String) -> int:
	for index in range(orders.size()):
		if str(orders[index].get("recipe_id", "")) == recipe_id:
			return index
	return -1

func _parse_pipeline(recipe_id: String) -> Array:
	var result: Array = []
	var recipe := ConfigDB.get_row("recipes", recipe_id)
	var text := str(recipe.get("pipeline", ""))
	if text.is_empty():
		text = "prep:%s|serve:0.6" % str(recipe.get("prep_seconds", "3.0"))
	for part in text.split("|", false):
		var pieces := part.split(":", false)
		if pieces.size() < 2:
			continue
		var stage_id := str(pieces[0])
		var duration := float(pieces[1])
		var station_type := str(pieces[2]) if pieces.size() >= 3 else str(STAGE_STATION_MAP.get(stage_id, "prep"))
		result.append({
			"stage_id": stage_id,
			"station_type": station_type,
			"duration": duration,
		})
	return result

func get_order_target() -> int:
	if location_id == "breakfast_shop":
		return int(ConfigDB.get_number("breakfast", "shift_order_target", 8))
	return int(ConfigDB.get_number("business", "shift_order_target", 12))

func get_recipe_name(recipe_id: String) -> String:
	return str(ConfigDB.get_row("recipes", recipe_id).get("name", recipe_id))

func get_station_name(station_type: String) -> String:
	return str(STATION_NAMES.get(station_type, station_type))

func get_stage_name(stage_id: String) -> String:
	return str(STAGE_NAMES.get(stage_id, stage_id))

func get_first_station_type(recipe_id: String) -> String:
	var pipeline := _parse_pipeline(recipe_id)
	if pipeline.is_empty():
		return "prep"
	return str(pipeline[0].get("station_type", "prep"))

func get_pipeline_text(recipe_id: String) -> String:
	var names: Array[String] = []
	for stage in _parse_pipeline(recipe_id):
		names.append("%s/%s" % [get_stage_name(str(stage.get("stage_id", ""))), get_station_name(str(stage.get("station_type", "")))])
	return " → ".join(names)

func get_patience_text(ratio: float) -> String:
	if ratio >= 0.72:
		return "还不急"
	if ratio >= 0.42:
		return "有点着急"
	return "快没耐心了"

func get_orders_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(orders.size()):
		var order: Dictionary = orders[index]
		result.append({
			"id": int(order.get("id", 0)),
			"recipe_id": str(order.get("recipe_id", "")),
			"name": get_recipe_name(str(order.get("recipe_id", ""))),
			"customer_id": str(order.get("customer_id", "regular")),
			"customer_name": str(order.get("customer_name", "客人")),
			"customer_line": str(order.get("customer_line", "")),
			"leave_line": str(order.get("leave_line", "")),
			"tip_rate": float(order.get("tip_rate", 0.0)),
			"rush": rush_active,
			"rush_name": rush_name,
			"patience": float(order.get("patience", 0.0)),
			"patience_ratio": clampf(float(order.get("patience", 0.0)) / maxf(0.1, float(order.get("patience_max", 1.0))), 0.0, 1.0),
			"queue_position": index + 1,
			"state": str(order.get("state", "waiting")),
			"is_hand": str(order.get("state", "waiting")) == "hand",
		})
	return result

func get_stations_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(stations.size()):
		var station: Dictionary = stations[index]
		var state := str(station.get("state", "idle"))
		var progress := float(station.get("progress", 0.0))
		var duration := maxf(0.1, float(station.get("duration", 0.0)))
		var recipe_id := str(station.get("recipe_id", ""))
		var job: Dictionary = station.get("job", {})
		var stage_id := str(job.get("stage_id", ""))
		var display := "空工位"
		if not recipe_id.is_empty():
			display = "%s · %s" % [get_recipe_name(recipe_id), get_stage_name(stage_id)]
		result.append({
			"index": index,
			"type": str(station.get("type", "")),
			"station_name": get_station_name(str(station.get("type", ""))),
			"state": state,
			"recipe_id": recipe_id,
			"name": display,
			"stage_id": stage_id,
			"progress_ratio": clampf(progress / duration, 0.0, 1.0),
			"level": int(equipment_levels.get(str(station.get("type", "")), 0)),
			"action_text": _station_action_text(state, str(station.get("type", ""))),
		})
	return result

func get_staging_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(staging.size()):
		var tray: Dictionary = staging[index]
		var station_type := str(tray.get("station_type", ""))
		result.append({
			"index": index,
			"recipe_id": str(tray.get("recipe_id", "")),
			"name": get_recipe_name(str(tray.get("recipe_id", ""))),
			"stage_id": str(tray.get("stage_id", "")),
			"stage_name": get_stage_name(str(tray.get("stage_id", ""))),
			"station_type": station_type,
			"station_name": get_station_name(station_type),
		})
	return result

func get_recipes_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_id in BusinessManager.get_unlocked_recipe_ids():
		var recipe := ConfigDB.get_row("recipes", recipe_id)
		var phases := str(recipe.get("phases", "")).split("|", false)
		result.append({
			"id": recipe_id,
			"name": str(recipe.get("name", recipe_id)),
			"goods_recipe": str(recipe.get("goods_recipe", "")),
			"labor_cost": int(recipe.get("labor_cost", 0)),
			"brain_cost": int(recipe.get("brain_cost", 0)),
			"sale_price": int(recipe.get("sale_price", 0)),
			"pipeline_text": get_pipeline_text(recipe_id),
			"available": BusinessManager.can_prepare_recipe(recipe_id),
			"in_phase": active_phase_id in phases or str(recipe_id) in MarketPhaseManager.get_festival_recipe_ids(),
		})
	return result

func _station_action_text(state: String, _station_type: String) -> String:
	match state:
		"idle":
			return "接单/放半成品"
		"processing":
			return "处理中"
		"stage_ready":
			return "移到托盘"
		"ready":
			return "点击出餐"
	return ""

func get_station_speed_multiplier(station_type: String) -> float:
	var level := int(equipment_levels.get(station_type, 0))
	var step := float(ConfigDB.get_row("equipment", station_type).get("speed_per_level", "0.18"))
	return (1.0 + float(level) * step) * (1.0 + WardrobeManager.get_bonus("work"))

func get_upgrade_cost(station_type: String) -> int:
	var row := ConfigDB.get_row("equipment", station_type)
	var level := int(equipment_levels.get(station_type, 0))
	return int(row.get("upgrade_base_cost", "260")) + int(row.get("upgrade_step", "220")) * level

func upgrade_station(station_type: String) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("kitchen_upgrade", {"station_type": station_type})
	var row := ConfigDB.get_row("equipment", station_type)
	if row.is_empty():
		return false
	var max_level := int(ConfigDB.get_number("business", "equipment_max_level", 3))
	var level := int(equipment_levels.get(station_type, 0))
	if level >= max_level:
		NoticeManager.show_message("%s已经升到顶了。" % get_station_name(station_type), "hint")
		return false
	var cost := get_upgrade_cost(station_type)
	if not GameState.spend(cost, "升级%s，只加快这种工位。" % get_station_name(station_type)):
		return false
	equipment_levels[station_type] = level + 1
	NoticeManager.show_message("%s升级完成，当前速度 ×%.2f。" % [get_station_name(station_type), get_station_speed_multiplier(station_type)], "positive")
	SaveManager.request_auto_save("equipment_upgrade")
	changed.emit()
	return true

func get_equipment_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for station_type in ConfigDB.get_rows("equipment"):
		var level := int(equipment_levels.get(station_type, 0))
		result.append({
			"type": str(station_type),
			"name": get_station_name(str(station_type)),
			"level": level,
			"max_level": int(ConfigDB.get_number("business", "equipment_max_level", 3)),
			"speed": get_station_speed_multiplier(str(station_type)),
			"upgrade_cost": get_upgrade_cost(str(station_type)),
			"description": str(ConfigDB.get_row("equipment", station_type).get("description", "")),
		})
	return result

func reset_new_game() -> void:
	active = false
	time_left = 0.0
	orders.clear()
	stations.clear()
	staging.clear()
	hand.clear()
	combo = 0
	served = 0
	failed = 0
	shift_earned = 0
	_order_counter = 0
	_spawn_timer = 0.0
	active_phase_id = ""
	equipment_levels.clear()
	changed.emit()

func get_save_data() -> Dictionary:
	return {
		"active": active,
		"time_left": time_left,
		"orders": orders.duplicate(true),
		"stations": stations.duplicate(true),
		"staging": staging.duplicate(true),
		"combo": combo,
		"served": served,
		"failed": failed,
		"shift_earned": shift_earned,
		"order_counter": _order_counter,
		"spawn_timer": _spawn_timer,
		"location_id": location_id,
		"active_phase_id": active_phase_id,
		"equipment_levels": equipment_levels.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	active = bool(data.get("active", false))
	time_left = maxf(0.0, float(data.get("time_left", 0.0)))
	orders = data.get("orders", []).duplicate(true)
	for order in orders:
		if str(order.get("state", "waiting")) == "hand":
			order["state"] = "waiting"
	stations = data.get("stations", []).duplicate(true)
	staging = data.get("staging", []).duplicate(true)
	hand.clear()
	combo = int(data.get("combo", 0))
	served = int(data.get("served", 0))
	failed = int(data.get("failed", 0))
	shift_earned = int(data.get("shift_earned", 0))
	_order_counter = int(data.get("order_counter", orders.size()))
	_spawn_timer = maxf(0.0, float(data.get("spawn_timer", 0.0)))
	location_id = str(data.get("location_id", "restaurant"))
	active_phase_id = str(data.get("active_phase_id", ""))
	equipment_levels = data.get("equipment_levels", {}).duplicate(true)
	if active and (active_phase_id.is_empty() or not MarketPhaseManager.is_location_open(location_id, active_phase_id)):
		active = false
		orders.clear()
		staging.clear()
	hand.clear()
	changed.emit()
