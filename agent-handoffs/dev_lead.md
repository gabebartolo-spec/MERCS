# Dev Lead handoff, 2026-10-15 (desktop, personal account, "Game Studio Lead mercs")
Start from this file, CLAUDE.md, `~/.claude/memory-shared/MEMORY.md`, the co-lead playbook,
your brief (`agent-briefs/DEV_LEAD_OPUS.md`, Project Architect 3.0 since D-071) and
`docs/08_ROADMAP.md` Phase 2 (lines 102-189). Run `git fetch`, `gh pr list`, `docs/STATUS.md`.

## State: working (milestone 2 builder running; awaiting the director's milestone 1 play)

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
- Board PR #76 (D-063..D-071, Phase 2 items, roadmap D-072 typo -> D-071): builder pushing a
  second commit with today's rulings; lead merges when green.
- Pruned two stale clean worktrees (dual-desktop, loving-elgamal).

## Director today (2026-10-15)
- "Start now" milestone 2 while he plays milestone 1.
- "Keep Art paused".
- Pending from him: milestone 1 verdict (play F2: road, rest, save, reopen). Also at milestone
  2's review: confirm or reorder milestones 3 and 4.

## Running
- Builder on milestone 2 (encounters: ambush with enemy first, patrol with fight-or-toll; new Rng
  stream "encounter"; pending encounter in the save with a default; fixtures: different road ->
  different encounter, chance 0 vs on). Worktree `../MERCS-wt/p2-m2`, branch
  claude/p2-m2-encounters. Its PR needs my mercs-sim-review (save shape) before merge, then a
  build for the director.

## Next for the lead
1. Merge #76 when green at its head. 2. Review the milestone 2 PR (sim review on the save,
   fixtures failing first, real taps), merge on green, fetch the build, ask him to play it.
3. Record his milestone verdicts the same turn (board PR body + this file).
4. Brief milestone 3 (six mercs in data, roster, captain, inspect screen) after his M2 verdict
   and his 3/4 order call.
5. Set `STRICT_FROM_PHASE = 2` in tools/lint/magic_numbers.py and caps phase 2 in a milestone
   PR (Concept Lead recommendation in #74/#75).

## Suites (floors on main)
data 96, smoke 24, stage 43, stage_scale 11, stage_light 8, assets 13, slice 15, battle 14,
loop 4, sim_world 9, save 7, effect 4, overworld 8.

## Worktrees (4 / 4)
`../MERCS-wt/slice-m1` (mine, branch claude/lead-handoff-1015), `../MERCS-wt/board` (#76),
`../MERCS-wt/p2-m2` (milestone 2), `../MERCS-wt/art-publish` (Art, paused). Remove board and
p2-m2 when their PRs merge.

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
