# Art Factory handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Instructions come from the lead session ("Claude2: MERCS Lead" / "MERCS BOSS"). Director rule 2026-10-08:
every sheet goes to the Lead for QC first; only passing sheets reach the director (Lead presents).

## State: paused (director, 2026-10-09): realistic QC round 2 fixes + 84 px @45 deg sample pending
Start nothing new until the Lead or director resumes Art. Work is local on claude/art-qc-c55; do not push or open a PR.
## Task
Director 2026-10-09: proportion C DROPPED; realistic proportions, more pixels per merc. Samples for the Lead's QC
(then the director): realistic average_m rest, pitch 55, at 56 / 84 / 112 px, plus 84 px rendered at sprite pitch 45.
## Branch and commit
claude/art-qc-c55, worktree ../MERCS-wt/art-qc, local commits only (last: this handoff). Not pushed, no PR.
## Files I own right now
tools/pipeline/ (build_body.py, bodies/bodies.json + average_m.blend, rig_contract.json, render_character.py,
pixelate.py/.json, contact_sheet.py); docs/audits/realistic_density/ (config/, sheets/, review PNGs = round-1 samples).
tools/pipeline/proportions.json still holds C (shared default); replace only on a director pick.
## Unfinished changes (Lead QC round 3 on the realistic samples, 2026-10-09)
DONE, not yet rendered or checked:
- (1) shoulders: clavicles ~6 deg lower (sample config); bodies.json contour adds shoulder-muscle-decr 0.4 L/R,
  torso-muscle-dorsi-decr 0.4, neck-scale-vert-incr 0.3; body rebuilt: rig hash 17b2aa42 unchanged,
  height_after_contour 1.7959 (render refits to 1.78).
- (2) arms close, elbows slightly back, hands + every finger aimed down (fingers together), thumbs along index
  (docs/audits/realistic_density/config/proportions_realistic.json). New bone_twist_deg (render_character.py
  twist_bones): hand roll is 0 for now; measure palm direction in a 0 deg side render, then set it so palms face thighs.
- (3) parts pass: arm vertices within 0.10 m of the shoulder joint count as body (no seam at the arm root).
- (4) legs straight, ankles ~0.12 m apart, toes out 13 deg.  (5) buttocks 0.3.
TO DO on resume:
1. Render realistic at 0 deg side-on (camera from scratch cam_side: pitch 0, 96 cell, pivot 48,88, height 72);
   check hands/palms (set bone_twist_deg), feet (E/W far toes not a stub), shoulders, neck sliver in S.
2. Re-render h56/h84/h112 (color, normal, parts), pixelate with --parts, pack with --stem, validate --camera=,
   contact sheets with --camera (1x and x4 as separate files).
3. Item 6: 84 px at sprite pitch 45 with the SAME px_per_m as 55/84: char_height_px = 84*cos45/cos55 = 103.55,
   cell ~176, pivot ~(88,152); Lead captures it with --pitch=55 --height=84. Label it.
4. Send the Lead the paths (1x and x4 per density + the 45 deg sample), self-review first (art-qa-critic).
## Evidence so far
- Round 1 realistic samples validate; Lead confirmed engine path (#44 --logical capture), no mixels, mud gone.
- Lead round 3 defects: gorilla shoulders/head sunk; claw hands, flared elbows; deltoid seam lines; far foot reads
  kicked back (NE/NW) and toe stub (E/W).
- test_pipeline rebuild fails until fixtures are regenerated after a pick (expected).
## Open decisions
- Director (via Lead): density 56 / 84 / 112; sprite pitch 55 vs 45 in a 55 deg world; placeholder head/hair layer.
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
