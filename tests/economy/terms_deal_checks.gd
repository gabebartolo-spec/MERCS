extends "res://tests/economy/terms_checks.gd"
## The agreed deal against wages and standing (Phase 5 C2, after C3 and C4 and the review of
## #136), run by tests/run_economy_tests.gd: coin in is the agreed price at any advance and the
## men's share is of the whole price; an advance taken and left to lapse is walked away from.
## Seeded by design: the board of seed 424242 (terms_checks.gd).

## The share check's numbers: a posted reward the employer can meet at a price of PRICE.
const POSTED := 120
const PRICE := 100
const ADVANCES: Array[int] = [0, 50, 100]


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_full_price_share()
	_check_lapse()


## Coin in is the agreed price whatever the advance, and the men's share (C3) is of the whole
## price, advance included (lead's ruling on the review of #136; Q-3 "share of contract pay").
func _check_full_price_share() -> void:
	var seen: Array[String] = []
	var share_pct := Merc.whole(
		Fixture.sect(Fixture.sect(Case.defs(), "economy"), "wages").get("share_pct", 0)
	)
	for advance: int in ADVANCES:
		var company := _posted()
		var economy := company.economy
		var row := economy.book.contract(_cid)
		row["reward"] = POSTED
		economy.standing.names[str(row.get("faction", ""))] = 100
		var purse := economy.purse
		var owed := economy.owed
		var asked := {"price": PRICE, "advance": advance, "speaker": "", "day": DAY}
		var reply := _reply(economy.negotiate(company, _cid, asked, Rng.from_seed(SEED)))
		var before_return := economy.purse
		economy.complete(_cid, company.roster)
		seen.append(
			(
				"%s in %d (on return %d) share %d"
				% [reply, economy.purse - purse, economy.purse - before_return, economy.owed - owed]
			)
		)
	var expected: Array[String] = []
	for advance: int in ADVANCES:
		expected.append(
			(
				"accept in %d (on return %d) share %d"
				% [PRICE, PRICE - advance, PRICE * share_pct / 100]
			)
		)
	_ok(
		seen == expected,
		"coin in is the price and the share is of the whole price at any advance: %s" % [seen]
	)


## An accepted contract left to lapse after a 100% advance is walked away from: the advance is
## kept, the name falls, a grudge grows and the captain remembers it; with no advance a lapse
## stays as it was before C2 (review of #136).
func _check_lapse() -> void:
	var lines: Array[String] = []
	for whole_advance: bool in [true, false]:
		lines.append(_lapse_line(whole_advance))
	var standing := Fixture.sect(Fixture.sect(Case.defs(), "economy"), "standing")
	var start := Merc.whole(standing.get("start", 0))
	var dent := Merc.whole(standing.get("abandon_dent", 0))
	var dented := "accept gone true purse kept true name %d grudge true line standing.grudge"
	var quiet := "accept gone true purse kept true name %d grudge false line "
	_ok(
		lines == [dented % (start - dent), quiet % start],
		(
			"a lapse after a whole advance dents the name and grows a grudge; none stays quiet: %s"
			% [lines]
		)
	)


## One lapse story: an accepted 80% price, the advance whole or none, the days run past the
## deadline; what the company is left with, in words.
func _lapse_line(whole_advance: bool) -> String:
	var company := _posted()
	var economy := company.economy
	var row := economy.book.contract(_cid)
	var faction := str(row.get("faction", ""))
	var price := _reward(company, _cid) * 80 / PERCENT
	var asked := {
		"price": price, "advance": price if whole_advance else 0, "speaker": "", "day": DAY
	}
	var reply := _reply(economy.negotiate(company, _cid, asked, Rng.from_seed(SEED)))
	var purse := economy.purse
	for day: int in range(1, Merc.whole(row.get("deadline", 0)) + 2):
		economy.on_day(company.roster, day, Case.SITES, Rng.from_seed(SEED))
	var last: Dictionary = economy.chronicle.back() if not economy.chronicle.is_empty() else {}
	return (
		"%s gone %s purse kept %s name %d grudge %s line %s"
		% [
			reply,
			economy.book.contract(_cid).is_empty(),
			economy.purse == purse,
			economy.standing.reputation(faction),
			not economy.standing.grudge(faction).is_empty(),
			last.get("key", ""),
		]
	)
