"""Empty two-place pickup stand for combination orders at the park cafe.

Blender uses metres and +Z up. GLB imports into Godot with +Y up and +Z
toward customers. The origin is the bottom centre of the stand. Dynamic dishes
rest on the two level pads at X = -0.85 and +0.85 m, Z = 0.56 m in Blender.
"""

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

NAME = "park_cafe_combo_pickup_tray"
mat = food.mat
box = food.box
ellipsoid = food.ellipsoid
curve_line = food.curve_line


def build():
    oak = mat("honey_oak_pickup_stand", "#B98C68", 0.82)
    endgrain = mat("pickup_stand_endgrain", "#89664F", 0.88)
    leg = mat("pickup_stand_warm_walnut", "#9D765D", 0.87)
    porcelain = mat("warm_celadon_service_surface", "#DAE2D1", 0.49)
    pad = mat("cream_stone_dish_landing_pad", "#F0E7D6", 0.54)
    rail = mat("subtle_celadon_edge", "#9EBCAF", 0.47)
    brass = mat("brushed_pickup_handle", "#BBA174", 0.43, 0.24)
    inset = mat("engraved_oak_reveal", "#805E49", 0.91)

    # Open riser gives food models room to read as two separate orders.
    box("low_oak_footprint", (0, 0, 0.042),
        (3.12, 0.98, 0.082), oak, 0.047)
    for side, x in (("left", -1.40), ("right", 1.40)):
        for face, y in (("front", -0.352), ("back", 0.352)):
            box(f"{side}_{face}_rounded_upright", (x, y, 0.269),
                (0.165, 0.176, 0.382), leg, 0.034)
            box(f"{side}_{face}_foot_cap", (x, y, 0.083),
                (0.185, 0.195, 0.054), endgrain, 0.021)
    box("continuous_rear_stiffener", (0, 0.426, 0.302),
        (2.99, 0.082, 0.149), leg, 0.022)
    box("front_low_open_crossbar", (0, -0.428, 0.167),
        (2.94, 0.067, 0.100), leg, 0.020)
    for x in (-1.50, 1.50):
        box(f"front_corner_carved_grain_{x}", (x, -0.464, 0.180),
            (0.019, 0.006, 0.067), inset, 0.004)

    # The broad top is a shallow landing surface, never a pre-plated bowl.
    box("wide_oak_service_top", (0, 0, 0.490),
        (3.190, 1.060, 0.108), oak, 0.042)
    box("porcelain_two_place_inset", (0, 0, 0.550),
        (3.024, 0.918, 0.014), porcelain, 0.018)
    for name, x in (("left", -0.850), ("right", 0.850)):
        box(f"{name}_empty_landing_pad", (x, 0, 0.558),
            (1.447, 0.813, 0.008), pad, 0.020)
        # Two tiny inlaid strips show each pad's alignment without printing
        # symbols that would compete with the finished food on top.
        for stripe, y in enumerate((-0.362, 0.362)):
            box(f"{name}_celadon_inlay_{stripe}", (x, y, 0.565),
                (0.566, 0.010, 0.004), rail, 0.002)

    # A very low lip prevents visual overlap with the plates brought in by
    # gameplay. The central strip is a true physical two-order divider.
    for name, y in (("front", -0.504), ("rear", 0.504)):
        box(f"{name}_shallow_safety_lip", (0, y, 0.580),
            (3.172, 0.051, 0.054), rail, 0.017)
    for name, x in (("left", -1.573), ("right", 1.573)):
        box(f"{name}_end_lip", (x, 0, 0.580),
            (0.046, 0.934, 0.054), rail, 0.014)
    box("slim_middle_order_divider", (0, 0, 0.579),
        (0.051, 0.925, 0.052), rail, 0.011)
    box("middle_brass_divider_accent", (0, -0.494, 0.601),
        (0.026, 0.010, 0.016), brass, 0.004)

    # Side handles are horizontal U-shaped grabs. Their ends attach to the
    # upper frame and only project 0.13 m beyond it, keeping total width ~3.45.
    for side, sign in (("left", -1), ("right", 1)):
        for y in (-0.240, 0.240):
            ellipsoid(f"{side}_handle_mount_{y}",
                      (sign * 1.582, y, 0.582),
                      (0.043, 0.045, 0.022), brass, 14, 9)
        curve_line(f"{side}_raised_pickup_handle",
                   [(sign * 1.582, -0.240, 0.582),
                    (sign * 1.712, -0.207, 0.597),
                    (sign * 1.712, 0.207, 0.597),
                    (sign * 1.582, 0.240, 0.582)],
                   0.017, brass)

    for x in (-1.53, 1.53):
        for y in (-0.452, 0.452):
            ellipsoid(f"quiet_corner_pin_{x}_{y}",
                      (x, y, 0.606), (0.012, 0.012, 0.004),
                      brass, 10, 6)


def export_and_preview():
    food.reset()
    build()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (NAME + ".blend")))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (NAME + ".glb")),
                              export_format="GLB")
    floor = mat("PREVIEW_ONLY_floor", "#D7DCD4", 0.94)
    box("PREVIEW_ONLY_floor", (0, 0, -0.069),
        (4.50, 2.15, 0.12), floor, 0)
    world = bpy.data.worlds[0]
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.84, 0.87, 0.83, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.44
    bpy.ops.object.light_add(type="AREA", location=(-2.7, -2.8, 3.7))
    bpy.context.object.data.energy = 340
    bpy.context.object.data.size = 2.5
    bpy.ops.object.light_add(type="AREA", location=(2.2, 1.8, 2.9))
    bpy.context.object.data.energy = 120
    bpy.context.object.data.size = 2.0
    bpy.ops.object.camera_add(location=(2.8, -4.0, 3.15))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.30)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.17
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT / (NAME + "_preview.png"))
    bpy.ops.render.render(write_still=True)
    print("PARK_COMBO_PICKUP_TRAY_READY:" + str(OUT / (NAME + ".glb")))


if __name__ == "__main__":
    export_and_preview()
