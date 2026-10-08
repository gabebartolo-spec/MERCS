# Dev Lead handoff, 2026-10-09 (desktop, second Claude account, "MERCS BOSS")
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), `docs/08_ROADMAP.md`
§Phase 1 only, `docs/specs/phase1_visual_proof.md`, and `docs/01_ENGINE_DECISION.md` "Rendering plan".
Run `git fetch`, then `gh pr list` and `docs/STATUS.md`: PR states below are as of writing.

## State: working (this PR open; awaiting Art's QC round 3)
## Who does what
This account has no Concept Lead: the session acts as lead AND Dev Lead under the original
account's rules. Peers (desktop sessions): "MERCS SUPPORT" = Merge & CI (merges, board PRs);
"MERCS ART FACTORY" = Art. Cloud sessions are fine for bounded Linux jobs only (no GPU, no Blender,
can push only their own branch, cannot reach desktop peers); the director moved Dev Lead back here.
## Director decisions (all logged or in PR bodies)
Pixel mode A whole screen; constant sprite scale; proportion C / 56 px / 55° (B/W-trainer-like,
more detail); grim Westeros palette; lots of weather, particles, beautiful lighting; Dev Lead codes,
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
## This PR (`claude/p1-lit-upright`): mercs are lit where they stand
#39 made the depth of camera-facing sprites upright, but lighting still read the leaning quad.
A merc in front of a wall drew nearly black (lit and shadowed from inside the wall), and the
ground cut off the toes (main too). `upright_sprite.gdshaderinc` now cuts each view ray with the
upright plane through the feet, or with the ground plane where that is nearer. Depth is exact per
pixel (`DEPTH`, with a Compatibility-renderer branch), and lighting uses that point per corner
(`skip_vertex_transform`). Evidence: `docs/audits/lit_upright/lit_upright_sheet.png`.
## Other open work
- #41 `claude/p1-import-gdignore`: `tools/pipeline/.gdignore`, so a headless import without
  Blender (Linux CI) stops failing on `average_m.blend` and importing no PNGs.
- `claude/p1-sheet-export-load` (d520808, cloud subagent; reviewed, no PR yet): SheetFrame loads
  imported res:// PNGs so sheets work from an exported .pck. Once #41 merges: merge main in,
  run assets (floor 8 → 11), open the PR. It edits `sheet_frame.gd` (light conflict possible).
## Suites (floors)
data 88, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 8.
## Next for the Dev Lead, in order
1. This PR, then #41 merged; export-load PR.
2. QC Art's round 3; when it passes, the default merc from `assets/`; one director question with
   labelled images (the look, plus the head/hair-layer question).
3. Street spec §6 occlusion/sorting fixture (crowd capture: `--extra=x,z;x,z`).
4. Weather catalogue only if the director pulls it forward (Phase 1 caps: rain, night, torch).
## Worktrees
Mine: `../MERCS-wt/p1-dev` (#41) and `../MERCS-wt/p1-lit` (this PR); remove each when it merges.
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
