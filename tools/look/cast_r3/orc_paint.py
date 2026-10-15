import sys
from px import *
from draw import *
from orc_global import orc_global, O
IR = ['3', '2', '1']          # plate: lit, mid, shadow (key from camera-left)
LE = ['o', 'n', 'm']          # leather in timber
SK = ['D', 'C']               # orc skin, kept clear of the grass ramps
def mirror(pts, c=88): return [(2 * c - x, y) for x, y in pts]

def arm(s, f, upper, fore, hand, contact=None, gap=None, tones=IR, flip=False):
    if gap: clear(s, f, gap)
    shade(s, f, upper, tones, [0.4, 0.8], flip=flip)
    shade(s, f, fore, tones, [0.4, 0.8], flip=flip)
    if contact: line(s, f, *contact, '0')
    shade(s, f, hand, SK, [0.55], flip=flip)

NRM = {}
T3 = [0.66, 0.22]          # plate cut-offs: lit / mid / shadow

def part(s, f, pts, tones=IR, thr=T3, ky=0.35, kx=1.0, only=None):
    shade3d(s, f, pts, tones, thr, ky=ky, kx=kx, normals=NRM, only=only)
def ink(s, f, polys, skip=()):
    """Inner line (06 section 3: where an arm meets the body): border pixels of the union of polys -> soot 0.
    skip: polygons whose pixels never take the line (e.g. the shoulder root under the pauldron)."""
    m = set()
    for p in polys: m |= set(inside(p))
    sk = set()
    for p in skip: sk |= set(inside(p))
    for x, y in m:
        if (x, y) in sk: continue
        if any((x + dx, y + dy) not in m for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))): s.put(f, x, y, 'K')
NOTHEAD = set('.K01234mnoMfghijkqQ')
P4 = (['4','3','2','1'], [0.9, 0.62, 0.2])

def S(s):
    f = 0
    clear(s, f, [(50,59),(126,59),(126,166),(50,166)])     # everything below the gorget is redrawn
    # legs first (behind the fauld): cuisses, knee cops, greaves, boots
    th = [(71,110),(87,110),(86,127),(73,127),(71,118)]
    gr = [(73,130),(85,130),(84,140),(83,146),(75,146),(74,140)]
    kn = [(72,125),(86,125),(87,129),(85,132),(73,132),(71,129)]
    bt = [(74,144),(84,144),(84,150),(83,156),(82,162),(70,162),(68,159),(70,154),(73,150)]
    for m in (False, True):
        g = mirror if m else (lambda p: p)
        part(s, f, g(th)); part(s, f, g(gr)); part(s, f, g(kn), ky=0.6)
        part(s, f, g(bt), LE, [0.55, 0.1], ky=0.6)
    # mail between the thighs
    part(s, f, [(84,110),(92,110),(91,118),(85,118)], ['1','0','0'], [0.5, 0.0])
    # fauld: lames skirting the hips
    part(s, f, [(70,95),(106,95),(108,103),(108,112),(68,112),(68,103)], ky=0.2)
    line(s, f, (69,103), (107,103), '1')
    # chest barrel
    part(s, f, [(72,57),(104,57),(106,70),(107,84),(100,90),(88,93),(76,90),(69,84),(70,70)], ky=0.45)
    # belt over the barrel
    belt = [(68,83),(76,88),(88,91),(100,88),(108,83),(108,88),(100,94),(88,97),(76,94),(68,88)]
    part(s, f, belt, LE, [0.5, 0.0], ky=0.9)
    fill(s, f, [(85,90),(91,90),(91,97),(85,97)], 'n'); fill(s, f, [(86,91),(90,91),(90,96),(86,96)], 'm')
    # arms hang beside the barrel, a gap below the elbow
    up = [(60,66),(71,66),(72,78),(70,90),(60,90),(58,78)]
    fo = [(59,89),(69,89),(68,101),(60,101)]
    ha = [(60,100),(68,100),(68,106),(66,111),(61,111),(59,106)]
    for m in (False, True):
        g = mirror if m else (lambda p: p)
        part(s, f, g(up), ky=0.2); part(s, f, g(fo), ky=0.2)
        part(s, f, g([(59,88),(70,88),(70,92),(59,92)]), ['3','2','1'], [0.6, 0.3], ky=0.8)   # couter
        part(s, f, g(ha), SK, [0.35], ky=0.5)
    line(s, f, (72,70), (72,86), '0'); line(s, f, (104,70), (104,86), '0')
    pa = [(51,62),(54,54),(61,50),(70,50),(76,54),(78,62),(76,70),(70,74),(58,74),(52,70)]
    for m in (False, True):
        g = mirror if m else (lambda p: p)
        part(s, f, g(pa), ['4','3','2','1'], [0.9, 0.62, 0.2], ky=0.9)
        line(s, f, *g([(53,66),(76,66)]), '1')
    s.outline(f)

ID = lambda p: p
HEADKEEP = set('ABCDEvwxyz')

def keep_head(s, f, ymax):
    """Keep the skull, tusks and eye pixels above ymax; clear everything else (it is redrawn)."""
    import draw
    if draw.SCALE != 1: return
    keep = set()
    for y in range(176):
        for x in range(176):
            c = s.get(f, x, y)
            if y <= ymax and c in HEADKEEP: keep.add((x, y))
    for y in range(176):
        for x in range(176):
            c = s.get(f, x, y)
            if c == 'K' and y <= ymax:
                n = sum((x + dx, y + dy) in keep for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))
                if n >= 3: keep.add((x, y))
    for y in range(176):
        for x in range(176):
            if (x, y) not in keep: s.put(f, x, y, '.')

def SE(s, f=1):
    keep_head(s, f, 58)
    # far side first: far leg, far arm
    part(s, f, [(92,108),(105,108),(104,124),(93,124)])
    part(s, f, [(93,127),(104,127),(103,141),(94,141)])
    part(s, f, [(91,121),(105,121),(106,126),(104,129),(92,129),(90,126)], ky=0.6)
    part(s, f, [(94,139),(103,139),(104,144),(111,148),(113,153),(108,156),(97,156),(93,152),(94,145)], LE, [0.55, 0.1], ky=0.6)
    part(s, f, [(105,68),(114,68),(115,86),(107,88)], ky=0.2)
    part(s, f, [(107,86),(115,86),(114,99),(108,99)], ky=0.2)
    part(s, f, [(108,98),(115,98),(115,104),(112,108),(109,107)], SK, [0.35], ky=0.5)
    # near leg
    part(s, f, [(75,110),(90,110),(89,127),(77,127)])
    part(s, f, [(77,130),(88,130),(87,146),(78,146)])
    part(s, f, [(75,124),(89,124),(90,129),(88,132),(76,132),(74,129)], ky=0.6)
    part(s, f, [(77,144),(87,144),(88,150),(94,155),(96,160),(91,163),(80,163),(76,158),(77,150)], LE, [0.55, 0.1], ky=0.6)
    # fauld, barrel, belt
    part(s, f, [(73,94),(108,92),(111,102),(111,110),(75,113),(72,104)], ky=0.2)
    line(s, f, (73,103), (110,101), '1')
    part(s, f, [(72,60),(100,57),(108,62),(110,78),(108,92),(96,96),(80,95),(70,90),(68,75)], ky=0.45)
    part(s, f, [(69,85),(80,90),(94,91),(110,85),(110,90),(94,97),(80,96),(69,91)], LE, [0.5, 0.0], ky=0.9)
    fill(s, f, [(95,90),(101,90),(101,97),(95,97)], 'n'); fill(s, f, [(96,91),(100,91),(100,96),(96,96)], 'm')
    # gorget: a collar round the neck, its back at the nape, not the ear; it passes behind the jaw
    part(s, f, [(78,50),(86,52),(96,57),(106,55),(108,61),(100,66),(84,66),(75,60)], *P4, ky=0.9, only=NOTHEAD)
    # far pauldron, then the near arm and pauldron
    part(s, f, [(100,60),(108,57),(115,59),(119,65),(117,73),(109,75),(102,71)], *P4, ky=0.9)
    part(s, f, [(61,74),(74,74),(74,91),(63,91),(60,83)], ky=0.2)
    part(s, f, [(61,90),(72,90),(71,102),(63,102)], ky=0.2)
    part(s, f, [(61,89),(73,89),(73,93),(61,93)], IR, [0.6, 0.3], ky=0.8)
    part(s, f, [(62,101),(71,101),(71,107),(69,112),(64,112),(62,107)], SK, [0.35], ky=0.5)
    line(s, f, (75,76), (75,90), '0')
    part(s, f, [(56,66),(60,58),(67,54),(76,55),(82,61),(83,70),(78,77),(64,78),(57,73)], ['4','3','2','1'], [0.9, 0.62, 0.2], ky=0.9)
    line(s, f, (58,70), (82,68), '1')
    s.outline(f)

def E(s, f=2):
    keep_head(s, f, 55)
    # far leg (a step behind), near leg
    part(s, f, [(88,106),(99,106),(98,124),(89,124)])
    part(s, f, [(89,128),(98,128),(97,142),(90,142)])
    part(s, f, [(88,140),(97,140),(99,145),(106,149),(107,154),(98,156),(88,156),(87,150)], LE, [0.55, 0.1], ky=0.6)
    part(s, f, [(82,108),(96,108),(95,126),(84,126)])
    part(s, f, [(84,130),(94,130),(93,146),(85,146)])
    part(s, f, [(81,123),(96,123),(98,128),(95,131),(83,131),(81,128)], ky=0.6)
    part(s, f, [(83,144),(94,144),(96,150),(105,153),(108,158),(104,161),(86,161),(82,157)], LE, [0.55, 0.1], ky=0.6)
    # fauld, barrel, belt round the barrel
    part(s, f, [(78,91),(108,89),(111,99),(110,108),(80,111),(76,100)], ky=0.2)
    line(s, f, (77,100), (110,98), '1')
    part(s, f, [(80,56),(100,55),(108,60),(113,72),(111,86),(104,93),(84,93),(77,85),(75,70)], ky=0.45)
    part(s, f, [(76,82),(94,87),(112,81),(112,86),(94,92),(76,87)], LE, [0.5, 0.0], ky=0.9)
    # gorget round the neck, below the ear
    part(s, f, [(84,47),(92,49),(104,51),(110,50),(111,55),(105,60),(88,60),(81,54)], *P4, ky=0.9, only=NOTHEAD)
    # near arm over the side: own planes, a shadow edge front and back
    up = [(86,70),(99,70),(100,88),(88,89),(85,80)]
    fo = [(88,87),(99,87),(101,99),(91,100)]
    ha = [(91,98),(101,98),(102,104),(99,109),(93,109),(90,104)]
    part(s, f, up, ky=0.2); part(s, f, fo, ky=0.2)
    part(s, f, [(87,86),(100,86),(100,90),(87,90)], IR, [0.6, 0.3], ky=0.8)
    part(s, f, ha, SK, [0.35], ky=0.5)
    ink(s, f, [up, fo, ha])
    part(s, f, [(81,62),(87,55),(97,53),(105,57),(108,64),(106,72),(98,76),(86,76),(80,70)], *P4, ky=0.9)
    line(s, f, (81,69), (107,68), '1')
    s.outline(f)

def N(s):
    f = 4
    keep_head(s, f, 44)
    clear(s, f, [(70,20),(106,20),(106,48),(70,48)])
    part(s, f, [(80,25),(85,22),(92,22),(97,25),(99,32),(99,40),(95,46),(81,46),(77,40),(77,32)], SK, [0.42], ky=0.8)
    for g in (ID, mirror):
        part(s, f, g([(71,105),(87,105),(86,122),(73,122),(71,113)]))
        part(s, f, g([(73,125),(85,125),(84,141),(75,141)]))
        part(s, f, g([(72,119),(86,119),(86,127),(73,127)]), ['2','1','1'], [0.5, 0.2], ky=0.6)
        part(s, f, g([(74,139),(84,139),(85,145),(85,151),(82,154),(74,154),(72,150),(73,145)]), LE, [0.55, 0.1], ky=0.6)
    part(s, f, [(70,90),(106,90),(108,98),(108,107),(68,107),(68,98)], ky=0.2)
    line(s, f, (69,98), (107,98), '1')
    part(s, f, [(72,50),(104,50),(106,64),(107,80),(100,86),(88,88),(76,86),(69,80),(70,64)], ky=0.45)
    line(s, f, (88,52), (88,85), '1')                       # backplate ridge
    part(s, f, [(68,78),(76,83),(88,86),(100,83),(108,78),(108,83),(100,89),(88,92),(76,89),(68,83)], LE, [0.5, 0.0], ky=0.9)
    part(s, f, [(76,40),(88,42),(100,40),(102,46),(96,51),(80,51),(74,46)], *P4, ky=0.9, only=NOTHEAD)
    up = [(60,62),(71,62),(72,74),(70,86),(60,86),(58,74)]
    fo = [(59,85),(69,85),(68,97),(60,97)]
    ha = [(60,96),(68,96),(68,102),(66,107),(61,107),(59,102)]
    for g in (ID, mirror):
        part(s, f, g(up), ky=0.2); part(s, f, g(fo), ky=0.2)
        part(s, f, g([(59,84),(70,84),(70,88),(59,88)]), IR, [0.6, 0.3], ky=0.8)
        part(s, f, g(ha), SK, [0.35], ky=0.5)
        ink(s, f, [g(up), g(fo), g(ha)], skip=[g([(56,60),(76,60),(76,68),(56,68)])])
        part(s, f, g([(51,58),(54,50),(61,46),(70,46),(76,50),(78,58),(76,66),(70,70),(58,70),(52,66)]), *P4, ky=0.9)
        line(s, f, *g([(53,62),(77,62)]), '1')
    s.outline(f)

def NE(s, f=3, g=ID):
    keep_head(s, f, 46)
    up = [(62,58),(72,58),(72,78),(63,78)]; fo = [(62,77),(71,77),(70,92),(63,92)]
    ha = [(63,91),(70,91),(70,97),(67,100),(63,99),(62,95)]
    part(s, f, g(up), ky=0.2); part(s, f, g(fo), ky=0.2); part(s, f, g(ha), SK, [0.35], ky=0.5)
    ink(s, f, [g(up), g(fo), g(ha)])
    part(s, f, g([(78,104),(90,104),(89,120),(79,120)]))
    part(s, f, g([(79,123),(88,123),(87,138),(80,138)]))
    part(s, f, g([(78,117),(90,117),(89,125),(79,125)]), ['2','1','1'], [0.5, 0.2], ky=0.6)
    part(s, f, g([(79,136),(88,136),(90,141),(90,147),(85,149),(79,149),(77,144)]), LE, [0.55, 0.1], ky=0.6)
    part(s, f, g([(93,106),(106,106),(105,124),(95,124)]))
    part(s, f, g([(95,127),(105,127),(104,143),(96,143)]))
    part(s, f, g([(94,121),(106,121),(105,129),(95,129)]), ['2','1','1'], [0.5, 0.2], ky=0.6)
    part(s, f, g([(95,141),(105,141),(108,146),(109,152),(104,156),(96,156),(93,151)]), LE, [0.55, 0.1], ky=0.6)
    part(s, f, g([(70,90),(114,88),(115,98),(114,106),(72,108),(69,99)]), ky=0.2)
    line(s, f, *g([(70,99),(114,97)]), '1')
    part(s, f, g([(68,50),(98,46),(112,52),(116,68),(115,86),(100,93),(78,93),(68,86),(64,66)]), ky=0.45)
    part(s, f, g([(67,80),(90,87),(116,81),(116,86),(90,92),(67,85)]), LE, [0.5, 0.0], ky=0.9)
    part(s, f, g([(80,44),(90,46),(102,44),(106,48),(100,53),(84,53),(78,49)]), *P4, ky=0.9, only=NOTHEAD)
    part(s, f, g([(58,52),(63,45),(72,42),(81,45),(84,53),(81,62),(70,65),(60,61)]), *P4, ky=0.9)
    line(s, f, *g([(59,57),(83,56)]), '1')
    up = [(107,72),(119,72),(119,90),(109,90)]; fo = [(109,89),(118,89),(117,101),(110,101)]
    ha = [(110,100),(117,100),(117,106),(115,110),(111,110),(109,106)]
    part(s, f, g(up), ky=0.2); part(s, f, g(fo), ky=0.2)
    part(s, f, g([(108,88),(119,88),(119,92),(108,92)]), IR, [0.6, 0.3], ky=0.8)
    part(s, f, g(ha), SK, [0.35], ky=0.5)
    ink(s, f, [g(up), g(fo), g(ha)], skip=[g([(104,70),(122,70),(122,76),(104,76)])])
    part(s, f, g([(100,60),(108,54),(117,55),(123,62),(121,72),(111,77),(102,73)]), *P4, ky=0.9)
    line(s, f, *g([(101,67),(122,66)]), '1')
    s.outline(f)

def chin_dots(s, f):
    """Old head-outline remnants: an interior soot 0 pixel with skin above and plate below takes the plate colour."""
    for y in range(1, 175):
        for x in range(1, 175):
            if s.get(f, x, y) != 'K': continue
            up, dn = s.get(f, x, y - 1), s.get(f, x, y + 1)
            if up in 'ABCDE' and dn in '01234' and '.' not in (s.get(f, x - 1, y), s.get(f, x + 1, y)):
                s.put(f, x, y, dn)

class Mirror:
    """Draw a facing's shapes mirrored about the pivot column; the light is flipped back so the key stays left."""
    def __init__(self, s): self.s = s
    def get(self, f, x, y): return self.s.get(f, 175 - x, y)
    def put(self, f, x, y, ch): self.s.put(f, 175 - x, y, ch)
    def outline(self, f): self.s.outline(f)

def mirrored(fn, f):
    import draw
    def run(s):
        global NRM
        old, keep = draw.LIGHT, NRM
        draw.LIGHT = (-old[0], old[1], old[2]); NRM = {}
        try: fn(Mirror(s), f)
        finally:
            draw.LIGHT = old
            for (ff, x, y), n in NRM.items(): keep[(ff, 175 - x, y)] = np.array([-n[0], n[1], n[2]])
            NRM = keep
    return run

def W(s): mirrored(E, 6)(s)
def SW(s): mirrored(SE, 7)(s)
def NW(s): mirrored(NE, 5)(s)

if __name__ == '__main__':
    s = orc_global()
    for fn in sys.argv[1:]:
        globals()[fn](s)
    for f in range(8): chin_dots(s, f)
    s.save(O + 'orc_p.png')
    import normals
    print('flat fallback px', normals.build(s.a, O + 'orig/orc_look_heartland_normal.png', NRM, O + 'orc_p_normal.png'))
