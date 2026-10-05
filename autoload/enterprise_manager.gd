extends Node

signal changed

var owned: Dictionary = {}
var last_daily_income := 0
var last_active_income := 0
var operations_done := 0

func reset_new_game() -> void:
	owned.clear()
	last_daily_income = 0
	last_active_income = 0
	operations_done = 0
	changed.emit()

func is_owned(enterprise_id: String) -> bool:
	return owned.has(enterprise_id)

func get_level(enterprise_id: String) -> int:
	return int(owned.get(enterprise_id, 0))

func buy(enterprise_id: String) -> bool:
	var row := ConfigDB.get_row("enterprises", enterprise_id)
	if row.is_empty() or is_owned(enterprise_id):
		return false
	var cost := int(row.get("buy_cost", "0"))
	if not GameState.spend(cost, "盘下%s。" % str(row.get("name", enterprise_id))):
		return false
	owned[enterprise_id] = 1
	NoticeManager.show_message("盘下了%s，从明天起会有一笔经营收入。" % str(row.get("name", enterprise_id)), "positive", "个体户老周")
	SaveManager.request_auto_save("enterprise_buy")
	changed.emit()
	return true

func upgrade(enterprise_id: String) -> bool:
	var row := ConfigDB.get_row("enterprises", enterprise_id)
	if row.is_empty() or not is_owned(enterprise_id):
		return false
	var level := get_level(enterprise_id)
	if level >= int(row.get("max_level", "3")):
		NoticeManager.show_message("%s已经是现在的上限了。" % str(row.get("name", enterprise_id)), "hint", "个体户老周")
		return false
	var cost := get_upgrade_cost(enterprise_id)
	if not GameState.spend(cost, "升级%s。" % str(row.get("name", enterprise_id))):
		return false
	owned[enterprise_id] = level + 1
	NoticeManager.show_message("%s升到第%d级，明天的生意会更稳。" % [str(row.get("name", enterprise_id)), level + 1], "positive", "个体户老周")
	SaveManager.request_auto_save("enterprise_upgrade")
	changed.emit()
	return true

func can_operate(enterprise_id: String) -> bool:
	if not is_owned(enterprise_id):
		return false
	var row := ConfigDB.get_row("enterprises", enterprise_id)
	if row.is_empty():
		return false
	if GameState.energy < float(row.get("operate_energy", "0")):
		return false
	if BusinessManager.labor_stock < int(row.get("operate_labor", "0")):
		return false
	if BusinessManager.brain_stock < int(row.get("operate_brain", "0")):
		return false
	for item in _parse_operation_goods(str(row.get("operate_goods", ""))):
		if BusinessManager.get_stock(str(item["goods_id"])) < int(item["amount"]):
			return false
	return true

func operate(enterprise_id: String) -> bool:
	var row := ConfigDB.get_row("enterprises", enterprise_id)
	if row.is_empty() or not is_owned(enterprise_id):
		return false
	var goods_needs := _parse_operation_goods(str(row.get("operate_goods", "")))
	var energy_cost := float(row.get("operate_energy", "0"))
	var labor_cost := int(row.get("operate_labor", "0"))
	var brain_cost := int(row.get("operate_brain", "0"))
	if GameState.energy < energy_cost:
		NoticeManager.show_message("今天已经没精神亲自照看%s了。" % str(row.get("name", enterprise_id)), "warning", _operation_speaker(enterprise_id))
		return false
	if BusinessManager.labor_stock < labor_cost or BusinessManager.brain_stock < brain_cost:
		NoticeManager.show_message("%s缺人手或缺提前安排的时间，先去批发市场或临时帮手那边补一补。" % str(row.get("name", enterprise_id)), "warning", _operation_speaker(enterprise_id))
		return false
	for item in goods_needs:
		if BusinessManager.get_stock(str(item["goods_id"])) < int(item["amount"]):
			NoticeManager.show_message("备货不够，先补%s再开张。" % _goods_names(goods_needs), "warning", _operation_speaker(enterprise_id))
			return false
	GameState.change_energy(-energy_cost)
	TimeSystem.advance_minutes(int(row.get("operate_minutes", "60")))
	for item in goods_needs:
		BusinessManager.consume_goods(str(item["goods_id"]), int(item["amount"]))
	BusinessManager.labor_stock = maxi(0, BusinessManager.labor_stock - labor_cost)
	BusinessManager.brain_stock = maxi(0, BusinessManager.brain_stock - brain_cost)
	var level := get_level(enterprise_id)
	var base := float(row.get("operate_base", "0")) * (1.0 + float(maxi(0, level - 1)) * 0.32)
	var staffing := 1.0 + StaffManager.get_bonus("morning_revenue") + StaffManager.get_bonus("patience") * 0.35
	var reputation_factor := 1.0 + float(BusinessManager.reputation) * 0.004
	var weather_factor := clampf(WeatherSystem.get_store_sales_bonus(), 0.9, 1.25)
	var variance := RandomManager.rng.randf_range(0.86, 1.22)
	var income := maxi(1, int(round(base * staffing * reputation_factor * weather_factor * variance)))
	last_active_income = income
	operations_done += 1
	GameState.earn(income, "%s今天亲自照看了一会儿，净收入 ¥%d。" % [str(row.get("name", enterprise_id)), income])
	NoticeManager.show_message(_operation_feedback(enterprise_id, income), "positive", _operation_speaker(enterprise_id))
	SaveManager.request_auto_save("enterprise_operate")
	changed.emit()
	return true

func get_operation_hint(enterprise_id: String) -> String:
	var row := ConfigDB.get_row("enterprises", enterprise_id)
	if row.is_empty() or not is_owned(enterprise_id):
		return ""
	if can_operate(enterprise_id):
		return "现在可以亲自照看%s。" % str(row.get("name", enterprise_id))
	var goods_needs := _parse_operation_goods(str(row.get("operate_goods", "")))
	return "需要 %.0f 体力、劳力 %d、脑力 %d、备货 %s。" % [
		float(row.get("operate_energy", "0")),
		int(row.get("operate_labor", "0")),
		int(row.get("operate_brain", "0")),
		_goods_names(goods_needs),
	]

func _parse_operation_goods(raw: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for part in raw.split("|", false):
		var pieces := part.split(":", false)
		if pieces.size() == 2:
			result.append({"goods_id": pieces[0], "amount": int(pieces[1])})
	return result

func _goods_names(items: Array[Dictionary]) -> String:
	var names: Array[String] = []
	for item in items:
		names.append(str(ConfigDB.get_row("goods", str(item["goods_id"])).get("name", item["goods_id"])))
	return "、".join(names)

func _operation_speaker(enterprise_id: String) -> String:
	match enterprise_id:
		"street_stall": return "地摊老周"
		"snack_drink": return "店长老黄"
		"retail_shop": return "百货阿珍"
		"small_factory": return "厂长老王"
	return "个体户老周"

func _operation_feedback(enterprise_id: String, income: int) -> String:
	match enterprise_id:
		"street_stall":
			return "老周说今天人流不错，收了 ¥%d，明天换个位置可能又不一样。" % income
		"snack_drink":
			return "黄姐说饮品卖得快，收了 ¥%d，忙的时候要先把备货摆顺。" % income
		"retail_shop":
			return "阿珍说街坊和游客都进门了，这趟流水 ¥%d。" % income
		"small_factory":
			return "王师傅说这批订单做完，账面进账 ¥%d，机器和人手都没白费。" % income
	return "今天的经营收入是 ¥%d。" % income

func get_upgrade_cost(enterprise_id: String) -> int:
	var row := ConfigDB.get_row("enterprises", enterprise_id)
	var level := maxi(1, get_level(enterprise_id))
	return int(round(float(row.get("upgrade_cost", "0")) * pow(float(row.get("upgrade_cost_growth", "1.6")), float(level - 1))))

func get_daily_income(enterprise_id: String) -> int:
	var row := ConfigDB.get_row("enterprises", enterprise_id)
	var level := get_level(enterprise_id)
	if row.is_empty() or level <= 0:
		return 0
	var base := float(row.get("base_income", "0")) + float(level - 1) * float(row.get("income_per_level", "0"))
	var staff_factor := 0.35 if StaffManager.hired.is_empty() else 1.0 + StaffManager.get_bonus("morning_revenue") + StaffManager.get_bonus("patience") * 0.25
	return maxi(1, int(round(base * staff_factor)))

func begin_new_day(_day_number: int) -> void:
	last_daily_income = 0
	for enterprise_id in owned:
		last_daily_income += get_daily_income(str(enterprise_id))
	if last_daily_income > 0:
		GameState.earn(last_daily_income, "名下生意今天送来的经营分成：¥%d。" % last_daily_income)
	SaveManager.request_auto_save("enterprise_daily")
	changed.emit()

func get_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enterprise_id in ConfigDB.get_rows("enterprises"):
		var row := ConfigDB.get_row("enterprises", enterprise_id)
		var level := get_level(str(enterprise_id))
		result.append({
			"id": str(enterprise_id),
			"name": str(row.get("name", enterprise_id)),
			"area_id": str(row.get("area_id", "")),
			"buy_cost": int(row.get("buy_cost", "0")),
			"upgrade_cost": get_upgrade_cost(str(enterprise_id)),
			"level": level,
			"max_level": int(row.get("max_level", "3")),
			"daily_income": get_daily_income(str(enterprise_id)),
			"operation_hint": get_operation_hint(str(enterprise_id)),
			"operate_minutes": int(row.get("operate_minutes", "60")),
			"operate_energy": float(row.get("operate_energy", "0")),
			"operate_labor": int(row.get("operate_labor", "0")),
			"operate_brain": int(row.get("operate_brain", "0")),
			"description": str(row.get("description", "")),
		})
	return result

func get_summary() -> String:
	if owned.is_empty():
		return "还没有自己的营生。"
	var names: Array[String] = []
	for enterprise_id in owned:
		names.append("%s Lv.%d" % [str(ConfigDB.get_row("enterprises", enterprise_id).get("name", enterprise_id)), get_level(enterprise_id)])
	return " · ".join(names)

func get_save_data() -> Dictionary:
	return {"owned": owned.duplicate(true), "last_daily_income": last_daily_income, "last_active_income": last_active_income, "operations_done": operations_done}

func restore(data: Dictionary) -> void:
	owned = data.get("owned", {}).duplicate(true)
	last_daily_income = int(data.get("last_daily_income", 0))
	last_active_income = int(data.get("last_active_income", 0))
	operations_done = int(data.get("operations_done", 0))
	changed.emit()
