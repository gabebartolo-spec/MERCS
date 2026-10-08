---
name: mercs-handoff
description: Writing and starting from a MERCS agent handoff - the file agent-handoffs/ROLE.md inside the repo that lets a fresh session continue without the old transcript, its 120-line cap, rewrite not append, and the context limits that say when to hand off. Use it when a task is done or you switch to unrelated work, when your context is getting long (past about 150k tokens), before the director restarts or clears a session, and at the start of any new session for the Dev Lead, Merge & CI, Art Factory or Concept Lead role.
---

# Handoffs

Context bloat is a named pitfall (guardrail C6). The rule (CLAUDE.md "Sessions and context";
`docs/03_TEAM_WORKFLOW.md` "Concurrency and cadence"):
- **Fresh session at every task boundary:** the PR is open with its evidence, or you switch to unrelated
  work. Do not restart mid-task, and never restart with in-flight work that is not written down.
- **Routine work stays at 50-100k tokens of context. Past 150k, hand off.**
- Write the handoff first, then start the new session from it.

## Where

`agent-handoffs/<role>.md` inside the repo, so it is versioned: `dev_lead.md`, `merge_ci.md`,
`art.md`, `concept_lead.md`. Cap 120 lines. **Rewrite it; do not append.** It is a snapshot, not a log.
Merge & CI keeps the folder tidy (`agent-briefs/MERGE_CI_AGENT.md`); the cap is checked in CI
(the doc caps job in `.github/workflows/lint.yml`). Write it on your task branch so it travels with the PR; main takes changes
only through PRs.

## What it says

Use the skeleton in `agent-briefs/HANDOFF_TEMPLATE.md` section A: a title with role and date, then
State (working, running a check, awaiting director, blocked, available), Task, Branch and commit,
Files I own right now, Unfinished changes, Evidence so far, Attempts, Open decisions, Running jobs,
and Rules learnt the hard way (under 10 lines). Short, factual, current; delete what is done.

- **Task** is the `docs/STATUS.md` item id and one sentence.
- **Branch and commit** is branch, sha, worktree path and PR number, or "no PR yet".
- **Unfinished changes** says what is half-done and what "done" looks like.
- **Attempts** is the fix-loop record (guardrail B5): for each open bug, what was tried and why it
  failed, so the next session does not repeat attempt three.
- **Open decisions** names the question ids and who they wait on. A decision that exists only in a
  chat does not exist: once the director answers, it goes in full into the "Board and log" section of the PR that
  acts on it, and Merge & CI records it in `docs/DECISIONS.md` at merge.
- **Running jobs** lists PIDs, Actions run ids and ComfyUI job ids, and what to do with each result. A
  Godot PID you did not record is a process you cannot safely stop (see mercs-godot-tests).
- Messages from other agents during the old session are not in the handoff unless you wrote them there.

## Starting a session from one

Read, in this order (`agent-briefs/HANDOFF_TEMPLATE.md` section A; CLAUDE.md):
1. the handoff, `agent-handoffs/<role>.md`;
2. `CLAUDE.md`, then your brief in `agent-briefs/`;
3. only the roadmap phase you were assigned, in `docs/08_ROADMAP.md`, by section, never the whole file;
4. `docs/STATUS.md` "Assigned items" and your own row.

Then check that every PR the handoff names still matches GitHub (`gh pr view <n>`: merged, red, new
head commit?) and that the branch tip is the sha written there. Carry on from "Unfinished changes". If
something you need is missing, ask its owner, or the director in protocol format
(`agent-briefs/DIRECTOR_QUESTION_PROTOCOL.md`); do not guess. Report your state at the end of your turn.
With nothing assigned, say "available" and wait; do not invent work (guardrail C4).

## Learnings

Proven findings for this project live in `references/learnings.md`. Read it before using this
skill; add to it only what proved effective, with evidence.
