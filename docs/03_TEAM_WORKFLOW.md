# 03 — Team workflow

Built from what worked on the AFL project (956 commits in 16 days with a four-agent team) and what
did not (a 6,600-line roadmap nobody could read, 128 live worktrees, idle agents, status drift,
decorative systems). The MERCS team is smaller, the documents are capped, and the repo is the only
shared memory.

## Roles

### Director (human)
Vision, taste, priorities, every appearance approval, every spend. Answers questions in the
protocol format. Reviews phase gates. Is never asked to read a wall of text.

### Concept Lead — Claude Fable 5.1 (this chat, high effort)
- Owns `docs/00`–`docs/11` and the agent briefs. Updates them only by explicit decision.
- Runs the **phase-gate review** at the end of every roadmap phase: reads the Dev Lead's evidence
  pack, plays or watches the captures, writes a verdict (PASS / PASS WITH NOTES / FAIL and why)
  into `docs/DECISIONS.md`, and re-briefs the next phase.
- Runs a **drift audit** every ~150 commits or when the director asks: guardrail compliance,
  doc size caps, decorative-system check, licence register completeness, style validator coverage.
- Researches anything the team is unsure about (engine behaviour, licence, technique) and writes
  the answer into the relevant doc so it is never researched twice.
- Does not write production code. May write a validator or a fixture to prove a point.
- Fed by: `docs/STATUS.md`, PR evidence, director notes. Starts every session from this pack.

### Dev Lead — Claude Code, Opus 5.5 (one session at a time, fresh per task boundary)
- Owns the game code, data schemas, tests and the phase deliverable.
- Breaks the assigned phase into items of at most one PR each, records them in `docs/STATUS.md`,
  executes them in order. Uses worktree-isolated subagents (Sonnet 5.5) for bounded, independent
  items (a validator, a data table, a test suite) and reviews their PRs itself.
- Must ask the director through the protocol whenever a choice changes what the player sees,
  decides or feels. Must not pick a visual answer alone.
- Never merges. Hands PRs to Merge & CI with a `[MERGE NOTE]`.

### Merge & CI — Claude Code, Sonnet 5.5 (cheap, low effort, long-running)
- Owns merges, CI health, branch and worktree hygiene, `docs/STATUS.md`, `.github/`, the licence
  register's "recorded in PR" column, and the handoff files' housekeeping.
- Merges on green for the exact head commit, after any required review and after the director's
  gate where one applies. Never enables auto-merge. Never force-pushes. Never lowers a check floor.
- Prunes merged worktrees and remote branches weekly; fails the build if more than four live
  worktrees exist.
- Runs the doc-size check (`tools/lint/doc_caps.py`) and bounces any PR that pushes a capped
  document past its cap.

### Art Factory — Claude Code, Opus 5.5 (one session at a time)
- Owns `tools/pipeline/`, `assets/`, the style validators, ComfyUI and Blender, and the licence
  register rows for models and tools.
- Produces every asset from a contract (`docs/07_ASSET_PIPELINE.md`) and ships it with a
  provenance manifest and a labelled contact sheet.
- Asks the director every look question with labelled images in the same message.
- Is the only agent allowed to start a GPU job.

### Document upkeep (Merge & CI agent; no separate tool)
- The Merge & CI agent keeps `docs/DECISIONS.md`, `docs/STATUS.md` history, the roadmap's phase
  status lines and cross-document references tidy, in the same PR that changes the state, and
  writes a weekly summary for the director (`docs/summaries/<date>.md`, under 300 words, game
  words).
- Upkeep never changes a decision, rule, cap, number or licence status. An inconsistency is
  flagged to the Concept Lead, never resolved by choosing.
- ChatGPT is not part of the team (D-020).
- **One writer for the board and the log (D-026).** `docs/STATUS.md` and
  `docs/DECISIONS.md` are edited only by the Merge & CI agent, in a single follow-up commit to
  `main` after each merge, from the PR body's "Board and log" section. No other PR touches them,
  so PRs never conflict on shared lines and decision ids never collide.
- **Decision ids are assigned at merge (D-021).** A PR writes `D-TBD-<slug>` in `DECISIONS.md`
  and in every reference; the Merge & CI agent replaces it with the next free `D-NNN` in the
  squash commit. Agents never pick a number.

## Concurrency and cadence

- **At most three Claude Code chats run at once:** Dev Lead, Merge & CI, Art Factory. The Dev Lead
  may spawn up to two worktree subagents. That is the whole fleet; the AFL "medium" and "PA" tiers
  are not recreated because they generated coordination load faster than work.
- **No idle-monitoring crons.** Each agent reports its state (working / running a check /
  awaiting director / blocked / available) at the end of every turn in STATUS.md. The director
  glances at STATUS.md; nobody polls.
- **Fresh session at every task boundary.** Write the handoff (`agent-briefs/HANDOFF_TEMPLATE.md`)
  into `agent-handoffs/<role>.md` inside the repo (not outside it, so it is versioned), then start
  a new session from it.
- **One Godot process per agent, one GPU job on the machine.** The Art agent announces GPU jobs
  in STATUS.md with the PID.

## The loop for one item

1. The Dev Lead (or Art agent) picks the next assigned item from STATUS.md, claims it, and opens
   a worktree.
2. Writes or updates the test or validator first; shows it failing on the current state.
3. Implements. Runs the touched suites locally with isolated `APPDATA`.
4. Opens the PR using the PR template: what the player sees, what changed, evidence, not exercised,
   `[MERGE NOTE]`, director gate yes/no.
5. If the item changes a look, the PR stays a prototype until the director approves from labelled
   captures in the question message.
6. Merge & CI merges on green for the exact head, prunes the worktree, updates STATUS.md.
7. At the end of the phase, the Dev Lead assembles the evidence pack; the Concept Lead reviews the
   gate; the director plays the build.

## Communication rules

- Every message between agents names the PR or item and the commit. No "received" or "noted".
- A CI failure or a conflict goes straight to the branch owner.
- The director receives: questions in protocol format, gate reviews, and the weekly
  summary. Nothing else unless they ask.
- Decisions are written to `docs/DECISIONS.md` within the same PR that acts on them. A decision
  that exists only in a chat does not exist.

## Document caps (enforced by the `doc-caps` job in `.github/workflows/lint.yml`)

| Document | Cap | When it is hit |
|----------|-----|----------------|
| `docs/08_ROADMAP.md` | 600 lines | finished phases move to `docs/archive/roadmap_phase_N.md` |
| `docs/STATUS.md` | 150 lines | history rolls to `docs/archive/status_<month>.md` |
| `docs/DECISIONS.md` | 400 lines | oldest decisions roll to archive with a one-line index entry |
| `agent-handoffs/<role>.md` | 120 lines | rewrite, do not append |
| `CLAUDE.md` | 120 lines | move detail to a skill in `.claude/skills/` |

## Skills to create in `.claude/skills/` (Phase 0, ported from AFL and adapted)

`mercs-pr` (PR body and merge note), `mercs-proof-evidence` (evidence by change type),
`mercs-godot-tests` (isolated runs, floors, seeds), `mercs-handoff`, `mercs-art-pipeline`
(sheet contract, may/ask/never), `mercs-sim-review` (review packet for anything touching the
save schema, world tick, injury, death, recruitment or memory systems).
