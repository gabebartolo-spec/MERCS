class_name EncounterBattle
extends RefCounted
## Builds the street battle an encounter on the road leads into (Phase 2 M2), from the same
## data the slice loop's battle uses: the company, its cells and the grid come from the
## authored scenario (the roster replaces them: CompanyWounds), the enemies from the pending
## encounter, the fighters and rules from data/balance/battle.json. An ambush gives the enemy
## the first turn. Reads the Rng "battle" stream through Battle. The sim decides every roll.


## scenario: one entry of data/scenarios.json; battle_data: data/balance/battle.json;
## pending: WorldSim.pending_encounter(); company_units: the company's fighters from
## CompanyWounds.units() (the road fields the roster); with none, the scenario's own pair.
static func build(
	pending: Dictionary,
	scenario: Dictionary,
	battle_data: Dictionary,
	rng: Rng,
	company_units: Array[BattleUnit] = []
) -> Battle:
	var setup := _dict(scenario, "battle")
	var fighters_data := _dict(battle_data, "fighters")
	var fighters: Array[BattleUnit] = company_units.duplicate()
	var cells := _list(setup, "company_cells")
	var company := _list(scenario, "company")
	for i: int in mini(company.size(), cells.size()):
		if not company_units.is_empty():
			break
		var kind := str(company[i])
		fighters.append(
			BattleUnit.make(kind, BattleUnit.COMPANY, _cell(cells[i]), _dict(fighters_data, kind))
		)
	var index := 0
	for entry: Variant in _list(pending, "enemies"):
		var enemy: Dictionary = entry if entry is Dictionary else {}
		var kind := str(enemy.get("fighter", ""))
		var unit_id := "%s_%d" % [kind, index]
		fighters.append(
			BattleUnit.make(
				unit_id, BattleUnit.ENEMY, _cell(enemy.get("cell", [])), _dict(fighters_data, kind)
			)
		)
		index += 1
	var battle := Battle.new()
	battle.setup(_dict(battle_data, "rules"), {"size": _cell(setup.get("grid", []))}, fighters, rng)
	if pending.get("enemy_first", false) == true:
		battle.give_first_turn(BattleUnit.ENEMY)
	return battle


## The scenario's cells for the company, in order (where CompanyWounds.units() stands them).
static func company_cells(scenario: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for entry: Variant in _list(_dict(scenario, "battle"), "company_cells"):
		cells.append(_cell(entry))
	return cells


## What WorldSim.resolve_encounter() takes: {"won": bool, "surrendered": bool}.
static func result(battle: Battle) -> Dictionary:
	var won := battle.is_over() and battle.winner == BattleUnit.COMPANY
	return {"won": won, "surrendered": battle.surrendered == BattleUnit.ENEMY}


static func _cell(value: Variant) -> Vector2i:
	var pair: Array = value if value is Array else []
	if pair.size() <= 1:
		return Vector2i.ZERO
	var x: float = pair[0] if pair[0] is float or pair[0] is int else 0.0
	var y: float = pair[1] if pair[1] is float or pair[1] is int else 0.0
	return Vector2i(roundi(x), roundi(y))


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}


static func _list(block: Dictionary, key: String) -> Array:
	var value: Variant = block.get(key, [])
	if not value is Array:
		return []
	var items: Array = value
	return items.duplicate()
