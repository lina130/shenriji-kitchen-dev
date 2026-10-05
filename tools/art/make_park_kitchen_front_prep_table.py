"""One-piece 14.0 m front prep table for the Talent Park restaurant.

The table supplies architecture and empty landing pads only. Dynamic stock,
combined dishes, buffer plates and pickup food are attached in Godot.
Blender +Z is height; local -Y faces the player (Godot +Z after GLB import).
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_park_foods as food

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "models" / "kitchen"
SOURCE = ROOT / "tools" / "art" / "source" / "kitchen"
NAME = "park_kitchen_front_prep_table"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
food.reset()

mat = food.mat
box = food.box
cylinder = food.cylinder
ellipsoid = food.ellipsoid
torus = food.torus
curve = food.curve_line

OAK = mat("front_table_warm_oak", "#A37D60", 0.79)
OAK_LIGHT = mat("front_table_blonde_oak", "#C5A47D", 0.79)
OAK_DEEP = mat("front_table_endgrain", "#735643", 0.88)
STONE = mat("front_table_warm_stone", "#D8C9AB", 0.57)
STONE_LIGHT = mat("front_table_worktop_field", "#E7DCC4", 0.63)
STONE_CUT = mat("front_table_inset_shadow", "#AE9C80", 0.79)
CELADON = mat("front_table_celadon", "#9BB7AA", 0.55)
CELADON_DEEP = mat("front_table_celadon_reveal", "#658A7D", 0.69)
CREAM = mat("front_table_ceramic_cream", "#EEE5D2", 0.49)
BRASS = mat("front_table_brushed_brass", "#B99A71", 0.46, 0.28)
LINEN = mat("front_table_unbleached_linen", "#E4D5BA", 0.89)
CORAL = mat("front_table_soft_coral_mark", "#C9917D", 0.67)


# An open underframe and individual fronts give the long unit a believable
# furniture rhythm in the fixed top-down camera.  Six bays have real reveals,
# short plinth feet and leg frames rather than one unbroken cuboid.
for i in range(7):
    x = -6.82 + i * (13.64 / 6)
    box(f"leg_post_{i}", (x, -0.01, 0.325),
        (0.140, 1.71, 0.61), OAK_DEEP, 0.031)
    box(f"quiet_floor_foot_{i}", (x, 0.07, 0.055),
        (0.185, 1.53, 0.085), OAK_DEEP, 0.026)
for i in range(6):
    x = -5.683 + i * (13.64 / 6)
    box(f"separate_cabinet_bay_{i}", (x, 0.07, 0.352),
        (2.08, 1.60, 0.557), OAK, 0.056)
    # A quiet shadow reveal makes each cabinet read as one piece from above.
    box(f"bay_shadow_recess_{i}", (x, -0.750, 0.355),
        (1.90, 0.015, 0.437), OAK_DEEP, 0.013)
    front = CELADON if i in (0, 1, 4) else OAK_LIGHT
    box(f"cabinet_door_{i}", (x, -0.783, 0.357),
        (1.78, 0.028, 0.405), front, 0.028)
    box(f"cabinet_inset_border_{i}", (x, -0.803, 0.357),
        (1.55, 0.006, 0.302), OAK if i in (0, 1, 4) else OAK_DEEP, 0.012)
    box(f"cabinet_inset_field_{i}", (x, -0.810, 0.357),
        (1.45, 0.007, 0.223), front, 0.010)
    cylinder(f"cabinet_round_pull_{i}", (x + 0.66, -0.838, 0.35),
             0.045, 0.025, BRASS, 16).rotation_euler.x = math.pi / 2

# Two continuous stretchers link the bays structurally but leave a recessed
# toe line so the silhouette is more than a slab on the floor.
box("recessed_rear_stretcher", (0, 0.79, 0.126),
    (13.70, 0.083, 0.115), OAK_DEEP, 0.022)
box("quiet_upper_apron_front", (0, -0.820, 0.623),
    (13.74, 0.040, 0.052), OAK_DEEP, 0.020)
box("deep_upper_apron_back", (0, 0.857, 0.623),
    (13.74, 0.080, 0.080), OAK, 0.027)


# A connected 14.0 x 2.05 m stone counter with raised physical landing boards.
# The underlying stone is lower so the game-owned bowls meet the boards at
# precisely 0.722 m, rather than hovering above a painted tabletop outline.
box("continuous_rounded_stone_top", (0, 0, 0.629),
    (14.00, 2.05, 0.092), STONE, 0.058)
box("satin_worktop_center_field", (0, 0, 0.679),
    (13.72, 1.79, 0.009), STONE_LIGHT, 0.009)
for y in (-0.985, 0.985):
    box("inlaid_brass_narrow_edge", (0, y, 0.666),
        (13.60, 0.014, 0.008), BRASS, 0.004)
for x in (-6.88, 6.88):
    box("stone_endgrain_cap", (x, 0, 0.667),
        (0.043, 1.80, 0.024), STONE, 0.010)


def landing_pad(label, cx, cy, width, depth, under, edge):
    """Low solid board: its upper face is the dynamic food landing height."""
    box(label + "_dark_separation_edge", (cx, cy, 0.694),
        (width, depth, 0.034), under, 0.024)
    box(label + "_full_thickness_linen_board", (cx, cy, 0.715),
        (width - 0.075, depth - 0.075, 0.014), LINEN, 0.019)
    box(label + "_low_front_edge", (cx, cy - depth * 0.475, 0.702),
        (width - 0.060, 0.025, 0.029), edge, 0.010)
    # Rear bead and two short corner bumpers are outside the food footprint.
    box(label + "_rear_stop", (cx, cy + depth * 0.47, 0.735),
        (width - 0.075, 0.035, 0.051), edge, 0.012)
    for side in (-1, 1):
        box(label + f"_corner_bumper_{side}",
            (cx + side * width * 0.48, cy - depth * 0.41, 0.740),
            (0.045, 0.15, 0.055), edge, 0.012)


# LEFT: two prep/half-finished stock stations. Their insets are empty on export.
landing_pad("left_rice_batter_stock", -5.65, 0.0, 1.56, 1.50, CELADON_DEEP, CELADON)
landing_pad("left_spice_oil_stock", -3.83, 0.0, 1.56, 1.50, CELADON_DEEP, CELADON)
for i, x in enumerate((-5.65, -3.83)):
    box(f"stock_bay_{i}_metal_slide", (x, -0.851, 0.611),
        (1.34, 0.020, 0.047), BRASS, 0.012)
    for side in (-1, 1):
        box(f"stock_bay_{i}_drawer_guide_{side}",
            (x + side * 0.72, -0.03, 0.710),
            (0.018, 1.27, 0.010), OAK_LIGHT, 0.005)


# CENTRE: a broad two-course board and a separate single-dish buffer board.
# Their interior surfaces remain completely open for the dynamic tray models.
landing_pad("two_course_combo", -0.75, 0.0, 3.70, 1.55,
            STONE_CUT, OAK_LIGHT)
landing_pad("single_dish_buffer", 2.20, 0.0, 1.65, 1.52,
            STONE_CUT, OAK_LIGHT)
for x, accent in ((-1.58, CELADON_DEEP), (0.08, CORAL), (2.20, CELADON_DEEP)):
    box("service_board_front_inlay", (x, -0.793, 0.720),
        (0.49, 0.013, 0.009), accent, 0.004)


# RIGHT: broad empty handoff pad; small service tools sit only in its rear
# corner, away from a future dynamically positioned finished plate.
landing_pad("finished_handoff", 5.18, 0.0, 3.10, 1.58,
            CELADON_DEEP, OAK_LIGHT)
box("pickup_corner_ticket_clip_base", (6.62, 0.82, 0.737),
    (0.23, 0.115, 0.055), OAK_DEEP, 0.017)
box("pickup_corner_spring_clip", (6.62, 0.82, 0.782),
    (0.10, 0.090, 0.036), BRASS, 0.014)
box("small_service_bell_foot", (6.85, -0.83, 0.730),
    (0.20, 0.20, 0.029), OAK, 0.012)
ellipsoid("small_service_bell_dome", (6.85, -0.83, 0.772),
          (0.092, 0.092, 0.055), BRASS, 16, 9)
ellipsoid("small_service_bell_button", (6.85, -0.83, 0.825),
          (0.029, 0.029, 0.012), OAK_DEEP, 10, 7)


# Front-facing towel bar and folded napkins add service detail without putting
# loose dishes on the tabletop where stateful food models must appear.
for x in (3.22, 3.78):
    cylinder("front_towel_bar_anchor", (x, -0.856, 0.47),
             0.027, 0.035, BRASS, 12).rotation_euler.x = math.pi / 2
curve("continuous_front_towel_rail", [(3.22, -0.891, 0.47),
                                      (3.48, -0.920, 0.46),
                                      (3.78, -0.891, 0.47)], 0.010, BRASS)
for i in range(3):
    box(f"folded_napkin_{i}", (3.38 + i * 0.10, -0.899, 0.362 - i * 0.012),
        (0.28, 0.032, 0.16), LINEN, 0.011)
    box(f"folded_napkin_hem_{i}",
        (3.38 + i * 0.10, -0.919, 0.295 - i * 0.012),
        (0.25, 0.006, 0.012), CORAL, 0.003)


bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (NAME + ".blend")))
bpy.ops.export_scene.gltf(filepath=str(OUT / (NAME + ".glb")), export_format="GLB")

# Presentation floor/lights/camera exist only in the preview, not in the GLB.
box("PREVIEW_ONLY_floor", (0, 0, -0.075),
    (16.0, 4.0, 0.13), mat("PREVIEW_ONLY_neutral_floor", "#D7DBD0", 0.95))
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.83, 0.86, 0.81, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.49
bpy.ops.object.light_add(type="AREA", location=(-5.8, -4.3, 5.2))
bpy.context.object.data.energy = 620
bpy.context.object.data.size = 6.0
bpy.ops.object.light_add(type="AREA", location=(5.4, 2.8, 4.7))
bpy.context.object.data.energy = 380
bpy.context.object.data.size = 5.0
bpy.ops.object.camera_add(location=(8.5, -13.0, 10.5))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0.35)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 17.0
bpy.context.scene.camera = camera
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = 830
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / (NAME + "_preview.png"))
bpy.ops.render.render(write_still=True)
camera.location = (0, -6.0, 15.0)
camera.rotation_euler = (Vector((0, 0, 0.35)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.ortho_scale = 15.3
scene.render.filepath = str(OUT / (NAME + "_top_preview.png"))
bpy.ops.render.render(write_still=True)
print("PARK_KITCHEN_FRONT_PREP_TABLE_READY:" + NAME)
