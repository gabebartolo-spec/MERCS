#!/usr/bin/env python3
"""Player-text lint (guardrail B12): player-visible strings come from data/text via Text.t("key").

Scans *.gd and *.tscn under ui/ and presentation/.

  TEXT-LITERAL  a .gd string literal that reads as player text: once printf conversions
                (%d, %s, %05.1f) are dropped it holds a letter and either whitespace or a
                leading uppercase letter. Exempt: the first argument of Text.t(; anything
                inside print, prints, printt, printraw, printerr, print_rich, print_verbose,
                print_debug, push_warning, push_error, assert and Debug.<any> calls; res://, user:// and
                uid:// paths; &"..." and ^"..." literals (the escape hatch for names such as
                &"Idle"); dictionary keys ("key": inside {}) and subscripts (x["key"]).
  TEXT-SCENE    a .tscn line that sets text, tooltip_text, placeholder_text, title or
                dialog_text to a string that reads as player text (same test; a value that
                spans lines is read whole and reported on the line it starts).

Usage: python tools/lint/strings.py [--root DIR]
"""
from __future__ import annotations

import re
import sys

from lintlib import (STR, GdSource, Lit, Report, ends_operand, files_under, next_char, parse_args,
                     prev_index, read_text, rel, scan_gd)

SCANNED = ("ui", "presentation")
PATH_PREFIXES = ("res://", "user://", "uid://")
DEV_CALLS = ("print", "prints", "printt", "printraw", "printerr", "print_rich", "print_verbose",
             "print_debug", "push_warning", "push_error", "assert")
# Any method of the Debug autoload is a developer call too (Concept Lead review of #5).
DEV_CALL = re.compile(r"(?:(?<!\w)(?:" + "|".join(DEV_CALLS) + r")|(?<![\w.])Debug\s*\.\s*\w+)\s*$")
TEXT_KEY = re.compile(r"(?<!\w)Text\s*\.\s*t\s*\(\s*(\x01)")
PRINTF = re.compile(r"%[-+#0]*\d*(?:\.\d+)?[a-zA-Z]")
ESCAPE = re.compile(r"\\(.)", re.S)
# Engine names passed as plain strings: groups, node paths and animations (#5 review).
ENGINE_NAME_CALLS = ("add_to_group", "remove_from_group", "is_in_group", "get_node", "get_node_or_null",
                     "has_node", "play", "play_backwards", "queue", "has_animation")
ENGINE_NAME_ARG = re.compile(r"(?<!\w)(?:" + "|".join(ENGINE_NAME_CALLS) + r")\s*\(\s*$")
OS_NAME = r"(?<![\w.])OS\s*\.\s*get_name\s*\(\s*\)"
OS_NAME_BEFORE = re.compile(OS_NAME + r"\s*[!=]=\s*$")
OS_NAME_AFTER = re.compile(r"\s*[!=]=\s*" + OS_NAME)
SCENE_PROPERTY = re.compile(r'^\s*(text|tooltip_text|placeholder_text|title|dialog_text)\s*=\s*"')
SCENE_STRING_END = re.compile(r'(?:[^"\\]|\\.)*"', re.S)


def excerpt(text: str) -> str:
    """One-line, at most 40 characters, for a finding message."""
    flat = " ".join(text.split())
    return flat if len(flat) <= 40 else flat[:37] + "..."


def reads_as_text(raw: str, prefix: str = "") -> bool:
    """True when the literal looks like words a player would read."""
    text = raw if prefix == "r" else ESCAPE.sub(lambda m: " " if m.group(1) in "ntr" else m.group(1), raw)
    text = PRINTF.sub("", text)
    if not any(ch.isalpha() for ch in text):
        return False
    return any(ch.isspace() for ch in text) or text[0].isupper()


def bracket_context(code: str) -> dict[int, tuple[str, bool]]:
    """For each string placeholder: (innermost opening bracket, inside a developer-message call)."""
    stack: list[tuple[str, bool]] = []
    context: dict[int, tuple[str, bool]] = {}
    for i, ch in enumerate(code):
        if ch in "([{":
            dev = ch == "(" and DEV_CALL.search(code, max(0, i - 64), i) is not None
            stack.append((ch, dev))
        elif ch in ")]}":
            if stack:
                stack.pop()
        elif ch == STR:
            context[i] = (stack[-1][0] if stack else "", any(dev for _, dev in stack))
    return context


def names_engine_thing(code: str, pos: int) -> bool:
    """True for the first argument of a group, node or animation call, or a string compared
    with OS.get_name(): engine names, not player text."""
    before = code[max(0, pos - 64):pos]
    return (ENGINE_NAME_ARG.search(before) is not None or OS_NAME_BEFORE.search(before) is not None
            or OS_NAME_AFTER.match(code, pos + 1) is not None)


def is_exempt(lit: Lit, code: str, context: dict[int, tuple[str, bool]], key_args: set[int]) -> bool:
    if lit.prefix in ("&", "^") or lit.text.startswith(PATH_PREFIXES) or lit.pos in key_args:
        return True
    opener, in_dev_call = context[lit.pos]
    if in_dev_call or names_engine_thing(code, lit.pos):
        return True
    after = next_char(code, lit.pos)
    if opener == "{":  # a dictionary key: "key": value
        return after == ":"
    if opener == "[":  # a subscript: x["key"], not an array literal such as ["a", "b"]
        bracket = prev_index(code, lit.pos)
        return code[bracket] == "[" and after == "]" and ends_operand(code, bracket)
    return False


def check_script(path: str, src: GdSource, report: Report) -> None:
    context = bracket_context(src.code)
    key_args = {match.start(1) for match in TEXT_KEY.finditer(src.code)}
    for lit in src.lits:
        if reads_as_text(lit.text, lit.prefix) and not is_exempt(lit, src.code, context, key_args):
            report.error(path, lit.line, "TEXT-LITERAL",
                         f'player text "{excerpt(lit.text)}" in a script: put it in data/text/en.json and call Text.t("key") (B12)')


def scene_string(lines: list[str], index: int, col: int) -> tuple[str, int]:
    """The string whose opening quote ends at lines[index][:col]; returns (text, next line index)."""
    parts: list[str] = []
    while index < len(lines):
        chunk = lines[index][col:]
        closed = SCENE_STRING_END.match(chunk)
        if closed:
            parts.append(chunk[:closed.end() - 1])
            return "\n".join(parts), index + 1
        parts.append(chunk)
        index, col = index + 1, 0
    return "\n".join(parts), index


def check_scene(path: str, text: str, report: Report) -> None:
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        match = SCENE_PROPERTY.match(lines[index])
        if not match:
            index += 1
            continue
        value, following = scene_string(lines, index, match.end())
        if reads_as_text(value):
            report.error(path, index + 1, "TEXT-SCENE",
                         f'scene sets {match.group(1)} to player text "{excerpt(value)}": set it from code with Text.t("key") (B12)')
        index = following


def main() -> int:
    root = parse_args(__doc__, __file__)
    report = Report()
    files = files_under(root, SCANNED, (".gd", ".tscn"))
    for path in files:
        if path.suffix.lower() == ".gd":
            check_script(rel(root, path), scan_gd(read_text(path)), report)
        else:
            check_scene(rel(root, path), read_text(path), report)
    return report.finish(f"{len(files)} ui and presentation files")


if __name__ == "__main__":
    sys.exit(main())
