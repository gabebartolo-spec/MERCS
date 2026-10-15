extends "res://tests/lib/runner.gd"
## Perf suite: what the sim costs, reported, and gated only on a large regression. Four
## workloads, each a fixed number of iterations on pinned seeds: a 6v6 battle played to its
## end, 30 world days of ticks, a full scripted campaign (tests/lib/campaign_kit.gd), and the
## save and load of a mid-campaign state through JSON. Each prints "PERF <name>: <ms> ms
## (baseline <ms>, ceiling <ms>)". The checks that decide pass or fail are deterministic: the
## battle ends, the world reaches day 30, every campaign stage happens, the save reloads to
## the same save. The one clock check is a ceiling per workload: the larger of gate_factor
## times the baseline and baseline plus slack_ms, read from tests/perf_baseline.json, so a
## slower machine does not fail it and only a large slowdown does. The clock never decides
## whether the sim is correct. PERF_WRITE=1 rewrites the baseline from this run (run it three
## times on a quiet machine and keep the highest numbers).
## Seeded by design: battle seeds 424242 + n, world seed 424242, campaign seed 424310.
##   godot --headless --path . --script tests/run_perf_tests.gd

const Campaign := preload("res://tests/lib/campaign_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const ABOUT := (
	"Sim cost baseline for tests/run_perf_tests.gd: the highest of several local runs. "
	+ "Gate: ms <= max(gate_factor * baseline, baseline + slack_ms)."
)
const BASELINE := "res://tests/perf_baseline.json"
const SEED := 424242
const CAMPAIGN_SEED := 424310
const SIDE := 6
const GRID := Vector2i(10, 8)
const FIGHTS := 25
const MAX_ACTIONS := 600
const WORLD_DAYS := 30
const MOVES_PER_DAY := 6
const WORLD_RUNS := 5
const CAMPAIGNS := 3
const SAVE_ROUNDS := 20
const USEC_PER_MS := 1000.0

var _baseline: Dictionary = {}
var _measured: Dictionary = {}


func suite_name() -> String:
	return "Perf"


func run_checks() -> void:
	_baseline = _load_baseline()
	_battle()
	_world()
	var saved := _campaign()
	_save_load(saved)
	for name: String in _measured:
		_gate(name)
	if OS.get_environment("PERF_WRITE") == "1":
		_write_baseline()
	await process_frame


func _load_baseline() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	return parsed if parsed is Dictionary else {}


func _record(name: String, started: int, work: int) -> void:
	var ms := float(Time.get_ticks_usec() - started) / USEC_PER_MS
	_measured[name] = {"ms": ms, "work": work}


## SIDE v SIDE on a GRID, the enemy's plain line (BattleAi via MercPlay), FIGHTS seeds.
func _battle() -> void:
	var rules := Fixture.rules()
	var ended := 0
	var events := 0
	var started := Time.get_ticks_usec()
	for n: int in FIGHTS:
		var battle := _six_v_six(rules, SEED + n)
		events += MercPlay.play_out(battle, rules, MAX_ACTIONS).size()
		ended += 1 if battle.is_over() else 0
	_record("battle", started, events)
	check(
		ended == FIGHTS,
		"every 6v6 battle ends within %d actions (%d of %d)" % [MAX_ACTIONS, ended, FIGHTS]
	)
	check(events > 0, "the 6v6 battles logged events (%d)" % events)


func _six_v_six(rules: Dictionary, seed_value: int) -> Battle:
	var fighters: Array[BattleUnit] = []
	var mine := {"hp": 10, "attack": 2, "defense": 2, "damage": 5, "initiative": 3}
	var theirs := {"hp": 9, "attack": 2, "defense": 1, "damage": 4, "initiative": 2}
	for i: int in SIDE:
		var home := Vector2i(1, 1 + i)
		fighters.append(BattleUnit.make("c%d" % i, BattleUnit.COMPANY, home, mine))
		var away := Vector2i(GRID.x - 2, 1 + i)
		fighters.append(BattleUnit.make("b%d" % i, BattleUnit.ENEMY, away, theirs))
	fighters[0].is_leader = true
	var battle := Battle.new()
	battle.setup(rules, {"size": GRID, "blocked": {}}, fighters, Rng.from_seed(seed_value))
	return battle


## WORLD_DAYS days of the world: a step and a rest per day, WORLD_RUNS times over.
func _world() -> void:
	var days := 0
	var started := Time.get_ticks_usec()
	for n: int in WORLD_RUNS:
		var world := World.world(SEED + n)
		world.parties.clear()
		var move := 0
		while world.day < WORLD_DAYS and move < WORLD_DAYS * MOVES_PER_DAY:
			World.scripted(world, move, move + 1)
			move += 1
		days += world.day
	_record("world", started, days)
	check(
		days == WORLD_DAYS * WORLD_RUNS,
		"the world ran %d days in all, wanted %d" % [days, WORLD_DAYS * WORLD_RUNS]
	)


## The full scripted campaign, CAMPAIGNS times; the last save is returned for the save test.
func _campaign() -> String:
	var missing := 0
	var text := ""
	var started := Time.get_ticks_usec()
	for _n: int in CAMPAIGNS:
		var run := Campaign.run(CAMPAIGN_SEED)
		var stages: Dictionary = run["stages"]
		for stage: Variant in stages:
			missing += 0 if stages[stage] == true else 1
		text = str(run["save"])
	_record("campaign", started, text.length() * CAMPAIGNS)
	check(missing == 0, "the scripted campaign walked every stage (%d missing)" % missing)
	check(not text.is_empty(), "the campaign ends in a save (%d bytes)" % text.length())
	return text


## The mid-campaign save through JSON text, SAVE_ROUNDS times: read, rebuild, write again.
func _save_load(text: String) -> void:
	var same := true
	var started := Time.get_ticks_usec()
	for _n: int in SAVE_ROUNDS:
		var parsed: Variant = JSON.parse_string(text)
		var saved: Dictionary = parsed if parsed is Dictionary else {}
		var model := SaveModel.from_dict(saved, World.data(), Fixture.defs())
		var again := SaveModel.to_dict(model.world, model.rng, model.company, model.wounds)
		again = SaveModel.with_story(again, model.story)
		same = same and model.ok and _canon(JSON.stringify(again)) == _canon(text)
	_record("save_load", started, text.length() * SAVE_ROUNDS)
	check(same, "the mid-campaign save loads and writes back the same, %d times" % SAVE_ROUNDS)


## A save's text read and written again, so ints and floats of one number compare equal.
func _canon(text: String) -> String:
	return JSON.stringify(JSON.parse_string(text))


func _gate(name: String) -> void:
	var now: Dictionary = _measured[name]
	var ms: float = now["ms"]
	var scenarios: Dictionary = _baseline.get("scenarios", {})
	var entry: Dictionary = scenarios.get(name, {})
	var base: float = entry.get("ms", 0.0)
	var factor: float = _baseline.get("gate_factor", 3.0)
	var slack: float = _baseline.get("slack_ms", 250.0)
	var ceiling := maxf(base * factor, base + slack)
	print(
		(
			"PERF %s: %.1f ms, work %d (baseline %.1f, ceiling %.1f)"
			% [name, ms, now["work"], base, ceiling]
		)
	)
	check(base > 0.0, "tests/perf_baseline.json has a baseline for %s" % name)
	check(
		ms <= ceiling or OS.get_environment("PERF_WRITE") == "1",
		(
			"%s took %.1f ms, over its ceiling %.1f ms (%.0fx baseline %.1f)"
			% [name, ms, ceiling, factor, base]
		)
	)


func _write_baseline() -> void:
	var scenarios := {}
	for name: String in _measured:
		var now: Dictionary = _measured[name]
		var ms: float = now["ms"]
		scenarios[name] = {"ms": snappedf(ms, 0.1), "work": now["work"]}
	var out := {
		"about": ABOUT,
		"gate_factor": _baseline.get("gate_factor", 3.0),
		"slack_ms": _baseline.get("slack_ms", 250.0),
		"scenarios": scenarios
	}
	var file := FileAccess.open(BASELINE, FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t") + "\n")
	file.close()
