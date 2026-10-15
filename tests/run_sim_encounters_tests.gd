extends "res://tests/lib/runner.gd"
## Sim encounters suite (Phase 2 M2: WorldSim encounters, EncounterBattle; data/encounters.json,
## data/balance/world.json "encounters"). A day on a road may raise an encounter on its own
## Rng stream (the map never shifts), which stops the travel where it is; travel and rest
## wait; a win loots and the road goes on, a loss costs supplies and falls back to the site
## left; a patrol's toll buys the way past (an ambush has none); an ambush gives the enemy
## the first turn, a patrol the company; the same seed raises the same encounters; a chance
## of 0 raises none. The sim_world suite covers the map and the day tick.
## Seeded by design: Rng.from_seed(424243), the seed whose three hub roads each raise one.
##   godot --headless --path . --script tests/run_sim_encounters_tests.gd

const BALANCE := "res://data/balance/world.json"
const OTHER_SEED := 424243
const ENCOUNTERS := "res://data/encounters.json"
const SCENARIOS := "res://data/scenarios.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const WORLD_STREAM := "world"


func suite_name() -> String:
	return "SimEncounters"


func run_checks() -> void:
	_check_encounter_stops_travel()
	_check_encounters_off()
	_check_win()
	_check_loss()
	_check_toll_paid()
	_check_toll_refused()
	_check_who_strikes_first()
	_check_encounters_replay()
	await process_frame


func _balance() -> Dictionary:
	return _json(BALANCE)


func _company() -> Dictionary:
	return _balance().get("company", {})


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## A world on the seed with the encounter line-ups loaded and the day chance as given
## (-1: the balance's own).
func _road_world(seed_value: int, chance: int = -1) -> WorldSim:
	var balance := _balance()
	var block: Dictionary = balance.get("encounters", {})
	if chance >= 0:
		block["chance_per_day"] = chance
	var world := WorldSim.new()
	world.start(balance, Rng.from_seed(seed_value))
	var lineups: Array = _json(ENCOUNTERS).get("encounters", [])
	world.set_lineups(lineups)
	return world


## The world after walking the hub's road number `index` on the seed.
func _after_road(seed_value: int, index: int, chance: int = -1) -> WorldSim:
	var world := _road_world(seed_value, chance)
	world.travel_to(world.destinations()[index])
	return world


## A world standing at an encounter of the given type (from the seed's hub roads), or null.
func _standing(kind: String) -> WorldSim:
	for index: int in _road_world(OTHER_SEED).destinations().size():
		var world := _after_road(OTHER_SEED, index)
		if world.encounter.get("type") == kind:
			return world
	return null


func _last_outcome(world: WorldSim) -> String:
	var entry: Dictionary = world.log.back()
	return str(entry.get("outcome", ""))


func _knobs(kind: String) -> Dictionary:
	var block: Dictionary = _balance().get("encounters", {})
	var found: Variant = block.get(kind, {})
	return found if found is Dictionary else {}


func _check_encounter_stops_travel() -> void:
	var world := _after_road(OTHER_SEED, 0)
	var pending := world.pending_encounter()
	var to := str(pending.get("to", ""))
	var full_days := world.site(RegionGen.HUB_ID).days_to(to)
	var enemies: Array = pending.get("enemies", [])
	var before := str(world.state())
	var refused := not world.travel_to(world.destinations()[0])
	world.rest()
	var days_left: int = pending.get("days_left", -1)
	check(
		(
			not pending.is_empty()
			and world.at == RegionGen.HUB_ID
			and world.day == full_days - days_left
			and days_left >= 0
			and not enemies.is_empty()
			and refused
			and str(world.state()) == before
		),
		(
			"a day on the road raises a %s on day %d of %d: the company stays, travel and rest wait"
			% [pending.get("type"), world.day, full_days]
		)
	)


func _check_encounters_off() -> void:
	var on := _after_road(OTHER_SEED, 0)
	var off := _after_road(OTHER_SEED, 0, 0)
	var to := str(on.encounter.get("to", ""))
	var same_map := (
		JSON.stringify(on.state().get("sites")) == JSON.stringify(off.state().get("sites"))
	)
	check(
		(
			off.encounter.is_empty()
			and off.at == to
			and on.at != off.at
			and same_map
			and off.day == off.site(to).days_to(RegionGen.HUB_ID)
		),
		"with a chance of 0 the same road is walked to its end with no encounter, on the same map"
	)


func _check_win() -> void:
	var won := _standing("ambush")
	if won == null:
		check(false, "the seed has an ambush road (none found)")
		return
	var per_day: int = _company().get("supplies_per_day", 0)
	var from_supplies := won.supplies
	var days_left: int = won.encounter.get("days_left", 0)
	var to := str(won.encounter.get("to", ""))
	var day_hit := won.day
	var resolved := won.resolve_encounter({"won": true})
	var loot: int = _knobs("ambush").get("win_supplies", 0)
	check(
		(
			resolved
			and won.at == to
			and won.encounter.is_empty()
			and won.supplies == from_supplies + loot - days_left * per_day
			and won.day == day_hit + days_left
			and _last_outcome(won) == "won"
		),
		"a win loots supplies and the road goes on to %s" % to
	)


func _check_loss() -> void:
	var lost := _standing("ambush")
	if lost == null:
		check(false, "the seed has an ambush road (none found)")
		return
	var from_supplies := lost.supplies
	lost.resolve_encounter({"won": false})
	var loss: int = _knobs("ambush").get("loss_supplies", 0)
	check(
		(
			lost.at == RegionGen.HUB_ID
			and lost.encounter.is_empty()
			and lost.supplies == maxi(0, from_supplies - loss)
			and _last_outcome(lost) == "lost"
			and not lost.resolve_encounter({"won": true})
		),
		"a loss costs supplies and the company falls back to the hub, and settles only once"
	)


func _check_toll_paid() -> void:
	var patrol := _standing("patrol")
	if patrol == null:
		check(false, "the seed has a patrol road (none found)")
		return
	var toll: int = _knobs("patrol").get("toll_supplies", 0)
	var per_day: int = _company().get("supplies_per_day", 0)
	var before := patrol.supplies
	var days_left: int = patrol.encounter.get("days_left", 0)
	var to := str(patrol.encounter.get("to", ""))
	var paid := patrol.pay_toll()
	check(
		(
			paid
			and toll > 0
			and patrol.at == to
			and patrol.encounter.is_empty()
			and patrol.supplies == before - toll - days_left * per_day
			and _last_outcome(patrol) == "paid"
		),
		"a patrol's toll buys the way past: %d supplies, then the road goes on to %s" % [toll, to]
	)


func _check_toll_refused() -> void:
	var broke := _standing("patrol")
	var ambush := _standing("ambush")
	if broke == null or ambush == null:
		check(false, "the seed has a patrol road and an ambush road (none found)")
		return
	var toll: int = _knobs("patrol").get("toll_supplies", 0)
	broke.supplies = toll - 1
	var broke_state := str(broke.state())
	var ambush_state := str(ambush.state())
	check(
		(
			not broke.pay_toll()
			and str(broke.state()) == broke_state
			and not ambush.pay_toll()
			and str(ambush.state()) == ambush_state
		),
		"the toll is refused when the supplies fall short, and for an ambush; nothing changes"
	)


func _check_who_strikes_first() -> void:
	var ambush := _standing("ambush")
	var patrol := _standing("patrol")
	if ambush == null or patrol == null:
		check(false, "the seed has an ambush road and a patrol road (none found)")
		return
	var scenarios: Array = _json(SCENARIOS).get("scenarios", [{}])
	var scenario: Dictionary = scenarios[0]
	var company: Array = scenario.get("company", [])
	var battle_data := _json(BATTLE_DATA)
	var rng := Rng.from_seed(OTHER_SEED)
	var ambushed := EncounterBattle.build(ambush.pending_encounter(), scenario, battle_data, rng)
	var met := EncounterBattle.build(patrol.pending_encounter(), scenario, battle_data, rng)
	var foes: Array = ambush.encounter.get("enemies", [])
	check(
		(
			ambushed.current().side == BattleUnit.ENEMY
			and met.current().side == BattleUnit.COMPANY
			and ambushed.units.size() == foes.size() + company.size()
		),
		"an ambush gives the enemy the first turn, a patrol the company; the line-up is the encounter's"
	)


func _check_encounters_replay() -> void:
	var count := _road_world(OTHER_SEED).destinations().size()
	var same := true
	var raised := 0
	for index: int in count:
		var a := _after_road(OTHER_SEED, index)
		var b := _after_road(OTHER_SEED, index)
		same = same and str(a.state()) == str(b.state())
		raised += 0 if a.encounter.is_empty() else 1
	var rng := Rng.from_seed(OTHER_SEED)
	var walked := WorldSim.new()
	walked.start(_balance(), rng)
	var lineups: Array = _json(ENCOUNTERS).get("encounters", [])
	walked.set_lineups(lineups)
	var laid_out := rng.stream(WORLD_STREAM).state
	walked.travel_to(walked.destinations()[0])
	check(
		same and raised > 1 and rng.stream(WORLD_STREAM).state == laid_out,
		(
			"the same seed raises the same encounters on every road (%d of %d), off the world stream"
			% [raised, count]
		)
	)
