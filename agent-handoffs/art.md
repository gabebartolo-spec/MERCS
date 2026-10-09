# Art Factory handoff, 2026-10-10 AEDT
Start from this file, CLAUDE.md, your brief, and the Lead ("MERCS BOSS") messages. Load art-qa-critic before any visual review.

## State: RESET requested by the director mid step 2 (2026-10-10). No jobs running. WIP committed and pushed.
Standing order (Lead, latest): FINISH step 2, send the clips to the Lead (never the director), then commit, rewrite this
file, push and PAUSE. Do not start step 3.
## Task
P1-ART-SLICE-CAST step 2: a 3 s gait loop at game speed, 1x and 2x, S/SE/E/NE, no foot slide. Orc: heavy, grounded.
Vampyr: controlled, predatory, upright. The Vampyr renders BARE (Lead decision); the sword returns in step 3 behind check A.
The orc keeps the axe only if it passes check A; otherwise render him bare and tell the Lead.
Carry into step 3: orc tusks as tapered cones; the Vampyr cape hugs the back (curved section, no proud edge at 45 deg).
## Lead-approved QA plan (2026-10-10, trimmed)
A in render_character.py (DONE, needs one fix, below): kit-vs-body clearance 1 cm on every dense frame, except a piece's
  "contact" bones (the axe lists RightHand, so the fingers may grip); direction "checks" in the kit json (claim, then
  measured min_dot). Results go to render_meta clip.kit_checks; a fail exits 1 and renders nothing (kit_checks.json written).
B: --pass layers (body clay, each kit group a flat label colour, DONE); 2x nearest crops of contact points at the key
  frames (clip.key_frames: foot forward L/R, right hand forward/back) for each facing. Crop script NOT written yet;
  outputs[].marks give the 1x pixel position of hands, hips and feet per frame.
C: one line per prop in the QC note (claim -> result). D dropped (A measures it); kit docs must match the maths.
E: a learnings entry in art-qa-critic once A or B has caught a real defect, with the run as evidence. A HAS caught them
  (below), so write the entry when step 2 lands.
## Check A evidence so far (logs D:\MERCS-vault\logs\2026-10-10_gait_*_A_*.log)
- Old axe (d2d8f93 kit): edge leads dot -0.345 FAIL, head forward -0.644 FAIL: the director's "held backwards" caught.
- Vampyr sword: scabbard -6.0 cm into LeftLeg FAIL, tip-trails axis dot 0.696 (< 0.9) FAIL, hilt and crossguard 1.3-1.7 cm
  into the torso FAIL: the director's "tendrils" caught.
- New axe (this branch): edge +0.796 PASS, head forward +0.559 PASS, head above grip 0.693 (needs 0.7) FAIL by a hair,
  haft clearance -0.120 m "near RightForeArm" FAIL. OPEN: a stance probe (ray parity) shows the haft BUTT (fraction 0.0,
  z 0.47 m) inside the body, i.e. probably the right THIGH, plus haft inside the fist (fractions 0.33-0.38, expected, the
  grip). The nearest-bone label comes from the BVH polygon and may be wrong. Next: confirm with a layers-pass 2x crop at
  dense frame 29 / 03; fix by shortening the haft below the fist or moving the grip down the haft; tilt the head up
  slightly (or set the need to 0.65 with a claim) so "head above the grip" passes honestly.
## Next, exactly
1. Fix the axe (above) until check A passes; if it can't, render the orc bare and tell the Lead.
2. Render colour and layers passes, S/SE/E/NE (facings 0-3), orc with axe_ kept, Vampyr with no kit.
   Runner: scratchpad run_gait.sh (pass --python-exit-code 1 to Blender or a traceback exits 0; use `read -r`).
3. pixelate.py to 1x, GIFs at 1x and 2x (3 s, the clip's fps; E row travels at ground_speed_mps over 0.25 m ticks), the
   2x crops at the key frames, a QC note with one line per prop. Send to the Lead. Commit, rewrite this file, push, pause.
## Done (committed)
render_character.py: --clip/--frames/--loop-window/--kit-keep/--pass layers; Mixamo retarget plus posture lean; gait layer
from bodies.json "gait" (swing_scale, hip sway/bounce/drop, cadence, hold_stance grip); two-bone leg IK on the clip's
ankles; KitChecks; marks; key_frames. Measured slide: orc 0.8 cm, Vampyr 0.6 cm. Pipeline self-test 15/15.
Orc kit: axe head forward (+20 X), blade on local -Y, spike +Y, contact + 3 checks. Vampyr kit: scabbard axis check only.
## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: measure evaluated_get(depsgraph). The MPFB rig is offset (location z 0.75).
- Blender 4D Vector.normalized() scales by its xyz length only: normalize a Quaternion as a Quaternion.
- Moving or rotating the hips drags planted feet: re-solve the legs (IK) onto the clip's ankles.
- Kit rot_deg: +X rotation leans a piece's +Z toward -Y (the body's front). Prove a direction by check A, never by the doc.
- Gear in body clay reads as anatomy: review kit in the layers pass, at 2x, at the contact frames.
- Blender returns exit 0 on a Python traceback unless --python-exit-code 1 is passed.
- Only Merge & CI edits STATUS.md and DECISIONS.md. Director: no mixels; send 1x and 2x as separate files.
