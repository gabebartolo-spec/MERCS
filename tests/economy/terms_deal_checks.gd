extends "res://tests/economy/terms_checks.gd"
## The agreed deal against wages and standing (Phase 5 C2, after C3 and C4 and the review of
## #136), run by tests/run_economy_tests.gd: coin in is the agreed price at any advance and the
## men's share is of the whole price. (A job left past its deadline after an advance is C1's:
## its Jobs judge calls Economy.abandon().)
## Seeded by design: the board of seed 424242 (terms_checks.gd).

## The share check's numbers: a posted reward the employer can meet at a price of PRICE.
const POSTED := 120
const PRICE := 100
const ADVANCES: Array[int] = [0, 50, 100]


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_full_price_share()


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
