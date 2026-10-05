class_name NoticeArbiter
extends RefCounted

## 单通道提示仲裁器：同一时刻最多只激活一条提示。
## NoticeManager 负责把原有 API 转成这里的优先级事件，HUD 只负责渲染当前激活项。

signal notice_activated(entry: Dictionary)
signal notice_cleared(notice_id: String)

enum Priority {
	AMBIENT = 0,
	NPC_HINT = 1,
	SCENE = 2,
	NPC = 2,
	SYSTEM = 3,
	CRITICAL = 4,
}

const MAX_QUEUE := 8
const DEFAULT_DURATION := 3.0

var _active: Dictionary = {}
var _queue: Array[Dictionary] = []
var _cooldowns: Dictionary = {}

func push(
	notice_id: String,
	text: String,
	priority: int = Priority.SYSTEM,
	duration: float = DEFAULT_DURATION,
	speaker: String = "",
	avatar_key: String = "",
	source_kind: String = "system",
	tone: String = "normal",
	cooldown: float = 0.0,
	queue_if_busy: bool = true,
) -> bool:
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		return false
	var resolved_id := notice_id.strip_edges()
	if resolved_id.is_empty():
		resolved_id = "%s:%s" % [source_kind, clean_text.left(32)]
	var now := Time.get_ticks_msec() / 1000.0
	if cooldown > 0.0:
		var expire := float(_cooldowns.get(resolved_id, 0.0))
		if expire > now:
			return false
		_cooldowns[resolved_id] = now + cooldown
	var resolved_duration := maxf(0.1, duration)
	var entry := {
		"id": resolved_id,
		"text": clean_text,
		"priority": priority,
		"duration": resolved_duration,
		"original_duration": resolved_duration,
		"speaker": speaker,
		"avatar_key": avatar_key,
		"source_kind": source_kind,
		"tone": tone,
		"pushed_at": now,
	}
	_remove_queued_by_id(resolved_id)
	if not _active.is_empty() and str(_active.get("id", "")) == resolved_id:
		_activate(entry)
		return true
	if _active.is_empty():
		_activate(entry)
		return true
	if priority > int(_active.get("priority", Priority.AMBIENT)):
		var preempted: Dictionary = _active.duplicate(true)
		preempted["duration"] = float(preempted.get("original_duration", DEFAULT_DURATION))
		if queue_if_busy:
			_enqueue(preempted)
		_activate(entry)
		return true
	if not queue_if_busy:
		return false
	return _enqueue(entry)

func tick(delta: float) -> void:
	if _active.is_empty():
		_dispense_next()
		return
	_active["duration"] = float(_active.get("duration", 0.0)) - delta
	if float(_active.get("duration", 0.0)) > 0.0:
		return
	clear_active()

func clear_active() -> void:
	if _active.is_empty():
		return
	var finished_id := str(_active.get("id", ""))
	_active = {}
	notice_cleared.emit(finished_id)
	_dispense_next()

func clear_all() -> void:
	if not _active.is_empty():
		notice_cleared.emit(str(_active.get("id", "")))
	_active = {}
	_queue.clear()

func get_active() -> Dictionary:
	return _active.duplicate(true)

func get_queue_size() -> int:
	return _queue.size()

func reset_cooldowns() -> void:
	_cooldowns.clear()

func _activate(entry: Dictionary) -> void:
	_active = entry
	notice_activated.emit(entry.duplicate(true))

func _dispense_next() -> void:
	if _active.is_empty() and not _queue.is_empty():
		_activate(_queue.pop_front())

func _enqueue(entry: Dictionary) -> bool:
	if _queue.size() < MAX_QUEUE:
		_queue.push_back(entry)
		return true
	var lowest_index := 0
	for index in range(1, _queue.size()):
		if int(_queue[index].get("priority", Priority.AMBIENT)) < int(_queue[lowest_index].get("priority", Priority.AMBIENT)):
			lowest_index = index
	if int(entry.get("priority", Priority.AMBIENT)) <= int(_queue[lowest_index].get("priority", Priority.AMBIENT)):
		return false
	_queue[lowest_index] = entry
	return true

func _remove_queued_by_id(notice_id: String) -> void:
	for index in range(_queue.size() - 1, -1, -1):
		if str(_queue[index].get("id", "")) == notice_id:
			_queue.remove_at(index)
