extends "res://tests/lib/effect_case.gd"
## intent_marker: each enemy shows the plan it made from what it sees. The road fight's band
## on seed 424242: with the company in its sight the round's plans read attack or advance on a
## named target; with the sight cut to one cell they all read hold. The marker is the sim's
## own (Battle.intents), the one the battle panel draws.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const BLIND := 1


func id() -> String:
	return "intent_marker"


func run() -> Dictionary:
	var sight := Merc.whole(Fixture.rules().get("sight_cells", 0))
	return {"on": _plans(sight), "off": _plans(BLIND)}


func _plans(sight: int) -> String:
	var rng := Rng.from_seed(SEED)
	var made := Kit.wounds(rng, "wound")
	var data := Fixture.json(Fixture.BATTLE)
	var rules: Dictionary = data["rules"]
	rules["sight_cells"] = sight
	var cells := EncounterBattle.company_cells(Kit.scenario())
	var units := made.units(cells, BattleUnit.COMPANY)
	var battle := EncounterBattle.build(Kit.pending(), Kit.scenario(), data, rng, units)
	var plans: Array[String] = []
	for plan: Dictionary in battle.intents():
		plans.append("%s:%s" % [plan.get("kind", ""), plan.get("target", "")])
	plans.sort()
	return "%d plans: %s" % [plans.size(), ", ".join(plans)]
