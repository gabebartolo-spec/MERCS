extends "res://tests/lib/effect_case.gd"
## encounter_toll: parties on the map. The same seed (424242) and the same walk toward a tile
## three steps out: with a band of bandits standing there the company is stopped, loses the
## fight and falls back to the hub short of supplies; with no party it arrives.

const Fixture := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const OUT := 3
const NEAR := 3
const WALK_LIMIT := 20


func id() -> String:
	return "encounter_toll"


func run() -> Dictionary:
	return {"on": _journey(true), "off": _journey(false)}


func _journey(with_party: bool) -> String:
	var world := Fixture.world(SEED)
	world.parties.clear()
	Fixture.out_of_town(world, OUT)
	var party := Fixture.lone_party(world, "ambush", NEAR)
	if party == null:
		return "no tile for the party"
	var target := party.tile
	if not with_party:
		world.parties.clear()
	Fixture.walk_toward(world, target, WALK_LIMIT)
	if not world.encounter.is_empty():
		world.resolve_encounter({"won": false})
	return "%d supplies at %s on day %d" % [world.supplies, world.band, world.day]
