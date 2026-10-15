extends "res://tests/lib/effect_case.gd"
## party_sight: parties see only what is in their sight (the AI is not psychic). The same seed
## (424242), the same bandits three steps from their start and a day of walking time: with
## the band in their sight they close in; with the band out of their sight they keep
## wandering near home.

const Fixture := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const OUT := 3
const NEAR := 3


func id() -> String:
	return "party_sight"


func run() -> Dictionary:
	return {"on": _day(true), "off": _day(false)}


func _day(in_sight: bool) -> String:
	var world := Fixture.world(SEED)
	world.parties.clear()
	Fixture.out_of_town(world, OUT)
	var party := Fixture.lone_party(world, "ambush", NEAR)
	if party == null:
		return "no tile for the party"
	var band := world.band if in_sight else Vector2i(world.region.width, world.region.height) * -1
	var march: Dictionary = Fixture.data().get("march", {})
	var units: int = march.get("units_per_day", 0)
	var knobs: Dictionary = Fixture.data().get("parties", {})
	PartyMoves.advance(party, units, band, world.region, knobs, Rng.from_seed(SEED))
	return (
		"%s: %d steps from the band"
		% ["chasing" if party.chasing else "wandering", TileRegion.gap(party.tile, world.band)]
	)
