class_name Company
extends RefCounted
## The company: the mercenaries the player owns, up to the roster cap (vision: twelve), the
## one who holds the captain's office, and the experience each has earned (Phase 2 milestone
## 3). Built from data (defs below); state() and restore() carry it through the save, with a
## default for a save made before the company existed: the starting six, the orc captain.
## Nothing here rolls (no stream), so a company has no seed. No Node, no file access.
##
## defs, the data a company is made from: {"mercs": data/mercs.json, "fighters":
## data/balance/battle.json "fighters", "company": data/balance/company.json}.

var roster: Array[Merc] = []
var captain_id := ""

var _defs := {}
var _cap := 0
var _level_xp: Array[int] = []


## A new company of the starting six (every merc in data, in order, up to the cap), the
## starting captain at its head.
static func start(defs: Dictionary) -> Company:
	var company := Company.new()
	company._read_rules(defs)
	for id: String in company._catalogue():
		company.add(id)
	company.captain_id = str(_section(defs, "mercs").get("starting_captain", ""))
	company._mend_captain()
	return company


## The company a save held. A save with no company (older, or empty) starts the starting six
## with the orc as captain; ids the data no longer has are dropped; a captain who is not on
## the roster is replaced by the starting captain, else the first merc.
static func restore(saved: Dictionary, defs: Dictionary) -> Company:
	var held: Variant = saved.get("roster", [])
	var rows: Array = held if held is Array else []
	if rows.is_empty():
		return Company.start(defs)
	var company := Company.new()
	company._read_rules(defs)
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var saved_merc: Dictionary = row
		var merc := company._add(str(saved_merc.get("id", "")))
		if merc != null:
			merc.apply_state(saved_merc)
	if company.roster.is_empty():
		return Company.start(defs)
	company.captain_id = str(saved.get("captain", ""))
	if company.member(company.captain_id) == null:
		company.captain_id = str(_section(defs, "mercs").get("starting_captain", ""))
	company._mend_captain()
	return company


func member(id: String) -> Merc:
	for merc: Merc in roster:
		if merc.id == id:
			return merc
	return null


func captain() -> Merc:
	return member(captain_id)


func cap() -> int:
	return _cap


## Hires a merc from the data onto the roster. False (and no change) when the id is not in
## the data, the merc is already on the roster or the roster is full.
func add(id: String) -> bool:
	return _add(id) != null


## Gives the captain's office to a merc on the roster. False (and no change) when they are
## not on it.
func appoint(id: String) -> bool:
	if member(id) == null:
		return false
	captain_id = id
	return true


## Experience to one merc; true when it raised their level.
func gain(id: String, amount: int) -> bool:
	var merc := member(id)
	return merc != null and merc.gain(amount)


## Experience to everyone on the roster; the ids whose level rose.
func gain_all(amount: int) -> Array[String]:
	var raised: Array[String] = []
	for merc: Merc in roster:
		if merc.gain(amount):
			raised.append(merc.id)
	return raised


## Fighters for a battle: the named roster members as BattleUnits on `side`, one per cell in
## order, the captain leading. Unknown ids are skipped.
func battle_units(ids: Array[String], cells: Array[Vector2i], side: int) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	for i: int in mini(ids.size(), cells.size()):
		var merc := member(ids[i])
		if merc != null:
			units.append(merc.to_battle_unit(side, cells[i], merc.id == captain_id))
	return units


## What the save keeps: who holds the office and each merc's experience and gear.
func state() -> Dictionary:
	var rows: Array[Dictionary] = []
	for merc: Merc in roster:
		rows.append(merc.state())
	return {"captain": captain_id, "roster": rows}


func _add(id: String) -> Merc:
	if member(id) != null or roster.size() >= _cap:
		return null
	for def: Dictionary in _entries():
		if str(def.get("id", "")) == id:
			var merc := Merc.make(def, _section(_defs, "fighters"), _level_xp)
			roster.append(merc)
			return merc
	return null


func _mend_captain() -> void:
	if member(captain_id) == null and not roster.is_empty():
		captain_id = roster[0].id


func _read_rules(defs: Dictionary) -> void:
	_defs = defs
	var balance := _section(defs, "company")
	_cap = Merc.whole(_section(balance, "roster").get("cap", 0))
	_level_xp.clear()
	var thresholds: Variant = _section(balance, "xp").get("level_xp", [])
	if thresholds is Array:
		for threshold: Variant in thresholds:
			_level_xp.append(Merc.whole(threshold))


func _entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var listed: Variant = _section(_defs, "mercs").get("mercs", [])
	if listed is Array:
		for entry: Variant in listed:
			if entry is Dictionary:
				var def: Dictionary = entry
				entries.append(def)
	return entries


func _catalogue() -> Array[String]:
	var ids: Array[String] = []
	for def: Dictionary in _entries():
		ids.append(str(def.get("id", "")))
	return ids


static func _section(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}
