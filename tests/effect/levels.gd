extends "res://tests/lib/effect_case.gd"
## levels: levelling changes the fight. The orc alone against the same band on the same seed
## (424242), once fresh (0 xp, level 1) and once at the level-3 threshold of the one bar: the
## veteran has the growth data/mercs.json gives him (more hp and attack) and the blood price
## move he learns at level 3, so his log, hp and result differ. Before D-094 level touched
## nothing and the two fights were identical.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const LEVEL_3 := 25


func id() -> String:
	return "levels"


func run() -> Dictionary:
	return {"on": _outcome(LEVEL_3), "off": _outcome(0)}


## What the fight came to, without the experience the orc had.
func _outcome(xp: int) -> String:
	var company := Company.start(Fixture.defs())
	company.member("orc").xp = xp
	var fight := Fixture.fight(company, "orc", SEED)
	var log: Array[Dictionary] = fight["log"]
	return (
		"%s with %d hp left; %d blood price, %d moves, %d attacks, %d events"
		% [
			"won" if fight["won"] else "lost",
			fight["hp"],
			Fixture.count(log, "blood_price"),
			Fixture.count(log, "move"),
			Fixture.count(log, "attack"),
			log.size()
		]
	)
