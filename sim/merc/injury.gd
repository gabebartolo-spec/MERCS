class_name Injury
extends RefCounted
## The wound ladder's rules (Phase 2 M5): triage, applying an injury to a merc's state and
## reading the stats, layers and role it leaves behind. All static, all plain dictionaries,
## so the company's Merc can adopt them later: a merc is
## {"id": String, "stats": {name: int}, "injuries": [{"id": String, "until_day": int}]}
## (a permanent injury has no "until_day"). Death is not applied here: Chronicle holds it,
## and a dead id is never touched again. Seeded: triage rolls the Rng "injury" stream, in
## id order, so the same seed gives the same triage whatever order the ids arrive in.

const STREAM := "injury"
const KIND_WOUND := "wound"
const KIND_TEMPORARY := "temporary"
const KIND_PERMANENT := "permanent"
const OUTCOME_DEAD := "dead"
## The outcomes in the order the triage thresholds cut the die.
const LADDER: Array[String] = [KIND_WOUND, KIND_TEMPORARY, KIND_PERMANENT]


## The one definition of a kind in data/injuries.json's "injuries" list ({} when none).
static func definition_of_kind(defs: Array, kind: String) -> Dictionary:
	for entry: Variant in defs:
		if entry is Dictionary:
			var def: Dictionary = entry
			if def.get("kind", "") == kind:
				return def
	return {}


static func definition(defs: Array, injury_id: String) -> Dictionary:
	for entry: Variant in defs:
		if entry is Dictionary:
			var def: Dictionary = entry
			if def.get("id", "") == injury_id:
				return def
	return {}


## The outcome a roll gives: a ladder kind, or OUTCOME_DEAD above the last threshold.
## rules: data/balance/injury.json "triage".
static func outcome_for_roll(roll: int, rules: Dictionary) -> String:
	for kind: String in LADDER:
		if roll <= num(rules, "%s_upto" % kind):
			return kind
	return OUTCOME_DEAD


## One roll per downed id, in id order: {id: outcome}.
static func triage(downed_ids: Array, rng: Rng, rules: Dictionary) -> Dictionary:
	var ids: Array[String] = []
	for raw: Variant in downed_ids:
		var merc_id := str(raw)
		if merc_id != "" and not ids.has(merc_id):
			ids.append(merc_id)
	ids.sort()
	var outcomes := {}
	for merc_id: String in ids:
		outcomes[merc_id] = outcome_for_roll(rng.roll(STREAM, 1, num(rules, "die_sides")), rules)
	return outcomes


## A copy of the merc with the injury recorded: a temporary one until day + its days, a
## wound until the day itself (it heals with the fight), a permanent one for good. An unknown
## injury id leaves the merc as it was.
static func apply(merc: Dictionary, injury_id: String, day: int, defs: Array) -> Dictionary:
	var updated := merc.duplicate(true)
	var def := definition(defs, injury_id)
	if def.is_empty():
		return updated
	var record := {"id": injury_id}
	match str(def.get("kind", "")):
		KIND_WOUND:
			record["until_day"] = day
		KIND_TEMPORARY:
			record["until_day"] = day + num(def, "days")
	var list := records(updated)
	list.append(record)
	updated["injuries"] = list
	return updated


## The merc without the injuries that have healed by `day` (wounds and temporary ones).
static func expire(merc: Dictionary, day: int) -> Dictionary:
	var updated := merc.duplicate(true)
	updated["injuries"] = _in_force(merc, day)
	return updated


## The stats a fight reads: the base stats (flags such as an ability stay as they are) plus
## every injury still in force on `day`.
static func effective_stats(merc: Dictionary, day: int, defs: Array) -> Dictionary:
	var stats := {}
	var base: Variant = merc.get("stats", {})
	if base is Dictionary:
		var base_stats: Dictionary = base
		stats = base_stats.duplicate()
	for record: Dictionary in _in_force(merc, day):
		var change: Variant = definition(defs, str(record.get("id", ""))).get("stat_change", {})
		if change is Dictionary:
			var delta: Dictionary = change
			for key: Variant in delta:
				stats[key] = num(stats, str(key)) + num(delta, str(key))
	return stats


## The sprite layer ids of the merc's permanent injuries, in the order they happened.
static func layers(merc: Dictionary, defs: Array) -> Array[String]:
	return _permanent_texts(merc, defs, "layer_id")


## The text keys of the role changes the merc's permanent injuries cause.
static func role_keys(merc: Dictionary, defs: Array) -> Array[String]:
	return _permanent_texts(merc, defs, "role_key")


## The merc's injury records as typed dictionaries.
static func records(merc: Dictionary) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var saved: Variant = merc.get("injuries", [])
	if saved is Array:
		var entries: Array = saved
		for entry: Variant in entries:
			if entry is Dictionary:
				var record: Dictionary = entry
				list.append(record.duplicate())
	return list


## Every merc's injuries, for a save: {id: [records]}.
static func state(mercs: Dictionary) -> Dictionary:
	var saved := {}
	for merc_id: Variant in mercs:
		var merc: Variant = mercs[merc_id]
		if merc is Dictionary:
			var merc_state: Dictionary = merc
			var list: Array[Dictionary] = records(merc_state)
			if not list.is_empty():
				saved[str(merc_id)] = list
	return saved


## The injuries to give back to the living: a dead id's record is refused, so a save can
## never bring one back (mortality is final).
static func restore(saved: Dictionary, chronicle: Chronicle) -> Dictionary:
	var restored := {}
	for merc_id: Variant in saved:
		if chronicle.is_dead(str(merc_id)):
			continue
		var whole: Array[Dictionary] = []
		for record: Dictionary in records({"injuries": saved[merc_id]}):
			var copy := {"id": str(record.get("id", ""))}
			if record.has("until_day"):
				copy["until_day"] = num(record, "until_day")
			whole.append(copy)
		restored[str(merc_id)] = whole
	return restored


## A whole number from a block: an int, or a float rounded (JSON holds numbers as floats).
static func num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0


static func _in_force(merc: Dictionary, day: int) -> Array[Dictionary]:
	var live: Array[Dictionary] = []
	for record: Dictionary in records(merc):
		if not record.has("until_day") or num(record, "until_day") > day:
			live.append(record)
	return live


static func _permanent_texts(merc: Dictionary, defs: Array, field: String) -> Array[String]:
	var found: Array[String] = []
	for record: Dictionary in records(merc):
		var def := definition(defs, str(record.get("id", "")))
		if def.get("kind", "") == KIND_PERMANENT and def.has(field):
			found.append(str(def[field]))
	return found
