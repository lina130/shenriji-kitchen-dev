extends Node

## NPC 个人支线。只通过日常交谈、关系和生活条件推进，不做任务列表。

signal story_advanced(npc_id: String, stage: int, title: String)
signal changed

var stages: Dictionary = {}

func reset_new_game() -> void:
	stages.clear()
	changed.emit()

func try_advance(npc_id: String) -> Dictionary:
	var next_stage := int(stages.get(npc_id, 0)) + 1
	var story_id := "%s_%d" % [npc_id, next_stage]
	var row := ConfigDB.get_row("npc_stories", story_id)
	if row.is_empty():
		return {}
	if RelationshipManager.get_affinity(npc_id) < int(row.get("required_affinity", 0)):
		return {}
	if not _flag_ok(str(row.get("required_flag", ""))):
		return {}
	stages[npc_id] = next_stage
	_apply_reward(row)
	SaveManager.request_auto_save("npc_story")
	story_advanced.emit(npc_id, next_stage, str(row.get("title", "")))
	changed.emit()
	return row

func get_reward_text(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	var reward_type := str(row.get("reward_type", ""))
	var value := int(row.get("reward_value", 0))
	match reward_type:
		"item":
			var item := InventoryManager.get_item(str(row.get("reward_item", "")))
			return "收下了%s。" % str(item.get("name", row.get("reward_item", "一件东西")))
		"money":
			return "这段来往让你额外挣到或省下 ¥%d。" % value
		"energy":
			return "这段交谈让你缓过一口气。"
		"affinity":
			return "你们之间的距离又近了一点。"
	return ""

func get_stage(npc_id: String) -> int:
	return int(stages.get(npc_id, 0))

func get_completed_count() -> int:
	var total := 0
	for npc_id in stages:
		total += int(stages[npc_id])
	return total

func get_summary() -> String:
	var total := ConfigDB.get_rows("npc_stories").size()
	var completed := get_completed_count()
	return "NPC 个人支线已完成 %d/%d 段" % [completed, total]

func get_save_data() -> Dictionary:
	return {"stages": stages.duplicate(true)}

func restore(data: Dictionary) -> void:
	stages = data.get("stages", {}).duplicate(true)
	changed.emit()

func _apply_reward(row: Dictionary) -> void:
	var reward_type := str(row.get("reward_type", ""))
	var value := int(row.get("reward_value", 0))
	match reward_type:
		"item":
			InventoryManager.add_item(str(row.get("reward_item", "")), 1)
		"money":
			GameState.earn(value, "")
		"energy":
			GameState.change_energy(float(value))
		"affinity":
			var npc_id := str(row.get("npc_id", ""))
			RelationshipManager.affinity[npc_id] = int(RelationshipManager.affinity.get(npc_id, 0)) + value
			RelationshipManager.changed.emit()

func _flag_ok(flag: String) -> bool:
	match flag:
		"", "always":
			return true
		"employed":
			return CareerManager.is_employed()
		"factory":
			return CareerManager.current_line == "factory"
		"promoted":
			return CareerManager.current_rank > 1
		"housing_upgraded":
			return HousingManager.current_tier > 0
		"family":
			return FamilyManager.stage_id != "single"
		"collection_10":
			return CollectionManager.discovered.size() >= 10
		"travel":
			return not TravelManager.visited.is_empty()
		"hobby":
			return not HobbyManager.enrolled.is_empty()
		"photo_taken":
			return not PhotoManager.photos.is_empty()
		"business_owned":
			return BusinessManager.business_level > 0 or not EnterpriseManager.owned.is_empty()
		"breakfast_shift":
			return KitchenManager.location_id == "breakfast_shop"
		"staff_hired":
			return not StaffManager.hired.is_empty()
		"wardrobe_owned":
			return not WardrobeManager.owned.is_empty()
		"fish_caught":
			return not FishingManager.catches.is_empty()
		"riverside_visited":
			for photo in PhotoManager.photos:
				if str(photo.get("area_id", "")) == "riverside":
					return true
			return GameState.current_area == "riverside"
		"pet_adopted":
			return not PetManager.adopted.is_empty()
	return false
