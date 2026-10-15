"""Skin-vs-grass table: CIEDE2000 of each skin_orc step against the grass colours (round 6 lead rule, see main).
Run from anywhere."""
import math, sys
from collections import Counter
import numpy as np
from PIL import Image
from pal import load, lab, dE, R
P = load()
def de2000(c1, c2):
    L1, a1, b1 = lab(c1); L2, a2, b2 = lab(c2)
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2); Cb = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cb**7 / (Cb**7 + 25**7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1 = math.degrees(math.atan2(b1, a1p)) % 360; h2 = math.degrees(math.atan2(b2, a2p)) % 360
    dL, dC = L2 - L1, C2p - C1p
    dh = 0 if C1p * C2p == 0 else (h2 - h1 if abs(h2 - h1) <= 180 else h2 - h1 - 360 if h2 > h1 else h2 - h1 + 360)
    dH = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dh / 2))
    Lb, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    hb = h1 + h2 if C1p * C2p == 0 else ((h1 + h2) / 2 if abs(h1 - h2) <= 180 else (h1 + h2 + 360) / 2 if h1 + h2 < 360 else (h1 + h2 - 360) / 2)
    T = 1 - .17*math.cos(math.radians(hb-30)) + .24*math.cos(math.radians(2*hb)) + .32*math.cos(math.radians(3*hb+6)) - .2*math.cos(math.radians(4*hb-63))
    SL = 1 + .015*(Lb-50)**2/math.sqrt(20+(Lb-50)**2); SC = 1 + .045*Cbp; SH = 1 + .015*Cbp*T
    RT = -2*math.sqrt(Cbp**7/(Cbp**7+25**7))*math.sin(math.radians(60*math.exp(-((hb-275)/25)**2)))
    return math.sqrt((dL/SL)**2 + (dC/SC)**2 + (dH/SH)**2 + RT*(dC/SC)*(dH/SH))
GRASS = {k: v for k, v in P.items() if k.startswith('verdure')}
GRASS['verdure_mid_0'] = (0x40, 0x50, 0x1d); GRASS['soil_2'] = P['soil_2']
def used(path, w=176):
    a = np.array(Image.open(path).convert('RGBA'))
    c = Counter(tuple(int(v) for v in p[:3]) for p in a.reshape(-1, 4) if p[3])
    return {i: c.get(P[f'skin_orc_{i}'], 0) for i in range(5)}
MASS = ['verdure_mid_0', 'verdure_2']             # the grass mass (B8 grass.png: mid_0 96.3%)
TUFTS = ['verdure_1', 'verdure_3', 'verdure_4']    # the tufts (1.5%, 0.8%, 0.8%)
def lch(c):
    L, a, b = lab(c); return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360
if __name__ == '__main__':
    # round 6 lead rule (2026-10-16): the face-mass step 2 needs CIEDE2000 >= 15 vs the grass mass and >= 10 vs the
    # tufts, chroma >= 20, a mossy hue of about 110-125; steps 0-1 stay inside the face (orc_paint.guard_dark).
    sheets = sys.argv[1:]
    use = [used(s) for s in sheets]
    cols = MASS + TUFTS + ['verdure_0']
    print('| step | hex | L, C, hue | px used (' + ', '.join(s.split('/')[-1] for s in sheets) + ') | ' +
          ' | '.join(cols) + ' | iron_2 | iron_3 | rule |')
    print('|---' * (6 + len(cols)) + '|')
    for i in range(5):
        c = P[f'skin_orc_{i}']; L, C, h = lch(c)
        d = {k: de2000(c, GRASS[k]) for k in cols}
        ok = min(d[k] for k in MASS) >= 15 and min(d[k] for k in TUFTS) >= 10
        if i == 2: ok = ok and C >= 20 and 110 <= h <= 125
        print(f'| {i} | #{c[0]:02x}{c[1]:02x}{c[2]:02x} | {L:.1f}, {C:.1f}, {h:.0f} | {" / ".join(str(u[i]) for u in use)} | '
              + ' | '.join(f'{d[k]:.1f}' for k in cols)
              + f' | {de2000(c, P["iron_2"]):.1f} | {de2000(c, P["iron_3"]):.1f} | {"pass" if ok else "fails (inside the face only)" if i < 2 else "FAIL"} |')
    print('grass:', ', '.join(f'{k} L%.1f C%.1f h%.0f' % lch(GRASS[k]) for k in cols))
    print('tusk bone_3 vs skin 2/3/4 dE2000:', [round(de2000(P['bone_3'], P[f'skin_orc_{i}']), 1) for i in (2, 3, 4)])
