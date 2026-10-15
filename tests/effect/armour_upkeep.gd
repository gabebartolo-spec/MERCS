extends "res://tests/lib/effect_case.gd"
## armour_upkeep: armour is strong but costly (Phase 5 C6, director 2026-10-16: "price and
## upkeep"). The starting company on seed 424242 lives ten days, the captain paying the whole
## day's bill each day from a purse that covers it; once with the orc in his plate, once with
## the orc in leather. The upkeep of the armour worn on the roster is on the day's bill
## (data/balance/economy.json "armoury" "upkeep"), so the purse after ten days differs by the
## plate's upkeep over leather's.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const DAYS := 10
## Enough coin that every day's bill is paid, so the purse shows the whole cost.
const PURSE := 1000
const WHO := "orc"
const SITES: Array[String] = ["site_1", "site_2", "site_3"]


func id() -> String:
	return "armour_upkeep"


func run() -> Dictionary:
	return {"on": _ten_days("plate"), "off": _ten_days("leather")}


func _ten_days(armour: String) -> String:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	company.member(WHO).gear_line["armour"] = armour
	economy.purse = PURSE
	var rng := Rng.from_seed(SEED)
	for day: int in range(1, DAYS + 1):
		economy.on_day(company.roster, day, SITES, rng)
		economy.pay_wages()
	return "purse %d, owing %d, morale %d" % [economy.purse, economy.owed, economy.morale]
