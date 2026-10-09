extends "res://tests/lib/runner.gd"
## Loop suite: the art direction slice's one pass of the core loop (SliceLoop,
## data/scenarios.json scn_slice_loop; docs/specs/art_direction_slice.md §2a). A scripted run
## from a seed reaches camp through every stage and replays to the same log; hiring adds the
## recruit; talking the lookout down leaves him out and the band shaken, failing or fighting
## brings him in; the aftermath choice only follows a band that yielded; a wounded company
## member comes home with one lasting injury. Seeded by design: Rng.from_seed only.
##   godot --headless --path . --script tests/run_loop_tests.gd

const SCENARIOS := "res://data/scenarios.json"
const SCENARIO_ID := "scn_slice_loop"
const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const MAX_TURNS := 400
const SEED_SEARCH := 64


func suite_name() -> String:
	return "Loop"


func run_checks() -> void:
	_check_full_run()
	_check_hire()
	_check_gate()
	_check_aftermath_needs_surrender()
	await process_frame


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _scenario() -> Dictionary:
	var all: Array = _json(SCENARIOS).get("scenarios", [])
	for entry: Variant in all:
		var scenario: Dictionary = entry if entry is Dictionary else {}
		if scenario.get("id") == SCENARIO_ID:
			return scenario
	return {}


func _loop(seed_value: int) -> SliceLoop:
	var loop := SliceLoop.new()
	loop.start(_scenario(), _json(BATTLE_DATA), Rng.from_seed(seed_value))
	return loop


## Plays one pass: hire, contract, the suggested speaker at the gate, both sides by the
## AI, the first fate on offer.
func _play(loop: SliceLoop) -> void:
	loop.advance()
	loop.hire(true)
	loop.accept_contract()
	loop.advance()
	loop.talk_down(loop.suggested_speaker())
	var rules: Dictionary = _json(BATTLE_DATA).get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	for _turn: int in MAX_TURNS:
		if loop.battle.is_over():
			break
		loop.battle.apply(BattleAi.choose(loop.battle, loop.battle.current(), sight))
	loop.end_battle()
	if loop.stage == SliceLoop.Stage.AFTERMATH:
		loop.choose_fate(str(loop.choices()[0]))
	loop.advance()
	loop.advance()


func _steps(loop: SliceLoop) -> Array:
	return loop.log.map(func(e: Dictionary) -> String: return str(e.get("step", "")))


func _check_full_run() -> void:
	var a := _loop(SEED)
	_play(a)
	var b := _loop(SEED)
	_play(b)
	var steps := _steps(a)
	var every := ["hired", "contract", "gate", "battle", "camp"].all(
		func(s: String) -> bool: return steps.has(s)
	)
	check(
		a.stage == SliceLoop.Stage.DONE and every and str(a.log) == str(b.log),
		"a seeded pass reaches camp through every stage and replays to the same log (%s)" % [steps]
	)


func _check_hire() -> void:
	var hired := _loop(SEED)
	hired.advance()
	hired.hire(true)
	var passed := _loop(SEED)
	passed.advance()
	passed.hire(false)
	check(
		hired.company.has(hired.recruit) and not passed.company.has(passed.recruit),
		"hiring adds the recruit to the company; passing does not"
	)


## Finds a seed whose talk-down roll succeeds and one where it fails.
func _check_gate() -> void:
	var lookouts := {}
	var shaken := {}
	for seed_value: int in SEED_SEARCH:
		var loop := _loop(seed_value)
		loop.advance()
		loop.hire(false)
		loop.accept_contract()
		loop.advance()
		var result := loop.talk_down(loop.suggested_speaker())
		var success: bool = result.get("success", false)
		lookouts[success] = _enemies(loop.battle)
		shaken[success] = loop.battle.morale(BattleUnit.ENEMY)
	var fought := _loop(SEED)
	fought.advance()
	fought.hire(false)
	fought.accept_contract()
	fought.advance()
	fought.fight()
	var both := lookouts.has(true) and lookouts.has(false)
	var with_lookout: int = lookouts.get(false, 0)
	var without: int = lookouts.get(true, 0)
	var calm: int = shaken.get(false, 0)
	var rattled: int = shaken.get(true, 0)
	check(
		(
			both
			and with_lookout == without + 1
			and rattled < calm
			and _enemies(fought.battle) == with_lookout
		),
		"talking the lookout down leaves him out and the band shaken; failing or fighting brings him in"
	)


func _enemies(battle: Battle) -> int:
	return (
		battle.units.filter(func(u: BattleUnit) -> bool: return u.side == BattleUnit.ENEMY).size()
	)


func _check_aftermath_needs_surrender() -> void:
	var loop := _loop(SEED)
	loop.advance()
	loop.hire(false)
	loop.accept_contract()
	loop.advance()
	loop.fight()
	for fighter: BattleUnit in loop.battle.units:
		if fighter.side == BattleUnit.ENEMY:
			fighter.down = true
	loop.battle.winner = BattleUnit.COMPANY
	loop.end_battle()
	var no_choice := loop.stage == SliceLoop.Stage.RETURN
	loop.battle.units[0].wounded = true
	loop.advance()
	var injured := _steps(loop).has("injury")
	check(
		no_choice and injured,
		"a band that dies fighting gives no aftermath choice; a wounded merc comes home with an injury"
	)
