extends RefCounted
## The economy suite's wage checks, run by tests/run_economy_tests.gd (Phase 5 C3,
## docs/plans/phase5_contracts.md): each merc's daily wage by his level, the share of a
## contract's pay split by level among those who fought it, who is owed what, the share counted
## as owed wages (morale), and the save: dues survive a reload, reload-then-continue equals an
## uninterrupted run, and an economy saved before C3 (no "dues") loads with its debt intact.
## Expected numbers are read from data/balance/economy.json "wages", never restated here.
## Seeded by design: the economy suite's seed.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const PRE_WAGES := "res://tests/fixtures/save/economy_pre_wages.json"
const SEED := 424242
const SITES: Array[String] = ["site_1", "site_2", "site_3"]
## A reward chosen so the share does not divide evenly among six men of level 1.
const ODD_REWARD := 23
const DAYS := 4

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_day_wage_by_level()
	_share_by_level()
	_share_whole_coins()
	_no_share_without_fighters()
	_share_is_owed_wages()
	_dues_round_trip()
	_old_save()
	_dead_wages_forfeit()
	_abandon_pays_no_share()


func _company() -> Company:
	return Company.start(Fixture.defs())


func _wages() -> Dictionary:
	return Fixture.sect(Fixture.json(Fixture.ECONOMY), "wages")


func _table() -> Array:
	return Fixture.rows(_wages(), "day_by_level")


func _share_pot(reward: int) -> int:
	return reward * Merc.whole(_wages().get("share_pct", 0)) / Payroll.PERCENT


## The armour upkeep owed over `days` by the starting roster (Phase 5 C6): on the day's bill,
## owed to the armourer, not to any man.
func _upkeep(economy: Economy, days: int) -> int:
	return economy.armoury.upkeep(_company().roster) * days


func _sum(dues: Dictionary) -> int:
	var total := 0
	for id: Variant in dues:
		total += Merc.whole(dues[id])
	return total


## A merc raised to `level` by experience (data/balance/company.json xp.level_xp).
func _raise(company: Company, id: String, level: int) -> void:
	while company.member(id).level() < level:
		company.gain(id, 1)


func _day_wage_by_level() -> void:
	var company := _company()
	var payroll := company.economy.payroll
	var orc := company.member("orc")
	var table := _table()
	var first := payroll.day_wage(orc)
	_raise(company, "orc", 2)
	var second := payroll.day_wage(orc)
	_check.call(
		table.size() >= 2 and first == Merc.whole(table[0]) and second == Merc.whole(table[1]),
		"the daily wage is set by level: level 1 %d, level 2 %d (table %s)" % [first, second, table]
	)
	_check.call(
		second > first, "a merc who rises a level costs more a day (%d after %d)" % [second, first]
	)
	_raise(company, "orc", orc.max_level())
	var top := payroll.day_wage(orc)
	var last := Merc.whole(table[mini(orc.max_level(), table.size()) - 1])
	_check.call(top == last, "the highest level reads its own entry, got %d" % top)
	var sum := 0
	for merc: Merc in company.roster:
		sum += payroll.day_wage(merc)
	_check.call(
		company.economy.wage_per_day(company.roster) == sum,
		"a day of wages is the sum of each merc's wage, %d" % sum
	)


func _share_by_level() -> void:
	var company := _company()
	_raise(company, "orc", 2)
	var fought: Array[Merc] = [company.member("orc"), company.member("vampyr")]
	fought.append(company.member("merc_3"))
	var reward := Payroll.PERCENT * fought.size()
	var pot := _share_pot(reward)
	var total := company.economy.payroll.share(reward, fought)
	var dues := company.economy.payroll.dues
	var orc := Merc.whole(dues.get("orc", 0))
	var vampyr := Merc.whole(dues.get("vampyr", 0))
	_check.call(
		pot > 0 and total == pot and _sum(dues) == pot,
		"the share is share_pct of the contract's pay, all of it owed: %d of %d" % [total, pot]
	)
	_check.call(
		orc == 2 * vampyr and vampyr == Merc.whole(dues.get("merc_3", 0)),
		"the share splits by level: level 2 gets twice a level 1 (%s)" % [dues]
	)
	_check.call(
		not dues.has("merc_4"), "a merc who did not fight the job is owed no share: %s" % [dues]
	)


func _share_whole_coins() -> void:
	var company := _company()
	var pot := _share_pot(ODD_REWARD)
	var total := company.economy.payroll.share(ODD_REWARD, company.roster)
	var dues := company.economy.payroll.dues
	var low := ODD_REWARD
	var high := 0
	for id: Variant in dues:
		low = mini(low, Merc.whole(dues[id]))
		high = maxi(high, Merc.whole(dues[id]))
	_check.call(
		total == pot and _sum(dues) == pot and high - low <= 1,
		"a share that does not divide evenly is still owed whole, cuts within a coin: %s" % [dues]
	)


func _no_share_without_fighters() -> void:
	var economy := _company().economy
	economy.refresh_board(0, SITES, Rng.from_seed(SEED))
	var id := str(economy.board[0]["id"])
	var reward := Merc.whole(economy.board[0]["reward"])
	economy.accept(id)
	var purse := economy.purse
	_check.call(
		economy.complete(id) and economy.purse == purse + reward and economy.owed == 0,
		"a job completed with nobody named as fighting it pays the purse and owes no share"
	)


func _share_is_owed_wages() -> void:
	var runs := {}
	for shares: bool in [true, false]:
		var company := _company()
		var economy := company.economy
		var rng := Rng.from_seed(SEED)
		economy.refresh_board(0, SITES, rng)
		var id := str(economy.board[0]["id"])
		economy.accept(id)
		var fought: Array[Merc] = []
		if shares:
			fought = company.roster
		economy.complete(id, fought)
		for day: int in range(1, DAYS + 1):
			economy.on_day(company.roster, day, SITES, rng)
		runs[shares] = economy
	var shared: Economy = runs[true]
	var unshared: Economy = runs[false]
	_check.call(
		(
			shared.owed > unshared.owed
			and shared.owed == _sum(shared.payroll.dues) + _upkeep(shared, DAYS)
		),
		(
			"a share unpaid counts as owed wages, by man: owed %d, dues %s"
			% [shared.owed, shared.payroll.dues]
		)
	)
	_check.call(
		shared.morale < Merc.whole(Fixture.sect(Fixture.json(Fixture.ECONOMY), "morale")["start"]),
		"wages and share unpaid past the grace cost morale, at %d" % shared.morale
	)
	shared.purse = shared.owed
	_check.call(
		shared.pay_wages() and shared.owed == 0 and shared.payroll.dues.is_empty(),
		"paying the whole debt pays every man his wages and share"
	)


func _dues_round_trip() -> void:
	var company := _company()
	var rng := Rng.from_seed(SEED)
	company.economy.on_day(company.roster, 1, SITES, rng)
	company.economy.payroll.share(ODD_REWARD, company.roster)
	var text := JSON.stringify(company.state())
	var parsed: Variant = JSON.parse_string(text)
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var reloaded := Company.restore(saved, Fixture.defs())
	_check.call(
		reloaded.economy.payroll.dues == company.economy.payroll.dues,
		"who is owed what survives a save and reload: %s" % [reloaded.economy.payroll.dues]
	)
	var again := Rng.restore(rng.state())
	for day: int in [2, 3]:
		company.economy.on_day(company.roster, day, SITES, rng)
		reloaded.economy.on_day(reloaded.roster, day, SITES, again)
	_check.call(
		JSON.stringify(reloaded.state()) == JSON.stringify(company.state()),
		"reload then continue matches the run that never stopped"
	)


func _old_save() -> void:
	var saved := Fixture.json(PRE_WAGES)
	var economy := Economy.restore(saved, Fixture.defs())
	_check.call(
		(
			not saved.has("dues")
			and economy.owed == Merc.whole(saved["owed"])
			and economy.payroll.dues.is_empty()
		),
		"an economy saved before wages by level loads: its debt kept, owed to nobody by name"
	)
	var company := _company()
	economy.on_day(company.roster, 1, SITES, Rng.from_seed(SEED))
	var day := economy.wage_per_day(company.roster)
	_check.call(
		(
			_sum(economy.payroll.dues) == day
			and economy.owed == Merc.whole(saved["owed"]) + day + _upkeep(economy, 1)
		),
		"and from then on each day's wages are owed by name"
	)
	economy.purse = economy.owed
	_check.call(
		economy.pay_wages() and economy.owed == 0 and economy.payroll.dues.is_empty(),
		"and paying clears the old debt with the new"
	)


## Director 2026-10-16: a merc who dies owing wages is not paid them; the company stops owing them
## (the debt falls by his dues, the rest stands), also through a save and reload (JSON).
func _dead_wages_forfeit() -> void:
	var company := _company()
	var economy := company.economy
	var rng := Rng.from_seed(SEED)
	for day: int in [1, 2]:
		economy.on_day(company.roster, day, SITES, rng)
	var orc_owed := Merc.whole(economy.payroll.dues.get("orc", 0))
	var before := economy.owed
	company.bury("orc")
	_check.call(
		orc_owed > 0 and economy.owed == before - orc_owed and not economy.payroll.dues.has("orc"),
		(
			"a dead merc's unpaid wages are forfeit: debt %d -> %d (he was owed %d)"
			% [before, economy.owed, orc_owed]
		)
	)
	var parsed: Variant = JSON.parse_string(JSON.stringify(company.state()))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var reloaded := Company.restore(saved, Fixture.defs())
	_check.call(
		reloaded.economy.owed == economy.owed and not reloaded.economy.payroll.dues.has("orc"),
		"the forfeit survives a save and reload"
	)
	economy.purse = economy.owed
	_check.call(
		economy.pay_wages() and economy.purse == 0,
		"paying the debt costs the living only what they are owed"
	)


## Director 2026-10-16: when the company abandons a job and keeps the advance, the mercs get no
## share of it: nothing is owed to any man, the purse keeps the advance.
func _abandon_pays_no_share() -> void:
	var company := _company()
	var economy := company.economy
	economy.refresh_board(0, SITES, Rng.from_seed(SEED))
	var id := str(economy.board[0].get("id", ""))
	economy.accept(id)
	economy.board[0]["advance"] = Merc.whole(economy.board[0].get("reward", 0)) / 2
	var purse := economy.purse
	var owed := economy.owed
	economy.abandon(id, company, 1)
	_check.call(
		economy.payroll.dues.is_empty() and economy.owed == owed and economy.purse == purse,
		(
			"abandoning a job gives the mercs no share of the kept advance (owed %d, dues %s)"
			% [economy.owed, economy.payroll.dues]
		)
	)
