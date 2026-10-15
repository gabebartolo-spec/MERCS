# Dev Lead handoff, 2026-10-15 23:45 (desktop, personal account, "Game Studio Lead mercs")
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md), docs/plans/phase4_combat.md, docs/DECISIONS.md D-082..D-090,
~/.claude/skills/ai-slop-art/SKILL.md (+ learnings). Then `git fetch`, `gh pr list`, `gh run list`.

## State: working (Phase 4 combat merging via a steward; art critic loops). Director watching a
movie (23:14): "dont question me for a while" -> queue questions below, make team calls yourself.

## Who does what
Session = lead AND Dev Lead. Team = builder subagents (die with the session). D-090: parallel
Godot OK (GODOT=/c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe,
own APPDATA on the command only, offscreen, kill by PID); no builder ceiling for independent work.
Common builder rules for combat: scratchpad p4_common.md + p4_rulings.md (session scratch; copy the
rulings below into briefs if the scratchpad is gone).

## Director rulings tonight (log as D-091.. in the next board PR, branch docs/board-after-<n>)
- D-091 Combat depth first. Q-B weapons sword/axe/spear/mace/bow; armour leather/mail/plate.
- Q-A 1 weapon + 4 moves (no item slot). Q-C surrender when cornered or leader down. Q-D captain death
  = large morale fall (lead: + per-fighter resolve test). Q-E withdraw: position decides.
- Q-F captain sits out: no XP, small morale dip. Q-G blood at every hit, bodies stay. Q-H NOT ASKED.
- D-092 original MERCS typeface ("better to make a unique one"); "More grit in headings only".
- D-093 look B colours on the game screens: "Yes, use B" (#115 merged).
- D-094 levels: small growth + new moves (#120 merged). D-095 XP from fights: survive + kills.
- Lead calls: prisoners only from surrender; enemies get placeholder gear; weapon action replaces
  plain attack for classed fighters; level-2 XP 10->9 (placeholder balance); tile "hill" -> "rough".

## Merged since last handoff
#112 perf, #113 gate evidence, #114 battle split, #115 look B UI, #117 battle readable, #119 effect
fixtures (8 systems, 4 routes), #120 levels, #121 action kit. #110 Ironman notes.

## Open PRs (steward agent merges 122->123->124->125->126 in order, re-pinning goldens between)
- #122 P5 non-psychic AI: review OK + add merc_play to the hidden-read scan.
- #123 P2 morale/surrender/rout: review OK + broken-fighter intent fix + no-prisoner hub check.
- #124 P4 deploy-or-delegate: review OK once its flat fight_xp is REMOVED.
- #125 XP from fights: review OK; set level_xp[1]=9. #126 kit follow-ups: review running.
- #116 MERCS Ledger typeface: Regular SHIP, Display fixed after critic r2 -> director look question.
- #118 cast fix (orc/vampyr/tokens): round 2 pushed, fresh critic running.
- Running builders: P1b gear (claude/p4-p1b-gear), P6b blood (claude/p4-p6b-blood), tiles B5
  (shore + rough), goldens round 3 (claude/art-desloppify), cast critic, #126 review, steward.

## Queued for the director (ask when he's back, one at a time, with images)
1. Tile method board (after B5 critic SHIP): A Blender rig / B Claude-painted / C Retro Diffusion;
   hills + transitions labelled missing; heather needs a purple ramp (palette add?).
2. MERCS Ledger look approval: "is the heading voice grim enough?" (board_v2.png).
3. Cast look (after critic SHIP). 4. Goldens round 3 (after critic SHIP).
5. Balance notes for play review: captain fall breaks 4/6 mercs + all recruits (resolve 5 vs bar 6);
   sat-out dip 10; sergeant = most XP; Vampyr blood price fires less (432->257 over 300 fights).
6. Q-H hover odds: % or roll needed (before P7 action bar).
7. Gate playthrough build: MERCS-builds/2026-10-15_gate_2ea4632 (stale now; rebuild after merges).

## Art status (vault D:/MERCS-vault/renders/)
Tiles: B4 7/10 SHIP (grass, road, forest x2, water x2); B5 fixing shore + rough. Goldens: E best,
round 3 running. Typeface: typeface_2026-10-15. Cast: cast_fix_2026-10-15/round2. Slop audit
README in slop_audit_2026-10-15 (root A: the live game shows no art yet -> integrate after picks).
Palette: orc skin_orc_1 == commonest grass colour (separate in the dedupe palette PR).

## Worktrees: 14 live (over the cap of 4; D-090). Steward removes merged ones.

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`. Board PRs: branch `docs/board-after-<n>`; DECISIONS.md 392/400: roll to archive.
- PR [MERGE NOTE] must use bullets "- Review needed: none|done (...)" / "- Director gate: ...":
  scratch note.py rewrites them. "Base branch policy prohibits" = retry after 20 s.
- Floors conflicts: keep every suite line at the count the suite RUNS; effect id lists keep all ids.
- Sim PRs: fresh mercs-sim-review that plays the exploit in separate processes, then merge.
- Art: maker never passes own work; fresh critic SHIP/FIX; lead QC at 2x/6x; nothing slop reaches him.
- gdlint caps: 400 lines/file, 4 args/function, complexity 12: split, don't squeeze.
