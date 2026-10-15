class_name BattleRanged
extends RefCounted
## Striking from a distance (Phase 4 P1c; director 2026-10-16: "Build ranged next", spears
## "Yes, 2 cells"): a weapon action strikes a foe within its class's "reach" (battle.json
## "rules" "actions" "weapon": 1 beside him, the spear's 2, the bow's shot further) when the
## straight line to him is clear (BattleGrid.line_clear). Walls and props stop an arrow and a
## thrust; no fighter does, friend or foe, so a spearman strikes over a friend's shoulder and an
## archer shoots over heads. A blow on a foe beside him needs no line. No distance penalty and
## no point-blank ban. Reads only; rolls nothing.

var _grid: BattleGrid = null
var _rules: BattleRules = null


func setup(grid: BattleGrid, rules: BattleRules) -> void:
	_grid = grid
	_rules = rules


## True when the actor's action of this kind can strike the target from where he stands.
func can_strike(actor: BattleUnit, target: BattleUnit, kind: String) -> bool:
	if actor == null or not BattleResolver.foe(actor, target):
		return false
	var steps := BattleGrid.gap(actor.cell, target.cell)
	if steps > _rules.reach(kind):
		return false
	return steps <= 1 or _grid.line_clear(actor.cell, target.cell)


## The foes the actor's action of this kind can strike now, in the battle's unit order.
func targets(actor: BattleUnit, units: Array[BattleUnit], kind: String) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for other: BattleUnit in units:
		if can_strike(actor, other, kind):
			out.append(other)
	return out
