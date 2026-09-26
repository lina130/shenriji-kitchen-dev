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
	BusinessManager.labor_stock = 12
	BusinessManager.brain_stock = 10
	for goods_id in ConfigDB.get_rows("goods"):
		BusinessManager.goods_stock[goods_id] = 20
	var opened := await _walk_to_and_interact(Vector2(640, 590), Vector2.UP, "restaurant_open")
	_check(opened and KitchenManager.active, "走到档口招牌开档营业")
	var station_ok := await _walk_to_and_interact(Vector2(330, 338), Vector2.UP, "restaurant_station|0")
	_check(station_ok, "走到灶台并点击开工")
	KitchenManager.end_shift()
	var exit_ok := await _walk_to_and_interact(Vector2(1080, 600), Vector2.UP, "restaurant_exit")
	_check(exit_ok and GameState.current_area == "street", "从餐馆顺利回到街上")

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
	var buy_ok := await _walk_to_and_interact(Vector2(210, 200), Vector2.UP, "wholesale_buy|%s" % first_goods)
	_check(buy_ok and BusinessManager.get_stock(first_goods) == before + 1, "走到货箱并买进一件")
	var sell_ok := await _walk_to_and_interact(Vector2(640, 510), Vector2.UP, "wholesale_sell_counter")
	_check(sell_ok and BusinessManager.get_stock(first_goods) == before, "走到收购台把货卖出去")
	var exit_ok := await _walk_to_and_interact(Vector2(640, 650), Vector2.DOWN, "wholesale_exit")
	_check(exit_ok and GameState.current_area == "street", "从批发市场顺利回到街上")

func _walk_to_and_interact(target: Vector2, approach: Vector2, expected_id: String) -> bool:
	var player = world.player
	if player == null:
		_fail("缺少玩家节点")
		return false
	player.global_position = target - approach * 70.0
	await _wait_frames(8)
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
	_fail("目标 %s 不在可达交互范围内" % expected_id)
	return false

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
