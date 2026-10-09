# Dev Lead handoff, 2026-10-09 (resumed after a director pause) (desktop, second Claude account, "MERCS BOSS")
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), `docs/08_ROADMAP.md`
§Phase 1 only, `docs/specs/phase1_visual_proof.md`, and `docs/01_ENGINE_DECISION.md` "Rendering plan".
Run `git fetch`, then `gh pr list` and `docs/STATUS.md`: PR states below are as of writing.

## State: working (open: #54 playback (this), #55 Art rest sheet, #57 stage freeze; next: M5 loop skeleton)
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
## Director picks 2026-10-09 (labelled 4K street captures, Lead QC passed)
Density **84 px** (960x540 logical; x2 at 1080p, x4 at 4K) and **45° sprites in the 55° world** at the
same px/m (82.275 px/m at 1x). Art's freeze is PR #52 (camera_rig: pitch_deg 45, world_pitch_deg 55,
px_per_m_1x authority, cell 176, pivot 88,152). Then Art publishes
`assets/sprites/mercs/average_m/average_m_body_rest.json` (the slice loads exactly this path) and
renders walk + idle (Mixamo works now: all 10 clips in the vault, retarget probe OK).
## Slice M1 PR (`claude/slice-m1-playable`)
`ui/screens/main.tscn` boots `presentation/world/slice_game.tscn`: `SliceGame` (keys / click walk via
`GridWalker`, A* on `StreetGrid.walkable_cells()`, camera `focus_on` in whole logical pixels, crowd
routes from `data/balance/slice.json`, T/R/F1/F3, door -> interior at x 100 and back). Runtime
lighting split into `StageLighting` (day / dusk / night, rain toggle); `PixelScreen` holds the
whole-screen wrap; `Text.t()` (`presentation/text.gd`) reads `data/text/en.json`. Slice sets
960x540 / 84 px itself; the stage's own defaults (and stage_scale's rig check reading
px_per_m_1x) change in the stage-freeze PR after #52. New suite `slice` (11, real input events).
Merged earlier: #49 (sheets load from a .pck), #51 is the slice spec.
## Draft `claude/slice-m2-clips` (depends on #53; merge main in after #53, then mark ready)
`SheetClip` (presentation/world/sheet_clip.gd) loads a whole mercs.sheet/1 once: frames per facing
("frame" 0..n-1), "fps", "loop", "ground_speed_mps". SliceGame plays walk while moving, idle while
standing (rest pose fallback), crowd phase-offset 0.37 s, mercs move at the walk clip's ground
speed. Art's agreed layout: row per facing in rig order, walk 8 frames (~6.5 fps), idle 4 (~4 fps),
files `average_m_body_walk.json` / `_idle.json` beside the rest sheet. slice floor 11 -> 13.
## #54 walk/idle playback (`claude/slice-m2-clips`)
`SheetClip` (presentation/world/sheet_clip.gd) loads a whole mercs.sheet/1 once: frames per facing
("frame" 0..n-1), "fps", "loop", "ground_speed_mps"; a facing short of a frame is dropped. SliceGame
plays walk while moving, idle while standing (rest fallback), crowd phase-offset 0.37 s, mercs move
at the walk clip's ground speed (Art measured 1.1004 m/s). slice floor 11 -> 13.
## Sprite sheets are plain git (Lead, 2026-10-09)
Art's #55 (rest sheet under assets/) went red on CI: `*.png` is LFS and CI checks out without LFS,
so Godot read pointer files. `.gitattributes` now makes `assets/sprites/**/*.png` plain git (like
the pipeline fixtures); big binaries stay LFS. After the fix merges, Art merges main into #55 and
runs `git add --renormalize assets/`. Lead QC of #55 in game: PASS (real merc in the slice).
## Suites (floors)
data 88, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 11, slice 11 (#53) -> 13 (m2-clips draft).
## Next for the Dev Lead, in order
1. After #52: stage-freeze PR (stage.json pixel 960x540 x2, sprite_height 84, stage_scale reads
   px_per_m_1x, capture defaults). Tell the director M1 is playable once main's build.yml is green.
2. M5 loop skeleton (recruit card, contract board, gate check, 3-4 v 4 battle on the grid, aftermath,
   camp) in sim/ + presentation, seeded. 3. Walk/idle playback (sheet clips) when Art delivers.
4. Street spec §6 occlusion/sorting fixture (crowd capture: `--extra=x,z;x,z`).
5. Weather catalogue only if the director pulls it forward (Phase 1 caps: rain, night, torch).
## Worktrees
Mine: `../MERCS-wt/slice-m1` (M1 PR); remove it when it merges.
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
