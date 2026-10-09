# Merge & CI handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/MERGE_CI_AGENT.md`, with step C2), and the current phase section of `docs/08_ROADMAP.md` only.

## State: available (team resumed by the director 2026-10-10; this session is being cleared and restarted from this file)
## Task
Standing merge pass (D-030). Last pass: `main` green; board current through #70 (board PRs through #69; #70's row is in this PR); D-060 pending.
## Branch and commit
This handoff only: docs/merge-ci-handoff-2.
## Files I own right now
None besides this file.
## Unfinished changes
None. Open PR: #72 (the refresh rule in `mercs-handoff`, docs only, the Lead's): check it first in the next pass (green + mergeable + no conflict; docs-only so shards skip legitimately).
## Evidence so far
Merged this session: #23-#29, #31-#37, #39-#60, #62-#71 (#70 sprite layers, assets floor 13) (squash, `--match-head-commit`, exact-head CI green). M1 and F5 exes: build.yml runs 37882105269 (3eaa7c6) and 37890864099 (5ab5e5c), both green.
## Attempts (for the fix-loop rule)
None open.
## Open decisions (awaiting director)
- D-060 Tripo: ask threshold 500 -> 2,000 credits per session, relayed by the Lead; logged as PENDING; 500 stands until the director confirms in writing (rule 8). Note: the project memory file already says 2,000; the decision log does not.
- Delete unmerged, superseded remote branches `claude/p1-crisp-snap` (664434c), `claude/p1-frame-time` (7236cdc), `claude/p1-sheet-export-load` (d520808). The permission classifier refuses `git push origin --delete`; needs a Bash allow rule or "leave them".
- Worktree `.claude/worktrees/dual-desktop-instances-a78d20` (3a12d1b, clean): prune only if the director confirms it is abandoned.
- The Lead's sketch calls in the slice loop and `caps.json scenarios: 1` (#66) are listed in STATUS under Waiting on the director.
## Running jobs
None.
## Rules learnt the hard way
- Squash-only repo: a PR stacked on a squashed base always conflicts. Brief step C2: dry-run `git merge-tree --write-tree --name-only origin/main <head>` for every open PR before and after each merge; the owner merges origin/main into the branch (no force push, D-030). Merge the PR that needs no sync first.
- Draft-to-ready trap: the ready_for_review run can still read the PR as a draft, so the Godot shards skip and `test` goes green vacuously. Check the run's `plan=... code=... shards=...` line on the exact head for any PR that was ever a draft; the owner pushes one new commit after marking ready (mercs-pr learnings).
- A sync done before another PR lands goes stale; re-run the dry-run after each merge.
- Floors read lower on a branch behind main: `plan` fails; owner merges origin/main.
- doc-caps: handoffs are capped at 120 lines (dev_lead.md hit 130 in #64).
- A cancelled duplicate run beside a green latest run is not a failure; check `gh run list --branch` for the exact head.
- Python edits of STATUS/DECISIONS: open with encoding utf-8; keep line endings. In git bash, `git show origin/main:path` can be mangled; use `gh api .../contents/...` or a worktree.
- Owners reuse worktrees for new branches; check `git worktree list` before calling one stale. Board worktrees vanish after merge on their own.
- Next board PR: D-063 onward for new decisions.
