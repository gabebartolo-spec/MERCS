#!/usr/bin/env bash
# D-071: is PR <n> eligible to merge? Steps B and C2 of agent-briefs/MERGE_CI_AGENT.md as a
# script. Prints "eligible <pr> <head-sha>" and exits 0, or the FIRST failing reason and exits 1.
#
#   tools/merge_eligibility.sh 77
#   tools/merge_eligibility.sh --fixture tests/fixtures/merge_eligibility/eligible.json   # offline
#
# Fetches with gh only; the decision is tools/merge_eligibility.py (offline, fixture-tested by
# tools/test_run_tests.sh). Merge with: gh pr merge <n> --squash --match-head-commit <sha> --delete-branch
set -euo pipefail
cd "$(dirname "$0")/.."

py=""
for candidate in "${PYTHON:-}" python3 python; do
	[ -n "$candidate" ] && command -v "$candidate" > /dev/null 2>&1 && py="$candidate" && break
done
[ -n "$py" ] || { echo "no python found (set PYTHON)"; exit 1; }

if [ "${1:-}" = "--fixture" ]; then
	exec "$py" tools/merge_eligibility.py "${2:?fixture path}"
fi
pr="${1:?usage: tools/merge_eligibility.sh <pr-number> | --fixture <file>}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gh pr view "$pr" --json number,state,isDraft,mergeable,mergeStateStatus,headRefOid,headRefName,body,files > "$tmp/pr.json"
sha=$("$py" -c 'import json,sys; print(json.load(open(sys.argv[1]))["headRefOid"])' "$tmp/pr.json")
# check-runs of exactly this head sha (the rollup can lag behind a push)
gh api --paginate "repos/{owner}/{repo}/commits/$sha/check-runs?per_page=100" --jq '.check_runs[]' \
	| "$py" -c 'import json,sys
dec=json.JSONDecoder(); s=sys.stdin.read(); i=0; out=[]
while i < len(s):
    while i < len(s) and s[i].isspace(): i+=1
    if i >= len(s): break
    o,i=dec.raw_decode(s,i); out.append(o)
json.dump(out, open(sys.argv[1],"w"))' "$tmp/runs.json"
"$py" -c 'import json,sys
pr=json.load(open(sys.argv[1])); pr["files"]=pr.get("files") or []
json.dump({"pr":pr,"check_runs":json.load(open(sys.argv[2]))}, open(sys.argv[3],"w"))' "$tmp/pr.json" "$tmp/runs.json" "$tmp/doc.json"
exec "$py" tools/merge_eligibility.py "$tmp/doc.json"
