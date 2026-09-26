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
	if not _world_ready():
		_fail("新游戏后世界未建立")
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
	await _travel_by_player(Vector2(1200, 360), Vector2.RIGHT)
	_check_area("street", "从出租屋走到街道")
	await _wait_frames(12)
	await _travel_by_player(Vector2(82, 360), Vector2.LEFT)
	_check_area("home", "从街道回到出租屋")
	await _wait_frames(12)
	await _run_home_checks()
	if not failures.is_empty():
		await _finish()
		return
	await _travel_by_player(Vector2(1200, 360), Vector2.RIGHT)
	_check_area("street", "从出租屋走到街道")
	await _wait_frames(12)
	await _move_player_to(Vector2(780, 360))
	await _travel_by_player(Vector2(1110, 560), Vector2.DOWN)
	_check_area("store", "从街道进入便利店")
	await _connect_and_click_nearest("store_counter", "打开便利店商品")
	await _close_modal()
	await _connect_and_click_nearest("clerk_shift", "便利店兼职")
	await _wait_frames(8)
	await _connect_and_click_nearest("npc|lin", "与小林交谈")
	await _close_modal()
	await _connect_and_click_nearest("store_exit", "离开便利店")
	_check_area("street", "从便利店回到街道")
	await _wait_frames(8)
	await _move_player_to(Vector2(260, 145))
	await _travel_by_player(Vector2(260, 145), Vector2.UP)
	_check_area("market", "从街道进入旧货市场")
	GameState.money = 10000
	InventoryManager.add_item("film_camera", 1)
	InventoryManager.add_item("old_radio", 1)
	await _connect_and_click_nearest("market_stall", "打开旧货行")
	await _press_modal_button_prefix("卖")
	await _press_modal_button_prefix("寄卖")
	await _press_modal_button_prefix("把摊位做大一点")
	await _close_modal()
	await _connect_and_click_nearest("expedition_board", "打开旧址入口")
	await _press_modal_button_prefix("旧楼地下室")
	await _wait_frames(18)
	_check_area("ruins", "进入旧楼地下室")
	await _interact_first_with_prefix("collect|ruins|", "拾取旧址旧物")
	await _connect_and_click_nearest("ruins_exit", "从旧址返回地面")
	_check_area("market", "探索结束回到旧货市场")
	await _connect_and_click_nearest("npc|chen", "与陈伯交谈")
	await _close_modal()
	await _connect_and_click_nearest("market_exit", "离开旧货市场")
	_check_area("street", "从旧货市场回到街道")
	await _wait_frames(8)
	await _move_player_to(Vector2(760, 620))
	await _travel_by_player(Vector2(760, 632), Vector2.DOWN)
	_check_area("park", "进入社区公园")
	await _connect_and_click_nearest("exercise_equipment", "在公园锻炼")
	await _wait_frames(8)
	await _connect_and_click_nearest("park_exit", "离开公园")
	_check_area("street", "从公园回到街道")
	await _wait_frames(8)
	await _move_player_to(Vector2(760, 645))
	await _move_player_to(Vector2(245, 645))
	await _move_player_to(Vector2(245, 580))
	await _travel_by_player(Vector2(245, 632), Vector2.DOWN)
	_check_area("recycle", "进入废品回收站")
	await _connect_and_click_nearest("recycle_search", "翻找废品堆")
	await _wait_frames(8)
	await _connect_and_click_nearest("recycle_exit", "离开废品回收站")
	_check_area("street", "从废品回收站回到街道")
	await _wait_frames(8)
	await _move_player_to(Vector2(1040, 150))
	await _travel_by_player(Vector2(1040, 142), Vector2.UP)
	_check_area("factory", "进入工厂")
	await _connect_and_click_nearest("work_station", "在工厂干活")
	await _wait_frames(8)
	await _connect_and_click_nearest("npc|wang", "与王师傅交谈")
	await _close_modal()
	await _connect_and_click_nearest("factory_exit", "离开工厂")
	_check_area("street", "从工厂回到街道")
	await _finish()

func _run_home_checks() -> void:
	await _connect_and_click_nearest("fridge", "打开冰箱背包")
	await _close_modal()
	await _connect_and_click_nearest("study_desk", "在书桌学习")
	await _wait_frames(8)
	await _open_shortcut("inventory", "打开背包快捷键")
	await _close_modal()
	await _open_shortcut("collection", "打开旧物册快捷键")
	await _close_modal()
	await _open_shortcut("map", "打开地图快捷键")
	await _close_modal()
	await _open_shortcut("bank", "打开账本快捷键")
	await _close_modal()
	await _connect_and_click_nearest("npc|mei", "与梅姨交谈")
	await _close_modal()
	TimeSystem.minute_of_day = 22 * 60
	await _connect_and_click_nearest("bed", "上床睡觉")
	await _wait_frames(12)
	_step("睡觉推进到次日")

func _open_shortcut(action_name: String, label: String) -> void:
	Input.action_press(action_name)
	await get_tree().process_frame
	Input.action_release(action_name)
	await get_tree().process_frame
	_step(label)

func _close_modal() -> void:
	if not is_instance_valid(main.hud) or main.hud._modal_state == main.hud.ModalState.NONE:
		return
	main.hud._close_modal()
	await get_tree().process_frame


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
	var approach_offsets := {
		"bed": Vector2(0, 105),
		"fridge": Vector2(115, 0),
		"study_desk": Vector2(0, 90),
		"store_counter": Vector2(0, 100),
		"work_station": Vector2(0, 90),
		"exercise_equipment": Vector2(0, 0),
	}
	var target: Vector2 = interactable.global_position + approach_offsets.get(interaction_id, Vector2.ZERO)
	if interaction_id == "exercise_equipment":
		await _move_player_to(Vector2(250, 580))
		await _move_player_to(Vector2(250, 280))
	if interaction_id == "park_exit":
		await _move_player_to(Vector2(250, 280))
		await _move_player_to(Vector2(250, 580))
		await _move_player_to(Vector2(640, 580))
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