# Handoff and PR templates

## A. Session handoff (`agent-handoffs/<role>.md`, cap 120 lines, rewrite not append)

```
# <Role> handoff, <date> <time AEDT>
Start from this file, CLAUDE.md, your brief, and docs/08_ROADMAP.md §<phase> only.

## State: working | running a check | awaiting director | blocked | available
## Task
<item id from STATUS.md> — <one sentence>
## Branch and commit
claude/<topic> at <sha>, worktree ../MERCS-wt/<topic>, PR #<n> (or "no PR yet")
## Files I own right now
<paths>
## Unfinished changes
<what is half-done and what "done" looks like>
## Evidence so far
<suites run and counts, captures by path, fixtures>
## Attempts (for the fix-loop rule)
<what was tried for any open bug, and why it failed>
## Open decisions
<question ids asked, waiting on whom>
## Running jobs
<PIDs, Actions run ids, ComfyUI job ids>
## Findings for the lead
<tricks, tools, skills or checks that made the game better or caught a defect this task, each
with evidence; or "none". The lead decides what goes to memory. Leads: "playbook: updated" or
"playbook: nothing new">
## Rules learnt the hard way (keep under 10 lines)
```

## B. Pull request body (`.github/PULL_REQUEST_TEMPLATE.md`)

```
## What the player sees, and why
<one short paragraph in game words; "nothing, internal" is valid>

## Assigned in
STATUS.md item <n> / decision <D-id>

## What changes
<mechanism in a few lines>

## Evidence
- Suites: <suite: count> …
- Fixture / seed: <path, seed>
- Capture or clip: <path or artefact name>
- Player-effect fixture (for any system change): <tests/effect/... id>

## Not exercised
<what this PR does not prove; "insufficient evidence" is an honest line>

## Board and log
<the STATUS.md row and item changes, and any decision in full (D-TBD-<slug>, who, what, why), for the Merge & CI agent to record after merge; "none" is valid>

## [MERGE NOTE]
- Hot files touched: <sim core, save model, UiKit, caps, floors, docs>
- Floors: <suite base → new (+inc)>
- Review needed: <none | mercs-sim-review by <agent>>
- Director gate: <none | look approval pending | approved in D-id>
- Ordering with other PRs: <…>
```

End with the attribution line your session's instructions require.

## C. Evidence by change type

| Change | Evidence that counts |
|--------|----------------------|
| Data, copy, docs | touched suites; schema validation; lint |
| Sim rule or balance | seeded paired fixture (before/after on the same seeds); player-effect fixture |
| UI flow | a real click at the control's screen position through the GUI, 1920×1080 capture |
| Visual or art | validators green, contact sheet beside the golden image, then the director's approval |
| Animation | assets suite (strips vs manifest, every clip played through) plus a 3-second clip |
| Save or lifecycle | reload, old-save fixture, failure paths, `mercs-sim-review` |
| Performance | perf suite numbers against floors |
