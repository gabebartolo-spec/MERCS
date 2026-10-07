"""Load a master palette JSON and draw its labelled swatch (Python standard library only).

  python tools/pipeline/palette_lib.py swatch tools/pipeline/palette/master_draft.json <out.png>

A palette file is `mercs.palette/1`: an id, a status, and named ramps of #rrggbb colours. The
colour index is the position in the flattened ramp list. The swatch is a review image: one row
per ramp, the ramp name, its colours as squares, and the palette status in the title.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from pixfont import GLYPH_H, draw_text, text_width
from pngio import Image, write_png

PALETTE_SCHEMA = "mercs.palette/1"
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
SWATCH_CELL = 24
SWATCH_GAP = 4
SWATCH_MARGIN = 12
SWATCH_LABEL_W = 110
SWATCH_BG = (40, 38, 42, 255)
SWATCH_INK = (235, 229, 211, 255)
SWATCH_WARN = (217, 185, 46, 255)
LABEL_SCALE = 1
TITLE_SCALE = 2


@dataclass
class Palette:
    id: str
    status: str
    sha256: str
    ramps: list[tuple[str, list[tuple[int, int, int]]]]

    @property
    def colours(self) -> list[tuple[int, int, int]]:
        return [c for _, cs in self.ramps for c in cs]

    def ramp_colours(self, names: list[str] | None) -> list[tuple[int, int, int]]:
        """Colours of the named ramps (all colours when names is None)."""
        if names is None:
            return self.colours
        known = {n for n, _ in self.ramps}
        missing = [n for n in names if n not in known]
        if missing:
            raise ValueError(f"palette {self.id} has no ramp {missing}")
        return [c for n, cs in self.ramps if n in names for c in cs]


def hex_to_rgb(text: str) -> tuple[int, int, int]:
    if not HEX.match(text):
        raise ValueError(f"not a #rrggbb colour: {text!r}")
    return (int(text[1:3], 16), int(text[3:5], 16), int(text[5:7], 16))


def load_palette(path: Path | str) -> Palette:
    path = Path(path)
    raw = path.read_bytes()
    data = json.loads(raw.decode("utf-8"))
    if data.get("schema") != PALETTE_SCHEMA:
        raise ValueError(f"{path}: schema is not {PALETTE_SCHEMA}")
    ramps = [(r["name"], [hex_to_rgb(c) for c in r["colours"]]) for r in data["ramps"]]
    flat = [c for _, cs in ramps for c in cs]
    if len(set(flat)) != len(flat):
        raise ValueError(f"{path}: duplicate colours")
    return Palette(data["id"], data["status"], hashlib.sha256(raw).hexdigest(), ramps)


def draw_swatch(pal: Palette) -> Image:
    longest = max(len(cs) for _, cs in pal.ramps)
    title = f"{pal.id} {len(pal.colours)} colours {pal.status}"
    title_h = GLYPH_H * TITLE_SCALE + SWATCH_MARGIN
    width = SWATCH_MARGIN * 2 + max(SWATCH_LABEL_W + longest * (SWATCH_CELL + SWATCH_GAP),
                                    text_width(title, TITLE_SCALE))
    height = SWATCH_MARGIN * 2 + title_h + len(pal.ramps) * (SWATCH_CELL + SWATCH_GAP)
    img = Image.blank(width, height)
    for i in range(0, len(img.rgba), 4):
        img.rgba[i:i + 4] = bytes(SWATCH_BG)
    draw_text(img, SWATCH_MARGIN, SWATCH_MARGIN, title, SWATCH_WARN, TITLE_SCALE)
    y = SWATCH_MARGIN + title_h
    for name, cs in pal.ramps:
        draw_text(img, SWATCH_MARGIN, y + (SWATCH_CELL - GLYPH_H) // 2, name, SWATCH_INK, LABEL_SCALE)
        x = SWATCH_MARGIN + SWATCH_LABEL_W
        for c in cs:
            for yy in range(y, y + SWATCH_CELL):
                for xx in range(x, x + SWATCH_CELL):
                    img.put(xx, yy, (*c, 255))
            x += SWATCH_CELL + SWATCH_GAP
        y += SWATCH_CELL + SWATCH_GAP
    return img


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[0] != "swatch":
        print(__doc__.strip().splitlines()[2].strip())
        return 2
    pal = load_palette(argv[1])
    write_png(argv[2], draw_swatch(pal))
    print(f"SWATCH {argv[2]} {pal.id} {len(pal.colours)} colours")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
