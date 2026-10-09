# Dev Lead handoff, 2026-10-09 evening (desktop, second Claude account, "MERCS BOSS")
Start from this file, CLAUDE.md, `~/.claude/memory-shared/MEMORY.md`, your brief
(`agent-briefs/DEV_LEAD_OPUS.md`), `docs/00_VISION.md` (revised 2026-10-09, #63) and
`docs/specs/art_direction_slice.md`. Run `git fetch`, then `gh pr list` and `docs/STATUS.md`.

## State: working (M5 stack open: #64 -> #66 -> #67; Art writing P1-ART-REFOCUS)

## Who does what
This account has no Concept Lead: the session acts as lead AND Dev Lead under the original
account's rules. Peers (desktop sessions, wake with ccd_session_mgmt send_message by id):
"MERCS SUPPORT" (local_f70eca67-...) = Merge & CI; "MERCS ART FACTORY" (local_e5986dbb-...) = Art.

## THE GOAL (director /goal, 2026-10-09)
"A playable vertical slice that I can test and assess the art direction before we develop bulk
assets and content", including "an example of the core gameplay loop". Spec (merged #51):
M1 playable street (done) -> M2 body in motion -> M3 street kit and weather -> M4 looks (waits for
P1-ART-REFOCUS) -> M5 loop example -> gate ("is this the look?").

## Director decisions that shape the work (logged D-042..D-058)
- Realistic proportions; 84 px mercs on a 960x540 logical screen (x2 1080p, x4 4K); sprites drawn
  at 45 deg inside the 55 deg world at the same px/m (camera_rig px_per_m_1x 82.275).
- Vision revised (#63): a HAND-MADE cast of 25 (no procedural recruits), grim grounded fantasy WITH
  magic (orcs, a Vampyr), no type chart (counters from combat roles; themed resolve per merc),
  three-stage promotion lines, per-merc gear lines, up to 4 moves. Art pipeline paused for
  P1-ART-REFOCUS (written proposal first, no renders). Nothing of Phase 2 MercGen starts.
- Testing cadence: per PR the smallest relevant suites + one capture; audits at milestones.
- Mixels are an automatic fail; every look question goes to the director with labelled images.

## Lead QC of Art (global CLAUDE.md; skill art-qa-critic)
Every Art image comes to the lead first; only passing work reaches the director. Lesson from the
walk clip: judge motion as a PLAYED CLIP at game speed, not frame by frame. The director flagged
the realistic walk's gait ("legs should be angled and move naturally") after a lead pass; Art's
clips PR was never opened and the art refocus supersedes it. Carry the gait note into the refocus.

## Open PRs (stacked; merge in order, sync each after the one below lands)
1. #64 `claude/slice-m5-cast-check`: the director's reference pair in `battle.json` "fighters"
   (orc: charge = walk + attack in one turn; Vampyr: blood price = pay hp, never the last, for one
   powered attack), bandits, `sim/story/checks.gd` (visible d20 + skill vs difficulty). battle 14.
2. #66 draft `claude/slice-m5-loop`: `sim/story/slice_loop.gd` (SliceLoop: arrive, recruit,
   contract, travel, gate, battle, aftermath, return, camp, done), `data/scenarios.json` + schema
   + fixtures, caps.json `scenarios: 1`. Suite loop 4; data floor 96. Lead sketch calls flagged
   for the director: a talked-down lookout leaves the band shaken; the defeated cannot be hired
   (Q21); the recruit is a placeholder.
3. #67 draft `claude/slice-m5-loop-ui`: F5 plays the loop on screen (`LoopDirector`, `LoopPanel`,
   `BattleView`; placeholder gold/red side rings until the cast's art carries identity). slice 15.
   GPU play-through passes end to end; captures in `docs/audits/slice_m5/`.

## Code map (slice)
- `presentation/world/slice_game.gd` (boots from `ui/screens/main.tscn`): walking (`GridWalker`),
  follow camera (`StreetStage.focus_on`), crowd, T/R/F1/F3/F5, door to the interior, walk/idle
  playback (`SheetClip`), the loop (`LoopDirector`).
- `presentation/world/street_stage.gd`: the 3D street, pixel screen (`PixelScreen`), lighting
  (`StageLighting`), upright depth/light shaders, `add_merc`/`move_extra`/`remove_merc`.
- `sim/core/rng.gd` (named streams), `sim/battle/` (Battle, BattleUnit, BattleAi),
  `sim/story/` (Checks, SliceLoop). Numbers in `data/balance/{stage,slice,battle}.json`.
- Capture: `tools/capture/capture_stage.gd` (`--logical=960x540 --height=84`, `--sheet`, `--extra`).

## Suites (floors after the stack lands)
data 96, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 11, slice 15, battle 14, loop 4.

## Next for the Dev Lead
1. Land the stack (#64, #66, #67); then tell the director the loop example is in the build (F5).
2. Review Art's P1-ART-REFOCUS proposal when it arrives (lead QC), then one director question.
3. Battle feel when the cast's art exists: walk/hit/death clips in the battle view, facing.
4. Branches waiting on the director (deletes refused by settings): claude/p1-crisp-snap,
   claude/p1-frame-time, claude/p1-sheet-export-load.

## Worktrees
Mine: `../MERCS-wt/slice-m1` (branch changes per PR). Art: `../MERCS-wt/art-publish`.

## Rules learnt the hard way (keep under 10 lines)
- REWRITE this file each time; never insert sections (doc-caps fails past 120 lines).
- Headless test windows are 64x64: size root to 1920x1080 before clicking GUI in a suite.
- Lit sprites ignore `modulate`; mark sides or states with world geometry, not tint.
- Damage is rolled 1..damage: to force a kill in a test set the target's hp to 1.
- `git show <ref>:file > file` writes LFS pointers for LFS paths; use `git lfs smudge`.
- A suite extending a script that fails to parse HANGS: `SUITE_TIMEOUT=120`; kill by PID.
- Typed GDScript: assign a Variant to a typed local before arithmetic, casts or `.get()`.
- `git fetch` and read `git log origin/main` before choosing or briefing any work.
