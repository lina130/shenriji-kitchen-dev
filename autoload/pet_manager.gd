extends Node

## 宠物系统：喂食、睡眠、运动、清洁、训练、成长，并带来经营增益。

signal changed
signal pet_adopted(pet_id: String)

var adopted: Dictionary = {}
var active_pet_id := ""

func _ready() -> void:
	reset_new_game()

func reset_new_game() -> void:
	adopted.clear()
	active_pet_id = ""
	changed.emit()

func adopt(pet_id: String) -> bool:
	var row := ConfigDB.get_row("pets", pet_id)
	if row.is_empty():
		return false
	if adopted.has(pet_id):
		NoticeManager.show_message("这只小家伙已经在你家了。", "hint")
		return false
	var price := int(row.get("price", "0"))
	if not GameState.spend(price, "把%s接回了家。" % str(row.get("name", pet_id))):
		return false
	adopted[pet_id] = {"fullness": 70.0, "energy": 70.0, "mood": 70.0, "clean": 70.0, "training": 0.0, "growth": 0.0, "stage": "baby", "days_together": 0}
	if active_pet_id.is_empty():
		active_pet_id = pet_id
	StoryManager.record_action("pet_adopt")
	pet_adopted.emit(pet_id)
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true

func has_pet(pet_id: String) -> bool:
	return adopted.has(pet_id)

func set_active(pet_id: String) -> bool:
	if not adopted.has(pet_id):
		return false
	active_pet_id = pet_id
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true

func get_active_pet_id() -> String:
	return active_pet_id

func feed(pet_id: String = "") -> bool:
	var target := _resolve(pet_id)
	if target.is_empty():
		return false
	if not InventoryManager.remove_item("pet_feed", 1):
		NoticeManager.show_message("没有宠物粮了，去宠物商店买一点吧。", "warning")
		return false
	var state: Dictionary = adopted[target]
	state["fullness"] = clampf(float(state.get("fullness", 0.0)) + 35.0, 0.0, 100.0)
	state["mood"] = clampf(float(state.get("mood", 0.0)) + 6.0, 0.0, 100.0)
	NoticeManager.show_message("%s吃饱了，蹭了蹭你的手。" % _pet_name(target), "positive")
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true

func play(pet_id: String = "") -> bool:
	var target := _resolve(pet_id)
	if target.is_empty():
		return false
	var state: Dictionary = adopted[target]
	if float(state.get("energy", 0.0)) < 12.0:
		NoticeManager.show_message("%s太累了，先让它睡一会儿。" % _pet_name(target), "warning")
		return false
	state["energy"] = clampf(float(state.get("energy", 0.0)) - 12.0, 0.0, 100.0)
	var used_toy := InventoryManager.get_count("pet_toy") > 0
	if used_toy:
		InventoryManager.remove_item("pet_toy", 1)
	state["mood"] = clampf(float(state.get("mood", 0.0)) + (34.0 if used_toy else 22.0), 0.0, 100.0)
	state["training"] = clampf(float(state.get("training", 0.0)) + 4.0, 0.0, 100.0)
	GameState.change_energy(-3.0)
	NoticeManager.show_message("你拿逗猫棒陪%s玩了一会儿，它开心地转圈。" % _pet_name(target) if used_toy else "你和%s玩了一会儿，它开心地转圈。" % _pet_name(target), "positive")
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true

func rest(pet_id: String = "") -> bool:
	var target := _resolve(pet_id)
	if target.is_empty():
		return false
	var state: Dictionary = adopted[target]
	state["energy"] = 100.0
	state["mood"] = clampf(float(state.get("mood", 0.0)) + 5.0, 0.0, 100.0)
	NoticeManager.show_message("%s睡了一觉，醒来精神多了。" % _pet_name(target), "positive")
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true

func bathe(pet_id: String = "") -> bool:
	var target := _resolve(pet_id)
	if target.is_empty():
		return false
	var cost := int(ConfigDB.get_number("petshop", "bath_cost", 8.0))
	if not GameState.spend(cost, "买了宠物洗澡用品。"):
		return false
	var state: Dictionary = adopted[target]
	state["clean"] = 100.0
	state["mood"] = clampf(float(state.get("mood", 0.0)) - 4.0, 0.0, 100.0)
	NoticeManager.show_message("%s洗得香喷喷，虽然有点不情愿。" % _pet_name(target), "positive")
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true

func help(pet_id: String = "") -> bool:
	var target := _resolve(pet_id)
	if target.is_empty():
		return false
	if InventoryManager.get_count("pet_medicine") <= 0:
		NoticeManager.show_message("没有宠物营养膏了，去宠物商店买一支吧。", "warning", "宠物店老板")
		return false
	InventoryManager.remove_item("pet_medicine", 1)
	var state: Dictionary = adopted[target]
	state["energy"] = clampf(float(state.get("energy", 0.0)) + 28.0, 0.0, 100.0)
	state["fullness"] = clampf(float(state.get("fullness", 0.0)) + 18.0, 0.0, 100.0)
	state["mood"] = clampf(float(state.get("mood", 0.0)) + 12.0, 0.0, 100.0)
	state["clean"] = clampf(float(state.get("clean", 0.0)) + 10.0, 0.0, 100.0)
	NoticeManager.show_message("%s用了营养膏，精神好多了。" % _pet_name(target), "positive", "宠物店老板")
	SaveManager.request_auto_save("pet_help")
	changed.emit()
	return true

func train(pet_id: String = "") -> bool:
	var target := _resolve(pet_id)
	if target.is_empty():
		return false
	var state: Dictionary = adopted[target]
	if float(state.get("fullness", 0.0)) < 30.0 or float(state.get("energy", 0.0)) < 30.0:
		NoticeManager.show_message("%s状态不好，训练前先喂饱睡足。" % _pet_name(target), "warning")
		return false
	var cost := int(ConfigDB.get_number("petshop", "training_cost", 25.0))
	if not GameState.spend(cost, "请了训练师。"):
		return false
	state["training"] = clampf(float(state.get("training", 0.0)) + 14.0, 0.0, 100.0)
	state["energy"] = clampf(float(state.get("energy", 0.0)) - 18.0, 0.0, 100.0)
	state["growth"] = clampf(float(state.get("growth", 0.0)) + 6.0, 0.0, 100.0)
	NoticeManager.show_message("%s学会了一个新动作。" % _pet_name(target), "positive")
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true

func show_pet(pet_id: String = "") -> bool:
	var target := _resolve(pet_id)
	if target.is_empty():
		return false
	var state: Dictionary = adopted[target]
	if float(state.get("training", 0.0)) < 30.0 or float(state.get("mood", 0.0)) < 40.0:
		NoticeManager.show_message("%s还没准备好上台表演。" % _pet_name(target), "warning")
		return false
	var base := int(ConfigDB.get_number("petshop", "show_reward_base", 80.0))
	var reward := int(round(float(base) * (1.0 + float(state.get("training", 0.0)) / 100.0)))
	GameState.earn(reward, "%s完成了一场小表演，收到 ¥%d。" % [_pet_name(target), reward])
	state["energy"] = clampf(float(state.get("energy", 0.0)) - 20.0, 0.0, 100.0)
	state["mood"] = clampf(float(state.get("mood", 0.0)) - 6.0, 0.0, 100.0)
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true

func begin_new_day(_day_number: int) -> void:
	var pets := adopted.keys()
	if pets.is_empty():
		return
	var growth_days := maxf(1.0, ConfigDB.get_number("petshop", "growth_days_to_adult", 6.0))
	for pet_id in pets:
		var state: Dictionary = adopted[pet_id]
		var care := _care_factor(state)
		state["fullness"] = clampf(float(state.get("fullness", 0.0)) - 28.0, 0.0, 100.0)
		state["energy"] = clampf(float(state.get("energy", 0.0)) - 18.0, 0.0, 100.0)
		state["clean"] = clampf(float(state.get("clean", 0.0)) - 20.0, 0.0, 100.0)
		state["mood"] = clampf(float(state.get("mood", 0.0)) + (6.0 if care > 0.75 else -10.0), 0.0, 100.0)
		state["days_together"] = int(state.get("days_together", 0)) + 1
		var growth_step := 100.0 / growth_days * care
		growth_step *= maxf(0.5, 1.0 + RoomManager.get_bonus("pet_growth"))
		state["growth"] = clampf(float(state.get("growth", 0.0)) + growth_step, 0.0, 100.0)
		if float(state.get("growth", 0.0)) >= 100.0:
			state["stage"] = "adult"
	changed.emit()

func get_bonus(bonus_type: String) -> float:
	var result := 0.0
	for pet_id in adopted:
		var row := ConfigDB.get_row("pets", pet_id)
		if row.is_empty() or str(row.get("bonus_type", "")) != bonus_type:
			continue
		var state: Dictionary = adopted[pet_id]
		var care := _care_factor(state)
		var growth_factor := 0.6 + 0.4 * (float(state.get("growth", 0.0)) / 100.0)
		result += float(row.get("bonus_value", "0")) * care * growth_factor
	return result

func get_pet_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pet_id in adopted:
		var row := ConfigDB.get_row("pets", pet_id)
		var state: Dictionary = adopted[pet_id]
		result.append({
			"id": pet_id,
			"name": row.get("name", pet_id),
			"stage": str(state.get("stage", "baby")),
			"fullness": float(state.get("fullness", 0.0)),
			"energy": float(state.get("energy", 0.0)),
			"mood": float(state.get("mood", 0.0)),
			"clean": float(state.get("clean", 0.0)),
			"training": float(state.get("training", 0.0)),
			"growth": float(state.get("growth", 0.0)),
			"active": pet_id == active_pet_id,
		})
	return result

func get_bonus_text() -> String:
	var lines: Array[String] = []
	for bt in ["sales", "patience", "treasure", "harvest", "sell", "luck"]:
		var value := get_bonus(bt)
		if value <= 0.0:
			continue
		lines.append("%s +%d%%" % [_bonus_name(bt), int(round(value * 100.0))])
	return " · ".join(lines) if not lines.is_empty() else "宠物状态一般，暂时没有加成。"

func get_stage_name(stage: String) -> String:
	match stage:
		"baby":
			return "幼年"
		"adult":
			return "成年"
	return stage

func _care_factor(state: Dictionary) -> float:
	var total := float(state.get("fullness", 0.0)) + float(state.get("energy", 0.0)) + float(state.get("mood", 0.0)) + float(state.get("clean", 0.0))
	return clampf(total / 400.0, 0.0, 1.0)

func _bonus_name(bonus_type: String) -> String:
	match bonus_type:
		"sales":
			return "营业额"
		"patience":
			return "客人耐心"
		"treasure":
			return "摸金机会"
		"harvest":
			return "农场产量"
		"sell":
			return "售卖价格"
		"luck":
			return "隐藏运气"
	return bonus_type

func _resolve(pet_id: String) -> String:
	if not pet_id.is_empty() and adopted.has(pet_id):
		return pet_id
	if not active_pet_id.is_empty() and adopted.has(active_pet_id):
		return active_pet_id
	var keys := adopted.keys()
	return str(keys[0]) if not keys.is_empty() else ""

func _pet_name(pet_id: String) -> String:
	return str(ConfigDB.get_row("pets", pet_id).get("name", pet_id))

func get_save_data() -> Dictionary:
	return {"adopted": adopted.duplicate(true), "active_pet_id": active_pet_id}

func restore(data: Dictionary) -> void:
	adopted = data.get("adopted", {}).duplicate(true)
	active_pet_id = str(data.get("active_pet_id", ""))
	changed.emit()
