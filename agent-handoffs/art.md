# Art Factory handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Instructions come from the lead session ("Claude2: MERCS Lead" / "MERCS BOSS"). Director rule 2026-10-08:
every sheet goes to the Lead for QC first; only passing sheets reach the director (Lead presents).

## State: awaiting Lead QC
## Task
P1-ART-QC-C55: fix the Lead's six QC points on the frozen C/56/55 average_m rest sheet, then (#39) publish
the passing sheet + normal map under assets/ with its licensing-register row so the stage build can use it.
## Branch and commit
claude/art-qc-c55 (from main after #34/#36/#37), worktree ../MERCS-wt/art-qc, local WIP commit, not pushed, no PR yet.
## Files I own right now
tools/pipeline/ (proportions.json, render_character.py recentre_bones, pixelate.py despeckle + outline,
pixelate.json, contact_sheet.py label), docs/audits/qc_c55/ (review images sent to the Lead).
## Unfinished changes
On a Lead pass: regenerate tests/fixtures/pipeline (render_4x, render_4x_normal, sheets/good, make_bad_sheets.py),
contact sheet in docs/audits/render_samples, run test_pipeline + SUITES_ONLY + lints + one capture, publish under
assets/characters/ (manifest, strip, normal, provenance) + register row, PR with Board and log. Drop docs/audits/qc_c55/sheet.
## Evidence so far
- Measured: feet planted (ankle z equal, knees 6.4 deg both); stance was 0.37 m wide -> far foot 16 px higher at 55.
- Side-on 0 deg render: full recentre put the head behind the spine and tore the neck; keep_offset 1/1.8 + 1.5 cm lift fixed it.
- QC sheet validates clean; rig_scale 0.9756, height 1.7800.
## Attempts (for the fix-loop rule)
- Head forward: (1) recentre centroid onto neck = over-corrected; (2) neck aim upright = no visible change. Then
  gathered side-on evidence; (3) partial recentre keep_offset 1/1.8 = correct.
## Open decisions
- Lead/director: fuller torso (MPFB body-shape targets) for the side views; placeholder head/hair layer (Lead asks the director).
- Interior outline lines (06 "inner-line where the silhouette would merge") not implemented.
## Running jobs
None. Mixamo: 10 clips in D:\MERCS-vault\clips\mixamo\ with SOURCES.md (director's yes 2026-10-08); not yet retargeted.
## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: always measure `evaluated_get(depsgraph)`, never `mesh.vertices`.
- `read_factory_settings` unloads MPFB; clear objects instead. Set `filepaths.save_version = 0`.
- Only Merge & CI edits STATUS.md and DECISIONS.md (D-026): put state and decisions in the PR body.
- Normal passes need view transform Raw and dither 0, or the data is tone-mapped and noisy.
- Director: mixels are an automatic fail; every image and view uses one texel size; send 1x and 4x as separate files.
- Godot runs leave tools/lint/node_classes.gd.uid and .import churn: delete/revert before staging.
- A child pose bone inherits its parent's scale: compensate (hands 1.3/0.85).
- Judge a pose fix side-on at 0 degrees before the 55-degree sprite; the steep view hides over-correction.
- Mixamo export links expire in 300 s and the monitor can return the previous job: export one clip per call and download at once.
