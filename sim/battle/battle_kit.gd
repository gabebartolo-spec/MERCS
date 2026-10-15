class_name BattleKit
extends RefCounted
## A fighter's action kit (Phase 4 P1a; director Q-A, 2026-10-15: "1 weapon + 4 moves"): the
## one weapon action his gear gives, then the learnt moves he took into the fight, at most
## "loadout_max" of them, each listed as a technique in the catalogue (battle.json "rules"
## "actions") with its numbers in "rules" "moves". No item slot until items exist. The weapon
## action is the class's ("actions" "weapon": sword, axe, spear, mace, bow; director Q-B); a
## fighter without a class in the catalogue has the plain blow, "attack". Move, attack and wait
## are always open and are not part of the kit. Reads only; rolls nothing.

var _rules: BattleRules = null


func setup(rules: BattleRules) -> void:
	_rules = rules


## The fighter's kit, in order: his weapon action, then his techniques in loadout order.
func of(fighter: BattleUnit) -> Array[String]:
	var out: Array[String] = [weapon_action(fighter)]
	out.append_array(techniques(fighter))
	return out


## True when the action is in the fighter's kit.
func has(fighter: BattleUnit, kind: String) -> bool:
	return of(fighter).has(kind)


## The action the fighter's weapon class gives: the class id when the catalogue lists it,
## else the plain blow.
func weapon_action(fighter: BattleUnit) -> String:
	var weapon := fighter.weapon_class
	if weapon != "" and _rules.actions(BattleRules.WEAPON).has(weapon):
		return weapon
	return BattleActions.ATTACK


## The fighter's learnt moves that are catalogued techniques, in loadout order, at most
## "loadout_max" (none counted past it; a non-positive cap means no cap).
func techniques(fighter: BattleUnit) -> Array[String]:
	var cap := _rules.num("loadout_max")
	var out: Array[String] = []
	for move: String in fighter.moves:
		if cap > 0 and out.size() >= cap:
			break
		if _rules.is_technique(move) and move not in out:
			out.append(move)
	return out
