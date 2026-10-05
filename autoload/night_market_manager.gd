extends Node

## 夜市在晚市之后出现，用场景点击补充食材、买夜宵或临时摆摊。

signal changed

const MAX_DAILY_PURCHASES := 3

var purchases_today := 0
var worked_today := false
var last_stall_id := ""

func reset_new_game() -> void:
	purchases_today = 0
	worked_today = false
	last_stall_id = ""
	changed.emit()

func begin_new_day(_day_number: int) -> void:
	purchases_today = 0
	worked_today = false
	changed.emit()

func is_open() -> bool:
	return TimeSystem.minute_of_day >= 18 * 60 and TimeSystem.minute_of_day < 23 * 60

func can_enter() -> bool:
	return is_open()

func get_available_stalls() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stall_id in ConfigDB.get_rows("night_market"):
		var row := ConfigDB.get_row("night_market", stall_id)
		if not _condition_ok(str(row.get("condition", "always"))):
			continue
		result.append({
			"id": str(stall_id),
			"name": str(row.get("name", stall_id)),
			"description": str(row.get("description", "")),
			"price": int(row.get("price", "0")),
			"available": purchases_today < MAX_DAILY_PURCHASES,
		})
	return result

func get_stall_lines() -> Array[Dictionary]:
	return get_available_stalls()

func get_stall_prompt(stall_id: String) -> String:
	var row := ConfigDB.get_row("night_market", stall_id)
	if row.is_empty():
		return "看看夜市摊位"
	if not is_open():
		return "夜市还没开"
	if purchases_today >= MAX_DAILY_PURCHASES:
		return "今晚已经买够了"
	return "在%s花¥%d" % [str(row.get("name", stall_id)), int(row.get("price", "0"))]

func buy_stall(stall_id: String) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("night_market_buy", {"stall_id": stall_id})
	if not is_open():
		NoticeManager.show_npc_message("夜市还没摆开，晚点再来。", "夜市摊主", "hint")
		return false
	if purchases_today >= MAX_DAILY_PURCHASES:
		NoticeManager.show_npc_message("一晚上买太多也拿不动，明天再来。", "夜市摊主", "hint")
		return false
	var row := ConfigDB.get_row("night_market", stall_id)
	if row.is_empty() or not _condition_ok(str(row.get("condition", "always"))):
		return false
	var price := int(row.get("price", "0"))
	if not GameState.spend(price, "在夜市买下了%s。" % str(row.get("name", stall_id))):
		return false
	var stall_type := str(row.get("stall_type", "item"))
	var amount := maxi(1, int(row.get("amount", "1")))
	match stall_type:
		"goods":
			var goods_id := str(row.get("goods_id", ""))
			if not goods_id.is_empty():
				BusinessManager.goods_stock[goods_id] = BusinessManager.get_stock(goods_id) + amount
		"item":
			var item_id := str(row.get("item_id", ""))
			if not item_id.is_empty():
				InventoryManager.add_item(item_id, amount)
		"service":
			var effect_type := str(row.get("effect_type", ""))
			var effect_value := float(row.get("effect_value", "0"))
			if effect_type == "money":
				GameState.earn(int(effect_value), "抽签摊主递回了一点零钱。")
			elif effect_type == "energy":
				GameState.change_energy(effect_value)
	purchases_today += 1
	last_stall_id = stall_id
	NoticeManager.show_npc_message("收好%s。夜市快收摊了，别逛太晚。" % str(row.get("name", stall_id)), "夜市摊主", "positive")
	SaveManager.request_auto_save("night_market_buy")
	changed.emit()
	return true

func work_stall() -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("night_market_work")
	if not is_open():
		NoticeManager.show_npc_message("夜市还没开，摊主也还没来。", "夜市摊主", "hint")
		return false
	if worked_today:
		NoticeManager.show_npc_message("今晚已经帮过一摊了，留点时间给自己。", "夜市摊主", "hint")
		return false
	if GameState.energy < 18.0:
		NoticeManager.show_npc_message("太累了，先吃点东西再帮工。", "夜市摊主", "warning")
		return false
	GameState.change_energy(-18.0)
	TimeSystem.advance_minutes(60)
	var wage := 70 + int(round(float(CareerManager.current_rank) * 8.0)) + int(round(WellbeingManager.get_action_bonus("work") * 40.0))
	GameState.earn(wage, "帮夜市摊主守了一小时，结了 ¥%d。" % wage)
	worked_today = true
	NoticeManager.show_npc_message("手脚挺快，下回摊主还愿意叫你。", "夜市摊主", "positive")
	SaveManager.request_auto_save("night_market_work")
	changed.emit()
	return true

func get_summary() -> String:
	if not is_open():
		return "夜市还没开，晚上六点到十一点最热闹。"
	if worked_today:
		return "夜市已摆开 · 今晚已经帮过一摊 · 还能买 %d 次" % maxi(0, MAX_DAILY_PURCHASES - purchases_today)
	return "夜市已摆开 · 可以买夜宵和食材，也能帮摊主守一小时"

func _condition_ok(condition: String) -> bool:
	match condition:
		"festival":
			return CalendarManager.is_festival()
		"weekend":
			return TimeSystem.get_day_name() in ["周六", "周日"]
		"always", "":
			return true
	return true

func get_save_data() -> Dictionary:
	return {"purchases_today": purchases_today, "worked_today": worked_today, "last_stall_id": last_stall_id}

func restore(data: Dictionary) -> void:
	purchases_today = int(data.get("purchases_today", 0))
	worked_today = bool(data.get("worked_today", false))
	last_stall_id = str(data.get("last_stall_id", ""))
	changed.emit()
