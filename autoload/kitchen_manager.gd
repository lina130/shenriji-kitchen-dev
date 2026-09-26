extends Node

signal changed
signal shift_ended(summary: Dictionary)

var active := false
var time_left := 0.0
var orders: Array = []
var stations: Array = []
var combo := 0
var served := 0
var failed := 0
var last_serve_time := 0.0
var shift_earned := 0
var _order_counter := 0
var _sync_accumulator := 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if not active:
		return
	time_left = maxf(0.0, time_left - delta)
	_update_stations(delta)
	_update_orders(delta)
	_spawn_order_if_needed()
	_sync_accumulator += delta
	if _sync_accumulator >= 0.12:
		_sync_accumulator = 0.0
		changed.emit()
	if time_left <= 0.0 or served >= get_order_target():
		end_shift()

func start_shift() -> bool:
	if active:
		return false
	if BusinessManager.labor_stock <= 0 or BusinessManager.brain_stock <= 0:
		NoticeManager.show_message("今天没有足够劳力或脑力，先休息或补库存。", "warning")
		return false
	active = true
	time_left = ConfigDB.get_number("business", "shift_duration", 120.0)
	orders.clear()
	stations.clear()
	combo = 0
	served = 0
	failed = 0
	last_serve_time = 0.0
	shift_earned = 0
	var station_count := 2 + mini(2, BusinessManager.business_level)
	for index in range(station_count):
		stations.append({"state": "idle", "recipe_id": "", "progress": 0.0, "duration": 0.0})
	for index in range(3):
		_spawn_order()
	NoticeManager.show_message("夜市档口开张，先看订单再安排工位。", "positive")
	changed.emit()
	return true

func place_recipe(recipe_id: String, station_index: int) -> bool:
	if not active or station_index < 0 or station_index >= stations.size():
		return false
	var station: Dictionary = stations[station_index]
	if str(station.get("state", "idle")) != "idle":
		NoticeManager.show_message("这个工位正忙着。", "hint")
		return false
	if not BusinessManager.consume_recipe_inputs(recipe_id):
		return false
	var recipe := ConfigDB.get_row("recipes", recipe_id)
	station["recipe_id"] = recipe_id
	station["state"] = "prep"
	station["progress"] = 0.0
	station["duration"] = float(recipe.get("prep_seconds", 3.0))
	changed.emit()
	return true

func advance_station(station_index: int) -> bool:
	if not active or station_index < 0 or station_index >= stations.size():
		return false
	var station: Dictionary = stations[station_index]
	match str(station.get("state", "idle")):
		"prep_ready":
			var recipe := ConfigDB.get_row("recipes", str(station.get("recipe_id", "")))
			station["state"] = "cook"
			station["progress"] = 0.0
			station["duration"] = maxf(1.0, float(recipe.get("prep_seconds", 3.0)) * 0.62)
			changed.emit()
			return true
		"cook_ready":
			station["state"] = "ready"
			station["progress"] = 0.0
			changed.emit()
			return true
		"ready":
			return _serve_station(station_index)
		_:
			NoticeManager.show_message("还没到下一步，盯紧工位。", "hint")
			return false


func prepare_next_order(station_index: int) -> bool:
	if orders.is_empty():
		_spawn_order()
	if orders.is_empty():
		return false
	return place_recipe(str(orders[0].get("recipe_id", "")), station_index)

func handle_station_action(station_index: int) -> bool:
	if not active or station_index < 0 or station_index >= stations.size():
		NoticeManager.show_message("档口还没开张。", "warning")
		return false
	var state := str(stations[station_index].get("state", "idle"))
	if state == "idle":
		return prepare_next_order(station_index)
	if state == "ready":
		NoticeManager.show_message("菜已经装好了，端到出餐台再送客。", "hint")
		return false
	return advance_station(station_index)

func serve_ready_station() -> bool:
	for index in range(stations.size()):
		if str(stations[index].get("state", "idle")) == "ready":
			return _serve_station(index)
	NoticeManager.show_message("还没有装好盘的菜。", "hint")
	return false

func _serve_station(station_index: int) -> bool:
	var station: Dictionary = stations[station_index]
	var recipe_id := str(station.get("recipe_id", ""))
	var order_index := _find_matching_order(recipe_id)
	if order_index < 0:
		NoticeManager.show_message("这道菜现在没人点，先别端出去。", "warning")
		return false
	var now := Time.get_ticks_msec() / 1000.0
	combo = combo + 1 if now - last_serve_time <= 6.0 else 1
	last_serve_time = now
	var revenue := BusinessManager.register_recipe_sale(recipe_id, combo)
	shift_earned += revenue
	var recipe_name := str(ConfigDB.get_row("recipes", recipe_id).get("name", recipe_id))
	NoticeManager.show_message("%s送出去了，收 ¥%d%s。" % [
		recipe_name,
		revenue,
		" · 连击 ×%d" % combo if combo > 1 else "",
	], "positive")
	orders.remove_at(order_index)
	station["state"] = "idle"
	station["recipe_id"] = ""
	station["progress"] = 0.0
	station["duration"] = 0.0
	served += 1
	TreasureManager.try_trigger("serve_dish")
	_spawn_order()
	if served >= get_order_target():
		end_shift()
	changed.emit()
	return true
func end_shift() -> void:
	if not active:
		return
	active = false
	var summary := {
		"earned": shift_earned,
		"served": served,
		"failed": failed,
		"combo": combo,
	}
	TimeSystem.advance_minutes(240)
	NoticeManager.show_message("打烊了，今晚卖了 %d 单，进账 ¥%d。" % [served, shift_earned], "positive")
	shift_ended.emit(summary)
	changed.emit()

func get_order_target() -> int:
	return int(ConfigDB.get_number("business", "shift_order_target", 12))

func get_recipe_name(recipe_id: String) -> String:
	return str(ConfigDB.get_row("recipes", recipe_id).get("name", recipe_id))

func get_orders_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order in orders:
		result.append({
			"id": int(order.get("id", 0)),
			"recipe_id": str(order.get("recipe_id", "")),
			"name": get_recipe_name(str(order.get("recipe_id", ""))),
			"patience": float(order.get("patience", 0.0)),
		})
	return result

func get_stations_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(stations.size()):
		var station: Dictionary = stations[index]
		var state := str(station.get("state", "idle"))
		var progress := float(station.get("progress", 0.0))
		var duration := maxf(0.1, float(station.get("duration", 0.0)))
		result.append({
			"index": index,
			"state": state,
			"recipe_id": str(station.get("recipe_id", "")),
			"name": get_recipe_name(str(station.get("recipe_id", ""))) if state != "idle" else "空工位",
			"progress_ratio": clampf(progress / duration, 0.0, 1.0),
			"action_text": _station_action_text(state),
		})
	return result

func get_recipes_status() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_id in BusinessManager.get_unlocked_recipe_ids():
		var recipe := ConfigDB.get_row("recipes", recipe_id)
		result.append({
			"id": recipe_id,
			"name": str(recipe.get("name", recipe_id)),
			"goods_recipe": str(recipe.get("goods_recipe", "")),
			"labor_cost": int(recipe.get("labor_cost", 0)),
			"brain_cost": int(recipe.get("brain_cost", 0)),
			"sale_price": int(recipe.get("sale_price", 0)),
			"available": BusinessManager.can_prepare_recipe(recipe_id),
		})
	return result

func _update_stations(delta: float) -> void:
	for station in stations:
		var state := str(station.get("state", "idle"))
		if state != "prep" and state != "cook":
			continue
		station["progress"] = float(station.get("progress", 0.0)) + delta
		if float(station["progress"]) >= float(station.get("duration", 1.0)):
			station["progress"] = float(station.get("duration", 1.0))
			station["state"] = "prep_ready" if state == "prep" else "cook_ready"

func _update_orders(delta: float) -> void:
	var remaining: Array = []
	for order in orders:
		order["patience"] = float(order.get("patience", 0.0)) - delta
		if float(order["patience"]) <= 0.0:
			failed += 1
			combo = 0
			BusinessManager.register_failed_order()
			NoticeManager.show_message("客人等太久走了，连击断了。", "warning")
		else:
			remaining.append(order)
	orders = remaining

func _spawn_order_if_needed() -> void:
	if orders.size() < 4 and served + orders.size() < get_order_target():
		_spawn_order()

func _spawn_order() -> void:
	var candidates := BusinessManager.get_unlocked_recipe_ids()
	if candidates.is_empty():
		return
	_order_counter += 1
	orders.append({
		"id": _order_counter,
		"recipe_id": str(RandomManager.pick(candidates)),
		"patience": maxf(8.0, 20.0 - float(_order_counter) * 0.25) + RelationshipManager.get_patience_bonus(),
	})

func _find_matching_order(recipe_id: String) -> int:
	for index in range(orders.size()):
		if str(orders[index].get("recipe_id", "")) == recipe_id:
			return index
	return -1

func _station_action_text(state: String) -> String:
	match state:
		"idle":
			return "空闲"
		"prep":
			return "备料中"
		"prep_ready":
			return "点一下下锅"
		"cook":
			return "炒制中"
		"cook_ready":
			return "点一下装盘"
		"ready":
			return "点一下上菜"
	return ""

func reset_new_game() -> void:
	active = false
	time_left = 0.0
	orders.clear()
	stations.clear()
	combo = 0
	served = 0
	failed = 0
	shift_earned = 0
	changed.emit()