"""Reusable rounded cafe counter and wash station for the kitchen diorama."""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_park_foods as food

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "models"
SOURCE = ROOT / "tools" / "art" / "source"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0

mat = food.mat
box = food.box
ellipsoid = food.ellipsoid
cylinder = food.cylinder
torus = food.torus
curve_line = food.curve_line


def park_cafe_counter_unit():
    """2.25×2.66m work counter with a 0.84m high stone top."""
    wood = mat("honey_oak_rounded_cabinet", "#AD8266", 0.84)
    wood_light = mat("cabinet_wood_panels", "#C29675", 0.85)
    wood_dark = mat("cabinet_deep_reveal", "#845F4C", 0.90)
    plinth = mat("cabinet_shadow_plinth", "#8B7765", 0.88)
    stone = mat("cream_stone_countertop", "#DDD0B7", 0.57)
    inset = mat("warm_worktop_inset", "#E9DDC7", 0.60)
    brass = mat("brushed_drawer_pull", "#B99D71", 0.44, 0.24)
    box("recessed_toe_plinth", (0, 0.040, 0.061),
        (2.04, 2.49, 0.119), plinth, 0.052)
    box("solid_oak_carcass", (0, 0, 0.398),
        (2.11, 2.52, 0.664), wood, 0.095)
    box("front_shadow_reveal", (0, -1.270, 0.399),
        (1.98, 0.024, 0.554), wood_dark, 0.045)
    for side, x in (("L", -0.500), ("R", 0.500)):
        box(f"{side}_rounded_door", (x, -1.296, 0.392),
            (0.857, 0.043, 0.508), wood_light, 0.065)
        for i in range(3):
            box(f"{side}_carved_vertical_grain_{i}",
                (x - 0.255 + i * 0.255, -1.323, 0.393),
                (0.013, 0.007, 0.395), wood, 0.006)
        box(f"{side}_rounded_pull", (x, -1.332, 0.424),
            (0.160, 0.021, 0.027), brass, 0.012)
    for side, x in (("L", -1.066), ("R", 1.066)):
        box(f"{side}_side_panel_inset", (x, -0.02, 0.40),
            (0.018, 2.32, 0.488), wood_light, 0.039)
        for y in (-0.73, 0, 0.73):
            box(f"{side}_side_grain_{y}", (x + (-0.013 if x < 0 else 0.013),
                                          y, 0.390),
                (0.011, 0.018, 0.355), wood, 0.004)
    box("thick_bullnose_stone_top", (0, 0, 0.775),
        (2.247, 2.655, 0.128), stone, 0.062)
    box("quiet_worktop_field", (0, 0, 0.845),
        (2.045, 2.450, 0.017), inset, 0.012)
    box("rear_oak_backstop", (0, 1.279, 0.905),
        (2.050, 0.058, 0.118), wood_light, 0.027)


def park_cafe_wash_basin():
    """Full-size wash station with a working basin and rear draining ledge."""
    shell = mat("washed_celadon_ceramic", "#A7C5BA", 0.42)
    shell_light = mat("ceramic_warm_cream_lip", "#EDE6D6", 0.42)
    inside = mat("basin_inside", "#729E9B", 0.40)
    water = mat("clear_wash_water", "#A5D5D0", 0.25)
    metal = mat("brushed_faucet", "#A5B7B2", 0.35, 0.48)
    soap = mat("coral_soap", "#DDA499", 0.55)
    slate = mat("drain_dark_metal", "#687C79", 0.52, 0.33)
    # The mounting apron now covers most of the 2.25 x 2.66 m worktop. The
    # basin itself is broad enough to visibly contain the recipe colanders.
    box("one_piece_sink_mount", (0, 0.017, 0.027),
        (1.94, 2.17, 0.052), shell_light, 0.054)
    ellipsoid("rounded_basin_outer_body", (0, -0.190, 0.100),
              (0.777, 0.620, 0.144), shell, 40, 18)
    ellipsoid("inset_basin_shadow", (0, -0.190, 0.188),
              (0.690, 0.539, 0.018), inside, 38, 12)
    ellipsoid("visible_shallow_water", (0, -0.190, 0.202),
              (0.642, 0.491, 0.008), water, 38, 11)
    rim = torus("rolled_celadon_basin_rim", (0, -0.190, 0.229),
                0.743, 0.030, shell_light, 40)
    rim.scale.y = 0.82
    cylinder("small_drain_grille", (0.344, -0.290, 0.210),
             0.071, 0.005, slate, 20)
    for i in range(4):
        a = i * math.tau / 4
        ellipsoid(f"drain_slot_{i}",
                  (0.344 + 0.033 * math.cos(a),
                   -0.290 + 0.033 * math.sin(a), 0.214),
                  (0.008, 0.004, 0.0015), metal, 8, 6)
    # Raised ribbed drain shelf stays separate from the water, so clean food
    # can be moved out of the basin without balancing on the faucet or soap.
    box("rear_draining_tray", (0, 0.847, 0.077),
        (1.50, 0.405, 0.061), shell, 0.039)
    box("rear_draining_dark_inset", (0, 0.847, 0.111),
        (1.36, 0.286, 0.009), inside, 0.013)
    for i in range(9):
        x = -0.586 + i * 0.146
        box(f"drainage_rib_{i}", (x, 0.847, 0.123),
            (0.029, 0.274, 0.016), metal, 0.007)
    # Bent faucet reaches the actual washing zone; the visible drop ends in
    # the water instead of floating over the counter beside the bowl.
    curve_line("continuous_swan_neck_faucet",
               [(-0.490, 0.617, 0.240),
                (-0.490, 0.617, 0.568),
                (-0.250, 0.335, 0.682),
                (-0.100, 0.035, 0.537)],
               0.029, metal)
    cylinder("short_faucet_spout", (-0.100, 0.035, 0.514),
             0.039, 0.070, metal, 16)
    ellipsoid("swan_neck_base", (-0.490, 0.617, 0.239),
              (0.078, 0.078, 0.042), metal, 18, 10)
    ellipsoid("single_water_drop", (-0.100, 0.035, 0.352),
              (0.024, 0.024, 0.041), water, 13, 9)
    box("rounded_soap_dish", (0.762, 0.665, 0.089),
        (0.265, 0.209, 0.046), shell_light, 0.023)
    ellipsoid("soft_coral_soap", (0.762, 0.665, 0.126),
              (0.099, 0.073, 0.042), soap, 18, 10)
    for i in range(2):
        curve_line(f"water_ripple_{i}",
                   [(-0.232 + i * 0.061, -0.055, 0.211),
                    (-0.162 + i * 0.061, -0.024, 0.215),
                    (-0.092 + i * 0.061, -0.028, 0.211)],
                   0.004, shell_light)


ASSETS = [
    ("park_cafe_counter_unit", park_cafe_counter_unit, 3.75),
    ("park_cafe_wash_basin", park_cafe_wash_basin, 2.44),
]


def export_asset(name, builder, camera_scale):
    food.reset()
    builder()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + ".blend")))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")),
                              export_format="GLB")
    floor = mat("PREVIEW_ONLY_studio_floor", "#D8DDD6", 0.95)
    box("PREVIEW_ONLY_studio_floor", (0, 0, -0.069),
        (3.0, 3.4, 0.12), floor)
    world = bpy.data.worlds[0]
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.84, 0.87, 0.83, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.44
    bpy.ops.object.light_add(type="AREA", location=(-2.6, -2.8, 3.6))
    bpy.context.object.data.energy = 330
    bpy.context.object.data.size = 2.4
    bpy.ops.object.light_add(type="AREA", location=(2.1, 1.8, 2.6))
    bpy.context.object.data.energy = 100
    bpy.context.object.data.size = 1.9
    bpy.ops.object.camera_add(location=(2.7, -3.9, 3.1))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.39)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = camera_scale
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 820
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT / (name + "_preview.png"))
    bpy.ops.render.render(write_still=True)
    print("PARK_KITCHEN_FIXTURE_READY:" + name)


requested = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else set()
for asset_name, build, ortho in ASSETS:
    if not requested or asset_name in requested:
        export_asset(asset_name, build, ortho)
