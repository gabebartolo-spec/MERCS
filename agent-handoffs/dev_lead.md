# Dev Lead handoff, 2026-10-16 04:35 (desktop, personal account, "Game Studio Lead mercs")
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md), docs/plans/phase4_combat.md, docs/plans/phase5_contracts.md ("Decided"),
docs/DECISIONS.md D-091..D-112, ~/.claude/skills/ai-slop-art/SKILL.md. Then `git fetch`, `gh pr list`.

## State: working overnight. Director asleep since ~03:20 ("dont ask me more questions im going to bed").
Ask NOTHING until he writes again. Team calls are yours; taste calls go in the queue below.

## Who does what
Session = lead AND Dev Lead. Team = builder subagents (die with the session: check ListAgents).
Parallel Godot OK (D-090): GODOT=/c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe,
own APPDATA on the command only, offscreen, kill by PID. Builder rules: session scratchpad p4_common.md;
all rulings: scratchpad p4_rulings.md (copy into briefs if the scratchpad is gone; the board has them too).

## Decisions: logged in DECISIONS.md D-091..D-112 by board PR #137. Not yet logged (next board PR):
- Mercs 3-6 "I draft, you pick"; rabble kinds (peasant mobs, deserters, cultists, starving brigands);
  hit-stop "Subtle, a few frames"; orc "Bulk and green-grey skin"; grass "Darken to match golden";
  passed art "Yes, wire it in"; Q-16 sizeable advance = half the pay. D-094/D-095 verbatim words:
  "Small growth + new moves", "Fights: survive + kills" (his option picks).
- Lead calls: P1c lines (walls block, fighters don't, range 6); gear placeholders (armour 1/2/3, chief mace no
  armour, bandit_spearman; slice 117/200); share on the full agreed price; a deadline passed with an advance =
  abandon (C1 owns); job type drawn at posting; orc skin may use grass-failing steps inside the face only;
  orc skin bar CIEDE2000 >= 18 vs grass mass; rough terrain lighter than grass.

## Merged tonight (all with review + CI green)
#116 Ledger, #122-#127 combat depth (AI, morale, delegate, XP, kit, gear), #129 blood/bodies, #130 plan,
#131 handoff, #132 C0 economy split, #133 blood spray + hit-stop, #134 C4 reputation, #135 C3 wages,
#136 C2 negotiation, #137 board, #138 C1 jobs.

## Open PRs and running agents (04:35)
- #139 P1c ranged + spear reach: opened by the P1c builder; needs a fresh mercs-sim-review, then merge.
- #118 cast: round 5 painter running (orc moss skin #7e8a73, broad jaw/brow/tusks, Vampyr darker armour +
  cape lining front, golden lit grass -> verdure_mid_0 via cherry-pick of tiles-b6 99a1de4). Then a FRESH
  critic (opus builder + ai-slop-art; realism-critic refuses pixel art without photos). Critic notes:
  scratchpad crit118_r4/CRITIC.md.
- Tiles B8 painter running (heather shadow sides, rough lighter, road 15 px/luma 85, forest 0110 saddle),
  vault tile_trial_2026-10-15/B8_claude; palette branch claude/tiles-b6 (heather + verdure_mid_0). Then critic.
- Contracts builders running: C5 prisoners, C6 loot/armoury, C7 road + rabble + lethality ledger,
  C4b hunter parties, C8 hub screens (captures -> lead QC). Each PR -> fresh mercs-sim-review -> merge.

## Queued for the director (when HE writes; one at a time, with images)
1. Pick mercs 3-6: MERCS-builds/merc_candidates_2026-10-16.md (12 drafts, 3 per slot).
2. Overworld golden before/after (grass recolour, #118) - a golden changes only by his yes.
3. Cast look (after critic SHIP), tile board (after critic SHIP), contract screens (after lead QC).
4. Name each merc's bargaining trait (placeholders now: Vampyr silver tongue, Orc hard bargain).
5. Dead merc's unpaid wages: paid with the debt (now) or forfeit? Share of a kept advance on abandon?
6. Balance read after his playtest: Vampyr in plate never falls (424200-426400); death target 1 per 4.
7. Next playtest only after combat + art land (his ruling); fresh gate build then.

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`. Board PRs: branch `docs/board-after-<n>`. merge_eligibility needs PYTHONUTF8=1.
- PR body: ## Evidence, ## Not exercised, ## Board and log, [MERGE NOTE] bullets "- Review needed: none|done (...)"
  and "- Director gate: none|done (...)" (scratch note.py). Only a branch's owner pushes to it.
- Merge chains: re-run the FULL suite after every sync (playbook 2026-10-16). Hash-neutral PRs merge first.
- Sim PRs: fresh mercs-sim-review that plays the exploit in separate processes; cross-PR checks catch API drift.
- Art: maker never passes own work; fresh critic; lead QC at 2x; CIEDE2000 for figure-vs-ground.
- gdlint caps: 400 lines/file, 4 args/function, complexity 12. gdformat writes CRLF here: strip to LF.
