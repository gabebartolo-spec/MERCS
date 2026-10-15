from tok import *
import orc_paint as op
from orc_global import orc_global, O
import draw
def spikes(H):
    """Outline pixels that stick out alone (<= 1 opaque 4-neighbour) are cleared, then the outline is redone."""
    for _ in range(2):
        for y in range(1, 87):
            for x in range(1, 87):
                if H.get(0, x, y) == 'K' and sum(H.get(0, x + dx, y + dy) != '.' for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))) <= 1:
                    H.put(0, x, y, '.')
    H.outline(0)
def eye(H, row):
    xs = [x for x in range(88) if H.get(0, x, row) in 'ABCDE']
    H.put(0, max(xs) - 1, row, 'K')
def main():
    s = orc_global()
    op.SE(s); op.chin_dots(s, 1)
    H = half(s, 1, 'orc', O + 'orc_tok.png')
    for y in range(88):                      # keep only the head from the vote
        for x in range(88):
            if y > 29 or H.get(0, x, y) not in 'ABCDEvwxyzK': H.put(0, x, y, '.')
    draw.SCALE = 0.5; p4 = op.P4; op.P4 = (['3', '2', '1'], [0.55, 0.1])
    try: op.SE(H, 0)
    finally: draw.SCALE = 1.0; op.P4 = p4
    H.outline(0)
    spikes(H)
    despeckle(H)
    H.put(0, 49, 22, 'K')            # one deliberate eye pixel, under the lit brow
    H.put(0, 49, 21, 'D'); H.put(0, 48, 21, 'D')
    return H
if __name__ == '__main__':
    T = main(); T.save(O + 'orc_tok.png')
    import numpy as np
    ys, xs = np.nonzero(T.a[:, :, 3]); print(T.dump(0, xs.min() - 1, ys.min() - 1, xs.max() + 2, ys.max() + 2))
