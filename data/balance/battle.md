# battle.json — sketch battle knobs

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/battle/battle.gd` and
`sim/battle/battle_ai.gd`. Spec: `docs/specs/art_direction_slice.md` §2a step 6. Phase 3 replaces
the attack/defense numbers with the equipment type chart; the turn, morale and surrender shape stays.

## rules
- `move_cells`: how far a fighter may walk in one turn, in 8-way grid steps.
- `die_sides`: the attack die (a d20).
- `hit_base`: an attack hits when die + attacker's attack ≥ this + defender's defense (11: an even fight hits half the time).
- `morale_start`: each side's morale when the fight begins.
- `morale_loss_ally_down`, `morale_loss_leader_down`: morale a side loses when one of its fighters goes down, and more when it is the leader.
- `surrender_below`: a side whose morale falls below this while it still has fighters up surrenders; the fight ends with living enemies.
- `sight_cells`: how far a fighter sees (Chebyshev cells); the enemy only acts on fighters it can see.
