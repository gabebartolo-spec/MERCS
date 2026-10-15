class_name BattleAi
extends RefCounted
## The enemy's plan for a round and its choice for one turn, from what it can see (CLAUDE.md
## rule 6: the AI is not psychic). Everything it knows of an opponent comes through
## BattleKnowledge: who stands within sight_cells and whether each looks wounded; never exact
## health, the other numbers, loadouts or plans. "In reach" is where its weapon action strikes
## (Battle.targets: beside it, a spear's 2 cells, a bow's shot along a line no wall stops; Phase
## 4 P1c), read only for opponents it sees. At the start of a round it plans (intent): attack
## the most hurt-looking seen opponent in reach, else advance on the closest seen one, else
## hold. On its turn it strikes its planned target if in reach, else the most hurt-looking
## seen opponent in reach (a front-liner who engaged it), else walks toward its planned target
## (the closest seen opponent when the plan is gone) by the fewest steps around walls; seeing
## no one, it walks to where it last saw a foe (BattleUnit.last_seen, its own memory) and
## holds once that spot is found empty or when it has never seen one (lead, 2026-10-16:
## deployments start within sight, a data check). Deterministic: no rolls, ties by id and cell.

const INTENT_ATTACK := "attack"
const INTENT_ADVANCE := "advance"
const INTENT_HOLD := "hold"
## Walking to where he last saw a foe (BattleUnit.last_seen): no target, he sees no one.
const INTENT_SEARCH := "search"


## The plan for this round: {"unit", "kind": attack | advance | search | hold, "target": id,
## "" for search and hold}.
static func intent(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Dictionary:
	var seen := BattleKnowledge.seen(battle, fighter, sight_cells)
	if seen.is_empty():
		var kind := INTENT_HOLD if fighter.last_seen == BattleUnit.NOWHERE else INTENT_SEARCH
		return {"unit": fighter.id, "kind": kind, "target": ""}
	var target := _most_hurt_in_reach(battle, fighter, seen)
	if target != null:
		return {"unit": fighter.id, "kind": INTENT_ATTACK, "target": target.id}
	var near := BattleKnowledge.nearest(fighter.cell, seen)
	return {"unit": fighter.id, "kind": INTENT_ADVANCE, "target": near.id}


static func choose(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Dictionary:
	var seen := BattleKnowledge.seen(battle, fighter, sight_cells)
	if seen.is_empty():
		if fighter.last_seen == BattleUnit.NOWHERE:
			return {"type": Battle.ACTION_WAIT}
		return _walk(battle, fighter, fighter.last_seen)
	var planned := _planned(battle, fighter, seen)
	var blow := battle.kit(fighter.id)[0]
	if planned != null and battle.targets(fighter.id).has(planned.id):
		return {"type": blow, "target": planned.id}
	var target := _most_hurt_in_reach(battle, fighter, seen)
	if target != null:
		return {"type": blow, "target": target.id}
	var goal := planned if planned != null else BattleKnowledge.nearest(fighter.cell, seen)
	return _walk(battle, fighter, goal.cell)


## A move to the reachable cell with the fewest steps left to the goal around walls
## (BattleGrid.distances), the nearer in a straight line between equals, the first cell in
## order after that; a wait when no cell is closer than where he stands. In the open this is
## the straight walk; behind a wall it goes round instead of stalling.
static func _walk(battle: Battle, fighter: BattleUnit, goal: Vector2i) -> Dictionary:
	var route := battle.grid.distances(goal)
	var far := battle.grid.size.x * battle.grid.size.y
	var best := fighter.cell
	var best_steps: int = route.get(best, far)
	var best_gap := BattleGrid.gap(best, goal)
	var cells: Array = battle.reachable(fighter).keys()
	cells.sort()
	for cell: Vector2i in cells:
		var steps: int = route.get(cell, far)
		var gap := BattleGrid.gap(cell, goal)
		if steps < best_steps or (steps == best_steps and gap < best_gap):
			best = cell
			best_steps = steps
			best_gap = gap
	if best == fighter.cell:
		return {"type": Battle.ACTION_WAIT}
	return {"type": Battle.ACTION_MOVE, "to": best}


## Plays the fighter's turn: his choice, or a wait when the battle refuses it, so an enemy
## turn always moves on (as MercPlay.play_out does). Returns the action
## applied, {} when even the wait was refused.
static func act(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Dictionary:
	var choice := choose(battle, fighter, sight_cells)
	if not battle.apply(choice).is_empty():
		return choice
	var hold := {"type": Battle.ACTION_WAIT}
	return hold if not battle.apply(hold).is_empty() else {}


## The target of this round's plan while it still stands in sight, else null.
static func _planned(battle: Battle, fighter: BattleUnit, seen: Array[BattleUnit]) -> BattleUnit:
	var target_id := str(battle.intent(fighter.id).get("target", ""))
	for other: BattleUnit in seen:
		if other.id == target_id:
			return other
	return null


## The seen opponent in the reach of the fighter's weapon action (Battle.targets) who looks
## most hurt (BattleKnowledge), else null.
static func _most_hurt_in_reach(
	battle: Battle, fighter: BattleUnit, seen: Array[BattleUnit]
) -> BattleUnit:
	var reach := battle.targets(fighter.id)
	var pick: BattleUnit = null
	for other: BattleUnit in seen:
		if not reach.has(other.id):
			continue
		if pick == null or BattleKnowledge.looks_worse(other, pick):
			pick = other
	return pick
