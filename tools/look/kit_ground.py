"""Ground material for the look-target kits (desloppify round 2, 2026-10-15): real surface detail
modelled as palette faces at the sprite's texel density, never dither or noise.

Street: packed earth with a cart's wheel ruts, trodden paths from the doors, a worn apron round the
well, damp ground under the eaves and the barrels, puddle-dark low spots, and loose stones in clumps
where stones gather (house corners, the well foot, the kerb, the fence). Cobbles: irregular setts
with a gutter, a patch of smaller repair setts and a few lost stones. Map: grass patchwork
pieces (lush and dry), tuft clumps and stone clusters that look_map.gd places by hand, a ragged
forest floor and a rutted road with ragged verges.
Every shape is placed on purpose (a fixed list or a fixed hash), so the detail sits where it has a
reason and open ground stays quiet.
"""
from __future__ import annotations

import math

import bmesh
from mathutils import Matrix, Vector

from kit_lib import P, h

DIRT = 0.012  # patch faces sit this far above the flat mud (metres); ruts and stones above them
TILE = 4.0
SETT_Z = 0.004


def rag(pts, seed, amp, step):
    """A closed outline with every edge cut every `step` metres and each cut moved in or out by up
    to `amp`: crisp, irregular, never a ruler line."""
    out = []
    for k, a in enumerate(pts):
        b = pts[(k + 1) % len(pts)]
        n = max(1, round(math.dist(a, b) / step))
        nx, ny = (b[1] - a[1]), -(b[0] - a[0])
        ln = math.hypot(nx, ny) or 1.0
        for s in range(n):
            t = s / n
            off = 0.0 if s == 0 else (h(seed, k, s, 91) - 0.5) * 2.0 * amp
            out.append((a[0] + (b[0] - a[0]) * t + nx / ln * off, a[1] + (b[1] - a[1]) * t + ny / ln * off))
    return out


def fan(o, outline, m, z):
    """Fills an outline (star-shaped about its centroid) as a triangle fan at height z."""
    cx = sum(p[0] for p in outline) / len(outline)
    cy = sum(p[1] for p in outline) / len(outline)
    for k, a in enumerate(outline):
        b = outline[(k + 1) % len(outline)]
        o.poly([(cx, cy, z), (a[0], a[1], z), (b[0], b[1], z)], m)


def blob(o, c, r, seed, m, z, n=14):
    """An irregular patch around c with radii r: neighbouring radii are averaged, so the edge has a
    few clear lobes rather than spikes."""
    raw = [0.62 + 0.38 * h(seed, k, 92) for k in range(n)]
    rad = [(raw[k - 1] + 2 * raw[k] + raw[(k + 1) % n]) / 4 for k in range(n)]
    fan(o, [(c[0] + math.cos(k / n * math.tau) * r[0] * rad[k], c[1] + math.sin(k / n * math.tau) * r[1] * rad[k])
            for k in range(n)], m, z)


def ribbon(o, pts, width, m, spec):
    """A strip along a polyline. spec = (z, seed, gaps, side): `gaps` is the share of segments left
    out (a rut fades where the ground is hard), `side` shifts the strip off the line (-1, 0, 1)."""
    z, seed, gaps, side = spec
    for k in range(len(pts) - 1):
        if h(seed, k, 93) < gaps:
            continue
        quad = []
        for idx in (k, k + 1):
            a, b = pts[max(idx - 1, 0)], pts[min(idx + 1, len(pts) - 1)]
            tx, ty = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / ln, tx / ln
            w = width * (0.85 + 0.3 * h(seed, idx, 94))
            lo, hi = (0.0, w) if side > 0 else (-w, 0.0) if side < 0 else (-w / 2, w / 2)
            quad.append(((pts[idx][0] + nx * lo, pts[idx][1] + ny * lo), (pts[idx][0] + nx * hi, pts[idx][1] + ny * hi)))
        (a0, a1), (b0, b1) = quad
        o.poly([(*a0, z), (*b0, z), (*b1, z), (*a1, z)], m)


def stone(o, x, y, r, spec, lift=0.0):
    """A loose stone: a low six-sided chunk, top and sides on their own palette steps, its base `lift`
    metres up. spec = (seed, top, side, flat): flat stones are drawn unlit (the map's, see pebble history)."""
    seed, top, side, flat = spec
    res = bmesh.ops.create_cone(o.bm, cap_ends=True, segments=6, radius1=r, radius2=r * 0.7, depth=r * 0.6,
                                matrix=Matrix.Translation(Vector((x, y, lift + r * 0.3))) @ Matrix.Rotation(h(seed, 71), 4, "Z")
                                @ Matrix.Diagonal((1.0, 0.75 + 0.3 * h(seed, 72), 1.0, 1.0)))
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = o.mi(P(*top, flat=flat) if f.normal.z > 0.9 else P(*side, flat=flat))


def clump(o, c, n, seed, spec, lift=0.0):
    """n stones gathered round c: one larger, the rest small, tighter toward the middle.
    spec = (size, top, side, flat)."""
    size, top, side, flat = spec
    for k in range(n):
        ang = h(seed, k, 75) * math.tau
        dist = 0.0 if k == 0 else size * (1.2 + 2.2 * h(seed, k, 76) ** 1.5)
        r = size * (1.0 if k == 0 else 0.4 + 0.4 * h(seed, k, 77))
        stone(o, c[0] + math.cos(ang) * dist, c[1] + math.sin(ang) * dist * 0.8, r, (seed * 10 + k, top, side, flat),
              lift)


def blade_fan(o, x, y, k, spec):
    """A grass tuft: three blades from one root, leaning a little away from the camera, so it has a
    lit and a shadow side. spec = (length, width, material)."""
    length0, width, m = spec
    lean = (h(k, 61) - 0.5) * 0.6
    for b in range(3):
        ang = math.pi + lean + (b - 1) * 0.7 + 0.2 * (h(k, b, 62) - 0.5)
        tilt = 0.3 + 0.2 * h(k, b, 63)
        length = length0 * (1.0 + 0.33 * h(k, b, 64))
        rot = Matrix.Rotation(ang, 4, "Z") @ Matrix.Rotation(tilt, 4, "X")
        mid = rot @ Vector((0.0, 0.0, length / 2))
        o.cone(width, 0.0, length, (x + mid.x, y + mid.y, mid.z), m, segs=3, rot=rot)


def tufts(o, c, n, seed, spec):
    """n tufts in a clump round c (dense in the middle, a straggler or two). spec = (spread, fan spec)."""
    spread, fspec = spec
    for k in range(n):
        ang = h(seed, k, 65) * math.tau
        dist = spread * h(seed, k, 66) ** 1.7
        blade_fan(o, c[0] + math.cos(ang) * dist, c[1] + math.sin(ang) * dist, seed * 37 + k, fspec)


# ---------------------------------------------------------------- street

def street_dirt(g):
    """The far verge's packed earth (the base mud is soil 2). Light comes from camera-left front."""
    worn, damp = P("soil", 3), P("soil", 1)
    # Trodden ground: a bending path from the timber house door to the road, and the well's apron
    # with the stone house's path to it.
    door = [(-3.8 + 0.25 * math.sin(k * 0.9) - 0.12 * k, 3.95 - 0.25 * k) for k in range(10)]
    ribbon(g, door, 0.85, worn, (DIRT, 3, 0.0, 0))
    blob(g, (3.3, 2.45), (1.4, 1.1), 5, worn, DIRT, n=24)
    ribbon(g, [(4.5 - 0.12 * k, 3.75 - 0.2 * k) for k in range(5)], 0.7, worn, (DIRT, 6, 0.0, 0))
    ribbon(g, [(0.75, 2.95), (1.15, 2.78), (1.55, 2.7), (1.95, 2.62)], 0.45, worn, (DIRT, 14, 0.0, 0))
    # Puddle-dark ground: under the barrels, a low spot along the kerb, spilt water by the well;
    # each a cluster of overlapping lobes, never a ring.
    for c, r, seed in (((0.15, 3.15), (0.8, 0.45), 7), ((0.6, 2.85), (0.4, 0.25), 8), ((-1.55, 1.9), (0.7, 0.2), 9),
                       ((-1.05, 1.98), (0.3, 0.16), 10), ((2.25, 1.95), (0.42, 0.22), 11), ((2.55, 1.8), (0.25, 0.14), 12)):
        blob(g, c, r, seed, damp, DIRT + 0.002, n=16)
    cart_ruts(g)
    for c, n, seed, size in (((-5.0, 3.72), 5, 1, 0.1), ((4.25, 1.95), 4, 2, 0.08), ((-0.95, 1.82), 3, 3, 0.07),
                             ((6.6, 3.42), 4, 4, 0.09), ((-6.4, 2.3), 3, 5, 0.06),
                             ((1.25, 2.1), 3, 6, 0.06)):
        clump(g, c, n, seed, (size, ("slate", 2), ("slate", 1), False))
    for c, n, seed in (((1.75, 3.62), 4, 1), ((7.3, 3.5), 3, 2), ((8.9, 3.48), 4, 3), ((-5.45, 3.82), 3, 4)):
        tufts(g, c, n, seed, (0.25, (0.14, 0.035, P("verdure", 2))))


def cart_ruts(g):
    """A cart's two wheel ruts along the verge, turning out onto the road: each a dark groove, broken
    where the ground is hard, with water standing in two places."""
    for gauge, end_x, seed in ((1.95, -2.2, 21), (3.2, -0.55, 22)):
        pts = []
        x = -7.0
        while x <= end_x + 1e-6:
            t = 0.0 if x < -4.2 else min(1.0, (x + 4.2) / (end_x + 4.2))
            y = gauge + 0.04 * math.sin(x * 0.9 + seed) - (gauge - 1.66) * (1 - math.cos(t * math.pi / 2))
            pts.append((x, y))
            x += 0.15
        ribbon(g, pts, 0.14, P("soil", 1), (DIRT + 0.006, seed, 0.05, 0))
        for k in (6, 19):
            ribbon(g, pts[k:k + 4], 0.12, P("soil", 0), (DIRT + 0.008, seed + 90, 0.0, 0))


def cobbles(g):
    """Setts in rows that wander a little, each stone its own size and set slightly askew; a darker
    gutter row by each kerb, a patch of smaller, squarer repair setts right of the lantern, a few
    stones lost (the grout shows) and a pale stone only where wheels have polished the crown."""
    row, z = 0, -1.58
    while z < 1.85:
        hgt = 0.18 + 0.04 * h(row, 1)
        x = -14.0 + 0.16 * h(row, 2)
        k = 0
        while x < 13.8:
            repair = 1.9 < x < 4.3 and 3 <= row <= 8 - (1 if x > 3.6 else 0)
            w = (0.16 + 0.03 * h(row, k)) if repair else (0.22 + 0.13 * h(row, k))
            pick = h(row, k, 3)
            lost = h(round(x * 2), row, 4) < 0.03 and pick < 0.6
            if not lost:
                gutter = z < -1.35 or z + hgt > 1.62
                polished = row in (6, 7, 10) and pick > 0.88
                m = (P("slate", 1) if (gutter and pick < 0.45) or pick < 0.06 else
                     P("slate", 3) if polished else P("slate", 2))
                sz = hgt - 0.035 - (0.02 if repair else 0.0)
                sett(g, (w - 0.04, sz),
                     (x + w / 2, -(z + hgt / 2 + 0.015 * (h(row, k, 5) - 0.5))),
                     m, 0.08 * (h(row, k, 6) - 0.5))
            x += w
            k += 1
        z += hgt
        row += 1


def sett(g, size, loc, m, rot_z):
    """A cobble as a flat face just over the grout, centred on loc (x, y). Boxes showed their sides
    edge-on as a 1-px fringe and cast specks of shadow into the grout, both flipping between palette
    colours (speckle); a face higher than the shadow bias still cast a dotted hairline."""
    c, s_ = math.cos(rot_z), math.sin(rot_z)
    hw, hd = size[0] / 2, size[1] / 2
    g.poly([(loc[0] + px * c - py * s_, loc[1] + px * s_ + py * c, SETT_Z)
            for px, py in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd))], m)


def kerbs(g):
    """Kerb stones of uneven length with the odd chipped one; mostly one grey, a few paler."""
    for z in (-1.65, 1.95):
        x, k = -14.0, 0
        while x < 14.0:
            w = 0.4 + 0.32 * h(k, z, 81)
            chipped = h(k, z, 82) < 0.08
            g.box((w - (0.12 if chipped else 0.03), 0.18, 0.08), (x + w / 2, -z, 0.03),
                  P("slate", 3 if h(k, z, 83) > 0.9 else 2))
            x += w
            k += 1


# ---------------------------------------------------------------- map

def map_dressing(col, obj):
    """Map pieces that look_map.gd places by hand: grass patches (unit radius, scaled there), tuft
    clumps and stone clusters. Stones are warm grey on a dark earth seat so they sit in the grass."""
    for v, (lush, dry) in enumerate((((6.0, 3.4), (3.4, 2.4)), ((4.4, 2.8), (4.2, 2.2)), ((7.0, 2.4), (3.0, 1.9)))):
        for name, m, r in (("patch_lush", P("verdure", 1), lush), ("patch_dry", P("verdure", 3), dry)):
            o = obj(f"{name}_{v}")
            fan(o, rag(lobed(r, 40 + v * 3 + len(name)), v + len(name), 0.12, 0.3), m, 0.006)
            o.finish(col)
        o = obj(f"tufts_{v}")
        tufts(o, (0.0, 0.0), 6 + 2 * v, 60 + v, (0.9, (0.32, 0.11, P("verdure", 3))))
        o.finish(col)
        o = obj(f"stones_{v}")
        n = 3 + v
        for k in range(n):
            ang = h(v, k, 75) * math.tau
            dist = 0.0 if k == 0 else 0.3 + 0.5 * h(v, k, 76)
            r = 0.26 if k == 0 else 0.11 + 0.08 * h(v, k, 77)
            x, y = math.cos(ang) * dist, math.sin(ang) * dist * 0.8
            blob(o, (x, y), (r * 1.35, r * 1.2), 70 + v * 10 + k, P("soil", 2, flat=True), 0.007, n=8)
            stone(o, x, y, r, (v * 10 + k, ("iron", 2), ("soil", 1), True))
        o.finish(col)


def lobed(r, seed, n=28):
    """A grass patch outline with radii r: a few broad lobes and bays (low harmonics), star-shaped."""
    ph = [h(seed, k, 98) * math.tau for k in range(3)]
    out = []
    for k in range(n):
        a = k / n * math.tau
        f = 1.0 + 0.18 * math.cos(2 * a + ph[0]) + 0.14 * math.cos(3 * a + ph[1]) + 0.08 * math.cos(5 * a + ph[2])
        out.append((math.cos(a) * r[0] * f, math.sin(a) * r[1] * f))
    return out


def forest_floor(o, v):
    """A forest tile's dark floor, reaching ragged past the tile's edges so a wood's outline is never
    the tile grid (neighbouring forest tiles overlap and hide each other's edges)."""
    s = TILE / 2
    corners = [(-s, -s), (s, -s), (s, s), (-s, s)]
    pts = []
    for k, a in enumerate(corners):
        b = corners[(k + 1) % 4]
        for t in range(8):
            px, py = a[0] + (b[0] - a[0]) * t / 8, a[1] + (b[1] - a[1]) * t / 8
            push = 1.0 + (0.05 + 0.3 * h(v, k, t, 85) ** 1.4) / s
            pts.append((px * push, py * push))
    fan(o, pts, P("verdure", 1), 0.007)


def road(o, v, along_x):
    """A dirt road across a tile: a band of packed earth (soil 3) whose verges wander (fixed width
    where tiles meet). No marks along it: at map scale any repeated mark read as a lane dash."""
    n = 10
    xs = [-TILE / 2 - 0.02 + k * (TILE + 0.04) / n for k in range(n + 1)]
    half = [0.55 if k in (0, n) else 0.45 + 0.25 * h(v, k, 86) for k in range(n + 1)]
    mid = [0.0 if k in (0, n) else 0.12 * (h(v, k, 87) - 0.5) for k in range(n + 1)]

    def at(x, y):
        return (x, y) if along_x else (y, x)
    for k in range(n):
        for side in (-1, 1):
            o.poly([(*at(xs[k], mid[k]), 0.03), (*at(xs[k + 1], mid[k + 1]), 0.03),
                    (*at(xs[k + 1], mid[k + 1] + side * half[k + 1]), 0.03), (*at(xs[k], mid[k] + side * half[k]), 0.03)],
                   P("soil", 3))
