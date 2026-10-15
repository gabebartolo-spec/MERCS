# Dev Lead handoff, 2026-10-15 18:58 (desktop, personal account, "Game Studio Lead mercs")
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md, Project Architect 3.0, cap FOUR coders), docs/08_ROADMAP.md
Phase 2 (lines 102-189), docs/STATUS.md, docs/brainstorms/2026-10-15-director-comments.md.
Then `git fetch`, `gh pr list`, `gh run list`.

## State: working (Art water fix on #100, Ironman coder running)

## Who does what
No Concept Lead in this account: the session is lead AND Dev Lead. The team is builder
subagents of this session (Sonnet; Opus for judgement work), one task per life; they die with the
session. Agents talk tersely (memory-shared terse-agent-messages.md). Art = a builder on Opus.

## Phase 2 (horizontal slice): ALL MILESTONES MERGED 2026-10-15
#80 encounters, #81 company (save v2, C), #82 wounds, #85 battle skeleton, #87 hub/economy (B),
#89 storylet+memory, #93 walkable overworld (M), #90 wiring, #98 campaign ends on wipe,
#97 gate pack (docs/audits/phase2_gate/README.md), #101 gate gaps (replay check, save refused
mid-fight/triage, names in memories, B/C panels, white seen-ring; sim review PASS WITH NOTES).
Also #83 4K display, #84 gdlint required, #86 letter keys, #91 validate_pixels (D-035).
Director played M1, M2 and the full loop: "playtest was good carry on".
Last build: Documents/GitHub/MERCS-builds/2026-10-15_loop_674c749/MERCS.exe (pre #98/#101).
Gate = Concept Lead's structural audit (other account) + his one playthrough (rebuild first).

## Open PRs and running builders
- #100 art lock look B (claude/art-look-target, `../MERCS-wt/art-look`): green at 1ffe90c, held by
  lead QC: overworld golden's water reads as an asphalt road (flat grey, square kerbs, white lane-like
  line). Fresh Opus Art builder re-rendering it; on its report: 2x-crop check, CI green, merge.
  PR delivers core.gpl (44) + biomes/heartland (64 total), goldens street_day/rain_night/overworld.
  Not done: game scenes still grey-box; pixelate.json default still master_draft.
- Ironman coder (claude/ironman, `../MERCS-wt/ironman`): director 2026-10-15 "Ironman as an option",
  default On (lead's pick; he may overturn). On = autosave at fight start + after Continue. Plus
  #101 review notes: test the save_run guard, reload-continues-identically check, MapCover when a
  fight starts with B/C open. Needs mercs-sim-review by another agent before merge.

## Next after #100 merges
Tile trial on B (heartland): Retro Diffusion (US$10 prepaid, his written yes; logged into the
built-in browser pane; lead drives it; skill ~/.claude/skills/retro-diffusion; download at
ORIGINAL size; check the first output's public flag) vs Texel Studio (local Ollama, licensing row
first) vs the Blender rig. Bring a pixel UI font sheet (06 §7 [D]). Then a fresh build for his
gate playthrough.

## Waiting on the director
Author merc_3..6, recruits, both factions, the storylet's words (placeholders in data); veto
tables (gate pack); confirm/reorder M3/M4; the Phase 2 gate playthrough.

## Next board PR must log (branch claude/board-after-<n>)
Retro Diffusion US$10 spend yes; campaign ends on wipe; full-loop playtest pass; lighting +5%;
fidelity note; look B (D-TBD-look-target-b); palette = core + biomes; Ironman option, default On.

## Worktrees (2/4)
art-look (#100), ironman. Remove each when its work merges (`git worktree remove --force` alone,
not chained; local branch claude/p2-gate-gaps still to delete).

## Co-lead playbook
playbook: updated 2026-10-15 (CI LFS pointers -> corrupt PNG; gitleaks 8.24.3 allowlist trap).

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`: set it on the Godot command only (breaks gh, git creds, Python user site).
- gdlint/gdformat: `python -m gdtoolkit.linter|formatter`; CI requires both (merge_eligibility).
- Handoff on a branch is deleted on merge: each update = new branch from main + PR; keep <=120 lines.
- Every merge: `bash tools/merge_eligibility.sh <pr>` then `gh pr merge --match-head-commit`.
- Before merging a sim PR: post the mercs-sim-review verdict, set Review needed: done.
- Director gate line: "none blocking; play review after merge (D-064)" (else eligibility refuses).
- tests.yml skips drafts: mark ready, then push. Headless windows are 64x64: size root first.
- Captures at 3840x2160 offscreen (--windowed --position 8000,8000) before he looks.
- Images tests load stay plain git, not LFS (CI has no LFS).
