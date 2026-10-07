# 08 — Roadmap (sequential, gated)

Cap: 600 lines. Finished phases move to `docs/archive/`. Read only your phase.

Every phase has: a goal, hard caps, deliverables, a **gate** (what must be true), who signs the
gate, and what is still forbidden afterwards. Phases are sequential; a phase does not start until
the previous gate is recorded PASS in `DECISIONS.md`. Estimated effort is in agent-days of focused
work and is a planning guess, not a promise.

| Phase | Name | Owner | Est. | Gate signer |
|-------|------|-------|------|-------------|
| 0 | Foundation | Merge & CI + Dev Lead | 3 | Concept Lead |
| 1 | Visual and factory proof | Art + Dev Lead | 8 | Director |
| 2 | Character proof | Dev Lead + Art | 6 | Director |
| 3 | Combat proof | Dev Lead | 10 | Director |
| 4 | Consequence proof | Dev Lead + Art | 6 | Director |
| 5 | Narrative proof | Dev Lead + Concept Lead | 8 | Director |
| 6 | Recruitment proof | Dev Lead | 4 | Director |
| 7 | World proof | Dev Lead | 8 | Director |
| 8 | Vertical slice and success test | all | 10 | Director |
| 9 | Production scaling | all | open | Director per content pack |

---

## Phase 0 — Foundation (no game yet)

**Goal:** a repo where an agent can be wrong safely and cheaply.

Deliverables
- Private repo, mono-repo layout from `05_STYLE_CODE.md`, `.gitattributes` with LFS rules,
  `.gitignore`, this pack committed.
- `project.godot` with static-typing warnings as errors, Forward+, 1920×1080, Windows export
  preset, CI build artefact.
- `.github/workflows/tests.yml` (plan → shards → aggregate `test`), `build.yml`, `assets.yml`
  (validators), `gitleaks`, `doc_caps`, `gdlint`/`gdformat`, layering lint, worktree-count lint.
- `tools/run_tests.sh`, `tools/check_ci_shards.sh`, `tests/expected_checks.txt` with a `data`
  suite and a `smoke` suite (project imports, main scene opens headless).
- Autoloads `Rng`, `GameData`, `EventBus`, `SaveSystem`, `Settings`, `Debug` as empty, typed shells
  with tests.
- `data/schema/` for backgrounds, traits, equipment, injuries, storylets, factions, text, balance,
  caps; empty-but-valid data files.
- `.claude/skills/` set from `03_TEAM_WORKFLOW.md`; PR template; `agent-handoffs/` seeded.
- `D:\MERCS-vault\` created with `models/`, `renders/`, `concepts/`, `clips/`, `logs/`; StabilityMatrix
  models root repointed; ComfyUI core updated; banned models moved out of the models root.
- `tools/machine_profile.json` written.

**Gate (Concept Lead):** a deliberately broken PR (untyped var, clock in sim, literal colour in
UI, doc over cap, five worktrees) is rejected by CI on every count; a clean PR merges and
produces a Windows build artefact that launches to an empty main scene.

Forbidden after: nothing new; it is foundation.

---

## Phase 1 — Visual and factory proof

**Goal:** prove the look and prove the machine that makes it, before any gameplay.

Caps: one street (about 40 × 20 m), one building interior, one `average` merc in three equipment
combinations, one `giant`, two injury overlays, six clips, eight facings, two fonts, one palette.

Deliverables
- Director decisions from labelled samples: camera pitch, character height, whole-screen pixel
  mode vs crisp 3D, palette count, portrait style, two fonts (`11_OPEN_QUESTIONS.md` Q4–Q9).
- Base body and frozen rig; Mixamo clip set retargeted; equipment mesh socket contract.
- `render_character.py`, `pixelate.py`, `pack_sheets.py`, all validators, Godot assets fixture.
- Street scene in Godot: GridMap kit, perspective camera, `Sprite3D` mercs walking with correct
  depth sorting, occlusion behind a wall, rain and night variants, torchlight.
- `assets/golden/street_day.png`, `street_rain_night.png`, `merc_sheet_average.png`.
- Pixel-stability result documented in `01_ENGINE_DECISION.md`.

**Gate (Director):** walks the street with a merc in the build, sees three equipment looks and
an eye-patch, and says "this is the game's look". Factory rebuilds from clean in under 30 minutes.
Concept Lead confirms validators and contracts are committed.

Forbidden after: new facings, new clip types beyond the Phase 2–3 lists, any diffusion frame.

---

## Phase 2 — Character proof

**Goal:** a generated person you want.

Caps: 12 backgrounds, 6 aptitudes, 24 traits, 6 cultures, 8 signature qualities, 20 equipment
items, 12 portraits approved, roster cap 12.

Deliverables
- `sim/merc/`: `MercDef` and `MercState`, `MercGen` from seed, identity layers, equipment slots,
  derived role description in words (not a class label).
- Portrait pipeline live: style LoRA trained and approved; 12 portraits for the fixture roster.
- Inspect screen: portrait, sprite turntable, background sentence, traits in plain words, equipment,
  history (empty for now), one "what this person is good at" paragraph generated from data.
- Tavern recruit screen with three candidates and a price; recruit → roster.
- The office of captain: one roster member holds it; the overworld figure is the captain; the
  inspect screen shows the office. Succession rules are data (`data/balance/captaincy.json`),
  chosen by the director in Q13; the succession event itself is Phase 4. The starting company is
  handed to the player with a sitting captain (Q14).
- `effect` fixture: two seeds produce two mercs a playtester can tell apart in one sentence each.
- Save v1 with migration scaffold.

**Gate (Director):** generates 20 mercs and names three they want and one they would never hire,
without reading numbers.

Forbidden after: more than 12 backgrounds until Phase 8; any stat shown on the inspect screen
front page.

---

## Phase 3 — Combat proof

**Goal:** a readable fight where you know everyone on the field and morale ends it.

Caps: 6 v 6, one map (the street), square grid 8-way, 5 weapon classes, 3 armour classes, 1 shield,
1 bow, 10 actions total, morale, surrender, rout.

Deliverables
- `sim/battle/`: grid, initiative order, action kit (weapon action + technique + personal + item),
  equipment interactions (the type chart), morale with visible thresholds, surrender and rout
  events, injury roll on hit (hooks for Phase 4), deterministic resolver with event log.
- Presentation: battle scene using the Phase 1 street kit, intent and order visible, hit/death
  frames, blood decals at logged points, bodies persist.
- UI: action bar from UiKit, hover explains rules and consequences, never the best move.
- `effect` fixtures: shieldman in front of archer changes arrow outcomes; killing the captain
  collapses morale; a surrender ends a fight with living enemies.
- `perf` suite baseline.
- Enemy AI that is not psychic: acts on seen units and known equipment only.
- Retreat: a withdraw order that ends the fight with the units that reach the map edge; units
  left behind are captured or killed by a seeded roll (their later fate is Phase 6). Encounter
  strength is set by the world, never scaled to the company.
- Deploy-or-delegate: the captain may sit out a fight; a field sergeant stands in. The morale
  effect of each choice is visible before the fight.

**Gate (Director):** plays five fights; can say why each was won or lost without a tooltip;
at least one ended by surrender or rout.

Forbidden after: more than 10 actions; stacked percentage synergies; a second map before Phase 7.

---

## Phase 4 — Consequence proof

**Goal:** wounds become biography.

Caps: 6 temporary injuries, 8 permanent injuries, 3 overlays beyond Phase 1, 4 adaptation paths,
death.

Deliverables
- Injury ladder in `sim/merc/Injury.gd`: wound → temporary → permanent → death; recovery clock;
  surgery check.
- Permanent states change sprite overlay, portrait (inpainted from the same seed), role options and
  tags; adaptation choices (left-hand retrain, scout, mentor, camp role).
- Triage: a downed mercenary is "down", not dead, until the battle resolves; then a seeded triage
  roll (surgeon skill, wound severity, time down) yields survived, permanently injured or died.
  Visually incontrovertible deaths (named kill frames) skip triage.
- Death handling: roster removal, memory creation for witnesses, company morale event, and if
  the dead mercenary held the captaincy, a succession event with one to three dissenting voices
  drawn from traits and memories.
- Company chronicle: an entry per member who ever served (living, retired, dead) with portrait
  history, origin, recruitment, battles, injuries, relationships, titles, equipment of renown,
  cause and place of death. Chronicle screen reachable from camp. `chronicle` fixture: a dead
  mercenary's entry survives save and reload.
- Epithets: four earned titles from deeds with visual or tag effects.
- `effect` fixtures: a lost eye changes archery; a limp selects the limp clip; a death creates a
  memory on two comrades.

**Gate (Director):** a merc they liked in Phase 2 loses a hand in Phase 3's fight, and the director
can describe what changed about them and what they are now for.

Forbidden after: resurrection, injury-free difficulty modes, new injury types until Phase 8.

---

## Phase 5 — Narrative proof

**Goal:** the sim produces facts; the writing makes them matter.

Caps: 15 storylets (at least 4 tagged warmth/humour/ordinary_life), 10 memory templates, 5
relationship states, 4 check types, 3 moral gates.

Deliverables
- `sim/story/`: storylet schema with casting rules over character, relationship, memory, world and
  location tags; selection with weights and cooldowns; visible checks with the dice shown; outcomes
  that write memories and relationship changes; fail-forward branches.
- Memory system: concrete sentences with actor, target, place, deed; referenced by later storylets.
- Relationship states (friends, rivals, mentor/protégé, grudge, oath) with causes shown in words.
- Camp screen where storylets fire; dialogue presentation from UiKit; copy in `data/text/`.
- Moral gates are company arguments: one to three relevant voices chosen by trait, origin and
  memory, never everyone; the player chooses the approach and, where it matters, which mercenary
  attempts the check.
- Storylet lint (tags, tone balance, pronouns) in CI; the Concept Lead reviews every batch.

**Gate (Director):** after two in-game weeks the director retells one story that happened between
two mercs, and it was not scripted to those two.

Forbidden after: any runtime text generation; storylets that reference a specific authored merc.

---

## Phase 6 — Recruitment proof

**Goal:** capture and morality are the same mechanic.

Deliverables
- Surrender → prisoner → ransom / release / execute / exchange / recruit with company reactions
  from traits, origin and memories; a recruited enemy with a grudge in the roster.
- Recurring-enemy hook: a released captain can return.
- Two additional recruit sources beyond tavern: battlefield survivor, rescued prisoner.
- A mercenary left behind in a Phase 3 retreat who survived capture surfaces as a rumour and can
  be rescued or ransomed back, returning with a memory of being abandoned.
- `effect` fixtures for each branch producing a different company state.

**Gate (Director):** recruits a surrendered captain, and someone in the company hates it for a
reason the director can name.

---

## Phase 7 — World proof

**Goal:** one region where faction pressure causes contracts and visible consequences.

Caps: one authored town (the Phase 1 street grown to a hub), three procedural sites, three
factions, four contract templates generated from two simulated problems (banditry, disputed
mine), one legendary location, travel with two event types, weather.

Deliverables
- `sim/world/`: region graph, faction state and pressure, problem generators, contract generation
  from problems, consequence of solving a problem, travel and supply, rumour surfacing.
- Overworld presentation: hub, roads, sites, weather, day/night, travel encounters feeding battle.
- Legendary location as an authored content package.
- Regional recruitment pools: each of the three sites draws backgrounds, weapon traditions and
  trait weights from its region and faction state (war zones yield deserters and veterans,
  mining country yields miners and brawlers), so "where do I look for this kind of person" is a
  real question.
- Contract board and rumour screens.
- Optional R&D slot (after the above are green, if time allows): Three.js animation lab round-trip
  test for one bespoke clip, as specified in the animation research brief.

**Gate (Director):** takes a contract caused by a simulated problem, solves it, returns, and the
region's problem is visibly different.

---

## Phase 8 — Vertical slice and the success test

**Goal:** everything above in one 60–90 minute playable loop, polished enough to judge.

Caps: 20–30 backgrounds, several dozen storylets, 12-person roster, one region, three factions,
one legendary location, a mortal captain with succession, a company chronicle, save/load,
settings, a start-to-death-or-triumph arc.

Deliverables
- Integration of Phases 1–7 in one build with save/load, settings, main menu, audio placeholder
  pass (licensed or original only), a start and an end state.
- Playtest protocol and notes template; two outside playtests if the director can arrange them.
- Concept Lead drift audit and licence audit; all registers CLEARED or items removed.

**Integration check (Concept Lead, before the director plays):** remove any three roster members
one at a time in a fixture; if nothing changes but combat power, the slice is not ready.

**Success test (Director):** *Did I recruit someone, learn who they are, watch relationships form,
see them physically change through injury, adapt how I used them, and feel something when they
died or left?* If yes, Phase 9. If no, the Concept Lead diagnoses which proof failed and the
team returns to that phase. More world content is not the fix.

---

## Phase 9 — Production scaling (only after PASS)

Content packs, each its own gated mini-phase with caps: more backgrounds and equipment, more
storylets, second and third regions, additional legendary locations, crisis frameworks, factions,
seasons, audio and music, Steam page and build pipeline, accessibility, localisation.
Order decided by the director with the Concept Lead from playtest evidence, never by what is easy.
