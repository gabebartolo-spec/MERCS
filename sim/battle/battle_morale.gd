class_name BattleMorale
extends RefCounted
## Each side's morale in one fight, the main non-HP ending (vision pillar 4, D-066). Both
## sides start at "morale_start"; a downed fighter costs his side morale (more for the
## leader). Two thresholds per side from data/balance/battle.json "rules" "morale_sides":
## below "shaken_below" the side is shaken (an event the player sees: one more loss may break
## it); below "rout_below" while it still has fighters standing it breaks and the fight ends
## with them alive (BattleEnd: they run, or surrender when cornered or leaderless).
## The captain's fall (Phase 4, director ruling Q-D "large morale fall"): when a side's leader
## goes down, every fighter of that side still standing loses a big chunk of resolve at once.
## Each fighter's own "resolve" decides: at or above "morale_captain_fall" "hold_resolve" he
## holds (steady veterans), below it he breaks: he stops acting for the rest of the fight
## (BattleTurns skips him) and shares his side's fate at the end. No rolls.

const EVENT_MORALE := "morale"
const EVENT_SHAKEN := "shaken"
const EVENT_CAPTAIN_FALL := "captain_fall"
## The words presentation shows for a side's state (data/text/en.json "battle.morale.<state>").
const STATE_STEADY := "steady"
const STATE_SHAKEN := "shaken"
const STATE_BROKEN := "broken"

var _rules := {}
var _values := {}
var _shaken := {}
var _broken := {}
var _leader_fell := {}


func setup(rules: Dictionary) -> void:
	_rules = rules
	_broken.clear()
	_leader_fell.clear()
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


## True when this fighter broke at his captain's fall and no longer acts.
func is_broken(unit_id: String) -> bool:
	return _broken.has(unit_id)


## True once the side's leader has gone down in this fight.
func leader_down(side: int) -> bool:
	return _leader_fell.has(side)


## The resolve a fighter needs to hold when his captain falls.
func hold_resolve() -> int:
	return _num(_block(_rules, "morale_captain_fall"), "hold_resolve")


## How many standing foes beside a fighter pin him, so a broken side's man surrenders
## instead of running ("surrender" "pinned_by"; 0: never pinned, only walled in).
func pinned_by() -> int:
	return _num(_block(_rules, "surrender"), "pinned_by")


## One side's threshold ("shaken_below" or "rout_below") from "morale_sides".
func threshold(side: int, key: String) -> int:
	return _num(_block(_block(_rules, "morale_sides"), BattleUnit.SIDE_KEYS[side]), key)


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


## A leader newly down: his side's standing fighters hold or break on their resolve. Returns
## one "captain_fall" event per fallen leader ({"side", "unit", "hold_resolve", "held",
## "broken"}: ids in the order given), none when no leader fell since the last call.
func captain_check(units: Array[BattleUnit]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for leader: BattleUnit in units:
		if not leader.is_leader or not leader.down or leader_down(leader.side):
			continue
		_leader_fell[leader.side] = true
		var held: Array[String] = []
		var broke: Array[String] = []
		for fighter: BattleUnit in units:
			if fighter.side != leader.side or fighter.down or is_broken(fighter.id):
				continue
			if fighter.resolve >= hold_resolve():
				held.append(fighter.id)
			else:
				_broken[fighter.id] = true
				broke.append(fighter.id)
		events.append(
			{
				"type": EVENT_CAPTAIN_FALL,
				"side": leader.side,
				"unit": leader.id,
				"hold_resolve": hold_resolve(),
				"held": held,
				"broken": broke
			}
		)
	return events


## True when the side has fighters standing and every one of them is broken.
func all_broken(units: Array[BattleUnit], side: int) -> bool:
	var up := 0
	for fighter: BattleUnit in units:
		if fighter.side == side and not fighter.down:
			up += 1
			if not is_broken(fighter.id):
				return false
	return up > 0


## What the player may see of a side's morale (Battle.standing): the value, both thresholds,
## the state word ("steady", "shaken", "broken"), whether the leader is down, the resolve a
## fighter needs to hold at the captain's fall, and who has broken.
func view(units: Array[BattleUnit], side: int) -> Dictionary:
	var broke: Array[String] = []
	for fighter: BattleUnit in units:
		if fighter.side == side and is_broken(fighter.id):
			broke.append(fighter.id)
	var state := STATE_SHAKEN if is_shaken(side) else STATE_STEADY
	if breaks(side) or all_broken(units, side):
		state = STATE_BROKEN
	return {
		"side": side,
		"morale": value(side),
		"shaken_below": threshold(side, "shaken_below"),
		"rout_below": threshold(side, "rout_below"),
		"state": state,
		"leader_down": leader_down(side),
		"hold_resolve": hold_resolve(),
		"broken": broke
	}


static func _block(block: Dictionary, key: String) -> Dictionary:
	var read: Variant = block.get(key, {})
	return read if read is Dictionary else {}


static func _num(block: Dictionary, key: String) -> int:
	var found: Variant = block.get(key, 0)
	if found is int:
		return found
	if found is float:
		var number: float = found
		return roundi(number)
	return 0
