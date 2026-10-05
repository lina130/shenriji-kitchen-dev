extends Node

signal achievement_unlocked(achievement_id: String)
signal changed

var unlocked: Dictionary = {}
var event_counts: Dictionary = {}

func _ready() -> void:
	CareerManager.promoted.connect(_on_promoted)
	KitchenManager.shift_ended.connect(_on_shift_ended)
	FishingManager.fish_caught.connect(_on_fish_caught)
	TravelManager.traveled.connect(_on_traveled)
	FarmManager.changed.connect(check_all)
	StaffManager.changed.connect(check_all)
	BusinessManager.changed.connect(check_all)
	HousingManager.changed.connect(check_all)
	EnterpriseManager.changed.connect(check_all)
	PetManager.pet_adopted.connect(_on_pet_adopted)
	StoryManager.story_advanced.connect(_on_story_advanced)
	FestivalManager.festival_gift_claimed.connect(_on_festival_gift_claimed)
	NpcStoryManager.story_advanced.connect(_on_npc_story_advanced)
	FamilyManager.changed.connect(check_all)

func reset_new_game() -> void:
	unlocked.clear()
	event_counts.clear()
	changed.emit()

func record_event(event_id: String, amount: int = 1) -> void:
	event_counts[event_id] = int(event_counts.get(event_id, 0)) + amount
	check_all()

func check_all() -> void:
	if _has_career_shift():
		_unlock("first_wage")
	if KitchenManager.served > 0:
		_unlock("first_serve")
	if event_counts.has("rush_shift"):
		_unlock("rush_shift")
	if event_counts.has("combo_five"):
		_unlock("combo_five")
	if int(FishingManager.catches.size()) > 0:
		_unlock("first_catch")
	if TravelManager.visited.size() > 0:
		_unlock("first_travel")
	if not StaffManager.hired.is_empty():
		_unlock("first_hire")
	if event_counts.has("referral_lead"):
		_unlock("referral_lead")
	if event_counts.has("shipping_sale"):
		_unlock("shipping_sale")
	if _has_referral_hire():
		_unlock("referral_trusted")
	if event_counts.has("farm_harvest"):
		_unlock("farm_harvest")
	if not PetManager.adopted.is_empty():
		_unlock("pet_family")
	if not EnterpriseManager.owned.is_empty():
		_unlock("own_business")
	if int(FishingManager.catches.get("moonfish", 0)) > 0:
		_unlock("moon_fish")
	if _career_route_count() >= 6:
		_unlock("six_lives")
	if TravelManager.postcards.size() >= ConfigDB.get_rows("travel_destinations").size() and not ConfigDB.get_rows("travel_destinations").is_empty():
		_unlock("postcard_master")
	if PhotoManager.photos.size() >= 10:
		_unlock("photo_album")
	if HousingManager.current_tier >= 3:
		_unlock("home_owner")
	if EnterpriseManager.owned.size() >= ConfigDB.get_rows("enterprises").size() and not ConfigDB.get_rows("enterprises").is_empty():
		_unlock("tycoon")
	if CollectionManager.discovered.size() >= ConfigDB.get_rows("collectibles").size() and not ConfigDB.get_rows("collectibles").is_empty():
		_unlock("collection_master")
	if FestivalManager.claimed.size() > 0:
		_unlock("first_festival")
	if event_counts.has("festival_activity"):
		_unlock("festival_activity")
	if FestivalManager.has_all_current_year():
		_unlock("festival_year")
	if event_counts.has("birthday_greeting"):
		_unlock("birthday_friend")
	if event_counts.has("birthday_gift"):
		_unlock("birthday_gift")
	if FamilyManager.stage_id in ["married", "family"]:
		_unlock("married_life")
	if event_counts.has("shared_evening"):
		_unlock("shared_evening")
	if event_counts.has("partner_date"):
		_unlock("partner_date")
	if event_counts.has("divorce"):
		_unlock("new_chapter")
	if NpcStoryManager.get_completed_count() > 0:
		_unlock("first_npc_story")
	if NpcStoryManager.get_completed_count() >= ConfigDB.get_rows("npc_stories").size() and not ConfigDB.get_rows("npc_stories").is_empty():
		_unlock("npc_story_master")

func _has_referral_hire() -> bool:
	for profile in StaffManager.hired.values():
		if str(profile.get("source", "")) == "referral":
			return true
	return false

func _has_career_shift() -> bool:
	if CareerManager.shifts_done > 0 or CareerManager.current_rank > 1:
		return true
	for event_id in event_counts:
		if str(event_id).begins_with("career_route:"):
			return true
	return false

func _career_route_count() -> int:
	var routes: Dictionary = {}
	for event_id in event_counts:
		if str(event_id).begins_with("career_route:"):
			routes[str(event_id).trim_prefix("career_route:")] = true
	return routes.size()

func _unlock(achievement_id: String) -> void:
	if unlocked.has(achievement_id):
		return
	var row := ConfigDB.get_row("achievements", achievement_id)
	if row.is_empty():
		return
	unlocked[achievement_id] = true
	PlatformIntegrationManager.unlock_achievement(achievement_id)
	NoticeManager.show_message("你好像做到了：%s。" % str(row.get("description", achievement_id)), "positive", str(row.get("hint_speaker", "街坊")))
	if unlocked.size() >= 3 and not unlocked.has("three_marks"):
		_unlock("three_marks")
	if unlocked.size() >= 3 and not event_counts.has("achievement_story"):
		event_counts["achievement_story"] = 1
		StoryManager.record_action("achievement_milestone")
	SaveManager.request_auto_save("achievement")
	achievement_unlocked.emit(achievement_id)
	changed.emit()

func _on_promoted(_line_id: String, _title: String, _hint: String) -> void:
	record_event("promotion")
	check_all()

func _on_shift_ended(summary: Dictionary) -> void:
	record_event("shift")
	if str(summary.get("reason", "")) != "transition" and bool(summary.get("rush_active", false)):
		record_event("rush_shift")
	if str(summary.get("reason", "")) != "transition" and int(summary.get("max_combo", 0)) >= 5:
		record_event("combo_five")
	check_all()

func _on_fish_caught(fish_id: String, _goods_id: String, _amount: int) -> void:
	record_event("fish", 1)
	if fish_id == "moonfish":
		_unlock("moon_fish")

func _on_traveled(_destination_id: String) -> void:
	record_event("travel")
	check_all()

func _on_pet_adopted(_pet_id: String) -> void:
	record_event("pet")
	check_all()

func _on_story_advanced(_chapter: int, _title: String) -> void:
	record_event("story")
	check_all()

func _on_festival_gift_claimed(_day_key: String, _item_id: String) -> void:
	record_event("festival")
	check_all()

func _on_npc_story_advanced(_npc_id: String, _stage: int, _title: String) -> void:
	record_event("npc_story")
	check_all()

func get_natural_hint() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for achievement_id in ConfigDB.get_rows("achievements"):
		if unlocked.has(achievement_id):
			continue
		var row := ConfigDB.get_row("achievements", str(achievement_id))
		var hint := str(row.get("hint", ""))
		if hint.is_empty():
			continue
		candidates.append({"text": hint, "speaker": str(row.get("hint_speaker", "街坊"))})
	if candidates.is_empty():
		return {}
	return candidates[RandomManager.rng.randi_range(0, candidates.size() - 1)]

func get_summary() -> String:
	return "见闻已留下 %d 条" % unlocked.size()

func get_hint_lines() -> Array[String]:
	var result: Array[String] = []
	for achievement_id in ConfigDB.get_rows("achievements"):
		if unlocked.has(achievement_id):
			continue
		var row := ConfigDB.get_row("achievements", achievement_id)
		result.append("%s：%s" % [str(row.get("hint_speaker", "街坊")), str(row.get("hint", ""))])
	return result

func get_save_data() -> Dictionary:
	return {"unlocked": unlocked.duplicate(true), "event_counts": event_counts.duplicate(true)}

func restore(data: Dictionary) -> void:
	unlocked = data.get("unlocked", {}).duplicate(true)
	event_counts = data.get("event_counts", {}).duplicate(true)
	changed.emit()
