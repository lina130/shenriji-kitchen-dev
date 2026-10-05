extends Node

signal changed
signal photo_taken(photo_id: String, area_id: String)

const PHOTO_DIR := "user://photos"
const MAX_PHOTOS := 80

var photos: Array = []
var counter := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PHOTO_DIR))

func reset_new_game() -> void:
	photos.clear()
	counter = 0
	changed.emit()

func take_photo(area_id: String = "") -> bool:
	var resolved_area := GameState.current_area if area_id.is_empty() else area_id
	var texture := PresentationManager.get_scene_texture(resolved_area)
	if texture == null:
		NoticeManager.show_scene_message("这里的光线或角度不适合拍照。", "相机", "hint")
		return false
	var image := texture.get_image()
	if image == null:
		return false
	counter += 1
	var photo_id := "%s_%04d" % [resolved_area, counter]
	var file_name := "%s_%d.png" % [photo_id, Time.get_unix_time_from_system()]
	var path := "%s/%s" % [PHOTO_DIR, file_name]
	var err := image.save_png(path)
	if err != OK:
		NoticeManager.show_scene_message("照片没有保存成功，再试一次。", "相机", "warning")
		return false
	photos.append({
		"id": photo_id,
		"area_id": resolved_area,
		"scene_name": str(PresentationManager.get_scene_metadata(resolved_area).get("display_name", resolved_area)),
		"day": TimeSystem.current_day,
		"time": TimeSystem.get_time_text(),
		"weather": WeatherSystem.get_weather_name(),
		"path": path,
	})
	while photos.size() > MAX_PHOTOS:
		var old: Dictionary = photos.pop_front()
		var old_path := str(old.get("path", ""))
		if FileAccess.file_exists(old_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	NoticeManager.show_scene_message("拍下了一张%s，照片已经放进相册。" % str(PresentationManager.get_scene_metadata(resolved_area).get("display_name", resolved_area)), "相机", "positive")
	SaveManager.request_auto_save("photo")
	photo_taken.emit(photo_id, resolved_area)
	changed.emit()
	return true

func get_photos() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(photos.duplicate(true))
	return result

func get_summary() -> String:
	return "相册里有 %d 张照片" % photos.size()

func get_save_data() -> Dictionary:
	return {"photos": photos.duplicate(true), "counter": counter}

func restore(data: Dictionary) -> void:
	photos = data.get("photos", []).duplicate(true)
	counter = int(data.get("counter", photos.size()))
	changed.emit()
