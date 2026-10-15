class_name BattleKnowledge
extends RefCounted
## What one fighter can know about the other side (CLAUDE.md rule 6: the AI is not psychic),
## the only way BattleAi and MercPlay read an opponent: who stands within sight (sight_cells,
## Chebyshev distance), and how hurt each one looks, unhurt or wounded (a blow has landed on
## him; everyone in the street saw it land). Never exact or full health, attack, defence,
## damage, initiative, learnt moves or the other side's plans. The visible gear class joins
## when gear exists (docs/plans/phase4_combat.md P5, after P1b). No rolls and no knobs.
## Memory: each fighter keeps the cell where he last saw a foe (remember), his own sight only.

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


## The seen opponent nearest the cell (Chebyshev), the lower id between equals; seen is not
## empty.
static func nearest(from: Vector2i, seen: Array[BattleUnit]) -> BattleUnit:
	var pick: BattleUnit = seen[0]
	for other: BattleUnit in seen:
		var gap := BattleGrid.gap(from, other.cell)
		var best := BattleGrid.gap(from, pick.cell)
		if gap < best or (gap == best and other.id < pick.id):
			pick = other
	return pick


## Every standing fighter remembers where he last saw a foe: the nearest one he sees now, if
## any (sight_cells). One who sees no one and stands on or beside the remembered cell has
## found it empty and forgets it. Called by Battle after each action, so a fight replayed from
## its actions remembers the same (FightRecord). No rolls.
static func remember(battle: Battle, sight_cells: int) -> void:
	for fighter: BattleUnit in battle.units:
		if fighter.down:
			continue
		var near := _nearest_in_sight(battle, fighter, sight_cells)
		if near != null:
			fighter.last_seen = near.cell
		elif (
			fighter.last_seen != BattleUnit.NOWHERE
			and BattleGrid.gap(fighter.cell, fighter.last_seen) <= 1
		):
			fighter.last_seen = BattleUnit.NOWHERE


## nearest(viewer.cell, seen(...)) in one pass without building the list (remember runs after
## every action): the standing foe within sight at the least gap, the lower id between equals.
static func _nearest_in_sight(battle: Battle, viewer: BattleUnit, sight_cells: int) -> BattleUnit:
	var pick: BattleUnit = null
	var pick_gap := sight_cells + 1
	for other: BattleUnit in battle.units:
		if other.side == viewer.side or other.down:
			continue
		var gap := BattleGrid.gap(viewer.cell, other.cell)
		if gap > sight_cells:
			continue
		if pick == null or gap < pick_gap or (gap == pick_gap and other.id < pick.id):
			pick = other
			pick_gap = gap
	return pick
