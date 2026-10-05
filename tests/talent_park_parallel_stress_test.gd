extends Node

const TARGET_SERVES := 60
const MAX_PASSES := 1800

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var kitchen := TalentParkRestaurant3D.new()
	add_child(kitchen)
	if not kitchen.start_shift("rush", true):
		_fail("Could not start endless rush service")
		return
	kitchen.tick(float(kitchen.snapshot()["rush_wave_at"]) + 0.05)
	var started_orders := {}
	var seen_recipes := {}
	var concurrent_three := false
	var simultaneous_heat := false
	var max_pass := 0
	for pass_index in range(MAX_PASSES):
		max_pass = pass_index + 1
		var before: Dictionary = kitchen.snapshot()
		if int(before["served"]) >= TARGET_SERVES:
			break
		var live: Array = before["tickets"]
		concurrent_three = concurrent_three or live.size() == 3
		var heating_count := 0
		for ticket in live:
			if float(ticket["heat_left"]) > 0.0:
				heating_count += 1
		simultaneous_heat = simultaneous_heat or heating_count >= 2
		# Keep customer patience out of this mechanical concurrency test.
		# Supply, cooking and pickup state still use the real production methods.
		var internal_tickets: Array = kitchen.get("_tickets")
		for slot in range(internal_tickets.size()):
			internal_tickets[slot]["time_left"] = 1000.0
		kitchen.set("_tickets", internal_tickets)
		var changed := false
		for slot in range(live.size()):
			var order_number := int((live[slot] as Dictionary)["order_number"])
			var current_tickets: Array = kitchen.snapshot()["tickets"]
			var current_slot := -1
			for current_index in range(current_tickets.size()):
				if int(current_tickets[current_index]["order_number"]) == order_number:
					current_slot = current_index
					break
			if current_slot < 0:
				continue
			var item: Dictionary = current_tickets[current_slot]
			if not started_orders.has(order_number):
				var opened: Dictionary = kitchen.select_order(current_slot)
				if not bool(opened.get("ok", false)) or str(opened.get("event", "")) != "order_started":
					_fail("Ticket did not start exactly once: %d" % order_number)
					return
				started_orders[order_number] = true
				changed = true
			if bool(item["buffered"]) or float(item["heat_left"]) > 0.0:
				continue
			var recipe: Dictionary = item["recipe"]
			seen_recipes[str(recipe["id"])] = true
			var action := str(item["next_action"])
			var result: Dictionary = kitchen.interact_order(order_number, action)
			if str(result.get("event", "")) == "ingredient_shortage":
				for ingredient in result.get("missing", []):
					var staged: Dictionary = kitchen.stage_raw_ingredient(str(ingredient))
					if not bool(staged.get("ok", false)):
						_fail("Could not replenish %s for order %d: %s" % [str(ingredient), order_number, str(staged.get("event", ""))])
						return
				result = kitchen.interact_order(order_number, action)
			if not bool(result.get("ok", false)):
				_fail("Order %d stuck on %s: %s" % [order_number, action, str(result.get("event", ""))])
				return
			var selected_after: Dictionary = kitchen.snapshot()
			if int(selected_after.get("selected_slot", -1)) < (selected_after["tickets"] as Array).size():
				var selected_item: Dictionary = selected_after["tickets"][int(selected_after["selected_slot"])]
				if int(selected_item["order_number"]) != order_number and str(result.get("event", "")) not in ["served", "served_combo"]:
					_fail("Bottom process target did not follow order %d after %s; now %d" % [order_number, str(result.get("event", "")), int(selected_item["order_number"])])
					return
			changed = true
		if bool(kitchen.snapshot()["combo_plate"]["ready"]):
			var combo: Dictionary = kitchen.serve_buffer(0)
			if not bool(combo.get("ok", false)):
				_fail("Completed combo could not be served: " + str(combo.get("event", "")))
				return
			changed = true
		if not changed:
			var wait_time := INF
			for waiting in kitchen.snapshot()["tickets"]:
				if float(waiting["heat_left"]) > 0.0:
					wait_time = minf(wait_time, float(waiting["heat_left"]))
			if is_inf(wait_time):
				_fail("Parallel production made no progress and no heat timer can release it")
				return
			kitchen.tick(wait_time + 0.01)
	var finished: Dictionary = kitchen.snapshot()
	if int(finished["served"]) < TARGET_SERVES or int(finished["missed"]) != 0 or not concurrent_three or not simultaneous_heat or seen_recipes.size() != TalentParkRestaurant3D.RECIPES.size():
		_fail("Stress coverage incomplete: served=%d missed=%d recipes=%d three=%s heat=%s passes=%d" % [int(finished["served"]), int(finished["missed"]), seen_recipes.size(), str(concurrent_three), str(simultaneous_heat), max_pass])
		return
	print("TALENT_PARK_PARALLEL_OK: %d dishes, all %d recipes, three active tickets, simultaneous heat, %d passes" % [int(finished["served"]), seen_recipes.size(), max_pass])
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
