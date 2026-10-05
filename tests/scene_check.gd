extends Node

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	GameState.reset_new_game()
	var world_script := load("res://scripts/gameplay/world.gd")
	var world = world_script.new()
	add_child(world)
	await get_tree().process_frame
	await _check_area("home", "初始出租屋")
	await _check_area("home_living", "初始出租屋生活区")
	GameState.money = 5000
	PetManager.adopt("cat_huang")
	await _check_area("home_living", "收养宠物后的生活区")
	await _check_area("restaurant", "餐馆实体场景")
	await _check_area("wholesale", "批发实体场景")
	await _check_area("street", "城中村主街")
	await _check_area("commercial_district", "商业区地图")
	await _check_area("high_end_district", "高端住宅区")
	await _check_area("industrial_district", "工业区地图")
	await _check_area("logistics_port", "物流港仓出口")
	await _check_area("craft_workshop", "手艺工坊出口")
	await _check_area("suburb", "城郊地图")
	await _check_area("clothing_store", "服装店")
	await _check_area("breakfast_shop", "早餐店前厅出口")
	await _check_area("breakfast_kitchen", "早餐店后厨出口")
	await _check_area("farm", "农场出口")
	await _check_area("farm_livestock", "农场圈舍出口")
	await _check_area("pet_store", "宠物商店出口")
	await _check_area("furniture_store", "家居超市出口")
	await _check_area("store", "便利店出口")
	await _check_area("bank", "银行出口")
	await _check_area("market", "旧货市场出口")
	await _check_area("night_market", "夜市出口")
	await _check_area("park", "公园出口")
	await _check_area("recycle", "回收站出口")
	await _check_area("factory", "工厂出口")
	await _check_area("ruins", "旧址出口")
	await _check_area("bus_station", "长途巴士站")
	await _check_area("clinic", "社区诊所")
	await _check_area("university", "城市校区")
	await _check_area("community_center", "社区活动中心")
	await _check_area("seaside_resort", "海边度假区")
	await _check_area("ancient_village", "古镇老街")
	await _check_area("mountain_spring", "山林温泉")
	await _check_area("riverside", "河边自然景观出口")
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
	var world = get_tree().get_first_node_in_group("world")
	if world == null:
		failures.append("%s: 找不到 world" % label)
		return
	var interactables := get_tree().get_nodes_in_group("interactables")
	_check_area_layout(world, label, interactables)
	if area_id in ["street", "commercial_district", "industrial_district"]:
		_check_zone_layout(world, label, interactables)
	var ids: Array[String] = []
	var id_counts: Dictionary = {}
	for node in interactables:
		if node is WorldInteractable:
			ids.append(node.interaction_id)
			id_counts[node.interaction_id] = int(id_counts.get(node.interaction_id, 0)) + 1
	for duplicate_id in id_counts:
		if int(id_counts[duplicate_id]) > 1:
			failures.append("%s: 场景存在重复交互物 %s" % [label, duplicate_id])
	var expected := ""
	match area_id:
		"home":
			expected = "bed"
		"home_living":
			expected = "home_living_to_bedroom"
		"restaurant":
			expected = "restaurant_open"
		"wholesale":
			expected = "wholesale_sell_counter"
		"street":
			expected = "enter_store"
		"commercial_district":
			expected = "enter_clothing"
		"high_end_district":
			expected = "high_end_exit"
		"industrial_district":
			expected = "labor_market"
		"logistics_port":
			expected = "logistics_port_exit"
		"craft_workshop":
			expected = "craft_workshop_exit"
		"suburb":
			expected = "enter_farm"
		"clothing_store":
			expected = "wardrobe_counter"
		"breakfast_shop":
			expected = "breakfast_exit"
		"breakfast_kitchen":
			expected = "breakfast_kitchen_exit"
		"farm":
			expected = "farm_exit"
		"farm_livestock":
			expected = "farm_livestock_exit"
		"pet_store":
			expected = "pet_store_exit"
		"furniture_store":
			expected = "furniture_exit"
		"store":
			expected = "store_exit"
		"bank":
			expected = "bank_exit"
		"market":
			expected = "market_exit"
		"night_market":
			expected = "night_market_exit"
		"park":
			expected = "park_exit"
		"recycle":
			expected = "recycle_exit"
		"factory":
			expected = "factory_exit"
		"ruins":
			expected = "ruins_exit"
		"bus_station":
			expected = "bus_station_exit"
		"clinic":
			expected = "clinic_exit"
		"university":
			expected = "university_exit"
		"community_center":
			expected = "community_center_exit"
		"seaside_resort", "ancient_village", "mountain_spring":
			expected = "destination_exit"
		"riverside":
			expected = "nature_exit"
		_:
			expected = ""
	if not ids.has(expected):
		failures.append("%s: 缺少交互物 %s（现有 %s）" % [label, expected, ",".join(ids)])
	elif area_id == "street" and ids.has("go_commercial"):
		failures.append("%s: 主街仍存在商业区传送门" % label)
	elif area_id == "home" and ids.has("home_pet"):
		failures.append("%s: 宠物照看入口不应挤进卧室" % label)
	elif area_id == "home_living" and PetManager.adopted.is_empty() and ids.has("home_pet"):
		failures.append("%s: 还没收养宠物就提前出现宠物窝" % label)
	elif area_id == "home_living" and not PetManager.adopted.is_empty() and not ids.has("home_pet"):
		failures.append("%s: 收养宠物后生活区没有照看入口" % label)
	else:
		if area_id in ["restaurant", "breakfast_shop", "breakfast_kitchen", "clothing_store"] and not _check_direct_click(world, expected):
			failures.append("%s: 经营场景无法用鼠标直接点到 %s" % [label, expected])
		else:
			print("SCENE_CHECK_OK: %s -> %s (%d 个交互物)" % [label, expected, ids.size()])

func _check_direct_click(world, interaction_id: String) -> bool:
	var target: WorldInteractable = _find_interactable_recursive(world._area_root, interaction_id)
	if target == null:
		return false
	return world._find_interactable_at_world(target.global_position) == target

func _find_interactable_recursive(node: Node, interaction_id: String) -> WorldInteractable:
	for child in node.get_children():
		if child is WorldInteractable and child.interaction_id == interaction_id:
			return child
		var found: WorldInteractable = _find_interactable_recursive(child, interaction_id)
		if found != null:
			return found
	return null

func _check_zone_layout(world: WorldRoot, label: String, interactables: Array) -> void:
	var counts: Dictionary = {}
	for node in interactables:
		if not node is WorldInteractable or not is_instance_valid(node) or not world.is_ancestor_of(node):
			continue
		var local_position := world._area_root.to_local(node.global_position)
		var zone := SceneLayoutManager.find_zone(str(world._area_root.get_meta("area_id", "")), local_position)
		if zone.is_empty():
			failures.append("%s: %s 被放在未定义分区" % [label, node.interaction_id])
			continue
		var zone_id := str(zone.get("id", ""))
		counts[zone_id] = int(counts.get(zone_id, 0)) + 1
	for zone_id in counts:
		if int(counts[zone_id]) > 8:
			failures.append("%s: 分区 %s 内交互物过密（%d）" % [label, zone_id, int(counts[zone_id])])

func _check_area_layout(world: WorldRoot, label: String, interactables: Array) -> void:
	var live: Array[WorldInteractable] = []
	for node in interactables:
		if node is WorldInteractable and is_instance_valid(node) and world.is_ancestor_of(node):
			live.append(node)
	for first_index in range(live.size()):
		var first := live[first_index]
		var first_center := world._area_root.to_local(first.global_position)
		var first_rect := Rect2(first_center - first.visual_size * 0.5, first.visual_size)
		for second_index in range(first_index + 1, live.size()):
			var second := live[second_index]
			var second_center := world._area_root.to_local(second.global_position)
			var second_rect := Rect2(second_center - second.visual_size * 0.5, second.visual_size)
			var overlap := first_rect.intersection(second_rect)
			if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
				continue
			var smaller_area := minf(first_rect.get_area(), second_rect.get_area())
			if smaller_area > 0.0 and overlap.get_area() / smaller_area >= 0.72:
				failures.append("%s: 交互物明显重叠 %s / %s" % [label, first.interaction_id, second.interaction_id])
	var expected_exit := _expected_interactable_id(str(world._area_root.get_meta("area_id", world._area_root.name)))
	var space := world.get_world_2d().direct_space_state
	for item in live:
		var params := PhysicsPointQueryParameters2D.new()
		params.position = item.global_position
		params.collision_mask = 2
		params.collide_with_areas = false
		params.collide_with_bodies = true
		if not space.intersect_point(params, 4).is_empty():
			if item.interaction_id == expected_exit and item.interaction_id.ends_with("_exit"):
				failures.append("%s: 出口 %s 的点击中心落在碰撞体里" % [label, item.interaction_id])
			elif not _check_direct_click(world, item.interaction_id):
				failures.append("%s: 交互物 %s 既不可接近也无法直接点击" % [label, item.interaction_id])
	var exit_item := _find_interactable_by_id(live, expected_exit)
	if exit_item != null:
		var blocked_samples := 0
		var clear_radius := maxf(30.0, minf(exit_item.hit_size.x, exit_item.hit_size.y) * 0.38)
		for sample_index in range(8):
			var params := PhysicsPointQueryParameters2D.new()
			params.position = exit_item.global_position + Vector2.from_angle(TAU * float(sample_index) / 8.0) * clear_radius
			params.collision_mask = 2
			params.collide_with_areas = false
			params.collide_with_bodies = true
			if not space.intersect_point(params, 2).is_empty():
				blocked_samples += 1
		if blocked_samples >= 6:
			failures.append("%s: 出口 %s 周围被碰撞体封住" % [label, expected_exit])

func _expected_interactable_id(area_id: String) -> String:
	match area_id:
		"home": return "bed"
		"home_living": return "home_living_to_bedroom"
		"restaurant": return "restaurant_open"
		"wholesale": return "wholesale_sell_counter"
		"street": return "enter_store"
		"commercial_district": return "enter_clothing"
		"high_end_district": return "high_end_exit"
		"industrial_district": return "labor_market"
		"logistics_port": return "logistics_port_exit"
		"craft_workshop": return "craft_workshop_exit"
		"suburb": return "enter_farm"
		"clothing_store": return "wardrobe_counter"
		"breakfast_shop": return "breakfast_exit"
		"breakfast_kitchen": return "breakfast_kitchen_exit"
		"farm": return "farm_exit"
		"farm_livestock": return "farm_livestock_exit"
		"pet_store": return "pet_store_exit"
		"furniture_store": return "furniture_exit"
		"store": return "store_exit"
		"bank": return "bank_exit"
		"market": return "market_exit"
		"night_market": return "night_market_exit"
		"park": return "park_exit"
		"recycle": return "recycle_exit"
		"factory": return "factory_exit"
		"ruins": return "ruins_exit"
		"bus_station": return "bus_station_exit"
		"clinic": return "clinic_exit"
		"university": return "university_exit"
		"community_center": return "community_center_exit"
		"seaside_resort", "ancient_village", "mountain_spring": return "destination_exit"
		"riverside": return "nature_exit"
	return ""

func _find_interactable_by_id(items: Array[WorldInteractable], interaction_id: String) -> WorldInteractable:
	if interaction_id.is_empty():
		return null
	for item in items:
		if item.interaction_id == interaction_id:
			return item
	return null
