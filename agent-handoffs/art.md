# Art Factory handoff, 2026-10-08 05:10 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/ART_AGENT.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).

## State: awaiting director
## Task
Phase 1 item 1 — rig freeze: MPFB `average_m` (male) at 1.78 m, Mixamo-named skeleton, six sockets, rest-pose hash in `tools/pipeline/rig_contract.json`.
## Branch and commit
claude/art-p1-rig-freeze, worktree ../MERCS-wt/art-p1, PR (see PR list).
## Files I own right now
`tools/pipeline/build_body.py`, `tools/pipeline/rig_sockets.json`, `tools/pipeline/rig_contract.json`,
`tools/pipeline/bodies/bodies.json`, `tools/pipeline/bodies/average_m.blend` (LFS), `docs/audits/rig_freeze_average_m.png`.
## Unfinished changes
None in this PR. Next for Art after merge: the female `average_f` body on the same skeleton (director: men and women,
two bodies); sample set 1 needs the Dev Lead's grey-box street and a Mixamo walk clip in the vault.
## Evidence so far
- Three independent builds give rest_pose_sha256 `17b2aa42…1f43cc5`; `--check` prints RIG_CONTRACT_OK.
- Height 1.7798 m (target 1.78 ± 0.002), 52 bones (cap 65), left = +X asserted by the script.
- Review sheet: rest and bent poses deform cleanly (`docs/audits/rig_freeze_average_m.png`).
## Attempts (for the fix-loop rule)
- Height fit 1: measured base vertex coords, so shape-key targets were invisible. Fixed by measuring the evaluated mesh.
## Open decisions
- Mixamo clips need the director's Adobe account (Art cannot sign in). Needed before sample set 1.
## Running jobs
None.
## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: always measure `evaluated_get(depsgraph)`, never `mesh.vertices`.
- `read_factory_settings` unloads MPFB; clear objects instead.
- Set `filepaths.save_version = 0` or Blender leaves `.blend1` backups beside assets.
- Only Merge & CI edits STATUS.md and DECISIONS.md (D-026): put state and decisions in the PR body.
- Civitai is region-blocked from this machine; do not route around it.
