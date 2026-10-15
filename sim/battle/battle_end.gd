class_name BattleEnd
extends RefCounted
## How a fight ends (vision pillar 4, D-066), checked after every action, company side first:
## a side with no one standing loses; a side whose morale breaks (BattleMorale.breaks) while
## the other still has fighters up routs, and the fight ends with its fighters alive. Sets
## the battle's winner, routed and surrendered and logs "rout" then "end". No rolls.

const EVENT_ROUT := "rout"
const EVENT_END := "end"


static func check(battle: Battle, morale: BattleMorale, events: Array[Dictionary]) -> void:
	for side: int in BattleUnit.SIDES:
		var up := standing(battle.units, side)
		var other := other_side(side)
		if up == 0:
			battle.winner = other
		elif morale.breaks(side) and standing(battle.units, other) > 0:
			battle.winner = other
			battle.routed = side
			battle.surrendered = side
			events.append({"type": EVENT_ROUT, "side": side, "standing": up})
		if battle.is_over():
			events.append({"type": EVENT_END, "winner": battle.winner})
			return


## How many of the side's fighters are not down.
static func standing(units: Array[BattleUnit], side: int) -> int:
	var count := 0
	for fighter: BattleUnit in units:
		if fighter.side == side and not fighter.down:
			count += 1
	return count


static func other_side(side: int) -> int:
	return BattleUnit.ENEMY if side == BattleUnit.COMPANY else BattleUnit.COMPANY
