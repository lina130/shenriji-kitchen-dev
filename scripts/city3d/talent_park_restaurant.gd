class_name TalentParkRestaurant3D
extends Node

signal state_changed(state: Dictionary)
signal event_happened(result: Dictionary)
signal shift_finished(summary: Dictionary)

const SAVE_VERSION := 2
const START_MINUTE := 480.0
const CLOSING_MINUTE := 1320.0
const GAME_MINUTES_PER_SECOND := 1.0
const BUFFER_CAPACITY := 3
const BUFFER_FRESHNESS := 26.0
const WARM_HOLD_SECONDS := 18.0
const REHEAT_SECONDS := 2.0
const PANTRY_LIMIT := 6
const GROUP_BONUS := {"calm": 12, "rush": 20}
const SERVICE_PERIODS := {
	"morning": {"price_scale": 0.92, "tip_scale": 0.90},
	"lunch": {"price_scale": 1.0, "tip_scale": 1.0},
	"evening": {"price_scale": 1.14, "tip_scale": 1.1}
}
const PERIOD_MENUS := {
	# All ten original recipes remain possible; the first requests of each
	# service period reflect what guests tend to order at that time of day.
	"morning": [0, 2, 4, 3, 9, 7, 8, 5, 6, 1],
	"lunch": [0, 6, 5, 7, 8, 3, 1, 9, 2, 4],
	"evening": [0, 1, 6, 5, 8, 7, 3, 9, 4, 2]
}
const ACTIONS := ["wash", "slice", "mix", "marinate", "portion", "steam", "fry", "boil", "garnish", "serve"]
const HEAT_ACTIONS := ["steam", "fry", "boil"]
const RUSH_WAVE_AT := 10.0
const RUSH_WAVES := [
	{"at": 9.0, "patience": 48.0, "bonus": 18},
	{"at": 11.0, "patience": 44.0, "bonus": 24},
	{"at": 13.0, "patience": 50.0, "bonus": 16}
]
const MODES := {
	"calm": {"orders": 6, "patience": 88.0, "price_scale": 1.0, "tip": 10, "bonus": 22, "mistake_penalty": 3.0, "pickup_window": 12.0, "overcook_penalty": 3.0},
	"rush": {"orders": 12, "patience": 56.0, "price_scale": 1.68, "tip": 19, "bonus": 86, "mistake_penalty": 5.0, "pickup_window": 8.0, "overcook_penalty": 5.0}
}
const STOCKS := {
	"rice_batter": {"name": "米浆底料", "steps": ["wash", "mix"], "yield": 3, "freshness": 92.0, "supply_key": "rice_mix", "ingredient_key": "rice_flour"},
	"spice_oil": {"name": "香料油", "steps": ["slice", "mix"], "yield": 3, "freshness": 78.0, "supply_key": "spice_mix", "ingredient_key": "spice_oil"}
}
const STOCK_CAPACITY := 8
const RAW_CAPACITY := 400
const RAW_PER_KIND := 28
const RAW_REFILL_TARGET := 20
const PREP_CAPACITY := 150
const PREP_PER_KIND := 8
const PREP_BATCH_TARGET := 6
const LEGACY_PREP_PER_KIND := 14
const CARRY_CAPACITY := 70
const RAW_GROUPS := {
	"staples": ["rice_flour", "soft_bun", "millet", "noodles", "rice"],
	"fresh": ["leafy_greens", "cucumber", "fruit", "seaweed", "osmanthus"],
	"protein": ["chicken", "egg", "soft_tofu", "shrimp", "yogurt"],
	"pantry": ["soy_sauce", "spice_oil", "ginger_syrup", "coconut_milk", "ice"]
}
const RECIPES := [
	{"id": "garden_rice_roll", "name": "青园蔬香米卷", "steps": ["wash", "mix", "steam", "garnish", "serve"], "ingredients": ["rice_flour", "leafy_greens", "soy_sauce"], "price": 50, "cook_seconds": 3.0, "stock": "rice_batter"},
	{"id": "macao_spice_bun", "name": "香料海风包", "steps": ["slice", "mix", "marinate", "fry", "garnish", "serve"], "ingredients": ["soft_bun", "chicken", "spice_oil", "leafy_greens"], "price": 70, "cook_seconds": 3.8, "stock": "spice_oil"},
	{"id": "morning_egg_bun", "name": "晨光鸡蛋包", "steps": ["slice", "fry", "garnish", "serve"], "ingredients": ["soft_bun", "egg", "cucumber"], "price": 37, "cook_seconds": 2.5, "stock": ""},
	{"id": "warm_tofu_bowl", "name": "暖姜豆花碗", "steps": ["boil", "portion", "garnish", "serve"], "ingredients": ["soft_tofu", "ginger_syrup", "osmanthus"], "price": 39, "cook_seconds": 2.6, "stock": ""},
	{"id": "coconut_millet", "name": "椰香小米盅", "steps": ["wash", "boil", "portion", "serve"], "ingredients": ["millet", "coconut_milk", "fruit"], "price": 38, "cook_seconds": 3.2, "stock": ""},
	{"id": "harbour_noodles", "name": "港湾拌面", "steps": ["slice", "mix", "boil", "garnish", "serve"], "ingredients": ["noodles", "leafy_greens", "spice_oil"], "price": 53, "cook_seconds": 3.1, "stock": "spice_oil"},
	{"id": "chicken_rice", "name": "香煎鸡肉饭", "steps": ["wash", "marinate", "fry", "portion", "garnish", "serve"], "ingredients": ["rice", "chicken", "soy_sauce", "leafy_greens"], "price": 66, "cook_seconds": 4.1, "stock": ""},
	{"id": "bay_shrimp_roll", "name": "湾畔鲜虾肠粉", "steps": ["wash", "mix", "portion", "steam", "garnish", "serve"], "ingredients": ["rice_flour", "shrimp", "soy_sauce"], "price": 68, "cook_seconds": 3.7, "stock": "rice_batter"},
	{"id": "seaweed_dumpling", "name": "海苔青蔬饺", "steps": ["wash", "mix", "portion", "steam", "serve"], "ingredients": ["rice_flour", "seaweed", "leafy_greens"], "price": 52, "cook_seconds": 3.4, "stock": "rice_batter"},
	{"id": "fruit_ice", "name": "果香冰沙杯", "steps": ["wash", "slice", "mix", "garnish", "serve"], "ingredients": ["fruit", "ice", "yogurt"], "price": 49, "cook_seconds": 0.0, "stock": ""}
]

var _active := false
var _endless := false
var _mode := ""
var _stage := "idle"
var _last_settlement: Dictionary = {}
var _session_start_day := 1
var _queue: Array[int] = []
var _next_order_index := 0
var _tickets: Array[Dictionary] = []
var _selected_slot := 0
var _selected_target := "ticket"
var _stock_job: Dictionary = {}
var _stock_units := {"rice_batter": [], "spice_oil": []}
var _pantry := {"rice_mix": 6, "spice_mix": 6}
var _raw_ingredients := {
	"rice_flour": 6, "soft_bun": 6, "millet": 6, "noodles": 6, "rice": 6,
	"leafy_greens": 6, "cucumber": 6, "fruit": 6, "seaweed": 6, "osmanthus": 6,
	"chicken": 6, "egg": 6, "soft_tofu": 6, "shrimp": 6, "yogurt": 6,
	"soy_sauce": 6, "spice_oil": 6, "ginger_syrup": 6, "coconut_milk": 6, "ice": 6
}
var _prep_ingredients := {
	"rice_flour": 1, "soft_bun": 1, "millet": 1, "noodles": 1, "rice": 1,
	"leafy_greens": 1, "cucumber": 1, "fruit": 1, "seaweed": 1, "osmanthus": 1,
	"chicken": 1, "egg": 1, "soft_tofu": 1, "shrimp": 1, "yogurt": 1,
	"soy_sauce": 1, "spice_oil": 1, "ginger_syrup": 1, "coconut_milk": 1, "ice": 1
}
var _carried_ingredients: Dictionary = {}
var _buffer: Array[Dictionary] = [{}, {}, {}]
var _mistakes := 0
var _served := 0
var _missed := 0
var _earned_total := 0
var _combo := 0
var _combo_left := 0.0
var _shift_serial := 0
var _migration := ""
var _last_display_second := -1
var _last_stock_display_second := -1
var _shift_elapsed := 0.0
var _rush_wave_triggered := false
var _rush_wave_variant := 0
var _rush_wave_at := RUSH_WAVE_AT
var _rush_wave_patience := 56.0
var _rush_wave_bonus := 0
var _clock_minutes := START_MINUTE
var _service_day := 1
var _shift_period := "morning"
var _has_combo_customer := false
var _customer_served_counts: Dictionary = {}
var _customer_missed_counts: Dictionary = {}


static func energy_cost_for(mode: String) -> int:
	var normalized := "calm" if mode == "relaxed" else mode
	return 0 if MODES.has(normalized) else -1


func start_shift(mode: String, endless: bool = false) -> bool:
	var normalized := "calm" if mode == "relaxed" else mode
	if _active or not MODES.has(normalized):
		return false
	_mode = normalized
	_endless = endless
	_active = true
	_stage = "prep"
	_last_settlement.clear()
	_session_start_day = _service_day
	_queue.clear()
	_tickets.clear()
	_next_order_index = 0
	_selected_slot = 0
	_selected_target = "ticket"
	_stock_job.clear()
	_mistakes = 0
	_served = 0
	_missed = 0
	_earned_total = 0
	_combo = 0
	_combo_left = 0.0
	_migration = ""
	_shift_period = _period_for_clock()
	_pantry["rice_mix"] = mini(PANTRY_LIMIT, int(_pantry["rice_mix"]) + 3)
	_pantry["spice_mix"] = mini(PANTRY_LIMIT, int(_pantry["spice_mix"]) + 3)
	_buffer = [{}, {}, {}]
	_has_combo_customer = true
	_customer_served_counts.clear()
	_customer_missed_counts.clear()
	_shift_elapsed = 0.0
	_rush_wave_triggered = false
	_rush_wave_variant = _shift_serial % RUSH_WAVES.size()
	_rush_wave_at = float(RUSH_WAVES[_rush_wave_variant]["at"])
	_rush_wave_patience = float(RUSH_WAVES[_rush_wave_variant]["patience"])
	_rush_wave_bonus = int(RUSH_WAVES[_rush_wave_variant]["bonus"])
	var service_menu: Array = PERIOD_MENUS[_shift_period]
	var menu_start := (_shift_serial * 3) % service_menu.size()
	for i in range(service_menu.size() if _endless else int(MODES[_mode]["orders"])):
		_queue.append(int(service_menu[(menu_start + i) % service_menu.size()]))
	_shift_serial += 1
	_fill_tickets()
	_emit_state()
	return true


func select_order(slot: int) -> Dictionary:
	if not _active or slot < 0 or slot >= _tickets.size():
		return _result(false, "no_ticket", "这张订单暂时没有顾客。")
	var ticket: Dictionary = _tickets[slot]
	var newly_started := not bool(ticket.get("started", false))
	if newly_started:
		ticket["started"] = true
		_tickets[slot] = ticket
	_selected_slot = slot
	_selected_target = "ticket"
	_emit_state()
	return _result(true, "order_started" if newly_started else "order_inspected", "已开始制作。" if newly_started else "已查看这道菜。")


func interact_order(order_number: int, action_id: String) -> Dictionary:
	if not _active:
		return _result(false, "not_working", "餐馆尚未营业。")
	for slot in range(_tickets.size()):
		if int(_tickets[slot].get("order_number", -1)) != order_number:
			continue
		if not bool(_tickets[slot].get("started", false)):
			return _result(false, "ticket_not_started", "先点右上角餐票开始制作。")
		_selected_slot = slot
		_selected_target = "ticket"
		var result := interact(action_id)
		if not bool(result.get("ok", false)):
			_emit_state()
		return result
	return _result(false, "no_ticket", "这份餐点已经离开。")


func interact_station(action_id: String) -> Dictionary:
	if _selected_target == "stock" and not _stock_job.is_empty():
		return _interact_stock(action_id)
	var matching: Array[int] = []
	for ticket in _tickets:
		if not bool(ticket.get("started", false)) or int(ticket.get("buffer_slot", -1)) >= 0:
			continue
		var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
		var expected := _recipe_heat_action(recipe) if bool(ticket.get("reheat_needed", false)) else str((recipe["steps"] as Array)[int(ticket["step_index"])])
		# A ready hot dish is still waiting at its cooker, but the next worktop
		# is already lit. Touching that worktop takes the dish and performs the
		# next step in one action; interact() clears the pickup timer.
		if expected == action_id and float(ticket.get("heat_left", 0.0)) <= 0.0:
			matching.append(int(ticket["order_number"]))
	if matching.size() == 1:
		return interact_order(matching[0], action_id)
	return _result(false, "choose_food" if matching.size() > 1 else "start_or_choose_food", "点台面上要加工的那份食物。" if matching.size() > 1 else "先点右上餐票，或点已经开做的食物。")


func interact_stock_action(action_id: String) -> Dictionary:
	if _stock_job.is_empty():
		return _result(false, "no_stock_job", "先选择半成品。")
	_selected_target = "stock"
	return _interact_stock(action_id)


func buffer_interact(slot: int) -> Dictionary:
	if slot < 0 or slot >= BUFFER_CAPACITY:
		return _result(false, "invalid_buffer", "这个托盘位不可用。")
	if not _buffer[slot].is_empty():
		return serve_buffer(slot)
	return buffer_selected(slot)


func buffer_selected(slot: int) -> Dictionary:
	if not _active or slot < 0 or slot >= BUFFER_CAPACITY or not _buffer[slot].is_empty() or _selected_target != "ticket":
		return _result(false, "buffer_unavailable", "先选择一张可以装盘的订单和空托盘。")
	var ticket: Dictionary = _selected_ticket()
	if ticket.is_empty() or int(ticket.get("buffer_slot", -1)) >= 0 or float(ticket["heat_left"]) > 0.0:
		return _result(false, "buffer_unavailable", "这份餐点现在不能放入托盘。")
	var customer: Dictionary = _customer_for_order(int(ticket["order_number"]))
	if _combo_plate_active():
		if int(ticket["order_number"]) <= 2 and slot != int(customer["group_index"]) - 1:
			return _result(false, "combo_slot_reserved", "这道菜有固定的组合餐盘位置。")
		if int(ticket["order_number"]) > 2 and slot < 2:
			return _result(false, "combo_slot_reserved", "前两格留给双菜顾客。")
	var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
	var steps: Array = recipe["steps"]
	if str(steps[int(ticket["step_index"])]) != "serve":
		return _result(false, "buffer_unavailable", "先完成烹饪与装盘。")
	var result := _stage_ticket_in_buffer(ticket, recipe, slot, "buffer")
	_emit_state()
	event_happened.emit(result)
	return result


func serve_buffer(slot: int) -> Dictionary:
	if not _active or slot < 0 or slot >= BUFFER_CAPACITY or _buffer[slot].is_empty():
		return _result(false, "buffer_empty", "托盘里没有可交付的餐点。")
	var order_number := int(_buffer[slot]["order_number"])
	if _has_combo_customer and order_number <= 2 and not _legacy_partial_combo():
		if not _combo_plate_ready():
			return _result(false, "combo_waiting", "组合餐还缺另一道菜。")
		_gain_combo()
		var combo_result := _serve_combo()
		combo_result["action_id"] = "serve"
		_emit_state()
		event_happened.emit(combo_result)
		if not _active:
			shift_finished.emit(snapshot())
		return combo_result
	for i in range(_tickets.size()):
		var ticket: Dictionary = _tickets[i]
		if int(ticket["order_number"]) != order_number:
			continue
		_selected_slot = i
		_selected_target = "ticket"
		_stock_job.clear()
		_gain_combo()
		var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
		var result := _serve_ticket(ticket, recipe)
		result["recipe_id"] = str(recipe["id"])
		result["ticket_slot"] = i
		result["buffer_slot"] = slot
		result["action_id"] = "serve"
		_emit_state()
		event_happened.emit(result)
		if not _active:
			shift_finished.emit(snapshot())
		return result
	_buffer[slot] = {}
	_emit_state()
	return _result(false, "buffer_empty", "对应顾客已离开，托盘已清理。")


func advance_to_next_day() -> bool:
	if _active:
		return false
	_service_day += 1
	_clock_minutes = START_MINUTE
	_pantry = {"rice_mix": PANTRY_LIMIT, "spice_mix": PANTRY_LIMIT}
	_stock_units = {"rice_batter": [], "spice_oil": []}
	_buffer = [{}, {}, {}]
	_emit_state()
	return true


func align_day(day: int) -> void:
	var aligned := maxi(_service_day, maxi(1, day))
	if aligned != _service_day:
		_service_day = aligned
		_emit_state()


func prepare_stock(stock_id: String) -> Dictionary:
	if not STOCKS.has(stock_id):
		return _result(false, "unknown_stock", "这里不能制作这种半成品。")
	if _active and _selected_target == "ticket" and _selected_slot < _tickets.size():
		var ticket: Dictionary = _tickets[_selected_slot]
		var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
		if str(recipe["stock"]) == stock_id and int(ticket["step_index"]) == 0 and float(ticket["heat_left"]) <= 0.0:
			var units: Array = _stock_units[stock_id]
			if not units.is_empty():
				var missing := _ingredient_shortage(recipe, stock_id)
				if not missing.is_empty():
					return _ingredient_shortage_result(missing)
				_consume_recipe_ingredients(recipe, ticket, stock_id)
				units.pop_front()
				ticket["step_index"] = 2
				_tickets[_selected_slot] = ticket
				_gain_combo()
				var used := _result(true, "stock_used", "%s已取用，省下两步现场备料。" % str(STOCKS[stock_id]["name"]))
				used["stock_id"] = stock_id
				used["recipe_id"] = str(recipe["id"])
				used["ticket_slot"] = _selected_slot
				used["action_id"] = "stock_take"
				_emit_state()
				event_happened.emit(used)
				return used
	if _stock_count() + int(STOCKS[stock_id]["yield"]) > STOCK_CAPACITY:
		var full := _result(false, "stock_full", "保鲜架已满，先用掉或等到新鲜库存腾出空间。")
		event_happened.emit(full)
		return full
	var supply_key := str(STOCKS[stock_id]["supply_key"])
	if int(_pantry[supply_key]) <= 0:
		var empty := _result(false, "stock_supplies_empty", "这种底料的备货原料用完了，下一班会补充。")
		empty["stock_id"] = stock_id
		event_happened.emit(empty)
		return empty
	var ingredient_key := str(STOCKS[stock_id]["ingredient_key"])
	if int(_prep_ingredients.get(ingredient_key, 0)) <= 0:
		return _ingredient_shortage_result([ingredient_key])
	if str(_stock_job.get("id", "")) != stock_id:
		_stock_job = {"id": stock_id, "step_index": 0}
	_selected_target = "stock"
	_emit_state()
	return _result(true, "stock_selected", "开始制作%s，请点亮起的工作台。" % str(STOCKS[stock_id]["name"]))


func interact(action_id: String) -> Dictionary:
	if not ACTIONS.has(action_id):
		return _result(false, "unknown_action", "这不是可用的厨房操作。")
	if _selected_target == "stock" and not _stock_job.is_empty():
		return _interact_stock(action_id)
	if not _active or _tickets.is_empty():
		return _result(false, "not_working", "先接一班工作，或从货架选择半成品备货。")
	var ticket: Dictionary = _tickets[_selected_slot]
	var acted_slot := _selected_slot
	if float(ticket["heat_left"]) > 0.0:
		return _result(false, "still_heating", "这单正在加热，先做另一单或提前备货。")
	var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
	var steps: Array = recipe["steps"]
	if bool(ticket.get("reheat_needed", false)):
		var reheat_action := _recipe_heat_action(recipe)
		if action_id != reheat_action:
			return _wrong_action(ticket, reheat_action)
		ticket["reheat_needed"] = false
		ticket["reheating"] = true
		ticket["heat_left"] = REHEAT_SECONDS
		_tickets[_selected_slot] = ticket
		var warming := _result(true, "reheating", "菜有些凉了，回锅热一下。")
		warming["recipe_id"] = str(recipe["id"])
		warming["ticket_slot"] = acted_slot
		warming["action_id"] = action_id
		_emit_state()
		event_happened.emit(warming)
		return warming
	var expected := str(steps[int(ticket["step_index"])])
	if action_id != expected:
		return _wrong_action(ticket, expected)
	if not bool(ticket.get("ingredients_reserved", false)):
		var missing := _ingredient_shortage(recipe)
		if not missing.is_empty():
			return _ingredient_shortage_result(missing)
		_consume_recipe_ingredients(recipe, ticket)
	if action_id == "serve" and _combo_requires_joint(ticket) and int(ticket.get("buffer_slot", -1)) >= 0:
		var plated_slot := int(ticket["buffer_slot"])
		return serve_buffer(plated_slot)
	var picked_up := float(ticket.get("pickup_left", 0.0)) > 0.0
	if picked_up:
		ticket["pickup_left"] = 0.0
		ticket["warm_left"] = WARM_HOLD_SECONDS
	_gain_combo()
	var result: Dictionary
	if HEAT_ACTIONS.has(action_id):
		ticket["heat_left"] = float(recipe["cook_seconds"])
		_tickets[_selected_slot] = ticket
		result = _result(true, "heating", "%s正在加热，可以处理另一单。" % str(recipe["name"]))
	elif action_id == "serve":
		if _combo_requires_joint(ticket):
			var combo_slot := int(_customer_for_order(int(ticket["order_number"]))["group_index"]) - 1
			if not _buffer[combo_slot].is_empty():
				return _result(false, "combo_slot_reserved", "组合餐盘位置尚未空出。")
			result = _stage_ticket_in_buffer(ticket, recipe, combo_slot, "serve")
		else:
			result = _serve_ticket(ticket, recipe)
	else:
		ticket["step_index"] = int(ticket["step_index"]) + 1
		_tickets[_selected_slot] = ticket
		result = _result(true, "step_done", "已完成%s，继续下一步。" % _action_name(action_id))
	result["recipe_id"] = str(recipe["id"])
	result["ingredients"] = (recipe["ingredients"] as Array).duplicate()
	result["ticket_slot"] = acted_slot
	result["customer_id"] = int(_customer_for_order(int(ticket["order_number"]))["customer_id"])
	result["action_id"] = action_id
	result["picked_up"] = picked_up
	_emit_state()
	event_happened.emit(result)
	if not _active:
		shift_finished.emit(snapshot())
	return result


func restock_group(group_id: String, priority_ingredient: String = "") -> Dictionary:
	if not RAW_GROUPS.has(group_id):
		return _result(false, "unknown_supply", "这个备料箱不可用。")
	var space := RAW_CAPACITY - _raw_total()
	var loaded := 0
	var delivery_order: Array = (RAW_GROUPS[group_id] as Array).duplicate()
	if delivery_order.has(priority_ingredient):
		delivery_order.erase(priority_ingredient)
		delivery_order.push_front(priority_ingredient)
	if not priority_ingredient.is_empty():
		var target_gap := maxi(0, RAW_REFILL_TARGET - int(_raw_ingredients.get(priority_ingredient, 0)))
		while space < target_gap:
			# The storekeeper exchanges surplus stock for the requested delivery.
			# It prevents a full warehouse from stranding a recipe ingredient.
			var surplus_key := ""
			var surplus_count := 2
			for key in _raw_ingredients.keys():
				if str(key) != priority_ingredient and int(_raw_ingredients[key]) > surplus_count:
					surplus_key = str(key)
					surplus_count = int(_raw_ingredients[key])
			if surplus_key.is_empty():
				break
			_raw_ingredients[surplus_key] = int(_raw_ingredients[surplus_key]) - 1
			space += 1
	for ingredient in delivery_order:
		if space <= 0:
			break
		var key := str(ingredient)
		if not priority_ingredient.is_empty() and key != priority_ingredient:
			continue
		var refill := mini(space, mini(RAW_PER_KIND, RAW_REFILL_TARGET) - int(_raw_ingredients[key]))
		if refill <= 0:
			continue
		_raw_ingredients[key] = int(_raw_ingredients[key]) + refill
		space -= refill
		loaded += refill
	if loaded <= 0:
		return _result(false, "raw_storage_full", "备料架已满，先制作几份餐点。")
	var result := _result(true, "raw_restocked", "后厨收到了 %d 份原料。" % loaded)
	result["group_id"] = group_id
	result["count"] = loaded
	_emit_state()
	event_happened.emit(result)
	return result


func take_raw_group(group_id: String) -> Dictionary:
	if not RAW_GROUPS.has(group_id):
		return _result(false, "unknown_supply", "这个仓库箱不可用。")
	if not _carried_ingredients.is_empty():
		return _result(false, "raw_in_hand", "先把手里的原料放到准备台。")
	var space := PREP_CAPACITY - _prep_total()
	if space <= 0:
		return _result(false, "prep_full", "准备台已满。")
	var selected_recipe: Dictionary = {}
	if _active and _selected_target == "ticket" and _selected_slot < _tickets.size():
		var selected_ticket: Dictionary = _tickets[_selected_slot]
		selected_recipe = RECIPES[int(selected_ticket["recipe_index"])]
	# One crate trip fills the entire category. Prioritize the selected dish if
	# the table is nearly full, but prepare other recipes on the same trip too.
	var pickup_order: Array = (RAW_GROUPS[group_id] as Array).duplicate()
	if not selected_recipe.is_empty():
		pickup_order.sort_custom(func(a, b): return int((selected_recipe["ingredients"] as Array).has(a)) > int((selected_recipe["ingredients"] as Array).has(b)))
	var carry := {}
	for ingredient in pickup_order:
		var key := str(ingredient)
		var needed := mini(PREP_PER_KIND - int(_prep_ingredients[key]), PREP_BATCH_TARGET - int(_prep_ingredients[key]))
		if needed <= 0:
			continue
		if int(_raw_ingredients[key]) < needed:
			var delivery := restock_group(group_id, key)
			if not bool(delivery.get("ok", false)) and int(_raw_ingredients[key]) <= 0:
				return delivery
		var picked := mini(needed, mini(int(_raw_ingredients[key]), mini(space, CARRY_CAPACITY - _count_items(carry))))
		if picked <= 0:
			break
		carry[key] = picked
		space -= picked
	if carry.is_empty():
		return _result(false, "prep_sufficient", "这类原料在准备台上已经够用了。")
	for key in carry.keys():
		_raw_ingredients[key] = int(_raw_ingredients[key]) - int(carry[key])
	_carried_ingredients = carry
	var result := _result(true, "raw_picked", "已从仓库取料，放到准备台。")
	result["group_id"] = group_id
	result["items"] = carry.duplicate()
	_emit_state()
	event_happened.emit(result)
	return result


func stage_raw_ingredient(ingredient_key: String) -> Dictionary:
	var group_id := ""
	for category in RAW_GROUPS.keys():
		if (RAW_GROUPS[category] as Array).has(ingredient_key):
			group_id = str(category)
			break
	if group_id.is_empty():
		return _result(false, "unknown_supply", "这个原料不可用。")
	# Old saves can contain a held group. Place it first so a one-click pantry
	# never leaves an invisible second-step dependency behind.
	if not _carried_ingredients.is_empty():
		place_carried_ingredients()
	var room := mini(PREP_CAPACITY - _prep_total(), PREP_BATCH_TARGET - int(_prep_ingredients[ingredient_key]))
	if room <= 0:
		return _result(false, "prep_full" if _prep_total() >= PREP_CAPACITY else "prep_sufficient", "这个备料位已满。")
	if int(_raw_ingredients[ingredient_key]) < room:
		var delivery := restock_group(group_id, ingredient_key)
		if not bool(delivery.get("ok", false)) and int(_raw_ingredients[ingredient_key]) <= 0:
			return delivery
	var moved := mini(room, int(_raw_ingredients[ingredient_key]))
	if moved <= 0:
		return _result(false, "raw_empty", "仓库暂时没有这种原料。")
	_raw_ingredients[ingredient_key] = int(_raw_ingredients[ingredient_key]) - moved
	_prep_ingredients[ingredient_key] = int(_prep_ingredients[ingredient_key]) + moved
	var result := _result(true, "raw_staged", "已备好 %d 份%s。" % [moved, ingredient_key])
	result["ingredient_key"] = ingredient_key
	result["group_id"] = group_id
	result["count"] = moved
	_emit_state()
	event_happened.emit(result)
	return result


func place_carried_ingredients() -> Dictionary:
	if _carried_ingredients.is_empty():
		if _prep_total() >= PREP_CAPACITY:
			return _return_prep_surplus()
		return _result(false, "hands_empty", "先到左侧仓库取原料。")
	var placed := _carried_ingredients.duplicate()
	for key in placed.keys():
		_prep_ingredients[key] = int(_prep_ingredients[key]) + int(placed[key])
	_carried_ingredients.clear()
	var result := _result(true, "raw_placed", "原料已放上准备台。")
	result["items"] = placed
	_emit_state()
	event_happened.emit(result)
	return result


func _return_prep_surplus() -> Dictionary:
	# A full worktop must always have a reversible way to make room. Keep the
	# selected meal's unspent ingredients first, then send four surplus portions
	# back to the warehouse. Overflow is cleared from the worktop as food waste.
	var keep := {}
	if _active and _selected_target == "ticket" and _selected_slot < _tickets.size():
		var ticket: Dictionary = _tickets[_selected_slot]
		if not bool(ticket.get("ingredients_reserved", false)):
			var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
			for ingredient in recipe["ingredients"]:
				keep[str(ingredient)] = true
	elif _selected_target == "stock" and STOCKS.has(str(_stock_job.get("id", ""))):
		keep[str(STOCKS[str(_stock_job["id"])]["ingredient_key"])] = true
	var order: Array[String] = []
	for key in _prep_ingredients.keys():
		if not keep.has(str(key)):
			order.append(str(key))
	for key in _prep_ingredients.keys():
		if keep.has(str(key)):
			order.append(str(key))
	var returned := {}
	var cleared := 0
	for key in order:
		while cleared < PREP_BATCH_TARGET and int(_prep_ingredients[key]) > (1 if keep.has(key) else 0):
			_prep_ingredients[key] = int(_prep_ingredients[key]) - 1
			if _raw_total() < RAW_CAPACITY and int(_raw_ingredients[key]) < RAW_PER_KIND:
				_raw_ingredients[key] = int(_raw_ingredients[key]) + 1
				returned[key] = int(returned.get(key, 0)) + 1
			cleared += 1
		if cleared >= PREP_BATCH_TARGET:
			break
	if cleared == 0:
		return _result(false, "prep_no_surplus", "准备台没有可以整理的余料。")
	var result := _result(true, "prep_cleared", "已整理准备台，腾出 %d 格。" % cleared)
	result["count"] = cleared
	result["returned"] = returned
	_emit_state()
	event_happened.emit(result)
	return result


func _count_items(items: Dictionary) -> int:
	var total := 0
	for quantity in items.values():
		total += int(quantity)
	return total


func _prep_total() -> int:
	return _count_items(_prep_ingredients)


func _raw_total() -> int:
	var total := 0
	for amount in _raw_ingredients.values():
		total += int(amount)
	return total


func _ingredient_shortage(recipe: Dictionary, prepared_stock_id: String = "") -> Array[String]:
	var missing: Array[String] = []
	var substitute := str(STOCKS[prepared_stock_id]["ingredient_key"]) if STOCKS.has(prepared_stock_id) else ""
	for ingredient in recipe["ingredients"]:
		var key := str(ingredient)
		if key == substitute:
			continue
		if int(_prep_ingredients.get(key, 0)) < 1:
			missing.append(key)
	return missing


func _recipe_ingredient_counts(recipe: Dictionary) -> Dictionary:
	var counts := {}
	for ingredient in recipe["ingredients"]:
		var key := str(ingredient)
		counts[key] = int(_prep_ingredients.get(key, 0))
	return counts


func _recipe_warehouse_counts(recipe: Dictionary) -> Dictionary:
	var counts := {}
	for ingredient in recipe["ingredients"]:
		var key := str(ingredient)
		counts[key] = int(_raw_ingredients.get(key, 0))
	return counts


func _ingredient_shortage_result(missing: Array[String]) -> Dictionary:
	var result := _result(false, "ingredient_shortage", "准备台缺料：点击左侧相应原料即可补足。")
	result["missing"] = missing
	_emit_state()
	event_happened.emit(result)
	return result


func _consume_recipe_ingredients(recipe: Dictionary, ticket: Dictionary, prepared_stock_id: String = "") -> void:
	var substitute := str(STOCKS[prepared_stock_id]["ingredient_key"]) if STOCKS.has(prepared_stock_id) else ""
	for ingredient in recipe["ingredients"]:
		var key := str(ingredient)
		if key == substitute:
			continue
		_prep_ingredients[key] = int(_prep_ingredients[key]) - 1
	ticket["ingredients_reserved"] = true


func _recipe_heat_action(recipe: Dictionary) -> String:
	for step in recipe["steps"]:
		if str(step) in HEAT_ACTIONS:
			return str(step)
	return ""


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var old_period := _period_for_clock()
	var old_day := _service_day
	_advance_clock(delta)
	var stock_changed := false
	var stock_losses := {"rice_batter": 0, "spice_oil": 0}
	if old_day != _service_day:
		for stock_id in STOCKS.keys():
			var overnight_units: Array = _stock_units[stock_id]
			stock_losses[stock_id] = overnight_units.size()
			stock_changed = stock_changed or not overnight_units.is_empty()
			overnight_units.clear()
		if _endless:
			_pantry["rice_mix"] = mini(PANTRY_LIMIT, int(_pantry["rice_mix"]) + 3)
			_pantry["spice_mix"] = mini(PANTRY_LIMIT, int(_pantry["spice_mix"]) + 3)
	if _endless and old_period != _period_for_clock():
		_shift_period = _period_for_clock()
	for stock_id in STOCKS.keys():
		var remaining: Array = _stock_units[stock_id]
		for i in range(remaining.size() - 1, -1, -1):
			remaining[i] = maxf(0.0, float(remaining[i]) - delta)
			if float(remaining[i]) <= 0.0:
				remaining.remove_at(i)
				stock_changed = true
				stock_losses[stock_id] = int(stock_losses[stock_id]) + 1
	var stock_display_second := -1
	for stock_id in STOCKS.keys():
		for remaining in _stock_units[stock_id]:
			var unit_second := ceili(float(remaining))
			if stock_display_second < 0 or unit_second < stock_display_second:
				stock_display_second = unit_second
	var stock_display_changed := stock_display_second != _last_stock_display_second
	_last_stock_display_second = stock_display_second
	if _combo_left > 0.0:
		_combo_left = maxf(0.0, _combo_left - delta)
		if _combo_left <= 0.0:
			_combo = 0
	if not _active:
		if stock_changed or stock_display_changed or old_period != _period_for_clock() or old_day != _service_day:
			_emit_state()
		_emit_stock_losses(stock_losses)
		return
	var was_active := _active
	_shift_elapsed += delta
	var events: Array[Dictionary] = []
	var expired_customers: Dictionary = {}
	_decrement_customer_patience(delta)
	for slot in range(_tickets.size() - 1, -1, -1):
		var ticket: Dictionary = _tickets[slot]
		var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
		if float(ticket["time_left"]) <= 0.0:
			var customer: Dictionary = _customer_for_order(int(ticket["order_number"]))
			var customer_key := str(customer["customer_id"])
			_customer_missed_counts[customer_key] = int(_customer_missed_counts.get(customer_key, 0)) + 1
			if not expired_customers.has(customer_key):
				expired_customers[customer_key] = {"customer": customer, "ticket_slot": slot,
					"missed_dishes": 0, "recipe_ids": [], "expired_orders": []}
			var departure: Dictionary = expired_customers[customer_key]
			departure["missed_dishes"] = int(departure["missed_dishes"]) + 1
			(departure["recipe_ids"] as Array).append(str(recipe["id"]))
			(departure["expired_orders"] as Array).append(int(ticket["order_number"]))
			expired_customers[customer_key] = departure
			_missed += 1
			_combo = 0
			_combo_left = 0.0
			_clear_buffer_for_order(int(ticket["order_number"]))
			_tickets.remove_at(slot)
			if slot < _selected_slot:
				_selected_slot -= 1
			continue
		if float(ticket["heat_left"]) > 0.0:
			var heat_before := float(ticket["heat_left"])
			ticket["heat_left"] = maxf(0.0, heat_before - delta)
			if float(ticket["heat_left"]) <= 0.0:
				if bool(ticket.get("reheating", false)):
					ticket["reheating"] = false
					ticket["warm_left"] = WARM_HOLD_SECONDS
					var rewarmed := _result(true, "reheat_ready", "回热好了，继续完成这份餐。")
					rewarmed["recipe_id"] = str(recipe["id"])
					rewarmed["ticket_slot"] = slot
					rewarmed["action_id"] = _recipe_heat_action(recipe)
					events.append(rewarmed)
				else:
					ticket["step_index"] = int(ticket["step_index"]) + 1
					ticket["pickup_left"] = maxf(0.0, float(MODES[_mode]["pickup_window"]) - maxf(0.0, delta - heat_before))
				if not bool(ticket.get("reheating", false)) and float(ticket["pickup_left"]) > 0.0:
					var ready := _result(true, "heat_ready", "加热完成，请在烧焦前取餐。")
					ready["recipe_id"] = str(recipe["id"])
					ready["ticket_slot"] = slot
					ready["customer_id"] = int(_customer_for_order(int(ticket["order_number"]))["customer_id"])
					ready["action_id"] = "heat_ready"
					events.append(ready)
				elif not bool(ticket.get("reheating", false)) and float(ticket.get("warm_left", 0.0)) <= 0.0:
					events.append(_overcook_ticket(ticket, recipe, slot))
		elif float(ticket.get("pickup_left", 0.0)) > 0.0:
			ticket["pickup_left"] = maxf(0.0, float(ticket["pickup_left"]) - delta)
			if float(ticket["pickup_left"]) <= 0.0:
				events.append(_overcook_ticket(ticket, recipe, slot))
		elif float(ticket.get("warm_left", 0.0)) > 0.0 and int(ticket.get("buffer_slot", -1)) < 0:
			ticket["warm_left"] = maxf(0.0, float(ticket["warm_left"]) - delta)
			if float(ticket["warm_left"]) <= 0.0:
				ticket["reheat_needed"] = true
				var cooled := _result(false, "dish_cooled", "这份菜凉了，回热后再完成。")
				cooled["recipe_id"] = str(recipe["id"])
				cooled["ticket_slot"] = slot
				cooled["action_id"] = _recipe_heat_action(recipe)
				events.append(cooled)
		var buffer_slot := int(ticket.get("buffer_slot", -1))
		if buffer_slot >= 0 and buffer_slot < BUFFER_CAPACITY and not _buffer[buffer_slot].is_empty():
			_buffer[buffer_slot]["fresh_left"] = maxf(0.0, float(_buffer[buffer_slot]["fresh_left"]) - delta)
			if float(_buffer[buffer_slot]["fresh_left"]) <= 0.0:
				_buffer[buffer_slot] = {}
				ticket.erase("buffer_slot")
				ticket["step_index"] = maxi(0, int(ticket["step_index"]) - 1)
				_penalize_customer_time(ticket, 3.0)
				ticket["mistakes"] = int(ticket["mistakes"]) + 1
				_mistakes += 1
				_combo = 0
				_combo_left = 0.0
				var spoiled := _result(false, "buffer_spoiled", "托盘上的餐点不新鲜了，重做最后一道工序。")
				spoiled["recipe_id"] = str(recipe["id"])
				spoiled["ticket_slot"] = slot
				spoiled["customer_id"] = int(_customer_for_order(int(ticket["order_number"]))["customer_id"])
				spoiled["buffer_slot"] = buffer_slot
				events.append(spoiled)
		_tickets[slot] = ticket
	for customer_key in expired_customers.keys():
		var departure: Dictionary = expired_customers[customer_key]
		var customer: Dictionary = departure["customer"]
		var expired := _result(false, "order_expired", "顾客离开了，未完成的餐点没有收入。")
		expired["customer_id"] = int(customer["customer_id"])
		expired["customer_label"] = str(customer["customer_label"])
		expired["group_size"] = int(customer["group_size"])
		expired["customer_complete"] = false
		expired["customer_left"] = true
		expired["ticket_slot"] = int(departure["ticket_slot"])
		expired["missed_dishes"] = int(departure["missed_dishes"])
		expired["recipe_ids"] = (departure["recipe_ids"] as Array).duplicate()
		expired["expired_orders"] = (departure["expired_orders"] as Array).duplicate()
		events.append(expired)
	_fill_tickets()
	if _mode == "rush" and not _rush_wave_triggered and _shift_elapsed >= _rush_wave_at:
		_rush_wave_triggered = true
		var before_wave := _tickets.size()
		_fill_tickets()
		if _tickets.size() > before_wave:
			var newcomer: Dictionary = _tickets.back()
			newcomer["time_left"] = _rush_wave_patience
			newcomer["patience_total"] = _rush_wave_patience
			newcomer["urgent"] = true
			_tickets[_tickets.size() - 1] = newcomer
			var newcomer_recipe: Dictionary = RECIPES[int(newcomer["recipe_index"])]
			var wave := _result(true, "rush_wave", "客流高峰来了，第三位顾客已入队。")
			wave["recipe_id"] = str(newcomer_recipe["id"])
			wave["ticket_slot"] = _tickets.size() - 1
			wave["urgent"] = true
			wave["patience_total"] = _rush_wave_patience
			wave["rush_wave_variant"] = _rush_wave_variant
			events.append(wave)
	_finish_if_complete()
	var second := ceili(float(_selected_ticket().get("time_left", 0.0))) if _active else -1
	if second != _last_display_second or not events.is_empty() or stock_changed or stock_display_changed or old_period != _period_for_clock() or old_day != _service_day or not _active:
		_emit_state()
	for event in events:
		event["state"] = snapshot()
		event_happened.emit(event)
	_emit_stock_losses(stock_losses)
	if was_active and not _active:
		shift_finished.emit(snapshot())


func clock_minutes() -> float:
	return _clock_minutes


func service_day() -> int:
	return _service_day


func service_period() -> String:
	return _period_for_clock()


func snapshot() -> Dictionary:
	var public_tickets: Array[Dictionary] = []
	for i in range(_tickets.size()):
		var ticket: Dictionary = _tickets[i]
		var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
		var steps: Array = recipe["steps"]
		var step_index := int(ticket["step_index"])
		var customer: Dictionary = _customer_for_order(int(ticket["order_number"]))
		var prepared_stock_id := str(recipe.get("stock", ""))
		var prepared_stock_count := (_stock_units[prepared_stock_id] as Array).size() if STOCKS.has(prepared_stock_id) and step_index == 0 else 0
		public_tickets.append({
			"slot": i, "order_number": int(ticket["order_number"]), "recipe": recipe.duplicate(true),
			"customer_id": int(customer["customer_id"]), "customer_label": str(customer["customer_label"]),
			"group_index": int(customer["group_index"]), "group_size": int(customer["group_size"]),
			"name": str(recipe["name"]), "step_index": step_index, "steps": steps.duplicate(),
			"started": bool(ticket.get("started", step_index > 0 or bool(ticket.get("ingredients_reserved", false)))),
			"ingredients_reserved": bool(ticket.get("ingredients_reserved", false)),
			"ingredient_counts": _recipe_ingredient_counts(recipe),
			"warehouse_counts": _recipe_warehouse_counts(recipe),
			"stock_substitute_key": str(STOCKS[prepared_stock_id]["ingredient_key"]) if prepared_stock_count > 0 else "",
			"stock_substitute_count": prepared_stock_count,
			"current_step": _recipe_heat_action(recipe) if bool(ticket.get("reheat_needed", false)) or bool(ticket.get("reheating", false)) else str(steps[step_index]),
			"next_action": _recipe_heat_action(recipe) if bool(ticket.get("reheat_needed", false)) or bool(ticket.get("reheating", false)) else str(steps[step_index]),
			"time_left": float(ticket["time_left"]), "patience_total": float(ticket.get("patience_total", MODES[_mode]["patience"])),
			"heat_left": float(ticket["heat_left"]), "heat_total": REHEAT_SECONDS if bool(ticket.get("reheating", false)) else float(recipe["cook_seconds"]),
			"reheat_needed": bool(ticket.get("reheat_needed", false)), "reheating": bool(ticket.get("reheating", false)),
			"warm_left": float(ticket.get("warm_left", 0.0)),
			"pickup_left": float(ticket.get("pickup_left", 0.0)), "pickup_total": float(MODES[_mode]["pickup_window"]),
			"waiting": float(ticket["heat_left"]) > 0.0, "urgent": bool(ticket.get("urgent", false)),
			"buffer_slot": int(ticket.get("buffer_slot", -1)), "buffered": int(ticket.get("buffer_slot", -1)) >= 0,
			"mistakes": int(ticket["mistakes"]), "count": 1
		})
	var selected: Dictionary = _selected_ticket()
	var current_recipe: Dictionary = RECIPES[int(selected["recipe_index"])] if not selected.is_empty() else {}
	var step := ""
	if _selected_target == "stock" and not _stock_job.is_empty():
		var stock_id := str(_stock_job["id"])
		step = str(STOCKS[stock_id]["steps"][int(_stock_job["step_index"])])
	elif not selected.is_empty():
		step = _recipe_heat_action(current_recipe) if bool(selected.get("reheat_needed", false)) or bool(selected.get("reheating", false)) else str(current_recipe["steps"][int(selected["step_index"])])
	var stage := _legacy_stage(step, float(selected.get("heat_left", 0.0))) if _active else _stage
	var stock_view: Array[Dictionary] = []
	for stock_id in ["rice_batter", "spice_oil"]:
		var units: Array = _stock_units[stock_id]
		var supply_key := str(STOCKS[stock_id]["supply_key"])
		var fresh_total := float(STOCKS[stock_id]["freshness"])
		var fresh_left := fresh_total if not units.is_empty() else 0.0
		for remaining in units:
			fresh_left = minf(fresh_left, float(remaining))
		stock_view.append({"id": stock_id, "name": str(STOCKS[stock_id]["name"]), "count": units.size(),
			"capacity": STOCK_CAPACITY, "fresh_left": fresh_left, "fresh_total": fresh_total, "units": units.duplicate(),
			"supply_key": supply_key, "supply_remaining": int(_pantry[supply_key])})
	var buffer_view: Array[Dictionary] = []
	for i in range(BUFFER_CAPACITY):
		var dish: Dictionary = _buffer[i]
		var dish_customer: Dictionary = _customer_for_order(int(dish["order_number"])) if not dish.is_empty() else {}
		buffer_view.append({"slot": i, "occupied": not dish.is_empty(),
			"recipe_id": str(dish.get("recipe_id", "")), "order_number": int(dish.get("order_number", 0)),
			"customer_id": int(dish_customer.get("customer_id", 0)),
			"group_index": int(dish_customer.get("group_index", 0)),
			"group_size": int(dish_customer.get("group_size", 0)),
			"combo_plate": not dish.is_empty() and int(dish.get("order_number", 0)) <= 2 and _combo_plate_active() and not _legacy_partial_combo(),
			"plate_ready": _combo_plate_ready() if not dish.is_empty() and int(dish.get("order_number", 0)) <= 2 else false,
			"fresh_left": float(dish.get("fresh_left", 0.0)), "fresh_total": BUFFER_FRESHNESS})
	var combo_recipe_ids: Array[String] = []
	for i in range(2):
		combo_recipe_ids.append(str(_buffer[i].get("recipe_id", "")))
	var combo_plate := {"active": _combo_plate_active() and not _legacy_partial_combo(),
		"customer_id": 1, "buffer_slots": [0, 1], "ready": _combo_plate_ready(),
		"staged_count": int(not _buffer[0].is_empty() and int(_buffer[0].get("order_number", 0)) == 1) + int(not _buffer[1].is_empty() and int(_buffer[1].get("order_number", 0)) == 2),
		"recipe_ids": combo_recipe_ids}
	var job_view := _stock_job.duplicate(true)
	if not job_view.is_empty():
		job_view["next_action"] = step
	return {
		"version": SAVE_VERSION, "active": _active, "endless": _endless, "mode": _mode, "stage": stage,
		"last_settlement": _last_settlement.duplicate(true), "session_start_day": _session_start_day,
		"clock_minutes": _clock_minutes, "day_minutes": _clock_minutes, "service_day": _service_day,
		"service_period": _period_for_clock(), "market_phase": _period_for_clock(), "shift_period": _shift_period,
		"queue": _queue.duplicate(), "order_index": _served + _missed, "next_order_index": _next_order_index,
		"tickets": public_tickets, "ticket_save": _tickets.duplicate(true), "selected_slot": _selected_slot,
		"selected_ticket": _selected_slot, "selected_target": _selected_target,
		"current_step": step, "next_action": step, "required_action": step,
		"time_left": float(selected.get("time_left", 0.0)), "patience_total": float(selected.get("patience_total", MODES[_mode]["patience"])) if _active else 0.0,
		"urgent": bool(selected.get("urgent", false)),
		"heat_left": float(selected.get("heat_left", 0.0)), "heat_total": REHEAT_SECONDS if bool(selected.get("reheating", false)) else float(current_recipe.get("cook_seconds", 0.0)),
		"reheat_needed": bool(selected.get("reheat_needed", false)), "reheating": bool(selected.get("reheating", false)),
		"pickup_left": float(selected.get("pickup_left", 0.0)), "pickup_total": float(MODES[_mode]["pickup_window"]) if _active else 0.0,
		"shift_elapsed": _shift_elapsed, "rush_wave_triggered": _rush_wave_triggered,
		"rush_wave_in": maxf(0.0, _rush_wave_at - _shift_elapsed) if _active and _mode == "rush" and not _rush_wave_triggered else 0.0,
		"rush_wave_at": _rush_wave_at, "rush_wave_variant": _rush_wave_variant,
		"rush_wave_patience": _rush_wave_patience, "rush_wave_bonus": _rush_wave_bonus,
		"mistakes": _mistakes, "served": _served, "missed": _missed, "earned_total": _earned_total,
		"has_combo_customer": _has_combo_customer,
		"combo_plate_version": 1, "combo_plate": combo_plate,
		"customer_served_counts": _customer_served_counts.duplicate(true),
		"customer_missed_counts": _customer_missed_counts.duplicate(true),
		"combo": _combo, "combo_left": _combo_left, "stock": stock_view,
		"stock_units": _stock_units.duplicate(true), "stock_job": job_view, "pantry": _pantry.duplicate(true),
		"raw_ingredients": _raw_ingredients.duplicate(true), "raw_capacity": RAW_CAPACITY, "raw_used": _raw_total(),
		"prep_ingredients": _prep_ingredients.duplicate(true), "prep_capacity": PREP_CAPACITY, "prep_used": _prep_total(),
		"carried_ingredients": _carried_ingredients.duplicate(true),
		"buffer": buffer_view, "buffer_save": _buffer.duplicate(true),
		"shift_serial": _shift_serial, "order": current_recipe.duplicate(true),
		"order_number": int(selected.get("order_number", 0)), "total_orders": 0 if _endless else _queue.size(),
		"energy_cost": energy_cost_for(_mode) if _active else 0, "migration": _migration
	}


func restore(data: Dictionary) -> void:
	_reset()
	var version := int(data.get("version", 0))
	if version == 1:
		_restore_legacy(data)
		_emit_state()
		return
	if version != SAVE_VERSION:
		_emit_state()
		return
	_shift_serial = maxi(0, int(data.get("shift_serial", 0)))
	_endless = bool(data.get("endless", false))
	var saved_settlement = data.get("last_settlement", {})
	_last_settlement = saved_settlement.duplicate(true) if saved_settlement is Dictionary else {}
	_session_start_day = maxi(1, int(data.get("session_start_day", 1)))
	_served = maxi(0, int(data.get("served", 0)))
	_missed = maxi(0, int(data.get("missed", 0)))
	_earned_total = maxi(0, int(data.get("earned_total", 0)))
	_mistakes = maxi(0, int(data.get("mistakes", 0)))
	_combo = clampi(int(data.get("combo", 0)), 0, 99)
	_combo_left = clampf(float(data.get("combo_left", 0.0)), 0.0, 4.0)
	_migration = str(data.get("migration", ""))
	_has_combo_customer = bool(data.get("has_combo_customer", false))
	var saved_customer_served = data.get("customer_served_counts", {})
	if saved_customer_served is Dictionary:
		for key in saved_customer_served.keys():
			_customer_served_counts[str(key)] = clampi(int(saved_customer_served[key]), 0, 2)
	var saved_customer_missed = data.get("customer_missed_counts", {})
	if saved_customer_missed is Dictionary:
		for key in saved_customer_missed.keys():
			_customer_missed_counts[str(key)] = clampi(int(saved_customer_missed[key]), 0, 2)
	_clock_minutes = clampf(float(data.get("clock_minutes", START_MINUTE)), START_MINUTE, CLOSING_MINUTE - 0.01)
	_service_day = maxi(1, int(data.get("service_day", 1)))
	_shift_period = str(data.get("shift_period", _period_for_clock()))
	if not SERVICE_PERIODS.has(_shift_period):
		_shift_period = _period_for_clock()
	var raw_pantry = data.get("pantry", {})
	if raw_pantry is Dictionary:
		for supply_key in _pantry.keys():
			_pantry[supply_key] = clampi(int(raw_pantry.get(supply_key, PANTRY_LIMIT)), 0, PANTRY_LIMIT)
	var saved_ingredients = data.get("raw_ingredients", {})
	if saved_ingredients is Dictionary:
		for ingredient_key in _raw_ingredients.keys():
			_raw_ingredients[ingredient_key] = clampi(int(saved_ingredients.get(ingredient_key, 6)), 0, RAW_PER_KIND)
	var saved_prep = data.get("prep_ingredients", {})
	if saved_prep is Dictionary and not saved_prep.is_empty():
		for ingredient_key in _prep_ingredients.keys():
			# Keep previously prepared portions from older, larger worktops.
			# New clicks obey the tighter target as those portions are consumed.
			_prep_ingredients[ingredient_key] = clampi(int(saved_prep.get(ingredient_key, 0)), 0, LEGACY_PREP_PER_KIND)
	var saved_carry = data.get("carried_ingredients", {})
	if saved_carry is Dictionary:
		for ingredient_key in saved_carry.keys():
			if _raw_ingredients.has(str(ingredient_key)) and _count_items(_carried_ingredients) < CARRY_CAPACITY:
				_carried_ingredients[str(ingredient_key)] = clampi(int(saved_carry[ingredient_key]), 0, CARRY_CAPACITY - _count_items(_carried_ingredients))
	_shift_elapsed = maxf(0.0, float(data.get("shift_elapsed", 0.0)))
	_rush_wave_triggered = bool(data.get("rush_wave_triggered", false))
	_rush_wave_variant = clampi(int(data.get("rush_wave_variant", 0)), 0, RUSH_WAVES.size() - 1)
	_rush_wave_at = maxf(0.0, float(data.get("rush_wave_at", RUSH_WAVE_AT))) if _endless else clampf(float(data.get("rush_wave_at", RUSH_WAVE_AT)), 8.0, 14.0)
	_rush_wave_patience = clampf(float(data.get("rush_wave_patience", MODES["rush"]["patience"])), 35.0, float(MODES["rush"]["patience"]))
	_rush_wave_bonus = clampi(int(data.get("rush_wave_bonus", 0)), 0, 40)
	_restore_stock(data.get("stock_units", {}))
	if not bool(data.get("active", false)):
		_stage = str(data.get("stage", "idle"))
		_emit_state()
		return
	var mode := str(data.get("mode", ""))
	var raw_queue = data.get("queue", [])
	var raw_tickets = data.get("ticket_save", [])
	if not MODES.has(mode) or not raw_queue is Array or not raw_tickets is Array:
		_migration = "invalid_shift_closed"
		_emit_state()
		return
	# Older version-2 saves may contain an active four/seven-order shift.
	var old_shift_orders := 4 if mode == "calm" else 7
	if (raw_queue.size() != 10 if _endless else raw_queue.size() not in [old_shift_orders, int(MODES[mode]["orders"])]) or raw_tickets.size() > 3:
		_migration = "invalid_shift_closed"
		_emit_state()
		return
	for entry in raw_queue:
		var recipe_index := int(entry)
		if recipe_index < 0 or recipe_index >= RECIPES.size():
			_migration = "invalid_shift_closed"
			_emit_state()
			return
		_queue.append(recipe_index)
	_mode = mode
	_next_order_index = clampi(int(data.get("next_order_index", 0)), 0, 1000000000 if _endless else _queue.size())
	for raw_ticket in raw_tickets:
		if not raw_ticket is Dictionary:
			continue
		var recipe_index := int(raw_ticket.get("recipe_index", -1))
		if recipe_index < 0 or recipe_index >= RECIPES.size():
			continue
		var recipe: Dictionary = RECIPES[recipe_index]
		var step_index := int(raw_ticket.get("step_index", -1))
		if step_index < 0 or step_index >= (recipe["steps"] as Array).size():
			continue
		_tickets.append({"recipe_index": recipe_index,
			"order_number": clampi(int(raw_ticket.get("order_number", 1)), 1, maxi(_queue.size(), _next_order_index) if _endless else _queue.size()),
			"step_index": step_index,
			"time_left": clampf(float(raw_ticket.get("time_left", 1.0)), 0.01, float(raw_ticket.get("patience_total", MODES[mode]["patience"]))),
			"patience_total": clampf(float(raw_ticket.get("patience_total", MODES[mode]["patience"])), 35.0, float(MODES[mode]["patience"])),
			"urgent": bool(raw_ticket.get("urgent", false)),
			"heat_left": clampf(float(raw_ticket.get("heat_left", 0.0)), 0.0, float(recipe["cook_seconds"])),
			"pickup_left": clampf(float(raw_ticket.get("pickup_left", 0.0)), 0.0, float(MODES[mode]["pickup_window"])),
			"warm_left": clampf(float(raw_ticket.get("warm_left", 0.0)), 0.0, WARM_HOLD_SECONDS),
			"reheat_needed": bool(raw_ticket.get("reheat_needed", false)),
			"reheating": bool(raw_ticket.get("reheating", false)),
			"started": bool(raw_ticket.get("started", step_index > 0 or bool(raw_ticket.get("ingredients_reserved", false)) or int(raw_ticket.get("buffer_slot", -1)) >= 0)),
			"ingredients_reserved": bool(raw_ticket.get("ingredients_reserved", int(raw_ticket.get("step_index", 0)) > 0)),
			"buffer_slot": clampi(int(raw_ticket.get("buffer_slot", -1)), -1, BUFFER_CAPACITY - 1),
			"mistakes": maxi(0, int(raw_ticket.get("mistakes", 0)))})
	if _tickets.is_empty() and _next_order_index >= _queue.size():
		_migration = "invalid_shift_closed"
		_emit_state()
		return
	_active = true
	var raw_buffer = data.get("buffer_save", [])
	if raw_buffer is Array:
		for i in range(mini(BUFFER_CAPACITY, raw_buffer.size())):
			if not raw_buffer[i] is Dictionary or raw_buffer[i].is_empty():
				continue
			var order_number := int(raw_buffer[i].get("order_number", -1))
			var found := false
			for ticket in _tickets:
				if int(ticket["order_number"]) == order_number and int(ticket.get("buffer_slot", -1)) == i:
					found = true
					break
			if found:
				_buffer[i] = {"order_number": order_number,
					"recipe_id": str(raw_buffer[i].get("recipe_id", "")),
					"fresh_left": clampf(float(raw_buffer[i].get("fresh_left", 0.0)), 0.01, BUFFER_FRESHNESS)}
	for i in range(_tickets.size()):
		var ticket: Dictionary = _tickets[i]
		var buffer_slot := int(ticket.get("buffer_slot", -1))
		if buffer_slot >= 0 and _buffer[buffer_slot].is_empty():
			ticket["buffer_slot"] = -1
			_tickets[i] = ticket
	_normalize_combo_buffer_positions()
	_selected_slot = clampi(int(data.get("selected_slot", 0)), 0, maxi(0, _tickets.size() - 1))
	_selected_target = "ticket"
	var saved_target := str(data.get("selected_target", "ticket"))
	var raw_job = data.get("stock_job", {})
	if saved_target == "stock" and raw_job is Dictionary and STOCKS.has(str(raw_job.get("id", ""))):
		var job_id := str(raw_job["id"])
		var job_step := int(raw_job.get("step_index", 0))
		if job_step >= 0 and job_step < (STOCKS[job_id]["steps"] as Array).size():
			_stock_job = {"id": job_id, "step_index": job_step}
			_selected_target = "stock"
	_fill_tickets()
	_emit_state()


func cancel_shift() -> Dictionary:
	if not _active:
		return _result(false, "not_working", "当前没有进行中的班次。")
	_active = false
	_stage = "finished"
	_tickets.clear()
	_stock_job.clear()
	_buffer = [{}, {}, {}]
	var result := _result(true, "shift_cancelled", "本班提前结束，已完成订单的收入保留。")
	_emit_state()
	event_happened.emit(result)
	shift_finished.emit(snapshot())
	return result


func set_service_mode(mode: String) -> Dictionary:
	if not _active or not MODES.has(mode):
		return _result(false, "mode_unavailable", "现在不能调整营业节奏。")
	_mode = mode
	if mode == "rush":
		_rush_wave_triggered = false
		_rush_wave_at = _shift_elapsed + 8.0
	else:
		_rush_wave_triggered = false
	var result := _result(true, "mode_changed", "已调整营业节奏。")
	result["mode"] = mode
	_emit_state()
	event_happened.emit(result)
	return result


func make_endless() -> void:
	if not _active or _endless:
		return
	_endless = true
	_queue.clear()
	for recipe_index in PERIOD_MENUS[_period_for_clock()]:
		_queue.append(int(recipe_index))
	_session_start_day = _service_day
	_emit_state()


func close_day() -> Dictionary:
	if not _active or not _endless:
		return _result(false, "closing_unavailable", "现在没有营业中的餐馆。")
	_active = false
	_stage = "closed"
	_tickets.clear()
	_stock_job.clear()
	_buffer = [{}, {}, {}]
	_selected_target = "ticket"
	_last_settlement = {
		"served": _served, "missed": _missed, "earned": _earned_total,
		"mistakes": _mistakes, "days": _service_day - _session_start_day + 1,
		"clock_minutes": _clock_minutes, "mode": _mode
	}
	var result := _result(true, "day_closed", "餐馆打烊，结算已完成。")
	result["settlement"] = _last_settlement.duplicate(true)
	_emit_state()
	event_happened.emit(result)
	shift_finished.emit(snapshot())
	return result


func _interact_stock(action_id: String) -> Dictionary:
	var stock_id := str(_stock_job["id"])
	var steps: Array = STOCKS[stock_id]["steps"]
	var expected := str(steps[int(_stock_job["step_index"])])
	if action_id != expected:
		return _wrong_action({}, expected)
	var supply_key := str(STOCKS[stock_id]["supply_key"])
	var ingredient_key := str(STOCKS[stock_id]["ingredient_key"])
	if int(_stock_job["step_index"]) == steps.size() - 1:
		if int(_pantry[supply_key]) <= 0:
			return _result(false, "stock_supplies_empty", "这批底料的备货包用完了。")
		if int(_prep_ingredients.get(ingredient_key, 0)) <= 0:
			return _ingredient_shortage_result([ingredient_key])
	_stock_job["step_index"] = int(_stock_job["step_index"]) + 1
	_gain_combo()
	var result: Dictionary
	if int(_stock_job["step_index"]) >= steps.size():
		_pantry[supply_key] = int(_pantry[supply_key]) - 1
		_prep_ingredients[ingredient_key] = int(_prep_ingredients[ingredient_key]) - 1
		var units: Array = _stock_units[stock_id]
		for i in range(int(STOCKS[stock_id]["yield"])):
			units.append(float(STOCKS[stock_id]["freshness"]))
		_stock_job.clear()
		_selected_target = "ticket"
		result = _result(true, "stock_prepared", "%s完成 %d 份，保鲜架现有 %d / %d 份。" % [str(STOCKS[stock_id]["name"]), int(STOCKS[stock_id]["yield"]), _stock_count(), STOCK_CAPACITY])
	else:
		result = _result(true, "step_done", "底料已完成第一步，还需%s。" % _action_name(str(steps[int(_stock_job["step_index"])])))
	result["stock_id"] = stock_id
	result["action_id"] = action_id
	result["target"] = "stock"
	result["supply_remaining"] = int(_pantry[supply_key])
	_emit_state()
	event_happened.emit(result)
	return result


func _wrong_action(ticket: Dictionary, expected: String) -> Dictionary:
	_mistakes += 1
	_combo = 0
	_combo_left = 0.0
	if not ticket.is_empty() and _active:
		ticket["mistakes"] = int(ticket["mistakes"]) + 1
		_penalize_customer_time(ticket, float(MODES[_mode]["mistake_penalty"]))
		_tickets[_selected_slot] = ticket
	var result := _result(false, "wrong_action", "顺序不对，下一步请%s。" % _action_name(expected))
	result["expected_action"] = expected
	result["target"] = _selected_target
	if not ticket.is_empty():
		result["customer_id"] = int(_customer_for_order(int(ticket["order_number"]))["customer_id"])
		result["ticket_slot"] = _selected_slot
	_emit_state()
	event_happened.emit(result)
	return result


func _serve_ticket(ticket: Dictionary, recipe: Dictionary) -> Dictionary:
	var config: Dictionary = MODES[_mode]
	var period_config: Dictionary = SERVICE_PERIODS[_shift_period]
	var customer: Dictionary = _customer_for_order(int(ticket["order_number"]))
	var customer_key := str(customer["customer_id"])
	var patience_ratio := clampf(float(ticket["time_left"]) / float(ticket.get("patience_total", config["patience"])), 0.0, 1.0)
	var base := roundi(float(recipe["price"]) * float(config["price_scale"]) * float(period_config["price_scale"]))
	var speed_tip := roundi(float(config["tip"]) * float(period_config["tip_scale"]) * patience_ratio)
	var combo_tip := mini(_combo, 12) * 2
	var clean_tip := 8 if int(ticket["mistakes"]) == 0 else 0
	var urgent_bonus := _rush_wave_bonus if bool(ticket.get("urgent", false)) else 0
	var buffer_slot := int(ticket.get("buffer_slot", -1))
	var from_buffer := buffer_slot >= 0 and buffer_slot < BUFFER_CAPACITY and not _buffer[buffer_slot].is_empty()
	var buffer_bonus := roundi(8.0 * float(_buffer[buffer_slot]["fresh_left"]) / BUFFER_FRESHNESS) if from_buffer else 0
	_customer_served_counts[customer_key] = int(_customer_served_counts.get(customer_key, 0)) + 1
	var customer_remaining := maxi(0, int(customer["group_size"]) - int(_customer_served_counts[customer_key]) - int(_customer_missed_counts.get(customer_key, 0)))
	var customer_complete := customer_remaining == 0 and int(_customer_missed_counts.get(customer_key, 0)) == 0
	var group_bonus := int(GROUP_BONUS[_mode]) if int(customer["group_size"]) == 2 and customer_complete else 0
	var earned := base + speed_tip + combo_tip + clean_tip + urgent_bonus + buffer_bonus + group_bonus
	_served += 1
	_clear_buffer_for_order(int(ticket["order_number"]))
	_tickets.remove_at(_selected_slot)
	_fill_tickets()
	if not _endless and _served + _missed >= _queue.size() and _missed == 0:
		earned += int(config["bonus"])
	_earned_total += earned
	_finish_if_complete()
	var result := _result(true, "served", "交餐完成，收入 %d 贝。" % earned, earned)
	result["urgent"] = bool(ticket.get("urgent", false))
	result["urgent_bonus"] = urgent_bonus
	result["from_buffer"] = from_buffer
	result["buffer_slot"] = buffer_slot if from_buffer else -1
	result["buffer_bonus"] = buffer_bonus
	result["service_period"] = _shift_period
	result["customer_id"] = int(customer["customer_id"])
	result["customer_label"] = str(customer["customer_label"])
	result["group_index"] = int(customer["group_index"])
	result["group_size"] = int(customer["group_size"])
	result["customer_remaining"] = customer_remaining
	result["customer_complete"] = customer_complete
	result["customer_left"] = customer_remaining == 0
	result["group_bonus"] = group_bonus
	return result


func _stage_ticket_in_buffer(ticket: Dictionary, recipe: Dictionary, slot: int, action_id: String) -> Dictionary:
	var customer: Dictionary = _customer_for_order(int(ticket["order_number"]))
	var staged_slot := _selected_slot
	_buffer[slot] = {"order_number": int(ticket["order_number"]), "recipe_id": str(recipe["id"]),
		"fresh_left": BUFFER_FRESHNESS}
	ticket["buffer_slot"] = slot
	_tickets[staged_slot] = ticket
	var result := _result(true, "dish_buffered", "餐点已放上保温托盘。")
	result["ticket_slot"] = staged_slot
	result["customer_id"] = int(customer["customer_id"])
	result["group_index"] = int(customer["group_index"])
	result["group_size"] = int(customer["group_size"])
	result["buffer_slot"] = slot
	result["buffer_slots"] = [0, 1] if int(customer["group_size"]) == 2 and not _legacy_partial_combo() else [slot]
	result["combo_plate"] = int(customer["group_size"]) == 2 and not _legacy_partial_combo()
	result["combo_ready"] = _combo_plate_ready()
	result["recipe_id"] = str(recipe["id"])
	result["action_id"] = action_id
	return result


func _combo_plate_active() -> bool:
	if not _has_combo_customer or int(_customer_missed_counts.get("1", 0)) > 0:
		return false
	for ticket in _tickets:
		if int(ticket["order_number"]) <= 2:
			return true
	return false


func _legacy_partial_combo() -> bool:
	return _has_combo_customer and int(_customer_served_counts.get("1", 0)) > 0 and int(_customer_served_counts.get("1", 0)) < 2


func _combo_requires_joint(ticket: Dictionary) -> bool:
	return _has_combo_customer and int(ticket["order_number"]) <= 2 and not _legacy_partial_combo() and int(_customer_missed_counts.get("1", 0)) == 0


func _combo_plate_ready() -> bool:
	if not _combo_plate_active() or _legacy_partial_combo():
		return false
	for slot in range(2):
		if _buffer[slot].is_empty() or int(_buffer[slot].get("order_number", 0)) != slot + 1:
			return false
	return true


func _normalize_combo_buffer_positions() -> void:
	if not _combo_plate_active() or _legacy_partial_combo():
		return
	var by_order: Dictionary = {}
	for dish in _buffer:
		if not dish.is_empty():
			by_order[int(dish["order_number"])] = dish.duplicate(true)
	_buffer = [{}, {}, {}]
	for order_number in [1, 2]:
		if by_order.has(order_number):
			_buffer[order_number - 1] = by_order[order_number]
	for order_number in by_order.keys():
		if int(order_number) > 2:
			_buffer[2] = by_order[order_number]
	for i in range(_tickets.size()):
		var ticket: Dictionary = _tickets[i]
		var order_number := int(ticket["order_number"])
		if by_order.has(order_number):
			ticket["buffer_slot"] = order_number - 1 if order_number <= 2 else 2
		else:
			ticket["buffer_slot"] = -1
		_tickets[i] = ticket


func _combo_dish_value(ticket: Dictionary, recipe: Dictionary, buffer_slot: int) -> int:
	var config: Dictionary = MODES[_mode]
	var period_config: Dictionary = SERVICE_PERIODS[_shift_period]
	var patience_ratio := clampf(float(ticket["time_left"]) / float(ticket.get("patience_total", config["patience"])), 0.0, 1.0)
	var base := roundi(float(recipe["price"]) * float(config["price_scale"]) * float(period_config["price_scale"]))
	var speed_tip := roundi(float(config["tip"]) * float(period_config["tip_scale"]) * patience_ratio)
	var combo_tip := mini(_combo, 12) * 2
	var clean_tip := 8 if int(ticket["mistakes"]) == 0 else 0
	var urgent_bonus := _rush_wave_bonus if bool(ticket.get("urgent", false)) else 0
	var buffer_bonus := roundi(8.0 * float(_buffer[buffer_slot]["fresh_left"]) / BUFFER_FRESHNESS)
	return base + speed_tip + combo_tip + clean_tip + urgent_bonus + buffer_bonus


func _serve_combo() -> Dictionary:
	var recipe_ids: Array[String] = []
	var ticket_slots: Array[int] = []
	var earned := int(GROUP_BONUS[_mode])
	var buffer_bonus := 0
	for dish_slot in range(2):
		for ticket_slot in range(_tickets.size()):
			var ticket: Dictionary = _tickets[ticket_slot]
			if int(ticket["order_number"]) != dish_slot + 1:
				continue
			var recipe: Dictionary = RECIPES[int(ticket["recipe_index"])]
			recipe_ids.append(str(recipe["id"]))
			ticket_slots.append(ticket_slot)
			earned += _combo_dish_value(ticket, recipe, dish_slot)
			buffer_bonus += roundi(8.0 * float(_buffer[dish_slot]["fresh_left"]) / BUFFER_FRESHNESS)
			break
	var removal_slots := ticket_slots.duplicate()
	removal_slots.sort()
	for ticket_slot in range(removal_slots.size() - 1, -1, -1):
		_tickets.remove_at(removal_slots[ticket_slot])
	_buffer[0] = {}
	_buffer[1] = {}
	_customer_served_counts["1"] = 2
	_served += 2
	_fill_tickets()
	if not _endless and _served + _missed >= _queue.size() and _missed == 0:
		earned += int(MODES[_mode]["bonus"])
	_earned_total += earned
	_finish_if_complete()
	var result := _result(true, "served_combo", "两道菜统一交付，收入 %d 贝。" % earned, earned)
	result["customer_id"] = 1
	result["customer_label"] = "顾客 1"
	result["group_size"] = 2
	result["customer_remaining"] = 0
	result["customer_complete"] = true
	result["customer_left"] = true
	result["group_bonus"] = int(GROUP_BONUS[_mode])
	result["recipe_ids"] = recipe_ids
	result["ticket_slots"] = ticket_slots
	result["buffer_slots"] = [0, 1]
	result["buffer_bonus"] = buffer_bonus
	result["from_buffer"] = true
	result["service_period"] = _shift_period
	return result


func _fill_tickets() -> void:
	if not _active:
		return
	var capacity := 3 if _mode == "rush" and _rush_wave_triggered else 2
	while _tickets.size() < capacity and (_endless or _next_order_index < _queue.size()):
		var recipe_index := int(PERIOD_MENUS[_period_for_clock()][_next_order_index % 10]) if _endless else int(_queue[_next_order_index])
		_tickets.append({"recipe_index": recipe_index, "order_number": _next_order_index + 1,
			"step_index": 0, "time_left": float(MODES[_mode]["patience"]), "patience_total": float(MODES[_mode]["patience"]),
			"started": false,
			"ingredients_reserved": false,
			"urgent": false, "heat_left": 0.0, "buffer_slot": -1,
			"pickup_left": 0.0, "warm_left": 0.0, "reheat_needed": false, "reheating": false, "mistakes": 0})
		_next_order_index += 1
	_selected_slot = clampi(_selected_slot, 0, maxi(0, _tickets.size() - 1))
	if _endless:
		var active_customers := {}
		for ticket in _tickets:
			active_customers[str(_customer_for_order(int(ticket["order_number"]))["customer_id"])] = true
		for key in _customer_served_counts.keys():
			if not active_customers.has(str(key)):
				_customer_served_counts.erase(key)
		for key in _customer_missed_counts.keys():
			if not active_customers.has(str(key)):
				_customer_missed_counts.erase(key)


func _finish_if_complete() -> void:
	if _active and not _endless and _served + _missed >= _queue.size():
		_active = false
		_stage = "finished"
		_tickets.clear()
		_stock_job.clear()
		_buffer = [{}, {}, {}]
		_selected_target = "ticket"


func _selected_ticket() -> Dictionary:
	return _tickets[_selected_slot] if _active and _selected_slot < _tickets.size() else {}


func _stock_count() -> int:
	return (_stock_units["rice_batter"] as Array).size() + (_stock_units["spice_oil"] as Array).size()


func _customer_for_order(order_number: int) -> Dictionary:
	var grouped := _has_combo_customer and order_number <= 2
	var customer_id := 1 if grouped else (order_number - 1 if _has_combo_customer else order_number)
	return {"customer_id": customer_id, "customer_label": "顾客 %d" % customer_id,
		"group_index": order_number if grouped else 1, "group_size": 2 if grouped else 1}


func _customer_key(ticket: Dictionary) -> String:
	return str(_customer_for_order(int(ticket["order_number"]))["customer_id"])


func _sync_customer_time(customer_key: String, remaining: float) -> void:
	for i in range(_tickets.size()):
		var sibling: Dictionary = _tickets[i]
		if _customer_key(sibling) == customer_key:
			sibling["time_left"] = remaining
			_tickets[i] = sibling


func _penalize_customer_time(ticket: Dictionary, seconds: float) -> void:
	var remaining := maxf(1.0, float(ticket["time_left"]) - seconds)
	ticket["time_left"] = remaining
	_sync_customer_time(_customer_key(ticket), remaining)


func _decrement_customer_patience(delta: float) -> void:
	var remaining_by_customer: Dictionary = {}
	for ticket in _tickets:
		var key := _customer_key(ticket)
		var current := float(ticket["time_left"])
		remaining_by_customer[key] = minf(float(remaining_by_customer.get(key, current)), current)
	for key in remaining_by_customer.keys():
		_sync_customer_time(str(key), maxf(0.0, float(remaining_by_customer[key]) - delta))


func _clear_buffer_for_order(order_number: int) -> void:
	for i in range(BUFFER_CAPACITY):
		if int(_buffer[i].get("order_number", -1)) == order_number:
			_buffer[i] = {}


func _period_for_clock() -> String:
	if _clock_minutes < 660.0:
		return "morning"
	if _clock_minutes < 1020.0:
		return "lunch"
	return "evening"


func _advance_clock(delta: float) -> void:
	var playable_day := CLOSING_MINUTE - START_MINUTE
	var offset := _clock_minutes - START_MINUTE + delta * GAME_MINUTES_PER_SECOND
	if offset >= playable_day:
		var day_count := floori(offset / playable_day)
		_service_day += day_count
		offset = fposmod(offset, playable_day)
	_clock_minutes = START_MINUTE + offset


func _emit_stock_losses(losses: Dictionary) -> void:
	for stock_id in losses.keys():
		var count := int(losses[stock_id])
		if count <= 0:
			continue
		var result := _result(false, "stock_spoiled", "%d 份%s已过保鲜期。" % [count, str(STOCKS[stock_id]["name"])])
		result["stock_id"] = stock_id
		result["count"] = count
		event_happened.emit(result)


func _gain_combo() -> void:
	_combo = _combo + 1 if _combo_left > 0.0 else 1
	_combo_left = 4.0


func _overcook_ticket(ticket: Dictionary, recipe: Dictionary, slot: int) -> Dictionary:
	ticket["step_index"] = maxi(0, int(ticket["step_index"]) - 1)
	ticket["pickup_left"] = 0.0
	ticket["warm_left"] = 0.0
	ticket["reheat_needed"] = false
	ticket["reheating"] = false
	_penalize_customer_time(ticket, float(MODES[_mode]["overcook_penalty"]))
	ticket["mistakes"] = int(ticket["mistakes"]) + 1
	_mistakes += 1
	_combo = 0
	_combo_left = 0.0
	var burned := _result(false, "overcooked", "食物烧焦了，重新加热这一份。")
	burned["recipe_id"] = str(recipe["id"])
	burned["ticket_slot"] = slot
	burned["customer_id"] = int(_customer_for_order(int(ticket["order_number"]))["customer_id"])
	burned["action_id"] = str(recipe["steps"][int(ticket["step_index"])])
	return burned


func _legacy_stage(action_id: String, heat_left: float) -> String:
	if heat_left > 0.0:
		return "heating"
	if HEAT_ACTIONS.has(action_id):
		return "heat"
	if action_id == "garnish":
		return "plate"
	if action_id == "serve":
		return "serve"
	return "prep"


func _action_name(action_id: String) -> String:
	return {"wash": "清洗", "slice": "切配", "mix": "搅拌", "marinate": "腌制", "portion": "分装",
		"steam": "蒸制", "fry": "煎制", "boil": "煮制", "garnish": "点缀", "serve": "交餐"}.get(action_id, "操作")


func _restore_stock(raw) -> void:
	if not raw is Dictionary:
		return
	for stock_id in STOCKS.keys():
		var source = raw.get(stock_id, [])
		if not source is Array:
			continue
		for duration in source:
			if _stock_count() >= STOCK_CAPACITY:
				return
			var remaining := clampf(float(duration), 0.0, float(STOCKS[stock_id]["freshness"]))
			if remaining > 0.0:
				(_stock_units[stock_id] as Array).append(remaining)


func _restore_legacy(data: Dictionary) -> void:
	_shift_serial = maxi(0, int(data.get("shift_serial", 0)))
	_served = maxi(0, int(data.get("served", 0)))
	_missed = maxi(0, int(data.get("missed", 0)))
	_earned_total = maxi(0, int(data.get("earned_total", 0)))
	_mistakes = maxi(0, int(data.get("mistakes", 0)))
	var raw_queue = data.get("queue", [])
	if raw_queue is Array:
		for entry in raw_queue:
			_queue.append(clampi(int(entry), 0, RECIPES.size() - 1))
	_mode = str(data.get("mode", "")) if MODES.has(str(data.get("mode", ""))) else ""
	_stage = "finished" if bool(data.get("active", false)) else str(data.get("stage", "idle"))
	_migration = "legacy_shift_closed" if bool(data.get("active", false)) else "legacy_idle_migrated"
	# The outer life state already contains paid cash and spent energy. Never emit earned on migration.


func _result(ok: bool, event: String, message: String, earned: int = 0) -> Dictionary:
	return {"ok": ok, "event": event, "message": message, "earned": maxi(0, earned), "state": snapshot()}


func _emit_state() -> void:
	_last_display_second = ceili(float(_selected_ticket().get("time_left", 0.0))) if _active else -1
	state_changed.emit(snapshot())


func _reset() -> void:
	_active = false
	_endless = false
	_mode = ""
	_stage = "idle"
	_last_settlement.clear()
	_session_start_day = 1
	_queue.clear()
	_next_order_index = 0
	_tickets.clear()
	_selected_slot = 0
	_selected_target = "ticket"
	_stock_job.clear()
	_stock_units = {"rice_batter": [], "spice_oil": []}
	_pantry = {"rice_mix": PANTRY_LIMIT, "spice_mix": PANTRY_LIMIT}
	for ingredient_key in _prep_ingredients.keys():
		_prep_ingredients[ingredient_key] = 1
	_carried_ingredients.clear()
	_buffer = [{}, {}, {}]
	_mistakes = 0
	_served = 0
	_missed = 0
	_earned_total = 0
	_combo = 0
	_combo_left = 0.0
	_shift_serial = 0
	_migration = ""
	_last_display_second = -1
	_last_stock_display_second = -1
	_shift_elapsed = 0.0
	_rush_wave_triggered = false
	_rush_wave_variant = 0
	_rush_wave_at = RUSH_WAVE_AT
	_rush_wave_patience = float(MODES["rush"]["patience"])
	_rush_wave_bonus = 0
	_clock_minutes = START_MINUTE
	_service_day = 1
	_shift_period = "morning"
	_has_combo_customer = false
	_customer_served_counts.clear()
	_customer_missed_counts.clear()
