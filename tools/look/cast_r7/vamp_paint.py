"""Vampyr round 6 (from round 5; critic r5): the S/SE/SW breastplate tapers to the waist and is shaded in planes
(`breastplate`: iron 0 only as the far-edge core shadow and under the plackart line), three fauld lames below it
(`fauld`), the lining between arm and body as cape folds (`lining_folds`); the E/W jaw blob becomes a jaw line
(`jaw_line`); the N slit between arm and cape is filled. Round 5's straight ridge (`cuirass`) is no longer used.

Round 5 (from round 4: his own armour, not the orc's).

Round 5 (critic r4): the armour one step darker (iron 1 mass, iron 2 lit, iron 0 shadow); the S/SE/SW cuirass
has a medial ridge (iron 2) between a lit plane (iron 1) and a shadow plane (iron 0); the cape's lining shows
3-4 px wide down both sides of the body from the shoulder to the hem (cloth red, shadow step), so he reads
as a caped lord from the front; the N cape folds start at the blades, widen toward the hem and stop at
different heights.


Slim sloped spaulders that follow the shoulder line (at most 2-3 px past the arm), a narrow waist over two
small tassets (no fauld box), the S face closed by the collar in iron 0 (no soot rings), and a cape whose
2-3 folds fan from the shoulder blades and widen to the hem, with an uneven hem that follows the folds.
S, SE, NE, N and their mirrors are clipped to the round-2 alpha grown by 1 px (the slim round-2 width)."""
import sys
import numpy as np
from PIL import Image
import draw
import orc_paint as op
from orc_paint import ink, keep_head, mirrored, chin_dots, mirror, ID, Mirror
from draw import clear, line, fill, inside
from vamp_global import vamp_global, O
BL = ['2', '1', '0']                 # blackened plate: lit, mid, shadow
CA = ['s', 'r']                      # cape: lit, shadow (red ramp only)
SK = ['D', 'C']
T3 = [0.9, 0.45]
VMASK = {}

def load_masks(path=None):
    a = np.array(Image.open(path or O + 'orig/vampyr_look_heartland.png').convert('RGBA'))
    for f in range(8):
        m = a[:, f * 176:(f + 1) * 176, 3] > 0
        g = m.copy()
        g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
        VMASK[f] = g

def part(s, f, pts, tones=BL, thr=T3, ky=0.35, only=None):
    op.part(s, f, pts, tones, thr, ky=ky, only=only)

def clip(s, f, mf):
    M = VMASK[mf]
    for y in range(176):
        for x in range(176):
            if not M[y, x] and s.get(f, x, y) != '.': s.put(f, x, y, '.')

def cape(s, f, outline, folds, only=None, lit=0.8):
    """Cape: shadow red base, then each fold a lit wedge (lit side toward the key) that widens to the hem."""
    part(s, f, outline, CA, [lit], ky=0.2, only=only)
    for fo in folds:
        part(s, f, fo, ['s', 's', 'r'], [0.2, -0.3], ky=0.1, only=only)

def fold(top, x0, x1, hem):
    """A fold: from a 2 px top at the blades to a band x0..x1 at the hem (it may lean out: a fan)."""
    tx, ty = top
    return [(tx, ty), (tx + 2, ty), (x1, hem), (x0, hem)]

def cuirass(s, f, pts, ridge):
    """Medial ridge (iron 2, 1 px along the polyline ridge) between the lit plane (iron 1, key side) and the
    shadow plane (iron 0) of the cuirass polygon."""
    lit_left = draw.LIGHT[0] < 0
    rx = {}
    for (x0, y0), (x1, y1) in zip(ridge, ridge[1:]):
        for y in range(y0, y1 + 1): rx[y] = round(x0 + (x1 - x0) * (y - y0) / max(1, y1 - y0))
    for x, y in inside(pts):
        if s.get(f, x, y) not in '0123' or y not in rx: continue
        c = '2' if x == rx[y] else ('1' if (x < rx[y]) == lit_left else '0')
        s.put(f, x, y, c)

def lining(s, f, pts):
    """The cape's inner lining seen at the front: cloth red in shadow (cloth_faded 0)."""
    fill(s, f, pts, 'r')

def lining_folds(s, f, pts, folds):
    """Round 6 (critic r5): the lining shows as cape folds behind the arms: cloth red in shadow (cloth_faded 0)
    with lit fold wedges (cloth_faded 1) that start narrow under the arm and widen to the hem."""
    fill(s, f, pts, 'r')
    for fo in folds: fill(s, f, fo, 's')

PLATE_N = {'lit': (-0.45, -0.35, 0.82), 'mid': (0.15, 0.0, 0.99), 'low': (-0.1, 0.25, 0.96),
           'edge': (0.75, 0.0, 0.66), 'line': (0.0, -0.6, 0.8), 'under': (0.0, 0.7, 0.71)}

def _plate_put(s, f, x, y, c, n):
    s.put(f, x, y, c)
    op.NRM[(f, x, y)] = np.array(PLATE_N[n]) / np.linalg.norm(PLATE_N[n])

def breastplate(s, f, y0, y1, top, waist, cx, arc_top, arc_side, edge=2):
    """Round 6 (critic r5: plate, not a slot). Tapers from top=(xl, xr) at row y0+3 to waist=(xl, xr) at row y1.
    Planes from the key: the lit upper chest iron 2, the far upper chest iron 1; a curved 1-px iron 2 plackart
    line (arc_top at cx, arc_side at the edges) with iron 0 under it on the far side only; the lower chest iron 1;
    iron 0 only as a 2-px core shadow along the far edge."""
    lit_left = draw.LIGHT[0] < 0
    ref = y0 + 3
    for y in range(y0, y1 + 1):
        t = min(1.0, max(0.0, (y - ref) / (y1 - ref)))
        xl = round(top[0] + (waist[0] - top[0]) * t); xr = round(top[1] + (waist[1] - top[1]) * t)
        if y < ref: xl, xr = xl - (ref - y), xr + (ref - y)      # the chest widens into the shoulders
        for x in range(xl, xr + 1):
            half = (cx - xl) if x < cx else (xr - cx)
            u = abs(x - cx) / max(1, half)
            ay = arc_top + round((arc_side - arc_top) * u * u)
            near = (x < cx) == lit_left
            far_edge = (x > xr - edge) if lit_left else (x < xl + edge)
            if y == ay: c, n = '2', 'line'
            elif y < ay: c, n = ('2', 'lit') if near else ('1', 'mid')
            elif y == ay + 1 and not near: c, n = '0', 'under'
            else: c, n = '1', 'low'
            if far_edge and y != ay: c, n = '0', 'edge'
            _plate_put(s, f, x, y, c, n)

def fauld(s, f, lames, cx, vee, sag=4):
    """Lames below the waist: per lame (y_top, rows, xl, xr) a 1-px iron 2 rolled edge on top, iron 0 under it,
    iron 1 below, iron 0 as a 2-px core shadow on the far edge. Each lame sags 1 px over the middle (|x - cx| <=
    sag) so the lines follow the belly, not a ruler; the last lame's lower edge is a V (vee rows)."""
    lit_left = draw.LIGHT[0] < 0
    for i, (yt, rows, xl, xr) in enumerate(lames):
        last = i == len(lames) - 1
        for x in range(xl, xr + 1):
            dip = 1 if abs(x - cx) <= sag else 0
            far_edge = (x > xr - 2) if lit_left else (x < xl + 2)
            if dip and i == 0: _plate_put(s, f, x, yt, '1', 'low')      # the waist plate fills over the sag
            depth = rows + (max(0, vee - abs(x - cx) // 3) if last else 0)
            for k in range(depth):
                y = yt + dip + k
                if k == 0: c, n = '2', 'line'
                elif k == 1: c, n = '0', 'under'
                elif far_edge: c, n = '0', 'edge'
                else: c, n = '1', 'low'
                _plate_put(s, f, x, y, c, n)

def spaulder(s, f, pts, lame):
    part(s, f, pts, ['2', '1', '0'], [0.55, 0.1], ky=0.9)
    line(s, f, *lame, '0')

def S(s, f=0, mf=0):
    keep_head(s, f, 58); op.KEPT.clear()
    # the cape behind: seen at the sides, its hem dropping lower where a fold hangs
    cape(s, f, [(70,58),(106,58),(108,80),(108,110),(108,127),(107,134),(105,131),(103,137),(100,132),(97,134),
                (79,134),(76,131),(73,136),(71,132),(69,135),(68,128),(68,110),(68,80)], [])
    # round 6: the lining between arm and body as cape folds (4 px under the spaulder, 6 px at the hem)
    for g in (ID, mirror):
        lining_folds(s, f, g([(72,64),(77,64),(80,87),(80,100),(78,134),(71,134),(71,100),(72,80)]),
                     [g([(74,74),(76,74),(77,134),(73,134)])])
    for g in (ID, mirror):
        part(s, f, g([(78,106),(87,106),(86,126),(79,126)]))
        part(s, f, g([(79,128),(86,128),(85,146),(80,146)]))
        part(s, f, g([(78,123),(87,123),(87,129),(79,129)]), ['2','1','0'], [0.5, 0.1], ky=0.6)
        part(s, f, g([(80,144),(86,144),(87,150),(86,156),(83,161),(79,158),(79,150)]), ky=0.6)
    # two small tassets over the hips, an inner line between them
    tl = [(78,98),(88,98),(88,108),(81,110),(77,106)]
    part(s, f, tl, ky=0.3); part(s, f, mirror(tl), ky=0.3)
    line(s, f, (88,99), (88,109), '0')
    # round 6: a tapered breastplate (23 px at row 61, 17 at the waist) and three fauld lames with a V edge
    breastplate(s, f, 58, 86, (77, 99), (80, 96), 88, 68, 73)
    fauld(s, f, [(87, 4, 79, 97), (91, 4, 78, 98), (95, 3, 77, 99)], 88, 3)
    # standing collar: hugs the jaw, closed in iron 0
    part(s, f, [(74,40),(82,40),(84,58),(93,58),(95,40),(102,40),(104,52),(102,61),(74,61),(72,52)], ky=0.5,
         only=set('.'))
    up = [(64,72),(72,72),(72,88),(65,88)]; fo = [(64,87),(72,87),(71,99),(65,99)]
    ha = [(65,98),(71,98),(71,104),(69,108),(66,108),(64,104)]
    for g in (ID, mirror):
        part(s, f, g(up), ky=0.2); part(s, f, g(fo), ky=0.2)
        part(s, f, g(ha), SK, [0.35], ky=0.5)
        ink(s, f, [g(up), g(fo), g(ha)], skip=[g([(60,68),(76,68),(76,74),(60,74)])])
        spaulder(s, f, g([(78,58),(71,59),(66,62),(62,66),(62,72),(65,76),(73,76),(75,70),(78,63)]),
                 g([(63,70),(74,69)]))
    clip(s, f, mf)
    s.outline(f)
    # the face's side lines next to the collar: iron 0, not soot (no goggle rings)
    for y in range(46, 59):
        for x in range(74, 102):
            if s.get(f, x, y) == 'K' and '.' not in [s.get(f, x + dx, y + dy) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))]:
                nb = [s.get(f, x + dx, y) for dx in (-1, 1)]
                if any(c in '012' for c in nb) and any(c in 'ABCDE' for c in nb): s.put(f, x, y, '0')

def SE(s, f=1, mf=1):
    keep_head(s, f, 60); op.KEPT.clear()
    cape(s, f, [(72,60),(100,56),(106,60),(107,90),(107,122),(106,131),(104,128),(102,135),(99,130),(96,133),
                (78,133),(75,130),(72,135),(70,130),(69,112),(69,84)],
         [fold((99,64), 100, 105, 133)])
    # round 6: the lining between arms and body as cape folds
    lining_folds(s, f, [(77,70),(80,70),(82,88),(82,100),(81,133),(76,133),(77,100)],
                 [[(78,96),(79,96),(79,133),(77,133)]])
    lining_folds(s, f, [(98,62),(101,62),(101,100),(104,131),(98,131),(97,100)],
                 [[(100,84),(101,84),(103,130),(101,130)]])
    part(s, f, [(90,104),(98,104),(97,122),(91,122)]); part(s, f, [(91,126),(98,126),(97,142),(92,142)])
    part(s, f, [(90,120),(99,120),(99,127),(91,127)], ['2','1','0'], [0.5, 0.1], ky=0.6)
    part(s, f, [(92,140),(98,140),(102,145),(105,150),(102,152),(96,151),(92,147)], ky=0.6)
    part(s, f, [(77,106),(87,106),(86,126),(78,126)]); part(s, f, [(78,130),(86,130),(85,147),(79,147)])
    part(s, f, [(77,124),(87,124),(87,131),(78,131)], ['2','1','0'], [0.5, 0.1], ky=0.6)
    part(s, f, [(79,145),(86,145),(89,150),(92,156),(90,159),(85,158),(80,155),(78,150)], ky=0.6)
    tl = [(79,99),(89,99),(89,108),(82,110),(78,106)]; tr = [(89,99),(98,98),(100,105),(97,109),(90,109)]
    part(s, f, tl, ky=0.3); part(s, f, tr, ky=0.3); line(s, f, (89,99), (89,109), '0')
    breastplate(s, f, 57, 86, (76, 101), (81, 97), 90, 68, 73)
    fauld(s, f, [(87, 4, 80, 98), (91, 4, 79, 99), (95, 3, 79, 100)], 90, 3)
    part(s, f, [(80,42),(88,44),(96,48),(100,47),(102,54),(100,62),(80,62),(76,54)], ky=0.5, only=set('.rs'))
    # far arm and spaulder
    part(s, f, [(100,70),(106,70),(107,88),(101,88)], ky=0.2); part(s, f, [(101,87),(107,87),(106,99),(101,99)], ky=0.2)
    part(s, f, [(101,98),(107,98),(106,104),(102,104)], SK, [0.35], ky=0.5)
    spaulder(s, f, [(96,59),(102,57),(106,61),(108,67),(105,72),(99,70),(96,65)], [(97,66),(107,66)])
    # near arm hangs in front of the body's side
    up = [(70,72),(78,72),(78,88),(71,88)]; fo = [(70,87),(78,87),(77,100),(71,100)]
    ha = [(71,99),(77,99),(77,105),(75,109),(72,109),(70,105)]
    part(s, f, up, ky=0.2); part(s, f, fo, ky=0.2); part(s, f, ha, SK, [0.35], ky=0.5)
    ink(s, f, [up, fo, ha], skip=[[(66,68),(82,68),(82,75),(66,75)]])
    spaulder(s, f, [(81,58),(75,59),(71,63),(69,69),(70,75),(78,76),(80,70),(82,63)], [(70,71),(80,70)])
    clip(s, f, mf)
    s.outline(f)

def E(s, f=2, mf=2):
    keep_head(s, f, 60); op.KEPT.clear()
    # the cape hangs from the shoulders down the back: three folds, lit side to the left (round 3, passed)
    cape(s, f, [(80,58),(90,58),(92,80),(95,110),(98,140),(92,137),(86,142),(80,137),(74,142),(70,136),(72,110),(75,84)],
         [fold((79,62), 71, 77, 140), fold((84,64), 81, 87, 141), fold((89,66), 91, 96, 139)])
    part(s, f, [(88,104),(97,104),(96,124),(89,124)]); part(s, f, [(89,128),(96,128),(95,142),(90,142)])
    part(s, f, [(89,140),(96,140),(102,145),(106,149),(100,150),(90,150)], ky=0.6)
    part(s, f, [(86,106),(96,106),(95,126),(87,126)]); part(s, f, [(87,129),(95,129),(94,147),(88,147)])
    part(s, f, [(85,123),(96,123),(97,129),(86,129)], ['2','1','0'], [0.5, 0.1], ky=0.6)
    part(s, f, [(87,145),(95,145),(101,150),(108,156),(104,158),(92,158),(87,154)], ky=0.6)
    part(s, f, [(86,97),(99,96),(101,105),(97,110),(88,109)], ky=0.3)                     # tasset
    part(s, f, [(86,58),(98,58),(103,66),(102,82),(99,96),(86,97),(83,84),(83,66)], ky=0.45)
    fill(s, f, [(86,95),(99,95),(99,97),(86,97)], '0')
    part(s, f, [(84,42),(92,46),(100,52),(102,62),(84,62),(80,52)], ky=0.5, only=set('.rs'))
    up = [(89,70),(97,70),(98,86),(90,87)]; fo = [(90,86),(98,86),(99,98),(92,99)]
    ha = [(92,97),(99,97),(100,103),(97,107),(93,107),(91,103)]
    part(s, f, up, ky=0.2); part(s, f, fo, ky=0.2); part(s, f, ha, SK, [0.35], ky=0.5)
    ink(s, f, [up, fo, ha], skip=[[(86,66),(102,66),(102,73),(86,73)]])
    spaulder(s, f, [(86,59),(94,58),(99,62),(100,70),(97,74),(89,74),(86,68)], [(87,68),(99,68)])
    s.outline(f)
    jaw_line(s, f)

# Round 6 (critic r4 item 4, r5 fix 2): the skin_pale_0 blob under the E jaw becomes a 1-px skin_pale_1 jaw
# line stepping back from the chin; face above it, the collar's shadow (iron 0) below. W gets it mirrored.
# Round 7 (critic r6 fix 2): the E/W head had no face (it read as a thumb): a 2x1 skin_pale_0 eye socket under a
# 2x1 skin_pale_1 brow notch, 3 px behind the profile edge. Nothing else.
JAW_E = {45: {91: 'B', 92: 'B'},
         46: {91: 'A', 92: 'A'},
         52: {93: 'C', 94: 'C', 95: 'B', 96: 'B'},
         53: {90: 'C', 91: 'C', 92: 'C', 93: 'B', 94: 'B', 95: '0', 96: '0'},
         54: {90: 'C', 91: 'B', 92: 'B', 93: '0', 94: '0', 95: '0'},
         55: {90: '0', 91: '0', 92: '0', 93: '0'},
         56: {90: '0', 91: '0', 92: '0', 93: '0'},
         57: {90: '0', 91: '0', 92: '0', 93: '0'}}

def jaw_line(s, f):
    for y, row in JAW_E.items():
        for x, c in row.items(): s.put(f, x, y, c)

def NE(s, f=3, mf=3):
    keep_head(s, f, 56); op.KEPT.clear()
    part(s, f, [(80,126),(88,126),(87,142),(81,142)]); part(s, f, [(80,140),(88,140),(90,146),(88,150),(81,150),(79,146)], ky=0.6)
    part(s, f, [(94,128),(102,128),(101,146),(95,146)]); part(s, f, [(93,143),(100,143),(102,146),(106,147),(106,151),(100,153),(96,155),(91,155),(90,150)], ky=0.6)
    part(s, f, [(72,58),(98,55),(104,62),(106,90),(104,112),(74,112),(70,90)], ky=0.45)
    cape(s, f, [(72,58),(98,55),(104,60),(106,90),(106,120),(105,133),(103,130),(101,137),(98,132),(94,134),(91,131),
                (88,138),(85,132),(81,135),(78,131),(75,136),(72,132),(70,120),(69,90)],
         [fold((75,64), 70, 76, 134), fold((87,62), 86, 91, 137), fold((98,64), 100, 105, 133)], lit=0.93)
    part(s, f, [(84,54),(100,52),(103,56),(102,62),(85,63),(82,58)], ky=0.5)
    spaulder(s, f, [(84,56),(77,56),(71,59),(67,64),(68,69),(76,69),(81,65)], [(68,66),(80,65)])
    up = [(99,72),(106,72),(106,90),(100,90)]; fo = [(100,89),(106,89),(105,101),(100,101)]
    ha = [(100,100),(106,100),(106,106),(104,109),(101,109),(99,106)]
    part(s, f, up, ky=0.2); part(s, f, fo, ky=0.2); part(s, f, ha, SK, [0.35], ky=0.5)
    ink(s, f, [up, fo, ha], skip=[[(96,68),(110,68),(110,76),(96,76)]])
    spaulder(s, f, [(96,59),(102,57),(107,61),(108,68),(105,74),(99,72),(96,66)], [(97,67),(107,67)])
    clip(s, f, mf)
    s.outline(f)

def N(s, f=4, mf=4):
    keep_head(s, f, 55); op.KEPT.clear()
    clear(s, f, [(70,30),(106,30),(106,58),(70,58)])
    part(s, f, [(82,40),(85,37),(90,37),(93,40),(95,47),(94,55),(81,55),(80,47)], SK, [0.42], ky=0.8)
    for g in (ID, mirror):
        part(s, f, g([(78,126),(86,126),(85,142),(79,142)]))
        part(s, f, g([(78,140),(86,140),(87,146),(85,151),(79,151),(77,146)]), ky=0.6)
    up = [(63,72),(70,72),(70,88),(64,88)]; fo = [(63,87),(70,87),(69,99),(64,99)]
    ha = [(64,98),(70,98),(70,104),(68,108),(65,108),(63,104)]
    for g in (ID, mirror):
        part(s, f, g(up), ky=0.2); part(s, f, g(fo), ky=0.2); part(s, f, g(ha), SK, [0.35], ky=0.5)
    # three folds fan from the blades: the outer two lean out, each 2 px at the top and 4-6 px at the hem;
    # the hem hangs lowest under each fold and the teeth between them differ (2/4/1/3 px)
    cape(s, f, [(71,58),(105,58),(107,80),(108,108),(109,128),(108,134),(105,131),(102,135),(99,133),(96,131),
                (92,134),(89,138),(85,135),(82,131),(79,132),(76,134),(73,131),(70,135),(68,130),(68,108),(69,80)],
         [[(75,62),(77,62),(75,96),(73,134),(68,134),(71,100)],          # left blade, fans out, 5 px at the hem
          [(87,64),(89,64),(91,88),(89,106),(87,111),(86,92)],           # middle, ends at two-thirds height
          [(98,63),(100,63),(103,96),(106,126),(103,128),(100,100)]],    # right blade, stops above the hem
         lit=2.0)
    part(s, f, [(77,51),(99,51),(103,55),(101,61),(75,61),(73,55)], ky=0.5)
    for g in (ID, mirror):
        ink(s, f, [g(up), g(fo), g(ha)], skip=[g([(58,68),(76,68),(76,76),(58,76)])])
        spaulder(s, f, g([(78,57),(71,58),(66,61),(62,66),(62,72),(65,75),(72,74),(75,69),(78,63)]), g([(63,70),(74,69)]))
    clip(s, f, mf)
    # round 6 (critic r5 optional 3): the enclosed slit between the left arm and the cape is filled with cape shadow
    for y in range(95, 108):
        for x in range(66, 72):
            if s.get(f, x, y) == '.' and s.get(f, x - 1, y) != '.' and any(s.get(f, x + d, y) != '.' for d in (1, 2)):
                s.put(f, x, y, 'r')
    s.outline(f)
    N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
    for y in range(95, 108):
        for x in range(66, 72):
            nb = [s.get(f, x + dx, y + dy) for dx, dy in N4]
            if s.get(f, x, y) == 'K' and '.' not in nb and nb.count('K') <= 1: s.put(f, x, y, 'r')

def W(s): mirrored(E, 6, 2)(s)
def SW(s): mirrored(SE, 7, 1)(s)
def NW(s): mirrored(NE, 5, 3)(s)

def build(names):
    load_masks()
    op.NRM.clear()
    s = vamp_global()
    for fn in names:
        globals()[fn](s)
        op.RIMS.clear()
    for f in range(8): chin_dots(s, f)
    from px import despeckle_sheet
    despeckle_sheet(s)
    FILLED[:] = fill_holes(s)
    return s

FILLED = []

def fill_holes(s):
    """Round 7 (critic r6 fix 1): a transparent pixel group that is not connected to the frame edge (an enclosed
    hole, 2x1 gaps ringed by soot 0 in E, NE (two), NW and W) is filled with soot 0. Returns [(f, x, y)]."""
    out = []
    for f in range(8):
        seen = set(); st = [(x, y) for y in range(176) for x in (0, 175)] + [(x, y) for x in range(176) for y in (0, 175)]
        st = [p for p in st if s.get(f, *p) == '.']; seen.update(st)
        while st:
            x, y = st.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if 0 <= q[0] < 176 and 0 <= q[1] < 176 and q not in seen and s.get(f, *q) == '.':
                    seen.add(q); st.append(q)
        for y in range(176):
            for x in range(176):
                if s.get(f, x, y) == '.' and (x, y) not in seen: out.append((f, x, y))
    for f, x, y in out: s.put(f, x, y, 'K')
    return out

def patch_hole_normals(path):
    """The filled holes take the normal of their soot neighbour (the next soot 0 pixel to the left, else right)."""
    a = np.array(Image.open(path).convert('RGBA'))
    for f, x, y in FILLED:
        X = f * 176 + x
        src = next(X + d for d in (-1, -2, 1, 2) if (X + d, y) not in {(g * 176 + u, v) for g, u, v in FILLED})
        a[y, X] = a[y, src]; a[y, X, 3] = 255
    Image.fromarray(a, 'RGBA').save(path)

if __name__ == '__main__':
    s = build(sys.argv[1:])
    s.save(O + 'vamp_p.png')
    import normals
    print('flat fallback px', normals.build(s.a, O + 'orig/vampyr_look_heartland_normal.png', op.NRM, O + 'vamp_p_normal.png'))
    patch_hole_normals(O + 'vamp_p_normal.png')
    print('holes filled', FILLED)
