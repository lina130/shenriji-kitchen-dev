extends Node

## 轻量 CSV 配置中心。正式数值统一从 data/*.csv 读取。
var tables: Dictionary = {}
var _key_fields: Dictionary = {}

func _ready() -> void:
	_load_all_tables()

func _load_all_tables() -> void:
	tables.clear()
	_key_fields.clear()
	_load_table("items", "res://data/items.csv", "item_id")
	_load_table("collectibles", "res://data/collectibles.csv", "item_id")
	_load_table("balance", "res://data/balance.csv", "key")
	_load_table("weather", "res://data/weather.csv", "weather_id")
	_load_table("npcs", "res://data/npcs.csv", "npc_id")
	_load_table("ruins", "res://data/ruins.csv", "site_id")
	_load_table("goods", "res://data/goods.csv", "goods_id")
	_load_table("recipes", "res://data/recipes.csv", "recipe_id")
	_load_table("business", "res://data/business.csv", "key")
	_load_table("bank", "res://data/bank.csv", "key")
	_load_table("calendar", "res://data/calendar.csv", "calendar_day")
	_load_table("festival_events", "res://data/festival_events.csv", "calendar_day")
	_load_table("crops", "res://data/crops.csv", "crop_id")
	_load_table("farm_tools", "res://data/farm_tools.csv", "tool_id")
	_load_table("farm_animals", "res://data/farm_animals.csv", "animal_id")
	_load_table("story_chapters", "res://data/story_chapters.csv", "trigger_action")
	_load_table("random_events", "res://data/random_events.csv", "event_id")
	_load_table("scene_metadata", "res://data/scene_metadata.csv", "area_id")
	_load_table("scene_zones", "res://data/scene_zones.csv", "zone_id")
	_load_table("visual_bindings", "res://data/visual_bindings.csv", "binding_id")
	_load_table("theme_tokens", "res://data/theme_tokens.csv", "token")
	_load_table("ui_text_styles", "res://data/ui_text_styles.csv", "style_id")
	_load_table("ui_assets", "res://data/ui_assets.csv", "asset_id")
	_load_table("fish", "res://data/fish.csv", "fish_id")
	_load_table("fishing_rods", "res://data/fishing_rods.csv", "rod_id")
	_load_table("housing", "res://data/housing.csv", "housing_id")
	_load_table("travel_destinations", "res://data/travel_destinations.csv", "destination_id")
	_load_table("enterprises", "res://data/enterprises.csv", "enterprise_id")
	_load_table("achievements", "res://data/achievements.csv", "achievement_id")
	_load_table("family_stages", "res://data/family_stages.csv", "stage_id")
	_load_table("child_stages", "res://data/child_stages.csv", "stage_id")
	_load_table("life_conditions", "res://data/life_conditions.csv", "condition_id")
	_load_table("unlock_levels", "res://data/unlock_levels.csv", "level_id")
	_load_table("clinic_services", "res://data/clinic_services.csv", "service_id")
	_load_table("life_endings", "res://data/life_endings.csv", "ending_id")
	_load_table("hobbies", "res://data/hobbies.csv", "hobby_id")
	_load_table("courses", "res://data/courses.csv", "course_id")
	_load_table("pets", "res://data/pets.csv", "pet_id")
	_load_table("petshop", "res://data/petshop.csv", "key")
	_load_table("furniture", "res://data/furniture.csv", "furniture_id")
	_load_table("staff", "res://data/staff.csv", "npc_id")
	_load_table("staff_candidates", "res://data/staff_candidates.csv", "candidate_id")
	_load_table("npc_schedule", "res://data/npc_schedule.csv", "npc_id")
	_load_table("npc_dialogue", "res://data/npc_dialogue.csv", "npc_id")
	_load_table("npc_stories", "res://data/npc_stories.csv", "story_id")
	_load_table("breakfast", "res://data/breakfast.csv", "key")
	_load_table("breakfast_menu", "res://data/breakfast_menu.csv", "item_id")
	_load_table("market_phases", "res://data/market_phases.csv", "phase_id")
	_load_table("night_market", "res://data/night_market.csv", "stall_id")
	_load_table("equipment", "res://data/equipment.csv", "station_type")
	_load_table("recruitment_channels", "res://data/recruitment_channels.csv", "channel_id")
	_load_table("careers", "res://data/careers.csv", "career_id")
	_load_table("clothing", "res://data/clothing.csv", "clothing_id")
	_load_table("festival_menu", "res://data/festival_menu.csv", "recipe_id")
	_load_table("customer_types", "res://data/customer_types.csv", "customer_id")
	_load_table("renovations", "res://data/renovations.csv", "renovation_id")

func get_rows(table_name: String) -> Dictionary:
	return tables.get(table_name, {})

func get_row(table_name: String, row_key: String) -> Dictionary:
	var rows := get_rows(table_name)
	return rows.get(row_key, {})

func get_number(table_name: String, row_key: String, fallback: float) -> float:
	var row := get_row(table_name, row_key)
	if row.is_empty():
		return fallback
	return float(row.get("value", fallback))

func get_key_field(table_name: String) -> String:
	return str(_key_fields.get(table_name, ""))

func has_table(table_name: String) -> bool:
	return _key_fields.has(table_name)

func reload_base_tables() -> void:
	_load_all_tables()

func merge_table(table_name: String, path: String) -> int:
	if not has_table(table_name):
		return 0
	var incoming := _parse_table(table_name, path, get_key_field(table_name))
	return merge_rows(table_name, incoming)

func merge_rows(table_name: String, incoming: Dictionary) -> int:
	if not has_table(table_name):
		return 0
	var rows: Dictionary = tables.get(table_name, {})
	var added := 0
	for row_key in incoming:
		var value = incoming[row_key]
		if typeof(value) == TYPE_ARRAY and get_key_field(table_name) == "npc_id" and (table_name == "npc_schedule" or table_name == "npc_dialogue"):
			var existing = rows.get(row_key, [])
			if typeof(existing) != TYPE_ARRAY:
				existing = [existing]
			for item in value:
				existing.append(item)
				added += 1
			rows[row_key] = existing
		else:
			if not rows.has(row_key):
				added += 1
			rows[row_key] = value
	tables[table_name] = rows
	return added

func _load_table(table_name: String, path: String, key_field: String) -> void:
	_key_fields[table_name] = key_field
	tables[table_name] = _parse_table(table_name, path, key_field)

func _parse_table(table_name: String, path: String, key_field: String) -> Dictionary:
	var rows: Dictionary = {}
	var resolved_path := path
	if not FileAccess.file_exists(resolved_path):
		resolved_path = path + ".txt"
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		push_warning("配置表无法读取：%s" % path)
		return rows
	var headers := file.get_csv_line()
	while not file.eof_reached():
		var values := file.get_csv_line()
		if values.is_empty() or values[0].strip_edges().is_empty():
			continue
		var row: Dictionary = {}
		for index in range(mini(headers.size(), values.size())):
			var key := headers[index].strip_edges()
			row[key] = values[index].strip_edges()
		var row_key := str(row.get(key_field, "")).strip_edges()
		if not row_key.is_empty():
			if key_field == "npc_id" and (table_name == "npc_schedule" or table_name == "npc_dialogue"):
				var existing = rows.get(row_key, [])
				if typeof(existing) != TYPE_ARRAY:
					existing = [existing]
				existing.append(row)
				rows[row_key] = existing
			else:
				rows[row_key] = row
	return rows