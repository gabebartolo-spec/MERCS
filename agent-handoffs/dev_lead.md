# Dev Lead handoff, 2026-10-16 04:50 (desktop, personal account, "Game Studio Lead mercs")
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

## Open PRs and running agents (04:50)
- #139 P1c ranged + spear reach: review APPROVE; builder adding the diagonal corner-gap fix (line_clear checks
  side cells), then merge on green.
- Stall fix builder (claude/p4-ai-path, starts after #139 merges): 29/300 random fights never ended (AI walk
  stuck behind walls). PRIORITY before the playtest; adds a fight-length audit check.
- #118 cast round 5 pushed (671f992); fresh critic running (crit118_r5). Lead concerns: orc head reads as a
  box/bucket helm; skin pale sage; Vampyr dark cuirass reads as a hole.
- Tiles B9 painter running (heather calmer |dx|<=10, rough 2-4 clumps + no fixed boulder, road_v2). Shipped
  so far: grass, water, shore, forest. Palette branch claude/tiles-b6 (heather + verdure_mid_0; #118 also
  carries it).
- Contracts builders running: C5 prisoners (reaction data placeholder), C6 loot/armoury, C7 road + rabble +
  ledger (line-ups by place/day), C4b hunters (one party per broken deal, fights once), C8 hub screens.
- Follow-ups queued: GUI test click helpers press only "attack" (armed mercs press Wait since #126) -> click
  kit[0] after #139; paired win-rate audit (watch spears now 2 cells).

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
