#!/usr/bin/env python3
"""No-weights lint (gate gap #14): model weights never enter the repository, LFS or not.

  WEIGHT-FILE  a git-tracked file has a weights extension (.safetensors, .ckpt, .gguf, .pth,
               .pt, .onnx) or is a .bin over 1 MB (a Git LFS pointer counts by its "size" line)
  WEIGHT-PATH  a git-tracked file lives under a folder named models/ (any depth)
  WEIGHT-GIT   `git ls-files` could not run in the root (not a repo, or git missing)

The list comes from `git ls-files` run in the root, so untracked scratch files are ignored and
an LFS pointer is caught like the file it stands for. Files under tests/fixtures/lint/ are the
lint self-test's planted violations and are skipped. Every finding points to
docs/10_LICENSING_REGISTER.md: a model may only be referenced there, never committed.

Usage: python tools/lint/no_weights.py [--root DIR]
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from lintlib import Report, parse_args

REGISTER = "docs/10_LICENSING_REGISTER.md"
WEIGHT_SUFFIXES = frozenset({".safetensors", ".ckpt", ".gguf", ".pth", ".pt", ".onnx"})
BIN_LIMIT = 1_000_000  # bytes: a .bin above this is treated as weights, below it as data
SKIP_PREFIX = "tests/fixtures/lint/"
LFS_POINTER = b"version https://git-lfs.github.com/spec/"


def tracked_files(root: Path) -> tuple[list[str], str]:
    """(paths relative to root with forward slashes, problem text if git failed)."""
    try:
        proc = subprocess.run(["git", "ls-files", "-z", "--", "."], cwd=root, capture_output=True,
                              check=False, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return [], str(exc)
    if proc.returncode != 0:
        return [], proc.stderr.decode("utf-8", "replace").strip() or f"exit code {proc.returncode}"
    paths = [p.decode("utf-8", "replace") for p in proc.stdout.split(b"\0") if p]
    return sorted(paths), ""


def tracked_size(path: Path) -> int:
    """On-disk size, or the size an LFS pointer declares for the object it stands for."""
    try:
        size = path.stat().st_size
        if size > 256:
            return size
        head = path.read_bytes()
    except OSError:
        return 0
    if not head.startswith(LFS_POINTER):
        return size
    for line in head.decode("utf-8", "replace").splitlines():
        key, _, value = line.partition(" ")
        if key == "size" and value.strip().isdigit():
            return int(value)
    return size


def main() -> int:
    root = parse_args(__doc__, __file__)
    report = Report()
    paths, problem = tracked_files(root)
    if problem:
        report.error(".", 0, "WEIGHT-GIT", f"cannot list tracked files: {problem}")
        return report.finish("")
    checked = 0
    for shown in paths:
        if shown.startswith(SKIP_PREFIX):
            continue
        checked += 1
        suffix = Path(shown).suffix.lower()
        why = ""
        if suffix in WEIGHT_SUFFIXES:
            why = f"{suffix} is a model-weights file"
        elif suffix == ".bin" and tracked_size(root / shown) > BIN_LIMIT:
            why = f".bin over {BIN_LIMIT // 1_000_000} MB is treated as model weights"
        if why:
            report.error(shown, 0, "WEIGHT-FILE", f"{why}: weights are never committed, LFS or not; "
                                                  f"register the model in {REGISTER} instead")
        elif "/models/" in f"/{shown}":
            report.error(shown, 0, "WEIGHT-PATH", f"lives under a models/ folder: weights are never "
                                                  f"committed, LFS or not; see {REGISTER}")
    return report.finish(f"{checked} tracked files, no model weights")


if __name__ == "__main__":
    sys.exit(main())
