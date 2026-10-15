#!/usr/bin/env python3
"""Save-order lint (Ironman, D-087: a quit resumes the exact state): an autosave is the last thing
a decision's handler does, after every state change the decision causes.

  SAVE-LATE    in a function that autosaves (`autosave()`, `autosave.call()`, `x.autosave()`),
               a statement that can run after the autosave is not presentation-only: it may
               change the run after the save was written, so a quit there loses it
  SAVE-PARKED  a world hook (`result_hook`, `day_hook`, or a local var holding one) bound with
               `.bind(`: its state changes are parked for a later input and miss the autosave
               that came before it
  SAVE-POLL    a function `_process` calls writes the run's memories (`<memory>.record(`,
               `.on_choice(`, `.on_death(` on a name containing "memory") but is not registered as a save observer
               (`before_save(<name>)` in the same file): a save written before that frame
               misses what it records

Presentation-only after an autosave: `return`, `pass`, redraws (`_show...(`, `show_...(`),
`set_open(`, `panel.`, `map.show_world(`, `_layer.`, and `if`/`for`/`while` headers (their
bodies are checked). Branches of the same `if` or `match` that cannot run after the autosave
(`elif`, `else`, other match arms) are skipped. The rule and its observers: CampaignSaves
(presentation/world/campaign_saves.gd, "Save order"). Scans presentation/ and ui/; comments
and strings never trigger a rule.

This lint is a tripwire, not the guard: it reads one function at a time and is easily fooled (a
lambda, bindv, a field, call_deferred, a timer, a helper that saves; review of #148). The guard is
the runtime check tests/lib/save_watch.gd (ironman_resume suite): no change without a save.

Usage: python tools/lint/save_order.py [--root DIR]
"""
from __future__ import annotations

import re
import sys

from lintlib import Report, files_under, parse_args, read_text, rel, scan_gd

SCANNED = ("presentation", "ui")
FUNC = re.compile(r"^(?:static\s+)?func\s+(\w+)")
AUTOSAVE = re.compile(r"(?<![\w.])autosave\s*\(\s*\)|\bautosave\.call\s*\(|\.autosave\s*\(")
SHOWS_ONLY = re.compile(
    r"^(?:return\b.*|pass|_?show\w*\(.*\)|set_open\(.*\)|panel\.\S.*|map\.show_world\(.*\)"
    r"|_layer\.\S.*|(?:if|for|while)\b.*:)$"
)
BRANCH = re.compile(r"^(?:elif\b.*|else\s*:)$")
# A match arm: `REST:`, `"pay":`, `A, B:` (no call, no assignment, not a block header).
ARM = re.compile(r"^(?!(?:if|for|while|match|elif|else|func)\b)[^=()]*[^=:]:$")
HOOK = r"\b\w+\.(?:result_hook|day_hook)\b"
HOOK_ALIAS = re.compile(r"^var\s+(\w+)\s*(?::\s*\w+\s*)?:?=\s*" + HOOK + r"\s*$")
WRITES_MEMORY = re.compile(r"(?i)(?<![\w])\w*memory\w*\.(?:record|on_choice|on_death)\(")
CALL = re.compile(r"(?<![\w.])(_?\w+)\(")
OBSERVER = re.compile(r"\bbefore_save\(\s*(\w+)\s*\)")

Body = list[tuple[int, int, str]]


def functions(code: str) -> list[tuple[str, Body]]:
    """(name, [(line, indent, stripped text)]) for each function's non-blank body."""
    found: list[tuple[str, Body]] = []
    for number, raw in enumerate(code.split("\n"), start=1):
        if not raw.strip():
            continue
        indent = len(raw) - len(raw.lstrip("\t"))
        match = FUNC.match(raw) if indent == 0 else None
        if match:
            found.append((match.group(1), []))
        elif indent == 0:
            found.append(("", []))  # a class-level statement ends the function
        elif found:
            found[-1][1].append((number, indent, raw.strip()))
    return [entry for entry in found if entry[0]]


def late_lines(body: Body, at: int) -> list[tuple[int, str]]:
    """Statements after body[at] (an autosave) that can run after it and are not show-only."""
    level = body[at][1]
    skip_above = -1
    late: list[tuple[int, str]] = []
    for number, indent, text in body[at + 1:]:
        if skip_above >= 0 and indent > skip_above:
            continue
        skip_above = -1
        if indent < level and (BRANCH.match(text) or ARM.match(text)):
            skip_above = indent
            continue
        if indent <= level and re.match(r"return\b", text):
            break
        level = min(level, indent)
        structure = BRANCH.match(text) or ARM.match(text) or AUTOSAVE.search(text)
        if not structure and not SHOWS_ONLY.match(text):
            late.append((number, text))
    return late


def check_late(report: Report, path: str, name: str, body: Body) -> None:
    for at, (_number, _indent, text) in enumerate(body):
        if AUTOSAVE.search(text):
            for number, late in late_lines(body, at):
                report.error(path, number, "SAVE-LATE",
                             f"`{late}` can run after the autosave in {name}(): apply every "
                             "change first, autosave last (CampaignSaves \"Save order\")")


def check_parked(report: Report, path: str, body: Body) -> None:
    aliases = [m.group(1) for _n, _i, text in body if (m := HOOK_ALIAS.match(text))]
    names = [HOOK] + [rf"\b{re.escape(alias)}\b" for alias in aliases]
    parked = re.compile(r"(?:" + "|".join(names) + r")\.bind\(")
    for number, _indent, text in body:
        if parked.search(text):
            report.error(path, number, "SAVE-PARKED",
                         "a world hook parked for a later input misses the autosave: apply it "
                         "now and wait only to show it (CampaignSaves \"Save order\")")


def check_poll(report: Report, path: str, name: str, body: Body,
               by_name: dict[str, Body], observers: set[str]) -> None:
    for number, _indent, text in body:
        for called in CALL.findall(text):
            target = by_name.get(called, [])
            writes = any(WRITES_MEMORY.search(line) for _n, _i, line in target)
            if writes and called not in observers:
                report.error(path, number, "SAVE-POLL",
                             f"{called}() writes memories from {name}() but is not registered "
                             f"with before_save({called}): a save made before that frame "
                             "misses them")


def check_file(report: Report, path: str, code: str) -> None:
    funcs = functions(code)
    by_name = dict(funcs)
    observers = set(OBSERVER.findall(code))
    for name, body in funcs:
        check_late(report, path, name, body)
        check_parked(report, path, body)
        if name in ("_process", "_physics_process"):
            check_poll(report, path, name, body, by_name, observers)


def main() -> int:
    root = parse_args(__doc__, __file__)
    report = Report()
    count = 0
    for file in files_under(root, SCANNED, (".gd",)):
        count += 1
        check_file(report, rel(root, file), scan_gd(read_text(file)).code)
    return report.finish(f"{count} scripts follow the save order")


if __name__ == "__main__":
    sys.exit(main())
