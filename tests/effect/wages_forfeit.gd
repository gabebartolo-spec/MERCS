extends "res://tests/lib/effect_case.gd"
## wages_forfeit (director 2026-10-16): a merc who dies owing back wages is not paid them. The
## starting company on seed 424242 goes two days without pay, then once the orc dies and once
## he lives; the purse holds exactly the debt of the living and pays it. Dead: the debt is
## smaller by his dues and the purse is left with that much more. Alive: he is paid too.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const SITES: Array[String] = ["site_1", "site_2", "site_3"]
const PURSE := 1000


func id() -> String:
	return "wages_forfeit"


func run() -> Dictionary:
	return {"on": _days(true), "off": _days(false)}


func _days(dies: bool) -> String:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	var rng := Rng.from_seed(SEED)
	for day: int in [1, 2]:
		economy.on_day(company.roster, day, SITES, rng)
	if dies:
		company.bury("orc")
	economy.purse = PURSE
	var owed := economy.owed
	economy.pay_wages()
	return "owed %d, paid it, purse left %d" % [owed, economy.purse]
