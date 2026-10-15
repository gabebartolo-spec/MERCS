class_name Company
extends RefCounted
## The company: the mercenaries the player owns, up to the roster cap (vision: twelve), the
## one who holds the captain's office, and the experience each has earned (Phase 2 milestone
## 3). Built from data (defs below); state() and restore() carry it through the save, with a
## default for a save made before the company existed: the starting six, the orc captain.
## Nothing here rolls (no stream), so a company has no seed. No Node, no file access.
##
## defs, the data a company is made from: {"mercs": data/mercs.json, "fighters":
## data/balance/battle.json "fighters", "company": data/balance/company.json}, and for the
## economy (see Economy) "economy", "factions", "equipment" and "recruits" (all optional).

var roster: Array[Merc] = []
var captain_id := ""
## The ids of the dead, buried here (mortality is final, hard rule 5): never on the roster
## again, not by add(), not by a save. The chronicle keeps the record of how they died.
var fallen: Array[String] = []
## The purse, wages, contracts, pack and hub (Phase 2 milestone 6); saved with the company.
var economy: Economy = null

var _defs := {}
var _cap := 0
var _level_xp: Array[int] = []


## A new company of the starting six (every merc in data, in order, up to the cap), the
## starting captain at its head.
static func start(defs: Dictionary) -> Company:
	var company := Company.new()
	company._read_rules(defs)
	company.economy = Economy.make(defs)
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
	if rows.is_empty() and not saved.has("fallen"):
		return Company.start(defs)
	var company := Company.new()
	company._read_rules(defs)
	var buried: Variant = saved.get("fallen", [])
	if buried is Array:
		for dead: Variant in buried:
			company.fallen.append(str(dead))
	company.economy = Economy.restore(_section(saved, "economy"), defs)
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var saved_merc: Dictionary = row
		var merc := company._add(str(saved_merc.get("id", "")))
		if merc != null:
			merc.apply_state(saved_merc)
	if company.roster.is_empty() and company.fallen.is_empty():
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
## order, the captain leading. Unknown ids are skipped. `fit` is {id: numbers} for a merc
## whose numbers injuries have changed (see Merc.to_battle_unit).
func battle_units(
	ids: Array[String], cells: Array[Vector2i], side: int, fit: Dictionary = {}
) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	for i: int in mini(ids.size(), cells.size()):
		var merc := member(ids[i])
		if merc != null:
			var numbers: Variant = fit.get(merc.id, {})
			var changed: Dictionary = numbers if numbers is Dictionary else {}
			units.append(merc.to_battle_unit(side, cells[i], merc.id == captain_id, changed))
	return units


## The roster's ids, the captain first, then the rest in roster order: who a fight fields.
func fighting_order() -> Array[String]:
	var ids: Array[String] = []
	if member(captain_id) != null:
		ids.append(captain_id)
	for merc: Merc in roster:
		if merc.id != captain_id:
			ids.append(merc.id)
	return ids


## The dead leave the roster for good. False (and no change) when the id is not on it. The
## captain's office is not handed on here: the succession (Aftermath) names who takes it.
func bury(id: String) -> bool:
	var merc := member(id)
	if merc == null:
		return false
	roster.erase(merc)
	if id not in fallen:
		fallen.append(id)
	if captain_id == id:
		captain_id = ""
	return true


## A merc's name from the data, on the roster or not (the dead keep theirs); the id when the
## data has none.
func name_of(id: String) -> String:
	for def: Dictionary in _entries():
		if str(def.get("id", "")) == id:
			return str(def.get("name", id))
	return id


## What the save keeps: who holds the office, each merc's experience and gear, the dead, and
## the economy (purse, wages, contracts, pack, hired recruits).
func state() -> Dictionary:
	var rows: Array[Dictionary] = []
	for merc: Merc in roster:
		rows.append(merc.state())
	return {
		"captain": captain_id,
		"roster": rows,
		"fallen": fallen.duplicate(),
		"economy": economy.state()
	}


## A merc made from a recruit's data (data/recruits.json) for inspection before a hire; not on
## the roster. Null when the id is not a recruit.
func preview(recruit_id: String) -> Merc:
	return _make(recruit_id, _recruit_entries())


func _add(id: String) -> Merc:
	if member(id) != null or id in fallen or roster.size() >= _cap:
		return null
	var merc := _make(id, _entries())
	if merc == null:
		merc = _make(id, _recruit_entries())
	if merc != null:
		roster.append(merc)
	return merc


func _make(id: String, defs: Array[Dictionary]) -> Merc:
	for def: Dictionary in defs:
		if str(def.get("id", "")) == id:
			var merc := Merc.make(def, _section(_defs, "fighters"), _level_xp)
			merc.items = economy.items()
			return merc
	return null


func _recruit_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var listed: Variant = _section(_defs, "recruits").get("recruits", [])
	if listed is Array:
		for entry: Variant in listed:
			if entry is Dictionary:
				var def: Dictionary = entry
				entries.append(def)
	return entries


func _mend_captain() -> void:
	if roster.is_empty():
		captain_id = ""
	elif member(captain_id) == null:
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
