# Dev Lead handoff, 2026-10-19 (clean handoff to the other account)
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md), docs/plans/demo_release.md (Task 0 first), docs/plans/phase5_contracts.md
("Decided"), docs/DECISIONS.md D-091..D-117, ~/.claude/skills/ai-slop-art/SKILL.md.
Then `git fetch`, `gh pr list`, `git worktree list`.

## State: PAUSED, awaiting director
Director 2026-10-18: "neither, comit the plan and pause". Demo release plan merged (#159). No execution
method chosen. Nothing of mine is running: no builders, no Godot PID, no GPU/Tripo job, no CI watch.
Next, only when the director says go: demo plan Task 0, six questions (DD-1..DD-6), one at a time via
ask-the-director, recommended option first; record answers verbatim for the next board PR. DD-1 public
or paid release = stop and re-plan Tasks 16-17 with him.

## Branch and commit
main = fdc78d7 (#160). This handoff: branch claude/handoff-1019, PR (see `gh pr list`). No code PR open.
Open PRs not mine to act on: #118 (art cast, DRAFT, on hold after r7 reject), #77 (concept lead handoff).

## Unfinished work (all stopped at the pause; resume only when assigned)
- Orc hand-painted figure study: rounds 4-6 in D:/MERCS-vault/renders/cast_paint_2026-10-16/. Round 6 SE
  checked by lead: hump and shield gone. Still to do: S polish, boards, fresh realism-critic with
  D:/MERCS-vault/refs/photos_2026-10-16/, lead QC at 1x/2x judging the READ, then the director.
- Heather B11: seed re-pick for v2-v5 STOPPED (processes killed by PID); v2-v5 seeds invalid
  (log shows "heather_v3 NO SEED in 1-700"). Rerun `bash _wip/repick_b11.sh heather_v2 heather_v3
  heather_v4 heather_v5` in D:/MERCS-vault/renders/tile_trial_2026-10-15/B11_claude/, log
  _wip/b11g_repick.txt; then rebuild x2, checks, board, fresh critic WITH moorland photos.
  Critic B10c verdict was FIX (bramble/grape read, 64-px lattice, too blue, 1-px bridged crowns, hard edges).
- Both art items need a GPU/helper; the 2026-10-18 shift had no Godot, Tripo or Blender access.

## Director rulings 2026-10-16 09:43-10:26 not yet in DECISIONS.md (next board PR logs them verbatim)
- Mercs 3-6: Wren (3), Gauda Kettle (4), Ser Ambrose Vell (5), Yaro Sedlak (6), as drafted in
  MERCS-builds/merc_candidates_2026-10-16.md. Bargaining traits as drafted; Orc "Hard bargain" and Vampyr
  "Silver tongue" placeholders kept.
- Cast r7 REJECTED: "both look awful. both of their heads are featureless stumps and their postures are
  bizarre and unnatural". #118 is draft, on hold, not synced.
- Faction/place names: "You draft, I pick" (drafts: MERCS-builds/faction_place_candidates_2026-10-16.md).
- Death-roll edit: builder was refused; director said yes to the lead making it (done in #154).
Check D-113..D-117 first: some of the 10-16 rulings (grass B, contract screens, lethality, wages forfeit,
no share, walk out) may already be logged there; log only what is missing.

## Queued for the director (when HE writes; one at a time, with images)
1. Demo Task 0 (DD-1..DD-6; DD-6 is the faction/place names: 2 factions, hub, 3 hamlets, 3 wild sites.
   Flag: caps allow 2 factions, palette has 3 heraldry pairs; patrols already draw in blue).
2. Orc painted figure (after critic + lead QC). 3. Heather board (after critic SHIP).
4. Balance, after his playtest: reopen loop still farms 56-110% of the bill (upper bound); patrols #1/#2
   lost 83-85% with ~1 death per fight.
5. Next playtest only after combat + art land; fresh gate build then.

## Housekeeping
- Worktrees: 12 live (limit 4). `git worktree remove` was refused by the permission system last shift;
  ask the director before retrying. Merged and removable: grass-b, baseline, c8, death-roll,
  wages-forfeit, walkout-advance, no-advance-line (#157), handoff5 (#160). Keep art-cast (#118, ~198
  dirty files), art-desloppify (~200 dirty, 5 commits ahead: check before any removal), tiles-b6
  (clean, 2 ahead, unmerged).
- At 2026-10-19 three Godot processes were running (PIDs 13728, 28432, 3392) that this role did not
  start: not ours, never kill them.
- Follow-ups: armoury buy/sell screen (new UI, look gate; demo Task 5); C2/C4 memory_key list is
  hand-written; hub_pack.gd.uid not committed; no test for speaker_hope.m/f lines; next board PR
  (rulings above + D-094/D-095 words).
- Playbook: nothing new this shift.

## Who does what
Session = lead AND Dev Lead. Team = builder subagents (die with the session: check ListAgents).
Godot: /c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe, own
APPDATA on the command only, kill by PID. Builder rules lived in the old session scratchpad
(p4_common.md, p4_rulings.md); they are gone with it: rebuild briefs from CLAUDE.md and this file.

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`. Board PRs: branch `docs/board-after-<n>`. merge_eligibility needs PYTHONUTF8=1.
- PR body: ## Evidence, ## Not exercised, ## Board and log, [MERGE NOTE] "- Review needed: ..." and
  "- Director gate: ...". Merge chain: sync, full suite, push, merge queue.
- Re-run the FULL suite after every sync in a merge chain. Builder numbers can be stale after a sync.
- Art: judge the READ first (is that a face, does it stand like a person, beside a real photo); metrics never pass art.
- A subagent's refused action is never redone by the lead without the director's explicit yes.
- gdlint caps: 400 lines/file, 4 args/function, complexity 12. gdformat writes CRLF here: strip to LF.
