"""Reusable, original 3D ingredients and in-process food for the park cafe.

Each prop has a small readable silhouette for close kitchen view. Blender uses
+Z up and the front is -Y; imported GLBs use Godot +Y up and +Z front.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_park_foods as food


ROOT = Path(__file__).resolve().parents[2]
food.MODEL_DIR = ROOT / "assets" / "art" / "models" / "food_stage"
food.SOURCE_DIR = ROOT / "tools" / "art" / "source" / "food_stage"
food.MODEL_DIR.mkdir(parents=True, exist_ok=True)
food.SOURCE_DIR.mkdir(parents=True, exist_ok=True)

mat = food.mat
box = food.box
ellipsoid = food.ellipsoid
cylinder = food.cylinder
torus = food.torus
curve_line = food.curve_line
mesh = food.mesh
garnish_leaf = food.garnish_leaf
serving_bowl = food.serving_bowl
wood_platter = food.wood_platter


def leafy_cluster(prefix, cx, cy, cz, scale=1.0, count=5):
    dark = mat("leafy_deep_green", "#548A66", 0.81)
    light = mat("leafy_sun_green", "#86B78A", 0.83)
    vein = mat("leafy_vein", "#B5CFA0", 0.84)
    for i in range(count):
        a = i * math.tau / count
        px = cx + math.cos(a) * 0.115 * scale
        py = cy + math.sin(a) * 0.080 * scale
        leaf = garnish_leaf(f"{prefix}_whole_leaf_{i}",
                            (px, py, cz + i % 2 * 0.014 * scale),
                            0.225 * scale, light if i % 2 else dark, a)
        leaf.rotation_euler.y = (i % 3 - 1) * 0.20
        curve_line(f"{prefix}_leaf_vein_{i}",
                   [(px - 0.065 * math.cos(a) * scale,
                     py - 0.065 * math.sin(a) * scale,
                     cz + 0.013 * scale),
                    (px, py, cz + 0.023 * scale),
                    (px + 0.065 * math.cos(a) * scale,
                     py + 0.065 * math.sin(a) * scale,
                     cz + 0.013 * scale)],
                   0.0025 * scale, vein)


def washed_greens():
    """Rinsed greens in a shallow celadon draining basket, with water beads."""
    serving_bowl("washed_herb_colander", 0.315, 0.145, "#98BBB0")
    lattice = mat("colander_drain_slots", "#689C93", 0.74)
    wet = mat("water_droplets", "#C5E8DC", 0.22)
    for i in range(12):
        a = i * math.tau / 12
        ellipsoid(f"drain_slot_{i}",
                  (0.245 * math.cos(a), 0.245 * math.sin(a), 0.088),
                  (0.017, 0.009, 0.006), lattice, 10, 6)
    leafy_cluster("rinsed_greens", 0, 0, 0.165, 1.0, 7)
    for i in range(7):
        a = i * 2.399
        r = 0.10 + (i % 2) * 0.07
        ellipsoid(f"water_bead_{i}",
                  (r * math.cos(a), r * math.sin(a), 0.193),
                  (0.024, 0.018, 0.011), wet, 12, 8)
    for i, (x, y) in enumerate(((-0.22, -0.08), (0.17, -0.15),
                                (-0.10, 0.19))):
        garnish_leaf(f"rinsed_loose_leaf_{i}",
                     (x, y, 0.181), 0.085,
                     mat("leafy_sun_green", "#86B78A", 0.83), i * 0.9)


def _rinsing_colander(prefix):
    """A matching ceramic draining bowl, with open slots and distinct droplets."""
    serving_bowl(f"{prefix}_celadon_colander", 0.315, 0.145, "#9BBDB4")
    slot = mat("fine_celadon_drain_slot", "#6D9D95", 0.78)
    water = mat("rinsing_water_beads", "#C9E6DA", 0.29)
    for i in range(12):
        a = i * math.tau / 12
        ellipsoid(f"{prefix}_drain_slot_{i}",
                  (0.251 * math.cos(a), 0.251 * math.sin(a), 0.090),
                  (0.018, 0.008, 0.006), slot, 10, 6)
    for i in range(8):
        a = i * 2.399
        r = 0.18 + (i % 3) * 0.020
        ellipsoid(f"{prefix}_water_bead_{i}",
                  (r * math.cos(a), r * math.sin(a), 0.191),
                  (0.021, 0.016, 0.010), water, 10, 6)


def washed_fruit():
    """Coral berries and little citrus wedges rinsed for the fruit ice."""
    _rinsing_colander("fruit")
    berry = mat("fresh_berry_coral", "#D98680", 0.62)
    blush = mat("fresh_berry_light", "#E9A69A", 0.66)
    citrus = mat("sweet_citrus_gold", "#E4B977", 0.66)
    leaf = mat("fruit_calyx_green", "#719D79", 0.82)
    for i, (x, y) in enumerate(((-0.12, -0.10), (0.09, -0.13),
                                (-0.015, 0.11), (0.15, 0.08))):
        ellipsoid(f"rinsed_berry_{i}", (x, y, 0.177),
                  (0.075, 0.068, 0.057), berry if i % 2 else blush, 16, 10)
        for j in range(3):
            garnish_leaf(f"berry_calyx_{i}_{j}",
                         (x + (j - 1) * 0.017, y, 0.230),
                         0.039, leaf, j * 1.8)
    for i, (x, y) in enumerate(((0.11, 0.175), (-0.155, 0.105))):
        piece = ellipsoid(f"small_citrus_wedge_{i}",
                          (x, y, 0.163), (0.062, 0.043, 0.037), citrus, 14, 8)
        piece.rotation_euler.z = 0.35 if i else -0.40


def _washed_grains(prefix, grain_color, grain_count, surface_color):
    _rinsing_colander(prefix)
    grain = mat(f"{prefix}_individual_grains", grain_color, 0.77)
    surface = mat(f"{prefix}_wet_grain_surface", surface_color, 0.52)
    ellipsoid(f"{prefix}_shallow_wet_grains", (0, 0, 0.155),
              (0.218, 0.206, 0.035), surface, 24, 10)
    for i in range(grain_count):
        a = i * 2.399
        r = 0.205 * math.sqrt((i + 0.5) / grain_count)
        grain_piece = ellipsoid(f"{prefix}_grain_{i}",
                                (r * math.cos(a), r * math.sin(a), 0.190),
                                (0.026, 0.011, 0.008), grain, 10, 6)
        grain_piece.rotation_euler.z = a + 0.35


def washed_millet():
    """Many individually visible golden grains for the coconut millet pot."""
    _washed_grains("millet", "#C7A56E", 38, "#DDD3BD")
    husk = mat("little_millet_husk", "#A89168", 0.85)
    for i in range(5):
        a = i * 1.7
        ellipsoid(f"millet_husk_{i}",
                  (0.12 * math.cos(a), 0.12 * math.sin(a), 0.196),
                  (0.029, 0.008, 0.006), husk, 10, 6)


def washed_rice():
    """Pale rinsed rice with visible grains for batter and chicken rice."""
    _washed_grains("rice", "#F4EAD4", 36, "#C5D4D0")


def washed_shrimp():
    """Rinsed small shrimp keep their curled silhouettes and coral tails."""
    _rinsing_colander("shrimp")
    body = mat("clean_shrimp_coral", "#E5A58F", 0.61)
    edge = mat("clean_shrimp_edge", "#CB8577", 0.66)
    for i, (x, y) in enumerate(((-0.12, -0.10), (0.105, -0.10),
                                (-0.055, 0.090), (0.140, 0.105))):
        curve_line(f"curled_shrimp_{i}",
                   [(x - 0.050, y + 0.018, 0.175),
                    (x - 0.014, y - 0.031, 0.185),
                    (x + 0.045, y - 0.022, 0.186),
                    (x + 0.057, y + 0.023, 0.177)], 0.027, body)
        ellipsoid(f"shrimp_tail_fan_{i}",
                  (x + 0.061, y + 0.034, 0.180),
                  (0.032, 0.023, 0.016), edge, 12, 8)
        ellipsoid(f"shrimp_back_stripe_{i}",
                  (x - 0.007, y - 0.046, 0.195),
                  (0.026, 0.007, 0.005), edge, 10, 6)


def washed_seaweed():
    """Folded dark seaweed ribbons with bright edges in the draining bowl."""
    _rinsing_colander("seaweed")
    ribbon = mat("fresh_seaweed_deep", "#4D806A", 0.79)
    highlight = mat("wet_seaweed_edge", "#7DA889", 0.70)
    for i in range(5):
        y = -0.15 + i * 0.075
        x = 0.035 * math.sin(i * 1.9)
        verts = []
        centre = []
        for j in range(7):
            t = j / 6
            px = x - 0.195 + 0.390 * t
            py = y + math.sin(t * math.tau + i * 0.6) * 0.025
            pz = 0.183 + math.sin(t * math.pi) * 0.026
            width = 0.032 + 0.012 * math.sin(t * math.pi)
            verts.extend([(px, py - width, pz), (px, py + width, pz + 0.004)])
            centre.append((px, py, pz + 0.006))
        faces = [(j * 2, j * 2 + 1, j * 2 + 3, j * 2 + 2) for j in range(6)]
        mesh(f"folded_seaweed_ribbon_{i}", verts, faces, ribbon, 0.008)
        curve_line(f"seaweed_sunlit_ridge_{i}", centre, 0.0035, highlight)


def chopped_ingredients():
    """Wood prep board with chopped cucumber, carrot and leafy strips."""
    wood_platter("rounded_chopping_board", 0.73, 0.53)
    peel = mat("cucumber_peel", "#5D946C", 0.79)
    core = mat("cucumber_centre", "#C5D9AC", 0.72)
    seed = mat("cucumber_seeds", "#EEE8CB", 0.69)
    carrot = mat("carrot_julienne", "#E49A61", 0.73)
    metal = mat("small_knife_brushed_steel", "#BBCAC5", 0.36, 0.30)
    handle = mat("small_knife_wood", "#856451", 0.79)
    for i in range(4):
        x = -0.225 + i * 0.090
        cylinder(f"cucumber_slice_rind_{i}", (x, -0.11, 0.115),
                 0.052, 0.024, peel, 20)
        cylinder(f"cucumber_slice_core_{i}", (x, -0.11, 0.128),
                 0.038, 0.005, core, 20)
        for j in range(3):
            a = j * math.tau / 3
            ellipsoid(f"cucumber_seed_{i}_{j}",
                      (x + 0.019 * math.cos(a),
                       -0.11 + 0.019 * math.sin(a), 0.132),
                      (0.004, 0.003, 0.002), seed, 8, 5)
    for i in range(6):
        x = -0.17 + (i % 3) * 0.068
        y = 0.095 + (i // 3) * 0.043
        piece = box(f"carrot_stick_{i}", (x, y, 0.116),
                    (0.024, 0.088, 0.026), carrot, 0.010)
        piece.rotation_euler.z = (i % 3 - 1) * 0.15
    leafy_cluster("cut_leafy_greens", 0.18, 0.095, 0.114, 0.42, 5)
    scored = mat("fine_cut_marks_in_wood", "#805B45", 0.88)
    for i in range(4):
        curve_line(f"board_cut_mark_{i}",
                   [(-0.185 + i * 0.052, 0.008, 0.100),
                    (-0.162 + i * 0.052, 0.067, 0.101)],
                   0.0035, scored)
    for i, (x, y) in enumerate(((0.088, 0.052), (0.267, 0.114),
                                (-0.048, 0.019), (0.180, -0.024))):
        ellipsoid(f"fresh_cut_scrap_{i}", (x, y, 0.110),
                  (0.027, 0.014, 0.007),
                  carrot if i == 2 else peel, 10, 6)
    box("knife_blade", (0.198, -0.112, 0.115),
        (0.230, 0.038, 0.019), metal, 0.007)
    box("knife_handle", (0.342, -0.112, 0.119),
        (0.124, 0.054, 0.032), handle, 0.014)


def _slicing_board(prefix):
    """Shared board and knife dimensions keep five preparations in one visual set."""
    wood_platter(f"{prefix}_rounded_board", 0.73, 0.53)
    steel = mat("small_knife_brushed_steel", "#BBCAC5", 0.36, 0.30)
    handle = mat("small_knife_wood", "#856451", 0.79)
    marks = mat("fine_cut_marks_in_wood", "#805B45", 0.88)
    for i in range(3):
        curve_line(f"{prefix}_cut_mark_{i}",
                   [(-0.23 + 0.06 * i, -0.035, 0.101),
                    (-0.20 + 0.06 * i, 0.025, 0.101)], 0.003, marks)
    blade = box(f"{prefix}_knife_blade", (0.220, -0.174, 0.117),
                (0.185, 0.035, 0.018), steel, 0.006)
    blade.rotation_euler.z = 0.18
    handle_obj = box(f"{prefix}_knife_handle", (0.352, -0.155, 0.120),
                     (0.115, 0.047, 0.030), handle, 0.012)
    handle_obj.rotation_euler.z = 0.18


def sliced_bun_veg():
    """Opened breakfast bun and cucumber rounds, before the egg reaches the pan."""
    _slicing_board("breakfast_bun")
    crust = mat("soft_breakfast_bun_crust", "#D8A66F", 0.70)
    crumb = mat("fresh_bun_cut_crumb", "#F2E2C0", 0.82)
    rind = mat("cucumber_skin", "#61966F", 0.79)
    core = mat("cucumber_cut_face", "#C4D8AA", 0.68)
    ellipsoid("bun_lower_half", (-0.118, 0.070, 0.140),
              (0.160, 0.130, 0.038), crust, 22, 10)
    ellipsoid("bun_open_crumb", (-0.118, 0.070, 0.173),
              (0.140, 0.111, 0.008), crumb, 22, 8)
    top = ellipsoid("bun_upper_half_leaning", (0.151, 0.079, 0.158),
                    (0.147, 0.120, 0.057), crust, 22, 10)
    top.rotation_euler.y = -0.20
    ellipsoid("upper_bun_cut_face", (0.150, 0.078, 0.117),
              (0.126, 0.104, 0.007), crumb, 22, 8)
    for i in range(4):
        x = -0.251 + i * 0.090
        cylinder(f"breakfast_cucumber_rind_{i}", (x, -0.099, 0.122),
                 0.045, 0.021, rind, 18)
        cylinder(f"breakfast_cucumber_core_{i}", (x, -0.099, 0.135),
                 0.032, 0.006, core, 18)
    for i, (x, y) in enumerate(((-0.16, 0.080), (-0.045, 0.025))):
        ellipsoid(f"bun_sesame_{i}", (x, y, 0.181),
                  (0.012, 0.006, 0.004), crumb, 9, 6)


def sliced_chicken_spice():
    """Raw chicken strips, visible spice flecks and spring onion for the bun."""
    _slicing_board("chicken_spice")
    flesh = mat("raw_chicken_peach", "#D89D88", 0.70)
    edge = mat("fresh_chicken_cut_face", "#E8B5A0", 0.72)
    spice = mat("macao_red_spice", "#AF6550", 0.79)
    green = mat("spring_onion_cut", "#78A67B", 0.78)
    for i in range(5):
        x = -0.225 + i * 0.087
        strip = box(f"cut_chicken_strip_{i}", (x, 0.035 + (i % 2) * 0.025, 0.139),
                    (0.063, 0.205, 0.055), flesh if i % 2 else edge, 0.018)
        strip.rotation_euler.z = (i - 2) * 0.09
        for j in range(2):
            ellipsoid(f"spice_on_chicken_{i}_{j}",
                      (x + (j - 0.5) * 0.027, 0.035 + j * 0.050, 0.169),
                      (0.009, 0.007, 0.005), spice, 8, 6)
    for i in range(5):
        x = -0.21 + i * 0.083
        cylinder(f"cut_spring_onion_{i}", (x, -0.126, 0.119),
                 0.019, 0.017, green, 12)


def sliced_noodle_greens():
    """Long leafy strips, scallion rings and a loose noodle nest."""
    _slicing_board("noodle_greens")
    deep = mat("sliced_choy_green", "#598F67", 0.81)
    light = mat("sliced_choy_light", "#8DB68A", 0.78)
    pale = mat("noodle_dough_pale", "#E7D6AD", 0.72)
    for i in range(7):
        y = -0.095 + i * 0.030
        strip = box(f"choy_strip_{i}", (-0.135, y, 0.118),
                    (0.275, 0.019, 0.014), deep if i % 2 else light, 0.008)
        strip.rotation_euler.z = (i % 3 - 1) * 0.10
    for i in range(4):
        x = 0.124 + (i % 2) * 0.068
        y = 0.001 + (i // 2) * 0.074
        torus(f"scallion_ring_{i}", (x, y, 0.122), 0.027, 0.008, light, 14)
    for i in range(3):
        y = 0.143 + i * 0.016
        curve_line(f"uncooked_noodle_loop_{i}",
                   [(-0.240, y, 0.132), (-0.107, y + 0.028, 0.135),
                    (0.015, y - 0.004, 0.133), (0.166, y + 0.021, 0.135)],
                   0.009, pale)


def sliced_fruit():
    """Cut berry faces, citrus wedges and mango cubes for the cold drink."""
    _slicing_board("fruit")
    berry = mat("cut_berry_red", "#D47A78", 0.63)
    face = mat("cut_berry_face", "#EFA9A1", 0.67)
    citrus = mat("citrus_skin_gold", "#E5AE6D", 0.74)
    pulp = mat("citrus_pulp", "#F1CE8C", 0.60)
    mango = mat("fresh_mango_cube", "#E8B671", 0.69)
    for i, (x, y) in enumerate(((-0.192, -0.093), (-0.035, -0.071),
                                (-0.105, 0.111))):
        piece = ellipsoid(f"halved_berry_{i}", (x, y, 0.140),
                          (0.062, 0.049, 0.039), berry, 16, 9)
        piece.rotation_euler.z = i * 0.55
        ellipsoid(f"visible_berry_cut_face_{i}", (x, y + 0.022, 0.171),
                  (0.051, 0.028, 0.009), face, 16, 8)
    for i in range(2):
        x = 0.108 + i * 0.108
        citrus_piece = ellipsoid(f"citrus_wedge_rind_{i}",
                                  (x, 0.105, 0.131), (0.065, 0.057, 0.028), citrus, 15, 8)
        citrus_piece.rotation_euler.z = 0.32 - i * 0.60
        ellipsoid(f"citrus_wedge_pulp_{i}", (x, 0.105, 0.155),
                  (0.053, 0.043, 0.007), pulp, 15, 8)
    for i, (x, y) in enumerate(((0.105, -0.040), (0.183, -0.060),
                                (0.046, 0.010))):
        box(f"mango_cube_{i}", (x, y, 0.139),
            (0.063, 0.059, 0.055), mango, 0.011)


def sliced_spices():
    """Ginger coins, red chile, scallion and anise for the stock oil."""
    _slicing_board("spice_oil")
    ginger = mat("ginger_cut_gold", "#D8B27B", 0.76)
    ginger_face = mat("ginger_fresh_face", "#EBD2A0", 0.67)
    chile = mat("small_red_chile", "#BE6B5C", 0.70)
    scallion = mat("spice_scallion_green", "#739D72", 0.82)
    anise = mat("anise_brown", "#8C5F4A", 0.86)
    for i in range(4):
        x = -0.232 + i * 0.084
        cylinder(f"ginger_coin_{i}", (x, -0.084, 0.122),
                 0.044, 0.023, ginger, 18)
        cylinder(f"ginger_flesh_{i}", (x, -0.084, 0.135),
                 0.033, 0.004, ginger_face, 18)
    for i in range(4):
        x = -0.182 + i * 0.089
        torus(f"red_chile_ring_{i}", (x, 0.091, 0.119),
              0.030, 0.012, chile, 14)
    for i in range(3):
        x = 0.142 + (i % 2) * 0.044
        y = 0.013 + i * 0.040
        box(f"chopped_scallion_{i}", (x, y, 0.117),
            (0.039, 0.018, 0.022), scallion, 0.006)
    for arm in range(5):
        a = arm * math.tau / 5
        pod = ellipsoid(f"star_anise_pod_{arm}",
                        (0.140 + 0.042 * math.cos(a), -0.103 + 0.042 * math.sin(a), 0.120),
                        (0.050, 0.014, 0.011), anise, 12, 7)
        pod.rotation_euler.z = a


def rice_batter_bowl():
    """Mixed rice batter in a glazed bowl, with a gently looping wooden whisk."""
    serving_bowl("rice_batter_mix_bowl", 0.335, 0.185, "#B7D1C9")
    batter = mat("rice_batter_satin", "#EEE9D8", 0.42)
    shadow = mat("rice_batter_fold", "#D5D5C8", 0.53)
    whisk = mat("slim_bamboo_whisk", "#B48A5E", 0.76)
    ellipsoid("soft_rice_batter_surface", (0, 0, 0.160),
              (0.254, 0.250, 0.021), batter, 28, 12)
    curve_line("batter_mixing_ripple",
               [(-0.09, -0.06, 0.181), (0.11, -0.09, 0.180),
                (0.16, 0.08, 0.178), (-0.02, 0.12, 0.180)],
               0.007, shadow)
    pivot = bpy.data.objects.new("StirPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.location = (0, 0, 0.17)
    spoon = food.cylinder("bamboo_whisk_handle", (0.15, -0.03, 0.330),
                          0.018, 0.28, whisk, 12)
    spoon.rotation_euler.y = 0.30
    head = ellipsoid("whisk_wire_head", (0.107, -0.03, 0.207),
                     (0.042, 0.030, 0.053), whisk)
    for item in (spoon, head):
        bpy.context.view_layer.update()
        world = item.matrix_world.copy()
        item.parent = pivot
        item.matrix_world = world
    pivot.rotation_mode = "XYZ"
    pivot.rotation_euler.z = 0
    pivot.keyframe_insert(data_path="rotation_euler", frame=1)
    pivot.rotation_euler.z = math.tau
    pivot.keyframe_insert(data_path="rotation_euler", frame=49)
    bpy.context.scene.frame_end = 48
    bpy.context.scene.frame_set(1)


def spice_jar():
    """Open ceramic spice jar with visible chili oil, seeds, twine and lid."""
    ceramic = mat("spice_jar_glazed_body", "#C58B73", 0.51)
    lip = mat("spice_jar_cream_lip", "#EEE0C4", 0.46)
    oil = mat("deep_spice_oil", "#A85942", 0.29)
    seed = mat("sesame_spice_seeds", "#E5BE80", 0.78)
    twine = mat("spice_jar_twine", "#D9B685", 0.86)
    food.lathe("spice_jar_curved_body",
               [(0.106, 0.014), (0.158, 0.047), (0.178, 0.181),
                (0.159, 0.270), (0.141, 0.281), (0.126, 0.190)], ceramic, 28)
    torus("spice_jar_rolled_lip", (0, 0, 0.277), 0.147, 0.019, lip, 28)
    cylinder("visible_spice_oil", (0, 0, 0.235), 0.122, 0.017, oil, 26)
    torus("tied_twine_band", (0, 0, 0.206), 0.164, 0.009, twine, 28)
    for i in range(12):
        a = i * 2.399
        r = 0.10 * math.sqrt((i + 0.5) / 12)
        ellipsoid(f"spice_speck_{i}",
                  (r * math.cos(a), r * math.sin(a), 0.247),
                  (0.007, 0.004, 0.003), seed, 8, 5)
    cylinder("spice_jar_lid_leaning", (0.241, 0.057, 0.038),
             0.139, 0.044, lip, 26)
    ellipsoid("lid_knob", (0.241, 0.057, 0.074),
              (0.032, 0.032, 0.026), ceramic, 14, 8)


def steamer_rice_roll():
    """Bamboo steamer holding folded but uncooked rice sheets and fresh greens."""
    bamboo = mat("fresh_bamboo_steamer", "#BA925F", 0.85)
    band = mat("steamer_rim", "#D2AD77", 0.83)
    paper = mat("parchment_liner", "#ECE5CD", 0.91)
    rice = mat("soft_rice_sheet_before_steam", "#E9E6D8", 0.55)
    green = mat("roll_leaf_filling", "#74A27A", 0.82)
    cylinder("steamer_base", (0, 0, 0.088), 0.354, 0.165, bamboo, 32)
    torus("steamer_upper_lip", (0, 0, 0.167), 0.331, 0.029, band, 32)
    cylinder("parchment", (0, 0, 0.175), 0.307, 0.012, paper, 30)
    for i, x in enumerate((-0.146, 0.010, 0.165)):
        ellipsoid(f"folded_sheet_{i}", (x, 0.014, 0.235),
                  (0.071, 0.224, 0.047), rice, 20, 12)
        ellipsoid(f"green_filling_tip_{i}", (x, -0.190, 0.236),
                  (0.046, 0.018, 0.024), green, 12, 8)
        curve_line(f"folded_sheet_seam_{i}",
                   [(x - 0.048, 0.065, 0.267),
                    (x + 0.010, 0.035, 0.277),
                    (x + 0.040, -0.015, 0.268)],
                   0.003, paper)


def _steamer_with_liner(prefix):
    bamboo = mat("honey_bamboo_steam_basket", "#B99163", 0.83)
    band = mat("sunlit_bamboo_binding", "#D5AE79", 0.80)
    liner = mat("warm_parchment_liner", "#EEE7D4", 0.89)
    cylinder(f"{prefix}_woven_base", (0, 0, 0.079), 0.366, 0.151, bamboo, 32)
    torus(f"{prefix}_top_binding", (0, 0, 0.161), 0.346, 0.025, band, 32)
    torus(f"{prefix}_bottom_binding", (0, 0, 0.028), 0.352, 0.012, band, 32)
    cylinder(f"{prefix}_paper_liner", (0, 0, 0.168), 0.320, 0.010, liner, 30)
    for i in range(10):
        angle = i * math.tau / 10
        box(f"{prefix}_vertical_weave_{i}",
            (0.354 * math.cos(angle), 0.354 * math.sin(angle), 0.087),
            (0.022, 0.026, 0.091), band, 0.007)


def steamer_shrimp_roll():
    """Three uncooked rice sheets reveal coral shrimp before the steamer closes."""
    _steamer_with_liner("shrimp_roll")
    sheet = mat("uncooked_rice_sheet", "#EAE7DD", 0.56)
    fold = mat("folded_rice_sheet_highlight", "#F6F1E4", 0.64)
    shrimp = mat("fresh_shrimp_coral", "#E6A28F", 0.60)
    tail = mat("shrimp_tail_rose", "#CB8579", 0.63)
    green = mat("fresh_scattered_chives", "#7FA984", 0.79)
    for i, y in enumerate((-0.175, 0.0, 0.175)):
        ellipsoid(f"visible_shrimp_filling_{i}",
                  (-0.18, y, 0.212), (0.067, 0.055, 0.037), shrimp, 16, 10)
        ellipsoid(f"shrimp_tail_peeking_{i}",
                  (-0.244, y + 0.022, 0.223), (0.037, 0.031, 0.017), tail, 12, 8)
        roll = ellipsoid(f"loose_rice_sheet_{i}",
                         (0.017, y, 0.232), (0.220, 0.065, 0.044), sheet, 24, 12)
        roll.rotation_euler.z = (i - 1) * 0.06
        curve_line(f"rice_sheet_fold_{i}",
                   [(-0.128, y + 0.023, 0.264),
                    (0.022, y + 0.046, 0.277),
                    (0.162, y + 0.031, 0.260)], 0.004, fold)
        for j in range(3):
            garnish_leaf(f"raw_chive_{i}_{j}",
                         (0.011 + (j - 1) * 0.065, y + 0.015, 0.278),
                         0.050, green, 0.22 + j * 0.4)


def steamer_seaweed_dumpling():
    """Five pale pleated dumplings with dark seaweed seams, still on parchment."""
    _steamer_with_liner("seaweed_dumpling")
    wrapper = mat("uncooked_dumpling_wrapper", "#DCE3CB", 0.67)
    ridge = mat("dumpling_pleat_ridge", "#EEF0DA", 0.68)
    filling = mat("seaweed_and_greens", "#5E8D72", 0.83)
    fleck = mat("seaweed_fleck_deep", "#4B725C", 0.85)
    positions = [(-0.163, -0.140), (0.127, -0.159),
                 (-0.014, 0.024), (-0.178, 0.170), (0.150, 0.151)]
    for i, (x, y) in enumerate(positions):
        body = ellipsoid(f"raw_vegetable_dumpling_{i}",
                         (x, y, 0.209), (0.115, 0.059, 0.057), wrapper, 18, 10)
        body.rotation_euler.z = (i % 3 - 1) * 0.19
        ellipsoid(f"open_green_filling_{i}",
                  (x, y - 0.047, 0.236), (0.077, 0.026, 0.017), filling, 14, 8)
        for j in range(4):
            px = x - 0.073 + j * 0.048
            curve_line(f"unsealed_pleat_{i}_{j}",
                       [(px - 0.014, y + 0.003, 0.256),
                        (px, y + 0.018, 0.276),
                        (px + 0.015, y + 0.010, 0.259)],
                       0.004, ridge)
        ellipsoid(f"seaweed_on_wrapper_{i}",
                  (x + 0.022, y + 0.023, 0.263),
                  (0.018, 0.009, 0.004), fleck, 10, 6)


def finished_serving_tray():
    """Low wooden handoff tray leaving the centre clear for any finished dish."""
    wood_platter("serving_tray", 0.84, 0.61)
    cloth = mat("folded_linen_napkin", "#EADFC9", 0.91)
    trim = mat("linen_napkin_edge", "#A9C4B2", 0.84)
    bamboo = mat("slim_chopsticks", "#B99064", 0.80)
    porcelain = mat("small_dipping_cup", "#F1E9D9", 0.38)
    box("folded_napkin", (0.257, 0.075, 0.115),
        (0.205, 0.242, 0.021), cloth, 0.011)
    box("napkin_herringbone_edge", (0.257, -0.049, 0.128),
        (0.205, 0.008, 0.008), trim, 0.003)
    for i in range(2):
        rod = food.cylinder(f"chopstick_{i}", (-0.18, 0.231 + i * 0.024, 0.115),
                            0.008, 0.367, bamboo, 8)
        rod.rotation_euler.y = math.pi / 2
    cylinder("little_dipping_cup", (0.300, -0.183, 0.126),
             0.081, 0.071, porcelain, 20)
    cylinder("dip_well", (0.300, -0.183, 0.165),
             0.063, 0.006, trim, 20)
    herb = mat("tray_fresh_herb_sprig", "#75A17B", 0.82)
    for i in range(3):
        garnish_leaf(f"tray_small_herb_leaf_{i}",
                     (-0.280 + i * 0.041, -0.190 + i * 0.015, 0.111),
                     0.076, herb, -0.20 + i * 0.45)


def marinated_chicken():
    """Uncooked cut chicken in a sauce dish with visible spice oil and herbs."""
    serving_bowl("marinating_celadon_dish", 0.327, 0.130, "#B7C9B0")
    chicken = mat("raw_chicken_rose", "#E8AD9D", 0.57)
    chicken_light = mat("raw_chicken_light", "#F0C5AD", 0.64)
    oil = mat("spice_oil_russet", "#A96A4E", 0.34)
    spice = mat("toasted_spice", "#79523D", 0.77)
    scallion = mat("finely_cut_scallion", "#6B9A71", 0.83)
    ellipsoid("shallow_marinate_pool", (0, 0, 0.108),
              (0.251, 0.242, 0.013), oil, 28, 10)
    for i, (x, y, rot) in enumerate(((-0.124, -0.082, 0.26),
                                    (0.045, -0.090, -0.18),
                                    (-0.084, 0.090, -0.31),
                                    (0.132, 0.084, 0.21))):
        meat = ellipsoid(f"cut_chicken_piece_{i}",
                         (x, y, 0.137), (0.126, 0.059, 0.041),
                         chicken_light if i % 2 else chicken, 18, 10)
        meat.rotation_euler.z = rot
        curve_line(f"spice_oil_on_meat_{i}",
                   [(x - 0.057, y - 0.007, 0.166),
                    (x, y + 0.014, 0.178),
                    (x + 0.054, y + 0.013, 0.164)],
                   0.004, oil)
    for i in range(11):
        a = i * 2.399
        r = 0.22 * math.sqrt((i + 0.5) / 11)
        ellipsoid(f"spice_and_scallion_{i}",
                  (r * math.cos(a), r * math.sin(a), 0.185),
                  (0.010, 0.006, 0.003),
                  scallion if i % 2 else spice, 10, 6)
    for i, (x, y) in enumerate(((-0.145, 0.090), (0.098, -0.121),
                                (0.127, 0.100))):
        garnish_leaf(f"marinade_herb_fragment_{i}",
                     (x, y, 0.187), 0.082, scallion, i * 0.7)
    for i in range(3):
        ellipsoid(f"amber_oil_glaze_bead_{i}",
                  (-0.090 + i * 0.096, -0.043 + (i % 2) * 0.125, 0.180),
                  (0.034, 0.022, 0.009), oil, 12, 8)


def pan_seared_chicken():
    """Golden chicken fillet browning in a rounded skillet."""
    iron = mat("warm_enamel_skidding_pan", "#637B78", 0.48, 0.12)
    inner = mat("dark_pan_inside", "#3F5551", 0.50, 0.14)
    handle = mat("pan_wood_handle", "#8D6651", 0.82)
    oil = mat("sizzling_spice_oil", "#C28B58", 0.30)
    meat = mat("seared_chicken_gold", "#D3996B", 0.65)
    edge = mat("crispy_seared_edge", "#A86948", 0.73)
    grill = mat("browned_pan_marks", "#83573F", 0.75)
    cylinder("round_skillet_base", (-0.078, 0, 0.058),
             0.300, 0.098, iron, 30)
    cylinder("dark_skillet_well", (-0.078, 0, 0.111),
             0.259, 0.010, inner, 28)
    torus("rolled_pan_lip", (-0.078, 0, 0.113),
          0.285, 0.020, iron, 30)
    pan_handle = box("rounded_skillet_handle", (0.299, 0, 0.079),
                     (0.374, 0.095, 0.049), handle, 0.033)
    pan_handle.rotation_euler.z = 0.03
    ellipsoid("oil_under_fillet", (-0.065, 0, 0.121),
              (0.210, 0.163, 0.010), oil, 24, 10)
    fillet = ellipsoid("one_chicken_fillet", (-0.065, 0.012, 0.151),
                       (0.205, 0.145, 0.050), meat, 24, 14)
    fillet.rotation_euler.z = -0.19
    for i in range(4):
        curve_line(f"browning_ridge_{i}",
                   [(-0.189 + i * 0.069, -0.087, 0.179),
                    (-0.181 + i * 0.069, 0.010, 0.197),
                    (-0.163 + i * 0.069, 0.097, 0.178)],
                   0.007, grill)
    for i in range(7):
        a = i * math.tau / 7
        ellipsoid(f"tiny_sizzle_bubble_{i}",
                  (-0.078 + 0.225 * math.cos(a),
                   0.195 * math.sin(a), 0.134),
                  (0.023, 0.018, 0.010), oil, 10, 6)
    steam = mat("faint_skillet_steam", "#D8DCD0", 0.65)
    for i in range(2):
        ellipsoid(f"pan_sizzle_steam_{i}",
                  (-0.135 + i * 0.153, 0.110, 0.233 + i * 0.040),
                  (0.040, 0.031, 0.022), steam, 10, 7)


def boiling_noodles():
    """Blue enamel pot with simmering wheat noodles and wilted greens."""
    blue = mat("noodle_pot_blue_enamel", "#67969B", 0.45)
    rim = mat("pot_bright_edge", "#CFD9CD", 0.49)
    broth = mat("noodle_broth", "#AA8B68", 0.45)
    noodle = mat("wheat_noodle", "#E7C584", 0.72)
    greens = mat("wilted_greens", "#78A279", 0.83)
    steam = mat("soft_steam", "#CFDCD6", 0.63)
    food.lathe("blue_enamel_pot",
               [(0.191, 0.013), (0.311, 0.025), (0.329, 0.254),
                (0.303, 0.277), (0.280, 0.178), (0.195, 0.099)], blue, 30)
    torus("pot_white_lip", (0, 0, 0.267), 0.315, 0.018, rim, 30)
    cylinder("simmering_broth", (0, 0, 0.232),
             0.278, 0.025, broth, 28)
    for side in (-1, 1):
        ellipsoid(f"side_handle_{side}",
                  (side * 0.333, 0, 0.179),
                  (0.050, 0.095, 0.038), blue, 16, 8)
    for i in range(8):
        a = i * 0.79
        r = 0.04 + 0.017 * i
        cx, cy = r * math.cos(a), r * math.sin(a)
        curve_line(f"wheat_noodle_loop_{i}",
                   [(cx - 0.065, cy - 0.031, 0.259),
                    (cx, cy + 0.051, 0.281),
                    (cx + 0.073, cy + 0.015, 0.266)],
                   0.007, noodle)
    for i in range(5):
        a = i * math.tau / 5
        garnish_leaf(f"soft_boiled_leaf_{i}",
                     (0.15 * math.cos(a), 0.15 * math.sin(a), 0.280),
                     0.095, greens, a)
    for i in range(3):
        ellipsoid(f"warm_steam_puff_{i}",
                  (-0.10 + 0.10 * i, 0.03, 0.335 + 0.045 * i),
                  (0.049, 0.037, 0.029), steam, 10, 7)


def portioned_tofu():
    """Tofu curds portioned in a small shallow bowl before topping."""
    serving_bowl("small_portion_bowl", 0.300, 0.147, "#C0D4C5")
    syrup = mat("ginger_syrup", "#C59969", 0.35)
    tofu = mat("silken_tofu_blocks", "#F4F0E2", 0.43)
    ginger = mat("ginger_threads", "#D5B47A", 0.75)
    ellipsoid("syrup_pool", (0, 0, 0.129),
              (0.225, 0.222, 0.012), syrup, 24, 10)
    for i, (x, y) in enumerate(((-0.100, -0.075), (0.095, -0.062),
                                (-0.055, 0.100), (0.105, 0.105))):
        box(f"soft_tofu_portion_{i}", (x, y, 0.165),
            (0.135, 0.095, 0.075), tofu, 0.028)
    for i in range(6):
        a = i * 2.399
        r = 0.12 * math.sqrt((i + 0.5) / 6)
        curve_line(f"fine_ginger_thread_{i}",
                   [(r * math.cos(a) - 0.022,
                     r * math.sin(a) - 0.012, 0.213),
                    (r * math.cos(a) + 0.030,
                     r * math.sin(a) + 0.011, 0.214)],
                   0.003, ginger)


def simmering_tofu_basin():
    """Several soft curds stay warm in a shared basin before ladling."""
    ceramic = mat("tofu_basin_celadon", "#8FAEA7", 0.64)
    rim = mat("tofu_basin_pale_rim", "#D7DDD0", 0.56)
    broth = mat("warm_ginger_broth", "#B68A61", 0.44)
    syrup = mat("ginger_surface_glow", "#DBB07D", 0.45)
    tofu = mat("silken_tofu_in_basin", "#F1EEE1", 0.49)
    tofu_edge = mat("tofu_warm_edge", "#D9D9CB", 0.58)
    bubble = mat("hot_broth_bubbles", "#E5CCAB", 0.36)
    steel = mat("serving_ladle_steel", "#B5C1BB", 0.35, 0.38)
    wood = mat("ladle_wood_handle", "#846855", 0.73)
    food.lathe("wide_shallow_earthen_basin",
               [(0.18, 0.012), (0.355, 0.045), (0.383, 0.157),
                (0.361, 0.203), (0.329, 0.174), (0.24, 0.091)], ceramic, 32)
    torus("basin_thick_celadon_lip", (0, 0, 0.190), 0.365, 0.021, rim, 32)
    for side in (-1, 1):
        ellipsoid(f"basin_ear_{side}", (side * 0.391, 0, 0.129),
                  (0.079, 0.112, 0.039), ceramic, 18, 10)
        ellipsoid(f"basin_ear_grip_{side}", (side * 0.405, -0.013, 0.140),
                  (0.040, 0.079, 0.013), rim, 16, 8)
    ellipsoid("ginger_broth_surface", (0, 0, 0.174),
              (0.326, 0.321, 0.013), broth, 30, 12)
    # Loose submerged curds in a shared vessel differ from the neatly plated
    # four-piece single serving produced by the following portion step.
    placements = ((-0.19, -0.08, -0.26), (-0.04, -0.16, 0.13),
                  (0.15, -0.11, -0.18), (-0.16, 0.12, 0.21),
                  (0.025, 0.12, -0.20), (0.20, 0.13, 0.16))
    for i, (x, y, angle) in enumerate(placements):
        curd = box(f"soft_tofu_curd_{i}", (x, y, 0.198 + i % 2 * 0.004),
                   (0.112, 0.082, 0.055), tofu, 0.022)
        curd.rotation_euler.z = angle
        edge = ellipsoid(f"soft_curd_broth_edge_{i}",
                         (x + 0.025, y - 0.026, 0.179),
                         (0.054, 0.012, 0.006), tofu_edge, 12, 6)
        edge.rotation_euler.z = angle
    for i in range(13):
        a = i * 2.399
        radius = 0.296 * math.sqrt((i + 0.5) / 13)
        bx, by = radius * math.cos(a), radius * math.sin(a)
        if abs(bx) < 0.24 and abs(by) < 0.21:
            continue
        torus(f"broth_bubble_ring_{i}", (bx, by, 0.191),
              0.014 + 0.004 * (i % 3), 0.0035, bubble, 12)
    curve_line("ginger_syrup_ribbon",
               [(-0.263, 0.021, 0.189), (-0.179, 0.222, 0.190),
                (0.094, 0.248, 0.190), (0.272, 0.033, 0.189)], 0.006, syrup)
    # A resting ladle reads as a transfer tool, not a second plated dish.
    ellipsoid("ladle_cup", (0.275, -0.211, 0.248),
              (0.074, 0.062, 0.018), steel, 16, 8)
    curve_line("ladle_shaft", [(0.316, -0.249, 0.257),
                                (0.411, -0.332, 0.328),
                                (0.469, -0.381, 0.365)], 0.012, steel)
    curve_line("ladle_handle_grip", [(0.461, -0.373, 0.361),
                                      (0.546, -0.447, 0.411)], 0.016, wood)


def garnish_kit():
    """Three tidy pinch bowls of herbs, sesame and citrus peel for plating."""
    wood_platter("garnish_preparation_board", 0.690, 0.420)
    bowls = mat("little_garnish_bowls", "#E5DBC8", 0.54)
    herb = mat("chopped_herb_green", "#6D9E78", 0.80)
    sesame = mat("sesame_pale_gold", "#E3C688", 0.72)
    zest = mat("citrus_zest", "#E3A76E", 0.76)
    for i, x in enumerate((-0.215, 0, 0.215)):
        cylinder(f"garnish_bowl_{i}", (x, 0, 0.125),
                 0.104, 0.052, bowls, 18)
        torus(f"garnish_bowl_lip_{i}", (x, 0, 0.153),
              0.093, 0.010, bowls, 18)
        base = herb if i == 0 else (sesame if i == 1 else zest)
        for j in range(7):
            a = j * 2.399
            r = 0.068 * math.sqrt((j + 0.5) / 7)
            ellipsoid(f"garnish_piece_{i}_{j}",
                      (x + r * math.cos(a), r * math.sin(a), 0.163),
                      (0.014, 0.007, 0.005), base, 9, 6)


def blended_fruit_ice():
    """Visible strawberry-yogurt slurry and fruit in a compact blender jar."""
    base = mat("blender_base_celadon", "#A8C5BA", 0.57)
    glass = mat("frosted_blender_wall", "#C6DDD5", 0.36)
    pink = mat("strawberry_yogurt_blend", "#DAA3A9", 0.43)
    berry = mat("loose_red_fruit", "#C6737A", 0.63)
    cream = mat("yogurt_white", "#F4E5D6", 0.48)
    steel = mat("blender_brushed_steel", "#ABB9B6", 0.39, 0.35)
    cylinder("small_blender_motor", (0, 0, 0.084),
             0.219, 0.164, base, 24)
    cylinder("blender_steel_socket", (0, 0, 0.168),
             0.146, 0.025, steel, 24)
    food.lathe("frosted_blender_jar_profile",
               [(0.127, 0.181), (0.176, 0.198), (0.198, 0.450),
                (0.168, 0.467), (0.153, 0.250)], glass, 28)
    cylinder("visible_pink_smoothie", (0, 0, 0.298),
             0.164, 0.169, pink, 24)
    ellipsoid("fluffy_pink_surface", (0, 0, 0.392),
              (0.154, 0.154, 0.026), pink, 22, 10)
    torus("glass_jar_rolled_lip", (0, 0, 0.461),
          0.182, 0.018, glass, 28)
    curve_line("rounded_blender_handle",
               [(0.186, 0.070, 0.415), (0.284, 0.072, 0.408),
                (0.299, 0.071, 0.253), (0.186, 0.070, 0.244)],
               0.021, base)
    for i, (x, y) in enumerate(((-0.073, -0.020), (0.081, 0.055),
                                (0.019, -0.088))):
        ellipsoid(f"strawberry_chunk_{i}", (x, y, 0.417),
                  (0.041, 0.037, 0.029), berry, 12, 8)
    curve_line("yogurt_swirl_in_blender",
               [(-0.117, 0, 0.410), (0.012, 0.121, 0.419),
                (0.110, 0.002, 0.418)], 0.009, cream)
    # Half-open lid gives this stage a different silhouette from the served cup.
    lid = cylinder("blender_lid_propped_on_edge", (0.152, 0.210, 0.464),
                   0.176, 0.034, base, 26)
    lid.rotation_euler.x = -0.35
    cylinder("lid_grip", (0.152, 0.210, 0.492),
             0.043, 0.023, steel, 14)


def fried_egg_pan():
    """Sunny-side egg setting in a pale pan with a visible golden yolk."""
    pan = mat("pale_enamel_egg_pan", "#9BB9AD", 0.49)
    well = mat("warm_nonstick_well", "#607E78", 0.51)
    handle = mat("short_wooden_handle", "#A98161", 0.81)
    white = mat("soft_setting_egg_white", "#F4EEDF", 0.46)
    yolk = mat("sunny_yolk", "#EDBD67", 0.29)
    bubble = mat("hot_oil_bubbles", "#D5AE72", 0.31)
    cylinder("rounded_egg_pan", (-0.065, 0, 0.060),
             0.292, 0.110, pan, 28)
    cylinder("nonstick_pan_well", (-0.065, 0, 0.117),
             0.253, 0.011, well, 26)
    torus("bright_pan_edge", (-0.065, 0, 0.118),
          0.280, 0.017, pan, 28)
    box("soft_wooden_handle", (0.307, 0, 0.080),
        (0.355, 0.085, 0.048), handle, 0.028)
    ellipsoid("irregular_fried_egg_base", (-0.077, -0.020, 0.135),
              (0.203, 0.168, 0.023), white, 24, 10)
    for i, (x, y) in enumerate(((-0.193, -0.104), (0.035, 0.121),
                                (0.081, -0.091))):
        ellipsoid(f"fried_egg_edge_lobe_{i}", (x, y, 0.133),
                  (0.073, 0.049, 0.014), white, 14, 8)
    ellipsoid("golden_yolk_dome", (-0.066, -0.019, 0.171),
              (0.077, 0.076, 0.042), yolk, 20, 12)
    ellipsoid("yolk_soft_highlight", (-0.092, -0.039, 0.204),
              (0.016, 0.012, 0.004), white, 10, 6)
    for i in range(7):
        a = i * math.tau / 7
        ellipsoid(f"oil_foam_{i}",
                  (-0.066 + 0.225 * math.cos(a),
                   0.180 * math.sin(a), 0.134),
                  (0.017, 0.013, 0.007), bubble, 10, 6)


def coconut_millet_simmer():
    """Warm coconut millet bubbling in a miniature clay cooking pot."""
    clay = mat("clay_simmer_pot", "#A57C65", 0.79)
    rim = mat("clay_sunlit_rim", "#C49B78", 0.82)
    cream = mat("coconut_milk_simmer", "#E9D5B2", 0.47)
    grain = mat("visible_millet_grains", "#B99562", 0.74)
    white = mat("coconut_cream_swirl", "#F3EAD6", 0.44)
    food.lathe("round_clay_cooking_pot",
               [(0.18, 0.012), (0.308, 0.048), (0.341, 0.225),
                (0.311, 0.266), (0.279, 0.170), (0.18, 0.089)], clay, 30)
    torus("clay_pot_rolled_rim", (0, 0, 0.255),
          0.322, 0.020, rim, 30)
    ellipsoid("hot_millet_surface", (0, 0, 0.229),
              (0.277, 0.274, 0.016), cream, 28, 11)
    for side in (-1, 1):
        ellipsoid(f"pot_ear_handle_{side}",
                  (side * 0.343, 0, 0.153),
                  (0.069, 0.101, 0.056), clay, 16, 9)
    for i in range(24):
        a = i * 2.399
        r = 0.225 * math.sqrt((i + 0.5) / 24)
        ellipsoid(f"individual_millet_grain_{i}",
                  (r * math.cos(a), r * math.sin(a), 0.246),
                  (0.019, 0.012, 0.006), grain, 10, 6)
    curve_line("coconut_milk_swirl_in_pot",
               [(-0.110, -0.070, 0.249), (0.075, -0.116, 0.251),
                (0.149, 0.041, 0.249), (-0.028, 0.139, 0.250)],
               0.010, white)
    for i, (x, y) in enumerate(((-0.179, 0.072), (0.175, -0.079),
                                (-0.082, -0.155))):
        ellipsoid(f"coconut_milk_bubble_{i}", (x, y, 0.260),
                  (0.027, 0.024, 0.014), white, 12, 8)


def mixed_shrimp_batter():
    """Rice batter and shrimp in a portable bowl, before the sheets are folded."""
    serving_bowl("shrimp_batter_transfer_bowl", 0.335, 0.172, "#B8D0C6")
    batter = mat("shrimp_batter_soft_white", "#EAE9DB", 0.52)
    fold = mat("shrimp_batter_fold", "#D0D5C6", 0.58)
    shrimp = mat("fresh_shrimp_rose", "#E6A28E", 0.63)
    tail = mat("fresh_shrimp_tail", "#CD8275", 0.69)
    chive = mat("fresh_chive_green", "#6E9D78", 0.80)
    ellipsoid("fresh_rice_batter_surface", (0, 0, 0.143),
              (0.266, 0.255, 0.020), batter, 28, 12)
    curve_line("rice_batter_fold", [(-0.18, -0.03, 0.165),
                                    (-0.06, 0.10, 0.169),
                                    (0.14, 0.05, 0.164)], 0.007, fold)
    for i, (x, y, angle) in enumerate(((-0.115, -0.082, -0.35),
                                      (0.120, -0.035, 0.43),
                                      (-0.018, 0.117, 0.18))):
        curl = curve_line(f"shrimp_curled_in_batter_{i}",
                          [(x - 0.045, y + 0.021, 0.176),
                           (x - 0.015, y - 0.032, 0.184),
                           (x + 0.041, y - 0.010, 0.184)], 0.020, shrimp)
        curl.rotation_euler.z = angle
        ellipsoid(f"shrimp_tail_tip_{i}", (x + 0.046, y + 0.008, 0.184),
                  (0.027, 0.018, 0.012), tail, 12, 8)
    for i in range(7):
        a = i * 2.399
        r = 0.18 * math.sqrt((i + 0.5) / 7)
        garnish_leaf(f"chive_in_shrimp_batter_{i}",
                     (r * math.cos(a), r * math.sin(a), 0.172),
                     0.052, chive, a)


def mixed_seaweed_dough():
    """Green dough and seaweed filling ready for hand folding, not a plain batter."""
    serving_bowl("seaweed_dough_transfer_bowl", 0.335, 0.172, "#B1C9BC")
    dough = mat("soft_pale_green_dough", "#BDCEAC", 0.71)
    cut = mat("opened_dough_face", "#F0EAD7", 0.70)
    seaweed = mat("seaweed_filling_dark", "#4C7C64", 0.82)
    leafy = mat("cut_greens_light", "#80A77D", 0.80)
    for i, (x, y) in enumerate(((-0.112, -0.105), (0.112, -0.100),
                                (-0.020, 0.098))):
        ellipsoid(f"dough_portion_{i}", (x, y, 0.182),
                  (0.108, 0.092, 0.055), dough, 20, 11)
        ellipsoid(f"dough_fold_face_{i}", (x, y - 0.030, 0.228),
                  (0.067, 0.037, 0.006), cut, 16, 8)
    for i in range(6):
        a = i * 2.399
        r = 0.12 * math.sqrt((i + 0.5) / 6)
        ribbon = curve_line(f"seaweed_filling_strand_{i}",
                            [(r * math.cos(a) - 0.042, r * math.sin(a), 0.240),
                             (r * math.cos(a), r * math.sin(a) + 0.023, 0.253),
                             (r * math.cos(a) + 0.039, r * math.sin(a), 0.239)],
                            0.009, seaweed)
        ribbon.rotation_euler.z = a * 0.12
    leafy_cluster("green_dumpling_filling", 0.054, 0.035, 0.245, 0.37, 5)


def mixed_harbour_noodles():
    """Uncooked noodle nest and sliced greens coated with spice oil for the boil."""
    serving_bowl("noodle_mix_bowl", 0.327, 0.162, "#93B4AE")
    noodle = mat("dry_wheat_noodle", "#E6CF9F", 0.77)
    oil = mat("noodle_spice_oil", "#AA7052", 0.38)
    greens = mat("noodle_mix_greens", "#6A9B71", 0.81)
    ellipsoid("shallow_spice_oil", (0, 0, 0.144),
              (0.239, 0.222, 0.009), oil, 24, 9)
    for i in range(10):
        a = i * 0.78
        r = 0.078 + i * 0.014
        curve_line(f"unboiled_wheat_loop_{i}",
                   [(r * math.cos(a), r * math.sin(a), 0.161),
                    (0.070 * math.cos(a + 1.4), 0.070 * math.sin(a + 1.4), 0.205),
                    (-r * math.cos(a + 0.3), -r * math.sin(a + 0.3), 0.168)],
                   0.008, noodle)
    for i in range(6):
        a = i * math.tau / 6
        garnish_leaf(f"uncooked_greens_{i}",
                     (0.16 * math.cos(a), 0.16 * math.sin(a), 0.212),
                     0.102, greens, a)
    for i in range(4):
        ellipsoid(f"spice_oil_bead_{i}",
                  (-0.11 + i * 0.071, -0.012 + (i % 2) * 0.07, 0.215),
                  (0.021, 0.012, 0.005), oil, 10, 6)


def portioned_coconut_millet():
    """One unsweetened coconut cup of millet, waiting for its fruit finish."""
    shell = mat("portion_coconut_fibre", "#A78264", 0.88)
    grain = mat("millet_pudding_gold", "#D6BB87", 0.70)
    milk = mat("coconut_milk_fold", "#F2E9D2", 0.47)
    seed = mat("millet_individual_grain", "#BC9D6E", 0.76)
    serving_bowl("plain_coconut_shell_portion", 0.352, 0.217, "#8B6852")
    torus("rough_coconut_shell_fibre", (0, 0, 0.222), 0.337, 0.022, shell, 30)
    ellipsoid("plain_millet_portion", (0, 0, 0.194),
              (0.282, 0.278, 0.022), grain, 28, 12)
    curve_line("milk_just_poured", [(-0.12, -0.064, 0.218),
                                    (0.03, -0.119, 0.218),
                                    (0.162, 0.027, 0.217)], 0.011, milk)
    for i in range(30):
        a = i * 2.399
        r = 0.226 * math.sqrt((i + 0.5) / 30)
        ellipsoid(f"visible_millet_grain_{i}",
                  (r * math.cos(a), r * math.sin(a), 0.220),
                  (0.018, 0.010, 0.005), seed, 10, 6)


def portioned_chicken_rice():
    """Rice and browned chicken share a plate before greens and soy are added."""
    food.porcelain_plate("chicken_rice_portion_plate", 0.428, 0.85)
    rice = mat("plain_rice_portion", "#EEE9D7", 0.76)
    rice_grain = mat("individual_rice_grain", "#DDD5BE", 0.80)
    flesh = mat("sliced_chicken_flesh", "#E9BC93", 0.69)
    skin = mat("seared_chicken_skin", "#CB8F5D", 0.66)
    grill = mat("small_chicken_grill_marks", "#8A6147", 0.80)
    ellipsoid("warm_rice_mound", (-0.162, 0.014, 0.145),
              (0.178, 0.205, 0.093), rice, 28, 14)
    for i in range(18):
        a = i * 2.399
        r = 0.155 * math.sqrt((i + 0.5) / 18)
        ellipsoid(f"rice_grain_{i}",
                  (-0.162 + r * math.cos(a), 0.014 + r * math.sin(a),
                   0.177 + 0.044 * (1 - r / 0.16)),
                  (0.018, 0.008, 0.005), rice_grain if i % 5 == 0 else rice, 9, 6)
    for i in range(4):
        x, y = 0.005 + 0.058 * i, -0.096 + 0.054 * i
        meat_z = 0.104 + i * 0.005
        item = ellipsoid(f"just_sliced_chicken_{i}",
                         (x, y, meat_z),
                         (0.106, 0.062, 0.039), flesh, 18, 10)
        item.rotation_euler.z = -0.17 + i * 0.08
        ellipsoid(f"golden_skin_{i}", (x, y - 0.011, meat_z + 0.032),
                  (0.102, 0.044, 0.009), skin, 18, 8)
        for j in range(2):
            ellipsoid(f"pan_mark_{i}_{j}",
                      (x - 0.029 + j * 0.057, y - 0.014, meat_z + 0.041),
                      (0.009, 0.023, 0.003), grill, 10, 6)


def portioned_shrimp_roll():
    """Three hand-folded raw shrimp sheets on portable parchment, before steam."""
    board = mat("slim_bamboo_transfer_board", "#B89065", 0.83)
    parchment = mat("folded_rice_parchment", "#F0E8D5", 0.91)
    sheet = mat("uncooked_rice_sheet_portion", "#EEEADF", 0.62)
    fold = mat("rice_sheet_fold_highlight", "#FBF5E9", 0.62)
    shrimp = mat("fresh_shrimp_inside", "#E3A18D", 0.62)
    chive = mat("raw_chive_strips", "#6F9D74", 0.79)
    box("portable_rice_sheet_board", (0, 0, 0.039),
        (0.78, 0.54, 0.073), board, 0.034)
    box("small_parchment_liner", (0, 0, 0.080),
        (0.695, 0.454, 0.010), parchment, 0.014)
    for i, y in enumerate((-0.148, 0.005, 0.158)):
        ellipsoid(f"shrimp_core_{i}", (-0.180, y, 0.111),
                  (0.066, 0.047, 0.028), shrimp, 14, 8)
        ellipsoid(f"rice_sheet_rolled_{i}", (0.035, y, 0.136),
                  (0.222, 0.057, 0.037), sheet, 22, 10)
        curve_line(f"unsteamed_wrapper_edge_{i}",
                   [(-0.145, y + 0.020, 0.161),
                    (0.021, y + 0.042, 0.172),
                    (0.195, y + 0.018, 0.159)], 0.004, fold)
        for j in range(2):
            garnish_leaf(f"chive_under_sheet_{i}_{j}",
                         (-0.09 + j * 0.13, y - 0.012, 0.176),
                         0.051, chive, 0.2 + j * 0.5)


def portioned_seaweed_dumpling():
    """Five raw hand-pinched dumplings on a carry board before steaming."""
    board = mat("dumpling_transfer_board", "#B58B63", 0.83)
    dust = mat("rice_flour_dusting", "#EADFC7", 0.89)
    wrapper = mat("uncooked_jade_wrapper", "#B9CBA7", 0.70)
    ridge = mat("pinched_wrapper_ridge", "#DCE5C8", 0.70)
    filling = mat("seaweed_greens_filling", "#58876B", 0.83)
    box("portable_dumpling_board", (0, 0, 0.038),
        (0.74, 0.56, 0.073), board, 0.037)
    for i in range(13):
        a = i * 2.399
        r = 0.27 * math.sqrt((i + 0.5) / 13)
        ellipsoid(f"fine_flour_dusting_{i}",
                  (r * math.cos(a), 0.75 * r * math.sin(a), 0.079),
                  (0.015, 0.009, 0.003), dust, 9, 6)
    positions = [(-0.190, -0.132), (0.095, -0.142),
                 (-0.040, 0.010), (-0.190, 0.158), (0.105, 0.148)]
    for i, (x, y) in enumerate(positions):
        verts = []
        for section in range(9):
            t = section / 8
            px = x - 0.108 + 0.216 * t
            width = max(0.12, math.sin(math.pi * t) ** 0.72)
            verts.extend([
                (px, y - 0.050 * width, 0.094),
                (px, y - 0.062 * width, 0.126),
                (px, y + 0.003 * width, 0.163 + 0.013 * width),
                (px, y + 0.056 * width, 0.122),
                (px, y + 0.043 * width, 0.094),
            ])
        faces = []
        for section in range(8):
            for edge in range(5):
                faces.append((section * 5 + edge,
                              (section + 1) * 5 + edge,
                              (section + 1) * 5 + (edge + 1) % 5,
                              section * 5 + (edge + 1) % 5))
        faces.append(tuple(reversed(range(5))))
        faces.append(tuple(8 * 5 + edge for edge in range(5)))
        mesh(f"unsteamed_crescent_wrapper_{i}", verts, faces, wrapper)
        ellipsoid(f"seaweed_filling_seam_{i}", (x, y - 0.059, 0.134),
                  (0.066, 0.011, 0.008), filling, 14, 8)
        for fleck in range(2):
            ellipsoid(f"seaweed_fleck_on_wrapper_{i}_{fleck}",
                      (x - 0.024 + fleck * 0.049,
                       y + 0.013, 0.176),
                      (0.013, 0.006, 0.003), filling, 9, 6)
        for j in range(4):
            px = x - 0.063 + j * 0.041
            curve_line(f"hand_pinched_pleat_{i}_{j}",
                       [(px - 0.013, y + 0.004, 0.168),
                        (px, y + 0.013, 0.179),
                        (px + 0.012, y + 0.006, 0.169)], 0.0038, ridge)


STAGES = [
    ("washed_greens", washed_greens),
    ("washed_fruit", washed_fruit),
    ("washed_millet", washed_millet),
    ("washed_rice", washed_rice),
    ("washed_shrimp", washed_shrimp),
    ("washed_seaweed", washed_seaweed),
    ("chopped_ingredients", chopped_ingredients),
    ("sliced_bun_veg", sliced_bun_veg),
    ("sliced_chicken_spice", sliced_chicken_spice),
    ("sliced_noodle_greens", sliced_noodle_greens),
    ("sliced_fruit", sliced_fruit),
    ("sliced_spices", sliced_spices),
    ("rice_batter_bowl", rice_batter_bowl),
    ("spice_jar", spice_jar),
    ("steamer_rice_roll", steamer_rice_roll),
    ("steamer_shrimp_roll", steamer_shrimp_roll),
    ("steamer_seaweed_dumpling", steamer_seaweed_dumpling),
    ("finished_serving_tray", finished_serving_tray),
    ("marinated_chicken", marinated_chicken),
    ("pan_seared_chicken", pan_seared_chicken),
    ("boiling_noodles", boiling_noodles),
    ("portioned_tofu", portioned_tofu),
    ("simmering_tofu_basin", simmering_tofu_basin),
    ("garnish_kit", garnish_kit),
    ("blended_fruit_ice", blended_fruit_ice),
    ("fried_egg_pan", fried_egg_pan),
    ("coconut_millet_simmer", coconut_millet_simmer),
    ("mixed_shrimp_batter", mixed_shrimp_batter),
    ("mixed_seaweed_dough", mixed_seaweed_dough),
    ("mixed_harbour_noodles", mixed_harbour_noodles),
    ("portioned_coconut_millet", portioned_coconut_millet),
    ("portioned_chicken_rice", portioned_chicken_rice),
    ("portioned_shrimp_roll", portioned_shrimp_roll),
    ("portioned_seaweed_dumpling", portioned_seaweed_dumpling),
]


if __name__ == "__main__":
    requested = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else set()
    for name, builder in STAGES:
        if not requested or name in requested:
            food.export_and_preview(name, builder)
