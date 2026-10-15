# Dev Lead handoff, 2026-10-16 10:52 (desktop, personal account, "Game Studio Lead mercs")
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md), docs/plans/phase5_contracts.md ("Decided"), docs/DECISIONS.md D-091..D-112,
~/.claude/skills/ai-slop-art/SKILL.md. Then `git fetch`, `gh pr list`, `git worktree list`.

## State: working. Director was back 09:43-10:26, answered the queue, then "afk, no more questions for now".
Ask NOTHING until he writes again. Team calls are yours; taste calls go in the queue below.

## Who does what
Session = lead AND Dev Lead. Team = builder subagents (die with the session: check ListAgents).
Godot: /c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe, own APPDATA on
the command only, kill by PID. Rules for builders: session scratchpad p4_common.md; all rulings: scratchpad
p4_rulings.md (copy into briefs if the scratchpad is gone).

## Director rulings today 09:43-10:26 (NOT yet in DECISIONS.md: next board PR logs them verbatim)
- Mercs 3-6: Wren (slot 3), Gauda Kettle (4), Ser Ambrose Vell (5), Yaro Sedlak (6), as drafted in
  MERCS-builds/merc_candidates_2026-10-16.md. Bargaining traits: theirs as drafted; Orc "Hard bargain" and
  Vampyr "Silver tongue" placeholders kept.
- Grass: "B: new grass" (shipped #151). Ref photos: yes to ~12 free-licence downloads (done, D:/MERCS-vault/refs/).
- Cast r7 REJECTED: "both look awful. both of their heads are featureless stumps and their postures are bizarre
  and unnatural". #118 is draft, on hold, not synced.
- Contract screens: "Merge as working panels" (styled look later, own look gate) (shipped #145).
- Lethality: "Downed die 1 in 3" (shipped #154; 0.30 -> 0.88 named deaths per 4 fights).
- Dead merc's unpaid wages: "Forfeit". Kept advance on abandon: "No share" (shipped #153).
- Advance farm: "Walk out, no more advances" (shipped #155).
- Faction/place names: "You draft, I pick" (drafts ready: MERCS-builds/faction_place_candidates_2026-10-16.md).
- Death-roll edit: permission system refused the builder; director said yes to the lead making it (done in #154).

## Merged today
#150 GUI clicks, #151 grass B, #152 baseline tune (economy 119% of bill, sergeant+4 patrol from day 8),
#153 wages forfeit, #145 C8 contract screens, #154 death roll 1 in 3, #155 walk-out closes advances + old-save forfeit.

## Running (10:52)
- Orc hand-painted figure study (opus builder): method change after two failed render-based rounds (r7, and
  cast_study_2026-10-16 which failed lead QC). Paints at r7 height ~122 px, head ~15-16 px. Output
  D:/MERCS-vault/renders/cast_paint_2026-10-16/. Next: fresh realism-critic with D:/MERCS-vault/refs/photos_2026-10-16/,
  then lead QC at 1x/2x judging the READ (face? natural stance?) before any metric; then the director.
- Heather B11 painter: critic B10c said FIX (bramble/grape read, 64-px lattice, too blue, 1-px bridged crowns, hard
  edges). Lead allowed full variants v4/v5. Next: fresh critic WITH the moorland photos, then the director's board.
- no-advance-line builder: terms screen shows hub.terms.no_advance and disables the advance buttons when
  Terms.advance_open is false. Review needed: none; merge via mq after CI.

## Queued for the director (when HE writes; one at a time, with images)
1. Faction/place names (2 factions, hub, 3 hamlets, 3 wild sites). Flag: caps allow 2 factions, palette has 3
   heraldry pairs; patrols already draw in blue.
2. Orc painted figure (after critic + lead QC). 3. Heather board (after critic SHIP).
4. Balance, after his playtest: reopen loop still farms 56-110% of the bill (upper bound); patrols #1/#2 lost
   83-85% with ~1 death per fight (hardness unchanged since spear reach).
5. Next playtest only after combat + art land; fresh gate build then.

## Housekeeping
- Worktrees: 12 live (limit 4). My `git worktree remove` was refused by the permission system; do not retry
  blindly. Merged and removable: grass-b, baseline, c8, death-roll, wages-forfeit, walkout-advance, handoff5 (after
  merge). Keep art-cast (#118 record), tiles-b6, art-desloppify (check), no-advance-line (open).
- Follow-ups: armoury buy/sell screen (new UI, look gate); C2/C4 memory_key list is hand-written; hub_pack.gd.uid
  not committed; no test for speaker_hope.m/f lines; next board PR (rulings above + D-094/D-095 words).

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`. Board PRs: branch `docs/board-after-<n>`. merge_eligibility needs PYTHONUTF8=1.
- PR body: ## Evidence, ## Not exercised, ## Board and log, [MERGE NOTE] "- Review needed: ..." and
  "- Director gate: ..." (scratch note.py). Merge chain: scratch chain.sh (sync, full suite, push, mq).
- Re-run the FULL suite after every sync in a merge chain. Builder numbers can be stale after a sync: reviewers re-measure.
- Art: judge the READ first (is that a face, does it stand like a person, beside a real photo); metrics never pass art.
- A subagent's refused action is never redone by the lead without the director's explicit yes.
- gdlint caps: 400 lines/file, 4 args/function, complexity 12. gdformat writes CRLF here: strip to LF.
