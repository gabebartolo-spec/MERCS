# Phase 4 — Combat depth: work packages

Director, 2026-10-15: Combat depth is the first depth pass (D-091). Source: `docs/08_ROADMAP.md`
Phase 4 (caps and deliverables), Phase 2 milestone 4 (the skeleton it deepens), Q20, pillars 3 and
4, the slop audit's row 1 (`D:/MERCS-vault/renders/slop_audit_2026-10-15/README.md`). This file
splits the phase into packages that builders can take in parallel; it decides no taste or balance.
Every package ends at the Phase 2 rule: its player-effect fixture passes (same seed, system on
and off, a visibly different outcome), then the director plays it.

## Caps every package obeys

6 v 6, one map (the street), square grid, 8 facings; 5 weapon classes, 3 armour classes, 1 shield,
1 bow; **10 actions total**; morale, surrender, rout. No type chart (pillar 3): counters come from
roles, position and equipment physics inside each merc's gear line (Q20). No stacked percentage
synergies. No second map. Caps go in `data/caps.json` so the content-count lint enforces them.

## The battle after the split (this PR)

`sim/battle/battle.gd` (398 lines) is now a facade over modules; behaviour is byte-identical
(`tests/battle/golden_checks.gd`: seven seeded fights, log and end state hashed and pinned).

| File | Holds | Package that owns it |
|---|---|---|
| `battle.gd` (Battle) | facade: setup, apply, reads; public state | shared, append-only (see below) |
| `battle_rules.gd` (BattleRules) | the battle.json "rules" view, learnt moves | P1a |
| `battle_turns.gd` (BattleTurns) | initiative order, rounds, ambush first turn | P2 (rarely touched) |
| `battle_intents.gd` (BattleIntents) | the enemy's round plans | P5 |
| `battle_actions.gd` (BattleActions) | the action kit: legality and dispatch | P1a |
| `battle_resolver.gd` (BattleResolver) | one blow: rolls, damage, hit hook, down | P1b |
| `battle_morale.gd` (BattleMorale) | morale, shaken, breaking | P2 |
| `battle_end.gd` (BattleEnd) | wipe and rout end the fight | P2 |
| `battle_grid.gd` (BattleGrid) | grid, blocking, reach | P1c |
| `battle_unit.gd` (BattleUnit) | a fighter's numbers, loadout, gear | P1b |
| `battle_ai.gd` (BattleAi) | the enemy's choice | P5 |

### Shared files: the only overlaps, and how they stay mechanical

- `sim/battle/battle.gd`: gdlint allows 20 public methods; 15 are used, so **5 are left for the
  whole phase**. A package adds at most one, at the end of the public block, and prefers
  `apply()` with a new action type over a new method. Budgeted: P1b `odds(action)`, P2
  `standing(side)`, P4 `adjust_morale(side, amount)`; two spare.
- `data/balance/battle.json` and `battle.md`: one key per package, never another's.
  P1a `rules.moves`, `rules.actions`; P1b `rules.die_sides`, `hit_base`, `rules.gear`, `fighters`;
  P2 `rules.morale_*`, `rules.surrender`; P3 `rules.withdraw`; P4 none (company.json); P5
  `rules.sight_cells`, `rules.knowledge`.
- `data/text/en.json`: keys prefixed by package (`battle.gear.*`, `battle.morale.*`, ...).
- `tests/expected_checks.txt`, `tests/README.md`, `tools/run_tests.sh`, `tools/ci_shards.txt`,
  `tests/run_effect_tests.gd` expected-system list: one line per package; merge order resolves.
- `tests/battle/golden_checks.gd`: a package that changes outcomes **on purpose** re-pins the hash
  of the seeds it moves, in the same PR, with a one-line reason and a before/after table; a
  package meant to be neutral for old setups adds new seeds and leaves the old hashes alone.

### Determinism rules for every package

- Battle rolls stay on the `battle` stream in resolver order. A new random feature that is not a
  blow (the left-behind roll, P3) uses its own stream so existing fights replay unchanged.
- Every new action type survives `FightRecord` (JSON: ids as text, a cell as `[x, y]`); the
  golden check's replay leg covers it once a golden seed uses it.
- A package that saves something new (P4's choice, P3's left-behind) bumps nothing silently:
  optional key with a default, old-save fixture loads, reload-continue equals uninterrupted
  (`mercs-sim-review`).

## Packages

Sizes are agent-days. "Starts now" means no unmerged dependency.

### P0 — Split and golden logs (this PR) — done on merge

`sim/battle/*` split, `tests/battle/golden_checks.gd`. Review: mercs-sim-review.

### P1a — Action kit (sim) — 2 days — starts now

- Files: `sim/battle/battle_actions.gd`, `sim/battle/battle_rules.gd`, new
  `sim/battle/battle_kit.gd` (a fighter's available actions: weapon action + learnt moves +
  item, within the cap), `tests/battle/kit_checks.gd` (new), `tests/effect/battle_kit.gd` (new).
- Data: `data/balance/battle.json` `rules.actions` (the catalogue: id, category
  weapon/technique/personal/item, knobs) beside `rules.moves`; `data/schema/balance.schema.json`
  for that block; cap `actions: 10` in `data/caps.json`.
- Fixture `battle_kit`: the same seeded fight with a merc's technique in the kit vs without it
  ends differently (who falls, or which side wins).
- Depends on: P0. Blocks P1c, P3, P7. Needs Q-A answered before the catalogue is filled; the
  mechanism (categories, legality, cap) can be built on the two moves that exist.

### P1b — Equipment physics (sim) — 3 days — starts now

- Files: `sim/battle/battle_resolver.gd`, `sim/battle/battle_unit.gd`, new
  `sim/battle/battle_gear.gd` (weapon class vs armour class vs shield: the few physical rules,
  e.g. plate turns cuts, axes break shields, as small whole-number adjustments, never a chart of
  multipliers), `sim/merc/merc.gd` (`to_battle_unit` carries gear classes),
  `tests/battle/gear_checks.gd` (new), `tests/effect/battle_gear.gd` (new).
- Data: `rules.gear` and `fighters` in `battle.json`; `data/equipment.json` +
  `data/schema/equipment.schema.json` gain a `class`; gear-line classes per merc in
  `data/mercs.json` + schema (the orc: axe, plate). Caps: 5 weapon, 3 armour, 1 shield, 1 bow.
- Also: `BattleResolver.odds()` and the facade's `Battle.odds(action)` (chance to hit and damage
  range, computed, never rolled) for the hover in P7.
- Fixture `battle_gear`: same seed, the orc in plate against a blade vs in cloth: a different
  fight; an axe against a shield vs a blade against it: the shield breaks or holds.
- Depends on: P0. Blocks P1c, P5's equipment half, P7's odds. Needs Q-B (the class names).
- Golden: moves the pinned hashes if `battle.json` fighters gain gear; re-pin with the reason.

### P1c — Bow and shield cover (sim) — 2 days — after P1a and P1b

- Files: `sim/battle/battle_grid.gd` (line of fire past fighters and walls), new
  `sim/battle/battle_ranged.gd` (the bow's shot; the shield covering the cell behind it), one
  dispatch line in `battle_actions.gd` (by then P1a is merged), `tests/battle/ranged_checks.gd`,
  `tests/effect/battle_shield_archer.gd`.
- Data: the bow and shield entries under `rules.gear` (P1b's block, extended by agreement).
- Fixture `battle_shield_archer` (roadmap): the shieldman in front of the archer vs beside him
  changes the arrows' outcome.

### P2 — Morale, surrender, rout, the captain's fall (sim) — 2 days — starts now

- Files: `sim/battle/battle_morale.gd`, `sim/battle/battle_end.gd`, `sim/battle/battle_turns.gd`
  (if a routed fighter stops acting), `sim/world/encounter_battle.gd` (`result()` reports a
  surrender and who is left), `tests/battle/morale_checks.gd` (new),
  `tests/effect/battle_captain.gd`, `tests/effect/battle_surrender.gd` (both new).
- Data: `rules.morale_sides` gains the visible thresholds' words; `rules.surrender`
  (when a side gives up instead of fleeing); morale loss for the captain.
- Events: `surrender` beside `rout`, each with who is still standing, so presentation and the
  prisoner decision read them.
- Fixtures: killing the captain vs killing a fighter of equal health collapses morale and ends
  the fight sooner; a surrender ends a fight with living enemies who become prisoners.
- Depends on: P0. Blocks P3, P4's integration. Needs Q-C, Q-D.

### P3 — Retreat: the withdraw order (sim + panel line) — 2 days — after P1a and P2

- Files: new `sim/battle/battle_withdraw.gd` (the order, edge cells, who got out, the
  left-behind roll on its own `battle_withdraw` stream), one dispatch line in `battle_actions.gd`,
  one end check in `battle_end.gd`, `sim/merc/company_wounds.gd` (left-behind mercs marked
  captured or killed; their later fate is Phase 7), `tests/battle/withdraw_checks.gd`,
  `tests/effect/battle_withdraw.gd`.
- Data: `rules.withdraw` (roll odds as whole numbers); save: left-behind mercs under an optional
  key with a default (sim review).
- Fixture `battle_withdraw`: same seed, withdrawing at round 3 vs fighting on leaves a different
  company (who is home, who is captured or dead). Encounter strength stays set by the world.
- Needs Q-E.

### P4 — Deploy or delegate, the field sergeant (sim + pre-fight line) — 2 days — starts now

- Files: `sim/merc/company.gd` (the captain may sit out; a field sergeant named), new
  `sim/merc/field_command.gd` (who commands this fight and the morale effect of the choice, as a
  preview before the fight and as numbers the battle reads), `presentation/world/overworld_words.gd`
  (the line on the encounter panel), `tests/run_company_tests.gd` checks,
  `tests/effect/battle_delegate.gd` (new).
- Data: `data/balance/company.json` + `.md` (`deploy` block); save: the choice per fight is not
  saved unless Ironman needs it mid-fight (then an optional key; sim review).
- Fixture `battle_delegate`: same seed, the captain deployed vs left behind: a different morale
  shown before the fight and a different result.
- Integration with the battle (`Battle.adjust_morale`, leader flag) after P2. Needs Q-F.

### P5 — Enemy AI that is not psychic (sim) — 2 days — starts now (equipment half after P1b)

- Files: `sim/battle/battle_ai.gd`, `sim/battle/battle_intents.gd`, new
  `sim/battle/battle_knowledge.gd` (what a side can know: fighters in sight, their visible gear
  class, never generic gear bonuses, exact health or the other side's plans),
  `sim/merc/merc_play.gd` (a delegated merc uses the same knowledge), `tests/battle/ai_checks.gd`,
  `tests/effect/battle_ai_knowledge.gd`.
- Data: `rules.knowledge` if any knob is needed (prefer none).
- Fixture `battle_ai_knowledge`: same seed, an enemy that reads the orc's plate picks another
  target than one blind to gear; generic gear the enemy cannot see changes nothing it decides.
- Rule 6 check in review: no read of hidden state.

### P6a — Battle screen readability (presentation) — 2 days — IN FLIGHT

Branch `claude/p4-battle-readable` (not yet a PR): slop row 1 (fighters in adjacent cells
overlap, duplicate floating intent labels, three pixel densities). Files as that branch has them:
`presentation/world/battle_view.gd`, `pixel_screen.gd`, `slice_game.gd`, `street_stage.gd`,
`data/balance/stage.json` + `.md`, `data/text/en.json`, `tests/run_panels_tests.gd`. No other
package edits these until it merges.

### P6b — Hits, deaths, blood, bodies (presentation) — 2 days — starts now in new files

- Files: new `presentation/battle/battle_fx.gd` (hit and death frames from the `hit`/`down`
  events), new `presentation/battle/battle_marks.gd` (blood decals at the logged `cell`, bodies
  that stay where they fell for the fight), a one-line hook in `battle_view.gd` after P6a
  merges, `tests/run_battle_view_tests.gd` (new suite, real clicks at 1920x1080).
- Data: `data/balance/battle_view.json` + `.md` + schema (decal sizes, frame timings).
- Evidence: a capture pair (club-coloured mercs, not the grey mannequin), lead's art QA first.
- Art dependency: hit and death frames per facing from the Art agent; a placeholder flash until
  then, labelled as one. Needs Q-G.

### P7 — Action bar with rule hovers (ui) — 3 days — after P1a, P1b and a UiKit

- Files: new `ui/widgets/action_bar.gd`, new `ui/widgets/rule_hover.gd`, the battle panel's
  buttons moved out of `battle_view.gd` (after P6a), `tests/run_action_bar_tests.gd` (new,
  real hover and click at the control's screen position).
- Data: `data/text/en.json` `battle.rule.*` (what each action does and what it risks).
- The hover states rules and consequences from `Battle.odds()`; it never ranks moves.
- Blocked on a UiKit (`docs/05_STYLE_CODE.md` names `ui/ui_kit.gd`; none exists; the look-B UI
  work on `claude/look-b-ui` may bring it). Needs Q-H.

### P8 — Perf baseline — 1 day — IN REVIEW

PR #112 (`claude/p4-perf`): `tests/run_perf_tests.gd`, `tests/perf_baseline.json`, CI shard.
Later packages keep its gate green; a 20% regression fails.

## Order and parallel lanes

```
now:   P1a  P1b  P2  P4(sim side)  P5(sight side)  P6b(new files)  [P6a, P8 in flight]
next:  P1c (P1a+P1b)   P3 (P1a+P2)   P4 integration (P2)   P5 gear half (P1b)
last:  P7 (P1a+P1b+UiKit+P6a)   then the Phase 4 gate: five fights, one by surrender or rout
```

Disjoint file sets for the "now" lane (beyond the shared append-only files above):

| Package | Owns |
|---|---|
| P1a | `battle_actions.gd`, `battle_rules.gd`, `battle_kit.gd`*, `tests/battle/kit_checks.gd`*, `tests/effect/battle_kit.gd`* |
| P1b | `battle_resolver.gd`, `battle_unit.gd`, `battle_gear.gd`*, `sim/merc/merc.gd`, `data/equipment.json`, `data/mercs.json` (+ schemas), gear tests* |
| P2 | `battle_morale.gd`, `battle_end.gd`, `battle_turns.gd`, `sim/world/encounter_battle.gd`, morale tests* |
| P4 | `sim/merc/company.gd`, `field_command.gd`*, `data/balance/company.json`/`.md`, `overworld_words.gd`, delegate effect* |
| P5 | `battle_ai.gd`, `battle_intents.gd`, `battle_knowledge.gd`*, `sim/merc/merc_play.gd`, ai tests* |
| P6b | `presentation/battle/*`*, `data/balance/battle_view.json`*, its suite* |

(* new file.) Total: about 21 agent-days; with five builders the sim lanes finish in about four
days, P7 and the gate after.

## Open questions for the director (one line each; nothing here is decided)

- **Q-A** Which 10 actions: one weapon action per class plus the learnt moves, and is there an
  item slot yet (Q20's recommendation: one weapon action, four moves, no item until one exists)?
- **Q-B** The 5 weapon classes and 3 armour classes by name (the orc is axe and plate; the rest?).
- **Q-C** When does a side surrender (and become prisoners) rather than rout (and flee)?
- **Q-D** How hard does the captain's death hit: an instant rout, or a large morale fall?
- **Q-E** On a withdraw, does the player choose who covers the retreat, or does position decide?
- **Q-F** Does a captain who sits out a fight still earn its experience, and lose any morale?
- **Q-G** How much blood: decals at every hit, or only where someone fell (tone: "cruelty is not maturity")?
- **Q-H** Does the hover show a hit chance as a percentage, or as the die roll needed?
