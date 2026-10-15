"""Orc token (round 4): the finished sheet's SE frame at half scale (2x2 vote, skin and bone win ties),
outline redone, lone outline spikes and orphan pixels cleaned (the sheet's bone 3 tusk survives the vote)."""
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
    return H
if __name__ == '__main__':
    T = main(); T.save(O + 'orc_tok.png')
    import numpy as np
    ys, xs = np.nonzero(T.a[:, :, 3]); print(T.dump(0, xs.min() - 1, ys.min() - 1, xs.max() + 2, ys.max() + 2))
