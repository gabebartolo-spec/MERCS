extends "res://tests/lib/effect_case.gd"
## world_map: the seeded tile region. Seed 424242 against 424243: the terrain on the map the
## band walks differs (where the hub's gate lies, how much road, forest, hill and water, and
## the tiles themselves), so another world is another map to cross.

const Fixture := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const OTHER_SEED := 424243


func id() -> String:
	return "world_map"


func run() -> Dictionary:
	return {"on": _map(SEED), "off": _map(OTHER_SEED)}


## The map in a line: the hub's gate, the tiles of each terrain and a hash of the whole grid.
func _map(seed_value: int) -> String:
	var world := Fixture.world(seed_value)
	var counts: Array[int] = []
	counts.resize(TileRegion.Terrain.size())
	for tile: int in world.region.tiles:
		counts[tile] += 1
	var named: Array[String] = []
	for kind: int in counts.size():
		named.append("%s %d" % [TileRegion.TERRAIN_KEYS[kind], counts[kind]])
	return (
		"seed %d: hub gate %s, %s, map %x"
		% [
			seed_value,
			world.region.entrance(RegionGen.HUB_ID),
			", ".join(named),
			world.region.picture().hash()
		]
	)
