"""Original plated food miniatures for the Talent Park restaurant.

Each recipe builds from its own silhouette, vessel and ingredient composition.
Assets use metre scale, +Z up in Blender, with a bottom-centred origin and a
local -Y presentation side (Godot +Z after GLB import).
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "assets" / "art" / "models" / "food"
SOURCE_DIR = ROOT / "tools" / "art" / "source" / "food"
MODEL_DIR.mkdir(parents=True, exist_ok=True)
SOURCE_DIR.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0


def srgb(value):
    vals = [int(value[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in vals) + (1,)


MATS = {}


def mat(name, color, rough=0.7, metal=0):
    key = (name, color, rough, metal)
    if key in MATS:
        return MATS[key]
    result = bpy.data.materials.new(name)
    result.diffuse_color = srgb(color)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = srgb(color)
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Metallic"].default_value = metal
    MATS[key] = result
    return result


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    MATS.clear()


def soften(obj, width=0.009):
    if not width:
        return obj
    bevel = obj.modifiers.new("soft_food_edge", "BEVEL")
    bevel.width = width
    bevel.segments = 3
    bevel.limit_method = "ANGLE"
    normal = obj.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def box(name, pos, size, material, bevel=0.009):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return soften(obj, bevel)


def ellipsoid(name, pos, size, material, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    obj.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def cylinder(name, pos, radius, depth, material, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return soften(obj, 0.005)


def torus(name, pos, major, minor, material, segments=32):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments, minor_segments=8,
                                     location=pos, major_radius=major,
                                     minor_radius=minor)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def curve_line(name, points, radius, material):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for handle, point in zip(spline.bezier_points, points):
        handle.co = point
        handle.handle_left_type = "AUTO"
        handle.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def mesh(name, verts, faces, material, thick=0):
    data = bpy.data.meshes.new(name + "_mesh")
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    if thick:
        solid = obj.modifiers.new("organic_food_thickness", "SOLIDIFY")
        solid.thickness = thick
        soften(obj, 0.003)
    return obj


def porcelain_plate(name, radius=0.42, elliptical_y=0.82):
    ceramic = mat("cream_porcelain", "#F5EFDF", 0.36)
    rim = mat("plate_warm_celadon_rim", "#A9C4B4", 0.43)
    base = ellipsoid(name + "_base", (0, 0, 0.034),
                     (radius, radius * elliptical_y, 0.033), ceramic, 32, 12)
    ring = torus(name + "_rolled_rim", (0, 0, 0.055), radius * 0.91, 0.025, rim)
    ring.scale.y = elliptical_y
    return base


def wood_platter(name, width=0.90, depth=0.67):
    wood = mat("oiled_small_platter", "#AE7E59", 0.74)
    edge = mat("platter_endgrain", "#805E47", 0.86)
    box(name + "_body", (0, 0, 0.044), (width, depth, 0.083), wood, 0.051)
    box(name + "_inset", (0, 0, 0.091), (width - 0.105, depth - 0.10, 0.012),
        edge, 0.018)


def lathe(name, profile, material, segments=32):
    verts = []
    for radius, height in profile:
        for i in range(segments):
            angle = math.tau * i / segments
            verts.append((radius * math.cos(angle), radius * math.sin(angle), height))
    faces = []
    for row in range(len(profile) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((row * segments + i, row * segments + j,
                          (row + 1) * segments + j, (row + 1) * segments + i))
    return mesh(name, verts, faces, material, 0.009)


def serving_bowl(name, radius=0.37, height=0.23, color="#CAD8C4"):
    vessel = mat(name + "_glazed_ceramic", color, 0.39)
    lip = mat(name + "_rim", "#F0EAD8", 0.43)
    foot = mat(name + "_foot", "#B0A99C", 0.73)
    lathe(name + "_hollow_profile", [
        (0.18, 0.018), (radius * 0.70, 0.035), (radius * 0.92, height * 0.83),
        (radius, height), (radius * 0.90, height + 0.003),
        (radius * 0.79, height * 0.43), (0.16, height * 0.30),
    ], vessel)
    torus(name + "_rolled_lip", (0, 0, height), radius * 0.95, 0.020, lip)
    cylinder(name + "_foot_ring", (0, 0, 0.018), radius * 0.54, 0.028, foot)


def garnish_leaf(name, pos, length, material, angle=0):
    obj = ellipsoid(name, pos, (length * 0.5, length * 0.23, length * 0.055),
                    material, 14, 8)
    obj.rotation_euler.z = angle
    return obj


def garden_rice_roll():
    """Three folded herb rice rolls with open ends and sauce on an oval plate."""
    porcelain_plate("garden_oval_plate", 0.46, 0.80)
    rice = mat("silky_steamed_rice_sheet", "#EEEADB", 0.49)
    rice_edge = mat("rice_sheet_fold", "#D8D8C8", 0.55)
    green = mat("garden_herbs", "#5E9868", 0.80)
    green_lit = mat("sunlit_herbs", "#8CB889", 0.80)
    carrot = mat("carrot_julienne", "#DF985D", 0.74)
    sauce = mat("soy_sauce_glaze", "#674D3C", 0.28)
    sesame = mat("toasted_sesame", "#E5C78D", 0.70)
    scallion = mat("scallion_curls", "#4D8961", 0.71)
    # A shallow pool appears under, not over, the milky sheets.
    ellipsoid("soy_sauce_pool", (0.0, 0.0, 0.073),
              (0.35, 0.245, 0.012), sauce, 28, 8)
    for i, x in enumerate((-0.235, 0, 0.235)):
        ellipsoid(f"rice_roll_{i}", (x, 0.018, 0.145),
                  (0.103, 0.262, 0.082), rice, 24, 14)
        # A thin draped flap gives each roll a real folded edge.
        verts = [
            (x - 0.10, -0.245, 0.145), (x + 0.10, -0.245, 0.145),
            (x + 0.086, 0.205, 0.180), (x - 0.086, 0.205, 0.180),
            (x - 0.022, 0.19, 0.218), (x + 0.022, 0.19, 0.218),
        ]
        mesh(f"folded_rice_flap_{i}", verts,
             [(0, 1, 5, 4, 3), (1, 2, 5), (3, 4, 5, 2)], rice_edge, 0.010)
        # A sliced end exposes the leafy cross-section inside the rice sheet.
        ellipsoid(f"cut_green_core_{i}", (x, -0.253, 0.145),
                  (0.071, 0.012, 0.055), green, 20, 12)
        lip = torus(f"rice_sheet_cut_lip_{i}",
                    (x, -0.264, 0.145), 0.064, 0.011, rice_edge, 24)
        lip.rotation_euler.x = math.pi / 2
        for j in range(3):
            ellipsoid(f"leaf_cross_section_{i}_{j}",
                      (x - 0.032 + j * 0.028, -0.267,
                       0.145 + (j % 2) * 0.017),
                      (0.023, 0.007, 0.013),
                      green_lit if j == 1 else green, 12, 8)
        for j in range(2):
            box(f"carrot_julienne_cut_{i}_{j}",
                (x - 0.027 + j * 0.038, -0.272, 0.126 + j * 0.023),
                (0.014, 0.008, 0.020), carrot, 0.003)
        for j in range(2):
            garnish_leaf(f"lengthwise_herb_{i}_{j}",
                         (x - 0.031 + j * 0.054, -0.128, 0.221),
                         0.10, green_lit, 0.28 + j * 0.24)
        curve_line(f"soy_glaze_ripe_{i}",
                   [(x - 0.09, -0.05, 0.214),
                    (x + 0.01, 0.025, 0.221),
                    (x + 0.075, 0.11, 0.205)],
                   0.0065, sauce)
        for j in range(4):
            ellipsoid(f"sesame_{i}_{j}",
                      (x - 0.06 + j * 0.036, 0.025 + ((i + j) % 2) * 0.06, 0.224),
                      (0.009, 0.005, 0.003), sesame, 10, 6)
    for j in range(5):
        a = j * math.tau / 5
        ellipsoid(f"garden_garnish_leaf_{j}",
                  (0.30 + 0.05 * math.cos(a),
                   0.22 + 0.05 * math.sin(a), 0.124),
                  (0.042, 0.022, 0.009), scallion, 12, 7)


def macao_spice_bun():
    """Split sesame bun, crisp chicken, sauce, cabbage and loose garnish."""
    wood_platter("spice_bun_board", 0.92, 0.67)
    bun = mat("brioche_toasted_gold", "#D49B63", 0.69)
    bun_edge = mat("brioche_light_crumb", "#F0C68D", 0.78)
    chicken = mat("spice_chicken_crust", "#B56D48", 0.74)
    chicken_lit = mat("golden_crispy_ridges", "#D9945B", 0.78)
    green = mat("romaine_green", "#6CA16B", 0.83)
    cabbage = mat("pickled_cabbage", "#B57382", 0.80)
    sauce = mat("macao_spice_oil", "#B24F3F", 0.40)
    sesame = mat("bun_sesame_cream", "#F6DFB1", 0.81)
    # Bun top is pulled slightly back to expose the cut layers at the front.
    ellipsoid("toasted_bun_bottom", (0, 0.01, 0.151),
              (0.31, 0.255, 0.080), bun_edge, 28, 14)
    for i in range(7):
        angle = i * math.tau / 7
        leaf_obj = ellipsoid(f"ruffled_romaine_{i}",
                            (0.19 * math.cos(angle), 0.015 + 0.18 * math.sin(angle), 0.210),
                            (0.14, 0.085, 0.028), green, 14, 8)
        leaf_obj.rotation_euler.z = angle
    ellipsoid("chicken_fillet_main", (0, -0.014, 0.257),
              (0.288, 0.230, 0.086), chicken, 24, 14)
    for i in range(13):
        a = i * 2.4
        r = 0.06 + (i % 4) * 0.053
        ellipsoid(f"crisp_chicken_ridge_{i}",
                  (r * math.cos(a), -0.018 + r * math.sin(a), 0.325 + 0.015 * (i % 3)),
                  (0.040, 0.035, 0.019), chicken_lit if i % 3 else chicken, 12, 8)
    for i in range(4):
        curve_line(f"spice_sauce_drizzle_{i}",
                   [(-0.24 + i * 0.15, -0.14, 0.337),
                    (-0.17 + i * 0.15, 0.02, 0.354),
                    (-0.21 + i * 0.15, 0.15, 0.335)],
                   0.009, sauce)
    for i in range(5):
        ellipsoid(f"pickled_cabbage_{i}",
                  (-0.16 + i * 0.079, -0.14, 0.349),
                  (0.052, 0.038, 0.018), cabbage, 14, 8)
    ellipsoid("toasted_bun_top", (0, 0.069, 0.420),
              (0.310, 0.245, 0.107), bun, 28, 16)
    ellipsoid("bun_crown_highlight", (-0.080, -0.055, 0.481),
              (0.13, 0.07, 0.022), bun_edge, 16, 8)
    rng = random.Random(2007)
    for i in range(20):
        a = rng.uniform(0, math.tau)
        r = math.sqrt(rng.uniform(0, 1)) * 0.225
        x = r * math.cos(a)
        y = 0.069 + r * math.sin(a) * 0.75
        z = 0.435 + 0.105 * math.sqrt(max(0, 1 - (r / 0.31) ** 2))
        seed = ellipsoid(f"bun_sesame_{i}", (x, y, z),
                         (0.015, 0.006, 0.003), sesame, 10, 6)
        seed.rotation_euler.z = a
    # Side salad and sauce cup communicate a complete plated menu item.
    cylinder("spice_oil_cup", (0.335, -0.195, 0.162),
             0.071, 0.090, bun_edge, 18)
    cylinder("spice_oil_surface", (0.335, -0.195, 0.211),
             0.058, 0.010, sauce, 18)
    for i in range(3):
        ellipsoid(f"board_cabbage_garnish_{i}",
                  (-0.36, -0.13 + i * 0.12, 0.127),
                  (0.034, 0.065, 0.013), cabbage, 12, 7)


def morning_egg_bun():
    """Soft breakfast bun with a visible yolk and crisp cucumber slices."""
    porcelain_plate("morning_round_plate", 0.42, 0.95)
    bun = mat("steamed_bun_cream", "#E9C997", 0.82)
    bun_gold = mat("bun_pan_toast", "#C78852", 0.70)
    egg_white = mat("fried_egg_white", "#F4F0DF", 0.45)
    yolk = mat("warm_yolk", "#F4BE55", 0.31)
    cucumber = mat("fresh_cucumber_rind", "#63996A", 0.80)
    cucumber_mid = mat("cucumber_centres", "#B9D0A3", 0.73)
    sauce = mat("breakfast_sauce", "#A95F4C", 0.40)
    ellipsoid("bottom_bun_cut_surface", (0, 0.028, 0.120),
              (0.29, 0.24, 0.056), bun)
    ellipsoid("bottom_bun_toast", (0, 0.032, 0.100),
              (0.29, 0.245, 0.031), bun_gold)
    for i in range(5):
        x = -0.19 + i * 0.095
        disc = cylinder(f"cucumber_disc_{i}", (x, -0.085, 0.188),
                        0.070, 0.034, cucumber, 18)
        disc.rotation_euler.x = math.radians(15)
        cylinder(f"cucumber_centre_{i}", (x, -0.085, 0.210),
                 0.047, 0.010, cucumber_mid, 18)
    ellipsoid("fried_egg_irregular_white", (0.015, -0.017, 0.225),
              (0.275, 0.208, 0.046), egg_white, 28, 12)
    for i, (x, y) in enumerate(((-0.14, -0.12), (0.17, -0.05), (0.12, 0.14))):
        ellipsoid(f"fried_egg_white_lobe_{i}", (x, y, 0.209),
                  (0.11, 0.085, 0.027), egg_white, 16, 8)
    ellipsoid("sunny_yolk_dome", (-0.030, -0.045, 0.275),
              (0.112, 0.103, 0.061), yolk, 24, 12)
    ellipsoid("yolk_highlight", (-0.064, -0.083, 0.317),
              (0.026, 0.018, 0.006), egg_white, 12, 7)
    curve_line("sauce_edge", [(-0.25, 0.05, 0.205),
                              (-0.15, 0.18, 0.209),
                              (0.04, 0.20, 0.208)], 0.008, sauce)
    # Tilted upper bun reads as an opened breakfast sandwich.
    top = ellipsoid("open_bun_top", (0.02, 0.12, 0.315),
                    (0.30, 0.205, 0.100), bun, 28, 14)
    top.rotation_euler.x = math.radians(20)
    for i in range(5):
        garnish_leaf(f"cucumber_side_garnish_{i}",
                     (0.32 + (i % 2) * 0.025,
                      -0.17 + i * 0.082, 0.095),
                     0.15, cucumber if i % 2 else cucumber_mid,
                     angle=i * 0.38)


def warm_tofu_bowl():
    """Hollow jade bowl, soft tofu curds, ginger syrup and osmanthus."""
    serving_bowl("tofu_jade_bowl", 0.39, 0.245, "#C8DCC9")
    syrup = mat("ginger_syrup_amber", "#BA8052", 0.38)
    tofu = mat("silken_tofu", "#F3EEE0", 0.43)
    ginger = mat("ginger_strips", "#D9A45F", 0.64)
    flower = mat("osmanthus_gold", "#E8B866", 0.67)
    ellipsoid("ginger_syrup_surface", (0, 0, 0.166),
              (0.325, 0.322, 0.022), syrup, 28, 12)
    for i, (x, y, z, s) in enumerate((
        (-0.19, -0.06, 0.225, 0.11), (0.05, -0.13, 0.231, 0.12),
        (0.20, 0.015, 0.217, 0.10), (-0.07, 0.14, 0.228, 0.11),
        (0.05, 0.04, 0.242, 0.12), (-0.20, 0.15, 0.212, 0.085)
    )):
        box(f"soft_tofu_curd_{i}", (x, y, z),
            (s * 1.38, s * 1.07, s * 0.70), tofu, 0.027)
    for i in range(9):
        a = i * 2.4
        r = 0.07 + 0.020 * (i % 5)
        obj = ellipsoid(f"ginger_sliver_{i}",
                        (r * math.cos(a), r * math.sin(a), 0.289),
                        (0.055, 0.009, 0.006), ginger, 12, 8)
        obj.rotation_euler.z = a
    for i in range(21):
        a = i * 2.63
        r = 0.10 + 0.012 * (i % 10)
        ellipsoid(f"osmanthus_blossom_{i}",
                  (r * math.cos(a), r * math.sin(a), 0.274 + 0.010 * (i % 3)),
                  (0.010, 0.006, 0.003), flower, 8, 6)
    # Spoon is placed at the rim and partly dipped into the dessert.
    ellipsoid("porcelain_spoon_bowl", (0.21, -0.165, 0.270),
              (0.085, 0.055, 0.019), tofu)
    curve_line("spoon_handle", [(0.23, -0.19, 0.272),
                                 (0.33, -0.29, 0.286),
                                 (0.41, -0.37, 0.309)], 0.016, tofu)


def coconut_millet():
    """Warm millet pudding in a coconut shell with fruit and milk swirl."""
    shell = mat("coconut_shell_cocoa", "#8B6852", 0.82)
    fibre = mat("coconut_fibrous_edge", "#B28A6C", 0.89)
    coconut = mat("coconut_white_inside", "#F0E7CF", 0.58)
    millet = mat("millet_cream_gold", "#D7B77F", 0.68)
    milk = mat("coconut_milk_swirl", "#F7EFDA", 0.43)
    papaya = mat("papaya_dice", "#EFAC69", 0.68)
    berry = mat("fruit_berry", "#CF6D70", 0.53)
    mint = mat("fresh_mint", "#6B9E79", 0.77)
    toasted = mat("toasted_coconut_edges", "#C7A176", 0.76)
    serving_bowl("coconut_shell_cup", 0.39, 0.24, "#8B6852")
    torus("coconut_fibrous_lip", (0, 0, 0.245), 0.369, 0.027, fibre)
    cylinder("coconut_cream_inner", (0, 0, 0.155),
             0.315, 0.080, coconut, 32)
    ellipsoid("millet_pudding_surface", (0, 0, 0.218),
              (0.314, 0.312, 0.029), millet, 28, 12)
    for i in range(43):
        a = i * 2.399
        r = math.sqrt((i + 0.5) / 43) * 0.25
        ellipsoid(f"millet_grain_cluster_{i}",
                  (r * math.cos(a), r * math.sin(a), 0.245),
                  (0.020, 0.012, 0.006), fibre, 10, 6)
    curve_line("coconut_milk_spiral", [(-0.12, -0.09, 0.248),
                                       (0.13, -0.06, 0.250),
                                       (0.18, 0.13, 0.249),
                                       (-0.06, 0.18, 0.251)],
               0.010, milk)
    for i, (x, y) in enumerate(((-0.17, -0.15), (-0.07, -0.18),
                                (0.15, 0.02), (0.18, 0.11))):
        box(f"papaya_piece_{i}", (x, y, 0.265),
            (0.066, 0.061, 0.045), papaya, 0.015)
    # Broad fresh fruit wedges and coconut curls make the bowl read as dessert.
    for i, (x, y) in enumerate(((-0.15, 0.025), (0.12, -0.11))):
        mesh(f"papaya_wedge_{i}",
             [(x - 0.057, y - 0.025, 0.255),
              (x + 0.064, y - 0.018, 0.255),
              (x - 0.012, y + 0.071, 0.270)],
             [(0, 1, 2)], papaya, 0.018)
    for i in range(4):
        a = -0.65 + i * 0.43
        curve_line(f"coconut_shaving_{i}",
                   [(0.11 + 0.08 * math.cos(a),
                     0.08 + 0.08 * math.sin(a), 0.254),
                    (0.08 + 0.10 * math.cos(a + 0.18),
                     0.09 + 0.10 * math.sin(a + 0.18), 0.272),
                    (0.05 + 0.13 * math.cos(a + 0.34),
                     0.10 + 0.13 * math.sin(a + 0.34), 0.257)],
                   0.010, coconut if i % 2 else toasted)
    for i, (x, y) in enumerate(((0.01, 0.15), (-0.15, 0.12))):
        ellipsoid(f"berry_piece_{i}", (x, y, 0.275),
                  (0.049, 0.047, 0.038), berry, 16, 10)
    for i in range(3):
        garnish_leaf(f"mint_leaf_{i}", (0.055 + i * 0.029, -0.018, 0.287),
                     0.13, mint, i * 0.6)


def harbour_noodles():
    """Deep blue bowl with loose wheat noodle loops, greens and chili oil."""
    serving_bowl("harbour_blue_bowl", 0.41, 0.26, "#6796A0")
    broth = mat("warm_noodle_broth", "#9A7555", 0.47)
    noodle = mat("wheat_noodle_gold", "#E5B973", 0.64)
    noodle_lit = mat("noodle_sunlit", "#F1D090", 0.63)
    green = mat("noodle_greens", "#5D9367", 0.82)
    chili = mat("chili_oil_red", "#B85B4B", 0.36)
    sesame = mat("scallion_pale", "#C3D7A1", 0.68)
    ellipsoid("noodle_broth_surface", (0, 0, 0.173),
              (0.335, 0.335, 0.021), broth, 30, 10)
    for i in range(13):
        a = i * 2.42
        r = 0.21 - (i % 4) * 0.026
        z = 0.228 + (i % 3) * 0.018
        curve_line(f"curled_noodle_{i}",
                   [(r * math.cos(a), r * math.sin(a), z),
                    (0.08 * math.cos(a + 1.15), 0.08 * math.sin(a + 1.15), z + 0.025),
                    (-r * 0.70 * math.cos(a + 0.6), -r * 0.70 * math.sin(a + 0.6), z),
                    (r * 0.60 * math.cos(a + 1.35), r * 0.60 * math.sin(a + 1.35), z + 0.008)],
                   0.010, noodle_lit if i % 4 == 0 else noodle)
    for i in range(6):
        a = i * math.tau / 6
        garnish_leaf(f"blanched_green_{i}",
                     (0.24 * math.cos(a), 0.21 * math.sin(a), 0.251),
                     0.16, green, a)
    for i in range(7):
        ellipsoid(f"chili_oil_dot_{i}",
                  (-0.12 + (i % 3) * 0.050,
                   -0.06 + (i // 3) * 0.051, 0.259),
                  (0.026, 0.018, 0.006), chili, 12, 7)
    for i in range(8):
        a = i * 2.1
        ellipsoid(f"scallion_slice_{i}",
                  (0.15 * math.cos(a), 0.11 * math.sin(a), 0.269),
                  (0.017, 0.012, 0.005), sesame, 10, 6)
    # Resting chopsticks are physically separate from the bowl rim.
    wood = mat("bamboo_chopsticks", "#B98A59", 0.78)
    for i in range(2):
        curve_line(f"bamboo_chopstick_{i}",
                   [(-0.45 + i * 0.027, -0.25, 0.34),
                    (-0.04 + i * 0.027, 0.18, 0.31)], 0.009, wood)


def chicken_rice():
    """Rice mound, fanned seared chicken slices, greens and soy glaze."""
    porcelain_plate("chicken_rice_plate", 0.45, 0.85)
    rice = mat("fluffy_steamed_rice", "#EEE9D5", 0.75)
    rice_shadow = mat("rice_shadow_grains", "#D8D2BD", 0.80)
    chicken = mat("seared_chicken_skin", "#C78856", 0.68)
    cut = mat("chicken_cut_flesh", "#E7BC8D", 0.73)
    char = mat("chicken_pan_marks", "#8A5741", 0.77)
    greens = mat("chicken_rice_bok_choy", "#679A69", 0.83)
    soy = mat("ginger_soy_pool", "#68463A", 0.34)
    ellipsoid("soy_pool_under_chicken", (0.13, 0.01, 0.076),
              (0.29, 0.215, 0.011), soy, 26, 8)
    ellipsoid("rice_mound", (-0.19, 0.04, 0.164),
              (0.213, 0.219, 0.120), rice, 28, 16)
    rng = random.Random(663)
    for i in range(29):
        angle = rng.uniform(0, math.tau)
        r = rng.uniform(0.03, 0.18)
        x = -0.19 + r * math.cos(angle)
        y = 0.04 + r * math.sin(angle)
        z = 0.166 + 0.111 * math.sqrt(max(0.0, 1 - (r / 0.21) ** 2))
        grain = ellipsoid(f"individual_rice_grain_{i}", (x, y, z),
                          (0.020, 0.009, 0.006),
                          rice_shadow if i % 5 == 0 else rice, 10, 6)
        grain.rotation_euler.z = angle
    for i in range(6):
        # Fan the slices out from the rice mound. Their lower surface rests on
        # the plate/glaze; the old 0.174 m centre left a conspicuous air gap.
        x = -0.005 + i * 0.058
        y = -0.115 + i * 0.045
        meat_z = 0.114 + i * 0.006
        slice_obj = ellipsoid(f"fanned_chicken_slice_{i}",
                              (x, y, meat_z),
                              (0.124, 0.071, 0.047), cut, 18, 10)
        slice_obj.rotation_euler.z = -0.16 + i * 0.08
        ellipsoid(f"golden_skin_slice_{i}",
                  (x + 0.003, y - 0.015, meat_z + 0.038),
                  (0.119, 0.049, 0.013), chicken, 18, 8)
        for j in range(2):
            ellipsoid(f"pan_sear_{i}_{j}",
                      (x - 0.043 + j * 0.076, y - 0.022, meat_z + 0.048),
                      (0.016, 0.034, 0.004), char, 10, 6)
    for i in range(5):
        a = -0.75 + i * 0.34
        garnish_leaf(f"bok_choy_side_{i}",
                     (-0.05 + 0.13 * math.cos(a),
                      0.23 + 0.07 * math.sin(a), 0.108),
                     0.22, greens, a)
    cylinder("soy_dipping_cup", (0.29, -0.235, 0.111),
             0.070, 0.077, rice, 18)
    cylinder("soy_dipping_surface", (0.29, -0.235, 0.154),
             0.058, 0.009, soy, 18)


def bay_shrimp_roll():
    """Cut shrimp rice sheets on a long rectangular ceramic platter."""
    ceramic = mat("shrimp_roll_rectangular_plate", "#F2ECDD", 0.37)
    rim = mat("shrimp_roll_celadon_trim", "#A4BDB4", 0.45)
    sheet = mat("thin_rice_sheet", "#ECEADD", 0.44)
    shrimp = mat("poached_shrimp_coral", "#E89A84", 0.53)
    shrimp_deep = mat("shrimp_tail_corally", "#D77E6E", 0.54)
    soy = mat("sweet_soy_brown", "#754C3E", 0.31)
    scallion = mat("fine_green_scallion", "#5D9368", 0.75)
    sesame = mat("toasted_sesame_sand", "#E3C58B", 0.75)
    box("long_serving_plate", (0, 0, 0.041),
        (0.94, 0.58, 0.076), ceramic, 0.075)
    box("long_plate_inset", (0, 0, 0.084),
        (0.81, 0.46, 0.010), rim, 0.044)
    ellipsoid("dark_soy_lacquer_pool", (0, 0.005, 0.094),
              (0.37, 0.20, 0.013), soy, 28, 8)
    # Two long rolls, each split in the middle, show shrimp filling at ends.
    for row, y in enumerate((-0.102, 0.110)):
        for seg, x in enumerate((-0.21, 0.21)):
            ellipsoid(f"rice_sheet_{row}_{seg}", (x, y, 0.164),
                      (0.205, 0.090, 0.064), sheet, 24, 12)
            ellipsoid(f"rice_flap_{row}_{seg}", (x, y + 0.017, 0.207),
                      (0.190, 0.058, 0.026), ceramic, 20, 10)
            facing = -1 if seg == 0 else 1
            px = x + facing * 0.174
            ellipsoid(f"shrimp_cutface_{row}_{seg}",
                      (px, y - 0.006, 0.162),
                      (0.055, 0.064, 0.045), shrimp, 14, 10)
            ellipsoid(f"shrimp_tail_{row}_{seg}",
                      (px, y + 0.04, 0.181),
                      (0.040, 0.032, 0.017), shrimp_deep, 12, 7)
            curve_line(f"soy_glaze_across_{row}_{seg}",
                       [(x - 0.12, y - 0.04, 0.225),
                        (x + 0.02, y + 0.015, 0.232),
                        (x + 0.13, y + 0.035, 0.217)], 0.006, soy)
    for i in range(13):
        a = i * 2.35
        r = 0.08 + 0.020 * (i % 5)
        garnish_leaf(f"scallion_shard_{i}",
                     (r * math.cos(a), r * math.sin(a), 0.227),
                     0.085, scallion, a)
        if i % 2 == 0:
            ellipsoid(f"sesame_shrimp_{i}",
                      (r * math.cos(a + 0.4), r * math.sin(a + 0.4), 0.231),
                      (0.010, 0.006, 0.004), sesame, 10, 6)


def seaweed_dumpling():
    """Five pointed jade crescents with vegetable filling in a bamboo steamer."""
    bamboo = mat("bamboo_steamer_honey", "#BA915E", 0.82)
    bamboo_light = mat("steamer_sunlit_rattan", "#D3AB74", 0.82)
    parchment = mat("steamer_parchment", "#EEE6CF", 0.87)
    wrapper = mat("green_dumpling_wrapper", "#D5DAB4", 0.67)
    wrapper_edge = mat("dumpling_pleat_edge", "#B3C69C", 0.71)
    seaweed = mat("seaweed_flakes", "#4E7A62", 0.83)
    filling = mat("veggie_filling", "#84A56B", 0.84)
    sauce = mat("dark_vinegar", "#684D45", 0.35)
    cylinder("steamer_woven_base", (0, 0, 0.074),
             0.432, 0.137, bamboo, 36)
    torus("steamer_upper_rim", (0, 0, 0.156), 0.405, 0.037, bamboo_light, 36)
    torus("steamer_lower_band", (0, 0, 0.045), 0.420, 0.018, bamboo_light, 36)
    cylinder("steamer_parchment_disc", (0, 0, 0.160),
             0.378, 0.013, parchment, 32)
    for i in range(6):
        angle = i * math.tau / 6
        box(f"woven_vertical_slats_{i}",
            (0.413 * math.cos(angle), 0.413 * math.sin(angle), 0.09),
            (0.034, 0.040, 0.072), bamboo_light, 0.009)
    positions = [(-0.19, -0.15), (0.08, -0.18), (0.24, 0.045),
                 (-0.04, 0.14), (-0.23, 0.14)]
    for i, (x, y) in enumerate(positions):
        # Five cross-section strips taper into pointed crescent ends. The
        # upright seam is deliberately taller than the soft stuffed belly.
        verts = []
        for j in range(11):
            t = j / 10
            px = x - 0.125 + 0.250 * t
            fade = max(0.08, math.sin(math.pi * t) ** 0.72)
            verts.extend([
                (px, y - 0.072 * fade, 0.207),
                (px, y - 0.077 * fade, 0.207 + 0.071 * fade),
                (px, y + 0.010 * fade, 0.207 + 0.119 * fade),
                (px, y + 0.069 * fade, 0.207 + 0.066 * fade),
                (px, y + 0.058 * fade, 0.207),
            ])
        faces = []
        for j in range(10):
            for k in range(4):
                faces.append((j * 5 + k, (j + 1) * 5 + k,
                              (j + 1) * 5 + k + 1, j * 5 + k + 1))
            faces.append((j * 5 + 4, (j + 1) * 5 + 4,
                          (j + 1) * 5, j * 5))
        faces.append(tuple(reversed(range(5))))
        faces.append(tuple(10 * 5 + k for k in range(5)))
        mesh(f"hand_folded_crescent_{i}", verts, faces, wrapper)
        ellipsoid(f"dumpling_filling_hint_{i}",
                  (x, y - 0.069, 0.225),
                  (0.087, 0.014, 0.018), filling, 16, 9)
        for j in range(3):
            ellipsoid(f"seaweed_fleck_{i}_{j}",
                      (x - 0.050 + j * 0.05, y - 0.019, 0.300),
                      (0.013, 0.007, 0.003), seaweed, 10, 6)
    cylinder("vinegar_dip_cup", (0.314, -0.284, 0.118),
             0.072, 0.080, bamboo_light, 18)
    cylinder("vinegar_dip_surface", (0.314, -0.284, 0.162),
             0.060, 0.009, sauce, 18)


def fruit_ice():
    """Pastel smoothie with shaped clear cup, fruit cubes, yogurt and straw."""
    wood_platter("smoothie_coaster", 0.70, 0.70)
    cup = mat("frosted_aqua_cup_wall", "#A4D3CC", 0.35)
    inner = mat("berry_yogurt_smoothie", "#DDA9B0", 0.43)
    inner_light = mat("smoothie_blended_highlight", "#ECC2BE", 0.47)
    yogurt = mat("whipped_yogurt", "#F6E7DA", 0.49)
    mango = mat("mango_cube_gold", "#F2B262", 0.62)
    strawberry = mat("strawberry_wedge", "#DB6A73", 0.56)
    mint = mat("smoothie_mint", "#69A182", 0.79)
    straw = mat("striped_reusable_straw", "#7EB1AA", 0.57)
    # Cup profile is tapered and hollow with visibly thick rolled rim.
    lathe("smoothie_cup_frosted_wall", [
        (0.16, 0.10), (0.21, 0.14), (0.27, 0.48), (0.28, 0.59),
        (0.25, 0.59), (0.23, 0.47), (0.15, 0.16),
    ], cup, 32)
    torus("smoothie_cup_lip", (0, 0, 0.59), 0.267, 0.019, cup)
    lathe("pink_smoothie_body", [(0.15, 0.14), (0.20, 0.23),
                                  (0.237, 0.48), (0.242, 0.548)], inner, 32)
    ellipsoid("smoothie_top_surface", (0, 0, 0.548),
              (0.242, 0.242, 0.016), inner_light, 28, 10)
    for i in range(4):
        a = i * math.tau / 4
        ellipsoid(f"yogurt_swirl_lobe_{i}",
                  (0.080 * math.cos(a), 0.080 * math.sin(a), 0.601),
                  (0.116, 0.097, 0.062), yogurt, 16, 10)
    ellipsoid("yogurt_peak", (0.0, 0, 0.665),
              (0.117, 0.117, 0.084), yogurt, 20, 12)
    for i, (x, y, z) in enumerate(((-0.17, -0.09, 0.581),
                                   (0.15, -0.11, 0.585),
                                   (0.10, 0.13, 0.612))):
        box(f"mango_topping_{i}", (x, y, z),
            (0.085, 0.071, 0.057), mango, 0.019)
    for i, (x, y) in enumerate(((-0.015, -0.174), (0.151, 0.030))):
        wedge = ellipsoid(f"strawberry_wedge_{i}",
                          (x, y, 0.648), (0.070, 0.038, 0.061),
                          strawberry, 14, 9)
        wedge.rotation_euler.z = i * 0.56
    rod = curve_line("curved_straw", [(0.13, 0.06, 0.56),
                                      (0.16, 0.08, 0.82),
                                      (0.29, 0.10, 0.87)], 0.020, straw)
    for i in range(2):
        garnish_leaf(f"smoothie_mint_{i}",
                     (-0.12 + i * 0.065, 0.08, 0.687),
                     0.18, mint, -0.45 + i * 0.9)


def export_and_preview(recipe_id, build):
    reset()
    build()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / (recipe_id + ".blend")))
    bpy.ops.export_scene.gltf(filepath=str(MODEL_DIR / (recipe_id + ".glb")),
                              export_format="GLB")
    world = bpy.data.worlds[0]
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.85, 0.87, 0.84, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.48
    floor = mat("PREVIEW_ONLY_FLOOR", "#D7DCD5", 0.94)
    box("PREVIEW_ONLY_FLOOR", (0, 0, -0.049), (1.7, 1.5, 0.08), floor, 0.0)
    bpy.ops.object.light_add(type="AREA", location=(-1.5, -1.8, 2.5))
    bpy.context.object.data.energy = 200
    bpy.context.object.data.size = 1.8
    bpy.ops.object.light_add(type="AREA", location=(1.6, 1.2, 2.2))
    bpy.context.object.data.energy = 85
    bpy.context.object.data.size = 1.5
    bpy.ops.object.camera_add(location=(1.15, -1.53, 1.24))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.20)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.31
    bpy.context.scene.camera = camera
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene.render.resolution_x = 900
    bpy.context.scene.render.resolution_y = 750
    bpy.context.scene.render.resolution_percentage = 100
    bpy.context.scene.render.image_settings.file_format = "PNG"
    bpy.context.scene.render.filepath = str(MODEL_DIR / (recipe_id + "_preview.png"))
    bpy.ops.render.render(write_still=True)
    print("FOOD_ASSET_READY:" + recipe_id)


RECIPES = [
    ("garden_rice_roll", garden_rice_roll),
    ("macao_spice_bun", macao_spice_bun),
    ("morning_egg_bun", morning_egg_bun),
    ("warm_tofu_bowl", warm_tofu_bowl),
    ("coconut_millet", coconut_millet),
    ("harbour_noodles", harbour_noodles),
    ("chicken_rice", chicken_rice),
    ("bay_shrimp_roll", bay_shrimp_roll),
    ("seaweed_dumpling", seaweed_dumpling),
    ("fruit_ice", fruit_ice),
]

if __name__ == "__main__":
    requested = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else set()
    for recipe_id, builder in RECIPES:
        if not requested or recipe_id in requested:
            export_and_preview(recipe_id, builder)
