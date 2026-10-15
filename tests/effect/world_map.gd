extends "res://tests/lib/effect_case.gd"
## world_map: the seeded region. Seed 424242 against 424243: the set of roads differs, so
## another world is another map to cross.

const BALANCE := "res://data/balance/world.json"
const SEED := 424242
const OTHER_SEED := 424243


func id() -> String:
	return "world_map"


func run() -> Dictionary:
	return {"on": _roads(SEED), "off": _roads(OTHER_SEED)}


## Every road once, as "a-b" with a < b, sorted, behind the seed that laid it.
func _roads(seed_value: int) -> String:
	var world := WorldSim.new()
	world.start(json(BALANCE), Rng.from_seed(seed_value))
	var pairs: Array[String] = []
	for site: WorldSite in world.sites:
		for other: String in site.neighbour_ids():
			if site.id < other:
				pairs.append("%s-%s" % [site.id, other])
	pairs.sort()
	return "seed %d roads %s" % [seed_value, ", ".join(pairs)]
