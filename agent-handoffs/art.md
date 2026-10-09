# Art Factory handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Instructions come from the lead session ("Claude2: MERCS Lead" / "MERCS BOSS"). Director rule 2026-10-08:
every sheet goes to the Lead for QC first; only passing sheets reach the director (Lead presents).

## State: awaiting merge (publish PR); then walk + idle clips
## Task
P1-ART-PUBLISH-REST: publish the frozen average_m rest sheet (+ normal) at assets/sprites/mercs/average_m/ with a
provenance manifest and a licensing-register row, so slice M1 (#53) and the build show the real body.
## Branch and commit
claude/art-publish-rest from origin/main (after #52), worktree ../MERCS-wt/art-publish, PR (gh pr list).
## Files I own right now
assets/sprites/mercs/average_m/ (rest .json/.png/_normal.png/.provenance.json), docs/10_LICENSING_REGISTER.md
"Shipped assets" section.
## Unfinished changes
Next (Lead-approved plan, 2026-10-09): walk + idle sheets beside the rest sheet:
- clips: walk = D:\MERCS-vault\clips\mixamo\walk_standard.fbx, idle = idle_standing.fbx (sword-and-shield set kept for battle).
- 8 walk / 4 idle frames per facing, one loop; manifest keys "fps" (real timing, ~6.5 walk), "loop": true,
  "ground_speed_mps" (walk; planted-foot travel); rows = facings in rig order, columns = frames; frames[] entries carry
  "facing", "index" (facing index), "frame". Same cell 176 / pivot 88,152; normal + parts passes per frame.
- render_character.py: --clip/--frames; retarget = align rest dirs (X Bot T vs our A) then copy world orientation; store
  per-frame matrix_basis and rotate only our rig per facing; constant ground offset so the lowest contact = 0.
  pack_sheets.py multi-frame layout; validate_sheet multi-frame + a clip fixture. Probe: scratchpad retarget_probe.py.
- QC to Lead: 1x + x4 separate, plus a 3-second clip as frames (S, SE, E, N folders); checks: foot slide vs
  ground_speed, arm swing opposing legs, loop seam 7 -> 0. "Jogging" is a later optional clip (not now).
## Evidence so far
- #52 merged 2026-10-09 04:02 (freeze). Publish branch: assets 11, smoke 24 pass; lints 9/9; sheet validates; Godot imports it.
- The published sheet is byte-identical to tests/fixtures/pipeline/sheets/good (same pipeline and inputs).
## Open decisions
- Palette master_draft is DRAFT: the sheet is re-rendered when the director approves a palette.
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
