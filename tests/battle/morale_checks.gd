extends RefCounted
## The battle suite's Phase 4 morale checks (docs/plans/phase4_combat.md P2), run by
## tests/run_battle_tests.gd. The captain's fall (director ruling Q-D, "large morale fall"):
## each standing fighter of the side holds on his own resolve or breaks and stops acting; a
## side whose standing fighters have all broken gives way. Rout or surrender (ruling Q-C,
## "cornered or leader down"): a broken side's men run when they have a way out and surrender
## when pinned by a foe beside them, walled in, or leaderless; position decides. The morale
## thresholds are readable (Battle.standing) and the encounter's result names the prisoners.
## Seeded by design: every roll comes from Rng.from_seed(SEED); every blow is a sure hit.

const BATTLE_DATA := "res://data/balance/battle.json"
const TEXT := "res://data/text/en.json"
const SEED := 424242
const GRID := Vector2i(10, 8)
const SURE_HIT := 100
const STEADY := 9
const SHAKY := 1

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_captain_fall()
	_check_broken_no_plan()
	_check_all_broken()
	_check_rout_way_out()
	_check_pinned_and_free()
	_check_walled_in()
	_check_standing()


func _rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var rules: Variant = data.get("rules", {})
	return rules if rules is Dictionary else {}


func _words() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT))
	return parsed if parsed is Dictionary else {}


## Rules where one ally down breaks a side (morale starts just above its rout line).
func _brittle() -> Dictionary:
	var rules := _rules().duplicate(true)
	var sides: Dictionary = rules.get("morale_sides", {})
	var enemy: Dictionary = sides.get("enemy", {})
	var rout_below: int = enemy.get("rout_below", 0)
	var loss: int = rules.get("morale_loss_ally_down", 0)
	rules["morale_start"] = rout_below + loss - 1
	return rules


## The striker "c" at (0, 0), first to act with a sure kill, then the rest.
func _fight(rules: Dictionary, others: Array[BattleUnit], blocked: Dictionary = {}) -> Battle:
	var fighters: Array[BattleUnit] = [
		BattleUnit.make(
			"c",
			BattleUnit.COMPANY,
			Vector2i(0, 0),
			{"attack": SURE_HIT, "damage": SURE_HIT, "initiative": 2, "resolve": STEADY}
		)
	]
	fighters.append_array(others)
	var battle := Battle.new()
	battle.setup(rules, {"size": GRID, "blocked": blocked}, fighters, Rng.from_seed(SEED))
	return battle


func _enemy(unit_id: String, at: Vector2i, resolve: int, leads := false) -> BattleUnit:
	var fighter := BattleUnit.make(
		unit_id, BattleUnit.ENEMY, at, {"hp": 1, "resolve": resolve, "leader": leads}
	)
	return fighter


func _company(unit_id: String, at: Vector2i) -> BattleUnit:
	return BattleUnit.make(unit_id, BattleUnit.COMPANY, at, {"resolve": STEADY})


func _event(events: Array[Dictionary], kind: String) -> Dictionary:
	for event: Dictionary in events:
		if event.get("type") == kind:
			return event
	return {}


func _check_captain_fall() -> void:
	var others: Array[BattleUnit] = [
		_enemy("lead", Vector2i(1, 0), STEADY, true),
		_enemy("vet", Vector2i(6, 5), STEADY),
		_enemy("raw", Vector2i(7, 5), SHAKY),
	]
	var battle := _fight(_rules(), others)
	var events := battle.apply({"type": Battle.ACTION_ATTACK, "target": "lead"})
	var fall := _event(events, Battle.EVENT_CAPTAIN_FALL)
	var acting := battle.turn_order().map(func(u: BattleUnit) -> String: return u.id)
	_check.call(
		(
			fall.get("held") == ["vet"]
			and fall.get("broken") == ["raw"]
			and not battle.is_over()
			and "vet" in acting
			and not "raw" in acting
			and battle.standing(BattleUnit.ENEMY).get("broken") == ["raw"]
		),
		"the captain's fall: the steady veteran holds, the shaky one breaks and stops acting"
	)


## A man who broke at his captain's fall shows no plan, at once and in the next round, while
## the veteran who held plans again (D-066: the intent shown is what will happen).
func _check_broken_no_plan() -> void:
	var others: Array[BattleUnit] = [
		_enemy("lead", Vector2i(1, 0), STEADY, true),
		_enemy("vet", Vector2i(6, 5), STEADY),
		_enemy("raw", Vector2i(7, 5), SHAKY),
	]
	var battle := _fight(_rules(), others)
	battle.apply({"type": Battle.ACTION_ATTACK, "target": "lead"})
	var at_once := battle.intent("raw").is_empty()
	battle.apply({"type": Battle.ACTION_WAIT})
	var planned := battle.intents().map(func(plan: Dictionary) -> String: return plan["unit"])
	_check.call(
		(
			at_once
			and battle.intent("raw").is_empty()
			and not "raw" in planned
			and "vet" in planned
			and not battle.is_over()
		),
		"a man broken at his captain's fall shows no plan; the veteran who held plans on"
	)


func _check_all_broken() -> void:
	var others: Array[BattleUnit] = [
		_enemy("lead", Vector2i(1, 0), STEADY, true),
		_enemy("raw", Vector2i(7, 5), SHAKY),
	]
	var battle := _fight(_rules(), others)
	var events := battle.apply({"type": Battle.ACTION_ATTACK, "target": "lead"})
	var gave_up := _event(events, Battle.EVENT_SURRENDER)
	(
		_check
		. call(
			(
				battle.is_over()
				and (
					battle.morale(BattleUnit.ENEMY)
					>= battle.standing(BattleUnit.ENEMY)["rout_below"]
				)
				and gave_up.get("prisoners") == ["raw"]
				and gave_up.get("leader_down") == true
				and battle.winner == BattleUnit.COMPANY
			),
			"a side whose standing men all broke at the captain's fall gives way and, leaderless, surrenders"
		)
	)


func _check_rout_way_out() -> void:
	var others: Array[BattleUnit] = [
		_enemy("e1", Vector2i(1, 0), STEADY),
		_enemy("e2", Vector2i(5, 5), STEADY),
	]
	var battle := _fight(_brittle(), others)
	var events := battle.apply({"type": Battle.ACTION_ATTACK, "target": "e1"})
	var rout := _event(events, Battle.EVENT_ROUT)
	_check.call(
		(
			battle.is_over()
			and rout.get("fled") == ["e2"]
			and _event(events, Battle.EVENT_SURRENDER).is_empty()
			and battle.surrendered == -1
			and battle.prisoners.is_empty()
			and EncounterBattle.result(battle)["fled"] == ["e2"]
		),
		"a broken side with its leader up and a way out runs: no prisoners"
	)


## e2 has a company fighter beside him, e3 none: one surrenders, the other runs; with
## "pinned_by" 0 both run.
func _check_pinned_and_free() -> void:
	var outcomes: Array[Dictionary] = []
	for pinned_by: int in [1, 0]:
		var rules := _brittle()
		rules["surrender"] = {"pinned_by": pinned_by}
		var others: Array[BattleUnit] = [
			_enemy("e1", Vector2i(1, 0), STEADY),
			_enemy("e2", Vector2i(5, 5), STEADY),
			_enemy("e3", Vector2i(7, 2), STEADY),
			_company("c2", Vector2i(5, 4)),
		]
		var battle := _fight(rules, others)
		battle.apply({"type": Battle.ACTION_ATTACK, "target": "e1"})
		outcomes.append(EncounterBattle.result(battle))
	var pinned := outcomes[0]
	var loose := outcomes[1]
	(
		_check
		. call(
			(
				pinned["won"] == true
				and pinned["surrendered"] == true
				and pinned["prisoners"] == ["e2"]
				and pinned["fled"] == ["e3"]
				and pinned["captured"] == []
				and loose["prisoners"] == []
				and loose["fled"] == ["e2", "e3"]
			),
			"position decides: the man pinned by a foe surrenders, the free one runs (pinned_by 0: both run)"
		)
	)


func _check_walled_in() -> void:
	var blocked := {}
	for step: Vector2i in BattleUnit.FACINGS:
		blocked[Vector2i(5, 5) + step] = true
	var others: Array[BattleUnit] = [
		_enemy("e1", Vector2i(1, 0), STEADY),
		_enemy("e2", Vector2i(5, 5), STEADY),
	]
	var battle := _fight(_brittle(), others, blocked)
	battle.apply({"type": Battle.ACTION_ATTACK, "target": "e1"})
	_check.call(
		battle.is_over() and battle.prisoners == ["e2"] and battle.fled.is_empty(),
		"a broken man walled in with no walk to the field's edge surrenders"
	)


func _check_standing() -> void:
	var rules := _rules()
	var sides: Dictionary = rules.get("morale_sides", {})
	var enemy: Dictionary = sides.get("enemy", {})
	var others: Array[BattleUnit] = [
		_enemy("e1", Vector2i(1, 0), STEADY),
		_enemy("e2", Vector2i(5, 5), STEADY),
		_enemy("e3", Vector2i(7, 5), STEADY),
	]
	var battle := _fight(rules, others)
	var before := battle.standing(BattleUnit.ENEMY)
	battle.apply({"type": Battle.ACTION_ATTACK, "target": "e1"})
	var after := battle.standing(BattleUnit.ENEMY)
	_check.call(
		(
			before["state"] == BattleMorale.STATE_STEADY
			and before["shaken_below"] == enemy.get("shaken_below")
			and before["rout_below"] == enemy.get("rout_below")
			and before["morale"] == rules.get("morale_start")
			and after["state"] == BattleMorale.STATE_SHAKEN
			and after["morale"] == battle.morale(BattleUnit.ENEMY)
			and _words().has("battle.morale." + str(after["state"]))
		),
		"Battle.standing shows the side's morale, its two thresholds and its state word"
	)
