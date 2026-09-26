extends Node

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _current_track := ""
var _audio_disabled := false

func _ready() -> void:
	_audio_disabled = "--smoke-test" in OS.get_cmdline_user_args() or "--stress-test" in OS.get_cmdline_user_args() or "--full-simulation" in OS.get_cmdline_user_args()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -8.0
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	_sfx_player.volume_db = -4.0
	add_child(_sfx_player)
	NoticeManager.notice_requested.connect(_on_notice_requested)
	CollectionManager.item_collected.connect(_on_item_collected)
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	TimeSystem.minute_changed.connect(_on_minute_changed)
	SettingsManager.settings_changed.connect(_apply_volume)
	_apply_volume()
	call_deferred("_refresh_ambient_track")

func play_music(track_id: String) -> void:
	if _audio_disabled:
		return
	if track_id == _current_track:
		return
	var path := "res://assets/audio/%s.wav" % track_id
	if not ResourceLoader.exists(path):
		return
	_current_track = track_id
	var audio = load(path)
	if audio is AudioStreamWAV:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player.stream = audio
	_music_player.play()

func play_sfx(sfx_id: String) -> void:
	if _audio_disabled:
		return
	var path := "res://assets/audio/%s.wav" % sfx_id
	if not ResourceLoader.exists(path):
		return
	_sfx_player.stream = load(path)
	_sfx_player.play()

func _refresh_ambient_track() -> void:
	if TimeSystem.get_daylight() < 0.25:
		play_music("night_ambient")
	elif WeatherSystem.current_weather_id in ["rain", "humid"]:
		play_music("rain_ambient")
	else:
		play_music("day_ambient")

func _on_minute_changed(minute_of_day: int) -> void:
	if minute_of_day % 60 == 0:
		_refresh_ambient_track()

func _on_weather_changed(_weather_id: String) -> void:
	_refresh_ambient_track()

func _on_notice_requested(_message: String, tone: String) -> void:
	if tone == "warning":
		play_sfx("soft_warning")
	elif tone == "positive":
		play_sfx("soft_confirm")

func _on_item_collected(_item_id: String, rarity: String) -> void:
	play_sfx("legendary_pickup" if rarity == "legendary" else "pickup")

func _apply_volume() -> void:
	if is_instance_valid(_music_player):
		_music_player.volume_db = lerpf(-24.0, -5.0, SettingsManager.master_volume)
	if is_instance_valid(_sfx_player):
		_sfx_player.volume_db = lerpf(-18.0, -2.0, SettingsManager.master_volume)
func shutdown() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	if is_instance_valid(_sfx_player):
		_sfx_player.stop()
		_sfx_player.stream = null
