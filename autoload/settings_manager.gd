extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const WINDOW_PRESETS := [Vector2i(1280, 800), Vector2i(1600, 900), Vector2i(1920, 1080)]
var fullscreen := false
var master_volume := 0.85
var window_preset_index := 0

func _ready() -> void:
	load_settings()
	apply_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_settings()
	save_settings()
	settings_changed.emit()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_settings()
	save_settings()
	settings_changed.emit()

func set_window_preset(index: int) -> void:
	window_preset_index = clampi(index, 0, WINDOW_PRESETS.size() - 1)
	apply_settings()
	save_settings()
	settings_changed.emit()

func get_window_presets() -> Array[Vector2i]:
	return WINDOW_PRESETS.duplicate()

func get_window_preset_label(index: int = -1) -> String:
	var resolved := window_preset_index if index < 0 else clampi(index, 0, WINDOW_PRESETS.size() - 1)
	var size: Vector2i = WINDOW_PRESETS[resolved]
	return "%d × %d" % [size.x, size.y]

func apply_settings() -> void:
	# The web canvas follows the browser viewport. Forcing a desktop-sized window
	# here leaves touch coordinates out of sync after mobile rotation/fullscreen.
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var window_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != window_mode:
			DisplayServer.window_set_mode(window_mode)
		if not fullscreen:
			var size: Vector2i = WINDOW_PRESETS[window_preset_index]
			DisplayServer.window_set_size(size)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), master_volume <= 0.001)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(master_volume, 0.001)))

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	window_preset_index = clampi(int(config.get_value("display", "window_preset", window_preset_index)), 0, WINDOW_PRESETS.size() - 1)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "window_preset", window_preset_index)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)
