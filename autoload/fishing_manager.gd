extends Node

signal changed
signal fish_caught(fish_id: String, goods_id: String, size_value: int)

const CAST_WAIT_SECONDS := 1.0
const BITE_EARLY_WINDOW := 0.55
const BITE_LATE_WINDOW := 0.75

var current_rod_id := "bamboo_rod"
var rod_level := 0
var skill := 0.0
var catches: Dictionary = {}
var active_cast := false
var _cast_started_at := 0
var last_catch_id := ""
var bite_delay := 0.0
var _bite_notified := false

func _ready() -> void:
	set_process(true)
	reset_new_game()

func _process(_delta: float) -> void:
	if not active_cast or bite_delay <= 0.0:
		return
	var elapsed := (Time.get_ticks_msec() - _cast_started_at) / 1000.0
	if not _bite_notified and elapsed >= bite_delay - BITE_EARLY_WINDOW:
		_bite_notified = true
		NoticeManager.show_scene_message("浮漂沉了一下，快收线。", "河边浮漂", "warning")
		changed.emit()
	if elapsed > bite_delay + BITE_LATE_WINDOW:
		active_cast = false
		bite_delay = 0.0
		_bite_notified = false
		NoticeManager.show_npc_message("收慢了，鱼把饵吐了。下次盯紧浮漂。", "强叔", "warning")
		changed.emit()

func reset_new_game() -> void:
	current_rod_id = "bamboo_rod"
	rod_level = 0
	skill = 0.0
	catches.clear()
	active_cast = false
	_cast_started_at = 0
	bite_delay = 0.0
	_bite_notified = false
	last_catch_id = ""
	changed.emit()

func cast_or_reel() -> bool:
	if GameState.current_area != "riverside":
		NoticeManager.show_message("这里没有合适的水面，去河边再试试。", "hint", "强叔")
		return false
	if not active_cast:
		active_cast = true
		_cast_started_at = Time.get_ticks_msec()
		bite_delay = RandomManager.rng.randf_range(1.6, 3.8)
		_bite_notified = false
		TimeSystem.advance_minutes(20)
		NoticeManager.show_message("浮漂已经扔进水里，等水面有动静再收线。", "hint", "强叔")
		SaveManager.request_auto_save("fishing_cast")
		changed.emit()
		return true
	var elapsed := (Time.get_ticks_msec() - _cast_started_at) / 1000.0
	if elapsed < bite_delay - BITE_EARLY_WINDOW:
		NoticeManager.show_message("收得太急了，再等一下浮漂。", "hint", "强叔")
		return false
	if elapsed > bite_delay + BITE_LATE_WINDOW:
		active_cast = false
		bite_delay = 0.0
		_bite_notified = false
		NoticeManager.show_npc_message("鱼已经跑了，等下一次浮漂。", "强叔", "warning")
		changed.emit()
		return false
	return resolve_cast()

func get_cast_elapsed_seconds() -> float:
	if not active_cast or _cast_started_at <= 0:
		return 0.0
	return (Time.get_ticks_msec() - _cast_started_at) / 1000.0

func is_bite_window() -> bool:
	if not active_cast or bite_delay <= 0.0:
		return false
	var elapsed := get_cast_elapsed_seconds()
	return elapsed >= bite_delay - BITE_EARLY_WINDOW and elapsed <= bite_delay + BITE_LATE_WINDOW

func get_cast_phase() -> String:
	if not active_cast:
		return "idle"
	return "bite" if is_bite_window() else "waiting"

func resolve_cast(force_fish_id: String = "") -> bool:
	if not active_cast:
		return false
	active_cast = false
	bite_delay = 0.0
	_bite_notified = false
	var candidates := get_available_fish()
	if candidates.is_empty():
		NoticeManager.show_message("今天这片水口没有鱼口，换个天气或时段再来。", "warning", "强叔")
		changed.emit()
		return false
	var chosen := force_fish_id
	if chosen.is_empty():
		chosen = _weighted_fish(candidates)
	if chosen.is_empty():
		return false
	var row := ConfigDB.get_row("fish", chosen)
	if row.is_empty():
		return false
	var goods_id := str(row.get("goods_id", ""))
	var quantity := 1 + (1 if rod_level >= 2 and RandomManager.chance(0.18) else 0)
	BusinessManager.add_farm_goods(goods_id, quantity)
	var value_bonus := int(row.get("bonus_value", "0")) + rod_level * 2
	GameState.earn(value_bonus, "把这次河鲜卖了点零头。")
	catches[chosen] = int(catches.get(chosen, 0)) + quantity
	skill = minf(100.0, skill + float(value_bonus) * 0.12)
	last_catch_id = chosen
	NoticeManager.show_message("收线成功，钓到%s ×%d，已经送进餐馆仓库。" % [str(row.get("name", chosen)), quantity], "positive", "强叔")
	fish_caught.emit(chosen, goods_id, quantity)
	SaveManager.request_auto_save("fishing_catch")
	changed.emit()
	return true

func get_available_fish() -> Array[String]:
	var result: Array[String] = []
	var hour := TimeSystem.minute_of_day / 60
	for fish_id in ConfigDB.get_rows("fish"):
		var row := ConfigDB.get_row("fish", fish_id)
		var start_h := int(row.get("start_hour", "0"))
		var end_h := int(row.get("end_hour", "24"))
		var time_ok := hour >= start_h and hour < end_h
		var weather_ok := _weather_matches(str(row.get("weather", "any")))
		var rod_ok := rod_level >= int(row.get("rod_level", "0"))
		if time_ok and weather_ok and rod_ok:
			result.append(str(fish_id))
	return result

func _weather_matches(required: String) -> bool:
	if required == "any":
		return true
	var weather := WeatherSystem.current_weather_id
	match required:
		"clear":
			return weather in ["sunny", "overcast"]
		"cool":
			return CalendarManager.get_season_id() == "winter" or weather in ["overcast", "humid"]
		_:
			return weather == required

func _weighted_fish(candidates: Array[String]) -> String:
	var total := 0.0
	for fish_id in candidates:
		var row := ConfigDB.get_row("fish", fish_id)
		var weight := maxf(1.0, float(row.get("weight", "1")))
		var rarity := str(row.get("rarity", "common"))
		if rarity == "rare":
			weight *= 1.0 + float(get_rod_row().get("rare_bonus", "0.0"))
		elif rarity == "legendary":
			weight *= 0.35 + float(get_rod_row().get("rare_bonus", "0.0")) * 2.0
		total += weight
	var roll := RandomManager.rng.randf() * total
	var accumulated := 0.0
	for fish_id in candidates:
		accumulated += maxf(1.0, float(ConfigDB.get_row("fish", fish_id).get("weight", "1")))
		if roll <= accumulated:
			return fish_id
	return candidates[0]

func upgrade_rod(rod_id: String = "") -> bool:
	if not rod_id.is_empty():
		var chosen := ConfigDB.get_row("fishing_rods", rod_id)
		if chosen.is_empty() or rod_id == current_rod_id:
			return false
		if GameState.money < int(chosen.get("cost", "0")):
			return false
		if not GameState.spend(int(chosen.get("cost", "0")), "换一根%s。" % str(chosen.get("name", rod_id))):
			return false
		current_rod_id = rod_id
		rod_level = 0
		NoticeManager.show_message("换了%s，出竿手感不一样了。" % str(chosen.get("name", rod_id)), "positive", "强叔")
		SaveManager.request_auto_save("fishing_rod_upgrade")
		changed.emit()
		return true
	var row := get_rod_row()
	if rod_level >= int(row.get("max_level", "3")):
		NoticeManager.show_message("%s已经升到顶了。" % str(row.get("name", current_rod_id)), "hint", "强叔")
		return false
	var cost := int(row.get("cost", "0")) + rod_level * 180
	if not GameState.spend(cost, "升级鱼竿。"):
		return false
	rod_level += 1
	NoticeManager.show_message("鱼竿升级了，起竿更稳，也更可能碰到稀有鱼。", "positive", "强叔")
	SaveManager.request_auto_save("fishing_rod_upgrade")
	changed.emit()
	return true

func get_rod_row() -> Dictionary:
	return ConfigDB.get_row("fishing_rods", current_rod_id)

func get_summary() -> String:
	var total := 0
	for count in catches.values():
		total += int(count)
	return "钓鱼熟练度靠手感积累 · 鱼获 %d 条 · 当前%s" % [total, str(get_rod_row().get("name", "竹制鱼竿"))]

func get_manager_hint() -> String:
	if WeatherSystem.current_weather_id == "heat":
		return "正午鱼口浅，等傍晚再下竿。"
	if TimeSystem.minute_of_day >= 20 * 60:
		return "夜里水色深，稀有鱼更活跃。"
	return "看浮漂，不要一直猛收线。"

func get_save_data() -> Dictionary:
	return {
		"current_rod_id": current_rod_id,
		"rod_level": rod_level,
		"skill": skill,
		"catches": catches.duplicate(true),
		"last_catch_id": last_catch_id,
	}

func restore(data: Dictionary) -> void:
	current_rod_id = str(data.get("current_rod_id", "bamboo_rod"))
	rod_level = int(data.get("rod_level", 0))
	skill = float(data.get("skill", 0.0))
	catches = data.get("catches", {}).duplicate(true)
	last_catch_id = str(data.get("last_catch_id", ""))
	active_cast = false
	bite_delay = 0.0
	_bite_notified = false
	changed.emit()
