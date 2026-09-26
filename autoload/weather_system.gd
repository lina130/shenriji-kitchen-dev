extends Node

signal weather_changed(weather_id: String)

var current_weather_id := "sunny"

func begin_new_day(_day_number: int) -> void:
	var choices: Array[String] = []
	var total_weight := 0.0
	for weather_id in ConfigDB.get_rows("weather"):
		var row := ConfigDB.get_row("weather", weather_id)
		var weight := float(row.get("weight", "1"))
		total_weight += weight
		choices.append(weather_id)
	var roll := RandomManager.rng.randf() * total_weight
	var accumulated := 0.0
	for weather_id in choices:
		var row := ConfigDB.get_row("weather", weather_id)
		accumulated += float(row.get("weight", "1"))
		if roll <= accumulated:
			current_weather_id = weather_id
			break
	weather_changed.emit(current_weather_id)

func get_weather_name() -> String:
	return str(ConfigDB.get_row("weather", current_weather_id).get("name", "晴"))

func get_description() -> String:
	return str(ConfigDB.get_row("weather", current_weather_id).get("description", ""))

func get_tint() -> Color:
	var raw := str(ConfigDB.get_row("weather", current_weather_id).get("tint", "#ffffff"))
	return Color.from_string(raw, Color.WHITE)

func get_collection_bonus() -> float:
	return float(ConfigDB.get_row("weather", current_weather_id).get("collection_bonus", "0"))

func get_work_energy_multiplier() -> float:
	return float(ConfigDB.get_row("weather", current_weather_id).get("work_energy_multiplier", "1"))

func get_store_sales_bonus() -> float:
	return float(ConfigDB.get_row("weather", current_weather_id).get("store_sales_bonus", "1"))

func get_save_data() -> Dictionary:
	return {"current_weather_id": current_weather_id}

func restore(data: Dictionary) -> void:
	current_weather_id = str(data.get("current_weather_id", "sunny"))
	weather_changed.emit(current_weather_id)

func reset_new_game() -> void:
	current_weather_id = "sunny"