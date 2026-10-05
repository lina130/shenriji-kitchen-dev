extends Node

signal changed

var visits := 0
var last_service_id := ""

func reset_new_game() -> void:
	visits = 0
	last_service_id = ""
	changed.emit()

func visit_service(service_id: String) -> bool:
	var row := ConfigDB.get_row("clinic_services", service_id)
	if row.is_empty():
		return false
	var cost := int(row.get("cost", "0"))
	if not GameState.spend(cost, "在诊所做了%s。" % str(row.get("name", service_id))):
		return false
	GameState.health = clampf(GameState.health + float(row.get("health_delta", "0")), 0.0, 100.0)
	WellbeingManager.stress = clampf(WellbeingManager.stress + float(row.get("stress_delta", "0")), 0.0, 100.0)
	GameState.change_energy(float(row.get("energy_delta", "0")))
	TimeSystem.advance_minutes(int(row.get("minutes", "60")))
	visits += 1
	last_service_id = service_id
	NoticeManager.show_message("做完%s了。%s" % [str(row.get("name", service_id)), _condition_hint()], "positive", "诊所护士")
	SaveManager.request_auto_save("medical_visit")
	changed.emit()
	return true

func get_hint() -> String:
	if GameState.health <= 25.0:
		return "脸色不太好，别硬撑着去上班。"
	if WellbeingManager.stress >= 70.0:
		return "最近压力太重，睡不好也会拖垮身体。"
	if GameState.health <= 55.0:
		return "看着还撑得住，但该休息就休息。"
	return "状态还算稳，注意别长期透支。"

func get_service_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for service_id in ConfigDB.get_rows("clinic_services"):
		var row := ConfigDB.get_row("clinic_services", service_id)
		result.append({
			"id": str(service_id),
			"name": str(row.get("name", service_id)),
			"cost": int(row.get("cost", "0")),
			"description": str(row.get("description", "")),
		})
	return result

func get_summary() -> String:
	return "社区诊所年度就诊 %d 次" % visits

func _condition_hint() -> String:
	return get_hint()

func get_save_data() -> Dictionary:
	return {"visits": visits, "last_service_id": last_service_id}

func restore(data: Dictionary) -> void:
	visits = int(data.get("visits", 0))
	last_service_id = str(data.get("last_service_id", ""))
	changed.emit()
