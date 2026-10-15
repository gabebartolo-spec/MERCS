# Dev Lead handoff, 2026-10-15 21:05 (desktop, personal account, "Game Studio Lead mercs")
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md, Project Architect 3.0, cap FOUR coders), docs/08_ROADMAP.md
Phase 2 (lines 102-189), docs/STATUS.md, docs/DECISIONS.md (D-082..D-088 are today's).
Then `git fetch`, `gh pr list`, `gh run list`.

## State: working (Ironman reroll fix, Texel Studio install, board PR #105)

## Who does what
No Concept Lead in this account: the session is lead AND Dev Lead. The team is builder
subagents of this session (Sonnet; Opus for judgement and art), one task per life; they die with
the session. Agents talk tersely (D-081). Art = a builder on Opus.

## Phase 2 (horizontal slice): ALL MILESTONES MERGED
#75 #80 #81 #82 #85 #87 #89 #93 #90; #98 campaign ends on wipe; #97 gate pack
(docs/audits/phase2_gate/README.md); #101 gate gaps (sim review PASS WITH NOTES). Director played
the full loop: "playtest was good carry on" (D-084). Last build 2026-10-15_loop_674c749 is pre
#98/#101/#103: rebuild from main before his gate playthrough.

## Open PRs
- #103 Ironman (claude/ironman, `../MERCS-wt/ironman`, head 20de67b green). D-087: option at
  campaign start, default On. Lead found a hole: the fight-start autosave is after the battle roll,
  so a mid-fight quit rerolls the fight. A builder is fixing it (reload = same fight, no toll
  re-offer, test shown failing first). Then: spawn an independent mercs-sim-review (Opus builder,
  read-only, posts PR comment), set "Review needed: done", merge via merge_eligibility.
- #105 board-after-104 (DECISIONS D-082..D-088, STATUS refresh): background watcher merges on green.
- #77 Concept Lead handoff (other account's; leave it).

## Look and art
- Look B "Peat and Ochre" locked (#100): assets/palette/core.* (44) + biomes/heartland.* (64 total);
  goldens assets/golden/{street_day,street_rain_night,overworld_map}.png. Game scenes still grey-box.
- Terrain-tile trial (D-080/D-082/D-088), vault D:/MERCS-vault/renders/tile_trial_2026-10-15/:
  spec 64 px tiles (golden texel density; game tile_px 16 must change: raise with the pick).
  A = Blender/Godot rig (`tools/look/render_tiles.gd`): seams clean; 35° sun = black forest, hill
  craters; 64 px repeat. C = Retro Diffusion (lead, browser; US$1.02 spent, balance 8.98;
  C_retro/picks + provenance.md): grass/heath/shore/forest ok, water failed 6x (bands/scenes),
  road seams. Board: board/tile_board_{1x,2x}.png (`tools/look/tile_board.py`). DEFECT before he
  sees it: C's road tile is N-S inside an E-W mixed map: rotate it on the board.
- B = Texel Studio (director: "Allow the install", D-088): cloned at cde7bdd into
  D:/MERCS-vault/tools/texel-studio; venv pip install + frontend build running in background
  (task b447gij2z); Ollama model ggml-org/gemma-4-E4B-it-GGUF:Q8_0 pulled. Next: .env
  OLLAMA_MODELS=that model, run `venv/Scripts/python server.py` (localhost:8500), make the 6 tiles
  at 64 px with the core+heartland palette, add row B to the board (fix C's road too), lead QC,
  then ONE question to the director with the labelled board (method pick).
- Then: pixel UI font sheet (06 §7 [D]); fresh build for the gate playthrough.

## Waiting on the director
Author merc_3..6, recruits, both factions, the storylet's words; veto tables (gate pack);
confirm/reorder M3/M4; the Phase 2 gate playthrough; the tile method pick (after board B).

## Worktrees (1/4)
ironman (#103). Remove with `git worktree remove --force` alone (D-079), not chained.

## Co-lead playbook
playbook: updated 2026-10-15 (CI LFS pointers; gitleaks 8.24.3 allowlist). retro-diffusion
learnings: first entry 2026-10-15 (4x blocks, snap after palette lock, 32 px tileset cap, water).

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`: set it on the Godot command only (breaks gh, git creds, Python user site).
- gdlint/gdformat: `python -m gdtoolkit.linter|formatter`; CI requires both (merge_eligibility).
- Handoff/board PR bodies need `## Evidence` and `## [MERGE NOTE]` (Hot files, Floors, Review
  needed, Director gate, Ordering) or merge_eligibility refuses. Copy #99's body.
- Every merge: `bash tools/merge_eligibility.sh <pr>` then `gh pr merge --match-head-commit`.
- Sim PRs: independent mercs-sim-review verdict posted, then "Review needed: done".
- Director gate line: "none blocking; play review after merge (D-064)" or "done (... D-id)".
- tests.yml skips drafts: mark ready, then push. Headless windows are 64x64: size root first.
- Images tests load stay plain git, not LFS (CI has no LFS).
- Lead QCs every art return at 2x before merge (#100's water read as a road; sent back, fixed).
