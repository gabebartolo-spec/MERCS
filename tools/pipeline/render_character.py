"""Render one body in its rest pose from the 8 fixed facings, at 4x, to PNG with alpha.

Run headless (Blender 5.2; no add-ons needed, the body .blend carries the mesh and rig):
  blender -b --factory-startup -P tools/pipeline/render_character.py -- --body average_m --out <dir>

The figure proportion and rest stance come from proportions.json (the director's pick): pose-bone
scales and aims only (no bone is added or renamed), then the figure is refitted to the reference
height. --pass normal writes camera-space normals instead of colour (OpenGL: R = screen right,
G = screen up, B = toward camera, encoded n * 0.5 + 0.5); a sheet ships both passes.
Sample options: --camera <json> swaps in another camera rig file; --proportions <json> --variant
<name> picks another proportion file or variant (tools/pipeline/samples/).

Writes <out>/facing_<k>_<name>.png (frame_px * render_scale square, RGBA 8-bit) for each facing
and <out>/render_meta.json (input and output hashes, Blender version). Camera and light rigs come
from camera_rig.json and light_rig.json; nothing visual is set in this file. No Mixamo clips yet
(they wait on the director's account sign-in), so the pose is the frozen rig's rest pose.
Clips: --clip <Mixamo FBX> --frames N retargets one loop onto the body, applies the body's "gait" block
(bodies.json: arm adduction, swing amplitudes per bone, hip sway and bounce, cadence) and the posture lean,
and writes facing_<k>_<name>_f<jj>.png per facing and frame; render_meta.json gains a "clip" block (fps at
the real timing, ground_speed_mps, ground offset, measured foot slide). --kit-keep keeps only some kit pieces.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

PIPELINE = Path(__file__).resolve().parent
CAMERA_FILE = PIPELINE / "camera_rig.json"
LIGHT_FILE = PIPELINE / "light_rig.json"
PROPORTIONS_FILE = PIPELINE / "proportions.json"
BODIES_DIR = PIPELINE / "bodies"
SRGB_LINEAR_BREAK = 0.04045
NORMAL_VIEW_TRANSFORM = "Raw"  # normals are data: written as computed, never tone-mapped


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--body", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--facings", default="all", help="'all' or comma-separated facing indices")
    p.add_argument("--camera", default=str(CAMERA_FILE), help="camera rig json (default: the committed rig)")
    p.add_argument("--proportions", default=str(PROPORTIONS_FILE), help="proportion variants json")
    p.add_argument("--variant", default="", help="variant in --proportions (default: its 'default')")
    p.add_argument("--kit", default="", help="stage gear kit json (tools/pipeline/kits/); blockout primitives on bones")
    p.add_argument("--kit-keep", default="", help="comma-separated kit piece name prefixes to keep (default all)")
    p.add_argument("--pass", dest="render_pass", choices=("color", "normal", "parts"), default="color")
    p.add_argument("--clip", default="", help="Mixamo FBX (vault) to retarget and sample; empty = rest pose")
    p.add_argument("--frames", type=int, default=8, help="frames sampled from one loop of --clip")
    p.add_argument("--loop-window", default="", help="LO-HI source frames: sample the best-matching sub-loop")
    return p.parse_args(argv)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rel_path(path: Path) -> str:
    try:
        return path.relative_to(PIPELINE.parents[1]).as_posix()
    except ValueError:
        return path.name


def srgb_to_linear(hex_colour: str) -> tuple[float, float, float, float]:
    out = []
    for i in (1, 3, 5):
        c = int(hex_colour[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= SRGB_LINEAR_BREAK else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


def px_per_m(cam: dict) -> float:
    """1x pixels per metre on the image plane: camera_rig.json's px_per_m_1x when it pins the scale to the
    world camera, else the older rule char_height_px / (reference_height_m * cos(pitch_deg))."""
    if "px_per_m_1x" in cam:
        return cam["px_per_m_1x"]
    return cam["char_height_px"] / (cam["reference_height_m"] * math.cos(math.radians(cam["pitch_deg"])))


def setup_render(cam: dict, light: dict) -> None:
    scene = bpy.context.scene
    r = scene.render
    r.engine = light["engine"]
    r.resolution_x = r.resolution_y = cam["frame_px"] * cam["render_scale"]
    r.resolution_percentage = 100
    r.pixel_aspect_x = r.pixel_aspect_y = 1.0
    r.film_transparent = True
    r.filter_size = light["filter_size_px"]
    r.use_compositing = False
    r.use_sequencer = False
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    for attr in dir(r):  # no date, time or file-name text chunks in the PNG
        if attr.startswith("use_stamp"):
            try:
                setattr(r, attr, False)
            except (AttributeError, TypeError):
                pass
    scene.eevee.taa_render_samples = light["render_samples"]
    scene.view_settings.view_transform = light["view_transform"]
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    world = scene.world or bpy.data.worlds.new("mercs_world")
    scene.world = world
    world.color = light["world_color"]
    if world.node_tree:
        bg = world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs["Color"].default_value = (*light["world_color"], 1.0)
            bg.inputs["Strength"].default_value = light["world_strength"]


def camera_rotation(cam: dict) -> Euler:
    """A camera looks down its local -Z; X = 90 deg looks along +Y; tilting down gives 90 - pitch."""
    return Euler((math.radians(90.0 - cam["pitch_deg"]), 0.0, 0.0), "XYZ")


def add_camera(cam: dict) -> bpy.types.Object:
    data = bpy.data.cameras.new("mercs_sprite_cam")
    data.type = "ORTHO"
    ppm = px_per_m(cam)
    data.ortho_scale = cam["frame_px"] / ppm
    data.sensor_fit = "AUTO"
    data.clip_start = cam["clip_start_m"]
    data.clip_end = cam["clip_end_m"]
    obj = bpy.data.objects.new("mercs_sprite_cam", data)
    bpy.context.scene.collection.objects.link(obj)
    rot = camera_rotation(cam).to_matrix()
    view, up, right = rot @ Vector((0, 0, -1)), rot @ Vector((0, 1, 0)), rot @ Vector((1, 0, 0))
    # Aim so the world origin (feet centre) lands on pivot_px: offsets in 1x pixels from centre.
    dx = (cam["pivot_px"][0] - cam["frame_px"] / 2) / ppm
    dy = (cam["pivot_px"][1] - cam["frame_px"] / 2) / ppm
    target = -right * dx + up * dy
    obj.location = target - view * cam["camera_distance_m"]
    obj.rotation_euler = camera_rotation(cam)
    bpy.context.scene.camera = obj
    return obj


def add_lights(light: dict) -> None:
    """Suns placed relative to the camera: it looks along +Y in plan, so camera-left is -X."""
    for spec in light["lights"]:
        az, el = math.radians(spec["azimuth_deg"]), math.radians(spec["elevation_deg"])
        to_light = Vector((-math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
        data = bpy.data.lights.new(f"mercs_{spec['name']}", type="SUN")
        data.energy = spec["energy"]
        data.color = spec["color"]
        data.use_shadow = False
        obj = bpy.data.objects.new(f"mercs_{spec['name']}", data)
        obj.rotation_euler = to_light.to_track_quat("Z", "Y").to_euler()
        bpy.context.scene.collection.objects.link(obj)


def apply_material(spec: dict) -> None:
    mat = bpy.data.materials.new(spec["name"])
    if mat.node_tree is None:
        mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = srgb_to_linear(spec["base_color_srgb"])
    bsdf.inputs["Roughness"].default_value = spec["roughness"]
    bsdf.inputs["Specular IOR Level"].default_value = spec["specular"]
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.data.materials.clear()
            obj.data.materials.append(mat)


def apply_normal_pass() -> None:
    """Emit the shading normal in camera space, encoded n * 0.5 + 0.5, with no colour transform.

    Blender's shader camera space has X = screen right, Y = screen up and Z = away from the viewer
    (measured: a body facing the camera encoded blue < 0.5), so Z is negated to give the OpenGL
    convention the stage reads (B = toward camera).
    """
    mat = bpy.data.materials.new("mercs_normal_pass")
    if mat.node_tree is None:
        mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    geo = nodes.new("ShaderNodeNewGeometry")
    xform = nodes.new("ShaderNodeVectorTransform")
    xform.vector_type, xform.convert_from, xform.convert_to = "NORMAL", "WORLD", "CAMERA"
    enc = nodes.new("ShaderNodeVectorMath")
    enc.operation = "MULTIPLY_ADD"
    enc.inputs[1].default_value = (0.5, 0.5, -0.5)
    enc.inputs[2].default_value = (0.5, 0.5, 0.5)
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = 1.0
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(geo.outputs["Normal"], xform.inputs["Vector"])
    links.new(xform.outputs["Vector"], enc.inputs[0])
    links.new(enc.outputs["Vector"], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.data.materials.clear()
            obj.data.materials.append(mat)
    scene = bpy.context.scene
    scene.view_settings.view_transform = NORMAL_VIEW_TRANSFORM
    scene.render.dither_intensity = 0.0


PART_GROUPS = {  # flat emission colour -> bones whose summed vertex weight marks the part
    (1.0, 0.0, 0.0): ("mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand"),
    (0.0, 1.0, 0.0): ("mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand"),
}
PART_BODY = (0.0, 0.0, 1.0)
PART_WEIGHT = 0.5
PART_ROOT = (1.0, 1.0, 1.0)  # the arm's root (shoulder cap): neither arm nor body, so no line either side
PART_ROOT_CLEAR_M = 0.10  # arm vertices this close to the shoulder joint are root


def apply_parts_pass() -> None:
    """Flat colour per body part (left arm red, right arm green, the rest blue) for the pixel post's
    inner lines (06 section 3: a line only where the silhouette would merge). Finger and hand
    groups count towards their arm by name prefix. The shoulder cap (arm vertices within
    PART_ROOT_CLEAR_M of the arm's root joint, at rest) is labelled root (white): lines are drawn only
    where an arm meets the body, never at the root, which the round-3 "body" label turned into a
    tick across the arm. Raw view, no dither: labels, not colour."""
    mat = bpy.data.materials.new("mercs_parts_pass")
    if mat.node_tree is None:
        mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "mercs_parts"
    emit = nodes.new("ShaderNodeEmission")
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(attr.outputs["Color"], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        layer = obj.data.color_attributes.new("mercs_parts", "FLOAT_COLOR", "POINT")
        if obj.parent_type == "BONE":  # rigid gear or feature: one label, from the bone it rides on
            colour = next((rgb for rgb, bones in PART_GROUPS.items() if obj.parent_bone.startswith(bones)), PART_BODY)
            for v in obj.data.vertices:
                layer.data[v.index].color = (*colour, 1.0)
            obj.data.materials.clear()
            obj.data.materials.append(mat)
            continue
        index_of = {g.index: g.name for g in obj.vertex_groups}
        rig = obj.parent
        roots = {rgb: rig.matrix_world @ rig.data.bones[bones[0]].head_local for rgb, bones in PART_GROUPS.items()}
        for v in obj.data.vertices:
            colour = PART_BODY
            where = obj.matrix_world @ v.co
            for rgb, bones in PART_GROUPS.items():
                w = sum(g.weight for g in v.groups if index_of[g.group].startswith(bones))
                if w >= PART_WEIGHT:
                    colour = rgb if (where - roots[rgb]).length >= PART_ROOT_CLEAR_M else PART_ROOT
            layer.data[v.index].color = (*colour, 1.0)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    scene = bpy.context.scene
    scene.view_settings.view_transform = NORMAL_VIEW_TRANSFORM
    scene.render.dither_intensity = 0.0


def figure_extent_z(rig: bpy.types.Object) -> tuple[float, float]:
    """World z range of the deformed body (shape keys and pose evaluated, never base vertices)."""
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    lo, hi = math.inf, -math.inf
    for obj in rig.children:
        if obj.type != "MESH" or obj.name.startswith(KIT_PREFIX):
            continue
        ev = obj.evaluated_get(deps)
        mesh = ev.to_mesh()
        mw = ev.matrix_world
        for v in mesh.vertices:
            z = (mw @ v.co).z
            lo, hi = min(lo, z), max(hi, z)
        ev.to_mesh_clear()
    return lo, hi


def aim_bones(rig: bpy.types.Object, targets: dict) -> None:
    """Turn each named bone, in order, about its head so it points along a world direction.

    Works in posed space, so a child listed after its parent follows the parent's new pose.
    """
    world_inv = rig.matrix_world.inverted()
    for bone, direction in targets.items():
        pb = rig.pose.bones.get(bone)
        if pb is None:
            raise SystemExit(f"pose: no bone {bone}")
        bpy.context.view_layer.update()
        m = rig.matrix_world @ pb.matrix
        current = (m.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
        turn = current.rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()
        head = Matrix.Translation(m.translation)
        pb.matrix = world_inv @ (head @ turn @ head.inverted() @ m)
    bpy.context.view_layer.update()


def group_centroid(rig: bpy.types.Object, group: str, min_weight: float) -> Vector:
    """World centroid of the deformed vertices weighted to a vertex group (the head mesh, say)."""
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    total, n = Vector((0.0, 0.0, 0.0)), 0
    for obj in rig.children:
        if obj.type != "MESH" or group not in obj.vertex_groups:
            continue
        gi = obj.vertex_groups[group].index
        ev = obj.evaluated_get(deps)
        mesh = ev.to_mesh()
        for v in mesh.vertices:
            if any(g.group == gi and g.weight >= min_weight for g in v.groups):
                total += ev.matrix_world @ v.co
                n += 1
        ev.to_mesh_clear()
    if not n:
        raise SystemExit(f"recentre: no vertices weighted to {group}")
    return total / n


def twist_bones(rig: bpy.types.Object, twists: dict) -> None:
    """Roll each named bone about its own length by degrees (pose only), e.g. palms toward the thighs."""
    world_inv = rig.matrix_world.inverted()
    for bone, degrees in twists.items():
        bpy.context.view_layer.update()
        pb = rig.pose.bones[bone]
        m = rig.matrix_world @ pb.matrix
        axis = (m.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
        turn = Matrix.Rotation(math.radians(degrees), 4, axis)
        head = Matrix.Translation(m.translation)
        pb.matrix = world_inv @ (head @ turn @ head.inverted() @ m)
    bpy.context.view_layer.update()


def recentre_bones(rig: bpy.types.Object, specs: dict) -> None:
    """Shift a bone (pose only) so its mesh centroid's horizontal offset from another bone's head
    shrinks to keep_offset of what it was, then lift it.

    Scaling the head 1.8x about its joint multiplies the face's natural forward offset by 1.8;
    keep_offset 1/1.8 restores the natural offset (0 would sit the head's centre on the spine,
    which pushes it behind the neck: measured side-on, 2026-10-09). Metres, before the refit.
    """
    world_inv = rig.matrix_world.inverted()
    for bone, spec in specs.items():
        pb = rig.pose.bones[bone]
        centre = group_centroid(rig, bone, spec["min_weight"])
        anchor = rig.matrix_world @ rig.pose.bones[spec["over"]].head
        pull = 1.0 - spec["keep_offset"]
        delta = Vector(((anchor.x - centre.x) * pull, (anchor.y - centre.y) * pull, spec["lift_m"]))
        pb.matrix = world_inv @ (Matrix.Translation(delta) @ (rig.matrix_world @ pb.matrix))
    bpy.context.view_layer.update()


def lean_bones(rig: bpy.types.Object, degrees: dict) -> None:
    """A merc's posture (bodies.json "posture_lean_deg"): turn each bone, in order, about the world X
    axis through its head; positive leans forward (the body faces -Y). Runs before the arm aims, so
    the arms still hang to their stance directions from the leaned shoulders."""
    world_inv = rig.matrix_world.inverted()
    for bone, deg in degrees.items():
        bpy.context.view_layer.update()
        pb = rig.pose.bones[bone]
        m = rig.matrix_world @ pb.matrix
        turn = Matrix.Rotation(math.radians(deg), 4, Vector((1.0, 0.0, 0.0)))
        head = Matrix.Translation(m.translation)
        pb.matrix = world_inv @ (head @ turn @ head.inverted() @ m)
    bpy.context.view_layer.update()


def apply_proportions(rig: bpy.types.Object, path: str, name: str, height_m: float, posture: dict) -> dict:
    """Pose and scale bones for a sample variant, then refit the figure to height_m with feet on z = 0."""
    cfg = json.loads(Path(path).read_text(encoding="utf-8"))
    name = name or cfg["default"]
    spec = cfg["variants"][name]
    scales = spec["bone_scale"]
    aim = {**cfg.get("pose", {}).get("bone_direction", {}), **spec.get("bone_direction", {})}
    if not scales and not aim and not posture and not cfg.get("pose", {}).get("bone_twist_deg"):
        return {"variant": name, "rig_scale": 1.0, "height_m": None}
    rig.data.pose_position = "POSE"
    lean_bones(rig, posture)
    aim_bones(rig, aim)
    twist_bones(rig, {**cfg.get("pose", {}).get("bone_twist_deg", {}), **spec.get("bone_twist_deg", {})})
    for bone, factor in scales.items():
        pb = rig.pose.bones.get(bone)
        if pb is None:
            raise SystemExit(f"variant {name}: no bone {bone}; bones are never added or renamed")
        pb.scale = (factor, factor, factor)
    recentre_bones(rig, spec.get("recentre", {}))
    lo, hi = figure_extent_z(rig)
    s = height_m / (hi - lo)
    rig.scale = (s, s, s)
    lo, hi = figure_extent_z(rig)
    rig.location.z -= lo
    lo, hi = figure_extent_z(rig)
    print(f"PROPORTION {name} rig_scale {s:.4f} height {hi - lo:.4f} feet {lo:.4f}")
    return {"variant": name, "rig_scale": round(s, 6), "height_m": round(hi - lo, 4)}


KIT_PREFIX = "kit_"
KIT_SHAPES = {"sphere": lambda: bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.5),
              "box": lambda: bpy.ops.mesh.primitive_cube_add(size=1.0),
              "cylinder": lambda: bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.5, depth=1.0)}


def bone_point(rig: bpy.types.Object, bone: str, at: str) -> Vector:
    pb = rig.pose.bones[bone]
    head, tail = rig.matrix_world @ pb.head, rig.matrix_world @ pb.tail
    return {"head": head, "tail": tail, "mid": (head + tail) / 2}[at]


def euler_matrix(degrees) -> Matrix:
    return Euler([math.radians(a) for a in degrees], "XYZ").to_matrix().to_4x4()


def add_kit(rig: bpy.types.Object, path: str, keep: tuple[str, ...] = ()) -> dict:
    """Stage gear blockout (route A): primitives sized in metres and placed on the posed figure,
    each parented to a bone so clips carry it. A piece sits at its bone's posed head, tail or mid
    point plus offset_m (world axes: +X the body's left, -Y its front, +Z up). "along_bone" turns
    the piece's Z axis down the bone (vambraces, greaves) and makes size[2] a share of the bone's
    length; otherwise rot_deg is a world XYZ rotation. A "cone" piece tapers from size[0] to
    top_size. Blockouts are silhouette studies; shipped gear replaces them piece by piece."""
    cfg = json.loads(Path(path).read_text(encoding="utf-8"))
    bpy.context.view_layer.update()
    groups = {}
    for gname, g in cfg.get("groups", {}).items():
        groups[gname] = (Matrix.Translation(bone_point(rig, g["bone"], g.get("at", "head")) + Vector(g.get("offset_m", (0, 0, 0))))
                         @ euler_matrix(g.get("rot_deg", (0.0, 0.0, 0.0))))
    pieces = {n: p for n, p in cfg["pieces"].items() if not keep or n.startswith(keep)}
    for name, piece in pieces.items():
        pb = rig.pose.bones[piece["bone"]]
        head = rig.matrix_world @ pb.head
        tail = rig.matrix_world @ pb.tail
        anchor = {"head": head, "tail": tail, "mid": (head + tail) / 2}[piece.get("at", "head")]
        size = Vector(piece["size"])
        if piece["shape"] == "cone":
            bpy.ops.mesh.primitive_cone_add(vertices=piece.get("sides", 12), radius1=0.5,
                                            radius2=0.5 * piece.get("top_size", 0.0) / size[0], depth=1.0)
        else:
            KIT_SHAPES[piece["shape"]]()
        obj = bpy.context.active_object
        obj.name = f"{KIT_PREFIX}{name}"
        if piece.get("along_bone"):
            axis = (tail - head)
            size[2] *= axis.length
            rot = Vector((0.0, 0.0, 1.0)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
        else:
            rot = Euler([math.radians(a) for a in piece.get("rot_deg", (0.0, 0.0, 0.0))], "XYZ").to_matrix().to_4x4()
        scale = Matrix.Diagonal((*size, 1.0))
        if "group" in piece:  # offset and rotation in the group's frame (an axe is one rigid object)
            obj.matrix_world = groups[piece["group"]] @ Matrix.Translation(Vector(piece.get("offset_m", (0, 0, 0)))) @ rot @ scale
        else:
            obj.matrix_world = Matrix.Translation(anchor + Vector(piece.get("offset_m", (0.0, 0.0, 0.0)))) @ rot @ scale
        bpy.context.view_layer.update()
        world = obj.matrix_world.copy()
        obj.parent = rig
        obj.parent_type = "BONE"
        obj.parent_bone = piece["bone"]
        bpy.context.view_layer.update()
        obj.matrix_world = world
    bpy.context.view_layer.update()
    return {"file": rel_path(Path(path).resolve()), "sha256": sha256(Path(path)), "pieces": len(pieces),
            "kept": list(keep)}


CONTACT_M = 0.02  # a foot within this of its lowest height in the loop counts as planted (ground speed)
HIPS = "mixamorig:Hips"
DIRECTION_BONES = tuple(f"mixamorig:{side}{part}" for side in ("Left", "Right")
                        for part in ("Arm", "ForeArm", "Hand",  # Hand also prefixes the finger bones
                                     "UpLeg", "Leg", "Foot", "ToeBase"))  # limbs: rest poses differ
SHOULDERS = ("mixamorig:LeftArm", "mixamorig:RightArm")
LOOP_STEP = 3  # source frames between candidate loop windows
HIP_WEIGHT = 10.0  # radians of pose difference per metre of hip travel when matching a loop's ends
FEET = ("mixamorig:LeftToeBase", "mixamorig:RightToeBase")
DENSE = 4  # retargeted poses per sampled frame: ground speed and foot slide are measured on the dense loop


def import_clip(path: str) -> tuple[bpy.types.Object, int, int, float]:
    """Import a Mixamo FBX (skin off) and return its armature, loop frame range and source fps."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    src = next(o for o in bpy.data.objects if o not in before and o.type == "ARMATURE")
    f0, f1 = (int(v) for v in src.animation_data.action.frame_range)
    return src, f0, f1, bpy.context.scene.render.fps / bpy.context.scene.render.fps_base


def bone_order(rig: bpy.types.Object) -> list[str]:
    """Bone names parents-first, so a retargeted child follows its already-posed parent."""
    order: list[str] = []
    stack = [b for b in rig.data.bones if b.parent is None]
    while stack:
        b = stack.pop(0)
        order.append(b.name)
        stack = list(b.children) + stack
    return order


def clip_offsets(src: bpy.types.Object, dst: bpy.types.Object, names: list[str]) -> dict:
    """Per bone, the rotation that maps a source world orientation onto ours.

    Limb chains (DIRECTION_BONES): the rest poses differ (the X Bot's arms rest level in a T-pose, ours hang
    in an A-pose), so the rest direction is aligned to the source's first and the bone copies the source's
    world direction. Every other bone keeps its own rest and takes the source's rotation delta from rest:
    copying direction on the clavicles lifted the far shoulder to ear height (Lead QC 2026-10-09)."""
    def rest(arm, n):
        return (arm.matrix_world @ arm.data.bones[n].matrix_local).to_quaternion()

    def direction(arm, n):
        b = arm.data.bones[n]
        return (arm.matrix_world.to_3x3() @ (b.tail_local - b.head_local)).normalized()

    def align(n):
        if n.startswith(DIRECTION_BONES):
            return direction(dst, n).rotation_difference(direction(src, n))
        return Quaternion()

    return {n: rest(src, n).inverted() @ (align(n) @ rest(dst, n)) for n in names}


def prefixed(name: str, table: dict, default):
    """The value for a bone: its own entry, or the longest matching prefix (fingers follow the hand)."""
    best = max((k for k in table if name.startswith(k)), key=len, default=None)
    return table[best] if best else default


def adduction(adduct_deg: dict) -> dict:
    """World rotations, about the body's forward axis at each joint, that bring each arm part toward the body.
    Left limbs sit on +X, so +angle about Y turns a hanging left arm inward and -angle the right; a negative
    angle holds the arm out (a bulky torso)."""
    out = {}
    for part, degrees in adduct_deg.items():
        for side, sign in (("Left", 1.0), ("Right", -1.0)):
            out[f"mixamorig:{side}{part}"] = Quaternion(Vector((0.0, 1.0, 0.0)), math.radians(sign * degrees))
    return out


def lean_angles(rig: bpy.types.Object, names: list[str], posture: dict) -> dict:
    """Per bone, the posture lean it carries (radians about world X): its own plus its ancestors'. Limb chains
    copy the clip's world direction and carry none, as the rest stance re-aims the arms after the lean."""
    out = {}
    for n in names:
        if n.startswith(DIRECTION_BONES):
            out[n] = 0.0
            continue
        b, total = rig.data.bones[n], 0.0
        while b is not None:
            total += posture.get(b.name, 0.0)
            b = b.parent
        out[n] = math.radians(total)
    return out


def retarget_frame(src: bpy.types.Object, dst: bpy.types.Object, names: list[str], offsets: dict,
                   hips_at, adduct: dict, lean: dict) -> None:
    """Pose dst like src at the current frame: world orientations copied through the offsets, parents first,
    with the merc's posture lean on the torso chain; the hips go where hips_at puts the source's hips (scaled
    and reshaped by the gait), every other bone keeps its head."""
    world_inv = dst.matrix_world.inverted()
    across = Vector((1.0, 0.0, 0.0))
    for n in names:
        bpy.context.view_layer.update()
        sp = src.matrix_world @ src.pose.bones[n].matrix
        pb = dst.pose.bones[n]
        pos = hips_at(sp.translation) if n == HIPS else (dst.matrix_world @ pb.matrix).translation
        q = Quaternion(across, lean[n]) @ prefixed(n, adduct, Quaternion()) @ sp.to_quaternion() @ offsets[n]
        pb.matrix = world_inv @ (Matrix.Translation(pos) @ q.to_matrix().to_4x4())
    bpy.context.view_layer.update()


def set_time(t: float) -> None:
    bpy.context.scene.frame_set(int(math.floor(t)), subframe=t - math.floor(t))


def find_loop_window(src: bpy.types.Object, f0: int, f1: int, span: tuple[int, int]) -> tuple[int, int]:
    """The sub-range [s, s + L] (L within span, in source frames) whose end pose best matches its start pose:
    a long clip (Mixamo's standing idle is 8 s) sampled at a few frames would hold each pose for seconds."""
    rot, hips = {}, {}
    for f in range(f0, f1 + 1):
        set_time(f)
        bpy.context.view_layer.update()
        rot[f] = [(src.matrix_world @ pb.matrix).to_quaternion() for pb in src.pose.bones]
        hips[f] = (src.matrix_world @ src.pose.bones[HIPS].matrix).translation.copy()
    best, best_d = (f0, min(f1, f0 + span[1])), math.inf
    for length in range(span[0], span[1] + 1, LOOP_STEP):
        for start in range(f0, f1 - length + 1, LOOP_STEP):
            end = start + length
            d = sum(a.rotation_difference(b).angle for a, b in zip(rot[start], rot[end]))
            d += HIP_WEIGHT * (hips[start] - hips[end]).length
            if d < best_d:
                best, best_d = (start, end), d
    print(f"LOOP window {best} distance {best_d:.4f}")
    return best


def scale_swing(poses: list[dict], amplitude: dict) -> None:
    """The gait's character: each listed bone's rotation (pose space, about its own mean over the loop) is
    scaled by its factor; above 1 swings wider, below 1 holds steadier. Children follow, as a keyed layer."""
    for name in poses[0]:
        k = prefixed(name, amplitude, 1.0)
        if k == 1.0:
            continue
        qs = [p[name].to_quaternion() for p in poses]
        ref = Vector(qs[0])
        mean = Vector((0.0, 0.0, 0.0, 0.0))
        for q in qs:
            mean += Vector(q) if Vector(q).dot(ref) >= 0 else -Vector(q)
        m = Quaternion(mean).normalized()  # a 4D Vector.normalized() scales by its xyz length only
        for p, q in zip(poses, qs):
            axis, angle = (m.inverted() @ q).to_axis_angle()
            if angle > math.pi:
                angle -= 2 * math.pi
            p[name] = Matrix.Translation(p[name].to_translation()) @ (m @ Quaternion(axis, angle * k)).to_matrix().to_4x4()


def apply_pose(rig: bpy.types.Object, pose: dict) -> None:
    for name, basis in pose.items():
        rig.pose.bones[name].matrix_basis = basis
    bpy.context.view_layer.update()


def foot_slide(tracks: dict, speed: float, dt: float) -> float:
    """Worst planted-foot drift in metres with the body travelling at speed: over each contact run the foot's
    ground position (its in-place y minus the distance walked) should stand still."""
    worst = 0.0
    for pts in tracks.values():
        low = min(q.z for q in pts)
        run: list[float] = []
        for i, q in enumerate(pts):
            if q.z <= low + CONTACT_M:
                run.append(q.y - speed * dt * i)
            elif run:
                worst, run = max(worst, max(run) - min(run)), []
        if run:
            worst = max(worst, max(run) - min(run))
    return worst


LEGS = tuple((f"mixamorig:{s}UpLeg", f"mixamorig:{s}Leg", f"mixamorig:{s}Foot", f"mixamorig:{s}ToeBase")
             for s in ("Left", "Right"))
REACH = 0.999  # a leg straightens to at most this share of its length (no snap through full extension)


def world_of(rig: bpy.types.Object, name: str) -> Matrix:
    return rig.matrix_world @ rig.pose.bones[name].matrix


def set_world(rig: bpy.types.Object, name: str, world: Matrix) -> None:
    rig.pose.bones[name].matrix = rig.matrix_world.inverted() @ world
    bpy.context.view_layer.update()


def leg_targets(rig: bpy.types.Object) -> list:
    """Per leg, what the clip put down: hip, knee and ankle positions and the foot and toe world matrices."""
    return [(world_of(rig, leg).translation.copy(), world_of(rig, shin).translation.copy(),
             world_of(rig, foot).translation.copy(), world_of(rig, foot).copy(), world_of(rig, toe).copy())
            for leg, shin, foot, toe in LEGS]


def aim_world(rig: bpy.types.Object, name: str, head: Vector, toward: Vector) -> None:
    """Place a bone's head at head and turn it (shortest turn, so its roll is kept) to point at toward."""
    m = world_of(rig, name)
    current = (m.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
    turn = current.rotation_difference((toward - head).normalized())
    set_world(rig, name, Matrix.Translation(head) @ (turn @ m.to_quaternion()).to_matrix().to_4x4())


def solve_legs(rig: bpy.types.Object, targets: list) -> None:
    """Two-bone IK: after the gait moves the hips, each thigh and shin are re-aimed so the ankle lands where
    the clip put it, the knee bending in the plane the clip's knee bent in; foot and toe keep the clip's
    world orientation. Hip sway, bounce and drop therefore never slide a planted foot."""
    for (leg, shin, foot, toe), (hip0, knee0, ankle, foot_m, toe_m) in zip(LEGS, targets):
        hip = world_of(rig, leg).translation.copy()
        l1, l2 = (knee0 - hip0).length, (ankle - knee0).length
        to = ankle - hip
        d = min(to.length, REACH * (l1 + l2))
        u = to.normalized()
        bend = knee0 - hip0
        pole = bend - bend.project(u)
        v = pole.normalized()
        cos_a = max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)))
        knee = hip + l1 * (u * cos_a + v * math.sqrt(1.0 - cos_a * cos_a))
        aim_world(rig, leg, hip, knee)
        aim_world(rig, shin, world_of(rig, shin).translation.copy(), hip + u * d)
        for bone, m in ((foot, foot_m), (toe, toe_m)):
            set_world(rig, bone, Matrix.Translation(world_of(rig, bone).translation) @ m.to_quaternion().to_matrix().to_4x4())


def sample_clip(rig: bpy.types.Object, path: str, frames: int, window: str, gait: dict,
                posture: dict) -> tuple[list, dict]:
    """Retarget one loop of a clip onto rig (facing 0) through the merc's gait and return `frames` poses as
    bone matrix_basis copies, plus clip facts: fps at the real timing (times the gait's cadence), ground
    speed from the planted foot, the measured foot slide at that speed and the constant ground offset.

    The gait (bodies.json "gait") is a layer over the clip: swing_scale on torso and arms, then the hips
    move (sway, bounce, drop) and the legs are solved back onto the clip's own foot path (solve_legs)."""
    src, f0, f1, src_fps = import_clip(path)
    if window:
        lo, hi = (int(v) for v in window.split("-"))
        f0, f1 = find_loop_window(src, f0, f1, (lo, hi))
    stance = {pb.name: pb.matrix_basis.copy() for pb in rig.pose.bones}
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    names = [n for n in bone_order(rig) if n in src.data.bones]
    offsets = clip_offsets(src, rig, names)
    adduct = adduction(gait.get("arm_adduct_deg", {}))
    lean = lean_angles(rig, names, posture)
    ratio = ((rig.matrix_world @ rig.data.bones[HIPS].head_local).z
             / (src.matrix_world @ src.data.bones[HIPS].head_local).z)
    dense = frames * DENSE
    poses, targets, hips = [], [], []
    for i in range(dense):
        set_time(f0 + i * (f1 - f0) / dense)
        retarget_frame(src, rig, names, offsets, lambda p: p * ratio, adduct, lean)
        poses.append({pb.name: pb.matrix_basis.copy() for pb in rig.pose.bones})
        targets.append(leg_targets(rig))
        hips.append(world_of(rig, HIPS).translation.copy())
    for obj in [src, *src.children]:
        bpy.data.objects.remove(obj, do_unlink=True)
    scale_swing(poses, gait.get("swing_scale", {}))
    for pose in poses:  # a gripping hand keeps the stance's wrist angle, so a weapon does not flail
        for name in (n for n in pose if n.startswith(tuple(gait.get("hold_stance", ())))):
            pose[name] = Matrix.Translation(pose[name].to_translation()) @ stance[name].to_quaternion().to_matrix().to_4x4()
    mean = sum(hips, Vector()) / len(hips)
    sway, bounce = gait.get("hip_sway_scale", 1.0), gait.get("hip_bounce_scale", 1.0)
    drop = gait.get("hip_drop_m", 0.0)
    tracks: dict = {foot: [] for foot in FEET}
    lowest, rise = math.inf, -math.inf
    rest_z = {b: (rig.matrix_world @ rig.data.bones[b].head_local).z for b in SHOULDERS}
    for pose, target, h in zip(poses, targets, hips):
        apply_pose(rig, pose)
        d = h - mean
        at = mean + Vector((d.x * sway, d.y, d.z * bounce - drop))
        set_world(rig, HIPS, Matrix.Translation(at) @ world_of(rig, HIPS).to_quaternion().to_matrix().to_4x4())
        solve_legs(rig, target)
        pose.update({pb.name: pb.matrix_basis.copy() for pb in rig.pose.bones})
        for foot in FEET:
            tracks[foot].append(world_of(rig, foot).translation.copy())
        lowest = min(lowest, figure_extent_z(rig)[0])
        rise = max(rise, max(world_of(rig, b).translation.z - rest_z[b] for b in SHOULDERS))
    cadence = gait.get("cadence_scale", 1.0)
    dt = (f1 - f0) / src_fps / dense / cadence  # playback seconds between dense poses
    speeds = []
    for pts in tracks.values():
        low = min(q.z for q in pts)
        speeds += [(b.y - a.y) / dt for a, b in zip(pts, pts[1:]) if max(a.z, b.z) <= low + CONTACT_M]
    speeds.sort()
    speed = speeds[len(speeds) // 2] if speeds else 0.0
    rig.location.z -= lowest
    facts = {"clip": Path(path).name, "clip_sha256": sha256(Path(path)), "source_frames": [f0, f1],
             "source_fps": src_fps, "frames": frames,
             "fps": round(frames * src_fps * cadence / (f1 - f0), 4), "loop": True,
             "ground_speed_mps": round(abs(speed), 4), "ground_offset_m": round(-lowest, 4),
             "foot_slide_m": round(foot_slide(tracks, speed, dt), 4), "bones_matched": len(names),
             "max_shoulder_rise_m": round(rise, 4), "gait": gait}
    print("CLIP " + json.dumps(facts))
    return poses[::DENSE], facts


def body_spec(body: str) -> dict:
    return json.loads((BODIES_DIR / "bodies.json").read_text(encoding="utf-8"))["bodies"].get(body, {})


def body_height_m(body: str, cam: dict) -> float:
    """The body's own standing height (bodies.json): a merc body keeps its height on the shared
    px_per_m scale, so the orc stands taller on screen than average_m (camera reference height)."""
    return body_spec(body).get("height_m", cam["reference_height_m"])


def body_rig() -> bpy.types.Object:
    rigs = [o for o in bpy.data.objects if o.type == "ARMATURE" and o.parent is None]
    if len(rigs) != 1:
        raise SystemExit(f"expected one root armature, found {len(rigs)}")
    rig = rigs[0]
    rig.data.pose_position = "REST"
    if abs(rig.location.x) > 1e-6 or abs(rig.location.y) > 1e-6:
        raise SystemExit("rig root is not over the world origin; facings would orbit, not turn")
    return rig


def main() -> None:
    args = parse_args()
    camera_file = Path(args.camera).resolve()
    cam = json.loads(camera_file.read_text(encoding="utf-8"))
    light = json.loads(LIGHT_FILE.read_text(encoding="utf-8"))
    blend = BODIES_DIR / f"{args.body}.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    for obj in list(bpy.data.objects):
        if obj.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(obj, do_unlink=True)
    setup_render(cam, light)
    rig = body_rig()
    proportion = apply_proportions(rig, args.proportions, args.variant, body_height_m(args.body, cam),
                                   body_spec(args.body).get("posture_lean_deg", {}))
    keep = tuple(k for k in args.kit_keep.split(",") if k)
    kit = add_kit(rig, args.kit, keep) if args.kit else None
    poses, clip = (sample_clip(rig, args.clip, args.frames, args.loop_window, body_spec(args.body).get("gait", {}),
                               body_spec(args.body).get("posture_lean_deg", {}))
                   if args.clip else ([None], None))
    if args.render_pass == "normal":
        apply_normal_pass()
    elif args.render_pass == "parts":
        apply_parts_pass()
    else:
        apply_material(light["body_material"])
    add_camera(cam)
    add_lights(light)

    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    names = cam["facings"]["order"]
    count = cam["facings"]["count"]
    wanted = range(count) if args.facings == "all" else [int(k) for k in args.facings.split(",")]
    outputs = []
    for k in wanted:
        rig.rotation_mode = "XYZ"
        rig.rotation_euler = (0.0, 0.0, math.radians(k * cam["facings"]["step_deg"]))
        for j, pose in enumerate(poses):
            if pose is not None:
                apply_pose(rig, pose)
            bpy.context.view_layer.update()
            stem = f"facing_{k}_{names[k]}" if pose is None else f"facing_{k}_{names[k]}_f{j:02d}"
            path = out / f"{stem}.png"
            bpy.context.scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            outputs.append({"facing": k, "name": names[k], **({} if pose is None else {"frame": j}),
                            "file": path.name, "sha256": sha256(path)})
            print(f"RENDERED {path.name} {outputs[-1]['sha256']}")

    meta = {
        "schema": "mercs.render_meta/1",
        "body": args.body,
        "pose": "rest" if clip is None else "clip",
        "inputs": {
            "body_blend": {"file": f"tools/pipeline/bodies/{blend.name}", "sha256": sha256(blend)},
            "camera_rig": {"file": rel_path(camera_file), "sha256": sha256(camera_file)},
            "light_rig": {"file": "tools/pipeline/light_rig.json", "sha256": sha256(LIGHT_FILE)},
            "render_script": {"file": "tools/pipeline/render_character.py", "sha256": sha256(Path(__file__))},
        },
        "tools": {"blender": bpy.app.version_string},
        "outputs": outputs,
    }
    if args.render_pass != "color":
        meta["pass"] = args.render_pass
    prop_file = Path(args.proportions).resolve()
    meta["inputs"]["proportions"] = {"file": rel_path(prop_file), "sha256": sha256(prop_file)}
    meta["proportion"] = proportion
    if kit:
        meta["inputs"]["kit"] = kit
    if clip is not None:
        meta["clip"] = clip
    (out / "render_meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("RENDER_OK " + str(len(outputs)))


main()
