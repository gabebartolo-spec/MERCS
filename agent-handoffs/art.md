# Art Factory handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Instructions come from the lead session ("Claude2: MERCS Lead" / "MERCS BOSS"). Director rule 2026-10-08:
every sheet goes to the Lead for QC first; only passing sheets reach the director (Lead presents).

## State: awaiting Lead QC
## Task
Director 2026-10-09: proportion C (big head) DROPPED; realistic proportions, "4k" = more pixels per merc.
P1-ART-REALISTIC-DENSITY: realistic average_m rest at pitch 55 in three densities (56 / 84 / 112 px), with the
round-2 general fixes, as samples for the Lead's 4K street QC, then the director.
## Branch and commit
claude/art-qc-c55, worktree ../MERCS-wt/art-qc, local commits only, not pushed, no PR. Samples are local files.
## Files I own right now
tools/pipeline/ (build_body.py contour after rig hash; bodies.json contour_targets; average_m.blend rebuilt, rig hash
unchanged 17b2aa42; render_character.py parts pass + recentre; pixelate.py despeckle clusters, outline, inner lines,
skin-only body quantise; contact_sheet.py --camera + label); docs/audits/realistic_density/ (config, sheets, review).
tools/pipeline/proportions.json still holds C (the shared default); replace with realistic only on a director pick.
## Unfinished changes
After the Lead/director pick a density (and maybe sprite pitch): camera_rig.json + proportions.json to the pick,
regenerate tests/fixtures/pipeline (render_4x, _normal, NEW render_4x_parts for the rebuild test, sheets/good,
make_bad_sheets.py), suites, capture, then #39: publish under assets/ with a register row. PR with Board and log.
docs/audits/qc_c55/ is obsolete C evidence: delete before the PR.
## Evidence so far
- build_body --check with contour targets: RIG_CONTRACT_OK, height 1.7798 unchanged.
- Stance measured: ankles 0.208 m, knees 4.1 deg, toes out 8 deg. Mud source: body quantised to soot (grey); now skin only.
- Realistic side-on 0 deg: upright natural posture; the 55 deg "hunch" is camera foreshortening, raised to the Lead.
- test_pipeline rebuild fails until fixtures are regenerated (expected; outline/despeckle change output).
## Attempts (for the fix-loop rule)
- C head: recentre full = over-correct; neck aim = no change; keep_offset 1/1.8 = correct (C now dropped).
## Open decisions
- Lead/director: density 56 / 84 / 112; accept 55 deg head foreshortening or shallower sprite pitch; buttocks 0.5 vs 0.3.
- Placeholder head/hair layer (Lead asks the director).
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
