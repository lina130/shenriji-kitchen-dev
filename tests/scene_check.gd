extends Node

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_new_game()
	var world_script := load("res://scripts/gameplay/world.gd")
	var world = world_script.new()
	add_child(world)
	await get_tree().process_frame
	await _check_area("restaurant", "餐馆实体场景")
	await _check_area("wholesale", "批发实体场景")
	AudioManager.shutdown()
	await get_tree().process_frame
	if failures.is_empty():
		print("SCENE_CHECK_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SCENE_CHECK_FAIL: %s" % failure)
		get_tree().quit(1)

func _check_area(area_id: String, label: String) -> void:
	SceneRouter.travel_to(area_id, "entrance")
	await get_tree().process_frame
	await get_tree().process_frame
	var world = get_tree().get_first_node_in_group("world")
	if world == null:
		failures.append("%s: 找不到 world" % label)
		return
	var interactables := get_tree().get_nodes_in_group("interactables")
	var ids: Array[String] = []
	for node in interactables:
		if node is WorldInteractable:
			ids.append(node.interaction_id)
	var expected := ""
	if area_id == "restaurant":
		expected = "restaurant_open"
	else:
		expected = "wholesale_sell_counter"
	if not ids.has(expected):
		failures.append("%s: 缺少交互物 %s（现有 %s）" % [label, expected, ",".join(ids)])
	else:
		print("SCENE_CHECK_OK: %s -> %s (%d 个交互物)" % [label, expected, ids.size()])
