extends "res://tests/lib/effect_case.gd"
## encounter_road: the party decides the encounter. The same seed (424242) and the same walk
## out of the hub into a lone party three steps away: bandits ambush the company (they strike
## first), a patrol bars the way and names a toll. (Since the walking map, the party the band
## meets takes the place of the road it walked.)

const Fixture := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const OUT := 3
const NEAR := 3
const WALK_LIMIT := 20


func id() -> String:
	return "encounter_road"


func run() -> Dictionary:
	return {"on": _met("ambush"), "off": _met("patrol")}


## What the company meets: type, who strikes first, the toll and the enemy line-up.
func _met(kind: String) -> String:
	var world := Fixture.world(SEED)
	world.parties.clear()
	Fixture.out_of_town(world, OUT)
	var party := Fixture.lone_party(world, kind, NEAR)
	if party == null:
		return "no tile for the party"
	Fixture.walk_toward(world, party.tile, WALK_LIMIT)
	var found := world.pending_encounter()
	if found.is_empty():
		return "nothing"
	var foes: Array[String] = []
	var enemies: Array = found.get("enemies", [])
	for enemy: Variant in enemies:
		var record: Dictionary = enemy if enemy is Dictionary else {}
		foes.append(str(record.get("fighter", "")))
	return (
		"%s (enemy first %s, toll %d) against %s"
		% [found.get("type"), found.get("enemy_first"), world.toll_cost(), foes]
	)
