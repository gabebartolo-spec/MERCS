# Dev Lead handoff, 2026-10-09 later (desktop, second Claude account, "MERCS BOSS")
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), `docs/08_ROADMAP.md`
§Phase 1 only, `docs/specs/phase1_visual_proof.md`, and `docs/01_ENGINE_DECISION.md` "Rendering plan".
Run `git fetch`, then `gh pr list` and `docs/STATUS.md`: PR states below are as of writing.

## State: working (this PR open; Art rendering realistic density samples for lead QC)
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
#41 `.gdignore` import fix; #42 mercs lit where they stand (upright depth and light, toes show).
## Other open work
- `claude/p1-sheet-export-load` (d520808, cloud subagent; reviewed, no PR yet): SheetFrame loads
  imported res:// PNGs so sheets work from an exported .pck. #41 has merged: merge main in,
  run assets (floor 8 → 11), open the PR. It edits `sheet_frame.gd` (light conflict possible).
## Suites (floors)
data 88, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 8.
## Next for the Dev Lead, in order
1. QC Art's realistic density samples; director picks the density (labelled 4K images).
2. Freeze the pick (Art: camera_rig/proportions; Dev: stage.json pixel block), default merc from
   `assets/`, head/hair-layer question. 3. Export-load PR.
4. Street spec §6 occlusion/sorting fixture (crowd capture: `--extra=x,z;x,z`).
5. Weather catalogue only if the director pulls it forward (Phase 1 caps: rain, night, torch).
## Worktrees
Mine: `../MERCS-wt/p1-res` (this PR); remove it when it merges.
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
