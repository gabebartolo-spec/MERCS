"""Build the look-target draft palettes (options A, B, C) from ramp anchors.

  python tools/look/make_palettes.py

Each option is one coherent set of named ramps (06_STYLE_ART.md section 2), 64 colours. A ramp is
given by its darkest and lightest colour; the steps between are spaced evenly in OKLab, so lightness
climbs evenly and any hue shift between the anchors (cool shadows, warm lights) is spread over the
ramp. A ramp given as a list keeps those colours as they are (cloth pairs, heraldry, blood, fire).
Writes the picked option (B) as assets/palette/core.json (the ramps that never change) and
assets/palette/biomes/heartland.json (the world ramps plus the light; it names core.json), each with a .gpl
and a swatch; the options not picked go to docs/audits/look_target/options/<X>/ as review records.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "tools" / "pipeline"))
from palette_lib import draw_swatch, load_palette  # noqa: E402
from pngio import write_png  # noqa: E402

OUT = REPO / "assets" / "palette" / "options"  # parent: assets/palette
PURPOSE = {
    "soot": "outlines, iron shadow, charred wood, night",
    "slate": "stone, steel shadow, sky, water",
    "iron": "mail, plate, blades",
    "soil": "ground, mud, leather lowlights",
    "timber": "wood, thatch, leather",
    "bone": "linen, plaster, bone, tusks",
    "skin_neutral": "the one skin ramp sprites render in; recoloured by index",
    "skin_orc": "the orc's skin (index-mapped from skin_neutral)",
    "skin_pale": "the Vampyr's skin (index-mapped from skin_neutral)",
    "cloth_faded": "commoner and dark cloth: dull red pair, dull blue pair",
    "verdure": "grass, moss, leaves",
    "heraldry": "faction colours only: crimson, gold, blue, white, yellow",
    "blood": "overlay only: two reds and a dried brown",
    "fire": "torch and ember accents",
}
STEPS = {"soot": 4, "slate": 5, "iron": 5, "soil": 5, "timber": 5, "bone": 5, "skin_neutral": 5,
         "skin_orc": 5, "skin_pale": 5, "verdure": 5}
ORDER = ["soot", "slate", "iron", "soil", "timber", "bone", "skin_neutral", "skin_orc", "skin_pale",
         "cloth_faded", "verdure", "heraldry", "blood", "fire"]

OPTIONS = {
    "A": {
        "name": "Ash and Hearth",
        "doc": "grim and muted: cool, low-chroma greys and browns; warmth only from fire and heraldry",
        "ramps": {
            "soot": ("#121114", "#3d3739"), "slate": ("#2e3540", "#a5aaae"), "iron": ("#292c30", "#b2b3b0"),
            "soil": ("#231b15", "#87715a"), "timber": ("#2d2019", "#9e7d59"), "bone": ("#867c6c", "#e7e0cd"),
            "skin_neutral": ("#4a2e22", "#ddb497"), "skin_orc": ("#242d1f", "#8f9a70"),
            "skin_pale": ("#463c45", "#d8d2cd"), "verdure": ("#1b2924", "#6c8172"),
            "cloth_faded": ["#5e3530", "#86524a", "#36435a", "#566780"],
            "heraldry": ["#8e1b24", "#b8323a", "#c9962b", "#23468c", "#e9e6dc", "#d9b92e"],
            "blood": ["#5c0f12", "#7e1a1c", "#4a2a1e"], "fire": ["#d9762b", "#f2c14e"],
        },
    },
    "B": {
        "name": "Peat and Ochre",
        "doc": "warm and earthy: browns, ochres and olive greens with a little more chroma; golden light",
        "ramps": {
            "soot": ("#17120f", "#45392f"), "slate": ("#34393d", "#aba693"), "iron": ("#2b2b2a", "#b6b1a3"),
            "soil": ("#2b1c11", "#a27a4e"), "timber": ("#321f0f", "#b68b51"), "bone": ("#8e7d5d", "#efe1bd"),
            "skin_neutral": ("#4c2d1f", "#e0b48f"), "skin_orc": ["#2e3428", "#485240", "#6e806f", "#8d9b80", "#b2bc9c"],
            "skin_pale": ("#4b3d39", "#e1d3c2"), "verdure": ("#1e2a12", "#808c46"),
            "cloth_faded": ["#7a3a26", "#a0573a", "#37474f", "#59706f"],
            "heraldry": ["#8a1d1d", "#bb3a2c", "#d29a2a", "#22488a", "#ece3cf", "#e0b92c"],
            "blood": ["#5c1010", "#80201a", "#4c2a18"], "fire": ["#e07a28", "#f6c64a"],
        },
    },
    "C": {
        "name": "Clear Day",
        "doc": "Black/White clarity: wider value range, hue-shifted ramps (violet shadows, warm lights)",
        "ramps": {
            "soot": ("#0e0f1a", "#3b3652"), "slate": ("#29324f", "#b9c4d2"), "iron": ("#242939", "#cacdd1"),
            "soil": ("#2a1a24", "#b48c62"), "timber": ("#2d1a20", "#c49462"), "bone": ("#8a7a7a", "#f7efe1"),
            "skin_neutral": ("#4a2a2c", "#eac2a2"), "skin_orc": ("#1d2d2c", "#a5b472"),
            "skin_pale": ("#3d3551", "#ebe3e2"), "verdure": ("#132a2c", "#7ea462"),
            "cloth_faded": ["#6e2a38", "#a04a4c", "#2a3e6c", "#4b6ba2"],
            "heraldry": ["#8e1b2a", "#cc323c", "#e2a42a", "#1f4aa4", "#f2f0e8", "#ecc62e"],
            "blood": ["#5c0f18", "#80181e", "#4a2a22"], "fire": ["#e8782a", "#fbd052"],
        },
    },
}


def _lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _enc(c: float) -> float:
    c = min(max(c, 0.0), 1.0)
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def to_oklab(hex_c: str) -> tuple[float, float, float]:
    r, g, b = (_lin(int(hex_c[i:i + 2], 16) / 255) for i in (1, 3, 5))
    l_ = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m_ = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s_ = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_)


def from_oklab(lab: tuple[float, ...]) -> str:
    big_l, a, b = lab
    l_ = (big_l + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m_ = (big_l - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s_ = (big_l - 0.0894841775 * a - 1.2914855480 * b) ** 3
    rgb = (4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
           -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
           -0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_)
    return "#" + "".join(f"{round(_enc(c) * 255):02x}" for c in rgb)


def ramp(spec, steps: int) -> list[str]:
    if isinstance(spec, list):
        return spec
    lo, hi = to_oklab(spec[0]), to_oklab(spec[1])
    return [from_oklab(tuple(lo[k] + (hi[k] - lo[k]) * i / (steps - 1) for k in range(3))) for i in range(steps)]


def gpl(name: str, ramps: list[dict]) -> str:
    lines = ["GIMP Palette", f"Name: {name}", "Columns: 6", "#"]
    for r in ramps:
        for i, c in enumerate(r["colours"]):
            lines.append(f"{int(c[1:3], 16):3d} {int(c[3:5], 16):3d} {int(c[5:7], 16):3d}\t{r['name']}_{i}")
    return "\n".join(lines) + "\n"


NL = chr(10)
CORE = ["soot", "iron", "bone", "skin_neutral", "skin_orc", "skin_pale", "cloth_faded", "heraldry", "blood", "fire"]
BIOME = ["slate", "soil", "timber", "verdure"]
PICKED = "B"  # director, 2026-10-15: option B "Peat and Ochre" is the look target
BIOME_NAME = "heartland"
AUDIT = REPO / "docs" / "audits" / "look_target" / "options"
LIGHTS = json.loads((HERE / "look_options.json").read_text(encoding="utf-8"))["options"]


def ramps_of(opt: dict, names: list[str]) -> list[dict]:
    return [{"name": n, "purpose": PURPOSE[n], "colours": ramp(opt["ramps"][n], STEPS.get(n, 0))} for n in names]


def save(path: Path, data: dict, title: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1) + NL, encoding="utf-8", newline=NL)
    pal = load_palette(path)
    ramps = [{"name": n, "colours": ["#%02x%02x%02x" % c for c in cs]} for n, cs in pal.ramps]
    path.with_suffix(".gpl").write_text(gpl(title, ramps), encoding="utf-8", newline=NL)
    write_png(path.with_name(path.stem + "_swatch.png"), draw_swatch(pal))
    print(path.relative_to(REPO).as_posix(), len(pal.colours), "colours")


def main() -> None:
    """The picked option becomes the core palette plus the heartland biome (06 section 2); the options the
    director did not pick stay as review records under docs/audits."""
    for key, opt in OPTIONS.items():
        if key == PICKED:
            continue
        save(AUDIT / key / "palette.json", {
            "_doc": f"Look-target option {key}, '{opt['name']}': {opt['doc']}. Not picked (director chose {PICKED}, "
                    "2026-10-15); kept as a review record. Built by tools/look/make_palettes.py.",
            "schema": "mercs.palette/1", "id": f"look_option_{key}", "name": opt["name"], "status": "NOT PICKED",
            "approved": False, "ramps": ramps_of(opt, ORDER)}, f"MERCS look option {key} ({opt['name']})")
        (AUDIT / key / "look.json").write_text(json.dumps(LIGHTS[key], indent=1) + NL, encoding="utf-8",
                                               newline=NL)
    opt = OPTIONS[PICKED]
    save(OUT.parent / "core.json", {
        "_doc": "MERCS core palette (06_STYLE_ART.md section 2): the ramps every biome shares and that never "
                "change: outline soot, plate iron, bone and linen, the skin ramps, faded cloth, heraldry, blood "
                "and fire. A biome palette adds the world's ramps. From look option B 'Peat and Ochre', picked "
                "by the director 2026-10-15. Never reorder: colour index is the position in the flattened list.",
        "schema": "mercs.palette/1", "id": "mercs_core", "status": "APPROVED", "approved": True,
        "ramps": ramps_of(opt, CORE)}, "MERCS core")
    save(OUT.parent / "biomes" / f"{BIOME_NAME}.json", {
        "_doc": f"MERCS biome palette '{BIOME_NAME}' (06 section 2): the core ramps (core.json) plus this "
                "biome's ground, stone and sky (slate), soil, timber and foliage, and its light. From look "
                "option B 'Peat and Ochre', picked by the director 2026-10-15. Other biomes (kingdoms, "
                "landscapes) are new files beside this one with the same ramp names.",
        "schema": "mercs.palette/1", "id": f"mercs_biome_{BIOME_NAME}", "status": "APPROVED", "approved": True,
        "core": "../core.json", "light": LIGHTS[PICKED], "ramps": ramps_of(opt, BIOME)},
        f"MERCS biome {BIOME_NAME} (core + biome)")


if __name__ == "__main__":
    main()
