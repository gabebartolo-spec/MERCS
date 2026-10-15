class_name BattleResolver
extends RefCounted
## Resolves one blow (D-066): the attack roll (d20 + attack + the move's bonus against
## hit_base + defense), and on a hit the damage (1..damage plus the move's bonus) off the
## target's health, the "hit" event and its hook, and a down at 0 that costs the side morale.
## Every roll is on the Rng "battle" stream, in a fixed order: the attack die, then on a hit
## the damage die. Equipment physics (BattleGear, D-092) adjusts the numbers, never the rolls:
## a shield adds defense, an axe splits a shield, armour soaks damage unless the blow finds its
## gap. odds() computes the same numbers without rolling (the hover, P7).

const STREAM := "battle"
const EVENT_ATTACK := "attack"
const EVENT_DAMAGE := "damage"
const EVENT_HIT := "hit"
const EVENT_DOWN := "down"
const PERCENT := 100

var _rules: BattleRules = null
var _rng: Rng = null
var _morale: BattleMorale = null
var _hit_hook := Callable()
var _gear := BattleGear.new()


func setup(rules: BattleRules, rng: Rng, morale: BattleMorale) -> void:
	_rules = rules
	_rng = rng
	_morale = morale
	_gear.setup(rules)


## Armour's effect on each fighter's initiative (before the turn order is drawn up).
func fit(rules: BattleRules, fighters: Array[BattleUnit]) -> void:
	_gear.setup(rules)
	_gear.fit(fighters)


## See Battle.set_hit_hook. Kept across setup().
func set_hit_hook(hook: Callable) -> void:
	_hit_hook = hook


## True when the target stands on the other side.
static func foe(actor: BattleUnit, target: BattleUnit) -> bool:
	return target != null and not target.down and target.side != actor.side


## The actor attacks a foe within the reach of move kind (BattleRules.reach: 1, beside him, but
## for a weapon action that reaches further, the spear's 2) with move kind; false (no events,
## no roll) when the target is not a foe within reach. Clears the actor's one-attack bonuses.
func attack(actor: BattleUnit, target: BattleUnit, kind: String, events: Array[Dictionary]) -> bool:
	if not foe(actor, target) or BattleGrid.gap(actor.cell, target.cell) > _rules.reach(kind):
		return false
	actor.facing = BattleGrid.toward(actor.cell, target.cell, actor.facing)
	var roll := _rng.roll(STREAM, 1, _rules.num("die_sides"))
	var need := _need(actor, target, actor.next_attack_bonus)
	actor.next_attack_bonus = 0
	var hit := roll >= need
	var splits := _gear.splits_shield(actor, target, roll, need)
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
	if splits:
		target.shield = false
		events.append({"type": BattleGear.EVENT_SHIELD_BROKEN, "unit": target.id, "by": actor.id})
	if hit:
		_wound(actor, target, kind, events)
	actor.next_damage_bonus = 0
	return true


## A hit lands: 1..damage (plus the move's bonus) off the target's health, the hit event and
## its hook, a down at 0.
func _wound(actor: BattleUnit, target: BattleUnit, kind: String, events: Array[Dictionary]) -> void:
	var rolled := _rng.roll(STREAM, 1, actor.damage + actor.next_damage_bonus)
	var amount := _gear.after_soak(rolled, actor, target)
	target.hp = maxi(0, target.hp - amount)
	target.wounded = true
	var damage := {"type": EVENT_DAMAGE, "unit": target.id, "amount": amount, "hp": target.hp}
	if amount < rolled:
		damage["soaked"] = rolled - amount
	events.append(damage)
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


## What a blow by actor on target would be, computed, never rolled (Battle.odds): {"need": the
## die roll that hits, "die_sides", "chance": whole percent, "damage_min", "damage_max" after
## the armour, "soak", "splits_shield": true when the blow can split his shield}. move: the
## learnt move's definition ({} for a plain attack). {} when the target is not a foe.
func odds(actor: BattleUnit, target: BattleUnit, move: Dictionary) -> Dictionary:
	if actor == null or not foe(actor, target):
		return {}
	var sides := _rules.num("die_sides")
	var need := _need(actor, target, BattleRules.read(move, "attack_bonus"))
	var faces := clampi(sides - maxi(need, 1) + 1, 0, sides)
	var top := actor.damage + BattleRules.read(move, "damage_bonus")
	return {
		"need": need,
		"die_sides": sides,
		"chance": floori(float(faces * PERCENT) / float(maxi(sides, 1))),
		"damage_min": _gear.after_soak(1, actor, target),
		"damage_max": _gear.after_soak(top, actor, target),
		"soak": _gear.soak(actor, target),
		"splits_shield": _gear.splits_shield(actor, target, sides, need),
	}


## The roll that hits: hit_base + the target's defense (shield included) - attack - bonus.
func _need(actor: BattleUnit, target: BattleUnit, bonus: int) -> int:
	return _rules.num("hit_base") + _gear.defense(target) - actor.attack - bonus


func _fall(fighter: BattleUnit, events: Array[Dictionary]) -> void:
	fighter.down = true
	events.append({"type": EVENT_DOWN, "unit": fighter.id})
	events.append_array(_morale.lower(fighter.side, _morale.loss_for(fighter)))
