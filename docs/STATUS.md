# Status board

Cap: 150 lines. Edited only by the Merge & CI agent, in a board PR after each merge, from the
merged PR's "Board and log" section (D-026, D-030). History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **1 — Visual and factory proof** (Phase 0 gate PASS WITH NOTES, D-027; every Phase 0 item merged). Gate signer: Concept Lead.

## Agents

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| Dev Lead (Opus 5.5) | available | Phase 1 item 6 lints merged (#21); next: assigned by the Concept Lead | — | 2026-10-08 |
| Merge & CI (Sonnet 5.5) | working | standing merge pass (D-030); board PR after each merge | — | 2026-10-08 |
| Art Factory (Opus 5.5) | awaiting director | Phase 1 item 3 render pipeline skeleton merged (#22): look approval on draft palette, rim light and pivot row 56; item 1 rig freeze merged (#13); Mixamo clips need the director's sign-in (D-029); sample set 1 waits on the grey-box street (#19) | — | 2026-10-08 |
| Concept Lead (Fable 5.1) | available | merge workflow audit merged (#20, D-028..D-030); render pipeline skeleton merged (#22); next: Phase 1 sample review | — | 2026-10-08 |

States: working · running a check · awaiting director · blocked · available.

## Assigned items (in order; an item starts only when it is listed here)

### Phase 0
1. Merge & CI: branch protection. DONE (D-019).
2. Merge & CI: `.gitattributes`, `.gitignore`, PR template, `lint.yml` with doc caps and gitleaks. DONE (#1).
3. Dev Lead: `project.godot`, autoloads, schemas, `tests/` scaffold, `run_tests.sh`, `tests.yml`, `build.yml`. DONE (#4).
4. Dev Lead: lints `layering.py`, `magic_numbers.py`, `strings.py`, `content_counts.py`, `worktrees.sh`. DONE (#5).
5. Art Factory: create `D:\MERCS-vault\`, repoint StabilityMatrix models root, update ComfyUI core,
   delete banned models and Realistic Vision (D-015), uninstall the four Unity editors via Unity
   Hub (D-015), write `tools/machine_profile.json`. DONE (#3, #8).
6. Art Factory: record Civitai permissions for the PENDING rows in `10_LICENSING_REGISTER.md`. DONE (#3).
7. Dev Lead: `.claude/skills/` set and `agent-handoffs/` seeds. DONE (#6).
8. Dev Lead: gdlint + gdformat job in `lint.yml` with the limits from `05_STYLE_CODE.md`
   (400 lines per file, 40 per function, 4 parameters, complexity 12); move `text.gd` to
   `presentation/` when it is created. DONE (#16).
9. Concept Lead: Phase 0 gate review. DONE (D-027, `docs/audits/phase0_gate_result.md`).
10. Dev Lead: `tests.yml` fails if any floor in `tests/expected_checks.txt` is lower than on `main` (gate gap #12). DONE (#17).
11. Dev Lead: re-test gitleaks with a non-allowlisted fake secret; add a custom rule if missed (gate gap #13). Make `build.yml`'s windows job depend on `test`; reword the harness self-test failure message. DONE (#17, #18 proof).
12. Dev Lead: `tools/lint/no_weights.py` fails on any `.safetensors`/`.ckpt`/`.gguf`/`.pth` tracked in the repo, wired into `project-lints` (gate gap #14). DONE (#15).

### Phase 1 (gate PASS WITH NOTES, D-027)
1. Art Factory: rig freeze (`average_m`, Mixamo skeleton, sockets, contract hash). DONE (#13).
2. Dev Lead: grey-box street capture stage, stage suite, capture tool. DONE (#19).
3. Concept Lead (subagent): render pipeline skeleton (camera/light rigs, render, pixelate, palette draft, pack, validators). DONE (#22).
4. Art Factory: fourteen Mixamo clips to `D:\MERCS-vault\clips` (needs D-029 sign-in), then sample set 1 (pitch × height) and sample set 2 (pixel mode, palette, fonts) as labelled sheets per `docs/specs/phase1_visual_proof.md`.
5. Art Factory: `assets.yml` (validators + Godot assets fixture + contact-sheet artefact).
6. Dev Lead: Phase 1 LOW: lint precision gaps listed by PR #5; function-length and complexity project lint. DONE (#21).

## Waiting on the director
- Sign in to mixamo.com in a browser the Art chat can use, so the fourteen clips can be downloaded (D-029).
- Restart the Merge & CI chat in the repo folder with the one-line kickoff in `agent-briefs/KICKOFF_PROMPTS.md` once this PR merges, so the new `.claude/settings.json` and brief load.

## Merge queue
(empty)

## GPU jobs
(none)

## LFS usage
0 / 10 GiB.

## Live worktrees
2 / 4: `.claude/worktrees/mercs-dev-lead-setup-0b99b1` (PR #4 merged, stale: prune), `.claude/worktrees/mercs-github-issue-21b87e` (Merge & CI).

## Logged for later (not assigned)
- Phase 1, LOW, lint precision (Concept Lead review of #5): `strings.py` flags names in
  `add_to_group`, `get_node` paths, `OS.get_name` and `$Anim.play`; `magic_numbers.py` accepts
  `-100` and `+1` and does not exempt `sim/core/rng.gd`; `layering.py` misses `Timer.new()`-style
  node construction in sim.
