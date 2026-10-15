class_name Loot
extends RefCounted
## What a won fight leaves (Phase 2 milestone 6): coin, and sometimes one piece of the gear the
## fallen enemies carried, in its worn form (Phase 5 C6, director: "Loot: yes, worn (battered)
## gear from fallen enemies"; Q-11; Armoury.spoils). How much, and how likely, by the
## encounter's type, is in data/balance/economy.json "loot". Seeded on the Rng "loot" stream:
## the same seed and the same fights loot the same things.

const STREAM := "loot"
## The key of a battle result (EncounterBattle.result) listing the battle classes the fallen
## enemies carried, weapon then armour, enemy by enemy.
const FALLEN_GEAR := "fallen_gear"


## {"coin": int, "item": id or ""} for a win over an encounter of `kind`. pool: the pieces the
## fallen left (Armoury.spoils), one drawn on a hit; none, no piece. Nothing (0, "") for a kind
## the data does not list.
static func roll(rules: Dictionary, kind: String, pool: Array[String], rng: Rng) -> Dictionary:
	var row: Variant = rules.get(kind, {})
	if not row is Dictionary:
		return {"coin": 0, "item": ""}
	var numbers: Dictionary = row
	var coin := rng.roll(STREAM, _knob(numbers, "coin_min"), _knob(numbers, "coin_max"))
	var item := ""
	var chance := rng.roll(STREAM, 1, 100)
	if chance <= _knob(numbers, "item_chance") and not pool.is_empty():
		item = pool[rng.roll(STREAM, 0, pool.size() - 1)]
	return {"coin": coin, "item": item}


static func _knob(numbers: Dictionary, key: String) -> int:
	return Merc.whole(numbers.get(key, 0))


## The battle classes the fallen carried, from a battle result ([] when absent).
static func fallen_gear(result: Dictionary) -> Array:
	var found: Variant = result.get(FALLEN_GEAR, [])
	return found if found is Array else []
