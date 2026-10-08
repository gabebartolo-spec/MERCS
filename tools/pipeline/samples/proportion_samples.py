"""Render, pixelate, pack and label the proportion samples (P1-ART-PROPORTIONS).

  python tools/pipeline/samples/proportion_samples.py --blender <blender.exe> --renders <4x dir> \
      --out docs/audits/proportion_samples [--only render|pack|review]

For every variant, size and pitch in proportions.json: a camera rig file derived from
camera_rig.json (pitch, height, frame and pivot overridden; written under <out>/cameras/), a 4x
Blender render of all 8 facings, the pipeline's pixel post and a packed mercs.sheet/1 strip under
<out>/sheets/. The normal_pass entry also gets a normal render and a "normal_image" strip. Then one
labelled review sheet per pitch (<out>/review_p<pitch>.png) at the zoom the game shows it, plus a 2x
crop of the S facing at the middle size. Blender runs one process at a time with its own APPDATA.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PIPELINE = Path(__file__).resolve().parents[1]
REPO = PIPELINE.parents[1]
sys.path.insert(0, str(PIPELINE))

from contact_sheet import blit, fill  # noqa: E402
from pack_sheets import pack  # noqa: E402
from pixelate import load_config, normals_dir, pixelate_dir  # noqa: E402
from pixfont import GLYPH_H, draw_text, text_width  # noqa: E402
from pngio import Image, read_png, write_png  # noqa: E402
from validate_sheet import validate  # noqa: E402

CONFIG = Path(__file__).resolve().parent / "proportions.json"
CAMERA_FILE = PIPELINE / "camera_rig.json"
BG = (103, 113, 124, 255)
CELL_BG = (132, 140, 148, 255)
INK = (20, 18, 22, 255)
WARN = (142, 27, 36, 255)
MARGIN, GAP = 16, 12  # text is drawn at the art's own zoom: one texel size per image, no mixels


def stem(variant: str, pitch: float, size: int) -> str:
    return f"average_m_{variant}_p{pitch:g}_h{size}"


def write_camera(cfg: dict, pitch: float, size: int, out: Path) -> Path:
    cam = json.loads(CAMERA_FILE.read_text(encoding="utf-8"))
    cam["_doc"] = f"SAMPLE camera derived from camera_rig.json by proportion_samples.py; not the game rig. {cam['_doc']}"
    cam.update(pitch_deg=pitch, char_height_px=size, frame_px=cfg["frame_px"], pivot_px=cfg["pivot_px"])
    path = out / "cameras" / f"camera_p{pitch:g}_h{size}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cam, indent=2) + "\n", encoding="utf-8", newline="\n")
    return path


def blender(exe: str, camera: Path, variant: str, out: Path, render_pass: str, appdata: Path) -> None:
    argv = [exe, "-b", "--factory-startup", "-P", str(PIPELINE / "render_character.py"), "--",
            "--body", "average_m", "--out", str(out), "--camera", str(camera),
            "--proportions", str(CONFIG), "--variant", variant, "--pass", render_pass]
    env = dict(os.environ, APPDATA=str(appdata))
    res = subprocess.run(argv, cwd=REPO, env=env, capture_output=True, text=True, errors="replace", timeout=900)
    lines = [ln for ln in res.stdout.splitlines() if ln.startswith(("PROPORTION", "RENDER_OK"))]
    print(f"  {out.name} {render_pass}: " + " | ".join(lines))
    if res.returncode != 0 or not any(ln.startswith("RENDER_OK") for ln in lines):
        sys.stderr.write(res.stdout[-3000:] + res.stderr[-3000:])
        raise SystemExit(f"blender failed for {out}")


def jobs(cfg: dict):
    for pitch in cfg["pitches_deg"]:
        for size in cfg["sizes_px"]:
            for variant in cfg["variants"]:
                normal = variant == cfg["normal_pass"]["variant"] and size == cfg["normal_pass"]["size_px"]
                yield pitch, size, variant, normal


def render_all(cfg: dict, exe: str, renders: Path, out: Path) -> None:
    appdata = renders / "_appdata"
    appdata.mkdir(parents=True, exist_ok=True)
    for pitch, size, variant, normal in jobs(cfg):
        cam = write_camera(cfg, pitch, size, out)
        blender(exe, cam, variant, renders / stem(variant, pitch, size), "color", appdata)
        if normal:
            blender(exe, cam, variant, renders / (stem(variant, pitch, size) + "_normal"), "normal", appdata)


def pack_all(cfg: dict, renders: Path, out: Path) -> list[Path]:
    pix_cfg = load_config(PIPELINE / "pixelate.json")
    manifests, failures = [], 0
    with tempfile.TemporaryDirectory() as tmp:
        for pitch, size, variant, normal in jobs(cfg):
            name = stem(variant, pitch, size)
            cam = write_camera(cfg, pitch, size, out)
            pix = Path(tmp) / name
            pixelate_dir(renders / name, pix, "body", pix_cfg)
            nrm = None
            if normal:
                nrm = Path(tmp) / (name + "_normal")
                normals_dir(renders / (name + "_normal"), pix, nrm, pix_cfg)
            man = pack("average_m", "body", "rest", renders / name, pix, out / "sheets", cam, nrm, name)
            findings = validate(man, cam)
            failures += bool(findings)
            print(f"  PACKED {man.relative_to(REPO).as_posix()} " + ("ok" if not findings else "; ".join(findings)))
            manifests.append(man)
    print(f"validate_sheet: {len(manifests) - failures} of {len(manifests)} sample sheets pass")
    return manifests


def frame_of(manifest: Path, facing: str) -> tuple[Image, dict]:
    m = json.loads(manifest.read_text(encoding="utf-8"))
    fr = next(f for f in m["frames"] if f["facing"] == facing)
    strip = read_png(manifest.parent / m["image"])
    img = Image.blank(fr["w"], fr["h"])
    blit(img, strip, fr["x"], fr["y"], fr["w"], fr["h"], 0, 0, 1)
    return img, m


def review(cfg: dict, out: Path, pitch: float) -> Path:
    """Rows: variants A/B/C. Columns: sizes, each with the review facings side by side."""
    zoom, facings, frame = cfg["review"]["zoom"], cfg["review"]["facings"], cfg["frame_px"]
    ts = zoom
    cell = frame * zoom
    col_w = len(facings) * cell + (len(facings) - 1) * 4
    head_h = 3 * (GLYPH_H * ts + 6)
    row_label_h = GLYPH_H * ts + 8
    col_label_h = GLYPH_H * ts + 6
    variants = list(cfg["variants"].items())
    width = MARGIN * 2 + len(cfg["sizes_px"]) * col_w + (len(cfg["sizes_px"]) - 1) * GAP * 2
    height = MARGIN + head_h + GAP + len(variants) * (row_label_h + col_label_h + cell + GAP) + MARGIN
    img = Image.blank(width, height)
    fill(img, 0, 0, width, height, BG)
    lines = [
        (f"PROPORTIONS  PITCH {pitch:g}°  x{zoom} = GAME SCALE AT 1080P", INK),
        ("SIZE = FIGURE HEIGHT IN GAME PIXELS.  FACINGS S, SE", INK),
        ("BARE BODY, DRAFT PALETTE: JUDGE SHAPE AND SIZE ONLY", WARN),
    ]
    y = MARGIN
    for text, colour in lines:
        draw_text(img, MARGIN, y, text, colour, ts)
        y += GLYPH_H * ts + 6
    y += GAP
    for key, spec in variants:
        draw_text(img, MARGIN, y, spec["label"], INK, ts)
        y += row_label_h
        for c, size in enumerate(cfg["sizes_px"]):
            x0 = MARGIN + c * (col_w + GAP * 2)
            draw_text(img, x0, y, f"{size} PX", INK, ts)
            for i, facing in enumerate(facings):
                fr, _ = frame_of(out / "sheets" / f"{stem(key, pitch, size)}.json", facing)
                cx = x0 + i * (cell + 4)
                fill(img, cx, y + col_label_h, cell, cell, CELL_BG)
                blit(img, fr, 0, 0, frame, frame, cx, y + col_label_h, zoom)
        y += col_label_h + cell + GAP
    path = out / f"review_p{pitch:g}.png"
    write_png(path, img)
    return path


def crop(cfg: dict, out: Path, pitch: float) -> Path:
    """The S facing of every variant at the middle size, x2 the review zoom, for detail."""
    size = cfg["sizes_px"][len(cfg["sizes_px"]) // 2]
    zoom, frame = cfg["review"]["zoom"] * 2, cfg["frame_px"]
    ts = zoom
    cell = frame * zoom
    variants = list(cfg["variants"].items())
    width = MARGIN * 2 + len(variants) * cell + (len(variants) - 1) * GAP
    title = f"2x CROP  {size} PX  PITCH {pitch:g}°"
    width = max(width, MARGIN * 2 + text_width(title, ts))
    top = MARGIN + GLYPH_H * ts + 6 + GLYPH_H * ts + 8
    img = Image.blank(width, top + cell + MARGIN)
    fill(img, 0, 0, img.width, img.height, BG)
    draw_text(img, MARGIN, MARGIN, title, INK, ts)
    for i, (key, spec) in enumerate(variants):
        x0 = MARGIN + i * (cell + GAP)
        draw_text(img, x0, MARGIN + GLYPH_H * ts + 6, spec["label"].split()[0], INK, ts)
        fr, _ = frame_of(out / "sheets" / f"{stem(key, pitch, size)}.json", "S")
        fill(img, x0, top, cell, cell, CELL_BG)
        blit(img, fr, 0, 0, frame, frame, x0, top, zoom)
    path = out / f"crop_p{pitch:g}_h{size}.png"
    write_png(path, img)
    return path


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="proportion samples for the director's look gate")
    p.add_argument("--blender", default=r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
    p.add_argument("--renders", required=True, type=Path, help="4x render folder (the vault, not the repo)")
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--only", choices=("render", "pack", "review"), default=None)
    a = p.parse_args(argv)
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
    out = a.out.resolve()
    if a.only in (None, "render"):
        render_all(cfg, a.blender, a.renders.resolve(), out)
    if a.only in (None, "pack"):
        pack_all(cfg, a.renders.resolve(), out)
    if a.only in (None, "review"):
        for pitch in cfg["pitches_deg"]:
            print(f"REVIEW {review(cfg, out, pitch)}")
            print(f"REVIEW {crop(cfg, out, pitch)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
