extends "res://tests/lib/effect_case.gd"
## contract_terms: the employer's reply to an ask (Phase 5 C2, docs/plans/phase5_contracts.md).
## The same first contract on seed 424242, asked three ways, with the system's lever on and off:
## the same ask at a high name vs a low one (accepted vs countered); the same ask with a merc
## stepping in vs without (a different reply); an ask past the walk line vs one inside it (the
## employer walks, the contract leaves the board and the name falls).

const Fixture := preload("res://tests/lib/company_fixture.gd")
const TRAITS := "res://data/traits.json"
const SEED := 424242
const SITES: Array[String] = ["site_1", "site_2", "site_3"]
const DAY := 1
## The asks, in percent of the posted reward: a modest one, a firm one, one past the line.
const MODEST := 110
const FIRM := 112
const GREEDY := 150
const HIGH_NAME := 100
const LOW_NAME := 0
const PERCENT := 100
## The placeholder merc with the best bargaining trait (data/traits.json).
const SPEAKER := "vampyr"


func id() -> String:
	return "contract_terms"


func run() -> Dictionary:
	var on := [_by_name(HIGH_NAME), _step_in(SPEAKER), _ask_past_line(GREEDY)]
	var off := [_by_name(LOW_NAME), _step_in(""), _ask_past_line(MODEST)]
	return {"on": " | ".join(on), "off": " | ".join(off)}


static func defs() -> Dictionary:
	var made := Fixture.defs()
	made["traits"] = Fixture.json(TRAITS)
	return made


## A company with a fresh board; its first contract's id.
static func posted() -> Array:
	var company := Company.start(defs())
	company.economy.refresh_board(0, SITES, Rng.from_seed(SEED))
	return [company, str(company.economy.board[0].get("id", ""))]


static func ask(company: Company, contract_id: String, pct: int) -> Dictionary:
	var row := company.economy.book.contract(contract_id)
	var price := Merc.whole(row.get("reward", 0)) * pct / PERCENT
	return {"price": price, "advance": 0, "speaker": "", "day": DAY}


func _reply_words(reply: Dictionary) -> String:
	var words := str(reply.get("reply", ""))
	if words == Terms.COUNTER:
		words += " at %d" % Merc.whole(reply.get("counter_price", 0))
	return words


func _by_name(name_value: int) -> String:
	var made := posted()
	var company: Company = made[0]
	var contract_id: String = made[1]
	var faction := str(company.economy.book.contract(contract_id).get("faction", ""))
	company.economy.terms.stub_reputation[faction] = name_value
	var reply := company.economy.negotiate(
		company, contract_id, ask(company, contract_id, MODEST), Rng.from_seed(SEED)
	)
	return "name %d: %s" % [name_value, _reply_words(reply)]


func _step_in(speaker: String) -> String:
	var made := posted()
	var company: Company = made[0]
	var contract_id: String = made[1]
	var asked := ask(company, contract_id, FIRM)
	asked["speaker"] = speaker
	var reply := company.economy.negotiate(company, contract_id, asked, Rng.from_seed(SEED))
	return "speaker '%s': %s" % [speaker, _reply_words(reply)]


func _ask_past_line(pct: int) -> String:
	var made := posted()
	var company: Company = made[0]
	var contract_id: String = made[1]
	var faction := str(company.economy.book.contract(contract_id).get("faction", ""))
	var reply := company.economy.negotiate(
		company, contract_id, ask(company, contract_id, pct), Rng.from_seed(SEED)
	)
	return (
		"ask %d%%: %s, name %d, on board %s"
		% [
			pct,
			_reply_words(reply),
			company.economy.terms.reputation(faction),
			not company.economy.book.contract(contract_id).is_empty(),
		]
	)
