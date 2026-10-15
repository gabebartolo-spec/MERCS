# Dev Lead handoff, 2026-10-15 (desktop, personal account, "Game Studio Lead mercs")
Start from this file, CLAUDE.md, `~/.claude/memory-shared/MEMORY.md`, the co-lead playbook,
your brief (`agent-briefs/DEV_LEAD_OPUS.md`, Project Architect 3.0 since D-071) and
`docs/08_ROADMAP.md` Phase 2 (lines 102-189). Run `git fetch`, `gh pr list`, `docs/STATUS.md`.

## State: working (four coders: M2, M3, M4, M5)

## Who does what
This account has no Concept Lead: the session is lead AND Dev Lead under the original account's
rules. No peer sessions were alive on 2026-10-15; the team is run as builder subagents
(`subagent_type: builder`, Sonnet) spawned from this session, one task per life. Merge & CI work
(board PRs) goes to a builder brief too. Art Factory: PAUSED (director 2026-10-15: "Keep Art
paused", focus on the playable baseline). Its handoff: `../MERCS-wt/art-publish/agent-handoffs/art.md`.

## THE GOAL (director, 2026-10-14, D-063..D-071, brainstorm docs/brainstorms/2026-10-14-...)
Medium term: the horizontal slice, a playable baseline of every pillar, thin and structurally
sound (Phase 2, seven milestones in dependency order). Short term (parked): the vertical slice
look gate (orc + Vampyr). Each milestone ships in the F-key build; the director plays it and
says carry on or wrong. Entry condition of every milestone: its player-effect fixture passes.

## Done this session (2026-10-15)
- Merged #74 (roadmap rewrite, D-063..D-071) and #75 (milestone 1: F2 overworld, WorldSim,
  save v1) at matched heads after checking every suite ran (13 suites at floor). Main 38b2659
  green; Windows build at `Documents/GitHub/MERCS-builds/2026-10-15_m1_38b2659/MERCS.exe`
  (headless boot clean).
- Board PR #76 merged (8df923a): D-063..D-071 logged, Phase 2 items 1-2, Art paused, roadmap
  D-072 typo -> D-071. Local branch claude/board-after-75 remains (delete refused by settings).
- Pruned two stale clean worktrees (dual-desktop, loving-elgamal).

## Director today (2026-10-15) - record in a dated roadmap chapter via the next board PR
- "Start now" M2; "Keep Art paused"; "4 coders" (D-071 cap 2 -> 4); "get busy" (memory-shared
  run-the-team-at-full-width.md).
- M1 "is played. its good"; M2 "playtest is a success. clearly limited by the lack of combat
  infrastructure but it works".
- 4K TV bug: "the game needs to display on a 4k tv, i cant read any of the text its too small"
  -> FIXED in #83 (fullscreen, canvas_items 2x, 24 px theme, smoke checks). Build not yet sent.
- DESIGN GOAL: "moving around the world should be done manually, not in a menu, our band will
  navigate an overworld just like pokemon, procedurally generated maps like battle brothers with
  bespoke hand crafted locations and events and towns". His picks: smaller map scale with a cut
  to street scale in towns/locations; encounters are visible parties (engage, avoid, run).
- Pending from him: author merc_3..merc_6; confirm/reorder M3/M4; the veto lists in #80-#82.

## Running (builder subagents of this session; they die with it)
- Merged today: #80 M2, #81 M3, #82 M5, #83 4K, #84 gdlint gate, #85 M4 battle, #86 letter keys
  (no F-keys: M map, C company, L loop, H help, G frame time; smoke fails on KEY_F).
- Walkable overworld (Opus): p2-walk, claude/p2-overworld-walk. Told: SliceKeys, slice_game <=400.
- M6 hub/economy (Sonnet): p2-m6, claude/p2-m6-hub. Told: hub key B via SliceKeys.
- M7 storylet+memory (Sonnet): p2-m7, claude/p2-m7-storylet.
- Wiring (Sonnet): slice-m1, claude/p2-wiring (company fights road, hit->injury, triage panel).
- ART resumed (director "look target first"): Opus, art-look, claude/art-look-target (main + art
  branch merged). Deliverable: 2-3 labelled options (palette+light+post), each = street day, street
  night/rain at 4K in-engine, overworld strip at map scale; draft palettes in assets/palette/options/.
  Lead QCs (art-qa-critic) before the director sees boards; his pick becomes golden + master palette.
- QUEUED after his palette pick: Texel Studio trial (director yes 2026-10-15) for map-scale
  terrain tiles only: local Ollama, no concept-art (diffusion) step, palette-locked, licensing
  register row CLEARED first (its licence: outputs ours, internal use ok, no resale as a service).
  One strip from Texel vs the Blender rig, side by side, he picks. Rucol GAN repo rejected (no licence).
Traps: never `export APPDATA` (breaks gh, git creds, Python user site for gdtoolkit); set it on
the Godot command line only. gdlint/gdformat: `python -m gdtoolkit.linter|formatter`.
Director 2026-10-15: agents talk tersely (memory-shared terse-agent-messages.md).

## Next for the lead
0. Next free slot: the wiring task (company fights encounters, hits -> injuries, triage screen)
   once M4 and the walkable overworld merge; then the Phase 2 evidence pack.
1. Review M2 and M3 PRs (mercs-sim-review on the save keys, fixtures failing first, real taps),
   merge on green (merge_eligibility.sh once it lands), fetch the build, ask him to play.
2. Record his milestone verdicts the same turn; ask him to author the four placeholder mercs
   and to confirm or reorder milestones 3/4.
3. After M2+M3 merge: flip STRICT_FROM_PHASE/caps phase to 2 and fix the listed literals.
4. Then milestone 4 (battle skeleton) and 5 (wounds) as the next two coder slots.
5. Handoff lives on remote branch claude/lead-handoff-1015 (updated via gh api while all
   worktrees are busy); open a docs-only PR for it at session end.

## Suites (floors on main)
data 96, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 13, slice 15, battle 14,
loop 4, sim_world 9, save 7, effect 4, overworld 8.

## Worktrees (5 / 4, director allows forced removal of finished ones)
p2-walk, p2-m6, p2-m7, slice-m1 (wiring), art-look. Remove each when its PR merges.

## Co-lead playbook
playbook: nothing new (2026-10-15; no worker findings yet).

## Rules learnt the hard way (keep under 10 lines)
- REWRITE this file each time; never insert sections (doc-caps fails past 120 lines).
- tests.yml skips draft PRs: mark ready, THEN push.
- Before merging, read the shard log: every suite listed with its count, not just "green".
- Headless test windows are 64x64: size root to 1920x1080 before clicking GUI in a suite.
- `git show <ref>:file > file` writes LFS pointers for LFS paths; use `git lfs smudge`.
- A suite extending a script that fails to parse HANGS: `SUITE_TIMEOUT=120`; kill by PID.
- Typed GDScript: assign a Variant to a typed local before arithmetic, casts or `.get()`.
- `git fetch` and read `git log origin/main` before choosing or briefing any work.
