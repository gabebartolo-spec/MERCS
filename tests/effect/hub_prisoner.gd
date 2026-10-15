extends "res://tests/lib/effect_case.gd"
## hub_prisoner: the prisoner choice changes the company. The same company and seed after one
## won fight: recruit the prisoner, or let them go. Roster size, coin and morale differ.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const DAY := 3


func id() -> String:
	return "hub_prisoner"


func run() -> Dictionary:
	return {"on": _decide(Economy.RECRUIT), "off": _decide(Economy.RELEASE)}


func _decide(choice: String) -> String:
	var company := Company.start(Fixture.defs())
	company.economy.captives.take(DAY)
	company.economy.decide_prisoner(company, choice, DAY)
	var economy := company.economy
	return "roster %d, coin %d, morale %d" % [company.roster.size(), economy.purse, economy.morale]
