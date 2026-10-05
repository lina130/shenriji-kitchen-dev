extends Node

signal changed
signal condition_changed(condition_id: String, hint: String)

var condition_id := "refreshed"
var mood := 70.0
var stress := 20.0
var focus_bonus := 0.05
var work_bonus := 0.04
var social_bonus := 0.03

func _ready() -> void:
	_connect_runtime.call_deferred()

func _connect_runtime() -> void:
	if not SceneRouter.travel_completed.is_connected(_on_travel_completed):
		SceneRouter.travel_completed.connect(_on_travel_completed)
	if not GameState.player_action_completed.is_connected(_on_player_action):
		GameState.player_action_completed.connect(_on_player_action)

func reset_new_game() -> void:
	mood = 70.0
	stress = 20.0
	_apply_condition("refreshed", false)

func begin_new_day(_day_number: int) -> void:
	stress = maxf(0.0, stress - 10.0)
	match WeatherSystem.current_weather_id:
		"rain":
			mood = maxf(0.0, mood - 3.0)
			_apply_condition("rainy_low")
		"heat":
			mood = maxf(0.0, mood - 4.0)
			stress = minf(100.0, stress + 8.0)
			_apply_condition("heat_tired")
		_:
			_reevaluate()
	changed.emit()

func get_hint() -> String:
	var row := ConfigDB.get_row("life_conditions", condition_id)
	return str(row.get("hint", "今天的状态还算平稳。"))

func get_action_bonus(bonus_type: String) -> float:
	match bonus_type:
		"focus":
			return focus_bonus
		"work":
			return work_bonus
		"social":
			return social_bonus
	return 0.0

func relax(mood_gain: float, stress_drop: float) -> void:
	mood = clampf(mood + mood_gain, 0.0, 100.0)
	stress = clampf(stress - stress_drop, 0.0, 100.0)
	_reevaluate()

func grow_social_warmth(amount: float) -> void:
	mood = clampf(mood + amount, 0.0, 100.0)
	stress = clampf(stress - amount * 0.5, 0.0, 100.0)
	_reevaluate()

func consume_item(item_id: String) -> void:
	match item_id:
		"herbal_tea", "fruit_cup":
			mood = minf(100.0, mood + 5.0)
			stress = maxf(0.0, stress - 8.0)
		"coffee", "energy_bar":
			stress = minf(100.0, stress + 3.0)
			focus_bonus = minf(0.18, focus_bonus + 0.03)
		_:
			mood = minf(100.0, mood + 2.0)
	_reevaluate()

func _on_player_action(action_id: String) -> void:
	match action_id:
		"sleep":
			mood = minf(100.0, mood + 10.0)
			stress = maxf(0.0, stress - 20.0)
			_apply_condition("refreshed")
		"exercise":
			mood = minf(100.0, mood + 5.0)
			stress = maxf(0.0, stress - 8.0)
		"use_item":
			pass
		_:
			if action_id.ends_with("_shift") or action_id == "shift":
				stress = minf(100.0, stress + 6.0)
	_reevaluate()

func _on_travel_completed(_area_id: String, _spawn_id: String) -> void:
	if RandomManager.chance(0.12):
		var commute_roll := RandomManager.rng.randf()
		if commute_roll < 0.34:
			GameState.change_energy(-4.0)
			stress = minf(100.0, stress + 6.0)
			NoticeManager.show_scene_message("路上堵了一阵，到地方时已经有点累。", "通勤路上", "hint")
		elif commute_roll < 0.67:
			mood = minf(100.0, mood + 5.0)
			NoticeManager.show_scene_message("路边花开得正好，路上心情轻了些。", "街边", "positive")
		else:
			GameState.hidden_luck = minf(100.0, GameState.hidden_luck + 1.0)
			NoticeManager.show_scene_message("低头看见一枚没用过的硬币，像是今天的小运气。", "街角", "positive")
		_reevaluate()

func _reevaluate() -> void:
	if stress >= 70.0:
		_apply_condition("stressed")
	elif GameState.energy <= 25.0:
		_apply_condition("worn_out")
	elif mood >= 82.0 and stress <= 25.0:
		_apply_condition("socially_warm")
	else:
		_apply_condition("refreshed")

func _apply_condition(new_condition: String, emit_notice: bool = true) -> void:
	condition_id = new_condition
	var row := ConfigDB.get_row("life_conditions", condition_id)
	focus_bonus = float(row.get("focus_bonus", "0"))
	work_bonus = float(row.get("work_bonus", "0"))
	social_bonus = float(row.get("social_bonus", "0"))
	if emit_notice:
		condition_changed.emit(condition_id, get_hint())
	changed.emit()

func get_save_data() -> Dictionary:
	return {
		"condition_id": condition_id,
		"mood": mood,
		"stress": stress,
		"focus_bonus": focus_bonus,
		"work_bonus": work_bonus,
		"social_bonus": social_bonus,
	}

func restore(data: Dictionary) -> void:
	condition_id = str(data.get("condition_id", "refreshed"))
	mood = clampf(float(data.get("mood", 70.0)), 0.0, 100.0)
	stress = clampf(float(data.get("stress", 20.0)), 0.0, 100.0)
	focus_bonus = float(data.get("focus_bonus", 0.05))
	work_bonus = float(data.get("work_bonus", 0.04))
	social_bonus = float(data.get("social_bonus", 0.03))
	changed.emit()
