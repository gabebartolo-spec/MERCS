"""Token = a sheet facing at half scale: 2x2 majority vote (skin and eyes win ties), outline, then hand edits."""
import sys
from collections import Counter
import numpy as np
from PIL import Image
from px import *
PRIORITY = 'KABCDEvwxyz'   # small features survive the vote
def half(sheet, f, merc, out):
    t = Sheet(out, merc) if False else None
    tok = np.zeros((88, 88, 4), np.uint8)
    T = Sheet.__new__(Sheet); T.a = tok; T.merc = merc; T.code = sheet.code; T.rgb = sheet.rgb; T.inv = sheet.inv; T.path = out
    for y in range(88):
        for x in range(88):
            cs = [sheet.get(f, 2 * x + dx, 2 * y + dy) for dy in (0, 1) for dx in (0, 1)]
            op = [c for c in cs if c != '.']
            if len(op) < 2: continue
            inner = [c for c in op if c != 'K']
            cnt = Counter(inner or op)
            best = max(cnt.items(), key=lambda kv: (kv[1], kv[0] in PRIORITY))[0]
            T.put(0, x, y, best)
    return T


def despeckle(T, keep=()):
    """ai-slop-art 2.2: an interior pixel with no 4-neighbour of its colour takes the commonest neighbour colour
    (decided on the input, so scan order does not matter). keep: (x, y) pixels that are deliberate (the eye)."""
    N = ((1, 0), (-1, 0), (0, 1), (0, -1))
    edits = []
    for y in range(1, 87):
        for x in range(1, 87):
            c = T.get(0, x, y)
            if c == '.' or (x, y) in keep: continue
            nb = [T.get(0, x + dx, y + dy) for dx, dy in N]
            if '.' in nb or c in nb: continue
            edits.append((x, y, Counter(nb).most_common(1)[0][0]))
    for x, y, c in edits: T.put(0, x, y, c)
    return len(edits)
