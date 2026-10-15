extends RefCounted
## Shared by the company suite and the company_merc effect case: the company's data as the
## game loads it, and one fixed fight (one company merc against the slice scenario's band,
## both sides played by MercPlay) that can be fought with any merc and any seed.

const MERCS := "res://data/mercs.json"
const BATTLE := "res://data/balance/battle.json"
const COMPANY := "res://data/balance/company.json"
const ECONOMY := "res://data/balance/economy.json"
const FACTIONS := "res://data/factions.json"
const EQUIPMENT := "res://data/equipment.json"
const RECRUITS := "res://data/recruits.json"
const SCENARIOS := "res://data/scenarios.json"
const MAX_ACTIONS := 300
## The band the merc faces: the scenario's first FOES enemies (the chief and a bandit).
const FOES := 2


static func json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## What a Company is made from, read from the data files.
static func defs() -> Dictionary:
	var battle := json(BATTLE)
	return {
		"mercs": json(MERCS),
		"fighters": battle.get("fighters", {}),
		"company": json(COMPANY),
		"economy": json(ECONOMY),
		"factions": json(FACTIONS),
		"equipment": json(EQUIPMENT),
		"recruits": json(RECRUITS),
	}


static func rules() -> Dictionary:
	return sect(json(BATTLE), "rules")


## A whole number from battle.json "rules".
static func rule(key: String) -> int:
	return Merc.whole(rules().get(key, 0))


## One fighter's numbers from battle.json.
static func fighter(kind: String) -> Dictionary:
	return sect(sect(json(BATTLE), "fighters"), kind)


## A block's sub-dictionary (the same object, so a test may change it), {} if absent.
static func sect(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}


static func rows(block: Dictionary, key: String) -> Array:
	var value: Variant = block.get(key, [])
	return value if value is Array else []


## One merc of `company` alone at the scenario's first company cell, against the scenario's
## band (its first FOES enemies, no lookout), the battle on the Rng "battle" stream of
## `seed_value`. Returns {"won": bool, "hp": merc's hp left, "log": events, "battle": Battle}.
static func fight(company: Company, merc_id: String, seed_value: int) -> Dictionary:
	var setup := sect(_scenario(), "battle")
	var cells := rows(setup, "company_cells")
	var ids: Array[String] = [merc_id]
	var first: Array = cells[0]
	var spots: Array[Vector2i] = [_cell(first)]
	var fighters := company.battle_units(ids, spots, BattleUnit.COMPANY)
	var enemies := rows(setup, "enemies")
	for i: int in mini(FOES, enemies.size()):
		var enemy: Dictionary = enemies[i]
		var kind := str(enemy.get("fighter", ""))
		var enemy_cell: Array = enemy.get("cell", [0, 0])
		fighters.append(
			BattleUnit.make("%s_%d" % [kind, i], BattleUnit.ENEMY, _cell(enemy_cell), fighter(kind))
		)
	var grid := rows(setup, "grid")
	var battle := Battle.new()
	battle.setup(rules(), {"size": _cell(grid)}, fighters, Rng.from_seed(seed_value))
	var log := MercPlay.play_out(battle, rules(), MAX_ACTIONS)
	var mine := battle.unit(merc_id)
	return {
		"won": battle.winner == BattleUnit.COMPANY,
		"hp": mine.hp,
		"log": log,
		"battle": battle,
	}


## How many events of a type a log holds.
static func count(log: Array[Dictionary], type: String) -> int:
	return log.filter(func(event: Dictionary) -> bool: return event.get("type") == type).size()


static func _scenario() -> Dictionary:
	var list := rows(json(SCENARIOS), "scenarios")
	var first: Dictionary = list[0]
	return first


static func _cell(pair: Array) -> Vector2i:
	return Vector2i(Merc.whole(pair[0]), Merc.whole(pair[1]))
