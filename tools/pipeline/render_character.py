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
Equipment layers and clips are later arguments of this same script (07 section 2.4).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector

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
    p.add_argument("--pass", dest="render_pass", choices=("color", "normal"), default="color")
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
    """1x pixels per metre on the image plane (the scale rule in camera_rig.json)."""
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


def figure_extent_z(rig: bpy.types.Object) -> tuple[float, float]:
    """World z range of the deformed body (shape keys and pose evaluated, never base vertices)."""
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    lo, hi = math.inf, -math.inf
    for obj in rig.children:
        if obj.type != "MESH":
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


def apply_proportions(rig: bpy.types.Object, path: str, name: str, height_m: float) -> dict:
    """Pose and scale bones for a sample variant, then refit the figure to height_m with feet on z = 0."""
    cfg = json.loads(Path(path).read_text(encoding="utf-8"))
    name = name or cfg["default"]
    spec = cfg["variants"][name]
    scales = spec["bone_scale"]
    aim = {**cfg.get("pose", {}).get("bone_direction", {}), **spec.get("bone_direction", {})}
    if not scales and not aim:
        return {"variant": name, "rig_scale": 1.0, "height_m": None}
    rig.data.pose_position = "POSE"
    aim_bones(rig, aim)
    for bone, factor in scales.items():
        pb = rig.pose.bones.get(bone)
        if pb is None:
            raise SystemExit(f"variant {name}: no bone {bone}; bones are never added or renamed")
        pb.scale = (factor, factor, factor)
    lo, hi = figure_extent_z(rig)
    s = height_m / (hi - lo)
    rig.scale = (s, s, s)
    lo, hi = figure_extent_z(rig)
    rig.location.z -= lo
    lo, hi = figure_extent_z(rig)
    print(f"PROPORTION {name} rig_scale {s:.4f} height {hi - lo:.4f} feet {lo:.4f}")
    return {"variant": name, "rig_scale": round(s, 6), "height_m": round(hi - lo, 4)}


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
    if args.render_pass == "normal":
        apply_normal_pass()
    else:
        apply_material(light["body_material"])
    rig = body_rig()
    proportion = apply_proportions(rig, args.proportions, args.variant, cam["reference_height_m"])
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
        bpy.context.view_layer.update()
        path = out / f"facing_{k}_{names[k]}.png"
        bpy.context.scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        outputs.append({"facing": k, "name": names[k], "file": path.name, "sha256": sha256(path)})
        print(f"RENDERED {path.name} {outputs[-1]['sha256']}")

    meta = {
        "schema": "mercs.render_meta/1",
        "body": args.body,
        "pose": "rest",
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
    (out / "render_meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("RENDER_OK " + str(len(outputs)))


main()
