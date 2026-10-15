extends "res://tests/lib/effect_case.gd"
## contract_grudge (Phase 5 C4, the reputation half): a broken deal is remembered. The same
## company and seed (424242) post a board, take its first contract with half its pay up front
## (the sizeable advance, standing.sizeable_advance), then once walk away from it
## (Economy.abandon) and once see it through (Economy.complete). Abandoned leaves a lower name
## with the faction, a grudge that has grown, and a line the captain remembers; completed
## leaves a better name and no grudge. (The hunter party the grudge sends is C4's second half.)

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const DAY := 1
const HALF := 2
const SITES: Array[String] = ["site_1", "site_2", "site_3"]


func id() -> String:
	return "contract_grudge"


func run() -> Dictionary:
	return {"on": _deal(true), "off": _deal(false)}


func _deal(abandons: bool) -> String:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	economy.on_day(company.roster, DAY, SITES, Rng.from_seed(SEED))
	var row: Dictionary = economy.board[0]
	var id_taken := str(row.get("id", ""))
	var faction := str(row.get("faction", ""))
	economy.accept(id_taken)
	# The advance taken up front: C2's terms write it; half the pay is "sizeable" (Q-16).
	row["advance"] = Merc.whole(row.get("reward", 0)) / HALF
	if abandons:
		economy.abandon(id_taken, company, DAY)
	else:
		economy.complete(id_taken)
	var grudge := economy.standing.grudge(faction)
	return (
		"name with %s %d, grudge growth %d, captain remembers %d lines"
		% [
			faction,
			economy.standing.reputation(faction),
			Merc.whole(grudge.get("growth", 0)),
			economy.chronicle.size()
		]
	)
