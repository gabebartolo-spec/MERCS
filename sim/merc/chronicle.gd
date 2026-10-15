class_name Chronicle
extends RefCounted
## The company's record of the dead (Phase 2 M5; hard rule 5, mortality is final). Entries
## are only ever appended: {"merc": id, "day": int, "cause": String}. A merc has one death,
## so a second record for the same id is refused, and nothing here can remove one. It saves
## with state() and comes back with Chronicle.restore(); `living()` is how a roster read from
## any older save is kept from bringing the dead back.

var entries: Array[Dictionary] = []


## Writes a death. False, and nothing changes, for an empty id or one already dead.
func record_death(merc_id: String, day: int, cause: String) -> bool:
	if merc_id == "" or is_dead(merc_id):
		return false
	entries.append({"merc": merc_id, "day": day, "cause": cause})
	return true


func is_dead(merc_id: String) -> bool:
	for entry: Dictionary in entries:
		if entry.get("merc", "") == merc_id:
			return true
	return false


## The ids given that are not dead, in the order given.
func living(ids: Array) -> Array[String]:
	var alive: Array[String] = []
	for raw: Variant in ids:
		if not is_dead(str(raw)):
			alive.append(str(raw))
	return alive


func state() -> Dictionary:
	return {"entries": entries.duplicate(true)}


## A chronicle with the saved entries (missing block: empty; a repeated or empty id: skipped).
static func restore(saved: Dictionary) -> Chronicle:
	var chronicle := Chronicle.new()
	var list: Variant = saved.get("entries", [])
	if list is Array:
		var raw_entries: Array = list
		for entry: Variant in raw_entries:
			if entry is Dictionary:
				var record: Dictionary = entry
				chronicle.record_death(
					str(record.get("merc", "")),
					Injury.num(record, "day"),
					str(record.get("cause", ""))
				)
	return chronicle
