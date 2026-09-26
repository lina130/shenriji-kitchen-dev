extends Node

signal changed
signal shift_settled(summary: Dictionary)

var goods_stock: Dictionary = {}
var average_cost: Dictionary = {}
var price_modifiers: Dictionary = {}
var price_notes: Dictionary = {}
var labor_stock := 0
var brain_stock := 0
var labor_capacity := 12
var brain_capacity := 10
var business_level := 0
var total_revenue := 0
var total_cost := 0
var trade_profit := 0
var customers_served := 0
var reputation := 0
var last_shift_earned := 0
var temporary_labor_bonus := 0
var temporary_brain_bonus := 0

func _ready() -> void:
	labor_capacity = int(ConfigDB.get_number("business", "labor_base_capacity", 12))
	brain_capacity = int(ConfigDB.get_number("business", "brain_base_capacity", 10))
	reset_new_game()

func begin_new_day(_day_number: int) -> void:
	temporary_labor_bonus = 0
	temporary_brain_bonus = 0
	labor_stock = mini(get_labor_capacity(), labor_stock + int(ConfigDB.get_number("business", "labor_daily_restore", 6)))
	brain_stock = mini(get_brain_capacity(), brain_stock + int(ConfigDB.get_number("business", "brain_daily_restore", 5)))
	_update_daily_prices()
	changed.emit()

func buy_goods(goods_id: String, quantity: int = 1) -> bool:
	if quantity <= 0 or ConfigDB.get_row("goods", goods_id).is_empty():
		return false
	var unit_price := get_buy_price(goods_id)
	var total_price := unit_price * quantity
	if not GameState.spend(total_price):
		return false
	var old_count := int(goods_stock.get(goods_id, 0))
	var old_cost := float(average_cost.get(goods_id, 0.0))
	var new_count := old_count + quantity
	average_cost[goods_id] = (old_cost * old_count + unit_price * quantity) / float(new_count)
	goods_stock[goods_id] = new_count
	total_cost += total_price
	changed.emit()
	return true

func sell_goods(goods_id: String, quantity: int = 1) -> bool:
	if quantity <= 0 or int(goods_stock.get(goods_id, 0)) < quantity:
		NoticeManager.show_message("库存不够，先去批发市场补货吧。", "warning")
		return false
	var unit_price := get_sell_price(goods_id)
	var proceeds := unit_price * quantity
	var cost_basis := float(average_cost.get(goods_id, 0.0)) * quantity
	var remaining := int(goods_stock.get(goods_id, 0)) - quantity
	if remaining <= 0:
		goods_stock.erase(goods_id)
		average_cost.erase(goods_id)
	else:
		goods_stock[goods_id] = remaining
	trade_profit += proceeds - int(round(cost_basis))
	total_revenue += proceeds
	GameState.earn(proceeds, "出手 %d 份%s，收到 ¥%d。" % [quantity, ConfigDB.get_row("goods", goods_id).get("name", goods_id), proceeds])
	TreasureManager.try_trigger("sell_goods")
	changed.emit()
	return true

func restock_labor() -> bool:
	if temporary_labor_bonus >= 6:
		NoticeManager.show_message("临时帮手已经够多了，再多也安排不开。", "hint")
		return false
	var cost := int(ConfigDB.get_number("business", "labor_restock_cost", 36))
	if not GameState.spend(cost):
		return false
	var amount := int(ConfigDB.get_number("business", "labor_restock_size", 3))
	temporary_labor_bonus += amount
	labor_stock += amount
	total_cost += cost
	NoticeManager.show_message("临时帮手到了，今天的劳力上限增加。", "positive")
	changed.emit()
	return true

func restock_brain() -> bool:
	if temporary_brain_bonus >= 6:
		NoticeManager.show_message("今天已经缓过来了，再喝只会睡不着。", "hint")
		return false
	var cost := int(ConfigDB.get_number("business", "brain_restock_cost", 30))
	if not GameState.spend(cost):
		return false
	var amount := int(ConfigDB.get_number("business", "brain_restock_size", 3))
	temporary_brain_bonus += amount
	brain_stock += amount
	total_cost += cost
	NoticeManager.show_message("坐下来喘口气，脑力库存增加。", "positive")
	changed.emit()
	return true

func get_labor_capacity() -> int:
	return int(ConfigDB.get_number("business", "labor_base_capacity", 12)) + business_level * 4 + temporary_labor_bonus

func get_brain_capacity() -> int:
	return int(ConfigDB.get_number("business", "brain_base_capacity", 10)) + business_level * 2 + temporary_brain_bonus

func get_buy_price(goods_id: String) -> int:
	var base := float(ConfigDB.get_row("goods", goods_id).get("base_cost", "1"))
	return maxi(1, int(round(base * (1.0 + float(price_modifiers.get(goods_id, 0.0))) * (1.0 - RelationshipManager.get_supplier_discount()))))

func get_sell_price(goods_id: String) -> int:
	var base := float(ConfigDB.get_row("goods", goods_id).get("base_cost", "1"))
	var modifier := float(price_modifiers.get(goods_id, 0.0))
	return maxi(1, int(round(base * (1.10 + modifier * 1.15))))

func get_price_note(goods_id: String) -> String:
	return str(price_notes.get(goods_id, "价格平稳"))

func get_stock(goods_id: String) -> int:
	return int(goods_stock.get(goods_id, 0))

func get_goods_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for goods_id in ConfigDB.get_rows("goods"):
		var row := ConfigDB.get_row("goods", goods_id)
		result.append({
			"id": goods_id,
			"name": str(row.get("name", goods_id)),
			"stock": get_stock(goods_id),
			"buy_price": get_buy_price(goods_id),
			"sell_price": get_sell_price(goods_id),
			"note": get_price_note(goods_id),
			"average_cost": float(average_cost.get(goods_id, 0.0)),
		})
	return result

func get_stock_value() -> int:
	var total := 0
	for goods_id in goods_stock:
		total += get_sell_price(goods_id) * int(goods_stock[goods_id])
	return total

func get_net_profit() -> int:
	return total_revenue - total_cost

func get_business_level_name() -> String:
	match business_level:
		1:
			return "固定档口"
		2:
			return "小铺面"
		3:
			return "深夜食堂"
		_:
			return "街边小摊"

func get_recipe_ids() -> Array[String]:
	var result: Array[String] = []
	for recipe_id in ConfigDB.get_rows("recipes"):
		result.append(recipe_id)
	return result

func get_unlocked_recipe_ids() -> Array[String]:
	var all_ids := get_recipe_ids()
	var count := mini(all_ids.size(), 3 + business_level)
	return all_ids.slice(0, count)

func can_prepare_recipe(recipe_id: String) -> bool:
	var recipe := ConfigDB.get_row("recipes", recipe_id)
	if recipe.is_empty():
		return false
	if labor_stock < int(recipe.get("labor_cost", 0)) or brain_stock < int(recipe.get("brain_cost", 0)):
		return false
	for item in _parse_recipe_goods(str(recipe.get("goods_recipe", ""))):
		if get_stock(str(item["goods_id"])) < int(item["amount"]):
			return false
	return true

func consume_recipe_inputs(recipe_id: String) -> bool:
	if not can_prepare_recipe(recipe_id):
		NoticeManager.show_message("缺劳力、脑力或食材，先补一样再开火。", "warning")
		return false
	var recipe := ConfigDB.get_row("recipes", recipe_id)
	for item in _parse_recipe_goods(str(recipe.get("goods_recipe", ""))):
		var goods_id := str(item["goods_id"])
		var remaining := get_stock(goods_id) - int(item["amount"])
		if remaining <= 0:
			goods_stock.erase(goods_id)
			average_cost.erase(goods_id)
		else:
			goods_stock[goods_id] = remaining
	labor_stock = maxi(0, labor_stock - int(recipe.get("labor_cost", 0)))
	brain_stock = maxi(0, brain_stock - int(recipe.get("brain_cost", 0)))
	changed.emit()
	return true
func register_recipe_sale(recipe_id: String, combo: int) -> int:
	var recipe := ConfigDB.get_row("recipes", recipe_id)
	if recipe.is_empty():
		return 0
	var base_revenue := int(recipe.get("sale_price", 0))
	var combo_multiplier := 1.0 + maxf(0.0, float(combo - 1)) * 0.06
	var level_multiplier := 1.0 + float(business_level) * 0.05
	var weather_multiplier := 1.0 + maxf(0.0, WeatherSystem.get_store_sales_bonus() - 1.0) * 0.25
	var festival_multiplier := 1.0 + CalendarManager.get_business_bonus()
	var revenue := int(round(base_revenue * combo_multiplier * level_multiplier * weather_multiplier * festival_multiplier))
	total_revenue += revenue
	customers_served += 1
	reputation = mini(999, reputation + 1)
	last_shift_earned += revenue
	GameState.earn(revenue)
	changed.emit()
	return revenue

func register_failed_order() -> void:
	reputation = maxi(0, reputation - 1)
	changed.emit()

func can_upgrade_business() -> bool:
	if business_level >= 3:
		return false
	var required_customers: Array = [12, 40, 100]
	return customers_served >= int(required_customers[business_level])

func get_upgrade_cost() -> int:
	match business_level:
		0:
			return int(ConfigDB.get_number("business", "business_upgrade_1_cost", 900))
		1:
			return int(ConfigDB.get_number("business", "business_upgrade_2_cost", 2600))
		2:
			return int(ConfigDB.get_number("business", "business_upgrade_3_cost", 7200))
	return 0

func upgrade_business() -> bool:
	if business_level >= 3:
		NoticeManager.show_message("现在的铺面已经做到这条街的上限了。", "hint")
		return false
	if not can_upgrade_business():
		NoticeManager.show_message("熟客还不够多，先把眼前的小店做稳。", "warning")
		return false
	if not GameState.spend(get_upgrade_cost()):
		return false
	business_level += 1
	labor_capacity = get_labor_capacity()
	brain_capacity = get_brain_capacity()
	NoticeManager.show_message("店面扩成了%s，菜单和人手都能再往上走。" % get_business_level_name(), "positive")
	changed.emit()
	return true

func get_business_valuation() -> int:
	return int(round(total_revenue * 0.35 + business_level * 2200 + get_stock_value() * 0.75 + reputation * 35))

func can_sell_business() -> bool:
	return business_level >= int(ConfigDB.get_number("business", "business_sale_min_level", 2))

func sell_business() -> bool:
	if not can_sell_business():
		NoticeManager.show_message("这个摊子还太小，暂时没人愿意接盘。", "warning")
		return false
	var payout := int(round(get_business_valuation() * 0.72))
	GameState.earn(payout, "把铺子转了出去，收到 ¥%d。" % payout)
	InventoryManager.add_item("store_plaque", 1)
	CollectionManager.discovered["store_plaque"] = true
	if RandomManager.chance(0.35) and InventoryManager.get_count("golden_abacus") <= 0:
		InventoryManager.add_item("golden_abacus", 1)
		CollectionManager.discovered["golden_abacus"] = true
		NoticeManager.show_message("买家还留下了一只金算盘，像是把旧日生意一并交给了你。", "positive")
	business_level = 0
	labor_capacity = get_labor_capacity()
	brain_capacity = get_brain_capacity()
	_set_starter_stock()
	labor_stock = get_labor_capacity()
	brain_stock = get_brain_capacity()
	changed.emit()
	return true

func get_recipe_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_id in get_unlocked_recipe_ids():
		var recipe := ConfigDB.get_row("recipes", recipe_id)
		result.append({
			"id": recipe_id,
			"name": str(recipe.get("name", recipe_id)),
			"goods_recipe": str(recipe.get("goods_recipe", "")),
			"labor_cost": int(recipe.get("labor_cost", 0)),
			"brain_cost": int(recipe.get("brain_cost", 0)),
			"sale_price": int(recipe.get("sale_price", 0)),
		})
	return result

func _update_daily_prices() -> void:
	price_modifiers.clear()
	price_notes.clear()
	for goods_id in ConfigDB.get_rows("goods"):
		var modifier := RandomManager.rng.randf_range(-0.18, 0.18)
		var row := ConfigDB.get_row("goods", goods_id)
		var category := str(row.get("category", "日常"))
		if WeatherSystem.current_weather_id == "rain" and category == "生鲜":
			modifier += 0.08
		elif WeatherSystem.current_weather_id == "heat" and goods_id in ["ice", "lemon"]:
			modifier += 0.12
		if modifier <= -0.08:
			price_notes[goods_id] = "今天进货便宜"
		elif modifier >= 0.08:
			price_notes[goods_id] = "今天货源紧"
		else:
			price_notes[goods_id] = "价格平稳"
		price_modifiers[goods_id] = modifier

func _parse_recipe_goods(recipe_text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for part in recipe_text.split("|", false):
		var pieces := part.split(":", false)
		if pieces.size() == 2:
			result.append({"goods_id": pieces[0], "amount": int(pieces[1])})
	return result

func _set_starter_stock() -> void:
	goods_stock = {"rice": 3, "egg": 4, "greens": 2, "tea": 2, "lemon": 3, "ice": 2}
	average_cost.clear()

func get_save_data() -> Dictionary:
	return {
		"goods_stock": goods_stock.duplicate(true),
		"average_cost": average_cost.duplicate(true),
		"price_modifiers": price_modifiers.duplicate(true),
		"price_notes": price_notes.duplicate(true),
		"labor_stock": labor_stock,
		"brain_stock": brain_stock,
		"business_level": business_level,
		"total_revenue": total_revenue,
		"total_cost": total_cost,
		"trade_profit": trade_profit,
		"customers_served": customers_served,
		"reputation": reputation,
		"temporary_labor_bonus": temporary_labor_bonus,
		"temporary_brain_bonus": temporary_brain_bonus,
	}

func restore(data: Dictionary) -> void:
	goods_stock = data.get("goods_stock", {}).duplicate(true)
	average_cost = data.get("average_cost", {}).duplicate(true)
	price_modifiers = data.get("price_modifiers", {}).duplicate(true)
	price_notes = data.get("price_notes", {}).duplicate(true)
	labor_stock = int(data.get("labor_stock", get_labor_capacity()))
	brain_stock = int(data.get("brain_stock", get_brain_capacity()))
	business_level = int(data.get("business_level", 0))
	total_revenue = int(data.get("total_revenue", 0))
	total_cost = int(data.get("total_cost", 0))
	trade_profit = int(data.get("trade_profit", 0))
	customers_served = int(data.get("customers_served", 0))
	reputation = int(data.get("reputation", 0))
	temporary_labor_bonus = int(data.get("temporary_labor_bonus", 0))
	temporary_brain_bonus = int(data.get("temporary_brain_bonus", 0))
	labor_capacity = get_labor_capacity()
	brain_capacity = get_brain_capacity()
	changed.emit()

func reset_new_game() -> void:
	business_level = 0
	total_revenue = 0
	total_cost = 0
	trade_profit = 0
	customers_served = 0
	reputation = 0
	last_shift_earned = 0
	temporary_labor_bonus = 0
	temporary_brain_bonus = 0
	_set_starter_stock()
	labor_capacity = get_labor_capacity()
	brain_capacity = get_brain_capacity()
	labor_stock = labor_capacity
	brain_stock = brain_capacity
	price_modifiers.clear()
	price_notes.clear()
	changed.emit()
