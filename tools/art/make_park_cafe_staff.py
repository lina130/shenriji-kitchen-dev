"""Talent Park cafe staff miniatures: preparation assistant and pickup clerk.

Blender metres; +Z up, face toward local -Y, origin at floor centre.
GLB import converts the facing direction to Godot +Z.
"""

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "assets" / "art" / "models"
SOURCE = ROOT / "tools" / "art" / "source"
MODEL.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0


def srgb(hex_value):
    c = [int(hex_value[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c) + (1,)


def mat(name, hex_value, rough=0.78, metal=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = srgb(hex_value)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = srgb(hex_value)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return m


def ellipsoid(name, xyz, radii, material, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         location=xyz)
    o = bpy.context.object
    o.name = name
    o.scale = radii
    o.data.materials.append(material)
    return o


def box(name, xyz, dims, material, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel:
        mod = o.modifiers.new("rounded_seam", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        weighted = o.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
        weighted.keep_sharp = True
    return o


def rod(name, start, end, radius, material, vertices=12):
    a, b = Vector(start), Vector(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=(b - a).length, location=(a + b) / 2)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(material)
    return o


def tapered_sleeve(name, path, radii, material, sides=14):
    """One connected, gently bent sleeve rather than stacked sphere joints."""
    vertices = []
    for i, (point, radius) in enumerate(zip(path, radii)):
        center = Vector(point)
        before = Vector(path[max(0, i - 1)])
        after = Vector(path[min(len(path) - 1, i + 1)])
        tangent = (after - before).normalized()
        right = tangent.cross(Vector((0, 1, 0))).normalized()
        front = tangent.cross(right).normalized()
        for j in range(sides):
            a = j * math.tau / sides
            vertices.append(center + radius * (math.cos(a) * right +
                                               math.sin(a) * front))
    faces = []
    for i in range(len(path) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(path) - 1) * sides + j for j in range(sides)))
    data = bpy.data.meshes.new(name + "_mesh")
    data.from_pydata(vertices, [], faces)
    data.update()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    data.materials.append(material)
    for face in data.polygons:
        face.use_smooth = True
    return o


def curved(name, points, radius, material):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 12
    data.bevel_depth = radius
    data.bevel_resolution = 2
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for handle, p in zip(spline.bezier_points, points):
        handle.co = p
        handle.handle_left_type = "AUTO"
        handle.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def staff(role):
    prep = role == "park_prep_assistant"
    skin = mat("peach_skin", "#F0BC9E", 0.69)
    skin_shade = mat("skin_nose", "#DEA98D", 0.73)
    blush = mat("warm_blush", "#E79A97", 0.86)
    eye = mat("dark_eye", "#3B4749", 0.39)
    glint = mat("eye_glint", "#FFF9E9", 0.30)
    mouth = mat("small_smile", "#9F6666", 0.80)
    hair = mat("soft_brown_hair" if prep else "ink_hair",
               "#65504B" if prep else "#3D414B", 0.83)
    hair_lit = mat("hair_highlights", "#84665B" if prep else "#5A5D68", 0.81)
    blouse = mat("linen_blouse", "#F5E9D9", 0.91)
    blouse_shadow = mat("linen_sleeve_cuff", "#DCD9CA", 0.89)
    apron = mat("sage_prep_apron" if prep else "coral_service_apron",
                "#8CB7A4" if prep else "#DB9187", 0.84)
    apron_dark = mat("apron_seam", "#669B87" if prep else "#BC716A", 0.87)
    apron_light = mat("apron_trim", "#B6D1B8" if prep else "#EDB4A5", 0.83)
    pants = mat("soft_slate_trousers", "#7C8390", 0.84)
    shoes = mat("soft_canvas_shoes", "#C8BEB1", 0.82)
    soles = mat("warm_rubber_sole", "#9F998F", 0.90)
    accent = mat("staff_accent", "#D3AE70" if prep else "#7EADAC", 0.69)

    # Rounded, short-legged miniature proportions, approximately 1.55 m tall.
    for side, x in (("L", -0.145), ("R", 0.145)):
        tapered_sleeve(f"{side}_single_tapered_pant_leg",
                       [(x, 0.018, 0.622),
                        (x, 0.018, 0.516),
                        (x, 0.010, 0.377),
                        (x, -0.018, 0.075)],
                       [0.122, 0.119, 0.104, 0.077], pants)
        box(f"{side}_low_canvas_shoe", (x, -0.060, 0.088),
            (0.255, 0.296, 0.105), shoes, 0.050)
        box(f"{side}_thin_sole", (x, -0.062, 0.027),
            (0.265, 0.306, 0.034), soles, 0.015)
    ellipsoid("cafe_torso", (0, 0.013, 0.800),
              (0.320, 0.211, 0.310), blouse)
    ellipsoid("soft_hip", (0, 0.020, 0.595),
              (0.281, 0.187, 0.112), pants)
    box("apron_body", (0, -0.205, 0.751),
        (0.497, 0.057, 0.516), apron, 0.055)
    for side, x in (("L", -0.245), ("R", 0.245)):
        rod(f"{side}_apron_strap", (x * 0.50, -0.225, 1.045),
            (x * 0.88, -0.236, 0.902), 0.023, apron_dark)
        tapered_sleeve(f"{side}_continuous_linen_sleeve",
                       [(x * 1.08, 0.040, 0.996),
                        (x * 1.27, 0.012, 0.938),
                        (x * 1.42, -0.040, 0.866),
                        (x * 1.52, -0.102, 0.749),
                        (x * 1.42, -0.155, 0.627)],
                       [0.070, 0.081, 0.084, 0.073, 0.055], blouse)
        rod(f"{side}_flat_wrist_cuff", (x * 1.42, -0.150, 0.645),
            (x * 1.42, -0.163, 0.614), 0.057, blouse_shadow)
        ellipsoid(f"{side}_small_hand", (x * 1.39, -0.191, 0.557),
                  (0.052, 0.048, 0.076), skin)
    box("apron_front_pocket", (0, -0.250, 0.662),
        (0.270, 0.028, 0.159), apron_light, 0.021)
    box("pocket_top_seam", (0, -0.268, 0.746),
        (0.282, 0.010, 0.015), apron_dark, 0.005)
    rod("neck", (0, 0, 1.063), (0, 0, 1.170), 0.100, skin)
    ellipsoid("rounded_face", (0, -0.015, 1.322),
              (0.268, 0.236, 0.264), skin, 28, 18)
    for side, x in (("L", -0.269), ("R", 0.269)):
        ellipsoid(f"{side}_ear", (x, -0.015, 1.329),
                  (0.051, 0.056, 0.078), skin)
    for side, x in (("L", -0.100), ("R", 0.100)):
        ellipsoid(f"{side}_eye", (x, -0.242, 1.356),
                  (0.026, 0.015, 0.034), eye, 16, 10)
        ellipsoid(f"{side}_eye_glint", (x - 0.006, -0.255, 1.369),
                  (0.008, 0.005, 0.010), glint, 12, 8)
        ellipsoid(f"{side}_cheek", (x * 1.80, -0.207, 1.276),
                  (0.056, 0.008, 0.027), blush, 16, 8)
    ellipsoid("tiny_nose", (0, -0.251, 1.296),
              (0.027, 0.022, 0.024), skin_shade)
    curved("small_smile_curve", [(-0.059, -0.241, 1.248),
                                  (0, -0.258, 1.237),
                                  (0.059, -0.241, 1.248)], 0.005, mouth)

    # Hair silhouette and service headwear differentiate the two NPCs.
    ellipsoid("hair_back", (0, 0.054, 1.389),
              (0.293, 0.233, 0.219), hair, 26, 16)
    ellipsoid("hair_crown", (0, 0.011, 1.504),
              (0.278, 0.222, 0.087), hair, 26, 14)
    if prep:
        fringe = ellipsoid("one_swept_fringe", (-0.018, -0.184, 1.485),
                           (0.227, 0.070, 0.064), hair_lit, 28, 12)
        fringe.rotation_euler.y = -0.12
        for side, x in (("L", -0.255), ("R", 0.255)):
            ellipsoid(f"{side}_bob_lock", (x, 0.008, 1.331),
                      (0.078, 0.106, 0.156), hair)
        curved("mint_hair_ribbon", [(-0.275, 0.005, 1.512),
                                     (0, -0.110, 1.550),
                                     (0.275, 0.005, 1.512)],
               0.023, apron_light)
        box("prep_board", (0, -0.321, 0.568),
            (0.396, 0.243, 0.043), accent, 0.025)
        herb = mat("fresh_chopped_herbs", "#5F9D71", 0.83)
        for i in range(7):
            a = 2.4 * i
            ellipsoid(f"board_herb_{i}",
                      (0.072 * math.cos(a), -0.32 + 0.061 * math.sin(a), 0.597),
                      (0.030, 0.018, 0.010), herb, 12, 8)
        rod("wooden_spatula_handle", (-0.11, -0.397, 0.596),
            (0.06, -0.312, 0.598), 0.011, apron_dark)
        box("wooden_spatula_head", (0.075, -0.305, 0.599),
            (0.083, 0.042, 0.014), accent, 0.007)
    else:
        cap = mat("service_cap", "#99C4B8", 0.82)
        ellipsoid("service_cap_crown", (0, -0.006, 1.548),
                  (0.282, 0.227, 0.082), cap)
        ellipsoid("soft_cap_bill", (0, -0.208, 1.499),
                  (0.241, 0.105, 0.023), apron_dark)
        ellipsoid("low_hair_bun", (0.198, 0.181, 1.373),
                  (0.100, 0.107, 0.104), hair_lit)
        ellipsoid("single_cap_hairline", (0, -0.177, 1.461),
                  (0.197, 0.050, 0.031), hair)
        paper = mat("takeaway_paper", "#EACBA5", 0.91)
        box("takeaway_bag", (0.212, -0.328, 0.620),
            (0.285, 0.170, 0.288), paper, 0.019)
        for x in (0.135, 0.287):
            curved(f"bag_handle_{x}", [(x, -0.418, 0.760),
                                       (x, -0.418, 0.828),
                                       (x, -0.418, 0.762)],
                   0.009, apron_dark)
        box("bag_fold", (0.212, -0.418, 0.635),
            (0.187, 0.008, 0.022), apron_light, 0.004)
        box("bag_leaf_seal", (0.212, -0.425, 0.685),
            (0.048, 0.008, 0.061), cap, 0.012)


def export(role):
    reset()
    staff(role)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (role + ".blend")))
    bpy.ops.export_scene.gltf(filepath=str(MODEL / (role + ".glb")),
                              export_format="GLB")
    floor = mat("PREVIEW_ONLY_floor", "#D9DEDA", 0.95)
    box("PREVIEW_ONLY_floor", (0, 0, -0.065), (1.6, 1.45, 0.12), floor)
    world = bpy.data.worlds[0]
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.84, 0.87, 0.84, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.45
    bpy.ops.object.light_add(type="AREA", location=(-2.1, -2.5, 3.2))
    bpy.context.object.data.energy = 250
    bpy.context.object.data.size = 2.1
    bpy.ops.object.light_add(type="AREA", location=(1.8, 1.3, 2.5))
    bpy.context.object.data.energy = 95
    bpy.context.object.data.size = 1.5
    bpy.ops.object.camera_add(location=(2.0, -3.1, 2.0))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.85)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.13
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 760
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(MODEL / (role + "_preview.png"))
    bpy.ops.render.render(write_still=True)
    print("PARK_STAFF_READY:" + role)


for role_name in ("park_prep_assistant", "park_pickup_clerk"):
    export(role_name)
