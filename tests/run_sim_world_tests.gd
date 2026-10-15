extends "res://tests/lib/runner.gd"
## Sim world suite (WorldSim, RegionGen, WorldSite; data/balance/world.json): the same seed
## lays out the same region and another seed a different one; the counts and ids match the
## balance; no two sites share a cell and every site is reachable from the hub by roads of
## the balance's length; travel off the roads is refused and changes nothing; a road costs
## its days and each day's supplies; supplies stop at 0 and the company is marked starving;
## a restored state continues exactly as the uninterrupted run.
## Seeded by design: Rng.from_seed(424242) and 424243
##   godot --headless --path . --script tests/run_sim_world_tests.gd

const BALANCE := "res://data/balance/world.json"
const SEED := 424242
const OTHER_SEED := 424243
const STEPS := 6
const SPLIT := 3
const HUNGRY_DAYS := 40


func suite_name() -> String:
	return "SimWorld"


func run_checks() -> void:
	_check_same_seed_same_region()
	_check_other_seed_other_region()
	_check_counts()
	_check_placement()
	_check_connected()
	_check_travel_refused()
	_check_travel_costs()
	_check_starving()
	_check_restore_continues()
	await process_frame


func _balance() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE))
	return parsed if parsed is Dictionary else {}


func _world(seed_value: int) -> WorldSim:
	var world := WorldSim.new()
	world.start(_balance(), Rng.from_seed(seed_value))
	return world


func _region() -> Dictionary:
	return _balance().get("region", {})


func _company() -> Dictionary:
	return _balance().get("company", {})


## Every road once, as "a-b" with a < b, sorted.
func _roads(world: WorldSim) -> Array[String]:
	var pairs: Array[String] = []
	for site: WorldSite in world.sites:
		for other: String in site.neighbour_ids():
			if site.id < other:
				pairs.append("%s-%s" % [site.id, other])
	pairs.sort()
	return pairs


## A scripted walk, steps `first` to `last` (exclusive) of one sequence: on even steps
## travel along the first road out, on odd steps rest. Splitting it keeps the sequence.
func _walk(world: WorldSim, first: int, last: int) -> void:
	for i: int in range(first, last):
		if i % 2 == 0:
			world.travel_to(world.destinations()[0])
		else:
			world.rest()


func _check_same_seed_same_region() -> void:
	var a := _world(SEED)
	var b := _world(SEED)
	check(
		str(a.state()) == str(b.state()) and not a.sites.is_empty(),
		"the same seed lays out the same region and starts the same state"
	)


func _check_other_seed_other_region() -> void:
	var a := _world(SEED)
	var b := _world(OTHER_SEED)
	var cells_a := a.sites.map(func(s: WorldSite) -> Vector2i: return Vector2i(s.x, s.y))
	var cells_b := b.sites.map(func(s: WorldSite) -> Vector2i: return Vector2i(s.x, s.y))
	check(
		str(cells_a) != str(cells_b) or _roads(a) != _roads(b),
		"another seed moves the sites or lays other roads (%s vs %s)" % [_roads(a), _roads(b)]
	)


func _check_counts() -> void:
	var world := _world(SEED)
	var hamlets: int = _region().get("hamlets", 0)
	var wilds: int = _region().get("sites", 0)
	var hubs := world.sites.filter(func(s: WorldSite) -> bool: return s.id == RegionGen.HUB_ID)
	var named := (
		world.site("site_hamlet_%d" % hamlets) != null
		and world.site("site_wild_%d" % wilds) != null
		and world.site("site_hamlet_%d" % (hamlets + 1)) == null
	)
	check(
		(
			hubs.size() == 1
			and _of_kind(world, WorldSite.Kind.HUB) == 1
			and _of_kind(world, WorldSite.Kind.HAMLET) == hamlets
			and _of_kind(world, WorldSite.Kind.WILD) == wilds
			and named
			and world.at == RegionGen.HUB_ID
		),
		(
			"one hub, %d hamlets and %d wild sites, named and counted as the balance says"
			% [hamlets, wilds]
		)
	)


func _of_kind(world: WorldSim, kind: WorldSite.Kind) -> int:
	return world.sites.filter(func(s: WorldSite) -> bool: return s.kind == kind).size()


func _check_placement() -> void:
	var world := _world(SEED)
	var width: int = _region().get("grid_w", 0)
	var height: int = _region().get("grid_h", 0)
	var seen := {}
	var inside := true
	for site: WorldSite in world.sites:
		seen[Vector2i(site.x, site.y)] = true
		inside = inside and site.x >= 0 and site.x < width and site.y >= 0 and site.y < height
	check(
		inside and seen.size() == world.sites.size(),
		"every site sits on its own cell of the %d x %d grid" % [width, height]
	)


func _check_connected() -> void:
	var world := _world(SEED)
	var low: int = _region().get("road_min_days", 0)
	var high: int = _region().get("road_max_days", 0)
	var in_range := true
	var symmetric := true
	for site: WorldSite in world.sites:
		for other: String in site.neighbour_ids():
			var days := site.days_to(other)
			in_range = in_range and days >= low and days <= high
			symmetric = symmetric and world.site(other).days_to(site.id) == days
	check(
		_reachable(world).size() == world.sites.size() and in_range and symmetric,
		"every site is reachable from the hub by two-way roads of %d to %d days" % [low, high]
	)


func _reachable(world: WorldSim) -> Dictionary:
	var seen := {RegionGen.HUB_ID: true}
	var queue: Array[String] = [RegionGen.HUB_ID]
	while not queue.is_empty():
		var next_id: String = queue.pop_front()
		var here := world.site(next_id)
		if here == null:
			continue
		for other: String in here.neighbour_ids():
			if not seen.has(other):
				seen[other] = true
				queue.append(other)
	return seen


func _check_travel_refused() -> void:
	var world := _world(SEED)
	var before := str(world.state())
	var far := ""
	for site: WorldSite in world.sites:
		if site.id != world.at and not site.is_neighbour(world.at):
			far = site.id
	var refused := not world.travel_to(far) and not world.travel_to("site_nowhere")
	check(
		far != "" and refused and str(world.state()) == before,
		"travel to a site with no road from here is refused and changes nothing"
	)


func _check_travel_costs() -> void:
	var world := _world(SEED)
	var per_day: int = _company().get("supplies_per_day", 0)
	var start: int = _company().get("start_supplies", 0)
	var to: String = world.destinations()[0]
	var days := world.site(world.at).days_to(to)
	var moved := world.travel_to(to)
	var ticks := world.log.filter(func(e: Dictionary) -> bool: return e.get("step") == "tick")
	check(
		(
			moved
			and world.at == to
			and world.day == days
			and ticks.size() == days
			and world.supplies == start - days * per_day
		),
		(
			"a road of %d days moves the company there, costs %d days and %d supplies a day"
			% [days, days, per_day]
		)
	)


func _check_starving() -> void:
	var world := _world(SEED)
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


func _check_restore_continues() -> void:
	var whole := _world(SEED)
	_walk(whole, 0, STEPS)
	var paused := _world(SEED)
	_walk(paused, 0, SPLIT)
	var resumed := WorldSim.restore(paused.state(), _balance(), Rng.from_seed(SEED))
	_walk(resumed, SPLIT, STEPS)
	check(
		str(resumed.state()) == str(whole.state()) and resumed.day == whole.day,
		(
			"restore(state()) after %d steps then %d more equals the uninterrupted run"
			% [SPLIT, STEPS - SPLIT]
		)
	)
