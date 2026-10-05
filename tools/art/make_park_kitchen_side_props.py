"""Authored pantry and pickup counter dressing for the Talent Park kitchen.

Each GLB has its origin on the existing worktop, with local -Y facing the
player.  The four groups deliberately have different silhouettes and utility:
staple storage, fresh ingredients, takeaway assembly, and pickup display.
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
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0

mat = food.mat
box = food.box
ellipsoid = food.ellipsoid
cylinder = food.cylinder
torus = food.torus
curve = food.curve_line
mesh = food.mesh

OAK = mat("side_props_honey_oak", "#A98261", 0.80)
OAK_DEEP = mat("side_props_oak_reveal", "#795944", 0.88)
WICKER = mat("side_props_woven_reed", "#C7A879", 0.85)
PAPER = mat("side_props_unbleached_paper", "#E9D8B9", 0.88)
PAPER_EDGE = mat("side_props_folded_paper_edge", "#C9AF89", 0.91)
CERAMIC = mat("side_props_warm_celadon", "#AFC8B9", 0.43)
CREAM = mat("side_props_cream_ceramic", "#EFE7D6", 0.48)
METAL = mat("side_props_brushed_steel", "#9EAAA3", 0.42, 0.29)
INK = mat("side_props_ink_green", "#52766A", 0.84)
LEAF = mat("side_props_leaf_green", "#6F9870", 0.83)
LEAF_LIGHT = mat("side_props_light_leaf", "#A9BD83", 0.78)
CARROT = mat("side_props_carrot_orange", "#D88958", 0.71)
EGG = mat("side_props_eggshell", "#EBD8B7", 0.73)
EGG_PINK = mat("side_props_pink_eggshell", "#DAB693", 0.73)
RICE = mat("side_props_rice_grain", "#F3EAD4", 0.79)
SAUCE = mat("side_props_chilli_sauce", "#A75C4A", 0.54)
TEA = mat("side_props_jasmine_tea", "#A4B785", 0.52)
CORAL = mat("side_props_seal_coral", "#CC8E79", 0.64)


def translated_group(name, objects, xyz):
    """Move pieces made around the origin without merging their materials."""
    for obj in objects:
        obj.location.x += xyz[0]
        obj.location.y += xyz[1]
        obj.location.z += xyz[2]
        obj.name = name + "__" + obj.name


def add_group(name, builder, xyz):
    before = set(bpy.context.scene.objects)
    builder()
    translated_group(name, set(bpy.context.scene.objects) - before, xyz)


def leaf_blade(name, origin, angle, length, width, material):
    """Curved raised leaf with visible central vein and a pointed silhouette."""
    x, y, z = origin
    a = angle
    forward = (math.cos(a), math.sin(a))
    side = (-math.sin(a), math.cos(a))
    verts = []
    for t, spread, rise in ((0.0, 0.08, 0.0), (0.35, 0.42, 0.12),
                            (0.72, 0.48, 0.08), (1.0, 0.0, -0.02)):
        cx = x + forward[0] * length * t
        cy = y + forward[1] * length * t
        cz = z + rise * length
        verts.extend([(cx - side[0] * width * spread,
                       cy - side[1] * width * spread, cz),
                      (cx + side[0] * width * spread,
                       cy + side[1] * width * spread, cz)])
    faces = [(i, i + 1, i + 3, i + 2) for i in (0, 2, 4)]
    mesh(name + "_lamina", verts, faces, material, 0.006)
    curve(name + "_raised_midvein", [
        (x, y, z + 0.004),
        (x + forward[0] * length * 0.5, y + forward[1] * length * 0.5, z + length * 0.10),
        (x + forward[0] * length, y + forward[1] * length, z - length * 0.01),
    ], 0.004, LEAF_LIGHT)


def slatted_crate(name, sx=0.78, sy=0.47):
    box(name + "_base", (0, 0, 0.036), (sx, sy, 0.065), OAK_DEEP, 0.016)
    for y in (-sy / 2 + 0.025, sy / 2 - 0.025):
        box(name + "_long_rail", (0, y, 0.121), (sx, 0.039, 0.13), OAK, 0.014)
        box(name + "_upper_slatted_edge", (0, y, 0.203), (sx, 0.034, 0.038), WICKER, 0.012)
    for x in (-sx / 2 + 0.025, sx / 2 - 0.025):
        box(name + "_end_rail", (x, 0, 0.121), (0.039, sy, 0.13), OAK, 0.013)
    for x in (-sx * 0.28, 0, sx * 0.28):
        box(name + "_front_woven_slit", (x, -sy / 2 - 0.001, 0.117),
            (0.013, 0.004, 0.082), OAK_DEEP, 0.003)


def bok_choy():
    for idx, (x, y, angle) in enumerate(((-0.23, 0.02, 2.15),
                                         (0.01, -0.05, 1.5),
                                         (0.23, 0.03, 0.72))):
        ellipsoid(f"bok_choy_{idx}_white_stem", (x, y, 0.245),
                  (0.082, 0.055, 0.103), CREAM, 16, 9)
        for leaf_idx, shift in enumerate((-0.35, 0.15, 0.48)):
            a = angle + shift
            leaf_blade(f"bok_choy_{idx}_{leaf_idx}",
                       (x, y, 0.293), a, 0.245, 0.126,
                       LEAF if leaf_idx != 1 else LEAF_LIGHT)


def carrots():
    for idx, (x, y, rot) in enumerate(((-0.24, -0.06, 0.2),
                                      (-0.10, 0.06, -0.25),
                                      (0.13, -0.08, 0.52),
                                      (0.28, 0.07, -0.12))):
        root = ellipsoid(f"carrot_{idx}_tapered_body", (x, y, 0.205),
                         (0.043, 0.155, 0.045), CARROT, 14, 9)
        root.rotation_euler.z = rot
        for j, spread in enumerate((-0.55, 0.0, 0.55)):
            curve(f"carrot_{idx}_leaf_{j}", [(x, y + 0.11, 0.208),
                                             (x + spread * 0.058, y + 0.17, 0.262),
                                             (x + spread * 0.090, y + 0.205, 0.242)],
                  0.008, LEAF)


def egg_carton():
    box("open_egg_carton_pulp_base", (0, 0, 0.055),
        (0.73, 0.43, 0.10), PAPER_EDGE, 0.028)
    box("open_egg_carton_flared_lid", (0, 0.228, 0.15),
        (0.72, 0.033, 0.28), PAPER, 0.018)
    for i, x in enumerate((-0.235, 0, 0.235)):
        for j, y in enumerate((-0.110, 0.095)):
            ellipsoid(f"carton_cup_shadow_{i}_{j}", (x, y, 0.102),
                      (0.101, 0.087, 0.030), OAK_DEEP, 14, 8)
            ellipsoid(f"carton_egg_{i}_{j}", (x, y, 0.177),
                      (0.082, 0.071, 0.111), EGG if (i + j) % 2 else EGG_PINK, 16, 10)


def pantry_fresh():
    # Three distinct ingredient families in slatted produce trays.
    for name, x, build in (("greens", -0.76, bok_choy),
                           ("roots", 0.0, carrots),
                           ("eggs", 0.77, egg_carton)):
        if name != "eggs":
            add_group(name + "_crate", lambda n=name: slatted_crate(n), (x, -0.03, 0))
        add_group(name, build, (x, -0.03, 0))


def paper_sack(name, width, depth, height, emblem):
    box(name + "_filled_body", (0, 0, height * 0.47),
        (width, depth, height * 0.92), PAPER, 0.055)
    box(name + "_folded_top", (0, 0.012, height * 0.925),
        (width * 0.92, depth * 0.91, 0.073), PAPER_EDGE, 0.025)
    box(name + "_front_fold", (0, -depth * 0.503, height * 0.69),
        (width * 0.72, 0.008, 0.016), PAPER_EDGE, 0.006)
    if emblem == "rice":
        for j in range(3):
            ellipsoid(name + f"_rice_grain_{j}",
                      ((j - 1) * 0.065, -depth * 0.513, height * 0.38 + j * 0.02),
                      (0.023, 0.009, 0.040), RICE, 10, 7)
        curve(name + "_sprig", [(-0.04, -depth * 0.515, height * 0.45),
                                 (0.0, -depth * 0.520, height * 0.31),
                                 (0.04, -depth * 0.515, height * 0.20)], 0.008, INK)
    else:
        leaf_blade(name + "_herb_emblem", (0, -depth * 0.515, height * 0.29),
                   math.pi / 2, 0.18, 0.055, INK)


def glass_jar(name, color, radius=0.12, height=0.32):
    cylinder(name + "_thick_glass_base", (0, 0, 0.025), radius + 0.008, 0.050, CREAM, 20)
    cylinder(name + "_visible_contents", (0, 0, height * 0.50), radius,
             height * 0.81, color, 20)
    torus(name + "_rolled_glass_lip", (0, 0, height * 0.91), radius, 0.018, CREAM, 20)
    cylinder(name + "_cork_stop", (0, 0, height * 0.96), radius * 0.84, 0.070, OAK, 18)
    box(name + "_paper_band", (0, -radius - 0.008, height * 0.48),
        (radius * 1.6, 0.014, 0.084), PAPER, 0.006)
    box(name + "_band_mark", (0, -radius - 0.019, height * 0.48),
        (radius * 0.58, 0.004, 0.034), color, 0.004)


def pantry_staples():
    add_group("rice_bag", lambda: paper_sack("rice", 0.45, 0.32, 0.47, "rice"),
              (-0.93, 0.0, 0))
    add_group("flour_bag", lambda: paper_sack("flour", 0.38, 0.29, 0.39, "herb"),
              (-0.42, 0.04, 0))
    for i, (x, color, h) in enumerate(((0.05, SAUCE, 0.33),
                                       (0.39, TEA, 0.37),
                                       (0.73, CARROT, 0.29))):
        add_group(f"labelled_spice_jar_{i}",
                  lambda c=color, z=h: glass_jar("labelled_spice", c, 0.13, z),
                  (x, -0.025, 0))
    # A garlic braid is a different shape from the jars and bags.
    curve("garlic_braid_hanging_string", [(1.08, 0.07, 0.40),
                                          (1.08, 0.05, 0.22),
                                          (1.05, 0.01, 0.13)], 0.011, OAK_DEEP)
    for i, pos in enumerate(((1.00, -0.04, 0.12), (1.15, -0.04, 0.17),
                             (1.08, 0.06, 0.06))):
        ellipsoid(f"braided_garlic_bulb_{i}", pos,
                  (0.075, 0.068, 0.075), CREAM, 14, 9)
        for j in (-1, 1):
            curve(f"garlic_bulb_{i}_rib_{j}",
                  [(pos[0] + j * 0.015, pos[1] - 0.060, pos[2] + 0.040),
                   (pos[0] + j * 0.032, pos[1] - 0.068, pos[2]),
                   (pos[0] + j * 0.014, pos[1] - 0.058, pos[2] - 0.047)],
                  0.0025, PAPER_EDGE)


def folded_bag(name, width, depth, height, seal):
    box(name + "_stiff_lower_body", (0, 0, height * 0.43),
        (width, depth, height * 0.82), PAPER, 0.045)
    box(name + "_folded_closed_lip", (0, 0, height * 0.90),
        (width * 0.90, depth * 0.86, 0.06), PAPER_EDGE, 0.014)
    box(name + "_front_bottom_fold", (0, -depth * 0.505, height * 0.18),
        (width * 0.76, 0.009, 0.026), PAPER_EDGE, 0.005)
    for side in (-1, 1):
        curve(name + f"_flat_paper_handle_{side}",
              [(side * width * 0.20, -depth * 0.14, height * 0.91),
               (side * width * 0.20, -depth * 0.12, height + 0.12),
               (side * width * 0.09, -depth * 0.12, height + 0.16),
               (0, -depth * 0.12, height + 0.14)],
              0.010, OAK)
    cylinder(name + "_front_seal", (0, -depth * 0.518, height * 0.56),
             width * 0.115, 0.014, seal, 16).rotation_euler.x = math.pi / 2


def takeaway_cup(name, drink, straw):
    cylinder(name + "_paper_cup", (0, 0, 0.22), 0.155, 0.38, CREAM, 24)
    cylinder(name + "_visible_drink", (0, 0, 0.412), 0.138, 0.018, drink, 24)
    torus(name + "_rolled_cup_rim", (0, 0, 0.423), 0.152, 0.016, CERAMIC, 24)
    box(name + "_ink_wrap", (0, -0.156, 0.25), (0.17, 0.012, 0.13), INK, 0.012)
    curve(name + "_bent_straw", [(-0.034, 0.012, 0.420),
                                 (-0.048, 0.012, 0.626),
                                 (0.020, 0.012, 0.644)], 0.011, straw)


def stacked_boxes(name):
    for i in range(2):
        z = 0.08 + i * 0.18
        box(name + f"_shallow_meal_box_{i}", (0, 0, z),
            (0.60, 0.42, 0.13), CREAM, 0.045)
        box(name + f"_flush_lid_{i}", (0, 0, z + 0.073),
            (0.65, 0.47, 0.035), PAPER, 0.020)
        box(name + f"_paper_sleeve_{i}",
            (0, -0.228, z + 0.032), (0.16, 0.015, 0.065), INK, 0.008)


def pickup_packing():
    add_group("bag_small", lambda: folded_bag("garden_takeaway", 0.42, 0.34, 0.42, LEAF),
              (-0.72, 0.06, 0))
    add_group("bag_large", lambda: folded_bag("noodle_takeaway", 0.50, 0.38, 0.54, CORAL),
              (-0.12, 0.10, 0))
    add_group("stacked_lidded_meal_boxes", lambda: stacked_boxes("stacked_takeaway"),
              (0.70, 0.045, 0))
    add_group("sealed_tea_cup", lambda: takeaway_cup("to_go_tea", TEA, CORAL),
              (0.84, -0.31, 0))


def service_tray(name, width=1.03, depth=0.57):
    box(name + "_solid_base", (0, 0, 0.032),
        (width, depth, 0.058), OAK_DEEP, 0.025)
    box(name + "_pale_wipeable_liner", (0, 0, 0.064),
        (width - 0.08, depth - 0.075, 0.011), CREAM, 0.008)
    for y in (-depth / 2 + 0.026, depth / 2 - 0.026):
        box(name + "_raised_reed_rail", (0, y, 0.083),
            (width, 0.050, 0.065), WICKER, 0.022)
    for x in (-width / 2 + 0.035, width / 2 - 0.035):
        box(name + "_short_reed_rail", (x, 0, 0.083),
            (0.05, depth, 0.065), WICKER, 0.022)


def wrapped_bun(name):
    box(name + "_folded_sleeve", (0, 0, 0.13),
        (0.32, 0.28, 0.17), PAPER, 0.035)
    ellipsoid(name + "_golden_dome", (0, 0, 0.225),
              (0.167, 0.145, 0.092), mat("baked_bun_gold", "#D8A46B", 0.68), 18, 11)
    curve(name + "_baked_split", [(-0.10, -0.01, 0.28),
                                   (0, 0, 0.30), (0.10, 0.015, 0.28)],
          0.004, PAPER_EDGE)
    box(name + "_sleeve_mark", (0, -0.144, 0.13),
        (0.105, 0.008, 0.045), CORAL, 0.008)


def rice_roll_pack(name):
    box(name + "_shallow_carton", (0, 0, 0.145),
        (0.44, 0.33, 0.16), PAPER, 0.033)
    for i in range(3):
        ellipsoid(name + f"_visible_roll_{i}",
                  ((i - 1) * 0.115, 0, 0.245),
                  (0.082, 0.125, 0.055), RICE, 14, 9)
        ellipsoid(name + f"_green_filling_{i}",
                  ((i - 1) * 0.115, -0.120, 0.246),
                  (0.038, 0.012, 0.030), LEAF, 10, 7)
    box(name + "_folded_front_flap", (0, -0.174, 0.127),
        (0.40, 0.014, 0.090), PAPER_EDGE, 0.006)


def pickup_ready():
    add_group("buns_tray", lambda: service_tray("bun_pickup_tray"),
              (-0.63, 0.0, 0))
    add_group("rolls_tray", lambda: service_tray("roll_pickup_tray"),
              (0.63, 0.0, 0))
    for idx, x in enumerate((-0.82, -0.46)):
        add_group(f"wrapped_bun_{idx}", lambda: wrapped_bun("ready_bun"),
                  (x, 0.0, 0.068))
    add_group("boxed_rice_roll", lambda: rice_roll_pack("ready_rolls"),
              (0.63, 0.0, 0.068))
    # Paper ticket clips give the pickup surface a specific service identity.
    for x, tint in ((-0.55, CORAL), (0.70, LEAF)):
        box("service_ticket", (x, 0.39, 0.24),
            (0.23, 0.010, 0.27), PAPER, 0.006)
        box("ticket_upper_color_mark", (x, 0.384, 0.32),
            (0.105, 0.004, 0.025), tint, 0.004)
        box("ticket_clip", (x, 0.380, 0.385),
            (0.065, 0.022, 0.039), METAL, 0.008)


ASSETS = [
    ("park_kitchen_pantry_staples", pantry_staples, 3.2),
    ("park_kitchen_pantry_fresh", pantry_fresh, 3.4),
    ("park_kitchen_pickup_packing", pickup_packing, 3.3),
    ("park_kitchen_pickup_ready", pickup_ready, 3.4),
]


def export_asset(name, builder, ortho_scale):
    food.reset()
    builder()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + ".blend")))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + ".glb")), export_format="GLB")
    # The studio floor is preview only; game GLBs sit flush on existing worktops.
    floor = mat("PREVIEW_ONLY_side_prop_studio", "#D9DECF", 0.95)
    box("PREVIEW_ONLY_studio_floor", (0, 0, -0.074), (3.2, 1.9, 0.13), floor)
    world = bpy.data.worlds[0]
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.83, 0.86, 0.81, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.47
    bpy.ops.object.light_add(type="AREA", location=(-2.2, -2.4, 3.3))
    bpy.context.object.data.energy = 340
    bpy.context.object.data.size = 2.5
    bpy.ops.object.light_add(type="AREA", location=(2.0, 1.0, 2.1))
    bpy.context.object.data.energy = 110
    bpy.context.object.data.size = 1.7
    bpy.ops.object.camera_add(location=(2.0, -3.4, 2.5))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.22)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho_scale
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 650
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT / (name + "_preview.png"))
    bpy.ops.render.render(write_still=True)
    print("PARK_KITCHEN_SIDE_PROP_READY:" + name)


requested = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else set()
for asset_name, build, scale in ASSETS:
    if not requested or asset_name in requested:
        export_asset(asset_name, build, scale)
