"""Model the look-target environment kits in Blender (06_STYLE_ART.md section 6) and export glTF.

  blender -b --factory-startup --python-exit-code 1 -P tools/look/build_look_kit.py -- --out assets/look_target/kit

Low-poly, flat-shaded, no textures: every face carries a material named "pal:<ramp>:<step>" and the
Godot look-target scene gives it that colour from the option's palette, so one mesh serves every
option and every colour is on the palette by construction. Grime and wear are per-face steps on the
same ramp, chosen by a fixed hash (deterministic; no random module).
Writes street_kit.glb (the street, composed in place, metres, +Y up after export) and
overworld_kit.glb (map tiles 4 x 4 m and markers, each a root object at the origin, named tile_* / marker_*).
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

TILE = 4.0
HILL_LIGHT = Vector((-0.45, -0.45, 0.77)).normalized()  # from the camera-left front, high


def args() -> Path:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return Path(argv[argv.index("--out") + 1]).resolve()


def h(*v: float) -> float:
    """Deterministic hash of numbers to [0, 1)."""
    x = 0.0
    for i, a in enumerate(v):
        x += math.sin(a * (12.9898 + 7.1 * i) + 78.233 * (i + 1)) * 43758.5453
    return x - math.floor(x)


def mat(name: str) -> bpy.types.Material:
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    return m


class Obj:
    """A mesh being built with bmesh; faces get palette material names."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.mats: list[str] = []

    def mi(self, m: str) -> int:
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def box(self, size, loc, m, rot_z: float = 0.0, jitter: tuple | None = None, rot_x: float = 0.0):
        r = Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Rotation(rot_x, 4, "X")
        res = bmesh.ops.create_cube(self.bm, size=1.0,
                                    matrix=Matrix.Translation(Vector(loc)) @ r @ Matrix.Diagonal((*size, 1.0)))
        self._paint(res["verts"], m, jitter)

    def cone(self, r1, r2, depth, loc, m, segs=6, jitter=None, rot=None):
        mtx = Matrix.Translation(Vector(loc))
        if rot is not None:
            mtx = mtx @ rot
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth,
                                    matrix=mtx)
        self._paint(res["verts"], m, jitter)

    def poly(self, pts, m):
        """A face, wound so its normal points up (+Z) or, for a vertical face, as given."""
        vs = [self.bm.verts.new(p) for p in pts]
        e1 = Vector(pts[1]) - Vector(pts[0])
        e2 = Vector(pts[2]) - Vector(pts[0])
        if e1.cross(e2).z < -1e-9:
            vs.reverse()
        f = self.bm.faces.new(vs)
        f.material_index = self.mi(m)

    def _paint(self, verts, m, jitter):
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            mm = m
            if jitter:
                c = f.calc_center_median()
                mm = jitter[int(h(c.x, c.y, c.z) * len(jitter))]
            f.material_index = self.mi(mm)

    def finish(self, collection) -> bpy.types.Object:
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for p in me.polygons:
            p.use_smooth = False
        for m in self.mats:
            me.materials.append(mat(m))
        ob = bpy.data.objects.new(self.name, me)
        collection.objects.link(ob)
        return ob


def P(ramp: str, step: int, flat: bool = False) -> str:
    """A palette face; flat ones are drawn unlit, exactly that colour (look_target.gd)."""
    return f"pal:{ramp}:{step}" + (":flat" if flat else "")


# ---------------------------------------------------------------- street

def tris(g, x_lo, x_hi, z_lo, z_hi, cell, choices, bump):
    """Ground as flat-shaded triangles with jittered heights: the sun shades each facet differently."""
    nx, nz = round((x_hi - x_lo) / cell), round((z_hi - z_lo) / cell)

    def y(x, z):
        return (h(round(x, 3) * 3.1, round(z, 3) * 2.7) - 0.5) * bump
    for ix in range(nx):
        for iz in range(nz):
            x0, z0 = x_lo + ix * cell, z_lo + iz * cell
            a, b = (x0, -z0, y(x0, z0)), (x0 + cell, -z0, y(x0 + cell, z0))
            c, d = (x0 + cell, -(z0 + cell), y(x0 + cell, z0 + cell)), (x0, -(z0 + cell), y(x0, z0 + cell))
            for k, tri in enumerate(((a, b, c), (a, c, d)) if (ix + iz) % 2 else ((a, b, d), (b, c, d))):
                pick = h(ix + x_lo, iz + z_lo, k)
                g.poly(list(tri), next(mm for t, mm in choices if pick < t))


def ground(col):
    """Mud verges in 0.5 m cells and a cobbled road in 0.25 m cells; mostly one ramp step, with a few
    neighbours, so the ground reads as worn surface, not a checkerboard."""
    g = Obj("ground")

    def cells(x_lo, x_hi, z_lo, z_hi, cell, choices, bump):
        nx, nz = round((x_hi - x_lo) / cell), round((z_hi - z_lo) / cell)
        for ix in range(nx):
            for iz in range(nz):
                x0, z0 = x_lo + ix * cell, z_lo + iz * cell

                def y(x, z):
                    return (h(x * 3.1, z * 2.7) - 0.5) * bump
                pts = [(x0, -z0, y(x0, z0)), (x0 + cell, -z0, y(x0 + cell, z0)),
                       (x0 + cell, -(z0 + cell), y(x0 + cell, z0 + cell)), (x0, -(z0 + cell), y(x0, z0 + cell))]
                pick = h(ix + x_lo, iz + z_lo, cell)
                m = next(mm for t, mm in choices if pick < t)
                g.poly(pts, m)
    # cobbles: running-bond rows of low stones over dark grout
    cells(-14.0, 14.0, -1.6, 1.9, 0.5, [(1.01, P("slate", 0))], 0.0)
    row = 0
    z = -1.58
    while z < 1.85:
        x = -14.0 + (0.14 if row % 2 else 0.0)
        k = 0
        while x < 13.8:
            w = 0.26 + 0.06 * h(row, k)
            pick = h(row, k, 3)
            m = P("slate", 2) if pick < 0.75 else P("slate", 1) if pick < 0.95 else P("slate", 3)
            g.box((w - 0.04, 0.19, 0.05 + 0.02 * h(k, row)), (x + w / 2, -(z + 0.11), 0.015), m)
            x += w
            k += 1
        z += 0.22
        row += 1
    mud = [(1.01, P("soil", 2))]
    tris(g, -14.0, 14.0, -12.0, -1.6, 0.6, mud, 0.015)
    tris(g, -14.0, 14.0, 1.9, 7.0, 0.6, mud, 0.015)
    for k in range(40):  # loose stones break up the mud
        sx = h(k, 31) * 24.0 - 12.0
        sz = 2.1 + h(k, 37) * 4.0 if k % 2 else -1.8 - h(k, 37) * 2.0
        g.box((0.14, 0.1, 0.06), (sx, -sz, 0.03), P("slate", 2 if k % 3 else 1), rot_z=h(k, 41) * math.pi)
    # kerb stones along the road edges
    for ix in range(-28, 28):
        for z in (-1.65, 1.95):
            g.box((0.46, 0.18, 0.08), (ix * 0.5 + 0.25, -z, 0.03), P("slate", 3 if h(ix, z) > 0.5 else 2))
    return g.finish(col)


def timber_house(col, name, x, z, w=5.2, d=4.6, eave=3.6, ridge=5.6, banner=True):
    o = Obj(name)
    wall = [P("bone", 1), P("bone", 2), P("bone", 2), P("bone", 3)]
    base = [P("slate", 1), P("slate", 2), P("slate", 2)]
    o.box((w, d, 0.6), (x, z, 0.3), None, jitter=base)
    o.box((w - 0.1, d - 0.1, eave - 0.6), (x, z, 0.6 + (eave - 0.6) / 2), None, jitter=wall)
    fz = z - d / 2  # front face (toward the street is -Y in Blender = +Z in Godot after export)
    tb = P("timber", 1)
    for i in range(5):  # posts
        px = x - w / 2 + 0.1 + i * (w - 0.2) / 4
        o.box((0.18, 0.08, eave - 0.6), (px, fz - 0.02, 0.6 + (eave - 0.6) / 2), tb)
    for zz in (0.65, 2.05, eave - 0.1):  # rails
        o.box((w + 0.05, 0.1, 0.16), (x, fz - 0.03, zz), tb)
    for i in range(4):  # braces
        px = x - w / 2 + 0.1 + (i + 0.5) * (w - 0.2) / 4
        o.box((0.12, 0.06, 1.55), (px, fz - 0.03, 2.8), tb, rot_x=0.0)
    # door and windows
    o.box((0.95, 0.12, 1.75), (x - 1.2, fz - 0.03, 0.6 + 0.88), P("timber", 0))
    o.box((0.18, 0.13, 0.05), (x - 0.9, fz - 0.05, 1.45), P("iron", 2))
    for wx in (x + 0.7, x + 1.75):
        o.box((0.7, 0.1, 0.65), (wx, fz - 0.03, 1.55), P("soot", 1))
        o.box((0.36, 0.06, 0.7), (wx - 0.55, fz - 0.07, 1.55), P("timber", 2))
    for wx in (x - 1.2, x + 1.2):
        o.box((0.7, 0.1, 0.6), (wx, fz - 0.03, 2.75), P("soot", 1))
    # roof: two slopes with shingle rows
    roof = [P("timber", 0), P("timber", 1), P("soil", 1), P("timber", 1)]
    over = 0.45
    span = d / 2 + over
    rise = ridge - eave
    ang = math.atan2(rise, span)
    length = math.hypot(span, rise)
    rows = 6
    for side in (-1, 1):
        for r in range(rows):
            t = (r + 0.5) / rows
            cy = z + side * (span * (1 - t))
            cz = eave + rise * t - 0.05
            for c in range(7):
                seg = (w + 2 * over) / 7
                o.box((seg + 0.02, length / rows + 0.06, 0.09),
                      (x - w / 2 - over + (c + 0.5) * seg, cy, cz + (0.02 if (r + c) % 2 else 0.0)),
                      roof[int(h(r, c, side, x) * len(roof))], rot_x=side * ang)
    # gable ends
    for gx in (x - w / 2 + 0.05, x + w / 2 - 0.05):
        o.poly([(gx, z - d / 2 + 0.05, eave), (gx, z + d / 2 - 0.05, eave), (gx, z, ridge - 0.1)], P("bone", 1))
        o.poly([(gx, z + d / 2 - 0.05, eave), (gx, z - d / 2 + 0.05, eave), (gx, z, ridge - 0.1)], P("bone", 1))
    o.box((0.6, 0.6, 1.4), (x + w / 2 - 0.8, z + 0.6, ridge - 0.1), None, jitter=base)
    if banner:  # a faction banner on a pole bracket: a heraldic punch of colour
        o.box((0.06, 0.9, 0.06), (x + 0.2, fz - 0.45, 3.1), tb)
        o.box((0.62, 0.03, 1.0), (x + 0.2, fz - 0.85, 2.55), P("heraldry", 1))
        o.box((0.62, 0.035, 0.14), (x + 0.2, fz - 0.85, 2.3), P("heraldry", 2))
        o.box((0.14, 0.035, 0.5), (x + 0.2, fz - 0.85, 2.7), P("heraldry", 2))
    # torch bracket
    o.box((0.06, 0.35, 0.06), (x + 1.95, fz - 0.17, 2.2), P("iron", 1))
    o.cone(0.07, 0.04, 0.3, (x + 1.95, fz - 0.36, 2.3), P("timber", 0), segs=5)
    return o.finish(col)


def stone_house(col, name, x, z, w=4.6, d=4.4, eave=2.9, ridge=4.6):
    o = Obj(name)
    stone = [P("slate", 1), P("slate", 2), P("slate", 2), P("slate", 3), P("iron", 2)]
    rows = 7
    for r in range(rows):  # coursed stone, offset every other row
        hgt = eave / rows
        n = 6
        for c in range(n + (r % 2)):
            seg = w / n
            sx = x - w / 2 + seg * (c + 0.5) - (seg / 2 if r % 2 else 0)
            sx = min(max(sx, x - w / 2 + seg / 4), x + w / 2 - seg / 4)
            o.box((seg * (0.5 if r % 2 and c in (0, n) else 1.0) - 0.03, d, hgt - 0.03),
                  (sx, z, hgt * (r + 0.5)), stone[int(h(r, c, x) * len(stone))])
    fz = z - d / 2
    o.box((0.9, 0.12, 1.7), (x + 0.9, fz - 0.03, 0.85), P("timber", 1))
    o.box((1.1, 0.14, 0.18), (x + 0.9, fz - 0.04, 1.75), P("timber", 2))
    o.box((0.6, 0.1, 0.55), (x - 1.0, fz - 0.03, 1.5), P("soot", 0))
    o.box((0.75, 0.14, 0.12), (x - 1.0, fz - 0.05, 1.2), P("slate", 3))
    thatch = [P("timber", 2), P("timber", 3), P("soil", 3), P("timber", 2)]
    over = 0.5
    span = d / 2 + over
    rise = ridge - eave
    ang = math.atan2(rise, span)
    length = math.hypot(span, rise)
    for side in (-1, 1):
        for r in range(4):
            t = (r + 0.5) / 4
            for c in range(5):
                seg = (w + 2 * over) / 5
                o.box((seg + 0.03, length / 4 + 0.12, 0.22),
                      (x - w / 2 - over + (c + 0.5) * seg, z + side * span * (1 - t), eave + rise * t),
                      thatch[int(h(r, c, side) * len(thatch))], rot_x=side * ang)
    for gx in (x - w / 2 + 0.02, x + w / 2 - 0.02):
        o.poly([(gx, z - d / 2, eave), (gx, z + d / 2, eave), (gx, z, ridge - 0.15)], P("slate", 2))
        o.poly([(gx, z + d / 2, eave), (gx, z - d / 2, eave), (gx, z, ridge - 0.15)], P("slate", 2))
    return o.finish(col)


def well(col, x, z):
    o = Obj("well")
    stone = [P("slate", 1), P("slate", 2), P("slate", 3)]
    n = 10
    for i in range(n):
        a = i / n * math.tau
        o.box((0.42, 0.2, 0.75), (x + math.cos(a) * 0.62, z + math.sin(a) * 0.62, 0.375), None,
              rot_z=a + math.pi / 2, jitter=stone)
    o.cone(0.55, 0.55, 0.05, (x, z, 0.55), P("soot", 0), segs=10)
    for s in (-1, 1):
        o.box((0.12, 0.12, 1.6), (x + s * 0.72, z, 1.3), P("timber", 1))
    o.box((1.6, 0.1, 0.1), (x, z, 1.85), P("timber", 2))
    o.box((0.24, 0.24, 0.26), (x, z, 1.25), P("timber", 2))
    for s in (-1, 1):
        o.box((1.9, 0.75, 0.07), (x, z + s * 0.33, 2.12 - 0.12), P("timber", 0), rot_x=s * 0.55)
    return o.finish(col)


def cart(col, x, z, rot):
    o = Obj("cart")
    c, s = math.cos(rot), math.sin(rot)

    def at(px, py, pz):
        return (x + px * c - py * s, z + px * s + py * c, pz)
    o.box((2.0, 1.1, 0.1), at(0, 0, 0.75), P("timber", 2), rot_z=rot)
    for sy in (-1, 1):
        o.box((2.0, 0.08, 0.4), at(0, sy * 0.53, 0.98), P("timber", 1), rot_z=rot)
        o.cone(0.42, 0.42, 0.08, at(-0.1, sy * 0.66, 0.42), P("timber", 0), segs=8,
               rot=Matrix.Rotation(rot, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X"))
        o.cone(0.1, 0.1, 0.1, at(-0.1, sy * 0.71, 0.42), P("iron", 1), segs=6,
               rot=Matrix.Rotation(rot, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for sy in (-1, 1):
        o.box((1.5, 0.06, 0.06), at(1.6, sy * 0.35, 0.62), P("timber", 1), rot_z=rot)
    o.box((0.6, 0.5, 0.35), at(-0.3, 0.1, 0.98), P("bone", 1), rot_z=rot + 0.2)
    o.box((0.5, 0.45, 0.3), at(0.35, -0.15, 0.95), P("bone", 0), rot_z=rot - 0.1)
    return o.finish(col)


def barrels(col, pts):
    o = Obj("barrels")
    for i, (x, z) in enumerate(pts):
        o.cone(0.3, 0.3, 0.85, (x, z, 0.425), P("timber", 2 if i % 2 else 1), segs=8)
        for hz in (0.18, 0.67):
            o.cone(0.32, 0.32, 0.06, (x, z, hz), P("iron", 1), segs=8)
        o.cone(0.27, 0.27, 0.02, (x, z, 0.86), P("timber", 3), segs=8)
    return o.finish(col)


def fence(col, x0, x1, z):
    o = Obj("fence")
    n = int((x1 - x0) / 0.8)
    for i in range(n + 1):
        px = x0 + i * 0.8
        o.box((0.1, 0.1, 1.0 + 0.1 * h(i, 2)), (px, z, 0.5), P("timber", 1 + int(h(i, 3) * 2)))
    for zz in (0.4, 0.8):
        o.box((x1 - x0, 0.06, 0.1), ((x0 + x1) / 2, z - 0.06, zz), P("timber", 2))
    return o.finish(col)


def lantern_post(col, x, z):
    """A street lantern on a timber post at the road's edge: the night frame's torch hangs in it."""
    o = Obj("lantern_post")
    o.box((0.3, 0.3, 0.2), (x, z, 0.1), P("slate", 2))
    o.box((0.14, 0.14, 2.3), (x, z, 1.25), P("timber", 1))
    o.box((0.08, 0.5, 0.08), (x, z + 0.2, 2.3), P("timber", 1))
    o.box((0.24, 0.24, 0.05), (x, z + 0.45, 2.24), P("iron", 1))
    o.box((0.2, 0.2, 0.05), (x, z + 0.45, 1.88), P("iron", 1))
    for sx in (-1, 1):
        for sz in (-1, 1):
            o.box((0.025, 0.025, 0.36), (x + sx * 0.1, z + 0.45 + sz * 0.1, 2.06), P("soot", 1))
    return o.finish(col)


def street(col):
    ground(col)
    timber_house(col, "house_timber", -2.6, 6.2)
    stone_house(col, "house_stone", 3.6, 5.9)
    timber_house(col, "house_timber_far", -8.6, 6.6, w=4.8, ridge=5.4, banner=False)
    well(col, 3.3, 2.5)
    cart(col, -4.7, -1.2, 0.3)
    barrels(col, [(-0.2, 3.5), (0.45, 3.4), (0.15, 2.95)])
    fence(col, 5.9, 10.0, 3.6)
    lantern_post(col, 0.05, -1.75)


# ---------------------------------------------------------------- overworld

def tile_base(o, m_choices, y0=0.0, bump=0.0, n=4, rows=None):
    """A map tile's ground: faceted triangles at the tile's edge height y0 (edges stay flat so tiles meet).
    rows limits it to a band of the n rows along Y (the shore tile: water rows, then grass rows)."""
    s = TILE / n

    def y(x, z):
        edge = abs(x) >= TILE / 2 - 1e-4 or abs(z) >= TILE / 2 - 1e-4
        return y0 + (0.0 if edge else (h(round(x, 3), round(z, 3)) - 0.5) * bump)
    for i in range(n):
        for j in rows or range(n):
            x0, z0 = -TILE / 2 + i * s, -TILE / 2 + j * s
            a, b = (x0, z0, y(x0, z0)), (x0 + s, z0, y(x0 + s, z0))
            c, d = (x0 + s, z0 + s, y(x0 + s, z0 + s)), (x0, z0 + s, y(x0, z0 + s))
            for k, tri in enumerate(((a, b, c), (a, c, d)) if (i + j) % 2 else ((a, b, d), (b, c, d))):
                pick = h(i, j, k, len(m_choices))
                o.poly(list(tri), next(mm for t, mm in m_choices if pick < t))


def tree(o, x, z, k):
    if h(x, z, k) > 0.45:  # conifer
        o.cone(0.08, 0.08, 0.5, (x, z, 0.25), P("timber", 0), segs=4)
        o.cone(0.62, 0.0, 1.5, (x, z, 1.15), P("verdure", 1 if h(k, x) > 0.5 else 0), segs=6)
        o.cone(0.45, 0.0, 1.0, (x, z, 1.75), P("verdure", 2), segs=6)
    else:  # broadleaf
        o.cone(0.09, 0.07, 0.8, (x, z, 0.4), P("timber", 1), segs=4)
        o.cone(0.6, 0.35, 0.9, (x, z, 1.25), P("verdure", 2), segs=7)
        o.cone(0.35, 0.0, 0.45, (x, z, 1.9), P("verdure", 3), segs=7)


WATER = ("cloth_faded", 2)
WATER_Y = -0.04
BANK_VARIANTS = 3
WATER_FACETS = [(1.01, P(*WATER, flat=True))]
SHORE_VARIANTS = 3


def glints(o, n, seed, z_lo=-1.3, z_hi=1.3):
    """Short broken glints on water: each is two short dashes with a gap, nothing long or continuous."""
    for i in range(n):
        gx, gz = h(i, seed, 21) * 2.6 - 1.3, z_lo + h(i, seed, 22) * (z_hi - z_lo)
        for k in range(2):
            o.box((0.16 + 0.1 * h(i, k, 23), 0.04, 0.01), (gx + k * 0.32, gz + 0.04 * k, WATER_Y + 0.01),
                  P("slate", 2, flat=True))


def reeds(o, x, z, k, n):
    """A clump of rushes: thin cones, green and dry ochre."""
    for r in range(n):
        rx, rz = x + (h(k, r, 41) - 0.5) * 0.35, z + (h(k, r, 42) - 0.5) * 0.25
        tall = 0.3 + 0.3 * h(k, r, 43)
        m = P("verdure", 3) if h(k, r, 44) < 0.55 else P("timber", 3) if h(k, r, 44) < 0.8 else P("verdure", 1)
        o.cone(0.05, 0.0, tall, (rx, rz, tall / 2), m, segs=3)


def bank(o, v, e=TILE / 2, x_lo=-TILE / 2 - 0.15, x_hi=TILE / 2 + 0.15):
    """A shoreline along the line y = e from x_lo to x_hi (+Y is the land side): ragged wet mud that runs
    out into the water by a varying depth and back under the grass, and a few low rush clumps. Every
    water-tile edge that meets land gets one (Godot turns it to face the land), and the shore tile has one
    across its middle, so no shore is a ruler-straight line."""
    n = max(2, round((x_hi - x_lo) / 0.43))
    xs = [x_lo + k * (x_hi - x_lo) / n for k in range(n + 1)]
    out = [0.2 + 0.55 * h(v, k, 51) for k in range(n + 1)]  # into the water, metres from the line
    mid = [o_ * (0.35 + 0.3 * h(v, k, 52)) for k, o_ in enumerate(out)]
    land = [0.04 + 0.36 * h(v, k, 53) ** 2 for k in range(n + 1)]  # back under the grass
    for k in range(n):
        x0, x1 = xs[k], xs[k + 1]
        o.poly([(x0, e - out[k], 0.012), (x1, e - out[k + 1], 0.012), (x1, e - mid[k + 1], 0.012),
                (x0, e - mid[k], 0.012)], P("soil", 1))
        o.poly([(x0, e - mid[k], 0.014), (x1, e - mid[k + 1], 0.014), (x1, e + land[k + 1], 0.014),
                (x0, e + land[k], 0.014)], P("soil", 2))
    for c in range(2):
        k = int(h(v, c, 56) * n)
        reeds(o, xs[k] + 0.2, e - out[k] * 0.6, v * 10 + c, 3)


def overworld(col):
    grass = [(1.01, P("verdure", 2))]
    o = Obj("tile_plain")
    tile_base(o, grass)
    for i in range(9):  # tufts and stones break up the flat grass
        o.cone(0.22, 0.0, 0.3, (h(i, 1) * 3.6 - 1.8, h(i, 2) * 3.6 - 1.8, 0.15), P("verdure", 3 if i % 3 else 1), segs=4)
    o.box((0.18, 0.14, 0.08), (h(3, 5) * 3.0 - 1.5, h(4, 5) * 3.0 - 1.5, 0.04), P("slate", 3))
    o.finish(col)
    o = Obj("tile_road")
    tile_base(o, grass)
    for i in range(8):  # a rutted dirt road along the tile's X axis
        o.box((TILE / 8 + 0.01, 1.0, 0.04), (-TILE / 2 + (i + 0.5) * TILE / 8, 0.0, 0.03),
              P("soil", 2 if h(i, 7) > 0.4 else 3))
    o.finish(col)
    o = Obj("tile_road_ns")
    tile_base(o, grass)
    for i in range(8):
        o.box((1.0, TILE / 8 + 0.01, 0.04), (0.0, -TILE / 2 + (i + 0.5) * TILE / 8, 0.03),
              P("soil", 2 if h(i, 9) > 0.4 else 3))
    o.finish(col)
    o = Obj("tile_forest")
    tile_base(o, [(1.01, P("verdure", 1))])
    for i in range(7):
        tree(o, h(i, 11) * 3.0 - 1.5, h(i, 13) * 3.0 - 1.5, i)
    o.finish(col)
    o = Obj("tile_hill")
    n = 8
    s = TILE / n
    for i in range(n):
        for j in range(n):
            x0, z0 = -TILE / 2 + i * s, -TILE / 2 + j * s
            def y(x, z):
                r = math.hypot(x, z) / (TILE / 2)
                return (math.cos(math.pi * min(r, 1.0)) + 1.0) / 2.0 * 2.6 + (h(x, z) - 0.5) * 0.15 * (r < 0.9)
            pts = [(x0, z0, y(x0, z0)), (x0 + s, z0, y(x0 + s, z0)), (x0 + s, z0 + s, y(x0 + s, z0 + s)),
                   (x0, z0 + s, y(x0, z0 + s))]
            top = (y(x0, z0) + y(x0 + s, z0 + s)) / 2
            for tri in ((pts[0], pts[1], pts[2]), (pts[0], pts[2], pts[3])):
                nrm = (Vector(tri[1]) - Vector(tri[0])).cross(Vector(tri[2]) - Vector(tri[0])).normalized()
                lit = nrm.dot(HILL_LIGHT)  # pixel-art hills: the slope's colour step is painted, not left to the sun
                m = (P("slate", 2) if top > 2.2 else P("verdure", 3) if lit > 0.9 else
                     P("verdure", 2) if lit > 0.7 else P("verdure", 1))
                o.poly(list(tri), m)
    o.box((0.6, 0.45, 0.35), (0.7, -0.5, 1.15), P("slate", 3), rot_z=0.4)
    o.finish(col)
    # Peat water: the palette's one blue-slate (cloth_faded 2), unlit so the warm sun cannot turn it
    # brown-grey, a little below the land; a few short broken glints, never one long line (a long pale
    # line read as a lane marking, and the whole as a road).
    o = Obj("tile_water")
    tile_base(o, WATER_FACETS, y0=WATER_Y, n=4)
    glints(o, 3, 0)
    o.finish(col)
    for v in range(SHORE_VARIANTS):
        o = Obj(f"tile_shore_{v}")  # water on the -Y half, grass on +Y, a ragged bank between
        tile_base(o, WATER_FACETS, y0=WATER_Y, n=4, rows=range(2))
        tile_base(o, grass, n=4, rows=range(2, 4))
        glints(o, 1, 5 + v, z_lo=-1.6, z_hi=-0.6)
        bank(o, 9 + v, e=0.0)
        o.finish(col)
    for v in range(BANK_VARIANTS):  # the edge of a water tile whose neighbour is land (Godot turns it)
        o = Obj(f"bank_{v}")
        bank(o, v)
        o.finish(col)
    for name, lo, hi in (("bank_half_pos", 0.0, TILE / 2 + 0.15), ("bank_half_neg", -TILE / 2 - 0.15, 0.0)):
        o = Obj(name)  # beside a shore tile: only its grass half needs a bank
        bank(o, 7, x_lo=lo, x_hi=hi)
        o.finish(col)
    # town marker: a walled hamlet with a hall and a tower, at map scale
    o = Obj("marker_town")
    for k in range(9):  # trodden earth inside the palisade
        a = k / 9 * math.tau
        o.box((1.2, 1.2, 0.02), (math.cos(a) * 0.8, math.sin(a) * 0.8, 0.01), P("soil", 2), rot_z=a)
    for k in range(20):
        a = k / 20 * math.tau
        o.box((0.18, 0.18, 0.8 + 0.15 * h(k, 4)), (math.cos(a) * 1.75, math.sin(a) * 1.75, 0.45), P("timber", 1))
    for (hx, hz, w, d, hh, rot) in ((-0.75, 0.55, 1.2, 0.9, 0.9, 0.2), (0.55, 0.75, 1.0, 0.8, 0.8, -0.3),
                                     (0.0, -0.45, 1.5, 1.0, 1.0, 0.0), (-0.95, -0.6, 0.8, 0.8, 0.7, 0.5)):
        o.box((w, d, hh), (hx, hz, hh / 2), None, rot_z=rot, jitter=[P("bone", 2), P("bone", 1)])
        o.cone(max(w, d) * 0.78, 0.0, 0.8, (hx, hz, hh + 0.4), P("timber", 1), segs=4,
               rot=Matrix.Rotation(rot + math.pi / 4, 4, "Z"))
    o.cone(0.45, 0.4, 2.6, (1.1, -0.7, 1.3), P("slate", 2), segs=6)
    o.cone(0.55, 0.0, 0.9, (1.1, -0.7, 3.05), P("slate", 1), segs=6)
    o.box((0.04, 0.04, 1.0), (1.1, -0.7, 3.8), P("timber", 0))
    o.box((0.6, 0.03, 0.4), (1.4, -0.7, 4.05), P("heraldry", 1))
    o.finish(col)
    # a banner pole carried beside a map token (band and party), heraldry swapped in Godot by name
    for name, main, trim in (("marker_banner_band", ("heraldry", 2), ("soot", 0)),
                             ("marker_banner_party", ("heraldry", 3), ("heraldry", 4))):
        o = Obj(name)
        o.box((0.08, 0.08, 3.4), (0, 0, 1.7), P("timber", 1))
        o.box((1.1, 0.04, 0.85), (0.57, 0, 2.9), P(*main))
        o.box((1.1, 0.045, 0.16), (0.57, 0, 2.5), P(*trim))
        o.finish(col)


def export(collection, path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in collection.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT")
    print("EXPORTED", path)


def main() -> None:
    out = args()
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.data.collections.new("street")
    bpy.context.scene.collection.children.link(s)
    street(s)
    w = bpy.data.collections.new("overworld")
    bpy.context.scene.collection.children.link(w)
    overworld(w)
    export(s, out / "street_kit.glb")
    export(w, out / "overworld_kit.glb")
    print("KIT_OK")


main()
