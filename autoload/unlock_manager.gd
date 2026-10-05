extends Node

signal changed
signal unlocked(level_id: int, name: String)

var current_level := 0
var force_unlock_all := false

func _ready() -> void:
	force_unlock_all = _is_test_process()
	CareerManager.changed.connect(_evaluate)
	BusinessManager.changed.connect(_evaluate)
	StoryManager.changed.connect(_evaluate)
	TimeSystem.day_started.connect(_on_day_started)
	_evaluate()

func reset_new_game() -> void:
	current_level = 0 if not force_unlock_all else 4
	changed.emit()

func can_access(area_id: String) -> bool:
	if force_unlock_all:
		return true
	match area_id:
		"home", "street", "commercial_district", "industrial_district":
			return true
		"suburb":
			return current_level >= 1
		"riverside":
			return current_level >= 2
		"bus_station", "seaside_resort", "ancient_village":
			return current_level >= 3
		"mountain_spring":
			return current_level >= 4
	return true

func get_hint(area_id: String) -> String:
	match area_id:
		"suburb":
			return "先在城里找一份稳定工作，或再熬几天，城郊公交才会常开。"
		"riverside":
			return "等生活稳定、开始自己的经营后，河边绿道才会成为日常路线。"
		"bus_station":
			return "先把一家店真正做起来，才有力气去更远的地方。"
	return "这条路线还没到开放的时候。"

func _on_day_started(_day_number: int) -> void:
	_evaluate()

func _evaluate() -> void:
	if force_unlock_all:
		_set_level(4)
		return
	var candidate := 0
	if CareerManager.is_employed() or TimeSystem.current_day >= 3:
		candidate = maxi(candidate, 1)
	if StoryManager.chapter >= 2:
		candidate = maxi(candidate, 2)
	if BusinessManager.business_level >= 1:
		candidate = maxi(candidate, 3)
	if TimeSystem.current_day >= 14:
		candidate = maxi(candidate, 4)
	_set_level(candidate)

func _set_level(value: int) -> void:
	var new_level := clampi(value, 0, 4)
	if new_level == current_level:
		return
	current_level = new_level
	var row := ConfigDB.get_row("unlock_levels", str(current_level))
	NoticeManager.show_message("生活范围扩大了：%s。" % str(row.get("description", "")), "positive", "梅姨")
	unlocked.emit(current_level, str(row.get("name", "新区域")))
	changed.emit()

func get_summary() -> String:
	var row := ConfigDB.get_row("unlock_levels", str(current_level))
	return "当前生活圈：%s" % str(row.get("name", "城中村起步"))

func _is_test_process() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			return true
	return false

func get_save_data() -> Dictionary:
	return {"current_level": current_level}

func restore(data: Dictionary) -> void:
	current_level = int(data.get("current_level", 0))
	_evaluate()
	changed.emit()
