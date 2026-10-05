extends SceneTree

# Renders the exact ingredient geometry used in the preparation bowls into
# compact ticket icons. Run with the Godot desktop renderer, not --headless.
const KITCHEN_VIEW := preload("res://scripts/city3d/talent_park_kitchen_view.gd")
const OUT_DIR := "res://assets/art/ui/ingredients"

func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_CLEAR_COLOR
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#fff0d9")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	scene.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.58
	camera.position = Vector3(0.36, 0.66, 0.82)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 0.12, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-51, -35, 0)
	light.light_energy = 1.1
	scene.add_child(light)
	var kitchen = KITCHEN_VIEW.new()
	for group in TalentParkRestaurant3D.RAW_GROUPS.values():
		for ingredient in group:
			var model := Node3D.new()
			scene.add_child(model)
			kitchen.call("_add_raw_ingredient", model, str(ingredient), 0.0)
			for frame in range(3):
				await process_frame
			var image := viewport.get_texture().get_image()
			var bounds := image.get_used_rect()
			if bounds.has_area():
				var crop := image.get_region(bounds)
				var zoom := 82.0 / float(maxi(bounds.size.x, bounds.size.y))
				crop.resize(maxi(1, roundi(bounds.size.x * zoom)), maxi(1, roundi(bounds.size.y * zoom)), Image.INTERPOLATE_LANCZOS)
				var centered := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
				centered.fill(Color.TRANSPARENT)
				centered.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), (Vector2i(96, 96) - crop.get_size()) / 2)
				image = centered
			var path := "%s/%s.png" % [OUT_DIR, str(ingredient)]
			if image.save_png(ProjectSettings.globalize_path(path)) != OK:
				push_error("Ticket icon export failed: " + path)
				quit(1)
				return
			model.queue_free()
			await process_frame
	kitchen.free()
	viewport.queue_free()
	await process_frame
	print("TICKET_INGREDIENT_ICONS_SAVED:20")
	quit(0)
