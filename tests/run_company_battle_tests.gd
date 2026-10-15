extends "res://tests/lib/runner.gd"
## Company battle suite (Phase 2 milestone 3: Merc.to_battle_unit, Company.battle_units,
## MercPlay). A merc becomes a BattleUnit from their data and their moves (abilities follow the
## moves learnt, a merc without "charge" cannot charge); the captain leads in a battle and the
## office moves with appoint; the orc runs at a foe in sight and strikes in the same turn; the
## Vampyr pays his blood price only to finish a foe and only while he can afford it.
## Seeded by design: nothing here rolls; the duels are set up on Rng.from_seed(424242) and only
## ask for a choice.
##   godot --headless --path . --script tests/run_company_battle_tests.gd

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242


func suite_name() -> String:
	return "CompanyBattle"


func run_checks() -> void:
	_check_battle_unit()
	_check_moves_gate_abilities()
	_check_captain_leads()
	_check_mercs_play_their_moves()
	_check_blood_price_kept_in_hand()
	await process_frame


## Variant equality as a bool, for values read out of untyped dictionaries.
func _is(found: Variant, expected: Variant) -> bool:
	return found == expected


func _company() -> Company:
	return Company.start(Fixture.defs())


## Which abilities a unit has, by the move that grants each: "charge", "blood_price" or "".
func _abilities(unit: BattleUnit) -> String:
	if unit.can_charge:
		return Battle.ACTION_CHARGE
	return Battle.ACTION_BLOOD_PRICE if unit.can_blood_price else ""


func _check_battle_unit() -> void:
	var company := _company()
	var fighters: Dictionary = Fixture.defs()["fighters"]
	var cell := Vector2i(3, 4)
	var orc := company.member("orc").to_battle_unit(BattleUnit.COMPANY, cell, false)
	var vampyr := company.member("vampyr").to_battle_unit(BattleUnit.COMPANY, cell, false)
	var other := company.member("merc_4").to_battle_unit(BattleUnit.COMPANY, cell, false)
	var orc_numbers: Dictionary = fighters["orc"]
	check(
		(
			orc.id == "orc"
			and orc.side == BattleUnit.COMPANY
			and orc.cell == cell
			and _is(orc.max_hp, orc_numbers["hp"])
			and orc.hp == orc.max_hp
			and _is(orc.attack, orc_numbers["attack"])
			and _is(orc.damage, orc_numbers["damage"])
			and _abilities(orc) == "charge"
			and _abilities(vampyr) == "blood_price"
			and _abilities(other) == ""
			and other.max_hp == company.member("merc_4").stat("hp")
		),
		(
			"a merc becomes a BattleUnit from their data: stats as the data say, abilities "
			+ "from the moves they have"
		)
	)


## Abilities follow the moves: without "charge" in the data the orc cannot charge.
func _check_moves_gate_abilities() -> void:
	var cell := Vector2i(3, 4)
	var defs := Fixture.defs()
	var list: Array = Fixture.sect(defs, "mercs").get("mercs", [])
	var orc_def: Dictionary = list[0]
	orc_def["moves_by_level"] = {"1": ["move", "attack"]}
	var tamed := Company.start(defs).member("orc").to_battle_unit(BattleUnit.COMPANY, cell, false)
	check(
		not tamed.can_charge,
		"an orc whose data holds no charge cannot charge, whatever the fighter data say"
	)


func _check_captain_leads() -> void:
	var company := _company()
	var ids: Array[String] = ["orc", "vampyr"]
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2)]
	var first := company.battle_units(ids, cells, BattleUnit.COMPANY)
	company.appoint("vampyr")
	var second := company.battle_units(ids, cells, BattleUnit.COMPANY)
	var unknown: Array[String] = ["orc", "nobody"]
	check(
		(
			first.size() == 2
			and first[0].is_leader
			and not first[1].is_leader
			and second[1].is_leader
			and not second[0].is_leader
			and company.battle_units(unknown, cells, BattleUnit.COMPANY).size() == 1
		),
		(
			"in a battle the captain leads (morale falls hardest when they go down); the "
			+ "office moves with appoint"
		)
	)


func _check_mercs_play_their_moves() -> void:
	var company := _company()
	var rules := Fixture.rules()
	var orc := company.member("orc").to_battle_unit(BattleUnit.COMPANY, Vector2i(1, 1), true)
	var foe := BattleUnit.make("foe", BattleUnit.ENEMY, Vector2i(5, 1), Fixture.fighter("bandit"))
	var far := _duel(orc, foe, rules)
	var plain_move := BattleAi.choose(far, orc, Fixture.rule("sight_cells"))
	var charge := MercPlay.choose(far, orc, rules)
	check(
		(
			_is(plain_move.get("type"), Battle.ACTION_MOVE)
			and _is(charge.get("type"), Battle.ACTION_CHARGE)
			and _is(charge.get("target"), "foe")
			and far.reachable(orc).has(charge.get("to"))
		),
		(
			"the orc runs at a foe in sight and strikes in the same turn where a plain "
			+ "fighter only closes in"
		)
	)


func _check_blood_price_kept_in_hand() -> void:
	var company := _company()
	var rules := Fixture.rules()
	var vampyr := company.member("vampyr").to_battle_unit(BattleUnit.COMPANY, Vector2i(1, 1), false)
	var foe := BattleUnit.make("foe", BattleUnit.ENEMY, Vector2i(2, 1), Fixture.fighter("bandit"))
	var duel := _duel(vampyr, foe, rules)
	var unhurt := MercPlay.choose(duel, vampyr, rules)
	foe.wounded = true
	var healthy := MercPlay.choose(duel, vampyr, rules)
	var price := Fixture.sect(Fixture.sect(rules, "moves"), BattleUnit.MOVE_BLOOD_PRICE)
	vampyr.hp = Merc.whole(price.get("hp_cost", 0)) * 2
	var weak := MercPlay.choose(duel, vampyr, rules)
	var blow := duel.kit(vampyr.id)[0]
	check(
		(
			_is(healthy.get("type"), Battle.ACTION_BLOOD_PRICE)
			and _is(weak.get("type"), blow)
			and _is(unhurt.get("type"), blow)
		),
		(
			"the Vampyr pays his blood price only on a foe he saw wounded (rule 6) and only "
			+ "while he can afford it"
		)
	)


func _duel(first: BattleUnit, second: BattleUnit, rules: Dictionary) -> Battle:
	var battle := Battle.new()
	var fighters: Array[BattleUnit] = [first, second]
	battle.setup(rules, {"size": Vector2i(12, 8)}, fighters, Rng.from_seed(SEED))
	return battle
