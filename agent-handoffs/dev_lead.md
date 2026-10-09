# Dev Lead handoff, 2026-10-10 (desktop, second Claude account, "MERCS BOSS")
Start from this file, CLAUDE.md, `~/.claude/memory-shared/MEMORY.md`, your brief
(`agent-briefs/DEV_LEAD_OPUS.md`), `docs/00_VISION.md` (revised 2026-10-09, #63) and
`docs/specs/art_direction_slice.md`. Run `git fetch`, then `gh pr list` and `docs/STATUS.md`.

## State: PAUSED by the director (2026-10-10: "once you and the team have all been regenerated, pause development")

## Who does what
This account has no Concept Lead: the session acts as lead AND Dev Lead under the original
account's rules. Peers (desktop sessions, message by session id):
"MERCS SUPPORT" (local_f70eca67-...) = Merge & CI; "MERCS ART FACTORY" (local_e5986dbb-...) = Art.

## Team refresh and pause (director, 2026-10-10)
Rule: `.claude/skills/mercs-handoff` "The lead refreshes the team" + shared memory
refresh-workers-at-task-boundaries. Art: regenerated, passed step 1 r2, started step 2 gait,
then told to PAUSE (commit WIP, rewrite art.md, push, stop). Support: NOT yet regenerated; it
refuses relayed director instructions and waits for the director to type "restart" in its chat
(then it fixes merge_ci.md for #70, merges that, clears). After its clear send NO kick-off while
paused. The lead regenerated itself after this rewrite. Nothing resumes until the director says.

## THE GOAL (director /goal, 2026-10-09)
"A playable vertical slice that I can test and assess the art direction before we develop bulk
assets and content", including "an example of the core gameplay loop". M1 street, M2 motion and
M5 loop example are on main (F5 in the build). Remaining: the cast's art (orc + Vampyr) in the
slice, then the gate ("is this the look?").

## Director decisions that shape the work (logged D-042..D-062)
- Realistic proportions; 84 px mercs on a 960x540 logical screen; sprites drawn at 45 deg in the
  55 deg world at the same px/m.
- Vision (#63): hand-made cast of 25, grim fantasy with magic, no type chart, promotion lines.
- Route A: Tripo for any part where it gives the best result (ask above 2,000 credits/session;
  D-060 confirmation pending on the board). Sprite changes only at promotion + one signature piece.
- "Permanent injuries must be considered for all spritework" -> injury layers.
- Testing: smallest suites per PR, audits at milestones. Mixels fail automatically.

## Art (P1-ART-SLICE-CAST, branch claude/art-slice-cast, no PR)
QC order: (1) clay + 45 deg silhouettes: PASSED r2 (2026-10-10), (2) gait as a played 3 s loop
(orc heavy and grounded, Vampyr controlled and predatory; bare bodies + weapon, no cape; S/SE/E/NE
at 1x and 2x; no foot slide): STARTED then PAUSED, clips come to the lead, (3) geared sheets with injury
layers per the layer contract. Step 3 must fix: orc tusks (front reads as flat plates; want
tapered cones from the lower jaw) and Vampyr cape (stands off the shoulder like a tower shield
in SE/SW/E/W; must hug back and shoulders). Vampyr Tripo head at 4x before full sheets.
Lesson: judge motion as a PLAYED CLIP at game speed, not frame by frame.

## Sprite layers (#70, merged)
`SheetClip.load_layers([body, gear, head, injury...])` composites same-grid mercs.sheet/1 layers.
Contract sent to Art: one manifest per layer per clip, identical frames/pivot/size, hard alpha,
`<merc>_<layer>_<clip>.json`, plus a look manifest (layer order per merc per stage).
Next code: SliceGame loads the orc and Vampyr looks from that manifest (data, not code).

## Code map (slice)
- `presentation/world/slice_game.gd`: walking, follow camera, crowd, T/R/F1/F3/F5, door, clips, loop.
- `presentation/world/{loop_director,loop_panel,battle_view,street_stage,sheet_clip}.gd`.
- `sim/core/rng.gd`, `sim/battle/`, `sim/story/{checks,slice_loop}.gd`.
- Data: `data/balance/{stage,slice,battle}.json`, `data/scenarios.json`.

## Suites (floors)
data 96, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 13, slice 15, battle 14, loop 4.

## Open PRs
`claude/team-refresh`: docs-only, the refresh rule in mercs-handoff + this handoff. Merge & CI merges.

## Next for the Dev Lead
1. Kick off Support after its restart (above). 2. QC Art's gait clips (art-qa-critic, played clip).
3. Tell the director the F5 loop example is playable in the build.
4. Load the cast's looks in SliceGame when Art publishes stage-1 sheets.
5. Branches waiting on the director (deletes refused by settings): claude/p1-crisp-snap,
   claude/p1-frame-time, claude/p1-sheet-export-load.

## Worktrees
Mine: `../MERCS-wt/slice-m1` (branch changes per PR). Art: `../MERCS-wt/art-publish`.

## Rules learnt the hard way (keep under 10 lines)
- REWRITE this file each time; never insert sections (doc-caps fails past 120 lines).
- tests.yml skips draft PRs: mark ready, THEN push.
- Headless test windows are 64x64: size root to 1920x1080 before clicking GUI in a suite.
- Lit sprites ignore `modulate`; mark sides or states with world geometry, not tint.
- `git show <ref>:file > file` writes LFS pointers for LFS paths; use `git lfs smudge`.
- A suite extending a script that fails to parse HANGS: `SUITE_TIMEOUT=120`; kill by PID.
- Typed GDScript: assign a Variant to a typed local before arithmetic, casts or `.get()`.
- `git fetch` and read `git log origin/main` before choosing or briefing any work.
