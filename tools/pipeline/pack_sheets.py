"""Pack 1x facing frames into one strip PNG plus a manifest JSON with provenance.

  python tools/pipeline/pack_sheets.py --body average_m --layer body --clip rest \
      --render-dir <4x renders> --pixel-dir <1x frames> --out <dir>

Writes <out>/<body>_<layer>_<clip>.png (one row, facings in camera_rig.json order, one frame per
facing until clips exist) and <out>/<body>_<layer>_<clip>.json (`mercs.sheet/1`: frame size, frame
rects, pivot at the feet, facing order, palette id and hash, and provenance: the 4x source hashes,
the rig, light, pixel-post and script hashes, and tool versions). No timestamps, so the same
inputs give the same bytes. validate_sheet.py checks the result.

Samples: --camera <json> packs frames rendered with another camera rig file; --normal-dir <1x normal
frames> also writes <stem>_normal.png, the same size and layout as the colour strip, and names it in
the manifest as "normal_image" (camera-facing tangent space, OpenGL, encoded n * 0.5 + 0.5).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import sys
from pathlib import Path

from palette_lib import load_palette
from pngio import Image, read_png, write_png

PIPELINE = Path(__file__).resolve().parent
REPO = PIPELINE.parents[1]
CAMERA_FILE = PIPELINE / "camera_rig.json"
PIXELATE_FILE = PIPELINE / "pixelate.json"
SHEET_SCHEMA = "mercs.sheet/1"
LICENCE_ROWS = ["Blender", "MPFB (MakeHuman Plugin for Blender)", "Python, Pillow, NumPy"]
SCRIPTS = ["pngio.py", "palette_lib.py", "pixelate.py", "pack_sheets.py"]


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repo_rel(path: Path) -> str:
    return path.resolve().relative_to(REPO).as_posix()


def blit_strip(sheet: Image, frame: Image, k: int, size: int) -> None:
    for y in range(size):
        row = frame.rgba[y * size * 4:(y + 1) * size * 4]
        start = (y * sheet.width + k * size) * 4
        sheet.rgba[start:start + size * 4] = row


def pack(body: str, layer: str, clip: str, render_dir: Path, pixel_dir: Path, out_dir: Path,
         camera_file: Path = CAMERA_FILE, normal_dir: Path | None = None, stem: str = "") -> Path:
    cam = json.loads(camera_file.read_text(encoding="utf-8"))
    pix = json.loads(PIXELATE_FILE.read_text(encoding="utf-8"))
    meta = json.loads((render_dir / "render_meta.json").read_text(encoding="utf-8"))
    pal = load_palette(REPO / pix["palette"])
    order = cam["facings"]["order"]
    size = cam["frame_px"]

    frames, sources = [], []
    sheet = Image.blank(size * len(order), size)
    normals = Image.blank(size * len(order), size) if normal_dir else None
    for k, name in enumerate(order):
        fname = f"facing_{k}_{name}.png"
        frame = read_png(pixel_dir / fname)
        if (frame.width, frame.height) != (size, size):
            raise SystemExit(f"{fname}: {frame.width}x{frame.height}, camera rig says {size}x{size}")
        blit_strip(sheet, frame, k, size)
        if normals is not None:
            blit_strip(normals, read_png(normal_dir / fname), k, size)
        frames.append({"facing": name, "index": k, "x": k * size, "y": 0, "w": size, "h": size})
        sources.append({"file": fname, "kind": "render_4x", "sha256": sha256_file(render_dir / fname)})

    stem = stem or f"{body}_{layer}_{clip}"
    out_dir.mkdir(parents=True, exist_ok=True)
    png_path = out_dir / f"{stem}.png"
    write_png(png_path, sheet)
    if normals is not None:
        write_png(out_dir / f"{stem}_normal.png", normals)
    inputs = dict(meta["inputs"])
    inputs["pixelate_config"] = {"file": repo_rel(PIXELATE_FILE), "sha256": sha256_file(PIXELATE_FILE)}
    manifest = {
        "schema": SHEET_SCHEMA,
        "body": body,
        "layer": layer,
        "clip": clip,
        "image": png_path.name,
        "image_pixel_sha256": sheet.pixel_sha256(),
        "frame_w": size,
        "frame_h": size,
        "frame_count": len(frames),
        "frames_per_facing": 1,
        "facings": order,
        "frames": frames,
        "pivot": {"x": cam["pivot_px"][0], "y": cam["pivot_px"][1],
                  "doc": "feet centre in frame pixels, the same in every frame"},
        "palette": {"id": pal.id, "file": pix["palette"], "sha256": pal.sha256, "status": pal.status},
        "provenance": {
            "sources": sources,
            "inputs": inputs,
            "tools": {
                "blender": meta["tools"]["blender"],
                "python": platform.python_version(),
                "scripts": {s: sha256_file(PIPELINE / s) for s in SCRIPTS},
            },
            "licence_rows": LICENCE_ROWS,
        },
    }
    if normals is not None:
        manifest["normal_image"] = f"{stem}_normal.png"
        manifest["normal_image_pixel_sha256"] = normals.pixel_sha256()
        manifest["normal_doc"] = ("camera-facing tangent space, OpenGL: R = screen right, G = screen up, "
                                  "B = toward camera, encoded n * 0.5 + 0.5; alpha copied from the colour frame")
    man_path = out_dir / f"{stem}.json"
    man_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    return man_path


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="pack facing frames into a strip and manifest")
    p.add_argument("--body", required=True)
    p.add_argument("--layer", default="body")
    p.add_argument("--clip", default="rest")
    p.add_argument("--render-dir", required=True, type=Path)
    p.add_argument("--pixel-dir", required=True, type=Path)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--camera", type=Path, default=CAMERA_FILE)
    p.add_argument("--normal-dir", type=Path, default=None)
    p.add_argument("--stem", default="", help="output name (default <body>_<layer>_<clip>)")
    a = p.parse_args(argv)
    path = pack(a.body, a.layer, a.clip, a.render_dir, a.pixel_dir, a.out, a.camera, a.normal_dir, a.stem)
    print(f"PACKED {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
