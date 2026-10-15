"""Palette contract check (06_STYLE_ART.md section 2): a palette file is well formed, and every opaque
pixel of every image given is one of its colours.

  python tools/pipeline/validate_palette.py --palette <palette.json> [image.png ...]

The palette must be mercs.palette/1, hold 48 to 65 distinct colours in named ramps (palette_lib checks
schema and duplicates). For each image, pixels with alpha 0 are ignored; any other pixel whose RGB is not
in the palette is counted. Prints one line per image (PASS/FAIL, off-palette pixel count, colours used)
and exits 1 on any failure.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette_lib import load_palette  # noqa: E402
from pngio import read_png  # noqa: E402

MIN_COLOURS = 48
MAX_COLOURS = 65  # core + biome cap: 44 + 21 (verdure_mid, director grass B, 2026-10-16)


def check_image(path: Path, allowed: set[int]) -> tuple[int, int]:
    """Off-palette opaque pixels and colours used (standard library only, like the rest of the pipeline)."""
    img = read_png(path)
    px = img.rgba
    bad, used = 0, set()
    for i in range(0, len(px), 4):
        if px[i + 3] == 0:
            continue
        key = (px[i] << 16) | (px[i + 1] << 8) | px[i + 2]
        used.add(key)
        bad += key not in allowed
    return bad, len(used)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--palette", required=True, type=Path)
    p.add_argument("images", nargs="*", type=Path)
    a = p.parse_args(argv)
    pal = load_palette(a.palette)
    ok = True
    n = len(pal.colours)
    names = [r for r, _ in pal.ramps]
    if not MIN_COLOURS <= n <= MAX_COLOURS or len(set(names)) != len(names):
        print(f"FAIL palette {pal.id}: {n} colours (need {MIN_COLOURS}-{MAX_COLOURS}), ramps {names}")
        ok = False
    else:
        print(f"PASS palette {pal.id}: {n} colours in {len(names)} named ramps ({pal.status})")
    allowed = {(r << 16) | (g << 8) | b for r, g, b in pal.colours}
    for img in a.images:
        bad, used = check_image(img, allowed)
        print(f"{'PASS' if bad == 0 else 'FAIL'} {img.name}: {bad} off-palette pixels, {used} colours used")
        ok = ok and bad == 0
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
