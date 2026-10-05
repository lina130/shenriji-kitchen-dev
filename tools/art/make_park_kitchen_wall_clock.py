"""A legible side-wall clock housing for the Talent Park restaurant.

The local +Z face normal becomes Godot local +Y after glTF import. The kitchen
places its solid back against the service-bay rear wall and rotates the node
+90 degrees around X, retaining the animated scene hands.
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
NAME = "park_kitchen_wall_clock"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0

food.reset()
mat = food.mat
cylinder = food.cylinder
torus = food.torus
box = food.box

WOOD = mat("clock_oiled_walnut", "#80654F", 0.78)
WOOD_EDGE = mat("clock_wood_edge", "#5E4B3E", 0.87)
IVORY = mat("clock_enamel_dial", "#EEE5D2", 0.55)
BRASS = mat("clock_soft_brass", "#C8A77B", 0.47, 0.33)
INK = mat("clock_dark_green_ink", "#627A70", 0.84)
CORAL = mat("clock_service_hour_marker", "#B77762", 0.72)

# Rounded wooden drum with a fully enclosed back, enamel dial and brass bezel.
cylinder("solid_wooden_back", (0, 0, 0.032), 0.421, 0.064, WOOD_EDGE, 48)
cylinder("rounded_clock_body", (0, 0, 0.078), 0.425, 0.113, WOOD, 48)
cylinder("inset_enamel_face", (0, 0, 0.141), 0.370, 0.020, IVORY, 48)
torus("continuous_brass_bezel", (0, 0, 0.142), 0.391, 0.025, BRASS, 48)
torus("fine_inner_dial_line", (0, 0, 0.154), 0.333, 0.004, INK, 48)

for hour in range(12):
    angle = math.tau * hour / 12
    radius = 0.300
    marker = box("hour_mark_%02d" % hour,
                 (math.sin(angle) * radius, math.cos(angle) * radius, 0.158),
                 (0.019 if hour % 3 else 0.031, 0.054 if hour % 3 else 0.075, 0.007),
                 CORAL if hour % 3 == 0 else INK, 0.003)
    marker.rotation_euler.z = -angle

# Delicate inner minute dashes read at near zoom without making a noisy ring.
for minute in range(60):
    if minute % 5 == 0:
        continue
    angle = math.tau * minute / 60
    mark = box("minute_dash_%02d" % minute,
               (math.sin(angle) * 0.345, math.cos(angle) * 0.345, 0.157),
               (0.006, 0.018, 0.004), INK, 0.001)
    mark.rotation_euler.z = -angle

# Small side casing bolts signal a constructed object rather than a dial decal.
for a in (-math.pi / 4, math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4):
    cylinder("bezel_fastener", (math.cos(a) * 0.391,
                                 math.sin(a) * 0.391, 0.166),
             0.012, 0.010, BRASS, 12)

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (NAME + ".blend")))
bpy.ops.export_scene.gltf(filepath=str(OUT / (NAME + ".glb")), export_format="GLB")

# The studio preview is excluded from the exported GLB.
background = mat("PREVIEW_ONLY_clock_studio", "#B0BFAF", 0.95)
box("PREVIEW_ONLY_wall", (0, 0.08, -0.069), (1.4, 1.4, 0.11), background)
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.84, 0.87, 0.82, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.47
bpy.ops.object.light_add(type="AREA", location=(-1.0, -1.5, 2.2))
bpy.context.object.data.energy = 240
bpy.context.object.data.size = 1.8
bpy.ops.object.camera_add(location=(0.9, -1.4, 1.75))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0.07)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 1.35
bpy.context.scene.camera = camera
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 800
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / (NAME + "_preview.png"))
bpy.ops.render.render(write_still=True)
print("PARK_KITCHEN_WALL_CLOCK_READY:" + NAME)
