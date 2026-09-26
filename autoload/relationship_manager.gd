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

func talk_to(npc_id: String) -> String:
	var today_key := "%s:%d" % [npc_id, TimeSystem.current_day]
	var lines: Array = DIALOGUES.get(npc_id, ["对方只是朝你点了点头。"])
	var line := str(RandomManager.pick(lines))
	if not talked_today.has(today_key):
		talked_today[today_key] = true
		affinity[npc_id] = int(affinity.get(npc_id, 0)) + 1
		ProgressionManager.record_social_action()
		changed.emit()
	return line

func give_item(npc_id: String, item_id: String) -> Dictionary:
	var item := InventoryManager.get_item(item_id)
	if item.is_empty() or not InventoryManager.remove_item(item_id, 1):
		return {"ok": false, "message": "包里没有这件东西。"}
	var preferred := str(ConfigDB.get_row("npcs", npc_id).get("preferred_item", ""))
	var gain := 3 if item_id == preferred else 1
	affinity[npc_id] = int(affinity.get(npc_id, 0)) + gain
	ProgressionManager.record_social_action()
	changed.emit()
	if item_id == preferred:
		return {"ok": true, "message": "%s眼睛一亮，小心收下了%s。" % [get_npc_name(npc_id), item.get("name", item_id)]}
	return {"ok": true, "message": "%s收下了%s，说你有心了。" % [get_npc_name(npc_id), item.get("name", item_id)]}

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
	}

func restore(data: Dictionary) -> void:
	affinity = data.get("affinity", {}).duplicate(true)
	talked_today = data.get("talked_today", {}).duplicate(true)
	changed.emit()

func reset_new_game() -> void:
	affinity.clear()
	talked_today.clear()
	changed.emit()