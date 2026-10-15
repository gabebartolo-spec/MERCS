class_name BattleGear
extends RefCounted
## Equipment physics (Phase 4 P1b; director's rulings D-092, 2026-10-15): a few physical rules
## between a fighter's weapon class, armour class and shield, each a small whole-number
## adjustment read from data/balance/battle.json "rules" "gear". Never a chart of multipliers or
## a class-against-class table (pillar 3): each class has a few physical properties and the
## same four rules read them.
## 1. Armour soaks: a hit loses the armour's "soak" off its damage (never below "min_damage"),
##    unless the blow is one the armour has a gap for (mail is open to thrusts; maces dent plate).
## 2. A shield adds its "defense" to the bearer's while it is whole.
## 3. A weapon that "breaks_shields" (the axe) splits a shield whenever the blow would have hit
##    without it; the shield is gone for the rest of the fight.
## 4. Armour may change initiative (plate is slow).
## A weapon's blow is the first of BLOWS it sets true; a fighter with no weapon class strikes no
## particular blow, so armour soaks it in full. Spear reach and the bow's shot are read by the
## action kit and the ranged rules (P1a, P1c) from the same block. Nothing here rolls.

const SWORD := "sword"
const AXE := "axe"
const SPEAR := "spear"
const MACE := "mace"
const BOW := "bow"
const WEAPONS: Array[String] = [SWORD, AXE, SPEAR, MACE, BOW]
const LEATHER := "leather"
const MAIL := "mail"
const PLATE := "plate"
const ARMOURS: Array[String] = [LEATHER, MAIL, PLATE]
const SHIELD := "shield"
const BLOWS: Array[String] = ["cut", "thrust", "crush"]
const EVENT_SHIELD_BROKEN := "shield_broken"
const WEAPON_KEY := "weapon_class"
const ARMOUR_KEY := "armour_class"
const GEAR_KEY := "gear"

var _gear := {}


## rules: the battle's BattleRules; reads its "gear" block (none: every rule adds nothing).
func setup(rules: BattleRules) -> void:
	var found: Variant = rules.data.get(GEAR_KEY, {})
	_gear = found if found is Dictionary else {}


## Dresses a fighter from fighter data: "weapon_class" and "armour_class" by name and "shield"
## true (a merc's gear line, Merc.to_battle_unit), or battle.json's "gear" as {class: true}.
## A named class outranks the "gear" block; an unknown name is no class.
static func dress(unit: BattleUnit, stats: Dictionary) -> void:
	var worn: Variant = stats.get(GEAR_KEY, {})
	var flags: Dictionary = worn if worn is Dictionary else {}
	unit.weapon_class = _named(stats.get(WEAPON_KEY), WEAPONS, flags)
	unit.armour_class = _named(stats.get(ARMOUR_KEY), ARMOURS, flags)
	unit.shield = stats.get(SHIELD) == true or flags.get(SHIELD) == true


## Rule 4: what each fighter's armour does to his initiative (set, never added twice).
func fit(fighters: Array[BattleUnit]) -> void:
	for fighter: BattleUnit in fighters:
		fighter.gear_initiative = armour_initiative(_gear, fighter.armour_class)


## Rule 4 from a "gear" block (battle.json "rules" "gear"): what this armour class adds to
## initiative. The one source for the number a fighter acts at and the number the company
## screen shows (Merc.fighting_initiative).
static func armour_initiative(gear: Dictionary, armour_class: String) -> int:
	var armours: Variant = gear.get("armour", {})
	var table: Dictionary = armours if armours is Dictionary else {}
	var found: Variant = table.get(armour_class, {})
	var picked: Dictionary = found if found is Dictionary else {}
	return BattleRules.read(picked, "initiative")


## Rule 2: the defense an attacker must beat, the shield included while it is whole.
func defense(target: BattleUnit) -> int:
	return target.defense + shield_defense(target)


func shield_defense(target: BattleUnit) -> int:
	return BattleRules.read(_block(SHIELD), "defense") if target.shield else 0


## Rule 1: how much of a hit the target's armour takes off (0 through a gap).
func soak(actor: BattleUnit, target: BattleUnit) -> int:
	var armour := _armour(target)
	var gaps: Variant = armour.get("gaps", {})
	var open: Dictionary = gaps if gaps is Dictionary else {}
	if open.get(blow(actor)) == true:
		return 0
	return BattleRules.read(armour, "soak")


## Damage after the soak, never below min_damage (nor above the rolled amount).
func after_soak(amount: int, actor: BattleUnit, target: BattleUnit) -> int:
	var floor_damage := mini(amount, BattleRules.read(_gear, "min_damage"))
	return maxi(floor_damage, amount - soak(actor, target))


## Rule 3: true when this blow splits the target's shield (the roll beat the defense without it).
func splits_shield(actor: BattleUnit, target: BattleUnit, roll: int, need: int) -> bool:
	if not target.shield or _weapon(actor).get("breaks_shields") != true:
		return false
	return roll >= need - shield_defense(target)


## The blow the actor's weapon strikes ("cut", "thrust", "crush"), or "" with no class.
func blow(actor: BattleUnit) -> String:
	var weapon := _weapon(actor)
	for kind: String in BLOWS:
		if weapon.get(kind) == true:
			return kind
	return ""


## A weapon class's knobs (rules.gear.weapons), e.g. "reach" for the action kit.
func weapon_def(weapon_class: String) -> Dictionary:
	var found: Variant = _block("weapons").get(weapon_class, {})
	return found if found is Dictionary else {}


func _weapon(fighter: BattleUnit) -> Dictionary:
	return weapon_def(fighter.weapon_class)


func _armour(fighter: BattleUnit) -> Dictionary:
	var found: Variant = _block("armour").get(fighter.armour_class, {})
	return found if found is Dictionary else {}


func _block(key: String) -> Dictionary:
	var found: Variant = _gear.get(key, {})
	return found if found is Dictionary else {}


static func _named(named: Variant, known: Array[String], flags: Dictionary) -> String:
	if named is String and str(named) in known:
		return str(named)
	for kind: String in known:
		if flags.get(kind) == true:
			return kind
	return ""
