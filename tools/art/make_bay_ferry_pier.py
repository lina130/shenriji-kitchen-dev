"""Original miniature Greater Bay ferry landing, shore at local -Y.

Editable metre-scale geometry is kept in a Blend source. The GLB is a single
landing module with an open pedestrian route between shore and boarding deck.
Review lights and water backdrop are added only after the game export.
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


def material(name, hex_value, roughness=0.75, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = srgb(hex_value)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = srgb(hex_value)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


limestone = material("warm_limestone_boardwalk_entry", "#C8BDA7", 0.92)
limestone_edge = material("worn_stone_edge", "#AAA48F", 0.91)
cream = material("painted_cream_booth", "#EFE5D3", 0.83)
cream_shadow = material("painted_cream_recess", "#D6D4C4", 0.88)
jade = material("oxidized_coastal_jade", "#5F9B93", 0.69, 0.14)
jade_lit = material("sunlit_oxidized_jade", "#81B3A9", 0.69, 0.13)
jade_dark = material("pier_shadow_green", "#3E726F", 0.65, 0.22)
navy = material("coastal_navy_trim", "#405E71", 0.68)
glass = material("ferry_window_blue_glass", "#83B8BF", 0.23, 0.06)
glass_dark = material("window_reflection_teal", "#5B93A1", 0.30, 0.09)
deck = material("salt_worn_walnut_planks", "#A97F5B", 0.82)
deck_light = material("sunlit_deck_planks", "#C29770", 0.80)
deck_gap = material("deck_seams", "#796F63", 0.92)
steel = material("brushed_stainless_rails", "#A8B8B8", 0.38, 0.72)
steel_dark = material("pier_dark_metalwork", "#546B70", 0.5, 0.60)
brass = material("aged_marine_brass", "#C9AB6F", 0.4, 0.57)
coral = material("safety_coral_red", "#D87C6B", 0.76)
white = material("life_buoy_cream", "#F5EBDA", 0.73)
rubber = material("weathered_black_fender", "#40494C", 0.95)
paper = material("timetable_paper", "#EFE8D8", 0.78)
lantern = material("warm_lamp_globe", "#F6D6A0", 0.35)


def bevel(obj, radius):
    if radius <= 0:
        return obj
    modifier = obj.modifiers.new("soft_edges", "BEVEL")
    modifier.width = radius
    modifier.segments = 3
    modifier.limit_method = "ANGLE"
    normal = obj.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def box(name, xyz, dims, mat, radius=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return bevel(obj, radius)


def cylinder(name, xyz, radius, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return bevel(obj, 0.012)


def ellipsoid(name, xyz, scale, mat, segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def rod(name, start, end, radius, mat, vertices=12):
    direction = Vector(end) - Vector(start)
    centre = (Vector(start) + Vector(end)) / 2
    obj = cylinder(name, centre, radius, direction.length, mat, vertices)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def shaped_mesh(name, verts, faces, mat, thickness=0):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if thickness:
        solid = obj.modifiers.new("profile_thickness", "SOLIDIFY")
        solid.thickness = thickness
        bevel(obj, 0.018)
    return obj


# A ten-metre class intercity landing. The first strip continues the city
# pavement; the long second deck projects into actual world water. Nothing
# blocks the central route x=-1.25..1.25 metres.
box("shore_limestone_apron", (0, -3.60, 0.15), (8.72, 2.20, 0.30), limestone, 0.11)
box("shore_curb_satin", (0, -4.68, 0.26), (8.72, 0.17, 0.18), limestone_edge, 0.055)
box("pier_structural_deck", (0, 1.10, 0.19), (8.72, 8.18, 0.38), deck_gap, 0.08)
for i in range(17):
    y = -2.74 + i * 0.48
    box(f"oak_deck_plank_{i:02}", (0, y, 0.404), (8.58, 0.43, 0.075),
        deck_light if i % 4 == 0 else deck, 0.025)
    for x in (-3.94, 3.94):
        cylinder(f"deck_bolt_{i:02}_{x}", (x, y, 0.449), 0.025, 0.008, steel, 10)
for x in (-3.55, 3.55):
    box(f"deck_side_beam_{x}", (x, 1.14, -0.09), (0.31, 8.27, 0.52), navy, 0.07)
    for y in (-2.6, -0.2, 2.2, 4.65):
        cylinder(f"water_piling_{x}_{y}", (x, y, -0.64), 0.18, 1.70, steel_dark, 18)
        cylinder(f"pile_wear_ring_{x}_{y}", (x, y, -0.11), 0.20, 0.10, rubber, 18)

# Cream ticket booths frame a real opening; glazing, interior depth, ticket
# trays, wall lamps and queuing bars make the pier useful at close zoom.
for side, x in (("left", -2.83), ("right", 2.83)):
    box(f"ticket_booth_body_{side}", (x, -1.34, 1.52), (2.28, 2.53, 2.62), cream, 0.11)
    box(f"ticket_booth_plinth_{side}", (x, -1.34, 0.47), (2.39, 2.65, 0.31), limestone_edge, 0.05)
    box(f"ticket_window_recess_{side}", (x, -2.625, 1.77), (1.77, 0.070, 1.27), jade_dark, 0.04)
    box(f"ticket_window_glass_{side}", (x, -2.672, 1.79), (1.60, 0.024, 1.11), glass, 0.015)
    box(f"ticket_window_reflection_{side}", (x - 0.42, -2.693, 1.89),
        (0.14, 0.012, 0.95), glass_dark, 0.006)
    box(f"ticket_window_mullion_{side}", (x, -2.711, 1.76), (0.054, 0.06, 1.24), steel, 0.013)
    box(f"ticket_counter_{side}", (x, -2.76, 1.105), (2.09, 0.34, 0.17), deck_light, 0.055)
    box(f"ticket_slot_{side}", (x, -2.957, 1.20), (0.30, 0.021, 0.035), steel_dark, 0.009)
    box(f"ticket_tray_{side}", (x, -2.83, 1.24), (0.46, 0.16, 0.035), steel, 0.015)
    box(f"booth_side_window_{side}",
        (x + (-1.15 if x < 0 else 1.15), -1.48, 1.81),
        (0.048, 1.55, 1.00), glass, 0.018)
    for z in (0.98, 2.55):
        box(f"booth_sill_{side}_{z}", (x, -2.751, z), (2.16, 0.26, 0.10),
            jade if z > 2 else limestone, 0.027)
    box(f"booth_wall_lamp_bracket_{side}", (x, -2.765, 2.66), (0.08, 0.12, 0.28), brass, 0.016)
    ellipsoid(f"booth_wall_lamp_globe_{side}", (x, -2.83, 2.48), (0.12, 0.12, 0.12), lantern)

# Rounded maritime roof: two curved slopes, inset lighter facets, raised ridge
# and ribs. The sculpted section gives the building a memorable skyline.
roof_y0, roof_y1 = -3.20, 0.88
for side in (-1, 1):
    for i in range(9):
        x0 = i * 3.91 / 9
        x1 = (i + 1) * 3.91 / 9
        z0 = 4.22 - 0.82 * (x0 / 3.91) ** 1.75
        z1 = 4.22 - 0.82 * (x1 / 3.91) ** 1.75
        shaped_mesh(f"curved_jade_roof_{side}_{i:02}",
                    [(side * x0, roof_y0, z0), (side * x1, roof_y0, z1),
                     (side * x1, roof_y1, z1), (side * x0, roof_y1, z0)],
                    [(0, 1, 2, 3)], jade_lit if i % 4 == 0 else jade, 0.10)
        if i in (0, 3, 6, 8):
            rod(f"roof_long_rib_{side}_{i:02}",
                (side * x1, roof_y0, z1 + 0.07),
                (side * x1, roof_y1, z1 + 0.07), 0.026, steel)
    rod(f"roof_eave_{side}", (side * 3.91, roof_y0, 3.35),
        (side * 3.91, roof_y1, 3.35), 0.075, jade_dark)
box("roof_central_crest", (0, -1.16, 4.26), (0.46, 4.30, 0.13), jade_dark, 0.06)
for y in (-3.10, 0.78):
    for side in (-1, 1):
        # A swept cream gable band articulates the shore and waterside edges.
        for i in range(8):
            x0 = i * 3.85 / 8
            x1 = (i + 1) * 3.85 / 8
            z0 = 4.18 - 0.82 * (x0 / 3.85) ** 1.75
            z1 = 4.18 - 0.82 * (x1 / 3.85) ** 1.75
            rod(f"gable_cream_line_{y}_{side}_{i}",
                (side * x0, y, z0), (side * x1, y, z1), 0.044, cream)
for x in (-3.65, 3.65):
    for y in (roof_y0 + 0.14, roof_y1 - 0.10):
        rod(f"canopy_corner_post_{x}_{y}", (x, y, 0.42), (x, y, 3.45), 0.084, jade_dark)
        cylinder(f"post_brass_foot_{x}_{y}", (x, y, 0.50), 0.13, 0.11, brass, 16)

# Physical boat-and-wave relief on a real fascia, with no floating words.
box("front_maritime_sign_panel", (0, roof_y0 - 0.10, 3.55),
    (1.32, 0.15, 0.60), cream, 0.075)
shaped_mesh("boat_pictogram_hull", [(-0.36, -3.39, 3.50), (0.36, -3.39, 3.50),
                                     (0.23, -3.39, 3.39), (-0.23, -3.39, 3.39)],
            [(0, 1, 2, 3)], navy, 0.02)
box("boat_pictogram_cabin", (0, -3.42, 3.59), (0.31, 0.03, 0.17), navy, 0.018)
for x in (-0.28, 0, 0.28):
    ellipsoid(f"boat_wave_{x}", (x, -3.42, 3.30), (0.18, 0.017, 0.025), glass_dark)

# Covered queue lines, with a wide central accessible path left deliberately
# clear. Gold turnstile cylinders suggest service without closing the route.
for side, x in (("left", -1.15), ("right", 1.15)):
    for y in (-2.0, -1.25, -0.5):
        cylinder(f"queue_post_{side}_{y}", (x, y, 0.83), 0.042, 0.77, brass, 12)
        ellipsoid(f"queue_post_cap_{side}_{y}", (x, y, 1.22),
                  (0.065, 0.065, 0.045), brass)
    for i, y in enumerate((-1.625, -0.875)):
        rod(f"queue_bar_{side}_{i}", (x, y - 0.36, 1.06),
            (x, y + 0.36, 1.06), 0.025, steel)
for x in (-0.95, 0.95):
    cylinder(f"ticket_gate_{x}", (x, 0.30, 0.91), 0.15, 1.03, jade_dark, 16)
    ellipsoid(f"ticket_gate_top_{x}", (x, 0.30, 1.47),
              (0.17, 0.17, 0.08), steel)
    rod(f"ticket_gate_bar_{x}", (x, 0.30, 1.02), (x + (0.40 if x < 0 else -0.40),
        0.30, 1.02), 0.026, brass)

# Deck furniture readable from overview and walkable at closer zoom.
for side, x in (("west", -3.92), ("east", 3.92)):
    for i, y in enumerate((1.42, 2.61, 3.80, 4.99)):
        rod(f"waterside_rail_post_{side}_{i}", (x, y, 0.47),
            (x, y, 1.50), 0.042, steel)
        cylinder(f"waterside_post_foot_{side}_{i}", (x, y, 0.48),
                 0.085, 0.055, brass)
    for z in (1.02, 1.50):
        rod(f"waterside_rail_{side}_{z}", (x, 1.35, z),
            (x, 5.25, z), 0.034, steel)
    for y in (2.0, 4.55):
        cylinder(f"mooring_bollard_base_{side}_{y}",
                 (x - (0.42 if x > 0 else -0.42), y, 0.53),
                 0.17, 0.17, steel_dark)
        cylinder(f"mooring_bollard_cap_{side}_{y}",
                 (x - (0.42 if x > 0 else -0.42), y, 0.67),
                 0.24, 0.095, steel_dark)

# Hand-painted life rings on the side rail. The torus is a familiar rescue
# symbol and the four coral blocks are physical bands, not a flat texture.
for x, y in ((-3.94, 3.07), (3.94, 3.07)):
    bpy.ops.mesh.primitive_torus_add(major_segments=28, minor_segments=8,
                                     location=(x, y, 1.16), major_radius=0.21,
                                     minor_radius=0.057)
    ring = bpy.context.object
    ring.name = f"life_ring_{x}"
    ring.rotation_euler.y = math.pi / 2
    ring.data.materials.append(white)
    for dz in (-0.20, 0.20):
        box(f"ring_coral_band_{x}_{dz}",
            (x + (0.025 if x > 0 else -0.025), y, 1.16 + dz),
            (0.06, 0.10, 0.09), coral, 0.025)

for x in (-3.58, 3.58):
    for y in (1.18, 5.15):
        rod(f"deck_lantern_post_{x}_{y}", (x, y, 0.44),
            (x, y, 2.10), 0.055, jade_dark)
        ellipsoid(f"deck_lantern_globe_{x}_{y}",
                  (x, y, 2.18), (0.17, 0.17, 0.21), lantern)
        cylinder(f"deck_lantern_hat_{x}_{y}", (x, y, 2.36),
                 0.21, 0.09, jade_dark)

# Public information cabinet is a built object at the landing entrance; tiny
# route blocks and timetable lines stay on that object, never over the map.
box("route_board_frame", (-3.55, -3.77, 1.48), (0.13, 0.84, 1.67), jade_dark, 0.045)
box("route_board_paper", (-3.469, -3.77, 1.49),
    (0.017, 0.67, 1.38), paper, 0.011)
for i in range(5):
    box(f"route_board_line_{i}", (-3.45, -4.005 + i * 0.105, 1.87 - i * 0.17),
        (0.009, 0.085, 0.022), navy, 0.004)
box("route_board_top_accent", (-3.448, -3.77, 2.08),
    (0.012, 0.55, 0.047), coral, 0.006)

# Rubber fenders protect the deck tip and clearly separate it from a generic
# plaza. A small central lip indicates where a future ferry gangway connects.
for x in (-3.05, -1.75, 1.75, 3.05):
    box(f"tip_rubber_fender_{x}", (x, 5.27, 0.11),
        (0.46, 0.17, 0.36), rubber, 0.055)
box("gangway_connection_plate", (0, 5.36, 0.44),
    (2.70, 0.58, 0.08), steel, 0.035)
for x in (-1.20, 1.20):
    cylinder(f"gangway_hinge_{x}", (x, 5.23, 0.53), 0.12, 0.10, brass)

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "bay_ferry_pier.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "bay_ferry_pier.glb"),
                          export_format="GLB")

# Non-exported context for a readable isolated asset review.
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.78, 0.84, 0.86, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.54
review_water = material("preview_only_tidal_blue", "#87B6BD", 0.4)
box("PREVIEW_ONLY_WATER", (0, 1.65, -1.50), (13, 11, 0.05), review_water, 0.0)
bpy.ops.object.light_add(type="AREA", location=(-6, -7, 11))
bpy.context.object.data.energy = 1600
bpy.context.object.data.size = 6
bpy.ops.object.light_add(type="AREA", location=(6, 7, 8))
bpy.context.object.data.energy = 600
bpy.context.object.data.size = 5
bpy.ops.object.camera_add(location=(13, -15, 13))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0.3, 1.4)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 16.0
bpy.context.scene.camera = camera
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1250
bpy.context.scene.render.resolution_y = 1050
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = str(OUT / "bay_ferry_pier_preview.png")
bpy.ops.render.render(write_still=True)
print("ART_ASSET_READY:" + str(OUT / "bay_ferry_pier.glb"))
