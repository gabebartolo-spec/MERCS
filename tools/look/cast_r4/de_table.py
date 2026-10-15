"""Skin-vs-grass table: CIE76 and CIEDE2000 of each skin_orc step against every grass colour (lead rule:
CIEDE2000 >= 12 and dE76 >= 15 for colours used on the figure). Run from anywhere."""
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
if __name__ == '__main__':
    sheets = sys.argv[1:]
    use = [used(s) for s in sheets]
    print('| step | rgb | px used (' + ', '.join(s.split('/')[-1] for s in sheets) + ') | worst dE76 (vs) | worst dE2000 (vs) | rule |')
    print('|---|---|---|---|---|---|')
    for i in range(5):
        c = P[f'skin_orc_{i}']
        d76 = min((dE(c, g), k) for k, g in GRASS.items()); d00 = min((de2000(c, g), k) for k, g in GRASS.items())
        ok = d76[0] >= 15 and d00[0] >= 12
        print(f'| {i} | {c} | {" / ".join(str(u[i]) for u in use)} | {d76[0]:.1f} ({d76[1]}) | {d00[0]:.1f} ({d00[1]}) | {"pass" if ok else "FAIL"} |')
    print('vs verdure_mid_0:', ', '.join(f'{i}: {dE(P[f"skin_orc_{i}"], GRASS["verdure_mid_0"]):.1f}/{de2000(P[f"skin_orc_{i}"], GRASS["verdure_mid_0"]):.1f}' for i in range(5)))
    print('tusk bone_3 vs skin 2/3/4 dE76:', [round(dE(P['bone_3'], P[f'skin_orc_{i}']), 1) for i in (2, 3, 4)])
