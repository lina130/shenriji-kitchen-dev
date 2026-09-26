extends Node

signal game_loaded
signal game_saved

const SAVE_PATH := "user://deep_city_save.json"
const SAVE_VERSION := 4

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(show_notice: bool = true) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"time": TimeSystem.get_save_data(),
		"game": GameState.get_save_data(),
		"inventory": InventoryManager.get_save_data(),
		"random": RandomManager.get_save_data(),
		"weather": WeatherSystem.get_save_data(),
		"collection": CollectionManager.get_save_data(),
		"progression": ProgressionManager.get_save_data(),
		"relationships": RelationshipManager.get_save_data(),
		"market_economy": MarketEconomyManager.get_save_data(),
		"expedition": ExpeditionManager.get_save_data(),
		"treasure": TreasureManager.get_save_data(),
		"business": BusinessManager.get_save_data(),
		"finance": FinanceManager.get_save_data(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		NoticeManager.show_message("存档失败，请稍后再试。", "warning")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	game_saved.emit()
	if show_notice:
		NoticeManager.show_message("生活进度已保存。", "positive")
	return true

func load_game(show_notice: bool = true) -> bool:
	if not has_save():
		NoticeManager.show_message("还没有可以读取的生活记录。", "warning")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		NoticeManager.show_message("读档失败，请稍后再试。", "warning")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		NoticeManager.show_message("存档内容损坏，暂时无法读取。", "warning")
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) > SAVE_VERSION:
		NoticeManager.show_message("这个存档来自更新版本，暂时无法读取。", "warning")
		return false
	TimeSystem.restore(data.get("time", {}))
	GameState.restore(data.get("game", {}))
	InventoryManager.restore(data.get("inventory", {}))
	RandomManager.restore(data.get("random", {}))
	WeatherSystem.restore(data.get("weather", {}))
	CollectionManager.restore(data.get("collection", {}))
	ProgressionManager.restore(data.get("progression", {}))
	RelationshipManager.restore(data.get("relationships", {}))
	MarketEconomyManager.restore(data.get("market_economy", {}))
	ExpeditionManager.restore(data.get("expedition", {}))
	TreasureManager.restore(data.get("treasure", {}))
	BusinessManager.restore(data.get("business", {}))
	FinanceManager.restore(data.get("finance", {}))
	SceneRouter.restore(GameState.current_area, GameState.spawn_id)
	game_loaded.emit()
	if show_notice:
		NoticeManager.show_message("生活进度已读取。", "positive")
	return true