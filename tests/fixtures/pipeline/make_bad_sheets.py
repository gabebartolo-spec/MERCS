"""Regenerate the pipeline fixtures under tests/fixtures/pipeline/ (run from the repo root).

How the fixtures were made (Blender 5.2, one process):
  blender -b --factory-startup -P tools/pipeline/render_character.py -- --body average_m --out <r>
  copy <r>/facing_*.png and <r>/render_meta.json to tests/fixtures/pipeline/render_4x/
  blender ... render_character.py -- --body average_m --pass normal --out <n>   (and --pass parts --out <t>)
  copy <n>/facing_*.png to tests/fixtures/pipeline/render_4x_normal/ (and <t> to render_4x_parts/)
  python tools/pipeline/pixelate.py --in tests/fixtures/pipeline/render_4x --parts tests/fixtures/pipeline/render_4x_parts --out <p>
  python tools/pipeline/pixelate.py --normals --in tests/fixtures/pipeline/render_4x_normal --mask <p> --out <q>
  python tools/pipeline/pack_sheets.py --body average_m --render-dir tests/fixtures/pipeline/render_4x \
      --pixel-dir <p> --normal-dir <q> --out tests/fixtures/pipeline/sheets/good
  python tests/fixtures/pipeline/make_bad_sheets.py

This script derives one planted-bad sheet per validator rule from sheets/good/, each in its own
folder with sheet.json, sheet.png, normal.png and expected.txt (the rules validate_sheet.py must
report). Each case's normal strip takes its alpha from that case's colour strip, so only the
normal_alpha case trips SHEET-NORMAL.
"""
from __future__ import annotations

import copy
import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "tools" / "pipeline"))

from pngio import read_png, write_png  # noqa: E402

GOOD = HERE / "sheets" / "good"
MAGENTA = (255, 0, 255, 255)
HALF_ALPHA = 128


def first_opaque(img, x0: int, w: int) -> tuple[int, int]:
    for y in range(img.height):
        for x in range(x0, x0 + w):
            if img.get(x, y)[3] == 255:
                return x, y
    raise SystemExit("good sheet has an empty frame")


def normal_matching(normal, img):
    """The good normal strip with its alpha replaced by img's, so the two line up exactly."""
    out = copy.deepcopy(normal)
    for i in range(3, len(out.rgba), 4):
        out.rgba[i] = img.rgba[i]
        if img.rgba[i] == 0:
            out.rgba[i - 3:i] = bytes(3)
    return out


def write_case(name: str, manifest: dict, img, rules: list[str], png_bytes: bytes | None = None,
               normal=None) -> None:
    folder = HERE / "sheets" / name
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    manifest = dict(manifest, image="sheet.png")
    if "normal_image" in manifest:
        good_normal = read_png(GOOD / manifest["normal_image"])
        manifest["normal_image"] = "normal.png"
        if normal is None:
            normal = normal_matching(good_normal, img) if png_bytes is None else good_normal
        write_png(folder / "normal.png", normal)
    (folder / "sheet.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    if png_bytes is not None:
        (folder / "sheet.png").write_bytes(png_bytes)
    else:
        write_png(folder / "sheet.png", img)
    lines = ["# rules validate_sheet.py must report for this planted-bad sheet"] + rules
    (folder / "expected.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    man_path = next(GOOD.glob("*.json"))
    good = json.loads(man_path.read_text(encoding="utf-8"))
    base = read_png(GOOD / good["image"])
    fw = good["frame_w"]

    img = read_png(GOOD / good["image"])
    img.put(*first_opaque(img, 0, fw), MAGENTA)
    write_case("off_palette", good, img, ["SHEET-PALETTE"])

    img = read_png(GOOD / good["image"])
    x, y = first_opaque(img, fw, fw)
    r, g, b, _ = img.get(x, y)
    img.put(x, y, (r, g, b, HALF_ALPHA))
    write_case("soft_alpha", good, img, ["SHEET-ALPHA"])

    m = copy.deepcopy(good)
    m["frame_w"] = m["frame_h"] = fw - 4
    for fr in m["frames"]:
        fr["w"] = fr["h"] = fw - 4
    write_case("bad_frame_size", m, base, ["SHEET-SIZE"])

    m = copy.deepcopy(good)
    m["pivot"]["y"] = good["pivot"]["y"] - 16
    write_case("bad_pivot", m, base, ["SHEET-PIVOT"])

    m = copy.deepcopy(good)
    m["pivot"]["x"] = fw + 6
    write_case("pivot_outside", m, base, ["SHEET-PIVOT"])

    m = copy.deepcopy(good)
    del m["palette"]
    write_case("bad_schema", m, base, ["SHEET-SCHEMA"])

    m = copy.deepcopy(good)
    m["provenance"]["sources"][0]["sha256"] = ""
    write_case("no_source_hash", m, base, ["SHEET-SCHEMA"])

    img = read_png(GOOD / good["image"])
    x, y = first_opaque(img, 3 * fw, fw)
    img.put(3 * fw + fw // 2, 0, img.get(x, y))
    write_case("clipped", good, img, ["SHEET-CLIP"])

    img = read_png(GOOD / good["image"])
    for yy in range(img.height):
        for xx in range(7 * fw, 8 * fw):
            img.put(xx, yy, (0, 0, 0, 0))
    write_case("empty_frame", good, img, ["SHEET-EMPTY"])

    m = copy.deepcopy(good)
    m["palette"]["sha256"] = "0" * 64
    write_case("palette_changed", m, base, ["SHEET-PALETTE"])

    write_case("not_png", good, base, ["SHEET-PNG"], png_bytes=b"this is not a png\n")

    normal = normal_matching(read_png(GOOD / good["normal_image"]), base)
    x, y = first_opaque(base, 0, fw)
    i = (y * normal.width + x) * 4
    normal.rgba[i:i + 4] = bytes(4)
    write_case("normal_alpha", good, base, ["SHEET-NORMAL"], normal=normal)
    print("bad sheets written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
