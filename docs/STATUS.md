# Status board

Cap: 150 lines. Owned by the Merge & CI agent; every agent updates its own row in the same PR
that changes its state. History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **0 — Foundation** (gate PASS WITH NOTES, D-027; items 8, 10–12 open). Gate signer: Concept Lead.

## Agents

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| Dev Lead (Opus 5.5) | available | Phase 0 items 8, 10, 11, 12, then Phase 1 grey-box street | — | 2026-10-08 |
| Merge & CI (Sonnet 5.5) | awaiting director | Phase 0 items 1 + 2 done; item 2 in PR #1; `test` requirement added after item 3 | claude/mercs-merge-ci-setup-83f2a5 | 2026-10-08 |
| Art Factory (Opus 5.5) | available | Phase 1 item 1: rig freeze, then sample sets (docs/specs/phase1_visual_proof.md) | — | 2026-10-08 |
| Concept Lead (Fable 5.1) | available | Phase 0 gate signed (D-027); next: Phase 1 sample review | — | 2026-10-08 |

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
9. Concept Lead: Phase 0 gate review. DONE (D-027, `docs/audits/phase0_gate_result.md`).
10. Dev Lead: `tests.yml` fails if any floor in `tests/expected_checks.txt` is lower than on `main` (gate gap #12).
11. Dev Lead: re-test gitleaks with a non-allowlisted fake secret; add a custom rule if missed (gate gap #13). Make `build.yml`'s windows job depend on `test`; reword the harness self-test failure message.
12. Dev Lead: `tools/lint/no_weights.py` fails on any `.safetensors`/`.ckpt`/`.gguf`/`.pth` tracked in the repo, wired into `project-lints` (gate gap #14).

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
