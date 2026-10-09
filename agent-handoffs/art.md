# Art Factory handoff, 2026-10-10 AEDT
Start from this file, CLAUDE.md, your brief, and the Lead ("MERCS BOSS") messages. Load art-qa-critic before any visual review.

## State: PAUSED by the director (2026-10-10, via Lead). No jobs running. Step 2 WIP committed; QA plan and two
## decisions (approve plan A-E; Vampyr gait bare or with the fixed sword) are with the Lead, unanswered. Send no clips until resumed.
## Exact next step on resume: get the Lead's answers; build check A (prop-intent direction + kit/bone clearance in the clip
## facts) and show it failing on the current axe/scabbard first; then re-render the orc (axe fix) and the Vampyr; walk B and C; send to the Lead.
## Task
P1-ART-SLICE-CAST: orc and Vampyr at stage 1. Step 1 r2 PASSED (Lead, 2026-10-10). Step 2: a 3 s gait loop at game speed,
1x and 2x, S/SE/E/NE at least, on bare bodies plus weapon, with no cape panels. Orc: heavy, grounded, sway, arms swing from
the shoulder. Vampyr: controlled, predatory, upright, less bounce. Check foot plant against ground_speed_mps. Clips go to the Lead.
Carry into step 3: orc tusks as tapered cones (two points from the front); the Vampyr cape hugs the back with a curved
cross-section and no proud edge at 45 deg.
## Branch
claude/art-slice-cast in ../MERCS-wt/art-publish (WIP commits, no PR). claude/art-clips is older clip work (paused); the retarget was ported from it.
## Done (WIP, this session)
- render_character.py: --clip/--frames/--loop-window/--kit-keep. Mixamo retarget (limb chains copy direction, the rest
  takes its delta from rest) plus posture lean on the torso chain. The gait layer comes from bodies.json "gait":
  arm_adduct_deg, swing_scale (rotation about the loop mean), hip_sway/bounce scale, hip_drop_m, cadence_scale and
  hold_stance (the grip keeps the stance wrist angle). A two-bone leg IK pins the ankles to the clip's foot path.
  The clip facts include foot_slide_m.
- Measured: orc 5.71 fps, 1.13 m/s, slide 0.8 cm; Vampyr 5.97 fps, 1.09 m/s, slide 0.6 cm. Pipeline self-test 15/15.
- Evidence in D:\MERCS-vault\renders\gait_2026-10-10\ (GIFs 1x/2x plus 4x frames). It SHOWS THE DEFECTIVE PROPS below.
## Defects the director caught (open)
1. Orc axe held backwards. The kit group rot_deg X -28 leaned the head back (+Y), and the edge faced out (-X). Kit edited to
   X +20, blade on local -Y, spike +Y (rot X -90). NOT rendered or verified yet.
2. Vampyr "tendrils": the sword blockout in skin clay. The scabbard is 0.95 m (tip at ankle height) and its rot X -12 leans the
   tip forward into the stride, so the leg passes through it. Proposed: one rigid sword group, hilt forward, tip back and
   out, 0.85 m. Or render him bare for the gait (my recommendation to the Lead).
## QA plan sent to the Lead (awaiting approval)
A machine checks: a prop-intent direction test and a kit-vs-bone clearance test per dense frame, both in the clip facts.
B evidence: a flat-colour layer pass, 2x crops of every contact point per facing and frame, and a 0-degree side view.
C a written claim per prop before rendering, and a written checklist walk after. D kit doc and rot_deg verified by test.
E a learnings entry once the checks catch a real defect.
## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: measure evaluated_get(depsgraph). The MPFB rig is offset (location z 0.75).
- Blender 4D Vector.normalized() scales by its xyz length only: normalize a Quaternion as a Quaternion.
- Scaling the hips' rotation or moving the hips drags planted feet: re-solve the legs (IK) onto the clip's ankles.
- Kit rot_deg: +X rotation leans a piece's +Z toward -Y (the body's front). Verify the direction by measurement, never by the doc.
- Gear in body clay reads as anatomy: review kit with a flat-colour layer pass, not only the clay render.
- Only Merge & CI edits STATUS.md and DECISIONS.md. Director: no mixels; send 1x and 2x/4x as separate files.
- Facing 2 (E) faces screen right (toes +X); the trailing push-off foot can mislead you, so measure it.
