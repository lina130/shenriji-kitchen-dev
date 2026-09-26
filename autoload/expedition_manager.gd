extends Node

signal changed
signal run_started(site_id: String)
signal run_ended(site_id: String, reason: String)

var active := false
var site_id := ""
var remaining_seconds := 0.0
var spawns: Dictionary = {}
var collected_count := 0
var estimated_value := 0
var _last_hint := -1

func _process(delta: float) -> void:
	if not active:
		return
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	var seconds_left := int(remaining_seconds)
	for threshold in [60, 30, 12]:
		if seconds_left <= threshold and _last_hint > threshold:
			_last_hint = threshold
			NoticeManager.show_message("手电的光圈越来越小，该找出口了。", "warning")
	if remaining_seconds <= 0.0:
		end_run("timeout")

func start_run(requested_site_id: String) -> bool:
	if active:
		NoticeManager.show_message("这一趟还没结束。", "warning")
		return false
	if not MarketEconomyManager.is_site_unlocked(requested_site_id):
		NoticeManager.show_message("缺一件趁手的工具，入口打不开。", "warning")
		return false
	var row := ConfigDB.get_row("ruins", requested_site_id)
	if row.is_empty():
		return false
	var fee := int(row.get("entry_fee", "0"))
	if fee > 0 and not GameState.spend(fee):
		return false
	active = true
	site_id = requested_site_id
	remaining_seconds = float(row.get("duration_seconds", "180"))
	_last_hint = 999
	collected_count = 0
	estimated_value = 0
	spawns = _generate_spawns(row)
	TreasureManager.clear_daily_limit()
	TimeSystem.set_time_scale(0.05)
	run_started.emit(site_id)
	SceneRouter.travel_to("ruins", site_id)
	NoticeManager.show_message("脚下的路一下暗了下来，手里的灯只能照亮眼前。", "hint")
	changed.emit()
	return true

func collect_spawn(spawn_id: String) -> bool:
	if not active:
		return false
	var spawn := _find_spawn(spawn_id)
	if spawn.is_empty() or bool(spawn.get("collected", false)):
		return false
	var energy_cost := float(ConfigDB.get_row("ruins", site_id).get("energy_cost", "3"))
	if GameState.energy < energy_cost:
		NoticeManager.show_message("再走下去只会更危险，先从这里出去吧。", "warning")
		end_run("exhausted")
		return false
	GameState.change_energy(-energy_cost)
	spawn["collected"] = true
	var item_id := str(spawn.get("item_id", ""))
	InventoryManager.add_item(item_id, 1)
	CollectionManager.discovered[item_id] = true
	var item := InventoryManager.get_item(item_id)
	var rarity := str(spawn.get("rarity", "common"))
	var value := int(item.get("sell_price", 0))
	estimated_value += value
	collected_count += 1
	GameState.on_collection_collected(item_id, rarity)
	NoticeManager.show_message("摸到%s，先收进包里。" % item.get("name", item_id), "positive")
	changed.emit()
	return true

func end_run(reason: String) -> void:
	if not active:
		return
	var finished_site := site_id
	active = false
	spawns.clear()
	TimeSystem.set_time_scale(1.0)
	SceneRouter.travel_to("market", "ruins_return")
	if reason == "timeout":
		NoticeManager.show_message("灯快灭了，你顺着记忆回到旧货市场。", "warning")
	else:
		NoticeManager.show_message("回到地面上，这次带回了 %d 件旧物。" % collected_count, "positive")
	run_ended.emit(finished_site, reason)
	changed.emit()

func get_area_spawns() -> Array:
	var result: Array = []
	for spawn in spawns.values():
		if not bool(spawn.get("collected", false)):
			result.append(spawn)
	return result

func get_site_name() -> String:
	return str(ConfigDB.get_row("ruins", site_id).get("name", "旧址"))

func get_light_radius() -> float:
	var base := 165.0
	var used_seconds := maxf(0.0, float(ConfigDB.get_row("ruins", site_id).get("duration_seconds", "180")) - remaining_seconds)
	var light_loss := used_seconds * 0.20
	var fatigue_loss := maxf(0.0, 70.0 - GameState.energy) * 0.55
	return clampf(base - light_loss - fatigue_loss, 58.0, 260.0)

func get_fog_strength() -> float:
	return 0.91

func _generate_spawns(row: Dictionary) -> Dictionary:
	var generated: Dictionary = {}
	# 旧楼里只有极少数位置值得停下翻找，更多旧物要靠日常里的彩蛋式偶遇。
	var count := clampi(int(row.get("spawn_count", "8")) / 3, 1, 2)
	var rarity_bonus := float(row.get("rarity_bonus", "0"))
	for index in range(count):
		var rarity := _roll_rarity(rarity_bonus)
		var item_id := _pick_item(rarity)
		if item_id.is_empty():
			continue
		generated["%s_%d" % [site_id, index]] = {
			"spawn_id": "%s_%d" % [site_id, index],
			"item_id": item_id,
			"rarity": rarity,
			"position": _spawn_position(index),
			"collected": false,
		}
	return generated

func _roll_rarity(bonus: float) -> String:
	var luck := GameState.get_collection_luck_bonus() + bonus
	var roll := RandomManager.rng.randf() * 100.0
	var legendary := 3.0 * (1.0 + luck)
	var rare := legendary + 12.0 * (1.0 + luck * 0.7)
	var uncommon := rare + 25.0
	if roll < legendary:
		return "legendary"
	if roll < rare:
		return "rare"
	if roll < uncommon:
		return "uncommon"
	return "common"

func _pick_item(rarity: String) -> String:
	var candidates: Array[String] = []
	for row_key in ConfigDB.get_rows("collectibles"):
		var item := ConfigDB.get_row("collectibles", row_key)
		if str(item.get("rarity", "common")) == rarity:
			candidates.append(row_key)
	return str(RandomManager.pick(candidates)) if not candidates.is_empty() else ""

func _spawn_position(index: int) -> Vector2:
	var points := [
		Vector2(640, 430), Vector2(420, 360), Vector2(860, 360), Vector2(250, 280),
		Vector2(1030, 280), Vector2(250, 640), Vector2(1030, 640), Vector2(500, 450),
		Vector2(780, 450), Vector2(500, 160), Vector2(780, 160), Vector2(400, 640),
		Vector2(880, 640), Vector2(640, 160),
	]
	return points[index % points.size()]

func _find_spawn(spawn_id: String) -> Dictionary:
	var spawn = spawns.get(spawn_id, {})
	return spawn if typeof(spawn) == TYPE_DICTIONARY else {}

func _serialize_spawns() -> Dictionary:
	var result: Dictionary = {}
	for key in spawns:
		var copy: Dictionary = spawns[key].duplicate(true)
		var point: Vector2 = copy.get("position", Vector2.ZERO)
		copy["position"] = {"x": point.x, "y": point.y}
		result[key] = copy
	return result

func _deserialize_spawns(saved: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in saved:
		var spawn: Dictionary = saved[key].duplicate(true)
		var raw = spawn.get("position", {"x": 0.0, "y": 0.0})
		if typeof(raw) == TYPE_DICTIONARY:
			spawn["position"] = Vector2(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)))
		else:
			spawn["position"] = Vector2.ZERO
		result[key] = spawn
	return result

func get_save_data() -> Dictionary:
	return {
		"active": active,
		"site_id": site_id,
		"remaining_seconds": remaining_seconds,
		"spawns": _serialize_spawns(),
		"collected_count": collected_count,
		"estimated_value": estimated_value,
		"last_hint": _last_hint,
	}

func restore(data: Dictionary) -> void:
	active = bool(data.get("active", false))
	site_id = str(data.get("site_id", ""))
	remaining_seconds = float(data.get("remaining_seconds", 0.0))
	spawns = _deserialize_spawns(data.get("spawns", {}))
	collected_count = int(data.get("collected_count", 0))
	estimated_value = int(data.get("estimated_value", 0))
	_last_hint = int(data.get("last_hint", 999))
	if active:
		TimeSystem.set_time_scale(0.05)
	changed.emit()

func reset_new_game() -> void:
	active = false
	site_id = ""
	remaining_seconds = 0.0
	spawns.clear()
	collected_count = 0
	estimated_value = 0
	_last_hint = -1
	TimeSystem.set_time_scale(1.0)
	changed.emit()