"""Vampyr round 4: his own armour, not the orc's (critic r3 V1-V4).

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
T3 = [0.62, 0.15]
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

def spaulder(s, f, pts, lame):
    part(s, f, pts, ['2', '1', '0'], [0.55, 0.1], ky=0.9)
    line(s, f, *lame, '0')

def S(s, f=0, mf=0):
    keep_head(s, f, 58); op.KEPT.clear()
    # the cape behind: seen at the sides, its hem dropping lower where a fold hangs
    cape(s, f, [(70,58),(106,58),(108,80),(108,110),(108,127),(107,134),(105,131),(103,137),(100,132),(97,134),
                (79,134),(76,131),(73,136),(71,132),(69,135),(68,128),(68,110),(68,80)], [])
    for g in (ID, mirror):
        part(s, f, g([(78,106),(87,106),(86,126),(79,126)]))
        part(s, f, g([(79,128),(86,128),(85,146),(80,146)]))
        part(s, f, g([(78,123),(87,123),(87,129),(79,129)]), ['2','1','0'], [0.5, 0.1], ky=0.6)
        part(s, f, g([(80,144),(86,144),(87,150),(86,156),(83,161),(79,158),(79,150)]), ky=0.6)
    # two small tassets over the hips, an inner line between them
    tl = [(78,98),(88,98),(88,108),(81,110),(77,106)]
    part(s, f, tl, ky=0.3); part(s, f, mirror(tl), ky=0.3)
    line(s, f, (88,99), (88,109), '0')
    # chest: a V to a narrow waist, one belt line
    part(s, f, [(74,58),(102,58),(104,66),(100,84),(97,97),(79,97),(76,84),(72,66)], ky=0.45)
    fill(s, f, [(79,96),(97,96),(97,98),(79,98)], '0')
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
    part(s, f, [(90,104),(98,104),(97,122),(91,122)]); part(s, f, [(91,126),(98,126),(97,142),(92,142)])
    part(s, f, [(90,120),(99,120),(99,127),(91,127)], ['2','1','0'], [0.5, 0.1], ky=0.6)
    part(s, f, [(92,140),(98,140),(102,145),(105,150),(102,152),(96,151),(92,147)], ky=0.6)
    part(s, f, [(77,106),(87,106),(86,126),(78,126)]); part(s, f, [(78,130),(86,130),(85,147),(79,147)])
    part(s, f, [(77,124),(87,124),(87,131),(78,131)], ['2','1','0'], [0.5, 0.1], ky=0.6)
    part(s, f, [(79,145),(86,145),(89,150),(92,156),(90,159),(85,158),(80,155),(78,150)], ky=0.6)
    tl = [(79,99),(89,99),(89,108),(82,110),(78,106)]; tr = [(89,99),(98,98),(100,105),(97,109),(90,109)]
    part(s, f, tl, ky=0.3); part(s, f, tr, ky=0.3); line(s, f, (89,99), (89,109), '0')
    part(s, f, [(76,58),(98,57),(102,63),(100,82),(96,97),(81,98),(78,84),(74,66)], ky=0.45)
    fill(s, f, [(81,97),(96,97),(96,99),(81,99)], '0')
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
         [fold((76,62), 69, 74, 134), fold((87,60), 86, 91, 138), fold((98,62), 102, 107, 134)], lit=0.93)
    part(s, f, [(77,51),(99,51),(103,55),(101,61),(75,61),(73,55)], ky=0.5)
    for g in (ID, mirror):
        ink(s, f, [g(up), g(fo), g(ha)], skip=[g([(58,68),(76,68),(76,76),(58,76)])])
        spaulder(s, f, g([(78,57),(71,58),(66,61),(62,66),(62,72),(65,75),(72,74),(75,69),(78,63)]), g([(63,70),(74,69)]))
    clip(s, f, mf)
    s.outline(f)

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
    return s

if __name__ == '__main__':
    s = build(sys.argv[1:])
    s.save(O + 'vamp_p.png')
    import normals
    print('flat fallback px', normals.build(s.a, O + 'orig/vampyr_look_heartland_normal.png', op.NRM, O + 'vamp_p_normal.png'))
