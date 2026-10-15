extends RefCounted
## The road's line-ups (Phase 5 C7), run by tests/run_sim_encounters_tests.gd. Every line-up in
## data/encounters.json stays inside the director's numbers: proper soldiers come 4-8 a fight,
## rabble (battle.json fighters marked "rabble") 12-16 (data/caps.json "enemies_soldiers",
## "enemies_rabble"); each names a fighter battle.json knows, on its own cell of the slice
## street, off the cells the company deploys on. Line-ups are chosen by place and day, never by
## the company (LineupPick): a narrowed line-up comes only on its places and from its day, and
## every type keeps one that comes anywhere from day 0. An encounter raised on the map brings
## one of the line-ups its tile and day allow.
## Seeded by design: Rng.from_seed(424242) through the world fixture.

const World := preload("res://tests/lib/world_fixture.gd")
const CAPS := "res://data/caps.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const SCENARIOS := "res://data/scenarios.json"
## The director's floors (2026-10-16, "Typical fight roughly even, 4-8 enemies"; Q-1 rabble
## "up to 12 or even 16"): the fewest of each kind a fight brings. The caps are the most.
const SOLDIERS_FEWEST := 4
const RABBLE_FEWEST := 12
const SOLDIERS_CAP := 8
const RABBLE_CAP := 16
const SEED := 424242
const NEAR := 3
const OUT := 3
const WALK_LIMIT := 20
const LATE_DAY := 99
const ROAD := "road"
const WILD := "forest"
const AMBUSH := "ambush"

var _check: Callable
var _fighters: Dictionary = {}


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_fighters = World.json(BATTLE_DATA).get("fighters", {})
	var caps: Dictionary = World.json(CAPS).get("caps", {})
	_check_sizes(caps)
	_check_cells()
	_check_open_line()
	_check_place_and_day()
	_check_raised()


static func _rules() -> Dictionary:
	var rules: Dictionary = World.json(BATTLE_DATA).get("rules", {})
	return rules


static func types() -> Array:
	var listed: Variant = World.json(World.ENCOUNTERS).get("encounters", [])
	return listed if listed is Array else []


static func lineups_of(kind: String) -> Array:
	for entry: Variant in types():
		var record: Dictionary = entry
		if record.get("type") == kind:
			var listed: Variant = record.get("lineups", [])
			return listed if listed is Array else []
	return []


static func is_rabble(fighters: Dictionary, kind: String) -> bool:
	var row: Variant = fighters.get(kind, {})
	if not row is Dictionary:
		return false
	var found: Dictionary = row
	return found.get("rabble", false) == true


## Whether every fighter of a line-up is rabble.
static func all_rabble(fighters: Dictionary, lineup: Array) -> bool:
	for entry: Variant in lineup:
		var row: Dictionary = entry
		if not is_rabble(fighters, str(row.get("fighter", ""))):
			return false
	return not lineup.is_empty()


func _check_sizes(caps: Dictionary) -> void:
	var soldiers_cap := Merc.whole(caps.get("enemies_soldiers", 0))
	var rabble_cap := Merc.whole(caps.get("enemies_rabble", 0))
	var wrong: Array[String] = []
	var biggest := {"soldiers": 0, "rabble": 0}
	for entry: Variant in types():
		var record: Dictionary = entry
		for lineup: Variant in lineups_of(str(record.get("type"))):
			var listed := LineupPick.fighters_of(lineup)
			var rabble := all_rabble(_fighters, listed)
			var low := RABBLE_FEWEST if rabble else SOLDIERS_FEWEST
			var high := rabble_cap if rabble else soldiers_cap
			var key := "rabble" if rabble else "soldiers"
			biggest[key] = maxi(Merc.whole(biggest[key]), listed.size())
			if listed.size() < low or listed.size() > high:
				wrong.append("%s:%d" % [record.get("type"), listed.size()])
	_check.call(
		soldiers_cap == SOLDIERS_CAP and rabble_cap == RABBLE_CAP,
		"data/caps.json holds the director's enemy caps: 8 soldiers, 16 rabble"
	)
	_check.call(
		wrong.is_empty(),
		(
			"every line-up brings %d-%d soldiers or %d-%d rabble (outside: %s)"
			% [SOLDIERS_FEWEST, soldiers_cap, RABBLE_FEWEST, rabble_cap, wrong]
		)
	)
	_check.call(
		(
			Merc.whole(biggest["soldiers"]) == soldiers_cap
			and Merc.whole(biggest["rabble"]) == rabble_cap
		),
		"the road holds a line-up at each cap (largest %s)" % [biggest]
	)


## Each fighter is known to battle.json, on its own cell of the street, off the company's; and
## every deployment starts in sight: each enemy within sight_cells of the nearest company cell,
## each company cell within sight_cells of the nearest enemy, so no side waits on a foe it
## cannot see (the stall the lead flagged: a fight where nobody moves).
func _check_cells() -> void:
	var scenarios: Array = World.json(SCENARIOS).get("scenarios", [])
	var scenario: Dictionary = scenarios[0]
	var setup: Dictionary = scenario.get("battle", {})
	var grid := _cell(setup.get("grid", []))
	var company := {}
	for cell: Variant in setup.get("road_cells", []):
		company[_cell(cell)] = true
	var sight := Merc.whole(_rules().get("sight_cells", 0))
	var wrong: Array[String] = []
	for entry: Variant in types():
		var record: Dictionary = entry
		for lineup: Variant in lineups_of(str(record.get("type"))):
			var seen := {}
			var enemy_cells: Array[Vector2i] = []
			for one: Variant in LineupPick.fighters_of(lineup):
				var row: Dictionary = one
				var at := _cell(row.get("cell", []))
				var inside := Rect2i(Vector2i.ZERO, grid).has_point(at)
				var known := _fighters.has(str(row.get("fighter", "")))
				var near := _nearest(at, company.keys()) <= sight
				enemy_cells.append(at)
				if not known or not inside or not near or seen.has(at) or company.has(at):
					wrong.append("%s %s %s" % [record.get("type"), row.get("fighter"), at])
				seen[at] = true
			for cell: Vector2i in company:
				if _nearest(cell, enemy_cells) > sight:
					wrong.append("%s company %s unseen" % [record.get("type"), cell])
	_check.call(
		wrong.is_empty(),
		(
			"every line-up's fighters are known, inside the street, one to a cell, off the "
			+ (
				"company's cells, and both sides start within sight_cells of each other (wrong: %s)"
				% [wrong]
			)
		)
	)


## Every type keeps a line-up that comes anywhere from day 0, so no place or day is empty.
func _check_open_line() -> void:
	var closed: Array[String] = []
	for entry: Variant in types():
		var record: Dictionary = entry
		var lineups := lineups_of(str(record.get("type")))
		for place: String in TileRegion.TERRAIN_KEYS:
			if LineupPick.allowed(lineups, place, 0).is_empty():
				closed.append("%s/%s" % [record.get("type"), place])
	_check.call(
		closed.is_empty(), "every type has a line-up for every place on day 0 (%s)" % [closed]
	)


## Place and day narrow the draw: the ambush brings rabble only off the road, and its biggest
## soldier line-up only later on.
func _check_place_and_day() -> void:
	var ambush := lineups_of(AMBUSH)
	var road_rabble := _rabble_count(LineupPick.allowed(ambush, ROAD, LATE_DAY))
	var wild_rabble := _rabble_count(LineupPick.allowed(ambush, WILD, 0))
	_check.call(
		road_rabble == 0 and wild_rabble > 0,
		"rabble ambush only off the road (road %d, forest %d)" % [road_rabble, wild_rabble]
	)
	var early := LineupPick.allowed(ambush, ROAD, 0)
	var late := LineupPick.allowed(ambush, ROAD, LATE_DAY)
	(
		_check
		. call(
			late.size() > early.size() and _largest(late) > _largest(early),
			(
				"later days open bigger line-ups (road day 0: %d line-ups, up to %d; later: %d, up to %d)"
				% [early.size(), _largest(early), late.size(), _largest(late)]
			)
		)
	)


func _rabble_count(lists: Array) -> int:
	var count := 0
	for listed: Variant in lists:
		var one: Array = listed
		count += 1 if all_rabble(_fighters, one) else 0
	return count


## An ambush walked into on the map brings one of the line-ups its tile and day allow.
func _check_raised() -> void:
	var world := World.world(SEED)
	world.parties.clear()
	World.out_of_town(world, OUT)
	var party := World.lone_party(world, AMBUSH, NEAR)
	if party != null:
		World.walk_toward(world, party.tile, WALK_LIMIT)
	var met: Array = world.encounter.get("enemies", [])
	var place := TileRegion.TERRAIN_KEYS[world.region.terrain(world.band)]
	var found := false
	for listed: Variant in LineupPick.allowed(lineups_of(AMBUSH), place, world.day):
		var one: Array = listed
		found = found or _same(one, met)
	_check.call(
		not met.is_empty() and found,
		(
			"the ambush met on %s on day %d brings an allowed line-up (%d enemies)"
			% [place, world.day, met.size()]
		)
	)


static func _same(listed: Array, met: Array) -> bool:
	if listed.size() != met.size():
		return false
	for i: int in listed.size():
		var a: Dictionary = listed[i]
		var b: Dictionary = met[i]
		if str(a.get("fighter")) != str(b.get("fighter")):
			return false
		if _cell(a.get("cell")) != _cell(b.get("cell")):
			return false
	return true


## The gap from `at` to the nearest of `cells` (a huge gap when there are none).
static func _nearest(at: Vector2i, cells: Array) -> int:
	var best := 1 << 30
	for cell: Variant in cells:
		var other: Vector2i = cell
		best = mini(best, BattleGrid.gap(at, other))
	return best


static func _largest(lists: Array) -> int:
	var most := 0
	for listed: Variant in lists:
		var one: Array = listed
		most = maxi(most, one.size())
	return most


static func _cell(value: Variant) -> Vector2i:
	var pair: Array = value if value is Array else []
	if pair.size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(Merc.whole(pair[0]), Merc.whole(pair[1]))
