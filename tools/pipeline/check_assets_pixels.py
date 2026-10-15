"""Run validate_pixels.py over every PNG under assets/ except the allowlist (run_all.sh calls this).

PNGs under a folder in PALETTE_DIRS are checked against that folder's palette (assets/sprites/: the
draft sheet palette of record; the look target and golden references: the core + heartland biome
palette, 06 section 2); all others are checked for upscaling, soft alpha and anti-aliased edges.
"""
from __future__ import annotations

import fnmatch
import subprocess
import sys
from pathlib import Path

PIPELINE = Path(__file__).resolve().parent
ROOT = PIPELINE.parents[1]
ALLOWLIST = PIPELINE / "pixels_allowlist.txt"
HEARTLAND = ROOT / "assets" / "palette" / "biomes" / "heartland.json"
PALETTE_DIRS = {
    "assets/sprites/": PIPELINE / "palette" / "master_draft.json",
    "assets/look_target/heartland/": HEARTLAND,
    "assets/golden/": HEARTLAND,
}


def allowed_patterns() -> list[str]:
    out = []
    for line in ALLOWLIST.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        pat, _, reason = line.partition(" # ")
        if not reason.strip():
            raise SystemExit(f"{ALLOWLIST.name}: line without a reason: {line}")
        out.append(pat.strip())
    return out


def main() -> int:
    skip = allowed_patterns()
    files = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "assets").rglob("*.png"))
    files = [f for f in files if not any(fnmatch.fnmatch(f, pat) for pat in skip)]
    groups = [([f for f in files if f.startswith(d)], ["--palette", str(pal)]) for d, pal in PALETTE_DIRS.items()]
    rest = [f for f in files if not f.startswith(tuple(PALETTE_DIRS))]
    code = 0
    for group, extra in (*groups, (rest, [])):
        if group:
            code |= subprocess.run([sys.executable, str(PIPELINE / "validate_pixels.py"), *group, *extra],
                                   cwd=ROOT).returncode
    print(f"check_assets_pixels: {len(files)} images checked, {len(skip)} allowlist patterns")
    return 1 if code else 0


if __name__ == "__main__":
    sys.exit(main())
