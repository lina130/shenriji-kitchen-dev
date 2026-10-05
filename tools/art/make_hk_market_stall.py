"""Build an original Hong Kong street-market produce stall miniature.

The asset is local to the street: metres, +Z up, -Y customer-facing.  A
separate preview render is generated after export; lights and review floor are
never part of the game GLB.
"""

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "models"
SOURCE = ROOT / "tools" / "art" / "source"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
RNG = random.Random(81023)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def srgb(hex_value):
    vals = [int(hex_value[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in vals) + (1,)


def material(name, color, rough=0.7, metal=0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = srgb(color)
    result.use_nodes = True
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = srgb(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return result


steel = material("satin_silver_market_frame", "#A9B8B6", 0.47, 0.7)
steel_dark = material("dark_weathered_frame", "#51666A", 0.57, 0.53)
canvas_green = material("striped_canopy_deep_jade", "#348B77", 0.92)
canvas_cream = material("striped_canopy_ivory", "#E8E6CE", 0.94)
canvas_edge = material("canvas_binding", "#286B60", 0.92)
wood = material("warm_oiled_crate_wood", "#B98252", 0.78)
wood_light = material("crate_slats_sunlit", "#DBA56D", 0.78)
crate_inner = material("crate_dark_recess", "#71583D", 0.93)
red = material("tomato_red", "#D94F46", 0.52)
red_light = material("tomato_lit", "#F4775E", 0.5)
leaf = material("bok_choy_leaf", "#427C50", 0.87)
leaf_bright = material("bok_choy_sunlit", "#6FA45E", 0.83)
leaf_pale = material("bok_choy_stem", "#D5DFB4", 0.82)
orange = material("tangerine_peel", "#F1A74F", 0.71)
orange_light = material("golden_tangerine", "#F9C36A", 0.67)
eggplant = material("eggplant_violet", "#563B6F", 0.4)
eggplant_light = material("eggplant_gloss", "#7D5A8F", 0.42)
lime = material("cucumber_green", "#5C8D52", 0.63)
yellow = material("market_banana", "#EBC968", 0.74)
paper = material("laminated_price_tag", "#F6ECD2", 0.64)
ink = material("price_tag_red_mark", "#BD4E48", 0.83)
screen = material("scale_display_umber", "#343F42", 0.34)
screen_glow = material("scale_digits_mint", "#9ED5B9", 0.31)
rubber = material("market_wheel_rubber", "#3A4243", 0.95)
tile = material("weathered_market_paving", "#B5AE9E", 0.9)
straw = material("basket_woven_honey", "#B8925F", 0.87)


def bevel(obj, width=0.025, segments=2):
    if not width:
        return obj
    mod = obj.modifiers.new("soft_radius", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    weighted = obj.modifiers.new("weighted_normal", "WEIGHTED_NORMAL")
    weighted.keep_sharp = True
    return obj


def cube(name, xyz, dimensions, mat, radius=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return bevel(obj, radius)


def cylinder(name, xyz, radius, depth, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return bevel(obj, 0.005, 2)


def ellipsoid(name, xyz, size, mat, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def rod(name, start, end, radius, mat, vertices=10):
    midpoint = (Vector(start) + Vector(end)) * 0.5
    direction = Vector(end) - Vector(start)
    obj = cylinder(name, midpoint, radius, direction.length, mat, vertices)
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
        mod = obj.modifiers.new("cloth_hem_thickness", "SOLIDIFY")
        mod.thickness = thickness
        bevel(obj, 0.012, 2)
    return obj


# The curb plinth belongs to the stall. It distinguishes the narrow Hong Kong
# pavement from the freestanding toy displays in the user's references.
cube("worn_narrow_pavement", (0, 0, 0.07), (5.2, 3.85, 0.14), tile, 0.10)
cube("drain_gutter", (0, -1.76, 0.151), (4.80, 0.15, 0.015), steel_dark, 0.008)
for i in range(18):
    cube(f"drain_grate_{i:02}", (-2.28 + i * 0.27, -1.76, 0.161), (0.08, 0.105, 0.015), steel, 0.004)

# A folding frame with a shaped canvas, alternating ivory/jade fabric panels,
# hanging scallops, fine rails and tension cables.
for x in (-2.18, 2.18):
    for y in (-1.38, 1.45):
        cylinder(f"frame_post_{x}_{y}", (x, y, 1.54), 0.046, 3.00, steel_dark)
        cube(f"post_foot_{x}_{y}", (x, y, 0.16), (0.25, 0.25, 0.09), steel, 0.024)
for y in (-1.38, 1.45):
    rod(f"top_crossbar_{y}", (-2.18, y, 3.04), (2.18, y, 3.04), 0.046, steel)
for x in (-2.18, 2.18):
    rod(f"top_sidebar_{x}", (x, -1.38, 3.04), (x, 1.45, 3.04), 0.041, steel)
    rod(f"roof_ridge_support_{x}", (x, -1.38, 3.04), (x, 0.12, 3.42), 0.026, steel_dark)
    rod(f"roof_ridge_support_back_{x}", (x, 0.12, 3.42), (x, 1.45, 3.04), 0.026, steel_dark)
rod("central_roof_ridge", (-2.18, 0.12, 3.42), (2.18, 0.12, 3.42), 0.034, steel)

for i in range(12):
    x0 = -2.19 + i * 4.38 / 12
    x1 = -2.19 + (i + 1) * 4.38 / 12
    cloth = canvas_cream if i % 2 else canvas_green
    for side, y_edge in (("front", -1.42), ("back", 1.49)):
        shaped_mesh(
            f"{side}_canopy_panel_{i:02}",
            [(x0, 0.10, 3.48), (x1, 0.10, 3.48),
             (x1, y_edge, 3.065), (x0, y_edge, 3.065)],
            [(0, 1, 2, 3)], cloth, 0.033,
        )
    # Distinct downward scallops visible from the sidewalk camera.
    ellipsoid(f"hem_scallop_{i:02}", ((x0 + x1) / 2, -1.438, 2.965),
              (0.182, 0.045, 0.105), cloth)
    cube(f"front_hem_binding_{i:02}", ((x0 + x1) / 2, -1.432, 3.055),
         (x1 - x0, 0.048, 0.035), canvas_edge, 0.008)
for side in (-1, 1):
    rod(f"awning_cable_{side}", (side * 2.18, -1.40, 3.00),
        (side * 2.18, -1.35, 1.52), 0.008, steel)

# Two-tier foldaway stand, with lower stock and upper front-facing produce.
for x in (-2.03, 2.03):
    for y in (-0.87, 0.83):
        cube(f"counter_leg_{x}_{y}", (x, y, 0.73), (0.075, 0.075, 1.22), steel_dark, 0.015)
cube("counter_lower_shelf", (0, 0.05, 0.58), (4.20, 1.90, 0.09), steel, 0.035)
cube("counter_wood_top", (0, 0.05, 1.36), (4.30, 2.02, 0.14), wood, 0.055)
cube("counter_top_inset", (0, 0.05, 1.443), (4.08, 1.79, 0.032), wood_light, 0.019)
cube("front_stock_rack", (0, -1.05, 0.93), (4.06, 0.66, 0.085), steel, 0.018)
for x in (-1.93, 0, 1.93):
    rod(f"front_stock_support_{x}", (x, -1.33, 0.91),
        (x, -0.86, 1.34), 0.025, steel_dark)


def crate(label, xyz, size=(1.19, 0.75, 0.32)):
    x, y, z = xyz
    sx, sy, sz = size
    cube(label + "_base", (x, y, z), (sx, sy, 0.055), crate_inner, 0.016)
    for yy in (-1, 1):
        cube(label + f"_long_{yy}", (x, y + yy * (sy / 2 - 0.035), z + sz / 2),
             (sx, 0.065, sz), wood, 0.017)
    for xx in (-1, 1):
        cube(label + f"_short_{xx}", (x + xx * (sx / 2 - 0.038), y, z + sz / 2),
             (0.065, sy - 0.11, sz), wood, 0.017)
    for k in range(3):
        cube(label + f"_slat_{k}", (x - sx * 0.28 + k * sx * 0.28, y - sy / 2 - 0.008,
                                 z + sz / 2), (0.055, 0.016, sz * 0.68), wood_light, 0.009)
    return z + 0.11


# Local currency tags are small physical cards clipped onto crates. The
# colored strokes evoke hand-marked prices without putting text onto the map.
def price_tag(label, xyz, angle=0):
    x, y, z = xyz
    parent = bpy.data.objects.new(label + "_marker", None)
    bpy.context.collection.objects.link(parent)
    parent.location = (x, y, z)
    parent.rotation_euler.z = angle
    for obj in (
        cube(label + "_card", (0, 0, 0), (0.30, 0.022, 0.25), paper, 0.014),
        cube(label + "_accent", (0, -0.018, -0.08), (0.23, 0.006, 0.025), ink, 0.003),
        cylinder(label + "_clip", (0, -0.013, 0.142), 0.027, 0.036, steel_dark),
    ):
        obj.parent = parent
    return parent


row_y = -0.44
for i, (x, label) in enumerate(((-1.40, "tomatoes"), (0, "bok_choy"), (1.40, "citrus"))):
    z = crate(f"upper_crate_{label}", (x, row_y, 1.47), (1.28, 0.83, 0.32))
    price_tag(f"tag_{label}", (x + 0.42, -0.91, 1.70))
    if label == "tomatoes":
        for n in range(15):
            px = x + (n % 5 - 2) * 0.205 + RNG.uniform(-0.026, 0.026)
            py = row_y + (n // 5 - 1) * 0.20
            pz = z + (0.11 if n < 10 else 0.21)
            ellipsoid(f"tomato_{n:02}", (px, py, pz), (0.12, 0.12, 0.105), red_light if n % 4 == 0 else red)
            ellipsoid(f"tomato_calyx_{n:02}", (px, py, pz + 0.105), (0.035, 0.044, 0.012), leaf)
    elif label == "bok_choy":
        for n in range(13):
            px = x + (n % 5 - 2) * 0.20 + RNG.uniform(-0.018, 0.018)
            py = row_y + (n // 5 - 1) * 0.19
            pz = z + 0.12
            ellipsoid(f"bok_stem_{n:02}", (px, py, pz), (0.070, 0.070, 0.15), leaf_pale)
            for j in range(2):
                ellipsoid(f"bok_leaf_{n:02}_{j}", (px + (j * 2 - 1) * 0.055, py, pz + 0.14),
                          (0.075, 0.105, 0.15), leaf_bright if (n + j) % 3 == 0 else leaf)
    else:
        for n in range(18):
            px = x + (n % 6 - 2.5) * 0.18 + RNG.uniform(-0.025, 0.025)
            py = row_y + (n // 6 - 1) * 0.20
            pz = z + (0.10 if n < 12 else 0.20)
            ellipsoid(f"tangerine_{n:02}", (px, py, pz), (0.105, 0.104, 0.093), orange_light if n % 4 == 0 else orange)
            ellipsoid(f"tangerine_leaf_{n:02}", (px + 0.032, py, pz + 0.092),
                      (0.052, 0.021, 0.012), leaf)

# Angle the lower crates toward approaching players; deep purple and lime
# provide readable silhouettes when viewed from a raised camera.
for i, (x, label) in enumerate(((-1.39, "aubergine"), (0, "cucumber"), (1.39, "banana"))):
    z = crate(f"lower_crate_{label}", (x, -1.02, 0.97), (1.25, 0.58, 0.29))
    if label == "aubergine":
        for n in range(10):
            px = x + (n % 5 - 2) * 0.21
            py = -1.02 + (n // 5 - 0.5) * 0.19
            ellipsoid(f"aubergine_{n:02}", (px, py, z + 0.11), (0.085, 0.14, 0.085),
                      eggplant_light if n % 3 == 0 else eggplant)
            ellipsoid(f"aubergine_stem_{n:02}", (px, py + 0.12, z + 0.12), (0.06, 0.045, 0.036), leaf)
    elif label == "cucumber":
        for n in range(8):
            px = x + (n % 4 - 1.5) * 0.28
            py = -1.02 + (n // 4 - 0.5) * 0.19
            ellipsoid(f"cucumber_{n:02}", (px, py, z + 0.12), (0.08, 0.20, 0.075), lime)
    else:
        for n in range(10):
            px = x + (n % 5 - 2) * 0.21
            py = -1.02 + (n // 5 - 0.5) * 0.18
            obj = ellipsoid(f"banana_{n:02}", (px, py, z + 0.11), (0.085, 0.15, 0.065), yellow)
            obj.rotation_euler.z = -0.25 if n % 2 else 0.25

# A vintage electronic weighing scale and thin carrying bags supply a
# recognisable wet-market story. All typography is omitted intentionally.
cube("scale_body", (1.55, 0.72, 1.59), (0.54, 0.38, 0.24), steel_dark, 0.045)
cube("scale_stainless_tray", (1.55, 0.72, 1.725), (0.66, 0.48, 0.055), steel, 0.045)
cube("scale_readout", (1.55, 0.515, 1.58), (0.31, 0.014, 0.075), screen, 0.008)
for i in range(3):
    cube(f"scale_green_readout_{i}", (1.46 + i * 0.09, 0.504, 1.58),
         (0.038, 0.005, 0.018), screen_glow, 0.004)
cylinder("scale_tray_tangerine", (1.51, 0.76, 1.82), 0.10, 0.13, orange, 16)
cube("market_bag_dispenser", (-1.82, 0.72, 1.58), (0.24, 0.27, 0.31), steel, 0.022)
for n in range(3):
    ellipsoid(f"rolled_bag_{n}", (-1.85 + n * 0.055, 0.60, 1.57),
              (0.038, 0.035, 0.11), canvas_cream)

# Rear shelving, two bulk baskets, a hanging lamp and side crates make the
# model credible from any rotation, as requested for a free-moving camera.
for x in (-1.75, 0.05, 1.75):
    cube(f"rear_shelf_{x}", (x, 1.04, 1.91), (1.44, 0.36, 0.058), steel, 0.017)
for x in (-2.24, 2.24):
    cylinder(f"side_basket_{x}", (x, 0.42, 0.40), 0.33, 0.48, straw, 16)
    cylinder(f"side_basket_rim_{x}", (x, 0.42, 0.65), 0.35, 0.055, wood, 16)
    for n in range(5):
        angle = n * math.tau / 5
        ellipsoid(f"basket_leaf_{x}_{n}", (x + 0.15 * math.cos(angle),
                  0.42 + 0.15 * math.sin(angle), 0.69), (0.13, 0.09, 0.15),
                  leaf_bright if n % 2 else leaf)
rod("pendant_cord", (0.02, 0.07, 3.39), (0.02, 0.07, 2.70), 0.014, steel_dark)
ellipsoid("pendant_lamp_shade", (0.02, 0.07, 2.67), (0.32, 0.32, 0.15), canvas_cream, 16, 8)
ellipsoid("pendant_globe", (0.02, 0.07, 2.56), (0.10, 0.10, 0.10), yellow, 12, 8)

# One hand trolley and stack of back-of-house crates make the stall look like
# a functioning business rather than a single decorative counter.
cube("delivery_trolley_deck", (1.63, 1.47, 0.36), (0.80, 0.51, 0.085), steel_dark, 0.033)
for x in (1.37, 1.88):
    for y in (1.26, 1.70):
        wheel = cylinder(f"delivery_wheel_{x}_{y}", (x, y, 0.25), 0.105, 0.052, rubber)
        wheel.rotation_euler.x = math.pi / 2
rod("delivery_trolley_handle_left", (1.28, 1.47, 0.41), (1.28, 1.47, 1.13), 0.028, steel)
rod("delivery_trolley_handle_right", (1.98, 1.47, 0.41), (1.98, 1.47, 1.13), 0.028, steel)
rod("delivery_trolley_handle_grip", (1.28, 1.47, 1.13), (1.98, 1.47, 1.13), 0.035, rubber)
crate("delivery_spare_crate", (1.62, 1.47, 0.47), (0.72, 0.44, 0.22))
crate("rear_spare_crate", (-1.54, 1.31, 0.23), (0.84, 0.72, 0.31))

# Save editable source and export only the asset geometry.
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "hk_market_stall.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "hk_market_stall.glb"), export_format="GLB")

# Isolated review setup is intentionally absent from the game asset.
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.78, 0.85, 0.82, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.65
bpy.ops.object.light_add(type="AREA", location=(-3.8, -5.5, 9))
bpy.context.object.data.energy = 1250
bpy.context.object.data.size = 5.5
bpy.ops.object.light_add(type="AREA", location=(5, 3, 6))
bpy.context.object.data.energy = 500
bpy.context.object.data.size = 4
bpy.ops.object.camera_add(location=(7.2, -9.5, 7.0))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 1.50)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 7.7
bpy.context.scene.camera = camera
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1150
bpy.context.scene.render.resolution_y = 1000
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = str(OUT / "hk_market_stall_preview.png")
bpy.ops.render.render(write_still=True)
print("ART_ASSET_READY:" + str(OUT / "hk_market_stall.glb"))
