"""Orc round 5 (from round 4): the round-2 bulk back (director 2026-10-16: "bulk and green-grey skin").

Per facing, the round-2 alpha (commit 7f972fd) is the outer mask. Below the neck line every mask pixel is
painted: first one barrel volume over the whole mask (the bulk), then the parts on top of it (legs, fauld,
belt, arms, pauldrons, boots), shaded in palette ramps from one key at camera-left. Above the neck line only
the kept head and the drawn parts (gorget, high pauldrons) paint, so the round-2 hood does not come back.
Nothing paints outside the mask except the cleared arm gaps, which only remove pixels.

Round 5 (critic r4): the heads are hand-placed grids (`heads.py`: broad jaw, brow shelf, mouth, tusks from the
lower jaw), laid on top and exempt from the round-2 mask; the plate is one iron step darker (body iron 2, lit
iron 3, shadow iron 1, iron 4 only as the key edge) so the head separates by value."""
import sys
import numpy as np
from PIL import Image
from px import *
import draw
from draw import *
from orc_global import orc_global, O

IR = ['3', '2', '1']          # plate: lit plane, body, shadow (key from camera-left)
LE = ['o', 'n', 'm']          # leather in timber
SK = ['E', 'D', 'C']          # orc skin, steps 2-4 only (clear of every grass colour)
P4 = (['3', '2', '1', '0'], [0.9, 0.5, 0.05])   # pauldrons and gorget: iron 4 only as the rim
T3 = [0.88, 0.4]
NRM = {}
NOTHEAD = set('.K01234mnoMfghijkqQ')
ID = lambda p: p
def mirror(pts, c=88): return [(2 * c - x, y) for x, y in pts]

MASK = {}                      # source facing -> bool array (rows, cols) of the round-2 alpha
def load_masks(path=None):
    a = np.array(Image.open(path or O + 'orig/orc_look_heartland.png').convert('RGBA'))
    for f in range(8): MASK[f] = a[:, f * 176:(f + 1) * 176, 3] > 0

KEPT = []                      # the kept head (x, y, code): laid back on top before the outline
RIMS = []                      # (frame, pixel set) of plates that take a lit top-left edge after the outline

def part(s, f, pts, tones=IR, thr=T3, ky=0.35, kx=1.0, only=None, rim=None):
    """rim: None, 'top' (lit top edge) or 'both' (top edge and the upper key-side edge)."""
    shade3d(s, f, pts, tones, thr, ky=ky, kx=kx, normals=NRM, only=only)
    if rim:
        own = {p: s.get(f, *p) for p in inside(pts)}
        RIMS.append((s, f, own, rim))

def ink(s, f, polys, skip=()):
    """Inner line where an arm crosses the body: border pixels of the union of polys -> soot 0."""
    m = set()
    for p in polys: m |= set(inside(p))
    sk = set()
    for p in skip: sk |= set(inside(p))
    for x, y in m:
        if (x, y) in sk: continue
        if any((x + dx, y + dy) not in m for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))): s.put(f, x, y, 'K')

def base(s, f, mf, top, ky=0.5, kx=1.0):
    """The barrel: every mask pixel below the neck line (and not head) takes one rounded plate volume."""
    M = MASK[mf]; H, W = M.shape
    t = int(round(top * draw.SCALE))
    px = [(x, y) for y in range(t, H) for x in range(W) if M[y, x] and s.get(f, x, y) not in 'ABCDEvwxyz']
    for (x, y), (d, n) in form_set(px, ky, kx).items():
        tone = '1'
        for tn, c in zip(IR, T3):
            if d >= c: tone = tn; break
        NRM[(f, x, y)] = n
        s.put(f, x, y, tone)

HEADPX = set()                 # the painted head (drawing coordinates): exempt from the round-2 mask

def clip(s, f, mf):
    M = MASK[mf]; H, W = M.shape
    for y in range(H):
        for x in range(W):
            if not M[y, x] and (x, y) not in HEADPX and s.get(f, x, y) != '.': s.put(f, x, y, '.')

def paint_head(s, f, src):
    """Clear the frame and lay the hand-placed head of facing src (heads.py). Each grid letter is a plane: its
    tone comes from the plane normal and the key (draw.LIGHT, flipped in the mirrored facings) and its normal
    goes to NRM for the normal strip. KEPT lays the head back on top after the body."""
    import heads
    x0, y0, rows = heads.HEADS[src]
    cells = {(x0 + i, y0 + j): ch for j, r in enumerate(rows) for i, ch in enumerate(r) if ch != ' '}
    for y in range(176):
        for x in range(176): s.put(f, x, y, '.')
    L = np.array(draw.LIGHT) / np.linalg.norm(draw.LIGHT)
    out = []
    for (x, y), ch in cells.items():
        n = np.array(heads.PLANES[ch], float); n /= np.linalg.norm(n)
        d = float(n @ L)
        tones, cuts = heads.TUSK if ch in 'yx' else heads.SKIN
        c = heads.FIXED.get(ch)
        if c is None:
            c = tones[-1]
            for t, k in zip(tones, cuts):
                if d >= k: c = t; break
        if c != 'K': NRM[(f, x, y)] = n
        s.put(f, x, y, c); out.append((x, y, c))
    KEPT[:] = out
    HEADPX.clear(); HEADPX.update(cells)

def keep_head(s, f, ymax):
    """Keep the skull, tusks and eye pixels above ymax; clear everything else (it is redrawn)."""
    if draw.SCALE != 1: return
    keep = set()
    for y in range(ymax + 1):
        for x in range(176):
            if s.get(f, x, y) in 'ABCDEvwxyz': keep.add((x, y))
    for y in range(ymax + 1):
        for x in range(176):
            if s.get(f, x, y) == 'K' and sum((x + dx, y + dy) in keep for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))) >= 3:
                keep.add((x, y))
    KEPT[:] = [(x, y, s.get(f, x, y)) for x, y in keep]
    for y in range(176):
        for x in range(176):
            if (x, y) not in keep: s.put(f, x, y, '.')

def head_light(s, f, box):
    """The lit top-left of the skull takes skin step 4: a Lambert cut over the head's skin pixels."""
    x0, y0, x1, y1 = box
    px = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if s.get(f, x, y) == 'D']
    for (x, y), (d, n) in form_set(px, 0.8, 1.0).items():
        if d >= 0.86: s.put(f, x, y, 'E')
    KEPT[:] = [(x, y, s.get(f, x, y)) for x, y, _ in KEPT]

def tusks(s, f, spots):
    """Tusks in bone 3, 2 px wide and 2-3 px tall, rising from the lower jaw past the lip line.
    Old bone pixels of the head take the skin under them first."""
    for y in range(176):
        for x in range(176):
            if s.get(f, x, y) in 'vwxyz': s.put(f, x, y, 'C')
    for x, y, h in spots:
        for dy in range(h):
            for dx in (0, 1): s.put(f, x + dx, y + dy, 'y')

def rims():
    """1-px iron 4 edge where the key hits each plate: its top edge (key-side 60%) and its key-side edge
    (top 45%), inside the outline; never along a whole edge."""
    side = -1 if draw.LIGHT[0] < 0 else 1
    for s, f, px, mode in RIMS:
        if not px: continue
        xs = [p[0] for p in px]; ys = [p[1] for p in px]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        lit_x = (lambda x: x <= x0 + 0.6 * (x1 - x0)) if side < 0 else (lambda x: x >= x1 - 0.6 * (x1 - x0))
        for x, y in px:
            if s.get(f, x, y) not in '0123' or s.get(f, x, y) != px[(x, y)]: continue   # painted over since
            up, lit = (x, y - 1), (x + side, y)
            top = (up not in px or s.get(f, *up) == 'K') and lit_x(x)
            sid = mode == 'both' and (lit not in px or s.get(f, *lit) == 'K') and y <= y0 + 0.45 * (y1 - y0)
            if (top or sid) and '.' not in (s.get(f, *up), s.get(f, *lit)): s.put(f, x, y, '4')
    RIMS.clear()

def arm(s, f, up, fo, ha, couter, skip=(), gap=None):
    if gap: clear(s, f, gap)
    part(s, f, up, ky=0.2); part(s, f, fo, ky=0.2)
    part(s, f, couter, IR, [0.6, 0.3], ky=0.8)
    part(s, f, ha, SK, [0.85, 0.3], ky=0.5)
    ink(s, f, [up, fo, ha, couter], skip=skip)

def pauldron(s, f, pts, lame, only=None):
    part(s, f, pts, *P4, ky=0.9, only=only, rim='both')
    line(s, f, *lame, '1')

def finish(s, f, mf):
    for x, y, c in KEPT: s.put(f, x, y, c)
    KEPT.clear()
    clip(s, f, mf)
    HEADPX.clear()
    s.outline(f)

# ---------------------------------------------------------------- facings
def S(s, f=0, mf=0):
    paint_head(s, f, mf)
    base(s, f, mf, 58)
    for g in (ID, mirror):
        part(s, f, g([(70,110),(87,110),(87,127),(71,127)]))                  # cuisse
        part(s, f, g([(71,122),(88,122),(88,131),(72,131)]), ['3','2','1'], [0.6, 0.2], ky=0.6)   # knee
        part(s, f, g([(73,130),(86,130),(85,144),(74,144)]), rim='both')                  # greave
        part(s, f, g([(74,143),(85,143),(85,150),(84,161),(70,161),(70,154),(73,150)]), LE, [0.55, 0.1], ky=0.6)
    part(s, f, [(86,110),(90,110),(90,130),(86,130)], ['1','0','0'], [0.5, 0.0])        # mail at the fork
    clear(s, f, [(86,132),(90,132),(90,144),(86,144)])                                  # daylight between the shins
    part(s, f, [(66,96),(110,96),(113,104),(113,112),(63,112),(62,104)], ky=0.2, rim='top')    # fauld
    line(s, f, (63,104), (112,104), '1')
    part(s, f, [(72,57),(104,57),(108,70),(111,84),(111,96),(100,102),(88,104),(76,102),(65,96),(65,84),(68,70)],
         ky=0.45, rim='top')                                                              # barrel
    part(s, f, [(65,84),(76,90),(88,92),(100,90),(111,84),(111,90),(100,96),(88,98),(76,96),(65,90)], LE, [0.5, 0.0], ky=0.9)
    fill(s, f, [(85,91),(91,91),(91,98),(85,98)], 'n'); fill(s, f, [(86,92),(90,92),(90,97),(86,97)], 'm')
    part(s, f, [(73,51),(103,51),(105,58),(100,62),(76,62),(71,58)], *P4, ky=0.9, only=NOTHEAD)   # gorget
    for g in (ID, mirror):
        arm(s, f, g([(59,64),(74,64),(75,78),(73,88),(61,88),(59,78)]), g([(61,88),(72,88),(71,101),(62,101)]),
            g([(61,100),(70,100),(70,106),(68,112),(62,112),(60,106)]), g([(60,86),(73,86),(73,91),(60,91)]),
            skip=[g([(56,60),(76,60),(76,70),(56,70)])])
        pauldron(s, f, g([(51,62),(54,53),(61,49),(71,49),(77,53),(79,62),(77,70),(70,74),(58,74),(52,70)]),
                 g([(53,66),(77,66)]))
    finish(s, f, mf)

def SE(s, f=1, mf=1):
    paint_head(s, f, mf)
    base(s, f, mf, 60)
    # far leg, far arm (behind)
    part(s, f, [(86,110),(101,110),(100,126),(87,126)])
    part(s, f, [(88,128),(99,128),(98,142),(89,142)])
    part(s, f, [(86,122),(101,122),(101,129),(87,129)], IR, [0.6, 0.2], ky=0.6)
    part(s, f, [(89,140),(99,140),(101,144),(107,146),(108,151),(103,154),(92,154),(89,150)], LE, [0.55, 0.1], ky=0.6)
    part(s, f, [(102,62),(112,62),(112,84),(104,86)], ky=0.2)
    part(s, f, [(104,84),(111,84),(111,98),(105,98)], ky=0.2)
    part(s, f, [(104,97),(111,97),(111,104),(108,108),(105,106)], SK, [0.7, 0.2], ky=0.5)
    # near leg
    part(s, f, [(68,110),(87,110),(86,128),(71,128)])
    part(s, f, [(70,124),(87,124),(88,132),(71,132)], IR, [0.6, 0.2], ky=0.6)
    part(s, f, [(72,131),(86,131),(85,147),(75,147)], rim='both')
    part(s, f, [(75,145),(85,145),(87,150),(92,155),(93,160),(88,163),(80,163),(77,158),(75,151)], LE, [0.55, 0.1], ky=0.6)
    # fauld, barrel, belt
    part(s, f, [(66,94),(108,92),(111,100),(109,108),(100,112),(68,112),(65,104)], ky=0.2, rim='top')
    line(s, f, (66,103), (110,101), '1')
    part(s, f, [(72,60),(100,58),(108,62),(111,78),(110,92),(98,98),(78,98),(66,92),(66,76)], ky=0.45, rim='top')
    part(s, f, [(66,85),(80,90),(94,91),(111,85),(111,91),(94,97),(80,96),(66,91)], LE, [0.5, 0.0], ky=0.9)
    fill(s, f, [(95,90),(101,90),(101,97),(95,97)], 'n'); fill(s, f, [(96,91),(100,91),(100,96),(96,96)], 'm')
    part(s, f, [(78,50),(86,50),(96,51),(106,52),(108,61),(100,66),(84,66),(75,60)], *P4, ky=0.9, only=NOTHEAD)   # r5: up under the jaw
    # far pauldron on the hunched shoulder, below the jaw line so the head stays clear
    pauldron(s, f, [(100,52),(105,45),(113,43),(118,49),(119,59),(113,66),(103,66),(99,59)], [(100,57),(118,56)],
             only=NOTHEAD)
    # near arm hangs long beside the barrel
    arm(s, f, [(62,74),(76,74),(76,92),(64,92),(61,84)], [(62,91),(74,91),(73,106),(64,106)],
        [(63,105),(74,105),(75,112),(72,121),(66,121),(63,113)], [(61,89),(75,89),(75,94),(61,94)],
        skip=[[(58,70),(84,70),(84,80),(58,80)]])
    pauldron(s, f, [(59,71),(62,64),(70,61),(79,62),(84,69),(83,77),(77,82),(64,82),(59,78)], [(60,76),(83,74)])
    finish(s, f, mf)

def E(s, f=2, mf=2):
    paint_head(s, f, mf)
    base(s, f, mf, 58)
    # far leg (a step ahead, foot higher), near leg
    part(s, f, [(84,108),(97,108),(96,126),(86,126)])
    part(s, f, [(86,126),(95,126),(94,138),(87,138)])
    part(s, f, [(86,136),(95,136),(98,139),(104,141),(104,145),(98,147),(87,147)], LE, [0.55, 0.1], ky=0.6)
    part(s, f, [(75,108),(95,108),(94,126),(77,126)])
    part(s, f, [(76,122),(95,122),(96,130),(77,130)], IR, [0.6, 0.2], ky=0.6)
    part(s, f, [(78,129),(93,129),(92,149),(81,149)], rim='both')
    part(s, f, [(80,147),(92,147),(94,151),(103,153),(105,157),(100,161),(86,161),(81,157)], LE, [0.55, 0.1], ky=0.6)
    # fauld round the hips, barrel with a forward belly, belt
    part(s, f, [(70,92),(108,90),(109,100),(106,108),(100,112),(76,112),(69,106),(67,98)], ky=0.2, rim='top')
    line(s, f, (68,100), (108,98), '1')
    part(s, f, [(76,54),(100,52),(108,56),(112,64),(113,76),(111,86),(108,94),(96,98),(80,98),(71,92),(70,80),(72,64)],
         ky=0.45, rim='top')
    part(s, f, [(70,82),(92,88),(111,81),(110,87),(92,94),(70,88)], LE, [0.5, 0.0], ky=0.9)
    part(s, f, [(80,47),(92,49),(104,51),(110,50),(112,55),(106,60),(88,60),(77,54)], *P4, ky=0.9, only=NOTHEAD)
    # near arm hangs long over the hip: own planes, inner line round it
    up = [(84,72),(98,72),(99,90),(87,91),(83,82)]
    fo = [(87,89),(98,89),(100,104),(90,106)]
    ha = [(89,104),(99,104),(100,112),(98,120),(91,121),(88,113)]
    arm(s, f, up, fo, ha, [(86,87),(99,87),(99,92),(86,92)])
    pauldron(s, f, [(77,63),(84,55),(97,52),(106,56),(110,64),(108,73),(98,78),(84,78),(76,71)], [(77,70),(109,69)])
    finish(s, f, mf)

def NE(s, f=3, mf=3):
    paint_head(s, f, mf)
    base(s, f, mf, 50)
    # near (left) arm hangs down the back
    up = [(64,56),(75,56),(75,78),(66,78)]; fo = [(65,77),(74,77),(73,94),(66,94)]
    ha = [(66,93),(73,93),(73,100),(70,103),(66,102),(65,97)]
    part(s, f, up, ky=0.2); part(s, f, fo, ky=0.2); part(s, f, ha, SK, [0.85, 0.3], ky=0.5)
    ink(s, f, [up, fo, ha])
    # legs
    part(s, f, [(71,112),(89,112),(88,128),(73,128)])
    part(s, f, [(73,126),(88,126),(87,141),(77,141)], rim='both')
    part(s, f, [(72,123),(89,123),(89,130),(73,130)], ['2','1','1'], [0.5, 0.2], ky=0.6)
    part(s, f, [(76,139),(87,139),(88,144),(86,149),(79,149),(76,145)], LE, [0.55, 0.1], ky=0.6)
    part(s, f, [(88,114),(102,114),(101,128),(90,128)])
    part(s, f, [(89,128),(100,128),(99,145),(90,145)])
    part(s, f, [(88,125),(102,125),(101,131),(89,131)], ['2','1','1'], [0.5, 0.2], ky=0.6)
    part(s, f, [(89,143),(99,143),(104,145),(108,148),(106,153),(98,156),(90,155),(88,150)], LE, [0.55, 0.1], ky=0.6)
    # fauld, barrel, belt
    part(s, f, [(66,94),(111,92),(111,104),(110,110),(92,114),(74,112),(67,104)], ky=0.2, rim='top')
    line(s, f, (67,103), (111,101), '1')
    part(s, f, [(70,48),(98,46),(112,52),(117,68),(114,88),(104,96),(80,96),(68,88),(66,66)], ky=0.45, rim='top')
    part(s, f, [(66,80),(90,87),(115,81),(115,87),(90,93),(66,86)], LE, [0.5, 0.0], ky=0.9)
    # gorget at the nape; the near pauldron sits below the head so the two never read as one mass
    part(s, f, [(80,44),(90,46),(102,44),(106,48),(100,53),(84,53),(78,49)], *P4, ky=0.9, only=NOTHEAD)
    pauldron(s, f, [(62,53),(66,46),(74,42),(83,43),(88,50),(86,59),(77,64),(66,63),(62,59)], [(63,57),(87,55)],
             only=NOTHEAD)
    # far arm and pauldron
    up = [(105,72),(115,72),(115,92),(107,92)]; fo = [(106,91),(113,91),(112,106),(106,106)]
    ha = [(105,105),(111,105),(111,112),(109,118),(105,118),(104,111)]
    arm(s, f, up, fo, ha, [(105,90),(115,90),(115,94),(105,94)], skip=[[(100,70),(122,70),(122,77),(100,77)]])
    pauldron(s, f, [(98,64),(104,57),(113,56),(118,62),(117,72),(110,79),(101,77),(97,70)], [(98,70),(117,68)])
    finish(s, f, mf)

def N(s, f=4, mf=4):
    paint_head(s, f, mf)
    base(s, f, mf, 46)
    for g in (ID, mirror):
        part(s, f, g([(70,116),(87,116),(87,130),(71,130)]))
        part(s, f, g([(72,128),(86,128),(85,143),(74,143)]), rim='both')
        part(s, f, g([(71,125),(87,125),(87,132),(72,132)]), ['2','1','1'], [0.5, 0.2], ky=0.6)
        part(s, f, g([(74,141),(84,141),(85,146),(84,152),(77,152),(73,148)]), LE, [0.55, 0.1], ky=0.6)
    part(s, f, [(86,116),(90,116),(90,130),(86,130)], ['1','0','0'], [0.5, 0.0])
    clear(s, f, [(86,132),(90,132),(90,144),(86,144)])
    part(s, f, [(66,98),(110,98),(113,106),(113,118),(63,118),(62,106)], ky=0.2, rim='top')
    line(s, f, (63,107), (112,107), '1')
    part(s, f, [(72,48),(104,48),(108,62),(111,80),(111,94),(100,100),(88,102),(76,100),(65,94),(65,80),(68,62)],
         ky=0.45, rim='top')
    line(s, f, (88,50), (88,84), '1')                                                   # backplate ridge
    part(s, f, [(65,80),(76,86),(88,88),(100,86),(111,80),(111,86),(100,92),(88,94),(76,92),(65,86)], LE, [0.5, 0.0], ky=0.9)
    part(s, f, [(76,40),(88,42),(100,40),(102,46),(96,51),(80,51),(74,46)], *P4, ky=0.9, only=NOTHEAD)
    for g in (ID, mirror):
        arm(s, f, g([(59,62),(74,62),(75,74),(73,86),(61,86),(59,74)]), g([(61,85),(72,85),(71,99),(62,99)]),
            g([(61,98),(70,98),(70,104),(68,109),(62,109),(60,104)]), g([(60,84),(73,84),(73,88),(60,88)]),
            skip=[g([(56,58),(76,58),(76,68),(56,68)])])
        pauldron(s, f, g([(51,57),(54,49),(61,45),(70,45),(76,49),(78,57),(76,66),(70,70),(58,70),(52,66)]),
                 g([(53,62),(77,62)]))
    finish(s, f, mf)

TUSKS = {}                     # round 5: the tusks are part of the head grids

def chin_dots(s, f):
    """Old head-outline remnants: an interior soot 0 pixel with skin above and plate below takes the plate colour."""
    for y in range(1, 175):
        for x in range(1, 175):
            if s.get(f, x, y) != 'K': continue
            up, dn = s.get(f, x, y - 1), s.get(f, x, y + 1)
            if up in 'ABCDE' and dn in '01234' and '.' not in (s.get(f, x - 1, y), s.get(f, x + 1, y)):
                s.put(f, x, y, dn)

class Mirror:
    """Draw a facing's shapes mirrored about the frame centre; the light is flipped back so the key stays left."""
    def __init__(self, s): self.s = s
    def get(self, f, x, y): return self.s.get(f, 175 - x, y)
    def put(self, f, x, y, ch): self.s.put(f, 175 - x, y, ch)
    def outline(self, f): self.s.outline(f)

def mirrored(fn, f, mf):
    def run(s):
        global NRM
        old, keep = draw.LIGHT, NRM
        draw.LIGHT = (-old[0], old[1], old[2]); NRM = {}
        try:
            m = Mirror(s); fn(m, f, mf); rims_on(m)
        finally:
            draw.LIGHT = old
            for (ff, x, y), n in NRM.items(): keep[(ff, 175 - x, y)] = np.array([-n[0], n[1], n[2]])
            NRM = keep
    return run

def rims_on(_): rims()

def W(s): mirrored(E, 6, 2)(s)
def SW(s): mirrored(SE, 7, 1)(s)
def NW(s): mirrored(NE, 5, 3)(s)

def tusk_pass(s):
    for f, spots in TUSKS.items(): tusks(s, f, spots)
    for f, src in ((6, 2), (7, 1)):
        tusks(Mirror(s), f, TUSKS[src])

def build(names):
    load_masks()
    s = orc_global()
    for fn in names:
        globals()[fn](s)
        rims()
    from px import despeckle_sheet
    despeckle_sheet(s)
    print('dark skin steps moved off the silhouette:', guard_dark(s))
    return s

def guard_dark(s):
    """Lead ruling 2026-10-16: skin steps 0-1 fail the grass rule, so they stay inside the face; any such pixel
    8-adjacent to a clear pixel or to the silhouette outline takes skin step 2."""
    N8 = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]
    def sil(f, x, y):
        c = s.get(f, x, y)
        if c == '.': return True
        return c == 'K' and any(s.get(f, x + dx, y + dy) == '.' for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))
    n = 0
    for f in range(8):
        for y in range(1, 175):
            for x in range(1, 175):
                if s.get(f, x, y) in 'AB' and any(sil(f, x + dx, y + dy) for dx, dy in N8):
                    s.put(f, x, y, 'C'); n += 1
    return n

if __name__ == '__main__':
    s = build(sys.argv[1:])
    s.save(O + 'orc_p.png')
    import normals
    print('flat fallback px', normals.build(s.a, O + 'orig/orc_look_heartland_normal.png', NRM, O + 'orc_p_normal.png'))
