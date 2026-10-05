extends Node

## 早市/午市/晚市轮换。营业地点和菜单池都由这里统一判定。

signal phase_changed(phase_id: String, previous_phase_id: String)

var current_phase_id := ""

func _ready() -> void:
	TimeSystem.minute_changed.connect(_on_minute_changed)
	TimeSystem.day_started.connect(_on_day_started)
	current_phase_id = get_phase_at_minute(TimeSystem.minute_of_day)

func _on_day_started(_day_number: int) -> void:
	_refresh_phase()

func _on_minute_changed(_minute_of_day: int) -> void:
	_refresh_phase()

func _refresh_phase() -> void:
	var next_phase := get_phase_at_minute(TimeSystem.minute_of_day)
	if next_phase == current_phase_id:
		return
	var previous := current_phase_id
	current_phase_id = next_phase
	if KitchenManager.active:
		KitchenManager.on_market_phase_changed(current_phase_id, previous)
	phase_changed.emit(current_phase_id, previous)

func force_refresh() -> void:
	current_phase_id = ""
	_refresh_phase()

func get_phase_at_minute(minute_of_day: int = -1) -> String:
	var minute := TimeSystem.minute_of_day if minute_of_day < 0 else minute_of_day
	for phase_id in ["morning", "lunch", "dinner"]:
		var row := ConfigDB.get_row("market_phases", phase_id)
		if row.is_empty():
			continue
		if minute >= int(row.get("start_minute", "0")) and minute < int(row.get("end_minute", "1440")):
			return phase_id
	return ""

func get_phase_row(phase_id: String = "") -> Dictionary:
	var resolved := current_phase_id if phase_id.is_empty() else phase_id
	if resolved.is_empty():
		return {}
	return ConfigDB.get_row("market_phases", resolved)

func get_phase_name(phase_id: String = "") -> String:
	var row := get_phase_row(phase_id)
	return str(row.get("name", "休市")) if not row.is_empty() else "休市"

func is_location_open(location_id: String, phase_id: String = "") -> bool:
	var row := get_phase_row(phase_id)
	if row.is_empty():
		return false
	var locations := str(row.get("locations", "")).split("|", false)
	return location_id in locations

func can_start_shift(location_id: String) -> bool:
	return not current_phase_id.is_empty() and is_location_open(location_id)

func get_current_recipe_ids() -> Array[String]:
	var result: Array[String] = []
	if current_phase_id.is_empty():
		return result
	for recipe_id in ConfigDB.get_rows("recipes"):
		var phases := str(ConfigDB.get_row("recipes", recipe_id).get("phases", "")).split("|", false)
		if current_phase_id in phases:
			result.append(str(recipe_id))
	return result

func get_festival_recipe_ids() -> Array[String]:
	var result: Array[String] = []
	var day_key := str(CalendarManager.get_day_of_year())
	for recipe_id in ConfigDB.get_rows("festival_menu"):
		var row := ConfigDB.get_row("festival_menu", recipe_id)
		if str(row.get("calendar_day", "")) == day_key:
			result.append(str(recipe_id))
	return result

func get_festival_bonus(recipe_id: String) -> float:
	var row := ConfigDB.get_row("festival_menu", recipe_id)
	if row.is_empty():
		return 0.0
	return float(row.get("price_bonus", "0"))

func get_next_phase_text() -> String:
	var minute := TimeSystem.minute_of_day
	for phase_id in ["morning", "lunch", "dinner"]:
		var row := ConfigDB.get_row("market_phases", phase_id)
		var start_minute := int(row.get("start_minute", "0"))
		if minute < start_minute:
			return "%s %02d:%02d 开市" % [str(row.get("name", phase_id)), start_minute / 60, start_minute % 60]
	return "明早 06:00 开市"

func get_price_multiplier(phase_id: String = "") -> float:
	return float(get_phase_row(phase_id).get("price_multiplier", "1.0"))

func get_demand_multiplier(phase_id: String = "") -> float:
	return float(get_phase_row(phase_id).get("demand_multiplier", "1.0"))

func is_rush_minute(minute_of_day: int = -1, phase_id: String = "") -> bool:
	var row := get_phase_row(phase_id)
	if row.is_empty():
		return false
	var minute := TimeSystem.minute_of_day if minute_of_day < 0 else minute_of_day
	var start_minute := int(row.get("rush_start_minute", "-1"))
	var end_minute := int(row.get("rush_end_minute", "-1"))
	return start_minute >= 0 and end_minute > start_minute and minute >= start_minute and minute < end_minute

func get_rush_name(phase_id: String = "") -> String:
	return str(get_phase_row(phase_id).get("rush_name", "客流高峰"))

func get_rush_spawn_multiplier(phase_id: String = "") -> float:
	return maxf(1.0, float(get_phase_row(phase_id).get("rush_spawn_multiplier", "1.0")))

func get_rush_patience_multiplier(phase_id: String = "") -> float:
	return clampf(float(get_phase_row(phase_id).get("rush_patience_multiplier", "1.0")), 0.5, 1.0)

func get_rush_tip_bonus(phase_id: String = "") -> float:
	return maxf(0.0, float(get_phase_row(phase_id).get("rush_tip_bonus", "0.0")))

func get_status_text() -> String:
	if current_phase_id.is_empty():
		return "休市 · %s" % get_next_phase_text()
	return "%s · %s" % [get_phase_name(), get_next_phase_text()]

func reset_new_game() -> void:
	current_phase_id = get_phase_at_minute(TimeSystem.minute_of_day)
