extends Node

var _music_player: AudioStreamPlayer
var _previous_music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _current_track := ""
var _audio_disabled := false
var _audio_cache: Dictionary = {}
var _music_fade := 1.0
var _music_base_db := -8.0
var _sfx_base_db := -4.0
const MUSIC_FADE_SECONDS := 1.35
const SFX_VOICES := 8
const KITCHEN_CUES := ["kitchen_ticket", "kitchen_pantry", "kitchen_place", "kitchen_wash",
	"kitchen_slice", "kitchen_mix", "kitchen_marinate", "kitchen_portion", "kitchen_steam",
	"kitchen_fry", "kitchen_boil", "kitchen_garnish", "kitchen_ready", "kitchen_serve",
	"kitchen_register", "kitchen_warning", "kitchen_rush"]

func _ready() -> void:
	_audio_disabled = "--smoke-test" in OS.get_cmdline_user_args() or "--stress-test" in OS.get_cmdline_user_args() or "--full-simulation" in OS.get_cmdline_user_args()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	_previous_music_player = AudioStreamPlayer.new()
	_previous_music_player.bus = "Master"
	add_child(_previous_music_player)
	for index in range(SFX_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Master"
		add_child(voice)
		_sfx_players.append(voice)
	NoticeManager.notice_requested.connect(_on_notice_requested)
	CollectionManager.item_collected.connect(_on_item_collected)
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	TimeSystem.minute_changed.connect(_on_minute_changed)
	SceneRouter.travel_completed.connect(_on_scene_changed)
	FestivalManager.festival_started.connect(_on_festival_started)
	SettingsManager.settings_changed.connect(_apply_volume)
	_apply_volume()
	call_deferred("_refresh_ambient_track")

func _process(delta: float) -> void:
	if _music_fade >= 1.0:
		return
	_music_fade = minf(1.0, _music_fade + delta / MUSIC_FADE_SECONDS)
	var angle := _music_fade * PI * 0.5
	_music_player.volume_db = _music_base_db + linear_to_db(maxf(0.001, sin(angle)))
	_previous_music_player.volume_db = _music_base_db + linear_to_db(maxf(0.001, cos(angle)))
	if _music_fade >= 1.0:
		_previous_music_player.stop()
		_previous_music_player.stream = null

func play_music(track_id: String) -> void:
	if _audio_disabled:
		return
	if track_id == _current_track:
		return
	var path := get_resolved_audio_path(track_id)
	if path.is_empty():
		return
	var audio = _load_audio(path)
	if audio == null:
		return
	if audio is AudioStreamWAV:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_current_track = track_id
	var standby := _previous_music_player
	standby.stop()
	_previous_music_player = _music_player
	_music_player = standby
	_music_player.stream = audio
	_music_player.volume_db = _music_base_db - 60.0
	_music_player.play()
	_music_fade = 0.0

func play_kitchen_music(clock_minutes: float) -> void:
	if clock_minutes < 660.0:
		play_music("kitchen_morning")
	elif clock_minutes < 1020.0:
		play_music("kitchen_lunch")
	else:
		play_music("kitchen_evening")

func warm_kitchen_audio() -> void:
	for sound_id in KITCHEN_CUES:
		var path := get_resolved_audio_path(sound_id)
		if not path.is_empty():
			_load_audio(path)

func play_sfx(sfx_id: String) -> void:
	if _audio_disabled:
		return
	var path := get_resolved_audio_path(sfx_id)
	if path.is_empty():
		return
	var audio = _load_audio(path)
	if audio == null:
		return
	var voice: AudioStreamPlayer
	for index in range(_sfx_players.size()):
		var candidate := _sfx_players[(_sfx_cursor + index) % _sfx_players.size()]
		if not candidate.playing:
			voice = candidate
			_sfx_cursor = (_sfx_cursor + index + 1) % _sfx_players.size()
			break
	if voice == null:
		voice = _sfx_players[_sfx_cursor]
		_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	voice.stop()
	voice.stream = audio
	voice.volume_db = _sfx_base_db
	voice.play()

func get_resolved_audio_path(audio_id: String) -> String:
	var baseline := "res://assets/audio/%s.wav" % audio_id
	var override_path := "res://assets/audio/formal/%s.wav" % audio_id
	if ResourceLoader.exists(override_path):
		return override_path
	if ResourceLoader.exists(baseline):
		return baseline
	return ""

func get_current_track_id() -> String:
	return _current_track

func _load_audio(path: String) -> AudioStream:
	if _audio_cache.has(path):
		return _audio_cache[path] as AudioStream
	var audio := load(path) as AudioStream
	_audio_cache[path] = audio
	return audio

func _refresh_ambient_track() -> void:
	if _current_track.begins_with("kitchen_"):
		return
	if FestivalManager.active_event_id != "" and GameState.current_area == FestivalManager.get_today_scene_id():
		play_music("festival_ambient")
		return
	var scene_track := PresentationManager.get_scene_music_key(GameState.current_area)
	if scene_track.is_empty() or scene_track in ["day_ambient", "night_ambient"]:
		if TimeSystem.get_daylight() < 0.25:
			play_music("night_ambient")
		elif WeatherSystem.current_weather_id in ["rain", "humid"]:
			play_music("rain_ambient")
		else:
			play_music(scene_track if not scene_track.is_empty() else "day_ambient")
		return
	play_music(scene_track)

func _on_minute_changed(minute_of_day: int) -> void:
	if minute_of_day % 60 == 0:
		_refresh_ambient_track()

func _on_weather_changed(_weather_id: String) -> void:
	_refresh_ambient_track()

func _on_scene_changed(_area_id: String, _spawn_id: String) -> void:
	_refresh_ambient_track()

func _on_festival_started(_day_key: String, _event_id: String) -> void:
	_refresh_ambient_track()

func _on_notice_requested(_message: String, tone: String, _speaker: String = "", _source_kind: String = "") -> void:
	if tone == "warning":
		play_sfx("soft_warning")
	elif tone == "positive":
		play_sfx("soft_confirm")

func _on_item_collected(_item_id: String, rarity: String) -> void:
	play_sfx("legendary_pickup" if rarity == "legendary" else "pickup")

func _apply_volume() -> void:
	_music_base_db = lerpf(-24.0, -5.0, SettingsManager.master_volume)
	_sfx_base_db = lerpf(-18.0, -2.0, SettingsManager.master_volume)
	if is_instance_valid(_music_player):
		_music_player.volume_db = _music_base_db if _music_fade >= 1.0 else _music_base_db + linear_to_db(maxf(0.001, sin(_music_fade * PI * 0.5)))
	if is_instance_valid(_previous_music_player) and _music_fade < 1.0:
		_previous_music_player.volume_db = _music_base_db + linear_to_db(maxf(0.001, cos(_music_fade * PI * 0.5)))
	for voice in _sfx_players:
		voice.volume_db = _sfx_base_db

func shutdown() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	if is_instance_valid(_previous_music_player):
		_previous_music_player.stop()
		_previous_music_player.stream = null
	for voice in _sfx_players:
		voice.stop()
		voice.stream = null
	_audio_cache.clear()
