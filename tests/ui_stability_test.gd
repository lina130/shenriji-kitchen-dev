extends SceneTree

var _failures: Array[String] = []
var _menu: Object
var _hud: Object

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager != null and save_manager.has_method("set_auto_save_enabled"):
		save_manager.call("set_auto_save_enabled", false)

	var menu_script := load("res://scripts/ui/main_menu.gd")
	var hud_script := load("res://scripts/ui/hud.gd")
	_menu = menu_script.new()
	root.add_child(_menu)
	await process_frame
	_check(not bool(_menu.get("_settings_panel").visible), "主菜单启动时设置面板必须隐藏")
	_menu.call("open_settings")
	_check(bool(_menu.get("_settings_panel").visible), "设置按钮应能打开设置面板")
	_menu.call("_unhandled_input", _cancel_event())
	_check(not bool(_menu.get("_settings_panel").visible), "主菜单 Esc 应只关闭设置面板")

	_hud = hud_script.new()
	root.add_child(_hud)
	await process_frame
	_check(int(_hud.get("_modal_state")) == 0, "HUD 启动时不能有活动模态框")
	_check(not bool(_hud.get("_modal_panel").visible), "HUD 启动时模态框必须隐藏")
	_check(not bool(_hud.get("_context_panel").visible), "HUD 启动时交互提示必须隐藏")
	_check(not bool(_hud.get("_pointer_panel").visible), "HUD 启动时指针提示必须隐藏")
	_check(not bool(_hud.get("_notice_panel").visible), "HUD 启动时不能凭空出现提示面板")

	var status_rect: Rect2 = _hud.get("_status_panel").get_global_rect()
	var context_rect: Rect2 = _hud.get("_context_panel").get_global_rect()
	var notice_rect: Rect2 = _hud.get("_notice_panel").get_global_rect()
	var hotbar_rect: Rect2 = _hud.get("_hotbar_panel").get_global_rect()
	_check(not status_rect.intersects(context_rect), "左上状态卡不能和顶部中央交互提示重叠")
	_check(not context_rect.intersects(notice_rect), "顶部交互提示不能和系统通知重叠")
	_check(not notice_rect.intersects(hotbar_rect), "底部提示不能和快捷栏重叠")

	_hud.call("_unhandled_input", _cancel_event())
	_check(int(_hud.get("_modal_state")) == _hud.ModalState.PAUSE, "无模态时 Esc 应只打开暂停")
	_hud.call("_unhandled_input", _cancel_event())
	_check(int(_hud.get("_modal_state")) == 0, "暂停时 Esc 应只关闭暂停")
	_check(not bool(root.get_node("GameState").get("input_locked")), "关闭暂停后必须恢复输入")

	_hud.call("open_inventory")
	_check(int(_hud.get("_modal_state")) == _hud.ModalState.INVENTORY, "背包应作为单层模态打开")
	var notice_manager := root.get_node("NoticeManager")
	notice_manager.call("show_npc_message", "模态内不应显示提示", "老街坊", "hint")
	_check(not bool(_hud.get("_notice_panel").visible), "模态打开时提示不能盖在模态上")
	_hud.call("_unhandled_input", _cancel_event())
	_check(int(_hud.get("_modal_state")) == 0, "背包 Esc 不能一次关闭多层")
	_check(not bool(root.get_node("GameState").get("input_locked")), "关闭背包后必须恢复输入")
	_check(bool(_hud.get("_notice_panel").visible), "关闭模态后仍有效的提示应恢复显示")
	notice_manager.call("clear_all")
	await process_frame

	_hud.call("open_dialogue", "lan")
	_check(int(_hud.get("_modal_state")) == _hud.ModalState.DIALOGUE, "对话应作为单层模态打开")
	_hud.call("_unhandled_input", _cancel_event())
	_check(int(_hud.get("_modal_state")) == 0, "对话 Esc 应只关闭对话")
	_check(root.gui_get_focus_owner() == null or not _hud.get("_modal_panel").is_ancestor_of(root.gui_get_focus_owner()), "关闭对话后不应把焦点留在隐藏模态中")

	_menu.queue_free()
	_hud.queue_free()
	await process_frame
	_finish()

func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var audio_node := root.get_node_or_null("AudioManager")
	if audio_node != null and audio_node.has_method("shutdown"):
		audio_node.call("shutdown")
	if _failures.is_empty():
		print("UI_STABILITY_PASS")
		call_deferred("quit", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("quit", 1)
