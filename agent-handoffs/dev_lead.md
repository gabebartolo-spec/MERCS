# Dev Lead handoff, 2026-10-08 (second Claude account, "Claude2: MERCS Lead")
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), `docs/08_ROADMAP.md`
§Phase 1 only, `docs/specs/phase1_visual_proof.md`, and `docs/01_ENGINE_DECISION.md` "Rendering plan".
Then `gh pr list` and `docs/STATUS.md`: PR states below are as of writing.

## State: available (awaiting Art's sample sheets; my open PRs wait on Merge & CI)
## Who did this
The director ran this session from a second Claude account with no Concept Lead, so it acted as
lead AND Dev Lead under the original account's rules. Peers in that account: "MERCS merge and CI
agent" (merges, board PRs) and "MERCS art agent setup" (Art Factory). Cross-session messages are
held and can expire when sessions run in different permission modes; the director approves them.
## Director decisions this session (2026-10-08; for Merge & CI's board PRs)
1. Pixel mode **A, whole screen** (640 × 360 SubViewport ×3; node setup in `01_ENGINE_DECISION.md`). Logged from #25.
2. Sprite scale **constant**: one texel = one logical pixel anywhere; distance shows by position. Logged from #25.
3. Look direction (NOT yet a ruling): mercs read like Pokémon Black/White trainer sprites, more
   detailed and slightly bigger; references (fan art, mood only, never in repo) show a steep
   top-down 3/4 camera (~50–60°), big-headed short figures, dense pixel scenery; grim Westeros
   palette (mud, stone, timber, overcast). "A lot of weather and particle effects, beautiful
   lighting." Spec §3's pitch range (30–40°) and `06_STYLE_ART.md` proportions need revisiting
   from Art's samples.
4. The Dev Lead works on development and coding; art goes to the Art agent.
5. **Testing cadence:** "avoid major testing or audits until milestones are reached at regular
   intervals". Per PR: run the existing suites and lints, attach one capture. New exhaustive
   suites, planted-defect rounds and audits happen at milestones (phase gates or a director-named
   checkpoint). Narrows CLAUDE.md rule 9's amount of proof, not the rule; needs a decision entry.
## Shipped
- #24 MERGED: stage scale contract. Rail distance derived (no fixed 12 m): texel = 1.78 × cos(pitch)
  / height_px, sprite Y-stretch 1/cos(pitch), so 1 texel = 1 logical px at the look-at point,
  matching `tools/pipeline/camera_rig.json`. `SheetFrame` shows `mercs.sheet/1` frames with pivot
  on the ground. Suite `stage_scale`.
- #25 MERGED: sample set 2. Stage exports `lighting` (DAY / RAIN_NIGHT: moon, torch, fixed-seed
  rain, tint), `depth_scale` (CONSTANT default; texel rescaled by depth, view-angle-corrected Y),
  `stand_at`; `StageData`, `StageWeather`; `tools/capture/sample_set_2.sh` + `sample_sheet.py`
  rebuild `docs/audits/sample_set_2/`. Stage defaults WHOLE_SCREEN and CONSTANT.
- #26 OPEN (claude/p1-lit-sprites): lit sprites. Frames with a normal map draw with a shaded,
  normal-mapped `StandardMaterial3D` (nearest, alpha scissor, Y billboard keeping scale, matte).
  Manifest key `"normal_image"`: same size as the sheet, camera-facing tangent space, OpenGL
  convention (R right, G up, B toward camera), n × 0.5 + 0.5. Suite `stage_light` (8).
- This PR (claude/p1-assets-suite): suite `assets` (8): every sheet under `assets/` plus the good
  fixture passes engine-side rules in `tests/lib/sheet_check.gd` (ENGINE-LOAD, -FACINGS, -FRAME,
  -PIVOT, -NORMAL); each rule rejects a planted-bad copy written to user:// at run time. Pixel
  rules stay in `tools/pipeline/validate_sheet.py` (Art's). Engine half of spec §6 "Engine";
  `assets.yml` (CI wiring) stays Art item 5. Built before decision 5; no more suites until a milestone.
## Merge order and expected conflicts
#26 and this PR both add a suite on the same lines of `tools/run_tests.sh` (ALL_SUITES),
`tools/ci_shards.txt`, `tests/expected_checks.txt`, `tests/README.md`. Whichever merges second
needs a sync: merge origin/main into it and keep BOTH suites (stage_light 8, assets 8). No force
push (denied by D-030 settings); merging main is fine because the repo squash-merges. No stacking:
branch from origin/main (rule in #27).
## Delegated
- Art Factory ("MERCS art agent setup"), item P1-ART-PROPORTIONS: proportion samples (realistic /
  heroic / B/W-like × 48/56/64 px × pitch 35° and 55°, facings S and SE, pose-bone scaling only),
  plus one normal pass in the format above; labelled sheet to the director; manifest paths to the
  Dev Lead. Its worktree: `../MERCS-wt/art-proportions`.
## Next for the Dev Lead, in order
1. When Art delivers manifests: place each in the stage at its pitch and height
   (`capture_stage.gd --sheet=<manifest> --pitch=<deg> --height=<px>`), lit and unlit, and give
   the director stage captures beside Art's sheets.
2. Street spec §6 "Street": a merc walking behind the well is occluded; two mercs crossing sort
   correctly (needs a second merc in the stage; alpha-scissor sprites depth-test, so verify).
3. Weather: the director wants much more. Phase 1 caps are rain + night + torch; the full
   catalogue (fog, snow, wind, storm, embers, light shafts) is a world-phase item. Ask before
   pulling it forward.
4. Sample set 1 (pitch × height) still waits on the Mixamo walk clip (D-029 sign-in).
## Worktrees
`../MERCS-wt/p1-stage-scale` is my one worktree (branch changes per PR). Remove it when #26 and
this PR merge. Others live: `.claude/worktrees/dual-desktop-instances-a78d20` (not mine) and Art's
`../MERCS-wt/art-proportions`.
## Rules learnt the hard way (keep under 10 lines)
- Sprite3D rebuilds its mesh and AABB on the next frame: `await process_frame` before measuring.
- gdformat writes CRLF here: normalise to LF after it. gdtoolkit is in ~/AppData/Roaming/Python/*/Scripts.
- A suite that extends a script failing to parse HANGS: run with `SUITE_TIMEOUT=120`; kill by PID.
- Constant depth scale needs the view-angle Y correction, not just the depth ratio.
- `docs/**/*.png` are plain git, not LFS. Commit the `.gd.uid` of each new script.
- Typed GDScript: assign a Variant to a typed local before `int()`/`float()` or a Dictionary cast.
- Python on this PC cannot see Git Bash's /tmp: pass `$(cygpath -m path)`.
