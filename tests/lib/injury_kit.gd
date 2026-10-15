extends RefCounted
## Shared pieces of the injury suite and its fixtures: the data files, a small company of
## merc states and a battle log with downed mercs.

const INJURIES := "res://data/injuries.json"
const BALANCE := "res://data/balance/injury.json"
const DAY := 10


static func state_of(mercs: Dictionary, merc_id: String) -> Dictionary:
	var merc: Dictionary = mercs[merc_id]
	return merc


static func json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func defs() -> Array:
	var list: Variant = json(INJURIES).get("injuries", [])
	return list if list is Array else []


static func rules() -> Dictionary:
	return json(BALANCE)


static func merc(merc_id: String, resolve: int) -> Dictionary:
	return {"id": merc_id, "stats": {"attack": 5, "hp": 10, "resolve": resolve}, "injuries": []}


static func company() -> Dictionary:
	return {
		"m_a": merc("m_a", 3), "m_b": merc("m_b", 9), "m_c": merc("m_c", 6), "m_d": merc("m_d", 6)
	}


static func battle_log(downed: Array, killer: String) -> Array:
	var events: Array = []
	for merc_id: Variant in downed:
		events.append({"type": "attack", "unit": killer, "target": merc_id, "hit": true})
		events.append({"type": "down", "unit": merc_id})
	return events


static func aftermath(seed_value: int, triage_rules: Dictionary) -> Aftermath:
	var all_rules := rules().duplicate(true)
	all_rules["triage"] = triage_rules
	var made := Aftermath.new(Rng.from_seed(seed_value), all_rules, defs())
	made.day = DAY
	return made
