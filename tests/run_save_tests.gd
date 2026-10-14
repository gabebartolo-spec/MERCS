extends "res://tests/lib/runner.gd"
## Save suite (SaveModel, sim/core/save_model.gd): to_dict -> from_dict -> to_dict gives the
## same dictionary; a run continued from a reload matches the uninterrupted run, also when
## the save has been through JSON; a save missing optional keys reads with defaults and is
## ok; a save from a newer version is refused with an error code; a version 0 fixture
## (fixtures/save/v0.json) migrates to the current version and keeps its state.
## Seeded by design: Rng.from_seed(424242) only.
##   godot --headless --path . --script tests/run_save_tests.gd

const BALANCE := "res://data/balance/world.json"
const V0_FIXTURE := "res://tests/fixtures/save/v0.json"
const SEED := 424242
const STEPS := 6
const SPLIT := 3
## Stream positions JSON's doubles cannot hold: 2^53 + 1 and an odd value near 2^62.
const BIG_STATE := 9007199254740993
const HUGE_STATE := 4611686018427387905
const WORLD_STREAM := "world"


func suite_name() -> String:
	return "Save"


func run_checks() -> void:
	_check_round_trip()
	_check_continue_after_reload()
	_check_continue_through_json()
	_check_defaults()
	_check_newer_version_refused()
	_check_migrate_v0()
	_check_rng_exact_through_json()
	await process_frame


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _balance() -> Dictionary:
	return _json(BALANCE)


func _world(rng: Rng) -> WorldSim:
	var world := WorldSim.new()
	world.start(_balance(), rng)
	return world


## A scripted walk, steps `first` to `last` (exclusive) of one sequence: on even steps
## travel along the first road out, on odd steps rest. Splitting it keeps the sequence.
func _walk(world: WorldSim, first: int, last: int) -> void:
	for i: int in range(first, last):
		if i % 2 == 0:
			world.travel_to(world.destinations()[0])
		else:
			world.rest()


func _check_round_trip() -> void:
	var rng := Rng.from_seed(SEED)
	var world := _world(rng)
	_walk(world, 0, SPLIT)
	var first := SaveModel.to_dict(world, rng)
	var model := SaveModel.from_dict(first, _balance())
	var second := SaveModel.to_dict(model.world, model.rng)
	var version: int = first.get("version", 0)
	check(
		model.ok and model.error == "" and str(first) == str(second) and version == 1,
		"to_dict -> from_dict -> to_dict gives the same save back, version %d" % version
	)


func _check_continue_after_reload() -> void:
	var whole := _world(Rng.from_seed(SEED))
	_walk(whole, 0, STEPS)
	var paused_rng := Rng.from_seed(SEED)
	var paused := _world(paused_rng)
	_walk(paused, 0, SPLIT)
	var model := SaveModel.from_dict(SaveModel.to_dict(paused, paused_rng), _balance())
	_walk(model.world, SPLIT, STEPS)
	check(
		model.ok and str(model.world.state()) == str(whole.state()),
		"a run continued after reload matches the uninterrupted run"
	)


## The save as presentation will write it: through JSON, where every number comes back a float.
func _check_continue_through_json() -> void:
	var whole := _world(Rng.from_seed(SEED))
	_walk(whole, 0, STEPS)
	var paused_rng := Rng.from_seed(SEED)
	var paused := _world(paused_rng)
	_walk(paused, 0, SPLIT)
	var text := JSON.stringify(SaveModel.to_dict(paused, paused_rng))
	var parsed: Variant = JSON.parse_string(text)
	var reread: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(reread, _balance())
	_walk(model.world, SPLIT, STEPS)
	# JSON sorts a dictionary's keys, so both states are compared in that same canonical form.
	check(
		model.ok and JSON.stringify(model.world.state()) == JSON.stringify(whole.state()),
		"a run continued from a save that went through JSON matches the uninterrupted run"
	)


func _check_defaults() -> void:
	var model := SaveModel.from_dict({}, _balance())
	var fresh := _world(Rng.from_seed(model.rng.seed_value))
	var world_block: Dictionary = _balance().get("world", {})
	var balance_seed: int = world_block.get("seed", 0)
	check(
		(
			model.ok
			and model.error == ""
			and model.rng.seed_value == balance_seed
			and str(model.world.state()) == str(fresh.state())
			and model.world.at == RegionGen.HUB_ID
		),
		"a save missing every optional key reads as a fresh world on the balance seed, ok"
	)


func _check_newer_version_refused() -> void:
	var rng := Rng.from_seed(SEED)
	var save := SaveModel.to_dict(_world(rng), rng)
	save["version"] = SaveModel.VERSION + 1
	var model := SaveModel.from_dict(save, _balance())
	check(
		not model.ok and model.error == SaveModel.ERROR_TOO_NEW and model.world == null,
		(
			"a save from version %d is refused with '%s'"
			% [SaveModel.VERSION + 1, SaveModel.ERROR_TOO_NEW]
		)
	)


func _check_migrate_v0() -> void:
	var fixture := _json(V0_FIXTURE)
	var model := SaveModel.from_dict(fixture, _balance())
	var after := SaveModel.to_dict(model.world, model.rng) if model.ok else {}
	var saved_world: Dictionary = fixture.get("world", {})
	var expected_day: int = saved_world.get("day", 0)
	var expected_at: String = saved_world.get("at", "")
	var version_before: int = fixture.get("version", -1)
	var version_after: int = after.get("version", -1)
	check(
		(
			version_before == 0
			and model.ok
			and version_after == SaveModel.VERSION
			and model.world.day == expected_day
			and model.world.at == expected_at
			and model.world.sites.size() == 3
			and model.world.site("site_wild_1").days_to("site_hamlet_1") == 1
			and model.rng.seed_value == SEED
		),
		(
			"the version 0 fixture migrates to version %d and keeps its day, place, sites and seed"
			% SaveModel.VERSION
		)
	)


## A 64-bit stream position survives the save as JSON writes it (every number a double).
func _check_rng_exact_through_json() -> void:
	var exact := true
	for position: int in [BIG_STATE, HUGE_STATE]:
		var rng := Rng.restore({"seed": SEED, "streams": {WORLD_STREAM: position}})
		var world := _world(rng)
		# start() rolled on from `position`; the position to keep is where the stream is now.
		var streams_now: Dictionary = rng.state().get("streams", {})
		var position_now: int = streams_now.get(WORLD_STREAM, 0)
		var parsed: Variant = JSON.parse_string(JSON.stringify(SaveModel.to_dict(world, rng)))
		var reread: Dictionary = parsed if parsed is Dictionary else {}
		var model := SaveModel.from_dict(reread, _balance())
		var state_after: Dictionary = model.rng.state().get("streams", {})
		var kept: int = state_after.get(WORLD_STREAM, 0)
		var next_roll := rng.roll(WORLD_STREAM, 0, HUGE_STATE)
		exact = exact and model.ok and kept == position_now and absi(position_now) > BIG_STATE
		exact = exact and model.rng.roll(WORLD_STREAM, 0, HUGE_STATE) == next_roll
	check(
		exact,
		"a stream position above 2^53 comes back from JSON identical and rolls the same next number"
	)
