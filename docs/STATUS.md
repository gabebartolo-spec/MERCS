# Status board

Cap: 150 lines. Owned by the Merge & CI agent; every agent updates its own row in the same PR
that changes its state. History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **0 — Foundation** (not started). Gate signer: Concept Lead.

## Agents

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| Dev Lead (Opus 5.5) | available | — | — | — |
| Merge & CI (Sonnet 5.5) | awaiting director | Phase 0 items 1 + 2 done; item 2 in PR #1; `test` requirement added after item 3 | claude/mercs-merge-ci-setup-83f2a5 | 2026-10-08 |
| Art Factory (Opus 5.5) | awaiting director | Phase 0 items 5, 6 done; PR review, empty Recycle Bin | claude/art-factory-setup-f074a4 | 2026-10-08 |
| Concept Lead (Fable 5.1) | available | Phase 0 gate review when items 1–7 land | — | 2026-10-08 |

States: working · running a check · awaiting director · blocked · available.

## Assigned items (in order; an item starts only when it is listed here)

### Phase 0
1. Merge & CI: branch protection (repo is already private and the pack is the first commit, done by the Concept Lead 2026-10-08).
2. Merge & CI: `.gitattributes`, `.gitignore`, PR template, `.github/workflows/lint.yml` with
   doc caps and gitleaks.
3. Dev Lead: `project.godot`, autoload shells, `data/schema/`, `tests/` scaffold, `tools/run_tests.sh`,
   `tests.yml` sharded CI, `build.yml`.
4. Dev Lead: lints `layering.py`, `magic_numbers.py`, `strings.py`, `content_counts.py`, `worktrees.sh`.
5. Art Factory: create `D:\MERCS-vault\`, repoint StabilityMatrix models root, update ComfyUI core,
   delete banned models and Realistic Vision (D-015), uninstall the four Unity editors via Unity
   Hub (D-015), write `tools/machine_profile.json`.
6. Art Factory: record Civitai permissions for the PENDING rows in `10_LICENSING_REGISTER.md`.
7. Dev Lead: `.claude/skills/` set and `agent-handoffs/` seeds.
8. Concept Lead: Phase 0 gate review (deliberately broken PR test).

## Waiting on the director
- Nothing. Q-BP answered 2026-10-08 (D-019: repo public, protection applied; `test` required once `tests.yml` exists, item 3).
- Q1, Q2, Q3, Q10, Q11, Q12 answered 2026-10-08 (D-010..D-015).

## Merge queue
(empty)

## GPU jobs
(none)

## LFS usage
0 / 10 GiB.

## Live worktrees
1 / 4 (claude/art-factory-setup-f074a4).
