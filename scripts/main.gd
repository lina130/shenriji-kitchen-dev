extends Node

const HudScript := preload("res://scripts/ui/hud.gd")
const WorldScript := preload("res://scripts/gameplay/world.gd")
const MenuScript := preload("res://scripts/ui/main_menu.gd")

var menu: MainMenu
var hud: GameHUD
var world: WorldRoot
var in_game := false

func _ready() -> void:
	if "--full-simulation" in OS.get_cmdline_user_args():
		var simulation_script := load("res://tests/full_progression_test.gd")
		add_child(simulation_script.new())
		return
	if "--playtest" in OS.get_cmdline_user_args():
		get_tree().auto_accept_quit = false
		var playtest_script := load("res://tests/playtest_runner.gd")
		add_child(playtest_script.new())
		return
	if "--economy-check" in OS.get_cmdline_user_args():
		var economy_check_script := load("res://tests/economy_check.gd")
		add_child(economy_check_script.new())
		return
	if "--scene-check" in OS.get_cmdline_user_args():
		var scene_check_script := load("res://tests/scene_check.gd")
		add_child(scene_check_script.new())
		return
	if "--stress-test" in OS.get_cmdline_user_args():
		var stress_script := load("res://tests/stress_test.gd")
		add_child(stress_script.new())
		return
	if "--smoke-test" in OS.get_cmdline_user_args():
		var test_script := load("res://tests/smoke_test.gd")
		add_child(test_script.new())
		return
	get_tree().auto_accept_quit = false
	var capture_path := OS.get_environment("DEEP_CITY_CAPTURE_PREVIEW")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-preview="):
			capture_path = argument.trim_prefix("--capture-preview=")
	var capture_area := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-area="):
			capture_area = argument.trim_prefix("--capture-area=")
	if not capture_path.is_empty():
		_start_new_game()
		if not capture_area.is_empty():
			SceneRouter.travel_to(capture_area, "entrance")
		_capture_preview.call_deferred(capture_path)
	else:
		_show_main_menu()

func _show_main_menu() -> void:
	in_game = false
	_clear_game_nodes()
	TimeSystem.set_paused(true)
	AudioManager.play_music("menu_ambient")
	menu = MenuScript.new()
	add_child(menu)
	menu.new_game_requested.connect(_start_new_game)
	menu.continue_requested.connect(_enter_game)

func _start_new_game() -> void:
	GameState.reset_new_game()
	_enter_game()

func _enter_game() -> void:
	_clear_game_nodes()
	in_game = true
	TimeSystem.set_paused(false)
	hud = HudScript.new()
	add_child(hud)
	world = WorldScript.new()
	add_child(world)
	world.shop_requested.connect(hud.open_shop)
	world.inventory_requested.connect(hud.open_inventory)
	world.npc_requested.connect(hud.open_dialogue)
	world.market_requested.connect(hud.open_market)
	world.expedition_map_requested.connect(hud.open_expedition_map)
	world.bank_requested.connect(hud.open_bank_service)
	hud.modal_changed.connect(_on_modal_changed)
	hud.return_to_menu_requested.connect(_show_main_menu)
	GameState.monthly_summary_ready.connect(hud.show_month_summary)
	AudioManager._refresh_ambient_track()
	if SaveManager.has_save():
		NoticeManager.show_message("F5 保存 · F9 读取 · C 查看旧物册", "hint")

func _clear_game_nodes() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
		menu = null
	if is_instance_valid(world):
		world.queue_free()
		world = null
	if is_instance_valid(hud):
		hud.queue_free()
		hud = null

func _unhandled_input(event: InputEvent) -> void:
	if not in_game:
		return
	if event.is_action_pressed("save_game"):
		SaveManager.save_game(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("load_game"):
		SaveManager.load_game(true)
		get_viewport().set_input_as_handled()

func _on_modal_changed(is_open: bool) -> void:
	if is_instance_valid(world):
		world.set_player_input_locked(is_open)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if in_game:
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
	AudioManager.shutdown()
	await get_tree().process_frame
	get_tree().quit(error)