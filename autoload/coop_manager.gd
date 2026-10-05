extends Node

signal coop_state_changed(active: bool, host: bool, peer_count: int)
signal peer_state_changed(peer_id: int, joined: bool)
signal remote_player_updated(peer_id: int, state: Dictionary)
signal remote_player_removed(peer_id: int)
signal economy_snapshot_applied(snapshot: Dictionary)

const MAX_PLAYERS := 4
const DEFAULT_PORT := 7777
const DEFAULT_ADDRESS := "127.0.0.1"

var active := false
var is_host := false
var peer_players: Dictionary = {}
var remote_states: Dictionary = {}
var session_notes: Array[String] = []
var economy_revision := 0
var _economy_dirty := false
var _economy_sync_elapsed := 0.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	GameState.money_changed.connect(_on_economy_changed)
	BusinessManager.changed.connect(_on_economy_changed)
	InventoryManager.changed.connect(_on_economy_changed)
	FinanceManager.changed.connect(_on_economy_changed)
	FarmManager.changed.connect(_on_economy_changed)
	StaffManager.changed.connect(_on_economy_changed)
	EnterpriseManager.changed.connect(_on_economy_changed)
	RoomManager.changed.connect(_on_economy_changed)
	NightMarketManager.changed.connect(_on_economy_changed)

func create_host(port: int = DEFAULT_PORT, max_players: int = MAX_PLAYERS) -> bool:
	leave_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, clampi(max_players, 2, MAX_PLAYERS))
	if err != OK:
		NoticeManager.show_system_message("创建合作房间失败，端口可能被占用。", "warning")
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	peer_players[1] = "房主"
	session_notes = ["纯合作", "最多 4 人", "不开放 PVP"]
	coop_state_changed.emit(active, is_host, get_player_count())
	return true

func join_session(address: String = DEFAULT_ADDRESS, port: int = DEFAULT_PORT) -> bool:
	leave_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		NoticeManager.show_system_message("连接好友房间失败，请检查地址和端口。", "warning")
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	coop_state_changed.emit(active, is_host, get_player_count())
	return true

func leave_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	active = false
	is_host = false
	peer_players.clear()
	remote_states.clear()
	session_notes.clear()
	economy_revision = 0
	_economy_dirty = false
	coop_state_changed.emit(active, is_host, 0)

func _process(delta: float) -> void:
	if not is_coop_active() or not is_host or not _economy_dirty:
		return
	_economy_sync_elapsed += delta
	if _economy_sync_elapsed < 0.75:
		return
	_economy_sync_elapsed = 0.0
	_economy_dirty = false
	_broadcast_economy.rpc(_build_economy_snapshot())

func is_client_view_only() -> bool:
	return is_coop_active() and not is_host

func _on_economy_changed(_value: Variant = null) -> void:
	if is_coop_active() and is_host:
		_economy_dirty = true

func request_shared_action(action_id: String, payload: Dictionary = {}) -> bool:
	if not is_client_view_only():
		return false
	_submit_shared_action.rpc(action_id, payload)
	NoticeManager.show_system_message("已交给房主结算，共同账本稍后自动同步。", "hint")
	return true

@rpc("any_peer", "call_remote", "reliable")
func _submit_shared_action(action_id: String, payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_execute_shared_action(action_id, payload)
	_economy_dirty = false
	_broadcast_economy.rpc(_build_economy_snapshot())

func _execute_shared_action(action_id: String, payload: Dictionary) -> bool:
	match action_id:
		"buy_goods":
			return BusinessManager.buy_goods(str(payload.get("goods_id", "")), int(payload.get("quantity", 1)))
		"sell_goods":
			return BusinessManager.sell_goods(str(payload.get("goods_id", "")), int(payload.get("quantity", 1)))
		"restock_labor":
			return BusinessManager.restock_labor()
		"restock_brain":
			return BusinessManager.restock_brain()
		"upgrade_business":
			return BusinessManager.upgrade_business()
		"sell_business":
			return BusinessManager.sell_business()
		"farm_plant":
			return FarmManager.plant(int(payload.get("plot_index", -1)), str(payload.get("crop_id", "")))
		"farm_water":
			return FarmManager.water(int(payload.get("plot_index", -1)))
		"farm_harvest":
			return FarmManager.harvest(int(payload.get("plot_index", -1)))
		"farm_upgrade_tool":
			return FarmManager.upgrade_tool(str(payload.get("tool_id", "")))
		"farm_buy_animal":
			return FarmManager.buy_animal(str(payload.get("animal_id", "")))
		"farm_feed_animal":
			return FarmManager.feed_animal(str(payload.get("animal_id", "")))
		"farm_collect_animal":
			return FarmManager.collect_animal_product(str(payload.get("animal_id", "")))
		"night_market_buy":
			return NightMarketManager.buy_stall(str(payload.get("stall_id", "")))
		"night_market_work":
			return NightMarketManager.work_stall()
		"kitchen_start":
			return KitchenManager.start_shift_for(str(payload.get("location", "restaurant")))
		"kitchen_end":
			KitchenManager.end_shift(str(payload.get("reason", "remote")))
			return true
		"kitchen_recipe":
			return KitchenManager.place_recipe(str(payload.get("recipe_id", "")), int(payload.get("station_index", -1)))
		"kitchen_order_tap":
			return KitchenManager.handle_order_tap(int(payload.get("order_index", -1)))
		"kitchen_station":
			return KitchenManager.handle_station_action(int(payload.get("station_index", -1)))
		"kitchen_load_staging":
			return KitchenManager.load_staging(int(payload.get("staging_index", -1)), int(payload.get("station_index", -1)))
		"kitchen_upgrade":
			return KitchenManager.upgrade_station(str(payload.get("station_type", "")))
	return false

func _build_economy_snapshot() -> Dictionary:
	economy_revision += 1
	return {
		"revision": economy_revision,
		"money": GameState.money,
		"inventory": InventoryManager.get_save_data(),
		"business": BusinessManager.get_save_data(),
		"finance": FinanceManager.get_save_data(),
		"farm": FarmManager.get_save_data(),
		"staff": StaffManager.get_save_data(),
		"enterprise": EnterpriseManager.get_save_data(),
		"room": RoomManager.get_save_data(),
		"night_market": NightMarketManager.get_save_data(),
		"kitchen": KitchenManager.get_save_data(),
	}

@rpc("any_peer", "call_remote", "reliable")
func _request_economy_snapshot() -> void:
	if multiplayer.is_server():
		_broadcast_economy.rpc_id(multiplayer.get_remote_sender_id(), _build_economy_snapshot())

@rpc("authority", "call_remote", "reliable")
func _broadcast_economy(snapshot: Dictionary) -> void:
	_apply_economy_snapshot(snapshot)

func _apply_economy_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	economy_revision = maxi(economy_revision, int(snapshot.get("revision", 0)))
	GameState.money = maxi(0, int(snapshot.get("money", GameState.money)))
	GameState.money_changed.emit(GameState.money)
	InventoryManager.restore(snapshot.get("inventory", {}))
	BusinessManager.restore(snapshot.get("business", {}))
	FinanceManager.restore(snapshot.get("finance", {}))
	FarmManager.restore(snapshot.get("farm", {}))
	StaffManager.restore(snapshot.get("staff", {}))
	EnterpriseManager.restore(snapshot.get("enterprise", {}))
	RoomManager.restore(snapshot.get("room", {}))
	NightMarketManager.restore(snapshot.get("night_market", {}))
	KitchenManager.restore(snapshot.get("kitchen", {}))
	economy_snapshot_applied.emit(snapshot.duplicate(true))

func is_coop_active() -> bool:
	return active and multiplayer.multiplayer_peer != null

func get_player_count() -> int:
	if not active:
		return 0
	return maxi(1, maxi(peer_players.size(), remote_states.size() + 1))

func can_start_session(max_players: int) -> bool:
	return max_players >= 2 and max_players <= MAX_PLAYERS

func get_summary() -> String:
	if not active:
		return "未加入好友合作。"
	var network_state := "等待好友" if is_host and get_player_count() <= 1 else "已有好友在城里"
	return "%s · 房间人数 %d/%d · %s" % ["房主" if is_host else "成员", get_player_count(), MAX_PLAYERS, network_state]

func get_slot_lines() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not active:
		return result
	var local_id := 1 if is_host else multiplayer.get_unique_id()
	result.append({"id": local_id, "name": "我", "host": is_host, "connected": true})
	for peer_id in peer_players:
		if int(peer_id) == local_id:
			continue
		result.append({"id": int(peer_id), "name": str(peer_players[peer_id]), "host": false, "connected": true})
	for peer_id in remote_states:
		if int(peer_id) == local_id:
			continue
		var exists := false
		for slot in result:
			if int(slot["id"]) == int(peer_id):
				exists = true
				break
		if not exists:
			result.append({"id": int(peer_id), "name": "好友%d" % int(peer_id), "host": false, "connected": true})
	return result

func get_peer_display_name(peer_id: int) -> String:
	return str(peer_players.get(peer_id, "好友%d" % peer_id))

func get_remote_states() -> Dictionary:
	return remote_states.duplicate(true)

func send_local_state(area_id: String, world_position: Vector2, facing: Vector2) -> void:
	if not is_coop_active():
		return
	if multiplayer.is_server():
		_broadcast_player_state.rpc(1, area_id, world_position.x, world_position.y, facing.x, facing.y)
	else:
		_submit_player_state.rpc(area_id, world_position.x, world_position.y, facing.x, facing.y)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_player_state(area_id: String, x: float, y: float, facing_x: float, facing_y: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_apply_remote_state(sender, area_id, Vector2(x, y), Vector2(facing_x, facing_y))
	if multiplayer.is_server():
		_broadcast_player_state.rpc(sender, area_id, x, y, facing_x, facing_y)

@rpc("authority", "call_remote", "unreliable_ordered")
func _broadcast_player_state(peer_id: int, area_id: String, x: float, y: float, facing_x: float, facing_y: float) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	_apply_remote_state(peer_id, area_id, Vector2(x, y), Vector2(facing_x, facing_y))

func _apply_remote_state(peer_id: int, area_id: String, world_position: Vector2, facing: Vector2) -> void:
	remote_states[peer_id] = {
		"area_id": area_id,
		"position": world_position,
		"facing": facing,
	}
	remote_player_updated.emit(peer_id, remote_states[peer_id].duplicate(true))
	coop_state_changed.emit(active, is_host, get_player_count())

func _on_peer_connected(peer_id: int) -> void:
	peer_players[peer_id] = "好友%d" % peer_id
	_broadcast_economy.rpc_id(peer_id, _build_economy_snapshot())
	peer_state_changed.emit(peer_id, true)
	coop_state_changed.emit(active, is_host, get_player_count())

func _on_peer_disconnected(peer_id: int) -> void:
	peer_players.erase(peer_id)
	_remove_remote_state(peer_id)
	if multiplayer.is_server():
		_broadcast_peer_left.rpc(peer_id)
	peer_state_changed.emit(peer_id, false)
	coop_state_changed.emit(active, is_host, get_player_count())

@rpc("authority", "call_remote", "reliable")
func _broadcast_peer_left(peer_id: int) -> void:
	_remove_remote_state(peer_id)

func _remove_remote_state(peer_id: int) -> void:
	if remote_states.erase(peer_id):
		remote_player_removed.emit(peer_id)
		coop_state_changed.emit(active, is_host, get_player_count())

func _on_connected_to_server() -> void:
	peer_players[multiplayer.get_unique_id()] = "我"
	_request_economy_snapshot.rpc_id(1)
	coop_state_changed.emit(active, is_host, get_player_count())

func _on_connection_failed() -> void:
	NoticeManager.show_system_message("好友房间连接失败。", "warning")
	leave_session()

func _on_server_disconnected() -> void:
	NoticeManager.show_system_message("房主离开了合作房间。", "warning")
	leave_session()
