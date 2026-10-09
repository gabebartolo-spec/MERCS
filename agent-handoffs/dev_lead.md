# Dev Lead handoff, 2026-10-09 (resumed after a director pause) (desktop, second Claude account, "MERCS BOSS")
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), `docs/08_ROADMAP.md`
§Phase 1 only, `docs/specs/phase1_visual_proof.md`, and `docs/01_ENGINE_DECISION.md` "Rendering plan".
Run `git fetch`, then `gh pr list` and `docs/STATUS.md`: PR states below are as of writing.

## State: working (art direction slice M1, then M5 loop skeleton; #49 and the slice-spec PR open; Art on realistic QC round 3)
## THE GOAL (director, 2026-10-09)
"A playable vertical slice that I can test and assess the art direction before we develop bulk
assets and content." Spec: `docs/specs/art_direction_slice.md` (the playable Phase 1 gate build:
controllable merc, crowd, real kit, day/dusk/night, rain + particles, three looks + eye-patch,
one interior, plus a scripted one-pass example of the core loop (recruit, contract, gate, 3v4
turn-based battle, aftermath, camp); milestones M1 playable grey-box -> M2 body -> M3 street ->
M4 looks -> M5 loop example -> gate). Dev owns M1 now, then the M5 skeleton.
## Who does what
This account has no Concept Lead: the session acts as lead AND Dev Lead under the original
account's rules. Peers (desktop sessions): "MERCS SUPPORT" = Merge & CI (merges, board PRs);
"MERCS ART FACTORY" = Art. Cloud sessions are fine for bounded Linux jobs only (no GPU, no Blender,
can push only their own branch, cannot reach desktop peers); the director moved Dev Lead back here.
## Director decisions (all logged or in PR bodies)
Pixel mode A whole screen; constant sprite scale; 55° pitch. **2026-10-09: proportion C is
REVERSED** ("I don't like the big head, let's go for a realistic, 4k pixel art look"): realistic
proportions, and the pixel density (56 / 84 / 112 px merc) is open until the director picks from
samples; grim Westeros palette; lots of weather, particles, beautiful lighting; Dev Lead codes,
Art does art; mixels are an automatic fail (captures too: never a 2× crop beside a 1× view);
testing cadence: per PR existing suites + lints + one capture, heavy audits only at milestones;
"do what you think is best" (autonomy, #39).
## Lead QC of Art (director rule 2026-10-08; global CLAUDE.md; skill `art-qa-critic`)
Art sends every image to the lead first. The lead checks at 1x and at integer zoom: anatomy,
contact points, stance, profile depth, silhouette, mixels, speckle, outline, pivot and feet, light.
Only passing work goes to the director, as one decision with labelled images and QC notes.
- Round 1 (#34 fixture): head jutting with no neck, arms too long, outline missing, speckle,
  unlabelled egg head. Art fixed all of these on `claude/art-qc-c55` (not yet committed).
- Round 2 (2026-10-09, `../MERCS-wt/art-qc/docs/audits/qc_c55/`): FAILED. E/W profile is a
  lollipop (torso about 6 px deep, arm merged into it), so it needs MPFB build targets to reach
  ~10–11 px of chest depth. Also: the 0.37 m stance makes a "C" foot hook in E/W and a kicked-up
  far foot in NE/NW (narrow it to ~0.2 m); mud blotches on the chest in SE/NW/SW; inner lines
  needed where the arm overlaps the torso. Sent back with these fixes.
- After it passes: Art publishes average_m rest + normal under `assets/` with a register row;
  then make it the stage's default merc (presentation may not reference `tests/`). Ask the
  director whether to add a placeholder head/hair layer (Art flagged it as a director question).
## Realistic density sample set (in flight)
Art renders the realistic body (round-2 fixes carried over) at pitch 55 and 56 / 84 / 112 px, in
`../MERCS-wt/art-qc/docs/audits/realistic_density/` (local, unpushed). This PR adds
`capture_stage.gd --logical=WxH` (stage `logical_size_px` / `integer_scale`): pair 960x540 with
`--height=84` and 1280x720 with `--height=112` and the merc keeps its share of the screen. 84 px
(960x540) is integer at 1080p (x2) and 4K (x4); 112 px (1280x720) mixels at 1080p (x1.5). Next:
QC Art's strips, capture each in the street, then ONE director question with labelled 4K images.
## Merged since the last handoff
#41 `.gdignore` import fix; #42 mercs lit where they stand; #44 `--logical=WxH` density captures.
## #49 (`claude/p1-sheet-pck-load`, open)
The cloud subagent's `claude/p1-sheet-export-load` (c790e02 test-first, d520808 fix) merged onto main:
`SheetFrame._load_image()` loads imported res:// PNGs through ResourceLoader, so sheets work from an
exported .pck (the Phase 1 gate is played in the build). Three `assets` checks: imported textures keep
every visible pixel, a sheet that exists only inside a .pck loads, and its pixels match. Floor 8 -> 11.
Delete the old remote branch `claude/p1-sheet-export-load` after merge (superseded by this PR).
## Suites (floors)
data 88, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 11 (this PR).
## Next for the Dev Lead, in order
1. Slice M1 (playable grey-box): boot into the street in the exported build, WASD/arrows +
   click-to-move, pixel-snapped follow camera, crowd loops, T/R/F1/F3 toggles, interior door.
   Then QC Art's realistic density samples; director picks density + sprite pitch.
2. Freeze the pick (Art: camera_rig/proportions; Dev: stage.json pixel block), default merc from
   `assets/`, head/hair-layer question. 3. Walk/idle clip route (Mixamo D-029 or Blender keys).
4. Street spec §6 occlusion/sorting fixture (crowd capture: `--extra=x,z;x,z`).
5. Weather catalogue only if the director pulls it forward (Phase 1 caps: rain, night, torch).
## Worktrees
Mine: `../MERCS-wt/p1-pck` (#49), `../MERCS-wt/p1-slice` (spec PR); remove each when it merges.
Art: `../MERCS-wt/art-qc`. Not mine: `.claude/worktrees/dual-desktop-instances-a78d20`.
## Rules learnt the hard way (keep under 10 lines)
- `git fetch` and read `git log origin/main` before choosing or briefing any work.
- Headless suites never compile shaders: prove a shader change with a GPU capture (Vulkan, plus
  `--rendering-driver opengl3` for the Compatibility branch).
- Pin a change to "pixel-identical where nothing should change": diff captures against main.
- Sprite3D rebuilds its mesh and AABB on the next frame: `await process_frame` before measuring.
- Typed GDScript: assign a Variant to a typed local before `int()`/`float()` or a cast.
- A suite extending a script that fails to parse HANGS: `SUITE_TIMEOUT=120`; kill by PID.
- Presentation may not name a `tests/` path (layering.py); data/balance holds numbers only.
- Check `gh pr view <n> --json state` before pushing: a merged, deleted branch gets recreated.
- Python can't see Git Bash's /tmp (`cygpath -m`); gdformat writes CRLF (normalise to LF).
