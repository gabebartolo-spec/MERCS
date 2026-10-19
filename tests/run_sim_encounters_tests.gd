extends "res://tests/lib/runner.gd"
## Sim encounters suite (Phase 2: WorldParty, PartyMoves, WorldSim encounters, EncounterBattle;
## data/encounters.json, data/balance/world.json "parties" and "encounters"). Parties walk the
## map: one that sees the band walks toward it, one that does not wanders near home, and one
## that loses sight goes back to wandering (the AI is not psychic). A party within a step of
## the band raises its encounter, which stops the band: steps and rests wait. A win loots and
## the party leaves the map for its return days, then comes back home; a loss costs supplies
## and the band falls back to the last site; a patrol's toll buys the way past (an ambush has
## none); an ambush gives the enemy the first turn, a patrol the company; the same seed and
## walk raise the same encounters; without the party the same walk meets nothing. Phase 5 C7:
## the line-ups stay inside the enemy caps and come by place and day (tests/world/lineup_checks.gd).
## Seeded by design: Rng.from_seed(424242) and 424243.
##   godot --headless --path . --script tests/run_sim_encounters_tests.gd

const Fixture := preload("res://tests/lib/world_fixture.gd")
const LineupChecks := preload("res://tests/world/lineup_checks.gd")
const SEED := 424242
const OTHER_SEED := 424243
const SCENARIOS := "res://data/scenarios.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const WORLD_STREAM := "world"
## How far from the band the lone test party starts (inside every type's sight).
const NEAR := 3
## Steps the band walks out of the hub's gate before a test places its party.
const OUT := 3
const WALK_LIMIT := 20
const SCRIPT_MOVES := 40


func suite_name() -> String:
	return "SimEncounters"


func run_checks() -> void:
	await _t("_test_contact_stops_the_band")
	await _t("_test_no_party_no_encounter")
	await _t("_test_win")
	await _t("_test_loss")
	await _t("_test_toll_paid")
	await _t("_test_toll_refused")
	await _t("_test_who_strikes_first")
	await _t("_test_encounters_replay")
	await _t("_test_sight")
	await _t("_test_lost_sight")
	await _t("_test_return")
	LineupChecks.new().run(check)
	await process_frame


func _knobs(block: String, kind: String) -> Dictionary:
	var found: Dictionary = Fixture.data().get(block, {})
	return found.get(kind, {})


## A world on the seed whose only party, of `kind`, started NEAR steps away and has been
## walked into: its encounter stands.
func _met(kind: String, seed_value: int = SEED) -> WorldSim:
	var world := _outside(seed_value)
	var party := Fixture.lone_party(world, kind, NEAR)
	if party != null:
		Fixture.walk_toward(world, party.tile, WALK_LIMIT)
	return world


## A world on the seed with the band OUT steps south of the hub's gate and no parties yet.
func _outside(seed_value: int) -> WorldSim:
	var world := Fixture.world(seed_value)
	world.parties.clear()
	Fixture.out_of_town(world, OUT)
	return world


func _day_units() -> int:
	var march: Dictionary = Fixture.data().get("march", {})
	return march.get("units_per_day", 0)


func _last_outcome(world: WorldSim) -> String:
	var entry: Dictionary = world.log.back()
	return str(entry.get("outcome", ""))


func _test_contact_stops_the_band() -> void:
	var world := _met("ambush")
	var pending := world.pending_encounter()
	var enemies: Array = pending.get("enemies", [])
	var party := world.party(str(pending.get("party", "")))
	var before := str(world.state())
	var refused := not world.step(Vector2i(0, 1)) and not world.step(Vector2i(0, -1))
	world.rest()
	check(
		(
			str(pending.get("type")) == "ambush"
			and party != null
			and TileRegion.gap(party.tile, world.band) <= 1
			and not enemies.is_empty()
			and refused
			and str(world.state()) == before
		),
		"a party within a step raises its %s; steps and rests wait" % pending.get("type")
	)


func _test_no_party_no_encounter() -> void:
	var met := _outside(SEED)
	var party := Fixture.lone_party(met, "ambush", NEAR)
	var alone := _outside(SEED)
	var target := party.tile if party != null else alone.band
	Fixture.walk_toward(met, target, WALK_LIMIT)
	Fixture.walk_toward(alone, target, WALK_LIMIT)
	check(
		(
			not met.encounter.is_empty()
			and alone.encounter.is_empty()
			and alone.band == target
			and met.region.picture() == alone.region.picture()
		),
		"without the party the same walk on the same map reaches %s with no encounter" % target
	)


func _test_win() -> void:
	var world := _met("ambush")
	var party := world.party(str(world.encounter.get("party", "")))
	var supplies := world.supplies
	var band := world.band
	var resolved := world.resolve_encounter({"won": true})
	var loot: int = _knobs("encounters", "ambush").get("win_supplies", 0)
	var away: int = _knobs("parties", "ambush").get("return_days", 0)
	check(
		(
			resolved
			and party != null
			and world.encounter.is_empty()
			and world.supplies == supplies + loot
			and world.band == band
			and not party.active(world.day)
			and party.away_until == world.day + away
			and _last_outcome(world) == "won"
		),
		(
			"a win loots %d supplies, the band stays and the bandits are gone for %d days"
			% [loot, away]
		)
	)


func _test_loss() -> void:
	var world := _met("ambush")
	var supplies := world.supplies
	var walked_off := world.band != world.region.entrance(RegionGen.HUB_ID)
	world.resolve_encounter({"won": false})
	var loss: int = _knobs("encounters", "ambush").get("loss_supplies", 0)
	check(
		(
			walked_off
			and world.band == world.region.entrance(RegionGen.HUB_ID)
			and world.at == RegionGen.HUB_ID
			and world.encounter.is_empty()
			and world.supplies == maxi(0, supplies - loss)
			and _last_outcome(world) == "lost"
			and not world.resolve_encounter({"won": true})
		),
		"a loss costs supplies and the band falls back to the hub's gate, and settles only once"
	)


func _test_toll_paid() -> void:
	var world := _met("patrol")
	var party := world.party(str(world.encounter.get("party", "")))
	var toll: int = _knobs("encounters", "patrol").get("toll_supplies", 0)
	var supplies := world.supplies
	var paid := world.pay_toll()
	check(
		(
			paid
			and toll > 0
			and party != null
			and not party.active(world.day)
			and world.encounter.is_empty()
			and world.supplies == supplies - toll
			and _last_outcome(world) == "paid"
		),
		"a patrol's toll buys the way past: %d supplies, and the patrol leaves the map" % toll
	)


func _test_toll_refused() -> void:
	var broke := _met("patrol")
	var ambush := _met("ambush")
	var toll: int = _knobs("encounters", "patrol").get("toll_supplies", 0)
	broke.supplies = toll - 1
	var broke_state := str(broke.state())
	var ambush_state := str(ambush.state())
	check(
		(
			not broke.encounter.is_empty()
			and not broke.pay_toll()
			and str(broke.state()) == broke_state
			and not ambush.pay_toll()
			and str(ambush.state()) == ambush_state
		),
		"the toll is refused when the supplies fall short, and for an ambush; nothing changes"
	)


func _test_who_strikes_first() -> void:
	var ambush := _met("ambush")
	var patrol := _met("patrol")
	var scenarios: Array = Fixture.json(SCENARIOS).get("scenarios", [{}])
	var scenario: Dictionary = scenarios[0]
	var company: Array = scenario.get("company", [])
	var battle_data := Fixture.json(BATTLE_DATA)
	var rng := Rng.from_seed(SEED)
	var ambushed := EncounterBattle.build(ambush.pending_encounter(), scenario, battle_data, rng)
	var met := EncounterBattle.build(patrol.pending_encounter(), scenario, battle_data, rng)
	var foes: Array = ambush.encounter.get("enemies", [])
	check(
		(
			not foes.is_empty()
			and ambushed.current().side == BattleUnit.ENEMY
			and met.current().side == BattleUnit.COMPANY
			and ambushed.units.size() == foes.size() + company.size()
		),
		"an ambush gives the enemy the first turn, a patrol the company; the line-up is the party's"
	)


## The seed's own parties, a long scripted walk: twice the same, and the map's stream unmoved.
func _test_encounters_replay() -> void:
	var a := Fixture.world(OTHER_SEED)
	var b := Fixture.world(OTHER_SEED)
	Fixture.scripted(a, 0, SCRIPT_MOVES)
	Fixture.scripted(b, 0, SCRIPT_MOVES)
	var rng := Rng.from_seed(OTHER_SEED)
	var walked := WorldSim.new()
	walked.start(Fixture.data(), rng)
	var laid_out := rng.stream(WORLD_STREAM).state
	Fixture.scripted(walked, 0, SCRIPT_MOVES)
	check(
		(
			str(a.state()) == str(b.state())
			and a.parties.size() > 1
			and rng.stream(WORLD_STREAM).state == laid_out
		),
		(
			"the same seed and walk move the same %d parties to the same place, off the world stream"
			% a.parties.size()
		)
	)


## The same party, the same time: the band within its sight draws it in; out of sight it
## wanders within its range of home and does not close in.
func _test_sight() -> void:
	var world := _outside(SEED)
	var party := Fixture.lone_party(world, "ambush", NEAR)
	var knobs: Dictionary = Fixture.data().get("parties", {})
	var units_per_day := _day_units()
	var start := party.tile
	PartyMoves.advance(party, units_per_day, world.band, world.region, knobs, Rng.from_seed(SEED))
	var seen := party.chasing and TileRegion.gap(party.tile, world.band) < NEAR
	var far := Vector2i(world.region.width, world.region.height) * -1
	var blind := WorldParty.make("party_1", "ambush", start)
	PartyMoves.advance(blind, units_per_day, far, world.region, knobs, Rng.from_seed(SEED))
	var wander: int = _knobs("parties", "ambush").get("wander_tiles", 0)
	check(
		seen and not blind.chasing and TileRegion.gap(blind.tile, start) <= wander,
		(
			"in sight the bandits close from %d to %d steps; out of sight they stay within %d of home"
			% [NEAR, TileRegion.gap(party.tile, world.band), wander]
		)
	)


## A party chasing the band loses it (the band out of its sight) and goes back to wandering,
## then heads home.
func _test_lost_sight() -> void:
	var world := _outside(SEED)
	var party := Fixture.lone_party(world, "ambush", NEAR)
	var knobs: Dictionary = Fixture.data().get("parties", {})
	var units_per_day := _day_units()
	var home := world.region.entrance(RegionGen.HUB_ID) + Vector2i(NEAR, NEAR)
	party.home = home
	party.chasing = true
	var gone := Vector2i(world.region.width, world.region.height) * -1
	var before := TileRegion.gap(party.tile, home)
	for _day: int in NEAR:
		PartyMoves.advance(party, units_per_day, gone, world.region, knobs, Rng.from_seed(SEED))
	var wander: int = _knobs("parties", "ambush").get("wander_tiles", 0)
	check(
		not party.chasing and TileRegion.gap(party.tile, home) <= maxi(wander, before),
		"a chasing party that loses sight of the band goes back to wandering near home"
	)


## A party the band dealt with is off the map until its return day: the band can stand on its
## home meanwhile; on the day it is back there, it meets the band.
func _test_return() -> void:
	var world := _met("patrol")
	var party := world.party(str(world.encounter.get("party", "")))
	world.pay_toll()
	var away := party.away_until
	var beside := party.home + Vector2i(1, 0)
	world.band = beside if world.region.passable(beside) else party.home
	var quiet := true
	while world.day < away - 1:
		world.rest()
		quiet = quiet and world.encounter.is_empty()
	world.rest()
	check(
		quiet and party.active(world.day) and not world.encounter.is_empty(),
		"a paid patrol stays off the map until day %d, then is back home and meets the band" % away
	)
