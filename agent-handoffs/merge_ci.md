# Merge & CI handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/MERGE_CI_AGENT.md`, with step C2), and the current phase section of `docs/08_ROADMAP.md` only.

## State: available (director paused work; nothing running)
## Task
Standing merge pass (D-030). Last pass: no open PRs; `main` green; board current through #60 (this PR).
## Branch and commit
This board and handoff only: docs/board-after-60. No other PR open.
## Files I own right now
None besides STATUS.md / DECISIONS.md rows in this PR and this file.
## Unfinished changes
None.
## Evidence so far
Merged: #23-#29, #31-#37, #39-#60 (squash, `--match-head-commit`, CI green on the exact head). Decisions logged through D-046. M1 exe: build.yml run 37882105269 on main (3eaa7c6), green.
## Attempts (for the fix-loop rule)
None open.
## Open decisions
- Awaiting director: delete remote branches `claude/p1-crisp-snap` (664434c), `claude/p1-frame-time` (7236cdc), `claude/p1-sheet-export-load` (d520808); all unmerged, no PR, superseded. The permission classifier refuses `git push origin --delete` (git destructive); needs a Bash allow rule or "leave them". Lead and I agreed not to route around it.
## Running jobs
None.
## Rules learnt the hard way
- Repo is squash-only: a PR stacked on a squashed base always conflicts. Brief step C2: dry-run `git merge-tree --write-tree --name-only origin/main <head>` for every open PR before and after each merge; the owner merges origin/main into the branch (no force push, D-030). Merge the PR that needs no sync first.
- A sync done before another PR lands goes stale; re-run the dry-run after each merge and tell the owner at once.
- Floors read lower on a branch behind main: `plan` fails; owner merges origin/main.
- A cancelled duplicate run beside a green latest run is not a failure; check `gh run list --branch` for the exact head.
- Python edits of STATUS/DECISIONS: open with encoding utf-8 (cp1252 mangles dashes); keep line endings.
- Owners reuse worktrees for new branches; check `git worktree list` before calling one stale.
- Next board PR needs: D-047 onward for new decisions; Dev Lead row.
