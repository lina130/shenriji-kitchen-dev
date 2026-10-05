extends Node

signal minute_changed(minute_of_day: int)
signal day_started(day_number: int)
signal late_night_reached
signal paused_changed(is_paused: bool)

const MINUTES_PER_DAY := 1440
const DEFAULT_REAL_SECONDS_PER_GAME_MINUTE := 2.0
const MAX_TIME_SCALE := 2.0

var current_day := 1
var minute_of_day := 7 * 60
var real_seconds_per_game_minute := DEFAULT_REAL_SECONDS_PER_GAME_MINUTE
var paused := false
var time_scale := 1.0
var _minute_accumulator := 0.0

func _ready() -> void:
	_load_time_config()

func _load_time_config() -> void:
	real_seconds_per_game_minute = maxf(0.1, ConfigDB.get_number("balance", "real_seconds_per_game_minute", DEFAULT_REAL_SECONDS_PER_GAME_MINUTE))

func set_real_seconds_per_game_minute(value: float) -> void:
	real_seconds_per_game_minute = maxf(0.1, value)
var _late_night_reported := false

func _process(delta: float) -> void:
	if paused:
		return
	_minute_accumulator += delta / real_seconds_per_game_minute * time_scale
	var whole_minutes := int(floor(_minute_accumulator))
	if whole_minutes <= 0:
		return
	_minute_accumulator -= float(whole_minutes)
	advance_minutes(whole_minutes)

func advance_minutes(amount: int) -> void:
	var remaining := maxi(0, amount)
	while remaining > 0:
		var until_midnight := MINUTES_PER_DAY - minute_of_day
		if remaining >= until_midnight:
			minute_of_day = MINUTES_PER_DAY
			remaining -= until_midnight
			_check_late_night()
			_begin_next_day()
		else:
			minute_of_day += remaining
			remaining = 0
			_check_late_night()
			minute_changed.emit(minute_of_day)

func sleep_to_next_morning(hour: int = 7) -> void:
	current_day += 1
	minute_of_day = clampi(hour, 0, 23) * 60
	_minute_accumulator = 0.0
	_late_night_reported = false
	day_started.emit(current_day)
	minute_changed.emit(minute_of_day)

func reset_new_game() -> void:
	current_day = 1
	minute_of_day = 7 * 60
	_minute_accumulator = 0.0
	_late_night_reported = false
	paused = false
	time_scale = 1.0
	day_started.emit(current_day)
	minute_changed.emit(minute_of_day)
	paused_changed.emit(false)

func set_time_scale(value: float) -> void:
	time_scale = clampf(value, 0.02, MAX_TIME_SCALE)

func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	paused_changed.emit(paused)

func get_day_name() -> String:
	const DAY_NAMES := ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
	return DAY_NAMES[(current_day - 1) % DAY_NAMES.size()]

func get_time_text() -> String:
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]

func get_period_name() -> String:
	var hour := int(minute_of_day / 60)
	if hour < 6:
		return "深夜"
	if hour < 9:
		return "清晨"
	if hour < 12:
		return "上午"
	if hour < 14:
		return "中午"
	if hour < 18:
		return "下午"
	if hour < 21:
		return "傍晚"
	return "夜晚"

func get_daylight() -> float:
	var hour := float(minute_of_day) / 60.0
	if hour <= 5.0 or hour >= 21.0:
		return 0.0
	if hour < 7.0:
		return (hour - 5.0) / 2.0
	if hour > 19.0:
		return 1.0 - ((hour - 19.0) / 2.0)
	return 1.0

func _begin_next_day() -> void:
	current_day += 1
	minute_of_day = 0
	_minute_accumulator = 0.0
	_late_night_reported = false
	day_started.emit(current_day)
	minute_changed.emit(minute_of_day)

func _check_late_night() -> void:
	if minute_of_day >= 120 and not _late_night_reported:
		_late_night_reported = true
		late_night_reached.emit()

func get_save_data() -> Dictionary:
	return {
		"current_day": current_day,
		"minute_of_day": minute_of_day,
		"paused": paused,
		"time_scale": time_scale,
	}

func restore(data: Dictionary) -> void:
	current_day = maxi(1, int(data.get("current_day", 1)))
	minute_of_day = clampi(int(data.get("minute_of_day", 420)), 0, 1439)
	_minute_accumulator = 0.0
	_late_night_reported = minute_of_day >= 120
	paused = bool(data.get("paused", false))
	time_scale = clampf(float(data.get("time_scale", 1.0)), 0.02, MAX_TIME_SCALE)
	day_started.emit(current_day)
	minute_changed.emit(minute_of_day)
	paused_changed.emit(paused)