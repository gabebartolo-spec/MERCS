# Art Factory handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Instructions come from the lead session ("Claude2: MERCS Lead" / "MERCS BOSS"). Director rule 2026-10-08:
every sheet goes to the Lead for QC first; only passing sheets reach the director (Lead presents).

## State: awaiting Lead QC (realistic round 3 samples sent 2026-10-09)
## Task
Director 2026-10-09: proportion C DROPPED; realistic proportions, more pixels per merc. Samples for the Lead's QC
(then the director): realistic average_m rest at pitch 55 in 56 / 84 / 112 px, plus 84 px at sprite pitch 45 with
the same px_per_m (103.56 px tall) for the director's sprite-pitch question.
## Branch and commit
claude/art-qc-c55, worktree ../MERCS-wt/art-qc, local commits only. Not pushed, no PR until the director picks.
## Files I own right now
tools/pipeline/ (build_body.py contour after rig hash; bodies.json; average_m.blend; rig_contract.json;
render_character.py parts pass with root label, recentre, twist; pixelate.py despeckle/outline/inner lines with root;
pixelate.json skin-only body; contact_sheet.py --camera); docs/audits/realistic_density/ (config/, sheets/, PNGs).
tools/pipeline/proportions.json still holds C (shared default); replace only on a director pick.
## Unfinished changes
Waiting on Lead QC, then the director's two picks (density; sprite pitch 55 vs 45). After the picks:
camera_rig.json + proportions.json (realistic pose from config/proportions_realistic.json), regenerate
tests/fixtures/pipeline (render_4x, _normal, NEW render_4x_parts in the rebuild test, sheets/good, make_bad_sheets.py),
suites + lints + one capture, #39 publish under assets/ with a register row, PR with Board and log.
Delete docs/audits/qc_c55/ (obsolete C evidence) before the PR.
## Evidence so far
- Round 3: four sheets validate; 0 deg side render: upright, palms face thighs, fingers together, feet natural.
- Root-seam fix verified at x8 with label map (only vertical inner-arm lines remain).
- build_body --check: RIG_CONTRACT_OK (17b2aa42) with contour + shoulder/neck targets.
- test_pipeline rebuild fails until fixtures are regenerated after a pick (expected).
## Attempts (for the fix-loop rule)
- Root seam: (1) shoulder cap labelled body = tick across the arm; (2) separate root label = fixed.
## Open decisions
- Director (via Lead): density 56 / 84 / 112; sprite pitch 55 vs 45; placeholder head/hair layer; softer elbows?
## Running jobs
None. Mixamo: 10 clips in D:\MERCS-vault\clips\mixamo\ with SOURCES.md; not yet retargeted.
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
