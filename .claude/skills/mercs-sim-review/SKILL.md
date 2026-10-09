---
name: mercs-sim-review
description: The review for changes that touch MERCS' save schema, world tick, injury, death, recruitment or memory systems - the review packet an author writes, the transitions and invariants a reviewer walks (versioned saves, defaults for new keys, migrations with old-save fixtures, save-reload-continue, determinism, mortality is final, the AI is not psychic) and how the verdict is recorded. Use it when asked to review such a PR, when you open one, or when a change you are making turns out to reach one of these areas, even if nobody said sim review. Extends the general game-architecture skill (its lifecycle review section) with this game's transitions.
---

# Sim review

A MERCS run lasts years of simulated time: mercenaries are recruited, wounded, scarred, remembered and
killed, and the save carries all of it. Two changes can each pass their tests and still be wrong
together. Tests check what their author thought of; this review checks the consequences nobody wrote a
test for. The PR's [MERGE NOTE] says "Review needed: mercs-sim-review by <agent>", and Merge & CI will
not merge without the reviewer's comment on the PR (`agent-briefs/MERGE_CI_AGENT.md` "Merge procedure",
step 3).

One reviewer, never the author. The reviewer judges the contract and its consequences, not the PR's
explanation of itself.

## If you are the author: the review packet

Put this in the PR body, under Evidence (`agent-briefs/HANDOFF_TEMPLATE.md` sections B and C):
- **Transitions affected:** which rows of the table below the change touches.
- **Invariants:** what must stay true across each (e.g. "a dead merc is never offered at a recruiting
  site", "an old save loads with the new key defaulted").
- **Evidence per invariant:** the test, fixture or reproduction, and anything not exercised.
- **If persisted state changed (guardrail B7):** the save version bump, a default for every new key, a
  migration plus an old-save fixture for every rename, and a save -> reload -> continue round trip in
  `tests/save/`.

## If you are the reviewer

1. **Read the packet, then put it aside.** Work out the affected transitions from the diff yourself;
   the packet may miss one.
2. **Walk the transitions** the changed state passes through. For each, ask whether it carries over,
   resets or transfers correctly:

| Transition | Typical questions |
|---|---|
| Save and reload (B7) | New state saved under a version? An old save without it loads with a default? A rename has a migration and an old-save fixture? A corrupt or half-written file fails safe? Does reload-then-continue match an uninterrupted run from the same seed (stream counters live in the save, `docs/05_STYLE_CODE.md` "Randomness")? |
| World tick | Advanced once per tick, in a fixed order, from seeded streams, nothing reading the clock? A year of simulated time still under 50 ms (B11)? |
| Injury | Do selection, available actions, role options and appearance treat an injured merc consistently, with the sim deciding and presentation reading its events (rule 3)? Are `inj_` ids stable? |
| Death (rule 5) | Does the dead merc leave rosters, contracts, markets, selection and new casting while the record of them (what others remember) stays? Is there any revive, respawn or save-scum door, in `Debug`, the save path or a UI shortcut? |
| Recruitment | Do the mercs the game generates (`MercGen`, seeded) actually reach the thresholds the rule depends on, such as an age band, a trait or a build? Is the roster cap (twelve, six deployed in the slice, D-013) enforced on every path that adds a merc? |
| Memory | Do memories refer to mercs and events by stable id, survive save and reload, and still resolve after the merc they name is dead, gone or hired away? |
| Identity | Is every reference keyed by id, never by a generated display name? Ids never change once a save can contain them (`docs/05_STYLE_CODE.md` "Naming"). |

3. **Check determinism and parity.** All randomness from `Rng` streams; nothing new reads the clock or calls
   `randi` or `randf` outside `sim/core/rng.gd` (B2, D-021). The enemy gets only information it could plausibly have (rule
   6): a new faction or AI rule must not read the player's hidden state (unrevealed roster, wounds,
   plans) without a plausible way for that information to have reached it.
4. **For rule or balance changes**, ask for (or run) the seeded paired fixture: the same seeds before
   and after, several of them, not one story. Check the player-effect fixture shows a real difference (A1).
5. **Prove what you suspect.** A suspected defect becomes a small test or a scripted reproduction (a fixture
   file plus the expected outcome) before you report it. "I think" is not a finding.

## The report

Post the review as a **comment on the PR**: that is the record Merge & CI checks. Per area: **fine**, or
**defect** with the reproduction, what goes wrong for the player, and the smallest fix you would suggest.
Name what you did not check. Tell the PR's owner in one line (PR number, commit, verdict). Do not rewrite
the PR yourself; open a fix PR only when the owner asks. If the PR has already merged, a defect goes
straight to a small fix PR whose test is the reproduction. Keep it short: the owner needs decisions and
repros, not a retelling of the diff.

## Learnings

Proven findings for this project live in `references/learnings.md`. Read it before using this
skill; add to it only what proved effective, with evidence.
