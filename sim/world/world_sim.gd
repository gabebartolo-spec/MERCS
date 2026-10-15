class_name WorldSim
extends RefCounted
## The world between battles (Phase 2 M1a): a region of sites joined by roads, the company
## at one of them, the day count and the supplies that every day on the road or at rest
## drains. Presentation reads the sites, the state and the log and calls travel_to() or
## rest(); the sim decides what a day costs. Seeded: start() lays the region out from the
## Rng "world" stream, so the same seed gives the same map, and state() / restore() carry
## a run through a save and continue it exactly.

## The Rng stream of each road's encounter rolls is "encounter.<from>.<to>" (never "world").
const ENCOUNTER_STREAM := "encounter"

var day := 0
var supplies := 0
## The id of the site the company is at (starts at the hub).
var at := ""
## What happened, in order, as ids and numbers for presentation to word:
## {"step": "travel", "to": id, "days": n} / {"step": "rest", "day": d} /
## {"step": "tick", "day": d, "supplies": s} / {"step": "starving", "day": d} /
## {"step": "encounter", "type": t, "outcome": "won"|"lost"|"paid", "supplies": change}.
var log: Array[Dictionary] = []
## The encounter the road raised and nobody has settled yet, or {} (Phase 2 M2): {"type",
## "from", "to", "day", "days_left", "enemy_first", "enemies": [{"fighter", "cell"}]}.
## While it stands the company is still at the site it left and cannot travel or rest.
var encounter: Dictionary = {}
## The region's sites in placement order (the hub first).
var sites: Array[WorldSite] = []

var _by_id: Dictionary = {}
var _supplies_per_day := 0
var _rng: Rng = null
var _encounters: Dictionary = {}
var _lineups: Dictionary = {}


## balance: data/balance/world.json. Lays out a fresh region and sets the company at the hub.
func start(balance: Dictionary, rng: Rng) -> void:
	begin(balance, rng, RegionGen.generate(_dict(balance, "region"), rng))


## The encounter types the road can raise: data/encounters.json's "encounters" array. A
## world without them (or with a chance of 0 in the balance) never raises one.
func set_lineups(entries: Array) -> void:
	_lineups.clear()
	for entry: Variant in entries:
		var record: Dictionary = entry if entry is Dictionary else {}
		if not str(record.get("type", "")).is_empty():
			_lineups[str(record.get("type"))] = record


func site(site_id: String) -> WorldSite:
	var found: Variant = _by_id.get(site_id, null)
	return found if found is WorldSite else null


## Where the roads from the company's site lead, in id order.
func destinations() -> Array[String]:
	var here := site(at)
	if here == null:
		return []
	return here.neighbour_ids()


## Walks a road to a neighbouring site, one tick per day on it. A day may raise an encounter
## (see `encounter`): the walk stops that day and goes on once it is settled. False, and
## nothing changes, when there is no road from here to site_id or an encounter stands.
func travel_to(site_id: String) -> bool:
	var here := site(at)
	if here == null or not here.is_neighbour(site_id) or not encounter.is_empty():
		return false
	var days := here.days_to(site_id)
	log.append({"step": "travel", "to": site_id, "days": days})
	for walked: int in days:
		_tick()
		if _raise_encounter(here.id, site_id, days - walked - 1):
			return true
	at = site_id
	return true


## One day where the company stays put (not while an encounter stands).
func rest() -> void:
	if not encounter.is_empty():
		return
	log.append({"step": "rest", "day": day + 1})
	_tick()


## The standing encounter, or {} (a copy).
func pending_encounter() -> Dictionary:
	return encounter.duplicate(true)


## Settles the standing encounter with a battle's result ({"won": bool}, see
## EncounterBattle.result). A win loots supplies and the road goes on to its end; a loss
## costs supplies and the company falls back to the site it left. False when none stands.
func resolve_encounter(result: Dictionary) -> bool:
	if encounter.is_empty():
		return false
	var kind := str(encounter.get("type", ""))
	if result.get("won", false) == true:
		_settle(kind, "won", _knob(kind, "win_supplies"))
		_finish_road()
	else:
		_settle(kind, "lost", -mini(supplies, _knob(kind, "loss_supplies")))
		encounter = {}
	return true


## Buys the way past a patrol with the toll, and the road goes on. False, and nothing
## changes, for any other encounter or when the supplies do not cover the toll.
func pay_toll() -> bool:
	var toll := toll_cost()
	if toll <= 0 or supplies < toll:
		return false
	_settle(str(encounter.get("type", "")), "paid", -toll)
	_finish_road()
	return true


## What the standing encounter's toll costs, 0 when it offers none.
func toll_cost() -> int:
	if encounter.is_empty():
		return 0
	return _knob(str(encounter.get("type", "")), "toll_supplies")


## Everything a save needs to continue exactly: plain ids and numbers only.
func state() -> Dictionary:
	var saved_sites: Array[Dictionary] = []
	for entry: WorldSite in sites:
		saved_sites.append(entry.to_dict())
	return {
		"day": day,
		"supplies": supplies,
		"at": at,
		"log": log.duplicate(true),
		"sites": saved_sites,
		"encounter": encounter.duplicate(true),
	}


## A sim that continues where state() was taken, without a roll: the saved sites are read
## back as they were. A save with no sites (or a block missing altogether) lays out a fresh
## region from the balance; missing numbers take their defaults.
static func restore(saved: Dictionary, balance: Dictionary, rng: Rng) -> WorldSim:
	var world := WorldSim.new()
	var restored: Array[WorldSite] = []
	for entry: Variant in _list(saved, "sites"):
		var record: Dictionary = entry if entry is Dictionary else {}
		if not record.is_empty():
			restored.append(WorldSite.from_dict(record))
	if restored.is_empty():
		world.start(balance, rng)
	else:
		world.begin(balance, rng, restored)
	world.day = _num(saved, "day")
	if saved.has("supplies"):
		world.supplies = _num(saved, "supplies")
	var where := str(saved.get("at", ""))
	if world.site(where) != null:
		world.at = where
	for entry: Variant in _list(saved, "log"):
		var record: Dictionary = entry if entry is Dictionary else {}
		if not record.is_empty():
			world.log.append(_whole(record))
	var standing := _dict(saved, "encounter")
	var road_known := world.site(str(standing.get("from", ""))) != null
	if road_known and world.site(str(standing.get("to", ""))) != null:
		world.encounter = _whole_dict(standing)
	return world


## A day on the road may raise an encounter: one roll for it on the road's own "encounter"
## stream, and on a hit one for the type (by weight) and one for the line-up. False when the
## roll misses or the balance and the data hold no encounters.
func _raise_encounter(from_id: String, to_id: String, days_left: int) -> bool:
	var stream := "%s.%s.%s" % [ENCOUNTER_STREAM, from_id, to_id]
	var hit := _rng.roll(stream, 1, 100) <= _num(_encounters, "chance_per_day")
	var kinds := _kinds()
	if not hit or kinds.is_empty():
		return false
	var entry := _dict(_lineups, _pick_kind(kinds, stream))
	var lineups := _list(entry, "lineups")
	if lineups.is_empty():
		return false
	var enemies: Array = _whole_deep(lineups[_rng.roll(stream, 0, lineups.size() - 1)])
	encounter = {
		"type": str(entry.get("type", "")),
		"from": from_id,
		"to": to_id,
		"day": day,
		"days_left": days_left,
		"enemy_first": entry.get("enemy_first", false) == true,
		"enemies": enemies,
	}
	return true


## Types with a line-up in the data and a weight in the balance, in name order.
func _kinds() -> Array[String]:
	var kinds: Array[String] = []
	for kind: Variant in _lineups:
		if _knob(str(kind), "weight") > 0:
			kinds.append(str(kind))
	kinds.sort()
	return kinds


func _pick_kind(kinds: Array[String], stream: String) -> String:
	var total := 0
	for kind: String in kinds:
		total += _knob(kind, "weight")
	var point := _rng.roll(stream, 1, total)
	for kind: String in kinds:
		point -= _knob(kind, "weight")
		if point <= 0:
			return kind
	return kinds[0]


## Applies a settled encounter's supplies change and logs it.
func _settle(kind: String, outcome: String, change: int) -> void:
	supplies = maxi(0, supplies + change)
	log.append({"step": "encounter", "type": kind, "outcome": outcome, "supplies": change})


## The rest of the road after a win or a toll: the days left tick without a roll, then arrival.
func _finish_road() -> void:
	var days_left := _num(encounter, "days_left")
	var arrive := str(encounter.get("to", at))
	encounter = {}
	for _day: int in days_left:
		_tick()
	at = arrive


func _knob(kind: String, key: String) -> int:
	return _num(_dict(_encounters, kind), key)


## A day passes: the drain, clamped at 0, then the starving mark while there is nothing left.
func _tick() -> void:
	day += 1
	supplies = maxi(0, supplies - _supplies_per_day)
	log.append({"step": "tick", "day": day, "supplies": supplies})
	if supplies == 0:
		log.append({"step": "starving", "day": day})


## Day one at the hub with the balance's supplies, on the sites given (restore() brings its own).
func begin(balance: Dictionary, rng: Rng, placed: Array[WorldSite]) -> void:
	_rng = rng
	_supplies_per_day = _num(_dict(balance, "company"), "supplies_per_day")
	_encounters = _dict(balance, "encounters")
	encounter = {}
	_set_sites(placed)
	day = 0
	supplies = _num(_dict(balance, "company"), "start_supplies")
	at = sites[0].id if not sites.is_empty() else ""
	log.clear()


func _set_sites(placed: Array[WorldSite]) -> void:
	sites = placed
	_by_id.clear()
	for entry: WorldSite in sites:
		_by_id[entry.id] = entry


## A log entry read back from JSON, its numbers whole again so the log replays byte for byte.
static func _whole(entry: Dictionary) -> Dictionary:
	var fixed := {}
	for key: Variant in entry:
		var value: Variant = entry[key]
		if value is float:
			fixed[str(key)] = _num(entry, str(key))
		else:
			fixed[str(key)] = value
	return fixed


## A saved value with every number in it whole again, however deep (JSON hands back floats).
static func _whole_deep(value: Variant) -> Variant:
	if value is Dictionary:
		var block: Dictionary = value
		return _whole_dict(block)
	if value is Array:
		var items: Array = value
		return items.map(_whole_deep)
	if value is float:
		var number: float = value
		return roundi(number)
	return value


static func _whole_dict(block: Dictionary) -> Dictionary:
	var fixed := {}
	for key: Variant in block:
		fixed[str(key)] = _whole_deep(block[key])
	return fixed


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}


static func _list(block: Dictionary, key: String) -> Array:
	var value: Variant = block.get(key, [])
	if not value is Array:
		return []
	var items: Array = value
	return items.duplicate()
