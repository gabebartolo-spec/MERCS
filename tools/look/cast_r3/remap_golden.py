"""Golden remap for the grey-olive skin_orc (director 2026-10-16, option A): grass pixels in the old skin_orc
colours go to their nearest verdure step (CIE76); pixels inside the orc figure's outline follow the new ramp by index."""
import numpy as np
from collections import deque
from PIL import Image
from pal import load, dE, R
P = load()   # already the new palette
OLD = [(40,48,22),(66,74,38),(94,102,55),(124,131,73),(155,161,92)]
NEW = [P[f'skin_orc_{i}'] for i in range(5)]
VER = [P[f'verdure_{i}'] for i in range(5)]
SOOT0 = P['soot_0']
BOXES = {'overworld_map': [(578,158,606,219)], 'street_day': [(375,370,455,535)], 'street_rain_night': [(375,370,455,535)]}
WALL = [P[k] for k in P if k.startswith(('soot_0', 'iron', 'slate', 'bone'))]
def figure_mask(a, box):
    """Per row of the figure's box: everything between the first and last outline/plate pixel."""
    x0,y0,x1,y1 = box
    sub = a[y0:y1, x0:x1]
    wall = np.zeros(sub.shape[:2], bool)
    for c in WALL: wall |= (sub == c).all(-1)
    m = np.zeros(a.shape[:2], bool)
    for y in range(y1 - y0):
        xs = np.nonzero(wall[y])[0]
        if len(xs) >= 2: m[y0 + y, x0 + xs.min():x0 + xs.max() + 1] = True
    return m
def run(name, src, dst):
    im = Image.open(src); mode = im.mode
    a = np.array(im.convert('RGBA')); rgb = a[..., :3]
    fig = np.zeros(a.shape[:2], bool)
    for b in BOXES[name]: fig |= figure_mask(rgb, b)
    stats = {}
    for i, c in enumerate(OLD):
        m = (rgb == c).all(-1)
        g = min(range(5), key=lambda k: dE(c, VER[k]))
        rgb[m & fig] = NEW[i]; rgb[m & ~fig] = VER[g]
        stats[i] = (int((m & fig).sum()), int((m & ~fig).sum()), f'verdure_{g}', round(dE(c, VER[g]), 1))
    a[..., :3] = rgb; Image.fromarray(a, 'RGBA').convert(mode).save(dst); return stats
if __name__ == '__main__':
    import sys
    for n in BOXES:
        print(n, run(n, sys.argv[1] + f'/{n}.png', R + f'assets/golden/{n}.png'))
