"""Build an original Shenzhen old-town tea shop miniature for the live district."""

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "models"
SOURCE = ROOT / "tools" / "art" / "source"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def rgb(value):
    values = [int(value[i : i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return (*[v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values], 1.0)


def mat(name, value, roughness=0.75, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgb(value)
    m.use_nodes = True
    node = m.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = rgb(value)
    node.inputs["Roughness"].default_value = roughness
    node.inputs["Metallic"].default_value = metallic
    return m


plaster = mat("lime_plaster_apricot", "#D9B797", 0.94)
plaster_light = mat("lime_plaster_cream", "#EBD7B8", 0.91)
stone = mat("worn_local_stone", "#B9AD98", 0.93)
stone_dark = mat("stone_mortar", "#8B8778", 0.97)
tile = mat("warm_clay_roof_tile", "#B77D6D", 0.84)
tile_light = mat("sunlit_clay_roof_tile", "#D2947B", 0.84)
wood = mat("tea_shop_walnut", "#805E4D", 0.77)
wood_light = mat("oiled_wood_counter", "#B18467", 0.69)
mint = mat("canvas_muted_jade", "#83ADA0", 0.91)
canvas_light = mat("canvas_cream", "#F2E9D3", 0.92)
glass = mat("glazed_tea_window", "#83B7B9", 0.28)
dark = mat("shadowed_window", "#3D5F5D", 0.72)
brass = mat("aged_brass", "#C2A471", 0.49, 0.54)
leaf = mat("plant_jade", "#6F9D76", 0.92)
leaf_light = mat("plant_light", "#A1BA85", 0.92)
ceramic = mat("tea_ceramic", "#F4EAD5", 0.42)


def box(name, xyz, size, material, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        m = obj.modifiers.new("soft_edge", "BEVEL")
        m.width = bevel
        m.segments = 3
        m.limit_method = "ANGLE"
        n = obj.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
        n.keep_sharp = True
    return obj


def cylinder(name, xyz, radius, depth, material, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def sphere(name, xyz, scale, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


# Local +Z is height; -Y is street-facing after glTF export.
box("old_town_main_plaster", (0, 0, 2.82), (7.35, 4.75, 5.64), plaster, 0.13)
box("ground_floor_cream_lime", (0, -2.405, 1.37), (7.16, 0.10, 2.56), plaster_light, 0.04)
box("stone_foundation", (0, -2.462, 0.42), (7.20, 0.15, 0.78), stone, 0.045)
box("stone_mortar_line", (0, -2.55, 0.79), (7.22, 0.018, 0.035), stone_dark, 0.0)
box("roof_cornice", (0, 0, 5.73), (7.86, 5.16, 0.31), stone, 0.075)
box("roof_clay_field", (0, 0, 5.96), (8.02, 5.36, 0.21), tile, 0.09)
for ix in range(17):
    x = -3.77 + ix * 0.47
    box(f"roof_tile_front_{ix}", (x, -2.69, 6.04), (0.42, 0.20, 0.085), tile_light if ix % 3 == 0 else tile, 0.025)
    if ix % 2 == 0:
        box(f"roof_tile_ridge_{ix}", (x, 0.10, 6.08), (0.06, 5.16, 0.08), tile_light, 0.025)
box("roof_shadow_band", (0, -2.61, 5.66), (7.76, 0.13, 0.12), wood, 0.035)

# Two human-scale upper windows with warm shutters and railings.
for side, x in (("west", -1.83), ("east", 1.83)):
    box(f"upper_recess_{side}", (x, -2.426, 4.24), (1.62, 0.10, 1.46), wood, 0.055)
    box(f"upper_glazing_{side}", (x, -2.492, 4.24), (1.40, 0.035, 1.23), glass, 0.025)
    box(f"upper_mullion_{side}", (x, -2.53, 4.24), (0.06, 0.045, 1.23), wood_light, 0.013)
    box(f"upper_sill_{side}", (x, -2.56, 3.43), (1.84, 0.31, 0.14), stone, 0.035)
    for rail in range(5):
        rx = x - 0.65 + rail * 0.33
        box(f"balcony_rail_{side}_{rail}", (rx, -2.78, 3.68), (0.045, 0.04, 0.43), dark, 0.013)
    box(f"balcony_top_{side}", (x, -2.78, 3.89), (1.68, 0.06, 0.06), dark, 0.016)

# Shopfront: split glazing, door frame and a counter visible at the fixed game camera.
box("shopfront_dark_base", (0, -2.478, 1.47), (6.83, 0.14, 2.73), dark, 0.065)
box("door_glazing", (0.12, -2.564, 1.37), (1.24, 0.035, 2.16), glass, 0.025)
box("door_walnut_rail", (0.12, -2.607, 0.43), (1.35, 0.055, 0.15), wood, 0.025)
box("door_brass_handle", (0.58, -2.635, 1.28), (0.055, 0.04, 0.31), brass, 0.018)
for side, x in (("left", -2.12), ("right", 2.18)):
    box(f"shop_window_{side}", (x, -2.56, 1.49), (2.26, 0.035, 1.81), glass, 0.032)
    box(f"shop_window_frame_{side}", (x, -2.608, 2.40), (2.42, 0.07, 0.095), wood_light, 0.02)
    box(f"shop_window_sill_{side}", (x, -2.624, 0.56), (2.42, 0.19, 0.13), wood_light, 0.034)
    box(f"shop_window_mullion_{side}", (x, -2.61, 1.49), (0.06, 0.055, 1.90), wood_light, 0.015)

box("customer_step", (0.11, -3.02, 0.12), (2.1, 0.71, 0.24), stone, 0.075)
box("awning_canvas_main", (0, -3.07, 2.90), (6.80, 1.42, 0.19), mint, 0.10)
box("awning_front_hem", (0, -3.75, 2.77), (6.88, 0.14, 0.27), mint, 0.065)
for i in range(9):
    x = -3.02 + i * 0.76
    box(f"awning_cream_stripe_{i}", (x, -3.07, 3.015), (0.38, 1.34, 0.025), canvas_light, 0.01)
    sphere(f"awning_scallop_{i}", (x, -3.81, 2.64), (0.32, 0.11, 0.17), mint if i % 2 else canvas_light)
for side in (-1, 1):
    box(f"awning_bracket_{side}", (side * 2.98, -2.91, 2.74), (0.08, 1.32, 0.07), dark, 0.019)

box("shop_sign_wood", (0, -2.535, 3.48), (4.23, 0.13, 0.70), wood, 0.075)
box("shop_sign_border", (0, -2.615, 3.48), (4.00, 0.025, 0.49), mint, 0.036)
box("display_counter", (-2.01, -2.89, 0.84), (1.82, 0.52, 0.90), wood_light, 0.06)
box("display_counter_top", (-2.01, -2.90, 1.34), (2.00, 0.65, 0.11), wood, 0.04)

# Ceramic tea ware, plants and a small hanging lamp create the street-scale story.
for i, x in enumerate((-2.70, -2.08, -1.48)):
    cylinder(f"tea_cup_{i}", (x, -3.02, 1.48), 0.11, 0.14, ceramic)
    cylinder(f"tea_cup_saucer_{i}", (x, -3.02, 1.39), 0.16, 0.035, brass)
cylinder("tea_jar", (2.87, -3.02, 1.36), 0.22, 0.46, ceramic)
box("hanging_lamp_cord", (2.60, -3.06, 2.44), (0.03, 0.03, 0.52), dark, 0.0)
sphere("hanging_lamp_globe", (2.60, -3.06, 2.13), (0.23, 0.23, 0.23), ceramic)
for side, x in (("west", -3.36), ("east", 3.34)):
    cylinder(f"clay_pot_{side}", (x, -3.04, 0.37), 0.31, 0.52, tile)
    cylinder(f"plant_stem_{side}", (x, -3.04, 0.77), 0.045, 0.42, wood)
    for j in range(5):
        angle = j * 2 * math.pi / 5
        sphere(f"plant_leaf_{side}_{j}", (x + 0.19 * math.cos(angle), -3.04 + 0.16 * math.sin(angle), 1.02 + 0.05 * (j % 2)), (0.25, 0.13, 0.36), leaf_light if j % 2 else leaf)

# A modest roof marker echoes the toy-diorama references without copying their icons.
cylinder("tea_pot_roof_base", (0, -0.15, 6.20), 0.50, 0.23, wood)
sphere("tea_pot_roof_body", (0, -0.15, 6.62), (0.52, 0.52, 0.43), ceramic)
cylinder("tea_pot_roof_lid", (0, -0.15, 7.02), 0.25, 0.07, mint)
box("tea_pot_spout", (0.61, -0.15, 6.68), (0.62, 0.16, 0.15), ceramic, 0.065)
sphere("tea_pot_handle", (-0.56, -0.15, 6.67), (0.18, 0.32, 0.25), ceramic)

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "nantou_tea_house.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "nantou_tea_house.glb"), export_format="GLB")

# Isolated asset review render (not game background).
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.82, 0.85, 0.82, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.55
bpy.ops.object.light_add(type="AREA", location=(-3, -5, 10))
bpy.context.object.data.energy = 950
bpy.context.object.data.size = 7
bpy.ops.object.camera_add(location=(11, -13, 11))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 3.4)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 11.7
bpy.context.scene.camera = camera
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1000
bpy.context.scene.render.resolution_y = 850
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = str(OUT / "nantou_tea_house_preview.png")
bpy.ops.render.render(write_still=True)
print("ART_ASSET_READY:" + str(OUT / "nantou_tea_house.glb"))
