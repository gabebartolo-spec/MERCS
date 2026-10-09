# Art Factory handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief, and the director's route A decisions (Lead messages, 2026-10-09).

## State: awaiting Lead QC (P1-ART-SLICE-CAST step 1 sent)
## Task
P1-ART-SLICE-CAST (Lead): orc + vampyr at stage 1. QC order: (1) side-on clay at 0 deg + 45 deg stage-1
silhouette, (2) gait loop clip, (3) geared rest/walk/idle sheets with injury starter layers. First PR widens the
Tripo licence row to character parts (director: "use it whenever it would achieve the most beautiful and functional result").
## Branch
claude/art-slice-cast (from origin/main) in ../MERCS-wt/art-publish; WIP commit, no PR yet. claude/art-clips kept, paused.
## Done so far
- build_body.py: shape_targets (pre-rig, "lr-" both sides, weight > 1 allowed), features (rigid cones on bones: tusks).
- bodies.json: orc (2.02 m) and vampyr (1.93 m) with posture_lean_deg; orc.blend, vampyr.blend built; rig_contract has their hashes.
- render_character.py: per-body height, posture lean, --kit (blockout primitives on bones, groups), passes after the kit,
  kit parts labelled by bone. Kits: tools/pipeline/kits/{orc,vampyr}_s1_blockout.json.
- QC images in the session scratchpad slice/ folder: step1_side0_clay.png, step1_45_stage1_{1x,x4}.png, step1_45_silhouette_{1x,x4}.png.
## Next
Wait for the Lead's step-1 verdict; then gait (Mixamo walk per merc + per-merc gait numbers + hand keys).
Known gaps: orc thighs a little knock-kneed; the vampyr body alone reads as a lean human (his look lives in face, hands, gear).
## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: measure evaluated_get(depsgraph), never mesh.vertices. MPFB needs the user APPDATA (build only).
- Kit placement uses posed world coordinates; bone-local head_local is in armature space (MPFB rig is offset).
- Only Merge & CI edits STATUS.md and DECISIONS.md. Director: no mixels; send 1x and 4x as separate files.
- Godot runs leave .import churn: revert tracked. node_classes.gd.uid is TRACKED: never delete it.
- Judge a pose side-on at 0 degrees before the 45-degree sprite.
