extends "res://tests/lib/runner.gd"
## Economy-in-the-company suite (Phase 2 milestone 6: Economy held by Company, Merc gear
## bonuses, SaveModel, the WorldSim hooks). A generic item in a slot changes the merc's battle
## numbers; hiring spends coin, obeys the roster cap and never offers a recruit twice; each
## prisoner choice moves the company's state and leaves a line the captain remembers; the
## economy survives a save through JSON and a save from before it reads with the new-game
## values; the world's day and result hooks reach it. Wages, contracts and loot are the
## economy suite; the screen is the hub suite.
## Seeded by design: every roll comes from Rng.from_seed(424242).
##   godot --headless --path . --script tests/run_economy_company_tests.gd

const Fixture := preload("res://tests/lib/company_fixture.gd")
const V1_FIXTURE := "res://tests/fixtures/save/v1.json"
const WORLD_BALANCE := "res://data/balance/world.json"
const SEED := 424242
const SITES: Array[String] = ["site_1", "site_2", "site_3"]
const ITEM := "wpn_iron_blade"
const ARMOUR := "arm_padded_coat"


func suite_name() -> String:
	return "EconomyCompany"


func run_checks() -> void:
	_check_equip()
	_check_hiring()
	_check_prisoner_choices()
	_check_prisoner_refusals()
	_check_save_round_trip()
	_check_older_save()
	_check_world_hooks()
	await process_frame


func _company() -> Company:
	return Company.start(Fixture.defs())


func _day(company: Company, day: int) -> void:
	company.economy.on_day(company.roster.size(), day, SITES, Rng.from_seed(SEED))


func _through_json(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _is(found: Variant, expected: Variant) -> bool:
	return found == expected


func _check_equip() -> void:
	var company := _company()
	var economy := company.economy
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var ids: Array[String] = ["orc"]
	var base := company.battle_units(ids, cells, BattleUnit.COMPANY)[0]
	var base_stats: Dictionary = company.member("orc").stats
	check(not economy.equip(company, "orc", ITEM), "gear not in the pack cannot be put on")
	economy.inventory.append(ITEM)
	check(not economy.equip(company, "nobody", ITEM), "gear cannot be put on a stranger")
	check(economy.equip(company, "orc", ITEM), "gear in the pack goes on a merc")
	var armed := company.battle_units(ids, cells, BattleUnit.COMPANY)[0]
	check(
		armed.damage == base.damage + 1 and armed.max_hp == base.max_hp,
		"a blade adds its damage to the battle numbers: %d against %d" % [armed.damage, base.damage]
	)
	check(
		company.member("orc").stat("damage") == Merc.whole(base_stats["damage"]) + 1,
		"the merc's stat reads the gear's bonus"
	)
	check(economy.inventory.is_empty(), "gear on a merc leaves the pack")
	economy.inventory.append("wpn_hunting_spear")
	economy.equip(company, "orc", "wpn_hunting_spear")
	check(
		(
			_is(economy.inventory, [ITEM])
			and _is(company.member("orc").gear["weapon"], "wpn_hunting_spear")
		),
		"swapping returns the old gear to the pack"
	)
	economy.inventory.append(ARMOUR)
	economy.equip(company, "orc", ARMOUR)
	var worn := company.battle_units(ids, cells, BattleUnit.COMPANY)[0]
	check(worn.defense == base.defense + 1, "armour adds defense; the slots stack")
	var restored := Company.restore(_through_json(company.state()), Fixture.defs())
	check(
		_is(restored.member("orc").gear, company.member("orc").gear),
		"gear on a merc survives the save"
	)


func _check_hiring() -> void:
	var company := _company()
	var preview := company.preview("recruit_2")
	check(
		preview != null and preview.placeholder and company.member("recruit_2") == null,
		"a recruit can be inspected without joining"
	)
	var economy := company.economy
	var offered := economy.offers()
	var offers := Merc.whole(Fixture.json(Fixture.ECONOMY)["recruits"]["offers"])
	check(offered.size() == offers, "the hub offers the data's recruits, got %d" % offered.size())
	var id := str(offered[0]["id"])
	var purse := economy.purse
	check(economy.hire(company, id), "a recruit is hired for coin")
	check(
		company.member(id) != null and economy.purse == purse - economy.hire_cost(),
		"the hire joins the roster and the cost leaves the purse"
	)
	check(
		not economy.hire(company, id) and str(economy.offers()[0]["id"]) != id,
		"a hired recruit is not offered or hired again"
	)
	company.roster.erase(company.member(id))
	check(
		economy.offers().all(func(def: Dictionary) -> bool: return def["id"] != id),
		"a recruit who left the roster is never offered again"
	)
	economy.purse = economy.hire_cost() - 1
	check(
		not economy.hire(company, str(economy.offers()[0]["id"])),
		"a hire the purse cannot cover fails"
	)
	economy.purse = economy.hire_cost() * company.cap()
	while not economy.offers().is_empty() and economy.hire(company, str(economy.offers()[0]["id"])):
		pass
	check(
		company.roster.size() <= company.cap(),
		"hiring stops at the roster cap, roster %d" % company.roster.size()
	)


func _prisoner_company() -> Company:
	var company := _company()
	company.economy.take_prisoner(3)
	return company


func _check_prisoner_choices() -> void:
	var start := _company()
	var after := {}
	for choice: String in Economy.CHOICES:
		var company := _prisoner_company()
		check(company.economy.decide_prisoner(company, choice, 4), "%s is decided" % choice)
		var economy := company.economy
		after[choice] = Vector3i(company.roster.size(), economy.purse, economy.morale)
		var note: Dictionary = economy.chronicle[0]
		check(
			(
				economy.prisoner.is_empty()
				and str(note["merc"]) == company.captain_id
				and str(note["key"]) == "prisoner." + choice
				and Merc.whole(note["day"]) == 4
			),
			"%s leaves the captain a remembered line and no prisoner waiting" % choice
		)
	var base := Vector3i(start.roster.size(), start.economy.purse, start.economy.morale)
	var released: Vector3i = after["release"]
	var ransomed: Vector3i = after["ransom"]
	var executed: Vector3i = after["execute"]
	var recruited: Vector3i = after["recruit"]
	check(
		released.z > base.z and released.x == base.x and released.y == base.y,
		"releasing lifts morale and changes no coin or roster: %s" % [released]
	)
	check(
		ransomed.y > base.y and ransomed.z < released.z,
		"ransoming brings coin and less morale than releasing"
	)
	check(executed.z < base.z, "executing costs the company its morale")
	check(
		recruited.x == base.x + 1 and recruited.y == base.y,
		"recruiting adds a placeholder to the roster for free"
	)
	var distinct := {}
	for choice: String in after:
		distinct[str(after[choice])] = true
	check(distinct.size() == Economy.CHOICES.size(), "the four choices leave four company states")


func _check_prisoner_refusals() -> void:
	var company := _company()
	check(not company.economy.decide_prisoner(company, "release", 1), "no prisoner, no decision")
	company.economy.take_prisoner(1)
	check(not company.economy.decide_prisoner(company, "hang", 1), "an unknown choice is refused")
	company.economy.purse = company.economy.hire_cost() * company.cap()
	while company.roster.size() < company.cap():
		company.economy.hire(company, str(company.economy.offers()[0]["id"]))
	check(
		(
			not company.economy.decide_prisoner(company, "recruit", 1)
			and not company.economy.prisoner.is_empty()
		),
		"a full roster cannot take the prisoner: the choice stays open"
	)
	var next := _company()
	next.economy.take_prisoner(1)
	next.economy.take_prisoner(9)
	check(
		Merc.whole(next.economy.prisoner["day"]) == 1,
		"a second prisoner does not replace the one waiting"
	)


func _check_save_round_trip() -> void:
	var company := _company()
	var economy := company.economy
	_day(company, 1)
	economy.take_loot("patrol", Rng.from_seed(SEED))
	economy.accept(str(economy.board[0]["id"]))
	economy.take_prisoner(1)
	economy.hire(company, "recruit_1")
	var saved := _through_json(company.state())
	var back := Company.restore(saved, Fixture.defs())
	check(
		_is(_through_json(back.state()), saved),
		"the company, with its economy, round-trips equal through JSON"
	)
	check(back.member("recruit_1") != null, "a hired recruit is on the restored roster")
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(Fixture.json(WORLD_BALANCE), rng)
	var model := SaveModel.from_dict(
		_through_json(SaveModel.to_dict(world, rng, company)),
		Fixture.json(WORLD_BALANCE),
		Fixture.defs()
	)
	check(
		model.ok and _is(_through_json(model.company.state()), saved),
		"the economy rides in the save model and comes back"
	)


func _check_older_save() -> void:
	var older := Fixture.json(V1_FIXTURE)
	var model := SaveModel.from_dict(older, Fixture.json(WORLD_BALANCE), Fixture.defs())
	var fresh := _company().economy
	check(
		model.ok and model.company.economy.purse == fresh.purse,
		"a save from before the economy reads with the new-game purse"
	)
	check(
		model.company.economy.morale == fresh.morale and model.company.economy.board.is_empty(),
		"and the new-game morale, an empty board and an empty pack"
	)
	var odd_economy := {"purse": "lots", "inventory": ["wpn_nope", ITEM], "morale": 900}
	var odd := Company.restore({"roster": [], "economy": odd_economy}, Fixture.defs())
	var held := Company.restore({"roster": [{"id": "orc"}], "economy": odd_economy}, Fixture.defs())
	check(
		(
			_is(held.economy.inventory, [ITEM])
			and held.economy.morale == Merc.whole(Fixture.json(Fixture.ECONOMY)["morale"]["max"])
			and held.economy.purse == fresh.purse
		),
		"odd economy values fall back: unknown gear dropped, morale at the ceiling, new purse"
	)
	check(odd.economy.purse == fresh.purse, "an economy beside an empty roster starts the new game")


func _check_world_hooks() -> void:
	var company := _company()
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(Fixture.json(WORLD_BALANCE), rng)
	var days: Array[int] = []
	var results: Array[String] = []
	world.day_hook = func(day: int) -> void: days.append(day)
	world.result_hook = func(kind: String, _result: Dictionary) -> void: results.append(kind)
	world.rest()
	world.rest()
	check(days == [1, 2], "the world calls the day hook once after each day, got %s" % [days])
	world.encounter = {"type": "ambush", "from": world.at, "to": world.at, "days_left": 0}
	world.resolve_encounter({"won": true})
	check(results == ["ambush"], "the world calls the result hook once a fight is applied")
	world.day_hook = func(day: int) -> void: _day(company, day)
	world.rest()
	check(company.economy.owed > 0, "a day of the world reaches the economy through the hook")
