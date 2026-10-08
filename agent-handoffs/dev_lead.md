# Dev Lead handoff, 2026-10-08 (second Claude account, "Claude2: MERCS Lead")
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), `docs/08_ROADMAP.md`
§Phase 1 only, `docs/specs/phase1_visual_proof.md`, and `docs/01_ENGINE_DECISION.md` "Rendering plan".
Then `gh pr list` and `docs/STATUS.md`: PR states below are as of writing.

## State: available. All Dev Lead PRs merged (#24, #25, #26, #29, #31); this PR carries a test fix.
## Who did this
The director ran this session from a second Claude account with no Concept Lead, so it acted as
lead AND Dev Lead under the original account's rules. Peers in that account: "MERCS merge and CI
agent" (merges, board PRs) and "MERCS art agent setup" (Art Factory). Cross-session messages are
held and can expire when sessions run in different permission modes; the director approves them.
## Director decisions this session (2026-10-08; Merge & CI logs them from PR bodies)
1. Pixel mode **A, whole screen** (640 × 360 SubViewport ×3; node setup in `01_ENGINE_DECISION.md`).
2. Sprite scale **constant**: one texel = one logical pixel anywhere; distance shows by position.
3. Mercs read like Pokémon Black/White trainer sprites, more detailed, a bit bigger. Picked from
   Art's samples (#28): **proportion C** (head 1.8×, hands 1.3×, thighs 0.85×, about 4½ heads),
   **56 px** figure, **55° pitch**. Grim Westeros palette (mud, stone, timber, overcast). References
   were fan art, mood only, never in the repo.
4. "A lot of weather and particle effects, beautiful lighting."
5. The Dev Lead works on development and coding; art goes to the Art agent.
6. **Testing cadence:** "avoid major testing or audits until milestones are reached at regular
   intervals". Per PR: run the existing suites and lints, attach one capture. New exhaustive
   suites, planted-defect rounds and audits happen at milestones (phase gates or a director-named
   checkpoint). Narrows CLAUDE.md rule 9's amount of proof, not the rule.
7. Mixels are an automatic fail, in assets and in captures: never put a 2× crop beside a 1× view.
## Shipped (all merged)
- #24 stage scale contract: rail distance derived (texel = 1.78 × cos(pitch) / height_px, sprite
  Y-stretch 1/cos(pitch)), so 1 texel = 1 logical px at the look-at point, matching
  `tools/pipeline/camera_rig.json`. `SheetFrame` shows `mercs.sheet/1` frames, pivot on the ground.
- #25 sample set 2: stage exports `lighting` (DAY / RAIN_NIGHT: moon, torch, fixed-seed rain),
  `depth_scale` (CONSTANT default; texel rescaled by depth, view-angle-corrected Y), `stand_at`;
  `StageData`, `StageWeather`; `tools/capture/sample_set_2.sh` + `sample_sheet.py`.
- #26 lit sprites: a frame with a normal map draws with a shaded, normal-mapped
  `StandardMaterial3D` (nearest, alpha scissor, Y billboard keeping scale, matte). Manifest key
  `"normal_image"`: same size as the sheet, camera-facing tangent space, OpenGL convention
  (R right, G up, B toward camera), n × 0.5 + 0.5. Unlit frames keep the night tint.
- #29 suite `assets`: every sheet under `assets/` plus the good fixture passes engine-side rules in
  `tests/lib/sheet_check.gd` (ENGINE-LOAD, -FACINGS, -FRAME, -PIVOT, -NORMAL), read against
  `camera_rig.json`. Pixel rules stay in `tools/pipeline/validate_sheet.py` (Art's).
- #31 stage defaults to 55° / 56 px; walk loop re-laid inside the 55° view (behind the well and back).
- This PR: the assets suite's planted copies also copy the good fixture's normal map, so the suite
  stays green when Art's rig freeze adds `normal_image` to the good fixture.
## Suites (floors)
data 88, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 8.
## In flight elsewhere
- Art: rig freeze for C / 56 / 55 on `claude/art-freeze-c55` (draft): `camera_rig.json` at 55° /
  56 px, cell 96, pivot (48,80); C's bone scales and the arms-down stance in the render step; the
  validator's feet tolerance; `06_STYLE_ART.md` §3; good fixture re-rendered with a normal pass.
  It edits `tests/run_stage_light_tests.gd` so the "no normal_image falls back" check uses a copy
  with the key removed (the director-approved plan; floor unchanged). Then `average_f`.
## Next for the Dev Lead, in order
1. When Art's freeze lands: make the re-rendered good fixture (C, 56 px, 55°, lit) the stage's
   default merc instead of the capsule, so every capture shows the chosen look.
2. Street spec §6 "Street": a merc walking behind the well is occluded; two mercs crossing sort
   correctly (needs a second merc; alpha-scissor sprites depth-test, so verify). Light proof only.
3. The grey-box props are sparse at 55°; the real modular street kit (spec step 8) is Art + Dev.
4. Weather: the director wants much more. Phase 1 caps are rain + night + torch; the full
   catalogue (fog, snow, wind, storm, embers, light shafts) is a world-phase item. Ask before
   pulling it forward.
5. Sample set 1 is superseded by the director's 55° / 56 px pick; the Mixamo walk clip (D-029
   sign-in) is still needed for walking sprites.
## Worktrees
`../MERCS-wt/p1-stage-scale` is the Dev Lead's one worktree (branch changes per PR); remove it when
idle. Others: `.claude/worktrees/dual-desktop-instances-a78d20` (not mine), Art's under `../MERCS-wt/`.
## Rules learnt the hard way (keep under 10 lines)
- Sprite3D rebuilds its mesh and AABB on the next frame: `await process_frame` before measuring.
- gdformat writes CRLF here: normalise to LF after it. gdtoolkit is in ~/AppData/Roaming/Python/*/Scripts.
- A suite that extends a script failing to parse HANGS: run with `SUITE_TIMEOUT=120`; kill by PID.
- Typed GDScript: assign a Variant to a typed local before `int()`/`float()` or a Dictionary cast.
- `docs/**/*.png` are plain git, not LFS. Commit the `.gd.uid` of each new script.
- Python on this PC cannot see Git Bash's /tmp: pass `$(cygpath -m path)`.
- A merge from main can silently restore lines without a conflict: run the suites before pushing.
- Check `gh pr view <n> --json state` before pushing to a PR branch: pushing to a merged, deleted
  branch recreates it on the remote.
