extends Node

signal changed

const DIALOGUES := {
	"mei": [
		"梅姨：回来啦？最近睡得还行吧。",
		"梅姨：屋子潮就把窗开一会儿，人住得舒服比什么都强。",
		"梅姨：日子慢慢过，别总绷着一根弦。",
	],
	"wang": [
		"王师傅：手上的活稳一点，比赶一时快更值钱。",
		"王师傅：累了就说，机器停一会儿不会塌。",
		"王师傅：你比刚来的时候熟多了，继续保持。",
	],
	"lin": [
		"小林：今天雨大，路上慢点。",
		"小林：店里的灯一直亮着，晚上回来也不冷清。",
		"小林：偶尔也要给自己买点喜欢的东西。",
	],
	"chen": [
		"陈伯：旧东西不吵不闹，却能记住很多事。",
		"陈伯：逛巷子别只看脚下，墙角和树上也常有惊喜。",
		"陈伯：摸到好东西是你的缘分，守得住才是本事。",
	],
}

var affinity: Dictionary = {}
var talked_today: Dictionary = {}
var birthday_greeted: Dictionary = {}

func _ready() -> void:
	TimeSystem.day_started.connect(_on_day_started)

func _on_day_started(day_number: int) -> void:
	for npc_id in get_birthday_npcs(day_number):
		if int(affinity.get(npc_id, 0)) >= 8:
			NoticeManager.show_scene_message("今天是%s生日。路过时别只点头，说一句也好。" % get_npc_name(npc_id), "城市日历", "positive")

func get_birthday_npcs(day_number: int = -1) -> Array[String]:
	var result: Array[String] = []
	var day_of_year := CalendarManager.get_day_of_year(day_number)
	for npc_id in ConfigDB.get_rows("npcs"):
		var birthday := int(ConfigDB.get_row("npcs", str(npc_id)).get("birthday_day", "-1"))
		if birthday == day_of_year:
			result.append(str(npc_id))
	return result

func get_today_birthday_names() -> Array[String]:
	var result: Array[String] = []
	for npc_id in get_birthday_npcs():
		result.append(get_npc_name(npc_id))
	return result

func is_birthday(npc_id: String, day_number: int = -1) -> bool:
	return int(ConfigDB.get_row("npcs", npc_id).get("birthday_day", "-1")) == CalendarManager.get_day_of_year(day_number)

func _birthday_key(npc_id: String) -> String:
	return "%d:%d:%s" % [CalendarManager.get_year(), CalendarManager.get_day_of_year(), npc_id]

func talk_to(npc_id: String) -> String:
	var today_key := "%s:%d" % [npc_id, TimeSystem.current_day]
	var line := _scheduled_line(npc_id)
	if line.is_empty():
		var lines: Array = DIALOGUES.get(npc_id, ["对方只是朝你点了点头。"])
		line = str(RandomManager.pick(lines))
	if not talked_today.has(today_key):
		var contextual := _contextual_line(npc_id)
		if not contextual.is_empty():
			line = "%s\n%s" % [line, contextual]
		if is_birthday(npc_id) and not birthday_greeted.has(_birthday_key(npc_id)):
			birthday_greeted[_birthday_key(npc_id)] = true
			affinity[npc_id] = int(affinity.get(npc_id, 0)) + 3
			AchievementManager.record_event("birthday_greeting")
			line = "%s\n今天是%s生日，你把祝福说得很认真。" % [line, get_npc_name(npc_id)]
			NoticeManager.show_npc_message("你还记得今天。", get_npc_name(npc_id), "positive")
		talked_today[today_key] = true
		var social_gain := 2 if WellbeingManager.get_action_bonus("social") >= 0.08 else 1
		var new_affinity := int(affinity.get(npc_id, 0)) + social_gain
		affinity[npc_id] = new_affinity
		ProgressionManager.record_social_action()
		if new_affinity == 4:
			InventoryManager.add_item("bread", 1)
			NoticeManager.show_message("%s开始把你当熟人了，顺手塞了点吃的。" % get_npc_name(npc_id), "positive")
		elif new_affinity == 10:
			NoticeManager.show_message("你和%s的关系更近了，拿货和招待客人都更顺。" % get_npc_name(npc_id), "positive")
		elif new_affinity == 18:
			var gift_id := _gift_for_npc(npc_id)
			InventoryManager.add_item(gift_id, 1)
			CollectionManager.discovered[gift_id] = true
			NoticeManager.show_message("%s把珍藏的%s送给了你。" % [get_npc_name(npc_id), InventoryManager.get_item(gift_id).get("name", gift_id)], "positive")
		changed.emit()
	return line


func _contextual_line(npc_id: String) -> String:
	match npc_id:
		"mei":
			if not CareerManager.is_employed():
				return "楼下早餐店和工业区都在招人，先去问一声，总比在家等强。"
			if HousingManager.current_tier <= 0:
				return "攒够钱就看看小单间，住得稳，做事才不容易被风吹散。"
		"wang":
			if not CareerManager.is_employed_in("factory"):
				return "工厂还缺人，工业区门口那块招聘牌看过没有？"
			if CareerManager.current_rank < 2:
				return "班次做稳，领班自然会让你碰更重要的活。"
		"lin":
			if WardrobeManager.owned.is_empty():
				return "服装店新到了几件合身的，穿舒服了做事也顺。"
			if PhotoManager.photos.is_empty():
				return "有空去河边拍张照片，今天也是以后才会有的日子。"
		"chen":
			if CollectionManager.discovered.size() < 10:
				return "旧货市场别只盯摊位，回收站墙角也常有好东西。"
		"huang":
			if KitchenManager.served <= 0:
				return "早餐忙起来别乱，先接单，再按每道早餐的工序走。"
			if StaffManager.hired.is_empty():
				return "店里忙不过来，就听熟人介绍个人，别一个人硬撑。"
		"azhen":
			if WardrobeManager.owned.is_empty():
				return "先买件合身的，不用贵。人舒服了，气色就不一样。"
		"qiang":
			if FishingManager.catches.is_empty():
				return "河边下竿先看风，别只盯浮漂。"
		"xiaoyu":
			if PhotoManager.photos.is_empty():
				return "拍照不用等远方，先把今天留下来。"
		"lan":
			if FestivalManager.claimed.is_empty():
				return "节日摊子过了就收，看到喜欢的纪念品就别犹豫。"
	return ""

func get_affinity(npc_id: String) -> int:
	return int(affinity.get(npc_id, 0))

func get_friend_count(threshold: int = 10) -> int:
	var count := 0
	for value in affinity.values():
		if int(value) >= threshold:
			count += 1
	return count

func get_supplier_discount() -> float:
	return minf(0.08, float(get_friend_count(10)) * 0.015)

func get_market_bonus() -> float:
	return minf(0.05, float(get_friend_count(10)) * 0.01)

func get_patience_bonus() -> float:
	return minf(6.0, float(get_friend_count(10)) * 1.2 + WardrobeManager.get_bonus("social") + WellbeingManager.get_action_bonus("social") * 8.0 + HobbyManager.get_social_bonus() * 6.0)

func get_network_effect_text() -> String:
	var friends := get_friend_count(10)
	if friends <= 0:
		return "熟客网络：还只是点头之交。"
	if get_friend_count(18) > 0:
		return "熟客网络：老朋友会留好货，客人也更有耐心。"
	return "熟客网络：已有 %d 位熟人，进货有折扣，客人更愿意等。" % friends

func get_effect_text(npc_id: String) -> String:
	var value := get_affinity(npc_id)
	if value >= 18:
		return "老朋友：拿货更便宜、客人更耐心，还会送你珍藏旧物。"
	if value >= 10:
		return "熟人：拿货有折扣，客人愿意多等一会儿。"
	if value >= 4:
		return "点头之交：见面更热情，偶尔会分你一点吃的。"
	return "刚认识：先从每天打个招呼开始。"

func _gift_for_npc(npc_id: String) -> String:
	match npc_id:
		"mei":
			return "sea_glass"
		"wang":
			return "workshop_badge"
		"lin":
			return "film_camera"
		"chen":
			return "brass_compass"
	return "metal_part"

func give_item(npc_id: String, item_id: String) -> Dictionary:
	var item := InventoryManager.get_item(item_id)
	if item.is_empty() or not InventoryManager.remove_item(item_id, 1):
		return {"ok": false, "message": "包里没有这件东西。"}
	var preferred := str(ConfigDB.get_row("npcs", npc_id).get("preferred_item", ""))
	var gain := 3 if item_id == preferred else 1
	var birthday := is_birthday(npc_id)
	if birthday:
		gain *= 2
	affinity[npc_id] = int(affinity.get(npc_id, 0)) + gain
	ProgressionManager.record_social_action()
	if birthday:
		AchievementManager.record_event("birthday_gift")
	changed.emit()
	if birthday:
		return {"ok": true, "message": "%s今天过生日，收下%s时比平时更高兴。" % [get_npc_name(npc_id), item.get("name", item_id)]}
	if item_id == preferred:
		return {"ok": true, "message": "%s眼睛一亮，小心收下了%s。" % [get_npc_name(npc_id), item.get("name", item_id)]}
	return {"ok": true, "message": "%s收下了%s，说你有心了。" % [get_npc_name(npc_id), item.get("name", item_id)]}

func _scheduled_line(npc_id: String) -> String:
	var hours := int(TimeSystem.minute_of_day / 60)
	var period := "morning"
	if hours >= 12 and hours < 18:
		period = "noon"
	elif hours >= 18:
		period = "evening"
	var entries = ConfigDB.get_rows("npc_dialogue").get(npc_id, [])
	if typeof(entries) != TYPE_ARRAY:
		entries = [entries]
	var candidates: Array = []
	for entry in entries:
		if str(entry.get("period", "")) != period:
			continue
		if not _dialogue_conditions_met(npc_id, entry):
			continue
		candidates.append(str(entry.get("line", "")))
	if candidates.is_empty():
		return ""
	return str(RandomManager.pick(candidates))

func _dialogue_conditions_met(npc_id: String, entry: Dictionary) -> bool:
	var weather := str(entry.get("weather", ""))
	if not weather.is_empty() and weather != WeatherSystem.current_weather_id:
		return false
	var career_line := str(entry.get("career_line", ""))
	if not career_line.is_empty() and career_line != CareerManager.current_line:
		return false
	if get_affinity(npc_id) < int(entry.get("min_affinity", "0")):
		return false
	return true

func get_npc_personality(npc_id: String) -> String:
	return str(ConfigDB.get_row("npcs", npc_id).get("personality", "看起来有自己的生活。"))

func get_npc_purpose(npc_id: String) -> String:
	return str(ConfigDB.get_row("npcs", npc_id).get("purpose", "会在城里过自己的日子。"))

func get_npc_name(npc_id: String) -> String:
	return str(ConfigDB.get_row("npcs", npc_id).get("name", npc_id))

func get_affinity_label(npc_id: String) -> String:
	var value := int(affinity.get(npc_id, 0))
	if value >= 18:
		return "像老朋友一样"
	if value >= 10:
		return "已经很熟络"
	if value >= 4:
		return "见面会聊几句"
	return "刚刚认识"

func begin_new_day(_day_number: int) -> void:
	talked_today.clear()

func get_save_data() -> Dictionary:
	return {
		"affinity": affinity.duplicate(true),
		"talked_today": talked_today.duplicate(true),
		"birthday_greeted": birthday_greeted.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	affinity = data.get("affinity", {}).duplicate(true)
	talked_today = data.get("talked_today", {}).duplicate(true)
	birthday_greeted = data.get("birthday_greeted", {}).duplicate(true)
	changed.emit()

func reset_new_game() -> void:
	affinity.clear()
	talked_today.clear()
	changed.emit()