class_name BattleActions
extends RefCounted
## The action kit (D-066): what a fighter may do on his turn and what it does. Base actions:
## move up to move_cells (8-way, no corner cutting, a walk ends when engaged), attack an
## adjacent enemy, wait. A learnt move (battle.json "rules" "moves", only if in the fighter's
## loadout): a walk first when it has "walk", a health price ("hp_cost", never the last point),
## then an attack with its "attack_bonus" and "damage_bonus". The weapon action of the
## fighter's class (battle.json "rules" "actions" "weapon", BattleKit): a blow on a foe within
## the class's "reach" (a spear's 2); a "ranged" class's shot is refused until the bow's line of
## fire exists (Phase 4 P1c). Only what the fighter's kit holds is legal beyond the base three.
## An action is refused whole (no events, nothing changed) unless every part is legal. The
## blow is BattleResolver's.

const MOVE := "move"
const ATTACK := "attack"
const WAIT := "wait"
const BASE: Array[String] = [MOVE, ATTACK, WAIT]

var kit := BattleKit.new()

var _rules: BattleRules = null
var _resolver: BattleResolver = null


func setup(rules: BattleRules, resolver: BattleResolver) -> void:
	_rules = rules
	_resolver = resolver
	kit.setup(rules)


## True when the actor may try an action of this kind at all (base, or one in his kit).
func legal_kind(actor: BattleUnit, kind: String) -> bool:
	if kind in BASE:
		return true
	return kit.has(actor, kind)


## Carries out the actor's action (its "type" already legal_kind); false (with no events)
## when it is not legal here.
func act(battle: Battle, actor: BattleUnit, action: Dictionary, events: Array[Dictionary]) -> bool:
	var kind := str(action.get("type", ""))
	match kind:
		MOVE:
			return _move(battle, actor, action, events)
		ATTACK:
			return _resolver.attack(actor, battle.unit(str(action.get("target", ""))), kind, events)
		WAIT:
			return true
	if kind == kit.weapon_action(actor):
		return _strike(battle, actor, action, events)
	return _use_move(battle, actor, action, events)


## The weapon action: a blow on "target" within the class's "reach" (at least 1); a "ranged"
## class is refused until its shot exists (P1c). The resolver reads the reach (BattleRules).
func _strike(
	battle: Battle, actor: BattleUnit, action: Dictionary, events: Array[Dictionary]
) -> bool:
	var kind := str(action.get("type", ""))
	var def := _rules.weapon_def(kind)
	if def.get("ranged") == true:
		return false
	return _resolver.attack(actor, battle.unit(str(action.get("target", ""))), kind, events)


## A learnt move: a walk to "to" first when the move has "walk", a health price ("hp_cost",
## never the last point), then an attack on "target" with the move's "attack_bonus" and
## "damage_bonus". Refused whole unless every part is legal.
func _use_move(
	battle: Battle, actor: BattleUnit, action: Dictionary, events: Array[Dictionary]
) -> bool:
	var kind := str(action.get("type", ""))
	var def := _rules.move_def(kind)
	var target := battle.unit(str(action.get("target", "")))
	var to: Variant = action.get("to", actor.cell)
	var cost := BattleRules.read(def, "hp_cost")
	if not BattleResolver.foe(actor, target) or not to is Vector2i or actor.hp <= cost:
		return false
	var landing: Vector2i = to
	if (
		landing != actor.cell
		and (def.get("walk") != true or not battle.reachable(actor).has(landing))
	):
		return false
	if not BattleGrid.adjacent(landing, target.cell):
		return false
	if landing != actor.cell:
		_move(battle, actor, action, events)
	if cost > 0:
		actor.hp -= cost
		events.append({"type": kind, "unit": actor.id, "cost": cost, "hp": actor.hp})
	actor.next_attack_bonus = BattleRules.read(def, "attack_bonus")
	actor.next_damage_bonus = BattleRules.read(def, "damage_bonus")
	return _resolver.attack(actor, target, kind, events)


func _move(
	battle: Battle, actor: BattleUnit, action: Dictionary, events: Array[Dictionary]
) -> bool:
	var to: Variant = action.get("to", actor.cell)
	if not to is Vector2i or not battle.reachable(actor).has(to):
		return false
	var target: Vector2i = to
	actor.facing = BattleGrid.toward(actor.cell, target, actor.facing)
	events.append(
		{"type": MOVE, "unit": actor.id, "from": actor.cell, "to": target, "facing": actor.facing}
	)
	actor.cell = target
	return true
