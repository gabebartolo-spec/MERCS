"""Build the look-target merc sprites for each palette option from one set of 4x renders.

  python tools/look/build_sprites.py --renders D:/MERCS-vault/renders/look_2026-10-15 [--options A,B,C]

One render rig for every option: the 4x colour, normal, parts and matid passes of render_character.py
(orc and Vampyr, stage-1 blockout kit, weapons left off). Per option:
1. pixelate.py reduces the colour pass to 1x in the option's skin_neutral ramp (the clay shading), with
   the soot outline and the arm inner lines, exactly as the sprite pipeline does;
2. the matid pass, reduced by majority vote per block, says which material each 1x pixel is; a pixel on
   skin_neutral step i moves to the same relative step of that material's ramp (skin to the merc's skin
   ramp, plate to iron, tusks to bone, the cape to dark cloth), so shading comes from the render and every
   colour from the option's palette (palette index mapping, 06 section 2);
3. pack_sheets.py packs the street sheet (84 px density, with the normal strip);
4. a map token: the same render reduced by 8 instead of 4 (half the street size), no normals.
Writes assets/look_target/<X>/sprites/. Deterministic: the same renders give the same bytes.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image as PILImage

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
PIPE = REPO / "tools" / "pipeline"
sys.path.insert(0, str(PIPE))
import pixelate  # noqa: E402
from palette_lib import load_palette  # noqa: E402
from pngio import Image, read_png, write_png  # noqa: E402

MATID = {"skin": (255, 0, 0), "iron": (0, 255, 0), "timber": (0, 0, 255), "cloth": (255, 255, 0),
         "bone": (255, 0, 255), "soot": (0, 255, 255), "leather": (255, 128, 0)}
# Per merc: which ramp each material takes. A list names (ramp, step) pairs: a composite ramp of
# palette colours (the Vampyr's blackened plate and wine cape).
MERCS = {
    "orc": {"skin": "skin_orc", "iron": "iron", "bone": "bone", "timber": "timber", "soot": "soot",
            "cloth": [("soot", 0), ("soot", 2), ("cloth_faded", 0), ("cloth_faded", 1)]},
    "vampyr": {"skin": "skin_pale", "bone": "bone", "timber": "timber", "soot": "soot",
               "iron": [("soot", 0), ("soot", 1), ("soot", 2), ("soot", 3), ("iron", 2)],
               "cloth": [("soot", 0), ("soot", 2), ("cloth_faded", 0), ("cloth_faded", 1)]},
}
TOKEN_SCALE = 8
TOKEN_CROP = (0, 0, 704, 704)  # 4x pixels; the pivot (352, 608) lands on (44, 76) at 1x / 8
TOKEN_PIVOT = (44, 76)


def option_config(key: str) -> Path:
    base = json.loads((PIPE / "pixelate.json").read_text(encoding="utf-8"))
    base["palette"] = f"assets/palette/options/{key}/palette.json"
    base["_doc"] = f"Look-target option {key}: tools/pipeline/pixelate.json with the option's palette. " + base["_doc"]
    path = REPO / "assets" / "palette" / "options" / key / "pixelate.json"
    path.write_text(json.dumps(base, indent=2) + "\n", encoding="utf-8", newline="\n")
    return path


def matid_labels(path: Path, scale: int, crop=None) -> np.ndarray:
    a = np.asarray(PILImage.open(path).convert("RGBA")).astype(int)
    if crop:
        a = a[crop[1]:crop[3], crop[0]:crop[2]]
    names = list(MATID)
    ref = np.array([MATID[n] for n in names])
    d = ((a[..., None, :3] - ref[None, None]) ** 2).sum(-1)
    lab = d.argmin(-1)
    lab[a[..., 3] < 128] = -1
    h, w = lab.shape[0] // scale, lab.shape[1] // scale
    blocks = lab[:h * scale, :w * scale].reshape(h, scale, w, scale).transpose(0, 2, 1, 3).reshape(h, w, -1)
    counts = np.stack([(blocks == k).sum(-1) for k in range(len(names))], -1)
    out = counts.argmax(-1)
    out[counts.max(-1) == 0] = -1
    return out


def ramp_of(pal, spec) -> list[tuple[int, int, int]]:
    if isinstance(spec, str):
        return pal.ramp_colours([spec])
    return [pal.ramp_colours([r])[s] for r, s in spec]


def remap(img: Image, labels: np.ndarray, pal, merc: str) -> Image:
    names = list(MATID)
    neutral = pal.ramp_colours(["skin_neutral"])
    index = {c: i for i, c in enumerate(neutral)}
    out = Image(img.width, img.height, bytearray(img.rgba))
    for y in range(img.height):
        for x in range(img.width):
            o = (y * img.width + x) * 4
            if out.rgba[o + 3] == 0:
                continue
            c = tuple(out.rgba[o:o + 3])
            if c not in index or labels[y, x] < 0:
                continue
            target = ramp_of(pal, MERCS[merc].get(names[labels[y, x]], "skin_neutral"))
            step = round(index[c] * (len(target) - 1) / (len(neutral) - 1))
            out.rgba[o:o + 3] = bytes(target[step])
    return out


def build(renders: Path, key: str) -> None:
    cfg_path = option_config(key)
    cfg = pixelate.load_config(cfg_path)
    pal = load_palette(REPO / cfg["palette"])
    out = REPO / "assets" / "look_target" / key / "sprites"
    tmp = renders / "pixel" / key
    for merc in MERCS:
        r = {p: renders / f"{merc}_4x_{p}" for p in ("color", "normal", "parts", "matid")}
        one = tmp / f"{merc}_1x"
        pixelate.pixelate_dir(r["color"], one, "body", cfg, r["parts"])
        for f in sorted(one.glob("facing_*.png")):
            labels = matid_labels(r["matid"] / f.name, cfg["scale"])
            write_png(f, remap(read_png(f), labels, pal, merc))
        nrm = tmp / f"{merc}_1x_normal"
        nrm.mkdir(parents=True, exist_ok=True)
        pixelate.normals_dir(r["normal"], one, nrm, cfg)
        subprocess.run([sys.executable, str(PIPE / "pack_sheets.py"), "--body", merc, "--layer", "body",
                        "--clip", "rest", "--render-dir", str(r["color"]), "--pixel-dir", str(one),
                        "--normal-dir", str(nrm), "--out", str(out), "--stem", f"{merc}_look_{key}",
                        "--pixelate-config", str(cfg_path)], check=True)
        token(r, pal, cfg, merc, out / f"{merc}_token_{key}.png")


def token(r: dict, pal, cfg: dict, merc: str, path: Path) -> None:
    tcfg = dict(cfg, scale=TOKEN_SCALE, coverage_min_samples=TOKEN_SCALE * TOKEN_SCALE // 2)
    quant = pixelate.Quantiser(pal.ramp_colours(["skin_neutral"]))
    face = "facing_1_SE.png"
    src = read_png(r["color"] / face)
    x0, y0, x1, y1 = TOKEN_CROP
    crop = Image(x1 - x0, y1 - y0, bytearray())
    for y in range(y0, y1):
        crop.rgba += src.rgba[(y * src.width + x0) * 4:(y * src.width + x1) * 4]
    img = pixelate.reduce_image(crop, tcfg, quant)
    img = remap(img, matid_labels(r["matid"] / face, TOKEN_SCALE, TOKEN_CROP), pal, merc)
    img = pixelate.outline(img, pal.ramp_colours(["soot"])[0])
    write_png(path, img)
    meta = {"source": f"render_character.py colour + matid pass, {face}", "reduction": TOKEN_SCALE,
            "pivot_px": list(TOKEN_PIVOT), "palette": cfg["palette"]}
    path.with_suffix(".json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--renders", required=True, type=Path)
    p.add_argument("--options", default="A,B,C")
    a = p.parse_args()
    for key in a.options.split(","):
        build(a.renders, key)
        print("BUILT", key)


if __name__ == "__main__":
    main()
