class_name GameHUD
extends CanvasLayer

signal modal_changed(is_open: bool)
signal return_to_menu_requested

enum ModalState { NONE, INVENTORY, SHOP, MARKET, COLLECTION_LOG, MAP, BANK, DIALOGUE, MONTHLY, PAUSE, EXPEDITION_MAP, KITCHEN, WHOLESALE }

var _root: Control
var _ambient_overlay: ColorRect
var _status_panel: PanelContainer
var _money_label: Label
var _time_label: Label
var _weather_label: Label
var _context_panel: PanelContainer
var _context_label: Label
var _notice_panel: PanelContainer
var _notice_label: Label
var _modal_panel: PanelContainer
var _modal_title: Label
var _modal_subtitle: Label
var _modal_items: VBoxContainer
var _notice_time_left := 0.0
var _clock_accumulator := 0.0
var _modal_state := ModalState.NONE
var _fog_overlay: ColorRect
var _kitchen_orders_box: VBoxContainer
var _kitchen_stations_box: VBoxContainer
var _kitchen_recipes_box: VBoxContainer
var _kitchen_status_label: Label
var _kitchen_station_buttons: Array[Button] = []
var _kitchen_recipe_buttons: Dictionary = {}
var _kitchen_order_labels: Array[Label] = []
var _kitchen_restart_button: Button
var _active_npc_id := ""

func _ready() -> void:
	layer = 20
	add_to_group("hud")
	_build_interface()
	GameState.money_changed.connect(_on_money_changed)
	KitchenManager.changed.connect(_on_kitchen_changed)
	BusinessManager.changed.connect(_on_business_changed)
	FinanceManager.changed.connect(_on_finance_changed)
	NoticeManager.notice_requested.connect(show_notice)
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	TimeSystem.paused_changed.connect(_on_pause_changed)
	_on_money_changed(GameState.money)
	_on_weather_changed(WeatherSystem.current_weather_id)
	_update_clock()
	_apply_ambient_state()

func _process(delta: float) -> void:
	_clock_accumulator += delta
	if _clock_accumulator >= 0.2:
		_clock_accumulator = 0.0
		_update_clock()
		if _modal_state == ModalState.KITCHEN:
			_refresh_kitchen_ui()
	_apply_ambient_state()
	_apply_expedition_state()
	if _notice_time_left > 0.0:
		_notice_time_left -= delta
		if _notice_time_left <= 0.0:
			_notice_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _modal_state != ModalState.NONE:
			_close_modal()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		_toggle_modal(ModalState.INVENTORY, open_inventory)
	elif event.is_action_pressed("collection"):
		_toggle_modal(ModalState.COLLECTION_LOG, open_collection_log)
	elif event.is_action_pressed("map"):
		_toggle_modal(ModalState.MAP, open_map)
	elif event.is_action_pressed("bank"):
		_toggle_modal(ModalState.BANK, open_bank)
	elif event.is_action_pressed("kitchen"):
		_toggle_modal(ModalState.KITCHEN, open_kitchen)
	elif event.is_action_pressed("chat"):
		NoticeManager.show_message("好友邀约会在轻量联机版本开放。", "hint")
	else:
		return
	get_viewport().set_input_as_handled()

func set_context_prompt(text: String) -> void:
	_context_label.text = text
	_context_panel.visible = not text.is_empty() and _modal_state == ModalState.NONE

func show_notice(message: String, tone: String = "normal") -> void:
	if message.is_empty():
		return
	_notice_label.text = message
	_notice_label.add_theme_color_override("font_color", _notice_color(tone))
	_notice_panel.visible = true
	_notice_time_left = 2.8

func open_inventory(intro: String = "") -> void:
	_build_inventory_content()
	_set_modal(ModalState.INVENTORY, "随身的包", intro if not intro.is_empty() else "东西都塞在一起，拿起来就能用。")

func open_shop(_shop_id: String = "convenience_store") -> void:
	_build_shop_content()
	_set_modal(ModalState.SHOP, "街角便利店", "柜台上都写着固定价格。")

func open_market(_market_id: String = "old_market") -> void:
	_build_market_content()
	_set_modal(ModalState.MARKET, "旧货行", "旧东西没有统一价钱，愿意收就换点生活费。")

func open_expedition_map() -> void:
	_build_expedition_map_content()
	_set_modal(ModalState.EXPEDITION_MAP, "旧物行深处", MarketEconomyManager.get_market_brief())

func open_collection_log() -> void:
	_build_collection_log_content()
	_set_modal(ModalState.COLLECTION_LOG, "旧物册", "逛到过的东西会留在这里，不催你去凑齐。")

func open_map() -> void:
	_build_map_content()
	_set_modal(ModalState.MAP, "深城手绘地图", "已走过的角落都记在上面。")

func open_bank() -> void:
	_build_bank_content()
	_set_modal(ModalState.BANK, "银行与彩票", "存钱、取钱，偶尔买一张彩票试试手气。")

func open_kitchen() -> void:
	if not KitchenManager.active:
		if not KitchenManager.start_shift():
			return
	_build_kitchen_content()
	_set_modal(ModalState.KITCHEN, "夜市档口", "订单不等人，备料、下锅、上菜要连贯。")

func open_wholesale() -> void:
	_build_wholesale_content()
	_set_modal(ModalState.WHOLESALE, "清晨批发市场", "便宜时进货，紧缺时出手，也会看走眼。")

func open_dialogue(npc_id: String) -> void:
	_active_npc_id = npc_id
	var line := RelationshipManager.talk_to(npc_id)
	_build_dialogue_content(line)
	_set_modal(ModalState.DIALOGUE, RelationshipManager.get_npc_name(npc_id), line)

func show_month_summary(summary: Dictionary) -> void:
	_build_month_summary_content(summary)
	_set_modal(ModalState.MONTHLY, "城中村的生活小结", "一个月过去，新的日子又开始了。")

func open_pause() -> void:
	_build_pause_content()
	_set_modal(ModalState.PAUSE, "先歇一下", "时间停在这里，外面暂时不会往前走。", true)

func _toggle_modal(state: ModalState, opener: Callable) -> void:
	if _modal_state == state:
		_close_modal()
		return
	if _modal_state != ModalState.NONE:
		_close_modal()
	opener.call()

func _on_kitchen_changed() -> void:
	if _modal_state == ModalState.KITCHEN and is_instance_valid(_kitchen_orders_box):
		_refresh_kitchen_ui()

func _on_business_changed() -> void:
	if _modal_state == ModalState.MARKET:
		_build_market_content()
	elif _modal_state == ModalState.WHOLESALE:
		_build_wholesale_content()
	elif _modal_state == ModalState.BANK:
		_build_bank_content()

func _on_finance_changed() -> void:
	if _modal_state == ModalState.BANK:
		_build_bank_content()
func _build_interface() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 19
	_root.theme = theme

	_ambient_overlay = ColorRect.new()
	_ambient_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ambient_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ambient_overlay)

	_fog_overlay = ColorRect.new()
	_fog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fog_material := ShaderMaterial.new()
	fog_material.shader = load("res://shaders/fog_of_war.gdshader")
	_fog_overlay.material = fog_material
	_fog_overlay.visible = false
	_root.add_child(_fog_overlay)

	_status_panel = PanelContainer.new()
	_status_panel.position = Vector2(24, 20)
	_status_panel.size = Vector2(610, 58)
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(_status_panel, Color(0.04, 0.09, 0.11, 0.84), Color(0.56, 0.88, 0.79, 0.32))
	_root.add_child(_status_panel)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 26)
	_status_panel.add_child(status_row)
	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 23)
	_money_label.add_theme_color_override("font_color", Color("#f2cf73"))
	status_row.add_child(_money_label)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 20)
	_time_label.add_theme_color_override("font_color", Color("#d9eee7"))
	status_row.add_child(_time_label)
	_weather_label = Label.new()
	_weather_label.add_theme_font_size_override("font_size", 19)
	_weather_label.add_theme_color_override("font_color", Color("#a9cbd3"))
	status_row.add_child(_weather_label)

	_context_panel = PanelContainer.new()
	_context_panel.anchor_left = 0.5
	_context_panel.anchor_right = 0.5
	_context_panel.anchor_top = 1.0
	_context_panel.anchor_bottom = 1.0
	_context_panel.offset_left = -280
	_context_panel.offset_right = 280
	_context_panel.offset_top = -104
	_context_panel.offset_bottom = -48
	_context_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(_context_panel, Color(0.03, 0.07, 0.08, 0.88), Color(1.0, 0.86, 0.45, 0.45))
	_root.add_child(_context_panel)
	_context_label = Label.new()
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context_label.add_theme_color_override("font_color", Color("#ffe8a8"))
	_context_panel.add_child(_context_label)
	_context_panel.visible = false

	_notice_panel = PanelContainer.new()
	_notice_panel.anchor_left = 0.5
	_notice_panel.anchor_right = 0.5
	_notice_panel.anchor_top = 1.0
	_notice_panel.anchor_bottom = 1.0
	_notice_panel.offset_left = -370
	_notice_panel.offset_right = 370
	_notice_panel.offset_top = -172
	_notice_panel.offset_bottom = -118
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(_notice_panel, Color(0.025, 0.055, 0.064, 0.94), Color(0.97, 0.78, 0.35, 0.55))
	_root.add_child(_notice_panel)
	_notice_label = Label.new()
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.add_theme_font_size_override("font_size", 20)
	_notice_panel.add_child(_notice_label)
	_notice_panel.visible = false

	_modal_panel = PanelContainer.new()
	_modal_panel.anchor_left = 0.5
	_modal_panel.anchor_right = 0.5
	_modal_panel.anchor_top = 0.5
	_modal_panel.anchor_bottom = 0.5
	_modal_panel.offset_left = -390
	_modal_panel.offset_right = 390
	_modal_panel.offset_top = -285
	_modal_panel.offset_bottom = 285
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(_modal_panel, Color(0.035, 0.075, 0.085, 0.98), Color(0.96, 0.77, 0.35, 0.7), 18)
	_root.add_child(_modal_panel)
	var modal_margin := MarginContainer.new()
	modal_margin.add_theme_constant_override("margin_left", 26)
	modal_margin.add_theme_constant_override("margin_right", 26)
	modal_margin.add_theme_constant_override("margin_top", 22)
	modal_margin.add_theme_constant_override("margin_bottom", 22)
	_modal_panel.add_child(modal_margin)
	var modal_column := VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 12)
	modal_margin.add_child(modal_column)
	_modal_title = Label.new()
	_modal_title.add_theme_font_size_override("font_size", 30)
	_modal_title.add_theme_color_override("font_color", Color("#f5d895"))
	modal_column.add_child(_modal_title)
	_modal_subtitle = Label.new()
	_modal_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_subtitle.add_theme_color_override("font_color", Color("#afc9c4"))
	modal_column.add_child(_modal_subtitle)
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.75, 0.62, 0.34, 0.38))
	modal_column.add_child(separator)
	_modal_items = VBoxContainer.new()
	_modal_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_items.add_theme_constant_override("separation", 9)
	modal_column.add_child(_modal_items)
	var close_button := Button.new()
	close_button.text = "收起（Esc）"
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.pressed.connect(_close_modal)
	modal_column.add_child(close_button)
func _build_inventory_content() -> void:
	_clear_modal_items()
	var entries := InventoryManager.get_inventory_lines()
	if entries.is_empty():
		_modal_items.add_child(_make_empty_label("包里暂时空着。"))
		return
	for entry in entries:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var label := "%s  ×%d" % [entry["name"], entry["count"]]
		if str(entry["category"]) == "collectible":
			label += "   · 旧物"
		button.text = label
		button.tooltip_text = str(entry["description"])
		if bool(entry["usable"]):
			button.pressed.connect(_on_inventory_use.bind(str(entry["id"])))
		else:
			button.disabled = true
		_modal_items.add_child(button)

func _build_shop_content() -> void:
	_clear_modal_items()
	for item_id in ["meal_rice", "bread", "water", "coffee"]:
		var item := InventoryManager.get_item(item_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s    ¥%d" % [item.get("name", item_id), int(item.get("price", 0))]
		button.tooltip_text = str(item.get("description", ""))
		button.pressed.connect(_on_shop_buy.bind(item_id))
		_modal_items.add_child(button)
	_modal_items.add_child(_make_empty_label("放进包里就能随身带着。"))

func _build_market_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("%s · 已服务 %d 位客人 · 店铺估值 ¥%d" % [BusinessManager.get_business_level_name(), BusinessManager.customers_served, BusinessManager.get_business_valuation()]))
	var operations := HBoxContainer.new()
	operations.add_theme_constant_override("separation", 8)
	_add_action_button(operations, "开始营业", func() -> void: _open_kitchen_from_market())
	_add_action_button(operations, "批发进货", func() -> void: _open_wholesale_from_market())
	_add_action_button(operations, "升级店面", _on_business_upgrade)
	_modal_items.add_child(operations)
	if BusinessManager.can_sell_business():
		_add_action_button(_modal_items, "转让铺子估值 ¥%d" % BusinessManager.get_business_valuation(), _on_sell_business)
	_modal_items.add_child(_make_empty_label(MarketEconomyManager.get_market_brief()))
	_modal_items.add_child(_make_empty_label("%s · %s" % [MarketEconomyManager.get_stall_name(), MarketEconomyManager.get_consignment_summary()]))
	var entries := InventoryManager.get_giftable_lines()
	if entries.is_empty():
		_modal_items.add_child(_make_empty_label("包里没有能出手的旧物。"))
	else:
		for entry in entries:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var price := MarketEconomyManager.get_current_price(str(entry["id"]))
			var info := Label.new()
			info.text = "%s ×%d · %s" % [entry["name"], entry["count"], MarketEconomyManager.get_demand_label(str(entry["id"]))]
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_color_override("font_color", Color("#d9e7e1"))
			row.add_child(info)
			var sell_button := Button.new()
			sell_button.text = "卖 ¥%d" % price
			sell_button.pressed.connect(_on_market_sell.bind(str(entry["id"])))
			row.add_child(sell_button)
			var consign_button := Button.new()
			consign_button.text = "寄卖"
			consign_button.pressed.connect(_on_market_consign.bind(str(entry["id"])))
			row.add_child(consign_button)
			_modal_items.add_child(row)
	if MarketEconomyManager.stall_tier < 2:
		var cost := 900 if MarketEconomyManager.stall_tier == 0 else 2400
		var upgrade := Button.new()
		upgrade.text = "把摊位做大一点 · ¥%d" % cost
		upgrade.custom_minimum_size = Vector2(0, 50)
		upgrade.pressed.connect(_on_market_upgrade)
		_modal_items.add_child(upgrade)

func _open_kitchen_from_market() -> void:
	_close_modal()
	open_kitchen()

func _open_wholesale_from_market() -> void:
	_close_modal()
	open_wholesale()

func _on_business_upgrade() -> void:
	BusinessManager.upgrade_business()

func _on_sell_business() -> void:
	BusinessManager.sell_business()

func _build_kitchen_content() -> void:
	_clear_modal_items()
	_kitchen_status_label = Label.new()
	_kitchen_status_label.add_theme_color_override("font_color", Color("#f4d88a"))
	_modal_items.add_child(_kitchen_status_label)
	_kitchen_orders_box = VBoxContainer.new()
	_modal_items.add_child(_kitchen_orders_box)
	_kitchen_orders_box.add_child(_make_empty_label("等待订单："))
	_kitchen_order_labels.clear()
	for index in range(4):
		var order_label := Label.new()
		order_label.visible = false
		_kitchen_orders_box.add_child(order_label)
		_kitchen_order_labels.append(order_label)
	_kitchen_stations_box = VBoxContainer.new()
	_modal_items.add_child(_kitchen_stations_box)
	_kitchen_stations_box.add_child(_make_empty_label("工位："))
	_kitchen_station_buttons.clear()
	for index in range(4):
		var station_button := Button.new()
		station_button.custom_minimum_size = Vector2(0, 48)
		station_button.visible = false
		station_button.pressed.connect(_on_kitchen_station.bind(index))
		_kitchen_stations_box.add_child(station_button)
		_kitchen_station_buttons.append(station_button)
	_kitchen_recipes_box = VBoxContainer.new()
	_modal_items.add_child(_kitchen_recipes_box)
	_kitchen_recipes_box.add_child(_make_empty_label("菜单（点一下放进空闲工位）："))
	_kitchen_recipe_buttons.clear()
	for recipe_id in BusinessManager.get_recipe_ids():
		var recipe_button := Button.new()
		var connected_recipe_id := str(recipe_id)
		recipe_button.custom_minimum_size = Vector2(0, 44)
		recipe_button.visible = false
		recipe_button.pressed.connect(_on_kitchen_place.bind(connected_recipe_id))
		_kitchen_recipes_box.add_child(recipe_button)
		_kitchen_recipe_buttons[connected_recipe_id] = recipe_button
	var support_row := HBoxContainer.new()
	support_row.add_theme_constant_override("separation", 8)
	_add_action_button(support_row, "招个帮手 ¥36", func() -> void: BusinessManager.restock_labor())
	_add_action_button(support_row, "集中缓一缓 ¥30", func() -> void: BusinessManager.restock_brain())
	_add_action_button(support_row, "提前打烊", func() -> void: KitchenManager.end_shift())
	_kitchen_restart_button = _add_action_button(support_row, "再开一次档", func() -> void: _restart_kitchen())
	_kitchen_restart_button.visible = false
	_modal_items.add_child(support_row)
	_refresh_kitchen_ui()

func _refresh_kitchen_ui() -> void:
	if not is_instance_valid(_kitchen_status_label):
		return
	if not KitchenManager.active:
		_kitchen_status_label.text = "今日营业已结束。"
		for button in _kitchen_station_buttons:
			button.visible = false
		for button in _kitchen_recipe_buttons.values():
			button.visible = false
		for label in _kitchen_order_labels:
			label.visible = false
		_kitchen_restart_button.visible = true
		return
	_kitchen_restart_button.visible = false
	_kitchen_status_label.text = "剩余 %d 秒 · 已出餐 %d/%d · 连击 %d · 劳力 %d · 脑力 %d" % [
		int(ceil(KitchenManager.time_left)), KitchenManager.served, KitchenManager.get_order_target(),
		KitchenManager.combo, BusinessManager.labor_stock, BusinessManager.brain_stock,
	]
	var order_status := KitchenManager.get_orders_status()
	for index in range(_kitchen_order_labels.size()):
		if index < order_status.size():
			var order: Dictionary = order_status[index]
			_kitchen_order_labels[index].visible = true
			_kitchen_order_labels[index].text = "%s · 耐心 %d 秒" % [order["name"], int(ceil(float(order["patience"])))]
		else:
			_kitchen_order_labels[index].visible = false
	var station_status := KitchenManager.get_stations_status()
	for index in range(_kitchen_station_buttons.size()):
		if index < station_status.size():
			var station: Dictionary = station_status[index]
			_kitchen_station_buttons[index].visible = true
			_kitchen_station_buttons[index].text = "工位 %d · %s · %s · %d%%" % [index + 1, station["name"], station["action_text"], int(float(station["progress_ratio"]) * 100.0)]
		else:
			_kitchen_station_buttons[index].visible = false
	var unlocked := BusinessManager.get_unlocked_recipe_ids()
	for recipe in KitchenManager.get_recipes_status():
		var recipe_id := str(recipe["id"])
		var button: Button = _kitchen_recipe_buttons.get(recipe_id)
		if button == null:
			continue
		button.visible = recipe_id in unlocked
		button.text = "%s ¥%d · %s · 劳力%d 脑力%d" % [recipe["name"], int(recipe["sale_price"]), recipe["goods_recipe"], int(recipe["labor_cost"]), int(recipe["brain_cost"])]
		button.disabled = not bool(recipe["available"]) or _first_idle_station() < 0

func _restart_kitchen() -> void:
	if KitchenManager.start_shift():
		_build_kitchen_content()

func _on_kitchen_place(recipe_id: String) -> void:
	var station_index := _first_idle_station()
	if station_index >= 0:
		KitchenManager.place_recipe(recipe_id, station_index)

func _on_kitchen_station(station_index: int) -> void:
	KitchenManager.advance_station(station_index)

func _first_idle_station() -> int:
	for station in KitchenManager.get_stations_status():
		if str(station["state"]) == "idle":
			return int(station["index"])
	return -1

func _build_wholesale_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("现金 ¥%d · 商品库存价值 ¥%d · 今日价格每日变化" % [GameState.money, BusinessManager.get_stock_value()]))
	for line in BusinessManager.get_goods_lines():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var info := Label.new()
		info.custom_minimum_size = Vector2(245, 0)
		info.text = "%s ×%d · 进¥%d 卖¥%d · %s" % [line["name"], int(line["stock"]), int(line["buy_price"]), int(line["sell_price"]), line["note"]]
		info.add_theme_color_override("font_color", Color("#dce8e2"))
		row.add_child(info)
		_add_action_button(row, "买1", _on_wholesale_buy.bind(str(line["id"]), 1))
		_add_action_button(row, "买5", _on_wholesale_buy.bind(str(line["id"]), 5))
		_add_action_button(row, "卖1", _on_wholesale_sell.bind(str(line["id"]), 1))
		_add_action_button(row, "卖5", _on_wholesale_sell.bind(str(line["id"]), 5))
		_modal_items.add_child(row)

func _on_wholesale_buy(goods_id: String, quantity: int) -> void:
	BusinessManager.buy_goods(goods_id, quantity)

func _on_wholesale_sell(goods_id: String, quantity: int) -> void:
	BusinessManager.sell_goods(goods_id, quantity)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _add_action_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_collection_log_content() -> void:
	_clear_modal_items()
	var entries := CollectionManager.get_log_entries()
	if entries.is_empty():
		_modal_items.add_child(_make_empty_label("还没有认真翻过城市的角落。"))
		return
	for item in entries:
		var rarity := CollectionManager.get_rarity_name(str(item.get("rarity", "common")))
		var card := PanelContainer.new()
		_style_panel(card, Color(0.06, 0.11, 0.12, 0.72), _rarity_panel_color(str(item.get("rarity", "common"))), 9)
		var label := Label.new()
		label.text = "%s · %s\n%s" % [rarity, item.get("name", ""), item.get("description", "")]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color("#dbe7df"))
		card.add_child(label)
		_modal_items.add_child(card)

func _on_inventory_use(item_id: String) -> void:
	if InventoryManager.use_item(item_id):
		_build_inventory_content()

func _on_shop_buy(item_id: String) -> void:
	var item := InventoryManager.get_item(item_id)
	if item.is_empty():
		return
	var price := int(item.get("price", 0))
	if GameState.spend(price):
		InventoryManager.add_item(item_id, 1)
		show_notice("买到%s，装进包里了。" % item.get("name", item_id), "positive")

func _on_market_sell(item_id: String) -> void:
	if MarketEconomyManager.sell_now(item_id):
		_build_market_content()

func _on_market_consign(item_id: String) -> void:
	if MarketEconomyManager.consign_item(item_id):
		_build_market_content()

func _on_market_upgrade() -> void:
	if MarketEconomyManager.upgrade_stall():
		_build_market_content()

func _build_expedition_map_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label(MarketEconomyManager.get_market_brief()))
	for site_id in ConfigDB.get_rows("ruins"):
		var row := ConfigDB.get_row("ruins", site_id)
		var unlocked := MarketEconomyManager.is_site_unlocked(site_id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 58)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s%s" % [row.get("name", site_id), "" if unlocked else " · 还没有门路"]
		button.tooltip_text = str(row.get("description", ""))
		button.disabled = not unlocked
		button.pressed.connect(_on_expedition_enter.bind(site_id))
		_modal_items.add_child(button)
		_modal_items.add_child(_make_empty_label(MarketEconomyManager.get_unlock_hint(site_id)))

func _on_expedition_enter(site_id: String) -> void:
	_close_modal()
	ExpeditionManager.start_run(site_id)

func _apply_expedition_state() -> void:
	if not is_instance_valid(_fog_overlay):
		return
	var world = get_tree().get_first_node_in_group("world")
	var active = ExpeditionManager.active and GameState.current_area == "ruins" and is_instance_valid(world) and is_instance_valid(world.player)
	_fog_overlay.visible = active
	if not active:
		return
	var light_center: Vector2 = world.player.global_position * world._area_root.scale + world._area_root.position
	var material := _fog_overlay.material as ShaderMaterial
	material.set_shader_parameter("light_center", light_center)
	material.set_shader_parameter("light_radius", ExpeditionManager.get_light_radius())
	material.set_shader_parameter("darkness", ExpeditionManager.get_fog_strength())

func _build_map_content() -> void:
	_clear_modal_items()
	var area_text := "出租屋 · 城中村街道 · 工业区工厂 · 街角便利店\n废品回收站 · 旧货市场 · 社区公园"
	_modal_items.add_child(_make_empty_label(area_text))
	_modal_items.add_child(_make_empty_label("今天的天气：%s\n%s" % [WeatherSystem.get_weather_name(), WeatherSystem.get_description()]))

func _build_bank_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("现金 ¥%d · 银行存款 ¥%d · 累计利息 ¥%d" % [GameState.money, FinanceManager.savings, FinanceManager.total_interest]))
	_modal_items.add_child(_make_empty_label(FinanceManager.get_daily_rate_text()))
	var bank_row := HBoxContainer.new()
	bank_row.add_theme_constant_override("separation", 8)
	_add_action_button(bank_row, "存 100", FinanceManager.deposit.bind(100))
	_add_action_button(bank_row, "存 500", FinanceManager.deposit.bind(500))
	_add_action_button(bank_row, "全部存", func() -> void: FinanceManager.deposit(GameState.money))
	_modal_items.add_child(bank_row)
	var withdraw_row := HBoxContainer.new()
	withdraw_row.add_theme_constant_override("separation", 8)
	_add_action_button(withdraw_row, "取 100", FinanceManager.withdraw.bind(100))
	_add_action_button(withdraw_row, "全部取", func() -> void: FinanceManager.withdraw(FinanceManager.savings))
	_modal_items.add_child(withdraw_row)
	_modal_items.add_child(_make_empty_label("一期彩票 ¥10。%s" % FinanceManager.get_lottery_summary()))
	var lottery_row := HBoxContainer.new()
	lottery_row.add_theme_constant_override("separation", 8)
	_add_action_button(lottery_row, "买 1 张", func() -> void: FinanceManager.buy_lottery(1))
	_add_action_button(lottery_row, "买 10 张", func() -> void: FinanceManager.buy_lottery(10))
	_modal_items.add_child(lottery_row)
	_modal_items.add_child(_make_empty_label("房租与月账：%s · 本月进账 ¥%d · 本月支出 ¥%d" % [
		"没有欠租" if GameState.rent_arrears == 0 else "还差 ¥%d" % GameState.rent_arrears,
		ProgressionManager.month_earned,
		ProgressionManager.month_spent,
	]))

func _build_dialogue_content(line: String) -> void:
	_clear_modal_items()
	var relation := Label.new()
	relation.text = "现在的关系：%s" % RelationshipManager.get_affinity_label(_active_npc_id)
	relation.add_theme_color_override("font_color", Color("#9fc6bb"))
	_modal_items.add_child(relation)
	_modal_items.add_child(_make_empty_label(line))
	var gift_button := Button.new()
	gift_button.text = "拿一件旧物当礼物"
	gift_button.custom_minimum_size = Vector2(0, 50)
	gift_button.pressed.connect(_build_gift_content)
	_modal_items.add_child(gift_button)

func _build_gift_content() -> void:
	_clear_modal_items()
	var entries := InventoryManager.get_giftable_lines()
	if entries.is_empty():
		_modal_items.add_child(_make_empty_label("包里没有适合送人的旧物。"))
		return
	for entry in entries:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.text = "%s  ×%d" % [entry["name"], entry["count"]]
		button.pressed.connect(_on_gift_selected.bind(str(entry["id"])))
		_modal_items.add_child(button)

func _on_gift_selected(item_id: String) -> void:
	var result := RelationshipManager.give_item(_active_npc_id, item_id)
	show_notice(str(result.get("message", "")), "positive" if bool(result.get("ok", false)) else "warning")
	if bool(result.get("ok", false)):
		open_dialogue(_active_npc_id)
	else:
		_build_gift_content()

func _build_month_summary_content(summary: Dictionary) -> void:
	_clear_modal_items()
	var arrears_text := "没有拖欠" if int(summary.get("arrears", 0)) == 0 else "还差 ¥%d" % int(summary.get("arrears", 0))
	var text := "这个月赚了 ¥%d，花了 ¥%d。\n工作了 %d 天，和城里的人来往了 %d 次。\n捡到旧物 %d 件，房租：%s。" % [
		int(summary.get("earned", 0)), int(summary.get("spent", 0)),
		int(summary.get("workdays", 0)), int(summary.get("social", 0)),
		int(summary.get("collected", 0)), arrears_text,
	]
	_modal_items.add_child(_make_empty_label(text))
	var continue_button := Button.new()
	continue_button.text = "继续过日子"
	continue_button.custom_minimum_size = Vector2(0, 50)
	continue_button.pressed.connect(_close_modal)
	_modal_items.add_child(continue_button)

func _build_pause_content() -> void:
	_clear_modal_items()
	var resume := Button.new()
	resume.text = "继续生活"
	resume.custom_minimum_size = Vector2(0, 52)
	resume.pressed.connect(_close_modal)
	_modal_items.add_child(resume)
	var save_button := Button.new()
	save_button.text = "保存进度"
	save_button.custom_minimum_size = Vector2(0, 52)
	save_button.pressed.connect(func() -> void: SaveManager.save_game(true))
	_modal_items.add_child(save_button)
	var menu_button := Button.new()
	menu_button.text = "保存并回到主菜单"
	menu_button.custom_minimum_size = Vector2(0, 52)
	menu_button.pressed.connect(func() -> void:
		SaveManager.save_game(false)
		return_to_menu_requested.emit()
	)
	_modal_items.add_child(menu_button)

func _set_modal(state: ModalState, title: String, subtitle: String, pause_clock: bool = false) -> void:
	_modal_state = state
	_modal_title.text = title
	_modal_subtitle.text = subtitle
	_modal_panel.visible = true
	_context_panel.visible = false
	GameState.input_locked = true
	TimeSystem.set_paused(pause_clock)
	modal_changed.emit(true)

func _close_modal() -> void:
	var was_pause := _modal_state == ModalState.PAUSE
	var was_kitchen := _modal_state == ModalState.KITCHEN
	if _modal_state == ModalState.NONE:
		return
	_modal_state = ModalState.NONE
	_active_npc_id = ""
	_modal_panel.visible = false
	GameState.input_locked = false
	if was_pause:
		TimeSystem.set_paused(false)
	modal_changed.emit(false)
	_clear_modal_items()
func _clear_modal_items() -> void:
	for child in _modal_items.get_children():
		child.queue_free()

func _make_empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#c9d8d4"))
	return label

func _on_money_changed(amount: int) -> void:
	_money_label.text = "¥ %d" % amount

func _update_clock() -> void:
	_time_label.text = "第 %d 天 · %s · %s" % [TimeSystem.current_day, TimeSystem.get_day_name(), TimeSystem.get_time_text()]

func _on_weather_changed(_weather_id: String) -> void:
	_weather_label.text = WeatherSystem.get_weather_name()

func _apply_ambient_state() -> void:
	var sleep_dim := GameState.get_visual_dim() * 0.46
	var night_dim := (1.0 - TimeSystem.get_daylight()) * 0.22
	var weather_tint := WeatherSystem.get_tint()
	var weather_alpha := 0.08 if WeatherSystem.current_weather_id in ["rain", "humid", "overcast"] else 0.035
	_set_ambient_color(Color(
		weather_tint.r * 0.25 + 0.018,
		weather_tint.g * 0.25 + 0.045,
		weather_tint.b * 0.25 + 0.06,
		clampf(sleep_dim + night_dim + weather_alpha, 0.0, 0.62)
	))

func _set_ambient_color(color: Color) -> void:
	_ambient_overlay.color = color

func _on_pause_changed(is_paused: bool) -> void:
	if is_paused:
		_context_panel.visible = false
	elif not _context_label.text.is_empty():
		_context_panel.visible = true

func _rarity_panel_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color(1.0, 0.78, 0.28, 0.82)
		"rare":
			return Color(0.45, 0.82, 0.92, 0.7)
		"uncommon":
			return Color(0.58, 0.83, 0.49, 0.65)
		_:
			return Color(0.72, 0.72, 0.65, 0.42)

func _notice_color(tone: String) -> Color:
	match tone:
		"positive":
			return Color("#a9e4b4")
		"warning":
			return Color("#ffc076")
		"hint":
			return Color("#a9d7df")
		_:
			return Color("#f4e4bd")

func _style_panel(panel: PanelContainer, background: Color, border: Color, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)