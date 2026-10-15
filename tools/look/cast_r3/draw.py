"""Polygon painter over px.Sheet: hand-placed shapes, plane shading lit from camera-left."""
import numpy as np

SCALE = 1.0   # token pass: the sheet's shapes drawn at half size

def inside(pts):
    """Pixels whose centre is inside the polygon (even-odd)."""
    pts = [(x * SCALE, y * SCALE) for x, y in pts]
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    out = []
    n = len(pts)
    for y in range(int(min(ys)), int(max(ys)) + 1):
        cy = y + 0.5
        for x in range(int(min(xs)), int(max(xs)) + 1):
            cx = x + 0.5; c = False
            for i in range(n):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
                if (y0 > cy) != (y1 > cy) and cx < x0 + (cy - y0) * (x1 - x0) / (y1 - y0):
                    c = not c
            if c: out.append((x, y))
    return out

def fill(s, f, pts, ch):
    for x, y in inside(pts): s.put(f, x, y, ch)

def clear(s, f, pts):
    fill(s, f, pts, '.')

def shade(s, f, pts, tones, cuts, axis='x', flip=False, only=None):
    """Fill the polygon; per row (axis x) or column (axis y) u = 0 at the lit edge .. 1 at the far edge;
    tones[i] where u < cuts[i] (cuts ascending, last tone takes the rest). flip: lit edge on the right/bottom."""
    px = inside(pts)
    if only is not None: px = [p for p in px if s.get(f, *p) in only]
    rows = {}
    for x, y in px:
        k = y if axis == 'x' else x
        rows.setdefault(k, []).append(x if axis == 'x' else y)
    for x, y in px:
        k, v = (y, x) if axis == 'x' else (x, y)
        lo, hi = min(rows[k]), max(rows[k])
        u = 0.5 if hi == lo else (v - lo) / (hi - lo)
        if flip: u = 1 - u
        t = tones[-1]
        for tone, c in zip(tones, cuts):
            if u < c: t = tone; break
        s.put(f, x, y, t)

def line(s, f, p0, p1, ch):
    (x0, y0), (x1, y1) = [(round(x * SCALE), round(y * SCALE)) for x, y in (p0, p1)]
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        s.put(f, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), ch)

def recolour(s, f, pts, mapping):
    for x, y in inside(pts):
        c = s.get(f, x, y)
        if c in mapping: s.put(f, x, y, mapping[c])

LIGHT = (-0.55, -0.45, 0.70)   # key from camera-left, above, toward the viewer (06 section 3)

def form(pts, ky=0.35, kx=1.0):
    """Per pixel of the polygon: Lambert of a rounded volume (per-row u, per-column v), plus the normal."""
    px = inside(pts)
    rows, cols = {}, {}
    for x, y in px:
        rows.setdefault(y, []).append(x); cols.setdefault(x, []).append(y)
    L = np.array(LIGHT) / np.linalg.norm(LIGHT)
    out = {}
    for x, y in px:
        r, c = rows[y], cols[x]
        u = 0.0 if max(r) == min(r) else 2 * (x + 0.5 - min(r)) / (max(r) + 1 - min(r)) - 1
        v = 0.0 if max(c) == min(c) else 2 * (y + 0.5 - min(c)) / (max(c) + 1 - min(c)) - 1
        n = np.array([kx * u, ky * v, 0.0]); n[2] = np.sqrt(max(0.05, 1 - n[0] ** 2 - n[1] ** 2))
        n /= np.linalg.norm(n)
        out[(x, y)] = (float(n @ L), n)
    return out

def shade3d(s, f, pts, tones, thr, ky=0.35, kx=1.0, only=None, normals=None):
    """tones lit->dark, thr descending Lambert cut-offs (len(tones)-1). normals: dict to record the volume normal."""
    for (x, y), (d, n) in form(pts, ky, kx).items():
        if only is not None and s.get(f, x, y) not in only: continue
        t = tones[-1]
        for tone, c in zip(tones, thr):
            if d >= c: t = tone; break
        if normals is not None: normals[(f, x, y)] = n
        s.put(f, x, y, t)
