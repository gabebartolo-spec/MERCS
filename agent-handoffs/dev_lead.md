# Dev Lead handoff, 2026-10-16 03:15 (desktop, personal account, "Game Studio Lead mercs")
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md), docs/plans/phase4_combat.md, docs/plans/phase5_contracts.md,
docs/DECISIONS.md D-082..D-090, ~/.claude/skills/ai-slop-art/SKILL.md. Then `git fetch`, `gh pr list`.

## State: working overnight. Director went to bed 03:13: "dont ask me more questions im going to bed".
Ask NOTHING until he writes again. Make team calls yourself; table taste calls below.

## Who does what
Session = lead AND Dev Lead. Team = builder subagents (die with the session: check ListAgents).
D-090: parallel Godot OK (GODOT=/c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe,
own APPDATA on the command only, offscreen, kill by PID). Builder rules: session scratchpad
p4_common.md; all rulings below (copy them into briefs if the scratchpad is gone).

## Director rulings (log as D-091..D-1xx in the next board PR, branch docs/board-after-<n>)
- 2026-10-15: D-091 combat depth first; weapons sword/axe/spear/mace/bow; armour leather/mail/plate;
  1 weapon + 4 moves; surrender when cornered or leader down; captain death = large morale fall;
  withdraw: position decides; captain sits out: no XP, small dip; blood every hit, bodies stay.
  D-092 own typeface, grit in headings. D-093 look B colours. D-094 small growth + new moves. D-095 XP survive+kills.
- 2026-10-16 interview: captain's fall breaks ABOUT HALF (placeholder resolves 4/5/6/6, done in #123);
  sit-out dip 10; sergeant = most XP; blood price frequency left; hover odds = PERCENTAGE;
  Ledger B "Ship B" (#116 merged); build ranged next (P1c) + spears real 2-cell reach; tiles method B'
  (Claude-painted); heather = 3 muted purples; orc skin -> grey-olive; next playtest AFTER combat merges
  AND art lands; next depth pass = Contracts and the road; prisoners ransom/recruit/release/execute;
  loot = worn gear; armour strong but costly (slower + price/upkeep); a named death every few fights
  (target 1 per 4); company cap 8; road fights 4-8 soldiers, up to 12-16 if rabble (weak kind).
- Contracts (Q-1..Q-16, all in docs/plans/phase5_contracts.md "Decided"): 6 deploy + 2 reserve; share
  of contract pay, split BY LEVEL; daily wage by level; terms negotiated ("you must negotiate"): advance
  vs on return + a merc steps in with a trait the director names; reputation PER FACTION; hunters only
  on abandoning after an advance of half the pay or more, growing with the grudge; towns buy and sell;
  worn = one point weaker; prisoner recruit left out "Not until you design it".
- Lead calls: P1c lines (walls block arrows/spears, fighters block neither, range 6 in data); #127 gear
  placeholders retuned to keep the slice 89-109/200 wins; orc skin option A (golden grass remapped to
  verdure); P6c impact (pasted brief): deterministic, no physics raycasts, hit-stop presentation only.

## Merged tonight
#116 Ledger, #122 non-psychic AI, #123 morale/surrender, #124 deploy-or-delegate, #125 XP from fights,
#128 handoff, #129 blood and bodies (lead QC r3 PASS), #130 contracts plan.

## Open PRs and running agents (03:15)
- Steward: merging #126 (kit follow-ups + wait fallback) then #127 (gear: initiative display from one
  source, placeholder retune, gear-off golden check). Reviews done (scratchpad review126/127.md).
- #118 cast round 3 (orc/vampyr/average_m repaint + grey-olive skin + golden remap): painter running,
  CI was red (test, plan) - painter told. Then a FRESH critic (opus builder briefed with ai-slop-art;
  realism-critic refuses pixel sprites without photos).
- Tiles B6 (D:/MERCS-vault/renders/tile_trial_2026-10-15/B6_claude, palette branch claude/tiles-b6
  92249fd, heather 3 colours, no PR yet): fresh critic running. Missing: hills, shore corners, road
  bends; water ramp (D-089) not yet in repo palette; grass luma 80 vs golden 71 (critic judges).
- P1c ranged + spear reach: waits for #127 to merge, then claude/p4-p1c-ranged.
- P6c blood spray + hit-stop: waits on #129 (merged) -> building claude/p4-p6c-impact.
- C0 economy split + route goldens: claude/c0-economy-split.

## Next steps
1. Merge #126, #127; then P1c, P6c, C0 PRs each after its review (sim review for P1c/C0; lead QC P6c).
2. Cast and tiles: critic loop until SHIP; then palette PR (heather + water ramp + grey-olive) and
   wire the art into the live game (slop audit root A: the game shows no art yet).
3. Board PR: D-091..D-1xx from the rulings above; roll the oldest DECISIONS entries to the archive.
   Add the "Run result: OBSERVED|NOT VERIFIED|N/A" line to the PR template (playbook TRIAL 2026-10-16).
4. Contracts C1-C4 after C0. Fresh gate build only when combat + art have landed (his ruling).

## Queued for the director (when HE writes again; one at a time, with images)
- Cast look and goldens round 3 (after critic SHIP). Tile board B6 (after SHIP). Name each merc's
  bargaining trait (contracts Q-8). Balance read after his playtest.

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`. Board PRs: branch `docs/board-after-<n>`; DECISIONS.md 392/400: roll to archive.
- PR body needs ## Evidence, ## Not exercised, [MERGE NOTE] bullets "- Review needed: none|done (...)" /
  "- Director gate: none|done (...)" (note.py). merge_eligibility needs PYTHONUTF8=1 on Windows.
- Floors conflicts: keep every suite line at the count it RUNS. Only a branch's owner pushes to it
  (auto-fix events on steward-owned PRs go to the steward).
- Sim PRs: fresh mercs-sim-review that plays the exploit in separate processes, then merge.
- Art: maker never passes own work; fresh critic; lead QC at 2x; nothing slop reaches him.
- gdlint caps: 400 lines/file, 4 args/function, complexity 12: split, don't squeeze.
