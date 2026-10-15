extends "res://tests/lib/runner.gd"
## Company suite (Phase 2 milestone 3: Merc, Company; data/mercs.json, data/balance/company.json).
## The cast in data: six mercs, the orc and the Vampyr sharing their numbers with the battle
## data, four flagged placeholders, only moves the battle sim knows; the starting company (six,
## the orc captain, cap twelve); state round-trips through JSON; appointing changes the saved
## state; the one experience bar raises levels and learns moves by level; the roster cap holds
## on every add; saves older than the company, odd saves and unknown ids read with defaults.
## Battle wiring is the company_battle suite.
## Seeded by design: nothing in the company rolls; the saves use Rng.from_seed(424242).
##   godot --headless --path . --script tests/run_company_tests.gd

const Fixture := preload("res://tests/lib/company_fixture.gd")
const FieldChecks := preload("res://tests/company/field_checks.gd")
const OverCapChecks := preload("res://tests/company/over_cap_checks.gd")
const V0_FIXTURE := "res://tests/fixtures/save/v0.json"
const WORLD_BALANCE := "res://data/balance/world.json"
const SEED := 424242
const CAP_FOR_TEST := 4
## The company cap (data/balance/company.json; director 2026-10-16, "Company cap 8", Phase 5 C7).
const ROSTER_CAP := 8
const STARTING_IDS: Array[String] = ["orc", "vampyr", "merc_3", "merc_4", "merc_5", "merc_6"]


func suite_name() -> String:
	return "Company"


func run_checks() -> void:
	_check_cast_in_data()
	_check_battle_numbers_one_source()
	_check_moves_known_to_the_battle()
	_check_starting_company()
	_check_state_through_json()
	_check_appoint()
	_check_appoint_saved()
	_check_experience_bar()
	_check_moves_by_level()
	_check_growth_by_level()
	_check_levels_in_data()
	_check_roster_cap()
	var field := FieldChecks.new()
	field.setup(Callable(self, "check"))
	field.run()
	var over_cap := OverCapChecks.new()
	over_cap.setup(Callable(self, "check"))
	over_cap.run()
	_check_older_save_defaults()
	_check_odd_saves()
	await process_frame


## Variant equality as a bool, for values read out of untyped dictionaries.
func _is(found: Variant, expected: Variant) -> bool:
	return found == expected


func _company() -> Company:
	return Company.start(Fixture.defs())


func _ids(company: Company) -> Array[String]:
	var ids: Array[String] = []
	for merc: Merc in company.roster:
		ids.append(merc.id)
	return ids


func _through_json(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _check_cast_in_data() -> void:
	var mercs: Array = Fixture.json(Fixture.MERCS).get("mercs", [])
	var ids: Array[String] = []
	var bad: Array[String] = []
	for entry: Variant in mercs:
		var def: Dictionary = entry
		ids.append(str(def.get("id")))
		var placeholder: bool = def.get("placeholder", false) == true
		var is_reference: bool = def.get("id") in ["orc", "vampyr"]
		if placeholder == is_reference or str(def.get("role", "")) == "":
			bad.append(str(def.get("id")))
		var slots: Dictionary = def.get("gear_slots", {})
		if (
			slots.size() != Merc.SLOTS.size()
			or slots.values().any(func(v: Variant) -> bool: return v != null)
		):
			bad.append(str(def.get("id")) + " slots")
		if placeholder and str(def.get("name", "")).begins_with("Unnamed"):
			bad.append(str(def.get("id")) + " name")
	check(
		ids == STARTING_IDS and bad.is_empty(),
		(
			"data/mercs.json holds the orc, the Vampyr and four flagged placeholders, empty "
			+ "slots: %s %s" % [ids, bad]
		)
	)


func _check_battle_numbers_one_source() -> void:
	var company := _company()
	var fighters := Fixture.sect(Fixture.defs(), "fighters")
	var drift: Array[String] = []
	for kind: String in ["orc", "vampyr"]:
		var numbers: Dictionary = fighters[kind]
		var merc := company.member(kind)
		for key: String in numbers:
			if merc.stats.get(key) != numbers[key]:
				drift.append("%s.%s" % [kind, key])
		if merc.stat("resolve") < 1:
			drift.append(kind + ".resolve")
	check(
		drift.is_empty(),
		(
			"the orc and the Vampyr read their battle numbers from data/balance/battle.json, "
			+ "plus resolve: %s" % [drift]
		)
	)


func _check_moves_known_to_the_battle() -> void:
	var unknown: Array[String] = []
	var mercs: Array = Fixture.json(Fixture.MERCS).get("mercs", [])
	for entry: Variant in mercs:
		var def: Dictionary = entry
		var by_level: Dictionary = def.get("moves_by_level", {})
		for level: String in by_level:
			for move: String in by_level[level]:
				if move not in Battle.ACTIONS:
					unknown.append("%s:%s" % [def.get("id"), move])
	check(
		unknown.is_empty(),
		"every move in data/mercs.json is one the battle sim has: %s" % [unknown]
	)


func _check_starting_company() -> void:
	var company := _company()
	check(
		(
			_ids(company) == STARTING_IDS
			and company.captain_id == "orc"
			and company.captain().display_name == "The Orc"
			and company.cap() == ROSTER_CAP
			and company.roster.all(
				func(merc: Merc) -> bool: return merc.level() == 1 and merc.xp == 0
			)
		),
		(
			"a new company is the starting six, the orc captain, cap 8, all at level 1 with "
			+ "no experience"
		)
	)


func _check_state_through_json() -> void:
	var company := _company()
	company.appoint("vampyr")
	company.gain("merc_3", 12)
	company.member("orc").gear["weapon"] = "wpn_test"
	var back := Company.restore(_through_json(company.state()), Fixture.defs())
	check(
		(
			JSON.stringify(back.state()) == JSON.stringify(company.state())
			and back.captain_id == "vampyr"
			and back.member("merc_3").level() == 2
			and _is(back.member("orc").gear["weapon"], "wpn_test")
		),
		"the company's state comes back from JSON equal: captain, experience, level and gear"
	)


func _check_appoint() -> void:
	var company := _company()
	var before := JSON.stringify(company.state())
	var refused := not company.appoint("nobody")
	var unchanged := JSON.stringify(company.state()) == before
	var done := company.appoint("vampyr")
	check(
		(
			refused
			and unchanged
			and done
			and company.captain_id == "vampyr"
			and JSON.stringify(company.state()) != before
		),
		(
			"appointing a roster member changes the saved state; an unknown id is refused "
			+ "and changes nothing"
		)
	)


## The captain survives the whole save: SaveModel -> JSON -> SaveModel.
func _check_appoint_saved() -> void:
	var balance := Fixture.json(WORLD_BALANCE)
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(balance, rng)
	var company := _company()
	var orc_save := _through_json(SaveModel.to_dict(world, rng, company))
	company.appoint("merc_5")
	var merc_save := _through_json(SaveModel.to_dict(world, rng, company))
	var orc_model := SaveModel.from_dict(orc_save, balance, Fixture.defs())
	var merc_model := SaveModel.from_dict(merc_save, balance, Fixture.defs())
	check(
		(
			orc_model.ok
			and merc_model.ok
			and orc_model.company.captain_id == "orc"
			and merc_model.company.captain_id == "merc_5"
			and JSON.stringify(orc_save.get("company")) != JSON.stringify(merc_save.get("company"))
		),
		"a different captain gives a different save, and each save reloads its own captain"
	)


func _check_experience_bar() -> void:
	var company := _company()
	var merc := company.member("orc")
	var xp: Dictionary = Fixture.json(Fixture.COMPANY).get("xp", {})
	var level_xp: Array = xp.get("level_xp", [])
	var two := Merc.whole(level_xp[1])
	var steps: Array[bool] = [merc.gain(two - 1), merc.gain(1), merc.gain(-50)]
	var bar_at_two: Dictionary = merc.bar()
	merc.gain(500)
	var top: Dictionary = merc.bar()
	var raised := company.gain_all(25)
	check(
		(
			_is(steps, [false, true, false])
			and merc.level() == 5
			and merc.level() == merc.max_level()
			and _is(bar_at_two.get("xp"), 0)
			and _is(bar_at_two.get("span"), Merc.whole(level_xp[2]) - two)
			and _is(top.get("span"), 0)
			and raised.size() == STARTING_IDS.size() - 1
			and company.member("vampyr").level() == 3
			and not company.gain("nobody", 5)
		),
		(
			"experience raises the level at the data's thresholds, never falls, stops at the "
			+ "top; gain_all reports who rose"
		)
	)


func _check_moves_by_level() -> void:
	var defs := Fixture.defs()
	var mercs: Dictionary = defs["mercs"]
	var list: Array = mercs["mercs"]
	var orc: Dictionary = list[0]
	orc["moves_by_level"] = {"1": ["move", "attack"], "2": ["charge"], "3": ["attack", "wait"]}
	var company := Company.start(defs)
	var merc := company.member("orc")
	var at_one := merc.moves()
	merc.gain(10)
	var at_two := merc.moves()
	merc.gain(15)
	check(
		(
			at_one == ["move", "attack"]
			and at_two == ["move", "attack", "charge"]
			and merc.moves() == ["move", "attack", "charge", "wait"]
		),
		(
			"moves are learnt by level, in order, once each: %s then %s then %s"
			% [at_one, at_two, merc.moves()]
		)
	)


func _check_growth_by_level() -> void:
	var merc := _company().member("orc")
	var base_hp := merc.stat("hp")
	var base_attack := merc.stat("attack")
	merc.gain(25)
	check(
		(
			merc.level() == 3
			and merc.stat("hp") == base_hp + 4
			and merc.stat("attack") == base_attack + 2
			and merc.stat("defense") == Merc.whole(merc.stats["defense"])
		),
		(
			"the orc at level 3 has two levels of growth (hp +4, attack +2) and no more: %d, %d"
			% [merc.stat("hp"), merc.stat("attack")]
		)
	)


func _check_levels_in_data() -> void:
	var company := _company()
	var odd: Array[String] = []
	for merc: Merc in company.roster:
		var gains := merc.next_level()
		var growth: Dictionary = gains.get("growth", {})
		if gains.is_empty() or growth.is_empty():
			odd.append(merc.id + ":no growth")
		var at_one := merc.moves().size()
		merc.gain(25)
		if merc.moves().size() <= at_one:
			odd.append(merc.id + ":no new move by level 3")
	var orc := company.member("orc")
	var vampyr := company.member("vampyr")
	check(
		(
			odd.is_empty()
			and not _is(orc.next_level().get("growth"), vampyr.next_level().get("growth"))
		),
		(
			"every merc grows and learns a move by level 3 from data, the orc and the Vampyr differently: %s"
			% [odd]
		)
	)


func _check_roster_cap() -> void:
	var defs := Fixture.defs()
	Fixture.sect(Fixture.sect(defs, "company"), "roster")["cap"] = CAP_FOR_TEST
	var company := Company.start(defs)
	var full := company.roster.size() == CAP_FOR_TEST
	var refused := (
		not company.add("merc_6") and not company.add("orc") and not company.add("nobody")
	)
	var roomy := Company.start(Fixture.defs())
	roomy.roster.remove_at(roomy.roster.size() - 1)
	check(
		(
			full
			and refused
			and company.roster.size() == CAP_FOR_TEST
			and roomy.add("merc_6")
			and not roomy.add("merc_6")
		),
		(
			"the roster stops at the cap; a duplicate or unknown id is refused; a free place "
			+ "takes the merc"
		)
	)


func _check_older_save_defaults() -> void:
	var balance := Fixture.json(WORLD_BALANCE)
	var v0 := Fixture.json(V0_FIXTURE)
	var from_v0 := SaveModel.from_dict(v0, balance, Fixture.defs())
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(balance, rng)
	var v1 := _through_json(SaveModel.to_dict(world, rng))
	v1["version"] = 1
	var from_v1 := SaveModel.from_dict(v1, balance, Fixture.defs())
	var starting := JSON.stringify(_company().state())
	check(
		(
			from_v0.ok
			and from_v1.ok
			and not v1.has("company")
			and JSON.stringify(from_v0.company.state()) == starting
			and JSON.stringify(from_v1.company.state()) == starting
			and from_v1.company.captain_id == "orc"
			and SaveModel.from_dict(v1, balance).company == null
		),
		(
			"a save older than the company (v0, v1) reads as the starting six with the orc "
			+ "captain; no data, no company"
		)
	)


func _check_odd_saves() -> void:
	var defs := Fixture.defs()
	var odd := {
		"captain": "ghost",
		"roster":
		[{"id": "vampyr", "xp": 30.0}, {"id": "ghost", "xp": 5}, {"id": "vampyr", "xp": 99}, 7],
	}
	var company := Company.restore(odd, defs)
	var empty := Company.restore({"captain": "orc", "roster": []}, defs)
	check(
		(
			_ids(company) == ["vampyr"]
			and company.captain_id == "vampyr"
			and company.member("vampyr").xp == 30
			and company.member("vampyr").level() == 3
			and JSON.stringify(empty.state()) == JSON.stringify(_company().state())
		),
		(
			"a saved roster drops unknown and repeated ids and non-rows, a captain off the "
			+ "roster is replaced, an empty roster restarts"
		)
	)
