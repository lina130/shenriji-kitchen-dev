class_name TalentParkSave
extends RefCounted

const SAVE_PATH := "user://talent_park_mvp.json"
const SAVE_VERSION := 1


func load_state(path: String = SAVE_PATH) -> Dictionary:
	var primary := _read_verified(path)
	if not primary.is_empty():
		return primary
	var backup := _read_verified(path + ".bak")
	if not backup.is_empty():
		_recover_primary_from_backup(path)
		return backup
	return _defaults()


func save_state(state: Dictionary, path: String = SAVE_PATH) -> bool:
	var normalized := _normalize(state)
	var payload := JSON.stringify(normalized)
	var envelope := JSON.stringify({
		"version": SAVE_VERSION,
		"payload": payload,
		"sha256": payload.sha256_text()
	})
	var temp_path := path + ".tmp"
	if not _ensure_directory(path):
		return false
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(envelope)
	file.flush()
	file.close()
	if _read_verified(temp_path).is_empty():
		_remove_if_exists(temp_path)
		return false
	var primary_exists := FileAccess.file_exists(path)
	if primary_exists and not _read_verified(path).is_empty():
		if not _remove_if_exists(path + ".bak"):
			_remove_if_exists(temp_path)
			return false
		if DirAccess.rename_absolute(_absolute(path), _absolute(path + ".bak")) != OK:
			_remove_if_exists(temp_path)
			return false
	elif primary_exists and not _remove_if_exists(path):
		_remove_if_exists(temp_path)
		return false
	if DirAccess.rename_absolute(_absolute(temp_path), _absolute(path)) != OK:
		return false
	return true


func _read_verified(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var envelope_parser := JSON.new()
	var parse_result := envelope_parser.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		return {}
	var envelope = envelope_parser.data
	if not envelope is Dictionary or int(envelope.get("version", 0)) != SAVE_VERSION:
		return {}
	var payload = envelope.get("payload", null)
	var checksum = envelope.get("sha256", null)
	if not payload is String or not checksum is String or payload.sha256_text() != checksum:
		return {}
	var payload_parser := JSON.new()
	if payload_parser.parse(payload) != OK:
		return {}
	var decoded = payload_parser.data
	if not _is_valid_state(decoded):
		return {}
	return _normalize(decoded)


func _is_valid_state(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for field in ["cash", "energy", "day", "position", "restaurant", "purchases"]:
		if not value.has(field):
			return false
	if not _is_whole_number(value["cash"]) or int(value["cash"]) < 0:
		return false
	if not _is_whole_number(value["energy"]) or int(value["energy"]) < 0 or int(value["energy"]) > 100:
		return false
	if not _is_whole_number(value["day"]) or int(value["day"]) < 1:
		return false
	if not value["restaurant"] is Dictionary or not value["purchases"] is Dictionary:
		return false
	return _position_or_empty(value["position"]).size() == 3 or (value["position"] is Array and value["position"].is_empty())


func _normalize(state: Dictionary) -> Dictionary:
	return {
		"cash": maxi(0, _safe_int(state.get("cash", 120), 120)),
		"energy": clampi(_safe_int(state.get("energy", 100), 100), 0, 100),
		"day": maxi(1, _safe_int(state.get("day", 1), 1)),
		"position": _position_or_empty(state.get("position", [])),
		"next_shift_mode": str(state.get("next_shift_mode", "calm")) if str(state.get("next_shift_mode", "calm")) in ["calm", "rush"] else "calm",
		"restaurant": _json_safe_dict(state.get("restaurant", {})),
		"purchases": _json_safe_dict(state.get("purchases", {}))
	}


func _defaults() -> Dictionary:
	return {"cash": 120, "energy": 100, "day": 1, "position": [], "next_shift_mode": "calm",
		"restaurant": {}, "purchases": {}}


func _position_or_empty(value: Variant) -> Array:
	var coordinates: Array = []
	if value is Vector3:
		coordinates = [value.x, value.y, value.z]
	elif value is Array and value.size() == 3:
		coordinates = value
	else:
		return []
	var result: Array = []
	for coordinate in coordinates:
		if typeof(coordinate) != TYPE_INT and typeof(coordinate) != TYPE_FLOAT:
			return []
		var number := float(coordinate)
		if is_nan(number) or is_inf(number):
			return []
		result.append(number)
	return result


func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return int(number)


func _is_whole_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and floorf(number) == number


func _json_safe_dict(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	return _json_safe(value, 0) as Dictionary


func _json_safe(value: Variant, depth: int) -> Variant:
	if depth > 16:
		return null
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			return value if not is_nan(value) and not is_inf(value) else null
		TYPE_ARRAY:
			var safe_array: Array = []
			for entry in value:
				safe_array.append(_json_safe(entry, depth + 1))
			return safe_array
		TYPE_DICTIONARY:
			var safe_dict: Dictionary = {}
			for key in value.keys():
				safe_dict[str(key)] = _json_safe(value[key], depth + 1)
			return safe_dict
		_:
			return null


func _recover_primary_from_backup(path: String) -> void:
	if not _ensure_directory(path):
		return
	var temp_path := path + ".tmp"
	_remove_if_exists(temp_path)
	if DirAccess.copy_absolute(_absolute(path + ".bak"), _absolute(temp_path)) != OK:
		return
	if _read_verified(temp_path).is_empty():
		_remove_if_exists(temp_path)
		return
	if not _remove_if_exists(path):
		return
	DirAccess.rename_absolute(_absolute(temp_path), _absolute(path))


func _ensure_directory(path: String) -> bool:
	return DirAccess.make_dir_recursive_absolute(_absolute(path).get_base_dir()) == OK


func _remove_if_exists(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(_absolute(path)) == OK


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
