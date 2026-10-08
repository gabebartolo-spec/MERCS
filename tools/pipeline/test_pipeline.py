#!/usr/bin/env python3
"""Self-test for the sprite pipeline's Python stages (standard library only; run by run_all.sh).

1. Validator fixtures: every folder in tests/fixtures/pipeline/sheets/ holds one manifest and an
   expected.txt; validate_sheet.py must report exactly those rules (none for `good`), and exit 1
   exactly when it reports any.
2. Rebuild: the committed 4x colour and normal renders in tests/fixtures/pipeline/render_4x/ and
   render_4x_normal/ are pixelated twice and packed twice into separate temp folders. Both runs
   must be byte-identical (frames, strips and manifest), the colour and normal strips' pixel hashes
   must equal the committed good sheet's, and the packed sheet must pass the validator.
3. Normals: a synthetic 4x normal render reduces to unit-length encoded normals, takes its alpha
   from the colour mask exactly, and is byte-identical across runs.

Usage: python tools/pipeline/test_pipeline.py        (exit 1 on any failure)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

PIPELINE = Path(__file__).resolve().parent
ROOT = PIPELINE.parents[1]
FIXTURES = ROOT / "tests" / "fixtures" / "pipeline"
RULE = re.compile(r":0: (SHEET-[A-Z]+) ")
BODY = "average_m"


def run(argv: list[str]) -> subprocess.CompletedProcess:
    env = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONDONTWRITEBYTECODE="1")
    return subprocess.run([sys.executable, *argv], cwd=ROOT, env=env, capture_output=True,
                          text=True, encoding="utf-8", errors="replace", timeout=300)


def expected_rules(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    lines = path.read_text(encoding="utf-8").splitlines()
    return {ln.strip() for ln in lines if ln.strip() and not ln.startswith("#")}


def case_sheet(folder: Path) -> list[str]:
    manifests = sorted(folder.glob("*.json"))
    if len(manifests) != 1:
        return [f"expected one manifest, found {len(manifests)}"]
    proc = run(["tools/pipeline/validate_sheet.py", str(manifests[0].relative_to(ROOT))])
    got = set(RULE.findall(proc.stdout))
    want = expected_rules(folder / "expected.txt")
    problems = []
    if proc.returncode != (1 if want else 0):
        problems.append(f"exit code {proc.returncode}, expected {1 if want else 0}")
    if want - got:
        problems.append(f"missing (recall): {sorted(want - got)}")
    if got - want:
        problems.append(f"unexpected (precision): {sorted(got - want)}")
    if problems and proc.stdout:
        problems += [f"    | {ln}" for ln in proc.stdout.strip().splitlines()[:4]]
    return problems


def same_files(a: Path, b: Path) -> list[str]:
    names_a = sorted(p.name for p in a.iterdir())
    names_b = sorted(p.name for p in b.iterdir())
    if names_a != names_b:
        return [f"file lists differ: {names_a} vs {names_b}"]
    return [f"{n} differs between runs" for n in names_a if (a / n).read_bytes() != (b / n).read_bytes()]


def case_rebuild() -> list[str]:
    src = FIXTURES / "render_4x"
    src_n = FIXTURES / "render_4x_normal"
    good = json.loads(next((FIXTURES / "sheets" / "good").glob("*.json")).read_text(encoding="utf-8"))
    problems: list[str] = []
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        for run_id in ("a", "b"):
            pix, nrm = str(t / f"pix_{run_id}"), str(t / f"nrm_{run_id}")
            for argv in (["tools/pipeline/pixelate.py", "--in", str(src), "--out", pix],
                         ["tools/pipeline/pixelate.py", "--normals", "--in", str(src_n), "--mask", pix,
                          "--out", nrm],
                         ["tools/pipeline/pack_sheets.py", "--body", BODY, "--render-dir", str(src),
                          "--pixel-dir", pix, "--normal-dir", nrm, "--out", str(t / f"sheet_{run_id}")]):
                proc = run(argv)
                if proc.returncode != 0:
                    return [f"{argv[0]} failed: {(proc.stderr or proc.stdout).strip()[-300:]}"]
        problems += same_files(t / "pix_a", t / "pix_b")
        problems += same_files(t / "nrm_a", t / "nrm_b")
        problems += same_files(t / "sheet_a", t / "sheet_b")
        manifest = t / "sheet_a" / f"{BODY}_body_rest.json"
        built = json.loads(manifest.read_text(encoding="utf-8"))
        if built["image_pixel_sha256"] != good["image_pixel_sha256"]:
            problems.append(f"strip pixels {built['image_pixel_sha256'][:12]} differ from the committed "
                            f"good sheet {good['image_pixel_sha256'][:12]}")
        if built.get("normal_image_pixel_sha256") != good.get("normal_image_pixel_sha256"):
            problems.append("normal strip pixels differ from the committed good sheet's")
        proc = run(["tools/pipeline/validate_sheet.py", str(manifest)])
        if proc.returncode != 0:
            problems.append("rebuilt sheet fails validation: " + proc.stdout.strip()[:300])
    return problems


def case_normals() -> list[str]:
    sys.path.insert(0, str(PIPELINE))
    from pixelate import FLAT_NORMAL, reduce_normals
    from pngio import Image

    cfg = {"scale": 4, "alpha_threshold": 128}
    src, mask = Image.blank(8, 8), Image.blank(2, 2)
    for y in range(8):
        for x in range(4):  # left block: +X and +Z samples mixed, a 45-degree normal after renormalising
            src.put(x, y, (255, 128, 128, 255) if (x + y) % 2 else (128, 128, 255, 255))
    mask.put(0, 0, (1, 2, 3, 255))
    mask.put(0, 1, (1, 2, 3, 255))
    mask.put(1, 1, (1, 2, 3, 255))  # opaque in the mask with no normal samples: falls back to flat
    a, b = reduce_normals(src, mask, cfg), reduce_normals(src, mask, cfg)
    problems = []
    if a.rgba != b.rgba:
        problems.append("normal reduction is not deterministic")
    r, g, bl, al = a.get(0, 0)
    vec = [(c / 255.0) * 2.0 - 1.0 for c in (r, g, bl)]
    if abs(sum(v * v for v in vec) ** 0.5 - 1.0) > 0.02 or not (r > 200 and bl > 200 and 120 <= g <= 136):
        problems.append(f"mixed +X/+Z block encoded {r, g, bl}, expected a unit 45-degree normal")
    if a.get(1, 1)[:3] != FLAT_NORMAL or a.get(1, 0)[3] != 0 or al != 255:
        problems.append("alpha does not follow the colour mask, or the flat fallback is wrong")
    return problems


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    results = [(f"sheet/{d.name}", case_sheet(d))
               for d in sorted((FIXTURES / "sheets").iterdir()) if d.is_dir()]
    results.append(("rebuild/byte-identical", case_rebuild()))
    results.append(("normals/reduce", case_normals()))
    width = max(len(label) for label, _ in results)
    for label, problems in results:
        if problems:
            print(f"FAIL  {label:<{width}}  {problems[0]}")
            for line in problems[1:]:
                print(f"      {line}")
        else:
            print(f"ok    {label:<{width}}")
    failed = sum(1 for _, p in results if p)
    print(f"pipeline self-test: {len(results) - failed} of {len(results)} cases pass")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
