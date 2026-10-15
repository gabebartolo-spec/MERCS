extends "res://tests/lib/effect_case.gd"
## hiring: coin buys a merc who fights. The starting company on seed 424242 with the purse at
## its start: once the first recruit on offer is hired, once the offer is left. The hire
## changes the roster, the purse and the offers, and the recruit alone against the band
## fights a fight the band without him never has.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const FIGHT_SEED := 424271


func id() -> String:
	return "hiring"


func run() -> Dictionary:
	return {"on": _day(true), "off": _day(false)}


func _day(hires: bool) -> String:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	var offered := economy.offers()
	var recruit := str(offered[0].get("id", ""))
	var done := economy.hire(company, recruit) if hires else false
	var seen := "none"
	if done:
		var fight := Fixture.fight(company, recruit, FIGHT_SEED)
		seen = "%s with %d hp" % ["won" if fight["won"] else "lost", fight["hp"]]
	var next_offer := str(economy.offers()[0].get("id", ""))
	return (
		"roster %d, purse %d, next on offer %s, recruit alone: %s"
		% [company.roster.size(), economy.purse, next_offer, seen]
	)
