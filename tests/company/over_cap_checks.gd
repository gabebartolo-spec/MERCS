extends RefCounted
## The company suite's over-the-cap save check (Phase 5 C7, review of #146 D1), run by
## tests/run_company_tests.gd. The cap fell from twelve to eight; a save made under the old cap
## (tests/fixtures/save/roster_over_cap.json: the starting six and recruit_1..6) must keep
## every living merc it holds. The cap only gates new hires: the company over it keeps all
## twelve, cannot take one more, and still fields six with the rest in reserve.
## Seeded by design: Rng.from_seed(424242).

const Fixture := preload("res://tests/lib/company_fixture.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const OVER_CAP := "res://tests/fixtures/save/roster_over_cap.json"
const WORLD_BALANCE := "res://data/balance/world.json"
const SEED := 424242
const SAVED_MERCS := 12
const FIELDED := 6
## The merc dropped from a copy of the save to try hiring him back past the cap.
const LEFT_OUT := "recruit_6"

var _check: Callable


func setup(check: Callable) -> void:
	_check = check


func run() -> void:
	var balance := Fixture.json(WORLD_BALANCE)
	var saved := Fixture.json(OVER_CAP)
	var model := SaveModel.from_dict(saved, balance, Fixture.defs())
	var company := model.company
	var kept := company.roster.size() if company != null else 0
	var cap := company.cap() if company != null else 0
	var fielded := 0
	if company != null:
		var made := CompanyWounds.make(
			company, {}, Rng.from_seed(SEED), Kit.rules(), Kit.injury_defs()
		)
		var cells := EncounterBattle.company_cells(Kit.scenario())
		fielded = made.units(cells, BattleUnit.COMPANY).size()
	_check.call(
		model.ok and kept == SAVED_MERCS and cap < SAVED_MERCS and fielded == FIELDED,
		(
			(
				"a save made under the old cap keeps all %d mercs (kept %d, cap %d) and fields %d "
				+ "with the rest in reserve (fielded %d)"
			)
			% [SAVED_MERCS, kept, cap, FIELDED, fielded]
		)
	)
	_check.call(_refuses_past_cap(saved, balance), "a company over the cap cannot hire one more")


## A copy of the save without LEFT_OUT loads with the other eleven, and adding him back is
## refused: the roster is over the cap.
func _refuses_past_cap(saved: Dictionary, balance: Dictionary) -> bool:
	var copy: Dictionary = saved.duplicate(true)
	var held: Dictionary = copy.get("company", {})
	var rows: Array = held.get("roster", [])
	var others: Array = []
	for row: Variant in rows:
		var entry: Dictionary = row if row is Dictionary else {}
		if entry.get("id") != LEFT_OUT:
			others.append(entry)
	held["roster"] = others
	var company := SaveModel.from_dict(copy, balance, Fixture.defs()).company
	if company == null or company.roster.size() != SAVED_MERCS - 1:
		return false
	return not company.add(LEFT_OUT) and company.member(LEFT_OUT) == null
