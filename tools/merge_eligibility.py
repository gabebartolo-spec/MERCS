#!/usr/bin/env python3
"""The decision half of tools/merge_eligibility.sh (D-071): reads one JSON document
{"pr": <gh pr view --json ...>, "check_runs": [<check-runs of the head sha>]}
from a file or stdin and prints "eligible <pr> <sha>" (exit 0) or the FIRST failing
reason (exit 1). Pure and offline, so the harness self-test can feed it fixtures.

The list is agent-briefs/MERGE_CI_AGENT.md steps B and C2, for the PR's head only.
"""
from __future__ import annotations

import json
import re
import sys

REQUIRED_CHECKS = ("test", "doc-caps", "gitleaks", "project-lints")
SECTIONS = ("Evidence", "Not exercised", "Board and log", "[MERGE NOTE]")
BOARD_FILES = ("docs/STATUS.md", "docs/DECISIONS.md")
BOARD_BRANCH = re.compile(r"^docs/board-after-")


def docs_only(files: list[str]) -> bool:
    return all(f.startswith("docs/") or f.endswith(".md") for f in files)


def section_body(body: str, name: str) -> str | None:
    match = re.search(r"^##\s+" + re.escape(name) + r"[^\n]*\n(.*?)(?=^##\s|\Z)", body, re.M | re.S)
    return None if match is None else match.group(1).strip()


def note_line(note: str, label: str) -> str | None:
    match = re.search(r"^[-*]\s*" + re.escape(label) + r":\s*(.*)$", note, re.M | re.I)
    return None if match is None else match.group(1).strip()


def decide(doc: dict) -> str | None:
    """None when eligible, else the first failing reason."""
    pr = doc["pr"]
    n = pr["number"]
    sha = pr["headRefOid"]
    if pr.get("state", "OPEN") != "OPEN":
        return f"#{n} is {pr['state'].lower()}, not open"
    if pr.get("isDraft"):
        return f"#{n} is a draft"
    if pr.get("mergeable") != "MERGEABLE":
        return f"#{n} is not mergeable ({pr.get('mergeable')}); the owner syncs origin/main"
    if pr.get("mergeStateStatus") in ("BEHIND", "DIRTY"):
        return f"#{n} is {pr['mergeStateStatus'].lower()} against main; the owner syncs origin/main"
    runs = [r for r in doc.get("check_runs", []) if r.get("head_sha") == sha]
    for name in REQUIRED_CHECKS:
        mine = [r for r in runs if r["name"] == name]
        if not mine:
            return f"required check '{name}' has no run on head {sha[:8]}"
        if not any(r.get("status") == "completed" and r.get("conclusion") == "success" for r in mine):
            r = mine[-1]
            return f"required check '{name}' is {r.get('conclusion') or r.get('status')} on head {sha[:8]}"
    files = [f["path"] for f in pr.get("files", [])]
    if not docs_only(files):
        shards = [r for r in runs if r["name"].startswith("shard ") or r["name"] == "harness self-test"]
        if not shards:
            return f"no Godot shard ran on head {sha[:8]} for a code PR"
        for r in shards:
            if r.get("conclusion") != "success":
                return f"'{r['name']}' is {r.get('conclusion') or r.get('status')} on head {sha[:8]} (a code PR must run the Godot shards)"
    body = pr.get("body") or ""
    for name in SECTIONS:
        text = section_body(body, name)
        if text is None:
            return f"PR body is missing the '## {name}' section"
        if not text:
            return f"PR body section '## {name}' is empty"
    note = section_body(body, "[MERGE NOTE]") or ""
    review = note_line(note, "Review needed")
    if review is None or not re.match(r"(none|done)\b", review, re.I):
        return f"[MERGE NOTE] 'Review needed' must be none or done, found: {review}"
    gate = note_line(note, "Director gate")
    if gate is None or not re.match(r"(none|done|approved in D-)", gate, re.I):
        return f"[MERGE NOTE] 'Director gate' must be none or done (or approved in D-id), found: {gate}"
    if not BOARD_BRANCH.match(pr.get("headRefName", "")):
        hit = [f for f in files if f in BOARD_FILES]
        if hit:
            return f"#{n} touches {', '.join(hit)} and is not a board PR (docs/board-after-*)"
    return None


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "-" else None
    doc = json.load(open(src, encoding="utf-8") if src else sys.stdin)
    reason = decide(doc)
    if reason:
        print(reason)
        return 1
    print(f"eligible {doc['pr']['number']} {doc['pr']['headRefOid']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
