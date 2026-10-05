extends SceneTree

const LifeScript := preload("res://scripts/city3d/city_life_state.gd")
const ChunkScript := preload("res://scripts/city3d/city_chunk.gd")
const SAVE_PATH := "user://city3d_easter_egg_test.json"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var life = LifeScript.new()
	if not life.discover_neighbor_memento().is_empty():
		_fail("Memento appeared before meeting the neighbor through daily life")
		return
	life.career_shifts["restaurant"] = 2
	life.rest_day()
	var item: Dictionary = life.discover_neighbor_memento()
	if item.get("name", "") != "老巷电影票册" or life.items.size() != 1:
		_fail("One-time neighbor memento did not enter the collection")
		return
	life.rest_day()
	if not life.discover_neighbor_memento().is_empty() or life.items.size() != 1:
		_fail("Sleeping renewed the easter egg like a daily loot point")
		return
	if not life.save_to_disk(SAVE_PATH):
		_fail("Memento save failed")
		return
	var loaded = LifeScript.new()
	if not loaded.load_from_disk(SAVE_PATH) or not loaded.found_secrets.has("nantou_neighbor") or loaded.items.size() != 1:
		_fail("Memento did not survive save and load")
		return
	if not loaded.discover_neighbor_memento().is_empty():
		_fail("Memento duplicated after load")
		return
	var legacy_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"version": 1, "discovered": {"老巷电影票册": true}}))
	legacy_file.close()
	var legacy = LifeScript.new()
	if not legacy.load_from_disk(SAVE_PATH) or not legacy.found_secrets.has("nantou_neighbor"):
		_fail("Older cache saves were not migrated to the one-time memento")
		return
	var chunk = ChunkScript.new()
	chunk.configure(-1)
	root.add_child(chunk)
	await process_frame
	var has_neighbor := false
	for area in get_nodes_in_group("city3d_interactable"):
		if not chunk.is_ancestor_of(area):
			continue
		var interaction_id := str(area.get_meta("interaction_id", ""))
		if interaction_id == "neighbor":
			has_neighbor = true
		if interaction_id.begins_with("search_") or interaction_id.begins_with("inspect_"):
			_fail("The street still contains a fixed treasure cache")
			return
	if not has_neighbor:
		_fail("Ordinary neighbor interaction is missing")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("CITY3D_EASTER_EGG_OK")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
