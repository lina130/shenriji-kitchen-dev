extends Node

signal notice_requested(message: String, tone: String, speaker: String, source_kind: String)
signal notice_cleared(notice_id: String)

var _last_message := ""
var _last_ticks := 0
var _arbiter := NoticeArbiter.new()

func _ready() -> void:
	_arbiter.notice_activated.connect(_on_arbiter_activated)
	_arbiter.notice_cleared.connect(_on_arbiter_cleared)
	set_process(true)

func _process(delta: float) -> void:
	_arbiter.tick(delta)

func show_message(message: String, tone: String = "normal", speaker: String = "", source_kind: String = "") -> void:
	_emit_notice(message, tone, speaker, source_kind)

func show_npc_hint(message: String, speaker: String = "街坊", duration: float = 4.0) -> void:
	if message.is_empty():
		return
	var resolved_speaker := get_speaker(message, "hint", speaker, "npc")
	_arbiter.push(
		"npc_hint:%s" % resolved_speaker,
		message,
		NoticeArbiter.Priority.NPC_HINT,
		duration,
		resolved_speaker,
		"",
		"npc",
		"hint",
		5.0,
		false,
	)

func show_system_message(message: String, tone: String = "normal") -> void:
	_emit_notice(message, tone, "系统", "system")

func show_npc_message(message: String, speaker: String, tone: String = "normal") -> void:
	_emit_notice(message, tone, speaker, "npc")

func show_scene_message(message: String, source_label: String = "", tone: String = "normal") -> void:
	_emit_notice(message, tone, source_label, "scene")

func _emit_notice(message: String, tone: String, speaker: String, source_kind: String) -> void:
	if message.is_empty():
		return
	var now := Time.get_ticks_msec()
	if message == _last_message and now - _last_ticks < 350:
		return
	var kind := source_kind
	if kind.is_empty():
		kind = infer_source_kind(message, speaker)
	var resolved_speaker := get_speaker(message, tone, speaker, kind)
	var priority := _priority_for(kind, tone)
	var accepted := _arbiter.push(
		"%s:%s" % [kind, resolved_speaker],
		message,
		priority,
		3.0 if kind != "system" else 4.0,
		resolved_speaker,
		"",
		kind,
		tone,
		0.0,
		true,
	)
	if not accepted:
		return
	_last_message = message
	_last_ticks = now

func _on_arbiter_activated(entry: Dictionary) -> void:
	notice_requested.emit(
		str(entry.get("text", "")),
		str(entry.get("tone", "normal")),
		str(entry.get("speaker", "")),
		str(entry.get("source_kind", "system")),
	)

func _on_arbiter_cleared(notice_id: String) -> void:
	notice_cleared.emit(notice_id)

func _priority_for(kind: String, tone: String) -> int:
	if kind == "system":
		return NoticeArbiter.Priority.SYSTEM
	if kind == "scene":
		return NoticeArbiter.Priority.SCENE
	if tone == "hint":
		return NoticeArbiter.Priority.NPC_HINT
	return NoticeArbiter.Priority.NPC

func clear_all() -> void:
	_arbiter.clear_all()
	_last_message = ""
	_last_ticks = 0

func get_active_notice() -> Dictionary:
	return _arbiter.get_active()

func infer_source_kind(message: String, explicit_speaker: String = "") -> String:
	if not explicit_speaker.is_empty():
		return "npc"
	if message.contains("存档") or message.contains("保存") or message.contains("读取") or message.contains("版本"):
		return "system"
	return "npc"

func get_speaker(message: String = "", _tone: String = "normal", explicit_speaker: String = "", source_kind: String = "") -> String:
	if source_kind == "system":
		return "系统"
	if not explicit_speaker.is_empty():
		return explicit_speaker
	if message.contains("存档") or message.contains("保存") or message.contains("读取") or message.contains("版本"):
		return "系统"
	if source_kind == "scene":
		return str(PresentationManager.get_scene_metadata(GameState.current_area).get("display_name", "场景"))
	var area := GameState.current_area
	match area:
		"restaurant":
			return "厨房师傅"
		"breakfast_shop", "breakfast_kitchen":
			return "黄姐"
		"market", "ruins":
			return "陈伯"
		"bank":
			return "银行柜员"
		"factory", "industrial_district":
			return "王师傅"
		"farm", "suburb":
			return "农场主"
		"pet_store":
			return "宠物店老板"
		"furniture_store":
			return "家居店老板"
		"clothing_store":
			return "阿珍"
		"store", "commercial_district":
			return "小林"
		"wholesale":
			return "批发老板"
		"home":
			return "梅姨"
		"riverside":
			return "强叔"
		"street":
			return "老街坊"
		"high_end_district":
			return "物业管家"
		"logistics_port":
			return "仓库调度"
		"craft_workshop":
			return "维修师傅"
		"night_market":
			return "夜市摊主"
		"bus_station":
			return "巴士司机"
		"clinic":
			return "社区医生"
		"university":
			return "夜校老师"
		"community_center":
			return "活动中心管理员"
		"seaside_resort", "ancient_village", "mountain_spring":
			return "当地向导"
	return "街坊"
