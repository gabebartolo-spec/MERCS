# Art Factory handoff, 2026-10-08 20:30 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Instructions come from the lead session "Claude2: MERCS Lead" (director's standing order, 2026-10-08).

## State: awaiting director
## Task
P1-ART-PROPORTIONS: average_m rest pose in three proportions (A realistic, B heroic, C B/W-like, D 3.5 heads) at
48/56/64 px and pitch 35/55, plus a lit-sprite normal pass (C, 56 px, both pitches) for the stage.
## Branch and commit
claude/art-proportions, worktree ../MERCS-wt/art-proportions, PR (see `gh pr list`).
## Files I own right now
`tools/pipeline/samples/` (proportions.json, proportion_samples.py), `docs/audits/proportion_samples/`,
and the sample options in render_character.py, pixelate.py (--normals), pack_sheets.py (--camera,
--normal-dir, --stem), validate_sheet.py (--camera=), contact_sheet.py (single texel size, 1x strip separate). Defaults are unchanged (self-test rebuild is byte-identical).
## Unfinished changes
None in the PR. Waiting on: the director's answers (proportion, size, pitch) and the lead's stage
captures at both pitches. After the answers: fold the chosen bone scales into a body build (not a
sample), redo the frame/pivot and validator feet tolerance for the chosen pitch, then average_f.
## Evidence so far
- 18 colour sheets + 2 normal strips, mercs.sheet/1. 35 degrees: 9/9 validate. 55 degrees: only SHEET-PIVOT
  (toes 14 px below pivot; the 7 px tolerance is 35-degree only, retune after the pitch decision).
- Director rule 2026-10-08: mixels = automatic fail. Review sheets and contact_sheet.py now draw text at the art's zoom.
- Normal axes measured on the 4x render: screen-right side R > 128, head top G > 128, B > 128 overall.
- 4x renders and the batch log are in the vault: D:\MERCS-vault\renders\proportions_2026-10-08\, logs\.
## Attempts (for the fix-loop rule)
- Normal pass 1: Blender's shader camera space has Z away from the viewer (B averaged 48). Fixed by negating Z.
- Cell 96, then 112: hands, then toes clipped at 64 px / 55 degrees. Samples use 128x128, pivot 64,108.
- Frozen rest pose (A-pose) reads as a hunch at 55 degrees; samples aim arms and forearms down (pose, not rig).
## Open decisions
- Director answered 2026-10-08: figure 56 px, pitch 55 degrees, proportion 'C pushed further' -> D (3.5 heads)
  rendered; asked C vs D. After the pick: rig camera to 55/56, body build with the bone scales, retune validator.
- Mixamo clips need the director's Adobe account (Art cannot sign in). Needed before sample set 1.
- Pose-bone scale must survive clips: strip scale curves on clip import, or apply the scale after the action.
## Running jobs
None.
## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: always measure `evaluated_get(depsgraph)`, never `mesh.vertices`.
- `read_factory_settings` unloads MPFB; clear objects instead.
- Set `filepaths.save_version = 0` or Blender leaves `.blend1` backups beside assets.
- Only Merge & CI edits STATUS.md and DECISIONS.md (D-026): put state and decisions in the PR body.
- Civitai is region-blocked from this machine; do not route around it.
- The body rig's origin is at hip height (z 0.82): refit height by measuring, then shift by the feet's z.
- Normal passes need view transform Raw and dither 0, or the data is tone-mapped and noisy.
