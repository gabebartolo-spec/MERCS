"""Vampyr token (round 4): the finished sheet's SE frame at half scale (2x2 vote), outline redone, spikes and
orphan pixels cleaned."""
from tok import *
import vamp_paint as vp
from vamp_global import O
from orc_token import token
def main(s=None):
    s = s or vp.build(['S', 'SE', 'E', 'NE', 'N', 'NW', 'W', 'SW'])
    return token(s, 1, 'vampyr', O + 'vamp_tok.png')
if __name__ == '__main__':
    T = main(); T.save(O + 'vamp_tok.png')
    import numpy as np
    ys, xs = np.nonzero(T.a[:, :, 3]); print(T.dump(0, xs.min() - 1, ys.min() - 1, xs.max() + 2, ys.max() + 2))
