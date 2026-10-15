extends "res://tests/lib/effect_case.gd"
## hub_wages: ignoring wages for a week changes morale. The same company and seed (424242)
## for seven days, once paying the wages at the hub each day and once leaving them unpaid.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const WEEK := 7
const SITES: Array[String] = ["site_1", "site_2", "site_3"]


func id() -> String:
	return "hub_wages"


func run() -> Dictionary:
	return {"on": _week(true), "off": _week(false)}


func _week(pays: bool) -> String:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	var rng := Rng.from_seed(SEED)
	for day: int in range(1, WEEK + 1):
		economy.on_day(company.roster.size(), day, SITES, rng)
		if pays:
			economy.pay_wages()
	return "morale %d, owing %d coin, purse %d" % [economy.morale, economy.owed, economy.purse]
