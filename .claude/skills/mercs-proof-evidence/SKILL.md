---
name: mercs-proof-evidence
description: How to prove a change to MERCS actually works before calling it done - the evidence that fits each kind of change, real mouse clicks through the GUI instead of handler calls, the player-effect fixture, pinned seeds, proving the asset the game actually loaded, new checks shown failing first, and the Not exercised line. Use it when finishing any feature or fix, writing a PR's Evidence section, adding a test, or about to say something works or looks right.
---

# Proof before "done"

"It works" is not evidence; what the game did is (CLAUDE.md rule 9). The usual false passes: a test
that calls a button's handler while a panel covers the button, a screenshot of a fallback sprite, a
check that passes on one lucky seed, and a green validator on an art change nobody has looked at.
MERCS is PC, mouse and keyboard (D-010), so UI proof means real mouse and keyboard events.

## Pick evidence that fits the change

`agent-briefs/HANDOFF_TEMPLATE.md` section C is the authority; where this table and C differ, C wins.

| Change | Evidence that counts |
|---|---|
| Data, copy, docs | touched suites; schema validation; lint |
| Sim rule or balance | seeded paired fixture (same seeds before and after); player-effect fixture |
| UI flow | a real click at the control's screen position through the GUI; 1920x1080 capture |
| Visual or art | validators green, contact sheet beside the golden image, then the director's approval |
| Animation | `assets` suite (strips vs manifest, every clip played through) plus a 3-second clip |
| Save or lifecycle | reload, old-save fixture, failure paths, `mercs-sim-review` |
| Performance | `perf` suite numbers against floors |

Scale the effort to the change: a data fix does not need a movie, an animation change does.

## A real click, not a handler call (guardrail B1)

`button.pressed.emit()` proves the handler's logic. It cannot show a player's click reaching the
button. For anything that stands for a click or a key:
- Send the mouse event at the control's on-screen centre through the viewport's GUI input, as a player
  would (scroll it into view first when it sits in a ScrollContainer), and assert that control got it.
  When it did not, report what took the click instead (a covering panel, a disabled control).
- Hover and right-click inspect are real input paths (D-010): test them with real motion and
  right-button events, not by calling their handlers. Keyboard actions: send the key event.
- Capture the screen at 1920x1080 and name the capture by path in the PR.
- If `tests/` has no click helper yet, write one in the first UI suite and share it; do not paste
  event code into every test.

## The player-effect fixture (guardrail A1)

Every system change ships a case in `tests/effect/` tagged with the system id: the same seed with the
system on and off gives a visibly different outcome (a different death, recruit, line of dialogue,
battle result or screen). Name it in the PR's Evidence section. No fixture, no PR
(`agent-briefs/DEV_LEAD_OPUS.md`). A system whose fixture cannot show a difference is decorative: say
so and propose cutting it (CLAUDE.md: the mercenaries are the game).

## Seeds

All randomness comes from `Rng` streams built from a seed (`docs/05_STYLE_CODE.md` "Randomness"); a
test constructs `Rng.from_seed(<n>)`. Pin the seed in the test and write it in the PR. A check that
fails now and then is an unpinned seed or a clock read (guardrail B2): pin it, never rerun it. For
balance, compare before and after on the same seeds, pair by seed, and use several seeds, not one
favourite. A reproduction is a fixture file under `tests/fixtures/` plus the expected outcome
(`docs/05_STYLE_CODE.md` "Tests").

## Prove the intended thing ran

- **Art and animation:** assert the asset the game actually loaded, not the file you meant it to load.
  The `assets` suite loads every manifest, plays every clip through, and checks frame alignment across
  layers and that `CharacterSheets.gd` matches the PNGs (`docs/07_ASSET_PIPELINE.md` 2.8). A frame
  requested past the end of a strip must fail a check, not freeze silently.
- **Save or lifecycle:** reload the save, load an old-save fixture, exercise the failure paths, and
  get a `mercs-sim-review` (guardrail B7).
- **New checks prove themselves:** show each new check failing on a known-bad input (a covered button,
  an empty frame, a data file that breaks its schema) before trusting its passes. The `data` suite's
  known-bad fixtures live in `tests/fixtures/data/`. Put the failing output in the PR.

## A look is the director's

Validators and green suites never approve a look: validators green, then a contact sheet beside the
golden image (`assets/golden/`), then the director's approval from labelled images
(`docs/06_STYLE_ART.md` section 8; `agent-briefs/DIRECTOR_QUESTION_PROTOCOL.md`). Blender close-ups are
the Art agent's own review, not proof; proof is a capture inside the Godot fixture at game scale.
Never write "looks right" on your own say-so.

## Write the evidence down

In the PR body (`agent-briefs/HANDOFF_TEMPLATE.md` section B):
- **Evidence:** suites with counts, the fixture and seed (path, seed), the capture or clip by path or
  artefact name, the player-effect fixture id.
- **Not exercised:** whatever you did not cover, explicitly: other screens, performance, a look the
  director has not seen. "Insufficient evidence" is an honest line; a check you could not run is not
  a pass.

After two similar failed fixes, change the evidence before writing another fix: a minimal
reproduction, the last good commit, the runtime state, the event path (CLAUDE.md rule 10; guardrail
B5). Write what you learnt in the PR.
