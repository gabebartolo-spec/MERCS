extends "res://tests/lib/runner.gd"
## Economy suite (Phase 2 milestone 6: Economy, Contracts, Loot; data/balance/economy.json,
## data/factions.json, data/equipment.json, data/recruits.json). The sim half of the hub:
## wages fall due every day and pay in full or not at all; unpaid days past the grace cost
## morale and paying lifts it; the contract board is drawn from the two factions by pressure,
## on its own seeded stream, and accept, complete and expire work; loot is seeded and bounded
## by the data. Gear, hiring, the prisoner, the save and the world's hooks are the
## economy_company suite; the screen is the hub suite.
## Seeded by design: every roll comes from Rng.from_seed with the seeds named below.
##   godot --headless --path . --script tests/run_economy_tests.gd

const Fixture := preload("res://tests/lib/company_fixture.gd")
const GoldenChecks := preload("res://tests/economy/golden_checks.gd")
const TermsChecks := preload("res://tests/economy/terms_checks.gd")
const TermsDealChecks := preload("res://tests/economy/terms_deal_checks.gd")
const PayrollChecks := preload("res://tests/economy/payroll_checks.gd")
const ArmouryChecks := preload("res://tests/economy/armoury_checks.gd")
const SEED := 424242
const OTHER_SEED := 7
const WEEK := 7
const BOARDS := 40
const SITES: Array[String] = ["site_1", "site_2", "site_3"]
## A won fight's result: two fallen watchmen and a bandit, the classes they carried (Phase 5 C6).
const FALLEN := {"won": true, "fallen_gear": ["spear", "mail", "spear", "mail", "sword", "leather"]}


func suite_name() -> String:
	return "Economy"


func run_checks() -> void:
	_check_data()
	_check_wages_fall_due()
	_check_paying()
	_check_morale()
	_check_contract_board()
	_check_contracts_by_pressure()
	_check_contract_lifecycle()
	_check_loot()
	GoldenChecks.new().run(check)
	TermsChecks.new().run(check)
	TermsDealChecks.new().run(check)
	PayrollChecks.new().run(check)
	ArmouryChecks.new().run(check)
	await process_frame


func _company() -> Company:
	return Company.start(Fixture.defs())


func _day(company: Company, day: int) -> void:
	company.economy.on_day(company.roster, day, SITES, Rng.from_seed(SEED))


func _through_json(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


## The names of the Rng streams that have rolled, sorted.
func _streams(rng: Rng) -> Array[String]:
	var held: Dictionary = rng.state()["streams"]
	var names: Array[String] = []
	for name: Variant in held:
		names.append(str(name))
	names.sort()
	return names


func _w(value: Variant) -> int:
	return Merc.whole(value)


func _is(found: Variant, expected: Variant) -> bool:
	return found == expected


func _check_data() -> void:
	var factions: Array = Fixture.json(Fixture.FACTIONS).get("factions", [])
	var pressures: Array[int] = []
	for entry: Variant in factions:
		var def: Dictionary = entry
		pressures.append(Merc.whole(def.get("pressure", 0)))
	check(
		factions.size() == 2 and pressures.all(func(p: int) -> bool: return p > 0 and p <= 100),
		"two factions in tension, each with a pressure from 1 to 100, got %s" % [pressures]
	)
	_check_recruits_and_gear()


func _check_recruits_and_gear() -> void:
	var recruits: Array = Fixture.json(Fixture.RECRUITS).get("recruits", [])
	var bad: Array[String] = []
	for i: int in recruits.size():
		var def: Dictionary = recruits[i]
		if def.get("placeholder") != true or def.get("name") != "Recruit %d" % (i + 1):
			bad.append(str(def.get("id")))
	check(
		not recruits.is_empty() and bad.is_empty(),
		"every hireable recruit is a placeholder named Recruit N, bad: %s" % [bad]
	)
	var wrong: Array[String] = []
	var items: Array = Fixture.json(Fixture.EQUIPMENT).get("equipment", [])
	for entry: Variant in items:
		var item: Dictionary = entry
		if str(item.get("slot")) not in Merc.SLOTS:
			wrong.append(str(item.get("id")))
	var slots: Array[String] = []
	for entry: Variant in items:
		var item: Dictionary = entry
		if str(item.get("slot")) not in slots:
			slots.append(str(item.get("slot")))
	check(
		wrong.is_empty() and slots.size() == Merc.SLOTS.size(),
		"generic gear fills the three slots (weapon, armour, trinket), wrong: %s" % [wrong]
	)


func _check_wages_fall_due() -> void:
	var company := _company()
	var per_day: int = company.economy.wage_per_day(company.roster)
	check(per_day > 0, "a roster of six costs coin every day, got %d" % per_day)
	_day(company, 1)
	_day(company, 2)
	_day(company, 3)
	check(
		(
			company.economy.owed == (per_day + company.economy.armoury.upkeep(company.roster)) * 3
			and company.economy.unpaid_days == 3
		),
		(
			"three days unpaid owe three days of wages and armour upkeep, owed %d"
			% company.economy.owed
		)
	)
	company.add("recruit_1")
	check(
		company.economy.wage_per_day(company.roster) > per_day, "a bigger roster costs more a day"
	)


func _check_paying() -> void:
	var company := _company()
	var economy := company.economy
	check(not economy.pay_wages(), "nothing owed, nothing to pay")
	_day(company, 1)
	var before := economy.purse
	var due := economy.owed
	check(economy.pay_wages(), "the wages are paid when the purse covers them")
	check(
		economy.purse == before - due and economy.owed == 0 and economy.unpaid_days == 0,
		"paying takes the debt from the purse and ends the unpaid days"
	)
	_day(company, 2)
	economy.purse = economy.owed - 1
	check(
		not economy.pay_wages() and economy.owed > 0 and economy.purse == economy.owed - 1,
		"a purse that falls short pays nothing and the debt stands"
	)


func _check_morale() -> void:
	var rules: Dictionary = Fixture.json(Fixture.ECONOMY)
	var grace: int = rules["wages"]["grace_days"]
	var loss: int = rules["wages"]["morale_loss_per_day"]
	var company := _company()
	var start := company.economy.morale
	for day: int in range(1, grace + 1):
		_day(company, day)
	check(company.economy.morale == start, "no morale lost within the %d grace days" % grace)
	_day(company, grace + 1)
	check(
		company.economy.morale == start - loss,
		"the first day past the grace costs %d morale, got %d" % [loss, company.economy.morale]
	)
	company.economy.purse = company.economy.owed
	var low := company.economy.morale
	company.economy.pay_wages()
	check(company.economy.morale > low, "paying the debt lifts morale")
	var floor_company := _company()
	for day: int in range(1, 60):
		_day(floor_company, day)
	check(floor_company.economy.morale == 0, "morale stops at 0 however long wages go unpaid")
	var ceiling := _company()
	for day: int in range(1, 30):
		_day(ceiling, day)
		ceiling.economy.purse = ceiling.economy.owed
		ceiling.economy.pay_wages()
	check(
		ceiling.economy.morale == _w(rules["morale"]["max"]),
		"morale stops at the ceiling however many days are paid"
	)


func _board(seed_value: int) -> Array[Dictionary]:
	var economy := _company().economy
	economy.refresh_board(0, SITES, Rng.from_seed(seed_value))
	return economy.board


func _check_contract_board() -> void:
	var rules: Dictionary = Fixture.json(Fixture.ECONOMY)["contracts"]
	var board := _board(SEED)
	var factions: Array[String] = ["fac_placeholder_a", "fac_placeholder_b"]
	var in_range: bool = (
		board.size() >= _w(rules["board_min"]) and board.size() <= _w(rules["board_max"])
	)
	check(in_range, "the board posts %d to %d contracts, got %d" % [1, 3, board.size()])
	var bad: Array[String] = []
	for row: Dictionary in board:
		var reward: int = row["reward"]
		var late: int = row["deadline"]
		if (
			row["site"] not in SITES
			or row["faction"] not in factions
			or reward < rules["reward_min"]
			or reward > rules["reward_max"]
			or late < rules["deadline_min"]
			or late > rules["deadline_max"]
			or row["accepted"] != false
		):
			bad.append(str(row["id"]))
	check(bad.is_empty(), "every contract names a site, a faction, a reward, a deadline: %s" % bad)
	check(
		_is(_board(SEED), _board(SEED)) and not _is(_board(SEED), _board(OTHER_SEED)),
		"the same seed posts the same board and another seed another"
	)
	var economy := _company().economy
	var rng := Rng.from_seed(SEED)
	economy.refresh_board(0, SITES, rng)
	check(
		_streams(rng) == ["contracts", "jobs"],
		(
			'the board rolls only its own streams, "contracts" and the job types on "jobs" (C1), got %s'
			% [_streams(rng)]
		)
	)
	economy.refresh_board(0, [], Rng.from_seed(SEED))
	check(economy.board.is_empty(), "with no site to name there is no contract")


func _check_contracts_by_pressure() -> void:
	var loud_a := _faction_counts(100, 1)
	var loud_b := _faction_counts(1, 100)
	check(
		(
			_w(loud_a["fac_placeholder_a"]) > _w(loud_a["fac_placeholder_b"]) * 3
			and _w(loud_b["fac_placeholder_b"]) > _w(loud_b["fac_placeholder_a"]) * 3
		),
		"the faction under more pressure posts most of the contracts: %s then %s" % [loud_a, loud_b]
	)


## How many contracts each faction posts over BOARDS boards when the two press as given.
func _faction_counts(pressure_a: int, pressure_b: int) -> Dictionary:
	var defs := Fixture.defs()
	var factions: Array = defs["factions"]["factions"]
	factions[0]["pressure"] = pressure_a
	factions[1]["pressure"] = pressure_b
	var counts := {"fac_placeholder_a": 0, "fac_placeholder_b": 0}
	var rng := Rng.from_seed(SEED)
	var economy := Economy.make(defs)
	for day: int in BOARDS:
		economy.refresh_board(day, SITES, rng)
		for row: Dictionary in economy.board:
			counts[row["faction"]] += 1
	return counts


func _check_contract_lifecycle() -> void:
	var economy := _company().economy
	economy.refresh_board(0, SITES, Rng.from_seed(SEED))
	var row: Dictionary = economy.board[0]
	var id: String = row["id"]
	check(not economy.complete(id), "a contract not yet accepted cannot be completed")
	check(economy.accept(id) and not economy.accept(id), "a contract is accepted once")
	check(not economy.accept("ctr_nope"), "an unknown contract is refused")
	economy.refresh_board(1, SITES, Rng.from_seed(OTHER_SEED))
	check(
		_is(economy.book.contract(id).get("accepted"), true),
		"a fresh board keeps the contracts already accepted"
	)
	var purse := economy.purse
	check(
		economy.complete(id) and economy.purse == purse + _w(row["reward"]),
		"completing pays the reward"
	)
	check(economy.book.contract(id).is_empty(), "a completed contract leaves the board")
	economy.refresh_board(0, SITES, Rng.from_seed(SEED))
	# A negative reward still pays, as it did before the split (the row is not a refusal).
	economy.book.board.append({"id": "ctr_neg", "accepted": true, "reward": -5})
	var before := economy.purse
	check(
		economy.complete("ctr_neg") and economy.purse == before - 5,
		"a negative reward is paid and the call returns true"
	)
	var lapsing: Dictionary = economy.board[0]
	var lapsed := economy.book.expire(_w(lapsing["deadline"]) + 1)
	check(
		str(lapsing["id"]) in lapsed and economy.book.contract(str(lapsing["id"])).is_empty(),
		"a contract past its deadline lapses, lapsed: %s" % [lapsed]
	)


func _check_loot() -> void:
	var rules: Dictionary = Fixture.json(Fixture.ECONOMY)["loot"]["patrol"]
	var items := _worn_ids()
	var seen: Array[String] = []
	var bounded := true
	var gear := 0
	for seed_value: int in range(1, BOARDS):
		var economy := _company().economy
		var purse := economy.purse
		var loot := economy.take_loot("patrol", Rng.from_seed(seed_value), FALLEN)
		seen.append(JSON.stringify(loot))
		bounded = (
			bounded
			and loot["coin"] >= rules["coin_min"]
			and loot["coin"] <= rules["coin_max"]
			and economy.purse == purse + loot["coin"]
			and (loot["item"] == "" or loot["item"] in items)
			and economy.inventory.size() == (0 if loot["item"] == "" else 1)
		)
		gear += 0 if loot["item"] == "" else 1
	check(bounded, "loot coin stays in the data's range and worn gear goes to the pack")
	check(gear > 0 and gear < BOARDS - 1, "some fights leave gear and some do not: %d" % gear)
	_check_loot_determinism(seen)


## The worn forms' ids in data/equipment.json: what loot can leave (Phase 5 C6).
func _worn_ids() -> Array[String]:
	var items: Array[String] = []
	for entry: Variant in Fixture.json(Fixture.EQUIPMENT)["equipment"]:
		var def: Dictionary = entry
		if def.has("worn"):
			items.append(str(def["worn"]["id"]))
	return items


func _check_loot_determinism(seen: Array[String]) -> void:
	var again := _company().economy.take_loot("patrol", Rng.from_seed(SEED))
	check(
		_is(again, _company().economy.take_loot("patrol", Rng.from_seed(SEED))),
		"the same seed loots the same things"
	)
	var seeds := {}
	for entry: String in seen:
		seeds[entry] = true
	check(seeds.size() > 1, "different seeds loot different things")
	var none := _company().economy.take_loot("not_a_fight", Rng.from_seed(SEED))
	check(
		_w(none["coin"]) == 0 and str(none["item"]) == "",
		"a fight the data does not list leaves nothing"
	)
	var rng := Rng.from_seed(SEED)
	_company().economy.take_loot("ambush", rng)
	check(_streams(rng) == ["loot"], 'loot rolls only its own stream, "loot"')
