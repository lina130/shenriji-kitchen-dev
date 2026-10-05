extends Node

## 轻量剧情与随机事件。没有任务列表，节点通过 NPC 提示和生活事件推进。

signal changed
signal story_advanced(chapter: int, title: String)
signal random_event_triggered(event_id: String)

var chapter := 0
var flags: Dictionary = {}
var last_event_id := ""
var random_events_enabled := true

func _ready() -> void:
	reset_new_game()

func reset_new_game() -> void:
	chapter = 0
	flags.clear()
	last_event_id = ""
	changed.emit()

func begin_new_story() -> void:
	_show_chapter(0)
	SaveManager.request_auto_save("story_start")

func record_action(action_id: String) -> bool:
	var row := ConfigDB.get_row("story_chapters", action_id)
	if row.is_empty():
		return false
	var row_chapter := int(row.get("chapter", "-1"))
	flags[action_id] = true
	if row_chapter != chapter + 1:
		SaveManager.request_auto_save("story_flag")
		changed.emit()
		return false
	chapter = row_chapter
	_show_chapter(chapter)
	_advance_pending()
	SaveManager.request_auto_save("story_advance")
	changed.emit()
	return true

func set_random_events_enabled(value: bool) -> void:
	random_events_enabled = value

func begin_new_day(day_number: int) -> void:
	if not random_events_enabled or day_number <= 1:
		return
	if RandomManager.chance(0.22):
		trigger_random_event()

func trigger_random_event(event_id: String = "") -> String:
	var row := _pick_event(event_id)
	if row.is_empty():
		return ""
	last_event_id = str(row.get("event_id", ""))
	var event_name := str(row.get("name", last_event_id))
	var speaker := str(row.get("speaker", "街坊"))
	var text := str(row.get("text", ""))
	_apply_event_effect(row)
	NoticeManager.show_message("%s：%s" % [event_name, text], "normal", speaker)
	SaveManager.request_auto_save("random_event")
	random_event_triggered.emit(last_event_id)
	changed.emit()
	return last_event_id

func get_story_hint() -> String:
	var row := _current_chapter_row()
	if row.is_empty():
		return "日子会在一件件小事里慢慢往前走。"
	return str(row.get("text", ""))

func get_story_speaker() -> String:
	var row := _current_chapter_row()
	return str(row.get("speaker", "街坊")) if not row.is_empty() else "街坊"

func get_chapter_title() -> String:
	var row := _current_chapter_row()
	return str(row.get("title", "城中村日常")) if not row.is_empty() else "城中村日常"

func _show_chapter(target_chapter: int) -> void:
	var row := _chapter_row(target_chapter)
	if row.is_empty():
		return
	NoticeManager.show_message("%s：%s" % [str(row.get("title", "")), str(row.get("text", ""))], "positive", str(row.get("speaker", "街坊")))
	story_advanced.emit(target_chapter, str(row.get("title", "")))

func _advance_pending() -> void:
	while true:
		var next_row := _chapter_row(chapter + 1)
		if next_row.is_empty():
			return
		var trigger := str(next_row.get("trigger_action", ""))
		if trigger.is_empty() or not flags.has(trigger):
			return
		chapter += 1
		_show_chapter(chapter)

func _pick_event(event_id: String) -> Dictionary:
	if not event_id.is_empty():
		return ConfigDB.get_row("random_events", event_id)
	var rows := ConfigDB.get_rows("random_events")
	if rows.is_empty():
		return {}
	var total := 0.0
	for row_key in rows:
		total += maxf(0.0, float(ConfigDB.get_row("random_events", row_key).get("weight", "1")))
	var roll := RandomManager.rng.randf() * total
	var accumulated := 0.0
	for row_key in rows:
		var row := ConfigDB.get_row("random_events", row_key)
		accumulated += maxf(0.0, float(row.get("weight", "1")))
		if roll <= accumulated:
			return row
	return {}

func _apply_event_effect(row: Dictionary) -> void:
	var effect_type := str(row.get("effect_type", ""))
	var value := float(row.get("effect_value", "0"))
	match effect_type:
		"energy":
			GameState.change_energy(value)
		"money":
			if value >= 0:
				GameState.earn(int(value), "偶发事件收入")
			else:
				GameState.spend(int(-value), "偶发事件支出")
		"reputation":
			BusinessManager.reputation = maxi(0, BusinessManager.reputation + int(value))
		"labor":
			BusinessManager.labor_stock += int(value)
		"relationship":
			var npc_id := str(row.get("effect_data", ""))
			if not npc_id.is_empty():
				RelationshipManager.affinity[npc_id] = int(RelationshipManager.affinity.get(npc_id, 0)) + int(value)
		"business_risk":
			BusinessManager.price_modifiers["greens"] = float(BusinessManager.price_modifiers.get("greens", 0.0)) - 0.08
		"market_hint":
			WeatherSystem.current_weather_id = str(row.get("effect_data", WeatherSystem.current_weather_id))
		"stress":
			WellbeingManager.stress = clampf(WellbeingManager.stress + value, 0.0, 100.0)
		"health":
			GameState.health = clampf(GameState.health + value, 0.0, 100.0)
		"collection_luck":
			GameState.hidden_luck = clampf(GameState.hidden_luck + value, 0.0, 100.0)
		"farm_growth":
			for plot in FarmManager.plots:
				if str(plot.get("stage", "")) == FarmManager.STAGE_GROWING:
					plot["days_grown"] = float(plot.get("days_grown", 0.0)) + value
			FarmManager.changed.emit()
		"child_mood":
			if FamilyManager.stage_id == "family" and not FamilyManager.child_name.is_empty():
				FamilyManager.child_mood = clampf(FamilyManager.child_mood + value, 0.0, 100.0)
				FamilyManager.changed.emit()
		"pet_mood":
			for pet_id in PetManager.adopted:
				var pet: Dictionary = PetManager.adopted[pet_id]
				pet["mood"] = clampf(float(pet.get("mood", 50.0)) + value, 0.0, 100.0)
			PetManager.changed.emit()

func _current_chapter_row() -> Dictionary:
	return _chapter_row(chapter)

func _chapter_row(target_chapter: int) -> Dictionary:
	for trigger in ConfigDB.get_rows("story_chapters"):
		var row := ConfigDB.get_row("story_chapters", trigger)
		if int(row.get("chapter", "-1")) == target_chapter:
			return row
	return {}

func get_save_data() -> Dictionary:
	return {"chapter": chapter, "flags": flags.duplicate(true), "last_event_id": last_event_id}

func restore(data: Dictionary) -> void:
	chapter = int(data.get("chapter", 0))
	flags = data.get("flags", {}).duplicate(true)
	last_event_id = str(data.get("last_event_id", ""))
	random_events_enabled = bool(data.get("random_events_enabled", true))
	changed.emit()
