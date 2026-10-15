# Dev Lead handoff, 2026-10-15 18:24 (desktop, personal account, "Game Studio Lead mercs")
Start: this file, CLAUDE.md, ~/.claude/memory-shared/MEMORY.md + co-lead-playbook.md, your brief
(agent-briefs/DEV_LEAD_OPUS.md, Project Architect 3.0, cap FOUR coders), docs/08_ROADMAP.md
Phase 2 (lines 102-189), docs/STATUS.md, docs/brainstorms/2026-10-15-director-comments.md.
Then `git fetch`, `gh pr list`, `gh run list`.

## State: working (look-target fixes, gate pack, campaign end running)

## Who does what
No Concept Lead in this account: the session is lead AND Dev Lead. The team is builder
subagents of this session (Sonnet; Opus for judgement work), one task per life; they die with the
session. Agents talk tersely (memory-shared terse-agent-messages.md). Art = a builder on Opus.

## Phase 2 (horizontal slice): ALL MILESTONES MERGED 2026-10-15
#80 encounters, #81 company (save v2, C), #82 wounds, #85 battle skeleton, #87 hub/economy (B),
#89 storylet+memory, #93 walkable overworld (M; tile region, locations.json, visible parties),
#90 wiring (company up to 6 fights parties, triage, dead stay dead). Also #83 4K display, #84
gdlint required, #86 letter keys (no F-keys), #88 board, #91 validate_pixels (D-035 no mixels).
Director played M1, M2 and the walk/full-loop build: "playtest was good carry on".
Full-loop build: Documents/GitHub/MERCS-builds/2026-10-15_loop_674c749/MERCS.exe.

## Running (builders)
- Gate pack: `../MERCS-wt/slice-m1`, claude/p2-gate-pack: blocked-step feedback + docs/audits/
  phase2_gate/ (what to play, veto table, placeholders, 4K captures, structural self-check).
  Then the gate = Concept Lead's structural audit (other account) + his one playthrough.
- Campaign end: `../MERCS-wt/campaign-end`, claude/campaign-end. Director: a wiped company ends
  the campaign (final chronicle screen, ended save never loads into play). Log as a D-entry.
- Art look target: `../MERCS-wt/art-look`, claude/art-look-target. A "Ash and Hearth", B "Peat and
  Ochre", C "Clear Day" (boards docs/audits/look_target/option_{A,B,C}.png; 4K frames
  D:/MERCS-vault/renders/look_2026-10-15). Re-rendering with lead QC fixes (puddles read as
  casterless shadows, straw as tools, orc pauldrons balloon + head big; "blockout" caption) and
  his note: "the colour looks good though. the lighting could stand to be 5% brighter" (+5% light,
  all options). He leans B ("most atmosphere") but picks from the FIXED A/B/C. His pick = master
  palette + goldens. He also said "the end fidelity would have to be much higher" (final art).
  realism-critic refuses without a real reference photo path (none in repo; ask before download).

## Queued after his look pick
Tile trial on the chosen palette: Retro Diffusion (US$10 prepaid, his written yes; logged into the
built-in browser pane; lead drives it; skill ~/.claude/skills/retro-diffusion; download at
ORIGINAL size; check the first output's public flag) vs Texel Studio (local Ollama, no diffusion
step, licensing row first) vs the Blender rig; RD Low-Poly 3D worth a props trial. Bring a pixel
UI font sheet (06 §7 [D]).

## Waiting on the director
Author merc_3..6, recruits, both factions, the storylet's words (placeholders in data); veto
tables #80-#93 (gate pack collects them); confirm/reorder M3/M4 (both built).

## Next board PR must log (branch claude/board-after-<n>)
Retro Diffusion US$10 spend yes; campaign ends on wipe; full-loop playtest pass; lighting +5%;
fidelity note; the look pick.

## Worktrees (3/4)
slice-m1 (gate pack), campaign-end, art-look. Remove each when its work merges.

## Co-lead playbook
playbook: updated 2026-10-15 (merge-check gap, APPDATA trap). Curate Art's "Findings for the
lead" (4K window 3836x2158; Blender glTF double-sided faces) on Art's refresh.

## Rules learnt the hard way (keep under 10 lines)
- Never `export APPDATA`: set it on the Godot command only (breaks gh, git creds, Python user site).
- gdlint/gdformat: `python -m gdtoolkit.linter|formatter`; CI requires both (merge_eligibility).
- Handoff on a branch is deleted on merge: each update = new branch from main + PR; keep <=120 lines.
- Every merge: `bash tools/merge_eligibility.sh <pr>` then `gh pr merge --match-head-commit`.
- Before merging a sim PR: post the mercs-sim-review verdict, set Review needed: done.
- A milestone's Director gate line: "none blocking; play review after merge (D-064)".
- tests.yml skips drafts: mark ready, then push. Headless windows are 64x64: size root first.
- Captures at 3840x2160 offscreen (--windowed --position 8000,8000) before he looks.
