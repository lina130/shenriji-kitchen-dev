extends Node

signal changed
signal market_day_started(hot_category: String, cold_category: String)

const CATEGORIES := ["metal", "ceramic", "paper", "photo", "daily"]
const CATEGORY_NAMES := {
	"metal": "旧金属和工具",
	"ceramic": "瓷器玻璃",
	"paper": "旧书纸品",
	"photo": "相机影像",
	"daily": "市井杂货",
}

var hot_category := "metal"
var cold_category := "paper"
var stall_tier := 0
var total_sales := 0
var completed_consignments := 0
var reputation := 0
var consignment_orders: Array = []

func begin_new_day(_day_number: int) -> void:
	_settle_consignments()
	var available: Array = CATEGORIES.duplicate()
	hot_category = str(RandomManager.pick(available))
	available.erase(hot_category)
	cold_category = str(RandomManager.pick(available))
	market_day_started.emit(hot_category, cold_category)
	changed.emit()

func sell_now(item_id: String) -> bool:
	var item := InventoryManager.get_item(item_id)
	if item.is_empty() or str(item.get("category", "")) != "collectible":
		return false
	if not InventoryManager.remove_item(item_id, 1):
		return false
	var price := get_current_price(item_id)
	total_sales += price
	reputation = mini(10, reputation + (2 if _demand_for(item_id) == "hot" else 1))
	GameState.earn(price, _sale_message(item, price))
	changed.emit()
	return true

func consign_item(item_id: String) -> bool:
	if consignment_orders.size() >= get_consignment_slots():
		NoticeManager.show_message("陈伯的柜台已经摆满了，明天再来吧。", "warning")
		return false
	var item := InventoryManager.get_item(item_id)
	if item.is_empty() or str(item.get("category", "")) != "collectible":
		return false
	if not InventoryManager.remove_item(item_id, 1):
		return false
	var order := {
		"item_id": item_id,
		"item_name": str(item.get("name", item_id)),
		"category": str(item.get("market_category", "daily")),
		"base_price": int(item.get("sell_price", 0)),
		"days_remaining": RandomManager.rand_int(1, 3),
		"attempts": 0,
	}
	consignment_orders.append(order)
	NoticeManager.show_message("%s先摆在陈伯柜台上寄卖。" % item.get("name", item_id), "hint")
	changed.emit()
	return true

func upgrade_stall() -> bool:
	if stall_tier >= 2:
		NoticeManager.show_message("现在这个小铺面已经够用了。", "hint")
		return false
	var cost := int(ConfigDB.get_number("balance", "stall_upgrade_1_cost" if stall_tier == 0 else "stall_upgrade_2_cost", 900 if stall_tier == 0 else 2400))
	if not GameState.spend(cost):
		return false
	stall_tier += 1
	if stall_tier == 1:
		NoticeManager.show_message("旧货行门口多了一块固定摊位，能寄卖的货更多了。", "positive")
	else:
		NoticeManager.show_message("你租下了半间小铺面，熟客开始主动上门。", "positive")
	reputation = mini(10, reputation + 2)
	changed.emit()
	return true

func get_current_price(item_id: String) -> int:
	var item := InventoryManager.get_item(item_id)
	if item.is_empty():
		return 0
	var base := int(item.get("sell_price", 0))
	var modifier := 1.0
	match _demand_for(item_id):
		"hot":
			modifier += 0.18
		"cold":
			modifier -= 0.08
	modifier += float(stall_tier) * 0.05
	modifier += minf(0.10, float(reputation) * 0.01)
	return maxi(1, int(round(base * modifier * (1.0 + RelationshipManager.get_market_bonus()))))

func get_demand_for(item_id: String) -> String:
	return _demand_for(item_id)

func get_demand_label(item_id: String) -> String:
	match _demand_for(item_id):
		"hot":
			return "今天很抢手"
		"cold":
			return "今天少人问"
		_:
			return "行情一般"

func get_market_brief() -> String:
	return "今天%s最好卖，%s几乎没人问。" % [
		CATEGORY_NAMES.get(hot_category, hot_category),
		CATEGORY_NAMES.get(cold_category, cold_category),
	]

func get_consignment_slots() -> int:
	return int(ConfigDB.get_number("balance", "consignment_base_slots", 2)) + stall_tier * int(ConfigDB.get_number("balance", "consignment_slots_per_tier", 2))

func get_stall_name() -> String:
	match stall_tier:
		1:
			return "旧货行固定摊位"
		2:
			return "半间小铺面"
		_:
			return "街边寄卖格"

func get_consignment_summary() -> String:
	if consignment_orders.is_empty():
		return "柜台上还没有替你寄卖的旧物。"
	var names: Array[String] = []
	for order in consignment_orders:
		names.append(str(order.get("item_name", "")))
	return "正在寄卖：%s" % "、".join(names)

func is_site_unlocked(site_id: String) -> bool:
	match site_id:
		"alley_basement":
			return true
		"old_pipe":
			return total_sales >= 600
		"sealed_workshop":
			return stall_tier >= 1
		"flooded_tunnel":
			return completed_consignments >= 5 or reputation >= 8
	return false

func get_unlock_hint(site_id: String) -> String:
	match site_id:
		"alley_basement":
			return "市场后面的旧楼梯"
		"old_pipe":
			return "做够几笔旧货生意后，陈伯会告诉你管道入口"
		"sealed_workshop":
			return "先盘下一块固定摊位，才有资格进封存车间"
		"flooded_tunnel":
			return "完成多次寄卖、成为熟客后，会有人带你走积水隧道"
	return "入口还没打听到"

func _settle_consignments() -> void:
	if consignment_orders.is_empty():
		return
	var remaining: Array = []
	var earned := 0
	var sold_names: Array[String] = []
	for order in consignment_orders:
		var category := str(order.get("category", "daily"))
		var chance := 0.38 + float(stall_tier) * 0.10 + minf(0.15, float(reputation) * 0.015)
		if category == hot_category:
			chance += 0.28
		elif category == cold_category:
			chance -= 0.12
		chance += minf(0.18, float(order.get("attempts", 0)) * 0.06)
		if RandomManager.chance(clampf(chance, 0.05, 0.92)):
			var price := maxi(1, int(round(float(order.get("base_price", 0)) * (1.04 + float(stall_tier) * 0.07))))
			earned += price
			total_sales += price
			completed_consignments += 1
			reputation = mini(10, reputation + 1)
			sold_names.append(str(order.get("item_name", "旧物")))
		else:
			order["days_remaining"] = int(order.get("days_remaining", 1)) - 1
			order["attempts"] = int(order.get("attempts", 0)) + 1
			remaining.append(order)
	consignment_orders = remaining
	if earned > 0:
		GameState.earn(earned, "%s卖出去了，陈伯转来 ¥%d。" % ["、".join(sold_names), earned])

func _demand_for(item_id: String) -> String:
	var category := str(InventoryManager.get_item(item_id).get("market_category", "daily"))
	if category == hot_category:
		return "hot"
	if category == cold_category:
		return "cold"
	return "normal"

func _sale_message(item: Dictionary, price: int) -> String:
	match _demand_for(str(item.get("id", ""))):
		"hot":
			return "%s正抢手，卖了 ¥%d。" % [item.get("name", "旧物"), price]
		"cold":
			return "%s今天不好卖，只换到 ¥%d。" % [item.get("name", "旧物"), price]
		_:
			return "%s卖了 ¥%d。" % [item.get("name", "旧物"), price]

func get_save_data() -> Dictionary:
	return {
		"hot_category": hot_category,
		"cold_category": cold_category,
		"stall_tier": stall_tier,
		"total_sales": total_sales,
		"completed_consignments": completed_consignments,
		"reputation": reputation,
		"consignment_orders": consignment_orders.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	hot_category = str(data.get("hot_category", "metal"))
	cold_category = str(data.get("cold_category", "paper"))
	stall_tier = int(data.get("stall_tier", 0))
	total_sales = int(data.get("total_sales", 0))
	completed_consignments = int(data.get("completed_consignments", 0))
	reputation = int(data.get("reputation", 0))
	consignment_orders = data.get("consignment_orders", []).duplicate(true)
	changed.emit()

func reset_new_game() -> void:
	hot_category = "metal"
	cold_category = "paper"
	stall_tier = 0
	total_sales = 0
	completed_consignments = 0
	reputation = 0
	consignment_orders.clear()
	changed.emit()