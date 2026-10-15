"""Lay out one review board per look option: three 4K captures side by side, labelled, with the palette.

  python tools/look/make_boards.py --caps <dir with A_day.png ...> --out docs/audits/look_target

Each 3840 x 2160 capture is shown at half size (1920 x 1080: the 960 x 540 logical frame at exactly
2x, nearest, so pixels stay whole). Above them: the option letter and name, and its 64-colour swatch.
A review image only; nothing here ships.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
FRAMES = (("day", "1  Street, day"), ("night", "2  Street, night and rain"), ("map", "3  Overworld, map scale"))
FRAME_W, FRAME_H = 1920, 1080
GAP = 24
HEAD = 150
LABEL = 64
BG = (24, 23, 26)
INK = (235, 229, 211)
SWATCH = 34


def font(size: int) -> ImageFont.ImageFont:
    for name in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def board(caps: Path, key: str) -> Image.Image:
    pal = json.loads((REPO / "assets" / "palette" / "options" / key / "palette.json").read_text(encoding="utf-8"))
    width = 3 * FRAME_W + 4 * GAP
    img = Image.new("RGB", (width, HEAD + LABEL + FRAME_H + GAP), BG)
    d = ImageDraw.Draw(img)
    d.text((GAP, 28), f"Option {key}: {pal['name']}", fill=INK, font=font(64))
    x = GAP + 1150
    for ramp in pal["ramps"]:
        for c in ramp["colours"]:
            d.rectangle((x, 40, x + SWATCH - 3, 40 + 2 * SWATCH), fill=c)
            x += SWATCH
        x += 10
    for i, (scene, label) in enumerate(FRAMES):
        fx = GAP + i * (FRAME_W + GAP)
        d.text((fx, HEAD + 6), f"{key}{label}", fill=INK, font=font(44))
        frame = Image.open(caps / f"{key}_{scene}.png").convert("RGB")
        img.paste(frame.resize((FRAME_W, FRAME_H), Image.NEAREST), (fx, HEAD + LABEL))
    return img


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--caps", required=True, type=Path)
    p.add_argument("--out", required=True, type=Path)
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    for key in "ABC":
        path = a.out / f"option_{key}.png"
        board(a.caps, key).save(path, optimize=True)
        print("BOARD", path)


if __name__ == "__main__":
    main()
