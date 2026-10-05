extends Node

## 节日事件与限时纪念品。节日当天由 NPC 自然讲述，不出现任务列表或进度条。

signal festival_started(day_key: String, event_id: String)
signal festival_gift_claimed(day_key: String, item_id: String)

var active_event_id := ""
var notified: Dictionary = {}
var claimed: Dictionary = {}
var activities_done: Dictionary = {}
var last_event_id := ""

func _ready() -> void:
	CalendarManager.calendar_day_started.connect(_on_calendar_day_started)

func reset_new_game() -> void:
	active_event_id = ""
	notified.clear()
	claimed.clear()
	activities_done.clear()
	last_event_id = ""

func _on_calendar_day_started(calendar_day: int, _festival_name: String) -> void:
	var row := get_event_for_day(calendar_day)
	if row.is_empty():
		active_event_id = ""
		return
	active_event_id = str(row.get("event_id", ""))
	last_event_id = active_event_id
	var day_key := _year_day_key(calendar_day)
	if notified.has(day_key):
		return
	notified[day_key] = true
	NoticeManager.show_npc_message(str(row.get("line", "")), str(row.get("speaker", "街坊")), "positive")
	festival_started.emit(day_key, active_event_id)
	SaveManager.request_auto_save("festival")

func get_event_for_day(day_number: int = -1) -> Dictionary:
	var day_key := str(CalendarManager.get_day_of_year(day_number))
	return ConfigDB.get_row("festival_events", day_key)

func get_today_event() -> Dictionary:
	return get_event_for_day()

func get_today_event_id() -> String:
	return str(get_today_event().get("event_id", ""))

func get_today_title() -> String:
	return str(get_today_event().get("title", "节日"))

func get_today_npc_id() -> String:
	return str(get_today_event().get("npc_id", ""))

func get_today_npc_line() -> String:
	return str(get_today_event().get("line", ""))

func get_today_decoration() -> String:
	return str(get_today_event().get("decoration", ""))

func get_today_scene_id() -> String:
	return str(get_today_event().get("scene_id", ""))

func is_festival_npc(npc_id: String) -> bool:
	var row := get_today_event()
	return not row.is_empty() and str(row.get("npc_id", "")) == npc_id

func claim_gift(npc_id: String) -> String:
	var row := get_today_event()
	if row.is_empty() or str(row.get("npc_id", "")) != npc_id:
		return ""
	var day_key := _year_day_key()
	var line := str(row.get("line", ""))
	var speaker := str(row.get("speaker", "街坊"))
	if claimed.has(day_key):
		return "%s\n\n%s说，今年的节日纪念品你已经收好了。" % [line, speaker]
	var item_id := str(row.get("reward_item_id", ""))
	if item_id.is_empty():
		return line
	InventoryManager.add_item(item_id, 1)
	CollectionManager.discovered[item_id] = true
	CollectionManager.changed.emit()
	var item := InventoryManager.get_item(item_id)
	claimed[day_key] = true
	line += "\n\n%s把【%s】交给你，说这件东西只在今年的这个节日留下。" % [
		speaker, str(item.get("name", item_id)),
	]
	festival_gift_claimed.emit(day_key, item_id)
	SaveManager.request_auto_save("festival_gift")
	return line

func join_today_activity() -> String:
	var row := get_today_event()
	if row.is_empty():
		return ""
	var day_key := _year_day_key()
	if activities_done.has(day_key):
		return "%s今天已经参加过了。" % str(row.get("activity_title", "这场活动"))
	activities_done[day_key] = true
	var activity_type := str(row.get("activity_type", "gathering"))
	var reward_money := int(row.get("activity_reward_money", "0"))
	var reward_energy := int(row.get("activity_reward_energy", "0"))
	if reward_money > 0:
		GameState.earn(reward_money)
	if reward_energy != 0:
		GameState.change_energy(float(reward_energy))
	var npc_id := str(row.get("npc_id", ""))
	if not npc_id.is_empty():
		RelationshipManager.affinity[npc_id] = int(RelationshipManager.affinity.get(npc_id, 0)) + 2
	var result_line := str(row.get("activity_line", ""))
	if activity_type == "competition":
		var score := int(round(GameState.energy * 0.12 + GameState.health * 0.08 + WellbeingManager.mood * 0.10 - WellbeingManager.stress * 0.08))
		var placement := "前几名" if score >= 24 else ("中游" if score >= 14 else "后几名")
		var bonus := maxi(0, score) * 2
		if bonus > 0:
			GameState.earn(bonus, "比赛结算和名次奖励合计 ¥%d。" % bonus)
		result_line += "
这次比赛排在后%s，名次奖励 ¥%d。" % [placement, bonus]
	else:
		WellbeingManager.relax(8.0, 9.0)
		WellbeingManager.grow_social_warmth(3.0)
		result_line += "
和人待在一起，心里的紧绷感松下来一些。"
	AchievementManager.record_event("festival_activity")
	SaveManager.request_auto_save("festival_activity")
	return result_line

func get_today_activity_title() -> String:
	return str(get_today_event().get("activity_title", ""))

func get_today_activity_hint() -> String:
	var row := get_today_event()
	if row.is_empty():
		return ""
	if activities_done.has(_year_day_key()):
		return "今天的%s已经参加过了。" % str(row.get("activity_title", "活动"))
	return str(row.get("activity_title", "节日活动"))

func get_summary() -> String:
	var row := get_today_event()
	if row.is_empty():
		return "%s。今天没有节日活动。" % CalendarManager.get_next_festival_text()
	var activity := get_today_activity_hint()
	var suffix := " · %s" % activity if not activity.is_empty() else ""
	return "%s · %s%s" % [str(row.get("title", "节日")), str(row.get("line", "")), suffix]

func get_gift_hint(item_id: String) -> String:
	var item := InventoryManager.get_item(item_id)
	return "节日纪念品：%s" % str(item.get("name", item_id))

func get_claimed_for_year(year: int = -1) -> int:
	var resolved_year := CalendarManager.get_year() if year < 0 else year
	var count := 0
	for day_key in claimed:
		if str(day_key).begins_with("%d:" % resolved_year):
			count += 1
	return count

func has_all_current_year() -> bool:
	return get_claimed_for_year() >= ConfigDB.get_rows("festival_events").size()

func get_save_data() -> Dictionary:
	return {
		"active_event_id": active_event_id,
		"notified": notified.duplicate(true),
		"claimed": claimed.duplicate(true),
		"activities_done": activities_done.duplicate(true),
		"last_event_id": last_event_id,
	}

func restore(data: Dictionary) -> void:
	active_event_id = str(data.get("active_event_id", get_today_event_id()))
	notified = data.get("notified", {}).duplicate(true)
	claimed = data.get("claimed", {}).duplicate(true)
	activities_done = data.get("activities_done", {}).duplicate(true)
	last_event_id = str(data.get("last_event_id", active_event_id))

func _year_day_key(day_number: int = -1) -> String:
	var day_of_year := CalendarManager.get_day_of_year(day_number)
	var year := CalendarManager.get_year(day_number)
	return "%d:%d" % [year, day_of_year]
