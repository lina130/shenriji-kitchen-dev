extends Node

const LifeScript := preload("res://scripts/city3d/city_life_state.gd")
const CityScript := preload("res://scripts/city3d/city_slice.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var life = LifeScript.new()
	if not life.begin_shift("relaxed") or life.energy != 82:
		_fail("Relaxed shift energy cost")
		return
	var calm_pay: int = life.finish_shift("restaurant", "relaxed", 3, 3)
	if not life.begin_shift("rush") or life.energy != 40:
		_fail("Rush shift energy cost")
		return
	var rush_pay: int = life.finish_shift("restaurant", "rush", 5, 5)
	if rush_pay <= calm_pay * 2 or rush_pay <= calm_pay * 42 / 18:
		_fail("High intensity work needs clearly higher return")
		return
	if not life.discover_neighbor_memento().is_empty():
		_fail("The neighbor memento must emerge through ordinary life progress")
		return
	life.rest_day()
	life.career_shifts["restaurant"] = 2
	var found: Dictionary = life.discover_neighbor_memento()
	if found.is_empty() or not life.discover_neighbor_memento().is_empty():
		_fail("The neighbor memento must be a one-time easter egg")
		return
	var cash_before_sale: int = life.cash
	if life.sell_item(0) != int(found["value"]) or life.cash != cash_before_sale + int(found["value"]):
		_fail("Collector price and cash did not agree")
		return
	if life.day != 2 or life.energy != 100:
		_fail("Rest must renew energy without a daily treasure reset")
		return
	var save_path := "user://city3d_feature_test.json"
	if not life.save_to_disk(save_path):
		_fail("Feature save failed")
		return
	var reloaded = LifeScript.new()
	if not reloaded.load_from_disk(save_path) or reloaded.cash != life.cash or reloaded.day != life.day or not reloaded.found_secrets.has("nantou_neighbor"):
		_fail("Feature save roundtrip failed")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var city = CityScript.new()
	city.preview_save_path = "user://city3d_feature_session_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(city.preview_save_path))
	add_child(city)
	for frame in range(3):
		await get_tree().process_frame
	for wanted in ["rest_home", "collector", "neighbor", "restaurant_rush", "restaurant_steam", "restaurant_tea", "restaurant_cake", "restaurant_customer"]:
		if not _has_interaction(wanted):
			_fail("Missing city interaction: " + wanted)
			return
	if not city.find_children("*", "Label3D", true, false).is_empty():
		_fail("Unattached floating labels remain in the street scene")
		return
	if city.get("_regions").size() < 6:
		_fail("Nearby 128 m region chunks were not streamed")
		return
	if not is_instance_valid(city.player.visual_root.find_child("BayResidentHeroAsset", true, false)):
		_fail("Blender resident model did not replace the placeholder")
		return
	var initial_cash: int = city.life_state.cash
	city._interact(_area_for("tea_house"))
	for station in ["restaurant_steam", "restaurant_tea", "restaurant_cake"]:
		city._interact(_area_for(station))
		if str(city.get("_shift").get("phase", "")) != "serve" or not is_instance_valid(city.get("_held_food")):
			_fail("Preparing an order did not create a carried meal")
			return
		city._interact(_area_for("restaurant_customer"))
	if city.life_state.cash != initial_cash + calm_pay or not city.get("_shift").is_empty():
		_fail("Physical restaurant stations and customer did not settle earnings")
		return
	if _has_interaction("search_nantou") or _has_interaction("inspect_nantou") or _has_interaction("search_shenzhen"):
		_fail("Daily treasure caches remained in the street")
		return
	var cash_after_restaurant: int = city.life_state.cash
	if not _interact_at(city, "courier_hub", 12.0):
		_fail("Courier hub did not start an in-world route")
		return
	var courier_time_before_map: float = float(city.get("_shift").get("seconds", 0.0))
	city._toggle_overview()
	city._tick_shift(7.0)
	if not city.get("_overview") or float(city.get("_shift").get("seconds", 0.0)) != courier_time_before_map:
		_fail("Route map cannot be opened or pauses incorrectly during work")
		return
	city._toggle_overview()
	for destination in [
		["delivery_nantou", -18.0], ["delivery_studio", 12.0], ["delivery_hongkong", 36.0]
	]:
		if not _interact_at(city, "courier_pickup", 12.0):
			_fail("Courier pickup prop was unavailable")
			return
		if destination[0] == "delivery_nantou":
			_interact_at(city, "delivery_studio", 12.0)
			if int(city.get("_shift").get("step", -1)) != 0 or str(city.get("_shift").get("phase", "")) != "deliver":
				_fail("Wrong courier destination advanced the order")
				return
			var saved_courier = LifeScript.new()
			if not saved_courier.load_from_disk(city.preview_save_path) or str(saved_courier.active_shift.get("phase", "")) != "deliver":
				_fail("In-progress field work was not saved")
				return
		if not _interact_at(city, destination[0], destination[1]):
			_fail("Courier pickup or delivery prop was unavailable")
			return
	if not city.get("_shift").is_empty() or city.life_state.cash <= cash_after_restaurant or city.hud.is_modal_open():
		_fail("Courier field route did not complete without menu answers")
		return
	var cash_after_courier: int = city.life_state.cash
	if not _interact_at(city, "creative_studio", 12.0):
		_fail("Studio did not start an in-world commission")
		return
	for observation in [
		["creative_inspiration_shenzhen", 12.0],
		["creative_inspiration_nantou", -18.0],
		["creative_inspiration_hongkong", 36.0]
	]:
		if observation[0] == "creative_inspiration_shenzhen":
			_interact_at(city, "creative_inspiration_nantou", -18.0)
			if str(city.get("_shift").get("phase", "")) != "inspiration":
				_fail("Wrong inspiration site advanced the commission")
				return
		if not _interact_at(city, observation[0], observation[1]) or not _interact_at(city, "creative_workbench", 12.0) or not _interact_at(city, "creative_client", 12.0):
			_fail("Creative inspiration, workbench, or client was unavailable")
			return
	if not city.get("_shift").is_empty() or city.life_state.cash <= cash_after_courier or city.hud.is_modal_open():
		_fail("Creative field route did not complete without menu answers")
		return
	city.player.global_position = Vector3(32.0, 0.5, 0.6)
	city._update_chunks()
	for frame in range(3):
		await get_tree().physics_frame
	if city.get("_last_district") != "香港 · 电车街市":
		_fail("The preview district did not load")
		return
	if city.atlas.CITIES.size() != 11 or city.atlas.world_bounds().get_area() < 16000000.0:
		_fail("Whole-region atlas is incomplete")
		return
	city._toggle_overview()
	if not city.get("_overview") or city.get("_target_zoom") < 4000.0:
		_fail("Whole-region overview did not zoom out")
		return
	city._travel_to_city("macao")
	if city.get("_overview") or city.atlas.nearest_city(city.player.global_position)["id"] != "macao":
		_fail("City selection did not return to local exploration")
		return
	var fare_start: int = city.life_state.cash
	if not _has_interaction("ferry_pier_macao") or not _has_interaction("ferry_pier_hongkong"):
		_fail("Both ferry pier entrances are required for physical travel")
		return
	city._interact(_area_for("ferry_pier_macao"))
	if city.life_state.cash != fare_start - city.FERRY_FARE or city.player.global_position.distance_to(Vector3(720.0, 0.5, 863.8)) > 1.0:
		_fail("Macao pier did not transport to Hong Kong or charge the fare")
		return
	city._interact(_area_for("ferry_pier_hongkong"))
	if city.life_state.cash != fare_start - city.FERRY_FARE * 2 or city.player.global_position.distance_to(Vector3(-1767.8, 0.5, 1415.0)) > 1.0:
		_fail("Hong Kong pier did not return to Macao")
		return
	var old_yaw: float = city.get("_camera_yaw")
	city.set("_orbiting", true)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(35, 0)
	city._unhandled_input(drag)
	if float(city.get("_camera_yaw")) == old_yaw:
		_fail("Camera yaw is still fixed")
		return
	var old_zoom: float = city.get("_target_zoom")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	city._unhandled_input(wheel)
	if float(city.get("_target_zoom")) <= old_zoom:
		_fail("Camera zoom is still fixed")
		return
	if not _interact_at(city, "courier_hub", 12.0) or not _interact_at(city, "courier_pickup", 12.0):
		_fail("Could not prepare a saved delivery for reload")
		return
	var resumed_city = CityScript.new()
	resumed_city.preview_save_path = city.preview_save_path
	add_child(resumed_city)
	for frame in range(2):
		await get_tree().process_frame
	if str(resumed_city.get("_shift").get("phase", "")) != "deliver" or not is_instance_valid(resumed_city.get("_held_food")):
		_fail("Reload did not restore the active route and held parcel")
		return
	resumed_city.player.global_position = Vector3(-4.0, 0.5, 4.0)
	resumed_city._physics_process(10.1)
	var position_reload = LifeScript.new()
	if not position_reload.load_from_disk(city.preview_save_path) or position_reload.player_position.distance_to(resumed_city.player.global_position) > 0.01:
		_fail("Nearby exploration position was not saved")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(city.preview_save_path))
	print("CITY3D_FEATURE_PASS")
	get_tree().quit(0)

func _has_interaction(interaction_id: String) -> bool:
	for area in get_tree().get_nodes_in_group("city3d_interactable"):
		if area.get_meta("interaction_id", "") == interaction_id:
			return true
	return false

func _area_for(interaction_id: String) -> Area3D:
	for area in get_tree().get_nodes_in_group("city3d_interactable"):
		if area.get_meta("interaction_id", "") == interaction_id:
			return area
	return null

func _interact_at(city, interaction_id: String, world_x: float) -> bool:
	city.player.global_position = Vector3(world_x, 0.5, 0.6)
	city._update_chunks()
	var area := _area_for(interaction_id)
	if not is_instance_valid(area):
		return false
	city._interact(area)
	return true

func _fail(reason: String) -> void:
	push_error("CITY3D_FEATURE_FAIL: " + reason)
	get_tree().quit(1)
