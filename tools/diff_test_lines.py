#!/usr/bin/env python3
"""Proof that a test-function conversion changed no assertion: compares each suite's lines
at a base ref and now as multisets, after undoing the mechanical rewrite (`await _t("_test_x",
[args])` back to `_x(args)`, `_test_` back to `_check_`, a leading `await ` dropped on a
call line). Prints every line that was removed or added; blank lines are ignored.

  python3 tools/diff_test_lines.py origin/main
"""
import collections
import glob
import re
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
call_old = re.compile(r"^(\t+)(?:await )?(_check_\w+\(.*\))\s*$")
call_new = re.compile(r'^(\t+)await _t\("(_test_\w+)"(?:, \[(.*)\])?\)$')


def norm_old(line):
    m = call_old.match(line)
    return m.group(1) + m.group(2) if m else line


def norm_new(line):
    m = call_new.match(line)
    return "%s%s(%s)" % (m.group(1), m.group(2), m.group(3) or "") if m else norm_old(line)


def unify(line):
    return line.replace("_test_", "_check_")


changed = 0
for path in sorted(glob.glob("tests/run_*_tests.gd")):
    git_path = path.replace("\\", "/")
    old = subprocess.run(["git", "show", "%s:%s" % (base, git_path)], capture_output=True,
                         encoding="utf-8").stdout.replace("\r\n", "\n").split("\n")
    new = open(path, encoding="utf-8", newline="").read().replace("\r\n", "\n").split("\n")
    old_set = collections.Counter(unify(norm_old(l)) for l in old if l.strip())
    new_set = collections.Counter(unify(norm_new(l)) for l in new if l.strip())
    removed, added = old_set - new_set, new_set - old_set
    if removed or added:
        changed += 1
        print(path, "REMOVED", dict(removed), "ADDED", dict(added))
print("%d suites differ beyond the mechanical rewrite" % changed)
