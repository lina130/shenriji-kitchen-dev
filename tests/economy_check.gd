extends Node

var failures: Array[String] = []
var world

func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_new_game()
	var world_script := load("res://scripts/gameplay/world.gd")
	world = world_script.new()
	add_child(world)
	await _wait_frames(4)
	await _run_restaurant()
	await _run_wholesale()
	AudioManager.shutdown()
	await _wait_frames(2)
	if failures.is_empty():
		print("ECONOMY_CHECK_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("ECONOMY_CHECK_FAIL: %s" % failure)
		get_tree().quit(1)

func _run_restaurant() -> void:
	SceneRouter.travel_to("restaurant", "entrance")
	await _wait_frames(4)
	_check_area("restaurant", "进入餐馆场景")
	TimeSystem.minute_of_day = 12 * 60
	MarketPhaseManager.force_refresh()
	BusinessManager.labor_stock = 12
	BusinessManager.brain_stock = 10
	for goods_id in ConfigDB.get_rows("goods"):
		BusinessManager.goods_stock[goods_id] = 20
	var opened := KitchenManager.start_shift_for("restaurant")
	_check(opened and KitchenManager.active, "餐馆开档营业")
	if KitchenManager.active:
		var order_ok := KitchenManager.handle_order_tap()
		_check(order_ok and not KitchenManager.hand.is_empty(), "点击顾客拿订单")
		KitchenManager.cancel_hand()
		KitchenManager.end_shift()
	SceneRouter.travel_to("street", "restaurant_exit")
	await _wait_frames(4)
	_check(GameState.current_area == "street", "从餐馆顺利回到主街")

func _run_wholesale() -> void:
	SceneRouter.travel_to("wholesale", "entrance")
	await _wait_frames(4)
	_check_area("wholesale", "进入批发场景")
	GameState.money = 2000
	var goods_ids := ConfigDB.get_rows("goods").keys()
	if goods_ids.is_empty():
		_fail("批发场景缺少货物配置")
		return
	var first_goods := str(goods_ids[0])
	var before := BusinessManager.get_stock(first_goods)
	var buy_ok := BusinessManager.buy_goods(first_goods, 1)
	_check(buy_ok and BusinessManager.get_stock(first_goods) == before + 1, "买进一件货物")
	var sell_ok := BusinessManager.sell_goods(first_goods, 1)
	_check(sell_ok and BusinessManager.get_stock(first_goods) == before, "卖出货物")
	SceneRouter.travel_to("street", "wholesale_exit")
	await _wait_frames(4)
	_check(GameState.current_area == "street", "从批发市场顺利回到主街")

func _walk_to_and_interact(target: Vector2, approach: Vector2, expected_id: String) -> bool:
	var player = world.player
	var area_before := GameState.current_area
	if player == null:
		_fail("缺少玩家节点")
		return false
	var expected_node = _find_interactable_recursive(world._area_root, expected_id)
	if expected_node == null:
		_fail("场景中不存在目标 %s" % expected_id)
		return false
	target = expected_node.global_position
	player.velocity = Vector2.ZERO
	var approach_distance := 12.0 if bool(expected_node.walk_trigger) else 45.0
	player.global_position = target - approach * approach_distance
	await _wait_frames(2)
	if not is_instance_valid(player) or GameState.current_area != area_before:
		return true
	player._refresh_context()
	await _wait_frames(32)
	if not is_instance_valid(player) or GameState.current_area != area_before:
		return true
	var nearby_names: Array[String] = []
	for node in player.nearby_interactables:
		nearby_names.append(node.interaction_id)
	print("ECONOMY_NEARBY target=%s nearby=%s" % [expected_id, ",".join(nearby_names)])
	for node in player.nearby_interactables:
		if node.interaction_id == expected_id:
			node.interact()
			await _wait_frames(3)
			return true
	for node in player.nearby_interactables:
		if node.interaction_id.begins_with(expected_id):
			node.interact()
			await _wait_frames(3)
			return true
	if not is_instance_valid(player):
		return GameState.current_area != area_before
	player.global_position = target
	await _wait_frames(2)
	player._refresh_context()
	await _wait_frames(4)
	for node in player.nearby_interactables:
		if node.interaction_id == expected_id or node.interaction_id.begins_with(expected_id):
			node.interact()
			await _wait_frames(4)
			return true
	_fail("目标 %s 不在可达交互范围内" % expected_id)
	return false

func _find_interactable_recursive(node: Node, interaction_id: String):
	if node is WorldInteractable and (node.interaction_id == interaction_id or node.interaction_id.begins_with(interaction_id)):
		return node
	for child in node.get_children():
		var found = _find_interactable_recursive(child, interaction_id)
		if found != null:
			return found
	return null

func _check_area(expected: String, label: String) -> void:
	if GameState.current_area != expected:
		_fail("%s（当前 %s）" % [label, GameState.current_area])
	else:
		print("ECONOMY_STEP_OK: " + label)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("ECONOMY_STEP_OK: " + label)
	else:
		_fail(label)

func _fail(message: String) -> void:
	failures.append(message)

func _wait_frames(count: int) -> void:
	for index in range(count):
		await get_tree().process_frame
