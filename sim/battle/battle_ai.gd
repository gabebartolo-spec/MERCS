class_name BattleAi
extends RefCounted
## The enemy's choice for one turn, from what it can see (CLAUDE.md rule 6: the AI is not
## psychic). A fighter sees opponents within sight_cells (Chebyshev distance). It attacks the
## most hurt seen opponent beside it; else it walks to the reachable cell nearest the closest
## seen opponent; else it waits. Deterministic: no rolls, ties broken by unit id and cell.


static func choose(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Dictionary:
	var seen := _seen(battle, fighter, sight_cells)
	if seen.is_empty():
		return {"type": Battle.ACTION_WAIT}
	var target := _weakest_adjacent(fighter, seen)
	if target != null:
		return {"type": Battle.ACTION_ATTACK, "target": target.id}
	var goal := _closest(fighter.cell, seen)
	var best := fighter.cell
	var best_gap := _gap(fighter.cell, goal.cell)
	var cells: Array = battle.reachable(fighter).keys()
	cells.sort()
	for cell: Vector2i in cells:
		var gap := _gap(cell, goal.cell)
		if gap < best_gap:
			best = cell
			best_gap = gap
	if best == fighter.cell:
		return {"type": Battle.ACTION_WAIT}
	return {"type": Battle.ACTION_MOVE, "to": best}


static func _seen(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Array[BattleUnit]:
	var seen: Array[BattleUnit] = []
	for other: BattleUnit in battle.units:
		if (
			other.side != fighter.side
			and not other.down
			and _gap(fighter.cell, other.cell) <= sight_cells
		):
			seen.append(other)
	return seen


static func _weakest_adjacent(fighter: BattleUnit, seen: Array[BattleUnit]) -> BattleUnit:
	var pick: BattleUnit = null
	for other: BattleUnit in seen:
		if _gap(fighter.cell, other.cell) != 1:
			continue
		if pick == null or other.hp < pick.hp or (other.hp == pick.hp and other.id < pick.id):
			pick = other
	return pick


static func _closest(from: Vector2i, seen: Array[BattleUnit]) -> BattleUnit:
	var pick: BattleUnit = seen[0]
	for other: BattleUnit in seen:
		var gap := _gap(from, other.cell)
		var best := _gap(from, pick.cell)
		if gap < best or (gap == best and other.id < pick.id):
			pick = other
	return pick


## Chebyshev distance: king moves on the 8-way grid.
static func _gap(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
