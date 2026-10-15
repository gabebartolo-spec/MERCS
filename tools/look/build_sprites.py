"""Build the look-target merc sprites for each palette option from one set of 4x renders.

  python tools/look/build_sprites.py --renders D:/MERCS-vault/renders/look_2026-10-15 \
      --palette assets/palette/biomes/heartland.json --out assets/look_target/heartland/sprites --tag heartland

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
Writes <out>/ and <out>/../pixelate.json. Deterministic: the same renders give the same bytes.
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
         "bone": (255, 0, 255), "soot": (0, 255, 255), "leather": (255, 128, 0), "eye": (128, 0, 255),
         "mail": (0, 255, 128)}
EYE = list(MATID).index("eye")
EYE_COLOUR = ("soot", 0)  # a deliberate face pixel, drawn whenever any 4x sample of the block is eye
EYE_PAIR_NUM, EYE_PAIR_DEN = 3, 4  # EYE_PAIR: a side block with 3/4 of the fullest count is the same eye
GAP_MIN = 3  # a transparent slot narrower than this inside a row is closed (close_gaps)
MIN_CLUSTER = 3  # ai-slop-art 2.2/2.3: an interior run of one colour smaller than this is speckle, not a decision
CLEAN_PASSES = 8
# Per merc: which ramp each material takes. A list names (ramp, step) pairs: a composite ramp of
# palette colours (the Vampyr's blackened plate and wine cape). soot step 0 is the outline and the eyes only
# (06 section 3: soot is drawn, never quantised to; fresh critic 2026-10-15: soot shading inside the coat
# merged the outline into the body), so no material ramp starts at it.
LEATHER = [("soot", 1), ("soot", 2), ("soot", 3)]
MAIL = [("soot", 2), ("iron", 0), ("iron", 1), ("iron", 2)]  # a step darker than plate: the parts read apart
MERCS = {
    "orc": {"skin": "skin_orc", "iron": "iron", "bone": "bone", "timber": "timber", "soot": "soot",
            "leather": LEATHER, "mail": MAIL,
            "cloth": [("soot", 3), ("cloth_faded", 0), ("cloth_faded", 1)]},
    "vampyr": {"skin": "skin_pale", "bone": "bone", "timber": "timber", "soot": "soot",
               "leather": LEATHER, "mail": MAIL,
               "iron": [("iron", 0), ("iron", 1), ("iron", 2)],
               "cloth": [("soot", 3), ("cloth_faded", 0), ("cloth_faded", 1)]},
}
TOKEN_SKIN_LIFT = {"orc": 1}  # skin steps a merc's map token is lifted by (token_skin_lift)
BROWS = ("orc",)  # mercs drawn with a lit brow ledge over each eye (eye_rims)
NL = chr(10)
TOKEN_SCALE = 8
TOKEN_CROP = (0, 0, 704, 704)  # 4x pixels; the pivot (352, 608) lands on (44, 76) at 1x / 8
TOKEN_PIVOT = (44, 76)


def option_config(palette: Path, out: Path, tag: str) -> Path:
    """tools/pipeline/pixelate.json with this palette, written beside the sprites it made."""
    base = json.loads((PIPE / "pixelate.json").read_text(encoding="utf-8"))
    base["palette"] = palette.resolve().relative_to(REPO).as_posix()
    base["_doc"] = f"Look sprites '{tag}': tools/pipeline/pixelate.json with the palette above. " + base["_doc"]
    path = out.parent / "pixelate.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(base, indent=2) + NL, encoding="utf-8", newline=NL)
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
    out[out == EYE] = labels_without_eye(counts)[out == EYE]
    for y, x in eye_pixels(counts[..., EYE]):
        out[y, x] = EYE
    out[counts.max(-1) == 0] = -1
    return out


def labels_without_eye(counts: np.ndarray) -> np.ndarray:
    c = counts.copy()
    c[..., EYE] = -1
    return c.argmax(-1)


def eye_pixels(eye: np.ndarray) -> list:
    """One deliberate pixel per eye (two when the eye spans two blocks almost equally): each 8-connected group
    of blocks holding eye samples keeps the block at its sample-weighted centre (the pushed eyeball grows
    sideways, its centre does not), and the nearer side neighbour when it has at least
    EYE_PAIR_NUM / EYE_PAIR_DEN of the fullest count. A whole group of blocks drawn dark reads as goggles,
    not an eye."""
    left = {(int(y), int(x)) for y, x in zip(*np.nonzero(eye))}
    keep = []
    while left:
        stack, group = [left.pop()], []
        while stack:
            y, x = stack.pop()
            group.append((y, x))
            for n in [(y + dy, x + dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1)]:
                if n in left:
                    left.remove(n)
                    stack.append(n)
        total = sum(int(eye[p]) for p in group)
        cy = round(sum(p[0] * int(eye[p]) for p in group) / total)
        cx = sum(p[1] * int(eye[p]) for p in group) / total
        x = round(cx)
        side = (cy, x + 1) if cx > x else (cy, x - 1)
        pair = side in group and eye[side] * EYE_PAIR_DEN >= eye[cy, x] * EYE_PAIR_NUM
        keep.append([(cy, x)] + ([side] if pair else []))
    if len({len(k) for k in keep}) > 1:  # one eye two pixels wide and the other one reads as a wink: one each
        keep = [k[:1] for k in keep]
    if len(keep) == 2 and abs(keep[0][0][0] - keep[1][0][0]) == 1:  # no head roll: both eyes on one row (the
        row = max(keep[0][0][0], keep[1][0][0])  # lower, under the brow); rounding split them by the pixel grid
        keep = [[(row, x) for _, x in k] for k in keep]
    return [p for k in keep for p in k]


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
            if labels[y, x] == EYE:
                out.rgba[o:o + 3] = bytes(pal.ramp_colours([EYE_COLOUR[0]])[EYE_COLOUR[1]])
                continue
            if c not in index or labels[y, x] < 0:
                continue
            target = ramp_of(pal, MERCS[merc].get(names[labels[y, x]], "skin_neutral"))
            step = round(index[c] * (len(target) - 1) / (len(neutral) - 1))
            out.rgba[o:o + 3] = bytes(target[step])
    return out


def close_gaps(img: Image, labels: np.ndarray) -> Image:
    """Fill each 1-2 px wide transparent slot inside a row (between the legs, between an arm and the body) with
    the darker of the two pixels bounding it, and give it that pixel's material. Outlined, such a slot became a
    one-pixel rod of outline (Lead QC 2026-10-15); a gap an artist keeps is at least GAP_MIN px wide."""
    out = Image(img.width, img.height, bytearray(img.rgba))
    for y in range(img.height):
        for x in range(1, img.width - 1):
            if img.get(x, y)[3] or not img.get(x - 1, y)[3]:
                continue
            right = next((x + k for k in range(1, GAP_MIN) if x + k < img.width and img.get(x + k, y)[3]), None)
            if right is None:
                continue
            a, b = img.get(x - 1, y), img.get(right, y)
            src = (x - 1) if pixelate.luma(a) <= pixelate.luma(b) else right
            for gx in range(x, right):
                out.put(gx, y, img.get(src, y))
                labels[y, gx] = labels[y, src]
    return out


def eyes_inside(img: Image, labels: np.ndarray) -> None:
    """An eye pixel on the silhouette edge becomes outline and is lost (Vampyr E, fresh critic 2026-10-15): move
    it one pixel inward, away from its transparent neighbours, onto the first interior pixel."""
    for y, x in zip(*np.nonzero(labels == EYE)):
        y, x = int(y), int(x)
        if not on_edge(img, x, y):
            continue
        dx = sum(1 for nx in (x - 1, x + 1) if 0 <= nx < img.width and img.get(nx, y)[3] == 0 and nx < x) -             sum(1 for nx in (x - 1, x + 1) if 0 <= nx < img.width and img.get(nx, y)[3] == 0 and nx > x)
        dy = (1 if y > 0 and img.get(x, y - 1)[3] == 0 else 0) - (1 if y + 1 < img.height and img.get(x, y + 1)[3] == 0 else 0)
        nx, ny = x + dx, y + dy
        if (nx, ny) != (x, y) and img.get(nx, ny)[3] and not on_edge(img, nx, ny):
            labels[y, x], labels[ny, nx] = labels[ny, nx], EYE


EYE_RIM_STEP = 2  # skin ramp step the pixels either side of an eye are lifted to, at least
BROW_STEP = 3  # skin ramp step of the brow ledge over an eye (merc "brow": true)


def eye_rims(img: Image, labels: np.ndarray, pal, merc: str) -> Image:
    """An eye reads only against a lit socket rim: in shadow (Vampyr E, fresh critic 2026-10-15) a soot eye on a
    dark skin step is lost. Each skin pixel 4-beside an eye pixel, not on the outline, is lifted to
    EYE_RIM_STEP of the merc's skin ramp when it is darker. A merc with "brow" in BROWS also gets a lit brow
    ledge: the skin pixels over the eye and its two diagonals go up to BROW_STEP, so the eye sits in shadow under
    a ridge (fresh critic 2026-10-15, orc item 1: at 1x his face was a green bean with no eyes)."""
    skin = ramp_of(pal, MERCS[merc]["skin"])
    out = Image(img.width, img.height, bytearray(img.rgba))

    def lift(x: int, y: int, step: int) -> None:
        c = img.get(x, y)[:3]
        if c in skin and not on_edge(img, x, y) and labels[y, x] != EYE and skin.index(c) < step:
            out.put(x, y, (*skin[step], 255))

    for y, x in zip(*np.nonzero(labels == EYE)):
        y, x = int(y), int(x)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            lift(nx, ny, EYE_RIM_STEP)
        if merc in BROWS:
            for nx in (x - 1, x, x + 1):
                lift(nx, y - 1, BROW_STEP)
    return out


HOLE_MAX = 80  # px: an enclosed window of background smaller than this is shadow, not daylight


def fill_holes(img: Image, labels: np.ndarray) -> Image:
    """A small window of background enclosed by the figure (between a hanging arm and a barrel chest, between
    touching knees) outlined itself into a ring of soot that read as a handle or a hole in the plate (round 2,
    2026-10-15). Each enclosed transparent region of at most HOLE_MAX pixels takes the darkest colour bordering
    it, and that pixel's material: deep shadow in the gap, as an artist would draw it."""
    w, h = img.width, img.height
    seen = set()
    out = Image(w, h, bytearray(img.rgba))
    for y0 in range(h):
        for x0 in range(w):
            if (x0, y0) in seen or img.get(x0, y0)[3]:
                continue
            region, edge, stack, border = [], False, [(x0, y0)], []
            seen.add((x0, y0))
            while stack:
                x, y = stack.pop()
                region.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if not (0 <= nx < w and 0 <= ny < h):
                        edge = True
                    elif img.get(nx, ny)[3]:
                        border.append((nx, ny))
                    elif (nx, ny) not in seen:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if edge or len(region) > HOLE_MAX:
                continue
            bx, by = min(border, key=lambda p: (pixelate.luma(img.get(*p)), p[1], p[0]))
            for x, y in region:
                out.put(x, y, img.get(bx, by))
                labels[y, x] = labels[by, bx]
    return out


def token_skin_lift(img: Image, pal, merc: str) -> Image:
    """The overworld grass is snapped to the same greens as the orc's skin (skin_orc 1 is the commonest grass
    colour on the golden), so his token head vanished into it (fresh critic 2026-10-15, T2). On the map token
    every interior skin pixel moves TOKEN_SKIN_LIFT steps up the merc's skin ramp: a top-lit head a value step
    above any grass; the soot outline and the eyes stay."""
    lift = TOKEN_SKIN_LIFT.get(merc, 0)
    skin = ramp_of(pal, MERCS[merc]["skin"])
    out = Image(img.width, img.height, bytearray(img.rgba))
    for y in range(img.height):
        for x in range(img.width):
            c = img.get(x, y)
            if c[3] and c[:3] in skin and not on_edge(img, x, y):
                out.put(x, y, (*skin[min(len(skin) - 1, skin.index(c[:3]) + lift)], 255))
    return out


def hand_edits(img: Image, pal, merc: str) -> Image:
    """tools/look/token_edits.json: deliberate pixel edits, each checked against the colour it replaces."""
    edits = json.loads((HERE / "token_edits.json").read_text(encoding="utf-8")).get(merc, [])
    for e in edits:
        x, y = e["at"]
        o = (y * img.width + x) * 4
        want = pal.ramp_colours([e["expect"][0]])[e["expect"][1]]
        if tuple(img.rgba[o:o + 3]) != want:
            raise SystemExit(f"token edit {merc} {e['at']}: expected {want}, found {tuple(img.rgba[o:o + 3])}")
        img.rgba[o:o + 3] = bytes(pal.ramp_colours([e["to"][0]])[e["to"][1]])
    return img


def clean(img: Image, labels: np.ndarray, pal) -> Image:
    """Merge speckle: every 4-connected run of one colour under MIN_CLUSTER pixels that holds no outline pixel
    (one with a transparent 4-neighbour) and no eye pixel takes the most common colour bordering it, outline
    pixels not counted (ties: lowest). Decided on each pass's input only, so scan order does not matter."""
    for _ in range(CLEAN_PASSES):
        src, changed = img, False
        img = Image(src.width, src.height, bytearray(src.rgba))
        for region, border in runs(src):
            if (len(region) >= MIN_CLUSTER or not border or any(on_edge(src, x, y) for x, y in region)
                    or any(labels[y, x] == EYE for x, y in region)):
                continue
            best = max(sorted(border), key=lambda c: border[c])
            for x, y in region:
                o = (y * src.width + x) * 4
                img.rgba[o:o + 3] = bytes(best)
            changed = True
        if not changed:
            break
    return img


def on_edge(img: Image, x: int, y: int) -> bool:
    """True for an outline pixel: on the image border or beside a transparent pixel."""
    return any(not (0 <= nx < img.width and 0 <= ny < img.height) or img.get(nx, ny)[3] == 0
               for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))


def runs(img: Image):
    """Yield (pixels, {bordering colour: count, outline pixels excluded}) per 4-connected opaque run of one colour."""
    seen = set()
    w, h = img.width, img.height
    for y0 in range(h):
        for x0 in range(w):
            if (x0, y0) in seen or img.get(x0, y0)[3] == 0:
                continue
            colour = img.get(x0, y0)[:3]
            region, border, stack = [], {}, [(x0, y0)]
            seen.add((x0, y0))
            while stack:
                x, y = stack.pop()
                region.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if not (0 <= nx < w and 0 <= ny < h) or img.get(nx, ny)[3] == 0:
                        continue
                    c = img.get(nx, ny)[:3]
                    if c == colour:
                        if (nx, ny) not in seen:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
                    elif not on_edge(img, nx, ny):
                        border[c] = border.get(c, 0) + 1
            yield region, border


def build(renders: Path, palette: Path, out: Path, key: str) -> None:
    cfg_path = option_config(palette, out, key)
    cfg = pixelate.load_config(cfg_path)
    pal = load_palette(REPO / cfg["palette"])
    tmp = renders / "pixel" / key
    for merc in MERCS:
        r = {p: renders / f"{merc}_4x_{p}" for p in ("color", "normal", "matid")}
        one = tmp / f"{merc}_1x"
        one.mkdir(parents=True, exist_ok=True)
        quant = pixelate.Quantiser(pal.ramp_colours(["skin_neutral"]))
        for src in sorted(r["color"].glob("facing_*.png")):
            labels = matid_labels(r["matid"] / src.name, cfg["scale"])
            img = pixelate.despeckle(pixelate.reduce_image(read_png(src), cfg, quant), cfg["despeckle_max_px"])
            img = pixelate.outline(fill_holes(close_gaps(img, labels), labels), pal.ramp_colours(["soot"])[0])
            eyes_inside(img, labels)
            write_png(one / src.name, eye_rims(clean(remap(img, labels, pal, merc), labels, pal), labels, pal, merc))
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
    labels = matid_labels(r["matid"] / face, TOKEN_SCALE, TOKEN_CROP)
    img = pixelate.outline(remap(fill_holes(close_gaps(img, labels), labels), labels, pal, merc),
                           pal.ramp_colours(["soot"])[0])
    img = hand_edits(eye_rims(token_skin_lift(clean(img, labels, pal), pal, merc), labels, pal, merc), pal, merc)
    write_png(path, img)
    meta = {"source": f"render_character.py colour + matid pass, {face}", "reduction": TOKEN_SCALE,
            "pivot_px": list(TOKEN_PIVOT), "palette": cfg["palette"]}
    path.with_suffix(".json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--renders", required=True, type=Path)
    p.add_argument("--palette", required=True, type=Path, help="palette json (a biome file brings its core)")
    p.add_argument("--out", required=True, type=Path, help="sprites folder, e.g. assets/look_target/heartland/sprites")
    p.add_argument("--tag", required=True, help="name in the file names, e.g. heartland")
    a = p.parse_args()
    build(a.renders, a.palette, a.out.resolve(), a.tag)
    print("BUILT", a.tag)


if __name__ == "__main__":
    main()
