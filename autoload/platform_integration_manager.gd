extends Node

## Steamworks / 平台接口预留。未加载 Steam 插件时自动使用本地回退，不影响单机。

signal platform_state_changed(provider: String)

var provider := "local"
var local_achievements: Dictionary = {}
var local_stats: Dictionary = {}

func _ready() -> void:
	provider = "steam" if Engine.has_singleton("Steam") else "local"
	platform_state_changed.emit(provider)

func reset_new_game() -> void:
	local_achievements.clear()
	local_stats.clear()

func is_steam_available() -> bool:
	return provider == "steam" and Engine.has_singleton("Steam")

func unlock_achievement(achievement_id: String) -> bool:
	if is_steam_available():
		var steam := Engine.get_singleton("Steam")
		if steam.has_method("unlock_achievement"):
			steam.call("unlock_achievement", achievement_id)
	local_achievements[achievement_id] = true
	return true

func set_stat(stat_id: String, value: float) -> void:
	local_stats[stat_id] = value
	if is_steam_available():
		var steam := Engine.get_singleton("Steam")
		if steam.has_method("set_stat"):
			steam.call("set_stat", stat_id, value)

func get_stat(stat_id: String, fallback: float = 0.0) -> float:
	return float(local_stats.get(stat_id, fallback))

func cloud_available() -> bool:
	if not is_steam_available():
		return false
	var steam := Engine.get_singleton("Steam")
	return steam.has_method("cloud_write")

func get_summary() -> String:
	return "平台：%s · 本地成就 %d 条" % ["Steam" if is_steam_available() else "本地回退", local_achievements.size()]

func get_save_data() -> Dictionary:
	return {"local_achievements": local_achievements.duplicate(true), "local_stats": local_stats.duplicate(true)}

func restore(data: Dictionary) -> void:
	local_achievements = data.get("local_achievements", {}).duplicate(true)
	local_stats = data.get("local_stats", {}).duplicate(true)
