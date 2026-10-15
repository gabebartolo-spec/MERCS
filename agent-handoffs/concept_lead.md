# Concept Lead handoff, 2026-10-15 UTC (cloud session, archived on the director's order)
Start from this file, CLAUDE.md, your brief (`agent-briefs/CONCEPT_LEAD_FABLE.md`), the Phase 2 section of
`docs/08_ROADMAP.md`, and `docs/brainstorms/2026-10-14-horizontal-slice-plan.md` (the director's decisions).

## State: archived; the director runs Phase 2 from a new session
## Task
Phase 2 (horizontal slice) under Project Architect 3.0 (D-071): the lead briefs coder subagents, reviews
their diffs and evidence, opens the PRs. Milestone 1 is on main (#75). Milestone 2 (travel and encounters
into the existing battle) is NEXT and NOT started: it begins only when the director assigns it.
## Branch and commit
This file and the learnings entry only: `claude/concept-lead-handoff-3`. No other branch of this role is open.
## Files I own right now
None open. Shipped this session: #74 (brainstorm record, roadmap rewrite, Q15-Q22, briefs for PA3),
#75 (milestone 1: WorldSim, RegionGen, WorldSite, SaveModel v1, data/balance/world.json, overworld on F2,
SaveSystem to user://save_v1.json, suites sim_world 9, save 7, effect 4, overworld 8).
## Unfinished changes
None. Deleted unpushed: `claude/p2-m2-encounters` (made by mistake on a wake-up; see learnings 2026-10-15).
## Evidence so far
- #75 CI green on head a2f07be with the real shard run (shard 1, harness self-test, four lints).
- Milestone 1 capture (real F2 tap, 1920x1080 under xvfb) was sent to the director in chat.
- Coder briefs that worked: scratchpad `briefs/m1a_world_sim.md`, `m1b_overworld.md` (cloud scratchpad,
  not in the repo); shape: setup, study list with file:line, numbered deliverables, proof before report,
  return contract under 300 tokens. Two defects caught in lead review before the PR: Rng stream states
  lost precision through JSON (fixed: strings), closing the map freed the run (fixed: one director, hidden).
## Attempts (for the fix-loop rule)
None open.
## Open decisions (waiting on the director)
1. Milestone 1 review: play F2 in the build; carry on or wrong.
2. Two Concept Lead calls in the rewrite, standing unless vetoed: the battle skeleton as milestone 4
   (between the cast and wounds); Combat depth's "type chart" corrected to equipment physics (pillar 3).
3. Recommendation: `STRICT_FROM_PHASE = 2` in `tools/lint/magic_numbers.py` and `caps.json` phase 2 in the
   milestone 2 PR, so sim magic numbers are errors during the breadth phase.
4. Still on the board from before: D-060 Tripo threshold, the slice sketch calls (#66), Mixamo sign-in,
   the three superseded remote branches.
## Board drift for Merge & CI
#74's and #75's "Board and log" sections carry the STATUS rows and D-063 to D-071; not yet on the board.
## Running jobs
None. No pending check-in trigger.
## Rules learnt the hard way (keep under 10 lines)
- A wake-up (merge event, check-in, subagent return) is not an assignment: do the event's work, report, wait.
- Godot 4.7.2 linux headless runs in the cloud container (download the release zip); xvfb-run + opengl3
  gives a real capture; headless gives none.
- Two coders on one branch must run in sequence, never at once (same worktree).
- Mark a PR ready before CI matters: drafts skip the Godot shards and `test` goes green vacuously.
