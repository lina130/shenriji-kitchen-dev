extends SceneTree

const RestaurantScript := preload("res://scripts/city3d/talent_park_restaurant.gd")

var failures: Array[String] = []
var settlement_events := 0
var event_log: Array[String] = []
var event_payloads: Array[Dictionary] = []
var stock_state_updates := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_recipes()
	_check_customer_group()
	_check_stock_and_restore()
	_check_heat_switch_and_recovery()
	_check_rush_wave_and_overcook()
	_check_service_clock_and_continuous_shifts()
	_check_stock_supplies_and_buffers()
	_check_raw_ingredient_storage()
	_check_endless_closing()
	_check_cooling_and_reheat()
	_check_economy()
	_check_legacy_migration()
	for child in root.get_children():
		if child.get_script() == RestaurantScript:
			child.free()
	if failures.is_empty():
		print("PASS talent_park_restaurant_v2_test: recipes, parallel tickets, stock, heat, economy, saves")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_recipes() -> void:
	var recipes: Array = RestaurantScript.RECIPES
	_check(recipes.size() == 10, "Expected exactly 10 dishes")
	var seen := {}
	var ranges := {}
	for recipe in recipes:
		var steps: Array = recipe["steps"]
		_check((recipe.get("ingredients", []) as Array).size() >= 2, "Recipe lacks ingredient icon IDs: " + str(recipe["id"]))
		_check(steps.size() >= 3 and steps.size() <= 6, "Recipe step count outside 3..6: " + str(recipe["id"]))
		_check(str(steps.back()) == "serve", "Recipe does not end with serve: " + str(recipe["id"]))
		for step in steps:
			_check(RestaurantScript.ACTIONS.has(step), "Unknown action: " + str(step))
		var composition := ",".join(steps)
		_check(not seen.has(composition), "Duplicate recipe action sequence: " + str(recipe["id"]))
		seen[composition] = true
		var count := steps.size()
		if not ranges.has(count):
			ranges[count] = {"minimum": 9999, "maximum": 0}
		ranges[count]["minimum"] = mini(int(ranges[count]["minimum"]), int(recipe["price"]))
		ranges[count]["maximum"] = maxi(int(ranges[count]["maximum"]), int(recipe["price"]))
	_check(int(ranges[4]["maximum"]) < int(ranges[5]["minimum"]), "Five-step meals should be worth more than four-step meals")
	_check(int(ranges[5]["maximum"]) < int(ranges[6]["minimum"]), "Six-step meals should be worth more than five-step meals")


func _check_customer_group() -> void:
	var kitchen = RestaurantScript.new()
	root.add_child(kitchen)
	kitchen.start_shift("calm")
	var opening: Dictionary = kitchen.snapshot()
	var first: Dictionary = opening["tickets"][0]
	var second: Dictionary = opening["tickets"][1]
	_check(int(first["customer_id"]) == int(second["customer_id"]) and str(first["customer_label"]) == "顾客 1", "First two dishes must belong to the same visible customer")
	_check(int(first["group_index"]) == 1 and int(second["group_index"]) == 2 and int(first["group_size"]) == 2 and int(second["group_size"]) == 2, "Combo tickets need stable 1-of-2 and 2-of-2 fields")
	kitchen.tick(2.0)
	var before_mistake := float(kitchen.snapshot()["tickets"][0]["time_left"])
	var wrong: Dictionary = kitchen.interact("serve")
	var after_mistake: Dictionary = kitchen.snapshot()
	_check(int(wrong.get("customer_id", -1)) == 1 and float(after_mistake["tickets"][0]["time_left"]) < before_mistake, "Wrong action should identify the customer and cost shared patience")
	_check(is_equal_approx(float(after_mistake["tickets"][0]["time_left"]), float(after_mistake["tickets"][1]["time_left"])), "Sibling dishes must share the same remaining patience")
	var restored = RestaurantScript.new()
	root.add_child(restored)
	restored.restore(after_mistake)
	_check(int(restored.snapshot()["tickets"][0]["customer_id"]) == 1 and int(restored.snapshot()["tickets"][1]["customer_id"]) == 1, "Combo identity must survive save and restore")
	_advance_selected_to_serve(restored)
	var first_stage: Dictionary = restored.interact("serve")
	_check(str(first_stage["event"]) == "dish_buffered" and int(first_stage["earned"]) == 0 and int(first_stage["buffer_slot"]) == 0, "First combo dish should stage in fixed plate slot zero without payment")
	_check(int(restored.snapshot()["served"]) == 0 and int(restored.snapshot()["earned_total"]) == 0, "Staging the first combo dish must not settle it")
	_check(str(restored.buffer_interact(0)["event"]) == "combo_waiting", "Clicking an incomplete combo plate should only report the missing dish")
	var one_staged: Dictionary = restored.snapshot()
	restored.restore(one_staged)
	_check(bool(restored.snapshot()["buffer"][0]["occupied"]) and int(restored.snapshot()["combo_plate"]["staged_count"]) == 1, "First staged combo dish must survive save and restore")
	restored.select_order(1)
	_advance_selected_to_serve(restored)
	var second_stage: Dictionary = restored.interact("serve")
	_check(str(second_stage["event"]) == "dish_buffered" and int(second_stage["earned"]) == 0 and int(second_stage["buffer_slot"]) == 1 and bool(second_stage["combo_ready"]), "Second combo dish should fill fixed plate slot one without payment")
	var both_staged: Dictionary = restored.snapshot()
	restored.restore(both_staged)
	_check(bool(restored.snapshot()["combo_plate"]["ready"]), "Ready combo plate must survive save and restore")
	var second_sale: Dictionary = restored.buffer_interact(1)
	_check(str(second_sale["event"]) == "served_combo" and bool(second_sale.get("customer_complete", false)) and bool(second_sale.get("customer_left", false)) and int(second_sale.get("group_bonus", 0)) == int(RestaurantScript.GROUP_BONUS["calm"]), "One plate click should deliver both dishes and pay the combo once")
	_check((second_sale["recipe_ids"] as Array).size() == 2 and second_sale["buffer_slots"] == [0, 1] and int(second_sale["earned"]) > 0, "Combo settlement should identify both recipes and physical tray slots")
	_check(int(restored.snapshot()["served"]) == 2 and int(restored.snapshot()["customer_served_counts"].get("1", 0)) == 2, "Group settlement count should survive the halfway reload")
	var paid: Dictionary = restored.snapshot()
	var paid_total := int(paid["earned_total"])
	restored.restore(paid)
	_check(int(restored.snapshot()["earned_total"]) == paid_total, "Reloading a completed combo must not settle it again")
	_check(str(restored.buffer_interact(0)["event"]) != "served_combo", "Cleared combo plate cannot be paid twice")
	event_payloads.clear()
	var abandoned = RestaurantScript.new()
	root.add_child(abandoned)
	abandoned.event_happened.connect(_on_capture_event)
	abandoned.start_shift("calm")
	abandoned.tick(89.0)
	var group_departures := 0
	for event in event_payloads:
		if str(event.get("event", "")) == "order_expired" and int(event.get("customer_id", -1)) == 1:
			group_departures += 1
			_check(int(event.get("missed_dishes", 0)) == 2 and bool(event.get("customer_left", false)), "Both unserved dishes should leave together in one customer event")
	_check(group_departures == 1 and int(abandoned.snapshot()["missed"]) == 2 and int(abandoned.snapshot()["earned_total"]) == 0, "Shared timeout should count two missed dishes but one departing customer, without debt")
	event_payloads.clear()
	var partial = RestaurantScript.new()
	root.add_child(partial)
	partial.event_happened.connect(_on_capture_event)
	partial.restore(one_staged)
	var earned_before_expiry := int(partial.snapshot()["earned_total"])
	partial.tick(90.0)
	var partial_departures := 0
	for event in event_payloads:
		if str(event.get("event", "")) == "order_expired" and int(event.get("customer_id", -1)) == 1:
			partial_departures += 1
			_check(int(event.get("missed_dishes", 0)) == 2, "An incomplete plated combo should lose both undelivered dishes")
	_check(partial_departures == 1 and int(partial.snapshot()["earned_total"]) == earned_before_expiry and not bool(partial.snapshot()["buffer"][0]["occupied"]), "Customer leaving with one plated dish must clear the tray without payment")
	var stale_plate = RestaurantScript.new()
	root.add_child(stale_plate)
	stale_plate.restore(both_staged)
	stale_plate.tick(27.0)
	_check(not bool(stale_plate.snapshot()["combo_plate"]["ready"]) and int(stale_plate.snapshot()["earned_total"]) == 0, "Both plated dishes should spoil without premature payout")
	_check(int(stale_plate.snapshot()["tickets"][0]["step_index"]) < (stale_plate.snapshot()["tickets"][0]["steps"] as Array).size() - 1, "Spoiled combo dish should be recoverable from its last cooking step")
	var old_partial: Dictionary = one_staged.duplicate(true)
	old_partial["ticket_save"] = [old_partial["ticket_save"][1]]
	old_partial["buffer_save"] = [{}, {}, {}]
	old_partial["served"] = 1
	old_partial["earned_total"] = 100
	old_partial["customer_served_counts"] = {"1": 1}
	old_partial["combo_plate_version"] = 0
	var legacy = RestaurantScript.new()
	root.add_child(legacy)
	legacy.restore(old_partial)
	_check(int(legacy.snapshot()["earned_total"]) == 100 and int(legacy.snapshot()["served"]) == 1, "Old halfway-paid combo must retain its cash and served count")
	_finish_selected_ticket(legacy, 0.0)
	_check(int(legacy.snapshot()["served"]) == 2 and int(legacy.snapshot()["earned_total"]) > 100, "Old halfway-paid combo should finish without requiring the absent first plate")
	var old_position: Dictionary = one_staged.duplicate(true)
	old_position["ticket_save"][0]["buffer_slot"] = 2
	old_position["buffer_save"][2] = old_position["buffer_save"][0]
	old_position["buffer_save"][0] = {}
	var remapped = RestaurantScript.new()
	root.add_child(remapped)
	remapped.restore(old_position)
	_check(bool(remapped.snapshot()["buffer"][0]["occupied"]) and not bool(remapped.snapshot()["buffer"][2]["occupied"]), "Older arbitrary combo tray placement should migrate to fixed plate slot zero")


func _check_stock_and_restore() -> void:
	var restaurant = RestaurantScript.new()
	root.add_child(restaurant)
	restaurant.event_happened.connect(_on_settlement_event)
	var chosen: Dictionary = restaurant.prepare_stock("rice_batter")
	_check(bool(chosen["ok"]), "Rice batter must be selectable before a shift")
	_check(str(restaurant.snapshot()["current_step"]) == "wash", "Stock job must expose wash as first mouse action")
	restaurant.interact("wash")
	restaurant.interact("mix")
	var stock: Array = restaurant.snapshot()["stock"]
	_check(int(stock[0]["count"]) == 3, "Three stock units should be produced by two manual operations")
	_check(int(restaurant.snapshot()["earned_total"]) == 0 and settlement_events == 0, "Stock preparation cannot mint income")
	_check(restaurant.start_shift("calm"), "Calm shift should start")
	_check((restaurant.snapshot()["tickets"] as Array).size() == 2, "Two customer tickets should be live in parallel")
	var used: Dictionary = restaurant.prepare_stock("rice_batter")
	_check(str(used["event"]) == "stock_used", "Matching stock should skip a ticket's first two steps")
	_check(int(restaurant.snapshot()["tickets"][0]["step_index"]) == 2, "Stock did not advance the ticket two steps")
	_check(int(restaurant.snapshot()["stock"][0]["count"]) == 2, "Taking stock must consume exactly one unit")
	var before_save: Dictionary = restaurant.snapshot()
	var loaded = RestaurantScript.new()
	root.add_child(loaded)
	loaded.event_happened.connect(_on_settlement_event)
	loaded.restore(before_save)
	_check(int(loaded.snapshot()["stock"][0]["count"]) == 2, "Stock count was not restored")
	_check(int(loaded.snapshot()["tickets"][0]["step_index"]) == 2, "Ticket step was not restored")
	_check(settlement_events == 0, "Loading an unpaid ticket emitted an income event")
	_finish_selected_ticket(loaded, 0.0)
	_check(int(loaded.snapshot()["served"]) == 2 and settlement_events == 1, "Restored combo should settle both dishes once")
	var paid_snapshot: Dictionary = loaded.snapshot()
	var money := int(paid_snapshot["earned_total"])
	loaded.restore(paid_snapshot)
	_check(int(loaded.snapshot()["earned_total"]) == money and settlement_events == 1, "Restore repeated a settled payout")
	loaded.tick(0.1)
	_check(settlement_events == 1, "Tick after restore repeated a settled payout")
	var capacity_test = RestaurantScript.new()
	root.add_child(capacity_test)
	for i in range(2):
		_stage_raw_key(capacity_test, "spice_oil")
		capacity_test.prepare_stock("spice_oil")
		capacity_test.interact("slice")
		capacity_test.interact("mix")
	_check(int(capacity_test.snapshot()["stock"][1]["count"]) == 6, "Two batches should fit in shared stock capacity")
	_check(str(capacity_test.prepare_stock("spice_oil")["event"]) == "stock_full", "Third batch must respect shared stock capacity")
	capacity_test.tick(100.0)
	_check(int(capacity_test.snapshot()["stock"][1]["count"]) == 0, "Stock must spoil after its freshness timer")
	var freshness_test = RestaurantScript.new()
	root.add_child(freshness_test)
	freshness_test.state_changed.connect(_on_stock_state_update)
	freshness_test.prepare_stock("rice_batter")
	freshness_test.interact("wash")
	freshness_test.interact("mix")
	var updates_before_tick := stock_state_updates
	freshness_test.tick(1.1)
	_check(stock_state_updates > updates_before_tick, "Shelf freshness must refresh while no shift is active")
	_stage_raw_key(freshness_test, "rice_flour")
	freshness_test.prepare_stock("rice_batter")
	freshness_test.interact("wash")
	freshness_test.interact("mix")
	var shown_stock: Dictionary = freshness_test.snapshot()["stock"][0]
	_check(int(shown_stock["count"]) == 6 and (shown_stock["units"] as Array).size() == 6, "Each stored unit needs its own shelf state")
	_check(float(shown_stock["fresh_left"]) < float(shown_stock["fresh_total"]), "Shelf summary must show the oldest unit, not the newest batch")


func _check_heat_switch_and_recovery() -> void:
	var restaurant = RestaurantScript.new()
	root.add_child(restaurant)
	restaurant.start_shift("calm")
	var wrong: Dictionary = restaurant.interact("serve")
	_check(str(wrong["event"]) == "wrong_action" and int(wrong["earned"]) == 0, "Mistake should be recoverable without debt")
	var first_step := str(restaurant.snapshot()["current_step"])
	_check(bool(restaurant.interact(first_step)["ok"]), "Correct action should work after a mistake")
	while true:
		var state: Dictionary = restaurant.snapshot()
		if float(state["heat_left"]) > 0.0:
			break
		var action := str(state["current_step"])
		_check(action != "serve", "First ticket should have a heating operation")
		restaurant.interact(action)
	var waiting: Dictionary = restaurant.snapshot()
	_check(bool(waiting["tickets"][0]["waiting"]), "Heat action should enter real-time wait")
	_check(str(restaurant.interact("garnish")["event"]) == "still_heating", "Heating cannot be skipped by clicking ahead")
	var switched: Dictionary = restaurant.select_order(1)
	_check(bool(switched["ok"]) and int(restaurant.snapshot()["selected_slot"]) == 1, "Player should switch to other live ticket")
	var second_step := str(restaurant.snapshot()["current_step"])
	_check(bool(restaurant.interact(second_step)["ok"]), "Other ticket should progress during heating")
	restaurant.tick(float(waiting["heat_left"]) + 0.1)
	restaurant.select_order(0)
	_check(not bool(restaurant.snapshot()["tickets"][0]["waiting"]), "Heating should finish while another ticket is selected")
	_check(str(restaurant.snapshot()["current_step"]) != "steam", "Finished heating should advance the recipe")
	restaurant.tick(90.0)
	_check(int(restaurant.snapshot()["earned_total"]) >= 0, "Expired orders must not create negative debt")


func _check_rush_wave_and_overcook() -> void:
	event_log.clear()
	var rush = RestaurantScript.new()
	root.add_child(rush)
	rush.event_happened.connect(_on_event_log)
	rush.start_shift("rush")
	_check((rush.snapshot()["tickets"] as Array).size() == 2, "Rush should open with two visible customers")
	var wave_at := float(rush.snapshot()["rush_wave_at"])
	rush.tick(wave_at - 0.1)
	_check((rush.snapshot()["tickets"] as Array).size() == 2 and float(rush.snapshot()["rush_wave_in"]) > 0.0, "Third customer must have a visible warning countdown")
	rush.tick(0.2)
	var waved: Dictionary = rush.snapshot()
	_check((waved["tickets"] as Array).size() == 3 and bool(waved["rush_wave_triggered"]), "Rush wave should add a third customer at the announced time")
	_check(bool(waved["tickets"][2]["urgent"]) and float(waved["tickets"][2]["patience_total"]) < float(waved["tickets"][0]["patience_total"]), "Wave arrival should carry a visible tighter deadline")
	_check(event_log.count("rush_wave") == 1, "Rush wave should emit exactly one arrival event")
	var waved_restore = RestaurantScript.new()
	root.add_child(waved_restore)
	waved_restore.event_happened.connect(_on_event_log)
	waved_restore.restore(waved)
	waved_restore.tick(1.0)
	_check((waved_restore.snapshot()["tickets"] as Array).size() <= 3 and event_log.count("rush_wave") == 1, "Restoring after rush wave must not duplicate arrivals")
	waved_restore.select_order(2)
	while str(waved_restore.snapshot()["current_step"]) != "serve":
		var urgent_state: Dictionary = waved_restore.snapshot()
		if float(urgent_state["heat_left"]) > 0.0:
			waved_restore.tick(float(urgent_state["heat_left"]) + 0.01)
		else:
			waved_restore.interact(str(urgent_state["current_step"]))
	var urgent_sale: Dictionary = waved_restore.interact("serve")
	_check(bool(urgent_sale.get("urgent", false)) and int(urgent_sale.get("urgent_bonus", 0)) > 0 and int(urgent_sale["earned"]) > 0, "Urgent wave ticket should pay a visible premium if fulfilled")
	var old_v2: Dictionary = waved.duplicate(true)
	for key in ["rush_wave_at", "rush_wave_variant", "rush_wave_patience", "rush_wave_bonus"]:
		old_v2.erase(key)
	for raw_ticket in old_v2["ticket_save"]:
		raw_ticket.erase("patience_total")
		raw_ticket.erase("urgent")
	var compatible = RestaurantScript.new()
	root.add_child(compatible)
	compatible.restore(old_v2)
	_check(bool(compatible.snapshot()["active"]) and (compatible.snapshot()["tickets"] as Array).size() == 3, "Prior v2 saves should load without losing active tickets")
	event_log.clear()
	var kitchen = RestaurantScript.new()
	root.add_child(kitchen)
	kitchen.event_happened.connect(_on_event_log)
	kitchen.start_shift("rush")
	while not RestaurantScript.HEAT_ACTIONS.has(str(kitchen.snapshot()["current_step"])):
		kitchen.interact(str(kitchen.snapshot()["current_step"]))
	var heat_action := str(kitchen.snapshot()["current_step"])
	kitchen.interact(heat_action)
	kitchen.tick(float(kitchen.snapshot()["heat_left"]) + 0.01)
	var ready: Dictionary = kitchen.snapshot()
	_check(event_log.has("heat_ready") and float(ready["pickup_left"]) > 0.0 and float(ready["pickup_left"]) <= 8.0, "Heating should start an eight-second visible pickup window")
	var resumed = RestaurantScript.new()
	root.add_child(resumed)
	resumed.event_happened.connect(_on_event_log)
	resumed.event_happened.connect(_on_settlement_event)
	resumed.restore(ready)
	var before_income := int(resumed.snapshot()["earned_total"])
	var before_settlements := settlement_events
	resumed.tick(float(resumed.snapshot()["pickup_left"]) + 0.1)
	var burned: Dictionary = resumed.snapshot()
	_check(event_log.count("overcooked") == 1, "Pickup timeout should emit one overcooked event")
	_check(str(burned["current_step"]) == heat_action and float(burned["pickup_left"]) == 0.0, "Burned food should reset only the heating step")
	_check(int(burned["combo"]) == 0 and int(burned["mistakes"]) == 1 and int(burned["earned_total"]) == before_income, "Burn should break combo and cost time, never money")
	resumed.restore(burned)
	resumed.tick(0.1)
	_check(event_log.count("overcooked") == 1, "Restoring burned food should not emit a second burn")
	_finish_selected_ticket(resumed, 0.0)
	_check(int(resumed.snapshot()["served"]) == 2 and settlement_events == before_settlements + 1, "Reworked combo should remain payable exactly once")


func _check_service_clock_and_continuous_shifts() -> void:
	_check(RestaurantScript.energy_cost_for("calm") == 0 and RestaurantScript.energy_cost_for("rush") == 0, "Work must not require or consume energy")
	var restaurant = RestaurantScript.new()
	root.add_child(restaurant)
	_check(is_equal_approx(float(restaurant.snapshot()["clock_minutes"]), 480.0) and str(restaurant.snapshot()["service_period"]) == "morning", "Shop should open at 08:00 in morning period")
	restaurant.tick(180.0)
	_check(str(restaurant.snapshot()["service_period"]) == "lunch" and is_equal_approx(float(restaurant.snapshot()["day_minutes"]), 660.0), "11:00 should enter lunch period")
	restaurant.tick(360.0)
	_check(str(restaurant.snapshot()["service_period"]) == "evening" and is_equal_approx(float(restaurant.snapshot()["clock_minutes"]), 1020.0), "17:00 should enter evening period")
	restaurant.tick(300.0)
	_check(int(restaurant.snapshot()["service_day"]) == 2 and str(restaurant.snapshot()["service_period"]) == "morning", "22:00 should roll to the next morning")
	restaurant.align_day(5)
	_check(int(restaurant.snapshot()["service_day"]) == 5, "Restaurant day should align upward with an older outer save")
	restaurant.align_day(3)
	_check(int(restaurant.snapshot()["service_day"]) == 5, "Day alignment must never rewind time")
	_check(restaurant.advance_to_next_day() and int(restaurant.snapshot()["service_day"]) == 6, "Bench rest should advance service day")
	for i in range(3):
		_check(restaurant.start_shift("calm"), "Player should be able to start consecutive shifts")
		_check(int(restaurant.snapshot()["energy_cost"]) == 0, "A repeated shift must stay free of energy gating")
		restaurant.cancel_shift()
	var period_income: Array[int] = []
	var period_second_orders: Array[String] = []
	for setting in [{"minute": 480.0, "period": "morning"}, {"minute": 660.0, "period": "lunch"}, {"minute": 1020.0, "period": "evening"}]:
		var kitchen = RestaurantScript.new()
		root.add_child(kitchen)
		var idle: Dictionary = kitchen.snapshot()
		idle["clock_minutes"] = float(setting["minute"])
		kitchen.restore(idle)
		kitchen.start_shift("calm")
		_check(str(kitchen.snapshot()["shift_period"]) == str(setting["period"]), "Shift should lock its opening service period")
		period_second_orders.append(str(kitchen.snapshot()["tickets"][1]["recipe"]["id"]))
		period_income.append(_finish_selected_ticket(kitchen, 0.0))
	_check(period_income[0] < period_income[1] and period_income[1] < period_income[2], "Identical meals should pay more through morning, lunch and evening demand")
	_check(period_second_orders[0] != period_second_orders[1] and period_second_orders[1] != period_second_orders[2] and period_second_orders[0] != period_second_orders[2], "Breakfast, lunch and evening guests should request visibly different second dishes")


func _check_stock_supplies_and_buffers() -> void:
	event_log.clear()
	var pantry = RestaurantScript.new()
	root.add_child(pantry)
	pantry.event_happened.connect(_on_event_log)
	for batch in range(6):
		if batch > 0:
			pantry.tick(93.0)
		_stage_raw_key(pantry, "rice_flour")
		_check(bool(pantry.prepare_stock("rice_batter")["ok"]), "Rice batch should start while raw supplies remain")
		pantry.interact("wash")
		pantry.interact("mix")
		_check(int(pantry.snapshot()["pantry"]["rice_mix"]) == 5 - batch, "Manual stock batch must consume one rice supply kit")
	pantry.tick(93.0)
	_check(str(pantry.prepare_stock("rice_batter")["event"]) == "stock_supplies_empty", "Stock should stop at zero raw supply without blocking normal orders")
	_check(event_log.count("stock_spoiled") >= 1 and int(pantry.snapshot()["stock"][0]["count"]) == 0, "Unconsumed semi-finished stock should spoil and emit feedback")
	_check(pantry.start_shift("calm") and int(pantry.snapshot()["pantry"]["rice_mix"]) == 3, "Next shift should restock limited raw supply")
	_stage_raw_key(pantry, "rice_flour")
	pantry.prepare_stock("rice_batter")
	pantry.interact("wash")
	pantry.interact("mix")
	_check(int(pantry.snapshot()["stock"][0]["count"]) == 3 and int(pantry.snapshot()["pantry"]["rice_mix"]) == 2, "Semi-finished batch should yield three perishable units from one supply kit")
	pantry.prepare_stock("rice_batter")
	_check(int(pantry.snapshot()["stock"][0]["count"]) == 2 and int(pantry.snapshot()["tickets"][0]["step_index"]) == 2, "Using stock should consume exactly one unit and skip two operations")
	var kitchen = RestaurantScript.new()
	root.add_child(kitchen)
	kitchen.start_shift("calm")
	_advance_selected_to_serve(kitchen)
	_check(str(kitchen.buffer_interact(0)["event"]) == "dish_buffered", "First finished dish should enter tray zero")
	kitchen.select_order(1)
	_advance_selected_to_serve(kitchen)
	_check(str(kitchen.buffer_interact(1)["event"]) == "dish_buffered", "Second finished dish should enter a separate tray")
	var two_dishes: Dictionary = kitchen.snapshot()
	_check(bool(two_dishes["buffer"][0]["occupied"]) and bool(two_dishes["buffer"][1]["occupied"]), "Two dishes must coexist in finished buffers")
	var loaded = RestaurantScript.new()
	root.add_child(loaded)
	loaded.event_happened.connect(_on_settlement_event)
	loaded.restore(two_dishes)
	_check(bool(loaded.snapshot()["buffer"][0]["occupied"]) and bool(loaded.snapshot()["buffer"][1]["occupied"]), "Both buffered dishes must survive restore")
	var before_settlements := settlement_events
	var first_sale: Dictionary = loaded.buffer_interact(0)
	_check(str(first_sale["event"]) == "served_combo" and bool(first_sale["from_buffer"]) and int(first_sale["buffer_bonus"]) > 0, "Serving a complete fresh combo plate should settle both dishes with a bounded presentation bonus")
	var paid: Dictionary = loaded.snapshot()
	loaded.restore(paid)
	_check(settlement_events == before_settlements + 1 and not bool(loaded.snapshot()["buffer"][0]["occupied"]), "Reloading paid tray must not mint another payout")
	var second_sale: Dictionary = loaded.buffer_interact(1)
	_check(str(second_sale["event"]) != "served_combo" and settlement_events == before_settlements + 1, "Second plate cell cannot pay again after one combined delivery")
	var direct = RestaurantScript.new()
	root.add_child(direct)
	direct.start_shift("calm")
	_advance_selected_to_serve(direct)
	direct.buffer_interact(0)
	direct.select_order(1)
	_advance_selected_to_serve(direct)
	var second_staged: Dictionary = direct.interact("serve")
	_check(str(second_staged["event"]) == "dish_buffered" and int(second_staged["buffer_slot"]) == 1, "Bell should stage the second combo dish in the matching cell")
	var direct_sale: Dictionary = direct.interact("serve")
	_check(str(direct_sale["event"]) == "served_combo" and bool(direct_sale.get("from_buffer", false)) and not bool(direct.snapshot()["buffer"][0]["occupied"]), "Bell should deliver both ready dishes and clear the combo plate")
	_check(str(direct.buffer_interact(0)["event"]) != "served_combo", "Cleared tray cannot pay twice")
	var rush_trays = RestaurantScript.new()
	root.add_child(rush_trays)
	rush_trays.start_shift("rush")
	rush_trays.tick(float(rush_trays.snapshot()["rush_wave_at"]) + 0.01)
	for slot in [2, 0, 1]:
		rush_trays.select_order(slot)
		_advance_selected_to_serve(rush_trays)
		if slot == 2:
			_check(str(rush_trays.buffer_interact(0)["event"]) == "combo_slot_reserved", "Solo rush guest must not occupy a reserved combo cell")
		_check(str(rush_trays.buffer_interact(slot)["event"]) == "dish_buffered", "Rush kitchen should fill finished tray " + str(slot))
	_check(bool(rush_trays.snapshot()["buffer"][0]["occupied"]) and bool(rush_trays.snapshot()["buffer"][1]["occupied"]) and bool(rush_trays.snapshot()["buffer"][2]["occupied"]), "All three finished tray slots should coexist")
	event_log.clear()
	var stale = RestaurantScript.new()
	root.add_child(stale)
	stale.event_happened.connect(_on_event_log)
	stale.start_shift("calm")
	_advance_selected_to_serve(stale)
	stale.buffer_interact(0)
	stale.tick(27.0)
	_check(event_log.count("buffer_spoiled") == 1 and not bool(stale.snapshot()["buffer"][0]["occupied"]), "Finished dish must leave tray when freshness expires")
	_check(int(stale.snapshot()["earned_total"]) == 0 and str(stale.snapshot()["current_step"]) != "serve", "Spoiled tray should reset one operation without debt or deadlock")
	_finish_selected_ticket(stale, 0.0)
	_check(int(stale.snapshot()["served"]) == 2, "Player should recover and deliver the combo after a spoiled tray")


func _check_economy() -> void:
	for seed in range(3):
		var calm: Dictionary = _run_perfect_shift("calm", seed)
		var rush: Dictionary = _run_perfect_shift("rush", seed)
		print("ECONOMY round=%d calm=%d in %.2fs, rush=%d in %.2fs" % [seed, int(calm["earned_total"]), float(calm["elapsed"]), int(rush["earned_total"]), float(rush["elapsed"])])
		_check(int(rush["rush_wave_variant"]) == seed and is_equal_approx(float(rush["rush_wave_at"]), float(RestaurantScript.RUSH_WAVES[seed]["at"])) and bool(rush["rush_wave_triggered"]), "Rush wave schedule should rotate predictably with the saved round")
		_check(int(calm["served"]) == int(RestaurantScript.MODES["calm"]["orders"]) and int(rush["served"]) == int(RestaurantScript.MODES["rush"]["orders"]) and int(rush["missed"]) == 0, "Perfect shifts should complete all orders for round " + str(seed))
		_check(int(rush["earned_total"]) > int(calm["earned_total"]), "Rush total payout should beat calm without energy gating for round " + str(seed))
		_check(float(rush["earned_total"]) / float(rush["elapsed"]) > float(calm["earned_total"]) / float(calm["elapsed"]), "Rush income per minute should beat calm for round " + str(seed))
	var quick = RestaurantScript.new()
	root.add_child(quick)
	quick.start_shift("calm")
	var slow = RestaurantScript.new()
	root.add_child(slow)
	slow.start_shift("calm")
	var fast_pay := _finish_selected_ticket(quick, 0.0)
	var slow_pay := _finish_selected_ticket(slow, 1.2)
	_check(fast_pay >= slow_pay, "Faster correct service should not earn less")
	var template = RestaurantScript.new()
	root.add_child(template)
	template.start_shift("calm")
	_advance_selected_to_serve(template)
	template.interact("serve")
	template.select_order(1)
	_advance_selected_to_serve(template)
	template.interact("serve")
	var low_state: Dictionary = template.snapshot()
	low_state["combo"] = 0
	low_state["combo_left"] = 0.0
	var high_state: Dictionary = template.snapshot()
	high_state["combo"] = 8
	high_state["combo_left"] = 4.0
	var low = RestaurantScript.new()
	root.add_child(low)
	low.restore(low_state)
	var high = RestaurantScript.new()
	root.add_child(high)
	high.restore(high_state)
	var low_result: Dictionary = low.buffer_interact(0)
	var high_result: Dictionary = high.buffer_interact(0)
	_check(int(high_result["earned"]) > int(low_result["earned"]), "Higher correct-action combo should increase pay at equal patience")


func _check_legacy_migration() -> void:
	var old_save := {"version": 1, "active": true, "mode": "calm", "stage": "heating",
		"queue": [0, 1, 2], "order_index": 2, "time_left": 14.0, "heat_left": 1.0,
		"mistakes": 1, "served": 2, "missed": 0, "earned_total": 100, "shift_serial": 3}
	var restaurant = RestaurantScript.new()
	root.add_child(restaurant)
	var before := settlement_events
	restaurant.event_happened.connect(_on_settlement_event)
	restaurant.restore(old_save)
	var migrated: Dictionary = restaurant.snapshot()
	_check(not bool(migrated["active"]) and str(migrated["migration"]) == "legacy_shift_closed", "Old in-progress shift should close safely")
	_check(int(migrated["served"]) == 2 and int(migrated["earned_total"]) == 100, "Old settled order count and income should survive migration")
	_check(settlement_events == before, "Legacy migration emitted a duplicate payout")
	_check(restaurant.start_shift("calm"), "Player should be able to begin a new shift after migration")
	for old_mode in ["calm", "rush"]:
		var earlier = RestaurantScript.new()
		root.add_child(earlier)
		earlier.start_shift(old_mode)
		var old_version_two: Dictionary = earlier.snapshot()
		old_version_two["queue"] = (old_version_two["queue"] as Array).slice(0, 4 if old_mode == "calm" else 7)
		var resumed = RestaurantScript.new()
		root.add_child(resumed)
		resumed.restore(old_version_two)
		_check(bool(resumed.snapshot()["active"]) and (resumed.snapshot()["queue"] as Array).size() == (4 if old_mode == "calm" else 7), "Existing shorter version-2 shift must resume without changing its order count: " + old_mode)


func _run_perfect_shift(mode: String, seed: int = 0) -> Dictionary:
	var restaurant = RestaurantScript.new()
	root.add_child(restaurant)
	if seed > 0:
		var idle: Dictionary = restaurant.snapshot()
		idle["shift_serial"] = seed
		restaurant.restore(idle)
	restaurant.start_shift(mode)
	var elapsed := 0.0
	var guard := 0
	while bool(restaurant.snapshot()["active"]) and guard < 200:
		guard += 1
		elapsed += _drive_customer_progress(restaurant, 0.35)
	_check(guard < 200, "Perfect shift failed to finish: " + mode)
	var result: Dictionary = restaurant.snapshot()
	result["elapsed"] = elapsed
	return result


func _check_raw_ingredient_storage() -> void:
	var direct = RestaurantScript.new()
	root.add_child(direct)
	direct.start_shift("calm")
	var direct_before := direct.snapshot()
	var direct_stage: Dictionary = direct.stage_raw_ingredient("rice_flour")
	var direct_after := direct.snapshot()
	_check(str(direct_stage["event"]) == "raw_staged" and int(direct_after["prep_ingredients"]["rice_flour"]) == RestaurantScript.PREP_BATCH_TARGET and (direct_after["carried_ingredients"] as Dictionary).is_empty(), "One physical ingredient click must fill its own preparation well directly")
	_check(int(direct_after["prep_ingredients"]["soft_bun"]) == int(direct_before["prep_ingredients"]["soft_bun"]), "Direct staging must leave neighboring ingredient quantities unchanged")
	var direct_empty := direct.snapshot()
	(direct_empty["raw_ingredients"] as Dictionary)["rice_flour"] = 0
	(direct_empty["prep_ingredients"] as Dictionary)["rice_flour"] = 0
	direct.restore(direct_empty)
	_check(str(direct.stage_raw_ingredient("rice_flour")["event"]) == "raw_staged" and int(direct.snapshot()["prep_ingredients"]["rice_flour"]) == RestaurantScript.PREP_BATCH_TARGET, "One click must fetch and stage an exhausted ingredient without a second input")
	var old_stock := direct.snapshot()
	(old_stock["prep_ingredients"] as Dictionary)["rice_flour"] = 12
	direct.restore(old_stock)
	_check(int(direct.snapshot()["prep_ingredients"]["rice_flour"]) == 12, "A smaller new batch size must not discard prepared food in an existing save")
	direct.free()
	var restaurant = RestaurantScript.new()
	root.add_child(restaurant)
	restaurant.start_shift("calm")
	var emptied: Dictionary = restaurant.snapshot()
	(emptied["raw_ingredients"] as Dictionary)["rice_flour"] = 0
	(emptied["prep_ingredients"] as Dictionary)["rice_flour"] = 0
	restaurant.restore(emptied)
	var refused: Dictionary = restaurant.interact("wash")
	_check(str(refused["event"]) == "ingredient_shortage" and int(restaurant.snapshot()["tickets"][0]["step_index"]) == 0, "A recipe must wait for its missing prepared ingredient")
	var fetched: Dictionary = restaurant.take_raw_group("staples")
	_check(str(fetched["event"]) == "raw_picked" and int(restaurant.snapshot()["prep_ingredients"]["rice_flour"]) == 0 and int(restaurant.snapshot()["carried_ingredients"]["rice_flour"]) == RestaurantScript.PREP_BATCH_TARGET and int(restaurant.snapshot()["carried_ingredients"]["soft_bun"]) == RestaurantScript.PREP_BATCH_TARGET - 1, "One warehouse click should carry all five staple ingredients for different recipes")
	var placed: Dictionary = restaurant.place_carried_ingredients()
	_check(str(placed["event"]) == "raw_placed" and int(restaurant.snapshot()["prep_ingredients"]["rice_flour"]) == RestaurantScript.PREP_BATCH_TARGET, "Ingredients must be placed on preparation table before cooking")
	var prepared: Dictionary = restaurant.interact("wash")
	_check(bool(prepared["ok"]) and bool(restaurant.snapshot()["tickets"][0]["ingredients_reserved"]) and int(restaurant.snapshot()["prep_ingredients"]["rice_flour"]) == RestaurantScript.PREP_BATCH_TARGET - 1, "First valid station action should reserve only one prepared portion")
	var saved: Dictionary = restaurant.snapshot()
	var restored = RestaurantScript.new()
	root.add_child(restored)
	restored.restore(saved)
	_check(int(restored.snapshot()["prep_ingredients"]["rice_flour"]) == RestaurantScript.PREP_BATCH_TARGET - 1 and bool(restored.snapshot()["tickets"][0]["ingredients_reserved"]), "Prepared batch and recipe reservation must survive save restore")
	var bulk = RestaurantScript.new()
	root.add_child(bulk)
	bulk.start_shift("calm")
	var bulk_setup: Dictionary = bulk.snapshot()
	for ingredient_key in ["rice_flour", "leafy_greens", "soy_sauce"]:
		(bulk_setup["prep_ingredients"] as Dictionary)[ingredient_key] = 0
		(bulk_setup["raw_ingredients"] as Dictionary)[ingredient_key] = 0
	(bulk_setup["ticket_save"] as Array)[0]["recipe_index"] = 0
	bulk.restore(bulk_setup)
	for group_id in ["staples", "fresh", "protein", "pantry"]:
		_check(str(bulk.take_raw_group(group_id)["event"]) == "raw_picked", "One crate pickup should stage a recipe ingredient batch")
		_check(str(bulk.place_carried_ingredients()["event"]) == "raw_placed", "Each ingredient batch should be put into the preparation bowls")
	for ingredient_key in ["rice_flour", "soft_bun", "leafy_greens", "fruit", "egg", "chicken", "soy_sauce", "ice"]:
		_check(int(bulk.snapshot()["prep_ingredients"][ingredient_key]) == RestaurantScript.PREP_BATCH_TARGET, "A single category pickup should prepare ingredients for several different dishes")
	for meal in range(RestaurantScript.PREP_BATCH_TARGET):
		var next_order: Dictionary = bulk.snapshot()
		(next_order["ticket_save"] as Array)[0]["recipe_index"] = 0
		(next_order["ticket_save"] as Array)[0]["step_index"] = 0
		(next_order["ticket_save"] as Array)[0]["ingredients_reserved"] = false
		bulk.restore(next_order)
		_check(bool(bulk.interact("wash")["ok"]), "One prepared batch should support twelve full ingredient reservations")
		for ingredient_key in ["rice_flour", "leafy_greens", "soy_sauce"]:
			_check(int(bulk.snapshot()["prep_ingredients"][ingredient_key]) == RestaurantScript.PREP_BATCH_TARGET - meal - 1, "Each meal should use exactly one portion per ingredient")
	var exhausted: Dictionary = bulk.snapshot()
	(exhausted["ticket_save"] as Array)[0]["recipe_index"] = 0
	(exhausted["ticket_save"] as Array)[0]["step_index"] = 0
	(exhausted["ticket_save"] as Array)[0]["ingredients_reserved"] = false
	bulk.restore(exhausted)
	_check(str(bulk.interact("wash")["event"]) == "ingredient_shortage", "The thirteenth meal should request another preparation batch")
	_check(int(bulk.snapshot()["prep_ingredients"]["soft_bun"]) == RestaurantScript.PREP_BATCH_TARGET, "Staging one recipe must also leave other dishes ready without another warehouse trip")
	var second_recipe: Dictionary = bulk.snapshot()
	(second_recipe["ticket_save"] as Array)[0]["recipe_index"] = 2
	(second_recipe["ticket_save"] as Array)[0]["step_index"] = 0
	(second_recipe["ticket_save"] as Array)[0]["ingredients_reserved"] = false
	bulk.restore(second_recipe)
	_check(bool(bulk.interact("slice")["ok"]) and int(bulk.snapshot()["prep_ingredients"]["soft_bun"]) == RestaurantScript.PREP_BATCH_TARGET - 1 and int(bulk.snapshot()["prep_ingredients"]["egg"]) == RestaurantScript.PREP_BATCH_TARGET - 1, "A different dish should start from the same group pickups without extra preparation")
	var batching = RestaurantScript.new()
	root.add_child(batching)
	var supply_state: Dictionary = batching.snapshot()
	(supply_state["prep_ingredients"] as Dictionary)["rice_flour"] = 1
	batching.restore(supply_state)
	batching.prepare_stock("rice_batter")
	batching.interact("wash")
	_check(str(batching.interact("mix")["event"]) == "stock_prepared" and int(batching.snapshot()["prep_ingredients"]["rice_flour"]) == 0, "Rice batter batch should consume one staged flour portion")
	batching.start_shift("calm")
	_check(int(batching.snapshot()["tickets"][0]["stock_substitute_count"]) == 3, "Meal ticket should recognize three prepared portions as an available flour substitute")
	var use_prepared: Dictionary = batching.prepare_stock("rice_batter")
	_check(str(use_prepared["event"]) == "stock_used" and int(batching.snapshot()["prep_ingredients"]["rice_flour"]) == 0, "Prepared batter should replace flour without charging it a second time")
	_check(bool(batching.snapshot()["tickets"][0]["ingredients_reserved"]) and int(batching.snapshot()["tickets"][0]["step_index"]) == 2, "Prepared batter should reserve other ingredients and skip both prep steps")
	var spice = RestaurantScript.new()
	root.add_child(spice)
	var spice_state: Dictionary = spice.snapshot()
	(spice_state["prep_ingredients"] as Dictionary)["spice_oil"] = 1
	spice.restore(spice_state)
	spice.prepare_stock("spice_oil")
	spice.interact("slice")
	_check(str(spice.interact("mix")["event"]) == "stock_prepared" and int(spice.snapshot()["prep_ingredients"]["spice_oil"]) == 0, "Spice batch should consume one staged spice portion")
	spice.start_shift("calm")
	var spice_ticket: Dictionary = spice.snapshot()
	(spice_ticket["ticket_save"] as Array)[0]["recipe_index"] = 1
	spice.restore(spice_ticket)
	_check(str(spice.prepare_stock("spice_oil")["event"]) == "stock_used" and int(spice.snapshot()["prep_ingredients"]["spice_oil"]) == 0, "Prepared spice oil should replace the dish's spice portion")
	var full = RestaurantScript.new()
	root.add_child(full)
	var crowded: Dictionary = full.snapshot()
	var crowded_prep: Dictionary = crowded["prep_ingredients"]
	var room := RestaurantScript.PREP_CAPACITY - int(crowded["prep_used"])
	for ingredient_key in crowded_prep.keys():
		if str(ingredient_key) == "leafy_greens":
			continue
		var added: int = mini(room, RestaurantScript.PREP_PER_KIND - int(crowded_prep[ingredient_key]))
		crowded_prep[ingredient_key] = int(crowded_prep[ingredient_key]) + added
		room -= added
		if room <= 0:
			break
	full.restore(crowded)
	_check(int(full.snapshot()["prep_used"]) == RestaurantScript.PREP_CAPACITY, "Preparation table fixture should be full")
	_check(str(full.take_raw_group("fresh")["event"]) == "prep_full", "A full preparation table must block further pickup")
	_check(str(full.place_carried_ingredients()["event"]) == "prep_cleared" and int(full.snapshot()["prep_used"]) <= RestaurantScript.PREP_CAPACITY - 4, "Player must be able to return surplus and unblock a full table")
	_check(str(full.take_raw_group("fresh")["event"]) == "raw_picked", "Pickup should resume after clearing table space")
	var carrying: Dictionary = full.snapshot()
	var carried_load = RestaurantScript.new()
	root.add_child(carried_load)
	carried_load.restore(carrying)
	_check(str(carried_load.place_carried_ingredients()["event"]) == "raw_placed" and int(carried_load.snapshot()["prep_used"]) <= RestaurantScript.PREP_CAPACITY, "Carried ingredients must survive restore and respect capacity")


func _check_endless_closing() -> void:
	var old_service = RestaurantScript.new()
	root.add_child(old_service)
	old_service.start_shift("calm")
	old_service.tick(2.0)
	var old_snapshot: Dictionary = old_service.snapshot()
	var upgraded = RestaurantScript.new()
	root.add_child(upgraded)
	upgraded.restore(old_snapshot)
	upgraded.make_endless()
	_check(bool(upgraded.snapshot()["active"]) and bool(upgraded.snapshot()["endless"]) and (upgraded.snapshot()["queue"] as Array).size() == 10 and int(upgraded.snapshot()["next_order_index"]) == int(old_snapshot["next_order_index"]), "Existing finite kitchen save should become endless without discarding active orders")
	var endless = RestaurantScript.new()
	root.add_child(endless)
	_check(endless.start_shift("calm", true), "Endless service should start without a bell gate")
	for passage in range(6):
		endless.tick(89.0)
	var running: Dictionary = endless.snapshot()
	_check(bool(running["active"]) and bool(running["endless"]) and int(running["next_order_index"]) > 6 and (running["queue"] as Array).size() == 10, "Kitchen must continue replenishing orders beyond old six-order shift without growing its menu queue")
	endless.set_service_mode("rush")
	var wave_at: float = float(endless.snapshot()["rush_wave_at"])
	var saved: Dictionary = endless.snapshot()
	var resumed = RestaurantScript.new()
	root.add_child(resumed)
	resumed.restore(saved)
	_check(bool(resumed.snapshot()["active"]) and int(resumed.snapshot()["next_order_index"]) == int(saved["next_order_index"]) and is_equal_approx(float(resumed.snapshot()["rush_wave_at"]), wave_at), "Endless order sequence and future rush timing must survive restore")
	var previous_day := int(resumed.snapshot()["service_day"])
	resumed.tick(RestaurantScript.CLOSING_MINUTE - RestaurantScript.START_MINUTE + 1.0)
	_check(bool(resumed.snapshot()["active"]) and int(resumed.snapshot()["service_day"]) > previous_day, "Clock must loop to the next morning while service remains active")
	var closed: Dictionary = resumed.close_day()
	_check(str(closed["event"]) == "day_closed" and not bool(resumed.snapshot()["active"]) and str(resumed.snapshot()["stage"]) == "closed", "Only hanging closing sign should end endless service")
	var settlement: Dictionary = resumed.snapshot()["last_settlement"]
	_check(int(settlement.get("missed", -1)) > 6 and int(settlement.get("days", 0)) >= 2, "Closing settlement should include all continuous orders and elapsed days")
	var reload = RestaurantScript.new()
	root.add_child(reload)
	reload.restore(resumed.snapshot())
	_check(str(reload.snapshot()["stage"]) == "closed" and int(reload.snapshot()["last_settlement"].get("missed", -1)) == int(settlement["missed"]), "Closing settlement must survive save restore")
	_check(reload.start_shift("calm", true) and bool(reload.snapshot()["active"]) and (reload.snapshot()["last_settlement"] as Dictionary).is_empty(), "Player can resume endless service after settlement without losing stored cash")


func _check_cooling_and_reheat() -> void:
	var restaurant = RestaurantScript.new()
	root.add_child(restaurant)
	restaurant.start_shift("calm")
	_advance_selected_to_serve(restaurant)
	restaurant.tick(RestaurantScript.WARM_HOLD_SECONDS + 0.1)
	var cooled: Dictionary = restaurant.snapshot()
	_check(bool(cooled["tickets"][0]["reheat_needed"]) and str(cooled["next_action"]) == "steam", "Completed hot dish should need its original heat station after cooling")
	var restored = RestaurantScript.new()
	root.add_child(restored)
	restored.restore(cooled)
	_check(bool(restored.snapshot()["tickets"][0]["reheat_needed"]), "Cooling requirement must survive save restore")
	_check(str(restored.interact("steam")["event"]) == "reheating", "Clicking the heat station should begin a short reheat")
	restored.tick(RestaurantScript.REHEAT_SECONDS + 0.01)
	_check(str(restored.snapshot()["next_action"]) == "serve" and not bool(restored.snapshot()["tickets"][0]["reheat_needed"]), "Reheat should return to the unfinished plating or service step")


func _finish_selected_ticket(restaurant, click_delay: float) -> int:
	var start_served := int(restaurant.snapshot()["served"])
	var start_earned := int(restaurant.snapshot()["earned_total"])
	var guard := 0
	while int(restaurant.snapshot()["served"]) == start_served and guard < 60:
		guard += 1
		_drive_customer_progress(restaurant, click_delay)
	_check(guard < 60, "Customer did not finish")
	return int(restaurant.snapshot()["earned_total"]) - start_earned


func _drive_customer_progress(restaurant, click_delay: float) -> float:
	var state: Dictionary = restaurant.snapshot()
	if bool(state["combo_plate"]["ready"]):
		restaurant.buffer_interact(0)
		if click_delay > 0.0 and bool(restaurant.snapshot()["active"]):
			restaurant.tick(click_delay)
		return click_delay
	var tickets: Array = state["tickets"]
	if tickets.is_empty():
		return 0.0
	var selected: Dictionary = tickets[int(state["selected_slot"])]
	if bool(selected["buffered"]):
		if bool(state["combo_plate"]["active"]):
			for ticket in tickets:
				if int(ticket["customer_id"]) == 1 and not bool(ticket["buffered"]):
					restaurant.select_order(int(ticket["slot"]))
					return 0.0
		restaurant.buffer_interact(int(selected["buffer_slot"]))
		return 0.0
	if float(state["heat_left"]) > 0.0:
		var wait_time := float(state["heat_left"]) + 0.01
		restaurant.tick(wait_time)
		return wait_time
	var acted: Dictionary = restaurant.interact(str(state["current_step"]))
	if str(acted.get("event", "")) == "ingredient_shortage":
		for group_id in RestaurantScript.RAW_GROUPS.keys():
			for ingredient in acted.get("missing", []):
				if ingredient in RestaurantScript.RAW_GROUPS[group_id]:
					var picked: Dictionary = restaurant.take_raw_group(str(group_id))
					if str(picked.get("event", "")) == "prep_full":
						restaurant.place_carried_ingredients()
						picked = restaurant.take_raw_group(str(group_id))
					if str(picked.get("event", "")) == "raw_restocked":
						picked = restaurant.take_raw_group(str(group_id))
					if str(picked.get("event", "")) == "raw_picked":
						restaurant.place_carried_ingredients()
		return 0.0
	if click_delay > 0.0 and bool(restaurant.snapshot()["active"]):
		restaurant.tick(click_delay)
	return click_delay


func _stage_raw_key(restaurant, ingredient_key: String) -> void:
	if int(restaurant.snapshot()["prep_ingredients"].get(ingredient_key, 0)) > 0:
		return
	for group_id in RestaurantScript.RAW_GROUPS.keys():
		if not (RestaurantScript.RAW_GROUPS[group_id] as Array).has(ingredient_key):
			continue
		for attempt in range(4):
			var result: Dictionary = restaurant.take_raw_group(str(group_id))
			match str(result.get("event", "")):
				"prep_full":
					restaurant.place_carried_ingredients()
				"raw_picked":
					restaurant.place_carried_ingredients()
				"raw_restocked":
					pass
				_:
					break
			if int(restaurant.snapshot()["prep_ingredients"].get(ingredient_key, 0)) > 0:
				break
		_check(int(restaurant.snapshot()["prep_ingredients"].get(ingredient_key, 0)) > 0, "Could not stage raw ingredient: " + ingredient_key)
		return


func _advance_selected_to_serve(restaurant) -> void:
	var guard := 0
	while str(restaurant.snapshot()["current_step"]) != "serve" and guard < 25:
		guard += 1
		var state: Dictionary = restaurant.snapshot()
		if float(state["heat_left"]) > 0.0:
			restaurant.tick(float(state["heat_left"]) + 0.01)
		else:
			restaurant.interact(str(state["current_step"]))
	_check(guard < 25, "Ticket failed to reach finished-dish stage")


func _on_settlement_event(result: Dictionary) -> void:
	if int(result.get("earned", 0)) > 0:
		settlement_events += 1


func _on_stock_state_update(_state: Dictionary) -> void:
	stock_state_updates += 1


func _on_event_log(result: Dictionary) -> void:
	event_log.append(str(result.get("event", "")))


func _on_capture_event(result: Dictionary) -> void:
	event_payloads.append(result.duplicate(true))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
