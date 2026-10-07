#!/usr/bin/env python3
"""Function limits (05_STYLE_CODE.md "Typing and structure"): what gdlint cannot check.

Scans *.gd under sim/, presentation/, ui/ and tests/ (never tests/fixtures/).

  FUNC-LINES       a function longer than 40 lines, counted from its `func` line through
                   its last non-blank line (comments and blank lines inside count).
  FUNC-COMPLEXITY  a function whose cyclomatic complexity is over 12: 1, plus one for each
                   `if`, `elif`, `for`, `while`, `and`, `or`, `&&`, `||` in code (a ternary
                   `if` counts) and one for each `match` arm. Comments and strings never count.

gdlint (lint.yml) checks the other 05 limits: 400 lines per file, 4 parameters.

Usage: python tools/lint/function_limits.py [--root DIR]
"""
from __future__ import annotations

import re
import sys

from lintlib import Report, files_under, parse_args, read_text, rel, scan_gd

MAX_LINES = 40
MAX_COMPLEXITY = 12
SCANNED = ("sim", "presentation", "ui", "tests")
FUNC = re.compile(r"^(?:static\s+)?func\s+(\w+)")
DECISION = re.compile(r"(?<!\w)(?:if|elif|for|while|and|or)(?!\w)|&&|\|\|")
MATCH = re.compile(r"^match\b.*:\s*$")


def indent_of(line: str) -> int:
    expanded = line.replace("\t", "    ")
    return (len(expanded) - len(expanded.lstrip(" "))) // 4


def function_spans(lines: list[str]) -> list[tuple[str, int, int]]:
    """(name, first index, last non-blank index) for every top-level or inner `func`."""
    spans = []
    for i, line in enumerate(lines):
        found = FUNC.match(line.strip())
        if not found:
            continue
        depth, last = indent_of(line), i
        for j in range(i + 1, len(lines)):
            if not lines[j].strip():
                continue
            if indent_of(lines[j]) <= depth:
                break
            last = j
        spans.append((found.group(1), i, last))
    return spans


def complexity(body: list[str]) -> int:
    score = 1
    for k, line in enumerate(body):
        score += len(DECISION.findall(line))
        if MATCH.match(line.strip()):
            depth = indent_of(line)
            for arm in body[k + 1:]:
                if not arm.strip():
                    continue
                if indent_of(arm) <= depth:
                    break
                if indent_of(arm) == depth + 1 and arm.rstrip().endswith(":"):
                    score += 1
    return score


def check_file(report: Report, root, path) -> None:
    lines = scan_gd(read_text(path)).code.split("\n")
    where = rel(root, path)
    for name, first, last in function_spans(lines):
        length = last - first + 1
        if length > MAX_LINES:
            report.error(where, first + 1, "FUNC-LINES",
                         f"{name}() is {length} lines (max {MAX_LINES}): split it")
        score = complexity(lines[first + 1:last + 1])
        if score > MAX_COMPLEXITY:
            report.error(where, first + 1, "FUNC-COMPLEXITY",
                         f"{name}() has complexity {score} (max {MAX_COMPLEXITY}): split it")


def main() -> int:
    root = parse_args(__doc__, __file__)
    report = Report()
    files = [p for p in files_under(root, SCANNED, (".gd",))
             if not rel(root, p).startswith("tests/fixtures/")]
    for path in files:
        check_file(report, root, path)
    return report.finish(f"{len(files)} scripts within {MAX_LINES} lines and complexity {MAX_COMPLEXITY} per function")


if __name__ == "__main__":
    sys.exit(main())
