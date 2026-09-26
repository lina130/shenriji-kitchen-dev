extends Node

## 轻量 CSV 配置中心。正式数值统一从 data/*.csv 读取。
var tables: Dictionary = {}

func _ready() -> void:
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

func _load_table(table_name: String, path: String, key_field: String) -> void:
	var rows: Dictionary = {}
	var resolved_path := path
	if not FileAccess.file_exists(resolved_path):
		resolved_path = path + ".txt"
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		push_warning("配置表无法读取：%s" % path)
		tables[table_name] = rows
		return
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
			rows[row_key] = row
	tables[table_name] = rows