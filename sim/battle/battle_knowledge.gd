class_name BattleKnowledge
extends RefCounted
## What one fighter can know about the other side (CLAUDE.md rule 6: the AI is not psychic),
## the only way BattleAi and MercPlay read an opponent: who stands within sight (sight_cells,
## Chebyshev distance), and how hurt each one looks, unhurt or wounded (a blow has landed on
## him; everyone in the street saw it land). Never exact or full health, attack, defence,
## damage, initiative, learnt moves or the other side's plans. The visible gear class joins
## when gear exists (docs/plans/phase4_combat.md P5, after P1b). No rolls and no knobs.

## How hurt an opponent looks, worst last.
const UNHURT := 0
const WOUNDED := 1


## Standing opponents of the viewer within sight, in the battle's unit order.
static func seen(battle: Battle, viewer: BattleUnit, sight_cells: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for other: BattleUnit in battle.units:
		if (
			other.side != viewer.side
			and not other.down
			and BattleGrid.gap(viewer.cell, other.cell) <= sight_cells
		):
			out.append(other)
	return out


## How hurt the opponent looks: WOUNDED once any blow has landed on him, else UNHURT.
static func looks(other: BattleUnit) -> int:
	return WOUNDED if other.wounded else UNHURT


## True when a looks more hurt than b; between two who look the same, the lower id (a fixed,
## seen tie-break).
static func looks_worse(a: BattleUnit, b: BattleUnit) -> bool:
	if looks(a) != looks(b):
		return looks(a) > looks(b)
	return a.id < b.id
