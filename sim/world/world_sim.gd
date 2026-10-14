class_name WorldSim
extends RefCounted
## The world between battles (Phase 2 M1a): a region of sites joined by roads, the company
## at one of them, the day count and the supplies that every day on the road or at rest
## drains. Presentation reads the sites, the state and the log and calls travel_to() or
## rest(); the sim decides what a day costs. Seeded: start() lays the region out from the
## Rng "world" stream, so the same seed gives the same map, and state() / restore() carry
## a run through a save and continue it exactly.

var day := 0
var supplies := 0
## The id of the site the company is at (starts at the hub).
var at := ""
## What happened, in order, as ids and numbers for presentation to word:
## {"step": "travel", "to": id, "days": n} / {"step": "rest", "day": d} /
## {"step": "tick", "day": d, "supplies": s} / {"step": "starving", "day": d}.
var log: Array[Dictionary] = []
## The region's sites in placement order (the hub first).
var sites: Array[WorldSite] = []

var _by_id: Dictionary = {}
var _supplies_per_day := 0
var _rng: Rng = null


## balance: data/balance/world.json. Lays out a fresh region and sets the company at the hub.
func start(balance: Dictionary, rng: Rng) -> void:
	begin(balance, rng, RegionGen.generate(_dict(balance, "region"), rng))


func site(site_id: String) -> WorldSite:
	var found: Variant = _by_id.get(site_id, null)
	return found if found is WorldSite else null


## Where the roads from the company's site lead, in id order.
func destinations() -> Array[String]:
	var here := site(at)
	if here == null:
		return []
	return here.neighbour_ids()


## Walks a road to a neighbouring site, one tick per day on it. False, and nothing
## changes, when there is no road from here to site_id.
func travel_to(site_id: String) -> bool:
	var here := site(at)
	if here == null or not here.is_neighbour(site_id):
		return false
	var days := here.days_to(site_id)
	log.append({"step": "travel", "to": site_id, "days": days})
	for _day: int in days:
		_tick()
	at = site_id
	return true


## One day where the company stays put.
func rest() -> void:
	log.append({"step": "rest", "day": day + 1})
	_tick()


## Everything a save needs to continue exactly: plain ids and numbers only.
func state() -> Dictionary:
	var saved_sites: Array[Dictionary] = []
	for entry: WorldSite in sites:
		saved_sites.append(entry.to_dict())
	return {
		"day": day, "supplies": supplies, "at": at, "log": log.duplicate(true), "sites": saved_sites
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
	return world


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
