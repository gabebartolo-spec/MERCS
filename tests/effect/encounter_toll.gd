extends "res://tests/lib/effect_case.gd"
## encounter_toll: encounters on the road. The same seed (424243) and the same journey (the
## hub's first road), with encounters on against a chance of 0: with them the company is
## stopped, loses the fight and is back at the hub short of supplies; without them it
## arrives. (M2 fixture: the system on and off leave the company in a different place.)

const BALANCE := "res://data/balance/world.json"
const ENCOUNTERS := "res://data/encounters.json"
const SEED := 424243


func id() -> String:
	return "encounter_toll"


func run() -> Dictionary:
	var on_balance := json(BALANCE)
	var off_balance := on_balance.duplicate(true)
	var encounters: Dictionary = off_balance.get("encounters", {})
	encounters["chance_per_day"] = 0
	return {"on": _journey(on_balance), "off": _journey(off_balance)}


func _journey(balance: Dictionary) -> String:
	var world := WorldSim.new()
	world.start(balance, Rng.from_seed(SEED))
	var lineups: Array = json(ENCOUNTERS).get("encounters", [])
	world.set_lineups(lineups)
	world.travel_to(world.destinations()[0])
	if not world.encounter.is_empty():
		world.resolve_encounter({"won": false})
	return "%d supplies at %s on day %d" % [world.supplies, world.at, world.day]
