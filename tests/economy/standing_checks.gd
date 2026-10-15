extends RefCounted
## The economy-company suite's standing checks (Phase 5 C4, the reputation half), run by
## tests/run_economy_company_tests.gd. The name is kept per faction (Q-7): completing mends it,
## failing honestly only dents it, an employer walking dents it, abandoning dents it more; only
## abandoning after an advance of standing.sizeable_advance percent of the pay or more (Q-16,
## "half the pay or more") grows the faction's one grudge, which records the deal and the
## captain and grows again with each such deal (Q-15). The captain remembers the abandon. The
## standing rides in the save as an optional key: a new game saves without it, an old save
## (fixtures/save/v2.json) loads at the starting name and can go on to abandon, and a reload in
## the middle continues exactly as an uninterrupted run.
## Seeded by design: nothing here rolls (the standing is computed, not drawn).

const Fixture := preload("res://tests/lib/company_fixture.gd")
const V2_FIXTURE := "res://tests/fixtures/save/v2.json"
const WORLD_BALANCE := "res://data/balance/world.json"
const A := "fac_placeholder_a"
const B := "fac_placeholder_b"
const PAY := 40
const DAY := 3
const DIRECTOR_HALF := 50

var _check: Callable
var _rules: Dictionary = {}


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	var economy_rules: Dictionary = Fixture.defs()["economy"]
	_rules = economy_rules.get("standing", {})
	_check_data()
	_check_per_faction()
	_check_honest_failure()
	_check_abandon_without_advance()
	_check_sizeable_line()
	_check_grudge_grows()
	_check_refusals()
	_check_save_key_optional()
	_check_old_save()
	_check_reload_continue()


func _rule(key: String) -> int:
	return Merc.whole(_rules.get(key, -1))


func _company() -> Company:
	return Company.start(Fixture.defs())


## Posts an accepted contract for `faction` paying PAY with `advance` taken up front.
func _take(economy: Economy, id: String, faction: String, advance: int) -> void:
	(
		economy
		. board
		. append(
			{
				"id": id,
				"faction": faction,
				"site": "site_1",
				"reward": PAY,
				"deadline": DAY + 10,
				"accepted": true,
				"advance": advance,
			}
		)
	)


func _through_json(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _last_line(economy: Economy) -> Dictionary:
	return economy.chronicle.back() if not economy.chronicle.is_empty() else {}


func _check_data() -> void:
	_check.call(
		_rule("sizeable_advance") == DIRECTOR_HALF and _rule("start") >= _rule("min"),
		"standing.sizeable_advance is half the pay (50), got %d" % _rule("sizeable_advance")
	)


func _check_per_faction() -> void:
	var economy := _company().economy
	var start := _rule("start")
	_check.call(
		economy.standing.reputation(A) == start and economy.standing.reputation(B) == start,
		"a new company stands at standing.start with both factions"
	)
	_take(economy, "ctr_a", A, 0)
	economy.complete("ctr_a")
	_check.call(
		(
			economy.standing.reputation(A) == start + _rule("complete_mend")
			and economy.standing.reputation(B) == start
		),
		"completing a contract mends the name with its faction only (per faction, Q-7)"
	)
	economy.standing.walked(B)
	_check.call(
		economy.standing.reputation(B) == start - _rule("walk_dent"),
		"an employer walking from an ask dents the name with that faction"
	)


func _check_honest_failure() -> void:
	var economy := _company().economy
	economy.standing.failed(A)
	_check.call(
		(
			economy.standing.reputation(A) == _rule("start") - _rule("fail_dent")
			and economy.standing.grudge(A).is_empty()
			and economy.standing.hunter_calls().is_empty()
		),
		"failing honestly only dents the name: no grudge, no hunters"
	)


func _check_abandon_without_advance() -> void:
	var company := _company()
	var economy := company.economy
	_take(economy, "ctr_1", A, 0)
	var ok := economy.abandon("ctr_1", company, DAY)
	_check.call(
		(
			ok
			and economy.book.contract("ctr_1").is_empty()
			and economy.standing.reputation(A) == _rule("start") - _rule("abandon_dent")
			and economy.standing.grudge(A).is_empty()
		),
		"abandoning without an advance leaves the board and dents the name, no grudge"
	)
	var last := _last_line(economy)
	_check.call(
		last == {"day": DAY, "merc": company.captain_id, "key": "standing.abandon"},
		"the captain remembers the abandoned deal, got %s" % [last]
	)


func _check_sizeable_line() -> void:
	var company := _company()
	var economy := company.economy
	var half := PAY * _rule("sizeable_advance") / Standing.PERCENT
	_take(economy, "ctr_under", A, half - 1)
	_take(economy, "ctr_half", B, half)
	economy.abandon("ctr_under", company, DAY)
	economy.abandon("ctr_half", company, DAY)
	var grudge := economy.standing.grudge(B)
	_check.call(
		economy.standing.grudge(A).is_empty() and grudge.get("growth") == _rule("grudge_growth"),
		"an advance just under half the pay grows no grudge; half the pay grows one (Q-16)"
	)
	_check.call(
		grudge.get("deals") == ["ctr_half"] and grudge.get("captain") == company.captain_id,
		"the grudge names the broken deal and the captain at the time, got %s" % [grudge]
	)
	_check.call(
		str(_last_line(economy).get("key")) == "standing.grudge",
		"the captain's memory of the grudge deal is its own line"
	)


func _check_grudge_grows() -> void:
	var company := _company()
	var economy := company.economy
	_take(economy, "ctr_1", A, PAY)
	_take(economy, "ctr_2", A, PAY)
	economy.abandon("ctr_1", company, DAY)
	economy.abandon("ctr_2", company, DAY + 1)
	var grudge := economy.standing.grudge(A)
	_check.call(
		(
			economy.standing.grudges.size() == 1
			and grudge.get("growth") == 2 * _rule("grudge_growth")
			and grudge.get("deals") == ["ctr_1", "ctr_2"]
		),
		"a second broken deal grows the faction's one grudge (Q-15), got %s" % [grudge]
	)
	_check.call(
		economy.standing.hunter_calls() == [A],
		"the hunter hook names the faction whose grudge has grown"
	)


func _check_refusals() -> void:
	var company := _company()
	var economy := company.economy
	_take(economy, "ctr_1", A, PAY)
	economy.board[0]["accepted"] = false
	var before := economy.state()
	_check.call(
		(
			not economy.abandon("ctr_1", company, DAY)
			and not economy.abandon("ctr_none", company, DAY)
			and economy.state() == before
		),
		"a contract not taken, or not on the board, cannot be abandoned (no change)"
	)
	for i: int in range(_rule("max")):
		economy.standing.failed(B)
	_check.call(
		economy.standing.reputation(B) == _rule("min"), "a name never falls below standing.min"
	)


func _check_save_key_optional() -> void:
	var company := _company()
	_check.call(
		not company.economy.state().has("standing"),
		"a game whose names never moved saves without the standing key (old routes unchanged)"
	)


func _check_old_save() -> void:
	var older := Fixture.json(V2_FIXTURE)
	var model := SaveModel.from_dict(older, Fixture.json(WORLD_BALANCE), Fixture.defs())
	var economy := model.company.economy
	var start := _rule("start")
	_check.call(
		(
			model.ok
			and economy.standing.reputation(A) == start
			and economy.standing.reputation(B) == start
			and economy.standing.grudges.is_empty()
		),
		"a save from before C4 (fixtures/save/v2.json) loads at the starting name, no grudge"
	)
	economy.book.contract("ctr_1")["advance"] = PAY
	_check.call(
		economy.abandon("ctr_1", model.company, DAY) and not economy.standing.grudge(B).is_empty(),
		"the old save's accepted contract can be abandoned and grows a grudge"
	)


## Abandon one deal, save through JSON, reload, abandon a second: the same as without the reload.
func _check_reload_continue() -> void:
	var straight := _two_deals(false)
	var reloaded := _two_deals(true)
	_check.call(
		straight == reloaded and straight.has("standing"),
		"save, reload and continue gives the same standing as an uninterrupted run"
	)


func _two_deals(reload: bool) -> Dictionary:
	var company := _company()
	_take(company.economy, "ctr_1", A, PAY)
	_take(company.economy, "ctr_2", A, 0)
	company.economy.abandon("ctr_1", company, DAY)
	if reload:
		var saved := _through_json(company.economy.state())
		company.economy = Economy.restore(saved, Fixture.defs())
	company.economy.abandon("ctr_2", company, DAY + 1)
	return _through_json(company.economy.state())
