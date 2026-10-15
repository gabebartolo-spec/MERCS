class_name BattleLanding
extends RefCounted
## Where a fighter ends up to use a move on an enemy (split out of battle_view.gd, unchanged, to
## keep that file under the 400-line cap). Presentation reads the sim's reach; it decides nothing.

const NOWHERE := Vector2i(-1, -1)


## Where the actor uses a move on the enemy: where he stands when beside them, else the
## nearest reachable cell beside them for a move that walks; NOWHERE when out of reach.
static func cell(battle: Battle, actor: BattleUnit, enemy: BattleUnit, move: String) -> Vector2i:
	if enemy == null:
		return NOWHERE
	if adjacent(actor.cell, enemy.cell):
		return actor.cell
	if battle.move_def(move).get("walk") != true:
		return NOWHERE
	var best := NOWHERE
	var cells: Array = battle.reachable(actor).keys()
	cells.sort()
	for here: Vector2i in cells:
		if (
			adjacent(here, enemy.cell)
			and (best == NOWHERE or _gap(here, actor.cell) < _gap(best, actor.cell))
		):
			best = here
	return best


## Whether two cells touch (diagonals too).
static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


static func _gap(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
