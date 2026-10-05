extends Node

signal changed

## 星露谷式格位规则：快捷栏始终 12 格，背包扩容只增加总格位；
## 初始随身 12 格，两次扩容后为 24 / 36 格，单个堆叠上限 999。
const HOTBAR_SIZE := 12
const BACKPACK_BASE := 0
const BACKPACK_STEP := 12
const BACKPACK_MAX_LEVEL := 2
const INVENTORY_MAX_SIZE := HOTBAR_SIZE + BACKPACK_BASE + BACKPACK_STEP * BACKPACK_MAX_LEVEL
const STORAGE_SIZE := 36
const SHIPPING_SIZE := 36
const MAX_STACK_SIZE := 999
const SCOPE_INVENTORY := "inventory"
const SCOPE_STORAGE := "storage"
const SCOPE_SHIPPING := "shipping"

var ITEMS: Dictionary = {}
var items: Dictionary = {}
var storage_items: Dictionary = {}
var shipping_items: Dictionary = {}
var inventory_slots: Array[Dictionary] = []
var storage_slots: Array[Dictionary] = []
var shipping_slots: Array[Dictionary] = []
var hotbar_slots: Array[Dictionary] = []
var backpack_slots: Array[Dictionary] = []
var backpack_level := 0
var selected_hotbar_index := 0

func _ready() -> void:
	_load_catalog()
	reset_new_game()

func _load_catalog() -> void:
	ITEMS.clear()
	for item_id in ConfigDB.get_rows("items"):
		var row: Dictionary = ConfigDB.get_row("items", item_id)
		ITEMS[item_id] = {
			"id": item_id,
			"name": str(row.get("name", item_id)),
			"description": str(row.get("description", "")),
			"kind": str(row.get("kind", "misc")),
			"category": "consumable",
			"price": int(row.get("price", "0")),
			"usable": str(row.get("usable", "false")).to_lower() == "true",
			"energy": float(row.get("energy", "0")),
			"use_hint": str(row.get("use_hint", "")),
			"rarity": "common",
			"sell_price": 0,
			"gift_npc": "",
			"displayable": false,
		}
	for item_id in ConfigDB.get_rows("collectibles"):
		var row: Dictionary = ConfigDB.get_row("collectibles", item_id)
		ITEMS[item_id] = {
			"id": item_id,
			"name": str(row.get("name", item_id)),
			"description": str(row.get("description", "")),
			"kind": "collectible",
			"category": "collectible",
			"price": 0,
			"usable": float(row.get("energy", "0")) > 0.0,
			"energy": float(row.get("energy", "0")),
			"rarity": str(row.get("rarity", "common")),
			"sell_price": int(row.get("sell_price", "0")),
			"gift_npc": str(row.get("gift_npc", "")),
			"displayable": str(row.get("displayable", "false")).to_lower() == "true",
			"market_category": str(row.get("market_category", "daily")),
		}

func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

func add_item(item_id: String, amount: int = 1) -> void:
	if not ITEMS.has(item_id) or amount <= 0:
		return
	var remaining := amount
	var unlocked := get_unlocked_inventory_size()
	while remaining > 0:
		var target := _find_stack_slot(inventory_slots, item_id, 0, unlocked)
		if target < 0:
			target = _find_empty_slot(inventory_slots, 0, unlocked)
		if target < 0:
			NoticeManager.show_message("随身格位满了，先整理背包或把东西放进木箱。", "warning", "小林")
			break
		var slot: Dictionary = inventory_slots[target]
		var room := MAX_STACK_SIZE - int(slot.get("count", 0))
		var moved := mini(remaining, room)
		slot["item_id"] = item_id
		slot["count"] = int(slot.get("count", 0)) + moved
		inventory_slots[target] = slot
		remaining -= moved
	if remaining < amount and get_node_or_null("/root/CollectionManager") != null:
		CollectionManager.record_item_seen(item_id)
	_after_container_change("", false)

func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_count(item_id) < amount:
		return false
	var removed := _remove_from_container(inventory_slots, item_id, amount, -1, get_unlocked_inventory_size())
	if removed <= 0:
		return false
	_after_container_change("", false)
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	return get_count(item_id) >= amount

func get_count(item_id: String) -> int:
	return int(items.get(item_id, 0))

func use_item(item_id: String) -> bool:
	var item := get_item(item_id)
	if item.is_empty() or not bool(item.get("usable", false)):
		return false
	if str(item.get("category", "")) == "collectible":
		return false
	if not remove_item(item_id, 1):
		return false
	GameState.on_item_used(item)
	return true

func eat_at_table() -> bool:
	var lines := get_inventory_lines()
	for entry in lines:
		var item_id := str(entry.get("id", ""))
		var item := get_item(item_id)
		if str(item.get("category", "")) in ["consumable", "food", "drink"] and bool(item.get("usable", false)):
			return use_item(item_id)
	NoticeManager.show_message("随身没有能马上吃的东西，先去便利店带点热食吧。", "hint", "店里伙计")
	return false

func select_hotbar_slot(index: int) -> bool:
	if index < 0 or index >= HOTBAR_SIZE:
		return false
	selected_hotbar_index = index
	changed.emit()
	return true

func get_selected_hotbar_line() -> Dictionary:
	var lines := get_hotbar_lines()
	if selected_hotbar_index < 0 or selected_hotbar_index >= lines.size():
		return {}
	return lines[selected_hotbar_index]

func get_backpack_capacity() -> int:
	return BACKPACK_BASE + backpack_level * BACKPACK_STEP

func get_unlocked_inventory_size() -> int:
	return mini(INVENTORY_MAX_SIZE, HOTBAR_SIZE + get_backpack_capacity())

func get_hotbar_lines() -> Array[Dictionary]:
	return _slot_lines(hotbar_slots)

func get_backpack_slots() -> Array[Dictionary]:
	return _slot_lines(backpack_slots)

func get_storage_slots() -> Array[Dictionary]:
	return _slot_lines(storage_slots)

func get_shipping_slots() -> Array[Dictionary]:
	return _slot_lines(shipping_slots)

func get_inventory_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in items:
		if get_count(str(item_id)) <= 0:
			continue
		result.append(_item_line(str(item_id)))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_collectible: bool = a.get("category") == "collectible"
		var b_collectible: bool = b.get("category") == "collectible"
		if a_collectible != b_collectible:
			return not a_collectible
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result

func get_giftable_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in get_inventory_lines():
		if str(entry.get("category", "")) == "collectible":
			result.append(entry)
	return result

func get_storage_lines() -> Array[Dictionary]:
	var result := _aggregate_container_lines(storage_slots)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result

func get_shipping_lines() -> Array[Dictionary]:
	var result := _aggregate_container_lines(shipping_slots)
	for line in result:
		var unit_price := int(get_item(str(line.get("id", ""))).get("sell_price", 0))
		if unit_price <= 0:
			unit_price = maxi(1, int(round(float(get_item(str(line.get("id", ""))).get("price", 0)) * 0.55)))
		line["shipping_price"] = unit_price
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result

func deposit_to_shipping(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_count(item_id) < amount:
		return false
	var accepted := _move_from_inventory_to_container(item_id, amount, shipping_slots, -1, SHIPPING_SIZE)
	if accepted <= 0:
		NoticeManager.show_message("收购箱已经塞满了，等明早结算后再来。", "warning", "门口收购车")
		return false
	_after_container_change("shipping_deposit")
	return true

## 收购箱对齐星露谷：放进去后由次日收购车统一结算，不能再取回。
func withdraw_from_shipping(_item_id: String, _amount: int = 1) -> bool:
	NoticeManager.show_message("放进收购箱的东西已经登记发车，不能取回了。", "hint", "门口收购车")
	return false

func sell_shipping_bin() -> int:
	if shipping_items.is_empty():
		return 0
	var total := 0
	for item_id in shipping_items:
		var item := get_item(str(item_id))
		var unit_price := int(item.get("sell_price", 0))
		if unit_price <= 0:
			unit_price = maxi(1, int(round(float(item.get("price", 0)) * 0.55)))
		total += unit_price * int(shipping_items[item_id])
	_clear_container(shipping_slots)
	_rebuild_caches()
	_sync_slots()
	if total > 0:
		GameState.earn(total)
		AchievementManager.record_event("shipping_sale")
		NoticeManager.show_scene_message("门口收购车把昨天放下的东西结清了：¥%d。" % total, "门口收购车", "positive")
	SaveManager.request_auto_save("shipping_sold")
	changed.emit()
	return total

func get_shipping_estimate() -> int:
	var total := 0
	for line in get_shipping_lines():
		total += int(line.get("shipping_price", 0)) * int(line.get("count", 0))
	return total

func get_backpack_summary() -> String:
	return "随身格位 %d/%d · 快捷栏 %d 格 · 背包升级 %d/%d" % [get_unlocked_inventory_size(), INVENTORY_MAX_SIZE, HOTBAR_SIZE, backpack_level, BACKPACK_MAX_LEVEL]

func get_backpack_upgrade_cost() -> int:
	match backpack_level:
		0:
			return 2000
		1:
			return 10000
	return 0

func upgrade_backpack() -> bool:
	if backpack_level >= BACKPACK_MAX_LEVEL:
		NoticeManager.show_message("背包已经扩到最大了。", "hint", "小林")
		return false
	var cost := get_backpack_upgrade_cost()
	if not GameState.spend(cost, "请小林帮忙把背包重新缝大了一圈。"):
		return false
	backpack_level += 1
	_sync_slots()
	NoticeManager.show_message("阿珍把背带和夹层重新缝牢，现在能装更多东西了。", "positive", "阿珍")
	SaveManager.request_auto_save("backpack_upgrade")
	changed.emit()
	return true

func deposit_to_storage(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_count(item_id) < amount:
		return false
	var accepted := _move_from_inventory_to_container(item_id, amount, storage_slots, -1, STORAGE_SIZE)
	if accepted <= 0:
		NoticeManager.show_message("木箱已经满了，先拿走一些东西再放。", "warning", "梅姨")
		return false
	_after_container_change("storage_deposit")
	return true

func withdraw_from_storage(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or int(storage_items.get(item_id, 0)) < amount:
		return false
	var accepted := _move_from_container_to_inventory(item_id, amount, storage_slots, -1)
	if accepted <= 0:
		NoticeManager.show_message("随身格位满了，先把背包整理出空位。", "warning", "小林")
		return false
	_after_container_change("storage_withdraw")
	return true

## scope 只能是 inventory / storage / shipping。
func move_slot(from_scope: String, from_index: int, to_scope: String, to_index: int, amount: int = -1) -> bool:
	if not _valid_scope_index(from_scope, from_index) or not _valid_scope_index(to_scope, to_index):
		return false
	var source := _container_for_scope(from_scope)
	var target := _container_for_scope(to_scope)
	if from_scope == to_scope:
		var changed_slots := _move_within_container(source, from_index, to_index)
		if not changed_slots:
			return false
		_after_container_change("inventory_sort")
		return true
	var source_slot: Dictionary = source[from_index]
	var item_id := str(source_slot.get("item_id", ""))
	var source_count := int(source_slot.get("count", 0))
	if item_id.is_empty() or source_count <= 0:
		return false
	var move_amount := source_count if amount < 0 else mini(amount, source_count)
	var moved := 0
	match from_scope + ">" + to_scope:
		"inventory>storage":
			moved = _transfer_slot(source, from_index, target, to_index, move_amount, STORAGE_SIZE)
		"storage>inventory":
			moved = _transfer_slot(source, from_index, target, to_index, move_amount, get_unlocked_inventory_size())
		"inventory>shipping":
			moved = _transfer_slot(source, from_index, target, to_index, move_amount, SHIPPING_SIZE)
		_:
			NoticeManager.show_message("这条路不能直接搬东西，先从箱子里放进随身背包。", "hint", "梅姨")
			return false
	if moved <= 0:
		return false
	_after_container_change("inventory_transfer")
	return true

func split_stack(scope: String, index: int, amount: int = -1) -> bool:
	if not _valid_scope_index(scope, index):
		return false
	var slots := _container_for_scope(scope)
	var slot: Dictionary = slots[index]
	var item_id := str(slot.get("item_id", ""))
	var count := int(slot.get("count", 0))
	if item_id.is_empty() or count <= 1:
		return false
	var empty_index := _find_empty_slot(slots, 0, get_container_size(scope))
	if empty_index < 0:
		return false
	var split_amount := int(floor(float(count) * 0.5)) if amount < 0 else clampi(amount, 1, count - 1)
	if split_amount >= count:
		return false
	slot["count"] = count - split_amount
	slots[index] = slot
	slots[empty_index] = {"item_id": item_id, "count": split_amount}
	_after_container_change("inventory_split")
	return true

func transfer_slot_to(scope: String, index: int, target_scope: String, amount: int = -1) -> bool:
	if not _valid_scope_index(scope, index) or scope == target_scope:
		return false
	var source_slot := get_slot(scope, index)
	var item_id := str(source_slot.get("item_id", ""))
	var source_count := int(source_slot.get("count", 0))
	if item_id.is_empty() or source_count <= 0:
		return false
	var target_size := get_container_size(target_scope)
	var target_slots := _container_for_scope(target_scope)
	var target_index := _find_transfer_target(target_slots, item_id, target_size)
	if target_index < 0:
		return false
	var move_amount := source_count if amount < 0 else mini(amount, source_count)
	return move_slot(scope, index, target_scope, target_index, move_amount)

func get_slot(scope: String, index: int) -> Dictionary:
	if not _valid_scope_index(scope, index):
		return {}
	return (_container_for_scope(scope)[index] as Dictionary).duplicate(true)

func get_container_size(scope: String) -> int:
	match scope:
		SCOPE_INVENTORY:
			return get_unlocked_inventory_size()
		SCOPE_STORAGE:
			return STORAGE_SIZE
		SCOPE_SHIPPING:
			return SHIPPING_SIZE
	return 0

func get_save_data() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"storage_items": storage_items.duplicate(true),
		"shipping_items": shipping_items.duplicate(true),
		"inventory_slots": inventory_slots.duplicate(true),
		"storage_slots": storage_slots.duplicate(true),
		"shipping_slots": shipping_slots.duplicate(true),
		"backpack_level": backpack_level,
		"selected_hotbar_index": selected_hotbar_index,
	}

func restore(data: Dictionary) -> void:
	items.clear()
	storage_items.clear()
	shipping_items.clear()
	inventory_slots = _make_empty_slots(INVENTORY_MAX_SIZE)
	storage_slots = _make_empty_slots(STORAGE_SIZE)
	shipping_slots = _make_empty_slots(SHIPPING_SIZE)
	backpack_level = clampi(int(data.get("backpack_level", 0)), 0, BACKPACK_MAX_LEVEL)
	selected_hotbar_index = clampi(int(data.get("selected_hotbar_index", 0)), 0, HOTBAR_SIZE - 1)

	var loaded_inventory_slots := _load_slot_array(data.get("inventory_slots", []), inventory_slots)
	var loaded_storage_slots := _load_slot_array(data.get("storage_slots", []), storage_slots)
	var loaded_shipping_slots := _load_slot_array(data.get("shipping_slots", []), shipping_slots)
	if not loaded_inventory_slots:
		_restore_legacy_items(data.get("items", {}), inventory_slots, INVENTORY_MAX_SIZE)
	if not loaded_storage_slots:
		_restore_legacy_items(data.get("storage_items", {}), storage_slots, STORAGE_SIZE)
	if not loaded_shipping_slots:
		_restore_legacy_items(data.get("shipping_items", {}), shipping_slots, SHIPPING_SIZE)
	_ensure_unlocked_items_visible()
	_compact_invalid_slots()
	_rebuild_caches()
	_sync_slots()
	changed.emit()

func reset_new_game() -> void:
	items.clear()
	storage_items.clear()
	shipping_items.clear()
	inventory_slots = _make_empty_slots(INVENTORY_MAX_SIZE)
	storage_slots = _make_empty_slots(STORAGE_SIZE)
	shipping_slots = _make_empty_slots(SHIPPING_SIZE)
	backpack_level = 0
	selected_hotbar_index = 0
	_rebuild_caches()
	_sync_slots()
	changed.emit()

func _item_line(item_id: String, count_override: int = -1) -> Dictionary:
	var item := get_item(item_id)
	var hint := str(item.get("use_hint", ""))
	if hint.is_empty() and str(item.get("category", "")) == "collectible":
		hint = "可在旧货市场卖出现金、寄卖，或送给喜欢它的 NPC。"
	return {
		"id": item_id,
		"name": item.get("name", item_id),
		"description": item.get("description", ""),
		"use_hint": hint,
		"icon_key": PresentationManager.get_icon_key("item", item_id),
		"count": get_count(item_id) if count_override < 0 else count_override,
		"usable": bool(item.get("usable", false)),
		"category": item.get("category", "consumable"),
		"rarity": item.get("rarity", "common"),
		"sell_price": int(item.get("sell_price", 0)),
	}

func _slot_lines(slots: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		var item_id := str(slot.get("item_id", ""))
		var count := int(slot.get("count", 0))
		if item_id.is_empty() or count <= 0:
			result.append({"index": index, "item_id": "", "count": 0, "name": "", "empty": true})
			continue
		var line := _item_line(item_id, count)
		line["index"] = index
		line["empty"] = false
		line["locked"] = _scope_for_container(slots) == SCOPE_INVENTORY and index >= get_unlocked_inventory_size()
		result.append(line)
	return result

func _sync_slots() -> void:
	hotbar_slots.clear()
	for index in range(HOTBAR_SIZE):
		var slot: Dictionary = inventory_slots[index] if index < inventory_slots.size() else {"item_id": "", "count": 0}
		hotbar_slots.append(slot.duplicate(true))
	backpack_slots.clear()
	for index in range(HOTBAR_SIZE, get_unlocked_inventory_size()):
		if index < inventory_slots.size():
			backpack_slots.append(inventory_slots[index].duplicate(true))
	_rebuild_caches()

func _rebuild_caches() -> void:
	items = _aggregate_container(inventory_slots, get_unlocked_inventory_size())
	storage_items = _aggregate_container(storage_slots, STORAGE_SIZE)
	shipping_items = _aggregate_container(shipping_slots, SHIPPING_SIZE)

func _aggregate_container(slots: Array[Dictionary], limit: int) -> Dictionary:
	var result: Dictionary = {}
	for index in range(mini(limit, slots.size())):
		var slot: Dictionary = slots[index]
		var item_id := str(slot.get("item_id", ""))
		var count := int(slot.get("count", 0))
		if not item_id.is_empty() and count > 0:
			result[item_id] = int(result.get(item_id, 0)) + count
	return result

func _aggregate_container_lines(slots: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var totals := _aggregate_container(slots, slots.size())
	for item_id in totals:
		if int(totals[item_id]) > 0:
			result.append(_item_line(str(item_id), int(totals[item_id])))
	return result

func _move_from_inventory_to_container(item_id: String, amount: int, target: Array[Dictionary], preferred_index: int, target_size: int) -> int:
	var available := mini(amount, get_count(item_id))
	if available <= 0:
		return 0
	var removed := _remove_from_container(inventory_slots, item_id, available, -1, get_unlocked_inventory_size())
	if removed <= 0:
		return 0
	var accepted := _add_to_container(target, item_id, removed, preferred_index, target_size)
	if accepted < removed:
		_add_to_container(inventory_slots, item_id, removed - accepted, -1, get_unlocked_inventory_size())
	return accepted

func _move_from_container_to_inventory(item_id: String, amount: int, source: Array[Dictionary], preferred_index: int) -> int:
	var removed := _remove_from_container(source, item_id, amount, preferred_index, source.size())
	if removed <= 0:
		return 0
	var accepted := _add_to_container(inventory_slots, item_id, removed, -1, get_unlocked_inventory_size())
	if accepted < removed:
		_add_to_container(source, item_id, removed - accepted, -1, source.size())
	return accepted

func _transfer_slot(source: Array[Dictionary], source_index: int, target: Array[Dictionary], target_index: int, amount: int, target_size: int) -> int:
	if source_index < 0 or source_index >= source.size() or target_index < 0 or target_index >= target_size:
		return 0
	var source_slot: Dictionary = source[source_index]
	var item_id := str(source_slot.get("item_id", ""))
	var source_count := int(source_slot.get("count", 0))
	if item_id.is_empty() or source_count <= 0 or amount <= 0:
		return 0
	var target_slot: Dictionary = target[target_index]
	var target_item := str(target_slot.get("item_id", ""))
	if not target_item.is_empty() and target_item != item_id:
		return 0
	var room := MAX_STACK_SIZE - int(target_slot.get("count", 0))
	if room <= 0:
		return 0
	var moved := mini(amount, mini(source_count, room))
	source_slot["count"] = source_count - moved
	if int(source_slot["count"]) <= 0:
		source_slot["item_id"] = ""
		source_slot["count"] = 0
	target_slot["item_id"] = item_id
	target_slot["count"] = int(target_slot.get("count", 0)) + moved
	source[source_index] = source_slot
	target[target_index] = target_slot
	return moved

func _move_within_container(slots: Array[Dictionary], from_index: int, to_index: int) -> bool:
	if from_index == to_index or from_index < 0 or from_index >= slots.size() or to_index < 0 or to_index >= slots.size():
		return false
	var source: Dictionary = slots[from_index]
	var target: Dictionary = slots[to_index]
	var source_item := str(source.get("item_id", ""))
	var source_count := int(source.get("count", 0))
	if source_item.is_empty() or source_count <= 0:
		return false
	var target_item := str(target.get("item_id", ""))
	if target_item.is_empty():
		slots[to_index] = source.duplicate(true)
		slots[from_index] = {"item_id": "", "count": 0}
		return true
	if target_item == source_item:
		var room := MAX_STACK_SIZE - int(target.get("count", 0))
		var moved := mini(source_count, room)
		if moved <= 0:
			return false
		target["count"] = int(target.get("count", 0)) + moved
		source["count"] = source_count - moved
		if int(source["count"]) <= 0:
			source["item_id"] = ""
			source["count"] = 0
		slots[to_index] = target
		slots[from_index] = source
		return true
	slots[from_index] = target
	slots[to_index] = source
	return true

func _add_to_container(slots: Array[Dictionary], item_id: String, amount: int, preferred_index: int, limit: int) -> int:
	if amount <= 0 or not ITEMS.has(item_id):
		return 0
	var remaining := amount
	if preferred_index >= 0 and preferred_index < mini(limit, slots.size()):
		var preferred: Dictionary = slots[preferred_index]
		var preferred_item := str(preferred.get("item_id", ""))
		if preferred_item.is_empty() or preferred_item == item_id:
			var room := MAX_STACK_SIZE - int(preferred.get("count", 0))
			var moved := mini(remaining, room)
			if moved > 0:
				preferred["item_id"] = item_id
				preferred["count"] = int(preferred.get("count", 0)) + moved
				slots[preferred_index] = preferred
				remaining -= moved
	while remaining > 0:
		var stack_index := _find_stack_slot(slots, item_id, 0, limit)
		if stack_index < 0:
			break
		var stack_slot: Dictionary = slots[stack_index]
		var room := MAX_STACK_SIZE - int(stack_slot.get("count", 0))
		var moved := mini(remaining, room)
		stack_slot["count"] = int(stack_slot.get("count", 0)) + moved
		slots[stack_index] = stack_slot
		remaining -= moved
	while remaining > 0:
		var empty_index := _find_empty_slot(slots, 0, limit)
		if empty_index < 0:
			break
		var moved := mini(remaining, MAX_STACK_SIZE)
		slots[empty_index] = {"item_id": item_id, "count": moved}
		remaining -= moved
	return amount - remaining

func _remove_from_container(slots: Array[Dictionary], item_id: String, amount: int, preferred_index: int, limit: int) -> int:
	if amount <= 0:
		return 0
	var remaining := amount
	if preferred_index >= 0 and preferred_index < mini(limit, slots.size()):
		remaining -= _remove_from_slot(slots, preferred_index, item_id, remaining)
	for index in range(mini(limit, slots.size()) - 1, -1, -1):
		if remaining <= 0:
			break
		remaining -= _remove_from_slot(slots, index, item_id, remaining)
	return amount - remaining

func _remove_from_slot(slots: Array[Dictionary], index: int, item_id: String, amount: int) -> int:
	if index < 0 or index >= slots.size() or amount <= 0:
		return 0
	var slot: Dictionary = slots[index]
	if str(slot.get("item_id", "")) != item_id:
		return 0
	var count := int(slot.get("count", 0))
	var removed := mini(count, amount)
	slot["count"] = count - removed
	if int(slot["count"]) <= 0:
		slot["item_id"] = ""
		slot["count"] = 0
	slots[index] = slot
	return removed

func _find_stack_slot(slots: Array[Dictionary], item_id: String, start: int, limit: int) -> int:
	for index in range(maxi(0, start), mini(limit, slots.size())):
		var slot: Dictionary = slots[index]
		if str(slot.get("item_id", "")) == item_id and int(slot.get("count", 0)) < MAX_STACK_SIZE:
			return index
	return -1

func _find_transfer_target(slots: Array[Dictionary], item_id: String, limit: int) -> int:
	var stack_index := _find_stack_slot(slots, item_id, 0, limit)
	if stack_index >= 0:
		return stack_index
	return _find_empty_slot(slots, 0, limit)

func _find_empty_slot(slots: Array[Dictionary], start: int, limit: int) -> int:
	for index in range(maxi(0, start), mini(limit, slots.size())):
		var slot: Dictionary = slots[index]
		if str(slot.get("item_id", "")).is_empty() or int(slot.get("count", 0)) <= 0:
			return index
	return -1

func _restore_legacy_items(raw_items: Variant, target: Array[Dictionary], limit: int) -> void:
	if typeof(raw_items) != TYPE_DICTIONARY:
		return
	for item_id in raw_items:
		var key := str(item_id)
		if not ITEMS.has(key):
			continue
		_add_to_container(target, key, maxi(0, int(raw_items[item_id])), -1, limit)
	var required_unique_slots := 0
	for item_id in raw_items:
		if ITEMS.has(str(item_id)) and int(raw_items[item_id]) > 0:
			required_unique_slots += 1
	var required_total := HOTBAR_SIZE + required_unique_slots
	if required_total > get_unlocked_inventory_size():
		backpack_level = mini(BACKPACK_MAX_LEVEL, maxi(backpack_level, int(ceil(float(required_total - HOTBAR_SIZE) / float(BACKPACK_STEP)))))

func _load_slot_array(raw_slots: Variant, target: Array[Dictionary]) -> bool:
	if typeof(raw_slots) != TYPE_ARRAY or raw_slots.is_empty():
		return false
	var loaded_any := false
	for index in range(target.size()):
		target[index] = {"item_id": "", "count": 0}
	for index in range(mini(raw_slots.size(), target.size())):
		var raw_slot: Variant = raw_slots[index]
		if typeof(raw_slot) != TYPE_DICTIONARY:
			continue
		var item_id := str(raw_slot.get("item_id", ""))
		if not ITEMS.has(item_id):
			continue
		var count := clampi(int(raw_slot.get("count", 0)), 0, MAX_STACK_SIZE)
		if count <= 0:
			continue
		target[index] = {"item_id": item_id, "count": count}
		loaded_any = true
	return loaded_any or raw_slots.size() >= target.size()

func _ensure_unlocked_items_visible() -> void:
	var highest_used := -1
	for index in range(inventory_slots.size()):
		var slot: Dictionary = inventory_slots[index]
		if not str(slot.get("item_id", "")).is_empty() and int(slot.get("count", 0)) > 0:
			highest_used = index
	if highest_used < get_unlocked_inventory_size():
		return
	var extra_slots := highest_used + 1 - HOTBAR_SIZE
	backpack_level = mini(BACKPACK_MAX_LEVEL, maxi(backpack_level, int(ceil(float(extra_slots) / float(BACKPACK_STEP)))))

func _compact_invalid_slots() -> void:
	for slots in [inventory_slots, storage_slots, shipping_slots]:
		for index in range(slots.size()):
			var slot: Dictionary = slots[index]
			var item_id := str(slot.get("item_id", ""))
			var count := clampi(int(slot.get("count", 0)), 0, MAX_STACK_SIZE)
			if item_id.is_empty() or count <= 0 or not ITEMS.has(item_id):
				slots[index] = {"item_id": "", "count": 0}
			else:
				slots[index] = {"item_id": item_id, "count": count}

func _clear_container(slots: Array[Dictionary]) -> void:
	for index in range(slots.size()):
		slots[index] = {"item_id": "", "count": 0}

func _after_container_change(save_reason: String, should_save: bool = true) -> void:
	_rebuild_caches()
	_sync_slots()
	if should_save and not save_reason.is_empty():
		SaveManager.request_auto_save(save_reason)
	changed.emit()

func _container_for_scope(scope: String) -> Array[Dictionary]:
	match scope:
		SCOPE_INVENTORY:
			return inventory_slots
		SCOPE_STORAGE:
			return storage_slots
		SCOPE_SHIPPING:
			return shipping_slots
	return []

func _scope_for_container(slots: Array[Dictionary]) -> String:
	if slots == inventory_slots:
		return SCOPE_INVENTORY
	if slots == storage_slots:
		return SCOPE_STORAGE
	if slots == shipping_slots:
		return SCOPE_SHIPPING
	return ""

func _valid_scope_index(scope: String, index: int) -> bool:
	if index < 0:
		return false
	match scope:
		SCOPE_INVENTORY:
			return index < get_unlocked_inventory_size()
		SCOPE_STORAGE:
			return index < STORAGE_SIZE
		SCOPE_SHIPPING:
			return index < SHIPPING_SIZE
	return false

func _make_empty_slots(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index in range(count):
		result.append({"item_id": "", "count": 0})
	return result
