"""Author the first HK street hero prop. Run with Blender --background --python this file."""

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "models"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "tools" / "art" / "source"
SOURCE.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def color(hex_code):
    rgb = [int(hex_code[i : i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return (*[v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb], 1.0)


def material(name, hex_code, roughness=0.72, metallic=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color(hex_code)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color(hex_code)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Alpha"].default_value = alpha
    return mat


cream = material("enamel_warm_cream", "#F4E7D0", 0.48)
mint = material("paint_muted_seafoam", "#75B2A6", 0.50)
deep_teal = material("paint_deep_teal", "#376F75", 0.54)
coral = material("paint_coral_route_band", "#D87D72", 0.49)
glass = material("glass_blue_tint", "#79B6C3", 0.21, 0.08)
metal = material("brushed_warm_metal", "#A5A69D", 0.39, 0.5)
dark = material("rubber_and_shadow", "#33474A", 0.85)
amber = material("lamp_warm_amber", "#F5D88E", 0.34)
seat = material("seat_oak", "#B88967", 0.78)


def box(name, at, dims, mat, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("soft_manufactured_edge", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        norm = obj.modifiers.new("weighted_corner_normals", "WEIGHTED_NORMAL")
        norm.keep_sharp = True
    return obj


def wheel(name, x, y):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.28, depth=0.16, location=(x, y, 0.31))
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler[0] = math.pi / 2
    obj.data.materials.append(dark)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.12, depth=0.18, location=(x, y + (0.015 if y > 0 else -0.015), 0.31))
    hub = bpy.context.object
    hub.name = name + "_silver_hub"
    hub.rotation_euler[0] = math.pi / 2
    hub.data.materials.append(metal)


# Scale is in meters. Local origin is ground at the middle of the car.
box("rounded_lower_carriage", (0, 0, 0.75), (5.55, 1.88, 1.35), mint, 0.21)
box("cream_middle_deck", (0, 0, 1.53), (5.35, 1.82, 0.49), cream, 0.11)
box("upper_carriage", (0, 0, 2.35), (5.25, 1.78, 1.28), cream, 0.20)
box("roof_canopy", (0, 0, 3.06), (5.56, 1.98, 0.25), deep_teal, 0.12)
box("roof_highlight", (0, 0, 3.20), (4.95, 1.62, 0.06), cream, 0.03)
box("route_stripe_left", (0, 0.963, 1.47), (5.1, 0.045, 0.17), coral, 0.023)
box("route_stripe_right", (0, -0.963, 1.47), (5.1, 0.045, 0.17), coral, 0.023)
box("lower_bottom_band", (0, 0.947, 0.39), (5.17, 0.048, 0.15), deep_teal, 0.025)
box("lower_bottom_band_back", (0, -0.947, 0.39), (5.17, 0.048, 0.15), deep_teal, 0.025)

for side in (-1, 1):
    y = side * 0.922
    for deck, z in (("lower", 1.01), ("upper", 2.35)):
        for i, x in enumerate((-1.86, -0.95, -0.04, 0.87, 1.78)):
            box(f"{deck}_window_{'R' if side > 0 else 'L'}_{i}", (x, y + side * 0.035, z), (0.74, 0.042, 0.57), glass, 0.045)
            box(f"{deck}_window_sill_{side}_{i}", (x, y + side * 0.07, z - 0.33), (0.78, 0.055, 0.045), cream, 0.014)
    # A working-looking front door, handle and separate step.
    door_x = 1.42
    box(f"entry_door_{side}", (door_x, y + side * 0.057, 0.84), (0.63, 0.06, 1.02), deep_teal, 0.035)
    box(f"door_glass_{side}", (door_x, y + side * 0.098, 1.04), (0.47, 0.025, 0.43), glass, 0.025)
    box(f"door_handle_{side}", (door_x - 0.24, y + side * 0.117, 0.74), (0.045, 0.045, 0.16), metal, 0.014)
    box(f"entry_step_{side}", (door_x, y + side * 0.19, 0.25), (0.70, 0.22, 0.11), metal, 0.025)

for end in (-1, 1):
    x = end * 2.70
    box(f"front_windscreen_{end}", (x + end * 0.031, 0, 2.34), (0.045, 1.28, 0.58), glass, 0.035)
    box(f"front_route_marker_{end}", (x + end * 0.06, 0, 1.52), (0.06, 1.08, 0.23), coral, 0.028)
    box(f"bumper_{end}", (x + end * 0.16, 0, 0.37), (0.18, 1.58, 0.14), metal, 0.055)
    for y in (-0.60, 0.60):
        box(f"headlamp_{end}_{y}", (x + end * 0.092, y, 0.67), (0.055, 0.21, 0.15), amber, 0.025)

for x in (-1.73, 1.73):
    for y in (-0.89, 0.89):
        wheel("tram_wheel_%s_%s" % (x, y), x, y)

for x in (-1.7, -0.8, 0.1, 1.0):
    box(f"upper_seat_{x}", (x, 0, 2.02), (0.56, 1.15, 0.16), seat, 0.045)

box("pantograph_base", (0, 0, 3.25), (0.68, 0.72, 0.11), metal, 0.035)
for sign in (-1, 1):
    rod = box(f"pantograph_arm_{sign}", (sign * 0.21, 0, 3.61), (0.055, 0.06, 0.77), metal, 0.019)
    rod.rotation_euler[1] = sign * 0.32
box("pantograph_contact", (0, 0, 4.02), (1.06, 0.09, 0.07), dark, 0.025)

# Keep just authored meshes in the export; reference render helpers are added afterward.
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "hk_tram.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "hk_tram.glb"), export_format="GLB")

world = bpy.data.worlds.new("warm_preview_world") if not bpy.data.worlds else bpy.data.worlds[0]
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.82, 0.87, 0.87, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.55

bpy.ops.object.light_add(type="AREA", location=(-3, -4, 8))
bpy.context.object.name = "preview_softbox"
bpy.context.object.data.energy = 850
bpy.context.object.data.shape = "DISK"
bpy.context.object.data.size = 6

bpy.ops.object.camera_add(location=(7, -9, 7))
camera = bpy.context.object
direction = Vector((0, 0, 1.8)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 8.8
bpy.context.scene.camera = camera
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1000
bpy.context.scene.render.resolution_y = 750
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = str(OUT / "hk_tram_preview.png")
bpy.ops.render.render(write_still=True)
print("ART_ASSET_READY:" + str(OUT / "hk_tram.glb"))
