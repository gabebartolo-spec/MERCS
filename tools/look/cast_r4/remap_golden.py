"""Goldens, round 4 (PR #118). Run from the repo root: python tools/look/cast_r4/remap_golden.py

1. The orc figures' skin follows the green-grey skin_orc ramp (director 2026-10-16, "bulk and green-grey
   skin"): every pixel in a round-3 skin_orc colour takes the new colour of the same index (only the orc
   figures use skin_orc; look_target.gd keeps it out of world snapping).
2. Overworld grass (lead call, 2026-10-16): the lit grass was a verdure_1/verdure_2 checker dither, a
   screen-door grain at 2x. Each pixel of that field takes ONE flat colour, the verdure step nearest luma 71
   (verdure_2). The field is the checker found by its neighbours (a pair pixel whose 4 neighbours are all the
   other colour), closed by 4 px so tufts and gaps inside it are covered; forest canopies and the flat
   shadow grass outside it keep their pixels. A stop-gap: the golden is re-rendered with the final B7 tiles."""
import sys
import numpy as np
from PIL import Image
from pal import load, R
P = load()
R3 = [(0x37,0x33,0x1e),(0x57,0x52,0x36),(0x78,0x72,0x50),(0x9c,0x95,0x6c),(0xc1,0xb9,0x89)]   # round-3 skin_orc
NEW = [P[f'skin_orc_{i}'] for i in range(5)]
VER = [P[f'verdure_{i}'] for i in range(5)]
LUMA = lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
FLAT = min(range(5), key=lambda i: abs(LUMA(VER[i]) - 71))

def sh(m, dy, dx):
    o = np.zeros_like(m); H, W = m.shape
    o[max(dy,0):H+min(dy,0), max(dx,0):W+min(dx,0)] = m[max(-dy,0):H+min(-dy,0), max(-dx,0):W+min(-dx,0)]
    return o
N4 = ((0,1),(0,-1),(1,0),(-1,0))
def grow(m, n, op):
    for _ in range(n):
        m = op(m, *[sh(m, dy, dx) for dy, dx in N4])
    return m

def grass_field(rgb):
    v1 = (rgb == VER[1]).all(-1); v2 = (rgb == VER[2]).all(-1)
    n1 = sum(sh(v1, dy, dx).astype(int) for dy, dx in N4); n2 = sum(sh(v2, dy, dx).astype(int) for dy, dx in N4)
    chk = (v1 & (n2 == 4)) | (v2 & (n1 == 4))
    field = grow(grow(chk, 4, lambda *a: np.logical_or.reduce(a)), 4, lambda *a: np.logical_and.reduce(a))
    return field & (v1 | v2)

def run(name):
    path = R + f'assets/golden/{name}.png'
    im = Image.open(path); mode = im.mode
    a = np.array(im.convert('RGBA')); rgb = a[..., :3]
    stats = {}
    for i, c in enumerate(R3):
        m = (rgb == c).all(-1); rgb[m] = NEW[i]; stats[f'skin_orc_{i}'] = int(m.sum())
    if name == 'overworld_map':
        g = grass_field(rgb); rgb[g] = VER[FLAT]; stats[f'grass->verdure_{FLAT}'] = int(g.sum())
    a[..., :3] = rgb
    Image.fromarray(a, 'RGBA').convert(mode).save(path)
    return stats

if __name__ == '__main__':
    for n in ('overworld_map', 'street_day', 'street_rain_night'):
        print(n, run(n))
