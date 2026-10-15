class_name BattleMorale
extends RefCounted
## Each side's morale in one fight, the main non-HP ending (vision pillar 4, D-066). Both
## sides start at "morale_start"; a downed fighter costs his side morale (more for the
## leader). Two thresholds per side from data/balance/battle.json "rules" "morale_sides":
## below "shaken_below" the side is shaken (an event the player sees: one more loss may break
## it); below "rout_below" while it still has fighters standing it routs, and the fight ends
## with them alive. Shaken changes no roll yet. No surrender or retreat (D-066 caps).

const EVENT_MORALE := "morale"
const EVENT_SHAKEN := "shaken"

var _rules := {}
var _values := {}
var _shaken := {}


func setup(rules: Dictionary) -> void:
	_rules = rules
	for side: int in BattleUnit.SIDES:
		_values[side] = _num(rules, "morale_start")
		_shaken[side] = false


func value(side: int) -> int:
	var found: int = _values.get(side, 0)
	return found


func is_shaken(side: int) -> bool:
	return _shaken.get(side, false) == true


## True when the side's morale is below its rout threshold.
func breaks(side: int) -> bool:
	return value(side) < threshold(side, "rout_below")


## One side's threshold ("shaken_below" or "rout_below") from "morale_sides".
func threshold(side: int, key: String) -> int:
	var sides: Variant = _rules.get("morale_sides", {})
	var by_side: Dictionary = sides if sides is Dictionary else {}
	var read: Variant = by_side.get(BattleUnit.SIDE_KEYS[side], {})
	var block: Dictionary = read if read is Dictionary else {}
	return _num(block, key)


## Morale lost when one of the side's fighters goes down.
func loss_for(fighter: BattleUnit) -> int:
	return _num(_rules, "morale_loss_leader_down" if fighter.is_leader else "morale_loss_ally_down")


## Lowers a side's morale (never below 0); returns the morale event and, the first time the
## side drops below its shaken threshold, the shaken event.
func lower(side: int, amount: int) -> Array[Dictionary]:
	_values[side] = maxi(0, value(side) - amount)
	var events: Array[Dictionary] = [{"type": EVENT_MORALE, "side": side, "value": value(side)}]
	if not is_shaken(side) and value(side) < threshold(side, "shaken_below"):
		_shaken[side] = true
		events.append({"type": EVENT_SHAKEN, "side": side, "value": value(side)})
	return events


static func _num(block: Dictionary, key: String) -> int:
	var found: Variant = block.get(key, 0)
	if found is int:
		return found
	if found is float:
		var number: float = found
		return roundi(number)
	return 0
