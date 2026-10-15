extends RefCounted
## Terms and negotiation checks, run by tests/run_economy_tests.gd (Phase 5 C2, sim/economy/
## terms.gd): the employer's reply is the rule over name, need and ask (accept, counter, walk);
## an agreed advance is paid now and the rest on return; a counter can be taken; a walk takes
## the contract off the board and dents the name; the step-in is once per contract, by a merc
## on the roster, on the "terms" stream only, and leaves a line on him; the name saves only
## once moved, an old save loads, and save, reload, continue equals uninterrupted.
## Seeded by design: seed 424242 for the board, and the step-in seeds found by _seed_for().

const Case := preload("res://tests/effect/contract_terms.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const DAY := 3
const PERCENT := 100
const SEARCH := 200

var _check: Callable
var _cid := ""


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_traits_data()
	_check_rule()
	_check_accept_pays()
	_check_counter_then_take()
	_check_walk()
	_check_bad_asks()
	_check_step_in()
	_check_step_in_once()
	_check_save()


func _ok(condition: Variant, expectation: String) -> void:
	_check.call(condition == true, expectation)


## A company with a fresh board; its first contract's id is left in _cid.
func _posted() -> Company:
	var made: Array = Case.posted()
	var company: Company = made[0]
	_cid = str(made[1])
	return company


func _ask(company: Company, contract_id: String, pct: int, advance: int) -> Dictionary:
	var asked := Case.ask(company, contract_id, pct)
	asked["advance"] = advance
	return asked


func _reward(company: Company, contract_id: String) -> int:
	return Merc.whole(company.economy.book.contract(contract_id).get("reward", 0))


func _check_traits_data() -> void:
	var defs := Case.defs()
	var mercs: Array = Fixture.rows(Fixture.sect(defs, "mercs"), "mercs")
	var ids: Array[String] = []
	for def: Variant in mercs:
		var merc_def: Dictionary = def
		ids.append(str(merc_def.get("id", "")))
	var traits: Array = Fixture.rows(Fixture.sect(defs, "traits"), "traits")
	var good := not traits.is_empty()
	for def: Variant in traits:
		var row: Dictionary = def
		good = good and row.get("placeholder") == true and Merc.whole(row.get("bargain", 0)) > 0
		for holder: Variant in Fixture.rows(row, "held_by"):
			good = good and str(holder) in ids
	_ok(good, "every bargaining trait is a marked placeholder held by a merc in data/mercs.json")


## The reply is the rule: inside the limit accept, inside the band counter, past it walk; a
## better name or a needier faction raises the limit; an advance weighs on it.
func _check_rule() -> void:
	var company := _posted()
	var terms := company.economy.terms
	var row := company.economy.book.contract(_cid)
	var faction := str(row.get("faction", ""))
	var limit := terms.limit_pct(row)
	var reward := _reward(company, _cid)
	var at_limit := reward * limit / PERCENT
	var replies := [
		_reply(terms.judge(row, at_limit, 0)),
		_reply(terms.judge(row, at_limit + reward / 10, 0)),
		_reply(terms.judge(row, reward * 2, 0)),
	]
	_ok(
		replies == [Terms.ACCEPT, Terms.COUNTER, Terms.WALK],
		"at the limit accept, a tenth past counter, double walk; got %s" % [replies]
	)
	_ok(
		_reply(terms.judge(row, at_limit, at_limit)) != Terms.ACCEPT,
		"the same price wholly in advance weighs more: no longer accepted"
	)
	company.economy.standing.names[faction] = 100
	var high := terms.limit_pct(row)
	company.economy.standing.names[faction] = 0
	var low := terms.limit_pct(row)
	_ok(
		high > limit and limit > low,
		"a better name raises the limit: %d > %d > %d" % [high, limit, low]
	)
	var why := terms.judge(row, at_limit, 0)
	_ok(
		(
			why.has_all(["reputation", "need", "limit_pct", "ask_pct"])
			and Merc.whole(why.get("need", 0)) > 0
		),
		(
			"the reply carries the numbers it was judged on (need is the faction's pressure): %s"
			% [why]
		)
	)


func _check_accept_pays() -> void:
	var company := _posted()
	var economy := company.economy
	var purse := economy.purse
	var reward := _reward(company, _cid)
	var advance := reward / 4
	var reply := economy.negotiate(
		company, _cid, _ask(company, _cid, PERCENT, advance), Rng.from_seed(SEED)
	)
	var row := economy.book.contract(_cid)
	_ok(
		(
			_reply(reply) == Terms.ACCEPT
			and row.get("accepted") == true
			and economy.purse == purse + advance
			and Merc.whole(row.get("advance", -1)) == advance
		),
		(
			"an accepted ask is taken, its advance paid now and kept on the row (%s, purse %d)"
			% [reply, economy.purse]
		)
	)
	economy.complete(_cid)
	_ok(
		economy.purse == purse + reward,
		(
			"on return the rest is paid: advance plus remainder is the agreed price %d, purse %d"
			% [reward, economy.purse]
		)
	)


func _check_counter_then_take() -> void:
	var company := _posted()
	var economy := company.economy
	var reply := economy.negotiate(company, _cid, _ask(company, _cid, 115, 0), Rng.from_seed(SEED))
	var row := economy.book.contract(_cid)
	_ok(
		_reply(reply) == Terms.COUNTER and row.get("accepted") != true and row.has("counter_price"),
		"a firm ask is countered; the offer stays open with his terms on it: %s" % [reply]
	)
	var take := {
		"price": row["counter_price"], "advance": row["counter_advance"], "speaker": "", "day": DAY
	}
	var again := economy.negotiate(company, _cid, take, Rng.from_seed(SEED))
	_ok(
		_reply(again) == Terms.ACCEPT and not row.has("counter_price"),
		"his counter, asked back, is accepted"
	)


func _check_walk() -> void:
	var company := _posted()
	var economy := company.economy
	var faction := str(economy.book.contract(_cid).get("faction", ""))
	var before := economy.terms.reputation(faction)
	var board := economy.board.size()
	var reply := economy.negotiate(company, _cid, _ask(company, _cid, 150, 0), Rng.from_seed(SEED))
	_ok(
		_reply(reply) == Terms.WALK and economy.board.size() == board - 1,
		"past the line he walks and the contract leaves the board"
	)
	_ok(
		economy.terms.reputation(faction) < before and economy.state().has("standing"),
		(
			"the name with that faction falls (%d to %d) and is saved"
			% [before, economy.terms.reputation(faction)]
		)
	)
	var again := economy.negotiate(
		company, _cid, _ask(company, _cid, PERCENT, 0), Rng.from_seed(SEED)
	)
	_ok(_reply(again) == "", "a walked-away contract cannot be talked over again")


func _check_bad_asks() -> void:
	var company := _posted()
	var before := JSON.stringify(company.economy.state())
	var greedy_advance := _ask(company, _cid, PERCENT, _reward(company, _cid) + 1)
	var replies := [
		_reply(company.economy.negotiate(company, _cid, greedy_advance, Rng.from_seed(SEED))),
		_reply(
			company.economy.negotiate(
				company, "ctr_999", _ask(company, _cid, PERCENT, 0), Rng.from_seed(SEED)
			)
		),
	]
	_ok(
		replies == ["", ""] and JSON.stringify(company.economy.state()) == before,
		"an advance above the price, or an unknown contract, changes nothing: %s" % [replies]
	)


## The first seed from 1 on whose step-in by `speaker` succeeds (or fails).
func _seed_for(speaker: String, success: bool) -> int:
	for seed_value: int in range(1, SEARCH):
		var company := _posted()
		var asked := _ask(company, _cid, PERCENT, 0)
		asked["speaker"] = speaker
		var reply := company.economy.negotiate(company, _cid, asked, Rng.from_seed(seed_value))
		var check := _step(reply)
		if check.get("success") == success:
			return seed_value
	return 0


func _check_step_in() -> void:
	var won := _seed_for(Case.SPEAKER, true)
	var lost := _seed_for(Case.SPEAKER, false)
	_ok(won > 0 and lost > 0, "the step-in can both succeed and fail (seeds %d, %d)" % [won, lost])
	var limits: Array[int] = []
	for seed_value: int in [won, lost]:
		var company := _posted()
		var odds := company.economy.terms.odds(Case.SPEAKER)
		var asked := _ask(company, _cid, PERCENT, 0)
		asked["speaker"] = Case.SPEAKER
		var rng := Rng.from_seed(seed_value)
		var reply := company.economy.negotiate(company, _cid, asked, rng)
		limits.append(Merc.whole(reply.get("limit_pct", 0)))
		var line: Dictionary = company.economy.chronicle.back()
		var streams: Dictionary = rng.state()["streams"]
		_ok(
			(
				line.get("merc") == Case.SPEAKER
				and Merc.whole(_step(reply).get("odds", -1)) == odds
				and streams.keys() == [Terms.STREAM]
			),
			"the step-in writes a line on him, shows the odds it rolled at, rolls only 'terms'"
		)
	var company := _posted()
	var base := company.economy.terms.limit_pct(company.economy.book.contract(_cid))
	_ok(
		limits[0] > base and limits[1] < base,
		"success raises his limit, failure lowers it: %s vs %d" % [limits, base]
	)
	var orc := company.economy.terms.odds("orc")
	var vampyr := company.economy.terms.odds(Case.SPEAKER)
	_ok(vampyr > orc, "the better bargainer has better odds (%d%% vs %d%%)" % [vampyr, orc])


func _check_step_in_once() -> void:
	var company := _posted()
	var rng := Rng.from_seed(SEED)
	var asked := _ask(company, _cid, 125, 0)
	asked["speaker"] = "nobody"
	var reply := company.economy.negotiate(company, _cid, asked, rng)
	_ok(_step(reply).is_empty(), "a merc not on the roster cannot step in")
	asked["speaker"] = Case.SPEAKER
	company.economy.negotiate(company, _cid, asked, rng)
	var after_one := JSON.stringify(rng.state())
	asked["speaker"] = "orc"
	reply = company.economy.negotiate(company, _cid, asked, rng)
	_ok(
		_step(reply).is_empty() and JSON.stringify(rng.state()) == after_one,
		"one step-in per negotiation: a second speaker rolls nothing"
	)


## The name saves only once moved (old routes keep their save text); an old save loads at the
## starting name; a talk saved halfway and reloaded ends as the uninterrupted one.
func _check_save() -> void:
	var fresh := Company.start(Case.defs())
	var old_state := fresh.economy.state()
	_ok(not old_state.has("standing"), "an untouched economy saves no new key")
	var loaded := Economy.restore(_json(old_state), Case.defs())
	var rules := Fixture.sect(Fixture.sect(Case.defs(), "economy"), "standing")
	var start := Merc.whole(rules.get("start", 0))
	_ok(
		loaded.terms.reputation("fac_placeholder_a") == start,
		"an old save loads at the starting name"
	)
	var whole := _talk(false)
	var halves := _talk(true)
	_ok(whole == halves, "save, reload, continue equals uninterrupted:\n%s\n%s" % [whole, halves])


## A firm ask with a step-in (countered or not), then a walk on the next contract, then the
## first ask again; optionally through a save between each.
func _talk(reload: bool) -> String:
	var company := _posted()
	var rng := Rng.from_seed(SEED)
	var asked := _ask(company, _cid, 118, 2)
	asked["speaker"] = Case.SPEAKER
	company.economy.negotiate(company, _cid, asked, rng)
	if reload:
		company = Company.restore(_json(company.state()), Case.defs())
		rng = _rng_through_save(rng)
	var second := str(company.economy.board[-1].get("id", ""))
	company.economy.negotiate(company, second, _ask(company, second, 150, 0), rng)
	if reload:
		company = Company.restore(_json(company.state()), Case.defs())
		rng = _rng_through_save(rng)
	asked["speaker"] = "orc"
	company.economy.negotiate(company, _cid, asked, rng)
	return JSON.stringify(company.state()) + JSON.stringify(rng.state())


static func _reply(reply: Dictionary) -> String:
	return str(reply.get("reply", ""))


static func _step(reply: Dictionary) -> Dictionary:
	var held: Variant = reply.get("check", {})
	return held if held is Dictionary else {}


## The Rng as a save carries it (SaveModel writes stream positions as digit strings, exact
## int64) and reads it back.
static func _rng_through_save(rng: Rng) -> Rng:
	var held: Dictionary = rng.state()
	var streams: Dictionary = held["streams"]
	var text := {}
	for name: Variant in streams:
		text[str(name)] = str(streams[name])
	var back := _json({"seed": str(held["seed"]), "streams": text})
	var whole := {}
	var read: Dictionary = back["streams"]
	for name: Variant in read:
		whole[str(name)] = str(read[name]).to_int()
	return Rng.restore({"seed": str(back["seed"]).to_int(), "streams": whole})


static func _json(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}
