"""Reject mixels and fake pixels in 2D art (Python standard library plus pngio only; D-035).

  python tools/pipeline/validate_pixels.py <png> [<png> ...] [--palette <palette.json|.gpl>]

Per image:

  PIX-UPSCALED  the art is stored at k>1 pixels per texel: every run of one colour along every row
                and column is a multiple of k (k >= 2), or every aligned kxk block is near-uniform
                (at least 75% one colour) while the blocks themselves differ
  PIX-ALPHA     a pixel's alpha is neither 0 nor 255
  PIX-PALETTE   (with --palette) an opaque pixel is not a colour of the palette
  PIX-AA        (without --palette) an opaque pixel is a blend of two of its neighbours: an
                anti-aliased edge. With a palette such pixels are reported as PIX-PALETTE.

Findings print as `<png>:0: <RULE> <message>`; exit 1 if any, 2 on bad usage.
"""
from __future__ import annotations

import json
import re
import sys
from math import gcd
from pathlib import Path

from pngio import Image, PngError, read_png

MAX_FINDINGS = 3  # per rule per image
MAX_K = 16
NEAR_UNIFORM = 0.75  # share of a block one colour must hold
AA_MIN_SPAN = 24  # the two neighbours must differ by this much in some channel to count as an edge
AA_TOLERANCE = 3  # per-channel slack when matching a blend
Px = tuple[int, int, int, int]


def norm(px: Px) -> Px:
    return (0, 0, 0, 0) if px[3] == 0 else px


def grid(img: Image) -> list[list[Px]]:
    return [[norm(img.get(x, y)) for x in range(img.width)] for y in range(img.height)]


def run_gcd(lines: list[list[Px]]) -> int:
    g = 0
    for line in lines:
        n = 1
        for i in range(1, len(line)):
            if line[i] == line[i - 1]:
                n += 1
            else:
                g = gcd(g, n)
                n = 1
        g = gcd(g, n)
    return g


def upscale_factor(img: Image) -> int:
    """Smallest k >= 2 at which the image is a k-times upscale, or 0."""
    rows = grid(img)
    if len({p for r in rows for p in r}) < 2 or img.width < 4 or img.height < 4:
        return 0
    cols = [list(c) for c in zip(*rows)]
    g = gcd(run_gcd(rows), run_gcd(cols))
    if g >= 2:
        return min(k for k in range(2, g + 1) if g % k == 0)
    for k in range(2, MAX_K + 1):
        if img.width % k or img.height % k or img.width < 2 * k or img.height < 2 * k:
            continue
        if near_uniform_blocks(rows, img.width, img.height, k):
            return k
    return 0


def near_uniform_blocks(rows: list[list[Px]], w: int, h: int, k: int) -> bool:
    heads = set()
    for by in range(0, h, k):
        for bx in range(0, w, k):
            counts: dict[Px, int] = {}
            for y in range(by, by + k):
                for x in range(bx, bx + k):
                    counts[rows[y][x]] = counts.get(rows[y][x], 0) + 1
            top = max(counts, key=lambda c: counts[c])
            if counts[top] < NEAR_UNIFORM * k * k:
                return False
            heads.add(top)
    return len(heads) >= 2


def is_blend(c: Px, a: Px, b: Px) -> bool:
    """c lies on the straight line between a and b (strictly inside) in RGB."""
    ca, cb, cc = a[:3], b[:3], c[:3]
    span = max(range(3), key=lambda i: abs(ca[i] - cb[i]))
    if abs(ca[span] - cb[span]) < AA_MIN_SPAN:
        return False
    t = (cc[span] - ca[span]) / (cb[span] - ca[span])
    if not 0.1 <= t <= 0.9:
        return False
    return all(abs(cc[i] - (ca[i] + t * (cb[i] - ca[i]))) <= AA_TOLERANCE for i in range(3))


def aa_pixels(img: Image) -> list[tuple[int, int]]:
    rows = grid(img)
    out = []
    for y in range(img.height):
        for x in range(img.width):
            c = rows[y][x]
            if c[3] == 0:
                continue
            near = []
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and rows[ny][nx][3] == 255 and rows[ny][nx] != c:
                    near.append(rows[ny][nx])
            if any(is_blend(c, a, b) for i, a in enumerate(near) for b in near[i + 1:]):
                out.append((x, y))
    return out


def load_colours(path: Path) -> set[tuple[int, int, int]]:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".gpl":
        found = re.findall(r"^\s*(\d+)\s+(\d+)\s+(\d+)", text, re.M)
        return {(int(r), int(g), int(b)) for r, g, b in found}
    data = json.loads(text)
    colours = {tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for r in data["ramps"] for c in r["colours"]}
    if "core" in data:  # a biome palette: core ramps plus the biome's own (06 section 2)
        colours |= load_colours((path.parent / data["core"]).resolve())
    return colours


def check_image(img: Image, label: str, colours: set | None = None) -> list[str]:
    out: list[str] = []
    k = upscale_factor(img)
    if k:
        out.append(f"{label}:0: PIX-UPSCALED art is stored at {k} pixels per texel; save it at 1x")
    soft = [(x, y) for y in range(img.height) for x in range(img.width) if img.get(x, y)[3] not in (0, 255)]
    for x, y in soft[:MAX_FINDINGS]:
        out.append(f"{label}:0: PIX-ALPHA pixel ({x}, {y}) alpha {img.get(x, y)[3]}, must be 0 or 255")
    if colours is not None:
        bad = [(x, y) for y in range(img.height) for x in range(img.width)
               if img.get(x, y)[3] == 255 and img.get(x, y)[:3] not in colours]
        for x, y in bad[:MAX_FINDINGS]:
            r, g, b, _ = img.get(x, y)
            out.append(f"{label}:0: PIX-PALETTE pixel ({x}, {y}) #{r:02x}{g:02x}{b:02x} is not in the palette")
    else:
        for x, y in aa_pixels(img)[:MAX_FINDINGS]:
            out.append(f"{label}:0: PIX-AA pixel ({x}, {y}) is a blend of its neighbours (anti-aliased edge)")
    return out


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    colours = None
    files: list[str] = []
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "--palette" and args:
            try:
                colours = load_colours(Path(args.pop(0)))
            except (OSError, ValueError, KeyError) as exc:
                print(f"validate_pixels: cannot load palette: {exc}")
                return 2
        else:
            files.append(a)
    if not files:
        print("usage: validate_pixels.py <png> [...] [--palette <palette.json|.gpl>]")
        return 2
    bad = 0
    for f in files:
        try:
            lines = check_image(read_png(f), Path(f).as_posix(), colours)
        except (OSError, PngError, ValueError) as exc:
            lines = [f"{Path(f).as_posix()}:0: PIX-PNG cannot read: {exc}"]
        print("\n".join(lines) if lines else f"{Path(f).as_posix()}: ok")
        bad += bool(lines)
    print(f"validate_pixels: {len(files) - bad} of {len(files)} images pass")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
