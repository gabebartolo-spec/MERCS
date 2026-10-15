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

## Director today (2026-10-15)
- "Start now" milestone 2 while he plays milestone 1.
- "Keep Art paused".
- "why do you only have 1 agent. get busy" -> run every slot (shared memory
  run-the-team-at-full-width.md).
- "4 coders" (raises D-071's two-coder cap to four; log it in the next board PR body).
- Merged since: #78 tools/merge_eligibility.sh (use it before every merge), #79 magic numbers
  are lint errors from Phase 2 (caps phase 2).
- Milestone 1 played: "milestone 1 is played. its good" (2026-10-15, 16:58) = carry on;
  log in the next board PR (STATUS: M1 review done).
- Pending from him: at milestone
  2's review: confirm or reorder milestones 3 and 4.

## Running (builder subagents of this session; they die with it)
- M2 encounters: `../MERCS-wt/p2-m2`, claude/p2-m2-encounters (Sonnet).
- M3 company (four placeholder mercs for him to author): `../MERCS-wt/p2-m3`, claude/p2-m3-company.
- M4 battle skeleton (Opus): `../MERCS-wt/slice-m1`, claude/p2-m4-battle. Keeps Battle's API.
- M5 wounds/triage/death/chronicle/succession, sim only, keyed by merc id:
  `../MERCS-wt/p2-m5`, claude/p2-m5-wounds.
Wiring after merges: company -> encounters, M4 hit hook -> M5 injuries, a triage screen.
If this session died: respawn each from its worktree with the same brief shape.

## Next for the lead
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

## Worktrees (5 / 4: over cap by one, see below)
p2-m2, p2-m3, p2-m5, slice-m1 (M4), art-publish (Art paused; clean, branch pushed at 99b3fdf).
Removing art-publish with --force (only .godot/.import untracked) was refused by the permission
classifier; ask the director to allow it or accept 5 while four coders run.

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
