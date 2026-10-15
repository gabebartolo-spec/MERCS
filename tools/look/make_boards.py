"""Lay out one review board per look option: three 4K captures side by side, labelled, with the palette.

  python tools/look/make_boards.py --caps <dir with A_day.png ...> --out docs/audits/look_target

Each 3840 x 2160 capture is shown at half size (1920 x 1080: the 960 x 540 logical frame at exactly
2x, nearest, so pixels stay whole). Above them: the option letter and name, and its 64-colour swatch.
A review image only; nothing here ships.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "pipeline"))
from palette_lib import load_palette  # noqa: E402

PALETTES = {"B": REPO / "assets" / "palette" / "biomes" / "heartland.json"}  # picked 2026-10-15
OPTION_NAMES = {"A": "Ash and Hearth", "B": "Peat and Ochre", "C": "Clear Day"}
FRAMES = (("day", "1  Street, day"), ("night", "2  Street, night and rain"), ("map", "3  Overworld, map scale"))
FRAME_W, FRAME_H = 1920, 1080
GAP = 24
HEAD = 150
CAPTION = "Figures are stage-1 blockouts: judge palette, light and finish, not shapes"
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
    path = PALETTES.get(key, REPO / "docs" / "audits" / "look_target" / "options" / key / "palette.json")
    pal = load_palette(path)
    name = OPTION_NAMES[key]
    width = 3 * FRAME_W + 4 * GAP
    img = Image.new("RGB", (width, HEAD + LABEL + FRAME_H + GAP), BG)
    d = ImageDraw.Draw(img)
    d.text((GAP, 10), f"Option {key}: {name}" + (" (picked: heartland biome)" if key in PALETTES else ""), fill=INK, font=font(60))
    d.text((GAP, 88), CAPTION, fill=INK, font=font(38))
    x = GAP + 1750
    for _, colours in pal.ramps:
        for c in colours:
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
