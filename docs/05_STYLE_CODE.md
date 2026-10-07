# 05 — Code style bible (GDScript, Godot 4.7.2)

Consistency is enforced by `gdformat` (formatting), `gdlint` (naming, size, typing) and three
project lints in `tools/lint/` (layering, magic numbers, strings). What a machine cannot check,
the PR reviewer checks against this file.

## Project layout

```
MERCS/
  project.godot
  CLAUDE.md
  docs/                      this pack
  agent-briefs/              role briefs and handoffs
  agent-handoffs/            live handoff files (versioned)
  data/                      content and balance, JSON + schemas
    schema/                  JSON Schema for every data file
    backgrounds.json  traits.json  equipment.json  injuries.json
    storylets/*.json  factions.json  balance/*.json  text/en.json
  sim/                       pure logic, RefCounted only, headless
    core/      rng.gd  clock.gd  ids.gd  result.gd
    merc/      merc.gd  merc_gen.gd  injury.gd  memory.gd  progression.gd
    battle/    battle.gd  grid.gd  actions.gd  morale.gd  resolver.gd
    world/     world.gd  faction.gd  contracts.gd  travel.gd  region.gd
    story/     storylet.gd  casting.gd  checks.gd
    save/      save_model.gd  migrations.gd
  presentation/              reads sim events, drives scenes
    autoload/  game_data.gd  event_bus.gd  save_system.gd  settings.gd  debug.gd
    world/  battle/  characters/  vfx/
  ui/                        screens and UiKit
    ui_kit.gd  text.gd  screens/*.tscn|gd  widgets/
  assets/                    engine-ready only (sprites, portraits, env, audio, fonts)
    golden/                  reference images for style review
  tools/
    pipeline/                Blender, ComfyUI, pixel post, validators (Python)
    lint/                    project lints (Python)
    run_tests.sh  check_ci_shards.sh  machine_profile.json
  tests/
    run_<suite>_tests.gd  expected_checks.txt  fixtures/  effect/
  .github/workflows/         tests.yml  build.yml  assets.yml
```

## Layering (enforced)

`data` → `sim` → `presentation` → `ui`. A script may `preload` only from its own layer or a
lower one. `sim/` never references `Node`, scene paths, `Input`, `Time`, `OS` or `Engine`.
`presentation/` never mutates sim state directly; it calls `Battle.apply(action)` style entry
points that return event lists.

## Naming

- Files `snake_case.gd`, classes `PascalCase` via `class_name`, functions and variables
  `snake_case`, constants `UPPER_SNAKE`, signals past-tense `snake_case` (`merc_died`), enums
  `PascalCase` with `UPPER_SNAKE` members.
- Private members prefixed `_`. No abbreviations that are not in the glossary below.
- Data ids are stable strings: `bg_hedge_knight`, `wpn_arming_sword`, `inj_lost_eye_left`,
  `st_bridge_refugees_01`. Ids never change once a save can contain them.

## Typing and structure

- Every declaration typed. `var hp: int = 0`, `func take(d: Damage) -> WoundResult:`.
  `Variant` and `Dictionary`-as-struct are allowed only at the data-loading boundary; inside `sim/`
  data becomes typed classes (`MercDef`, `WeaponDef`) at load time.
- 400 lines per file, 40 per function, 4 parameters per function (pass a small typed object past
  that), cyclomatic complexity 12.
- No `await` in `sim/`. Presentation may await tweens and timers.
- Sim → presentation: sim objects expose their own signals or return typed event lists from
  entry points (`battle.apply(action) -> Array[BattleEvent]`); presentation relays them onto the
  `EventBus` autoload, which carries only typed event records (`BattleEvent`, `WorldEvent`,
  `StoryEvent`). Sim never references `EventBus` or any other autoload (D-021). Presentation → sim
  is direct calls on entry points.
- Autoloads (five, under `presentation/autoload/`): `GameData`, `EventBus`, `SaveSystem`,
  `Settings`, `Debug`. Sim never references them.
- Errors: `sim/` returns typed result objects (`Result.ok(value)` / `Result.err(code)`), never
  pushes errors or prints. `presentation/` may `push_warning` for asset problems.

## Randomness

`Rng` (`sim/core/rng.gd`, RefCounted, `class_name Rng`) wraps `RandomNumberGenerator` with a
named stream per system (`rng.stream("battle")`, `rng.stream("world")`, `rng.stream("merc_gen")`),
each derived from the save seed and a counter held in the save model. It is **not an autoload**:
sim objects receive their `Rng` from the save model or their constructor, so sim never touches the
scene tree (D-021). A test constructs `Rng.from_seed(424242)`. Nothing else makes random numbers.

## Data

- JSON with a schema in `data/schema/`; CI validates every file. Keys `snake_case`. A `_comment`
  key is allowed anywhere and ignored.
- Balance numbers in `data/balance/<system>.json` with a sibling `<system>.md` that explains each
  knob in one line.
- All player-visible text in `data/text/en.json`; code calls `Text.t("merc.died.title", {name=...})`.
- Content caps per phase are in `data/caps.json` and enforced by lint.

## Tests

- One runner per suite `tests/run_<suite>_tests.gd`, prints `"<Suite> tests: %d checks, %d failures"`
  and quits non-zero on failure. Floors in `tests/expected_checks.txt` only go up.
- Suites from Phase 0: `data` (schema + caps), `sim_merc`, `sim_battle`, `sim_world`, `story`,
  `save`, `effect` (player-effect fixtures, see guardrail A1), `assets`, `ui`, `perf`.
- Seeded fixtures under `tests/fixtures/` are the reproduction currency: a bug report is a fixture
  file plus the expected outcome.

## Commits and PRs

- Conventional prefixes: `sim:`, `ui:`, `data:`, `art:`, `tools:`, `docs:`, `tests:`, `ci:`.
  Subject under 72 chars, present tense, says what the player gets when it is player-facing.
- Squash merge. Branch `claude/<topic>`. PR body per `agent-briefs/HANDOFF_TEMPLATE.md`.
- Attribution line required by the session's instructions goes last.

## Glossary (the only sanctioned abbreviations)

`merc` mercenary · `bg` background · `wpn` weapon · `arm` armour · `inj` injury · `st` storylet ·
`fac` faction · `hp` hit points · `ap` action points · `rng` random stream · `def` definition
(immutable data) · `state` (mutable, saved).

## Things that fail review on sight

Untyped `var`; `get_node` in `sim/`; a number literal in `sim/` that is not 0/1/-1/100; a string
literal a player will read outside `data/text/`; a colour literal outside `UiKit.gd`; a new
autoload; a `.import` change in a code PR; `git add -A`; a test whose floor went down; a PR with
no "Not exercised" line.
