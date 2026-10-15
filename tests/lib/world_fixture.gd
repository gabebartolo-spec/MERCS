extends RefCounted
## Shared set-up for the walking-overworld suites and effect cases: the world data as the game
## builds it (data/balance/world.json with data/locations.json's stamps), a seeded WorldSim
## with the encounter line-ups, a lone party placed a given number of steps from the band,
## and a greedy walk of the band toward a tile. Seeded by the caller; nothing here rolls.

const BALANCE := "res://data/balance/world.json"
const LOCATIONS := "res://data/locations.json"
const ENCOUNTERS := "res://data/encounters.json"


static func json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The world data the game hands WorldSim: the balance plus the hand-made stamps.
static func data() -> Dictionary:
	var world_data := json(BALANCE)
	var stamps: Array = json(LOCATIONS).get("locations", [])
	world_data["locations"] = stamps
	return world_data


## A world on the seed with the line-ups loaded; world_data defaults to data().
static func world(seed_value: int, world_data: Dictionary = {}) -> WorldSim:
	var made := WorldSim.new()
	made.start(data() if world_data.is_empty() else world_data, Rng.from_seed(seed_value))
	var lineups: Array = json(ENCOUNTERS).get("encounters", [])
	made.set_lineups(lineups)
	return made


## Steps the band straight out of the hub's gate (south, where the stamp opens) up to
## `count` steps, so a test meets its party in the open. The steps taken.
static func out_of_town(on: WorldSim, count: int) -> int:
	var taken := 0
	while taken < count and on.step(Vector2i(0, 1)):
		taken += 1
	return taken


## Replaces the world's parties with one of `type` on the first walkable, non-site tile
## exactly `gap` steps from the band (searched row by row, so the same map picks the same
## tile). Null when there is none.
static func lone_party(on: WorldSim, type: String, gap: int) -> WorldParty:
	for y: int in range(on.band.y - gap, on.band.y + gap + 1):
		for x: int in range(on.band.x - gap, on.band.x + gap + 1):
			var tile := Vector2i(x, y)
			var free := on.region.passable(tile) and on.region.site_at(tile).is_empty()
			if TileRegion.gap(tile, on.band) == gap and free:
				var placed := WorldParty.make("party_0", type, tile)
				on.parties = [placed]
				return placed
	return null


## Steps the band toward `target` (each step to the walkable neighbour nearest it) until an
## encounter stands, it arrives, or `limit` steps. The steps taken.
static func walk_toward(on: WorldSim, target: Vector2i, limit: int) -> int:
	var taken := 0
	while taken < limit and on.encounter.is_empty() and on.band != target:
		var best := Vector2i.ZERO
		var best_gap := TileRegion.gap(on.band, target)
		for step: Vector2i in TileRegion.STEPS:
			var next := on.band + step
			if on.region.passable(next) and TileRegion.gap(next, target) < best_gap:
				best = step
				best_gap = TileRegion.gap(next, target)
		if best == Vector2i.ZERO or not on.step(best):
			break
		taken += 1
	return taken


## A scripted run, moves `first` to `last` (exclusive) of one sequence: on even moves a step
## (the first walkable of the eight steps, the order turned by the move's number), on odd
## moves a rest. It reads nothing but the world, so splitting it at a save keeps the sequence.
static func scripted(on: WorldSim, first: int, last: int) -> void:
	var turns := TileRegion.STEPS.size()
	for move: int in range(first, last):
		if move % 2 == 1:
			on.rest()
			continue
		for turn: int in turns:
			if on.step(TileRegion.STEPS[(move + turn) % turns]):
				break
