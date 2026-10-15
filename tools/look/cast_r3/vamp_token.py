from tok import *
import orc_paint as op
import vamp_paint as vp
from vamp_global import vamp_global, O
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
    s = vamp_global()
    vp.SE(s); op.chin_dots(s, 1)
    H = half(s, 1, 'vampyr', O + 'vamp_tok.png')
    for y in range(88):
        for x in range(88):
            if y > 31 or H.get(0, x, y) not in 'ABCDEvwxyzK': H.put(0, x, y, '.')
    draw.SCALE = 0.5
    try: vp.SE(H, 0)
    finally: draw.SCALE = 1.0
    H.outline(0)
    spikes(H)
    despeckle(H)
    eye(H, 23)
    return H
if __name__ == '__main__':
    T = main(); T.save(O + 'vamp_tok.png')
    import numpy as np
    ys, xs = np.nonzero(T.a[:, :, 3]); print(T.dump(0, xs.min() - 1, ys.min() - 1, xs.max() + 2, ys.max() + 2))
