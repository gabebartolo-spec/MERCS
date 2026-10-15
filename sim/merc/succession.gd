class_name Succession
extends RefCounted
## Who leads when the captain falls (Phase 2 M5). The living comrades are ranked by resolve
## (ties by id); data/balance/injury.json "succession" says which rank takes the company and
## which rank is the one dissenting voice. A pure function of its arguments: no roll.


## candidates: [{"id": String, "resolve": int}], the living comrades. Returns {} when the
## dead merc was not the captain, else {"type": "succession", "dead", "day", "captain",
## "dissent"}; the captain is "" when nobody is left, the dissent "" when nobody else is.
static func after_death(
	dead_id: String, captain_id: String, candidates: Array, rules: Dictionary, day: int
) -> Dictionary:
	if dead_id == "" or dead_id != captain_id:
		return {}
	var ranked: Array[Dictionary] = []
	for entry: Variant in candidates:
		if entry is Dictionary:
			var candidate: Dictionary = entry
			if candidate.get("id", "") != dead_id:
				ranked.append(candidate)
	ranked.sort_custom(_ahead)
	return {
		"type": "succession",
		"dead": dead_id,
		"day": day,
		"captain": _id_at(ranked, Injury.num(rules, "successor_rank")),
		"dissent": _id_at(ranked, Injury.num(rules, "dissent_rank"))
	}


static func _ahead(a: Dictionary, b: Dictionary) -> bool:
	var resolve_a := Injury.num(a, "resolve")
	var resolve_b := Injury.num(b, "resolve")
	if resolve_a != resolve_b:
		return resolve_a > resolve_b
	return str(a.get("id", "")) < str(b.get("id", ""))


static func _id_at(ranked: Array[Dictionary], rank: int) -> String:
	if rank < 0 or rank >= ranked.size():
		return ""
	return str(ranked[rank].get("id", ""))
