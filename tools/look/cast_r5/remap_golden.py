"""Goldens, round 5 (PR #118). Run from the repo root: python tools/look/cast_r5/remap_golden.py

1. Overworld grass (critic r4, lead 2026-10-16): rebuilt from main's approved golden (commit 8cdb0ba), not from
   round 4. The lit grass there is a dither of the old skin_orc 1 (66,74,38) with verdure_2; that field (the
   dither found by its neighbours, closed by 4 px) becomes flat verdure_mid_0 #40501d (CIEDE2000 4.4 from the
   old colour; the grass step the director approved on 2026-10-16). The old skin_orc 0 (40,48,22), the dither
   partner in the shade, takes verdure_0 only inside deep shade (2+ verdure_0 neighbours) and verdure_1
   everywhere else, so no tuft or cast-shadow edge gets a dark rim. Other old skin_orc pixels outside the orc
   go to their nearest verdure step (as round 3).
2. The orc figures (overworld and both streets) keep their round-4 pixels with the skin moved to the round-5
   skin_orc ramp by index (only the orc figures use skin_orc)."""
import subprocess
import numpy as np
from PIL import Image
from pal import load, dE, R
P = load()
OLD = [(40,48,22),(66,74,38),(94,102,55),(124,131,73),(155,161,92)]          # skin_orc on main (8cdb0ba)
R4 = [(0x2e,0x34,0x28),(0x48,0x52,0x40),(0x6e,0x80,0x6f),(0x8d,0x9b,0x80),(0xb2,0xbc,0x9c)]   # round 4
NEW = [P[f'skin_orc_{i}'] for i in range(5)]
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

def skin_r4_to_r5(rgb):
    for i, c in enumerate(R4): rgb[eq(rgb, c)] = NEW[i]

def overworld(main_png, r4_png):
    a = np.array(Image.open(main_png).convert('RGB')); r4 = np.array(Image.open(r4_png).convert('RGB'))
    fig = figure_mask(a)
    o0, o1, v0, v1, v2 = eq(a, OLD[0]), eq(a, OLD[1]), eq(a, VER[0]), eq(a, VER[1]), eq(a, VER[2])
    chk = (o1 & (nsum(v2) >= 3)) | (v2 & (nsum(o1) >= 3))
    field = grow(grow(chk, 4, lambda *m: np.logical_or.reduce(m)), 4, lambda *m: np.logical_and.reduce(m))
    field &= (o1 | v2) & ~fig
    out = a.copy()
    out[field] = MID
    rest1 = o1 & ~field & ~fig
    near_field = nsum(field) > 0
    out[rest1 & (near_field | (nsum(v1) < 3))] = MID
    out[rest1 & ~near_field & (nsum(v1) >= 3)] = VER[1]
    deep = nsum(v0) >= 2
    out[o0 & ~fig & deep] = VER[0]
    out[o0 & ~fig & ~deep] = VER[1]
    for c in OLD[2:]:
        g = min(range(5), key=lambda k: dE(c, VER[k])); out[eq(a, c) & ~fig] = VER[g]
    fr = r4.copy(); skin_r4_to_r5(fr); out[fig] = fr[fig]
    return out, int(field.sum())

if __name__ == '__main__':
    import io
    main = io.BytesIO(subprocess.run(['git', 'show', '8cdb0ba:assets/golden/overworld_map.png'], cwd=R,
                                     capture_output=True, check=True).stdout)
    path = R + 'assets/golden/overworld_map.png'
    im = Image.open(path); mode = im.mode
    out, n = overworld(main, path)
    Image.fromarray(out).convert(mode).save(path); print('overworld field px', n)
    for name in ('street_day', 'street_rain_night'):
        p = R + f'assets/golden/{name}.png'; im = Image.open(p); mode = im.mode
        a = np.array(im.convert('RGBA')); rgb = a[..., :3]; skin_r4_to_r5(rgb); a[..., :3] = rgb
        Image.fromarray(a, 'RGBA').convert(mode).save(p); print(name, 'done')
