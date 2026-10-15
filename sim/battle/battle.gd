class_name Battle
extends RefCounted
## The compact turn-based battle (Phase 2 milestone 4, D-064/D-066), grown from the slice's
## sketch (docs/specs/art_direction_slice.md §2a step 6). This file is the facade every caller
## uses (setup, apply, the reads presentation and the AI make); the rules live in modules, so
## Phase 4's packages (docs/plans/phase4_combat.md) each own their own file:
## - BattleRules (battle_rules.gd): the battle.json "rules" knobs and learnt moves;
## - BattleTurns (battle_turns.gd): the strict turn order by initiative (ties by id), rounds;
## - BattleIntents (battle_intents.gd): each enemy's round plan from what it sees (BattleAi);
## - BattleActions (battle_actions.gd): move, attack, wait and the learnt moves, legal or not;
## - BattleResolver (battle_resolver.gd): one blow's rolls, damage, the hit hook, a down;
## - BattleMorale (battle_morale.gd): each side's morale, shaken and breaking;
## - BattleEnd (battle_end.gd): a wipe or a rout ends the fight;
## - BattleGrid, BattleUnit, BattleAi: the grid with blocking, a fighter, the enemy's choices.
## Every outcome is a roll on the Rng "battle" stream; apply() returns the events presentation
## draws and log keeps them all, rounds and intents included. Seeded: the same setup, seed and
## actions give the same log (tests/battle/golden_checks.gd pins it).

const STREAM := BattleResolver.STREAM
const ACTION_MOVE := BattleActions.MOVE
const ACTION_ATTACK := BattleActions.ATTACK
const ACTION_WAIT := BattleActions.WAIT
const ACTION_CHARGE := BattleUnit.MOVE_CHARGE
const ACTION_BLOOD_PRICE := BattleUnit.MOVE_BLOOD_PRICE
const ACTIONS: Array[String] = [
	ACTION_MOVE, ACTION_ATTACK, ACTION_WAIT, ACTION_CHARGE, ACTION_BLOOD_PRICE
]
const BASE_ACTIONS: Array[String] = BattleActions.BASE
const EVENT_HIT := BattleResolver.EVENT_HIT
const EVENT_ROUT := BattleEnd.EVENT_ROUT
const EVENT_ROUND := BattleTurns.EVENT_ROUND
const EVENT_INTENT := BattleIntents.EVENT_INTENT
const EVENT_TURN := "turn"

var units: Array[BattleUnit] = []
var winner := -1
## The side whose morale broke with fighters still standing, or -1.
var routed := -1
## The sketch's name for routed, still read by SliceLoop's aftermath.
var surrendered := -1
## The round under way, from 1; a round ends when everyone standing has acted.
var round_number: int:
	get:
		return _turns.round_number
## Every event since setup, in order (rounds and intents included).
var log: Array[Dictionary] = []

var _rules := BattleRules.new()
var _grid := BattleGrid.new()
var _morale := BattleMorale.new()
var _turns := BattleTurns.new()
var _intents := BattleIntents.new()
var _resolver := BattleResolver.new()
var _actions := BattleActions.new()


## rules: data/balance/battle.json "rules"; field: {"size": Vector2i, "blocked": {Vector2i: true}}
## (walls and props); fighters act in initiative order.
func setup(rules: Dictionary, field: Dictionary, fighters: Array[BattleUnit], rng: Rng) -> void:
	_rules.setup(rules)
	_grid.setup(field)
	units = fighters
	_turns.setup(fighters)
	_morale.setup(rules)
	_resolver.setup(_rules, rng, _morale)
	_actions.setup(_rules, _resolver)
	winner = -1
	routed = -1
	surrendered = -1
	log.clear()
	var loadout_max := _rules.num("loadout_max")
	for fighter: BattleUnit in fighters:
		if loadout_max > 0 and fighter.moves.size() > loadout_max:
			fighter.moves.resize(loadout_max)
		BattleGrid.face_nearest(fighter, fighters)
	_turns.skip_downed()
	_begin_round(log)


## Called with a copy of every "hit" event (attacker "unit", "target", "damage", "cell", "hp",
## "down", "move") after the damage lands and before a down is resolved. It may return an
## Array of event Dictionaries (an injury), logged right after the hit. It must draw any
## randomness from its own Rng stream, never "battle". An invalid Callable turns it off.
func set_hit_hook(hook: Callable) -> void:
	_resolver.set_hit_hook(hook)


func is_over() -> bool:
	return winner >= 0


func current() -> BattleUnit:
	return _turns.current()


func morale(side: int) -> int:
	return _morale.value(side)


func is_shaken(side: int) -> bool:
	return _morale.is_shaken(side)


## Lowers a side's morale before the fight starts (a band shaken by losing its lookout).
func lower_morale(side: int, amount: int) -> void:
	log.append_array(_morale.lower(side, amount))


## The given side takes the first turn (an ambush): the turn moves to that side's first
## fighter in the order, and the strict order carries on from there.
func give_first_turn(side: int) -> void:
	_turns.give_first_turn(side)


func unit(unit_id: String) -> BattleUnit:
	for fighter: BattleUnit in units:
		if fighter.id == unit_id:
			return fighter
	return null


## Cells the fighter may move to this turn (within move_cells; a walk ends when engaged).
func reachable(fighter: BattleUnit) -> Dictionary:
	return _grid.reachable(fighter, units, _rules.num("move_cells"))


## Who acts from now on, the current fighter first: each standing fighter once, in order.
func turn_order() -> Array[BattleUnit]:
	return _turns.turn_order()


## What a standing enemy plans for this round, until it acts: {"unit", "kind": "attack" |
## "advance" | "hold", "target"} (BattleAi.intent); {} when it has no plan.
func intent(unit_id: String) -> Dictionary:
	return _intents.plan(unit_id)


## Every plan still to be carried out this round, in turn order.
func intents() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fighter: BattleUnit in turn_order():
		if _intents.has_plan(fighter.id):
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
	if not _actions.legal_kind(actor, kind) or not _actions.act(self, actor, action, events):
		return events
	_intents.done(actor.id)
	BattleEnd.check(self, _morale, events)
	if not is_over():
		if _turns.advance():
			_begin_round(events)
		events.append({"type": EVENT_TURN, "unit": current().id})
	log.append_array(events)
	return events


## The definition of a learnt move (battle.json "rules" "moves"), or {}.
func move_def(move: String) -> Dictionary:
	return _rules.move_def(move)


## A new round: each standing enemy plans what it will do from what it can see.
func _begin_round(events: Array[Dictionary]) -> void:
	events.append(_turns.next_round())
	events.append_array(_intents.plan_round(self, _turns.order(), _rules.num("sight_cells")))
