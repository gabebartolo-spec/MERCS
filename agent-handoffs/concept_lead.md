# Concept Lead handoff, 2026-10-09 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/CONCEPT_LEAD_FABLE.md`), and the current phase section of `docs/08_ROADMAP.md` only (`docs/STATUS.md` names the phase).
Account note: the director runs two Claude accounts. Day-to-day Phase 1 work is led from the other
account's "MERCS BOSS" chat (acting lead + Dev Lead), with "MERCS SUPPORT" (Merge & CI) and
"MERCS ART FACTORY". This role reviews gates and audits; it does not drive daily work there.

## State: awaiting director
## Task
Phase 1 oversight. Next real task: Phase 1 sample review / gate when the Dev Lead's evidence pack lands.
## Branch and commit
docs/concept-lead-handoff (this file only). Nothing else open from this role.
## Files I own right now
None open. Shipped by this role: #20 merge-workflow audit (D-030: autonomous Merge & CI, one board
writer, routine git allowed, squash-only repo settings), #22 render pipeline skeleton (via subagent).
## Unfinished changes
None in the repo.
## Evidence so far
- Phase 0 gate PASS WITH NOTES (D-027), all gaps closed (#15–#18).
- 2026-10-09 status check: no open PRs; main at #46. Art paused by the director (realistic QC round 3
  fixes staged locally on claude/art-qc-c55, unrendered). Density pick (56 / 84 / 112 px) pending.
## Attempts (for the fix-loop rule)
None open.
## Open decisions (waiting on the director)
1. Resume Art (renders round-3 fixes and density samples, leading to the 56/84/112 decision).
2. Which Project Architect 3.0 ideas to adopt. My recommendation, given in chat 2026-10-08:
   adopt coder subagents owning edit/build/test loops, retriever subagents for reads >300 lines
   (<=40-line file:line returns), a fixed <300-token return contract (STATUS · CHANGED · VERIFIED ·
   PR/COMMIT · BLOCKER), a scripted merge-eligibility check, boss restart from handoff at ~150k.
   Reject keep-warm, critic agent, per-tool hooks, memory-file sprawl, Haiku. Trial a scoped read
   guard and a tiny usage report on AFL first (AFL boss transcript 185 MB vs MERCS 7 MB).
3. Local models (local-models MCP): reason mode for reviews, verify everything, not during GPU jobs;
   proposed licensing-register rows as dev tools (Gemma uncleared). Not yet in the repo.
## Board drift for Merge & CI
STATUS "Waiting on the director" still asks for the Mixamo sign-in (Art has 10 of 14 clips) and a
merge-chat restart (done); Art row says working (paused).
## Running jobs
None.
## Rules learnt the hard way (keep under 10 lines)
- Verify a peer is running (`get_session` isRunning, PR state) before reporting it as working.
- Wake an idle peer with `send_message` to its session id; a `/loop` must be typed by the director.
- A routine git refusal is a settings bug: fix `.claude/settings.json`, never hand the command over.
- Delegate big reads and test loops to subagents; take back short summaries only.
