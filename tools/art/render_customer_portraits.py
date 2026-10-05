"""Render compact customer portraits from the same 3D resident used in queue.

Each transparent PNG is framed around the head and shoulders. The two hats
match the lightweight costume variants attached to guests in the kitchen.
"""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "assets" / "art" / "models" / "bay_resident.glb"
OUTPUT = ROOT / "assets" / "art" / "ui" / "customers"
SOURCE = ROOT / "tools" / "art" / "source" / "customers"
OUTPUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)


def material(name, color):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1.0)
    value.use_nodes = True
    value.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (*color, 1.0)
    value.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.78
    return value


def cylinder(name, radius, depth, at, color, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material(name + "_mat", color))
    bevel = obj.modifiers.new("soft_edge", "BEVEL")
    bevel.width = 0.018
    bevel.segments = 2
    obj.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
    return obj


def render_portrait(index):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(MODEL))
    if index == 1:
        cylinder("coral_worker_cap", 0.285, 0.115, (0, 0, 1.966), (0.70, 0.36, 0.32))
        brim = bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.195, 1.912))
        brim_obj = bpy.context.object
        brim_obj.name = "coral_cap_brim"
        brim_obj.dimensions = (0.50, 0.31, 0.058)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        brim_obj.data.materials.append(material("cap_brim", (0.70, 0.36, 0.32)))
    elif index == 2:
        cylinder("straw_hat_crown", 0.25, 0.21, (0, 0, 2.005), (0.72, 0.58, 0.36))
        cylinder("straw_hat_brim", 0.37, 0.055, (0, 0, 1.911), (0.78, 0.65, 0.43))
        cylinder("straw_hat_band", 0.252, 0.037, (0, 0, 1.93), (0.43, 0.56, 0.48))

    centre = Vector((0.0, -0.035, 1.585))
    direction = Vector((1.10, -3.4, 0.95)).normalized()
    bpy.ops.object.camera_add(location=centre + direction * 3.5)
    camera = bpy.context.object
    camera.name = "Customer_Portrait_Camera"
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.12
    bpy.context.scene.camera = camera

    world = bpy.data.worlds.new("Portrait_World")
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.87, 0.89, 0.83, 1.0)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.55
    bpy.context.scene.world = world
    for name, offset, power, size in (
        ("softbox_left", Vector((-1.2, -2.5, 2.3)), 210, 2.4),
        ("softbox_right", Vector((1.6, 0.4, 2.7)), 95, 1.9),
    ):
        bpy.ops.object.light_add(type="AREA", location=centre + offset)
        light = bpy.context.object
        light.name = name
        light.data.energy = power
        light.data.size = size

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 320
    scene.render.resolution_y = 320
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(OUTPUT / f"guest_{index}.png")
    scene.view_settings.view_transform = "AgX"
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"guest_{index}.blend"))
    bpy.ops.render.render(write_still=True)
    print(f"CUSTOMER_PORTRAIT_READY:guest_{index}")


if __name__ == "__main__":
    for customer_index in range(3):
        render_portrait(customer_index)
