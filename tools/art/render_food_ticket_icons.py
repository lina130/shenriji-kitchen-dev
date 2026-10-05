"""Render transparent restaurant ticket thumbnails from the shipped food GLBs.

Run with Blender, for example:
    blender --background --python tools/art/render_food_ticket_icons.py

The camera is framed from each mesh's world-space bounds, so future revisions of a
dish do not need a hand-tuned crop. The source GLBs are never modified.
"""

from pathlib import Path
import sys
from array import array

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "assets" / "art" / "models" / "food"
OUTPUT_DIR = ROOT / "assets" / "art" / "ui" / "tickets"
RECIPES = (
    "garden_rice_roll",
    "macao_spice_bun",
    "morning_egg_bun",
    "warm_tofu_bowl",
    "coconut_millet",
    "harbour_noodles",
    "chicken_rice",
    "bay_shrimp_roll",
    "seaweed_dumpling",
    "fruit_ice",
)


def visible_bounds(path: Path) -> tuple[int, float, float]:
    """Get food footprint and center from a Blender PNG without Pillow."""
    image = bpy.data.images.load(str(path), check_existing=False)
    pixels = array("f", [0.0]) * (image.size[0] * image.size[1] * 4)
    image.pixels.foreach_get(pixels)
    width = image.size[0]
    left = width
    right = -1
    bottom = image.size[1]
    top = -1
    for index, alpha in enumerate(pixels[3::4]):
        if alpha < 0.02:
            continue
        x = index % width
        y = index // width
        left = min(left, x)
        right = max(right, x)
        bottom = min(bottom, y)
        top = max(top, y)
    bpy.data.images.remove(image)
    if right < left:
        raise RuntimeError(f"Blank transparent ticket icon: {path}")
    return max(right - left + 1, top - bottom + 1), (left + right) * 0.5, (bottom + top) * 0.5


def render_recipe(recipe_id: str) -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(MODEL_DIR / f"{recipe_id}.glb"))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh in {recipe_id}.glb")

    corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    center = Vector(tuple((min(v[i] for v in corners) + max(v[i] for v in corners)) * 0.5 for i in range(3)))

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "Ticket_Camera"
    direction = Vector((1.15, -1.53, 1.24)).normalized()
    camera.location = center + direction * 4.0
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    rotation = camera.rotation_euler.to_matrix()
    right = rotation @ Vector((1, 0, 0))
    up = rotation @ Vector((0, 1, 0))
    x_values = [right.dot(point - center) for point in corners]
    y_values = [up.dot(point - center) for point in corners]
    width = max(x_values) - min(x_values)
    height = max(y_values) - min(y_values)
    # A world-axis bounding-box midpoint can sit noticeably off-center after the
    # isometric projection, especially for tall cups. Aim at the projected midpoint.
    center += right * (max(x_values) + min(x_values)) * 0.5
    center += up * (max(y_values) + min(y_values)) * 0.5
    camera.location = center + direction * 4.0
    camera.data.ortho_scale = max(width, height) * 1.17
    bpy.context.scene.camera = camera

    world = bpy.data.worlds.new("Ticket_World")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.82, 0.86, 0.86, 1.0)
    background.inputs["Strength"].default_value = 0.5
    bpy.context.scene.world = world

    for location, energy, size in (((-1.5, -1.8, 2.5), 240, 1.8), ((1.6, 1.2, 2.2), 95, 1.5)):
        bpy.ops.object.light_add(type="AREA", location=center + Vector(location))
        lamp = bpy.context.object
        lamp.data.energy = energy
        lamp.data.shape = "DISK"
        lamp.data.size = size

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.filepath = str(OUTPUT_DIR / f"{recipe_id}.png")
    scene.render.image_settings.compression = 45
    scene.view_settings.view_transform = "AgX"
    bpy.ops.render.render(write_still=True)
    # GLB bounds sometimes include thin nearly invisible edges. Fit the actual
    # rendered food into a consistent icon footprint while keeping clear margins.
    extent, x_center, y_center = visible_bounds(Path(scene.render.filepath))
    camera.location += right * ((x_center - 255.5) / 512.0 * camera.data.ortho_scale)
    camera.location += up * ((y_center - 255.5) / 512.0 * camera.data.ortho_scale)
    camera.data.ortho_scale *= extent / 438.0
    bpy.ops.render.render(write_still=True)
    print(f"TICKET_ICON_READY:{recipe_id}")


if __name__ == "__main__":
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    requested = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else set(RECIPES)
    unknown = requested.difference(RECIPES)
    if unknown:
        raise ValueError(f"Unknown recipe IDs: {sorted(unknown)}")
    for recipe in RECIPES:
        if recipe in requested:
            render_recipe(recipe)
