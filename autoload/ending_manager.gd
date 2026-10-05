extends Node

signal changed
signal ending_recorded(ending_id: String, name: String)

var endings: Dictionary = {}
var last_ending_id := ""

func reset_new_game() -> void:
	endings.clear()
	last_ending_id = ""
	changed.emit()

func begin_new_day(_day_number: int) -> void:
	evaluate()

func evaluate() -> void:
	var total_money := GameState.money + FinanceManager.savings
	if HousingManager.current_tier >= 3 and FamilyManager.stage_id == "family":
		_record("stable_life")
	if EnterpriseManager.owned.size() >= ConfigDB.get_rows("enterprises").size() and not ConfigDB.get_rows("enterprises").is_empty():
		_record("small_boss")
	if total_money >= 100000:
		_record("millionaire")
	if CareerManager.current_line == "restaurant" and CareerManager.current_rank >= 4:
		_record("master_chef")
	if CareerManager.current_line == "factory" and CareerManager.current_rank >= 4:
		_record("factory_lead")
	if EducationManager.credentials.size() >= 3:
		_record("scholar")
	if TravelManager.postcards.size() >= ConfigDB.get_rows("travel_destinations").size() and not ConfigDB.get_rows("travel_destinations").is_empty():
		_record("world_wanderer")
	if CollectionManager.discovered.size() >= ConfigDB.get_rows("collectibles").size() and not ConfigDB.get_rows("collectibles").is_empty():
		_record("collector")
	if not PetManager.adopted.is_empty() and FamilyManager.stage_id == "family":
		_record("animal_family")
	if EnterpriseManager.is_owned("snack_drink") and CareerManager.current_rank >= 2:
		_record("coffee_shop_life")
	_evaluate_data_conditions()

func _evaluate_data_conditions() -> void:
	for ending_id in ConfigDB.get_rows("life_endings"):
		var row := ConfigDB.get_row("life_endings", str(ending_id))
		var condition_type := str(row.get("condition_type", ""))
		if condition_type.is_empty():
			continue
		if _condition_met(condition_type, str(row.get("condition_value", ""))):
			_record(str(ending_id))

func _condition_met(condition_type: String, raw_value: String) -> bool:
	match condition_type:
		"career_rank":
			var parts := raw_value.split(":", false)
			return parts.size() == 2 and CareerManager.current_line == parts[0] and CareerManager.current_rank >= int(parts[1])
		"career_shifts":
			return CareerManager.shifts_done >= int(raw_value)
		"housing_tier":
			return HousingManager.current_tier >= int(raw_value)
		"savings":
			return FinanceManager.savings >= int(raw_value)
		"staff_count":
			return StaffManager.hired.size() >= int(raw_value)
		"business_level":
			return BusinessManager.business_level >= int(raw_value)
		"animal_count":
			return FarmManager.animals.size() >= int(raw_value)
		"farm_harvest":
			return int(AchievementManager.event_counts.get("farm_harvest", 0)) >= int(raw_value)
		"fish_catches":
			return _total_fish_catches() >= int(raw_value)
		"moon_fish":
			return int(FishingManager.catches.get("moonfish", 0)) >= int(raw_value)
		"riverside_photos":
			return _riverside_photo_count() >= int(raw_value)
		"photos":
			return PhotoManager.photos.size() >= int(raw_value)
		"market_sales":
			return MarketEconomyManager.total_sales >= int(raw_value)
		"consignments":
			return MarketEconomyManager.completed_consignments >= int(raw_value)
		"wardrobe":
			return WardrobeManager.owned.size() >= int(raw_value)
		"pet_training":
			return _best_pet_training() >= float(raw_value)
		"health":
			return GameState.health >= float(raw_value)
		"stress_below":
			return WellbeingManager.stress <= float(raw_value)
		"hobby_level":
			return _best_hobby_level() >= int(raw_value)
		"credentials":
			return EducationManager.credentials.size() >= int(raw_value)
		"festival_year":
			return FestivalManager.has_all_current_year()
		"friends":
			return RelationshipManager.get_friend_count(10) >= int(raw_value)
		"enterprise_count":
			return EnterpriseManager.owned.size() >= int(raw_value)
	return false

func _total_fish_catches() -> int:
	var total := 0
	for fish_id in FishingManager.catches:
		total += int(FishingManager.catches[fish_id])
	return total

func _riverside_photo_count() -> int:
	var total := 0
	for photo in PhotoManager.photos:
		if str(photo.get("area_id", "")) == "riverside":
			total += 1
	return total

func _best_pet_training() -> float:
	var best := 0.0
	for pet_id in PetManager.adopted:
		best = maxf(best, float(PetManager.adopted[pet_id].get("training", 0.0)))
	return best

func _best_hobby_level() -> int:
	var best := 0
	for hobby_id in HobbyManager.levels:
		best = maxi(best, int(HobbyManager.levels[hobby_id]))
	return best

func _record(ending_id: String) -> void:
	if endings.has(ending_id):
		return
	var row := ConfigDB.get_row("life_endings", ending_id)
	if row.is_empty():
		return
	endings[ending_id] = true
	last_ending_id = ending_id
	NoticeManager.show_message("%s：%s" % [str(row.get("name", ending_id)), str(row.get("description", ""))], "positive", str(row.get("speaker", "街坊")))
	SaveManager.request_auto_save("life_ending")
	ending_recorded.emit(ending_id, str(row.get("name", ending_id)))
	changed.emit()

func get_summary() -> String:
	return "留下 %d 条人生注脚" % endings.size()

func get_endings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ending_id in endings:
		var row := ConfigDB.get_row("life_endings", ending_id)
		result.append({"id": str(ending_id), "name": str(row.get("name", ending_id)), "description": str(row.get("description", ""))})
	return result

func get_hint_lines() -> Array[String]:
	var result: Array[String] = []
	for ending_id in ConfigDB.get_rows("life_endings"):
		if endings.has(ending_id):
			continue
		var row := ConfigDB.get_row("life_endings", ending_id)
		result.append("%s：%s" % [str(row.get("speaker", "街坊")), str(row.get("hint", ""))])
	return result

func get_save_data() -> Dictionary:
	return {"endings": endings.duplicate(true), "last_ending_id": last_ending_id}

func restore(data: Dictionary) -> void:
	endings = data.get("endings", {}).duplicate(true)
	last_ending_id = str(data.get("last_ending_id", ""))
	changed.emit()
