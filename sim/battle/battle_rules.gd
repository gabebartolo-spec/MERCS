class_name BattleRules
extends RefCounted
## A read-only view of data/balance/battle.json "rules" for the battle's modules: whole-number
## knobs (a float in the JSON rounds), the learnt moves by id and the action catalogue
## ("actions": each weapon class's action, the techniques that may be learnt). Holds nothing
## else and rolls nothing; every module of one Battle reads the same instance.

## The catalogue's categories (Q-A, director 2026-10-15: one weapon action + four learnt moves;
## no item slot until items exist).
const WEAPON := "weapon"
const TECHNIQUE := "technique"
const CATEGORIES: Array[String] = [WEAPON, TECHNIQUE]

var data := {}


func setup(rules: Dictionary) -> void:
	data = rules


## A whole-number knob of "rules" (0 when absent or not a number).
func num(key: String) -> int:
	return read(data, key)


## The definition of a learnt move ("rules" "moves"), or {}.
func move_def(move: String) -> Dictionary:
	var found: Variant = _moves().get(move, {})
	return found if found is Dictionary else {}


## True when "rules" "moves" defines the move.
func has_move(move: String) -> bool:
	return _moves().has(move)


## The weapon action of a class ("actions" "weapon": its knobs, e.g. "reach", "ranged"), or {}.
func weapon_def(weapon_class: String) -> Dictionary:
	var found: Variant = actions(WEAPON).get(weapon_class, {})
	return found if found is Dictionary else {}


## How far an action of this kind strikes, in grid cells: a weapon action's "reach" (at least
## 1); 1 for every other kind (the plain blow, the learnt moves).
func reach(kind: String) -> int:
	return maxi(1, read(weapon_def(kind), "reach"))


## True when the catalogue lists the technique and "moves" defines its numbers.
func is_technique(move: String) -> bool:
	return actions(TECHNIQUE).get(move) == true and has_move(move)


## One category of the action catalogue ("rules" "actions"), {} when absent.
func actions(category: String) -> Dictionary:
	var catalogue: Variant = data.get("actions", {})
	if not catalogue is Dictionary:
		return {}
	var block: Dictionary = catalogue
	var found: Variant = block.get(category, {})
	return found if found is Dictionary else {}


## Every action id in the catalogue, weapon actions first, in data order.
func action_ids() -> Array[String]:
	var out: Array[String] = []
	for category: String in CATEGORIES:
		for key: Variant in actions(category):
			out.append(str(key))
	return out


## A whole number from any data block: an int as it is, a float rounded, else 0.
static func read(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0


func _moves() -> Dictionary:
	var moves: Variant = data.get("moves", {})
	return moves if moves is Dictionary else {}
