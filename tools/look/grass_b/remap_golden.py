"""Overworld golden: the new grass (director picked grass B, 2026-10-16 09:47). Run from the repo root:
python tools/look/grass_b/remap_golden.py   (reads the golden on main, commit 8cdb0ba; rerun is identical)

From PR #118's cast_r7 remap, grass part only. The lit grass (the old skin_orc 1 (66,74,38) / verdure_2
dither, found by its neighbours) and every other (66,74,38) pixel outside the orc become flat verdure_mid_0
#40501d; every old skin_orc 0 (40,48,22) outside the orc becomes verdure_0 (main's forest-floor dither
survives); the other old skin_orc steps outside the orc go to the nearest verdure step. The orc's box keeps
main's pixels, skin included. The street goldens are not touched."""
import subprocess
import numpy as np
from PIL import Image
from pal import load, dE, R
P = load()
OLD = [(40,48,22),(66,74,38),(94,102,55),(124,131,73),(155,161,92)]          # skin_orc on main (8cdb0ba)
VER = [P[f'verdure_{i}'] for i in range(5)]
MID = P['verdure_mid_0']
BOX = (578, 158, 606, 219)
WALL = [P[k] for k in P if k.startswith(('soot_0', 'iron', 'slate', 'bone'))]
N4 = ((0,1),(0,-1),(1,0),(-1,0))

def sh(m, dy, dx):
    o = np.zeros_like(m); H, W = m.shape
    o[max(dy,0):H+min(dy,0), max(dx,0):W+min(dx,0)] = m[max(-dy,0):H+min(-dy,0), max(-dx,0):W+min(-dx,0)]
    return o
def nsum(m): return sum(sh(m, dy, dx).astype(int) for dy, dx in N4)
def grow(m, n, op):
    for _ in range(n): m = op(m, *[sh(m, dy, dx) for dy, dx in N4])
    return m
def eq(rgb, c): return (rgb == c).all(-1)

def figure_mask(rgb):
    """Per row of the orc's box: everything between the first and last outline/plate pixel (as round 3)."""
    x0, y0, x1, y1 = BOX
    sub = rgb[y0:y1, x0:x1]; wall = np.zeros(sub.shape[:2], bool)
    for c in WALL: wall |= eq(sub, c)
    m = np.zeros(rgb.shape[:2], bool)
    for y in range(y1 - y0):
        xs = np.nonzero(wall[y])[0]
        if len(xs) >= 2: m[y0 + y, x0 + xs.min():x0 + xs.max() + 1] = True
    return m


def overworld(main_png):
    a = np.array(Image.open(main_png).convert('RGB'))
    fig = figure_mask(a)
    o0, o1, v0, v1, v2 = eq(a, OLD[0]), eq(a, OLD[1]), eq(a, VER[0]), eq(a, VER[1]), eq(a, VER[2])
    chk = (o1 & (nsum(v2) >= 3)) | (v2 & (nsum(o1) >= 3))
    field = grow(grow(chk, 4, lambda *m: np.logical_or.reduce(m)), 4, lambda *m: np.logical_and.reduce(m))
    field &= (o1 | v2) & ~fig
    out = a.copy()
    out[field] = MID
    out[o1 & ~field & ~fig] = MID
    out[o0 & ~fig] = VER[0]
    for c in OLD[2:]:
        g = min(range(5), key=lambda k: dE(c, VER[k])); out[eq(a, c) & ~fig] = VER[g]
    return out, int(field.sum())

if __name__ == '__main__':
    import io
    main = io.BytesIO(subprocess.run(['git', 'show', '8cdb0ba:assets/golden/overworld_map.png'], cwd=R,
                                     capture_output=True, check=True).stdout)
    path = R + 'assets/golden/overworld_map.png'
    mode = Image.open(path).mode
    out, n = overworld(main)
    Image.fromarray(out).convert(mode).save(path); print('overworld field px', n)
