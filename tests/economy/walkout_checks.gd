extends RefCounted
## Walk out, no more advances (director 2026-10-16) and the old-save forfeit (review of #153),
## run by tests/run_economy_tests.gd. After the company abandons a job (a deadline that lapses
## on an advance included, Jobs calls the same Economy.abandon) that faction's paymasters pay
## nothing up front, per faction, until the company completes a job for them; the closed
## faction is saved. A save made before #153 that owes a merc already dead loads with his dues
## forfeit. The reload checks run in a new Godot process (restore_probe.gd).
## Seeded by design: the board of seed 424242.

const Case := preload("res://tests/effect/contract_terms.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const PROBE := "res://tests/economy/restore_probe.gd"
const SCRATCH := "user://walkout_save.json"
const SITES: Array[String] = ["site_1", "site_2", "site_3"]
const SEED := 424242
const DAY := 1
const PERCENT := 100
const HALF := 50
const LITTLE := 10
const DEAD := "orc"

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_closed_per_faction()
	_reopens_after_completing()
	_closed_survives_new_process()
	_old_save_forfeits_dead_dues()


## A posted company: [company, first contract id, second contract id].
func _posted() -> Array:
	var made: Array = Case.posted()
	var company: Company = made[0]
	return [company, made[1], str(company.economy.board[1].get("id", ""))]


func _reply(company: Company, id: String, advance_pct: int) -> Dictionary:
	var economy := company.economy
	var row := economy.book.contract(id)
	economy.standing.names[str(row.get("faction", ""))] = PERCENT
	var price := Merc.whole(row.get("reward", 0))
	var ask := {"price": price, "advance": price * advance_pct / PERCENT, "speaker": "", "day": DAY}
	return economy.negotiate(company, id, ask, Rng.from_seed(SEED))


func _closed_per_faction() -> void:
	var made := _posted()
	var company: Company = made[0]
	var economy := company.economy
	var first := economy.book.contract(str(made[1]))
	var other := economy.book.contract(str(made[2]))
	first["faction"] = "faction_a"
	other["faction"] = "faction_b"
	economy.accept(str(made[1]))
	var before := economy.terms.advance_open(other)
	economy.abandon(str(made[1]), company, DAY)
	_check.call(
		before and not economy.terms.advance_open(first) and economy.terms.advance_open(other),
		"walking out closes advances for that faction only"
	)
	var purse := economy.purse
	var reply := _reply(company, str(made[2]), LITTLE)
	_check.call(
		reply.get("reply") == Terms.ACCEPT and economy.purse > purse,
		(
			"another faction still pays a little up front: %s, purse %d -> %d"
			% [reply.get("reply"), purse, economy.purse]
		)
	)


func _reopens_after_completing() -> void:
	var made := _posted()
	var company: Company = made[0]
	var economy := company.economy
	var first_id := str(made[1])
	var faction := str(economy.book.contract(first_id).get("faction", ""))
	var second := economy.book.contract(str(made[2]))
	second["faction"] = faction
	economy.accept(first_id)
	economy.abandon(first_id, company, DAY)
	var purse := economy.purse
	var closed := _reply(company, str(made[2]), HALF)
	var paid_closed := economy.purse - purse
	_check.call(
		(
			closed.get("reply") == Terms.ACCEPT
			and paid_closed == 0
			and Merc.whole(economy.book.contract(str(made[2])).get("advance", -1)) == 0
		),
		(
			"a closed faction accepts the ask with the advance struck to nothing (in hand %d)"
			% paid_closed
		)
	)
	_finish_then_ask(company, faction)


func _finish_then_ask(company: Company, faction: String) -> void:
	var economy := company.economy
	var third := {
		"id": "x_third",
		"faction": faction,
		"site": "site_1",
		"reward": 60,
		"deadline": 9,
		"accepted": true
	}
	economy.board.append(third)
	economy.complete("x_third", company.roster)
	_check.call(economy.terms.advance_open(third), "finishing a job for them opens advances again")
	var fresh := {
		"id": "x_fresh", "faction": faction, "site": "site_1", "reward": 60, "deadline": 9
	}
	economy.board.append(fresh)
	var purse := economy.purse
	var reopened := _reply(company, "x_fresh", HALF)
	_check.call(
		reopened.get("reply") == Terms.ACCEPT and economy.purse - purse > 0,
		"and the advance is paid up front once more (in hand %d)" % (economy.purse - purse)
	)


func _closed_survives_new_process() -> void:
	var made := _posted()
	var company: Company = made[0]
	var first_id := str(made[1])
	var faction := str(company.economy.book.contract(first_id).get("faction", ""))
	company.economy.accept(first_id)
	company.economy.abandon(first_id, company, DAY)
	var seen := _reopened(company.state())
	var closed: Array = seen.get("no_advance", [])
	_check.call(
		closed == [faction], "the closed faction survives a save and a new process: %s" % [closed]
	)


func _old_save_forfeits_dead_dues() -> void:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	var rng := Rng.from_seed(SEED)
	for day: int in [1, 2]:
		economy.on_day(company.roster, day, SITES, rng)
	var saved := company.state()
	var roster: Array = saved["roster"]
	var living: Array = []
	for row: Variant in roster:
		var one: Dictionary = row
		if one.get("id") != DEAD:
			living.append(one)
	saved["roster"] = living
	saved["fallen"] = [DEAD]
	var held: Dictionary = saved["economy"]
	var dues: Dictionary = held["dues"]
	var dead_owed := Merc.whole(dues.get(DEAD, 0))
	var owed := Merc.whole(held["owed"])
	var seen := _reopened(saved)
	var after: Dictionary = seen["dues"] if seen.has("dues") else {}
	(
		_check
		. call(
			(
				dead_owed > 0
				and not after.has(DEAD)
				and Merc.whole(seen.get("owed", -1)) == owed - dead_owed
			),
			(
				"an old save owing a dead merc loads his dues forfeit (new process): owed %d -> %s, was %d"
				% [owed, seen.get("owed"), dead_owed]
			)
		)
	)


## The save written to disk and opened by a new Godot process: the probe's line as a dictionary.
func _reopened(saved: Dictionary) -> Dictionary:
	var file := FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	var args: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		PROBE,
		"--",
		ProjectSettings.globalize_path(SCRATCH),
	]
	var output: Array = []
	OS.execute(OS.get_executable_path(), args, output)
	for chunk: Variant in output:
		for line: String in str(chunk).split("\n"):
			if line.begins_with("RESTORE_STATE "):
				var parsed: Variant = JSON.parse_string(
					line.trim_prefix("RESTORE_STATE ").strip_edges()
				)
				return parsed if parsed is Dictionary else {}
	return {}
