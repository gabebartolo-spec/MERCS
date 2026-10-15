class_name BattleRules
extends RefCounted
## A read-only view of data/balance/battle.json "rules" for the battle's modules: whole-number
## knobs (a float in the JSON rounds) and the learnt moves by id. Holds nothing else and rolls
## nothing; every module of one Battle reads the same instance.

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
