"""Labelled review contact sheet of a packed strip (Python standard library only).

  python tools/pipeline/contact_sheet.py <manifest.json> <out.png> [--zoom 4]

Draws every frame of the strip at --zoom (nearest neighbour) in a grid of four columns, each
labelled with its facing index and name, a pivot tick under each cell, and a header naming the
body, clip, camera numbers and palette status. Text is drawn at the same zoom as the frames, and
the 1x game-scale strip is a separate file (<out>_1x.png): one texel size per image, never mixels.
For the director's look gate; it changes nothing in the sheet.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from pixfont import GLYPH_H, draw_text, text_width
from pngio import Image, read_png, write_png

PIPELINE = Path(__file__).resolve().parent
CAMERA_FILE = PIPELINE / "camera_rig.json"
COLUMNS = 4
MARGIN = 16
GAP = 16
LINE_GAP = 6
BG = (103, 113, 124, 255)  # slate mid step of the draft palette: neutral, not black or white
CELL_BG = (132, 140, 148, 255)
INK = (20, 18, 22, 255)
WARN = (142, 27, 36, 255)
PIVOT_TICK = (217, 185, 46, 255)
TICK_TEXELS = 2


def fill(img: Image, x0: int, y0: int, w: int, h: int, colour) -> None:
    for y in range(max(0, y0), min(img.height, y0 + h)):
        for x in range(max(0, x0), min(img.width, x0 + w)):
            img.put(x, y, colour)


def blit(dst: Image, src: Image, sx: int, sy: int, w: int, h: int, dx: int, dy: int, zoom: int) -> None:
    for y in range(h):
        for x in range(w):
            px = src.get(sx + x, sy + y)
            if px[3] == 0:
                continue
            for zy in range(zoom):
                for zx in range(zoom):
                    dst.put(dx + x * zoom + zx, dy + y * zoom + zy, px)


def build(manifest_path: Path, zoom: int) -> Image:
    m = json.loads(manifest_path.read_text(encoding="utf-8"))
    cam = json.loads(CAMERA_FILE.read_text(encoding="utf-8"))
    strip = read_png(manifest_path.parent / m["image"])
    fw, fh = m["frame_w"], m["frame_h"]
    cell_w, cell_h = fw * zoom, fh * zoom
    label_scale = title_scale = zoom  # text texels match art texels
    tick_px = TICK_TEXELS * zoom
    label_h = GLYPH_H * label_scale + LINE_GAP
    rows = (len(m["frames"]) + COLUMNS - 1) // COLUMNS
    lines = [
        (f"{m['body']} {m['layer']} {m['clip']}  {len(m['frames'])} facings", INK),
        (f"pitch {cam['pitch_deg']:g}°  {cam['char_height_px']} px  x{zoom}", INK),
        (f"base body, no head or hair layer. palette {m['palette'].get('status', '')}", WARN),
    ]
    header_h = len(lines) * (GLYPH_H * title_scale + LINE_GAP)
    grid_w = COLUMNS * cell_w + (COLUMNS - 1) * GAP
    width = MARGIN * 2 + max(grid_w, max(text_width(t, title_scale) for t, _ in lines))
    grid_top = MARGIN + header_h + GAP
    height = grid_top + rows * (label_h + cell_h + tick_px + GAP) + MARGIN
    img = Image.blank(width, height)
    fill(img, 0, 0, width, height, BG)
    y = MARGIN
    for text, colour in lines:
        draw_text(img, MARGIN, y, text, colour, title_scale)
        y += GLYPH_H * title_scale + LINE_GAP
    for i, fr in enumerate(m["frames"]):
        col, row = i % COLUMNS, i // COLUMNS
        x0 = MARGIN + col * (cell_w + GAP)
        y0 = grid_top + row * (label_h + cell_h + tick_px + GAP)
        draw_text(img, x0, y0, f"{fr.get('index', i)} {fr['facing']}", INK, label_scale)
        fill(img, x0, y0 + label_h, cell_w, cell_h, CELL_BG)
        blit(img, strip, fr["x"], fr["y"], fw, fh, x0, y0 + label_h, zoom)
        tick_x = x0 + m["pivot"]["x"] * zoom
        fill(img, tick_x, y0 + label_h + cell_h, zoom, tick_px, PIVOT_TICK)
    return img


def game_scale_strip(manifest_path: Path) -> Image:
    """The strip at 1x on the cell background: its own image, so no texel size is mixed."""
    m = json.loads(manifest_path.read_text(encoding="utf-8"))
    strip = read_png(manifest_path.parent / m["image"])
    img = Image.blank(strip.width, strip.height)
    fill(img, 0, 0, img.width, img.height, CELL_BG)
    blit(img, strip, 0, 0, strip.width, strip.height, 0, 0, 1)
    return img


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="labelled contact sheet of a packed strip")
    p.add_argument("manifest", type=Path)
    p.add_argument("out", type=Path)
    p.add_argument("--zoom", type=int, default=4)
    a = p.parse_args(argv)
    write_png(a.out, build(a.manifest, a.zoom))
    strip_out = a.out.with_name(a.out.stem + "_1x.png")
    write_png(strip_out, game_scale_strip(a.manifest))
    print(f"CONTACT_SHEET {a.out} {strip_out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
