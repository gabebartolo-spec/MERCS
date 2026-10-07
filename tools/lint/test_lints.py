#!/usr/bin/env python3
"""Self-test for the project lints: each one must catch a deliberately broken fixture.

Every lint runs against a fixture root under tests/fixtures/lint/. The fixture is a
mini repo (sim/, presentation/, ui/, data/, project.godot) with one planted violation
per line, plus look-alikes that must NOT be flagged. The fixture's expected.txt lists
the error findings as `RULE path:line`; the set the lint reports must equal it:

    missing    = planted but not reported (recall failure)
    unexpected = reported but not planted (precision failure)

A root may also carry expected_warnings.txt, compared the same way against warnings.
An empty expected.txt means the lint must exit 0. The no_weights fixture's planted files are
committed (git-tracked) on purpose, since that lint reads `git ls-files`. The worktrees lint is fed every
*.txt capture in tests/fixtures/lint/worktrees/ through WORKTREE_LIST.

Usage: python tools/lint/test_lints.py        (exit 1 on any failure)
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "tests" / "fixtures" / "lint"
FINDING = re.compile(
    r"^(?P<path>\S+?):(?P<line>\d+): (?P<warn>warning )?(?P<rule>[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+)(?: |$)"
)
SHOW_LIMIT = 8  # lines shown per missing/unexpected list

# (label, lint script, fixture root under tests/fixtures/lint/)
PYTHON_CASES = [
    ("layering", "layering.py", "layering"),
    ("magic_numbers", "magic_numbers.py", "magic_numbers"),
    ("magic_numbers/phase1", "magic_numbers.py", "magic_numbers_phase1"),
    ("magic_numbers/no-caps", "magic_numbers.py", "magic_numbers_nocaps"),
    ("strings", "strings.py", "strings"),
    ("content_counts", "content_counts.py", "content_counts"),
    ("content_counts/no-caps", "content_counts.py", "content_counts_nocaps"),
    ("content_counts/bad-json", "content_counts.py", "content_counts_badjson"),
    ("content_counts/bad-shape", "content_counts.py", "content_counts_badshape"),
    ("no_weights", "no_weights.py", "no_weights"),
    ("function_limits", "function_limits.py", "function_limits"),
]


def read_lines(path: Path) -> set[str]:
    """Non-blank, non-comment lines of an expected file (a missing file is empty)."""
    if not path.is_file():
        return set()
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    return {ln.strip() for ln in lines if ln.strip() and not ln.lstrip().startswith("#")}


def parse_findings(output: str) -> tuple[set[str], set[str]]:
    """Split a lint's stdout into (errors, warnings), each as `RULE path:line`."""
    errors: set[str] = set()
    warnings: set[str] = set()
    for raw in output.splitlines():
        match = FINDING.match(raw)
        if match:
            key = f"{match['rule']} {match['path']}:{match['line']}"
            (warnings if match["warn"] else errors).add(key)
    return errors, warnings


def run(argv: list[str], env_extra: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    env = {k: v for k, v in os.environ.items() if k not in ("GITHUB_ACTIONS", "WORKTREE_LIST")}
    env.update({"PYTHONIOENCODING": "utf-8", "PYTHONUTF8": "1", "PYTHONDONTWRITEBYTECODE": "1"})
    env.update(env_extra or {})
    try:
        return subprocess.run(argv, cwd=ROOT, env=env, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=120)
    except OSError as exc:
        return subprocess.CompletedProcess(argv, 127, "", str(exc))


def find_bash() -> str:
    """Git Bash on Windows (never the WSL launcher in System32); plain bash elsewhere."""
    if os.name == "nt":
        for var in ("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)", "LOCALAPPDATA"):
            base = os.environ.get(var)
            for tail in ("Git/bin/bash.exe", "Programs/Git/bin/bash.exe"):
                if base and (Path(base) / tail).is_file():
                    return str(Path(base) / tail)
    return shutil.which("bash") or "bash"


def diff_sets(kind: str, expected: set[str], actual: set[str]) -> list[str]:
    problems: list[str] = []
    for title, items in ((f"missing {kind} (recall)", expected - actual),
                         (f"unexpected {kind} (precision)", actual - expected)):
        if items:
            ordered = sorted(items)
            problems.append(f"{title}: {len(ordered)}")
            problems += [f"    {item}" for item in ordered[:SHOW_LIMIT]]
            if len(ordered) > SHOW_LIMIT:
                problems.append(f"    ... and {len(ordered) - SHOW_LIMIT} more")
    return problems


def check_run(proc: subprocess.CompletedProcess, expected: set[str], expected_warn: set[str] | None,
              want_exit: int) -> list[str]:
    """Problems found comparing one lint run with what the fixture promises."""
    errors, warnings = parse_findings(proc.stdout)
    problems: list[str] = []
    if proc.returncode != want_exit:
        problems.append(f"exit code {proc.returncode}, expected {want_exit}")
        tail = (proc.stderr.strip() or proc.stdout.strip()).splitlines()[-2:]
        problems += [f"    | {line}" for line in tail]
    problems += diff_sets("errors", expected, errors)
    if expected_warn is not None:
        problems += diff_sets("warnings", expected_warn, warnings)
    return problems


def case_python(script: str, fixture: str) -> list[str]:
    root = FIXTURES / fixture
    expected = read_lines(root / "expected.txt")
    warn_file = root / "expected_warnings.txt"
    expected_warn = read_lines(warn_file) if warn_file.is_file() else None
    proc = run([sys.executable, f"tools/lint/{script}", "--root", str(root.relative_to(ROOT))])
    return check_run(proc, expected, expected_warn, 1 if expected else 0)


def case_worktrees() -> list[str]:
    """Feed every capture to worktrees.sh; a capture passes unless expected.txt names it."""
    folder = FIXTURES / "worktrees"
    expected = read_lines(folder / "expected.txt")
    actual: set[str] = set()
    problems: list[str] = []
    for capture in sorted(folder.glob("*.txt")):
        if capture.name == "expected.txt":
            continue
        rel = capture.relative_to(ROOT).as_posix()
        proc = run([find_bash(), "tools/lint/worktrees.sh"], {"WORKTREE_LIST": rel})
        errors, _ = parse_findings(proc.stdout)
        actual |= errors
        flagged = any(key.endswith(f" {capture.name}:0") for key in expected)
        want_exit = 1 if flagged else 0
        if proc.returncode != want_exit:
            problems.append(f"{capture.name}: exit code {proc.returncode}, expected {want_exit}")
            tail = (proc.stderr.strip() or proc.stdout.strip()).splitlines()[-2:]
            problems += [f"    | {line}" for line in tail]
    return problems + diff_sets("errors", expected, actual)


def main() -> int:
    results: list[tuple[str, list[str]]] = []
    for label, script, fixture in PYTHON_CASES:
        results.append((label, case_python(script, fixture)))
    results.append(("worktrees", case_worktrees()))
    width = max(len(label) for label, _ in results)
    for label, problems in results:
        if problems:
            print(f"FAIL  {label:<{width}}  {problems[0]}")
            for line in problems[1:]:
                print(f"      {line}")
        else:
            print(f"ok    {label:<{width}}")
    failed = sum(1 for _, problems in results if problems)
    print(f"lint self-test: {len(results) - failed} of {len(results)} fixtures behave as planted")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
