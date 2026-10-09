# Art Factory handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Instructions come from the lead session ("Claude2: MERCS Lead" / "MERCS BOSS"). Director rule 2026-10-08:
every sheet goes to the Lead for QC first; only passing sheets reach the director (Lead presents).

## State: awaiting merge (freeze PR), then publish + walk/idle
## Task
P1-ART-FREEZE-REALISTIC: freeze the director's pick (2026-10-09): realistic proportions, density B = 84 px in the
55-degree world, sprites rendered at 45 degrees (D). camera_rig.json pins the scale (px_per_m_1x 82.275), proportions.json
realistic, fixtures re-rendered (colour, normal, NEW parts), 06 section 3.
## Branch and commit
claude/art-freeze-realistic (from claude/art-qc-c55 + origin/main merged), worktree ../MERCS-wt/art-qc, PR (gh pr list).
## Files I own right now
tools/pipeline/ (camera_rig.json, proportions.json, render_character.py, pixelate.py/.json, build_body.py, bodies/,
contact_sheet.py, test_pipeline.py), tests/fixtures/pipeline/ (render_4x, render_4x_normal, render_4x_parts, sheets/),
docs/06_STYLE_ART.md section 3, docs/audits/realistic_density/ (the pick's evidence), docs/audits/freeze_realistic/.
## Unfinished changes
After the freeze merges (Lead order):
1. Publish average_m rest + normal at assets/sprites/mercs/average_m/average_m_body_rest.json (+ .png, _normal.png)
   with provenance and its licensing-register row (#39; the slice game M1 loads exactly that path).
2. Walk and idle clips from D:\MERCS-vault\clips\mixamo\ (walk_standard / walk_sns, idle_standing / idle_sns):
   retarget = align rest directions (X Bot T-pose vs our A-pose) then copy world orientation; COMPOSE the facing turn with
   the FBX object's own rotation; fix the ~4 cm foot dip (hip height). Probe: scratchpad retarget_probe.py. Publish as
   average_m_body_walk.json / _idle.json beside the rest sheet. Lead QC before the director.
3. Then: three equipment looks + eye-patch, modular street kit, battle clips (spec PR #51 docs/specs/art_direction_slice.md).
## Evidence so far
- Suites: data 88, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 11 all pass; lints 9/9; pipeline 15/15.
- Fixture vs the picked sample: 21 of 19034 px differ (sample's height was rounded to 103.56; rig uses the exact formula).
- Capture at logical 960x540: docs/audits/freeze_realistic/street_p55_h84_rain_night_lit.png.
- Mixamo retarget probe: walk plays correctly side-on and front (all 52 bones, no scale keys).
## Open decisions
- Placeholder head/hair layer (Lead asks the director).
## Running jobs
None.
## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: always measure `evaluated_get(depsgraph)`, never `mesh.vertices`.
- `read_factory_settings` unloads MPFB; clear objects instead. Set `filepaths.save_version = 0`.
- Only Merge & CI edits STATUS.md and DECISIONS.md (D-026): put state and decisions in the PR body.
- Normal passes need view transform Raw and dither 0, or the data is tone-mapped and noisy.
- Director: mixels are an automatic fail; every image and view uses one texel size; send 1x and 4x as separate files.
- Godot runs leave .import churn: revert tracked, git clean -- '*.png.import'. node_classes.gd.uid is TRACKED now: never delete it.
- A child pose bone inherits its parent's scale: compensate (hands 1.3/0.85).
- Judge a pose fix side-on at 0 degrees before the 55-degree sprite; the steep view hides over-correction.
- Mixamo export links expire in 300 s and the monitor can return the previous job: export one clip per call and download at once.
