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
- `sight_cells`: how far a fighter sees (Chebyshev cells); the enemy plans and acts only on fighters it can see.
- `loadout_max`: how many learnt moves a fighter takes into a fight (D-066: up to four); extra moves are left out, last first.
- `morale_sides`: each side's (`company`, `enemy`) morale thresholds. `shaken_below`: below this the side is shaken (shown to the player; no roll changes yet). `rout_below`: below this, with fighters still up, the side routs and the fight ends with them alive (the main non-HP ending).
- Blocking, the one terrain feature of Phase 2 (D-066), has no knob: a walk ends on the first cell next to a standing opponent, so a front-liner in front of a back-liner stops attackers reaching him.
- `moves`: the learnt moves by id, each a few knobs; a fighter may use one only if it is in their loadout. `walk`: may walk (as a move) before the attack, in the same turn. `hp_cost`: health paid first, never the last point. `attack_bonus`, `damage_bonus`: added to that one attack's roll and damage. `charge` is the orc's (pure aggression); `blood_price` is the Vampyr's (health as energy).
- `gear` (Phase 4 P1b, director's rulings D-092: weapons sword, axe, spear, mace, bow; armour leather, mail, plate; one shield): equipment physics as a few physical rules, each a small whole number, never a class-against-class chart (`sim/battle/battle_gear.gd`). The numbers are PLACEHOLDERS for the director to tune.
  - `min_damage`: a hit never does less than this after the armour (nor more than it rolled).
  - `weapons`: each class names the blow it strikes, `cut`, `thrust` or `crush` (sword, axe: cut; spear, bow: thrust; mace: crush). `breaks_shields`: a blow that would have hit without the shield splits it for the rest of the fight (the axe). `reach`: how many cells the weapon reaches (the spear: two; read by the action kit, P1a). The bow's shot is P1c's.
  - `armour`: `soak`: damage each hit loses (even leather is real armour). `gaps`: blows the armour does not stop (mail stops slashes, not thrusts; a mace dents plate). `initiative`: added to the wearer's initiative (plate is slow).
  - `shield`: `defense`: added to the bearer's defense while it is whole.
  - Caps (`data/caps.json`): `weapon_classes` 5, `armour_classes` 3, `shields` 1, `bows` 1; checked by `tests/battle/gear_checks.gd` (these are classes, not content files, so the content-count lint does not see them).

## fighters
The loop sketch's fighters, by id. The orc and the Vampyr are the director's reference pair (brainstorm 2026-10-09); their numbers are a sketch to read the playstyles, not balance. Names live in `data/text/en.json`.
- `hp`, `attack`, `defense`, `damage`, `initiative`: as in `rules`.
- `presence`: weight in social checks (talking the lookout down).
- `moves`: the fighter's loadout, `{move_id: true}`, in order (ids from `rules.moves`; at most `loadout_max`).
- `gear`: the fighter's gear classes, `{class: true}` (a weapon, an armour, `shield`); none means no gear rule applies to him. The orc is axe and plate (vision). PLACEHOLDERS for the director: the Vampyr sword and plate; bandit sword and leather; bandit chief axe and mail; watchman spear, mail and shield; watch sergeant sword and plate. `recruit_placeholder` has none until the cast member is authored.
- `leader`: losing this fighter costs `morale_loss_leader_down`.
- `watchman`, `watch_sergeant`: the road patrol's fighters (Phase 2 M2, data/encounters.json); the sergeant leads.
- `recruit_placeholder`: the loop's recruit until the director designs the cast member offered there.

## gate
- `die_sides`, `talk_down_difficulty`: the bandit lookout check: die + presence must reach the difficulty.
- `shaken_morale`: morale the band starts without when its lookout is talked down (he slips away; on a failure he fights with them).
