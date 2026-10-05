"""Original Shenzhen Talent Park cafe-bookbar miniature.

The real park bookbar's public uses inspire the program: reading, viewing,
resting, coffee, drinks and pastries. This model is an original stylized
building, with an open service side that exposes a full small restaurant loop.
Metres; +Z up; local -Y faces the public park promenade.
"""

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


def srgb(hex_value):
    values = [int(hex_value[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values) + (1,)


def material(name, color, rough=0.8, metallic=0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = srgb(color)
    result.use_nodes = True
    node = result.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = srgb(color)
    node.inputs["Roughness"].default_value = rough
    node.inputs["Metallic"].default_value = metallic
    return result


stone = material("talent_park_warm_paving", "#C8C6B2", 0.93)
stone_shadow = material("paving_and_wall_recess", "#A8B2A5", 0.94)
cream = material("limewash_library_ivory", "#F1E9D6", 0.88)
cream_deep = material("counter_base_sand", "#D7CDB7", 0.88)
sage = material("roof_soft_sage", "#83AD9E", 0.75)
sage_highlight = material("roof_sunlit_sage", "#A8C6AC", 0.74)
sage_dark = material("park_green_structure", "#4B776D", 0.65, 0.18)
glass = material("bookbar_window_blue_green", "#91C1C3", 0.24, 0.04)
glass_shadow = material("glazing_deep_teal", "#6498A0", 0.31, 0.06)
wood = material("warm_oiled_wood_counter", "#B58763", 0.72)
wood_light = material("counter_rounded_nose", "#D2A47A", 0.73)
wood_dark = material("library_walnut_trim", "#7D6150", 0.78)
brass = material("brushed_coffee_brass", "#C5A775", 0.44, 0.52)
steel = material("coffee_machine_satin_steel", "#B6C0B8", 0.43, 0.65)
steel_dark = material("cooking_surface_charcoal", "#4F6164", 0.48, 0.52)
ceramic = material("service_cream_ceramic", "#FAF0DC", 0.45)
coffee = material("espresso_warm_brown", "#8A5F45", 0.58)
pastry = material("pastry_golden_crust", "#DDA96F", 0.69)
pastry_shadow = material("pastry_baked_edge", "#C68C59", 0.71)
tomato = material("fresh_tomato_coral", "#DB6C5D", 0.61)
leaf = material("park_planter_jade", "#5E9A72", 0.89)
leaf_light = material("park_leaf_sunlit", "#93B883", 0.87)
ink = material("book_cover_ink", "#4E6773", 0.84)
red_book = material("book_cover_coral", "#CA766E", 0.88)
ochre_book = material("book_cover_ochre", "#D0B070", 0.88)
teal_book = material("book_cover_jade", "#75A9A4", 0.88)
paper = material("paper_page_edges", "#EBE4D3", 0.92)
lamp = material("pendant_warm_frosted_glass", "#F7DCAA", 0.42)


def bevel(obj, radius):
    if radius <= 0:
        return obj
    modifier = obj.modifiers.new("hand_softened_edges", "BEVEL")
    modifier.width = radius
    modifier.segments = 3
    modifier.limit_method = "ANGLE"
    weighted = obj.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
    weighted.keep_sharp = True
    return obj


def box(name, xyz, dimensions, mat, radius=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return bevel(obj, radius)


def cylinder(name, xyz, radius, depth, mat, vertices=18):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return bevel(obj, 0.009)


def ellipsoid(name, xyz, radii, mat, segments=18, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.scale = radii
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def rod(name, start, end, radius, mat, vertices=12):
    direction = Vector(end) - Vector(start)
    midpoint = (Vector(start) + Vector(end)) / 2
    obj = cylinder(name, midpoint, radius, direction.length, mat, vertices)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def panel(name, vertices, faces, mat, thickness=0):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if thickness:
        modifier = obj.modifiers.new("panel_thickness", "SOLIDIFY")
        modifier.thickness = thickness
        bevel(obj, 0.02)
    return obj


def anchor(name, xyz):
    obj = bpy.data.objects.new("ANCHOR_" + name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = xyz
    obj.empty_display_type = "SPHERE"
    obj.empty_display_size = 0.16
    return obj


# A free-standing, gently rounded pavilion on a shoreline park promenade.
# The paved margin is intentionally small; the real continuous map supplies
# the surrounding path, planting, lake and city backdrop.
box("park_bookbar_foundation", (0, 0, 0.10), (9.6, 7.5, 0.20), stone, 0.12)
for y in (-3.25, -2.55, -1.85):
    box(f"promenade_paver_{y}", (0, y, 0.213),
        (8.86, 0.67, 0.025), stone_shadow if y == -2.55 else stone, 0.035)
for x in (-4.25, 4.25):
    box(f"side_planted_edge_{x}", (x, -0.20, 0.39),
        (0.64, 5.87, 0.44), stone_shadow, 0.11)

# Rear reading room is open at the front and partially glazed on both sides.
# Book shelves sit against the rear wall while the restaurant work line
# occupies the first half; from the camera, work stations stay visible.
box("reading_room_back_wall", (0, 2.86, 1.73),
    (8.15, 0.25, 3.04), cream, 0.10)
box("reading_room_back_base", (0, 2.68, 0.38),
    (8.24, 0.40, 0.40), stone_shadow, 0.07)
for side, x in (("left", -3.99), ("right", 3.99)):
    box(f"reading_room_side_plinth_{side}", (x, 1.46, 0.57),
        (0.26, 2.90, 0.84), cream_deep, 0.055)
    box(f"reading_room_side_glazing_{side}", (x, 1.46, 2.04),
        (0.07, 2.71, 1.84), glass, 0.018)
    for y in (0.14, 1.51, 2.78):
        box(f"side_window_mullion_{side}_{y}", (x, y, 2.05),
            (0.12, 0.064, 2.09), sage_dark, 0.019)
    box(f"side_window_top_rail_{side}", (x, 1.46, 3.01),
        (0.16, 2.90, 0.095), sage_dark, 0.024)
for x in (-3.89, 3.89):
    rod(f"front_terrace_pillar_{x}", (x, -2.47, 0.42),
        (x, -2.47, 3.46), 0.075, sage_dark)
    cylinder(f"front_pillar_brass_foot_{x}", (x, -2.47, 0.39),
             0.15, 0.11, brass)

# A partial leaf canopy shades the reading room; the service terrace uses
# spaced timber pergola slats. This cutaway preserves interior readability
# from oblique cameras without requiring an unnatural missing roof.
for side in (-1, 1):
    for i in range(8):
        x0 = i * 4.50 / 8
        x1 = (i + 1) * 4.50 / 8
        z0 = 4.12 - 0.62 * (x0 / 4.50) ** 1.45
        z1 = 4.12 - 0.62 * (x1 / 4.50) ** 1.45
        panel(f"leaf_roof_{side}_{i}",
              [(side * x0, 0.15, z0), (side * x1, 0.15, z1),
               (side * x1, 3.22, z1), (side * x0, 3.22, z0)],
              [(0, 1, 2, 3)], sage_highlight if i in (0, 4) else sage, 0.12)
        if i in (0, 3, 6):
            rod(f"roof_seam_{side}_{i}", (side * x1, 0.17, z1 + 0.08),
                (side * x1, 3.22, z1 + 0.08), 0.021, sage_dark)
box("roof_ridge", (0, 1.69, 4.17), (0.34, 3.35, 0.14), sage_dark, 0.065)
for x in (-4.05, 4.05):
    rod(f"pergola_long_beam_{x}", (x, -2.45, 3.53),
        (x, 0.28, 3.53), 0.085, wood_dark)
for i in range(9):
    y = -2.43 + i * 0.34
    obj = box(f"pergola_sunshade_slat_{i}", (0, y, 3.60),
              (8.17, 0.11, 0.15), wood_light, 0.04)
    obj.rotation_euler.x = math.radians(11)
rod("pergola_front_beam", (-4.05, -2.48, 3.48),
    (4.05, -2.48, 3.48), 0.12, sage_dark)

# Physical book and cup icon, fixed to the real timber beam. No city name or
# HUD-style floating label is painted into world space.
box("bookbar_emblem_backplate", (0, -2.61, 3.15),
    (1.38, 0.10, 0.55), cream, 0.07)
box("emblem_book_left", (-0.22, -2.677, 3.11),
    (0.36, 0.035, 0.18), teal_book, 0.025)
box("emblem_book_right", (0.13, -2.677, 3.11),
    (0.36, 0.035, 0.18), red_book, 0.025)
box("emblem_cup", (0.38, -2.69, 3.18),
    (0.16, 0.037, 0.15), coffee, 0.025)
rod("emblem_book_spine", (-0.04, -2.70, 3.02),
    (-0.04, -2.70, 3.24), 0.013, wood_dark)

# Shelves with a varied rhythm of actual book spines form the readable side of
# the bookbar. Different heights and several color families avoid flat decals.
for shelf_side, centre_x in (("west", -2.63), ("east", 2.66)):
    box(f"bookshelf_back_{shelf_side}", (centre_x, 2.64, 1.77),
        (2.57, 0.25, 2.38), wood_dark, 0.055)
    for row, z in enumerate((0.79, 1.39, 1.99, 2.59)):
        box(f"bookshelf_horizontal_{shelf_side}_{row}",
            (centre_x, 2.43, z), (2.52, 0.43, 0.09), wood_light, 0.025)
        for i in range(11):
            x = centre_x - 1.10 + i * 0.21
            height = 0.32 + 0.035 * ((i * 3 + row * 2) % 5)
            cover = (ink, red_book, ochre_book, teal_book)[(i + row) % 4]
            box(f"book_{shelf_side}_{row}_{i}",
                (x, 2.42, z + 0.055 + height / 2),
                (0.13, 0.20, height), cover, 0.009)
            if i % 4 == 0:
                box(f"book_page_edge_{shelf_side}_{row}_{i}",
                    (x + 0.067, 2.38, z + 0.055 + height / 2),
                    (0.01, 0.17, height - 0.025), paper, 0.003)

# Kitchen line, exposed left to right: preparation, heat, plating/collection,
# payment. Physical workstation pieces make each interaction legible even
# before the first mini-game is wired up.
for label, x, width in (("prep", -2.42, 2.22), ("heat", -0.35, 1.90)):
    box(f"{label}_workbench_base", (x, 0.30, 0.63),
        (width, 0.92, 1.00), cream_deep, 0.07)
    box(f"{label}_workbench_top", (x, 0.30, 1.18),
        (width + 0.11, 1.02, 0.11), wood_light, 0.048)
    box(f"{label}_toe_recess", (x, -0.185, 0.28),
        (width - 0.11, 0.055, 0.15), stone_shadow, 0.025)

# Ingredients in shallow removable trays; a board and knife make prep a
# distinct action zone rather than another undifferentiated counter.
box("prep_chopping_board", (-2.63, -0.05, 1.254),
    (0.85, 0.57, 0.055), wood, 0.048)
rod("prep_knife_blade", (-2.90, -0.02, 1.302),
    (-2.45, 0.10, 1.302), 0.014, steel)
box("prep_knife_handle", (-2.28, 0.14, 1.31),
    (0.28, 0.044, 0.035), wood_dark, 0.012)
for label, x, crop in (("greens", -1.93, leaf),
                       ("tomatoes", -1.36, tomato)):
    box(f"prep_ingredient_tray_{label}", (x, 0.53, 1.25),
        (0.49, 0.39, 0.07), steel, 0.035)
    for i in range(5):
        ellipsoid(f"prep_ingredient_{label}_{i}",
                  (x - 0.15 + (i % 3) * 0.15,
                   0.44 + (i // 3) * 0.14, 1.314),
                  (0.083, 0.065, 0.057), crop, 12, 8)

# Induction hob, hood and little sauté pan; clear black/brass heat controls.
box("heat_induction_plate", (-0.35, 0.20, 1.266),
    (1.26, 0.63, 0.034), steel_dark, 0.035)
for x in (-0.73, 0.08):
    cylinder(f"heat_induction_ring_{x}", (x, 0.20, 1.292),
             0.24, 0.016, brass, 28)
cylinder("heat_skillet", (-0.74, 0.20, 1.34),
         0.18, 0.078, steel_dark, 24)
rod("heat_skillet_handle", (-0.56, 0.20, 1.34),
    (-0.19, 0.20, 1.34), 0.028, wood_dark)
box("heat_hood", (-0.38, 0.36, 2.68),
    (1.66, 0.78, 0.29), steel, 0.08)
box("heat_hood_filter", (-0.38, 0.36, 2.505),
    (1.33, 0.52, 0.034), steel_dark, 0.018)
for x in (-0.90, -0.38, 0.14):
    box(f"heat_hood_slit_{x}", (x, 0.36, 2.478),
        (0.26, 0.36, 0.008), stone_shadow, 0.006)

# The expo counter faces the park and has physical food models and a pickup
# shelf. The pay counter is shifted right to avoid blocking the cooking view.
box("expo_counter_base", (0.80, -1.32, 0.65),
    (1.75, 0.70, 1.02), cream, 0.085)
box("expo_counter_top", (0.80, -1.32, 1.18),
    (1.90, 0.86, 0.12), wood_light, 0.055)
box("expo_pickup_lip", (0.80, -1.80, 1.07),
    (1.72, 0.13, 0.10), wood, 0.035)
for i, x in enumerate((0.36, 0.79, 1.23)):
    cylinder(f"plating_saucer_{i}", (x, -1.26, 1.27),
             0.16, 0.03, ceramic)
    ellipsoid(f"plating_pastry_{i}", (x, -1.26, 1.34),
              (0.12, 0.10, 0.07), pastry if i % 2 else pastry_shadow)
box("payment_counter_base", (2.81, -1.72, 0.67),
    (1.78, 0.86, 1.06), wood, 0.09)
box("payment_counter_top", (2.81, -1.72, 1.20),
    (1.95, 1.04, 0.11), wood_light, 0.05)
box("payment_pos_body", (2.36, -1.49, 1.35),
    (0.29, 0.22, 0.21), steel_dark, 0.027)
box("payment_pos_screen", (2.36, -1.65, 1.42),
    (0.23, 0.02, 0.13), glass_shadow, 0.01)
for i in range(3):
    box(f"payment_pos_button_{i}", (2.26 + i * 0.10, -1.655, 1.34),
        (0.052, 0.012, 0.02), brass, 0.004)

# Curved clear display with separate pastries, espresso unit and ceramic cups.
box("payment_pastry_case_base", (3.15, -1.72, 1.32),
    (0.84, 0.66, 0.09), steel, 0.032)
box("payment_pastry_case_glass", (3.15, -1.72, 1.61),
    (0.86, 0.69, 0.48), glass, 0.095)
for i, x in enumerate((2.90, 3.15, 3.40)):
    ellipsoid(f"pastry_display_{i}", (x, -1.79, 1.42),
              (0.12, 0.10, 0.07), pastry if i % 2 else pastry_shadow)
box("espresso_machine_body", (1.47, 0.71, 1.51),
    (0.63, 0.54, 0.52), steel, 0.08)
box("espresso_machine_face", (1.47, 0.425, 1.53),
    (0.54, 0.035, 0.31), steel_dark, 0.022)
for x in (1.30, 1.64):
    cylinder(f"espresso_dial_{x}", (x, 0.39, 1.63),
             0.055, 0.022, brass, 16)
    rod(f"espresso_portafilter_{x}", (x, 0.40, 1.43),
        (x, 0.11, 1.39), 0.023, wood_dark)
for i, x in enumerate((1.30, 1.60, 1.90)):
    cylinder(f"coffee_cup_{i}", (x, 0.80, 1.29),
             0.092, 0.14, ceramic)
    cylinder(f"coffee_saucer_{i}", (x, 0.80, 1.21),
             0.13, 0.020, brass)

# Park reading terrace: one compact table, two chairs, tea and books. Keeping
# it on the left leaves a straight route from the promenade to payment.
cylinder("reading_terrace_table_stem", (-2.73, -2.02, 0.55),
         0.065, 0.68, sage_dark)
cylinder("reading_terrace_table_top", (-2.73, -2.02, 0.94),
         0.55, 0.12, wood_light, 24)
for i, (x, y) in enumerate(((-3.50, -2.18), (-1.94, -2.20))):
    cylinder(f"reading_chair_stem_{i}", (x, y, 0.43),
             0.05, 0.55, sage_dark)
    ellipsoid(f"reading_chair_seat_{i}", (x, y, 0.73),
              (0.33, 0.29, 0.08), wood)
    box(f"reading_chair_back_{i}", (x, y + 0.27, 1.04),
        (0.61, 0.09, 0.50), wood, 0.05)
box("terrace_open_book_left", (-2.85, -2.00, 1.025),
    (0.25, 0.20, 0.03), paper, 0.018)
box("terrace_open_book_right", (-2.60, -2.00, 1.025),
    (0.25, 0.20, 0.03), paper, 0.018)
rod("terrace_book_spine", (-2.72, -2.0, 1.045),
    (-2.72, -1.84, 1.045), 0.013, wood_dark)
cylinder("terrace_drink_cup", (-2.98, -2.28, 1.065),
         0.075, 0.13, ceramic)

# Wall-height pocket planters and pendant lights distinguish a calm city park
# venue from a generic street kiosk.
for side, x in (("left", -4.40), ("right", 4.40)):
    cylinder(f"planter_terracotta_{side}", (x, -1.18, 0.52),
             0.30, 0.64, wood, 20)
    cylinder(f"planter_lip_{side}", (x, -1.18, 0.88),
             0.33, 0.09, wood_light, 20)
    for i in range(7):
        angle = i * math.tau / 7
        ellipsoid(f"planter_leaf_{side}_{i}",
                  (x + 0.18 * math.cos(angle),
                   -1.18 + 0.18 * math.sin(angle), 1.19 + 0.06 * (i % 2)),
                  (0.20, 0.11, 0.31), leaf_light if i % 3 == 0 else leaf)
for x in (-2.60, 0.10, 2.52):
    rod(f"warm_pendant_cord_{x}", (x, -0.40, 3.52),
        (x, -0.40, 2.79), 0.015, sage_dark)
    ellipsoid(f"warm_pendant_shade_{x}", (x, -0.40, 2.71),
              (0.27, 0.27, 0.16), sage)
    ellipsoid(f"warm_pendant_globe_{x}", (x, -0.40, 2.60),
              (0.10, 0.10, 0.10), lamp)

# Named GLB nodes for the gameplay agent. They are intentionally empties and
# do not produce visible floating labels or unexpected mesh collision.
anchor("Prep", (-2.50, -0.66, 1.20))
anchor("Heat", (-0.39, -0.65, 1.20))
anchor("Plate", (0.78, -1.77, 1.22))
anchor("Pay", (2.80, -2.33, 1.24))
anchor("CustomerQueue", (2.80, -3.13, 0.22))
anchor("StaffStand", (-0.75, -0.82, 0.22))
anchor("ReadSeat", (-2.73, -2.02, 0.94))
anchor("Entry", (0, -3.38, 0.22))

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "sz_park_bookbar_cafe.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "sz_park_bookbar_cafe.glb"),
                          export_format="GLB")

# Review images are made after export; no review lights/backdrops enter GLB.
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.82, 0.86, 0.82, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.58
bpy.ops.object.light_add(type="AREA", location=(-4.5, -5.5, 9.0))
bpy.context.object.data.energy = 1500
bpy.context.object.data.size = 5
bpy.ops.object.light_add(type="AREA", location=(5.5, 2, 7.0))
bpy.context.object.data.energy = 650
bpy.context.object.data.size = 4
bpy.ops.object.camera_add(location=(10.5, -11.6, 9.0))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 1.90)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 13.4
bpy.context.scene.camera = camera
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1280
bpy.context.scene.render.resolution_y = 1100
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = str(OUT / "sz_park_bookbar_cafe_preview.png")
bpy.ops.render.render(write_still=True)

camera.location = (5.8, -9.8, 4.9)
camera.rotation_euler = (Vector((0, -0.35, 1.54)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.ortho_scale = 9.1
bpy.context.scene.render.filepath = str(OUT / "sz_park_bookbar_cafe_service_preview.png")
bpy.ops.render.render(write_still=True)
print("ART_ASSET_READY:" + str(OUT / "sz_park_bookbar_cafe.glb"))
