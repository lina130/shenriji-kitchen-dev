extends Node

const TEST_PATH := "user://save_stability_case.json"

var failures: Array[String] = []
var _original_day := 1
var _original_minute := 420

func _ready() -> void:
	await get_tree().process_frame
	_original_day = TimeSystem.current_day
	_original_minute = TimeSystem.minute_of_day
	SaveManager.set_auto_save_enabled(false)
	SaveManager.prepare_new_game()

	_test_atomic_write()
	_test_backup_rotation()
	_test_checksum_detection()
	_test_corruption_fallback()
	_test_version_migration()
	_test_migration_chain_complete()
	_test_load_failure_protection()
	_test_timed_interval_math()
	_test_day_start_key_node()
	_test_manual_and_auto_coexist()
	_test_real_save_api_if_isolated()

	_restore_state()
	if failures.is_empty():
		print("SAVE_STABILITY_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SAVE_STABILITY_FAIL: %s" % failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _restore_state() -> void:
	_cleanup_path(TEST_PATH)
	TimeSystem.current_day = _original_day
	TimeSystem.minute_of_day = _original_minute
	SaveManager.set_auto_save_enabled(true)
	SaveManager.prepare_new_game()

func _cleanup_path(path: String) -> void:
	for suffix in ["", ".tmp", ".bak1", ".bak2", ".bak3", ".bak4"]:
		var target: String = path + str(suffix)
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))

func _cleanup_candidate_paths() -> void:
	for path in SaveManager._candidate_paths():
		_cleanup_path(path)

func _read_test_file(path: String) -> Dictionary:
	return SaveManager._read_save_file(path)

func _test_atomic_write() -> void:
	_cleanup_path(TEST_PATH)
	var ok := SaveManager._write_save_atomically(TEST_PATH, {"version": SaveManager.SAVE_VERSION, "money": 100})
	_check(ok, "T1.1 应能原子写入测试档")
	var read_result := _read_test_file(TEST_PATH)
	_check(bool(read_result.get("ok", false)), "T1.2 原子写入结果应可读")
	_check(int(read_result.get("data", {}).get("money", 0)) == 100, "T1.3 原子写入应保留 money")
	_check(bool(read_result.get("has_checksum", false)), "T1.4 新写入档应带校验和")

	# 模拟 rename 前留下的临时文件，主档不应因此改变。
	var temp_file := FileAccess.open(TEST_PATH + SaveManager.TEMP_SUFFIX, FileAccess.WRITE)
	if temp_file != null:
		temp_file.store_string("{\"version\":15,\"money\":999}")
		temp_file.close()
	read_result = _read_test_file(TEST_PATH)
	_check(int(read_result.get("data", {}).get("money", 0)) == 100, "T1.5 残留 tmp 不应覆盖主档")
	_cleanup_path(TEST_PATH)

func _test_backup_rotation() -> void:
	_cleanup_path(TEST_PATH)
	for index in range(1, 6):
		SaveManager._write_save_atomically(TEST_PATH, {"version": SaveManager.SAVE_VERSION, "n": index})
	_check(FileAccess.file_exists(TEST_PATH), "T2.1 主档应存在")
	for index in range(1, SaveManager.BACKUP_COUNT + 1):
		_check(FileAccess.file_exists("%s.bak%d" % [TEST_PATH, index]), "T2.2 应存在第 %d 份备份" % index)
	_check(not FileAccess.file_exists("%s.bak4" % TEST_PATH), "T2.3 不应存在第 4 份备份")
	var oldest_result := _read_test_file("%s.bak3" % TEST_PATH)
	_check(bool(oldest_result.get("ok", false)), "T2.4 第 3 份备份应可读")
	_check(int(oldest_result.get("data", {}).get("n", 0)) == 2, "T2.5 第 3 份备份应保留第二次写入内容")
	_cleanup_path(TEST_PATH)

func _test_checksum_detection() -> void:
	var data := {"version": SaveManager.SAVE_VERSION, "money": 320, "energy": 100.0}
	var with_checksum := SaveManager._attach_checksum(data)
	_check(with_checksum.has(SaveManager.CHECKSUM_KEY), "T3.1 应附加校验和")
	_check(SaveManager._verify_checksum(with_checksum), "T3.2 校验和应通过")
	with_checksum["money"] = 32
	_check(not SaveManager._verify_checksum(with_checksum), "T3.3 篡改 money 后校验和应失败")

func _test_corruption_fallback() -> void:
	_cleanup_path(TEST_PATH)
	SaveManager._write_save_atomically(TEST_PATH, {"version": SaveManager.SAVE_VERSION, "money": 100})
	SaveManager._write_save_atomically(TEST_PATH, {"version": SaveManager.SAVE_VERSION, "money": 200})
	var broken := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if broken != null:
		broken.store_string("{invalid json")
		broken.close()
	var main_result := _read_test_file(TEST_PATH)
	_check(not bool(main_result.get("ok", false)), "T4.1 损坏主档应读取失败")
	var backup_result := _read_test_file(TEST_PATH + ".bak1")
	_check(bool(backup_result.get("ok", false)), "T4.2 损坏主档应能回退到备份1")
	_check(int(backup_result.get("data", {}).get("money", 0)) == 100, "T4.3 备份内容应正确")
	_cleanup_path(TEST_PATH)

func _test_version_migration() -> void:
	var v10 := {
		"version": 10,
		"inventory": {},
		"room": {},
		"relationships": {},
		"family": {},
		"staff": {},
		"festival": {},
	}
	var migrated := SaveManager._migrate_save(v10)
	_check(int(migrated.get("version", 0)) == SaveManager.SAVE_VERSION, "T5.1 v10 应迁移到当前版本")
	_check(migrated.has("pet") == false, "T5.2 迁移不应凭空伪造未定义数据")
	_check(SaveManager._migrate_save({"version": 0}, false).is_empty(), "T5.3 缺少有效版本应拒绝加载")
	_check(SaveManager._migrate_save({"version": SaveManager.SAVE_VERSION + 1}, false).is_empty(), "T5.4 未来版本应拒绝加载")

func _test_migration_chain_complete() -> void:
	for version in range(SaveManager.MIN_SUPPORTED_VERSION, SaveManager.SAVE_VERSION):
		_check(SaveManager.MIGRATIONS.has(version), "T6.1 缺少 v%d 迁移函数" % version)

func _test_load_failure_protection() -> void:
	SaveManager._load_failed = true
	SaveManager._load_failed_acknowledged = false
	var blocked := SaveManager.save_game(false, false)
	_check(not blocked, "T7.1 加载失败未确认时不应允许存档")
	SaveManager.acknowledge_load_failure()
	_check(not SaveManager._load_failed, "T7.2 确认后应解除覆盖保护")
	SaveManager.prepare_new_game()

func _test_timed_interval_math() -> void:
	SaveManager._last_auto_save_key = 1000
	TimeSystem.current_day = 0
	TimeSystem.minute_of_day = 100
	var key := SaveManager._current_time_key()
	_check(abs(key - SaveManager._last_auto_save_key) >= SaveManager.auto_save_interval_minutes, "T8.1 时间回退后也应满足自动存档间隔")
	TimeSystem.current_day = _original_day
	TimeSystem.minute_of_day = _original_minute

func _test_day_start_key_node() -> void:
	SaveManager.set_auto_save_enabled(true)
	SaveManager._last_auto_save_key = -1
	SaveManager._on_day_started(TimeSystem.current_day + 1)
	_check(SaveManager._last_auto_save_key >= 0, "T9.1 首次跨天应建立自动存档基准")
	SaveManager.set_auto_save_enabled(false)

func _test_real_save_api_if_isolated() -> void:
	if OS.get_environment("DEEP_CITY_SAVE_TEST_ISOLATED") != "1":
		return
	_cleanup_candidate_paths()
	SaveManager.set_auto_save_enabled(false)
	GameState.reset_new_game()
	GameState.money = 100
	_check(SaveManager.save_game(false, false, "manual_isolated_1"), "T11.1 隔离环境下手动存档应可写")
	GameState.money = 200
	_check(SaveManager.save_game(false, false, "manual_isolated_2"), "T11.2 隔离环境下第二次手动存档应产生备份")
	GameState.money = 222
	SaveManager.set_auto_save_enabled(true)
	_check(SaveManager.request_auto_save("auto_isolated"), "T11.3 隔离环境下自动存档应可写")
	SaveManager.set_auto_save_enabled(false)
	var manual_result := _read_test_file(SaveManager.MANUAL_SAVE_PATH)
	var auto_result := _read_test_file(SaveManager.AUTO_SAVE_PATH)
	_check(int(manual_result.get("data", {}).get("game", {}).get("money", 0)) == 200, "T11.4 自动档不应覆盖手动档")
	_check(int(auto_result.get("data", {}).get("game", {}).get("money", 0)) == 222, "T11.5 自动档应保存最新状态")
	var broken := FileAccess.open(SaveManager.MANUAL_SAVE_PATH, FileAccess.WRITE)
	if broken != null:
		broken.store_string("{invalid json")
		broken.close()
	var loaded := SaveManager.load_game(false)
	_check(loaded, "T11.6 损坏主档时应加载到备份")
	_check(GameState.money == 100, "T11.7 回退后应恢复第一份手动档")
	_cleanup_candidate_paths()
	SaveManager.prepare_new_game()
	SaveManager.set_auto_save_enabled(false)

func _test_manual_and_auto_coexist() -> void:
	var manual_path := "user://save_stability_manual.json"
	var auto_path := "user://save_stability_auto.json"
	_cleanup_path(manual_path)
	_cleanup_path(auto_path)
	SaveManager._write_save_atomically(manual_path, {"version": SaveManager.SAVE_VERSION, "money": 111})
	SaveManager._write_save_atomically(auto_path, {"version": SaveManager.SAVE_VERSION, "money": 222})
	var manual_result := _read_test_file(manual_path)
	var auto_result := _read_test_file(auto_path)
	_check(int(manual_result.get("data", {}).get("money", 0)) == 111, "T10.1 手动档应独立保留")
	_check(int(auto_result.get("data", {}).get("money", 0)) == 222, "T10.2 自动档应独立保留")
	_cleanup_path(manual_path)
	_cleanup_path(auto_path)
