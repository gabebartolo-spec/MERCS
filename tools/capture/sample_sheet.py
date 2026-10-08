"""Labelled director sheets for sample set 2 (Python standard library only).

  python -I tools/capture/sample_sheet.py <OUT>

Reads what tools/capture/sample_set_2.sh wrote to OUT (stills/*_crop.png, depth/*_crop.png,
frame_times.txt) and writes OUT/sheet_pixel_mode.png and OUT/sheet_depth.png: a 2 x 2 grid of
crops, each labelled in the top-left, a header and the recommendation. Review images only.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "pipeline"))
from pixfont import GLYPH_H, draw_text, text_width  # noqa: E402
from pngio import Image, read_png, write_png  # noqa: E402

MARGIN = 24
GAP = 16
LABEL_SCALE = 2
FOOT_SCALE = 2
TITLE_SCALE = 4
PAD = 8
BG = (40, 40, 44, 255)
INK = (236, 232, 222, 255)
TAG_BG = (12, 12, 14, 255)


def fill(img: Image, x0: int, y0: int, w: int, h: int, colour) -> None:
    for y in range(max(0, y0), min(img.height, y0 + h)):
        row = bytes(colour) * max(0, min(img.width, x0 + w) - max(0, x0))
        i = (y * img.width + max(0, x0)) * 4
        img.rgba[i:i + len(row)] = row


def paste(dst: Image, src: Image, dx: int, dy: int) -> None:
    for y in range(src.height):
        s = y * src.width * 4
        d = ((dy + y) * dst.width + dx) * 4
        dst.rgba[d:d + src.width * 4] = src.rgba[s:s + src.width * 4]


def tag(img: Image, x: int, y: int, text: str) -> None:
    h = GLYPH_H * LABEL_SCALE + 2 * PAD
    fill(img, x, y, text_width(text, LABEL_SCALE) + 2 * PAD, h, TAG_BG)
    draw_text(img, x + PAD, y + PAD, text, INK, LABEL_SCALE)


def grid(cells: list[tuple[Path, str]], title: str, footer: list[str]) -> Image:
    crops = [read_png(path) for path, _ in cells]
    cw, ch = crops[0].width, crops[0].height
    line = GLYPH_H * TITLE_SCALE + GAP
    label_h = GLYPH_H * LABEL_SCALE + 2 * PAD
    row_h = label_h + ch + GAP
    width = 2 * MARGIN + 2 * cw + GAP
    height = 2 * MARGIN + line + 2 * row_h + len(footer) * (GLYPH_H * FOOT_SCALE + GAP)
    img = Image.blank(width, height)
    fill(img, 0, 0, width, height, BG)
    draw_text(img, MARGIN, MARGIN, title, INK, TITLE_SCALE)
    top = MARGIN + line
    for i, (crop, (_, label)) in enumerate(zip(crops, cells)):
        x = MARGIN + (i % 2) * (cw + GAP)
        y = top + (i // 2) * row_h
        tag(img, x, y, label)
        paste(img, crop, x, y + label_h)
    y = top + 2 * row_h
    for text in footer:
        draw_text(img, MARGIN, y, text, INK, FOOT_SCALE)
        y += GLYPH_H * FOOT_SCALE + GAP
    return img


def frame_times(out: Path) -> dict[str, str]:
    times: dict[str, str] = {}
    for row in (out / "frame_times.txt").read_text(encoding="utf-8").splitlines():
        parts = row.split()
        if len(parts) >= 4 and parts[2] == "frame_time_ms":
            times[f"{parts[0]}_{parts[1]}"] = parts[3]
    return times


def main(argv: list[str]) -> int:
    out = Path(argv[1])
    ms = frame_times(out)
    names = {"whole": "A WHOLE SCREEN", "crisp": "B CRISP WORLD"}
    lights = {"day": "DAY", "rain_night": "RAIN NIGHT"}
    cells = []
    for light in ("day", "rain_night"):
        for mode in ("whole", "crisp"):
            key = f"{mode}_{light}"
            label = f"{names[mode]} - {lights[light]} - {ms.get(key, '?')} MS"
            cells.append((out / "stills" / f"{key}_crop.png", label))
    write_png(out / "sheet_pixel_mode.png", grid(
        cells, "SAMPLE SET 2: PIXEL MODE (35 DEG, 48 PX)",
        ["CROPS 2X OF THE 1920X1080 FRAME. MS = MEAN FRAME TIME, VSYNC OFF, RTX 4070 SUPER.",
         "RECOMMENDED: A (WHOLE SCREEN): ONE PIXEL GRID FOR WORLD AND PEOPLE."]))
    depth = []
    for scale, word in (("perspective", "PERSPECTIVE"), ("constant", "CONSTANT")):
        for spot, where in (("near", "4 M NEARER"), ("far", "2.5 M FURTHER")):
            depth.append((out / "depth" / f"{scale}_{spot}_crop.png", f"{word} - {where}"))
    write_png(out / "sheet_depth.png", grid(
        depth, "DEPTH: SHRINK WITH DISTANCE, OR NOT",
        ["PERSPECTIVE: SIZE FOLLOWS DISTANCE, PIXELS RESAMPLE UNEVENLY OFF THE MIDDLE.",
         "CONSTANT: EVERY SPRITE PIXEL STAYS ONE GAME PIXEL, ONLY POSITION SHOWS DEPTH.",
         "RECOMMENDED: CONSTANT. KEEPS THE FACTORY PIXELS INTACT ANYWHERE ON THE STREET."]))
    print(f"wrote {out / 'sheet_pixel_mode.png'} and {out / 'sheet_depth.png'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
