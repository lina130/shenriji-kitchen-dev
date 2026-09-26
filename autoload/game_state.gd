extends Node

signal money_changed(amount: int)
signal energy_changed(value: float)
signal visual_state_changed(dim_strength: float, speed_multiplier: float)
signal player_action_completed(action_id: String)

const STARTING_MONEY := 320
const RENT_AMOUNT := 800
const RENT_INTERVAL_DAYS := 30
const FACTORY_WAGE := 180
const FACTORY_SHIFT_MINUTES := 8 * 60
const FACTORY_ENERGY_COST := 32.0

var starting_money := STARTING_MONEY
var rent_amount := RENT_AMOUNT
var rent_interval_days := RENT_INTERVAL_DAYS
var factory_wage := FACTORY_WAGE
var factory_shift_minutes := FACTORY_SHIFT_MINUTES
var factory_energy_cost := FACTORY_ENERGY_COST

var money := STARTING_MONEY
var energy := 100.0
var health := 100.0
var rent_arrears := 0
var current_area := "home"
var spawn_id := "start"
var input_locked := false
var _low_energy_warned_on_day := -1

func _ready() -> void:
	_load_balance_config()
	TimeSystem.day_started.connect(_on_day_started)
	TimeSystem.minute_changed.connect(_on_minute_changed)
	TimeSystem.late_night_reached.connect(_on_late_night_reached)
	_emit_all()

func spend(amount: int, reason: String = "") -> bool:
	if amount <= 0:
		return true
	if money < amount:
		NoticeManager.show_message("钱不够，先想办法赚一点吧。", "warning")
		return false
	money -= amount
	money_changed.emit(money)
	if not reason.is_empty():
		NoticeManager.show_message(reason)
	return true

func earn(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)
	if not reason.is_empty():
		NoticeManager.show_message(reason, "positive")

func change_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, 100.0)
	energy_changed.emit(energy)
	visual_state_changed.emit(get_visual_dim(), get_speed_multiplier())

func get_visual_dim() -> float:
	if energy >= 55.0:
		return clampf((55.0 - energy) * 0.002, 0.0, 0.05)
	return clampf((55.0 - energy) * 0.009, 0.0, 0.42)

func get_speed_multiplier() -> float:
	if energy >= 50.0:
		return 1.0
	return lerpf(0.62, 1.0, energy / 50.0)

func can_work_factory() -> bool:
	return TimeSystem.minute_of_day >= 7 * 60 and TimeSystem.minute_of_day <= 18 * 60

func work_factory_shift() -> void:
	if not can_work_factory():
		NoticeManager.show_message("工厂今天已经收工了，明早再来吧。", "warning")
		return
	if energy < 30.0:
		NoticeManager.show_message("实在太累了，今天干不动重活了。", "warning")
		return
	change_energy(-factory_energy_cost)
	TimeSystem.advance_minutes(factory_shift_minutes)
	earn(factory_wage, "今天的工钱到手了：¥%d" % factory_wage)
	player_action_completed.emit("factory_shift")

func sleep_to_next_day() -> void:
	var hour := TimeSystem.minute_of_day / 60
	var can_sleep := hour >= 22 or hour < 6
	if not can_sleep:
		NoticeManager.show_message("天还亮着，晚一点再收拾睡觉吧。", "warning")
		return
	energy = 100.0
	health = minf(100.0, health + 2.0)
	TimeSystem.sleep_to_next_morning(7)
	energy_changed.emit(energy)
	visual_state_changed.emit(get_visual_dim(), get_speed_multiplier())
	NoticeManager.show_message("一觉醒来，窗外又是新的一天。", "positive")
	player_action_completed.emit("sleep")

func on_item_used(item: Dictionary) -> void:
	var energy_gain := float(item.get("energy", 0.0))
	if energy_gain > 0.0:
		change_energy(energy_gain)
	NoticeManager.show_message("吃下去舒服多了。" if item.get("kind") == "food" else "喝一口，缓过来了。", "positive")
	player_action_completed.emit("use_item")

func _on_day_started(day_number: int) -> void:
	RandomManager.begin_new_day(day_number)
	_low_energy_warned_on_day = -1
	if day_number % rent_interval_days == 0:
		_charge_rent()
	player_action_completed.emit("new_day")

func _on_minute_changed(_minute_of_day: int) -> void:
	if energy <= 25.0 and _low_energy_warned_on_day != TimeSystem.current_day:
		_low_energy_warned_on_day = TimeSystem.current_day
		NoticeManager.show_message("有点累了，找个地方歇歇吧。", "warning")

func _on_late_night_reached() -> void:
	NoticeManager.show_message("眼皮越来越沉……该回家了。", "warning")

func _charge_rent() -> void:
	var remaining := rent_amount
	if money >= remaining:
		money -= remaining
		money_changed.emit(money)
		NoticeManager.show_message("新一期房租已交：¥%d" % rent_amount, "normal")
	else:
		var paid := money
		remaining -= paid
		money = 0
		rent_arrears += remaining
		money_changed.emit(money)
		NoticeManager.show_message("房租还差一点，房东说晚些再补。", "warning")

func _load_balance_config() -> void:
	starting_money = int(ConfigDB.get_number("balance", "starting_money", STARTING_MONEY))
	rent_amount = int(ConfigDB.get_number("balance", "rent_amount", RENT_AMOUNT))
	rent_interval_days = maxi(1, int(ConfigDB.get_number("balance", "rent_interval_days", RENT_INTERVAL_DAYS)))
	factory_wage = int(ConfigDB.get_number("balance", "factory_wage", FACTORY_WAGE))
	factory_shift_minutes = int(ConfigDB.get_number("balance", "factory_shift_minutes", FACTORY_SHIFT_MINUTES))
	factory_energy_cost = ConfigDB.get_number("balance", "factory_energy_cost", FACTORY_ENERGY_COST)
	money = starting_money

func _emit_all() -> void:
	money_changed.emit(money)
	energy_changed.emit(energy)
	visual_state_changed.emit(get_visual_dim(), get_speed_multiplier())

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"energy": energy,
		"health": health,
		"rent_arrears": rent_arrears,
		"current_area": current_area,
		"spawn_id": spawn_id,
	}

func restore(data: Dictionary) -> void:
	money = maxi(0, int(data.get("money", starting_money)))
	energy = clampf(float(data.get("energy", 100.0)), 0.0, 100.0)
	health = clampf(float(data.get("health", 100.0)), 0.0, 100.0)
	rent_arrears = maxi(0, int(data.get("rent_arrears", 0)))
	current_area = str(data.get("current_area", "home"))
	spawn_id = str(data.get("spawn_id", "start"))
	_emit_all()