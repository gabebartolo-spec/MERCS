extends "res://tests/lib/runner.gd"
## Save suite (SaveModel, sim/core/save_model.gd): to_dict -> from_dict -> to_dict gives the
## same dictionary; a run continued from a reload matches the uninterrupted run, also when
## the save has been through JSON; a save missing optional keys reads with defaults and is
## ok; a save from a newer version is refused with an error code; a version 0 fixture
## (fixtures/save/v0.json) migrates to the current version and keeps its state; a version 1
## fixture (v1.json, before the company) does too and reads as the starting six, the orc
## captain; the company is saved and comes back equal.
## Encounters
## (Phase 2 M2, no version bump: one new key with a default): a party's standing encounter
## survives a save through JSON and the run continues exactly as the uninterrupted one; an
## older save without the key loads with no encounter. The walking map (no version bump:
## optional keys with defaults; the map itself is laid out again from the seed): the band's
## tile and the parties come back; a save without them starts at the hub's gate.
## Seeded by design: Rng.from_seed(424242) and 424243 only.
##   godot --headless --path . --script tests/run_save_tests.gd

const BALANCE := "res://data/balance/world.json"
const V0_FIXTURE := "res://tests/fixtures/save/v0.json"
const V1_FIXTURE := "res://tests/fixtures/save/v1.json"
const Fixture := preload("res://tests/lib/company_fixture.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const STEPS := 12
const SPLIT := 5
## The band's walk out of the hub, and how far off the lone party starts.
const OUT := 3
const NEAR := 3
const WALK_LIMIT := 20
## Stream positions JSON's doubles cannot hold: 2^53 + 1 and an odd value near 2^62.
const BIG_STATE := 9007199254740993
const HUGE_STATE := 4611686018427387905
const WORLD_STREAM := "world"
const ENCOUNTERS := "res://data/encounters.json"
const ROAD_SEED := 424243


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
	_check_company_round_trip()
	_check_migrate_v1()
	_check_encounter_through_json()
	_check_old_save_has_no_encounter()
	_check_band_and_parties()
	await process_frame


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The world data as the game hands it over: the balance with the hand-made stamps.
func _balance() -> Dictionary:
	return World.data()


func _world(rng: Rng) -> WorldSim:
	var world := WorldSim.new()
	world.start(_balance(), rng)
	return world


## The split-safe scripted run of steps and rests (tests/lib/world_fixture.gd).
func _walk(world: WorldSim, first: int, last: int) -> void:
	World.scripted(world, first, last)


func _check_round_trip() -> void:
	var rng := Rng.from_seed(SEED)
	var world := _world(rng)
	_walk(world, 0, SPLIT)
	var first := SaveModel.to_dict(world, rng)
	var model := SaveModel.from_dict(first, _balance())
	var second := SaveModel.to_dict(model.world, model.rng)
	var version: int = first.get("version", 0)
	check(
		(
			model.ok
			and model.error == ""
			and str(first) == str(second)
			and version == SaveModel.VERSION
		),
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
			and expected_at == "site_hamlet_1"
			and model.world.at == RegionGen.HUB_ID
			and model.world.band == model.world.region.entrance(RegionGen.HUB_ID)
			and model.world.sites.size() == _world(Rng.from_seed(SEED)).sites.size()
			and model.rng.seed_value == SEED
		),
		(
			(
				"the version 0 fixture migrates to version %d and keeps its day and seed; the map is"
				+ " laid out again from the seed and the band stands at the hub's gate"
			)
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


## The company rides in the save: written, read back (through JSON) and written again equal.
func _check_company_round_trip() -> void:
	var rng := Rng.from_seed(SEED)
	var world := _world(rng)
	var company := Company.start(Fixture.defs())
	company.appoint("vampyr")
	company.gain("merc_4", 12)
	var first := SaveModel.to_dict(world, rng, company)
	var parsed: Variant = JSON.parse_string(JSON.stringify(first))
	var reread: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(reread, _balance(), Fixture.defs())
	var second := SaveModel.to_dict(model.world, model.rng, model.company) if model.ok else {}
	check(
		(
			model.ok
			and JSON.stringify(first) == JSON.stringify(second)
			and model.company.captain_id == "vampyr"
		),
		"a save with a company round-trips through JSON: the Vampyr captain, experience kept"
	)


## A save from before the company: the world carries over, the company is the starting six.
func _check_migrate_v1() -> void:
	var fixture := _json(V1_FIXTURE)
	var model := SaveModel.from_dict(fixture, _balance(), Fixture.defs())
	var starting := Company.start(Fixture.defs())
	var version_before: int = fixture.get("version", -1)
	var after := SaveModel.to_dict(model.world, model.rng, model.company) if model.ok else {}
	var version_after: int = after.get("version", -1)
	check(
		(
			version_before == 1
			and model.ok
			and model.world.day == 2
			and model.company.captain_id == "orc"
			and JSON.stringify(model.company.state()) == JSON.stringify(starting.state())
			and version_after == SaveModel.VERSION
		),
		(
			(
				"the version 1 fixture (no company) migrates to version %d with the starting "
				+ "six, the orc captain"
			)
			% SaveModel.VERSION
		)
	)


## A world on ROAD_SEED, its line-ups loaded, walked into a lone ambush: its encounter stands.
func _met(rng: Rng) -> WorldSim:
	var world := _world(rng)
	var lineups: Array = _json(ENCOUNTERS).get("encounters", [])
	world.set_lineups(lineups)
	world.parties.clear()
	World.out_of_town(world, OUT)
	var party := World.lone_party(world, "ambush", NEAR)
	if party != null:
		World.walk_toward(world, party.tile, WALK_LIMIT)
	return world


## The run stopped by an encounter, saved as JSON text, read back and carried on (win, then
## the next road) matches the run that never stopped.
func _check_encounter_through_json() -> void:
	var whole := _met(Rng.from_seed(ROAD_SEED))
	var paused_rng := Rng.from_seed(ROAD_SEED)
	var paused := _met(paused_rng)
	var parsed: Variant = JSON.parse_string(JSON.stringify(SaveModel.to_dict(paused, paused_rng)))
	var reread: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(reread, _balance())
	var lineups: Array = _json(ENCOUNTERS).get("encounters", [])
	model.world.set_lineups(lineups)
	var standing := (
		model.ok
		and not model.world.encounter.is_empty()
		and JSON.stringify(model.world.state()) == JSON.stringify(whole.state())
	)
	for world: WorldSim in [whole, model.world]:
		world.resolve_encounter({"won": true})
		_walk(world, 0, SPLIT)
	check(
		standing and JSON.stringify(model.world.state()) == JSON.stringify(whole.state()),
		"a pending encounter survives a save through JSON and the run continues as the uninterrupted one"
	)


func _check_old_save_has_no_encounter() -> void:
	var from_v0 := SaveModel.from_dict(_json(V0_FIXTURE), _balance())
	var rng := Rng.from_seed(SEED)
	var current := SaveModel.to_dict(_world(rng), rng)
	var world_block: Dictionary = current.get("world", {})
	world_block.erase("encounter")
	var without_key := SaveModel.from_dict(current, _balance())
	check(
		(
			from_v0.ok
			and from_v0.world.encounter.is_empty()
			and without_key.ok
			and without_key.world.encounter.is_empty()
			and without_key.world.step(Vector2i(0, 1))
		),
		"a save from before encounters, and a v1 save without the key, load with no encounter"
	)


## The walking map's state rides in the save: the band's tile, the day's units walked and
## every party (through JSON); a save from before it (no band, no parties) puts the band at
## the hub's gate with the seed's own parties.
func _check_band_and_parties() -> void:
	var rng := Rng.from_seed(SEED)
	var world := _world(rng)
	_walk(world, 0, STEPS)
	var parsed: Variant = JSON.parse_string(JSON.stringify(SaveModel.to_dict(world, rng)))
	var reread: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(reread, _balance())
	var old := SaveModel.to_dict(world, rng)
	var old_world: Dictionary = old.get("world", {})
	for key: String in ["band", "march", "haven", "parties"]:
		old_world.erase(key)
	var from_old := SaveModel.from_dict(old, _balance())
	var fresh := _world(Rng.from_seed(SEED))
	var parties_back := JSON.stringify(model.world.state().get("parties"))
	check(
		(
			model.ok
			and model.world.band == world.band
			and world.band != fresh.band
			and parties_back == JSON.stringify(world.state().get("parties"))
			and from_old.ok
			and from_old.world.band == fresh.band
			and from_old.world.at == RegionGen.HUB_ID
			and (
				JSON.stringify(from_old.world.state().get("parties"))
				== JSON.stringify(fresh.state().get("parties"))
			)
		),
		"the band's tile and the parties come back from JSON; a save without them starts at the hub"
	)
