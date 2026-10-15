extends "res://tests/lib/effect_case.gd"
## walkout_advance (director 2026-10-16, "Walk out, no more advances"): after the company walks
## out on a faction's job, that faction's paymasters pay nothing up front until it finishes a
## job for them. Seed 424242: the company takes a contract, then walks out of it (on) or finishes
## it (off); then asks the same faction for half the next job's price as an advance. Walked out:
## the deal is struck with no coin in hand. Finished: the advance lands in the purse.

const Case := preload("res://tests/effect/contract_terms.gd")
const DAY := 1
const PERCENT := 100
const HALF := 50


func id() -> String:
	return "walkout_advance"


func run() -> Dictionary:
	return {"on": _then_ask(true), "off": _then_ask(false)}


func _then_ask(walks_out: bool) -> String:
	var made: Array = Case.posted()
	var company: Company = made[0]
	var first: String = made[1]
	var economy := company.economy
	var faction := str(economy.book.contract(first).get("faction", ""))
	economy.accept(first)
	if walks_out:
		economy.abandon(first, company, DAY)
	else:
		economy.complete(first, company.roster)
	var second := str(economy.board[0].get("id", ""))
	var row := economy.book.contract(second)
	row["faction"] = faction
	economy.standing.names[faction] = PERCENT
	var price := Merc.whole(row.get("reward", 0))
	var ask := {"price": price, "advance": price * HALF / PERCENT, "speaker": "", "day": DAY}
	var purse := economy.purse
	var reply := economy.negotiate(company, second, ask, Rng.from_seed(424242))
	return "%s, %d coin in hand" % [reply.get("reply", ""), economy.purse - purse]
