extends "res://tests/lib/runner.gd"
## Sim world suite (WorldSim, RegionGen, TileGen, TileRegion, WorldSite; data/balance/world.json,
## data/locations.json): the same seed lays out the same tile map and another seed a different
## one; the counts and ids match the balance; each site's entrance is its own road tile and
## every entrance can be walked to from the hub's; the hand-made stamps are laid as authored;
## the map holds every terrain; a step onto water, a town wall, off the map or further than
## one tile is refused and changes nothing; steps cost their terrain's units and a day's worth
## ticks a day and its supplies; supplies stop at 0 and the company is marked starving; a
## restored state continues exactly as the uninterrupted run.
## Seeded by design: Rng.from_seed(424242) and 424243
##   godot --headless --path . --script tests/run_sim_world_tests.gd

const Fixture := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const OTHER_SEED := 424243
const STEPS := 12
const SPLIT := 5
const HUNGRY_DAYS := 40
const LAND_WALK := 30


func suite_name() -> String:
	return "SimWorld"


func run_checks() -> void:
	_check_same_seed_same_region()
	_check_other_seed_other_map()
	_check_counts()
	_check_entrances()
	_check_connected()
	_check_stamps()
	_check_terrain_mix()
	_check_step_refused()
	_check_step_costs()
	_check_starving()
	_check_restore_continues()
	await process_frame


## A world with no parties: nothing can stop the band.
func _alone(seed_value: int) -> WorldSim:
	var world := Fixture.world(seed_value)
	world.parties.clear()
	return world


func _region() -> Dictionary:
	return Fixture.data().get("region", {})


func _company() -> Dictionary:
	return Fixture.data().get("company", {})


func _check_same_seed_same_region() -> void:
	var a := Fixture.world(SEED)
	var b := Fixture.world(SEED)
	check(
		(
			str(a.state()) == str(b.state())
			and a.region.picture() == b.region.picture()
			and not a.sites.is_empty()
		),
		"the same seed lays out the same tile map and starts the same state"
	)


func _check_other_seed_other_map() -> void:
	var a := Fixture.world(SEED)
	var b := Fixture.world(OTHER_SEED)
	var same_size := a.region.width == b.region.width and a.region.height == b.region.height
	check(
		same_size and a.region.picture() != b.region.picture(),
		(
			"another seed lays another tile map of the same size (%d x %d)"
			% [a.region.width, a.region.height]
		)
	)


func _check_counts() -> void:
	var world := Fixture.world(SEED)
	var hamlets: int = _region().get("hamlets", 0)
	var wilds: int = _region().get("sites", 0)
	var named := (
		world.site("site_hamlet_%d" % hamlets) != null
		and world.site("site_wild_%d" % wilds) != null
		and world.site("site_hamlet_%d" % (hamlets + 1)) == null
	)
	check(
		(
			_of_kind(world, WorldSite.Kind.HUB) == 1
			and _of_kind(world, WorldSite.Kind.HAMLET) == hamlets
			and _of_kind(world, WorldSite.Kind.WILD) == wilds
			and named
			and world.at == RegionGen.HUB_ID
			and world.band == world.region.entrance(RegionGen.HUB_ID)
		),
		(
			"one hub, %d hamlets and %d wild sites as the balance says; the band at the hub's gate"
			% [hamlets, wilds]
		)
	)


func _of_kind(world: WorldSim, kind: WorldSite.Kind) -> int:
	return world.sites.filter(func(s: WorldSite) -> bool: return s.kind == kind).size()


func _check_entrances() -> void:
	var world := Fixture.world(SEED)
	var seen := {}
	var fine := true
	for site: WorldSite in world.sites:
		var gate := world.region.entrance(site.id)
		seen[gate] = true
		fine = fine and world.region.inside(gate)
		fine = fine and world.region.terrain(gate) == TileRegion.Terrain.ROAD
		fine = fine and world.region.site_at(gate) == site.id
	check(
		fine and seen.size() == world.sites.size(),
		"every site has its own entrance tile, on the map and on a road"
	)


func _check_connected() -> void:
	var failures: Array[String] = []
	for seed_value: int in [SEED, OTHER_SEED]:
		var world := Fixture.world(seed_value)
		var reached := _walkable_from(world, world.region.entrance(RegionGen.HUB_ID))
		for site: WorldSite in world.sites:
			if not reached.has(world.region.entrance(site.id)):
				failures.append("%d:%s" % [seed_value, site.id])
	check(
		failures.is_empty(),
		"every site's entrance can be walked to from the hub's: unreachable %s" % [failures]
	)


func _walkable_from(world: WorldSim, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_front()
		for step: Vector2i in TileRegion.STEPS:
			var next := here + step
			if world.region.passable(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


## Every '#' of the hub's and the hamlets' stamps is a town wall around their entrances.
func _check_stamps() -> void:
	var world := Fixture.world(SEED)
	var walls := 0
	var wrong: Array[String] = []
	var stamps: Array = Fixture.data().get("locations", [])
	for entry: Variant in stamps:
		var stamp: Dictionary = entry
		var rows: Array = stamp.get("rows", [])
		for site: WorldSite in world.sites:
			if TileGen.KIND_KEYS[site.kind] != str(stamp.get("site_kind")):
				continue
			var origin := world.region.entrance(site.id) - _gate_in(rows)
			for tile: Vector2i in _walls_of(rows):
				walls += 1
				if world.region.terrain(origin + tile) != TileRegion.Terrain.TOWN:
					wrong.append("%s %s" % [site.id, origin + tile])
	check(
		walls > 0 and wrong.is_empty(),
		"the hand-made stamps are laid as authored (%d walls; wrong: %s)" % [walls, wrong]
	)


func _gate_in(rows: Array) -> Vector2i:
	for y: int in rows.size():
		var found := str(rows[y]).find(TileGen.GATE)
		if found >= 0:
			return Vector2i(found, y)
	return Vector2i.ZERO


func _walls_of(rows: Array) -> Array[Vector2i]:
	var walls: Array[Vector2i] = []
	for y: int in rows.size():
		var row := str(rows[y])
		for x: int in row.length():
			if row[x] == TileGen.WALL:
				walls.append(Vector2i(x, y))
	return walls


func _check_terrain_mix() -> void:
	var world := Fixture.world(SEED)
	var kinds := {}
	for tile: int in world.region.tiles:
		kinds[tile] = true
	check(
		kinds.size() == TileRegion.Terrain.size(),
		"the map holds road, plain, forest, hills, water and town walls (%d kinds)" % kinds.size()
	)


func _check_step_refused() -> void:
	var world := _alone(SEED)
	var before := str(world.state())
	var wall := world.band + Vector2i(0, -1)
	var refused := (
		world.region.terrain(wall) == TileRegion.Terrain.TOWN
		and not world.step(Vector2i(0, -1))
		and not world.step(Vector2i(2, 0))
		and not world.step(Vector2i.ZERO)
	)
	var water := _beside_water(world)
	var shore: Vector2i = water[0]
	var wade: Vector2i = water[1]
	world.band = shore
	var at_water := str(world.state())
	refused = refused and wade != Vector2i.ZERO and not world.step(wade)
	refused = refused and str(world.state()) == at_water
	world.band = Vector2i.ZERO
	var at_corner := str(world.state())
	refused = refused and not world.step(Vector2i(-1, 0)) and str(world.state()) == at_corner
	world.band = world.region.entrance(RegionGen.HUB_ID)
	check(
		refused and str(world.state()) == before,
		"a step into a town wall, onto water, off the map or of two tiles is refused; nothing changes"
	)


## [a walkable tile, the step from it onto water].
func _beside_water(world: WorldSim) -> Array:
	for y: int in world.region.height:
		for x: int in world.region.width:
			var here := Vector2i(x, y)
			for step: Vector2i in TileRegion.STEPS:
				var next := here + step
				var water := world.region.terrain(next) == TileRegion.Terrain.WATER
				if world.region.passable(here) and water and world.region.inside(next):
					return [here, step]
	return [Vector2i.ZERO, Vector2i.ZERO]


## Walks out of the hub's gate and back, over and over: each step costs its tile's units;
## every full day's worth ticks a day and its supplies, the rest waits in `march`.
func _check_step_costs() -> void:
	var world := _alone(SEED)
	var per_day: int = _company().get("supplies_per_day", 0)
	var start: int = _company().get("start_supplies", 0)
	var march: Dictionary = Fixture.data().get("march", {})
	var units_per_day: int = march.get("units_per_day", 0)
	var units := 0
	var steps := 0
	for walk: int in LAND_WALK:
		if not world.step(Vector2i(0, 1) if walk % 2 == 0 else Vector2i(0, -1)):
			break
		units += world.region.cost(world.band)
		steps += 1
	var ticks := world.log.filter(func(e: Dictionary) -> bool: return e.get("step") == "tick")
	var days := units / units_per_day
	check(
		(
			steps == LAND_WALK
			and days > 0
			and world.day == days
			and ticks.size() == days
			and world.march == units % units_per_day
			and world.supplies == start - days * per_day
		),
		(
			"%d steps cost %d units: %d days at %d a day, %d supplies a day, %d units carried"
			% [steps, units, days, units_per_day, per_day, world.march]
		)
	)


func _check_starving() -> void:
	var world := _alone(SEED)
	for _day: int in HUNGRY_DAYS:
		world.rest()
	var starving := world.log.filter(
		func(e: Dictionary) -> bool: return e.get("step") == "starving"
	)
	var first_zero := -1
	for entry: Dictionary in world.log:
		if entry.get("step") == "tick" and entry.get("supplies") == 0 and first_zero < 0:
			first_zero = entry.get("day")
	var first_mark: Dictionary = starving[0] if not starving.is_empty() else {}
	var marked_day: int = first_mark.get("day", -1)
	check(
		(
			world.supplies == 0
			and first_zero > 0
			and starving.size() == HUNGRY_DAYS - first_zero + 1
			and marked_day == first_zero
		),
		"supplies stop at 0 after %d days of rest, then every day is marked starving" % HUNGRY_DAYS
	)


## Parties on the map: the run split by a restore (the Rng's streams carried as a save does)
## walks on exactly as the run that never stopped.
func _check_restore_continues() -> void:
	var whole := Fixture.world(SEED)
	Fixture.scripted(whole, 0, STEPS)
	var paused_rng := Rng.from_seed(SEED)
	var paused := WorldSim.new()
	paused.start(Fixture.data(), paused_rng)
	var lineups: Array = Fixture.json(Fixture.ENCOUNTERS).get("encounters", [])
	paused.set_lineups(lineups)
	Fixture.scripted(paused, 0, SPLIT)
	var carried := Rng.restore(paused_rng.state())
	var resumed := WorldSim.restore(paused.state(), Fixture.data(), carried)
	resumed.set_lineups(lineups)
	Fixture.scripted(resumed, SPLIT, STEPS)
	check(
		str(resumed.state()) == str(whole.state()) and resumed.day == whole.day and whole.day > 0,
		(
			"restore(state()) after %d moves then %d more equals the uninterrupted run (day %d)"
			% [SPLIT, STEPS - SPLIT, whole.day]
		)
	)
