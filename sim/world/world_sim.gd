class_name WorldSim
extends RefCounted
## The world between battles (Phase 2): a region of sites joined by roads, laid onto tiles
## (TileRegion), the band walking it a tile at a time, the parties walking it too, the day
## count and the supplies every day drains. Each step costs its terrain's units; a day's
## worth of units ticks a day. A party that comes within a step of the band raises its
## encounter (data/encounters.json); the band settles it by a fight or, with a patrol, a
## toll. Presentation reads the state and calls step(), rest() and the settling calls; the
## sim decides every cost and every roll. Seeded: start() lays the region out from the Rng
## "world" stream and the parties from "parties"; state() holds only what changes, and
## restore() lays the same region out again from the seed and continues exactly.

## The Rng stream an encounter's line-up is rolled on (never "world": the map never shifts).
const ENCOUNTER_STREAM := "encounter"

var day := 0
var supplies := 0
## The id of the site whose entrance the band stands on, or "" out in the land.
var at := ""
## The band's tile.
var band := Vector2i.ZERO
## Units walked toward the next day.
var march := 0
## The last site the band stood at: it falls back there after a lost fight.
var haven := ""
## What happened, in order, as ids and numbers for presentation to word:
## {"step": "arrive", "site": id} / {"step": "rest", "day": d} /
## {"step": "tick", "day": d, "supplies": s} / {"step": "starving", "day": d} /
## {"step": "encounter", "type": t, "outcome": "won"|"lost"|"paid", "supplies": change}.
var log: Array[Dictionary] = []
## The encounter a party raised and nobody has settled yet, or {}: {"type", "party", "day",
## "enemy_first", "enemies": [{"fighter", "cell"}]}. While it stands the band cannot move.
var encounter: Dictionary = {}
## Callables the hub's economy registers (Phase 2 M6, not saved): day_hook.call(day) after every
## day's tick; result_hook.call(encounter type, result) after a fight's result is applied.
var day_hook := Callable()
var result_hook := Callable()
## The region's sites in placement order (the hub first).
var sites: Array[WorldSite] = []
var region: TileRegion = null
var parties: Array[WorldParty] = []

var _by_id: Dictionary = {}
var _supplies_per_day := 0
var _units_per_day := 1
var _rng: Rng = null
var _encounters: Dictionary = {}
var _party_knobs: Dictionary = {}
var _lineups: Dictionary = {}


## world_data: data/balance/world.json, with "locations" set to data/locations.json's array
## (the hand-made stamps; without it every site is a lone gate tile). Lays out a fresh region
## and parties and sets the band at the hub's entrance.
func start(world_data: Dictionary, rng: Rng) -> void:
	_lay_out(world_data, rng)
	parties = PartyMoves.spawn(_party_knobs, region, band, rng)


## The encounter types parties raise: data/encounters.json's "encounters" array.
func set_lineups(entries: Array) -> void:
	_lineups.clear()
	for entry: Variant in entries:
		var record: Dictionary = entry if entry is Dictionary else {}
		if not str(record.get("type", "")).is_empty():
			_lineups[str(record.get("type"))] = record


func site(site_id: String) -> WorldSite:
	var found: Variant = _by_id.get(site_id, null)
	return found if found is WorldSite else null


## One step of the band to a neighbouring tile (a diagonal counts as one). Costs the new
## tile's terrain units; the parties walk the same time, and one that comes within a step
## raises its encounter. False, and nothing changes, onto water, a town wall or off the
## map, for anything but a single step, or while an encounter stands.
func step(direction: Vector2i) -> bool:
	var target := band + direction
	var single := direction != Vector2i.ZERO and TileRegion.gap(direction, Vector2i.ZERO) == 1
	if not single or not encounter.is_empty() or not region.passable(target):
		return false
	band = target
	at = region.site_at(band)
	if not at.is_empty():
		haven = at
		log.append({"step": "arrive", "site": at})
	var units := region.cost(target)
	march += units
	while march >= _units_per_day:
		march -= _units_per_day
		_tick()
	_pass_time(units)
	return true


## One day where the band stays put; the parties walk the day (not while an encounter stands).
func rest() -> void:
	if not encounter.is_empty():
		return
	log.append({"step": "rest", "day": day + 1})
	_tick()
	_pass_time(_units_per_day)


## The party by id, or null.
func party(party_id: String) -> WorldParty:
	for found: WorldParty in parties:
		if found.id == party_id:
			return found
	return null


## The standing encounter, or {} (a copy).
func pending_encounter() -> Dictionary:
	return encounter.duplicate(true)


## Settles the standing encounter with a battle's result ({"won": bool}, see
## EncounterBattle.result). A win loots supplies; a loss costs supplies and the band falls
## back to the last site it stood at. Either way the party leaves the map for its return
## days. False when none stands.
func resolve_encounter(result: Dictionary) -> bool:
	if encounter.is_empty():
		return false
	var kind := str(encounter.get("type", ""))
	if result.get("won", false) == true:
		_settle(kind, "won", _knob(kind, "win_supplies"))
	else:
		_settle(kind, "lost", -mini(supplies, _knob(kind, "loss_supplies")))
		if site(haven) != null:
			band = region.entrance(haven)
			at = haven
	if result_hook.is_valid():
		result_hook.call(kind, result)
	return true


## Buys the way past a patrol with the toll; the patrol leaves the map for its return days.
## False, and nothing changes, for any other encounter or when the supplies fall short.
func pay_toll() -> bool:
	var toll := toll_cost()
	if toll <= 0 or supplies < toll:
		return false
	_settle(str(encounter.get("type", "")), "paid", -toll)
	return true


## What the standing encounter's toll costs, 0 when it offers none.
func toll_cost() -> int:
	if encounter.is_empty():
		return 0
	return _knob(str(encounter.get("type", "")), "toll_supplies")


## Everything that changes, for a save: plain ids and numbers only. The region itself is
## not saved: restore() lays it out again from the seed.
func state() -> Dictionary:
	var saved_parties: Array[Dictionary] = []
	for entry: WorldParty in parties:
		saved_parties.append(entry.to_dict())
	return {
		"day": day,
		"supplies": supplies,
		"at": at,
		"band": [band.x, band.y],
		"march": march,
		"haven": haven,
		"log": log.duplicate(true),
		"encounter": encounter.duplicate(true),
		"parties": saved_parties,
	}


## A sim that continues where state() was taken: the region laid out again from rng's seed
## (on a fresh Rng, so the restored streams stay where they were), then the saved state. A
## save from before the walking map (no "band") puts the band at the hub's entrance; one
## with no "parties" places them fresh; missing numbers take their defaults.
static func restore(saved: Dictionary, world_data: Dictionary, rng: Rng) -> WorldSim:
	var world := WorldSim.new()
	var layout := Rng.from_seed(rng.seed_value)
	world._lay_out(world_data, layout)
	world._rng = rng
	world.day = _num(saved, "day")
	if saved.has("supplies"):
		world.supplies = _num(saved, "supplies")
	world._restore_band(saved)
	world._restore_parties(saved, layout)
	for entry: Variant in _list(saved, "log"):
		var record: Dictionary = entry if entry is Dictionary else {}
		if not record.is_empty():
			world.log.append(_whole(record))
	var standing := _dict(saved, "encounter")
	if not str(standing.get("type", "")).is_empty():
		world.encounter = _whole_dict(standing)
	return world


func _restore_band(saved: Dictionary) -> void:
	var pair := _list(saved, "band")
	if pair.size() <= 1:
		return
	var tile := Vector2i(_num({"v": pair[0]}, "v"), _num({"v": pair[1]}, "v"))
	if not region.passable(tile):
		return
	band = tile
	at = region.site_at(band)
	march = _num(saved, "march")
	if site(str(saved.get("haven", ""))) != null:
		haven = str(saved.get("haven"))


func _restore_parties(saved: Dictionary, layout: Rng) -> void:
	if not saved.has("parties"):
		parties = PartyMoves.spawn(_party_knobs, region, region.entrance(RegionGen.HUB_ID), layout)
		return
	parties.clear()
	for entry: Variant in _list(saved, "parties"):
		var record: Dictionary = entry if entry is Dictionary else {}
		if not record.is_empty():
			parties.append(WorldParty.from_dict(record))


## Time passes for every party on the map, in id order; the first to come within a step
## of the band raises its encounter and the rest wait.
func _pass_time(units: int) -> void:
	for walker: WorldParty in parties:
		if not walker.active(day):
			continue
		var met := PartyMoves.advance(walker, units, band, region, _party_knobs, _rng)
		if met and _raise_encounter(walker):
			return


## The party's encounter: its type, and a line-up rolled on the "encounter" stream. False
## when the data holds no line-up for the type.
func _raise_encounter(walker: WorldParty) -> bool:
	var entry := _dict(_lineups, walker.type)
	var lineups := _list(entry, "lineups")
	if lineups.is_empty():
		return false
	var enemies: Array = _whole_deep(lineups[_rng.roll(ENCOUNTER_STREAM, 0, lineups.size() - 1)])
	encounter = {
		"type": walker.type,
		"party": walker.id,
		"day": day,
		"enemy_first": entry.get("enemy_first", false) == true,
		"enemies": enemies,
	}
	return true


## Applies a settled encounter's supplies change, logs it and sends the party away.
func _settle(kind: String, outcome: String, change: int) -> void:
	supplies = maxi(0, supplies + change)
	log.append({"step": "encounter", "type": kind, "outcome": outcome, "supplies": change})
	var walker := party(str(encounter.get("party", "")))
	if walker != null:
		walker.send_away(day + _num(_dict(_party_knobs, walker.type), "return_days"))
	encounter = {}


func _knob(kind: String, key: String) -> int:
	return _num(_dict(_encounters, kind), key)


## A day passes: the drain, clamped at 0, then the starving mark while there is nothing left.
func _tick() -> void:
	day += 1
	supplies = maxi(0, supplies - _supplies_per_day)
	log.append({"step": "tick", "day": day, "supplies": supplies})
	if supplies == 0:
		log.append({"step": "starving", "day": day})
	if day_hook.is_valid():
		day_hook.call(day)


## Day zero at the hub's entrance with the balance's supplies, on a freshly laid region.
func _lay_out(world_data: Dictionary, rng: Rng) -> void:
	_rng = rng
	var company := _dict(world_data, "company")
	_supplies_per_day = _num(company, "supplies_per_day")
	_units_per_day = maxi(1, _num(_dict(world_data, "march"), "units_per_day"))
	_encounters = _dict(world_data, "encounters")
	_party_knobs = _dict(world_data, "parties")
	sites = RegionGen.generate(_dict(world_data, "region"), rng)
	_by_id.clear()
	for entry: WorldSite in sites:
		_by_id[entry.id] = entry
	region = TileGen.generate(world_data, sites, rng)
	encounter = {}
	day = 0
	march = 0
	supplies = _num(company, "start_supplies")
	at = sites[0].id if not sites.is_empty() else ""
	haven = at
	band = region.entrance(at)
	log.clear()


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
