# Brainstorm: the plan to a horizontal slice (2026-10-14, big)

Run with the game-director-brainstorm skill by the Concept Lead. Tested against `CLAUDE.md`,
`docs/00_VISION.md` (pillars, north star, hard rules) and `docs/08_ROADMAP.md` as it stands.

> **For agents:** nothing here is assigned. The roadmap, `DECISIONS.md` and `STATUS.md` are not
> changed by this file. The ready-to-paste decision lines are at the end for the Merge & CI agent,
> once the director confirms them. The roadmap rewrite that applies them is Concept Lead work
> (board item 18, reshaped by this session) and starts only when the director assigns it.

## The idea (director's words)

"The vertical slice can be a short term goal, the horizontal is a medium term goal of a playable
baseline of the game, not feature rich and not visually complete but structurally sound for us to
build on." It contains "the open world/map, a handful of prototype mercs, a prototype economy,
battle encounters, basically a playable game", and "the foundations of all our core tenets should
be visible in the horizontal slice."

## The moment in play

One sitting on the director's PC, placeholder art: a randomised region with one hub; the company
travels, meets an encounter, fights on a grid with turn order, moves and a morale ending; someone
goes down, is triaged, is wounded or dies and enters the chronicle; the company returns to the
hub, pays wages, takes a contract, hires, decides a prisoner's fate; one storylet fires and a
memory is recorded. Then the Concept Lead's audit: save, reload, continue; same seed, same
campaign; every system has a passing player-effect fixture; all content in `data/`.

## Decided

- **Two goals.** The vertical slice (the look: orc and Vampyr in the street) is the short-term
  goal. The horizontal slice is the medium-term goal: a playable baseline, structurally sound,
  thin and ugly where it must be.
- **Contents.** The map, prototype mercs, a prototype economy, battle encounters, and a visible
  foundation of every pillar (wounds and death, storylets and memories, recruitment and prisoners
  included). Director: "the foundations of all our core tenets should be visible."
- **Shape.** One breadth phase replaces roadmap Phases 2 to 7. Work is ordered by dependency. The
  director reviews each milestone by playing the build and says carry on or wrong; one formal
  PASS or FAIL gate at the end. Chosen over sequential gated phases and over a gate per milestone.
- **Start now, parallel with art.** Breadth starts immediately with placeholder sprites. Art
  finishes the cast on its own track; the look gate (Phase 1) is signed whenever art lands.
- **Milestone order.** 1 map and world tick; 2 travel and encounters into the existing battle;
  3 the prototype cast and the company; 4 wounds and death; 5 the hub with economy and
  recruitment; 6 storylets and memories.
- **Caps.** 6 prototype mercs (one full deployment, no reserve: death means fighting short).
  One region, one authored hub (the street grown), two or three hamlets, two or three procedural
  sites, one road network, randomised each campaign. Two named factions in tension.
- **Economy.** Wages and supplies as the drain; contracts and loot as income. Trade, crafting,
  gladiator events and banditry wait.
- **Battle.** The skeleton: square grid with facings, visible turn order and intent, up to four
  learnt moves, resolve and morale as the main non-HP ending, plus one terrain feature so one
  physical synergy (cover or a blocking front-liner) is proven once.
- **Wounds and death.** The whole ladder, one of each: wound, one temporary injury, one permanent
  injury with a sprite overlay and a role change, down-then-triage, final death with a chronicle
  entry.
- **Recruitment and the captain.** Recruits inspected and hired at the hub; one prisoner decision
  after a fight (release, ransom, execute, recruit) with a company reaction; the captain's office
  exists and succession happens on death.
- **Storylets.** One authored scene, plus the memory system recording sentences from every fight
  and choice. Structure proven, content waits.
- **End gate.** A structural audit plus one play: one playthrough of the loop by the director,
  and the Concept Lead's audit (save-reload-continue, determinism, every system has a passing
  player-effect fixture, all content in data).
- **Review.** Every milestone ships in the F-key build; the director plays it and answers in chat.
  Captures are evidence, not the review.
- **Deliberately left out.** Promotion lines and stage looks (mercs stay at stage 1); trade,
  crafting and gladiator events; weather, rain and night; portraits and the final UI.
- **This session.** No art credits spent; the focus is content and architecture. Director:
  "i dont want to waste too many credits on art in this session, focus on content and
  architecture."
- **Team.** Project Architect 3.0 adopted for the breadth phase: a lead per project, coder
  subagents owning edit/build/test loops, retriever subagents for reads over 300 lines (short
  file:line returns), a fixed short return contract (STATUS, CHANGED, VERIFIED, PR/COMMIT,
  BLOCKER), a scripted merge-eligibility check, restart from handoff at about 150k. Rejected with
  it: keep-warm, a critic agent, per-tool hooks, memory-file sprawl, Haiku.

## Tests, and what they found

- **Roadmap rule broken on purpose.** `08_ROADMAP.md`: "a phase does not start until the previous
  gate is recorded PASS." Starting breadth before the Phase 1 look gate breaks it. The director
  chose this knowingly; the rule needs a decision line, and the roadmap rewrite amends it for
  Phase 1 only (art and breadth run in parallel; the look gate still has to be signed).
- **Loot against bespoke gear lines (open).** The vision: "no general gear is shared between
  mercs." Loot as generic equipment would break that. The Concept Lead's reading: in the baseline,
  loot is coin and supplies, and a merc-specific piece only if it is from that merc's own gear
  line. Needs the director's yes (below).
- **Pillar 1 risk, not a failure.** "Recruitment must feel like discovery, not shopping." Hiring at
  the hub is the thin structural version; the baseline will feel like shopping. Acceptable for
  structure, and the depth pass after the gate owes the discovery (Q21).
- **Core test for every milestone (recommendation, not yet decided).** The player-effect fixture
  rule (every system has a fixture proving it changes what the player sees, decides or remembers)
  as a hard entry condition on each milestone, because a thin pass makes decorative systems easy.
- **Hard rules.** Determinism, sim authority, content in data, mortality final: nothing decided
  conflicts. Six mercs in `data/`; the world tick seeded; the chronicle keeps the dead.
- **Scope.** The breadth phase is not on the roadmap. Building it needs the director to assign the
  roadmap rewrite, then the Dev Lead's first milestone. The team is paused (2026-10-10) until the
  director says otherwise.
- **Simplest version.** Already thin. The only further cut found: milestone 3 can be data only
  (four new mercs beside the orc and the Vampyr already defined), no new screens.

## Rejected and why

- Sequential gated Phases 2 to 7 with cut caps: six deep proofs in isolation leave the seams
  (save, tick, schemas, sim boundary) untested until Phase 8.
- A gate per milestone: slows the breadth pass to the pace of the director's gate reviews.
- Waiting for the look gate before any breadth work: the cast is not needed to prove structure.

## Open questions for the director

1. Loot in the baseline is coin and supplies only (no generic equipment)? Yes / no.
2. The player-effect fixture as a hard entry condition on every milestone? Yes / no.
3. Does this plan replace the roadmap's Phase 8 "vertical slice and success test", or does Phase 8
   remain as the depth gate after the horizontal slice passes?
4. Is the Project Architect 3.0 adoption MERCS-only or both projects? (It was recommended for AFL
   first; the director's answer here covers MERCS.)

## For the decision log (ready to paste, pending the director's confirmation)

- D-063: Two goals. Vertical slice (the look) short term; horizontal slice (playable baseline,
  structurally sound) medium term. Director, 2026-10-14.
- D-064: One breadth phase replaces roadmap Phases 2 to 7; dependency order; director plays each
  milestone build; one formal gate at the end (structural audit plus one play).
- D-065: Breadth starts now with placeholder sprites, in parallel with art; the Phase 1 look gate
  is signed when art lands. Amends the roadmap's phase-order rule for Phase 1 only.
- D-066: Baseline caps: 6 mercs; one region, one hub, two or three hamlets, two or three
  procedural sites; two factions; wages, supplies, contracts, loot; combat skeleton plus one
  terrain feature; full injury ladder one of each; hire at the hub plus one prisoner choice,
  captain's office and succession; one storylet plus the memory system.
- D-067: Left out of the baseline: promotion lines and stage looks, trade/crafting/gladiator
  events, weather, portraits and final UI.
- D-068: No art spend this session (2026-10-14); content and architecture first.
- D-069: Project Architect 3.0 adopted as the team structure for the breadth phase (set as in the
  Concept Lead handoff of 2026-10-09).
