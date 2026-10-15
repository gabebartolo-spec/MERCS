class_name BattleTurns
extends RefCounted
## The battle's strict turn order and rounds (D-066): fighters act by initiative, highest
## first, ties by id; a fighter who is down is skipped; passing the end of the order starts a
## new round. A fighter broken at his captain's fall (BattleMorale.is_broken) is skipped too:
## he stands but no longer acts. Presentation reads the order ahead (Battle.turn_order). No rolls.

const EVENT_ROUND := "round"

## The round under way, from 1; a round ends when everyone standing has acted.
var round_number := 0

var _order: Array[BattleUnit] = []
var _turn := 0
var _morale: BattleMorale = null


## Sorts the fighters into the order and puts the turn on the first who can act; morale says
## who has broken (none when null).
func setup(fighters: Array[BattleUnit], morale: BattleMorale = null) -> void:
	_morale = morale
	_order = fighters.duplicate()
	_order.sort_custom(_acts_before)
	round_number = 0
	_turn = 0


func current() -> BattleUnit:
	return _order[_turn] if not _order.is_empty() else null


## The whole order, downed fighters included, from the top.
func order() -> Array[BattleUnit]:
	return _order


## Who acts from now on, the current fighter first: each standing fighter once, in order.
func turn_order() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for i: int in _order.size():
		var fighter := _order[(_turn + i) % _order.size()]
		if _acts(fighter):
			out.append(fighter)
	return out


## The turn moves to the side's first standing fighter in the order (an ambush).
func give_first_turn(side: int) -> void:
	for i: int in _order.size():
		if _order[i].side == side and _acts(_order[i]):
			_turn = i
			return


## The next standing fighter's turn; true when it passed the end of the order (a new round).
func advance() -> bool:
	var wrapped := false
	for _i: int in _order.size():
		_turn += 1
		if _turn >= _order.size():
			_turn = 0
			wrapped = true
		if _acts(_order[_turn]):
			break
	return wrapped


## Moves the turn off fighters who cannot act, from where it stands.
func skip_downed() -> void:
	for _i: int in _order.size():
		if _acts(_order[_turn]):
			return
		_turn = (_turn + 1) % _order.size()


## Starts the next round and returns its event.
func next_round() -> Dictionary:
	round_number += 1
	return {"type": EVENT_ROUND, "round": round_number}


## True when the fighter is standing and has not broken.
func _acts(fighter: BattleUnit) -> bool:
	return fighter.can_act() and (_morale == null or not _morale.is_broken(fighter.id))


static func _acts_before(a: BattleUnit, b: BattleUnit) -> bool:
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	return a.id < b.id
