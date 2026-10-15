"""Orc token (round 6): the finished sheet's SE frame at half scale (2x2 vote, skin and bone win ties),
outline redone, lone outline spikes and orphan pixels cleaned; then the head by hand at half scale
(critic r4: the jaw and tusks must survive the vote): brow, soot eyes and mouth, 1x2 tusks in bone 3."""
from tok import *
import orc_paint as op
from orc_global import O
def spikes(H):
    """Outline pixels that stick out alone (<= 1 opaque 4-neighbour) are cleared, then the outline is redone."""
    for _ in range(2):
        for y in range(1, 87):
            for x in range(1, 87):
                if H.get(0, x, y) == 'K' and sum(H.get(0, x + dx, y + dy) != '.' for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))) <= 1:
                    H.put(0, x, y, '.')
    H.outline(0)
def token(sheet, f, merc, out, keep=()):
    H = half(sheet, f, merc, out)
    H.outline(0); spikes(H)
    despeckle(H, keep=keep)
    return H
def main(s=None):
    s = s or op.build(['S', 'SE', 'E', 'NE', 'N', 'NW', 'W', 'SW'])
    H = token(s, 1, 'orc', O + 'orc_tok.png')
    face(H)
    return H

TOKEN_HEAD = (39, 16, [            # the SE head at half scale, by hand (round 6): rounded crown 6/10/12, brow arches
    "    KKKKKK     ",               # (lit near arch step 4), ear at the left, a step-1 shadow over 2x1 eyes, a nose,
    "  KKEDDDDCKK   ",               # a straight mouth with the tusks crossing it (base below, tip above: no upturned
    " KEDDDDDDCCCK  ",               # corners, so it does not read as a grin), the jaw wider than the crown, a neck
    " KDEEEDCDDDDCK ",
    "KDKCBBCDCBBCK  ",
    "KCKCKKCDCKKCK  ",
    " KKDCCCDDBCCK  ",
    " KDCCyCCCyCCCK ",
    " KDCKyKKKyKCCK ",
    " KCCCyCCCyCCCK ",
    " KKKBBBBBKKKKK ",
])

def face(H):
    x0, y0, rows = TOKEN_HEAD
    cells = {(x0 + i, y0 + j): ch for j, r in enumerate(rows) for i, ch in enumerate(r) if ch != ' '}
    for y in range(y0 - 3, y0 + len(rows)):
        for x in range(x0 - 2, x0 + len(rows[0])):
            if (x, y) not in cells and H.get(0, x, y) in 'ABCDEKy': H.put(0, x, y, '.')
    for (x, y), ch in cells.items(): H.put(0, x, y, ch)
    H.outline(0)

if __name__ == '__main__':
    T = main(); T.save(O + 'orc_tok.png')
    import numpy as np
    ys, xs = np.nonzero(T.a[:, :, 3]); print(T.dump(0, xs.min() - 1, ys.min() - 1, xs.max() + 2, ys.max() + 2))
