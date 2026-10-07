# Status board

Cap: 150 lines. Owned by the Merge & CI agent; every agent updates its own row in the same PR
that changes its state. History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **0 — Foundation** (items 1–7 merged; gate run pending). Gate signer: Concept Lead.

## Agents

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| Dev Lead (Opus 5.5) | available | Phase 0 items 3, 4, 7 done, handed to Merge & CI | #4 claude/p0-scaffold, #5 claude/p0-lints, #6 claude/p0-skills | 2026-10-08 |
| Merge & CI (Sonnet 5.5) | awaiting director | Phase 0 items 1 + 2 done; item 2 in PR #1; `test` requirement added after item 3 | claude/mercs-merge-ci-setup-83f2a5 | 2026-10-08 |
| Art Factory (Opus 5.5) | available | Phase 0 items 5, 6 done (#3); waiting for the Phase 0 gate | — | 2026-10-08 |
| Concept Lead (Fable 5.1) | working | Phase 0 gate review; board and log after #2, #8 | claude/board-and-log | 2026-10-08 |

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
8. Dev Lead: gdlint + gdformat job in `lint.yml` with the limits from `05_STYLE_CODE.md`
   (400 lines per file, 40 per function, 4 parameters, complexity 12); move `text.gd` to
   `presentation/` when it is created.
9. Concept Lead: Phase 0 gate review (`docs/audits/phase0_gate_plan.md`).

### Phase 1 (assigned only after the Phase 0 gate is PASS)
- Art Factory: `assets.yml` (validators + Godot assets fixture + contact-sheet artefact).
- Dev Lead: Phase 1 LOW: lint precision gaps listed by PR #5.

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

## Logged for later (not assigned)
- Phase 1, LOW, lint precision (Concept Lead review of #5): `strings.py` flags names in
  `add_to_group`, `get_node` paths, `OS.get_name` and `$Anim.play`; `magic_numbers.py` accepts
  `-100` and `+1` and does not exempt `sim/core/rng.gd`; `layering.py` misses `Timer.new()`-style
  node construction in sim.
<!-- GATE-11 padding line 1 -->
<!-- GATE-11 padding line 2 -->
<!-- GATE-11 padding line 3 -->
<!-- GATE-11 padding line 4 -->
<!-- GATE-11 padding line 5 -->
<!-- GATE-11 padding line 6 -->
<!-- GATE-11 padding line 7 -->
<!-- GATE-11 padding line 8 -->
<!-- GATE-11 padding line 9 -->
<!-- GATE-11 padding line 10 -->
<!-- GATE-11 padding line 11 -->
<!-- GATE-11 padding line 12 -->
<!-- GATE-11 padding line 13 -->
<!-- GATE-11 padding line 14 -->
<!-- GATE-11 padding line 15 -->
<!-- GATE-11 padding line 16 -->
<!-- GATE-11 padding line 17 -->
<!-- GATE-11 padding line 18 -->
<!-- GATE-11 padding line 19 -->
<!-- GATE-11 padding line 20 -->
<!-- GATE-11 padding line 21 -->
<!-- GATE-11 padding line 22 -->
<!-- GATE-11 padding line 23 -->
<!-- GATE-11 padding line 24 -->
<!-- GATE-11 padding line 25 -->
<!-- GATE-11 padding line 26 -->
<!-- GATE-11 padding line 27 -->
<!-- GATE-11 padding line 28 -->
<!-- GATE-11 padding line 29 -->
<!-- GATE-11 padding line 30 -->
<!-- GATE-11 padding line 31 -->
<!-- GATE-11 padding line 32 -->
<!-- GATE-11 padding line 33 -->
<!-- GATE-11 padding line 34 -->
<!-- GATE-11 padding line 35 -->
<!-- GATE-11 padding line 36 -->
<!-- GATE-11 padding line 37 -->
<!-- GATE-11 padding line 38 -->
<!-- GATE-11 padding line 39 -->
<!-- GATE-11 padding line 40 -->
<!-- GATE-11 padding line 41 -->
<!-- GATE-11 padding line 42 -->
<!-- GATE-11 padding line 43 -->
<!-- GATE-11 padding line 44 -->
<!-- GATE-11 padding line 45 -->
<!-- GATE-11 padding line 46 -->
<!-- GATE-11 padding line 47 -->
<!-- GATE-11 padding line 48 -->
<!-- GATE-11 padding line 49 -->
<!-- GATE-11 padding line 50 -->
<!-- GATE-11 padding line 51 -->
<!-- GATE-11 padding line 52 -->
<!-- GATE-11 padding line 53 -->
<!-- GATE-11 padding line 54 -->
<!-- GATE-11 padding line 55 -->
<!-- GATE-11 padding line 56 -->
<!-- GATE-11 padding line 57 -->
<!-- GATE-11 padding line 58 -->
<!-- GATE-11 padding line 59 -->
<!-- GATE-11 padding line 60 -->
<!-- GATE-11 padding line 61 -->
<!-- GATE-11 padding line 62 -->
<!-- GATE-11 padding line 63 -->
<!-- GATE-11 padding line 64 -->
<!-- GATE-11 padding line 65 -->
<!-- GATE-11 padding line 66 -->
<!-- GATE-11 padding line 67 -->
<!-- GATE-11 padding line 68 -->
<!-- GATE-11 padding line 69 -->
<!-- GATE-11 padding line 70 -->
<!-- GATE-11 padding line 71 -->
<!-- GATE-11 padding line 72 -->
<!-- GATE-11 padding line 73 -->
<!-- GATE-11 padding line 74 -->
<!-- GATE-11 padding line 75 -->
<!-- GATE-11 padding line 76 -->
<!-- GATE-11 padding line 77 -->
<!-- GATE-11 padding line 78 -->
<!-- GATE-11 padding line 79 -->
<!-- GATE-11 padding line 80 -->
<!-- GATE-11 padding line 81 -->
<!-- GATE-11 padding line 82 -->
<!-- GATE-11 padding line 83 -->
<!-- GATE-11 padding line 84 -->
<!-- GATE-11 padding line 85 -->
<!-- GATE-11 padding line 86 -->
<!-- GATE-11 padding line 87 -->
<!-- GATE-11 padding line 88 -->
