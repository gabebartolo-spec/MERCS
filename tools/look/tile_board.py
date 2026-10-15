"""Compare overworld terrain-tile sets made by different methods, beside the overworld golden.

  python tools/look/tile_board.py --method A=<dir> --method B=<dir> [--method C=<dir>] --out <dir>
      [--name A="Blender rig"] [--golden assets/golden/overworld_map.png] [--golden-box x,y,w,h]

Each method folder holds one PNG per terrain type, named grass, road, forest, hill, water, shore
(.png). For every method the board shows, left to right: each tile repeated 6 x 6 (a seam shows as
a line or a step every tile width), then a 6 x 6 map mixing the six types in the golden's order
(grass and forest, a road, the shore, water), all at true 1x. Under each patch is its seam score:
the mean colour difference across the wrap-around edge divided by the mean difference between
neighbouring pixel columns (rows) inside the tile; 1.0 means the seam is no more visible than the
tile's own texture. LINE marks a seam above 1.5 that is also stronger than every edge inside the
tile (a faceted or striped tile has strong inner edges too, so a high score alone is not a line).
The worse axis is shown. The shore is an edge tile (grass north, water south),
so it is scored east to west only. On the left is a crop of the golden overworld map.

Writes tile_board_1x.png and tile_board_2x.png (the same board doubled, nearest-neighbour: separate
files, never mixed scales in one image) and prints the seam scores. A review image only; nothing
here ships. Trial tiles live in the vault, not the repo.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
TYPES = ("grass", "road", "forest", "hill", "water", "shore")
EDGE_TILES = {"shore"}  # tiles that only repeat east to west
REPEAT = 6
# The mixed patch: G grass, F forest, H hill, R road, S shore, W water (the golden's layout order).
MIXED = ("FFGGHH", "FGGGGH", "RRRRRR", "GGGGFF", "SSSSSS", "WWWWWW")
CODES = {"G": "grass", "F": "forest", "H": "hill", "R": "road", "S": "shore", "W": "water"}
DEFAULT_GOLDEN = REPO / "assets" / "golden" / "overworld_map.png"
DEFAULT_BOX = (420, 156, 384, 384)  # road, hills, forest edge, shore and water
SEAM_LINE = 1.5
GAP = 16
HEAD = 64
ROW_LABEL = 40
CAPTION = 30
BG = (24, 23, 26)
INK = (235, 229, 211)
WARN = (226, 120, 90)
MISSING = (90, 40, 60)


def font(size: int) -> ImageFont.ImageFont:
    for name in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def load_set(folder: Path) -> dict[str, Image.Image]:
    tiles = {}
    for kind in TYPES:
        path = folder / f"{kind}.png"
        if path.is_file():
            tiles[kind] = Image.open(path).convert("RGBA")
    return tiles


def _dist(a: tuple, b: tuple) -> float:
    return sum(abs(x - y) for x, y in zip(a[:3], b[:3])) / 3.0


def seam_score(tile: Image.Image, both_axes: bool = True) -> tuple[float, bool]:
    """(wrap-around edge difference over the mean inner edge difference, is it a line) for the worse axis."""
    w, h = tile.size
    px = tile.load()
    worst = (0.0, False)
    axes = [(w, h, lambda i, j: px[i, j])]
    if both_axes:
        axes.append((h, w, lambda i, j: px[j, i]))
    for n, m, at in axes:
        seam = sum(_dist(at(n - 1, j), at(0, j)) for j in range(m)) / m
        inner = [sum(_dist(at(i, j), at(i + 1, j)) for j in range(m)) / m for i in range(n - 1)]
        mean = sum(inner) / len(inner)
        ratio = seam / mean if mean > 0 else (0.0 if seam == 0 else float("inf"))
        line = ratio > SEAM_LINE and seam > max(inner)
        worst = max(worst, (ratio, line), key=lambda s: (s[1], s[0]))
    return worst


def repeat(tile: Image.Image, n: int = REPEAT) -> Image.Image:
    w, h = tile.size
    out = Image.new("RGBA", (w * n, h * n))
    for j in range(n):
        for i in range(n):
            out.paste(tile, (i * w, j * h))
    return out


def mixed(tiles: dict[str, Image.Image], size: tuple[int, int]) -> Image.Image:
    w, h = size
    out = Image.new("RGBA", (w * len(MIXED[0]), h * len(MIXED)), MISSING)
    for j, row in enumerate(MIXED):
        for i, code in enumerate(row):
            tile = tiles.get(CODES[code])
            if tile is not None and tile.size == size:
                out.paste(tile, (i * w, j * h))
    return out


def tile_size(tiles: dict[str, Image.Image]) -> tuple[int, int]:
    sizes = sorted({t.size for t in tiles.values()})
    return sizes[0] if sizes else (64, 64)


def board(methods: list[tuple[str, str, Path]], golden: Path, box: tuple[int, int, int, int]):
    rows = []
    report = []
    for key, name, folder in methods:
        tiles = load_set(folder)
        size = tile_size(tiles)
        patches = []
        for kind in TYPES:
            tile = tiles.get(kind)
            if tile is None:
                patches.append((kind, Image.new("RGBA", (size[0] * REPEAT, size[1] * REPEAT), MISSING), "missing"))
                report.append(f"{key} {kind}: missing")
                continue
            score, line = seam_score(tile, kind not in EDGE_TILES)
            note = f"{tile.size[0]}x{tile.size[1]}  seam {score:.2f}" + ("  LINE" if line else "")
            report.append(f"{key} {kind}: {note}")
            patches.append((kind, repeat(tile), note))
        patches.append(("mixed 6x6", mixed(tiles, size), f"{size[0]} px tiles"))
        rows.append((f"{key}  {name}", patches))
    gold = Image.open(golden).convert("RGBA")
    x, y, w, h = box
    crop = gold.crop((x, y, x + w, y + h))
    patch_w = max(p.size[0] for _, ps in rows for _, p, _ in ps)
    patch_h = max(p.size[1] for _, ps in rows for _, p, _ in ps)
    row_h = ROW_LABEL + patch_h + CAPTION
    width = GAP + crop.size[0] + GAP + (len(TYPES) + 1) * (patch_w + GAP)
    height = HEAD + max(len(rows) * (row_h + GAP), ROW_LABEL + crop.size[1] + CAPTION)
    img = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(img)
    d.text((GAP, 8), "Overworld terrain tiles, heartland: each tile repeated 6 x 6 at 1x (seams show as lines),"
           " then a mixed 6 x 6 map; seam score 1.0 = no more visible than the tile's own edges", fill=INK, font=font(30))
    d.text((GAP, HEAD), "Golden overworld (crop, 1x)", fill=INK, font=font(26))
    img.paste(crop, (GAP, HEAD + ROW_LABEL))
    d.text((GAP, HEAD + ROW_LABEL + crop.size[1] + 4), f"assets/golden crop {x},{y} {w}x{h}", fill=INK, font=font(20))
    left = GAP + crop.size[0] + GAP
    for r, (label, patches) in enumerate(rows):
        top = HEAD + r * (row_h + GAP)
        d.text((left, top), label, fill=INK, font=font(30))
        for c, (kind, patch, note) in enumerate(patches):
            px = left + c * (patch_w + GAP)
            img.paste(patch, (px, top + ROW_LABEL), patch)
            colour = WARN if ("LINE" in note or note == "missing") else INK
            d.text((px, top + ROW_LABEL + patch.size[1] + 2), f"{kind}: {note}", fill=colour, font=font(20))
    return img, report


def parse_pairs(values: list[str]) -> dict[str, str]:
    out = {}
    for value in values or []:
        key, _, rest = value.partition("=")
        out[key.strip()] = rest.strip()
    return out


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--method", action="append", required=True, help="KEY=folder, e.g. A=D:/.../A_blender")
    p.add_argument("--name", action="append", help='KEY="label", e.g. A="Blender rig"')
    p.add_argument("--golden", type=Path, default=DEFAULT_GOLDEN)
    p.add_argument("--golden-box", default=",".join(map(str, DEFAULT_BOX)))
    p.add_argument("--out", required=True, type=Path)
    a = p.parse_args()
    names = parse_pairs(a.name)
    methods = [(k, names.get(k, Path(v).name), Path(v)) for k, v in parse_pairs(a.method).items()]
    box = tuple(int(v) for v in a.golden_box.split(","))
    img, report = board(methods, a.golden, box)
    a.out.mkdir(parents=True, exist_ok=True)
    one = a.out / "tile_board_1x.png"
    two = a.out / "tile_board_2x.png"
    img.save(one, optimize=True)
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(two, optimize=True)
    for line in report:
        print("SEAM", line)
    print("BOARD", one)
    print("BOARD", two)


if __name__ == "__main__":
    main()
