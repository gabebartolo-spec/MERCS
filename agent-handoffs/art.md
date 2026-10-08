# Art Factory handoff, 2026-10-08 22:00 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Instructions come from the lead session "Claude2: MERCS Lead" (director's standing order, 2026-10-08).

## State: awaiting merge (then average_f)
## Task
P1-ART-FREEZE-C55: freeze the director's pick (proportion C, 56 px, pitch 55) into the contract: camera_rig.json
(55 / 56 / cell 96 / pivot 48,80 / feet tolerance), tools/pipeline/proportions.json applied by default in
render_character.py, validator SHEET-NORMAL, good + bad fixtures re-rendered with normal strips, 06 section 3.
## Branch and commit
claude/art-freeze-c55 (stacked on claude/art-proportions = PR #28), worktree ../MERCS-wt/art-proportions,
draft PR (see `gh pr list`). No stacking (#27): when #28 merges, merge origin/main in, rerun suites, mark ready.
## Files I own right now
tools/pipeline/ (camera_rig.json, proportions.json, render_character.py, validate_sheet.py, test_pipeline.py),
tests/fixtures/pipeline/ (all), tests/run_stage_light_tests.gd (one check, lead-approved), docs/06_STYLE_ART.md section 3.
## Unfinished changes
None in the PR. After merge: tell the lead the new good fixture is on main (they make it the stage default merc).
Then average_f on the same skeleton and proportions.json (bodies.json entry, build_body.py, rig hash must match).
## Evidence so far
- Suites (SUITES_ONLY): data 88, smoke 24, stage 43, stage_scale 11, stage_light 8, all pass; lints 9/9; pipeline 15/15.
- Good fixture: measured extents at 55/56 = 64 px above pivot, 10 below, +-16 wide; validates clean.
- Capture: docs/audits/render_samples/freeze_p55_h56_rain_night_lit(.png, _crop.png), lit by the stage.
## Attempts (for the fix-loop rule)
- Normal pass 1: Blender's shader camera space has Z away from the viewer (B averaged 48). Fixed by negating Z.
- Sample cells 96 then 112 clipped at 64 px / 55; the frozen 56 px figure fits 96 with pivot 48,80.
## Open decisions
- Mixamo clips need the director's Adobe account (Art cannot sign in). Needed before sample set 1.
- Clips must not key bone scale (strip scale curves on import) or C's proportions are undone.
## Running jobs
None.
## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: always measure `evaluated_get(depsgraph)`, never `mesh.vertices`.
- `read_factory_settings` unloads MPFB; clear objects instead.
- Set `filepaths.save_version = 0` or Blender leaves `.blend1` backups beside assets.
- Only Merge & CI edits STATUS.md and DECISIONS.md (D-026): put state and decisions in the PR body.
- The body rig's origin is at hip height (z 0.82): refit height by measuring, then shift by the feet's z.
- Normal passes need view transform Raw and dither 0, or the data is tone-mapped and noisy.
- Director: mixels are an automatic fail; every image and view uses one texel size.
- Godot runs leave tools/lint/node_classes.gd.uid and .import churn: delete/revert before staging.
