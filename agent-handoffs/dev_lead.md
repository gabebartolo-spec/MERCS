# Dev Lead handoff, 2026-10-15 22:30 (desktop, personal account, "Game Studio Lead mercs")
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md), docs/08_ROADMAP.md Phase 4 (lines 229-266), docs/DECISIONS.md
D-082..D-090, ~/.claude/skills/ai-slop-art/SKILL.md. Then `git fetch`, `gh pr list`, `gh run list`.

## State: working (10 builders; Phase 4 Combat depth started; art desloppify)

## Who does what
No Concept Lead here: session = lead AND Dev Lead. Team = builder subagents (die with the session).
Director 22:13: "build faster ... summon more builders" (D-090): no 4-coder ceiling for independent
work; parallel Godot allowed (each own APPDATA, offscreen, kill by PID; "STOP OPENING GODOT" = stop all).

## Director tonight (all in D-082..D-090 or memory-shared)
- Combat depth is the first depth pass (answer 2026-10-15; log it as D-091 in the next board PR).
- "dont forget to actually build the game alongside the art".
- No slop: "brutal QA", "worlds leading expert on AI SLOP ART" -> skill ai-slop-art (+ slop_scan.py),
  memory-shared/no-slop-art-qa.md. Maker never passes own work; fresh critic decides SHIP/FIX.
- "add water colours" (D-089): water_deep #1c2a33, water_low #2e3e48, water_high #42565d,
  water_glint #a3b7ad; palette cap raised to core+biome <= 72 (lead), ships with the dedupe PR.
- Ironman option default On (D-087) - merged #103, #108; #110 in review.

## Merged today (since last handoff)
#100 look B palette+goldens, #101 gate gaps, #103 #108 Ironman, #104 tile tools, #106 handoff,
#107 board D-082..88, #109 board D-089/90. Gate build: MERCS-builds/2026-10-15_gate_2ea4632/MERCS.exe
(director told; not yet played). Gate needs his playthrough + Concept Lead audit (evidence PR coming).

## Running builders (report to main; check ListAgents if the session restarted - they die with it)
- p4 plan + battle.gd split (claude/p4-plan-split, ../MERCS-wt/p4-split): refactor (byte-identical
  logs) + docs/plans/phase4_combat.md with parallel work packages/file sets. NEXT: spawn one builder
  per package (actions+equipment, morale/surrender/rout, retreat+deploy-or-delegate, AI perception),
  each PR -> fresh mercs-sim-review -> merge.
- battle readability (claude/p4-battle-readable): audit row 1 (overlaps, duplicate clipped labels,
  3 pixel scales, "Unnamed" names). Presentation only.
- perf suite baseline (claude/p4-perf).
- look-B UI recolour (claude/look-b-ui): every game colour from palette, contrast >= 4.5:1;
  Director gate: look approval -> show him before/after captures.
- gate evidence pack (claude/p2-gate-evidence): docs/audits/phase2_gate/structural_evidence.md.
- #110 Ironman notes: sim review running (review110 worktree); merge on PASS.
- Art desloppify (claude/art-desloppify): goldens A/B(no dither)/C(+palette dedupe + water ramp,
  68 colours), vault D:/MERCS-vault/renders/desloppify_2026-10-15/. Then director A/B/C question.
- Art cast fix (claude/art-cast-fix): orc/vampyr sheets per slop audit rows 7-16; needs a FRESH critic.
- Tiles B3 repaint (vault tile_trial_2026-10-15/B3_claude) from B2 CRITIC.md (all 9 FIX); then a fresh
  critic; only SHIP goes on the board -> director tile-method question (A rig / B' Claude-painted / C RD).
- Font round 2 (vault font_trial_2026-10-15/board_r2.png): Tiny5 only legible so far; CC0/MIT allowed.

## Findings to act on
- Slop audit (D:/MERCS-vault/renders/slop_audit_2026-10-15/README.md): 18/19 FIX. Root A: the live game
  shows none of the art (mannequins, blockout, stock UI). Root B: golden dither. Each row has a fix.
- Texel Studio: local Ollama failed; free Gemini made weak tiles (quota 20/day). Server stopped. Claude
  painting with Texel's Canvas (B') is the working method. Install: D:/MERCS-vault/tools/texel-studio.
- Retro Diffusion: US$1.02 of US$10 spent; water fails; ~/.claude/skills/retro-diffusion learnings.

## Worktrees (over 4; director D-090 "dont bottleneck"): p4-split, p4-readable, p4-perf, look-b-ui,
gate-evidence, ironman-notes, review110, art-desloppify, art-cast. Remove each on merge
(`git worktree remove --force` alone, not chained).

## Co-lead playbook
playbook: updated 2026-10-15 (CI LFS; gitleaks 8.24.3; persistence tests must replay the exploit).
ai-slop-art learnings: scan passes but eye fails -> 6x6 1x repeat + variant-identity measure.

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`: set it on the Godot command only.
- Board PRs: branch `docs/board-after-<n>` (not claude/); DECISIONS.md at 392/400: roll oldest to archive.
- PR bodies need `## Evidence` and `## [MERGE NOTE]` (Hot files, Floors, Review needed, Director gate,
  Ordering) or merge_eligibility refuses. If merge says "base branch policy prohibits", retry in 20 s.
- Every merge: `bash tools/merge_eligibility.sh <pr>` then `gh pr merge --squash --match-head-commit`.
- Sim PRs: fresh mercs-sim-review that PLAYS the exploit in separate processes, then "Review needed: done".
- Lead QCs every art return at 2x/6x; fresh critic for agent-made art; nothing slop reaches him.
- gdlint/gdformat: `python -m gdtoolkit.linter|formatter`. tests.yml skips drafts: mark ready first.
- Windows env OLLAMA_MODELS (Ollama's folder) overrides tool .env files: set per process.
