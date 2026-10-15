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
## seen opponent in reach (a front-liner who engaged it), else walks to the
## reachable cell nearest its planned target (the closest seen opponent when the plan is
## gone); else it waits. Deterministic: no rolls, ties broken by unit id and cell.

const INTENT_ATTACK := "attack"
const INTENT_ADVANCE := "advance"
const INTENT_HOLD := "hold"


## The plan for this round: {"unit", "kind": attack | advance | hold, "target": id or ""}.
static func intent(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Dictionary:
	var seen := BattleKnowledge.seen(battle, fighter, sight_cells)
	if seen.is_empty():
		return {"unit": fighter.id, "kind": INTENT_HOLD, "target": ""}
	var target := _most_hurt_in_reach(battle, fighter, seen)
	if target != null:
		return {"unit": fighter.id, "kind": INTENT_ATTACK, "target": target.id}
	return {"unit": fighter.id, "kind": INTENT_ADVANCE, "target": _closest(fighter.cell, seen).id}


static func choose(battle: Battle, fighter: BattleUnit, sight_cells: int) -> Dictionary:
	var seen := BattleKnowledge.seen(battle, fighter, sight_cells)
	if seen.is_empty():
		return {"type": Battle.ACTION_WAIT}
	var planned := _planned(battle, fighter, seen)
	var blow := battle.kit(fighter.id)[0]
	if planned != null and battle.targets(fighter.id).has(planned.id):
		return {"type": blow, "target": planned.id}
	var target := _most_hurt_in_reach(battle, fighter, seen)
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


static func _closest(from: Vector2i, seen: Array[BattleUnit]) -> BattleUnit:
	var pick: BattleUnit = seen[0]
	for other: BattleUnit in seen:
		var gap := BattleGrid.gap(from, other.cell)
		var best := BattleGrid.gap(from, pick.cell)
		if gap < best or (gap == best and other.id < pick.id):
			pick = other
	return pick
