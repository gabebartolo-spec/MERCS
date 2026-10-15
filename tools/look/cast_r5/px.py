"""Pixel paint kit: letter codes per palette colour, dump and patch frames."""
import numpy as np
from PIL import Image
from pal import load, R
P = load()
SKIN = {'orc': 'skin_orc', 'vampyr': 'skin_pale', 'avg': 'skin_neutral'}
def codes(merc):
    c = {}
    for i in range(4): c['Kkq Q'.replace(' ', '')[i]] = f'soot_{i}'
    for i in range(5): c['01234'[i]] = f'iron_{i}'
    for i in range(5): c['ABCDE'[i]] = f'{SKIN[merc]}_{i}'
    for i in range(5): c['vwxyz'[i]] = f'bone_{i}'
    for i in range(4): c['rstu'[i]] = f'cloth_faded_{i}'
    for i in range(5): c['mnopM'[i]] = f'timber_{i}'
    for i in range(5): c['fghij'[i]] = f'soil_{i}'
    return c
class Sheet:
    def __init__(self, path, merc):
        self.path = path; self.merc = merc
        self.a = np.array(Image.open(path).convert('RGBA'))
        self.code = codes(merc)
        self.rgb = {k: P[v] for k, v in self.code.items()}
        self.inv = {v: k for k, v in self.rgb.items()}
    def get(self, f, x, y):
        p = self.a[y, f * 176 + x]
        if p[3] == 0: return '.'
        return self.inv.get(tuple(int(v) for v in p[:3]), '?')
    def put(self, f, x, y, ch):
        X = f * 176 + x
        if ch == '.': self.a[y, X] = (0, 0, 0, 0)
        else: self.a[y, X] = (*self.rgb[ch], 255)
    def dump(self, f, x0, y0, x1, y1):
        out = ['    ' + ''.join(str((x // 10) % 10) if x % 10 == 0 else ' ' for x in range(x0, x1)),
               '    ' + ''.join(str(x % 10) for x in range(x0, x1))]
        for y in range(y0, y1):
            out.append(f'{y:3d} ' + ''.join(self.get(f, x, y) for x in range(x0, x1)))
        return '\n'.join(out)
    def patch(self, f, x0, y0, text):
        """text rows; ' ' leaves a pixel, '.' clears it, a code paints it. Leading '|' marks column x0."""
        for dy, row in enumerate(text.strip('\n').split('\n')):
            row = row.split('|', 1)[1] if '|' in row else row
            for dx, ch in enumerate(row):
                if ch != ' ': self.put(f, x0 + dx, y0 + dy, ch)
    def remap(self, f, mapping, box=None, where=None):
        """mapping {from_code: to_code} inside box (x0,y0,x1,y1) of frame f (f None = all)."""
        frames = range(8) if f is None else [f]
        for fr in frames:
            x0, y0, x1, y1 = box or (0, 0, min(176, self.a.shape[1]), self.a.shape[0])
            for y in range(y0, y1):
                for x in range(x0, x1):
                    c = self.get(fr, x, y)
                    if c in mapping and (where is None or where(fr, x, y)): self.put(fr, x, y, mapping[c])
    def outline(self, f=None):
        """Silhouette pixels (4-neighbour of clear) become soot_0; pixels that are soot_0 with no clear neighbour stay."""
        frames = range(8) if f is None else [f]
        H, W = self.a.shape[0], min(176, self.a.shape[1])
        for fr in frames:
            for y in range(H):
                for x in range(W):
                    if self.get(fr, x, y) == '.': continue
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        nx, ny = x + dx, y + dy
                        if not (0 <= nx < W and 0 <= ny < H) or self.get(fr, nx, ny) == '.':
                            self.put(fr, x, y, 'K'); break
    def save(self, path=None):
        Image.fromarray(self.a, 'RGBA').save(path or self.path)

def despeckle_sheet(s, skip='Ky'):
    """ai-slop-art 2.2 on a sheet: an interior pixel with no 4-neighbour of its colour takes the commonest
    neighbour colour (decided on the input). Outline, inner lines and tusks are deliberate and kept."""
    from collections import Counter
    N = ((1, 0), (-1, 0), (0, 1), (0, -1))
    n = 0
    for f in range(8):
        edits = []
        for y in range(1, 175):
            for x in range(1, 175):
                c = s.get(f, x, y)
                if c == '.' or c in skip: continue
                nb = [s.get(f, x + dx, y + dy) for dx, dy in N]
                if '.' in nb or c in nb: continue
                pick = [k for k in nb if k != 'K'] or nb
                edits.append((x, y, Counter(pick).most_common(1)[0][0]))
        for x, y, c in edits: s.put(f, x, y, c)
        n += len(edits)
    return n
