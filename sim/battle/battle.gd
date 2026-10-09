class_name Battle
extends RefCounted
## The slice's compact turn-based battle (docs/specs/art_direction_slice.md §2a step 6), the
## thin first form of Phase 3's sim/battle. A square grid with blocked cells, a strict turn
## order by initiative (ties by id), and three actions: move up to move_cells (8-way, no
## corner cutting), attack an adjacent enemy (d20 + attack against hit_base + defense; a hit
## deals 1..damage and wounds), or wait. A downed fighter lowers their side's morale (more
## for the leader); a side whose morale falls below surrender_below with fighters still up
## surrenders, which ends the fight with living enemies (vision pillar 4). Every outcome is a
## roll on the Rng "battle" stream, and apply() returns the events presentation draws.
## Seeded: the same setup, seed and actions give the same event log.

const STREAM := "battle"
const ACTION_MOVE := "move"
const ACTION_ATTACK := "attack"
const ACTION_WAIT := "wait"

var units: Array[BattleUnit] = []
var winner := -1
var surrendered := -1

var _rules := {}
var _rng: Rng = null
var _size := Vector2i.ONE
var _blocked := {}
var _order: Array[BattleUnit] = []
var _turn := 0
var _morale := {}


## rules: data/balance/battle.json "rules"; field: {"size": Vector2i, "blocked": {Vector2i: true}}
## (walls and props); fighters act in initiative order.
func setup(rules: Dictionary, field: Dictionary, fighters: Array[BattleUnit], rng: Rng) -> void:
	_rules = rules
	var size: Variant = field.get("size", Vector2i.ONE)
	_size = size if size is Vector2i else Vector2i.ONE
	var blocked: Variant = field.get("blocked", {})
	_blocked = blocked if blocked is Dictionary else {}
	_rng = rng
	units = fighters
	_order = fighters.duplicate()
	_order.sort_custom(_acts_before)
	for side: int in BattleUnit.SIDES:
		_morale[side] = _rule("morale_start")
	_turn = 0
	_skip_downed()


func is_over() -> bool:
	return winner >= 0


func current() -> BattleUnit:
	return _order[_turn] if not _order.is_empty() else null


func morale(side: int) -> int:
	var value: int = _morale.get(side, 0)
	return value


func unit(unit_id: String) -> BattleUnit:
	for fighter: BattleUnit in units:
		if fighter.id == unit_id:
			return fighter
	return null


## Cells the current fighter may move to this turn (reachable within move_cells).
func reachable(fighter: BattleUnit) -> Dictionary:
	var reach := {fighter.cell: 0}
	var frontier: Array[Vector2i] = [fighter.cell]
	var limit := _rule("move_cells")
	while not frontier.is_empty():
		var from: Vector2i = frontier.pop_front()
		var steps: int = reach[from]
		if steps >= limit:
			continue
		for step: Vector2i in _steps_from(from):
			if not reach.has(step):
				reach[step] = steps + 1
				frontier.append(step)
	reach.erase(fighter.cell)
	return reach


## Applies one action by the current fighter and returns what happened, in order:
## {"type": "move"|"attack"|"damage"|"down"|"morale"|"surrender"|"end"|"turn", ...}.
## An illegal action changes nothing and returns [].
func apply(action: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var actor := current()
	if is_over() or actor == null:
		return events
	var kind := str(action.get("type", ""))
	if kind == ACTION_MOVE and not _move(actor, action, events):
		return events
	if kind == ACTION_ATTACK and not _attack(actor, action, events):
		return events
	if kind not in [ACTION_MOVE, ACTION_ATTACK, ACTION_WAIT]:
		return events
	_check_end(events)
	if not is_over():
		_advance()
		events.append({"type": "turn", "unit": current().id})
	return events


func _move(actor: BattleUnit, action: Dictionary, events: Array[Dictionary]) -> bool:
	var to: Variant = action.get("to", actor.cell)
	if not to is Vector2i or not reachable(actor).has(to):
		return false
	var target: Vector2i = to
	events.append({"type": ACTION_MOVE, "unit": actor.id, "from": actor.cell, "to": target})
	actor.cell = target
	return true


func _attack(actor: BattleUnit, action: Dictionary, events: Array[Dictionary]) -> bool:
	var target := unit(str(action.get("target", "")))
	if target == null or target.down or target.side == actor.side:
		return false
	if absi(target.cell.x - actor.cell.x) > 1 or absi(target.cell.y - actor.cell.y) > 1:
		return false
	var roll := _rng.roll(STREAM, 1, _rule("die_sides"))
	var need := _rule("hit_base") + target.defense - actor.attack
	var hit := roll >= need
	events.append(
		{
			"type": ACTION_ATTACK,
			"unit": actor.id,
			"target": target.id,
			"roll": roll,
			"need": need,
			"hit": hit
		}
	)
	if hit:
		var amount := _rng.roll(STREAM, 1, actor.damage)
		target.hp = maxi(0, target.hp - amount)
		target.wounded = true
		events.append({"type": "damage", "unit": target.id, "amount": amount, "hp": target.hp})
		if target.hp == 0:
			_fall(target, events)
	return true


func _fall(fighter: BattleUnit, events: Array[Dictionary]) -> void:
	fighter.down = true
	events.append({"type": "down", "unit": fighter.id})
	var loss := _rule("morale_loss_leader_down" if fighter.is_leader else "morale_loss_ally_down")
	_morale[fighter.side] = maxi(0, morale(fighter.side) - loss)
	events.append({"type": "morale", "side": fighter.side, "value": morale(fighter.side)})


func _check_end(events: Array[Dictionary]) -> void:
	for side: int in BattleUnit.SIDES:
		var standing := _standing(side)
		var other := _other(side)
		if standing == 0:
			winner = other
		elif morale(side) < _rule("surrender_below") and _standing(other) > 0:
			winner = other
			surrendered = side
			events.append({"type": "surrender", "side": side})
		if is_over():
			events.append({"type": "end", "winner": winner})
			return


func _standing(side: int) -> int:
	var count := 0
	for fighter: BattleUnit in units:
		if fighter.side == side and not fighter.down:
			count += 1
	return count


func _other(side: int) -> int:
	return BattleUnit.ENEMY if side == BattleUnit.COMPANY else BattleUnit.COMPANY


func _advance() -> void:
	_turn = (_turn + 1) % _order.size()
	_skip_downed()


func _skip_downed() -> void:
	for _i: int in _order.size():
		if _order[_turn].can_act():
			return
		_turn = (_turn + 1) % _order.size()


## Free neighbouring cells, 8-way, never cutting a blocked or occupied corner.
func _steps_from(from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var step := Vector2i(dx, dy)
			if step == Vector2i.ZERO or not _free(from + step):
				continue
			if (
				dx != 0
				and dy != 0
				and not (_free(from + Vector2i(dx, 0)) and _free(from + Vector2i(0, dy)))
			):
				continue
			out.append(from + step)
	return out


func _free(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y or _blocked.has(cell):
		return false
	for fighter: BattleUnit in units:
		if fighter.cell == cell and not fighter.down:
			return false
	return true


func _acts_before(a: BattleUnit, b: BattleUnit) -> bool:
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	return a.id < b.id


func _rule(key: String) -> int:
	var value: Variant = _rules.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0
