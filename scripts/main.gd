extends Node

const HudScript := preload("res://scripts/ui/hud.gd")
const WorldScript := preload("res://scripts/gameplay/world.gd")

var hud: GameHUD
var world: WorldRoot

func _ready() -> void:
	if "--smoke-test" in OS.get_cmdline_user_args():
		var test_script := load("res://tests/smoke_test.gd")
		add_child(test_script.new())
		return
	get_tree().auto_accept_quit = false
	hud = HudScript.new()
	add_child(hud)
	world = WorldScript.new()
	add_child(world)
	world.shop_requested.connect(hud.open_shop)
	world.inventory_requested.connect(hud.open_inventory)
	hud.modal_changed.connect(_on_modal_changed)
	TimeSystem.set_paused(false)
	var capture_path := OS.get_environment("DEEP_CITY_CAPTURE_PREVIEW")
	if not capture_path.is_empty():
		_capture_preview.call_deferred(capture_path)
	if SaveManager.has_save():
		NoticeManager.show_message("按 F9 可以继续上次的生活。", "hint")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		SaveManager.save_game(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("load_game"):
		SaveManager.load_game(true)
		get_viewport().set_input_as_handled()

func _on_modal_changed(is_open: bool) -> void:
	world.set_player_input_locked(is_open)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game(false)
		get_tree().quit()
func _capture_preview(output_path: String) -> void:
	for frame in range(8):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	if error == OK:
		print("PREVIEW_SAVED:" + output_path)
	else:
		push_error("PREVIEW_SAVE_FAILED:%d" % error)
	get_tree().quit(error)
