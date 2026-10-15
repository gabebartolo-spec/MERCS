extends RefCounted
## The company suite's field-command checks (Phase 4 P4, run by tests/run_company_tests.gd): the
## captain may sit out a fight and a field sergeant leads (FieldCommand), the cost comes from
## data/balance/company.json "deploy", and the choice is saved only while it stands. Nothing
## here rolls.

const Fixture := preload("res://tests/lib/company_fixture.gd")

var _check: Callable


func setup(check: Callable) -> void:
	_check = check


func run() -> void:
	preview_and_sergeant()
	sitting_out()
	saved()


func _company() -> Company:
	return Company.start(Fixture.defs())


func _through_json(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _defs_with_cap(cap_value: int) -> Dictionary:
	var defs := Fixture.defs().duplicate(true)
	var balance: Dictionary = defs["company"]
	var roster: Dictionary = balance["roster"]
	roster["cap"] = cap_value
	return defs


## P4: the captain may sit out; the most experienced of the rest leads, the captain is not
## fielded, the cost is previewed from data, the choice is refused when nobody can stand in.
func preview_and_sergeant() -> void:
	var company := _company()
	company.member("merc_4").gain(3)
	var dip := Merc.whole(company.deploy.get("captain_out_morale_dip", 0))
	var in_cost: Dictionary = FieldCommand.preview(company, false)
	var out_cost: Dictionary = FieldCommand.preview(company, true)
	var in_dip: int = in_cost["dip"]
	var out_dip: int = out_cost["dip"]
	var out_leader: String = out_cost["leader"]
	(
		_check
		. call(
			(
				FieldCommand.sergeant(company) == "merc_4"
				and FieldCommand.leader_id(company) == "orc"
				and in_dip == 0
				and out_dip == dip
				and dip > 0
				and out_leader == "merc_4"
				and company.fighting_order()[0] == "orc"
			),
			"the sergeant is the most experienced of the rest; leading costs no morale, sitting out the dip"
		)
	)


## Sitting out: the captain is not fielded, the sergeant is the one leader, a lone captain cannot
## sit out, and the choice is spent with the fight.
func sitting_out() -> void:
	var company := _company()
	company.member("merc_4").gain(3)
	_check.call(FieldCommand.set_out(company, true), "the captain may sit out")
	var ids := company.fighting_order()
	var cells: Array[Vector2i] = []
	for i: int in ids.size():
		cells.append(Vector2i(i, 0))
	var units := company.battle_units(ids, cells, BattleUnit.COMPANY)
	var leaders: Array[String] = []
	for unit: BattleUnit in units:
		if unit.is_leader:
			leaders.append(unit.id)
	_check.call(
		(
			"orc" not in ids
			and ids[0] == "merc_4"
			and ids.size() == company.roster.size() - 1
			and leaders == ["merc_4"]
		),
		"sitting out: the captain is not fielded and the sergeant is the one leader"
	)
	var alone := Company.start(_defs_with_cap(1))
	_check.call(
		not FieldCommand.can_sit_out(alone) and not FieldCommand.set_out(alone, true),
		"a captain with nobody to stand in cannot sit out"
	)
	FieldCommand.finish(company)
	_check.call(
		not company.captain_out and company.fighting_order()[0] == "orc",
		"the choice is spent with the fight: the captain leads the next"
	)


## The choice is saved only while it stands, an older save reads as the captain leading, and a
## sitting out that cannot be honoured (nobody to stand in) reads as leading.
func saved() -> void:
	var company := _company()
	_check.call(
		not company.state().has("captain_out"), "a captain who leads adds nothing to the save"
	)
	FieldCommand.set_out(company, true)
	var back := Company.restore(_through_json(company.state()), Fixture.defs())
	var older := Company.restore(
		_through_json({"captain": "orc", "roster": [], "fallen": []}), Fixture.defs()
	)
	var lone := _through_json(company.state())
	lone["roster"] = [lone["roster"][0]]
	var kept := Company.restore(lone, Fixture.defs())
	(
		_check
		. call(
			(
				back.captain_out
				and back.state() == company.state()
				and not older.captain_out
				and not kept.captain_out
			),
			"sitting out round-trips through JSON; an older save and an impossible choice read as leading"
		)
	)
