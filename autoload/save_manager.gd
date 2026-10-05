extends Node

## 手动存档与自动存档分开保存；两者都使用原子写入和 3 份轮转备份。

signal game_loaded
signal game_saved(automatic: bool)

const MANUAL_SAVE_PATH := "user://deep_city_save.json"
const AUTO_SAVE_PATH := "user://deep_city_autosave.json"
const SAVE_VERSION := 15
const MIN_SUPPORTED_VERSION := 1
const BACKUP_COUNT := 3
const TEMP_SUFFIX := ".tmp"
const MAX_SAVE_SIZE := 4 * 1024 * 1024
const CHECKSUM_KEY := "checksum"
const MIGRATIONS := {
	1: "_migrate_1_to_2",
	2: "_migrate_2_to_3",
	3: "_migrate_3_to_4",
	4: "_migrate_4_to_5",
	5: "_migrate_5_to_6",
	6: "_migrate_6_to_7",
	7: "_migrate_7_to_8",
	8: "_migrate_8_to_9",
	9: "_migrate_9_to_10",
	10: "_migrate_10_to_11",
	11: "_migrate_11_to_12",
	12: "_migrate_12_to_13",
	13: "_migrate_13_to_14",
	14: "_migrate_14_to_15",
}

var auto_save_enabled := true
var auto_save_interval_minutes := 15
var _last_auto_save_key := -1
var _last_auto_save_reason := ""
var _is_saving := false
var _is_loading := false
var _load_failed := false
var _load_failed_acknowledged := false

func _ready() -> void:
	auto_save_interval_minutes = maxi(1, int(ConfigDB.get_number("balance", "auto_save_interval_minutes", 15)))
	TimeSystem.minute_changed.connect(_on_minute_changed)
	TimeSystem.day_started.connect(_on_day_started)

func has_save() -> bool:
	for path in _candidate_paths():
		if FileAccess.file_exists(path):
			return true
	return false

func save_game(show_notice: bool = true, automatic: bool = false, reason: String = "") -> bool:
	if _is_loading:
		return false
	if _is_saving:
		return false
	if _load_failed and not _load_failed_acknowledged:
		if show_notice:
			NoticeManager.show_message("读档失败，尚未确认放弃原档，不能覆盖存档。", "warning")
		return false
	_is_saving = true
	var path := AUTO_SAVE_PATH if automatic else MANUAL_SAVE_PATH
	var data := _build_save_data()
	var ok := _write_save_atomically(path, data)
	_is_saving = false
	if not ok:
		NoticeManager.show_message("存档失败，原有记录没有被覆盖。", "warning")
		return false
	_last_auto_save_reason = reason if not reason.is_empty() else ("automatic" if automatic else "manual")
	_last_auto_save_key = _current_time_key()
	game_saved.emit(automatic)
	if show_notice:
		NoticeManager.show_message("生活进度已保存。" if not automatic else "已自动保存。", "positive")
	return true

func request_auto_save(reason: String = "event") -> bool:
	if not auto_save_enabled:
		return false
	if _is_loading or _is_saving:
		return false
	return save_game(false, true, reason)

func acknowledge_load_failure() -> void:
	_load_failed = false
	_load_failed_acknowledged = true

func prepare_new_game() -> void:
	_is_loading = false
	_is_saving = false
	_load_failed = false
	_load_failed_acknowledged = false
	_last_auto_save_key = -1
	_last_auto_save_reason = ""

func load_game(show_notice: bool = true) -> bool:
	if _is_loading:
		return false
	_is_loading = true
	_load_failed = false
	_load_failed_acknowledged = false
	var found_any := false
	var manual_primary_failed := false
	var last_error := ""
	var loaded_path := ""
	for path in _candidate_paths():
		if not FileAccess.file_exists(path):
			continue
		found_any = true
		var read_result := _read_save_file(path)
		if not bool(read_result.get("ok", false)):
			if path == MANUAL_SAVE_PATH:
				manual_primary_failed = true
			last_error = str(read_result.get("error", "invalid"))
			continue
		var parsed: Dictionary = read_result.get("data", {})
		var migrated := _migrate_save(parsed)
		if migrated.is_empty():
			if path == MANUAL_SAVE_PATH:
				manual_primary_failed = true
			last_error = "migration_failed"
			continue
		_apply_save(migrated)
		loaded_path = path
		break

	if loaded_path.is_empty():
		_is_loading = false
		if not found_any:
			if show_notice:
				NoticeManager.show_message("没有找到可读取的存档。", "hint")
			return false
		_load_failed = true
		_load_failed_acknowledged = false
		if show_notice:
			var detail := "（%s）" % last_error if not last_error.is_empty() else ""
			NoticeManager.show_message("存档内容损坏%s，暂时无法读取；原档没有被覆盖。" % detail, "warning")
		return false

	_last_auto_save_key = _current_time_key()
	_last_auto_save_reason = "loaded"
	_load_failed = false
	_load_failed_acknowledged = false
	_is_loading = false
	game_loaded.emit()
	if show_notice:
		var is_backup := loaded_path.begins_with(MANUAL_SAVE_PATH + ".bak") or loaded_path.begins_with(AUTO_SAVE_PATH + ".bak")
		var is_auto_main := loaded_path == AUTO_SAVE_PATH
		if is_backup:
			NoticeManager.show_message("检测到存档损坏，已自动回退到最近一份有效备份。", "warning")
		elif is_auto_main and manual_primary_failed:
			NoticeManager.show_message("手动存档不可用，已读取自动存档。", "warning")
		elif is_auto_main:
			NoticeManager.show_message("没有手动存档，已读取自动存档。", "hint")
		else:
			NoticeManager.show_message("生活进度已读取。", "positive")
	return true

func get_save_paths() -> Dictionary:
	return {
		"manual": MANUAL_SAVE_PATH,
		"automatic": AUTO_SAVE_PATH,
		"manual_backups": _backup_paths(MANUAL_SAVE_PATH),
		"automatic_backups": _backup_paths(AUTO_SAVE_PATH),
	}

func get_last_auto_save_reason() -> String:
	return _last_auto_save_reason

func set_auto_save_enabled(value: bool) -> void:
	auto_save_enabled = value

func _on_minute_changed(_minute_of_day: int) -> void:
	if _is_loading or not auto_save_enabled:
		return
	var key := _current_time_key()
	if _last_auto_save_key < 0:
		_last_auto_save_key = key
		return
	if abs(key - _last_auto_save_key) < auto_save_interval_minutes:
		return
	request_auto_save("timed")

func _on_day_started(_day_number: int) -> void:
	if _is_loading or not auto_save_enabled:
		return
	if _last_auto_save_key < 0:
		_last_auto_save_key = _current_time_key()
		return
	request_auto_save("day_start")

func _current_time_key() -> int:
	return TimeSystem.current_day * 1440 + TimeSystem.minute_of_day

func _build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"time": TimeSystem.get_save_data(),
		"game": GameState.get_save_data(),
		"inventory": InventoryManager.get_save_data(),
		"random": RandomManager.get_save_data(),
		"weather": WeatherSystem.get_save_data(),
		"collection": CollectionManager.get_save_data(),
		"progression": ProgressionManager.get_save_data(),
		"relationships": RelationshipManager.get_save_data(),
		"market_economy": MarketEconomyManager.get_save_data(),
		"expedition": ExpeditionManager.get_save_data(),
		"treasure": TreasureManager.get_save_data(),
		"business": BusinessManager.get_save_data(),
		"finance": FinanceManager.get_save_data(),
		"farm": FarmManager.get_save_data(),
		"pet": PetManager.get_save_data(),
		"room": RoomManager.get_save_data(),
		"staff": StaffManager.get_save_data(),
		"career": CareerManager.get_save_data(),
		"wardrobe": WardrobeManager.get_save_data(),
		"story": StoryManager.get_save_data(),
		"fishing": FishingManager.get_save_data(),
		"housing": HousingManager.get_save_data(),
		"travel": TravelManager.get_save_data(),
		"enterprise": EnterpriseManager.get_save_data(),
		"achievements": AchievementManager.get_save_data(),
		"platform": PlatformIntegrationManager.get_save_data(),
		"family": FamilyManager.get_save_data(),
		"wellbeing": WellbeingManager.get_save_data(),
		"unlocks": UnlockManager.get_save_data(),
		"medical": MedicalManager.get_save_data(),
		"education": EducationManager.get_save_data(),
		"endings": EndingManager.get_save_data(),
		"hobbies": HobbyManager.get_save_data(),
		"photos": PhotoManager.get_save_data(),
		"festival": FestivalManager.get_save_data(),
		"npc_stories": NpcStoryManager.get_save_data(),
		"kitchen": KitchenManager.get_save_data(),
		"market_phase": MarketPhaseManager.current_phase_id,
		"night_market": NightMarketManager.get_save_data(),
	}

func _apply_save(data: Dictionary) -> void:
	TimeSystem.restore(data.get("time", {}))
	GameState.restore(data.get("game", {}))
	InventoryManager.restore(data.get("inventory", {}))
	RandomManager.restore(data.get("random", {}))
	WeatherSystem.restore(data.get("weather", {}))
	CollectionManager.restore(data.get("collection", {}))
	ProgressionManager.restore(data.get("progression", {}))
	RelationshipManager.restore(data.get("relationships", {}))
	MarketEconomyManager.restore(data.get("market_economy", {}))
	ExpeditionManager.restore(data.get("expedition", {}))
	TreasureManager.restore(data.get("treasure", {}))
	BusinessManager.restore(data.get("business", {}))
	FinanceManager.restore(data.get("finance", {}))
	FarmManager.restore(data.get("farm", {}))
	PetManager.restore(data.get("pet", {}))
	RoomManager.restore(data.get("room", {}))
	StaffManager.restore(data.get("staff", {}))
	CareerManager.restore(data.get("career", {}))
	WardrobeManager.restore(data.get("wardrobe", {}))
	StoryManager.restore(data.get("story", {}))
	FishingManager.restore(data.get("fishing", {}))
	HousingManager.restore(data.get("housing", {}))
	TravelManager.restore(data.get("travel", {}))
	EnterpriseManager.restore(data.get("enterprise", {}))
	AchievementManager.restore(data.get("achievements", {}))
	PlatformIntegrationManager.restore(data.get("platform", {}))
	FamilyManager.restore(data.get("family", {}))
	WellbeingManager.restore(data.get("wellbeing", {}))
	UnlockManager.restore(data.get("unlocks", {}))
	MedicalManager.restore(data.get("medical", {}))
	EducationManager.restore(data.get("education", {}))
	EndingManager.restore(data.get("endings", {}))
	HobbyManager.restore(data.get("hobbies", {}))
	PhotoManager.restore(data.get("photos", {}))
	FestivalManager.restore(data.get("festival", {}))
	NpcStoryManager.restore(data.get("npc_stories", {}))
	NightMarketManager.restore(data.get("night_market", {}))
	KitchenManager.restore(data.get("kitchen", {}))
	MarketPhaseManager.force_refresh()
	SceneRouter.restore(GameState.current_area, GameState.spawn_id)

func _migrate_save(data: Dictionary, report_errors: bool = true) -> Dictionary:
	if data.is_empty():
		return {}
	var version := int(data.get("version", 0))
	if version <= 0:
		_report_save_error("SAVE: 存档缺少有效 version 字段，拒绝加载", report_errors)
		return {}
	if version < MIN_SUPPORTED_VERSION:
		_report_save_error("SAVE: 存档版本 %d 低于最低支持版本 %d，拒绝加载" % [version, MIN_SUPPORTED_VERSION], report_errors)
		return {}
	if version > SAVE_VERSION:
		_report_save_error("SAVE: 存档版本 %d 高于当前版本 %d，拒绝加载以防降级损坏" % [version, SAVE_VERSION], report_errors)
		return {}

	var migrated := data.duplicate(true)
	while version < SAVE_VERSION:
		var migration_name := str(MIGRATIONS.get(version, ""))
		if migration_name.is_empty() or not has_method(migration_name):
			_report_save_error("SAVE: 缺少 v%d 到 v%d 的迁移函数" % [version, version + 1], report_errors)
			return {}
		var migration_result: Variant = call(migration_name, migrated)
		if typeof(migration_result) != TYPE_DICTIONARY:
			_report_save_error("SAVE: v%d 迁移返回了非字典数据" % version, report_errors)
			return {}
		migrated = migration_result
		var next_version := int(migrated.get("version", version + 1))
		if next_version <= version or next_version > SAVE_VERSION:
			_report_save_error("SAVE: v%d 迁移没有推进版本号" % version, report_errors)
			return {}
		version = next_version
	return migrated

func _report_save_error(message: String, report_errors: bool) -> void:
	if report_errors:
		push_error(message)

func _dictionary_field(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value

func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	data["version"] = 2
	return data

func _migrate_2_to_3(data: Dictionary) -> Dictionary:
	data["version"] = 3
	return data

func _migrate_3_to_4(data: Dictionary) -> Dictionary:
	data["version"] = 4
	return data

func _migrate_4_to_5(data: Dictionary) -> Dictionary:
	if not data.has("kitchen"):
		data["kitchen"] = {}
	if not data.has("market_phase"):
		data["market_phase"] = MarketPhaseManager.get_phase_at_minute()
	data["version"] = 5
	return data

func _migrate_5_to_6(data: Dictionary) -> Dictionary:
	var staff := _dictionary_field(data, "staff")
	var hired := _dictionary_field(staff, "hired")
	for key in hired.keys():
		if typeof(hired[key]) == TYPE_BOOL:
			hired[key] = {"id": str(key), "npc_id": str(key), "legacy": true}
	staff["hired"] = hired
	data["staff"] = staff
	data["version"] = 6
	return data

func _migrate_6_to_7(data: Dictionary) -> Dictionary:
	if not data.has("career"):
		data["career"] = {}
	if not data.has("wardrobe"):
		data["wardrobe"] = {}
	data["version"] = 7
	return data

func _migrate_7_to_8(data: Dictionary) -> Dictionary:
	if not data.has("festival"):
		data["festival"] = {}
	data["version"] = 8
	return data

func _migrate_8_to_9(data: Dictionary) -> Dictionary:
	if not data.has("npc_stories"):
		data["npc_stories"] = {}
	data["version"] = 9
	return data

func _migrate_9_to_10(data: Dictionary) -> Dictionary:
	if not data.has("night_market"):
		data["night_market"] = {}
	data["version"] = 10
	return data

func _migrate_10_to_11(data: Dictionary) -> Dictionary:
	var inventory := _dictionary_field(data, "inventory")
	for key in ["storage_items", "shipping_items"]:
		if not inventory.has(key):
			inventory[key] = {}
	for key in ["backpack_level", "selected_hotbar_index"]:
		if not inventory.has(key):
			inventory[key] = 0
	data["inventory"] = inventory

	var room := _dictionary_field(data, "room")
	if not room.has("renovation_style"):
		room["renovation_style"] = ""
	data["room"] = room

	var relationships := _dictionary_field(data, "relationships")
	if not relationships.has("birthday_greeted"):
		relationships["birthday_greeted"] = {}
	data["relationships"] = relationships

	var family := _dictionary_field(data, "family")
	for key in ["married_day", "married_days", "last_evening_day", "last_date_day"]:
		if not family.has(key):
			family[key] = 0
	if not family.has("last_anniversary_year"):
		family["last_anniversary_year"] = -1
	data["family"] = family

	var staff := _dictionary_field(data, "staff")
	if not staff.has("pending_candidate_id"):
		staff["pending_candidate_id"] = ""
	if not staff.has("pending_candidate_stage"):
		staff["pending_candidate_stage"] = 0
	if not staff.has("referral_days"):
		staff["referral_days"] = {}
	data["staff"] = staff

	var festival := _dictionary_field(data, "festival")
	if not festival.has("activities_done"):
		festival["activities_done"] = {}
	data["festival"] = festival

	data["version"] = 11
	return data

func _migrate_11_to_12(data: Dictionary) -> Dictionary:
	var inventory := _dictionary_field(data, "inventory")
	for key in ["inventory_slots", "storage_slots", "shipping_slots"]:
		if not inventory.has(key):
			inventory[key] = []
	data["inventory"] = inventory
	data["version"] = 12
	return data

func _migrate_12_to_13(data: Dictionary) -> Dictionary:
	var collection := _dictionary_field(data, "collection")
	for key in ["seen_items", "seen_recipes", "seen_areas", "seen_careers"]:
		if not collection.has(key):
			collection[key] = {}
	data["collection"] = collection
	data["version"] = 13
	return data

func _migrate_13_to_14(data: Dictionary) -> Dictionary:
	var career := _dictionary_field(data, "career")
	for key in ["low_performance_streak", "layoff_count"]:
		if not career.has(key):
			career[key] = 0
	data["career"] = career
	data["version"] = 14
	return data

func _migrate_14_to_15(data: Dictionary) -> Dictionary:
	var career := _dictionary_field(data, "career")
	if not career.has("application_line"):
		career["application_line"] = ""
	for key in ["application_stage", "trial_progress", "trial_required"]:
		if not career.has(key):
			career[key] = 0
	data["career"] = career
	data["version"] = 15
	return data

func _write_save_atomically(path: String, data: Dictionary) -> bool:
	var payload := _attach_checksum(data)
	var json_text := JSON.stringify(payload, "	")
	if json_text.is_empty() or json_text == "{}":
		push_error("SAVE: 序列化结果为空，拒绝写入")
		return false
	if json_text.length() > MAX_SAVE_SIZE:
		push_error("SAVE: 存档体积 %d 超过上限 %d，拒绝写入" % [json_text.length(), MAX_SAVE_SIZE])
		return false

	var absolute_path := ProjectSettings.globalize_path(path)
	var temp_path := absolute_path + TEMP_SUFFIX
	_remove_if_exists(temp_path)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SAVE: 无法打开临时文件 %s，可能是磁盘空间或权限问题" % temp_path)
		return false
	file.store_string(json_text)
	file.flush()
	file.close()

	var had_primary := FileAccess.file_exists(absolute_path)
	if not _rotate_backups(absolute_path):
		_remove_if_exists(temp_path)
		return false

	_remove_if_exists(absolute_path)
	var rename_error := DirAccess.rename_absolute(temp_path, absolute_path)
	for _attempt in range(2):
		if rename_error == OK:
			break
		OS.delay_msec(25)
		rename_error = DirAccess.rename_absolute(temp_path, absolute_path)
	if rename_error != OK:
		# 主档已轮转到 .bak1，尝试恢复；失败时保留 .tmp 供人工恢复。
		if had_primary and FileAccess.file_exists(absolute_path + ".bak1"):
			DirAccess.rename_absolute(absolute_path + ".bak1", absolute_path)
		push_error("SAVE: 原子重命名失败 err=%d，临时文件保留在 %s" % [rename_error, temp_path])
		return false
	return true

func _attach_checksum(data: Dictionary) -> Dictionary:
	var payload := data.duplicate(true)
	payload.erase(CHECKSUM_KEY)
	payload[CHECKSUM_KEY] = _hash_dictionary(payload)
	return payload

func _verify_checksum(data: Dictionary) -> bool:
	if not data.has(CHECKSUM_KEY):
		return false
	var expected := str(data.get(CHECKSUM_KEY, ""))
	var payload := data.duplicate(true)
	payload.erase(CHECKSUM_KEY)
	return _hash_dictionary(payload) == expected

func _hash_dictionary(data: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_canonical_json(data).to_utf8_buffer())
	return context.finish().hex_encode()

func _canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var keys: Array = dictionary.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var dictionary_parts: Array[String] = []
			for key in keys:
				dictionary_parts.append(JSON.stringify(str(key)) + ":" + _canonical_json(dictionary[key]))
			return "{" + ",".join(dictionary_parts) + "}"
		TYPE_ARRAY:
			var array_value: Array = value
			var array_parts: Array[String] = []
			for item in array_value:
				array_parts.append(_canonical_json(item))
			return "[" + ",".join(array_parts) + "]"
		TYPE_FLOAT:
			var number := float(value)
			if is_equal_approx(number, round(number)):
				return str(int(round(number)))
			return String.num(number, 12)
		TYPE_INT:
			return str(int(value))
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_NIL:
			return "null"
		TYPE_STRING:
			return JSON.stringify(str(value))
		_:
			return JSON.stringify(str(value))

func _rotate_backups(path: String) -> bool:
	for index in range(BACKUP_COUNT, 1, -1):
		var source := "%s.bak%d" % [path, index - 1]
		var destination := "%s.bak%d" % [path, index]
		if FileAccess.file_exists(source):
			if not _replace_path(source, destination):
				return false
	if FileAccess.file_exists(path):
		if not _replace_path(path, path + ".bak1"):
			return false
	return true

func _replace_path(source: String, destination: String) -> bool:
	if not FileAccess.file_exists(source):
		return true
	_remove_if_exists(destination)
	var rename_error := DirAccess.rename_absolute(source, destination)
	if rename_error != OK:
		push_error("SAVE: 备份轮转失败 %s -> %s err=%d" % [source, destination, rename_error])
		return false
	return true

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			push_error("SAVE: 无法删除文件 %s err=%d" % [path, remove_error])

func _backup_paths(path: String) -> Array[String]:
	var result: Array[String] = []
	for index in range(1, BACKUP_COUNT + 1):
		result.append("%s.bak%d" % [path, index])
	return result

func _candidate_paths() -> Array[String]:
	var result: Array[String] = [MANUAL_SAVE_PATH]
	result.append_array(_backup_paths(MANUAL_SAVE_PATH))
	result.append(AUTO_SAVE_PATH)
	result.append_array(_backup_paths(AUTO_SAVE_PATH))
	return result

func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "missing", "has_checksum": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": {}, "error": "open_failed", "has_checksum": false}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {"ok": false, "data": {}, "error": "empty_file", "has_checksum": false}

	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "data": {}, "error": "json_parse_failed", "has_checksum": false}
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "data": {}, "error": "not_dictionary", "has_checksum": false}
	var data: Dictionary = parsed
	if data.is_empty():
		return {"ok": false, "data": {}, "error": "empty_dictionary", "has_checksum": false}
	if data.has(CHECKSUM_KEY) and not _verify_checksum(data):
		return {"ok": false, "data": {}, "error": "checksum_mismatch", "has_checksum": true}
	return {"ok": true, "data": data, "error": "", "has_checksum": data.has(CHECKSUM_KEY)}

## 兼容旧测试与旧调用：只返回解析后的字典，不返回读取状态。
func _read_json_file(path: String) -> Dictionary:
	var result := _read_save_file(path)
	if bool(result.get("ok", false)):
		return result.get("data", {})
	return {}
