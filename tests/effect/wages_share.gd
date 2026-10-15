extends "res://tests/lib/effect_case.gd"
## wages_share: the men who fought a job are owed their share of its pay (Phase 5 C3). The
## starting company on seed 424242 takes the first contract on the board and completes it. Once
## the share is owed to the six who fought it, once no share is owed (nobody named as having
## fought). The purse then holds four days' wages (SAVED_DAYS) and the captain pays the whole
## debt every day it covers it, for a week: the share eats into those days, so wages go
## unpaid a day sooner, morale falls further and named men are left owed.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const WEEK := 7
## Days of wages the purse holds after the job.
const SAVED_DAYS := 4
const SITES: Array[String] = ["site_1", "site_2", "site_3"]


func id() -> String:
	return "wages_share"


func run() -> Dictionary:
	return {"on": _week(true), "off": _week(false)}


func _week(shares: bool) -> String:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	var rng := Rng.from_seed(SEED)
	economy.refresh_board(0, SITES, rng)
	var contract := str(economy.board[0].get("id", ""))
	economy.accept(contract)
	var fought: Array[Merc] = []
	if shares:
		fought = company.roster
	economy.complete(contract, fought)
	economy.purse = economy.wage_per_day(company.roster) * SAVED_DAYS
	for day: int in range(1, WEEK + 1):
		economy.on_day(company.roster, day, SITES, rng)
		economy.pay_wages()
	var owed_to: Array[String] = []
	for merc_id: Variant in economy.payroll.dues:
		owed_to.append("%s %d" % [merc_id, economy.payroll.dues[merc_id]])
	return (
		"morale %d, purse %d, owing %d (%s)"
		% [economy.morale, economy.purse, economy.owed, ", ".join(owed_to)]
	)
