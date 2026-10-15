"""Kit extras for render_character.py (Blender only): conformed armour shells, pleated cloth and the eyes.

Slop audit 2026-10-15 (rows 7-16): primitive plate (a sphere breastplate, cylinder greaves) could not
enclose the MPFB body, so skin poked through the plate in random patches. A shell instead is the body
itself: a copy of the body mesh that keeps only the vertices whose dominant bone the shell covers, smoothed
(plate does not show every muscle) and pushed out along the normals by offset_m. It is outside the body by
construction, so no skin can show through it, and it deforms with the rig like the body does. Kit json:

  "shells": {"cuirass": {"bones": ["mixamorig:Spine", "mixamorig:Hips"], "exclude": [], "offset_m": 0.03,
                         "smooth": 8, "material": "iron"}}

"eyes": true (or {"push_m": metres}) copies the MPFB eye helpers (hidden on the body) as one object named feature_eyes, so the
material-ID pass can mark the eyes and build_sprites.py can keep them as deliberate face pixels.
A kit piece with "pleats" (a list of metres, one per side of a cone) zigzags the cone's bottom ring in depth:
irregular fold clusters that each catch the key light on one side (a cape, not a flat slab).
"""
from __future__ import annotations

import math

import bpy
from mathutils import Vector

SHELL_PREFIX = "shell_"
EXTRA_FLAG = "mercs_extra"  # set on every object this module adds: render_character.body_mesh skips them
EYES_NAME = "feature_eyes"
EYE_GROUPS = ("helper-l-eye", "helper-r-eye")
BODY_GROUP = "body"
HALF = 0.5
COVER_KEEP_RINGS = 2
EYE_PUSH_M = 0.008


def dominant_bones(body: bpy.types.Object, bones: set) -> list:
    """Per vertex: the name of its most-weighted rig bone, or None."""
    names = {g.index: g.name for g in body.vertex_groups}
    out = []
    for v in body.data.vertices:
        best = max(((g.weight, names[g.group]) for g in v.groups if names[g.group] in bones), default=None)
        out.append(best[1] if best else None)
    return out


def in_group(body: bpy.types.Object, groups: tuple) -> list:
    """Per vertex: True when it carries one of the named vertex groups at weight above half."""
    idx = {body.vertex_groups[n].index for n in groups if n in body.vertex_groups}
    return [any(g.group in idx and g.weight > HALF for g in v.groups) for v in body.data.vertices]


def masked_copy(body: bpy.types.Object, name: str, members: list) -> bpy.types.Object:
    """A copy of the body that shows only the member vertices (shares mesh, shape keys and rig)."""
    group = body.vertex_groups.new(name=f"mercs_{name}")
    group.add([i for i, m in enumerate(members) if m], 1.0, "REPLACE")
    obj = body.copy()
    obj.data = body.data.copy()  # own mesh (with its shape keys): a pass's material must not land on the body
    for col in body.users_collection:
        col.objects.link(obj)
    obj.name = name
    obj[EXTRA_FLAG] = True
    mask = next(m for m in obj.modifiers if m.type == "MASK")
    mask.vertex_group = group.name
    mask.invert_vertex_group = False
    return obj


def add_shells(rig: bpy.types.Object, body: bpy.types.Object, shells: dict) -> list:
    bones = {b.name for b in rig.data.bones}
    dom = dominant_bones(body, bones)
    flesh = in_group(body, (BODY_GROUP,))
    made, covered = [], [False] * len(dom)
    for name, spec in sorted(shells.items()):
        take, skip = tuple(spec["bones"]), tuple(spec.get("exclude", ()))
        members = [bool(f and b and b.startswith(take) and not (skip and b.startswith(skip)))
                   for b, f in zip(dom, flesh)]
        covered = [c or m for c, m in zip(covered, members)]
        obj = masked_copy(body, SHELL_PREFIX + name, members)
        obj["kit_material"] = spec.get("material", "iron")
        obj["kit_group"] = name
        smooth = obj.modifiers.new("shell_smooth", "SMOOTH")
        smooth.factor = 1.0
        smooth.iterations = spec.get("smooth", 0)
        disp = obj.modifiers.new("shell_offset", "DISPLACE")
        disp.direction = "NORMAL"
        disp.mid_level = 0.0
        disp.strength = spec["offset_m"]
        if "bulge" in spec:
            add_bulge(obj, members, spec["bulge"])
        made.append(obj.name)
    if made:
        hide_covered(body, covered)
    return made


def add_bulge(obj: bpy.types.Object, members: list, bulge: dict) -> None:
    """Plate that stands off the body where it faces one way: a barrel breastplate swells the chest and gut
    forward (bulge {"dir": [0, -1, 0], "m": 0.06}), so a heavy leads with his front, not his back. Each member
    vertex is pushed out along its normal by m times how squarely its rest normal faces dir (0 when it faces
    away), optionally only between z_min_m and z_max_m (rest-mesh height)."""
    d = Vector(bulge["dir"]).normalized()
    lo, hi = bulge.get("z_min_m", -math.inf), bulge.get("z_max_m", math.inf)
    group = obj.vertex_groups.new(name="mercs_bulge")
    for v, m in zip(obj.data.vertices, members):
        w = max(0.0, v.normal.dot(d)) if m and lo <= v.co.z <= hi else 0.0
        if w > 0.0:
            group.add([v.index], w, "REPLACE")
    disp = obj.modifiers.new("shell_bulge", "DISPLACE")
    disp.direction = "NORMAL"
    disp.mid_level = 0.0
    disp.strength = bulge["m"]
    disp.vertex_group = group.name


def hide_covered(body: bpy.types.Object, covered: list) -> None:
    """Drop the body's own skin under the shells, so smoothing can never let a toe or a knee poke through.
    The ring of COVER_KEEP_RINGS vertices at each shell's rim stays, so no gap opens into the hollow body."""
    inner = list(covered)
    edges = [tuple(e.vertices) for e in body.data.edges]
    for _ in range(COVER_KEEP_RINGS):
        nxt = list(inner)
        for a, b in edges:
            if inner[a] != inner[b]:
                nxt[a] = nxt[b] = False
        inner = nxt
    group = body.vertex_groups.new(name="mercs_covered")
    group.add([i for i, c in enumerate(inner) if c], 1.0, "REPLACE")
    mask = body.modifiers.new("hide_covered", "MASK")
    mask.vertex_group = group.name
    mask.invert_vertex_group = True


def add_eyes(body: bpy.types.Object, push_m: float = 0.0) -> str:
    """The eyeballs, pushed EYE_PUSH_M out through the lids: seen from the 45 degree sprite camera the lids and
    brow hide the true eyeball, and a face with no eyes reads as a mannequin (slop audit rows 7-9)."""
    obj = masked_copy(body, EYES_NAME, in_group(body, EYE_GROUPS))
    push = obj.modifiers.new("eye_push", "DISPLACE")
    push.direction = "NORMAL"
    push.mid_level = 0.0
    push.strength = push_m or EYE_PUSH_M
    return obj.name


def pleat(obj: bpy.types.Object, depths: list, size_y: float) -> None:
    """Move the cone's bottom-ring vertices along local Y by depths[k] metres (k = side index, from +X round)."""
    verts = [v for v in obj.data.vertices if v.co.z < 0.0 and (v.co.x or v.co.y)]
    for k, v in enumerate(sorted(verts, key=lambda v: _angle(v.co))):
        v.co.y += depths[k % len(depths)] / size_y


def _angle(co) -> float:
    return math.atan2(co.y, co.x) % (2.0 * math.pi)


DRAPE_COLS = 28
DRAPE_ROWS = 44
DRAPE_SOLIDIFY_M = 0.012


def fold_rise(t: float, start: float) -> float:
    """0 above a fold's start, rising smoothly to 1 at the hem."""
    k = max(0.0, min(1.0, (t - start) / max(1e-6, 1.0 - start)))
    return k * k * (3.0 - 2.0 * k)


def drape(objs: list, spec: dict) -> bpy.types.Object:
    """A cape that hangs (Lead QC 2026-10-15: a cone cape read as a rigid plank held out in still air, with
    daylight between it and the waist). A grid in world space from the shoulder line (top_z_m) to the hem
    (hem_z_m), width_top_m widening to width_hem_m. Each column hangs like cloth: at every height it sits
    clear_m behind the furthest-back point of the figure above it in that column (it rests on the shoulder
    blades and the buttocks, then falls straight), plus hem_flare_m * t^2 toward the hem (t = 0 at the top,
    1 at the hem), less tuck_m * t^2 (the hem settles in toward the calves; never into the figure). Its side edges wrap forward by wrap_m toward the arms (never into them), so no daylight
    shows between cape and back in profile. folds [[x_frac, depth_m, width_frac], ...] add shaped fold
    clusters that deepen toward the hem, each from its own start (an optional 4th value, 0..1 down the cape: a
    fold that runs from the collar to the hem reads as a stripe); a fold may go inward only where the figure
    leaves room. hem_wave_m
    lets an outward fold hang that much lower than an inward one, so the hem is not a ruled line."""
    deps = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        ev = o.evaluated_get(deps)
        mesh = ev.to_mesh()
        mw = ev.matrix_world
        pts.extend((mw @ v.co) for v in mesh.vertices)
        ev.to_mesh_clear()
    top, hem = spec["top_z_m"], spec["hem_z_m"]
    band = spec.get("column_m", 0.035)
    clear = spec["clear_m"]
    folds = spec.get("folds", [])
    us = [-1.0 + 2.0 * j / (DRAPE_COLS - 1) for j in range(DRAPE_COLS)]
    shapes = [[d * math.exp(-((u - f[0]) / f[2]) ** 2) for f, d in ((f, f[1]) for f in folds)] for u in us]
    profile = [sum(row) for row in shapes]
    peak = max((abs(p) for p in profile), default=0.0) or 1.0
    hems = [hem - spec.get("hem_wave_m", 0.0) * p / peak for p in profile]  # a fold that stands out hangs lower
    verts, grid = [], []
    for i in range(DRAPE_ROWS):
        t = i / (DRAPE_ROWS - 1)
        half = 0.5 * (spec["width_top_m"] + (spec["width_hem_m"] - spec["width_top_m"]) * t)
        row = []
        for j, u in enumerate(us):
            z = top - (top - hems[j]) * t
            x = u * half
            col = [p for p in pts if abs(p.x - x) < band]
            above = max((p.y for p in col if z - band <= p.z <= top + band), default=None)
            here = max((p.y for p in col if abs(p.z - z) < band), default=None)
            hang = (above if above is not None else spec.get("back_y_m", 0.0)) + clear
            y = hang + (spec.get("hem_flare_m", 0.0) - spec.get("tuck_m", 0.0)) * t * t
            y += sum(a * fold_rise(t, f[3] if len(f) > 3 else 0.0) for a, f in zip(shapes[j], folds))
            edge = max(0.0, (abs(u) - 0.55) / 0.45)
            y -= spec.get("wrap_m", 0.0) * edge * edge
            floor = (here + clear) if here is not None else -math.inf
            row.append(len(verts))
            verts.append((x, max(y, floor), z))
        grid.append(row)
    faces = [(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])
             for i in range(DRAPE_ROWS - 1) for j in range(DRAPE_COLS - 1)]
    mesh = bpy.data.meshes.new("drape")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.shade_smooth()
    obj = bpy.data.objects.new("drape", mesh)
    bpy.context.scene.collection.objects.link(obj)
    sol = obj.modifiers.new("drape_thickness", "SOLIDIFY")
    sol.thickness = DRAPE_SOLIDIFY_M
    sol.offset = 1.0
    obj.modifiers.new("drape_smooth", "SUBSURF").levels = 1
    return obj
