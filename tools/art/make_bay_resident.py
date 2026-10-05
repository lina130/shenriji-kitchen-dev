"""Create an original miniature Greater Bay Area resident with a walk cycle.

Metres; +Z up and -Y is the face.  The game GLB includes a root visual and
local-motion limbs, while the character controller supplies world motion.
"""

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "models"
SOURCE = ROOT / "tools" / "art" / "source"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def srgb(hex_value):
    values = [int(hex_value[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values) + (1,)


def material(name, color, rough=0.8, metal=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = srgb(color)
    result.use_nodes = True
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = srgb(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return result


skin = material("warm_skin", "#E7AC88", 0.62)
skin_light = material("sunlit_skin", "#F2BD9D", 0.64)
blush = material("soft_peach_cheeks", "#E99588", 0.84)
hair = material("deep_chestnut_hair", "#423C3C", 0.80)
hair_lit = material("chestnut_highlight", "#65514A", 0.84)
eye = material("dark_ink_eyes", "#283941", 0.35)
eye_glint = material("eye_warm_reflection", "#FCF6E8", 0.26)
mouth = material("soft_berry_smile", "#8A534F", 0.86)
jacket = material("sea_glass_overshirt", "#70A9A2", 0.84)
jacket_dark = material("overshirt_fold", "#568D8A", 0.88)
jacket_light = material("seam_highlight", "#91C0B6", 0.86)
shirt = material("linen_cream_top", "#F1DFC8", 0.88)
stripe = material("shirt_coral_stripe", "#D58978", 0.86)
trouser = material("slate_navy_trouser", "#515D75", 0.82)
trouser_light = material("trouser_cuff", "#6D7890", 0.84)
shoe = material("cream_canvas_sneaker", "#E4DAC9", 0.78)
shoe_sole = material("rubber_sneaker_sole", "#BFB7A8", 0.94)
shoe_toe = material("shoe_coral_toecap", "#C88272", 0.77)
bag = material("crossbody_warm_cognac", "#BE8C60", 0.77)
bag_dark = material("bag_folds", "#926C53", 0.86)
metal = material("brushed_bag_hardware", "#C6AD83", 0.39, 0.49)


def bevel(obj, width=0.025):
    if width <= 0:
        return obj
    mod = obj.modifiers.new("soft_edge", "BEVEL")
    mod.width = width
    mod.segments = 3
    mod.limit_method = "ANGLE"
    weighted = obj.modifiers.new("weighted_normal", "WEIGHTED_NORMAL")
    weighted.keep_sharp = True
    return obj


def cuboid(name, pos, dims, mat, radius=0.02, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel(obj, radius)
    if parent is not None:
        attach_keep_world(obj, parent)
    return obj


def ellipsoid(name, pos, dims, mat, parent=None, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.scale = dims
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if parent is not None:
        attach_keep_world(obj, parent)
    return obj


def cylinder(name, pos, radius, depth, mat, parent=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel(obj, 0.009)
    if parent is not None:
        attach_keep_world(obj, parent)
    return obj


def attach_keep_world(obj, parent):
    # Blender lazily updates matrix_world after direct Euler/location edits.
    # Flush it before parenting so diagonal straps and limb offsets survive.
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def pivot(name, position, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = position
    if parent is not None:
        attach_keep_world(obj, parent)
    return obj


def rod(name, start, end, radius, mat, parent=None, vertices=12):
    midpoint = (Vector(start) + Vector(end)) / 2
    direction = Vector(end) - Vector(start)
    obj = cylinder(name, midpoint, radius, direction.length, mat, None, vertices)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    if parent is not None:
        attach_keep_world(obj, parent)
    return obj


def curved_line(name, points, radius, mat, parent=None):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 12
    data.bevel_depth = radius
    data.bevel_resolution = 2
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for handle, point in zip(spline.bezier_points, points):
        handle.co = point
        handle.handle_left_type = "AUTO"
        handle.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if parent is not None:
        attach_keep_world(obj, parent)
    return obj


root = pivot("ResidentVisual", (0, 0, 0))
body = pivot("BodyBob", (0, 0, 0), root)
left_leg = pivot("WalkLegLeft", (-0.185, 0.015, 0.78), root)
right_leg = pivot("WalkLegRight", (0.185, 0.015, 0.78), root)
left_arm = pivot("WalkArmLeft", (-0.41, 0.00, 1.21), body)
right_arm = pivot("WalkArmRight", (0.41, 0.00, 1.21), body)

# Shoes, shaped trouser legs and small ankle reveal preserve the silhouette at
# both street distance and close camera zoom.
for side, x, leg_pivot in (("left", -0.185, left_leg), ("right", 0.185, right_leg)):
    ellipsoid(f"{side}_trouser_thigh", (x, 0.005, 0.58), (0.155, 0.152, 0.250), trouser, leg_pivot)
    ellipsoid(f"{side}_trouser_lower", (x, 0.010, 0.34), (0.134, 0.127, 0.205), trouser, leg_pivot)
    ellipsoid(f"{side}_trouser_cuff", (x, 0.010, 0.245), (0.138, 0.132, 0.055), trouser_light, leg_pivot)
    ellipsoid(f"{side}_visible_sock", (x, -0.005, 0.205), (0.105, 0.105, 0.061), shirt, leg_pivot)
    ellipsoid(f"{side}_sneaker", (x, -0.065, 0.115), (0.162, 0.232, 0.111), shoe, leg_pivot)
    ellipsoid(f"{side}_shoe_toe", (x, -0.246, 0.105), (0.130, 0.078, 0.072), shoe_toe, leg_pivot)
    cuboid(f"{side}_shoe_sole", (x, -0.070, 0.055), (0.30, 0.425, 0.058), shoe_sole, 0.030, leg_pivot)
    for lace_index in range(3):
        cuboid(f"{side}_shoe_lace_{lace_index}",
                (x, -0.177 + lace_index * 0.045, 0.212 - lace_index * 0.010),
                (0.095, 0.018, 0.012), shirt, 0.004, leg_pivot)

# Oversized but human-scale torso: tapered linen tee below an open lightweight
# jacket, with cuffs, panel seams, pocket flaps and a tiny zipper pull.
ellipsoid("trouser_waist", (0, 0.01, 0.79), (0.345, 0.225, 0.14), trouser, body)
ellipsoid("linen_top", (0, 0.010, 1.055), (0.355, 0.230, 0.335), shirt, body)
for stripe_z in (0.985, 1.115):
    cuboid(f"shirt_woven_stripe_{stripe_z}", (0, -0.234, stripe_z),
            (0.63, 0.018, 0.018), stripe, 0.008, body)
for side, x in (("left", -0.272), ("right", 0.272)):
    panel = ellipsoid(f"jacket_open_panel_{side}", (x, -0.080, 1.08),
                      (0.138, 0.205, 0.352), jacket, body)
    panel.rotation_euler.y = -0.10 if x < 0 else 0.10
    rod(f"jacket_front_seam_{side}", (x * 0.72, -0.252, 0.865),
        (x * 0.72, -0.252, 1.29), 0.015, jacket_light, body)
    cuboid(f"jacket_patch_pocket_{side}", (x * 1.13, -0.271, 0.965),
            (0.145, 0.025, 0.115), jacket_dark, 0.018, body)
    cuboid(f"jacket_pocket_flap_{side}", (x * 1.13, -0.292, 1.032),
            (0.16, 0.035, 0.030), jacket_light, 0.009, body)
ellipsoid("jacket_back", (0, 0.085, 1.075), (0.395, 0.218, 0.350), jacket, body)
ellipsoid("collar_left", (-0.128, -0.165, 1.357), (0.17, 0.083, 0.075), jacket_light, body)
ellipsoid("collar_right", (0.128, -0.165, 1.357), (0.17, 0.083, 0.075), jacket_light, body)
cuboid("zipper_pull", (0.034, -0.283, 1.19), (0.025, 0.015, 0.062), metal, 0.004, body)
ellipsoid("neck", (0, 0, 1.365), (0.102, 0.100, 0.122), skin, body)

for side, x, arm in (("left", -0.41, left_arm), ("right", 0.41, right_arm)):
    ellipsoid(f"{side}_sleeve", (x, 0, 1.056), (0.151, 0.155, 0.230), jacket, arm)
    ellipsoid(f"{side}_sleeve_cuff", (x, -0.004, 0.864), (0.135, 0.132, 0.071), jacket_dark, arm)
    ellipsoid(f"{side}_hand", (x, -0.012, 0.750), (0.103, 0.092, 0.132), skin, arm)
    ellipsoid(f"{side}_thumb", (x + (0.058 if x < 0 else -0.058), -0.080, 0.756),
              (0.042, 0.047, 0.076), skin_light, arm)

# Soft facial volume, tiny distinct ears and glossy eye dots. No printed face
# texture is required, so the GLB remains crisp at close zoom.
ellipsoid("face", (0, -0.016, 1.594), (0.306, 0.267, 0.336), skin_light, body, 24, 16)
for side, x in (("left", -0.300), ("right", 0.300)):
    ellipsoid(f"ear_{side}", (x, -0.015, 1.579), (0.060, 0.062, 0.100), skin, body)
for side, x in (("left", -0.118), ("right", 0.118)):
    ellipsoid(f"eye_{side}", (x, -0.269, 1.628), (0.030, 0.020, 0.049), eye, body, 16, 10)
    ellipsoid(f"eye_glint_{side}", (x - 0.008, -0.286, 1.647),
              (0.009, 0.007, 0.013), eye_glint, body, 12, 8)
    ellipsoid(f"cheek_{side}", (x * 1.63, -0.245, 1.528),
              (0.070, 0.011, 0.038), blush, body, 16, 8)
ellipsoid("small_nose", (0, -0.281, 1.554), (0.032, 0.028, 0.033), skin, body)
curved_line("subtle_smile", [(-0.075, -0.269, 1.485), (0, -0.283, 1.466),
                             (0.075, -0.269, 1.485)], 0.0075, mouth, body)

# Asymmetric short hair, under-layer at the back, shaped crown, side locks and
# separate fringe pieces make the head readable on every camera orbit.
ellipsoid("hair_back", (0, 0.057, 1.681), (0.329, 0.271, 0.302), hair, body, 24, 16)
ellipsoid("hair_crown", (0, 0.026, 1.831), (0.326, 0.277, 0.172), hair, body, 24, 14)
for side, x in (("left", -0.265), ("right", 0.266)):
    lock = ellipsoid(f"hair_side_lock_{side}", (x, -0.056, 1.665),
                     (0.082, 0.116, 0.233), hair if x < 0 else hair_lit, body)
    lock.rotation_euler.y = 0.13 if x < 0 else -0.13
for i in range(4):
    x = -0.201 + i * 0.126
    lock = ellipsoid(f"swept_fringe_{i}", (x, -0.202, 1.822 - i * 0.019),
                     (0.114, 0.088, 0.080), hair_lit if i == 1 else hair, body)
    lock.rotation_euler.y = 0.22

# Everyday transit accessory: adjustable canvas strap with buckle and rounded
# side satchel. Phone corner and key ring are tiny secondary focal points.
rod("crossbody_strap_front", (-0.29, -0.222, 1.282),
    (0.39, -0.236, 0.875), 0.028, bag_dark, body)
rod("crossbody_strap_back", (-0.30, 0.215, 1.28),
    (0.40, 0.214, 0.865), 0.028, bag_dark, body)
ellipsoid("satchel_main", (0.407, -0.044, 0.861), (0.172, 0.158, 0.218), bag, body)
cuboid("satchel_flap", (0.421, -0.206, 0.923), (0.298, 0.045, 0.145), bag_dark, 0.023, body)
cuboid("satchel_seam", (0.421, -0.236, 0.857), (0.246, 0.012, 0.017), bag, 0.005, body)
cuboid("satchel_clasp", (0.416, -0.237, 0.886), (0.047, 0.018, 0.053), metal, 0.006, body)
ellipsoid("satchel_key_ring", (0.545, -0.117, 0.747), (0.035, 0.021, 0.050), metal, body)

# A seam-sized mint hair clip provides a stronger visual identity without any
# logos or culture-specific caricature.
cuboid("hair_clip", (-0.208, -0.211, 1.807), (0.105, 0.028, 0.026), jacket_light, 0.011, body)

# One full stationary walk loop. The controller translates the root, while
# four pivots and a subtle body bob animate in place.
scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 25
scene.render.fps = 24
for frame, angle in ((1, 0.34), (7, 0.0), (13, -0.34), (19, 0.0), (25, 0.34)):
    left_leg.rotation_euler.x = angle
    right_leg.rotation_euler.x = -angle
    left_arm.rotation_euler.x = -angle * 0.70
    right_arm.rotation_euler.x = angle * 0.70
    for obj in (left_leg, right_leg, left_arm, right_arm):
        obj.keyframe_insert(data_path="rotation_euler", frame=frame, group="Walk")
for frame, bob in ((1, 0.0), (4, 0.028), (7, 0.0), (10, 0.028),
                   (13, 0.0), (16, 0.028), (19, 0.0), (22, 0.028), (25, 0.0)):
    body.location.z = bob
    body.keyframe_insert(data_path="location", frame=frame, group="Walk")
for obj in (left_leg, right_leg, left_arm, right_arm, body):
    if obj.animation_data and obj.animation_data.action:
        action = obj.animation_data.action
        action.name = "Walk_" + obj.name

scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "bay_resident.blend"))
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "bay_resident.glb"), export_format="GLB",
    export_animation_mode="ACTIVE_ACTIONS",
)

# Render review only after exporting: review lights never contaminate the GLB.
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.80, 0.85, 0.84, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.60
bpy.ops.object.light_add(type="AREA", location=(-3, -4, 7))
bpy.context.object.data.energy = 730
bpy.context.object.data.size = 4
bpy.ops.object.light_add(type="AREA", location=(3, 2, 5))
bpy.context.object.data.energy = 340
bpy.context.object.data.size = 3
bpy.ops.object.camera_add(location=(3.1, -5.1, 2.9))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0.96)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.48
scene.camera = camera
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / "bay_resident_preview.png")
bpy.ops.render.render(write_still=True)
print("ART_ASSET_READY:" + str(OUT / "bay_resident.glb"))
