# 08 — Roadmap (sequential, gated)

Cap: 600 lines. Finished phases move to `docs/archive/`. Read only your phase.

Every phase has: a goal, hard caps, deliverables, a **gate** (what must be true), who signs the
gate, and what is still forbidden afterwards. Phases are sequential; a phase does not start until
the previous gate is recorded PASS in `DECISIONS.md`. One exception, chosen by the director on
2026-10-14 (D-065): Phase 2 runs in parallel with Phase 1 on placeholder sprites, and Phase 1's
look gate is signed whenever art lands. Estimated effort is in agent-days of focused work and is
a planning guess, not a promise.

Shape (director, 2026-10-14, `docs/brainstorms/2026-10-14-horizontal-slice-plan.md`): the
vertical slice (the look) is the short-term goal; the **horizontal slice** (Phase 2, a playable
baseline, thin everywhere, structurally sound) is the medium-term goal. After it passes, the old
sequential proofs become **depth passes** (Phases 3 to 8), then the vertical slice and the success
test (Phase 9). Nothing scales until the north star is true in a playable slice.

| Phase | Name | Owner | Est. | Gate signer |
|-------|------|-------|------|-------------|
| 0 | Foundation | Merge & CI + Dev Lead | 3 | Concept Lead (PASS, D-027) |
| 1 | Visual and factory proof | Art + Dev Lead | 8 | Director |
| 2 | Horizontal slice (the playable baseline) | Dev Lead | 16 | Director, after the Concept Lead's structural audit |
| 3 | Character depth | Dev Lead + Art | 4 | Director |
| 4 | Combat depth | Dev Lead | 6 | Director |
| 5 | Consequence depth | Dev Lead + Art | 4 | Director |
| 6 | Narrative depth | Dev Lead + Concept Lead | 6 | Director |
| 7 | Recruitment depth | Dev Lead | 3 | Director |
| 8 | World depth | Dev Lead | 6 | Director |
| 9 | Vertical slice and success test | all | 10 | Director |
| 10 | Production scaling | all | open | Director per content pack |

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

> Rewritten 2026-10-14 for the hand-made cast (D-048) and art route A (D-059): one skeleton
> contract with per-merc bone lengths, one body per merc kept across its three stages, a gear kit
> per stage; the sprite changes only at promotion plus one signature piece (D-061); injuries are
> separate layers on every stage, facing and clip (D-062). The `average` base body, `giant` and
> "three equipment combinations" are retired. Runs in parallel with Phase 2 (D-065); no art
> credits are spent on Phase 2's placeholders.

Caps: one street (about 40 × 20 m), one building interior, two cast members at stage 1 (the orc
and the Vampyr: clay, gait, geared sheets), the injury starter set as layers, six clips, eight
facings, two fonts, one palette.

Deliverables
- Director decisions from labelled samples: camera pitch, character height, whole-screen pixel
  mode vs crisp 3D, palette count, portrait style, two fonts (`11_OPEN_QUESTIONS.md` Q4–Q9).
- The skeleton contract (D-059) frozen; Mixamo clip set retargeted; the layer contract (body,
  gear, head, injury layers on one grid, `SheetClip.load_layers`, #70) and a look manifest per
  merc per stage, so the game loads a cast member's look from data.
- The orc and the Vampyr at stage 1 through the QC order: clay and silhouettes, gait as a played
  clip at game speed, geared sheets with the injury starter set (P1-ART-SLICE-CAST).
- `render_character.py`, `pixelate.py`, `pack_sheets.py`, all validators, Godot assets fixture.
- Street scene in Godot: GridMap kit, perspective camera, `Sprite3D` mercs walking with correct
  depth sorting, occlusion behind a wall, rain and night variants, torchlight.
- `assets/golden/street_day.png`, `street_rain_night.png`, one golden sheet per cast member.
- Pixel-stability result documented in `01_ENGINE_DECISION.md`.

**Gate (Director):** walks the street with the orc and the Vampyr in the build, sees one
injury layer on one of them, and says "this is the game's look". The playable build for this gate
is specified in `specs/art_direction_slice.md` (director, 2026-10-09). Factory rebuilds from clean
in under 30 minutes. Concept Lead confirms validators and contracts are committed.

Forbidden after: new facings, new clip types beyond the Phase 3–4 lists, any diffusion frame.

---

## Phase 2 — Horizontal slice (the playable baseline)

**Goal:** a playable baseline of the whole game: every pillar has a foundation standing, thin,
connected and structurally sound to build on. Director, 2026-10-14: "a playable baseline of the
game, not feature rich and not visually complete but structurally sound for us to build on";
"the open world/map must be established, a handful of prototype mercs, a prototype economy,
battle encounters, basically a playable game"; "the foundations of all our core tenets should be
visible in the horizontal slice."

Decisions: D-063 to D-071 (`docs/brainstorms/2026-10-14-horizontal-slice-plan.md`). Starts now,
on placeholder sprites, in parallel with Phase 1 (D-065). Extends the slice loop already on main
(#66, #67, F5 in the build): nothing here is a second skeleton.

**Caps (D-066):**
- Mercs: 6 at stage 1 (the orc, the Vampyr and four more), authored in `data/`; one full
  deployment, no reserve. Roster cap stays 12 (vision).
- World: one region, randomised each campaign: one authored hub (the Phase 1 street grown), two
  or three hamlets, two or three procedural sites, one road network; a seeded day tick.
- Factions: two, in tension; faction pressure is the cause of contracts.
- Economy: wages and supplies as the drain; contracts and loot as income. Loot is coin, supplies
  and generic equipment. Generic equipment is equipped for stats in a few slots (weapon, armour,
  trinket) and never shows on the sprite or portrait: the merc's own gear line is the look.
- Battle: 6 v 6 on the street; square grid, eight facings; visible turn order and intent; up to
  four learnt moves per merc; resolve and morale as the main non-HP ending; one terrain feature
  that proves one physical synergy (cover, or a front-liner who blocks); enemy AI acts only on
  what it can see. No height, formation, surrender or retreat yet.
- Wounds: the whole ladder, one of each: a wound, one temporary injury, one permanent injury
  with a sprite layer and a role change, down-then-triage, final death with a chronicle entry.
- Recruitment: inspect and hire at the hub; one prisoner decision after a fight (release, ransom,
  execute, recruit) with a company reaction; the captain's office, succession on the captain's
  death.
- Narrative: one authored storylet with casting rules and a visible check; the memory system
  recording a sentence from every fight and choice.
- Deliberately out (D-067): promotion lines and stage looks (everyone stays at stage 1); trade,
  crafting, gladiator events and banditry; weather, rain and night; portraits and the final UI;
  retreat, surrender, legendary locations, regional recruitment pools, epithets (depth passes).

**Milestones**, in dependency order (D-064). Each one ships in the F-key build; the director plays
it and says carry on or wrong in chat (captures are evidence, not the review). **Entry condition
for every milestone: its player-effect fixture passes** (same seed, system on and off, a visibly
different outcome; D-066). Est. in agent-days.

1. **Map and world tick** (3). `sim/world/`: seeded region generator (hub, hamlets, sites,
   roads), the day tick (supplies drain, travel advances), the first save (v1, migration
   scaffold) because world state is the first thing that must persist. Overworld presentation on
   the existing stage: hub, roads, sites, travel along a road. Fixture: two seeds give two maps a
   playtester can tell apart; a day's tick changes the supply count.
2. **Travel and encounters** (2). The world raises encounters on the road (two types: an ambush
   and a patrol) that lead into the existing street battle and back to the map with the result
   applied. Fixture: the same seed on a different road gives a different encounter.
3. **The cast and the company** (2). Six mercs in `data/` (stats, resolve, moves by level, role
   description in words, stage-1 gear line, generic-gear slots), the roster, the captain's office,
   one experience bar, a thin inspect screen. Placeholder sprites until Phase 1 lands; the look
   manifest loads the real sheets without a code change. Fixture: the orc and the Vampyr, same
   seed, same fight, visibly different behaviour and result.
4. **Battle skeleton** (4). `sim/battle/` grows from the sketch: grid, initiative order, intent,
   the four-move loadout, hit and injury hooks, morale thresholds with a rout ending, one terrain
   feature, non-psychic enemy AI, deterministic event log; presentation shows order and intent.
   Fixtures: the front-liner in front of the back-liner changes the outcome; a morale collapse
   ends a fight with living enemies.
5. **Wounds and death** (2). `sim/merc/injury`: wound, one temporary, one permanent (sprite
   layer and role change), down-then-triage after the fight, death, the chronicle entry, the
   succession event if the captain died (one dissenting voice). Fixtures: the permanent injury
   changes a battle outcome; a death writes a memory on a comrade and a chronicle entry that
   survives save and reload.
6. **Hub, economy and recruitment** (2). Wages and supplies due per day; contracts generated
   from the two factions' pressure; loot after a fight (coin, supplies, generic gear, equip for
   stats); inspect and hire at the hub; the prisoner decision with a company reaction. Fixture:
   ignoring wages for a week changes morale; the prisoner choice changes company state.
7. **Storylet and memory** (1). Memory sentences from fights and choices; one storylet cast over
   character, relationship, memory, world and location tags with a visible check and a
   fail-forward branch. Fixture: the storylet fires for one company and not another, by memory.

The Concept Lead orders milestones 3 and 4 as written (the battle skeleton needs the cast's
moves; wounds need real hits); the director confirms or reorders at milestone 2's review.

**Gate (Director, D-064):** one playthrough of the loop by the director (arrive, travel, fight,
triage, return, pay, hire, decide a prisoner's fate, see a storylet fire), **plus** the Concept
Lead's structural audit recorded in `docs/audits/`: save, reload and continue from every
milestone's state; the same seed replays the same campaign; every system has a passing
player-effect fixture; all content in `data/` under schema; lints and floors green. PASS, PASS
WITH NOTES or FAIL in `DECISIONS.md`. At PASS the director sets the order of the depth passes.

Forbidden after: content above these caps until the depth pass that owns it; a second region; a
stage-2 look; any new system without a player-effect fixture.

---

## Phase 3 — Character depth

**Goal:** a hand-made person you want.

> **Depth pass.** Starts only after the Phase 2 gate, in the order the director sets at that gate.
> Its caps are raised from the Phase 2 baseline, not from zero; anything the baseline already
> proved is not rebuilt, it is deepened.

Rewritten 2026-10-14 for the hand-made cast (D-048): mercs are authored, never generated. `MercGen`,
backgrounds, aptitudes, cultures and signature qualities do not exist.

Caps: 12 of the 25 cast members authored in `data/` (the Phase 9 roster cap), each with three
stage looks defined in data (art for stage 2 and 3 only for the two reference mercs), a gear line
per stage, moves by level, a resolve theme; generic equipment stays stat-only; 12 portraits
approved; roster cap 12.

Deliverables
- `sim/merc/`: `MercDef` from data and `MercState`; the three-stage promotion line on one
  experience bar (wages rise, abilities grow, the look manifest switches stage); moves learnt by
  level, four taken into battle (what sits beside them: Q20); the role description in words,
  never a class label.
- Portrait pipeline live, as the only generative asset: style chosen and approved; fixed-seed
  identity; `validate_portrait.py`; 12 approved portraits. No spend without a decision entry.
- Inspect screen: portrait, sprite turntable, role sentence, moves, gear line, generic slots,
  history (the chronicle so far), one "what this person is good at" paragraph from data.
- The hub recruit screen grows into discovery: cast members are found in the world (Q21), with a
  price and a reason they are there; recruit → roster.
- Captaincy rules in `data/balance/captaincy.json` (D-024, D-025); the reaction scenes are Phase 6.
- `effect` fixture: any two cast members, same seed, are told apart in one sentence each.
- Save migration from Phase 2's v1 with an old-save fixture.

**Gate (Director):** inspects the 12 and names three they want and one they would never hire,
without reading numbers.

Forbidden after: more than 12 cast members until Phase 9; any stat shown on the inspect screen
front page.

---

## Phase 4 — Combat depth

**Goal:** a readable fight where you know everyone on the field and morale ends it.

> **Depth pass.** Starts only after the Phase 2 gate, in the order the director sets at that gate.
> Its caps are raised from the Phase 2 baseline, not from zero; anything the baseline already
> proved is not rebuilt, it is deepened.

The Phase 2 skeleton (grid, order, intent, four moves, morale, one terrain feature) is deepened
here, not rebuilt.

Caps: 6 v 6, one map (the street), square grid 8-way, 5 weapon classes, 3 armour classes, 1 shield,
1 bow, 10 actions total, morale, surrender, rout.

Deliverables
- `sim/battle/`: grid, initiative order, action kit (weapon action + technique + personal + item),
  equipment physics inside gear lines (plate resists cuts, axes break shields; Q20), never a
  type chart (pillar 3), morale with visible thresholds, surrender and rout events, injury roll on hit (hooks for Phase 5), deterministic resolver with event log.
- Presentation: battle scene using the Phase 1 street kit, intent and order visible, hit/death
  frames, blood decals at logged points, bodies persist.
- UI: action bar from UiKit, hover explains rules and consequences, never the best move.
- `effect` fixtures: shieldman in front of archer changes arrow outcomes; killing the captain
  collapses morale; a surrender ends a fight with living enemies.
- `perf` suite baseline.
- Enemy AI that is not psychic: acts on seen units and known equipment only.
- Retreat: a withdraw order that ends the fight with the units that reach the map edge; units
  left behind are captured or killed by a seeded roll (their later fate is Phase 7). Encounter
  strength is set by the world, never scaled to the company.
- Deploy-or-delegate: the captain may sit out a fight; a field sergeant stands in. The morale
  effect of each choice is visible before the fight.

**Gate (Director):** plays five fights; can say why each was won or lost without a tooltip;
at least one ended by surrender or rout.

Forbidden after: more than 10 actions; stacked percentage synergies; a second map before Phase 8.

---

## Phase 5 — Consequence depth

**Goal:** wounds become biography.

> **Depth pass.** Starts only after the Phase 2 gate, in the order the director sets at that gate.
> Its caps are raised from the Phase 2 baseline, not from zero; anything the baseline already
> proved is not rebuilt, it is deepened.

Phase 2 proved one of each rung, triage, death and the chronicle; this pass fills the ladder.

Caps: 6 temporary injuries, 8 permanent injuries, 3 injury layers beyond Phase 1, 4 adaptation
paths, death.

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

**Gate (Director):** a merc they liked in Phase 3 loses a hand in a Phase 4 fight, and the director
can describe what changed about them and what they are now for.

Forbidden after: resurrection, injury-free difficulty modes, new injury types until Phase 9.

---

## Phase 6 — Narrative depth

**Goal:** the sim produces facts; the writing makes them matter.

> **Depth pass.** Starts only after the Phase 2 gate, in the order the director sets at that gate.
> Its caps are raised from the Phase 2 baseline, not from zero; anything the baseline already
> proved is not rebuilt, it is deepened.

Phase 2 proved the memory system and one storylet; this pass is content and relationships.

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

## Phase 7 — Recruitment depth

**Goal:** capture and morality are the same mechanic.

> **Depth pass.** Starts only after the Phase 2 gate, in the order the director sets at that gate.
> Its caps are raised from the Phase 2 baseline, not from zero; anything the baseline already
> proved is not rebuilt, it is deepened.

> **Open (director, 2026-10-09):** with a fixed cast of 25, how recruitment stays a discovery and
> where prisoners fit is Q21 in `11_OPEN_QUESTIONS.md`. Phase 2 ships one prisoner decision
> (release, ransom, execute, recruit) with a company reaction (D-066); this pass is rewritten
> once Q21 is answered.

Deliverables
- Surrender → prisoner → ransom / release / execute / exchange / recruit with company reactions
  from traits, origin and memories; a recruited enemy with a grudge in the roster.
- Recurring-enemy hook: a released captain can return.
- Two additional recruit sources beyond tavern: battlefield survivor, rescued prisoner.
- A mercenary left behind in a Phase 4 retreat who survived capture surfaces as a rumour and can
  be rescued or ransomed back, returning with a memory of being abandoned.
- `effect` fixtures for each branch producing a different company state.

**Gate (Director):** recruits a surrendered captain, and someone in the company hates it for a
reason the director can name.

---

## Phase 8 — World depth

**Goal:** one region where faction pressure causes contracts and visible consequences.

> **Depth pass.** Starts only after the Phase 2 gate, in the order the director sets at that gate.
> Its caps are raised from the Phase 2 baseline, not from zero; anything the baseline already
> proved is not rebuilt, it is deepened.

Phase 2 built the region, the tick, two factions and contracts from pressure; this pass adds the
third faction, weather and day/night, the legendary location and rumours.

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

## Phase 9 — Vertical slice and the success test

**Goal:** everything above in one 60–90 minute playable loop, polished enough to judge.

Caps: 20–30 backgrounds, several dozen storylets, 12-person roster, one region, three factions,
one legendary location, a mortal captain with succession, a company chronicle, save/load,
settings, a start-to-death-or-triumph arc.

Deliverables
- Integration of Phases 1–8 in one build with save/load, settings, main menu, audio placeholder
  pass (licensed or original only), a start and an end state.
- Playtest protocol and notes template; two outside playtests if the director can arrange them.
- Concept Lead drift audit and licence audit; all registers CLEARED or items removed.

**Integration check (Concept Lead, before the director plays):** remove any three roster members
one at a time in a fixture; if nothing changes but combat power, the slice is not ready.

**Success test (Director):** *Did I recruit someone, learn who they are, watch relationships form,
see them physically change through injury, adapt how I used them, and feel something when they
died or left?* If yes, Phase 10. If no, the Concept Lead diagnoses which proof failed and the
team returns to that phase. More world content is not the fix.

---

## Phase 10 — Production scaling (only after PASS)

Content packs, each its own gated mini-phase with caps: more backgrounds and equipment, more
storylets, second and third regions, additional legendary locations, crisis frameworks, factions,
seasons, audio and music, Steam page and build pipeline, accessibility, localisation.
Order decided by the director with the Concept Lead from playtest evidence, never by what is easy.
