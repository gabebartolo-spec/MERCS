"""Normal strip for a repainted sheet: alpha = colour alpha; redrawn pixels take the normal of the volume they
were shaded with; kept pixels keep their rendered normal; anything else takes the mean of its normal neighbours."""
import numpy as np
from PIL import Image
def enc(n):
    n = np.asarray(n, float); n = n / np.linalg.norm(n)
    return (int(round((n[0] + 1) / 2 * 255)), int(round((1 - n[1]) / 2 * 255)), int(round((n[2] + 1) / 2 * 255)))
def build(colour_rgba, orig_normal_path, nrm, out_path):
    col = colour_rgba
    old = np.array(Image.open(orig_normal_path).convert('RGBA'))
    out = np.zeros_like(old)
    todo = []
    H, W = col.shape[:2]
    for y in range(H):
        for x in range(W):
            if col[y, x, 3] == 0: continue
            f, fx = divmod(x, 176)
            if (f, fx, y) in nrm: out[y, x] = (*enc(nrm[(f, fx, y)]), 255)
            elif old[y, x, 3]: out[y, x] = old[y, x]
            else: todo.append((x, y))
    for _ in range(6):
        left = []
        for x, y in todo:
            nb = [out[y + dy, x + dx, :3].astype(float) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))
                  if 0 <= x + dx < W and 0 <= y + dy < H and out[y + dy, x + dx, 3]]
            if nb: out[y, x] = (*np.mean(nb, 0).round().astype(int), 255)
            else: left.append((x, y))
        todo = left
    for x, y in todo: out[y, x] = (128, 128, 255, 255)
    Image.fromarray(out, 'RGBA').save(out_path)
    return len(todo)
