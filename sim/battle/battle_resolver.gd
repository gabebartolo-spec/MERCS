class_name BattleResolver
extends RefCounted
## Resolves one blow (D-066): the attack roll (d20 + attack + the move's bonus against
## hit_base + defense), and on a hit the damage (1..damage plus the move's bonus) off the
## target's health, the "hit" event and its hook, and a down at 0 that costs the side morale.
## Every roll is on the Rng "battle" stream, in a fixed order: the attack die, then on a hit
## the damage die. Equipment physics (Phase 4, Q20) belongs here.

const STREAM := "battle"
const EVENT_ATTACK := "attack"
const EVENT_DAMAGE := "damage"
const EVENT_HIT := "hit"
const EVENT_DOWN := "down"

var _rules: BattleRules = null
var _rng: Rng = null
var _morale: BattleMorale = null
var _hit_hook := Callable()


func setup(rules: BattleRules, rng: Rng, morale: BattleMorale) -> void:
	_rules = rules
	_rng = rng
	_morale = morale


## See Battle.set_hit_hook. Kept across setup().
func set_hit_hook(hook: Callable) -> void:
	_hit_hook = hook


## True when the target stands on the other side.
static func foe(actor: BattleUnit, target: BattleUnit) -> bool:
	return target != null and not target.down and target.side != actor.side


## The actor attacks an adjacent foe with move kind; false (no events, no roll) when the
## target is not a foe beside him. Clears the actor's one-attack bonuses.
func attack(actor: BattleUnit, target: BattleUnit, kind: String, events: Array[Dictionary]) -> bool:
	if not foe(actor, target) or not BattleGrid.adjacent(actor.cell, target.cell):
		return false
	actor.facing = BattleGrid.toward(actor.cell, target.cell, actor.facing)
	var roll := _rng.roll(STREAM, 1, _rules.num("die_sides"))
	var need := _rules.num("hit_base") + target.defense - actor.attack - actor.next_attack_bonus
	actor.next_attack_bonus = 0
	var hit := roll >= need
	events.append(
		{
			"type": EVENT_ATTACK,
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
	events.append({"type": EVENT_DAMAGE, "unit": target.id, "amount": amount, "hp": target.hp})
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
	events.append({"type": EVENT_DOWN, "unit": fighter.id})
	events.append_array(_morale.lower(fighter.side, _morale.loss_for(fighter)))
