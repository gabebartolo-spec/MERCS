# battle.json — sketch battle knobs

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/battle/battle.gd` and
`sim/battle/battle_ai.gd`. Spec: `docs/specs/art_direction_slice.md` §2a step 6. Counters come from
combat roles and each merc's own abilities, never a type chart (vision, 2026-10-09); Phase 3 deepens these numbers.

## rules
- `move_cells`: how far a fighter may walk in one turn, in 8-way grid steps.
- `die_sides`: the attack die (a d20).
- `hit_base`: an attack hits when die + attacker's attack ≥ this + defender's defense (11: an even fight hits half the time).
- `morale_start`: each side's morale when the fight begins.
- `morale_loss_ally_down`, `morale_loss_leader_down`: morale a side loses when one of its fighters goes down, and more when it is the leader.
- `surrender_below`: a side whose morale falls below this while it still has fighters up surrenders; the fight ends with living enemies.
- `blood_price_hp`, `blood_price_attack`, `blood_price_damage`: the Vampyr's blood price: hp he pays (never his last point) and what it adds to that attack's roll and damage.
- `sight_cells`: how far a fighter sees (Chebyshev cells); the enemy only acts on fighters it can see.

## fighters
The loop sketch's fighters, by id. The orc and the Vampyr are the director's reference pair (brainstorm 2026-10-09); their numbers are a sketch to read the playstyles, not balance. Names live in `data/text/en.json`.
- `hp`, `attack`, `defense`, `damage`, `initiative`: as in `rules`.
- `presence`: weight in social checks (talking the lookout down).
- `ability_charge`: walks and attacks in one turn (the orc: pure aggression). `ability_blood_price`: may pay hp to power an attack (the Vampyr: health as energy).
- `leader`: losing this fighter costs `morale_loss_leader_down`.
- `recruit_placeholder`: the loop's recruit until the director designs the cast member offered there.

## gate
- `die_sides`, `talk_down_difficulty`: the bandit lookout check: die + presence must reach the difficulty.
- `shaken_morale`: morale the band starts without when its lookout is talked down (he slips away; on a failure he fights with them).
