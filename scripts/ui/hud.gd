class_name GameHUD
extends CanvasLayer

const InventorySlotButtonScript := preload("res://scripts/ui/inventory_slot_button.gd")

signal modal_changed(is_open: bool)
signal return_to_menu_requested

enum ModalState { NONE, INVENTORY, STORAGE, SHIPPING, SHOP, MARKET, COLLECTION_LOG, MAP, BANK, DIALOGUE, MONTHLY, PAUSE, EXPEDITION_MAP, KITCHEN, WHOLESALE, FARM, PETS, ROOM, STAFF, ENCYCLOPEDIA, CAREER, WARDROBE, PHOTO_ALBUM, COOP }

var _root: Control
var _ambient_overlay: ColorRect
var _status_panel: PanelContainer
var _money_label: Label
var _time_label: Label
var _weather_label: Label
var _calendar_label: Label
var _context_panel: PanelContainer
var _context_label: Label
var _pointer_panel: PanelContainer
var _pointer_label: Label
var _notice_panel: PanelContainer
var _notice_label: Label
var _notice_speaker_label: Label
var _notice_avatar_label: Label
var _notice_avatar_image: TextureRect
var _notice_source_kind := "npc"
var _modal_panel: PanelContainer
var _modal_title: Label
var _modal_subtitle: Label
var _modal_items: VBoxContainer
var _modal_close_button: Button
var _clock_accumulator := 0.0
var _npc_hint_accumulator := 0.0
var _npc_hint_index := -1
var _modal_state := ModalState.NONE
var _fog_overlay: ColorRect
var _kitchen_orders_box: VBoxContainer
var _kitchen_stations_box: VBoxContainer
var _kitchen_recipes_box: VBoxContainer
var _kitchen_status_label: Label
var _kitchen_staging_box: VBoxContainer
var _kitchen_equipment_box: VBoxContainer
var _kitchen_station_buttons: Array[Button] = []
var _kitchen_recipe_buttons: Dictionary = {}
var _kitchen_order_labels: Array[Label] = []
var _kitchen_staging_buttons: Array[Button] = []
var _kitchen_equipment_buttons: Dictionary = {}
var _kitchen_restart_button: Button
var _active_npc_id := ""
var _career_preferred_line := ""
var _encyclopedia_tab := "items"
var _coop_address_edit: LineEdit
var _coop_port_edit: LineEdit
var _coop_slots_box: VBoxContainer
var _hotbar_panel: PanelContainer
var _hotbar_box: HBoxContainer
var _hotbar_buttons: Array[Button] = []

func _ready() -> void:
	layer = 20
	_modal_state = ModalState.NONE
	add_to_group("hud")
	_build_interface()
	_ensure_clean_startup_ui()
	GameState.money_changed.connect(_on_money_changed)
	KitchenManager.changed.connect(_on_kitchen_changed)
	BusinessManager.changed.connect(_on_business_changed)
	InventoryManager.changed.connect(_on_inventory_changed)
	FinanceManager.changed.connect(_on_finance_changed)
	NoticeManager.notice_requested.connect(show_notice)
	NoticeManager.notice_cleared.connect(_on_notice_cleared)
	CoopManager.coop_state_changed.connect(_on_coop_state_changed)
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	TimeSystem.paused_changed.connect(_on_pause_changed)
	_on_money_changed(GameState.money)
	_on_weather_changed(WeatherSystem.current_weather_id)
	_update_clock()
	_refresh_hotbar()
	_apply_ambient_state()

func _ensure_clean_startup_ui() -> void:
	NoticeManager.clear_all()
	_modal_state = ModalState.NONE
	if is_instance_valid(_modal_panel):
		_modal_panel.visible = false
	if is_instance_valid(_context_panel):
		_context_panel.visible = false
	if is_instance_valid(_pointer_panel):
		_pointer_panel.visible = false
	if is_instance_valid(_notice_panel):
		_notice_panel.visible = false
	GameState.input_locked = false

func _process(delta: float) -> void:
	_clock_accumulator += delta
	if _modal_state == ModalState.NONE:
		_npc_hint_accumulator += delta
		if _npc_hint_accumulator >= 5.0:
			_npc_hint_accumulator = 0.0
			_update_npc_hint()
	else:
		_npc_hint_accumulator = 0.0
	if _clock_accumulator >= 0.2:
		_clock_accumulator = 0.0
		_update_clock()
		if _modal_state == ModalState.KITCHEN:
			_refresh_kitchen_ui()
	_apply_ambient_state()
	_apply_expedition_state()
	_update_pointer_panel()

func _is_cancel_event(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_cancel"):
		return false
	return not (event is InputEventKey and event.echo)

func _unhandled_input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	if _modal_state == ModalState.NONE and event is InputEventKey and event.pressed and not event.echo:
		var hotbar_index := _hotbar_index_for_key(event.keycode)
		if hotbar_index >= 0:
			InventoryManager.select_hotbar_slot(hotbar_index)
			get_viewport().set_input_as_handled()
			return
	if _is_cancel_event(event):
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
		NoticeManager.show_message("经营不用翻面板，走到档口旁点设备、菜单卡和托盘就行。", "hint", "厨房师傅")
	elif event.is_action_pressed("farm"):
		NoticeManager.show_message("种地要到城郊农场现场点作物、地和工具。", "hint", "农场主")
	elif event.is_action_pressed("pets"):
		_toggle_modal(ModalState.PETS, open_pets)
	elif event.is_action_pressed("room"):
		NoticeManager.show_message("房间布置在出租屋里点“布置房间”，再看空位和地面。", "hint", "梅姨")
	elif event.is_action_pressed("staff"):
		_toggle_modal(ModalState.STAFF, open_staff)
	elif event.is_action_pressed("encyclopedia"):
		_toggle_modal(ModalState.ENCYCLOPEDIA, open_encyclopedia)
	elif event.is_action_pressed("career"):
		_toggle_modal(ModalState.CAREER, open_career)
	elif event.is_action_pressed("wardrobe"):
		_toggle_modal(ModalState.WARDROBE, open_wardrobe)
	elif event.is_action_pressed("photo_album"):
		_toggle_modal(ModalState.PHOTO_ALBUM, open_photo_album)
	elif event.is_action_pressed("coop_panel"):
		_toggle_modal(ModalState.COOP, open_coop)
	elif event.is_action_pressed("chat"):
		NoticeManager.show_system_message("聊天输入会在正式联机大厅接入，当前先使用场景互动。", "hint")
	else:
		return
	get_viewport().set_input_as_handled()

func _hotbar_index_for_key(keycode: Key) -> int:
	match keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		KEY_7:
			return 6
		KEY_8:
			return 7
		KEY_9:
			return 8
		KEY_0:
			return 9
		KEY_MINUS:
			return 10
		KEY_EQUAL:
			return 11
	return -1

func _on_inventory_changed() -> void:
	_refresh_hotbar()

func _refresh_hotbar() -> void:
	if not is_instance_valid(_hotbar_box) or _hotbar_buttons.is_empty():
		return
	var lines := InventoryManager.get_hotbar_lines()
	for index in range(_hotbar_buttons.size()):
		var button := _hotbar_buttons[index]
		var line: Dictionary = lines[index] if index < lines.size() else {"item_id": "", "count": 0, "empty": true}
		button.configure("inventory", index, line)
		button.modulate = Color(1.0, 0.9, 0.62) if not bool(line.get("empty", true)) and index == InventoryManager.selected_hotbar_index else button.modulate

func _on_hotbar_slot(index: int) -> void:
	var lines := InventoryManager.get_hotbar_lines()
	if index < 0 or index >= lines.size() or bool(lines[index].get("empty", true)):
		return
	var item_id := str(lines[index].get("id", ""))
	if index == InventoryManager.selected_hotbar_index and bool(lines[index].get("usable", false)):
		InventoryManager.use_item(item_id)
	else:
		InventoryManager.select_hotbar_slot(index)
	_refresh_hotbar()

func _update_npc_hint() -> void:
	if is_queued_for_deletion() or _modal_state != ModalState.NONE:
		return
	var area_speaker := NoticeManager.get_speaker("", "hint", "")
	var hints: Array[Dictionary] = []
	for text in _get_area_hints():
		hints.append({"speaker": area_speaker, "text": text})
	var story_hint := StoryManager.get_story_hint()
	if not story_hint.is_empty():
		hints.append({"speaker": StoryManager.get_story_speaker(), "text": story_hint})
	hints.append({"speaker": area_speaker, "text": WellbeingManager.get_hint()})
	hints.append({"speaker": "社区医生", "text": MedicalManager.get_hint()})
	var achievement_hint := AchievementManager.get_natural_hint()
	if not achievement_hint.is_empty():
		hints.append(achievement_hint)
	if hints.is_empty():
		hints = [{"speaker": "老街坊", "text": "有不懂的就看身边人的提示。"}]
	_npc_hint_index = (_npc_hint_index + 1) % hints.size()
	var selected: Dictionary = hints[_npc_hint_index]
	NoticeManager.show_npc_hint(
		str(selected.get("text", "")),
		str(selected.get("speaker", "街坊")),
		4.0,
	)

func _get_area_hints() -> Array[String]:
	match GameState.current_area:
		"home":
			if PetManager.adopted.is_empty():
				return ["家里还没有宠物，先别急着买窝；收养后这里才会出现照看入口。", "冰箱、书桌、床和房间布置都能直接用。"]
			return ["宠物用品不是摆设：粮、玩具和营养膏在照看界面里各自有用。"]
		"restaurant":
			return ["经营时不用追着人跑，左键直接点排队客人、菜单卡、工位和托盘。", "半成品一定在托盘上，点托盘会自动送到匹配工位。", "升级设备只加快对应工位，不要指望油锅升级了蒸笼。" ]
		"breakfast_shop":
			return ["客人会排队，左键点排队客人接单，再按每道早餐的工序走。", "座位和点餐台都能在场景里直接点。", "错过早市就等明天，别把备料留到午市。" ]
		"farm", "suburb":
			return [FarmManager.get_weather_farm_hint(), "先点作物卡选种，再点空地；成熟后点地收割。", "工具升级花的是现金，换回来的是产量、自动浇水或成长速度。" ]
		"market", "ruins":
			return ["先点左侧旧物卡选中，再点卖出或寄卖。", "天气和行情会改变今天卖旧物的价钱。" ]
		"factory":
			return ["先应聘成为工厂员工，表现好会有人暗示晋升。", "上班消耗体力，但能推进职业线和工资。" ]
		"bank":
			return ["存取款和彩票都在柜台直接办理。", "存款有利息，但不会替你经营。" ]
		"wholesale":
			return ["货箱直接点就是进货，收购台直接点就是出货。", "雨天叶菜贵，酷暑柠檬和冰块需求高。" ]
		"clothing_store":
			return ["服装会改变外观，也会影响社交或干活手感。"]
		"high_end_district":
			return ["这里看房不只看钱，收入和稳定工作也会被物业看见。", "楼顶花园、咖啡店和画廊分别影响放松、社交和照片收藏。"]
		"logistics_port":
			return ["先看调度台线路，再决定今天是上班还是接临时装卸。", "临时装卸不需要入职，但会消耗体力和时间。"]
		"craft_workshop":
			return ["师傅会先看你会不会用工具，表现稳了才谈晋升。", "维修和木工练习都消耗体力，但能提升手艺线收益。"]
		"night_market":
			return ["夜市只在晚上开，摊主会看天气和节日备货。", "摊位上买到的原料可以补餐馆库存，帮工也能拿临时工钱。"]
		"riverside":
			return ["强叔的鱼竿升级会影响能钓到的鱼。", "河边拍照、捡拾和钓鱼都在同一个自然循环里。"]
		"bus_station":
			return ["长途车会推进一大段时间，出门前先看状态和目的地。", "纪念品和明信片会记进相册和图鉴。"]
		"clinic":
			return ["身体不舒服要早点看，诊所服务会花现金但省下后面的麻烦。", "简单处理和大项检查各有代价，不是单纯买药。"]
		"university":
			return ["夜校课程会影响职业门槛，报名后要持续上课。", "证书记录可以在课程汇总处查看。"]
		"community_center":
			return ["兴趣活动会消耗体力，但会带来职业加成和隐藏结局条件。", "琴房、画架和跑步机不是摆设，各自对应不同兴趣。"]
		"seaside_resort", "ancient_village", "mountain_spring":
			return ["这里的纪念品和照片会进入旅行记录。", "旅行会推进时间，回城前记得留够精力和现金。"]
		"pet_store":
			return ["宠物用品在这里买，收养后出租屋才会出现照看入口。", "不同宠物会影响不同经营加成。"]
		"furniture_store":
			return ["买下家具后回出租屋可以自由微调和旋转。", "家具加成会在房间界面直接说明。"]
		"store":
			return ["货架上的东西按用途买，吃完或送人都会改变状态。"]
		"commercial_district":
			return ["工作、开店、购物和住房要从不同入口进，不要都堆在一条街上。"]
		"industrial_district":
			return ["工厂、物流和手艺线各自在不同场景上班，招聘牌只负责说明。"]
		"street":
			return ["楼下早餐店有早市，夜市另一条巷子，时间不对就看不到摊。"]
	return ["看看地上和身边的物件，很多操作直接点就能做。" ]

func set_context_prompt(text: String) -> void:
	_context_label.text = "场景提示：%s" % text if not text.is_empty() else ""
	_context_panel.visible = not text.is_empty() and _modal_state == ModalState.NONE

func set_pointer_prompt(text: String) -> void:
	if not is_instance_valid(_pointer_label):
		return
	_pointer_label.text = text
	_pointer_panel.visible = not text.is_empty() and _modal_state == ModalState.NONE and not GameState.input_locked
	if _pointer_panel.visible:
		_update_pointer_panel()

func _update_pointer_panel() -> void:
	if not is_instance_valid(_pointer_panel) or not _pointer_panel.visible:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var panel_size := _pointer_panel.get_combined_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var next_position := mouse_position + Vector2(18, 18)
	if next_position.x + panel_size.x > viewport_size.x - 12.0:
		next_position.x = mouse_position.x - panel_size.x - 18.0
	if next_position.y + panel_size.y > viewport_size.y - 12.0:
		next_position.y = mouse_position.y - panel_size.y - 18.0
	_pointer_panel.position = Vector2(maxf(12.0, next_position.x), maxf(12.0, next_position.y))

func show_notice(message: String, tone: String = "normal", speaker: String = "", source_kind: String = "") -> void:
	if message.is_empty():
		return
	_notice_source_kind = source_kind if not source_kind.is_empty() else NoticeManager.infer_source_kind(message, speaker)
	var resolved_speaker := NoticeManager.get_speaker(message, tone, speaker, _notice_source_kind)
	_notice_speaker_label.text = resolved_speaker
	match _notice_source_kind:
		"system":
			_notice_avatar_label.text = "系"
			_notice_speaker_label.add_theme_color_override("font_color", PresentationManager.get_color("color.system", Color("#9fc6bb")))
		"scene":
			_notice_avatar_label.text = "景"
			_notice_speaker_label.add_theme_color_override("font_color", PresentationManager.get_color("color.scene", Color("#d8b878")))
		_:
			_notice_avatar_label.text = resolved_speaker.left(1)
			_notice_speaker_label.add_theme_color_override("font_color", PresentationManager.get_color("color.accent", Color("#f0c66f")))
	var npc_id := PresentationManager.find_npc_id_by_name(resolved_speaker)
	var notice_expression := "happy" if tone == "positive" else ("tired" if tone == "hint" else ("worried" if tone == "warning" else "neutral"))
	var portrait := PresentationManager.get_npc_portrait_texture(npc_id, notice_expression) if not npc_id.is_empty() else null
	_notice_avatar_image.texture = portrait
	_notice_avatar_image.visible = portrait != null and _notice_source_kind == "npc"
	_notice_avatar_label.visible = not _notice_avatar_image.visible
	_notice_label.text = message
	_notice_label.add_theme_color_override("font_color", _notice_color(tone))
	_place_notice_panel(_notice_source_kind)
	_notice_panel.visible = _modal_state == ModalState.NONE


func _on_notice_cleared(_notice_id: String) -> void:
	if is_instance_valid(_notice_panel):
		_notice_panel.visible = false

func _place_notice_panel(source_kind: String) -> void:
	if not is_instance_valid(_notice_panel):
		return
	if source_kind == "system":
		_notice_panel.anchor_left = 1.0
		_notice_panel.anchor_right = 1.0
		_notice_panel.anchor_top = 0.0
		_notice_panel.anchor_bottom = 0.0
		_notice_panel.offset_left = -430
		_notice_panel.offset_right = -20
		_notice_panel.offset_top = 18
		_notice_panel.offset_bottom = 136
	else:
		_notice_panel.anchor_left = 0.5
		_notice_panel.anchor_right = 0.5
		_notice_panel.anchor_top = 1.0
		_notice_panel.anchor_bottom = 1.0
		_notice_panel.offset_left = -360
		_notice_panel.offset_right = 360
		_notice_panel.offset_top = -246
		_notice_panel.offset_bottom = -126
func open_inventory(intro: String = "") -> void:
	_build_inventory_content()
	_set_modal(ModalState.INVENTORY, "随身的包", intro if not intro.is_empty() else "快捷栏和背包分开，常用东西先放在手边。")

func open_storage() -> void:
	_build_storage_content()
	_set_modal(ModalState.STORAGE, "出租屋木箱", "背包和木箱分开收纳，常用的留手边，压箱底的放这里。")

func open_shipping_bin() -> void:
	_build_shipping_content()
	_set_modal(ModalState.SHIPPING, "门口收购箱", "放进去的东西，第二天早上会有收购车统一结算。")

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

func open_bank_service(service_id: String) -> void:
	if service_id == "lottery":
		_build_lottery_content()
		_set_modal(ModalState.BANK, "街角彩票站", "小赌怡情，但系统不会让你长期稳赚。")
	else:
		open_bank()

func _build_lottery_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("现金 ¥%d · %s" % [GameState.money, FinanceManager.get_lottery_summary()]))
	_modal_items.add_child(_make_empty_label("一等奖很遥远，小额奖项偶尔能回一点。"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_add_action_button(row, "买 1 张", func() -> void: FinanceManager.buy_lottery(1))
	_add_action_button(row, "买 10 张", func() -> void: FinanceManager.buy_lottery(10))
	_modal_items.add_child(row)

func open_farm() -> void:
	_build_farm_content()
	_set_modal(ModalState.FARM, "城郊小农场", FarmManager.get_summary())

func open_pets() -> void:
	_build_pets_content()
	_set_modal(ModalState.PETS, "宠物与我的手账", PetManager.get_bonus_text())

func open_room() -> void:
	_build_room_content()
	_set_modal(ModalState.ROOM, "出租屋与家居超市", RoomManager.get_room_summary())

func open_staff() -> void:
	_build_staff_content()
	_set_modal(ModalState.STAFF, "店铺人手", StaffManager.get_summary())

func open_career(preferred_line: String = "") -> void:
	_career_preferred_line = preferred_line
	_build_career_content()
	_set_modal(ModalState.CAREER, "工作与岗位", CareerManager.get_summary())

func open_photo_album() -> void:
	_build_photo_album_content()
	_set_modal(ModalState.PHOTO_ALBUM, "生活相册", PhotoManager.get_summary())

func open_coop() -> void:
	_build_coop_content()
	_set_modal(ModalState.COOP, "好友与平台", "同城好友可以一起进店、逛巷和看节日，不开放 PVP。")

func _build_coop_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label(CoopManager.get_summary()))
	_modal_items.add_child(_make_empty_label(PlatformIntegrationManager.get_summary()))
	_modal_items.add_child(_make_empty_label("这是真实 ENet 会话。玩家位置和当前场景会同步；共同账本以房主为准，访客会自动接收房主同步。"))
	_modal_items.add_child(_make_empty_label("共同资金：¥%d · 同步版本 %d" % [GameState.money, CoopManager.economy_revision]))
	var address_row := HBoxContainer.new()
	address_row.add_theme_constant_override("separation", 8)
	var address_label := Label.new()
	address_label.text = "好友地址"
	address_label.custom_minimum_size = Vector2(110, 0)
	address_row.add_child(address_label)
	_coop_address_edit = LineEdit.new()
	_coop_address_edit.text = CoopManager.DEFAULT_ADDRESS
	_coop_address_edit.custom_minimum_size = Vector2(300, 42)
	address_row.add_child(_coop_address_edit)
	_modal_items.add_child(address_row)
	var port_row := HBoxContainer.new()
	port_row.add_theme_constant_override("separation", 8)
	var port_label := Label.new()
	port_label.text = "房间端口"
	port_label.custom_minimum_size = Vector2(110, 0)
	port_row.add_child(port_label)
	_coop_port_edit = LineEdit.new()
	_coop_port_edit.text = str(CoopManager.DEFAULT_PORT)
	_coop_port_edit.custom_minimum_size = Vector2(160, 42)
	port_row.add_child(_coop_port_edit)
	_modal_items.add_child(port_row)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	_add_action_button(action_row, "创建本地房间", _on_coop_host)
	_add_action_button(action_row, "加入好友房间", _on_coop_join)
	_add_action_button(action_row, "离开房间", _on_coop_leave)
	_modal_items.add_child(action_row)
	_coop_slots_box = VBoxContainer.new()
	_modal_items.add_child(_coop_slots_box)
	_refresh_coop_slots()

func _refresh_coop_slots() -> void:
	if not is_instance_valid(_coop_slots_box):
		return
	for child in _coop_slots_box.get_children():
		child.queue_free()
	var slots := CoopManager.get_slot_lines()
	if slots.is_empty():
		_coop_slots_box.add_child(_make_empty_label("还没有房间。创建后，把地址和端口告诉好友即可。"))
		return
	_coop_slots_box.add_child(_make_empty_label("房间成员"))
	for slot in slots:
		var role := "房主" if bool(slot.get("host", false)) else "成员"
		_coop_slots_box.add_child(_make_empty_label("%s · %s" % [str(slot.get("name", "好友")), role]))

func _on_coop_host() -> void:
	var port := int(_coop_port_edit.text) if is_instance_valid(_coop_port_edit) else CoopManager.DEFAULT_PORT
	if CoopManager.create_host(port, CoopManager.MAX_PLAYERS):
		NoticeManager.show_system_message("合作房间已创建。把地址和端口告诉好友。", "positive")
		_build_coop_content()

func _on_coop_join() -> void:
	var address := _coop_address_edit.text.strip_edges() if is_instance_valid(_coop_address_edit) else CoopManager.DEFAULT_ADDRESS
	var port := int(_coop_port_edit.text) if is_instance_valid(_coop_port_edit) else CoopManager.DEFAULT_PORT
	if address.is_empty():
		address = CoopManager.DEFAULT_ADDRESS
	if CoopManager.join_session(address, port):
		NoticeManager.show_system_message("正在加入 %s:%d。" % [address, port], "positive")
		_build_coop_content()

func _on_coop_leave() -> void:
	if not CoopManager.is_coop_active():
		NoticeManager.show_system_message("当前没有在合作房间里。", "hint")
		return
	CoopManager.leave_session()
	_build_coop_content()

func _on_coop_state_changed(_active: bool, _host: bool, _peer_count: int) -> void:
	if _modal_state == ModalState.COOP:
		_build_coop_content()

func open_wardrobe() -> void:
	_build_wardrobe_content()
	_set_modal(ModalState.WARDROBE, "衣服与穿着", WardrobeManager.get_outfit_summary())

func open_encyclopedia() -> void:
	_build_encyclopedia_content()
	_set_modal(ModalState.ENCYCLOPEDIA, "城市图鉴", "见过的物品、做过的菜、走过的场景和工作都会留在册子里，不催你凑齐。")

func open_kitchen() -> void:
	if not KitchenManager.active:
		var location := "breakfast_shop" if GameState.current_area == "breakfast_shop" else "restaurant"
		if not KitchenManager.start_shift_for(location):
			return
	_build_kitchen_content()
	var title := "楼下早餐店" if KitchenManager.location_id == "breakfast_shop" else "餐饮档口"
	_set_modal(ModalState.KITCHEN, title, "%s · 订单不等人，备料、加工、装盘要按商品自己的工序走。" % MarketPhaseManager.get_phase_name(KitchenManager.active_phase_id))

func open_wholesale() -> void:
	_build_wholesale_content()
	_set_modal(ModalState.WHOLESALE, "清晨批发市场", "便宜时进货，紧缺时出手，也会看走眼。")

func open_dialogue(npc_id: String) -> void:
	_active_npc_id = npc_id
	var line := RelationshipManager.talk_to(npc_id)
	if FestivalManager.is_festival_npc(npc_id):
		var festival_line := FestivalManager.claim_gift(npc_id)
		if not festival_line.is_empty():
			line = festival_line
		var activity_line := FestivalManager.join_today_activity()
		if not activity_line.is_empty():
			line = "%s\n%s" % [line, activity_line]
	var story_row := NpcStoryManager.try_advance(npc_id)
	if not story_row.is_empty():
		var story_line := "【%s】\n%s" % [str(story_row.get("title", "一段旧事")), str(story_row.get("line", ""))]
		var reward_text := NpcStoryManager.get_reward_text(story_row)
		if not reward_text.is_empty():
			story_line += "\n" + reward_text
		line = story_line
	var referral_line := StaffManager.receive_npc_referral(npc_id)
	if not referral_line.is_empty():
		line = "%s\n%s" % [line, referral_line]
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
	_root.theme = PresentationManager.build_ui_theme()

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
	_status_panel.position = Vector2(18, 16)
	_status_panel.size = Vector2(560, 48)
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(
		_status_panel,
		PresentationManager.get_color("color.bg.panel", Color("#F5E9D6E6")),
		PresentationManager.get_color("color.border.soft", Color("#D9C4A8")),
		12,
	)
	_root.add_child(_status_panel)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	status_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_status_panel.add_child(status_row)
	_money_label = Label.new()
	_money_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_money_label.add_theme_font_size_override("font_size", 20)
	_money_label.add_theme_color_override("font_color", PresentationManager.get_color("color.accent.warm", Color("#E8A85C")))
	status_row.add_child(_money_label)
	status_row.add_child(_make_status_separator())
	_time_label = Label.new()
	_time_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_time_label.add_theme_font_size_override("font_size", 18)
	_time_label.add_theme_color_override("font_color", PresentationManager.get_color("color.text.primary", Color("#4A3B2E")))
	status_row.add_child(_time_label)
	status_row.add_child(_make_status_separator())
	_weather_label = Label.new()
	_weather_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_weather_label.add_theme_font_size_override("font_size", 16)
	_weather_label.add_theme_color_override("font_color", PresentationManager.get_color("color.text.secondary", Color("#7A6653")))
	status_row.add_child(_weather_label)
	status_row.add_child(_make_status_separator())
	_calendar_label = Label.new()
	_calendar_label.add_theme_font_size_override("font_size", 16)
	_calendar_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_calendar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_calendar_label.add_theme_color_override("font_color", PresentationManager.get_color("color.text.muted", Color("#A89684")))
	status_row.add_child(_calendar_label)


	_context_panel = PanelContainer.new()
	_context_panel.anchor_left = 0.5
	_context_panel.anchor_right = 0.5
	_context_panel.anchor_top = 0.0
	_context_panel.anchor_bottom = 0.0
	_context_panel.offset_left = -210
	_context_panel.offset_right = 210
	_context_panel.offset_top = 76
	_context_panel.offset_bottom = 124
	_context_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(
		_context_panel,
		PresentationManager.get_color("color.bg.panel", Color("#F5E9D6E6")),
		PresentationManager.get_color("color.border.focus", Color("#E8B87A")),
		12,
	)
	_root.add_child(_context_panel)
	_context_label = Label.new()
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_context_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_context_label.max_lines_visible = 1
	_context_label.add_theme_font_size_override("font_size", 16)
	_context_label.add_theme_color_override("font_color", PresentationManager.get_color("color.text.primary", Color("#4A3B2E")))
	_context_panel.add_child(_context_label)
	_context_panel.visible = false

	_hotbar_panel = PanelContainer.new()
	_hotbar_panel.anchor_left = 0.5
	_hotbar_panel.anchor_right = 0.5
	_hotbar_panel.anchor_top = 1.0
	_hotbar_panel.anchor_bottom = 1.0
	_hotbar_panel.offset_left = -470
	_hotbar_panel.offset_right = 470
	_hotbar_panel.offset_top = -100
	_hotbar_panel.offset_bottom = -20
	_hotbar_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_style_panel(_hotbar_panel, Color(0.025, 0.055, 0.064, 0.92), Color(0.76, 0.68, 0.44, 0.48), 10)
	_root.add_child(_hotbar_panel)
	_hotbar_box = HBoxContainer.new()
	_hotbar_box.add_theme_constant_override("separation", 4)
	_hotbar_panel.add_child(_hotbar_box)
	_hotbar_buttons.clear()
	for index in range(InventoryManager.HOTBAR_SIZE):
		var hotbar_button := InventorySlotButtonScript.new()
		hotbar_button.custom_minimum_size = Vector2(72, 64)
		hotbar_button.clip_text = true
		hotbar_button.pressed.connect(_on_hotbar_slot.bind(index))
		hotbar_button.move_requested.connect(_on_container_slot_move)
		_hotbar_box.add_child(hotbar_button)
		_hotbar_buttons.append(hotbar_button)

	_pointer_panel = PanelContainer.new()
	_pointer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer_panel.custom_minimum_size = Vector2(300, 0)
	_style_panel(_pointer_panel, Color(0.025, 0.055, 0.064, 0.94), Color(0.97, 0.78, 0.35, 0.58), 10)
	_pointer_label = Label.new()
	_pointer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pointer_label.add_theme_color_override("font_color", Color("#ffe8a8"))
	_pointer_panel.add_child(_pointer_label)
	_root.add_child(_pointer_panel)
	_pointer_panel.visible = false

	_notice_panel = PanelContainer.new()
	_notice_panel.anchor_left = 1.0
	_notice_panel.anchor_right = 1.0
	_notice_panel.anchor_top = 0.0
	_notice_panel.anchor_bottom = 0.0
	_notice_panel.offset_left = -430
	_notice_panel.offset_right = -20
	_notice_panel.offset_top = 18
	_notice_panel.offset_bottom = 132
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(
		_notice_panel,
		PresentationManager.get_color("color.bg.panel", Color("#F5E9D6E6")),
		PresentationManager.get_color("color.border.focus", Color("#E8B87A")),
		16,
	)
	_root.add_child(_notice_panel)
	var notice_margin := MarginContainer.new()
	notice_margin.add_theme_constant_override("margin_left", 14)
	notice_margin.add_theme_constant_override("margin_right", 16)
	notice_margin.add_theme_constant_override("margin_top", 12)
	notice_margin.add_theme_constant_override("margin_bottom", 12)
	_notice_panel.add_child(notice_margin)
	var notice_row := HBoxContainer.new()
	notice_row.add_theme_constant_override("separation", 14)
	notice_margin.add_child(notice_row)
	var avatar_panel := PanelContainer.new()
	avatar_panel.custom_minimum_size = Vector2(64, 64)
	_style_panel(
		avatar_panel,
		PresentationManager.get_color("color.bg.panel_soft", Color("#F5E9D6B3")),
		PresentationManager.get_color("color.border.focus", Color("#E8B87A")),
		32,
	)
	notice_row.add_child(avatar_panel)
	_notice_avatar_label = Label.new()
	_notice_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_avatar_label.add_theme_font_size_override("font_size", 27)
	_notice_avatar_label.add_theme_color_override("font_color", PresentationManager.get_color("color.accent.warm", Color("#E8A85C")))
	avatar_panel.add_child(_notice_avatar_label)
	_notice_avatar_image = TextureRect.new()
	_notice_avatar_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_notice_avatar_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_notice_avatar_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_notice_avatar_image.visible = false
	avatar_panel.add_child(_notice_avatar_image)
	var notice_text := VBoxContainer.new()
	notice_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice_text.add_theme_constant_override("separation", 3)
	notice_row.add_child(notice_text)
	_notice_speaker_label = Label.new()
	_notice_speaker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_notice_speaker_label.max_lines_visible = 1
	_notice_speaker_label.add_theme_font_size_override("font_size", 17)
	_notice_speaker_label.add_theme_color_override("font_color", PresentationManager.get_color("color.accent.warm", Color("#E8A85C")))
	notice_text.add_child(_notice_speaker_label)
	_notice_label = Label.new()
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_notice_label.max_lines_visible = 3
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.add_theme_font_size_override("font_size", 19)
	notice_text.add_child(_notice_label)
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
	var modal_scroll := ScrollContainer.new()
	modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.custom_minimum_size = Vector2(0, 350)
	modal_column.add_child(modal_scroll)
	_modal_items = VBoxContainer.new()
	_modal_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_items.add_theme_constant_override("separation", 9)
	modal_scroll.add_child(_modal_items)
	_modal_close_button = Button.new()
	_modal_close_button.text = "收起（Esc）"
	_modal_close_button.custom_minimum_size = Vector2(0, 44)
	_modal_close_button.pressed.connect(_close_modal)
	modal_column.add_child(_modal_close_button)
	_modal_panel.visible = false
func _build_inventory_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label(InventoryManager.get_backpack_summary()))
	_modal_items.add_child(_make_empty_label("快捷栏 · 数字键选择，同一格再按一次使用"))
	_modal_items.add_child(_make_slot_grid("inventory", InventoryManager.get_hotbar_lines(), 0))
	_modal_items.add_child(_make_empty_label("背包 · 拖动整理；右键拆半，Shift+右键整叠转移，Ctrl+右键转移 1 件"))
	_modal_items.add_child(_make_slot_grid("inventory", InventoryManager.get_backpack_slots(), InventoryManager.HOTBAR_SIZE))
	_modal_items.add_child(_make_empty_label("初始只有快捷栏，逐步扩容到 24、36 格；单个堆叠上限 999。"))

func _build_storage_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("出租屋木箱 · %d 格 · 可整理、可整箱搬运" % InventoryManager.STORAGE_SIZE))
	_modal_items.add_child(_make_empty_label("随身背包"))
	_modal_items.add_child(_make_slot_grid("inventory", _combined_inventory_slots(), 0))
	_modal_items.add_child(_make_empty_label("木箱"))
	_modal_items.add_child(_make_slot_grid("storage", InventoryManager.get_storage_slots(), 0))
	_modal_items.add_child(_make_empty_label("拖动物品放进箱子或取回；右键拆半，Shift+右键整叠转移，Ctrl+右键转移 1 件。木箱内容不会计入随身重量。"))

func _build_shipping_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("门口收购箱 · %d 格 · 明早估计 ¥%d" % [InventoryManager.SHIPPING_SIZE, InventoryManager.get_shipping_estimate()]))
	_modal_items.add_child(_make_empty_label("随身背包"))
	_modal_items.add_child(_make_slot_grid("inventory", _combined_inventory_slots(), 0))
	_modal_items.add_child(_make_empty_label("已登记发货"))
	_modal_items.add_child(_make_slot_grid("shipping", InventoryManager.get_shipping_slots(), 0))
	_modal_items.add_child(_make_empty_label("收购箱放进的东西不能取回，次日开门统一结算。"))

func _make_shipping_rows(entries: Array[Dictionary], deposit_mode: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.custom_minimum_size = Vector2(620, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var price_text := " · 单价 ¥%d" % int(entry.get("shipping_price", 0)) if not deposit_mode else ""
		label.text = "%s ×%d%s · %s" % [str(entry.get("name", "")), int(entry.get("count", 0)), price_text, str(entry.get("description", ""))]
		row.add_child(label)
		var item_id := str(entry.get("id", ""))
		_add_action_button(row, "放入 1" if deposit_mode else "取回 1", (_on_shipping_deposit.bind(item_id) if deposit_mode else _on_shipping_withdraw.bind(item_id)))
		box.add_child(row)
	if entries.is_empty():
		box.add_child(_make_empty_label("这里暂时空着。"))
	return box

func _make_slot_grid(scope: String, slots: Array[Dictionary], base_index: int = 0) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for local_index in range(slots.size()):
		var absolute_index := base_index + local_index
		var slot: Dictionary = slots[local_index]
		var button := InventorySlotButtonScript.new()
		button.custom_minimum_size = Vector2(104, 64)
		button.clip_text = true
		button.configure(scope, absolute_index, slot)
		button.move_requested.connect(_on_container_slot_move)
		button.stack_transfer_requested.connect(_on_container_stack_transfer)
		if not bool(slot.get("empty", true)):
			button.pressed.connect(_on_container_slot_pressed.bind(scope, absolute_index))
		grid.add_child(button)
	return grid

func _combined_inventory_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append_array(InventoryManager.get_hotbar_lines())
	result.append_array(InventoryManager.get_backpack_slots())
	return result

func _make_storage_rows(entries: Array[Dictionary], deposit_mode: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.custom_minimum_size = Vector2(620, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s ×%d · %s" % [str(entry.get("name", "")), int(entry.get("count", 0)), str(entry.get("description", ""))]
		row.add_child(label)
		var item_id := str(entry.get("id", ""))
		_add_action_button(row, "存入 1" if deposit_mode else "取出 1", (_on_storage_deposit.bind(item_id) if deposit_mode else _on_storage_withdraw.bind(item_id)))
		box.add_child(row)
	if entries.is_empty():
		box.add_child(_make_empty_label("这里暂时空着。"))
	return box

func _build_shop_content() -> void:
	_clear_modal_items()
	for item_id in ["meal_rice", "bread", "water", "coffee", "energy_bar", "herbal_tea", "rice_box", "fruit_cup"]:
		var item := InventoryManager.get_item(item_id)
		var card := PanelContainer.new()
		_style_panel(card, Color(0.06, 0.11, 0.12, 0.72), Color(0.85, 0.72, 0.36, 0.28), 9)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var icon_texture := PresentationManager.get_item_icon_texture(item_id)
		if icon_texture != null:
			var icon := TextureRect.new()
			icon.texture = icon_texture
			icon.custom_minimum_size = Vector2(40, 40)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(icon)
		var info := _make_empty_label("%s · ¥%d\n%s\n用途：%s" % [item.get("name", item_id), int(item.get("price", 0)), item.get("description", ""), item.get("use_hint", "")])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_add_action_button(row, "买下", _on_shop_buy.bind(item_id))
		_modal_items.add_child(card)
	_modal_items.add_child(_make_empty_label("这些都是能吃能喝的日常补给，背包里点一下就能用。"))
	_modal_items.add_child(_make_empty_label(InventoryManager.get_backpack_summary()))
func _build_market_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("%s · 已服务 %d 位客人 · 店铺估值 ¥%d" % [BusinessManager.get_business_level_name(), BusinessManager.customers_served, BusinessManager.get_business_valuation()]))
	_modal_items.add_child(_make_empty_label(RelationshipManager.get_network_effect_text()))
	var operations := HBoxContainer.new()
	operations.add_theme_constant_override("separation", 8)
	_add_action_button(operations, "去现场经营", func() -> void: _open_kitchen_from_market())
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
	NoticeManager.show_message("开工要回到餐馆场景，直接点门口招牌、菜单卡和工位。", "hint", "厨房师傅")

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
	_kitchen_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_items.add_child(_kitchen_status_label)

	_kitchen_orders_box = VBoxContainer.new()
	_modal_items.add_child(_kitchen_orders_box)
	_kitchen_orders_box.add_child(_make_empty_label("顾客队列（场景里点顾客拿起订单）："))
	_kitchen_order_labels.clear()
	for index in range(5):
		var order_label := Label.new()
		order_label.visible = false
		order_label.add_theme_color_override("font_color", Color("#d8e7e2"))
		_kitchen_orders_box.add_child(order_label)
		_kitchen_order_labels.append(order_label)

	_kitchen_stations_box = VBoxContainer.new()
	_modal_items.add_child(_kitchen_stations_box)
	_kitchen_stations_box.add_child(_make_empty_label("工位（点工位放下手上的订单或半成品）："))
	_kitchen_station_buttons.clear()
	for index in range(8):
		var station_button := Button.new()
		station_button.custom_minimum_size = Vector2(0, 48)
		station_button.visible = false
		station_button.pressed.connect(_on_kitchen_station.bind(index))
		_kitchen_stations_box.add_child(station_button)
		_kitchen_station_buttons.append(station_button)

	_kitchen_staging_box = VBoxContainer.new()
	_modal_items.add_child(_kitchen_staging_box)
	_kitchen_staging_box.add_child(_make_empty_label("半成品托盘（点托盘拿起半成品，再点对应工位）："))
	_kitchen_staging_buttons.clear()
	for index in range(6):
		var tray_button := Button.new()
		tray_button.custom_minimum_size = Vector2(0, 42)
		tray_button.visible = false
		tray_button.pressed.connect(_on_kitchen_load_staging.bind(index))
		_kitchen_staging_box.add_child(tray_button)
		_kitchen_staging_buttons.append(tray_button)

	_kitchen_recipes_box = VBoxContainer.new()
	_modal_items.add_child(_kitchen_recipes_box)
	_kitchen_recipes_box.add_child(_make_empty_label("本时段菜单（场景菜单卡可作为快捷入口）："))
	_kitchen_recipe_buttons.clear()
	for recipe_id in BusinessManager.get_recipe_ids():
		var recipe_button := Button.new()
		var connected_recipe_id := str(recipe_id)
		recipe_button.custom_minimum_size = Vector2(0, 44)
		recipe_button.visible = false
		recipe_button.pressed.connect(_on_kitchen_place.bind(connected_recipe_id))
		_kitchen_recipes_box.add_child(recipe_button)
		_kitchen_recipe_buttons[connected_recipe_id] = recipe_button

	_kitchen_equipment_box = VBoxContainer.new()
	_modal_items.add_child(_kitchen_equipment_box)
	_kitchen_equipment_box.add_child(_make_empty_label("设备升级（只影响对应工位）："))
	_kitchen_equipment_buttons.clear()
	for equipment in KitchenManager.get_equipment_lines():
		var equipment_type := str(equipment["type"])
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 42)
		button.pressed.connect(_on_equipment_upgrade.bind(equipment_type))
		_kitchen_equipment_box.add_child(button)
		_kitchen_equipment_buttons[equipment_type] = button

	var support_row := HBoxContainer.new()
	support_row.add_theme_constant_override("separation", 8)
	_modal_items.add_child(support_row)
	_add_action_button(support_row, "招帮手 +3劳力 ¥36", func() -> void: BusinessManager.restock_labor())
	_add_action_button(support_row, "休整 +3脑力 ¥30", func() -> void: BusinessManager.restock_brain())
	_add_action_button(support_row, "提前打烊", func() -> void: KitchenManager.end_shift())
	_kitchen_restart_button = _add_action_button(support_row, "再开一次档", func() -> void: _restart_kitchen())
	_kitchen_restart_button.visible = false
	_refresh_kitchen_ui()

func _refresh_kitchen_ui() -> void:
	if not is_instance_valid(_kitchen_status_label):
		return
	if not KitchenManager.active:
		_kitchen_status_label.text = "当前已收档。%s" % MarketPhaseManager.get_status_text()
		for button in _kitchen_station_buttons:
			button.visible = false
		for button in _kitchen_staging_buttons:
			button.visible = false
		for button in _kitchen_recipe_buttons.values():
			button.visible = false
		for label in _kitchen_order_labels:
			label.visible = false
		_kitchen_restart_button.visible = MarketPhaseManager.can_start_shift("restaurant") or MarketPhaseManager.can_start_shift("breakfast_shop")
		return
	_kitchen_restart_button.visible = false
	var hand_status := KitchenManager.get_hand_status()
	var hand_text := "手上空着，点顾客拿订单，或点托盘拿半成品。"
	if not bool(hand_status.get("empty", true)):
		hand_text = "手上：%s · %s · %s" % [
			str(hand_status.get("name", "")),
			str(hand_status.get("stage_name", "")),
			str(hand_status.get("prompt", "")),
		]
	_kitchen_status_label.text = "%s · 剩余 %d 秒 · 已出餐 %d/%d · 连击 %d · 劳力 %d/%d · 脑力 %d/%d%s\n%s" % [
		MarketPhaseManager.get_phase_name(KitchenManager.active_phase_id),
		int(ceil(KitchenManager.time_left)), KitchenManager.served, KitchenManager.get_order_target(),
		KitchenManager.combo, BusinessManager.labor_stock, BusinessManager.get_labor_capacity(),
		BusinessManager.brain_stock, BusinessManager.get_brain_capacity(),
		" · %s" % KitchenManager.get_rush_status_text() if not KitchenManager.get_rush_status_text().is_empty() else "",
		hand_text,
	]
	var order_status := KitchenManager.get_orders_status()
	for index in range(_kitchen_order_labels.size()):
		if index < order_status.size():
			var order: Dictionary = order_status[index]
			_kitchen_order_labels[index].visible = true
			var order_prefix := "手上" if bool(order.get("is_hand", false)) else str(index + 1)
			_kitchen_order_labels[index].text = "%s. %s · %s · %s" % [order_prefix, order.get("customer_name", "客人"), order["name"], KitchenManager.get_patience_text(float(order.get("patience_ratio", 0.0)))]
		else:
			_kitchen_order_labels[index].visible = false
	var station_status := KitchenManager.get_stations_status()
	for index in range(_kitchen_station_buttons.size()):
		if index < station_status.size():
			var station: Dictionary = station_status[index]
			_kitchen_station_buttons[index].visible = true
			_kitchen_station_buttons[index].text = "工位 %d · %s · %s · %s · %d%%" % [
				index + 1, station["station_name"], station["name"], station["action_text"],
				int(float(station["progress_ratio"]) * 100.0),
			]
		else:
			_kitchen_station_buttons[index].visible = false
	var staging_status := KitchenManager.get_staging_status()
	for index in range(_kitchen_staging_buttons.size()):
		if index < staging_status.size():
			var tray: Dictionary = staging_status[index]
			_kitchen_staging_buttons[index].visible = true
			_kitchen_staging_buttons[index].text = "托盘 %d · %s · %s → %s" % [
				index + 1, tray["name"], tray["stage_name"], tray["station_name"],
			]
		else:
			_kitchen_staging_buttons[index].visible = false
	var unlocked := BusinessManager.get_unlocked_recipe_ids()
	for recipe in KitchenManager.get_recipes_status():
		var recipe_id := str(recipe["id"])
		var button: Button = _kitchen_recipe_buttons.get(recipe_id)
		if button == null:
			continue
		button.visible = recipe_id in unlocked
		button.text = "%s ¥%d · %s · %s" % [recipe["name"], int(recipe["sale_price"]), recipe["pipeline_text"], recipe["goods_recipe"]]
		var in_phase := bool(recipe.get("in_phase", false))
		var station_index := _first_idle_station_of_type(KitchenManager.get_first_station_type(recipe_id))
		button.disabled = not in_phase or not bool(recipe["available"]) or station_index < 0
	for equipment in KitchenManager.get_equipment_lines():
		var equipment_type := str(equipment["type"])
		var button: Button = _kitchen_equipment_buttons.get(equipment_type)
		if button == null:
			continue
		button.text = "%s Lv.%d ×%.2f · 升级 ¥%d" % [
			equipment["name"], int(equipment["level"]), float(equipment["speed"]), int(equipment["upgrade_cost"]),
		]
		button.disabled = int(equipment["level"]) >= int(equipment["max_level"]) or GameState.money < int(equipment["upgrade_cost"])

func _restart_kitchen() -> void:
	var location := "breakfast_shop" if KitchenManager.location_id == "breakfast_shop" else "restaurant"
	if KitchenManager.start_shift_for(location):
		_build_kitchen_content()

func _on_kitchen_place(recipe_id: String) -> void:
	var station_index := _first_idle_station_of_type(KitchenManager.get_first_station_type(recipe_id))
	if station_index >= 0:
		KitchenManager.place_recipe(recipe_id, station_index)

func _on_kitchen_station(station_index: int) -> void:
	KitchenManager.handle_station_action(station_index)

func _on_kitchen_load_staging(staging_index: int) -> void:
	KitchenManager.load_staging(staging_index, -1)

func _on_equipment_upgrade(equipment_type: String) -> void:
	if KitchenManager.upgrade_station(equipment_type):
		_refresh_kitchen_ui()

func _first_idle_station_of_type(station_type: String) -> int:
	for station in KitchenManager.get_stations_status():
		if str(station.get("type", "")) == station_type and str(station.get("state", "")) == "idle":
			return int(station["index"])
	return -1

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

func _build_farm_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("现金 ¥%d · %s" % [GameState.money, FarmManager.get_summary()]))
	if not FarmManager.has_farm:
		_add_action_button(_modal_items, "租下城郊农场（¥1200）", _on_farm_unlock)
		return
	for animal in FarmManager.get_animal_lines():
		var state_text := "未修建"
		if bool(animal.get("owned", false)):
			state_text = "可收%s" % str(animal.get("product_name", "")) if bool(animal.get("ready", false)) else ("已喂过" if bool(animal.get("fed", false)) else "等喂饲料")
		_modal_items.add_child(_make_empty_label("%s · %s · 在农场场景点击动物棚" % [str(animal.get("name", "")), state_text]))
	for plot in FarmManager.get_all_plots():
		var idx := int(plot.get("index", 0))
		var stage := str(plot.get("stage", "empty"))
		_modal_items.add_child(_make_empty_label("%d号地 · %s · %s %d%%" % [idx + 1, FarmManager.get_stage_name(stage), plot.get("crop_name", "空地"), int(float(plot.get("progress", 0.0)) * 100.0)]))
		if stage == "empty":
			var crops := FarmManager.get_available_crops()
			if crops.is_empty():
				_modal_items.add_child(_make_empty_label("这个季节没有合适种子"))
			else:
				var crop_row := HBoxContainer.new()
				_modal_items.add_child(crop_row)
				for crop_id in crops.slice(0, 4):
					var cid := str(crop_id)
					var cname := str(FarmManager.get_crop_row(cid).get("name", cid))
					_add_action_button(crop_row, "种%s" % cname, _on_farm_plant.bind(idx, cid))
		elif stage == "growing":
			var grow_row := HBoxContainer.new()
			_modal_items.add_child(grow_row)
			_add_action_button(grow_row, "浇水（生长+25%）", _on_farm_water.bind(idx))
		elif stage == "ripe":
			var ripe_row := HBoxContainer.new()
			_modal_items.add_child(ripe_row)
			_add_action_button(ripe_row, "收割直接入库", _on_farm_harvest.bind(idx))

func _build_pets_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("宠物加成：%s" % PetManager.get_bonus_text()))
	var pets := PetManager.get_pet_lines()
	if pets.is_empty():
		_modal_items.add_child(_make_empty_label("家里还没有宠物，可以去宠物商店接一只回家。"))
	for pet in pets:
		var pid := str(pet.get("id", ""))
		_modal_items.add_child(_make_empty_label("%s · %s · 陪伴 %d 天" % [pet.get("name", ""), PetManager.get_stage_name(str(pet.get("stage", "baby"))), int(pet.get("days_together", 0))]))
		_modal_items.add_child(_make_empty_label("饱腹 %d · 精力 %d · 心情 %d · 清洁 %d · 训练 %d" % [int(pet.get("fullness", 0.0)), int(pet.get("energy", 0.0)), int(pet.get("mood", 0.0)), int(pet.get("clean", 0.0)), int(pet.get("training", 0.0))]))
		var actions := GridContainer.new()
		actions.columns = 4
		actions.add_theme_constant_override("h_separation", 6)
		actions.add_theme_constant_override("v_separation", 6)
		_modal_items.add_child(actions)
		_add_action_button(actions, "喂食", _on_pet_feed.bind(pid))
		_add_action_button(actions, "陪玩", _on_pet_play.bind(pid))
		_add_action_button(actions, "睡觉", _on_pet_rest.bind(pid))
		_add_action_button(actions, "洗澡", _on_pet_bathe.bind(pid))
		_add_action_button(actions, "用药", _on_pet_help.bind(pid))
		_add_action_button(actions, "训练", _on_pet_train.bind(pid))
		_add_action_button(actions, "表演", _on_pet_show.bind(pid))

func _build_room_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label(RoomManager.get_room_summary()))
	_modal_items.add_child(_make_empty_label("家具加成：%s · 现金 ¥%d" % [RoomManager.get_bonus_text(), GameState.money]))
	_modal_items.add_child(_make_empty_label("装修：%s" % RoomManager.get_renovation_summary()))
	var renovation_row := GridContainer.new()
	renovation_row.columns = 2
	renovation_row.add_theme_constant_override("h_separation", 6)
	renovation_row.add_theme_constant_override("v_separation", 6)
	_modal_items.add_child(renovation_row)
	for renovation in RoomManager.get_renovation_lines():
		var renovation_id := str(renovation["id"])
		var renovation_text := "%s ¥%d" % [str(renovation["name"]), int(renovation["cost"])]
		if bool(renovation["active"]):
			renovation_text = "当前 · %s" % str(renovation["name"])
		_add_action_button(renovation_row, renovation_text, _on_room_renovate.bind(renovation_id))
	var layout_row := GridContainer.new()
	layout_row.columns = 3
	layout_row.add_theme_constant_override("h_separation", 6)
	layout_row.add_theme_constant_override("v_separation", 6)
	_modal_items.add_child(layout_row)
	_add_action_button(layout_row, "保存为日常", _on_room_layout_save.bind("日常"))
	_add_action_button(layout_row, "保存为会客", _on_room_layout_save.bind("会客"))
	_add_action_button(layout_row, "保存为宠物角", _on_room_layout_save.bind("宠物角"))
	for layout_name in RoomManager.get_layout_names():
		_add_action_button(layout_row, "换%s" % layout_name, _on_room_layout_load.bind(str(layout_name)))
	_modal_items.add_child(_make_empty_label("手动摆放：点家具下方方向键微调，旋转键每次转 15°。场景里的位置会同步变化。"))
	for placement in RoomManager.get_placement_lines():
		var fid := str(placement["id"])
		var rotation_value := int(placement.get("rotation", 0))
		var placement_state := "未摆放" if str(placement.get("slot", "")).is_empty() else "已摆放 · 朝向 %d°" % rotation_value
		var furniture_card := VBoxContainer.new()
		furniture_card.add_theme_constant_override("separation", 5)
		furniture_card.add_child(_make_empty_label("%s · %s" % [placement["name"], placement_state]))
		var slot_row := GridContainer.new()
		slot_row.columns = 4
		slot_row.add_theme_constant_override("h_separation", 6)
		slot_row.add_theme_constant_override("v_separation", 6)
		furniture_card.add_child(slot_row)
		for slot_id in ["bed", "light", "rug", "rug_alt", "shelf", "plant", "table", "appliance", "aquarium", "pet", "desk"]:
			_add_action_button(slot_row, RoomManager.get_slot_name(slot_id), _on_room_place.bind(fid, slot_id))
		var move_row := GridContainer.new()
		move_row.columns = 5
		move_row.add_theme_constant_override("h_separation", 6)
		move_row.add_theme_constant_override("v_separation", 6)
		furniture_card.add_child(move_row)
		_add_action_button(move_row, "左移", _on_room_nudge.bind(fid, Vector2(-0.02, 0.0)))
		_add_action_button(move_row, "右移", _on_room_nudge.bind(fid, Vector2(0.02, 0.0)))
		_add_action_button(move_row, "上移", _on_room_nudge.bind(fid, Vector2(0.0, -0.02)))
		_add_action_button(move_row, "下移", _on_room_nudge.bind(fid, Vector2(0.0, 0.02)))
		_add_action_button(move_row, "旋转", _on_room_rotate.bind(fid, 15))
		if not str(placement.get("slot", "")).is_empty():
			_add_action_button(move_row, "取下", _on_room_unplace.bind(fid))
		_modal_items.add_child(furniture_card)
	_modal_items.add_child(_make_empty_label("家居超市："))
	for fid in ConfigDB.get_rows("furniture"):
		var row := ConfigDB.get_row("furniture", fid)
		if RoomManager.has_owned(str(fid)):
			continue
		_add_action_button(_modal_items, "%s ¥%d · %s" % [row.get("name", fid), int(row.get("price", "0")), row.get("description", "")], _on_furniture_buy.bind(str(fid)))

func _build_staff_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("驻店员工每天结算工钱。欠薪、低薪、长期加班和春节返乡潮都会让人离开。"))
	_modal_items.add_child(_make_empty_label("当前：%s" % StaffManager.get_summary()))
	for employee in StaffManager.get_employee_lines():
		var employee_id := str(employee["id"])
		var card := PanelContainer.new()
		_style_panel(card, Color(0.06, 0.11, 0.12, 0.72), Color(0.53, 0.78, 0.66, 0.34), 9)
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 12)
		card.add_child(row_box)
		var portrait_id := str(employee.get("portrait_id", employee.get("base_id", employee_id)))
		var portrait := PresentationManager.get_npc_portrait_texture(portrait_id, "neutral")
		if portrait != null:
			var portrait_rect := TextureRect.new()
			portrait_rect.texture = portrait
			portrait_rect.custom_minimum_size = Vector2(76, 76)
			portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row_box.add_child(portrait_rect)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_child(content)
		var wage_note := "工钱还算合适" if int(employee["wage"]) >= int(employee["expected_wage"]) else "对现在的工钱有些想法"
		content.add_child(_make_empty_label("%s · %s · 日薪 ¥%d · %s" % [
			employee.get("name", employee["role"]), employee["role"], int(employee["wage"]), wage_note,
		]))
		var biography := str(employee.get("biography", ""))
		if not biography.is_empty():
			content.add_child(_make_empty_label(biography))
		var ability_hint := str(employee.get("ability_hint", ""))
		if not ability_hint.is_empty():
			content.add_child(_make_empty_label("能力暗示：" + ability_hint))
		content.add_child(_make_empty_label("%s · 诉求：%s · %s" % [
			StaffManager.get_condition_text(StaffManager.hired.get(employee_id, {})), employee["trait_text"],
			"住在附近" if bool(employee["housing"]) else "自己找住处",
		]))
		content.add_child(_make_empty_label("%s · 来源：%s" % [
			StaffManager.get_skill_text(StaffManager.hired.get(employee_id, {})), employee["source"],
		]))
		var actions := GridContainer.new()
		actions.columns = 3
		actions.add_theme_constant_override("h_separation", 6)
		actions.add_theme_constant_override("v_separation", 6)
		content.add_child(actions)
		_add_action_button(actions, "加薪", _on_staff_wage.bind(employee_id))
		_add_action_button(actions, "年终奖", _on_staff_bonus.bind(employee_id))
		_add_action_button(actions, "包住", _on_staff_housing.bind(employee_id))
		_add_action_button(actions, "调休", _on_staff_day_off.bind(employee_id))
		_add_action_button(actions, "教手艺", _on_staff_teach.bind(employee_id))
		_add_action_button(actions, "垫路费", _on_staff_travel_fund.bind(employee_id))
		_add_action_button(actions, "离开", _on_staff_dismiss.bind(employee_id))
		_modal_items.add_child(card)

	_modal_items.add_child(_make_empty_label("招人不靠表格：去工业区劳务市场见工人，或者和熟人聊天等他们主动介绍。"))
	var lead_hint := StaffManager.get_pending_candidate_summary()
	if not lead_hint.is_empty():
		_modal_items.add_child(_make_empty_label("有人提过：%s" % lead_hint))
	_add_action_button(_modal_items, "去劳务市场看看", _on_staff_go_labor)

func _build_encyclopedia_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label("城市图鉴 · 翻到哪一页算哪一页，不催你凑齐。"))
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	for tab in [
		{"id": "items", "name": "物品"},
		{"id": "food", "name": "美食"},
		{"id": "scenes", "name": "场景"},
		{"id": "careers", "name": "职业"},
		{"id": "souvenirs", "name": "纪念品"},
		{"id": "collectibles", "name": "旧物"},
	]:
		var tab_button := Button.new()
		tab_button.text = str(tab["name"])
		tab_button.custom_minimum_size = Vector2(88, 38)
		tab_button.disabled = str(tab["id"]) == _encyclopedia_tab
		tab_button.pressed.connect(_on_encyclopedia_tab.bind(str(tab["id"])))
		tab_row.add_child(tab_button)
	_modal_items.add_child(tab_row)
	match _encyclopedia_tab:
		"food":
			_build_encyclopedia_food()
		"scenes":
			_build_encyclopedia_scenes()
		"careers":
			_build_encyclopedia_careers()
		"souvenirs":
			_build_encyclopedia_collectibles(true)
		"collectibles":
			_build_encyclopedia_collectibles(false)
		_:
			_build_encyclopedia_items()
	_modal_items.add_child(_make_empty_label("隐藏见闻：%s" % AchievementManager.get_summary()))
	for hint in AchievementManager.get_hint_lines().slice(0, mini(2, AchievementManager.get_hint_lines().size())):
		_modal_items.add_child(_make_empty_label("线索 · %s" % hint))

func _on_encyclopedia_tab(tab_id: String) -> void:
	_encyclopedia_tab = tab_id
	_build_encyclopedia_content()

func _add_encyclopedia_card(title: String, body: String, accent: Color) -> void:
	var card := PanelContainer.new()
	_style_panel(card, Color(0.05, 0.10, 0.11, 0.74), accent, 9)
	var label := Label.new()
	label.text = "%s
%s" % [title, body]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#dbe7df"))
	card.add_child(label)
	_modal_items.add_child(card)

func _build_encyclopedia_items() -> void:
	var ids: Array = ConfigDB.get_rows("items").keys()
	ids.sort()
	var seen_count := 0
	for item_id in ids:
		if CollectionManager.has_seen_item(str(item_id)):
			seen_count += 1
	_modal_items.add_child(_make_empty_label("物品：见过 %d / %d" % [seen_count, ids.size()]))
	for item_id in ids:
		var row := ConfigDB.get_row("items", str(item_id))
		var seen := CollectionManager.has_seen_item(str(item_id))
		var body := "还没在生活里遇到，名字先留在册子上。"
		if seen:
			body = "%s
用途：%s" % [str(row.get("description", "")), str(row.get("use_hint", ""))]
		_add_encyclopedia_card("%s · %s" % ["已见" if seen else "未见", str(row.get("name", item_id))], body, Color(0.76, 0.66, 0.42, 0.36))

func _build_encyclopedia_food() -> void:
	var ids: Array = ConfigDB.get_rows("recipes").keys()
	ids.sort()
	var seen_count := 0
	for recipe_id in ids:
		if CollectionManager.has_seen_recipe(str(recipe_id)):
			seen_count += 1
	_modal_items.add_child(_make_empty_label("美食与商品：亲手做过 %d / %d" % [seen_count, ids.size()]))
	for recipe_id in ids:
		var row := ConfigDB.get_row("recipes", str(recipe_id))
		var seen := CollectionManager.has_seen_recipe(str(recipe_id))
		var body := "还没亲手做过这道菜。"
		if seen:
			body = "类别：%s · 参考售价 ¥%d
工序：%s" % [
				str(row.get("category", "日常")),
				int(row.get("sale_price", "0")),
				KitchenManager.get_pipeline_text(str(recipe_id)),
			]
		_add_encyclopedia_card("%s · %s" % ["做过" if seen else "未做", str(row.get("name", recipe_id))], body, Color(0.85, 0.45, 0.36, 0.42))

func _build_encyclopedia_scenes() -> void:
	var ids: Array = ConfigDB.get_rows("scene_metadata").keys()
	ids.sort()
	var seen_count := 0
	for area_id in ids:
		if CollectionManager.has_seen_area(str(area_id)):
			seen_count += 1
	_modal_items.add_child(_make_empty_label("场景：到过 %d / %d" % [seen_count, ids.size()]))
	for area_id in ids:
		var row := ConfigDB.get_row("scene_metadata", str(area_id))
		var seen := CollectionManager.has_seen_area(str(area_id))
		var body := "还没走到这里，只记在地图边缘。"
		if seen:
			body = "已经到过这里。场景主要回应由%s承担。" % ("人物" if str(row.get("default_message_source", "scene")) == "npc" else "环境与物件")
		_add_encyclopedia_card("%s · %s" % ["去过" if seen else "未去", str(row.get("display_name", area_id))], body, Color(0.46, 0.66, 0.73, 0.42))

func _build_encyclopedia_careers() -> void:
	var lines := CareerManager.get_available_lines()
	var seen_count := 0
	for line in lines:
		if CollectionManager.has_seen_career(str(line.get("id", ""))):
			seen_count += 1
	_modal_items.add_child(_make_empty_label("职业：接触过 %d / %d 条路线" % [seen_count, lines.size()]))
	for line in lines:
		var line_id := str(line.get("id", ""))
		var seen := CollectionManager.has_seen_career(line_id)
		var rank_titles: Array[String] = []
		for rank_row in CareerManager.get_all_ranks(line_id):
			rank_titles.append("%d.%s" % [int(rank_row.get("rank", 0)), str(rank_row.get("title", ""))])
		var body := "还没在这条线登记。" if not seen else "岗位阶梯：%s" % " → ".join(rank_titles)
		if CareerManager.current_line == line_id:
			body += "
现在是：%s" % CareerManager.get_current_title()
		_add_encyclopedia_card("%s · %s" % ["已接触" if seen else "未接触", str(line.get("name", line_id))], body, Color(0.62, 0.55, 0.82, 0.42))

func _build_encyclopedia_collectibles(souvenirs_only: bool) -> void:
	var ids: Array = ConfigDB.get_rows("collectibles").keys()
	ids.sort()
	var total := 0
	var seen_count := 0
	for item_id in ids:
		var row := ConfigDB.get_row("collectibles", str(item_id))
		var is_souvenir := not str(row.get("availability_day", "")).is_empty()
		if is_souvenir != souvenirs_only:
			continue
		total += 1
		if CollectionManager.discovered.has(str(item_id)):
			seen_count += 1
	var section_name := "节日纪念品" if souvenirs_only else "城中旧物"
	_modal_items.add_child(_make_empty_label("%s：收集 %d / %d" % [section_name, seen_count, total]))
	for item_id in ids:
		var row := ConfigDB.get_row("collectibles", str(item_id))
		var is_souvenir := not str(row.get("availability_day", "")).is_empty()
		if is_souvenir != souvenirs_only:
			continue
		var seen := CollectionManager.discovered.has(str(item_id))
		var rarity := CollectionManager.get_rarity_name(str(row.get("rarity", "common")))
		var body := "还没摸到，只有一页空档。"
		if seen:
			body = "%s
%s" % [str(row.get("description", "")), "可卖、可送、可陈列。" if bool(row.get("displayable", "false")) else "可卖、可送。"]
		_add_encyclopedia_card("%s · %s · %s" % [rarity, str(row.get("name", item_id)), "已收" if seen else "未收"], body, _rarity_panel_color(str(row.get("rarity", "common"))))

func _on_farm_unlock() -> void:
	if GameState.spend(1200, "在城郊租下了一小块农场。"):
		FarmManager.unlock_farm()
		_build_farm_content()

func _on_farm_plant(plot_index: int, crop_id: String) -> void:
	if FarmManager.plant(plot_index, crop_id):
		_build_farm_content()

func _on_farm_water(plot_index: int) -> void:
	if FarmManager.water(plot_index):
		_build_farm_content()

func _on_farm_harvest(plot_index: int) -> void:
	if FarmManager.harvest(plot_index):
		_build_farm_content()

func _on_pet_feed(pid: String) -> void:
	if PetManager.feed(pid):
		_build_pets_content()

func _on_pet_play(pid: String) -> void:
	if PetManager.play(pid):
		_build_pets_content()

func _on_pet_rest(pid: String) -> void:
	if PetManager.rest(pid):
		_build_pets_content()

func _on_pet_bathe(pid: String) -> void:
	if PetManager.bathe(pid):
		_build_pets_content()

func _on_pet_help(pid: String) -> void:
	if PetManager.help(pid):
		_build_pets_content()

func _on_pet_train(pid: String) -> void:
	if PetManager.train(pid):
		_build_pets_content()

func _on_pet_show(pid: String) -> void:
	if PetManager.show_pet(pid):
		_build_pets_content()

func _on_room_renovate(renovation_id: String) -> void:
	if RoomManager.renovate(renovation_id):
		_build_room_content()

func _on_room_place(fid: String, slot_id: String) -> void:
	if RoomManager.place_at(fid, slot_id):
		_build_room_content()

func _on_room_layout_save(name: String) -> void:
	if RoomManager.save_layout(name):
		_build_room_content()

func _on_room_layout_load(name: String) -> void:
	if RoomManager.load_layout(name):
		_build_room_content()

func _on_room_nudge(fid: String, delta: Vector2) -> void:
	if RoomManager.nudge_furniture(fid, delta):
		_build_room_content()

func _on_room_rotate(fid: String, degrees: int) -> void:
	if RoomManager.rotate_furniture(fid, degrees):
		_build_room_content()

func _on_room_unplace(fid: String) -> void:
	if RoomManager.unplace(fid):
		_build_room_content()

func _on_furniture_buy(fid: String) -> void:
	if RoomManager.buy(fid):
		_build_room_content()

func _on_staff_hire(nid: String) -> void:
	if StaffManager.hire(nid):
		_build_staff_content()

func _on_staff_dismiss(nid: String) -> void:
	if StaffManager.dismiss(nid):
		_build_staff_content()

func _on_staff_go_labor() -> void:
	_close_modal()
	NoticeManager.show_npc_message("劳务市场在工业区，到了直接和等活的人谈。", "劳务市场阿叔", "hint")

func _on_staff_refresh(channel_id: String) -> void:
	StaffManager.refresh_candidates(channel_id)
	_build_staff_content()

func _on_staff_hire_candidate(candidate_id: String) -> void:
	if StaffManager.hire_candidate(candidate_id):
		_build_staff_content()

func _on_staff_wage(employee_id: String) -> void:
	if StaffManager.adjust_wage(employee_id):
		_build_staff_content()

func _on_staff_bonus(employee_id: String) -> void:
	if StaffManager.give_year_bonus(employee_id):
		_build_staff_content()

func _on_staff_housing(employee_id: String) -> void:
	if StaffManager.provide_housing(employee_id):
		_build_staff_content()

func _on_staff_day_off(employee_id: String) -> void:
	if StaffManager.give_day_off(employee_id):
		_build_staff_content()

func _on_staff_teach(employee_id: String) -> void:
	if StaffManager.teach_skill(employee_id):
		_build_staff_content()

func _on_staff_travel_fund(employee_id: String) -> void:
	if StaffManager.advance_travel_fund(employee_id):
		_build_staff_content()

func _build_career_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label(CareerManager.get_summary()))
	if not CareerManager.is_employed():
		_modal_items.add_child(_make_empty_label("现在没有正式工作。招聘改成现场流程：到招聘板登记，再去工位试工，最后由负责人确认。"))
		_modal_items.add_child(_make_empty_label(CareerManager.get_application_summary()))
		for line in CareerManager.get_available_lines():
			var line_id := str(line["id"])
			if not _career_preferred_line.is_empty() and line_id != _career_preferred_line:
				continue
			var card := PanelContainer.new()
			_style_panel(card, Color(0.06, 0.11, 0.12, 0.72), Color(0.53, 0.78, 0.66, 0.34), 9)
			var content := VBoxContainer.new()
			card.add_child(content)
			content.add_child(_make_empty_label("%s · 从%s做起" % [line["name"], line["first_title"]]))
			content.add_child(_make_empty_label(str(line["description"])))
			content.add_child(_make_empty_label("这里只显示招工信息；到对应场景找招聘板登记。"))
			_modal_items.add_child(card)
		return
	_modal_items.add_child(_make_empty_label("负责人暗示：%s" % CareerManager.get_manager_hint()))
	if CareerManager.current_line == "factory":
		_add_action_button(_modal_items, "跟班做一班", _on_career_factory_shift)
	elif CareerManager.current_line == "restaurant":
		_add_action_button(_modal_items, "去厨房实操", _on_career_kitchen_shift)
	else:
		var action_text := "去上课" if CareerManager.current_line == "study" else ("去接单" if CareerManager.current_line == "freelance" else "去做一班")
		_add_action_button(_modal_items, action_text, _on_career_generic_shift.bind(CareerManager.current_line))
	_add_action_button(_modal_items, "辞掉这份工作", _on_career_resign)

func _build_photo_album_content() -> void:
	_clear_modal_items()
	var photos := PhotoManager.get_photos()
	if photos.is_empty():
		_modal_items.add_child(_make_empty_label("还没有拍过照片。去旅游地点、河边观景台或其他场景按下拍照互动。"))
		return
	for photo in photos:
		var card := PanelContainer.new()
		_style_panel(card, Color(0.06, 0.11, 0.12, 0.72), Color(0.67, 0.79, 0.88, 0.32), 8)
		var column := VBoxContainer.new()
		card.add_child(column)
		var texture_path := str(photo.get("path", ""))
		var absolute_path := ProjectSettings.globalize_path(texture_path)
		if FileAccess.file_exists(absolute_path):
			var image := Image.load_from_file(absolute_path)
			if image != null:
				var preview := TextureRect.new()
				preview.texture = ImageTexture.create_from_image(image)
				preview.custom_minimum_size = Vector2(0, 180)
				preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				column.add_child(preview)
		column.add_child(_make_empty_label("%s · 第%d天 %s · %s" % [
			photo.get("scene_name", photo.get("area_id", "")), int(photo.get("day", 1)),
			photo.get("time", ""), photo.get("weather", ""),
		]))
		_modal_items.add_child(card)

func _build_wardrobe_content() -> void:
	_clear_modal_items()
	_modal_items.add_child(_make_empty_label(WardrobeManager.get_outfit_summary()))
	_modal_items.add_child(_make_empty_label("穿什么会影响别人怎么看你，也会影响干活时的手感。"))
	for clothing in WardrobeManager.get_clothing_lines():
		var clothing_id := str(clothing["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.custom_minimum_size = Vector2(610, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var impression := "更适合干活" if float(clothing["work_bonus"]) >= float(clothing["social_bonus"]) else "更体面"
		label.text = "%s · %s · ¥%d · %s\n%s" % [
			clothing["name"], clothing["slot_name"], int(clothing["price"]), impression, clothing["description"],
		]
		row.add_child(label)
		if bool(clothing["wearing"]):
			_add_action_button(row, "穿着中", _on_wardrobe_wear.bind(clothing_id))
		elif bool(clothing["owned"]):
			_add_action_button(row, "换上", _on_wardrobe_wear.bind(clothing_id))
		else:
			_add_action_button(row, "买下", _on_wardrobe_buy.bind(clothing_id))
		_modal_items.add_child(row)

func _on_career_apply(line_id: String) -> void:
	if CareerManager.apply_for_job(line_id):
		_career_preferred_line = ""
		_build_career_content()

func _on_career_resign() -> void:
	if CareerManager.resign():
		_build_career_content()

func _on_career_generic_shift(line_id: String) -> void:
	GameState.work_career_shift(line_id)
	_build_career_content()

func _on_career_factory_shift() -> void:
	GameState.work_factory_shift()
	_build_career_content()

func _on_career_kitchen_shift() -> void:
	_close_modal()
	SceneRouter.travel_to("restaurant", "entrance")
	NoticeManager.show_message("餐馆到了，点门口招牌开档，再按菜单卡和工位操作。", "hint", "厨房师傅")

func _on_wardrobe_buy(clothing_id: String) -> void:
	if WardrobeManager.buy(clothing_id):
		_build_wardrobe_content()

func _on_wardrobe_wear(clothing_id: String) -> void:
	if WardrobeManager.wear(clothing_id):
		_build_wardrobe_content()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _add_action_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	_style_button(button)
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

func _on_family_confess(npc_id: String) -> void:
	if FamilyManager.confess(npc_id):
		_build_dialogue_content("")

func _on_family_marry(npc_id: String) -> void:
	if FamilyManager.marry(npc_id):
		_build_dialogue_content("")

func _on_family_start() -> void:
	if FamilyManager.start_family():
		_build_dialogue_content("")

func _on_family_divorce() -> void:
	if FamilyManager.divorce():
		_build_dialogue_content("")

func _on_inventory_use(item_id: String) -> void:
	if InventoryManager.use_item(item_id):
		_build_inventory_content()

func _on_inventory_slot(item_id: String) -> void:
	var item := InventoryManager.get_item(item_id)
	if item.is_empty():
		return
	show_notice("%s：%s" % [str(item.get("name", item_id)), str(item.get("use_hint", item.get("description", "")))], "hint")

func _on_container_slot_pressed(scope: String, index: int) -> void:
	var slot := InventoryManager.get_slot(scope, index)
	var item_id := str(slot.get("item_id", ""))
	if item_id.is_empty():
		return
	if scope == "inventory" and _modal_state == ModalState.INVENTORY and InventoryManager.get_item(item_id).get("usable", false):
		_on_inventory_use(item_id)
		return
	var item := InventoryManager.get_item(item_id)
	var hint := str(item.get("use_hint", item.get("description", "")))
	if scope == "shipping":
		hint = "已经登记发货，明早收购车会按固定价结算。"
	show_notice("%s：%s" % [str(item.get("name", item_id)), hint], "hint")

func _on_container_slot_move(from_scope: String, from_index: int, to_scope: String, to_index: int) -> void:
	if InventoryManager.move_slot(from_scope, from_index, to_scope, to_index):
		_refresh_container_modal()

func _on_container_stack_transfer(scope: String, index: int, mode: String) -> void:
	var slot := InventoryManager.get_slot(scope, index)
	var item_id := str(slot.get("item_id", ""))
	if item_id.is_empty():
		return
	if mode == "half":
		if InventoryManager.split_stack(scope, index):
			_refresh_container_modal()
		return
	var amount := -1 if mode == "whole" else 1
	var moved := false
	match _modal_state:
		ModalState.STORAGE:
			if scope == "inventory":
				moved = InventoryManager.transfer_slot_to(scope, index, "storage", amount)
			elif scope == "storage":
				moved = InventoryManager.transfer_slot_to(scope, index, "inventory", amount)
		ModalState.SHIPPING:
			if scope == "inventory":
				moved = InventoryManager.transfer_slot_to(scope, index, "shipping", amount)
	if moved:
		_refresh_container_modal()

func _refresh_container_modal() -> void:
	match _modal_state:
		ModalState.INVENTORY:
			_build_inventory_content()
		ModalState.STORAGE:
			_build_storage_content()
		ModalState.SHIPPING:
			_build_shipping_content()

func _on_backpack_upgrade() -> void:
	if InventoryManager.upgrade_backpack():
		_build_inventory_content()

func _on_storage_deposit(item_id: String) -> void:
	if InventoryManager.deposit_to_storage(item_id, 1):
		_build_storage_content()

func _on_storage_withdraw(item_id: String) -> void:
	if InventoryManager.withdraw_from_storage(item_id, 1):
		_build_storage_content()

func _on_storage_deposit_first() -> void:
	var lines := InventoryManager.get_inventory_lines()
	if lines.is_empty():
		return
	_on_storage_deposit(str(lines[0].get("id", "")))

func _on_shipping_deposit(item_id: String) -> void:
	if InventoryManager.deposit_to_shipping(item_id, 1):
		_build_shipping_content()

func _on_shipping_withdraw(item_id: String) -> void:
	if InventoryManager.withdraw_from_shipping(item_id, 1):
		_build_shipping_content()

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
	var scene_row := PresentationManager.get_scene_metadata(GameState.current_area)
	var current_name := str(scene_row.get("display_name", GameState.current_area))
	var current_zone := _map_zone_for_area(GameState.current_area)
	var current_card := PanelContainer.new()
	_style_panel(current_card, Color(0.05, 0.12, 0.13, 0.88), Color(0.95, 0.78, 0.38, 0.64), 10)
	var current_label := Label.new()
	current_label.text = "当前位置：%s\n所属区域：%s\n找门或道路即可切换具体场景。" % [current_name, current_zone]
	current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_label.add_theme_color_override("font_color", Color("#ffe4a1"))
	current_card.add_child(current_label)
	_modal_items.add_child(current_card)
	var area_text := "城市分区：\n城中村生活区：出租屋 · 早餐店 · 旧货市场 · 回收站 · 社区公园\n商业区：餐馆 · 便利店 · 银行彩票 · 家居超市 · 服装店\n工业区：工厂 · 劳务市场 · 批发仓库 · 手艺工坊\n城郊自然区：农场 · 宠物商店 · 河边保护区 · 旧址深处\n交通：主街中部有商业、工业和城郊方向；夜间夜市在主街南侧。"
	_modal_items.add_child(_make_empty_label(area_text))
	_modal_items.add_child(_make_empty_label("今天的天气：%s\n%s" % [WeatherSystem.get_weather_name(), WeatherSystem.get_description()]))
	var festival := CalendarManager.get_festival()
	if not festival.is_empty():
		_modal_items.add_child(_make_empty_label("今天是%s。%s" % [festival.get("name", ""), festival.get("description", "")]))
	_modal_items.add_child(_make_empty_label(CalendarManager.get_next_festival_text()))

func _build_map_preview(current_name: String) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(820, 360)
	_style_panel(frame, Color(0.035, 0.075, 0.082, 0.94), Color(0.95, 0.78, 0.38, 0.56), 10)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(780, 338)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(canvas)
	var texture := PresentationManager.get_scene_texture("street")
	if texture != null:
		var map_image := TextureRect.new()
		map_image.texture = texture
		map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		map_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		map_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		map_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(map_image)
	var marker_position := _map_marker_position(GameState.current_area)
	var marker := PanelContainer.new()
	marker.anchor_left = marker_position.x
	marker.anchor_right = marker_position.x
	marker.anchor_top = marker_position.y
	marker.anchor_bottom = marker_position.y
	marker.offset_left = -72.0
	marker.offset_right = 72.0
	marker.offset_top = -18.0
	marker.offset_bottom = 18.0
	_style_panel(marker, Color(0.30, 0.08, 0.07, 0.94), Color(1.0, 0.83, 0.38, 0.92), 10)
	var marker_label := _make_empty_label("● 你在这里：%s" % current_name)
	marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker_label.add_theme_color_override("font_color", Color("#ffe7a0"))
	marker.add_child(marker_label)
	canvas.add_child(marker)
	return frame

func _map_marker_position(area_id: String) -> Vector2:
	match area_id:
		"home", "home_living":
			return Vector2(0.115, 0.91)
		"breakfast_shop", "breakfast_kitchen":
			return Vector2(0.10, 0.80)
		"market", "ruins":
			return Vector2(0.17, 0.33)
		"recycle":
			return Vector2(0.20, 0.86)
		"park", "community_center":
			return Vector2(0.34, 0.75)
		"night_market":
			return Vector2(0.555, 0.875)
		"riverside":
			return Vector2(0.42, 0.80)
		"commercial_district", "store", "bank", "restaurant", "furniture_store", "clothing_store", "high_end_district":
			return Vector2(0.68, 0.82)
		"industrial_district", "factory", "logistics_port", "craft_workshop", "wholesale":
			return Vector2(0.85, 0.30)
		"suburb", "farm", "farm_livestock", "pet_store":
			return Vector2(0.88, 0.85)
		"bus_station", "seaside_resort", "ancient_village", "mountain_spring":
			return Vector2(0.55, 0.53)
		"clinic", "university":
			return Vector2(0.68, 0.82)
	return Vector2(0.46, 0.54)

func _map_zone_for_area(area_id: String) -> String:
	if area_id in ["home", "home_living", "breakfast_shop", "breakfast_kitchen", "market", "recycle", "park", "night_market", "street"]:
		return "城中村生活区"
	if area_id in ["restaurant", "store", "bank", "furniture_store", "clothing_store", "commercial_district", "high_end_district"]:
		return "商业区"
	if area_id in ["factory", "industrial_district", "logistics_port", "craft_workshop", "wholesale"]:
		return "工业区"
	if area_id in ["farm", "farm_livestock", "suburb", "riverside", "pet_store", "ruins"]:
		return "城郊自然区"
	if area_id in ["bus_station", "seaside_resort", "ancient_village", "mountain_spring"]:
		return "交通与旅行"
	if area_id in ["clinic", "university", "community_center"]:
		return "城市公共服务区"
	return "深城其他区域"

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
	relation.text = "现在的关系：%s\n性格：%s\n能帮到你：%s\n%s" % [RelationshipManager.get_affinity_label(_active_npc_id), RelationshipManager.get_npc_personality(_active_npc_id), RelationshipManager.get_npc_purpose(_active_npc_id), RelationshipManager.get_effect_text(_active_npc_id)]
	relation.add_theme_color_override("font_color", Color("#9fc6bb"))
	_modal_items.add_child(relation)
	_modal_items.add_child(_make_empty_label(line))
	var family_row := HBoxContainer.new()
	_modal_items.add_child(family_row)
	if FamilyManager.can_confess(_active_npc_id):
		_add_action_button(family_row, "认真谈一谈", _on_family_confess.bind(_active_npc_id))
	if FamilyManager.stage_id == "partner" and FamilyManager.partner_id == _active_npc_id:
		_add_action_button(family_row, "求婚 ¥2800", _on_family_marry.bind(_active_npc_id))
	if FamilyManager.stage_id == "married" and FamilyManager.partner_id == _active_npc_id:
		_add_action_button(family_row, "迎接新家庭成员 ¥5000", _on_family_start)
	if FamilyManager.can_divorce() and FamilyManager.partner_id == _active_npc_id:
		_add_action_button(family_row, "认真谈分开", _on_family_divorce)
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
	_pointer_panel.visible = false
	_notice_panel.visible = false
	if is_instance_valid(_modal_close_button):
		_modal_close_button.grab_focus()
	GameState.input_locked = true
	TimeSystem.set_paused(pause_clock)
	modal_changed.emit(true)

func _close_modal() -> void:
	var was_pause := _modal_state == ModalState.PAUSE
	if _modal_state == ModalState.NONE:
		return
	_release_modal_focus()
	_modal_state = ModalState.NONE
	_active_npc_id = ""
	_modal_panel.visible = false
	GameState.input_locked = false
	if was_pause:
		TimeSystem.set_paused(false)
	modal_changed.emit(false)
	_clear_modal_items()
	_restore_hud_overlays()

func _release_modal_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and _modal_panel.is_ancestor_of(focus_owner):
		focus_owner.release_focus()

func _restore_hud_overlays() -> void:
	_restore_context_visibility()
	if is_instance_valid(_pointer_panel):
		_pointer_panel.visible = false
	var active_notice := NoticeManager.get_active_notice()
	if not active_notice.is_empty():
		show_notice(
			str(active_notice.get("text", "")),
			str(active_notice.get("tone", "normal")),
			str(active_notice.get("speaker", "")),
			str(active_notice.get("source_kind", "")),
		)

func _restore_context_visibility() -> void:
	if not is_instance_valid(_context_panel):
		return
	_context_panel.visible = _modal_state == ModalState.NONE and not TimeSystem.paused and not _context_label.text.is_empty()
func _clear_modal_items() -> void:
	for child in _modal_items.get_children():
		_modal_items.remove_child(child)
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
	_time_label.text = "%s · %s · %s" % [CalendarManager.get_calendar_line(), TimeSystem.get_day_name(), TimeSystem.get_time_text()]
	var festival := CalendarManager.get_festival()
	var birthday_names := RelationshipManager.get_today_birthday_names()
	var birthday_text := " · 生日：%s" % "、".join(birthday_names) if not birthday_names.is_empty() else ""
	if not festival.is_empty():
		var activity := FestivalManager.get_today_activity_title()
		var activity_text := " · %s" % activity if not activity.is_empty() else ""
		_calendar_label.text = "今天是%s · 营业加成 +%d%%%s%s" % [
			festival.get("name", ""),
			int(round(CalendarManager.get_business_bonus() * 100.0)),
			activity_text,
			birthday_text,
		]
		_calendar_label.add_theme_color_override("font_color", PresentationManager.get_color("color.state.warning", Color("#E8B87A")))
	else:
		_calendar_label.text = "%s · %s%s" % [CalendarManager.get_season_name(), CalendarManager.get_next_festival_text(), birthday_text]
		_calendar_label.add_theme_color_override("font_color", PresentationManager.get_color("color.text.muted", Color("#A89684")))

func _on_weather_changed(_weather_id: String) -> void:
	_weather_label.text = WeatherSystem.get_weather_name()

func _apply_ambient_state() -> void:
	var sleep_dim := GameState.get_visual_dim() * 0.46
	var night_dim := (1.0 - TimeSystem.get_daylight()) * 0.22
	var weather_tint := WeatherSystem.get_tint()
	var weather_alpha := 0.08 if WeatherSystem.current_weather_id in ["rain", "humid", "overcast"] else 0.035
	var season := CalendarManager.get_season_id()
	var season_tint := Color(0.0, 0.0, 0.0, 0.0)
	var season_alpha := 0.0
	match season:
		"spring":
			season_tint = Color(0.42, 0.72, 0.42, 1.0)
			season_alpha = 0.05
		"summer":
			season_tint = Color(0.95, 0.85, 0.45, 1.0)
			season_alpha = 0.07
		"autumn":
			season_tint = Color(0.85, 0.55, 0.25, 1.0)
			season_alpha = 0.06
		"winter":
			season_tint = Color(0.60, 0.72, 0.88, 1.0)
			season_alpha = 0.07
	_set_ambient_color(Color(
		weather_tint.r * 0.25 + season_tint.r * season_alpha + 0.018,
		weather_tint.g * 0.25 + season_tint.g * season_alpha + 0.045,
		weather_tint.b * 0.25 + season_tint.b * season_alpha + 0.06,
		clampf(sleep_dim + night_dim + weather_alpha, 0.0, 0.62)
	))

func _set_ambient_color(color: Color) -> void:
	_ambient_overlay.color = color

func _on_pause_changed(_is_paused: bool) -> void:
	_restore_context_visibility()

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
			return PresentationManager.get_color("color.state.success", Color("#9BBF8A"))
		"warning":
			return PresentationManager.get_color("color.state.warning", Color("#E8B87A"))
		"hint":
			return PresentationManager.get_color("color.state.info", Color("#A8B8C8"))
		_:
			return PresentationManager.get_color("color.text.primary", Color("#4A3B2E"))

func _make_status_separator() -> Control:
	var separator := VSeparator.new()
	separator.custom_minimum_size = Vector2(1, 20)
	separator.add_theme_color_override(
		"separator",
		PresentationManager.get_color("color.border.soft", Color("#D9C4A8")),
	)
	return separator

func _style_button(button: Button, role: String = "button") -> void:
	var texture := PresentationManager.get_ui_texture("button.primary.normal" if role == "button" else role)
	button.theme_type_variation = "PrimaryButton" if role == "button" else "GhostButton"
	if texture == null:
		return
	var normal := StyleBoxTexture.new()
	normal.texture = texture
	normal.texture_margin_left = 18
	normal.texture_margin_right = 18
	normal.texture_margin_top = 14
	normal.texture_margin_bottom = 14
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate(true) as StyleBoxTexture
	hover.modulate_color = Color(1.08, 1.08, 1.08, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate(true) as StyleBoxTexture
	pressed.modulate_color = Color(0.82, 0.86, 0.84, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)

func _style_panel(panel: PanelContainer, background: Color, border: Color, radius: int = 12) -> void:
	var panel_texture := PresentationManager.get_ui_texture("panel.paper")
	if panel_texture != null:
		var texture_style := StyleBoxTexture.new()
		texture_style.texture = panel_texture
		texture_style.texture_margin_left = 24
		texture_style.texture_margin_right = 24
		texture_style.texture_margin_top = 24
		texture_style.texture_margin_bottom = 24
		texture_style.content_margin_left = 18.0
		texture_style.content_margin_right = 18.0
		texture_style.content_margin_top = 12.0
		texture_style.content_margin_bottom = 12.0
		panel.add_theme_stylebox_override("panel", texture_style)
		return
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