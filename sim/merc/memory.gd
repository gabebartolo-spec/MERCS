class_name Memory
extends RefCounted
## What each merc remembers (Phase 2 M5 wrote the first memories: a comrade's death, a
## captain's death, a dissent; M7 adds a sentence from every fight and choice). A memory is
## {"key": text key in data/text/en.json, "about": merc id ("" when none), "params": the
## values that fill the sentence (always holds "about"), "day": int}, kept per merc id in the
## order it was written; the store keeps the memories of the dead too. Keyed by id, so it
## needs no Merc class. state() / restore().
##
## The way to write one, for any system (the hub, the battle, a storylet):
##   record(merc_id, key, params, day)          one sentence on one merc
##   on_fight(ids, won, fallen, day)            a fight's sentence on each who fought
##   on_choice(ids, key, day)                   a choice's sentence on each it touched
## Presentation words a memory with Text.t(key, params + the day).

const KEY_COMRADE_DIED := "memory.comrade_died"
const KEY_CAPTAIN_DIED := "memory.captain_died"
const KEY_DISSENT := "memory.dissent"
## A fight: every merc in it remembers it won or lost; one who went down remembers that too.
const KEY_FIGHT_WON := "memory.fight_won"
const KEY_FIGHT_LOST := "memory.fight_lost"
const KEY_FIGHT_FELL := "memory.fight_fell"
## A choice: the contract taken, and the prisoner's fate ("memory.fate_" + the choice id).
const KEY_CONTRACT := "memory.contract_taken"
const KEY_FATE_PREFIX := "memory.fate_"

var _by_merc: Dictionary = {}


func write(merc_id: String, key: String, about: String, day: int) -> void:
	record(merc_id, key, {"about": about}, day)


## One memory sentence on one merc. `params` fill the sentence; its "about" (a merc id) is
## also kept on the entry. An empty id or key writes nothing.
func record(merc_id: String, key: String, params: Dictionary, day: int) -> void:
	if merc_id == "" or key == "":
		return
	var list: Array = _by_merc.get(merc_id, [])
	var kept := params.duplicate(true)
	var about := str(kept.get("about", ""))
	kept["about"] = about
	list.append({"key": key, "about": about, "params": kept, "day": day})
	_by_merc[merc_id] = list


## A fight's memory on each merc who fought, in id order: won or lost, and for each of the
## `fallen` (downed, whether or not they lived) a sentence of their own.
func on_fight(ids: Array, won: bool, fallen: Array, day: int) -> void:
	var key := KEY_FIGHT_WON if won else KEY_FIGHT_LOST
	for merc_id: String in _sorted(ids):
		record(merc_id, key, {}, day)
		if fallen.has(merc_id):
			record(merc_id, KEY_FIGHT_FELL, {}, day)


## A choice's memory (`key` a KEY_ constant or KEY_FATE_PREFIX + the choice) on each merc.
func on_choice(ids: Array, key: String, day: int) -> void:
	for merc_id: String in _sorted(ids):
		record(merc_id, key, {}, day)


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
			var record_entry: Dictionary = entry
			out.append(record_entry.duplicate(true))
	return out


## Whether the merc holds a memory with this key.
func has_key(merc_id: String, key: String) -> bool:
	for entry: Dictionary in of(merc_id):
		if entry.get("key", "") == key:
			return true
	return false


## The relationship: two different mercs share a memory when each holds one with the same
## key about the same merc (they stood at the same death), or the same key and day for a
## memory about no one (they fought the same fight).
func shared(first_id: String, second_id: String) -> bool:
	if first_id == second_id:
		return false
	for mine: Dictionary in of(first_id):
		for theirs: Dictionary in of(second_id):
			if _same_event(mine, theirs):
				return true
	return false


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
					var record_entry: Dictionary = entry
					var params: Variant = record_entry.get("params", {})
					var kept: Dictionary = params if params is Dictionary else {}
					if not kept.has("about"):
						kept["about"] = str(record_entry.get("about", ""))
					memory.record(
						str(merc_id),
						str(record_entry.get("key", "")),
						kept,
						Injury.num(record_entry, "day")
					)
	return memory


static func _same_event(first: Dictionary, second: Dictionary) -> bool:
	if first.get("key", "") != second.get("key", ""):
		return false
	if first.get("about", "") != second.get("about", ""):
		return false
	return first.get("about", "") != "" or first.get("day", 0) == second.get("day", 0)


static func _sorted(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for raw: Variant in ids:
		if not out.has(str(raw)):
			out.append(str(raw))
	out.sort()
	return out
