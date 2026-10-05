"""Low wall-backed prep console, readable from the kitchen's top-down camera.

The original tall shelf presented its thin side and cast jagged shadows.  This
unit has a broad working top with three distinct prep zones and a low backstop.
Local +X projects from the left wall into the room; local Y follows the wall.
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
NAME = "park_kitchen_wall_prep_console"
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

OAK = mat("prep_console_oiled_oak", "#A68161", 0.80)
OAK_REVEAL = mat("prep_console_oak_reveal", "#765A49", 0.88)
OAK_LIGHT = mat("prep_console_oak_edge", "#CEB18C", 0.74)
STONE = mat("prep_console_cream_stone", "#DCCDB0", 0.55)
STONE_INSET = mat("prep_console_stone_inset", "#E9DDC4", 0.61)
CELADON = mat("prep_console_muted_celadon", "#A5C2B0", 0.52)
CELADON_DARK = mat("prep_console_deep_celadon", "#678F7B", 0.68)
PORCELAIN = mat("prep_console_warm_porcelain", "#F1E7D2", 0.47)
BRASS = mat("prep_console_brushed_brass", "#BD9F72", 0.42, 0.25)
PAPER = mat("prep_console_butter_paper", "#E7D8B7", 0.87)
HERBS = mat("prep_console_fresh_herb", "#6B9B72", 0.79)
HERBS_PALE = mat("prep_console_pale_herb", "#A7BD89", 0.78)
CARROT = mat("prep_console_chopped_root", "#D68C5C", 0.73)
RICE = mat("prep_console_rice", "#E8DAB6", 0.80)
SPICE = mat("prep_console_chilli_oil", "#AF7059", 0.58)


# One continuous architectural mass and shallow toe recess; no elevated
# horizontal shelf slabs occlude the working surface from above.
box("setback_floor_plinth", (0.29, 0, 0.052),
    (0.67, 2.22, 0.104), OAK_REVEAL, 0.028)
box("rounded_low_cabinet_carcass", (0.32, 0, 0.345),
    (0.74, 2.35, 0.59), OAK, 0.048)
for y in (-0.78, 0, 0.78):
    box("enamel_cabinet_door", (0.701, y, 0.36),
        (0.035, 0.695, 0.47), CELADON, 0.020)
    box("door_inset_face", (0.721, y, 0.36),
        (0.012, 0.60, 0.36), CELADON_DARK, 0.014)
    box("fine_front_panel", (0.729, y, 0.36),
        (0.011, 0.55, 0.29), CELADON, 0.010)
    cylinder("small_brass_pull", (0.751, y + 0.20, 0.36),
             0.025, 0.028, BRASS, 12).rotation_euler.y = math.pi / 2
box("single_bullnose_stone_worktop", (0.35, 0, 0.687),
    (0.88, 2.48, 0.092), STONE, 0.040)
box("worktop_satin_inset", (0.36, 0, 0.738),
    (0.79, 2.37, 0.015), STONE_INSET, 0.012)
box("low_sage_backstop", (-0.073, 0, 0.84),
    (0.095, 2.45, 0.23), CELADON, 0.024)
box("backstop_oak_cap", (-0.073, 0, 0.978),
    (0.105, 2.44, 0.041), OAK_LIGHT, 0.016)
for y in (-1.12, 1.12):
    box("backstop_end_cap", (-0.055, y, 0.83),
        (0.15, 0.06, 0.28), OAK, 0.016)


# Zone 1: leafy prep in a low crate.  Distinct stems and individual blades
# project above the tray, rather than a line of generic green beads.
box("herb_tray_recess", (0.36, -0.79, 0.766),
    (0.65, 0.64, 0.035), OAK_REVEAL, 0.018)
box("herb_tray_liner", (0.36, -0.79, 0.787),
    (0.59, 0.57, 0.012), CELADON_DARK, 0.012)
for yy in (-1.03, -0.85, -0.67):
    for xx in (0.20, 0.40, 0.56):
        curve("visible_pale_herb_stem",
              [(xx, yy - 0.07, 0.803), (xx + 0.025, yy, 0.837),
               (xx + 0.038, yy + 0.070, 0.823)], 0.006, HERBS_PALE)
        leaf = ellipsoid("separate_herb_leaf", (xx + 0.038, yy + 0.065, 0.831),
                         (0.049, 0.081, 0.019), HERBS, 12, 8)
        leaf.rotation_euler.z = 0.21 if xx > 0.3 else -0.18


# Zone 2: an actual chopping board with two ingredient colours, a knife, and
# a folded cloth.  It reads as work in progress from overhead.
box("oiled_chopping_board", (0.37, 0.0, 0.777),
    (0.62, 0.64, 0.052), OAK_LIGHT, 0.045)
box("cut_board_inset", (0.37, 0, 0.806),
    (0.54, 0.56, 0.006), OAK, 0.007)
for yy in (-0.17, -0.04, 0.10):
    for xx in (0.19, 0.30, 0.41):
        ellipsoid("diced_chilli_or_carrot", (xx, yy, 0.828),
                  (0.031, 0.023, 0.020), CARROT, 10, 7)
for yy in (-0.13, 0.01, 0.13):
    for xx in (0.49, 0.55):
        ellipsoid("cut_scallion_piece", (xx, yy, 0.824),
                  (0.025, 0.016, 0.013), HERBS, 10, 7)
box("short_chef_knife_blade", (0.49, 0.26, 0.815),
    (0.26, 0.038, 0.012), PORCELAIN, 0.006)
box("short_chef_knife_handle", (0.26, 0.26, 0.818),
    (0.21, 0.050, 0.025), OAK_REVEAL, 0.012)


# Zone 3: open rice bowl, square ingredient canister and a narrow seasoning
# bottle, all seated on the same top and clear of the prep worker's walkway.
ellipsoid("rice_bowl_rounded_base", (0.27, 0.79, 0.818),
          (0.21, 0.21, 0.068), PORCELAIN, 20, 11)
ellipsoid("rice_bowl_visible_rice", (0.27, 0.79, 0.867),
          (0.176, 0.176, 0.029), RICE, 20, 10)
torus("rice_bowl_rolled_celadon_rim", (0.27, 0.79, 0.851),
      0.205, 0.016, CELADON, 24)
for angle in (0, 1.6, 3.3, 4.7):
    ellipsoid("individual_rice_grain", (0.27 + math.cos(angle) * 0.080,
                                        0.79 + math.sin(angle) * 0.075, 0.894),
              (0.019, 0.009, 0.007), PORCELAIN, 9, 7)
box("square_flour_canister", (0.62, 0.73, 0.879),
    (0.18, 0.19, 0.19), PAPER, 0.018)
box("flour_canister_folded_lid", (0.62, 0.73, 0.987),
    (0.20, 0.21, 0.036), OAK_LIGHT, 0.011)
cylinder("seasoning_bottle_body", (0.62, 1.06, 0.876),
         0.075, 0.18, SPICE, 16)
cylinder("seasoning_bottle_cap", (0.62, 1.06, 0.985),
         0.081, 0.046, OAK, 16)


bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (NAME + ".blend")))
bpy.ops.export_scene.gltf(filepath=str(OUT / (NAME + ".glb")), export_format="GLB")

# Neutral preview walls are not exported.
box("PREVIEW_ONLY_floor", (0.25, 0, -0.065),
    (1.8, 3.0, 0.12), mat("PREVIEW_ONLY_floor_mat", "#D7DCCF", 0.95))
box("PREVIEW_ONLY_wall", (-0.15, 0, 0.67),
    (0.08, 2.8, 1.45), mat("PREVIEW_ONLY_wall_mat", "#A6BAAB", 0.91))
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.84, 0.87, 0.82, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.45
bpy.ops.object.light_add(type="AREA", location=(2.8, -2.4, 3.0))
bpy.context.object.data.energy = 310
bpy.context.object.data.size = 2.5
bpy.ops.object.light_add(type="AREA", location=(1.0, 1.8, 2.2))
bpy.context.object.data.energy = 110
bpy.context.object.data.size = 2.0
bpy.ops.object.camera_add(location=(2.8, -3.5, 3.1))
camera = bpy.context.object
camera.rotation_euler = (Vector((0.30, 0, 0.66)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 3.4
bpy.context.scene.camera = camera
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1100
scene.render.resolution_y = 750
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / (NAME + "_preview.png"))
bpy.ops.render.render(write_still=True)
print("PARK_KITCHEN_WALL_PREP_CONSOLE_READY:" + NAME)
