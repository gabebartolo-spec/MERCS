# Dev Lead handoff, 2026-10-08 23:50 AEDT (cloud session, handing back to the desktop)
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), `docs/08_ROADMAP.md`
§Phase 1 only, `docs/specs/phase1_visual_proof.md`, and `docs/01_ENGINE_DECISION.md` "Rendering plan".
Then `gh pr list` and `docs/STATUS.md`. Run `git fetch` FIRST: this cloud session began from a desktop
snapshot 16 commits behind main and briefed two subagents on stale state (wasted, branches below).

## State: awaiting director
The director judged cloud mode too limited for MERCS: no Windows GPU and no Blender, it can push only
its own branch (`main-xlcsi2`), and it cannot reach the desktop agents. The Dev Lead seat moves back to
the desktop app. Cloud sessions are fine for bounded Linux jobs (suites, lints, small code).

## Director decisions this session (log them from #39's body)
- "Do what you think is best" / "work autonomously for the next hour": the director authorised the
  Dev Lead to pick and open the work below. No look decisions were made.
- Earlier decisions (pixel mode A, constant scale, proportion C, 56 px, 55°, testing cadence, mixels
  fail) are unchanged; see main's previous handoff in git history (bd074c2) and DECISIONS.md.

## PR #39 (branch `main-xlcsi2`, head 6888039 + this handoff): CI RED, do not merge yet
1. 3ffdaf4 + 9af9de8: `tools/capture/capture_stage.gd` defaults to the good fixture sheet (`--capsule`
   for the placeholder); default `--walk` 10 → 14 s so the merc is in view at 55°. CI green on 6979bef.
2. 6979bef: commits `tools/lint/node_classes.gd.uid` (it was regenerated untracked on every run).
3. a33e42f: **upright sprite depth.** Camera-facing sprites (#36) lean back by the pitch, so a merc
   0.2 m in front of the well lost everything above the shins. New `presentation/world/
   upright_sprite.gdshaderinc` + `_lit` / `_unlit.gdshader` (SheetFrame `lit_material()` /
   `unlit_material()`) keep the camera-facing quad but write depth as if the figure stood on the
   vertical plane through its feet. Lighting still reads the quad. Evidence (Linux, software GL):
   open ground, crossing mercs and behind-the-well captures are pixel-identical to main; front-of-well
   now shows the whole body; at night only one rain streak changes (now behind the arm).
   `stage_light` checks rewritten for the shaders, still 8. Sheet: `docs/audits/upright_depth/`.
4. **CI `test` failed on a33e42f** (run 37778851296, job 113316802693). Not yet diagnosed. Prime
   suspect: see "Import blocker" below. Locally (cloud, after import) all suites passed: data 88,
   smoke 24, stage 43, stage_scale 11, stage_light 8, assets 8; run_all.sh 9/9; gdformat/gdlint clean.
   First step on the desktop: read that job's log, reproduce, fix, push to #39 (or split part 3
   into its own `claude/` PR if cleaner; the director allowed either).

## Import blocker (needs a director or Art call)
Headless `--editor --import` hits `tools/pipeline/bodies/average_m.blend`, errors ("Blender path is
invalid ... headless mode") and imports NO PNGs: `.godot/imported` stays empty. Your PC has Blender set,
so it may never show there, but Linux CI does. Options: a `.gdignore` in `tools/pipeline/` (Art's folder:
ask Art), or `filesystem/import/blender/enabled=false` in project.godot (Dev's file; may need a decision
entry). Unproven fix: the test of the `.gdignore` idea was stopped by the director before it ran.

## Subagent branch `claude/p1-sheet-export-load` (d520808): reviewed, NOT merged
`SheetFrame._load_image()` loads imported res:// PNGs through ResourceLoader so sheets work from an
exported .pck (the gate is played in the build). Code is right. Its 3 new `assets` checks (floor 8 → 11)
build a real .pck with PCKPacker, but they FAIL on a fresh checkout because of the import blocker above.
Fix the import first, re-run, then open its PR. It also edits `sheet_frame.gd`; it merges cleanly with
#39's shader change.

## Open question for the director (asked, unanswered)
Should a merc pressed against a wall be lit where it actually stands (option D on the evidence sheet)?
D also shows the toes, which the ground currently cuts off (main too). Cost: lit mercs look slightly
different everywhere (legs brighter). No answer: the depth-only fix stays. The D shader is not committed;
it moves lighting to the upright point with `skip_vertex_transform` and picks the nearer of the figure
plane and the ground plane per corner.

## For other agents (in #39's Board and log)
- Merge & CI: delete the obsolete branches `claude/p1-crisp-snap` and `claude/p1-frame-time` (subagents
  briefed on stale main; superseded by #25 / D-031). The cloud proxy refused the delete.
- Art: publish the good sheet (average_m body rest, C/56/55, with normal map) under `assets/` with its
  licence row, so the stage itself can default to it in the build. Presentation may not reference
  `tests/` (layering lint), so the stage's default merc waits for this.

## Next for the Dev Lead, in order
1. #39 red CI (above). 2. Import blocker decision. 3. Export-load branch → PR. 4. After Art publishes:
stage default merc from `assets/`. 5. Street spec §6 occlusion/sorting fixture (now possible with #39).

## Worktrees
None from this session (cloud container). Desktop ones per STATUS.md.

## Rules learnt the hard way (keep under 10 lines)
- `git fetch` and read `git log origin/main` before choosing or briefing any work.
- Presentation code may not name a `tests/` path (layering.py), and data/balance takes numbers only.
- Sprite3D `material_override` must carry the texture itself; region UVs still come from the mesh.
- Pin a change to "pixel-identical where nothing should change": diff captures against main.
- Rain differs run to run outside the merc; compare the merc box, and recapture main twice to be sure.
- Sprite3D rebuilds its mesh and AABB on the next frame: `await process_frame` before measuring.
- Typed GDScript: assign a Variant to a typed local before `int()`/`float()`/casts or `is_equal_approx`.
- Commit the `.uid` of each new script or shader.
