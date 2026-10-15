extends "res://tests/lib/effect_case.gd"
## encounter_road: the road decides the encounter. The same seed (424243), walking two
## different roads out of the hub, raises two different encounters: another type, day or
## line-up. (M2 fixture: "the same seed on a different road gives a different encounter".)

const BALANCE := "res://data/balance/world.json"
const ENCOUNTERS := "res://data/encounters.json"
const SEED := 424243


func id() -> String:
	return "encounter_road"


func run() -> Dictionary:
	var first := _destinations()[0]
	var second := _destinations()[1]
	return {"on": _met_on(first), "off": _met_on(second)}


func _destinations() -> Array[String]:
	return _world().destinations()


func _world() -> WorldSim:
	var world := WorldSim.new()
	world.start(json(BALANCE), Rng.from_seed(SEED))
	var lineups: Array = json(ENCOUNTERS).get("encounters", [])
	world.set_lineups(lineups)
	return world


## What the company meets walking the road to `to`: type, day and the enemy line-up (not the road).
func _met_on(to: String) -> String:
	var world := _world()
	world.travel_to(to)
	var found := world.pending_encounter()
	if found.is_empty():
		return "nothing"
	var foes: Array[String] = []
	var enemies: Array = found.get("enemies", [])
	for enemy: Variant in enemies:
		var record: Dictionary = enemy if enemy is Dictionary else {}
		foes.append(str(record.get("fighter", "")))
	return "%s on day %d against %s" % [found.get("type"), found.get("day"), foes]
