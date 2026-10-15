class_name Loot
extends RefCounted
## What a won fight leaves (Phase 2 milestone 6): coin, and sometimes one piece of generic
## gear from data/equipment.json. How much, and how likely, by the encounter's type, is in
## data/balance/economy.json "loot". Seeded on the Rng "loot" stream: the same seed and the
## same fights loot the same things.

const STREAM := "loot"


## {"coin": int, "item": id or ""} for a win over an encounter of `kind`. item_ids: the ids in
## data/equipment.json, in order. Nothing (0, "") for a kind the data does not list.
static func roll(rules: Dictionary, kind: String, item_ids: Array[String], rng: Rng) -> Dictionary:
	var row: Variant = rules.get(kind, {})
	if not row is Dictionary:
		return {"coin": 0, "item": ""}
	var numbers: Dictionary = row
	var coin := rng.roll(STREAM, _knob(numbers, "coin_min"), _knob(numbers, "coin_max"))
	var item := ""
	var chance := rng.roll(STREAM, 1, 100)
	if chance <= _knob(numbers, "item_chance") and not item_ids.is_empty():
		item = item_ids[rng.roll(STREAM, 0, item_ids.size() - 1)]
	return {"coin": coin, "item": item}


static func _knob(numbers: Dictionary, key: String) -> int:
	return Merc.whole(numbers.get(key, 0))
