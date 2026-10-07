"""Render one body in its rest pose from the 8 fixed facings, at 4x, to PNG with alpha.

Run headless (Blender 5.2; no add-ons needed, the body .blend carries the mesh and rig):
  blender -b --factory-startup -P tools/pipeline/render_character.py -- --body average_m --out <dir>

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
from mathutils import Euler, Vector

PIPELINE = Path(__file__).resolve().parent
CAMERA_FILE = PIPELINE / "camera_rig.json"
LIGHT_FILE = PIPELINE / "light_rig.json"
BODIES_DIR = PIPELINE / "bodies"
SRGB_LINEAR_BREAK = 0.04045


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--body", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--facings", default="all", help="'all' or comma-separated facing indices")
    return p.parse_args(argv)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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
    cam = json.loads(CAMERA_FILE.read_text(encoding="utf-8"))
    light = json.loads(LIGHT_FILE.read_text(encoding="utf-8"))
    blend = BODIES_DIR / f"{args.body}.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    for obj in list(bpy.data.objects):
        if obj.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(obj, do_unlink=True)
    setup_render(cam, light)
    apply_material(light["body_material"])
    rig = body_rig()
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
            "camera_rig": {"file": "tools/pipeline/camera_rig.json", "sha256": sha256(CAMERA_FILE)},
            "light_rig": {"file": "tools/pipeline/light_rig.json", "sha256": sha256(LIGHT_FILE)},
            "render_script": {"file": "tools/pipeline/render_character.py", "sha256": sha256(Path(__file__))},
        },
        "tools": {"blender": bpy.app.version_string},
        "outputs": outputs,
    }
    (out / "render_meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("RENDER_OK " + str(len(outputs)))


main()
