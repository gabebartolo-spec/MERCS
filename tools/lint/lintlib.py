"""Shared helpers for the project lints (Python standard library only).

* `parse_args`: the `--root DIR` option; the default root is the repo this file lives in.
* `Report`: findings printed as `<path>:<line>: <RULE> <message>` (`warning <RULE>` for
  warnings) plus GitHub annotations when GITHUB_ACTIONS is set; exit 1 on any error.
* `scan_gd`: a GDScript tokeniser that separates code from comments and string literals.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from bisect import bisect_right
from dataclasses import dataclass, field
from pathlib import Path

STR = "\x01"  # stands in for one string literal inside GdSource.code
IDENT = re.compile(r"(?<!\w)[A-Za-z_]\w*")
KEYWORDS = frozenset(
    "return and or not in if elif else while await is as match assert yield".split()
)


def parse_args(doc: str, script: str) -> Path:
    """Parse `--root DIR` (default: the repo root, two levels above tools/lint/)."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=doc.strip().splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(script).resolve().parents[2],
                        help="repo root to check (default: the repo containing this script)")
    return parser.parse_args().root.resolve()


def rel(root: Path, path: Path) -> str:
    """Path relative to the root with forward slashes, as printed in findings."""
    return path.relative_to(root).as_posix()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def files_under(root: Path, subdirs: tuple[str, ...], suffixes: tuple[str, ...]) -> list[Path]:
    """Sorted files with one of the suffixes below root/<subdir>, skipping hidden folders."""
    found: list[Path] = []
    for sub in subdirs:
        base = root / sub
        if base.is_dir():
            for path in base.rglob("*"):
                hidden = any(part.startswith(".") for part in path.relative_to(base).parts)
                if path.is_file() and path.suffix.lower() in suffixes and not hidden:
                    found.append(path)
    return sorted(found)


@dataclass(frozen=True, order=True)
class Finding:
    path: str
    line: int
    rule: str
    message: str
    warning: bool = False


class Report:
    """Collects findings; `finish` prints them and returns the process exit code."""

    def __init__(self) -> None:
        self.items: set[Finding] = set()

    def error(self, path: str, line: int, rule: str, message: str) -> None:
        self.items.add(Finding(path, line, rule, " ".join(message.split())))

    def warn(self, path: str, line: int, rule: str, message: str) -> None:
        self.items.add(Finding(path, line, rule, " ".join(message.split()), warning=True))

    def finish(self, ok_message: str) -> int:
        annotate = bool(os.environ.get("GITHUB_ACTIONS"))
        for item in sorted(self.items):
            tag = "warning " if item.warning else ""
            print(f"{item.path}:{item.line}: {tag}{item.rule} {item.message}")
            if annotate:
                kind = "warning" if item.warning else "error"
                print(f"::{kind} file={item.path},line={item.line}::{item.rule} {item.message}")
        if any(not item.warning for item in self.items):
            return 1
        print(f"ok: {ok_message}")
        return 0


@dataclass
class Lit:
    """One string literal: raw text between the quotes, prefix (&, ^, r or none), position."""

    text: str
    prefix: str
    pos: int   # index of its STR placeholder in GdSource.code
    line: int  # line the literal starts on (1-based)


@dataclass
class GdSource:
    """GDScript text with comments removed and every string literal replaced by one STR.

    Newlines survive (a multi-line literal keeps its newlines after the placeholder), so
    line numbers computed from `code` match the file.
    """

    code: str
    lits: list[Lit]
    lit_at: dict[int, Lit] = field(init=False)
    _starts: list[int] = field(init=False)

    def __post_init__(self) -> None:
        self.lit_at = {lit.pos: lit for lit in self.lits}
        self._starts = [0] + [i + 1 for i, ch in enumerate(self.code) if ch == "\n"]

    def line_at(self, idx: int) -> int:
        return bisect_right(self._starts, idx)


_PLAIN = re.compile(r"[^\n#\"']+")


def scan_gd(text: str) -> GdSource:
    """Tokenise GDScript: `#` comments (and `##` docs) end at the line end, strings are
    "..." and '...' with backslash escapes, triple-quoted strings may span lines, and the
    prefixes &"..." (StringName), ^"..." (NodePath) and r"..." (raw) are recognised.
    A `#` inside a string is not a comment."""
    out: list[str] = []
    lits: list[Lit] = []
    i, line, n = 0, 1, len(text)
    while i < n:
        ch = text[i]
        if ch == "\n":
            out.append(ch)
            line += 1
            i += 1
        elif ch == "#":
            end = text.find("\n", i)
            i = n if end < 0 else end
        elif ch in "\"'":
            i, line = _read_string(text, i, line, out, lits)
        else:
            run = _PLAIN.match(text, i).group()
            out.extend(run)
            i += len(run)
    return GdSource("".join(out), lits)


def _read_string(text: str, i: int, line: int, out: list[str], lits: list[Lit]) -> tuple[int, int]:
    quote = text[i]
    triple = text.startswith(quote * 3, i)
    closer = quote * (3 if triple else 1)
    start = i + len(closer)
    end, closed = _string_end(text, start, closer)
    body = text[start:end]
    prefix = _take_prefix(out)
    lits.append(Lit(body, prefix, len(out), line))
    out.append(STR)
    newlines = body.count("\n")
    out.extend("\n" * newlines)
    return (end + len(closer) if closed else end), line + newlines


def _string_end(text: str, j: int, closer: str) -> tuple[int, bool]:
    """Index of the closing quote(s) at or after j, and whether they were found."""
    n = len(text)
    while j < n:
        if text[j] == "\\":
            j += 2
        elif text.startswith(closer, j):
            return j, True
        elif text[j] == "\n" and len(closer) == 1:
            return j, False  # unterminated one-line string: stop at the line end
        else:
            j += 1
    return n, False


def _take_prefix(out: list[str]) -> str:
    """Pop a string prefix already copied into `out` and return it."""
    if not out:
        return ""
    last, before = out[-1], (out[-2] if len(out) > 1 else "")
    if last in "&^" and before != last:  # `&&` is logical and, not a StringName prefix
        out.pop()
        return last
    if last == "r" and not (before.isalnum() or before == "_"):
        out.pop()
        return "r"
    return ""


def prev_index(code: str, idx: int) -> int:
    """Index of the last non-blank character before idx (-1 at the start of the code)."""
    j = idx - 1
    while j >= 0 and code[j] in " \t\r\n":
        j -= 1
    return j


def prev_char(code: str, idx: int) -> str:
    """Last non-blank character before idx ('' at the start of the code)."""
    j = prev_index(code, idx)
    return code[j] if j >= 0 else ""


def next_char(code: str, idx: int) -> str:
    """First non-blank character after idx ('' at the end of the code)."""
    j = idx + 1
    while j < len(code) and code[j] in " \t\r\n":
        j += 1
    return code[j] if j < len(code) else ""


def is_member(code: str, idx: int) -> bool:
    """True when the token at idx is reached through a dot (`obj.token`)."""
    return prev_char(code, idx) == "."


def ends_operand(code: str, idx: int) -> bool:
    """True when the expression before idx is complete (a value), so a following `%` is the
    modulo operator and a following `[` is a subscript rather than a new expression."""
    prev = prev_char(code, idx)
    if not prev:
        return False
    if prev in ")]}" + STR:
        return True
    if prev.isalnum() or prev == "_":
        word = re.search(r"[A-Za-z_]\w*$", code[:idx].rstrip())
        return not (word and word.group() in KEYWORDS)
    return False
