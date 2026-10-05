extends Node

## 本地模组接口：从 user://mods/<mod_id>/mod.json 和数据 CSV 合并内容。

signal mods_reloaded

const MOD_ROOT := "user://mods"
const MANIFEST := "mod.json"
const DATA_DIR := "data"

var loaded_mods: Array[Dictionary] = []

func _ready() -> void:
	reload()

func reload() -> void:
	ConfigDB.reload_base_tables()
	loaded_mods.clear()
	var root := ProjectSettings.globalize_path(MOD_ROOT)
	DirAccess.make_dir_recursive_absolute(root)
	for directory in DirAccess.get_directories_at(root):
		_load_mod(root.path_join(directory))
	if not loaded_mods.is_empty():
		print("MODS_LOADED=%d" % loaded_mods.size())
	mods_reloaded.emit()

func _load_mod(mod_dir: String) -> void:
	var manifest_path := mod_dir.path_join(MANIFEST)
	var manifest := _read_json(manifest_path)
	if manifest.is_empty():
		push_warning("模组缺少有效 mod.json：%s" % mod_dir)
		return
	var mod_id := str(manifest.get("id", "")).strip_edges()
	var mod_name := str(manifest.get("name", mod_id)).strip_edges()
	var version := str(manifest.get("version", "0.0.0"))
	var game_version := str(manifest.get("game_version", "0.5.0"))
	if mod_id.is_empty():
		push_warning("模组缺少 id：%s" % mod_dir)
		return
	if not _compatible(game_version):
		push_warning("模组 %s 需要游戏版本 %s，当前为 %s。" % [mod_id, game_version, ProjectSettings.get_setting("application/config/version", "0.5.0")])
		return
	var data_dir := mod_dir.path_join(DATA_DIR)
	var table_counts: Dictionary = {}
	var added_rows := 0
	if DirAccess.dir_exists_absolute(data_dir):
		for file_name in DirAccess.get_files_at(data_dir):
			if not file_name.to_lower().ends_with(".csv"):
				continue
			var table_name := file_name.get_basename()
			if not ConfigDB.has_table(table_name):
				push_warning("模组 %s 使用了未知配置表：%s" % [mod_id, table_name])
				continue
			var merged := ConfigDB.merge_table(table_name, data_dir.path_join(file_name))
			table_counts[table_name] = merged
			added_rows += merged
	loaded_mods.append({
		"id": mod_id,
		"name": mod_name,
		"version": version,
		"game_version": game_version,
		"description": str(manifest.get("description", "")),
		"path": mod_dir,
		"tables": table_counts,
		"added_rows": added_rows,
	})
	_refresh_runtime_catalogs()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parsed = json.parse(file.get_as_text())
	file.close()
	if parsed != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func _compatible(required_version: String) -> bool:
	var current := str(ProjectSettings.get_setting("application/config/version", "0.5.0"))
	var required := required_version.split(".")
	var installed := current.split(".")
	if required.size() < 2 or installed.size() < 2:
		return false
	return required[0] == installed[0] and required[1] == installed[1]

func _refresh_runtime_catalogs() -> void:
	var inv := get_node_or_null("/root/InventoryManager")
	if inv != null and inv.has_method("_load_catalog"):
		inv.call("_load_catalog")

func get_summary() -> String:
	if loaded_mods.is_empty():
		return "当前没有加载本地模组。"
	var names: Array[String] = []
	for mod in loaded_mods:
		names.append("%s %s" % [str(mod.get("name", "")), str(mod.get("version", ""))])
	return "已加载 %d 个模组：%s" % [loaded_mods.size(), "、".join(names)]

func get_mod_lines() -> Array[Dictionary]:
	return loaded_mods.duplicate(true)
