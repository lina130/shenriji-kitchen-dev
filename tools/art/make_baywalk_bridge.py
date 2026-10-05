"""Original repeatable Greater Bay waterfront footbridge span.

The 12 m module joins at local Y +/-6 m. Its walk surface is at local Z=0,
with a 3.8 m clear path between the two guardrails. Water-support structure
extends below the deck. Review lights and backdrop are never exported.
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
    vals = [int(hex_value[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in vals) + (1,)


def material(name, hex_value, rough=0.8, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = srgb(hex_value)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = srgb(hex_value)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


ivory = material("warm_coastal_concrete", "#D7CFBB", 0.92)
ivory_shade = material("bridge_edge_weathering", "#ABA99E", 0.91)
wood = material("sun_washed_deck_timber", "#B48B69", 0.77)
wood_light = material("deck_timbers_highlights", "#CEA17A", 0.76)
wood_dark = material("deck_joints_and_endgrain", "#866F60", 0.91)
jade = material("jade_bridge_lacquer", "#6BA49F", 0.62, 0.18)
jade_light = material("sunlit_rail_jade", "#8CBDB3", 0.62, 0.15)
jade_dark = material("rail_structure_deep_jade", "#3E7475", 0.63, 0.25)
steel = material("brushed_bridge_stainless", "#B4C1BA", 0.39, 0.72)
brass = material("marine_brass_fasteners", "#D2B47A", 0.45, 0.55)
glass = material("soft_glazed_bridge_infill", "#9CC4C1", 0.27, 0.04)
terracotta = material("warm_coastal_terracotta", "#C87C66", 0.82)
rubber = material("dark_footbridge_fender", "#4E5B5E", 0.95)
leaf = material("salt_tolerant_greenery", "#568C67", 0.92)
leaf_bright = material("salt_tolerant_leaf_tips", "#8DB68A", 0.90)
lamp = material("frosted_lantern_glass", "#F5DFB4", 0.41)


def bevel(obj, radius):
    if radius <= 0:
        return obj
    mod = obj.modifiers.new("rounded_machined_edges", "BEVEL")
    mod.width = radius
    mod.segments = 3
    mod.limit_method = "ANGLE"
    normal = obj.modifiers.new("weighted_normal", "WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def box(name, xyz, dims, mat, radius=0.028):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return bevel(obj, radius)


def cylinder(name, xyz, radius, depth, mat, vertices=18):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return bevel(obj, 0.009)


def sphere(name, xyz, radii, mat, segments=18, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.scale = radii
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def rod(name, start, end, radius, mat, vertices=12):
    direction = Vector(end) - Vector(start)
    midpoint = (Vector(start) + Vector(end)) / 2
    obj = cylinder(name, midpoint, radius, direction.length, mat, vertices)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def curve_line(name, points, radius, mat):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, xyz in zip(spline.points, points):
        point.co = (*xyz, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def shaped_mesh(name, verts, faces, mat, thickness=0):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if thickness:
        solid = obj.modifiers.new("profile_thickness", "SOLIDIFY")
        solid.thickness = thickness
        bevel(obj, 0.02)
    return obj


# Edge coordinates are exact and deliberately unobstructed: another module
# can be instanced at +/-12 m without a visible deck or guardrail seam.
box("bridge_rounded_concrete_slab", (0, 0, -0.246),
    (4.78, 12.0, 0.38), ivory, 0.16)
box("inset_deck_dark_reveal", (0, 0, -0.056),
    (4.41, 11.97, 0.05), wood_dark, 0.028)
for i in range(33):
    y = -5.81 + i * 0.363
    box(f"crossgrain_board_{i:02}", (0, y, -0.002),
        (4.31, 0.337, 0.057), wood_light if i % 6 == 0 else wood, 0.017)
    for x in (-1.93, 1.93):
        for dy in (-0.12, 0.12):
            cylinder(f"recessed_screw_{i:02}_{x}_{dy}",
                     (x, y + dy, 0.028), 0.012, 0.003, steel, 8)
for x in (-2.15, 2.15):
    box(f"continuous_edge_guard_{x}", (x, 0, 0.045),
        (0.16, 12.0, 0.21), ivory_shade, 0.065)
    box(f"bronze_guiding_inlay_{x}", (x + (-0.04 if x < 0 else 0.04), 0, 0.154),
        (0.025, 12.0, 0.010), brass, 0.005)

# Two softly scalloped side girders give the bridge a sculpted underside,
# unlike a plain box slab. Their profiles repeat at both module ends.
for side, x in (("port", -2.30), ("starboard", 2.30)):
    vertices = []
    for i in range(49):
        y = -6.0 + i * 0.25
        scallop = 0.22 * (1 - math.cos((y + 6.0) * math.tau / 6.0)) / 2
        vertices.append((x, y, -0.34 - scallop))
    for i in range(49):
        y = -6.0 + i * 0.25
        vertices.append((x, y, -0.68 - 0.28 *
                         (1 - math.cos((y + 6.0) * math.tau / 6.0)) / 2))
    faces = [(i, i + 1, 49 + i + 1, 49 + i) for i in range(48)]
    shaped_mesh(f"wave_girder_{side}", vertices, faces, jade_dark, 0.12)
    rod(f"girder_lit_top_{side}", (x, -6, -0.35),
        (x, 6, -0.35), 0.035, jade_light)
    # Narrow bolted vertical fins make the structure look assembled.
    for i in range(9):
        y = -5.45 + i * 1.36
        box(f"girder_fin_{side}_{i}", (x + (-0.08 if x < 0 else 0.08), y, -0.47),
            (0.04, 0.11, 0.37), jade, 0.013)
        cylinder(f"girder_fin_rivet_{side}_{i}",
                 (x + (-0.111 if x < 0 else 0.111), y, -0.43),
                 0.026, 0.016, brass, 10)

# The bright, slight wave of the handrail reads from far away. Center walking
# width between inner rail faces exceeds 3.8 m throughout this straight span.
for side, x in (("left", -2.27), ("right", 2.27)):
    for idx in range(9):
        y = -5.75 + idx * 1.4375
        cylinder(f"rail_post_{side}_{idx}", (x, y, 0.70),
                 0.047, 1.32, jade_dark, 14)
        cylinder(f"rail_post_collar_{side}_{idx}", (x, y, 0.15),
                 0.088, 0.12, brass, 14)
        sphere(f"rail_post_finial_{side}_{idx}", (x, y, 1.41),
               (0.08, 0.08, 0.08), brass)
        if idx < 8:
            mid_y = y + 0.71875
            box(f"glazed_panel_{side}_{idx}", (x, mid_y, 0.91),
                (0.032, 1.24, 0.43), glass, 0.018)
            for z in (0.59, 1.23):
                rod(f"panel_bound_{side}_{idx}_{z}",
                    (x, y + 0.11, z), (x, y + 1.3275, z),
                    0.018, steel)
    # Half panels close the guardrail at each modular end. The next span
    # supplies the matching half, avoiding an open 0.5 m gap at every seam.
    for end in (-1, 1):
        y = end * 5.875
        box(f"glazed_seam_half_{side}_{end}", (x, y, 0.91),
            (0.032, 0.225, 0.43), glass, 0.015)
        for z in (0.59, 1.23):
            rod(f"seam_half_bound_{side}_{end}_{z}",
                (x, end * 5.76, z), (x, end * 6.0, z),
                0.018, steel)
    wave_points = []
    for i in range(97):
        y = -6 + i * 0.125
        z = 1.42 + 0.058 * math.sin((y + 6) * math.tau / 6)
        wave_points.append((x, y, z))
    curve_line(f"continuous_wave_top_rail_{side}", wave_points, 0.051, jade)
    curve_line(f"continuous_lower_rail_{side}",
               [(x, -6 + i * 0.25, 0.56) for i in range(49)],
               0.025, steel)

# Braced concrete piers carry the deck over water. Every 12 m module has two
# supports, spaced to avoid a fake floating slab when seen in an atlas view.
for y in (-3.0, 3.0):
    for x in (-1.55, 1.55):
        cylinder(f"tapered_bridge_pier_{x}_{y}", (x, y, -1.39),
                 0.29, 2.11, ivory_shade, 20)
        cylinder(f"pier_waterline_band_{x}_{y}", (x, y, -1.74),
                 0.31, 0.13, jade_dark, 20)
        cylinder(f"pier_head_cap_{x}_{y}", (x, y, -0.40),
                 0.36, 0.15, ivory, 20)
    rod(f"pier_underside_crossbrace_{y}", (-1.55, y, -0.97),
        (1.55, y, -0.97), 0.10, jade_dark)
    for side in (-1, 1):
        rod(f"pier_diagonal_brace_{side}_{y}",
            (side * 1.55, y, -1.27),
            (side * 0.65, y, -0.49), 0.075, jade)

# Twin lanterns are visible from the zoomed-out district view, but sit beyond
# the pedestrian line. Their low, hooded shape belongs to the ferry-side kit.
for side, x in (("left", -2.27), ("right", 2.27)):
    for y in (-3.03, 3.03):
        rod(f"coastal_lamp_post_{side}_{y}", (x, y, 0.17),
            (x, y, 2.08), 0.055, jade_dark, 14)
        box(f"coastal_lamp_bracket_{side}_{y}",
            (x + (-0.105 if x < 0 else 0.105), y, 2.09),
            (0.26, 0.115, 0.055), brass, 0.019)
        sphere(f"coastal_lamp_globe_{side}_{y}",
               (x, y, 2.17), (0.15, 0.15, 0.19), lamp)
        cylinder(f"coastal_lamp_hat_{side}_{y}",
                 (x, y, 2.36), 0.20, 0.09, jade, 18)

# Hanging terracotta pots and small readable leaf clusters bring the city
# path close to people. They sit outside the rail, preserving clearance.
for side, x in (("left", -2.51), ("right", 2.51)):
    for y in (-1.45, 1.45):
        box(f"planter_rail_bracket_{side}_{y}", (x, y, 1.16),
            (0.27, 0.42, 0.045), jade_dark, 0.015)
        cylinder(f"hanging_pot_{side}_{y}", (x, y, 1.31),
                 0.20, 0.25, terracotta, 18)
        cylinder(f"pot_lip_{side}_{y}", (x, y, 1.45),
                 0.23, 0.05, terracotta, 18)
        for i in range(6):
            angle = i * math.tau / 6
            lx = x + 0.11 * math.cos(angle)
            ly = y + 0.11 * math.sin(angle)
            obj = sphere(f"salt_leaf_{side}_{y}_{i}",
                         (lx, ly, 1.57 + 0.035 * (i % 2)),
                         (0.105, 0.058, 0.18),
                         leaf_bright if i % 3 == 0 else leaf, 12, 8)
            obj.rotation_euler.z = angle

# Marine safety rings are bolted onto the outer rail. The spacing is 12 m,
# matching the module pitch, so they do not clutter a long water crossing.
for side, x in (("left", -2.32), ("right", 2.32)):
    bpy.ops.mesh.primitive_torus_add(major_segments=28, minor_segments=8,
                                     location=(x, 0, 0.90), major_radius=0.18,
                                     minor_radius=0.052)
    torus = bpy.context.object
    torus.name = f"rescue_ring_{side}"
    torus.rotation_euler.y = math.pi / 2
    torus.data.materials.append(ivory)
    for dz in (-0.17, 0.17):
        box(f"rescue_ring_coral_{side}_{dz}", (x, 0, 0.90 + dz),
            (0.07, 0.11, 0.075), terracotta, 0.024)

# Four compliant water fenders hang beneath the visible deck edge, adding
# another material response without affecting walking collision.
for x in (-2.37, 2.37):
    for y in (-4.55, 4.55):
        box(f"rubber_wave_fender_{x}_{y}", (x, y, -0.41),
            (0.13, 0.65, 0.35), rubber, 0.065)

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "baywalk_bridge_span.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "baywalk_bridge_span.glb"),
                          export_format="GLB")

# Isolated preview water and lighting are excluded from the GLB and Blend.
water = material("PREVIEW_ONLY_WATER", "#9FC8C5", 0.46)
box("PREVIEW_ONLY_WATER_PLANE", (0, 0, -1.83),
    (9.5, 15.5, 0.04), water, 0)
world = bpy.data.worlds[0]
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.78, 0.85, 0.83, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.53
bpy.ops.object.light_add(type="AREA", location=(-5.5, -7, 9))
bpy.context.object.data.energy = 1450
bpy.context.object.data.size = 6
bpy.ops.object.light_add(type="AREA", location=(5, 7, 7))
bpy.context.object.data.energy = 570
bpy.context.object.data.size = 5
bpy.ops.object.camera_add(location=(9.5, -13.5, 10.2))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, -0.24)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 16.9
bpy.context.scene.camera = camera
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1200
bpy.context.scene.render.resolution_y = 1180
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = "PNG"
bpy.context.scene.render.filepath = str(OUT / "baywalk_bridge_span_preview.png")
bpy.ops.render.render(write_still=True)
print("ART_ASSET_READY:" + str(OUT / "baywalk_bridge_span.glb"))
