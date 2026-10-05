extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arbiter := NoticeArbiter.new()
	var activated: Array[String] = []
	arbiter.notice_activated.connect(func(entry: Dictionary) -> void:
		activated.append(str(entry.get("id", "")))
	)

	arbiter.push("scene_1", "场景消息", NoticeArbiter.Priority.SCENE, 5.0, "场景", "", "scene")
	arbiter.push("system_1", "系统消息", NoticeArbiter.Priority.SYSTEM, 5.0, "系统", "", "system")
	_check(str(arbiter.get_active().get("id", "")) == "system_1", "高优先级应抢占低优先级")
	_check(arbiter.get_queue_size() == 1, "被抢占的低优先级消息应回队列")

	var accepted := arbiter.push(
		"npc_hint_1",
		"低优先级暗示",
		NoticeArbiter.Priority.NPC_HINT,
		1.0,
		"老街坊",
		"",
		"npc",
		"hint",
		0.0,
		false,
	)
	_check(not accepted, "高优先级占用时，低优先级暗示应被抑制")
	_check(str(arbiter.get_active().get("id", "")) == "system_1", "被抑制的暗示不能覆盖当前提示")

	arbiter.tick(5.0)
	_check(str(arbiter.get_active().get("id", "")) == "scene_1", "当前提示结束后应恢复排队消息")
	arbiter.tick(5.0)
	_check(arbiter.get_active().is_empty(), "队列清空后不应残留活动提示")
	_check(activated == ["scene_1", "system_1", "scene_1"], "激活顺序应符合抢占和队列规则")

	arbiter.push("cooldown_1", "冷却消息", NoticeArbiter.Priority.SYSTEM, 1.0, "系统", "", "system", "normal", 10.0)
	arbiter.tick(1.0)
	var cooldown_accepted := arbiter.push("cooldown_1", "冷却消息", NoticeArbiter.Priority.SYSTEM, 1.0, "系统", "", "system", "normal", 10.0)
	_check(not cooldown_accepted, "同一提示 id 在冷却期内应被抑制")

	var audio_node := root.get_node_or_null("AudioManager")
	if audio_node != null and audio_node.has_method("shutdown"):
		audio_node.call("shutdown")
	if _failures.is_empty():
		print("NOTICE_ARBITER_PASS")
		call_deferred("quit", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("quit", 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
