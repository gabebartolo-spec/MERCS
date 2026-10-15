# battle.json — battle knobs

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/battle/` (through `battle_rules.gd`; `battle_ai.gd`,
`battle_morale.gd`, `battle_unit.gd`); Phase 2 milestone 4 (D-064, D-066) grew it from the slice's sketch. Spec: `docs/specs/art_direction_slice.md` §2a step 6. Counters come from
combat roles and each merc's own abilities, never a type chart (vision, 2026-10-09); Phase 3 deepens these numbers.

## rules
- `move_cells`: how far a fighter may walk in one turn, in 8-way grid steps.
- `die_sides`: the attack die (a d20).
- `hit_base`: an attack hits when die + attacker's attack ≥ this + defender's defense (11: an even fight hits half the time).
- `morale_start`: each side's morale when the fight begins.
- `morale_loss_ally_down`, `morale_loss_leader_down`: morale a side loses when one of its fighters goes down, and more when it is the leader.
- `sight_cells`: how far a fighter sees (Chebyshev cells); the enemy plans and acts only on fighters it can see, and of each it knows only whether he looks wounded (`sim/battle/battle_knowledge.gd`), never his exact health or other numbers (rule 6).
- `loadout_max`: how many learnt moves a fighter takes into a fight (D-066: up to four); extra moves are left out, last first.
- `morale_sides`: each side's (`company`, `enemy`) morale thresholds. `shaken_below`: below this the side is shaken (shown to the player; no roll changes yet). `rout_below`: below this, with fighters still up, the side routs and the fight ends with them alive (the main non-HP ending).
- Blocking, the one terrain feature of Phase 2 (D-066), has no knob: a walk ends on the first cell next to a standing opponent, so a front-liner in front of a back-liner stops attackers reaching him.
- `moves`: the learnt moves by id, each a few knobs; a fighter may use one only if it is in their loadout. `walk`: may walk (as a move) before the attack, in the same turn. `hp_cost`: health paid first, never the last point. `attack_bonus`, `damage_bonus`: added to that one attack's roll and damage. `charge` is the orc's (pure aggression); `blood_price` is the Vampyr's (health as energy).

## fighters
The loop sketch's fighters, by id. The orc and the Vampyr are the director's reference pair (brainstorm 2026-10-09); their numbers are a sketch to read the playstyles, not balance. Names live in `data/text/en.json`.
- `hp`, `attack`, `defense`, `damage`, `initiative`: as in `rules`.
- `presence`: weight in social checks (talking the lookout down).
- `moves`: the fighter's loadout, `{move_id: true}`, in order (ids from `rules.moves`; at most `loadout_max`).
- `leader`: losing this fighter costs `morale_loss_leader_down`.
- `watchman`, `watch_sergeant`: the road patrol's fighters (Phase 2 M2, data/encounters.json); the sergeant leads.
- `recruit_placeholder`: the loop's recruit until the director designs the cast member offered there.

## gate
- `die_sides`, `talk_down_difficulty`: the bandit lookout check: die + presence must reach the difficulty.
- `shaken_morale`: morale the band starts without when its lookout is talked down (he slips away; on a failure he fights with them).
