---
name: mercs-pr
description: Opening, syncing and handing over a pull request the MERCS way - worktree and branch, the PR body sections and [MERGE NOTE], floors, director gates, who merges, the Board and log section, and how to report a PR to Merge & CI. Use it whenever you are about to open a PR, update one after main moved, resolve a conflict in tests/expected_checks.txt, write a commit message, or tell another agent about a PR or CI result. Extends the general github-hygiene skill (~/.claude/skills) with this repo's template, board rules and roles.
---

# A PR the MERCS way

Three Claude Code chats share this repo: the Dev Lead writes the game, Merge & CI merges and keeps
main green, the Art Factory agent owns assets and the pipeline (`docs/03_TEAM_WORKFLOW.md` "Roles").
The director decides anything the player sees. A PR carries everything the merger and the director
need, so nobody has to reread your conversation.

## Before you start

Work only on what `docs/STATUS.md` "Assigned items" lists (CLAUDE.md: a roadmap item is context, not
authorisation). Branch from current main in your own worktree; more than four live (`../MERCS-wt/` and the app's
`.claude/worktrees/` together, D-021) is a violation.

```bash
bash tools/lint/worktrees.sh            # more than four live: tell Merge & CI and stop
git fetch -q origin
git worktree add -b claude/<topic> ../MERCS-wt/<topic> origin/main
```

One PR per branch. Stage files by name, never `git add -A`, and revert `.import` churn before you
commit (see mercs-godot-tests). Commit subjects take a prefix (`sim:` `ui:` `data:` `art:` `tools:`
`docs:` `tests:` `ci:`), stay under 72 characters, use the present tense, and say what the player
gets when the change is player-facing (`docs/05_STYLE_CODE.md` "Commits and PRs"). The attribution
line your session's instructions give goes last.

## The PR body

The template is `agent-briefs/HANDOFF_TEMPLATE.md` section B; Merge & CI installs it as
`.github/PULL_REQUEST_TEMPLATE.md`. Keep every heading. Merge & CI will not merge a body with a
section missing, and a PR with no "Not exercised" line fails review on sight.

```
## What the player sees, and why   one short paragraph, game words; "nothing, internal" is valid
## Assigned in                     STATUS.md item <n> / decision <D-id>  (guardrail A4)
## What changes                    the mechanism, in a few lines
## Evidence                        suites and counts, fixture and seed, capture or clip, player-effect fixture
## Not exercised                   what this PR does not prove; "insufficient evidence" is honest
## Board and log                   your STATUS row change and any decision in full (D-TBD-<slug>); "none" is valid
## [MERGE NOTE]
- Hot files touched: <sim core, save model, UiKit, caps, floors, docs>
- Floors: <suite base -> new (+inc)>
- Review needed: <none | mercs-sim-review by <agent>>
- Director gate: <none | look approval pending | approved in D-id>
- Ordering with other PRs: <...>
```

See mercs-proof-evidence for what goes under Evidence and mercs-sim-review for the review line. A change
to how anything looks stays a prototype until the director approves it from labelled captures in a
question message (`docs/03_TEAM_WORKFLOW.md` "The loop for one item", step 5;
`agent-briefs/DIRECTOR_QUESTION_PROTOCOL.md`). Green CI is never approval of a look. Write the answer
in full under "Board and log" in the PR that acts on it; Merge & CI records it in `docs/DECISIONS.md`.

## STATUS.md and DECISIONS.md: never in your PR

Only Merge & CI edits `docs/STATUS.md` and `docs/DECISIONS.md` (CLAUDE.md; D-026, D-030). Put your
row change (state, item, branch / PR) and any decision, in full as `D-TBD-<slug>`, under "## Board and
log" in the PR body; Merge & CI records them in a board PR after the merge. A PR that touches either
file is sent back. States: working, running a check, awaiting director, blocked, available.

## After opening

- **You do not merge.** Merge & CI merges on green for the exact head commit, after any required
  review and any director gate (`agent-briefs/MERGE_CI_AGENT.md` "Merge procedure"). Never enable
  auto-merge. Draft and docs-only PRs skip the Godot jobs in `tests.yml` (`test` still
  reports): mark a draft ready when its tests should run.
- **A push after `test` went green makes that green stale.** Merge & CI merges only the exact head it
  checked, so every later push means waiting for a new green. Push when the work is final.
- **Sync your own branch** when main moves under it: merge or rebase `origin/main`
  (`docs/09_REPO_AND_HOSTING.md` "Branching"), then rerun the touched suites. Nobody else pushes to it.
  - **`tests/expected_checks.txt` conflict:** per suite line keep the higher floor of the two sides,
    then run that suite; if its real count is higher still (both PRs added checks), raise the line to
    the real count. Never lower a floor to get green (guardrail B6).
  - A capped doc must still be under its cap after the merge (`docs/03_TEAM_WORKFLOW.md` "Document caps").
- **Remove your worktree when the PR merges** (`git worktree remove ../MERCS-wt/<topic>`). Merge & CI
  does it in its merge procedure; do it yourself if it is still there. The branch is deleted on
  squash merge, so follow-up work starts a new branch from `origin/main`.
- **Hand over at task boundaries:** write `agent-handoffs/<role>.md` (see mercs-handoff).
- **A Dev Lead subagent** reports to the Dev Lead, who reviews the PR before handing it to Merge & CI
  (`agent-briefs/DEV_LEAD_OPUS.md` "Your responsibilities").

## Messages to other agents

When a PR is ready, send Merge & CI one line: the PR number and the commit. Every message names its PR or
item and the commit and says what you need or what you found; no "received" or "noted"
(`docs/03_TEAM_WORKFLOW.md` "Communication rules"). Send a CI failure or a conflict straight to the branch
owner: branch, commit, run id, failing suite and check, whether it also fails on main, who acts next.
Dev Lead blockers and findings go to the Concept Lead; the director gets only questions in protocol
format and the phase evidence pack.

Say which state you are in. Waiting on a result or an approval is a valid state; do not invent work to
look busy. Never ask another agent to do something your own session was refused permission for. A
routine git or GitHub refusal is a bug in `.claude/settings.json`: fix it by PR and restart; only an
unsafe-by-design refusal goes to the director (guardrail C5, D-030).

## Learnings

Proven findings for this project live in `references/learnings.md`. Read it before using this
skill; add to it only what proved effective, with evidence.
