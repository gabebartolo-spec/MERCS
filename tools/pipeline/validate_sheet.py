"""Validate sprite sheets against their manifests (Python standard library only).

  python tools/pipeline/validate_sheet.py <manifest.json> [<manifest.json> ...]

Each manifest (`mercs.sheet/1`, written by pack_sheets.py) and the PNG it names are checked:

  SHEET-SCHEMA   manifest unreadable, wrong schema, or a required key missing or mistyped
  SHEET-PNG      the image is missing or not a readable PNG
  SHEET-SIZE     frame size differs from camera_rig.json, or the image size or a frame rect
                 disagrees with the frame list
  SHEET-PALETTE  the palette file is missing or its hash differs, or an opaque pixel is not
                 a colour of that palette
  SHEET-ALPHA    a pixel's alpha is neither 0 nor 255
  SHEET-PIVOT    the pivot is outside the frame, or a frame's feet (lowest opaque row) are not
                 at the pivot, or the pivot column misses the figure
  SHEET-CLIP     an opaque pixel touches a frame edge (the figure is cut off)
  SHEET-EMPTY    a frame has no opaque pixel

Findings print as `<manifest>:0: <RULE> <message>`; exit 1 if any. The palette is resolved as
<repo>/<palette.file>, so a manifest always names a palette committed in the repo.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from palette_lib import load_palette
from pngio import PngError, read_png

PIPELINE = Path(__file__).resolve().parent
REPO = PIPELINE.parents[1]
CAMERA_FILE = PIPELINE / "camera_rig.json"
SHEET_SCHEMA = "mercs.sheet/1"
SHA = re.compile(r"^[0-9a-f]{64}$")
FEET_ABOVE_PIVOT_PX = 2  # lowest opaque row may sit this far above the pivot (heels at N facing)
FEET_BELOW_PIVOT_PX = 7  # or this far below it (a foot nearer the camera at 35 degrees)
MAX_PIXEL_FINDINGS = 3  # per rule per frame, so one bad sheet does not flood the log

REQUIRED = {
    "schema": str, "body": str, "layer": str, "clip": str, "image": str, "frame_w": int,
    "frame_h": int, "frame_count": int, "facings": list, "frames": list, "pivot": dict,
    "palette": dict, "provenance": dict,
}
FRAME_KEYS = ("facing", "x", "y", "w", "h")


class Findings:
    def __init__(self, label: str):
        self.label = label
        self.lines: list[str] = []

    def add(self, rule: str, message: str) -> None:
        self.lines.append(f"{self.label}:0: {rule} {message}")


def check_schema(m: object, f: Findings) -> bool:
    if not isinstance(m, dict):
        f.add("SHEET-SCHEMA", "manifest is not a JSON object")
        return False
    ok = True
    for key, kind in REQUIRED.items():
        if not isinstance(m.get(key), kind) or isinstance(m.get(key), bool):
            f.add("SHEET-SCHEMA", f"'{key}' missing or not {kind.__name__}")
            ok = False
    if not ok:
        return False
    if m["schema"] != SHEET_SCHEMA:
        f.add("SHEET-SCHEMA", f"schema is {m['schema']!r}, expected {SHEET_SCHEMA!r}")
        ok = False
    for key in ("x", "y"):
        if not isinstance(m["pivot"].get(key), int):
            f.add("SHEET-SCHEMA", f"pivot.{key} missing or not int")
            ok = False
    for key in ("id", "file", "sha256"):
        if not isinstance(m["palette"].get(key), str):
            f.add("SHEET-SCHEMA", f"palette.{key} missing or not str")
            ok = False
    for i, fr in enumerate(m["frames"]):
        if not isinstance(fr, dict) or any(not isinstance(fr.get(k), (int, str)) for k in FRAME_KEYS):
            f.add("SHEET-SCHEMA", f"frames[{i}] lacks one of {FRAME_KEYS}")
            ok = False
    if len(m["frames"]) != m["frame_count"]:
        f.add("SHEET-SCHEMA", f"frame_count {m['frame_count']} but {len(m['frames'])} frames listed")
        ok = False
    sources = m["provenance"].get("sources")
    if not isinstance(sources, list) or not sources:
        f.add("SHEET-SCHEMA", "provenance.sources missing or empty")
        ok = False
    elif any(not isinstance(s, dict) or not SHA.match(str(s.get("sha256", ""))) for s in sources):
        f.add("SHEET-SCHEMA", "a provenance source lacks a sha256")
        ok = False
    if not isinstance(m["provenance"].get("tools"), dict):
        f.add("SHEET-SCHEMA", "provenance.tools missing")
        ok = False
    return ok


def check_sizes(m: dict, img, frame_px: int, f: Findings) -> bool:
    ok = True
    if (m["frame_w"], m["frame_h"]) != (frame_px, frame_px):
        f.add("SHEET-SIZE", f"frame {m['frame_w']}x{m['frame_h']}, camera rig says {frame_px}x{frame_px}")
        ok = False
    for fr in m["frames"]:
        if (fr["w"], fr["h"]) != (m["frame_w"], m["frame_h"]):
            f.add("SHEET-SIZE", f"frame {fr['facing']} is {fr['w']}x{fr['h']}")
            ok = False
        if fr["x"] < 0 or fr["y"] < 0 or fr["x"] + fr["w"] > img.width or fr["y"] + fr["h"] > img.height:
            f.add("SHEET-SIZE", f"frame {fr['facing']} rect falls outside the {img.width}x{img.height} image")
            ok = False
    want_w = max((fr["x"] + fr["w"] for fr in m["frames"]), default=0)
    want_h = max((fr["y"] + fr["h"] for fr in m["frames"]), default=0)
    if (img.width, img.height) != (want_w, want_h):
        f.add("SHEET-SIZE", f"image is {img.width}x{img.height}, frames cover {want_w}x{want_h}")
        ok = False
    return ok


def check_pixels(m: dict, img, colours: set, f: Findings) -> None:
    px, py = m["pivot"]["x"], m["pivot"]["y"]
    if not (0 <= px < m["frame_w"] and 0 <= py < m["frame_h"]):
        f.add("SHEET-PIVOT", f"pivot ({px}, {py}) is outside the {m['frame_w']}x{m['frame_h']} frame")
        px = py = None
    for fr in m["frames"]:
        counts = {"SHEET-ALPHA": 0, "SHEET-PALETTE": 0, "SHEET-CLIP": 0}
        rows, cols = [], []
        for y in range(fr["h"]):
            for x in range(fr["w"]):
                r, g, b, a = img.get(fr["x"] + x, fr["y"] + y)
                where = f"frame {fr['facing']} pixel ({x}, {y})"
                if a not in (0, 255):
                    counts["SHEET-ALPHA"] += 1
                    if counts["SHEET-ALPHA"] <= MAX_PIXEL_FINDINGS:
                        f.add("SHEET-ALPHA", f"{where} alpha {a}, must be 0 or 255")
                if a == 0:
                    continue
                rows.append(y)
                cols.append(x)
                if (r, g, b) not in colours:
                    counts["SHEET-PALETTE"] += 1
                    if counts["SHEET-PALETTE"] <= MAX_PIXEL_FINDINGS:
                        f.add("SHEET-PALETTE", f"{where} #{r:02x}{g:02x}{b:02x} is not in palette {m['palette']['id']}")
                if x in (0, fr["w"] - 1) or y in (0, fr["h"] - 1):
                    counts["SHEET-CLIP"] += 1
                    if counts["SHEET-CLIP"] <= MAX_PIXEL_FINDINGS:
                        f.add("SHEET-CLIP", f"{where} is opaque on the frame edge")
        if not rows:
            f.add("SHEET-EMPTY", f"frame {fr['facing']} has no opaque pixel")
            continue
        if py is None:
            continue
        feet = max(rows)
        if not (py - FEET_ABOVE_PIVOT_PX <= feet <= py + FEET_BELOW_PIVOT_PX):
            f.add("SHEET-PIVOT", f"frame {fr['facing']} feet at row {feet}, pivot row is {py}")
        if not (min(cols) <= px <= max(cols)):
            f.add("SHEET-PIVOT", f"frame {fr['facing']} pivot column {px} misses the figure ({min(cols)}..{max(cols)})")


def validate(manifest_path: Path) -> list[str]:
    f = Findings(manifest_path.as_posix())
    try:
        m = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        f.add("SHEET-SCHEMA", f"cannot read manifest: {exc}")
        return f.lines
    if not check_schema(m, f):
        return f.lines
    try:
        img = read_png(manifest_path.parent / m["image"])
    except (OSError, PngError, ValueError) as exc:
        f.add("SHEET-PNG", f"cannot read {m['image']}: {exc}")
        return f.lines
    frame_px = json.loads(CAMERA_FILE.read_text(encoding="utf-8"))["frame_px"]
    if not check_sizes(m, img, frame_px, f):
        return f.lines
    pal_path = REPO / m["palette"]["file"]
    try:
        pal = load_palette(pal_path)
    except (OSError, ValueError, KeyError) as exc:
        f.add("SHEET-PALETTE", f"cannot load palette {m['palette']['file']}: {exc}")
        return f.lines
    if pal.sha256 != m["palette"]["sha256"] or pal.id != m["palette"]["id"]:
        f.add("SHEET-PALETTE", f"palette {m['palette']['file']} differs from the one the sheet was made with")
    check_pixels(m, img, set(pal.colours), f)
    return f.lines


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if not argv:
        print("usage: validate_sheet.py <manifest.json> [...]")
        return 2
    bad = 0
    for arg in argv:
        lines = validate(Path(arg))
        for line in lines:
            print(line)
        bad += bool(lines)
        if not lines:
            print(f"{Path(arg).as_posix()}: ok")
    print(f"validate_sheet: {len(argv) - bad} of {len(argv)} sheets pass")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
