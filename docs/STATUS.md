# Status board

Cap: 150 lines. Edited only by the Merge & CI agent, in a board PR after each merge, from the
merged PR's "Board and log" section (D-026, D-030). History rolls to `docs/archive/status_<month>.md`.

## Phase
Current phase: **4 (combat depth, D-091) and 5 (Contracts and the road) in progress; art in critic loops** (Phase 2 horizontal slice built and playtested, D-084; Phase 0 gate PASS WITH NOTES, D-027). Gate signer: Concept Lead.
Phase 4: merged P1a (#121, #126), P1b equipment physics (#127), P2 morale and surrender (#123), P4 deploy or delegate (#124), P5 non-psychic enemy (#122), P6b/P6c blood and hit-stop (#129, #133), XP (#125), levels (#120), Ledger typeface (#116). Open: P1c ranged and spear reach (in progress), P7 hover odds (not built).
Phase 5: plan #130; C0 economy facade (#132) and C4 reputation half (#134) merged; C3 wages (#135) merging; C1 and C2 (#136) in review.

## Agents

| Agent | State | Item | Branch / PR | Since |
|-------|-------|------|-------------|-------|
| Dev Lead (Opus 5.5) | working | Combat depth merged except P1c ranged (in progress); contracts C0, C3, C4 merged or merging, C1 and C2 in review; overnight team of builders (D-090) | claude/p4-p1c-ranged | 2026-10-16 |
| Merge & CI (Sonnet 5.5) | working | board PR after #134 (D-091..D-112) | docs/board-after-134 | 2026-10-16 |
| Art Factory (Opus 5.5) | working | cast fix #118 and tile boards (method B', D-106) in critic loops; palette PR (heather, water ramp, grey-olive) after SHIP | claude/tiles-b6, #118 | 2026-10-16 |
| Concept Lead (Fable 5.1) | available | roadmap rewrite DONE (#74); handoff #77 open | claude/concept-lead-handoff (#77) | 2026-10-15 |

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
4. (PAUSED under D-051) Art Factory: fourteen Mixamo clips to `D:\MERCS-vault\clips` (needs D-029 sign-in), then sample set 1 (pitch × height) and sample set 2 (pixel mode, palette, fonts) as labelled sheets per `docs/specs/phase1_visual_proof.md`.
5. Art Factory: `assets.yml` (validators + Godot assets fixture + contact-sheet artefact).
6. Dev Lead: Phase 1 LOW: lint precision gaps listed by PR #5; function-length and complexity project lint. DONE (#21).

7. Dev Lead: stage scale contract (texel = logical pixel, derived rail, sheet on stage). DONE (#24).
8. Dev Lead: sample set 2, pixel mode and depth scale (spec §4). DONE (#25; director answered, D-031, D-032).
9. Dev Lead: lit sprites (normal-mapped frames lit by scene lights, `stage_light` suite). DONE (#26).
10. Art Factory: P1-ART-PROPORTIONS, proportion samples and a normal pass sample. DONE (#28; director chose C, 56 px, 55 degrees: D-036..D-038).
11. Dev Lead: assets suite (`assets` suite, floor 8). DONE (#29).
12. Art Factory: P1-ART-FREEZE-C55, the look frozen into the rig. DONE (#34).
13. Dev Lead: stage defaults 55 degrees / 56 px (#31); crowd, occlusion and camera-facing sprites in the street. DONE (#36).

14. Art Factory: P1-ART-FREEZE-REALISTIC (realistic, 84 px, 45 degree sprites in the 55 degree world, #52); first published asset `average_m` rest sheet (#55). DONE.
15. Dev Lead: art direction slice (spec #51, D-043): M1 playable grey-box (#53), M2 walk/idle playback (#54), stage defaults at 84 px / 960x540 (#57). DONE. Next: M5 core-loop skeleton (M3, M4 and the gate still open).
16. Merge & CI: sprite sheets under `assets/sprites/` are plain git (#56, D-046). DONE.

17. Art Factory: P1-ART-REFOCUS, a written proposal (no renders) for making the hand-made cast: non-human builds, three stage looks per merc, bespoke gear lines, personal-detail variants for a returning playstyle, what of the current pipeline carries over, art cost for the slice and for 25 mercs; options with costs, to the director as a question; approval before any new art work. Assigned (D-051).
18. Concept Lead: roadmap rewrite for the hand-made cast and the horizontal-slice plan, plus Q15-Q22 recommendations. DONE (#74; D-048, D-063..D-071).
20. Art Factory: P1-ART-SLICE-CAST, the orc and the Vampyr at stage 1: clay, gait, geared sheets with the injury starter set (D-059..D-062). Assigned.
19. Merge & CI: vision revision (#63, D-047..D-058) merged; #61 superseded. DONE.

### Phase 2 (horizontal slice, D-064)
1. Milestone 1, map and world tick. DONE (#75).
2. Milestone 2, travel and encounters. DONE (#80). Director: playtest success (D-076).
3. Milestone 3, the cast and the company. DONE (#81); four mercs are placeholders.
4. Milestone 4, battle skeleton (order, intent, morale rout, blocking). DONE (#85).
5. Milestone 5, wounds, triage, death, chronicle, succession (sim). DONE (#82); wiring after M3/M4.
6. Milestone 6, wages, contracts, loot, hiring, the prisoner choice. DONE (#87).
7. Milestone 7, one storylet plus the memory system. DONE (#89).
Extras: lint magic numbers are errors (#79); `tools/merge_eligibility.sh` (#78); 4K display fix (#83); gdlint required (#84); letter keys replace function keys (#86); walkable overworld (#93, D-078); wiring (#90); campaign ends on a wipe (#98, D-083); gate pack (#97, `docs/audits/phase2_gate/README.md`); gate gaps (#101); Ironman (#103, D-087, merged). Full-loop playtest passed (D-084).
Art: look target B "Peat and Ochre" locked (#100, D-085); palette = core + biome sets (D-086). Terrain tiles: method B' Claude-painted (D-106), boards in critic loops; art that passes the critics is wired in (D-111).

## Waiting on the director
- Pick mercs 3-6 from `MERCS-builds/merc_candidates_2026-10-16.md` (12 drafts, D-111); name the bargaining trait per merc (D-110 Q-8).
- The overworld golden before and after (grass remap, #118 r4); cast look after critic SHIP; tile board after SHIP.
- A dead merc's unpaid wages: paid with the whole debt (current) or forfeited?
- Balance flag (#127): with placeholder plate the Vampyr never falls over seeds 424200-426400; target is a named death per 4 fights (D-110); tune after his playtest.
- Author `merc_3` to `merc_6` (#81), the six recruits, the two factions and the generic items (#87); placeholders stand until then.
- Confirm or reorder milestones 3 and 4 (both built).
- Veto lists: #80, #81, #82, #85, #87 (calls in each PR body); `caps.json` gains `encounters`, `equipment`, `factions`, `recruits`, `scenarios`.
- The Phase 2 gate playthrough (`docs/audits/phase2_gate/README.md`).
- Tripo threshold (D-060): confirm 500 -> 2,000 credits per session in writing; 500 stands.
- Mixamo: 10 of 14 clips are in the vault; the rest wait on his sign-in (D-029).
- Allow or decline deleting superseded remote branches `claude/p1-crisp-snap`, `claude/p1-frame-time`, `claude/p1-sheet-export-load`.

## Merge queue
#77 open (Concept Lead handoff, docs). #118 cast (critic loop). #135 C3, #136 C2 (review). P1c in progress.

## GPU jobs
(none)

## LFS usage
0 / 10 GiB.

## Live worktrees
Check `bash tools/lint/worktrees.sh`; limit 4 (D-021).

## Logged for later (not assigned)
- Phase 1, LOW, lint precision (Concept Lead review of #5): `strings.py` flags names in
  `add_to_group`, `get_node` paths, `OS.get_name` and `$Anim.play`; `magic_numbers.py` accepts
  `-100` and `+1` and does not exempt `sim/core/rng.gd`; `layering.py` misses `Timer.new()`-style
  node construction in sim.
- Look direction (director, 2026-10-08, NOT a ruling): mercs read like Pokémon Black/White trainer sprites with more detail and slightly bigger; steep top-down 3/4 camera (about 50-60 degrees), big-headed short figures, dense detailed pixel environments; grim Westeros setting. `06_STYLE_ART.md` and spec §3's 30-40 degree pitch range need revisiting from the proportion samples (#28).
- QC defect (Lead, on #39's evidence sheet): sprite lean at 55 degrees. #39's option B fixes the main bug (a merc 0.2 m in front of the well lost everything above the shins) but the merc then draws nearly black, because lighting still reads the leaning quad inside the well's shadow. The Dev Lead's follow-up moves lighting to the upright point (option D), which also stops the ground cutting off the toes. #39's `dev_lead.md` "awaiting director" state is superseded.
- Art Factory request (from #39, needs assigning): publish the good sheet (average_m body rest, C/56/55, with its normal map) under `assets/` with its licensing-register row, so the stage can default to it in the build.
- Merge & CI: `claude/p1-crisp-snap` and `claude/p1-frame-time` (unmerged, no PR, superseded by #25 and D-031) were to be deleted; the delete was refused by the permission classifier, so they stay until the director allows it. Tips for recovery if ever wanted: 664434c, 7236cdc.
