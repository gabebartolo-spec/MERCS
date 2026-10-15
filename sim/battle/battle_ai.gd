class_name BattleAi
extends RefCounted
## The enemy's plan for a round and its choice for one turn, from what it can see (CLAUDE.md
## rule 6: the AI is not psychic). A fighter sees opponents within sight_cells (Chebyshev
## distance) and nothing else: no hidden health, plans or loadouts. At the start of a round it
## plans (intent): attack the most hurt seen opponent beside it, else advance on the closest
## seen one, else hold. On its turn it attacks its planned target if beside it, else any seen
## opponent beside it (a front-liner who engaged it), else walks to the reachable cell nearest
## its planned target (the closest seen opponent when the plan is gone); else it waits.
## Deterministic: no rolls, ties broken by unit id and cell.

const INTENT_ATTACK := "attack"
const INTENT_ADVANCE := "advance"
const INTENT_HOLD := "hold"


## The plan for this round: {"unit", "kind": attack | advance | hold, "target": id or ""}.
static func intent(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Dictionary:
	var seen := _seen(battle, fighter, sight_cells)
	if seen.is_empty():
		return {"unit": fighter.id, "kind": INTENT_HOLD, "target": ""}
	var target := _weakest_adjacent(fighter, seen)
	if target != null:
		return {"unit": fighter.id, "kind": INTENT_ATTACK, "target": target.id}
	return {"unit": fighter.id, "kind": INTENT_ADVANCE, "target": _closest(fighter.cell, seen).id}


static func choose(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Dictionary:
	var seen := _seen(battle, fighter, sight_cells)
	if seen.is_empty():
		return {"type": Battle.ACTION_WAIT}
	var planned := _planned(battle, fighter, seen)
	var blow := battle.kit(fighter.id)[0]
	if planned != null and BattleGrid.gap(fighter.cell, planned.cell) == 1:
		return {"type": blow, "target": planned.id}
	var target := _weakest_adjacent(fighter, seen)
	if target != null:
		return {"type": blow, "target": target.id}
	var goal := planned if planned != null else _closest(fighter.cell, seen)
	var best := fighter.cell
	var best_gap := BattleGrid.gap(fighter.cell, goal.cell)
	var cells: Array = battle.reachable(fighter).keys()
	cells.sort()
	for cell: Vector2i in cells:
		var gap := BattleGrid.gap(cell, goal.cell)
		if gap < best_gap:
			best = cell
			best_gap = gap
	if best == fighter.cell:
		return {"type": Battle.ACTION_WAIT}
	return {"type": Battle.ACTION_MOVE, "to": best}


## The target of this round's plan while it still stands in sight, else null.
static func _planned(battle: Battle, fighter: BattleUnit, seen: Array[BattleUnit]) -> BattleUnit:
	var target_id := str(battle.intent(fighter.id).get("target", ""))
	for other: BattleUnit in seen:
		if other.id == target_id:
			return other
	return null


static func _seen(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Array[BattleUnit]:
	var seen: Array[BattleUnit] = []
	for other: BattleUnit in battle.units:
		if (
			other.side != fighter.side
			and not other.down
			and BattleGrid.gap(fighter.cell, other.cell) <= sight_cells
		):
			seen.append(other)
	return seen


static func _weakest_adjacent(fighter: BattleUnit, seen: Array[BattleUnit]) -> BattleUnit:
	var pick: BattleUnit = null
	for other: BattleUnit in seen:
		if BattleGrid.gap(fighter.cell, other.cell) != 1:
			continue
		if pick == null or other.hp < pick.hp or (other.hp == pick.hp and other.id < pick.id):
			pick = other
	return pick


static func _closest(from: Vector2i, seen: Array[BattleUnit]) -> BattleUnit:
	var pick: BattleUnit = seen[0]
	for other: BattleUnit in seen:
		var gap := BattleGrid.gap(from, other.cell)
		var best := BattleGrid.gap(from, pick.cell)
		if gap < best or (gap == best and other.id < pick.id):
			pick = other
	return pick
