"""Compact, wall-anchored pantry for the Talent Park restaurant kitchen.

Blender coordinates: +X points from the left wall into the kitchen, Y runs
along the wall, and Z is height.  The model origin rests on the existing floor.
The cabinet, shelves, vessels, towels and utensils share actual supports.
"""

import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_park_foods as food


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "models" / "kitchen"
SOURCE = ROOT / "tools" / "art" / "source" / "kitchen"
NAME = "park_kitchen_wall_pantry"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0

food.reset()
mat = food.mat
box = food.box
cylinder = food.cylinder
ellipsoid = food.ellipsoid
curve = food.curve_line
torus = food.torus

OAK = mat("wall_pantry_warm_oak", "#A68161", 0.79)
OAK_DARK = mat("wall_pantry_oak_endgrain", "#745B4A", 0.87)
OAK_LIGHT = mat("wall_pantry_shelf_edge", "#D3B693", 0.76)
CELADON = mat("wall_pantry_enamel", "#A2B9AB", 0.59)
CELADON_DARK = mat("wall_pantry_shadow_green", "#6D8D81", 0.74)
LINEN = mat("wall_pantry_cream_linen", "#EADCC2", 0.89)
LINEN_STRIPE = mat("wall_pantry_linen_hem", "#BA8672", 0.84)
CERAMIC = mat("wall_pantry_cream_ceramic", "#EFE4CE", 0.48)
GLASS = mat("wall_pantry_soft_glass", "#BED1C4", 0.29)
BRASS = mat("wall_pantry_brushed_brass", "#C4A176", 0.42, 0.38)
TEA = mat("wall_pantry_dried_tea", "#6F8970", 0.83)
RICE = mat("wall_pantry_rice", "#E8D8B0", 0.84)
CHILLI = mat("wall_pantry_dried_chilli", "#B7755C", 0.80)
PAPER = mat("wall_pantry_unbleached_label", "#E2D2B2", 0.92)


def hook(y, z):
    # Hook stalk meets the peg rail.  Its upward tip retains the hung object.
    cylinder("peg_hook_anchor", (0.47, y, z), 0.055, 0.028, BRASS, 12).rotation_euler.y = math.pi / 2
    curve("peg_hook_curved_steel", [(0.47, y, z), (0.56, y, z - 0.016),
                                    (0.575, y, z - 0.085), (0.54, y, z - 0.080)], 0.012, BRASS)


def jar(y, contents, height, radius):
    # Jar base is z=1.01, exactly on the upper shelf.
    x = 0.27
    z0 = 1.012
    cylinder("jar_contact_foot", (x, y, z0 + 0.021), radius * 0.91, 0.042, GLASS, 20)
    cylinder("jar_visible_contents", (x, y, z0 + height * 0.43), radius,
             height * 0.78, contents, 20)
    cylinder("jar_clear_neck", (x, y, z0 + height * 0.86), radius, 0.055, GLASS, 20)
    torus("jar_glass_rim", (x, y, z0 + height * 0.90), radius, 0.013, CERAMIC, 20)
    cylinder("jar_lid", (x, y, z0 + height * 0.95), radius * 0.95, 0.060, OAK_LIGHT, 20)
    box("jar_label", (x + radius + 0.005, y, z0 + height * 0.49),
        (0.010, radius * 1.65, 0.072), PAPER, 0.004)
    box("jar_label_color_mark", (x + radius + 0.012, y, z0 + height * 0.49),
        (0.004, radius * 0.52, 0.024), contents, 0.002)


def woven_bin(y, pigment):
    # Two short open bins sit on the lower shelf, with slats and contact bases.
    x, z0 = 0.28, 0.67
    box("woven_bin_base", (x, y, z0 + 0.020), (0.39, 0.56, 0.040), OAK_DARK, 0.012)
    for dy in (-0.25, 0.25):
        box("woven_bin_end_rail", (x, y + dy, z0 + 0.115),
            (0.39, 0.035, 0.18), OAK, 0.009)
    for dx in (-0.17, 0.17):
        box("woven_bin_long_rail", (x + dx, y, z0 + 0.115),
            (0.035, 0.54, 0.18), OAK_LIGHT, 0.009)
    for dy in (-0.16, -0.05, 0.06, 0.17):
        box("woven_bin_cross_weave", (x + 0.190, y + dy, z0 + 0.125),
            (0.012, 0.024, 0.14), OAK_DARK, 0.003)
    for dy in (-0.13, 0.11):
        ellipsoid("woven_bin_visible_produce", (x + 0.01, y + dy, z0 + 0.13),
                  (0.13, 0.10, 0.085), pigment, 16, 9)


# Continuous back panel and structural side rails give the assembly a visibly
# fixed home on the left wall.  Local X=-0.08 slightly interpenetrates that wall.
box("wall_anchor_backboard", (-0.028, 0, 1.00), (0.085, 2.40, 1.72), CELADON, 0.018)
for y in (-1.17, 1.17):
    box("wall_anchor_vertical_oak", (0.032, y, 0.99),
        (0.16, 0.073, 1.73), OAK_DARK, 0.015)
    for z in (0.42, 1.41):
        cylinder("countersunk_wall_screw", (0.073, y, z), 0.021, 0.013, BRASS, 12).rotation_euler.y = math.pi / 2

# Base cupboard rests on the floor; doors and pulls face into the room (+X).
box("base_cupboard_plinth", (0.22, 0, 0.077), (0.57, 2.24, 0.155), OAK_DARK, 0.018)
box("base_cupboard_body", (0.19, 0, 0.333), (0.58, 2.27, 0.49), OAK, 0.031)
for y in (-0.56, 0.56):
    box("cabinet_recessed_door", (0.495, y, 0.343),
        (0.031, 1.045, 0.386), CELADON, 0.014)
    box("cabinet_door_inner_panel", (0.513, y, 0.343),
        (0.012, 0.88, 0.291), CELADON_DARK, 0.009)
    box("cabinet_door_refined_face", (0.521, y, 0.343),
        (0.011, 0.83, 0.245), CELADON, 0.008)
    cylinder("brass_pull_socket", (0.545, y + (0.30 if y < 0 else -0.30), 0.34),
             0.032, 0.026, BRASS, 12).rotation_euler.y = math.pi / 2
box("base_cupboard_worktop", (0.24, 0, 0.599), (0.65, 2.39, 0.090), OAK_LIGHT, 0.032)
box("worktop_front_inlaid_edge", (0.565, 0, 0.593), (0.024, 2.22, 0.045), OAK_DARK, 0.006)

# Above the cupboard, shelves project into the room and are physically held by
# vertical uprights and brackets.  Nothing is suspended in open space.
for z in (0.643, 0.992, 1.465):
    box("open_shelf_plank", (0.267, 0, z), (0.63, 2.40, 0.063), OAK_LIGHT, 0.024)
    box("open_shelf_front_rail", (0.568, 0, z + 0.025),
        (0.027, 2.30, 0.075), OAK, 0.010)
    for y in (-1.01, 1.01):
        box("shelf_support_bracket", (0.218, y, z - 0.105),
            (0.40, 0.045, 0.135), OAK_DARK, 0.008)

# Open lower shelf bins and a towel folded onto the actual top of one bin.
woven_bin(-0.62, TEA)
woven_bin(0.60, CHILLI)
box("folded_flourcloth_on_shelf", (0.22, 0, 0.676),
    (0.42, 0.31, 0.040), LINEN, 0.011)
box("cloth_woven_hem", (0.22, -0.12, 0.700),
    (0.38, 0.025, 0.005), LINEN_STRIPE, 0.002)

# Three jars on the upper shelf; the back wall remains visible through them.
jar(-0.69, TEA, 0.33, 0.12)
jar(-0.16, RICE, 0.38, 0.14)
jar(0.42, CHILLI, 0.30, 0.125)

# Slim enamel tea tin gives a non-round silhouette, and a potted herb adds a
# living shape at one end while being supported by the same shelf.
box("enamel_tea_tin", (0.27, 0.84, 1.177), (0.29, 0.27, 0.32), CELADON_DARK, 0.039)
box("enamel_tea_tin_lid", (0.27, 0.84, 1.351), (0.32, 0.30, 0.040), OAK_LIGHT, 0.022)
box("tea_tin_front_leaf_emblem", (0.422, 0.84, 1.175),
    (0.006, 0.105, 0.11), TEA, 0.003)

# Peg rail is under the upper cap.  Both hanging towels and ladle originate at
# visible hooks and terminate above the next shelf, not mid-air.
box("peg_rail_screwed_to_back", (0.115, 0, 1.795),
    (0.135, 2.14, 0.075), OAK, 0.015)
for y in (-0.74, -0.31, 0.22, 0.73):
    hook(y, 1.78)
for y, tint in ((-0.74, LINEN), (-0.31, CELADON_DARK)):
    box("tea_towel_fold_at_hook", (0.523, y, 1.740),
        (0.075, 0.115, 0.035), tint, 0.009)
    box("tea_towel_hanging_fabric", (0.550, y, 1.633),
        (0.026, 0.15, 0.224), tint, 0.010)
    box("tea_towel_lower_hem", (0.568, y, 1.527),
        (0.006, 0.15, 0.020), LINEN_STRIPE, 0.002)
for y in (0.22, 0.73):
    curve("hanging_utensil_handle", [(0.54, y, 1.72), (0.57, y, 1.64),
                                     (0.575, y, 1.555)], 0.012, BRASS)
    if y < 0.5:
        ellipsoid("hanging_ladle_bowl", (0.579, y, 1.532),
                  (0.07, 0.077, 0.021), CERAMIC, 18, 9)
    else:
        box("hanging_flat_spatula", (0.58, y, 1.555),
            (0.020, 0.155, 0.095), OAK_LIGHT, 0.011)

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (NAME + ".blend")))
bpy.ops.export_scene.gltf(filepath=str(OUT / (NAME + ".glb")), export_format="GLB")

# Preview floor and wall are rendered but excluded from the exported model.
studio_floor = mat("PREVIEW_ONLY_floor", "#D6DCCF", 0.96)
studio_wall = mat("PREVIEW_ONLY_wall", "#A3B9AC", 0.94)
box("PREVIEW_ONLY_floor", (0.23, 0, -0.08), (1.60, 3.2, 0.13), studio_floor)
box("PREVIEW_ONLY_wall", (-0.105, 0, 1.02), (0.10, 3.00, 2.1), studio_wall)
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.84, 0.87, 0.82, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.47
bpy.ops.object.light_add(type="AREA", location=(2.8, -2.1, 3.1))
bpy.context.object.data.energy = 340
bpy.context.object.data.size = 2.6
bpy.ops.object.light_add(type="AREA", location=(1.0, 1.9, 2.2))
bpy.context.object.data.energy = 120
bpy.context.object.data.size = 1.8
bpy.ops.object.camera_add(location=(3.9, -3.4, 3.7))
camera = bpy.context.object
camera.rotation_euler = (Vector((0.18, 0, 0.88)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 3.7
bpy.context.scene.camera = camera
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1100
scene.render.resolution_y = 750
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / (NAME + "_preview.png"))
bpy.ops.render.render(write_still=True)
print("PARK_KITCHEN_WALL_PANTRY_READY:" + NAME)
