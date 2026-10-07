"""Build a base body with the frozen Mixamo rig and sockets, then write or check the rig contract.

Run headless with the user profile, because MPFB is a user extension (Blender 5.2):
  blender -b -P tools/pipeline/build_body.py -- --body average_m --out <dir> [--check]

Writes <out>/<body>.blend and, unless --check, updates tools/pipeline/rig_contract.json.
With --check it rebuilds in memory and exits 1 if the rest-pose hash differs from the contract.
Deterministic: the hash covers bone names, parents, rest head/tail/roll and socket transforms,
rounded to 0.1 mm / 0.0001 rad, so the same inputs give the same hash.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.targetservice import TargetService
from bl_ext.user_default.mpfb.entities.objectproperties import HumanObjectProperties

PIPELINE = Path(__file__).resolve().parent
BODIES_FILE = PIPELINE / "bodies" / "bodies.json"
SOCKETS_FILE = PIPELINE / "rig_sockets.json"
CONTRACT_FILE = PIPELINE / "rig_contract.json"
ROUND_DIGITS = 4
BISECT_STEPS = 30


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--body", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--check", action="store_true")
    return p.parse_args(argv)


def body_z_range(basemesh: bpy.types.Object) -> tuple[float, float]:
    """Min and max z of the evaluated body (targets are shape keys; the mask drops helpers)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = basemesh.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    zs = [(basemesh.matrix_world @ v.co).z for v in mesh.vertices]
    evaluated.to_mesh_clear()
    return min(zs), max(zs)


def body_height(basemesh: bpy.types.Object) -> float:
    lo, hi = body_z_range(basemesh)
    return hi - lo


def set_macros(basemesh: bpy.types.Object, macros: dict, height_macro: float) -> None:
    for name, value in macros.items():
        if name != "race":
            HumanObjectProperties.set_value(name, value, entity_reference=basemesh)
    for name, value in macros["race"].items():
        HumanObjectProperties.set_value(name, value, entity_reference=basemesh)
    HumanObjectProperties.set_value("height", height_macro, entity_reference=basemesh)
    TargetService.reapply_macro_details(basemesh)


def build_mesh(spec: dict, tolerance: float) -> tuple[bpy.types.Object, float]:
    basemesh = HumanService.create_human(feet_on_ground=False)
    lo, hi = 0.0, 1.0
    macro = 0.5
    for _ in range(BISECT_STEPS):
        macro = (lo + hi) / 2
        set_macros(basemesh, spec["macros"], macro)
        h = body_height(basemesh)
        if abs(h - spec["height_m"]) <= tolerance / 4:
            break
        lo, hi = (macro, hi) if h < spec["height_m"] else (lo, macro)
    h = body_height(basemesh)
    if abs(h - spec["height_m"]) > tolerance:
        raise SystemExit(f"height fit failed: {h:.4f} m vs {spec['height_m']} m")
    # Feet on the ground: shift so the lowest body vertex sits at z = 0.
    basemesh.location.z -= body_z_range(basemesh)[0]
    bpy.context.view_layer.update()
    return basemesh, macro


def add_sockets(armature: bpy.types.Object, sockets: dict) -> None:
    for name, s in sockets.items():
        bone = armature.data.bones[s["bone"]]
        anchor = {"head": bone.head_local, "tail": bone.tail_local,
                  "mid": (bone.head_local + bone.tail_local) / 2}[s["at"]]
        world = armature.matrix_world @ Matrix.Translation(anchor + Vector(s["offset_m"]))
        empty = bpy.data.objects.new(f"socket_{name}", None)
        empty.empty_display_type = "ARROWS"
        empty.empty_display_size = 0.05
        bpy.context.scene.collection.objects.link(empty)
        empty.parent = armature
        empty.parent_type = "BONE"
        empty.parent_bone = s["bone"]
        bpy.context.view_layer.update()
        empty.matrix_world = world


def rest_pose(armature: bpy.types.Object, sockets: dict) -> dict:
    r = lambda v: [round(float(c), ROUND_DIGITS) + 0.0 for c in v]  # +0.0 folds -0.0
    bones = {}
    for b in armature.data.bones:
        roll = b.matrix_local.to_euler()
        bones[b.name] = {"parent": b.parent.name if b.parent else None,
                         "head": r(b.head_local), "tail": r(b.tail_local), "rot": r(roll)}
    socks = {}
    for name in sockets:
        socks[name] = {"bone": sockets[name]["bone"],
                       "location": r(bpy.data.objects[f"socket_{name}"].matrix_world.translation)}
    return {"bones": dict(sorted(bones.items())), "sockets": dict(sorted(socks.items()))}


def check_left_is_plus_x(armature: bpy.types.Object) -> None:
    left = armature.data.bones["mixamorig:LeftUpLeg"].head_local.x
    if left <= 0:
        raise SystemExit("orientation assumption broken: LeftUpLeg is not on +X; socket offsets are wrong")


def main() -> None:
    args = parse_args()
    bodies = json.loads(BODIES_FILE.read_text(encoding="utf-8"))
    sockets = json.loads(SOCKETS_FILE.read_text(encoding="utf-8"))["sockets"]
    spec = bodies["bodies"][args.body]

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    basemesh, height_macro = build_mesh(spec, bodies["height_tolerance_m"])
    armature = HumanService.add_builtin_rig(basemesh, bodies["rig"], import_weights=True)
    check_left_is_plus_x(armature)
    add_sockets(armature, sockets)

    pose = rest_pose(armature, sockets)
    digest = hashlib.sha256(json.dumps(pose, sort_keys=True).encode("utf-8")).hexdigest()
    result = {"body": args.body, "height_m": round(body_height(basemesh), ROUND_DIGITS),
              "height_macro": round(height_macro, 6), "bone_count": len(pose["bones"]),
              "rest_pose_sha256": digest}
    print("BUILD_BODY_RESULT " + json.dumps(result))

    contract = json.loads(CONTRACT_FILE.read_text(encoding="utf-8")) if CONTRACT_FILE.exists() else {}
    if args.check:
        want = contract.get("bodies", {}).get(args.body, {}).get("rest_pose_sha256")
        if want != digest:
            print(f"RIG_CONTRACT_MISMATCH {args.body}: contract {want} vs built {digest}")
            sys.exit(1)
        print("RIG_CONTRACT_OK")
        return

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups beside the asset
    bpy.ops.wm.save_as_mainfile(filepath=str(out / f"{args.body}.blend"), compress=True)

    contract["_doc"] = ("Frozen rig contract (07_ASSET_PIPELINE.md 2.1). Generated by build_body.py; "
                        "never edit by hand. A changed hash means every clip and equipment fit is suspect.")
    contract["rig"] = bodies["rig"]
    contract["tools"] = {"blender": bpy.app.version_string, "mpfb": mpfb_version()}
    contract["bones"] = {k: v["parent"] for k, v in pose["bones"].items()}
    contract["sockets"] = {k: sockets[k] for k in sorted(sockets)}
    contract.setdefault("bodies", {})[args.body] = {k: v for k, v in result.items() if k != "body"}
    CONTRACT_FILE.write_text(json.dumps(contract, indent=2) + "\n", encoding="utf-8", newline="\n")


def mpfb_version() -> str:
    import bl_ext.user_default.mpfb as mpfb
    manifest = Path(mpfb.__file__).parent / "blender_manifest.toml"
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if line.startswith("version"):
            return line.split("=", 1)[1].strip().strip('"')
    return "unknown"


main()
