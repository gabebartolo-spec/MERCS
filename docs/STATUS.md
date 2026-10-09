# Status board

Cap: 150 lines. Edited only by the Merge & CI agent, in a board PR after each merge, from the
merged PR's "Board and log" section (D-026, D-030). History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **1 — Visual and factory proof** (Phase 0 gate PASS WITH NOTES, D-027; every Phase 0 item merged). Gate signer: Concept Lead.

## Agents

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| Dev Lead (Opus 5.5) | working | capture density support, `--logical=WxH` (#44); next: QC Art's realistic samples, then the director's density pick; sheets load from an exported .pck (export-load PR, the Lead's `claude/p1-sheet-export-load`, do not prune) | — | 2026-10-09 |
| Merge & CI (Sonnet 5.5) | working | standing merge pass (D-030); board PR after each merge | — | 2026-10-08 |
| Art Factory (Opus 5.5) | working (local; no PR until the density pick) | P1-ART-PROPORTIONS (#28) and P1-ART-FREEZE-C55 (#34) merged; proportion C reversed (D-042): realistic density samples at 56 / 84 / 112 px, QC with the Lead; Mixamo clips need the director's sign-in (D-029) | — | 2026-10-09 |
| Concept Lead (Fable 5.1) | awaiting director | handoff refreshed (#47); Project Architect adoption | — | 2026-10-09 |

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

7. Dev Lead: stage scale contract (texel = logical pixel, derived rail, sheet on stage). DONE (#24).
8. Dev Lead: sample set 2, pixel mode and depth scale (spec §4). DONE (#25; director answered, D-031, D-032).
9. Dev Lead: lit sprites (normal-mapped frames lit by scene lights, `stage_light` suite). DONE (#26).
10. Art Factory: P1-ART-PROPORTIONS, proportion samples and a normal pass sample. DONE (#28; director chose C, 56 px, 55 degrees: D-036..D-038).
11. Dev Lead: assets suite (`assets` suite, floor 8). DONE (#29).
12. Art Factory: P1-ART-FREEZE-C55, the look frozen into the rig. DONE (#34).
13. Dev Lead: stage defaults 55 degrees / 56 px (#31); crowd, occlusion and camera-facing sprites in the street. DONE (#36).

## Waiting on the director
- The density pick (56 / 84 / 112 px) from Art's realistic samples once the Lead has QC'd them (D-042). Art works locally and opens no PR until then.
- Project Architect adoption (Concept Lead handoff).
- Mixamo: 10 of 14 clips are in the vault (D-029 sign-in); the rest wait on the director's sign-in.
- Allow or decline deleting the unmerged, superseded remote branches `claude/p1-crisp-snap` (664434c) and `claude/p1-frame-time` (7236cdc); the permission classifier refused it.

## Merge queue
(empty)

## GPU jobs
(none)

## LFS usage
0 / 10 GiB.

## Live worktrees
4 / 4: `.claude/worktrees/dual-desktop-instances-a78d20`, `../MERCS-wt/art-proportions` (branch claude/art-freeze-c55), `../MERCS-wt/p1-stage-scale` (branch claude/p1-stage-55), `../MERCS-wt/board2` (this board PR).

## Logged for later (not assigned)
- Phase 1, LOW, lint precision (Concept Lead review of #5): `strings.py` flags names in
  `add_to_group`, `get_node` paths, `OS.get_name` and `$Anim.play`; `magic_numbers.py` accepts
  `-100` and `+1` and does not exempt `sim/core/rng.gd`; `layering.py` misses `Timer.new()`-style
  node construction in sim.
- Look direction (director, 2026-10-08, NOT a ruling): mercs read like Pokémon Black/White trainer sprites with more detail and slightly bigger; steep top-down 3/4 camera (about 50-60 degrees), big-headed short figures, dense detailed pixel environments; grim Westeros setting. `06_STYLE_ART.md` and spec §3's 30-40 degree pitch range need revisiting from the proportion samples (#28).
- QC defect (Lead, on #39's evidence sheet): sprite lean at 55 degrees. #39's option B fixes the main bug (a merc 0.2 m in front of the well lost everything above the shins) but the merc then draws nearly black, because lighting still reads the leaning quad inside the well's shadow. The Dev Lead's follow-up moves lighting to the upright point (option D), which also stops the ground cutting off the toes. #39's `dev_lead.md` "awaiting director" state is superseded.
- Art Factory request (from #39, needs assigning): publish the good sheet (average_m body rest, C/56/55, with its normal map) under `assets/` with its licensing-register row, so the stage can default to it in the build.
- Merge & CI: `claude/p1-crisp-snap` and `claude/p1-frame-time` (unmerged, no PR, superseded by #25 and D-031) were to be deleted; the delete was refused by the permission classifier, so they stay until the director allows it. Tips for recovery if ever wanted: 664434c, 7236cdc.
