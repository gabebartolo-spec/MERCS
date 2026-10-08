# Merge & CI handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/MERGE_CI_AGENT.md`, now with step C2), and the current phase section of `docs/08_ROADMAP.md` only.

## State: available (director paused work; nothing running)
## Task
Standing merge pass (D-030). Last pass: no open PRs; `main` green; board current through #44 (board PRs #30, #32, #35, #37, #40, #43, #45).
## Branch and commit
This handoff only: docs/merge-ci-handoff. No other PR open.
## Files I own right now
None besides this file.
## Unfinished changes
None.
## Evidence so far
Merged this session: #23-#29, #31-#37, #39-#45 (squash, `--match-head-commit`, CI green on the exact head).
## Attempts (for the fix-loop rule)
None open.
## Open decisions
- Awaiting director: delete remote branches `claude/p1-crisp-snap` (664434c, 2 commits) and `claude/p1-frame-time` (7236cdc), unmerged, no PR, superseded by #25 / D-031. The permission classifier refused `git push origin --delete` (git destructive). Needs a Bash allow rule or a "leave them". Logged in STATUS.md "Logged for later".
- Do not prune `claude/p1-sheet-export-load` (the Lead's, d520808).
## Running jobs
None.
## Rules learnt the hard way
- Repo is squash-only: a PR stacked on a squashed base always conflicts. Brief step C2: dry-run `git merge-tree --write-tree --name-only origin/main <head>` for every open PR before and after each merge; tell the owner to merge origin/main into the branch (no force push, D-030). Prefer unstacked PRs.
- A merge of main with `-X ours` can still resurrect lines git merges silently; owners must re-run suites after a sync.
- Floors read lower on a branch behind main: `plan` fails; owner merges origin/main.
- Python edits of STATUS/DECISIONS: open with encoding utf-8 (cp1252 mangles the dashes); keep line endings.
- Worktrees: owners reuse them for new branches; check `git worktree list` before saying one is stale.
- Next board PR needs: D-043 onward for new decisions; STATUS Dev Lead / Art rows (D-042 realistic proportions, density 56/84/112 open).
