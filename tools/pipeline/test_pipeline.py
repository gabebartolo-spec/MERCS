#!/usr/bin/env python3
"""Self-test for the sprite pipeline's Python stages (standard library only; run by run_all.sh).

1. Validator fixtures: every folder in tests/fixtures/pipeline/sheets/ holds one manifest and an
   expected.txt; validate_sheet.py must report exactly those rules (none for `good`), and exit 1
   exactly when it reports any.
2. Rebuild: the committed 4x renders in tests/fixtures/pipeline/render_4x/ are pixelated twice and
   packed twice into separate temp folders. Both runs must be byte-identical (frames, strip and
   manifest), the strip's pixel hash must equal the committed good sheet's, and the packed sheet
   must pass the validator.

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
    good = json.loads(next((FIXTURES / "sheets" / "good").glob("*.json")).read_text(encoding="utf-8"))
    problems: list[str] = []
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        for run_id in ("a", "b"):
            for argv in (["tools/pipeline/pixelate.py", "--in", str(src), "--out", str(t / f"pix_{run_id}")],
                         ["tools/pipeline/pack_sheets.py", "--body", BODY, "--render-dir", str(src),
                          "--pixel-dir", str(t / f"pix_{run_id}"), "--out", str(t / f"sheet_{run_id}")]):
                proc = run(argv)
                if proc.returncode != 0:
                    return [f"{argv[0]} failed: {(proc.stderr or proc.stdout).strip()[-300:]}"]
        problems += same_files(t / "pix_a", t / "pix_b")
        problems += same_files(t / "sheet_a", t / "sheet_b")
        manifest = t / "sheet_a" / f"{BODY}_body_rest.json"
        built = json.loads(manifest.read_text(encoding="utf-8"))
        if built["image_pixel_sha256"] != good["image_pixel_sha256"]:
            problems.append(f"strip pixels {built['image_pixel_sha256'][:12]} differ from the committed "
                            f"good sheet {good['image_pixel_sha256'][:12]}")
        proc = run(["tools/pipeline/validate_sheet.py", str(manifest)])
        if proc.returncode != 0:
            problems.append("rebuilt sheet fails validation: " + proc.stdout.strip()[:300])
    return problems


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    results = [(f"sheet/{d.name}", case_sheet(d))
               for d in sorted((FIXTURES / "sheets").iterdir()) if d.is_dir()]
    results.append(("rebuild/byte-identical", case_rebuild()))
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
