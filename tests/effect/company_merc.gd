extends "res://tests/lib/effect_case.gd"
## company_merc: who the merc is changes the fight. The orc and the Vampyr, from the company's
## data, each alone against the same band on the same seed (424242): the orc charges in and
## strikes in one turn, the Vampyr pays his own health for the blow, and the logs and results
## differ. The outcome never names the merc, so two mercs who fought alike would read the same
## and the case would fail.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242


func id() -> String:
	return "company_merc"


func run() -> Dictionary:
	var company := Company.start(Fixture.defs())
	return {"on": _outcome(company, "orc"), "off": _outcome(company, "vampyr")}


## What the fight came to, without who fought it.
func _outcome(company: Company, merc_id: String) -> String:
	var fight := Fixture.fight(company, merc_id, SEED)
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
