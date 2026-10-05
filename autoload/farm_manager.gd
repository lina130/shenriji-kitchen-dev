extends Node

## 农场供应链：自己种出的原料直接进餐馆库存，利润比批发更高。
## 作物按游戏日生长，并受季节限制。

signal changed

const PLOT_COUNT := 6
const STAGE_EMPTY := "empty"
const STAGE_GROWING := "growing"
const STAGE_RIPE := "ripe"

var has_farm := false
var plots: Array = []
var tool_levels: Dictionary = {}
var selected_crop_id := ""
var last_weather_note := ""
var animals: Dictionary = {}
var animal_fed: Dictionary = {}
var animal_progress: Dictionary = {}
var animal_product_ready: Dictionary = {}

func _ready() -> void:
	reset_new_game()

func reset_new_game() -> void:
	has_farm = false
	plots.clear()
	tool_levels.clear()
	selected_crop_id = ""
	last_weather_note = ""
	animals.clear()
	animal_fed.clear()
	animal_progress.clear()
	animal_product_ready.clear()
	for index in range(PLOT_COUNT):
		plots.append({"stage": STAGE_EMPTY, "crop_id": "", "days_grown": 0.0, "watered": false})
	changed.emit()


func unlock_farm() -> bool:
	if has_farm:
		return false
	has_farm = true
	StoryManager.record_action("farm_unlock")
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true


func select_crop(crop_id: String) -> bool:
	if crop_id not in get_available_crops():
		NoticeManager.show_message("这个季节种不了这种作物。", "warning", "农场主")
		return false
	selected_crop_id = crop_id
	NoticeManager.show_message("选好了%s，去点一块空地种下。" % str(get_crop_row(crop_id).get("name", crop_id)), "hint", "农场主")
	changed.emit()
	return true

func get_selected_crop_name() -> String:
	if selected_crop_id.is_empty():
		return "还没选"
	return str(get_crop_row(selected_crop_id).get("name", selected_crop_id))

func interact_plot(plot_index: int) -> bool:
	if not _valid_plot(plot_index):
		return false
	var plot: Dictionary = plots[plot_index]
	match str(plot.get("stage", STAGE_EMPTY)):
		STAGE_EMPTY:
			var crop_id := selected_crop_id
			var available := get_available_crops()
			if crop_id.is_empty() and not available.is_empty():
				crop_id = str(available[0])
			return plant(plot_index, crop_id)
		STAGE_GROWING:
			if bool(plot.get("watered", false)):
				NoticeManager.show_message("这块地今天浇过了，等天气和作物自己长。", "hint", "农场主")
				return false
			return water(plot_index)
		STAGE_RIPE:
			return harvest(plot_index)
	return false

func get_weather_farm_hint() -> String:
	match WeatherSystem.current_weather_id:
		"rain":
			return "今天下雨，整片地都会自动浇透，叶菜和番茄的收购价也会好一点。"
		"heat":
			return "酷暑天不浇水会明显拖慢生长，柠檬和玉米却更卖得起价。"
		"humid":
			return "回南天潮气重，作物长得快一点，但青菜容易压价。"
		"overcast":
			return "阴天不晒，正常浇水就行。"
		_:
			return "晴天适合下地，记得给没浇的地补水。"
	return ""

func get_crop_row(crop_id: String) -> Dictionary:
	return ConfigDB.get_row("crops", crop_id)


func is_crop_in_season(crop_id: String, day_number: int = -1) -> bool:
	var row := get_crop_row(crop_id)
	if row.is_empty():
		return false
	var seasons := str(row.get("seasons", "")).split("|", false)
	var current := CalendarManager.get_season_id(day_number)
	for season in seasons:
		if str(season).strip_edges() == current:
			return true
	return false


func get_available_crops(day_number: int = -1) -> Array[String]:
	var result: Array[String] = []
	for crop_id in ConfigDB.get_rows("crops"):
		if is_crop_in_season(str(crop_id), day_number):
			result.append(str(crop_id))
	return result


func plant(plot_index: int, crop_id: String) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("farm_plant", {"plot_index": plot_index, "crop_id": crop_id})
	if not _valid_plot(plot_index):
		return false
	if not has_farm:
		NoticeManager.show_message("还没有属于自己的地，先去城郊租一块吧。", "warning")
		return false
	var plot: Dictionary = plots[plot_index]
	if str(plot.get("stage", STAGE_EMPTY)) != STAGE_EMPTY:
		NoticeManager.show_message("这块地已经种着东西了。", "hint")
		return false
	var row := get_crop_row(crop_id)
	if row.is_empty():
		return false
	if not is_crop_in_season(crop_id):
		NoticeManager.show_message("%s不适合这个季节，换个当季的吧。" % row.get("name", crop_id), "warning")
		return false
	var seed_cost := int(row.get("seed_cost", "0"))
	if InventoryManager.get_count("seed_pack") > 0:
		InventoryManager.remove_item("seed_pack", 1)
		NoticeManager.show_message("拆开种子包种下%s，这次不用再买种子。" % str(row.get("name", crop_id)), "positive", "农场主")
	elif seed_cost > 0 and not GameState.spend(seed_cost, "买下%s的种子，种进了第%d块地。" % [row.get("name", crop_id), plot_index + 1]):
		return false
	plot["stage"] = STAGE_GROWING
	plot["crop_id"] = crop_id
	plot["days_grown"] = 0.0
	plot["watered"] = false
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true


func water(plot_index: int) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("farm_water", {"plot_index": plot_index})
	if not _valid_plot(plot_index):
		return false
	var plot: Dictionary = plots[plot_index]
	if str(plot.get("stage", STAGE_EMPTY)) != STAGE_GROWING:
		return false
	plot["watered"] = true
	var radius := int(tool_levels.get("watering_can", 0)) * int(ConfigDB.get_row("farm_tools", "watering_can").get("effect_per_level", "1"))
	for offset in range(1, radius + 1):
		var adjacent := plot_index + offset
		if _valid_plot(adjacent) and str(plots[adjacent].get("stage", STAGE_EMPTY)) == STAGE_GROWING:
			plots[adjacent]["watered"] = true
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true


func harvest(plot_index: int) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("farm_harvest", {"plot_index": plot_index})
	if not _valid_plot(plot_index):
		return false
	var plot: Dictionary = plots[plot_index]
	if str(plot.get("stage", STAGE_EMPTY)) != STAGE_RIPE:
		return false
	var crop_id := str(plot.get("crop_id", ""))
	var row := get_crop_row(crop_id)
	if row.is_empty():
		return false
	var goods_id := str(row.get("goods_id", ""))
	var amount := int(row.get("yield_amount", "1"))
	var bonus := PetManager.get_bonus("harvest") + get_tool_effect("harvest_bonus")
	amount = int(round(float(amount) * maxf(1.0, 1.0 + bonus)))
	BusinessManager.add_farm_goods(goods_id, amount)
	NoticeManager.show_message("收了 %d 份%s，直接送进餐馆仓库。" % [amount, row.get("name", crop_id)], "positive")
	AchievementManager.record_event("farm_harvest")
	plot["stage"] = STAGE_EMPTY
	plot["crop_id"] = ""
	plot["days_grown"] = 0.0
	plot["watered"] = false
	SaveManager.request_auto_save("world_action")
	changed.emit()
	return true


func begin_new_day(_day_number: int) -> void:
	if not has_farm:
		return
	for index in range(plots.size()):
		var plot: Dictionary = plots[index]
		if str(plot.get("stage", STAGE_EMPTY)) != STAGE_GROWING:
			continue
		var row := get_crop_row(str(plot.get("crop_id", "")))
		if row.is_empty():
			continue
		var grow_days := maxf(1.0, float(row.get("grow_days", "1")))
		var sprinkler_plots := int(tool_levels.get("sprinkler", 0)) * int(ConfigDB.get_row("farm_tools", "sprinkler").get("effect_per_level", "1"))
		if index < sprinkler_plots or WeatherSystem.current_weather_id == "rain":
			plot["watered"] = true
		var step := 1.0
		var watered := bool(plot.get("watered", false))
		match WeatherSystem.current_weather_id:
			"rain":
				step = 1.35
			"heat":
				step = 1.0 if watered else 0.72
			"humid":
				step = 1.16
			_:
				step = 1.25 if watered else 1.0
		step += get_tool_effect("growth_bonus")
		plot["days_grown"] = float(plot.get("days_grown", 0.0)) + step
		plot["watered"] = WeatherSystem.current_weather_id == "rain"
		if float(plot["days_grown"]) >= grow_days:
			plot["days_grown"] = grow_days
			plot["stage"] = STAGE_RIPE
	last_weather_note = get_weather_farm_hint()
	_update_animals()
	changed.emit()

func buy_animal(animal_id: String) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("farm_buy_animal", {"animal_id": animal_id})
	if not has_farm:
		NoticeManager.show_npc_message("先租下农场，再考虑养鸡养牛。", "农场主", "hint")
		return false
	var row := ConfigDB.get_row("farm_animals", animal_id)
	if row.is_empty() or animals.has(animal_id):
		return false
	var cost := int(row.get("cost", "0"))
	if not GameState.spend(cost, "买下了%s。" % str(row.get("name", animal_id))):
		return false
	animals[animal_id] = true
	animal_fed[animal_id] = false
	animal_progress[animal_id] = 0
	animal_product_ready[animal_id] = false
	NoticeManager.show_npc_message("%s已经有住的地方了。记得每天喂饲料。" % str(row.get("name", animal_id)), "农场主", "positive")
	SaveManager.request_auto_save("farm_animal_buy")
	changed.emit()
	return true

func feed_animal(animal_id: String) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("farm_feed_animal", {"animal_id": animal_id})
	if not animals.has(animal_id) or bool(animal_fed.get(animal_id, false)):
		return false
	if BusinessManager.get_stock("animal_feed") <= 0:
		if not BusinessManager.buy_goods("animal_feed", 1):
			NoticeManager.show_npc_message("店里没有饲料，先去批发市场进一点。", "农场主", "warning")
			return false
	BusinessManager.goods_stock["animal_feed"] = maxi(0, BusinessManager.get_stock("animal_feed") - 1)
	animal_fed[animal_id] = true
	var row := ConfigDB.get_row("farm_animals", animal_id)
	NoticeManager.show_npc_message("%s喂好了。" % str(row.get("name", animal_id)), "农场主", "positive")
	SaveManager.request_auto_save("farm_animal_feed")
	changed.emit()
	return true

func collect_animal_product(animal_id: String) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("farm_collect_animal", {"animal_id": animal_id})
	if not animals.has(animal_id) or not bool(animal_product_ready.get(animal_id, false)):
		return false
	var row := ConfigDB.get_row("farm_animals", animal_id)
	var goods_id := str(row.get("product_goods_id", ""))
	var amount := int(row.get("product_amount", "1"))
	amount += int(round(float(amount) * get_tool_effect("harvest_bonus")))
	BusinessManager.goods_stock[goods_id] = BusinessManager.get_stock(goods_id) + amount
	animal_product_ready[animal_id] = false
	animal_progress[animal_id] = 0
	NoticeManager.show_npc_message("收下了%d份%s，已经放进餐馆仓库。" % [amount, str(row.get("product_name", goods_id))], "农场主", "positive")
	SaveManager.request_auto_save("farm_animal_collect")
	changed.emit()
	return true

func interact_animal(animal_id: String) -> bool:
	if not animals.has(animal_id):
		return buy_animal(animal_id)
	if not bool(animal_fed.get(animal_id, false)):
		return feed_animal(animal_id)
	if bool(animal_product_ready.get(animal_id, false)):
		return collect_animal_product(animal_id)
	var row := ConfigDB.get_row("farm_animals", animal_id)
	NoticeManager.show_npc_message("%s今天已经喂过了，等明天再看。" % str(row.get("name", animal_id)), "农场主", "hint")
	return false

func get_animal_prompt(animal_id: String) -> String:
	var row := ConfigDB.get_row("farm_animals", animal_id)
	if row.is_empty():
		return "看看动物棚"
	if not animals.has(animal_id):
		return "买下%s（¥%d）" % [str(row.get("name", animal_id)), int(row.get("cost", "0"))]
	if not bool(animal_fed.get(animal_id, false)):
		return "给%s喂饲料" % str(row.get("name", animal_id))
	if bool(animal_product_ready.get(animal_id, false)):
		return "收取%s的%s" % [str(row.get("name", animal_id)), str(row.get("product_name", "产物"))]
	return "查看%s" % str(row.get("name", animal_id))

func get_animal_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for animal_id in ConfigDB.get_rows("farm_animals"):
		var row := ConfigDB.get_row("farm_animals", animal_id)
		result.append({
			"id": str(animal_id),
			"name": str(row.get("name", animal_id)),
			"owned": animals.has(animal_id),
			"fed": bool(animal_fed.get(animal_id, false)),
			"ready": bool(animal_product_ready.get(animal_id, false)),
			"progress": int(animal_progress.get(animal_id, 0)),
			"days_per_product": int(row.get("days_per_product", "1")),
			"product_name": str(row.get("product_name", "")),
		})
	return result

func _update_animals() -> void:
	for animal_id in animals:
		if not bool(animal_fed.get(animal_id, false)):
			animal_progress[animal_id] = int(animal_progress.get(animal_id, 0))
			animal_fed[animal_id] = false
			continue
		var row := ConfigDB.get_row("farm_animals", animal_id)
		var step := 1.0
		if WeatherSystem.current_weather_id in ["rain", "humid"]:
			step = 1.2
		elif WeatherSystem.current_weather_id == "heat":
			step = 0.9
		var next_progress := int(animal_progress.get(animal_id, 0)) + int(round(step))
		if next_progress >= int(row.get("days_per_product", "1")):
			animal_product_ready[animal_id] = true
			animal_progress[animal_id] = int(row.get("days_per_product", "1"))
		else:
			animal_progress[animal_id] = next_progress
		animal_fed[animal_id] = false

func get_tool_effect(effect_type: String) -> float:
	var total := 0.0
	for tool_id in ConfigDB.get_rows("farm_tools"):
		var row := ConfigDB.get_row("farm_tools", tool_id)
		if str(row.get("effect_type", "")) != effect_type:
			continue
		total += float(tool_levels.get(tool_id, 0)) * float(row.get("effect_per_level", "0"))
	return total

func get_tool_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tool_id in ConfigDB.get_rows("farm_tools"):
		var row := ConfigDB.get_row("farm_tools", tool_id)
		var level := int(tool_levels.get(tool_id, 0))
		result.append({
			"id": str(tool_id),
			"name": str(row.get("name", tool_id)),
			"level": level,
			"max_level": int(row.get("max_level", "3")),
			"cost": get_tool_upgrade_cost(str(tool_id)),
			"description": str(row.get("description", "")),
		})
	return result

func get_tool_upgrade_cost(tool_id: String) -> int:
	var row := ConfigDB.get_row("farm_tools", tool_id)
	var level := int(tool_levels.get(tool_id, 0))
	return int(round(float(row.get("base_cost", "0")) * pow(float(row.get("upgrade_cost_growth", "1.8")), float(level))))

func upgrade_tool(tool_id: String) -> bool:
	if CoopManager.is_client_view_only():
		return CoopManager.request_shared_action("farm_upgrade_tool", {"tool_id": tool_id})
	var row := ConfigDB.get_row("farm_tools", tool_id)
	if row.is_empty() or not has_farm:
		return false
	var level := int(tool_levels.get(tool_id, 0))
	if level >= int(row.get("max_level", "3")):
		NoticeManager.show_message("%s已经升到顶了。" % str(row.get("name", tool_id)), "hint", "农场主")
		return false
	var cost := get_tool_upgrade_cost(tool_id)
	if not GameState.spend(cost, "升级农场工具：%s。" % str(row.get("name", tool_id))):
		return false
	tool_levels[tool_id] = level + 1
	NoticeManager.show_message("%s升到 Lv.%d。%s" % [str(row.get("name", tool_id)), level + 1, str(row.get("description", ""))], "positive", "农场主")
	SaveManager.request_auto_save("farm_tool_upgrade")
	changed.emit()
	return true

func get_plot_status(plot_index: int) -> Dictionary:
	if not _valid_plot(plot_index):
		return {}
	var plot: Dictionary = plots[plot_index]
	var crop_id := str(plot.get("crop_id", ""))
	var row := get_crop_row(crop_id)
	var grow_days := maxf(1.0, float(row.get("grow_days", "1")))
	return {
		"index": plot_index,
		"stage": str(plot.get("stage", STAGE_EMPTY)),
		"crop_id": crop_id,
		"crop_name": str(row.get("name", "空地")),
		"days_grown": float(plot.get("days_grown", 0.0)),
		"grow_days": grow_days,
		"progress": clampf(float(plot.get("days_grown", 0.0)) / grow_days, 0.0, 1.0),
		"watered": bool(plot.get("watered", false)),
	}


func get_all_plots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(plots.size()):
		result.append(get_plot_status(index))
	return result


func get_stage_name(stage: String) -> String:
	match stage:
		STAGE_EMPTY:
			return "空地"
		STAGE_GROWING:
			return "生长中"
		STAGE_RIPE:
			return "可以收割"
	return stage


func get_summary() -> String:
	if not has_farm:
		return "还没有租到农场。"
	var growing := 0
	var ripe := 0
	for plot in plots:
		if str(plot.get("stage", "")) == STAGE_GROWING:
			growing += 1
		elif str(plot.get("stage", "")) == STAGE_RIPE:
			ripe += 1
	var owned_animals := animals.size()
	var ready_animals := 0
	for animal_id in animal_product_ready:
		if bool(animal_product_ready[animal_id]):
			ready_animals += 1
	return "生长中 %d 块 · 可以收割 %d 块 · 圈舍 %d 只 · 可收 %d 份 · 选中%s" % [growing, ripe, owned_animals, ready_animals, get_selected_crop_name()]


func _valid_plot(plot_index: int) -> bool:
	return plot_index >= 0 and plot_index < plots.size()


func get_save_data() -> Dictionary:
	return {
		"has_farm": has_farm,
		"plots": plots.duplicate(true),
		"tool_levels": tool_levels.duplicate(true),
		"selected_crop_id": selected_crop_id,
		"animals": animals.duplicate(true),
		"animal_fed": animal_fed.duplicate(true),
		"animal_progress": animal_progress.duplicate(true),
		"animal_product_ready": animal_product_ready.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	has_farm = bool(data.get("has_farm", false))
	tool_levels = data.get("tool_levels", {}).duplicate(true)
	selected_crop_id = str(data.get("selected_crop_id", ""))
	animals = data.get("animals", {}).duplicate(true)
	animal_fed = data.get("animal_fed", {}).duplicate(true)
	animal_progress = data.get("animal_progress", {}).duplicate(true)
	animal_product_ready = data.get("animal_product_ready", {}).duplicate(true)
	plots.clear()
	var saved: Array = data.get("plots", [])
	for index in range(PLOT_COUNT):
		if index < saved.size() and typeof(saved[index]) == TYPE_DICTIONARY:
			var plot: Dictionary = saved[index].duplicate(true)
			plots.append({
				"stage": str(plot.get("stage", STAGE_EMPTY)),
				"crop_id": str(plot.get("crop_id", "")),
				"days_grown": float(plot.get("days_grown", 0.0)),
				"watered": bool(plot.get("watered", false)),
			})
		else:
			plots.append({"stage": STAGE_EMPTY, "crop_id": "", "days_grown": 0.0, "watered": false})
	changed.emit()
