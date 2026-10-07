#!/usr/bin/env python3
"""Magic-number and colour-literal lint (guardrails B9 and D3).

  MAGIC-NUMBER    a numeric literal in sim/**/*.gd whose value is not 0, 1 or 100 (any sign;
                  int, float, 0x hex, 0b binary, 1_000 and exponent forms; digits inside
                  identifiers such as Vector2i are not literals). An error once data/caps.json
                  says "phase" >= STRICT_FROM_PHASE; a warning in Phases 0-2 and whenever
                  caps.json is missing or unreadable (B9: warning in Phase 1-2, error from 3).
  COLOUR-LITERAL  always an error, in ui/**/*.gd, ui/**/*.tscn and ui/**/*.tres except the
                  colour owner: Color( or Color8( or any Color.<member> (Color.RED,
                  Color.html(, Color.from_hsv(, ...) in code, and .gd string literals that are
                  hex colours (#rgb, #rgba, #rrggbb, #rrggbbaa; without # only six or eight hex
                  digits, at least one a digit so words like "decade" pass). Scenes and
                  resources are scanned line by line for Color( (;-comment lines skipped).

The colour owner (UiKit) is the file whose path, lowercased with underscores removed, is
ui/uikit.gd, so the docs' UiKit.gd and the naming rule's ui_kit.gd both match. D3 says
"lint rejects literal colours in ui/", so presentation/ is out of scope. &"..." and ^"..."
literals are identifiers, never colours.

Usage: python tools/lint/magic_numbers.py [--root DIR]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from lintlib import GdSource, Report, files_under, parse_args, read_text, rel, scan_gd

STRICT_FROM_PHASE = 3  # B9: MAGIC-NUMBER is a warning in Phase 1-2 and an error from Phase 3
ALLOWED_VALUES = frozenset({0.0, 1.0, 100.0})  # B9: 0, 1, -1 and 100 (sign is ignored)
COLOUR_OWNER = "ui/uikit.gd"  # compared with the lowercased path minus underscores

NUMBER = re.compile(
    r"(?<![\w.])"  # not inside an identifier, a member access or another number
    r"(?:0[xX][0-9a-fA-F_]+"
    r"|0[bB][01_]+"
    r"|(?:\d[\d_]*(?:\.[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d[\d_]*)?)"
    r"(?!\w)"
)
COLOUR_CALL = re.compile(r"(?<![\w.])Color8?\s*\(")
COLOUR_MEMBER = re.compile(r"(?<![\w.])Color\s*\.")
SCENE_COLOUR = re.compile(r"(?<![\w.])Color\(")
HEX_WITH_HASH = re.compile(r"#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})")
HEX_BARE = re.compile(r"(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})")


def number_value(token: str) -> float:
    text = token.replace("_", "")
    try:
        if text[:2] in ("0x", "0X"):
            return float(int(text, 16))
        if text[:2] in ("0b", "0B"):
            return float(int(text, 2))
        return float(text)
    except ValueError:
        return float("nan")  # never in ALLOWED_VALUES, so it is reported


def is_hex_colour(text: str) -> bool:
    if text.startswith("#"):
        return HEX_WITH_HASH.fullmatch(text) is not None
    return HEX_BARE.fullmatch(text) is not None and any(ch.isdigit() for ch in text)


def read_phase(root: Path) -> int | None:
    """The "phase" of data/caps.json, or None when it is missing or not an integer."""
    try:
        data = json.loads(read_text(root / "data" / "caps.json"))
    except (OSError, ValueError):
        return None
    phase = data.get("phase") if isinstance(data, dict) else None
    return phase if isinstance(phase, int) and not isinstance(phase, bool) else None


def check_numbers(path: str, src: GdSource, strict: bool, report: Report) -> None:
    emit = report.error if strict else report.warn
    for match in NUMBER.finditer(src.code):
        if number_value(match.group()) not in ALLOWED_VALUES:
            emit(path, src.line_at(match.start()), "MAGIC-NUMBER",
                 f"literal {match.group()} in sim: tunable numbers live in data/balance/*.json (B9)")


def check_colours_gd(path: str, src: GdSource, report: Report) -> None:
    for pattern, what in ((COLOUR_CALL, "a Color constructor"), (COLOUR_MEMBER, "a Color member")):
        for match in pattern.finditer(src.code):
            report.error(path, src.line_at(match.start()), "COLOUR-LITERAL",
                         f"ui code uses {what}: take colours from UiKit (D3)")
    for lit in src.lits:
        if lit.prefix not in ("&", "^") and is_hex_colour(lit.text):
            report.error(path, lit.line, "COLOUR-LITERAL",
                         f'ui code has the hex colour "{lit.text}": take colours from UiKit (D3)')


def check_colours_scene(path: str, text: str, report: Report) -> None:
    for number, raw in enumerate(text.splitlines(), 1):
        if not raw.lstrip().startswith(";") and SCENE_COLOUR.search(raw):
            report.error(path, number, "COLOUR-LITERAL",
                         "ui scene or resource sets a Color( literal: take colours from UiKit (D3)")


def main() -> int:
    root = parse_args(__doc__, __file__)
    report = Report()
    phase = read_phase(root)
    strict = phase is not None and phase >= STRICT_FROM_PHASE
    sim_files = files_under(root, ("sim",), (".gd",))
    for path in sim_files:
        check_numbers(rel(root, path), scan_gd(read_text(path)), strict, report)
    ui_files = files_under(root, ("ui",), (".gd", ".tscn", ".tres"))
    for path in ui_files:
        name = rel(root, path)
        if name.lower().replace("_", "") == COLOUR_OWNER:
            continue
        if path.suffix.lower() == ".gd":
            check_colours_gd(name, scan_gd(read_text(path)), report)
        else:
            check_colours_scene(name, read_text(path), report)
    warnings = sum(1 for item in report.items if item.warning)
    note = f", {warnings} warnings" if warnings else ""
    return report.finish(f"{len(sim_files)} sim scripts, {len(ui_files)} ui files{note}")


if __name__ == "__main__":
    sys.exit(main())
