"""Authored day/evening Shenzhen Bay window panorama for the cafe kitchen.

The fixed-window wall is 14.7 m wide.  This shallow exterior diorama has its
origin at the centre of its bottom sill, +Z up, and local -Y facing the player.
Godot placement: Vector3(0, 0.77, -4.79), scale 1.  Import either GLB and
switch visibility with the in-game clock.  Keep the warm frame in both variants.
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_park_foods as food


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "models" / "kitchen"
SOURCE = ROOT / "tools" / "art" / "source" / "kitchen"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0

WIDTH = 14.72
HEIGHT = 1.68
box = food.box
ellipsoid = food.ellipsoid
cylinder = food.cylinder
curve = food.curve_line


def material(name, hex_color, roughness=0.75, emissive=None, strength=0.0):
    mat = food.mat(name, hex_color, roughness)
    if emissive:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Emission Color"].default_value = food.srgb(emissive)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def vertical(name, x, y, bottom, top, width, depth, mat, bevel=0.008):
    return box(name, (x, y, (bottom + top) / 2),
               (width, depth, top - bottom), mat, bevel)


def quad_batch(name, rectangles, y, mat):
    """One GLB mesh for many lit building windows or water glints."""
    vertices, faces = [], []
    for x, z, w, h in rectangles:
        base = len(vertices)
        vertices.extend([(x-w/2, y, z-h/2), (x+w/2, y, z-h/2),
                         (x+w/2, y, z+h/2), (x-w/2, y, z+h/2)])
        faces.append((base, base+1, base+2, base+3))
    mesh_data = bpy.data.meshes.new(name + "_mesh")
    mesh_data.from_pydata(vertices, [], faces)
    mesh_data.update()
    obj = bpy.data.objects.new(name, mesh_data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def build_window(evening, dusk=False, dawn=False):
    food.reset()
    rng = random.Random(4017)

    cream = material("window_cream_stone", "#E8D8B8", 0.77)
    frame = material("window_honey_oak", "#B28B70" if dawn else ("#9A7059" if dusk else ("#A98264" if not evening else "#8E6A56")), 0.72)
    inner_frame = material("window_frame_reveal", "#745A4A", 0.88)
    celadon = material("window_celadon_sill", "#A8BCAC", 0.65)
    sky_colors = (["#F5D3A0", "#F2C4A9", "#D9B8C1", "#9DAEC8"] if dawn else
                  (["#F2BC7D", "#ECA17D", "#BD8294", "#617A9A"] if dusk else
                  (["#A7CAD2", "#B8D5D5", "#C9DCD5", "#D8DACF"] if not evening else
                   ["#1C3047", "#2C4053", "#445467", "#5F6771"])))
    sky = [material("sky_gradient_%d" % i, c) for i, c in enumerate(sky_colors)]
    water = material("bay_water", "#81A4AF" if dawn else ("#527B91" if dusk else ("#70A7B4" if not evening else "#284C65")), 0.42)
    water_light = material("bay_water_sheen", "#E9CBA6" if dawn else ("#E1B584" if dusk else ("#B2D0C7" if not evening else "#86A5A0")), 0.47)
    reflected_gold = material("distant_light_reflection", "#F1D2AA" if dawn else ("#E9AE77" if dusk else ("#B8C3B6" if not evening else "#D6A978")),
                              0.48, "#FFE0AE" if dawn else ("#F2C28B" if dusk else ("#E0B67E" if evening else None)), 0.55 if dawn else (0.65 if dusk else (0.8 if evening else 0)))
    shore = material("opposite_shore", "#6A847B" if dusk else ("#8FAF9C" if not evening else "#526A65"))
    park_rail = material("park_rail", "#D9D5BA" if not evening else "#AA9B85", 0.57)
    grass = material("talent_park_green", "#637E6C" if dusk else ("#7FA481" if not evening else "#536D62"))
    leaf = [material("park_leaf_%d" % i, c) for i, c in enumerate(
        (["#617D6A", "#849A76", "#587B79"] if dusk else (["#709976", "#9EBA8B", "#729A8F"] if not evening else
         ["#3F625A", "#55745F", "#477478"])))]
    trunk = material("tree_bark", "#786854", 0.91)
    tower = [material("tower_%d" % i, c, 0.52) for i, c in enumerate(
        (["#6C7182", "#857D85", "#6F8190", "#9B8181", "#5E7387"] if dusk else
         (["#8EAAA7", "#B0C5B8", "#94ADA9", "#ACB6AB", "#849FA7"] if not evening else
          ["#435766", "#596879", "#496477", "#6B6E72", "#435B72"])))]
    glass_hi = material("tower_glazing", "#CBAA9C" if dusk else ("#C4D9D1" if not evening else "#7A8E9D"), 0.42)
    building_lights = material("tower_warm_windows", "#F5C98F" if dusk else ("#F4D4A1" if not evening else "#F4C678"),
                               0.72, "#FFD69C" if dusk else ("#FFE1A6" if evening else None), 0.8 if dusk else (1.7 if evening else 0))
    park_lights = material("park_lamps", "#FFE2AA" if dusk else ("#EDE4C6" if not evening else "#FFDF9B"),
                           0.58, "#FFE0A1" if dusk or evening else None, 0.9 if dusk else (2.0 if evening else 0))

    # A real sill and framed recess conceal the previous flat wall.  Layers are
    # shallow to fit in front of the existing back wall in the first playable build.
    box("recess_dark_oak", (0, -0.005, 0.84), (WIDTH, 0.10, HEIGHT), inner_frame, 0)
    for i, mat in enumerate(sky):
        lo = 0.44 + i * 0.31
        box("sky_depth_band_%d" % i, (0, -0.063, lo + 0.155),
            (WIDTH - 0.15, 0.008, 0.317), mat, 0)
    if dusk or dawn:
        sun_x = -6.94 if dawn else -1.34
        sun = material("low_sun", "#FFF0C6" if dawn else "#F9D79E", 0.9,
                       "#FFE8BA" if dawn else "#FFD9A2", 0.72 if dawn else 0.9)
        haze = material("horizon_haze", "#F4D4AE" if dawn else "#F4B989", 0.95)
        box("horizon_haze", (-6.81 if dawn else sun_x, -0.076, 0.57), (1.0 if dawn else 4.8, 0.006, 0.13), haze, 0)
        ellipsoid("low_sun_disc", (sun_x, -0.079, 0.80 if dawn else 0.65),
                  (0.24, 0.006, 0.18 if dawn else 0.21), sun, 32, 16)
    box("bay_water_surface", (0, -0.070, 0.19),
        (WIDTH - 0.15, 0.006, 0.39), water, 0)
    box("far_shore_green", (0, -0.074, 0.46),
        (WIDTH - 0.15, 0.012, 0.065), shore, 0.013)

    # Distant bayfront skyline.  The tapered Spring Bamboo echo and low sports
    # pavilion give Shenzhen/Houhai identity without relying on floating text.
    skyline = [
        (-6.50, 0.48, 0.35, 0.44, 0), (-5.94, 0.48, 0.43, 0.67, 2),
        (-5.24, 0.48, 0.30, 0.36, 1), (-4.71, 0.48, 0.43, 0.73, 4),
        (-4.02, 0.48, 0.33, 0.51, 0), (-3.45, 0.48, 0.43, 0.63, 3),
        (-2.77, 0.48, 0.35, 0.39, 2), (-2.30, 0.48, 0.43, 0.55, 1),
        (-1.67, 0.48, 0.41, 0.91, 4), (-1.04, 0.48, 0.28, 0.44, 0),
        (-0.52, 0.48, 0.41, 0.65, 1), (0.16, 0.48, 0.38, 0.51, 2),
        (0.70, 0.48, 0.44, 0.71, 0), (1.34, 0.48, 0.34, 0.47, 3),
        (1.86, 0.48, 0.43, 0.56, 4), (2.48, 0.48, 0.31, 0.41, 1),
        (2.99, 0.48, 0.42, 0.75, 2), (3.66, 0.48, 0.32, 0.52, 0),
        (4.23, 0.48, 0.39, 0.67, 3), (4.84, 0.48, 0.31, 0.43, 4),
        (5.33, 0.48, 0.39, 0.61, 1), (5.99, 0.48, 0.44, 0.77, 0),
        (6.60, 0.48, 0.32, 0.48, 2),
    ]
    windows = []
    for i, (x, base, width, height, palette) in enumerate(skyline):
        vertical("houhai_building_%02d" % i, x, -0.085, base, base+height,
                 width, 0.019, tower[palette], 0.012)
        vertical("glazed_vertical_rib_%02d" % i, x-width*0.22, -0.097,
                 base+0.045, base+height-0.04, 0.027, 0.006, glass_hi, 0.003)
        vertical("glazed_vertical_rib_%02d_b" % i, x+width*0.22, -0.097,
                 base+0.045, base+height-0.04, 0.027, 0.006, glass_hi, 0.003)
        for row in range(max(2, int(height / 0.11))):
            for col in (-1, 0, 1):
                if rng.random() < (0.20 if dawn else (0.49 if dusk else (0.67 if evening else 0.26))):
                    windows.append((x+col*width*0.18, base+0.105+row*0.095,
                                    width*0.085, 0.030))
    # Landmark Spring Bamboo echo: a tall continuous taper remains entirely
    # within the pane instead of poking unrealistically through the top rail.
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.24, radius2=0.055,
                                    depth=0.99, location=(2.99, -0.109, 0.985))
    spring_bamboo = bpy.context.object
    spring_bamboo.name = "houhai_spring_bamboo_taper"
    spring_bamboo.scale.y = 0.15
    spring_bamboo.data.materials.append(tower[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for t in (-0.7, -0.35, 0.0, 0.35, 0.7):
        curve("spring_bamboo_vertical_glazing", [
            (2.99+t*0.24, -0.155, 0.51),
            (2.99+t*0.12, -0.154, 1.02),
            (2.99+t*0.055, -0.151, 1.46),
        ], 0.006, glass_hi)
    # Sculpted sports pavilion has a plinth, so its roof is physically anchored.
    vertical("bay_sports_hall_glazed_plinth", -3.80, -0.112,
             0.48, 0.57, 0.82, 0.04, tower[0], 0.028)
    ellipsoid("bay_sports_hall_roof", (-3.80, -0.141, 0.58),
              (0.47, 0.035, 0.13), cream, 26, 12)
    quad_batch("distant_window_lights", windows, -0.100, building_lights)

    # Horizontal water glints and nearer Talent Park promenade.
    glints = []
    for i in range(46):
        x = rng.uniform(-7.0, 7.0)
        z = rng.uniform(0.07, 0.35)
        glints.append((x, z, rng.uniform(0.05, 0.24), 0.007))
    quad_batch("bay_water_glints", glints, -0.091, water_light)
    if evening or dusk or dawn:
        gold_glints = []
        for x in ((-6.94, -6.77, -6.55) if dawn else ((-1.34, -1.14, -1.54, -0.94, 2.99) if dusk else (-5.90, -4.70, -1.65, 0.73, 2.99, 4.23, 5.98))):
            for i in range(7):
                gold_glints.append((x+rng.uniform(-0.16, 0.16),
                                    0.12+i*0.031,
                                    rng.uniform(0.027, 0.13), 0.006))
        quad_batch("building_light_reflections_on_bay", gold_glints,
                   -0.094, reflected_gold)
    box("near_baywalk_green_ribbon", (0, -0.120, 0.14),
        (WIDTH-0.12, 0.02, 0.12), grass, 0.012)
    box("near_baywalk_rail_top", (0, -0.145, 0.285),
        (WIDTH-0.12, 0.025, 0.014), park_rail, 0.002)
    for x in [i*0.43-7.1 for i in range(34)]:
        vertical("promenade_rail_picket", x, -0.145, 0.09, 0.29,
                 0.013, 0.013, park_rail, 0.001)
    for i, x in enumerate([-6.65, -5.36, -3.07, -1.82, -0.46,
                           0.84, 1.80, 3.45, 4.72, 6.34]):
        stem = 0.18 + (i % 3)*0.022
        vertical("park_tree_trunk_%d" % i, x, -0.133, 0.15, 0.15+stem,
                 0.024, 0.018, trunk, 0.004)
        for side in (-1, 0, 1):
            ellipsoid("canopy_%d_%d" % (i, side),
                      (x+side*0.07, -0.145-abs(side)*0.002,
                       0.34+stem*0.40+abs(side)*0.035),
                      (0.12, 0.026, 0.10), leaf[(i+side)%3], 12, 8)
    # Carefully placed promenade lamps are luminous at night, but remain
    # modest in daytime so the restaurant's lighting can carry the scene.
    for i, x in enumerate((-6.15, -4.60, -2.28, 0.0, 2.10, 4.18, 6.08)):
        vertical("baywalk_lamppost_%d" % i, x, -0.152, 0.17, 0.44,
                 0.018, 0.018, inner_frame, 0.002)
        ellipsoid("baywalk_lamp_%d" % i, (x, -0.162, 0.45),
                  (0.033, 0.018, 0.024), park_lights, 12, 8)

    # Three-dimensional frame, mullions, transom, stone sill and mullion caps.
    for x in (-7.32, -3.66, 0.0, 3.66, 7.32):
        vertical("main_oak_mullion", x, -0.205, 0.0, HEIGHT,
                 0.105, 0.128, frame, 0.013)
        vertical("inner_glazing_bead", x, -0.283, 0.03, HEIGHT-0.03,
                 0.020, 0.010, cream, 0.004)
    for x in (-5.49, -1.83, 1.83, 5.49):
        vertical("thin_sash_split", x, -0.177, 0.06, 1.46,
                 0.027, 0.040, frame, 0.004)
    box("window_top_rail", (0, -0.210, HEIGHT-0.05),
        (WIDTH, 0.14, 0.10), frame, 0.012)
    box("window_transom_rail", (0, -0.200, 1.48),
        (WIDTH, 0.08, 0.045), frame, 0.008)
    box("window_bottom_rail", (0, -0.195, 0.065),
        (WIDTH, 0.13, 0.13), frame, 0.012)
    box("continuous_celadon_stone_sill", (0, -0.272, 0.035),
        (WIDTH + 0.12, 0.35, 0.075), celadon, 0.022)
    for x in (-5.48, 5.48):
        box("window_corner_planter", (x, -0.31, 0.19),
            (0.43, 0.25, 0.20), cream, 0.032)
        for offset in (-0.11, 0.0, 0.11):
            ellipsoid("planter_leaf", (x+offset, -0.31, 0.32),
                      (0.10, 0.065, 0.11), leaf[(int(offset*10)+3)%3], 12, 8)


def export_and_preview(evening, dusk=False, dawn=False):
    name = "park_kitchen_bay_window_dawn" if dawn else ("park_kitchen_bay_window_dusk" if dusk else ("park_kitchen_bay_window_evening" if evening else "park_kitchen_bay_window_day"))
    build_window(evening, dusk, dawn)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + ".blend")))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB")

    world = bpy.data.worlds[0]
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (
        (0.68, 0.59, 0.59, 1) if dawn else ((0.46, 0.30, 0.31, 1) if dusk else ((0.12, 0.18, 0.25, 1) if evening else (0.75, 0.81, 0.77, 1))))
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.55
    bpy.ops.object.light_add(type="AREA", location=(-5.0, -5.0, 6.0))
    bpy.context.object.data.energy = 620 if dawn else (650 if dusk else (500 if evening else 750))
    if dusk or dawn:
        bpy.context.object.data.color = (1.0, 0.68, 0.47) if dawn else (1.0, 0.54, 0.32)
    bpy.context.object.data.size = 8.0
    bpy.ops.object.camera_add(location=(0.5, -11.0, 4.1))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.88)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 15.5
    bpy.context.scene.camera = camera
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene.render.resolution_x = 1600
    bpy.context.scene.render.resolution_y = 500
    bpy.context.scene.render.resolution_percentage = 100
    bpy.context.scene.render.image_settings.file_format = "PNG"
    bpy.context.scene.render.film_transparent = False
    bpy.context.scene.render.filepath = str(OUT / (name + "_preview.png"))
    bpy.ops.render.render(write_still=True)
    print("KITCHEN_WINDOW_READY:" + name)


if __name__ == "__main__":
    if "--dawn-only" in sys.argv:
        export_and_preview(False, False, True)
    elif "--dusk-only" in sys.argv:
        export_and_preview(False, True)
    else:
        export_and_preview(False)
        export_and_preview(True)
        export_and_preview(False, True)
