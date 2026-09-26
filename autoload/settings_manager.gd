extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
var fullscreen := false
var master_volume := 0.85

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

func apply_settings() -> void:
	var window_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != window_mode:
		DisplayServer.window_set_mode(window_mode)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), master_volume <= 0.001)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(master_volume, 0.001)))

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)