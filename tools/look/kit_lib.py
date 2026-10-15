"""Shared pieces of the look-target kit builders (Blender): the deterministic hash, the bmesh
builder whose faces carry palette material names, and the palette face name."""
from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix, Vector


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
