extends Node

signal money_changed(amount: int)
signal energy_changed(value: float)
signal visual_state_changed(dim_strength: float, speed_multiplier: float)
signal player_action_completed(action_id: String)
signal monthly_summary_ready(summary: Dictionary)

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
var clerk_wage := 95
var clerk_shift_minutes := 300
var clerk_energy_cost := 20.0
var study_minutes := 120
var study_energy_cost := 10.0
var exercise_minutes := 90
var exercise_energy_cost := 18.0

var money := STARTING_MONEY
var energy := 100.0
var max_energy := 100.0
var health := 100.0
var rent_arrears := 0
var current_area := "home"
var spawn_id := "start"
var input_locked := false
var hidden_luck := 0.0
var hidden_reputation := 0.0
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
	ProgressionManager.record_money(amount, false)
	money_changed.emit(money)
	if not reason.is_empty():
		NoticeManager.show_message(reason)
	return true

func earn(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	money += amount
	ProgressionManager.record_money(amount, true)
	money_changed.emit(money)
	if not reason.is_empty():
		NoticeManager.show_message(reason, "positive")

func change_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	energy_changed.emit(energy)
	visual_state_changed.emit(get_visual_dim(), get_speed_multiplier())

func get_visual_dim() -> float:
	var normalized := energy / maxf(1.0, max_energy)
	if normalized >= 0.55:
		return clampf((0.55 - normalized) * 0.12, 0.0, 0.05)
	return clampf((0.55 - normalized) * 0.88, 0.0, 0.42)

func get_speed_multiplier() -> float:
	var normalized := energy / maxf(1.0, max_energy)
	var base := 1.0 if normalized >= 0.5 else lerpf(0.62, 1.0, normalized / 0.5)
	return base + ProgressionManager.get_speed_bonus()

func can_work_factory() -> bool:
	return CareerManager.can_work("factory") and TimeSystem.minute_of_day >= 7 * 60 and TimeSystem.minute_of_day <= 18 * 60

func can_work_clerk() -> bool:
	return false
func work_factory_shift() -> void:
	if health <= 20.0:
		NoticeManager.show_message("身体已经吃不消了，先去诊所看看。", "warning", "诊所护士")
		return
	if not can_work_factory():
		NoticeManager.show_message("工厂今天已经收工了，明早再来吧。", "warning")
		return
	var energy_cost := factory_energy_cost * WeatherSystem.get_work_energy_multiplier() * ProgressionManager.get_work_energy_multiplier()
	if energy < energy_cost:
		NoticeManager.show_message("实在太累了，今天干不动重活了。", "warning")
		return
	var shift_quality := CareerManager.evaluate_shift_quality()
	change_energy(-energy_cost)
	TimeSystem.advance_minutes(factory_shift_minutes)
	var wage := int(round((factory_wage + ProgressionManager.get_factory_wage_bonus()) * CareerManager.get_shift_wage_multiplier() * (1.0 + WellbeingManager.get_action_bonus("work"))))
	earn(wage, "今天的工钱到手了：¥%d" % wage)
	ProgressionManager.record_work("factory")
	CareerManager.record_shift("factory", shift_quality)
	AchievementManager.record_event("career_route:factory")
	NoticeManager.show_message(CareerManager.get_manager_hint(), "hint")
	TreasureManager.try_trigger("work_shift")
	player_action_completed.emit("factory_shift")

func work_career_shift(line_id: String) -> void:
	if health <= 20.0:
		NoticeManager.show_message("身体已经吃不消了，先去诊所看看。", "warning", "诊所护士")
		return
	if not CareerManager.can_work(line_id):
		NoticeManager.show_message("还没有正式入职这条路线，先去找招聘牌应聘。", "warning")
		return
	var line_config := {
		"office": {"minutes": 480, "energy": 28.0, "wage": 150},
		"study": {"minutes": 240, "energy": 18.0, "wage": 0},
		"public": {"minutes": 420, "energy": 22.0, "wage": 135},
		"freelance": {"minutes": 360, "energy": 24.0, "wage": 120},
		"logistics": {"minutes": 420, "energy": 26.0, "wage": 135},
		"craft": {"minutes": 390, "energy": 24.0, "wage": 140},
	}
	var config: Dictionary = line_config.get(line_id, {"minutes": 360, "energy": 24.0, "wage": 100})
	var energy_cost := float(config["energy"]) * WeatherSystem.get_work_energy_multiplier() * ProgressionManager.get_work_energy_multiplier()
	if energy < energy_cost:
		NoticeManager.show_message("今天状态太差，先吃口东西休息一下。", "warning")
		return
	var shift_quality := CareerManager.evaluate_shift_quality()
	change_energy(-energy_cost)
	TimeSystem.advance_minutes(int(config["minutes"]))
	var base_wage := int(config["wage"])
	var credential_bonus := EducationManager.get_career_bonus(line_id) + HobbyManager.get_career_bonus(line_id)
	var wage := int(round(float(base_wage) * CareerManager.get_shift_wage_multiplier() * (1.0 + WellbeingManager.get_action_bonus("work") + credential_bonus))) if base_wage > 0 else 0
	if wage > 0:
		earn(wage, "今天这份工作结了 ¥%d。" % wage)
	ProgressionManager.record_work(line_id)
	CareerManager.record_shift(line_id, shift_quality)
	AchievementManager.record_event("career_route:" + line_id)
	NoticeManager.show_message(CareerManager.get_manager_hint(), "hint")
	TreasureManager.try_trigger("work_shift")
	player_action_completed.emit(line_id + "_shift")

func work_clerk_shift() -> void:
	NoticeManager.show_message("现在只开放餐饮和工厂两条职业线，便利店不会再招长期兼职。", "hint")

func study_at_desk() -> void:
	if TimeSystem.minute_of_day < 7 * 60 or TimeSystem.minute_of_day > 23 * 60:
		NoticeManager.show_message("这个点该歇歇了，书也看不进去。", "warning")
		return
	if energy < study_energy_cost:
		NoticeManager.show_message("脑子有点转不动，先吃点东西吧。", "warning")
		return
	change_energy(-study_energy_cost)
	TimeSystem.advance_minutes(study_minutes)
	NoticeManager.show_message(ProgressionManager.record_study(), "positive")
	player_action_completed.emit("study")

func exercise_at_park() -> void:
	if TimeSystem.minute_of_day < 6 * 60 or TimeSystem.minute_of_day > 21 * 60:
		NoticeManager.show_message("公园器材那边已经安静下来了。", "warning")
		return
	if energy < exercise_energy_cost:
		NoticeManager.show_message("今天一点劲儿都提不起来，先缓一缓。", "warning")
		return
	change_energy(-exercise_energy_cost)
	TimeSystem.advance_minutes(exercise_minutes)
	if ProgressionManager.fitness_sessions > 0 and ProgressionManager.fitness_sessions % 7 == 0:
		max_energy = minf(112.0, max_energy + 2.0)
	NoticeManager.show_message(ProgressionManager.record_exercise(), "positive")
	player_action_completed.emit("exercise")

func sleep_to_next_day() -> void:
	var hour := TimeSystem.minute_of_day / 60
	var can_sleep := hour >= 22 or hour < 6
	if not can_sleep:
		NoticeManager.show_message("天还亮着，晚一点再收拾睡觉吧。", "warning")
		return
	energy = minf(120.0, max_energy + HousingManager.get_bonus("energy") + FamilyManager.get_bonus("energy"))
	health = minf(100.0, health + 2.0)
	TimeSystem.sleep_to_next_morning(7)
	energy_changed.emit(energy)
	visual_state_changed.emit(get_visual_dim(), get_speed_multiplier())
	NoticeManager.show_message("一觉醒来，窗外又是新的一天。", "positive")
	player_action_completed.emit("sleep")

func on_item_used(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	WellbeingManager.consume_item(item_id)
	if item_id in ["photo_frame", "warm_blanket"]:
		RoomManager.install_decor(item_id)
		return
	var energy_gain := float(item.get("energy", 0.0))
	if energy_gain > 0.0:
		change_energy(energy_gain)
	NoticeManager.show_message("吃下去舒服多了。" if item.get("kind") == "food" else "喝一口，缓过来了。", "positive")
	player_action_completed.emit("use_item")

func on_collection_collected(_item_id: String, rarity: String) -> void:
	CollectionManager.total_collected += 1
	hidden_luck = minf(100.0, hidden_luck + (4.0 if rarity == "legendary" else 1.0))
	hidden_reputation = minf(100.0, hidden_reputation + 0.3)
	ProgressionManager.record_collection(rarity)
	player_action_completed.emit("collection")

func get_collection_luck_bonus() -> float:
	return minf(0.55, hidden_luck * 0.006 + WeatherSystem.get_collection_bonus())

func get_hidden_reputation() -> float:
	return hidden_reputation
func _on_day_started(day_number: int) -> void:
	InventoryManager.sell_shipping_bin()
	RandomManager.begin_new_day(day_number)
	CalendarManager.announce_today()
	WeatherSystem.begin_new_day(day_number)
	CollectionManager.refresh_for_day(day_number)
	RelationshipManager.begin_new_day(day_number)
	MarketEconomyManager.begin_new_day(day_number)
	NightMarketManager.begin_new_day(day_number)
	FarmManager.begin_new_day(day_number)
	PetManager.begin_new_day(day_number)
	StaffManager.begin_new_day(day_number)
	BusinessManager.begin_new_day(day_number)
	EnterpriseManager.begin_new_day(day_number)
	WellbeingManager.begin_new_day(day_number)
	FamilyManager.begin_new_day(day_number)
	StoryManager.begin_new_day(day_number)
	EndingManager.begin_new_day(day_number)
	FinanceManager.begin_new_day(day_number)
	_low_energy_warned_on_day = -1
	if day_number > 1 and day_number % rent_interval_days == 0:
		_charge_rent()
	player_action_completed.emit("new_day")

func _on_minute_changed(_minute_of_day: int) -> void:
	if energy <= max_energy * 0.25 and _low_energy_warned_on_day != TimeSystem.current_day:
		_low_energy_warned_on_day = TimeSystem.current_day
		NoticeManager.show_message("有点累了，找个地方歇歇吧。", "warning")

func _on_late_night_reached() -> void:
	NoticeManager.show_message("眼皮越来越沉……该回家了。", "warning")

func _charge_rent() -> void:
	var remaining := rent_amount
	if money >= remaining:
		money -= remaining
		ProgressionManager.record_money(remaining, false)
		money_changed.emit(money)
		NoticeManager.show_message("新一期房租已交：¥%d" % rent_amount, "normal")
	else:
		var paid := money
		remaining -= paid
		money = 0
		rent_arrears += remaining
		ProgressionManager.record_money(paid, false)
		money_changed.emit(money)
		NoticeManager.show_message("房租还差一点，房东说晚些再补。", "warning")
	_emit_month_summary()
	ProgressionManager.begin_new_month()

func _emit_month_summary() -> void:
	monthly_summary_ready.emit({
		"month": int((TimeSystem.current_day - 1) / rent_interval_days),
		"earned": ProgressionManager.month_earned,
		"spent": ProgressionManager.month_spent,
		"collected": ProgressionManager.month_collected,
		"workdays": ProgressionManager.month_workdays,
		"social": ProgressionManager.month_social_actions,
		"arrears": rent_arrears,
	})

func _load_balance_config() -> void:
	starting_money = int(ConfigDB.get_number("balance", "starting_money", STARTING_MONEY))
	rent_amount = int(ConfigDB.get_number("balance", "rent_amount", RENT_AMOUNT))
	rent_interval_days = maxi(1, int(ConfigDB.get_number("balance", "rent_interval_days", RENT_INTERVAL_DAYS)))
	factory_wage = int(ConfigDB.get_number("balance", "factory_wage", FACTORY_WAGE))
	factory_shift_minutes = int(ConfigDB.get_number("balance", "factory_shift_minutes", FACTORY_SHIFT_MINUTES))
	factory_energy_cost = ConfigDB.get_number("balance", "factory_energy_cost", FACTORY_ENERGY_COST)
	clerk_wage = int(ConfigDB.get_number("balance", "clerk_wage", 95))
	clerk_shift_minutes = int(ConfigDB.get_number("balance", "clerk_shift_minutes", 300))
	clerk_energy_cost = ConfigDB.get_number("balance", "clerk_energy_cost", 20.0)
	study_minutes = int(ConfigDB.get_number("balance", "study_minutes", 120))
	study_energy_cost = ConfigDB.get_number("balance", "study_energy_cost", 10.0)
	exercise_minutes = int(ConfigDB.get_number("balance", "exercise_minutes", 90))
	exercise_energy_cost = ConfigDB.get_number("balance", "exercise_energy_cost", 18.0)
	money = starting_money

func reset_new_game() -> void:
	SaveManager.prepare_new_game()
	_load_balance_config()
	energy = 100.0
	max_energy = 100.0
	health = 100.0
	rent_arrears = 0
	current_area = "home"
	spawn_id = "start"
	input_locked = false
	hidden_luck = 0.0
	hidden_reputation = 0.0
	InventoryManager.reset_new_game()
	ProgressionManager.reset_new_game()
	RelationshipManager.reset_new_game()
	MarketEconomyManager.reset_new_game()
	ExpeditionManager.reset_new_game()
	BusinessManager.reset_new_game()
	FarmManager.reset_new_game()
	PetManager.reset_new_game()
	RoomManager.reset_new_game()
	StaffManager.reset_new_game()
	CareerManager.reset_new_game()
	StoryManager.reset_new_game()
	FishingManager.reset_new_game()
	HousingManager.reset_new_game()
	TravelManager.reset_new_game()
	EnterpriseManager.reset_new_game()
	AchievementManager.reset_new_game()
	PlatformIntegrationManager.reset_new_game()
	FamilyManager.reset_new_game()
	WellbeingManager.reset_new_game()
	UnlockManager.reset_new_game()
	MedicalManager.reset_new_game()
	EducationManager.reset_new_game()
	EndingManager.reset_new_game()
	HobbyManager.reset_new_game()
	PhotoManager.reset_new_game()
	FestivalManager.reset_new_game()
	NightMarketManager.reset_new_game()
	NpcStoryManager.reset_new_game()
	WardrobeManager.reset_new_game()
	FinanceManager.reset_new_game()
	TreasureManager.reset_new_game()
	KitchenManager.reset_new_game()
	TimeSystem.reset_new_game()
	WeatherSystem.begin_new_day(1)
	CollectionManager.reset_new_game()
	SceneRouter.restore("home", "start")
	_emit_all()

func _emit_all() -> void:
	money_changed.emit(money)
	energy_changed.emit(energy)
	visual_state_changed.emit(get_visual_dim(), get_speed_multiplier())

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"energy": energy,
		"max_energy": max_energy,
		"health": health,
		"rent_arrears": rent_arrears,
		"current_area": current_area,
		"spawn_id": spawn_id,
		"hidden_luck": hidden_luck,
		"hidden_reputation": hidden_reputation,
	}

func restore(data: Dictionary) -> void:
	money = maxi(0, int(data.get("money", starting_money)))
	energy = clampf(float(data.get("energy", 100.0)), 0.0, 120.0)
	max_energy = clampf(float(data.get("max_energy", 100.0)), 100.0, 120.0)
	health = clampf(float(data.get("health", 100.0)), 0.0, 100.0)
	rent_arrears = maxi(0, int(data.get("rent_arrears", 0)))
	current_area = str(data.get("current_area", "home"))
	spawn_id = str(data.get("spawn_id", "start"))
	hidden_luck = clampf(float(data.get("hidden_luck", 0.0)), 0.0, 100.0)
	hidden_reputation = clampf(float(data.get("hidden_reputation", 0.0)), 0.0, 100.0)
	_emit_all()