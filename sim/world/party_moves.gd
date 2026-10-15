class_name PartyMoves
extends RefCounted
## Where the overworld's parties start and how they walk (Phase 2), on the Rng "parties"
## stream. Each party type's numbers are in data/balance/world.json "parties". A party sees
## the band only within its sight (steps, a diagonal counting one); seeing it, it steps to
## the neighbouring tile closest to the band; not seeing it, it wanders to a random
## neighbouring tile within its wander range of home. Nothing else about the band reaches it.

const STREAM := "parties"
const PREFIX := "party_"


## The parties of every type in the balance (types in name order), each on its own free,
## walkable tile at least min_spawn_tiles from the hub's entrance and off every entrance.
static func spawn(knobs: Dictionary, region: TileRegion, hub: Vector2i, rng: Rng) -> Array[WorldParty]:
	var parties: Array[WorldParty] = []
	var taken := {}
	for type: String in types(knobs):
		for _party: int in _num(_dict(knobs, type), "count"):
			var at := _free_tile(knobs, region, hub, taken, rng)
			if at == Vector2i(-1, -1):
				continue
			taken[at] = true
			parties.append(WorldParty.make("%s%d" % [PREFIX, parties.size()], type, at))
	return parties


## The party types the balance gives numbers for, in name order.
static func types(knobs: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for key: Variant in knobs:
		if knobs[key] is Dictionary:
			found.append(str(key))
	found.sort()
	return found


static func _free_tile(
	knobs: Dictionary, region: TileRegion, hub: Vector2i, taken: Dictionary, rng: Rng
) -> Vector2i:
	var reach := _num(knobs, "min_spawn_tiles")
	for _try: int in _num(knobs, "spawn_tries"):
		var at := Vector2i(rng.roll(STREAM, 0, region.width - 1), rng.roll(STREAM, 0, region.height - 1))
		var far := TileRegion.gap(at, hub) >= reach
		if far and region.passable(at) and region.site_at(at).is_empty() and not taken.has(at):
			return at
	return Vector2i(-1, -1)


## Time reaches the party: `units` times its speed, saved up and spent tile by tile on the
## terrain it walks. Stops when the units run out or it comes within a step of the band.
## True when it made contact.
static func advance(
	party: WorldParty, units: int, band: Vector2i, region: TileRegion, knobs: Dictionary, rng: Rng
) -> bool:
	var own := _dict(knobs, party.type)
	party.budget += units * _num(own, "speed_pct") / 100
	while true:
		party.chasing = TileRegion.gap(party.tile, band) <= _num(own, "sight_tiles")
		if contact(party, band):
			return true
		var next := _chase(party, band, region) if party.chasing else _wander(party, own, region, rng)
		if next == party.tile or party.budget < region.cost(next):
			break
		party.budget -= region.cost(next)
		party.tile = next
	# What is not spent carries over, but never more than a day's walking on the dearest ground.
	party.budget = mini(party.budget, _num(knobs, "budget_cap"))
	return false


## Within a step of the band (the same or a neighbouring tile).
static func contact(party: WorldParty, band: Vector2i) -> bool:
	return TileRegion.gap(party.tile, band) <= 1


## The walkable neighbour closest to the band (ties: the fewer straight steps, then the
## fixed step order); its own tile when no neighbour is closer.
static func _chase(party: WorldParty, band: Vector2i, region: TileRegion) -> Vector2i:
	var best := party.tile
	var best_gap := TileRegion.gap(party.tile, band)
	var best_walk := _walk(party.tile, band)
	for step: Vector2i in TileRegion.STEPS:
		var next := party.tile + step
		if not region.passable(next):
			continue
		var next_gap := TileRegion.gap(next, band)
		var next_walk := _walk(next, band)
		if next_gap < best_gap or (next_gap == best_gap and next_walk < best_walk):
			best = next
			best_gap = next_gap
			best_walk = next_walk
	return best


## A random walkable neighbour within the wander range of home; a party beyond it (after a
## chase) only takes steps back toward home. Its own tile when there is none.
static func _wander(party: WorldParty, own: Dictionary, region: TileRegion, rng: Rng) -> Vector2i:
	var reach := maxi(_num(own, "wander_tiles"), TileRegion.gap(party.tile, party.home) - 1)
	var options: Array[Vector2i] = []
	for step: Vector2i in TileRegion.STEPS:
		var next := party.tile + step
		if region.passable(next) and TileRegion.gap(next, party.home) <= reach:
			options.append(next)
	if options.is_empty():
		return party.tile
	return options[rng.roll(STREAM, 0, options.size() - 1)]


static func _walk(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


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
