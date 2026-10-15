class_name Memory
extends RefCounted
## What each merc remembers (Phase 2 M5 writes the first memories: a comrade's death, a
## captain's death, a dissent). A memory is {"key": text key in data/text/en.json, "about":
## merc id, "day": int}, kept per merc id in the order it was written; the store keeps the
## memories of the dead too. Keyed by id, so it needs no Merc class. state() / restore().

const KEY_COMRADE_DIED := "memory.comrade_died"
const KEY_CAPTAIN_DIED := "memory.captain_died"
const KEY_DISSENT := "memory.dissent"

var _by_merc: Dictionary = {}


func write(merc_id: String, key: String, about: String, day: int) -> void:
	if merc_id == "" or key == "":
		return
	var list: Array = _by_merc.get(merc_id, [])
	list.append({"key": key, "about": about, "day": day})
	_by_merc[merc_id] = list


## One memory sentence on each comrade given (never the dead one), in id order.
func on_death(dead_id: String, comrade_ids: Array, day: int, key: String) -> void:
	var ids: Array[String] = []
	for raw: Variant in comrade_ids:
		if str(raw) != dead_id and not ids.has(str(raw)):
			ids.append(str(raw))
	ids.sort()
	for merc_id: String in ids:
		write(merc_id, key, dead_id, day)


func of(merc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array = _by_merc.get(merc_id, [])
	for entry: Variant in list:
		if entry is Dictionary:
			var record: Dictionary = entry
			out.append(record.duplicate())
	return out


func state() -> Dictionary:
	return _by_merc.duplicate(true)


static func restore(saved: Dictionary) -> Memory:
	var memory := Memory.new()
	for merc_id: Variant in saved:
		var list: Variant = saved[merc_id]
		if list is Array:
			var entries: Array = list
			for entry: Variant in entries:
				if entry is Dictionary:
					var record: Dictionary = entry
					memory.write(
						str(merc_id),
						str(record.get("key", "")),
						str(record.get("about", "")),
						Injury.num(record, "day")
					)
	return memory
