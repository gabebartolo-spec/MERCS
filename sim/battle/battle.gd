class_name Battle
extends RefCounted
## The compact turn-based battle (Phase 2 milestone 4, D-064/D-066), grown from the slice's
## sketch (docs/specs/art_direction_slice.md §2a step 6). A square grid (BattleGrid) with
## blocked cells and one terrain feature, blocking: a walk ends next to a standing opponent,
## so a front-liner in front of a back-liner shields him. A strict turn order by initiative
## (ties by id) that presentation reads ahead (turn_order); rounds, and at the start of each
## the enemy's intent, planned from what each enemy can see (BattleAi.intent) and shown before
## it acts. Actions: move up to move_cells (8-way, no corner cutting), attack an adjacent
## enemy (d20 + attack against hit_base + defense; a hit deals 1..damage and wounds), wait, or
## one of the fighter's learnt moves (up to loadout_max, defined in data: a walk, a health
## price, attack and damage bonuses). Each fighter faces one of eight ways. Every hit is a
## "hit" event and goes to an optional hook (set_hit_hook) that may add injury events. Morale
## (BattleMorale) falls as fighters go down; a side below its shaken threshold is shaken, and
## below its rout threshold with fighters still up routs, which ends the fight with living
## enemies (vision pillar 4). Every outcome is a roll on the Rng "battle" stream; apply()
## returns the events presentation draws and log keeps them all. Seeded: the same setup, seed
## and actions give the same log.

const STREAM := "battle"
const ACTION_MOVE := "move"
const ACTION_ATTACK := "attack"
const ACTION_WAIT := "wait"
const ACTION_CHARGE := BattleUnit.MOVE_CHARGE
const ACTION_BLOOD_PRICE := BattleUnit.MOVE_BLOOD_PRICE
const ACTIONS: Array[String] = [
	ACTION_MOVE, ACTION_ATTACK, ACTION_WAIT, ACTION_CHARGE, ACTION_BLOOD_PRICE
]
const BASE_ACTIONS: Array[String] = [ACTION_MOVE, ACTION_ATTACK, ACTION_WAIT]
const EVENT_HIT := "hit"
const EVENT_ROUT := "rout"
const EVENT_ROUND := "round"
const EVENT_INTENT := "intent"

var units: Array[BattleUnit] = []
var winner := -1
## The side whose morale broke with fighters still standing, or -1.
var routed := -1
## The sketch's name for routed, still read by SliceLoop's aftermath.
var surrendered := -1
## The round under way, from 1; a round ends when everyone standing has acted.
var round_number := 0
## Every event since setup, in order (rounds and intents included).
var log: Array[Dictionary] = []

var _rules := {}
var _rng: Rng = null
var _grid := BattleGrid.new()
var _morale := BattleMorale.new()
var _order: Array[BattleUnit] = []
var _turn := 0
var _intents := {}
var _hit_hook := Callable()


## rules: data/balance/battle.json "rules"; field: {"size": Vector2i, "blocked": {Vector2i: true}}
## (walls and props); fighters act in initiative order.
func setup(rules: Dictionary, field: Dictionary, fighters: Array[BattleUnit], rng: Rng) -> void:
	_rules = rules
	_grid.setup(field)
	_rng = rng
	units = fighters
	_order = fighters.duplicate()
	_order.sort_custom(_acts_before)
	_morale.setup(rules)
	winner = -1
	routed = -1
	surrendered = -1
	round_number = 0
	log.clear()
	var loadout_max := _rule("loadout_max")
	for fighter: BattleUnit in fighters:
		if loadout_max > 0 and fighter.moves.size() > loadout_max:
			fighter.moves.resize(loadout_max)
		BattleGrid.face_nearest(fighter, fighters)
	_turn = 0
	_skip_downed()
	_begin_round(log)


## Called with a copy of every "hit" event (attacker "unit", "target", "damage", "cell", "hp",
## "down", "move") after the damage lands and before a down is resolved. It may return an
## Array of event Dictionaries (an injury), logged right after the hit. It must draw any
## randomness from its own Rng stream, never "battle". An invalid Callable turns it off.
func set_hit_hook(hook: Callable) -> void:
	_hit_hook = hook


func is_over() -> bool:
	return winner >= 0


func current() -> BattleUnit:
	return _order[_turn] if not _order.is_empty() else null


func morale(side: int) -> int:
	return _morale.value(side)


func is_shaken(side: int) -> bool:
	return _morale.is_shaken(side)


## Lowers a side's morale before the fight starts (a band shaken by losing its lookout).
func lower_morale(side: int, amount: int) -> void:
	log.append_array(_morale.lower(side, amount))


func unit(unit_id: String) -> BattleUnit:
	for fighter: BattleUnit in units:
		if fighter.id == unit_id:
			return fighter
	return null


## Cells the fighter may move to this turn (within move_cells; a walk ends when engaged).
func reachable(fighter: BattleUnit) -> Dictionary:
	return _grid.reachable(fighter, units, _rule("move_cells"))


## Who acts from now on, the current fighter first: each standing fighter once, in order.
func turn_order() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for i: int in _order.size():
		var fighter := _order[(_turn + i) % _order.size()]
		if fighter.can_act():
			out.append(fighter)
	return out


## What a standing enemy plans for this round, until it acts: {"unit", "kind": "attack" |
## "advance" | "hold", "target"} (BattleAi.intent); {} when it has no plan.
func intent(unit_id: String) -> Dictionary:
	var plan: Dictionary = _intents.get(unit_id, {})
	return plan.duplicate()


## Every plan still to be carried out this round, in turn order.
func intents() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fighter: BattleUnit in turn_order():
		if _intents.has(fighter.id):
			out.append(intent(fighter.id))
	return out


## Applies one action by the current fighter and returns what happened, in order:
## {"type": "move"|"attack"|"damage"|"hit"|"down"|"morale"|"shaken"|"rout"|"end"|"round"|
## "intent"|"turn"|<move id>, ...}. An illegal action changes nothing and returns [].
func apply(action: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var actor := current()
	if is_over() or actor == null:
		return events
	var kind := str(action.get("type", ""))
	if not _legal_kind(actor, kind) or not _act(kind, actor, action, events):
		return events
	_intents.erase(actor.id)
	_check_end(events)
	if not is_over():
		_advance(events)
		events.append({"type": "turn", "unit": current().id})
	log.append_array(events)
	return events


## The definition of a learnt move (battle.json "rules" "moves"), or {}.
func move_def(move: String) -> Dictionary:
	var moves: Variant = _rules.get("moves", {})
	var all: Dictionary = moves if moves is Dictionary else {}
	var found: Variant = all.get(move, {})
	return found if found is Dictionary else {}


func _legal_kind(actor: BattleUnit, kind: String) -> bool:
	if kind in BASE_ACTIONS:
		return true
	var moves: Variant = _rules.get("moves", {})
	var all: Dictionary = moves if moves is Dictionary else {}
	return actor.knows(kind) and all.has(kind)


## Carries out one legal action; false (with no events) when it is not legal.
func _act(kind: String, actor: BattleUnit, action: Dictionary, events: Array[Dictionary]) -> bool:
	match kind:
		ACTION_MOVE:
			return _move(actor, action, events)
		ACTION_ATTACK:
			return _attack(actor, unit(str(action.get("target", ""))), kind, events)
		ACTION_WAIT:
			return true
	return _use_move(kind, actor, action, events)


## A learnt move: a walk to "to" first when the move has "walk", a health price ("hp_cost",
## never the last point), then an attack on "target" with the move's "attack_bonus" and
## "damage_bonus". Refused whole unless every part is legal.
func _use_move(
	kind: String, actor: BattleUnit, action: Dictionary, events: Array[Dictionary]
) -> bool:
	var def := move_def(kind)
	var target := unit(str(action.get("target", "")))
	var to: Variant = action.get("to", actor.cell)
	var cost := _num(def, "hp_cost")
	if not _foe(actor, target) or not to is Vector2i or actor.hp <= cost:
		return false
	var landing: Vector2i = to
	if landing != actor.cell and (def.get("walk") != true or not reachable(actor).has(landing)):
		return false
	if not BattleGrid.adjacent(landing, target.cell):
		return false
	if landing != actor.cell:
		_move(actor, action, events)
	if cost > 0:
		actor.hp -= cost
		events.append({"type": kind, "unit": actor.id, "cost": cost, "hp": actor.hp})
	actor.next_attack_bonus = _num(def, "attack_bonus")
	actor.next_damage_bonus = _num(def, "damage_bonus")
	return _attack(actor, target, kind, events)


func _foe(actor: BattleUnit, target: BattleUnit) -> bool:
	return target != null and not target.down and target.side != actor.side


func _move(actor: BattleUnit, action: Dictionary, events: Array[Dictionary]) -> bool:
	var to: Variant = action.get("to", actor.cell)
	if not to is Vector2i or not reachable(actor).has(to):
		return false
	var target: Vector2i = to
	actor.facing = BattleGrid.toward(actor.cell, target, actor.facing)
	events.append(
		{
			"type": ACTION_MOVE,
			"unit": actor.id,
			"from": actor.cell,
			"to": target,
			"facing": actor.facing
		}
	)
	actor.cell = target
	return true


func _attack(
	actor: BattleUnit, target: BattleUnit, kind: String, events: Array[Dictionary]
) -> bool:
	if not _foe(actor, target) or not BattleGrid.adjacent(actor.cell, target.cell):
		return false
	actor.facing = BattleGrid.toward(actor.cell, target.cell, actor.facing)
	var roll := _rng.roll(STREAM, 1, _rule("die_sides"))
	var need := _rule("hit_base") + target.defense - actor.attack - actor.next_attack_bonus
	actor.next_attack_bonus = 0
	var hit := roll >= need
	events.append(
		{
			"type": ACTION_ATTACK,
			"unit": actor.id,
			"target": target.id,
			"roll": roll,
			"need": need,
			"hit": hit,
			"move": kind,
			"facing": actor.facing
		}
	)
	if hit:
		_wound(actor, target, kind, events)
	actor.next_damage_bonus = 0
	return true


## A hit lands: 1..damage (plus the move's bonus) off the target's health, the hit event and
## its hook, a down at 0.
func _wound(actor: BattleUnit, target: BattleUnit, kind: String, events: Array[Dictionary]) -> void:
	var amount := _rng.roll(STREAM, 1, actor.damage + actor.next_damage_bonus)
	target.hp = maxi(0, target.hp - amount)
	target.wounded = true
	events.append({"type": "damage", "unit": target.id, "amount": amount, "hp": target.hp})
	var hit := {
		"type": EVENT_HIT,
		"unit": actor.id,
		"target": target.id,
		"damage": amount,
		"cell": target.cell,
		"hp": target.hp,
		"down": target.hp == 0,
		"move": kind
	}
	events.append(hit)
	if _hit_hook.is_valid():
		var extra: Variant = _hit_hook.call(hit.duplicate())
		if extra is Array:
			for entry: Variant in extra:
				if entry is Dictionary:
					events.append(entry)
	if target.hp == 0:
		_fall(target, events)


func _fall(fighter: BattleUnit, events: Array[Dictionary]) -> void:
	fighter.down = true
	events.append({"type": "down", "unit": fighter.id})
	events.append_array(_morale.lower(fighter.side, _morale.loss_for(fighter)))


func _check_end(events: Array[Dictionary]) -> void:
	for side: int in BattleUnit.SIDES:
		var standing := _standing(side)
		var other := _other(side)
		if standing == 0:
			winner = other
		elif _morale.breaks(side) and _standing(other) > 0:
			winner = other
			routed = side
			surrendered = side
			events.append({"type": EVENT_ROUT, "side": side, "standing": standing})
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


## The next standing fighter's turn; passing the end of the order starts a new round.
func _advance(events: Array[Dictionary]) -> void:
	var wrapped := false
	for _i: int in _order.size():
		_turn += 1
		if _turn >= _order.size():
			_turn = 0
			wrapped = true
		if _order[_turn].can_act():
			break
	if wrapped:
		_begin_round(events)


func _skip_downed() -> void:
	for _i: int in _order.size():
		if _order[_turn].can_act():
			return
		_turn = (_turn + 1) % _order.size()


## A new round: each standing enemy plans what it will do from what it can see.
func _begin_round(events: Array[Dictionary]) -> void:
	round_number += 1
	_intents.clear()
	events.append({"type": EVENT_ROUND, "round": round_number})
	var sight := _rule("sight_cells")
	for fighter: BattleUnit in _order:
		if fighter.side == BattleUnit.ENEMY and fighter.can_act():
			var plan := BattleAi.intent(self, fighter, sight)
			_intents[fighter.id] = plan
			var event := plan.duplicate()
			event["type"] = EVENT_INTENT
			events.append(event)


func _acts_before(a: BattleUnit, b: BattleUnit) -> bool:
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	return a.id < b.id


func _rule(key: String) -> int:
	return _num(_rules, key)


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0
