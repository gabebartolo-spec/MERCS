#!/usr/bin/env python3
"""Content-count lint (guardrail A2): hard counts per phase live in data/caps.json.

  CAP-OVER     a content collection holds more entries than its cap
  CAP-MISSING  a content collection exists in data/ but caps.json gives it no cap
  CAP-FILE     data/caps.json is missing, unparsable or not {"phase": N, "caps": {name: count}},
               or a collection file is unparsable or lacks its "<name>" array

A content collection is data/<name>.json holding {"<name>": [...]}, or a folder data/<name>/
whose *.json files each hold {"<name>": [...]} (their entries are summed). data/schema/,
data/text/, data/balance/ and data/caps.json are not collections. A _comment key may appear
anywhere and is ignored. With no data/ folder at all there is nothing to count: the lint passes.

Usage: python tools/lint/content_counts.py [--root DIR]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from lintlib import Report, parse_args, read_text, rel

CAPS_FILE = "data/caps.json"
NOT_CONTENT = frozenset({"schema", "text", "balance"})


def parse_json(path: Path) -> tuple[object, str, int]:
    """(data, problem, line): problem is empty when the file parsed, else the error and its line."""
    try:
        return json.loads(read_text(path)), "", 0
    except ValueError as exc:
        return None, str(exc), getattr(exc, "lineno", 0)
    except OSError as exc:
        return None, str(exc), 0


def non_negative_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def shape_problems(data: object) -> list[str]:
    if not isinstance(data, dict):
        return ['must be an object like {"phase": 0, "caps": {"backgrounds": 0}}']
    problems = []
    if not non_negative_int(data.get("phase")):
        problems.append('"phase" must be a non-negative integer')
    caps = data.get("caps")
    if not isinstance(caps, dict):
        problems.append('"caps" must be an object of collection name to count')
    else:
        problems += [f'cap "{name}" must be a non-negative integer'
                     for name, value in caps.items() if name != "_comment" and not non_negative_int(value)]
    return problems


def load_caps(root: Path, report: Report) -> tuple[int, dict[str, int]] | None:
    path = root / CAPS_FILE
    if not path.is_file():
        report.error(CAPS_FILE, 0, "CAP-FILE", "missing: every content collection needs a cap in this file")
        return None
    data, problem, line = parse_json(path)
    if problem:
        report.error(CAPS_FILE, line, "CAP-FILE", f"not valid JSON: {problem}")
        return None
    problems = shape_problems(data)
    for text in problems:
        report.error(CAPS_FILE, 0, "CAP-FILE", text)
    if problems:
        return None
    return data["phase"], {name: count for name, count in data["caps"].items() if name != "_comment"}


def find_collections(data_dir: Path) -> dict[str, list[Path]]:
    """Collection name -> its JSON files (one file, or the files of a folder)."""
    found: dict[str, list[Path]] = {}
    for entry in sorted(data_dir.iterdir()):
        if entry.name.startswith("."):
            continue
        if entry.is_file() and entry.suffix.lower() == ".json" and entry.name != "caps.json":
            found.setdefault(entry.stem, []).append(entry)
        elif entry.is_dir() and entry.name not in NOT_CONTENT:
            files = sorted(f for f in entry.glob("*.json") if f.is_file())
            if files:
                found.setdefault(entry.name, []).extend(files)
    return found


def count_entries(root: Path, name: str, files: list[Path], report: Report) -> int:
    total = 0
    for file in files:
        shown = rel(root, file)
        data, problem, line = parse_json(file)
        if problem:
            report.error(shown, line, "CAP-FILE", f"not valid JSON: {problem}")
            continue
        entries = data.get(name) if isinstance(data, dict) else None
        if not isinstance(entries, list):
            report.error(shown, 0, "CAP-FILE", f'must hold a "{name}" array')
            continue
        total += len(entries)
    return total


def main() -> int:
    root = parse_args(__doc__, __file__)
    report = Report()
    data_dir = root / "data"
    if not data_dir.is_dir():
        return report.finish("no data/ folder yet, 0 collections")
    loaded = load_caps(root, report)
    checked = 0
    if loaded is not None:
        _, caps = loaded
        for name, files in find_collections(data_dir).items():
            where = rel(root, files[0]) if files[0].parent == data_dir else f"data/{name}"
            if name not in caps:
                report.error(where, 0, "CAP-MISSING", f'"{name}" has no cap in {CAPS_FILE}')
                continue
            total = count_entries(root, name, files, report)
            checked += 1
            if total > caps[name]:
                report.error(where, 0, "CAP-OVER", f'"{name}" holds {total} entries, the cap is {caps[name]}')
    phase = f" (phase {loaded[0]})" if loaded is not None else ""
    return report.finish(f"{checked} collections within their caps{phase}")


if __name__ == "__main__":
    sys.exit(main())
