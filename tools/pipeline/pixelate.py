"""Reduce 4x renders to 1x palette pixel art, deterministically (Python standard library only).

  python tools/pipeline/pixelate.py --in <render dir> --out <dir> [--layer body] [--config pixelate.json]

Every facing_*.png in --in is reduced by pixelate.json's scale (box mean over covered samples),
alpha is thresholded to 0 or 255, and each opaque pixel is mapped to the nearest colour of the
layer's ramps in the palette, with no dithering. Integer arithmetic only, sorted inputs and a
fixed PNG encoder: the same input bytes give byte-identical output (tools/pipeline/test_pipeline.py
proves it). Prints one `PIXELATED <file> <pixel sha256>` line per frame.

  python tools/pipeline/pixelate.py --normals --in <normal renders> --mask <1x colour frames> --out <dir>

Normal mode: the same block reduction, but the mean encoded normal is renormalised instead of
palette-quantised, and alpha is copied from the matching 1x colour frame so both line up exactly.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

from palette_lib import Palette, load_palette
from pngio import Image, read_png, write_png

PIPELINE = Path(__file__).resolve().parent
REPO = PIPELINE.parents[1]
DEFAULT_CONFIG = PIPELINE / "pixelate.json"
OPAQUE = 255
CONFIG_SCHEMA = "mercs.pixelate/1"
FLAT_NORMAL = (128, 128, 255)  # encoded +Z (toward camera), for a colour pixel with no normal sample
ENCODE_MAX = 255


def load_config(path: Path) -> dict:
    cfg = json.loads(path.read_text(encoding="utf-8"))
    if cfg.get("schema") != CONFIG_SCHEMA:
        raise ValueError(f"{path}: schema is not {CONFIG_SCHEMA}")
    return cfg


class Quantiser:
    """Nearest palette colour by squared RGB distance; ties go to the lowest index."""

    def __init__(self, colours: list[tuple[int, int, int]]):
        self.colours = colours
        self.cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}

    def nearest(self, rgb: tuple[int, int, int]) -> tuple[int, int, int]:
        hit = self.cache.get(rgb)
        if hit is None:
            r, g, b = rgb
            best, best_d = self.colours[0], None
            for c in self.colours:
                d = (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2
                if best_d is None or d < best_d:
                    best, best_d = c, d
            hit = self.cache[rgb] = best
        return hit


def reduce_image(src: Image, cfg: dict, quant: Quantiser) -> Image:
    scale = cfg["scale"]
    if src.width % scale or src.height % scale:
        raise ValueError(f"render {src.width}x{src.height} is not a multiple of scale {scale}")
    out = Image.blank(src.width // scale, src.height // scale)
    threshold, need = cfg["alpha_threshold"], cfg["coverage_min_samples"]
    data, w = src.rgba, src.width
    for oy in range(out.height):
        for ox in range(out.width):
            n = sr = sg = sb = 0
            for y in range(oy * scale, oy * scale + scale):
                row = y * w
                for x in range(ox * scale, ox * scale + scale):
                    i = (row + x) * 4
                    if data[i + 3] >= threshold:
                        n += 1
                        sr += data[i]
                        sg += data[i + 1]
                        sb += data[i + 2]
            if n >= need:
                half = n // 2
                mean = ((sr + half) // n, (sg + half) // n, (sb + half) // n)
                out.put(ox, oy, (*quant.nearest(mean), OPAQUE))
    return out


def encode_mean_normal(sr: int, sg: int, sb: int, n: int) -> tuple[int, int, int]:
    """Mean of n encoded samples, decoded to [-1, 1], renormalised and re-encoded n * 0.5 + 0.5."""
    v = [2.0 * c / (n * ENCODE_MAX) - 1.0 for c in (sr, sg, sb)]
    length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if length == 0.0:
        return FLAT_NORMAL
    return tuple(int(round((c / length * 0.5 + 0.5) * ENCODE_MAX)) for c in v)  # type: ignore[return-value]


def reduce_normals(src: Image, mask: Image, cfg: dict) -> Image:
    scale = cfg["scale"]
    if (src.width // scale, src.height // scale) != (mask.width, mask.height):
        raise ValueError("normal render and colour frame sizes do not match")
    out = Image.blank(mask.width, mask.height)
    threshold, data, w = cfg["alpha_threshold"], src.rgba, src.width
    for oy in range(out.height):
        for ox in range(out.width):
            if mask.get(ox, oy)[3] == 0:
                continue
            n = sr = sg = sb = 0
            for y in range(oy * scale, oy * scale + scale):
                for x in range(ox * scale, ox * scale + scale):
                    i = (y * w + x) * 4
                    if data[i + 3] >= threshold:
                        n += 1
                        sr += data[i]
                        sg += data[i + 1]
                        sb += data[i + 2]
            rgb = encode_mean_normal(sr, sg, sb, n) if n else FLAT_NORMAL
            out.put(ox, oy, (*rgb, OPAQUE))
    return out


def normals_dir(src_dir: Path, mask_dir: Path, out_dir: Path, cfg: dict) -> list[tuple[str, str]]:
    frames = sorted(src_dir.glob("facing_*.png"))
    if not frames:
        raise SystemExit(f"no facing_*.png in {src_dir}")
    results = []
    for path in frames:
        img = reduce_normals(read_png(path), read_png(mask_dir / path.name), cfg)
        write_png(out_dir / path.name, img)
        results.append((path.name, img.pixel_sha256()))
    return results


NEIGHBOURS_4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
NEIGHBOURS_8 = NEIGHBOURS_4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))


def luma(rgb) -> int:
    return 299 * rgb[0] + 587 * rgb[1] + 114 * rgb[2]


def despeckle(img: Image) -> Image:
    """Replace isolated dark pixels inside the figure with their neighbours' most common colour.

    A pixel is a speckle when all four neighbours are opaque, none of its eight neighbours shares
    its colour, and it is darker than every four-neighbour (block-mean noise, not a drawn line).
    Decided on the input image only, so the result does not depend on scan order.
    """
    out = Image.blank(img.width, img.height)
    out.rgba[:] = img.rgba
    for y in range(1, img.height - 1):
        for x in range(1, img.width - 1):
            px = img.get(x, y)
            if px[3] == 0:
                continue
            n4 = [img.get(x + dx, y + dy) for dx, dy in NEIGHBOURS_4]
            if any(n[3] == 0 for n in n4):
                continue
            if any(img.get(x + dx, y + dy)[:3] == px[:3] for dx, dy in NEIGHBOURS_8):
                continue
            if not all(luma(px) < luma(n) for n in n4):
                continue
            counts: dict = {}
            for n in n4:
                counts[n[:3]] = counts.get(n[:3], 0) + 1
            best = max(sorted(counts), key=lambda c: counts[c])  # ties: lowest colour wins
            out.put(x, y, (*best, OPAQUE))
    return out


def outline(img: Image, colour: tuple[int, int, int]) -> Image:
    """06 section 3 outline: every opaque pixel with a transparent 4-neighbour (or on the image
    edge) becomes the outline colour. Drawn on the figure's own edge pixels, so the silhouette,
    the pivot and the alpha the normal map copies do not change."""
    out = Image.blank(img.width, img.height)
    out.rgba[:] = img.rgba
    for y in range(img.height):
        for x in range(img.width):
            if img.get(x, y)[3] == 0:
                continue
            for dx, dy in NEIGHBOURS_4:
                nx, ny = x + dx, y + dy
                if not (0 <= nx < img.width and 0 <= ny < img.height) or img.get(nx, ny)[3] == 0:
                    out.put(x, y, (*colour, OPAQUE))
                    break
    return out


def pixelate_dir(src_dir: Path, out_dir: Path, layer: str, cfg: dict) -> list[tuple[str, str]]:
    pal: Palette = load_palette(REPO / cfg["palette"])
    quant = Quantiser(pal.ramp_colours(cfg["ramps_by_layer"].get(layer)))
    line = cfg.get("outline", {})
    line_colour = pal.ramp_colours([line["ramp"]])[line["step"]] if layer in line.get("layers", []) else None
    frames = sorted(src_dir.glob("facing_*.png"))
    if not frames:
        raise SystemExit(f"no facing_*.png in {src_dir}")
    results = []
    for path in frames:
        img = reduce_image(read_png(path), cfg, quant)
        if layer in cfg.get("despeckle_layers", []):
            img = despeckle(img)
        if line_colour is not None:
            img = outline(img, line_colour)
        write_png(out_dir / path.name, img)
        results.append((path.name, img.pixel_sha256()))
    return results


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="4x renders to 1x palette pixel art")
    p.add_argument("--in", dest="src", required=True, type=Path)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--layer", default="body")
    p.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    p.add_argument("--normals", action="store_true", help="reduce a normal pass (needs --mask)")
    p.add_argument("--mask", type=Path, help="1x colour frames whose alpha the normal frames copy")
    args = p.parse_args(argv)
    cfg = load_config(args.config)
    if args.normals:
        if args.mask is None:
            p.error("--normals needs --mask")
        args.out.mkdir(parents=True, exist_ok=True)
        results = normals_dir(args.src, args.mask, args.out, cfg)
    else:
        results = pixelate_dir(args.src, args.out, args.layer, cfg)
    for name, digest in results:
        print(f"PIXELATED {name} {digest}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
