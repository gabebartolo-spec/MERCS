extends RefCounted
## More whole-campaign routes for the replay checks (Phase 2 gate, structural evidence
## gap 3), beside campaign_kit.gd's one winning route: a lost fight, a patrol's toll paid, a
## second fight after a first, the campaign's end (the last merc cut down) and, since Phase 5
## C1, a contract taken as a job and played until it is judged ("job"). Each is the
## wiring the game's directors do with no scene, every roll on the one Rng of `seed_value`, so
## two runs of one seed (in one process, or in two) must end in the same save, byte for byte.
## run(route, seed) returns {"save": JSON text, "stages": {stage: bool}}.
## Used by tests/run_campaign_tests.gd and tools/audit/route_replay.gd.

const World := preload("res://tests/lib/world_fixture.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const JobKit := preload("res://tests/lib/job_kit.gd")
const ROUTES: Array[String] = ["loss", "toll", "second_fight", "wipe", "job"]
const OUT := 3
const NEAR := 3
const WALK_LIMIT := 40
const HOME_LIMIT := 60
const REST_DAYS := 2
## Who is left standing for a route that must lose: the two weakest of the six.
const LOSERS: Array[String] = ["merc_5", "merc_6"]
const LAST: Array[String] = ["merc_6"]


static func run(route: String, seed_value: int) -> Dictionary:
	if route == "job":
		return _job(seed_value)
	var played := _start(route, seed_value)
	var stages := {}
	match route:
		"loss":
			stages.merge(_meet(played, "ambush"))
			stages.merge(_fight(played))
			_go_home(played, stages)
		"toll":
			stages.merge(_meet(played, "patrol"))
			stages["toll_paid"] = played.world.pay_toll()
			_go_home(played, stages)
		"second_fight":
			stages.merge(_meet(played, "ambush"))
			stages.merge(_fight(played))
			stages["second_met"] = _meet(played, "ambush").get("met", false)
			stages["second_fought"] = _fight(played).get("fought", false)
			_go_home(played, stages)
		"wipe":
			stages.merge(_meet(played, "ambush"))
			stages.merge(_fight(played))
	var ended := played.company.is_wiped()
	stages["ended"] = ended
	var saved := SaveModel.to_dict(
		played.world, played.rng, played.company, played.wounds.state(), ended
	)
	return {"save": JSON.stringify(saved), "stages": stages}


## Phase 5 C1: the first contract on the board taken as the job it was posted as (its own
## type and deadline), played by tests/lib/job_kit.gd (every fight won) until it is judged.
static func _job(seed_value: int) -> Dictionary:
	var played := JobKit.begin(seed_value, "", true)
	JobKit.play(played, true)
	var verdict := "" if played.verdicts.is_empty() else str(played.verdicts[0].get("verdict"))
	var stages := {"judged": not verdict.is_empty(), "done": verdict == Jobs.DONE}
	var saved := SaveModel.to_dict(played.world, played.rng, played.company)
	return {"save": JSON.stringify(saved), "stages": stages}


static func _start(route: String, seed_value: int) -> Played:
	var kept: Array[String] = []
	var triage := "wound"
	if route == "loss":
		kept = LOSERS
	elif route == "wipe":
		kept = LAST
		triage = "dead"
	return Played.new(seed_value, triage, kept)


## One lone party of `type` placed near the band (out of the gate first, from the hub) and
## walked into.
static func _meet(played: Played, type: String) -> Dictionary:
	played.world.parties.clear()
	if played.world.at == RegionGen.HUB_ID:
		World.out_of_town(played.world, OUT)
	var party := World.lone_party(played.world, type, NEAR)
	if party != null:
		World.walk_toward(played.world, party.tile, WALK_LIMIT)
	return {"met": not played.world.encounter.is_empty()}


## The standing encounter fought to its end, the triage, the world told (loot on a win).
static func _fight(played: Played) -> Dictionary:
	var world := played.world
	if world.encounter.is_empty():
		return {"fought": false}
	played.wounds.day = world.day
	var kind := str(world.encounter.get("type", ""))
	var battle := RoadFight.build(
		played.wounds,
		world.pending_encounter(),
		Kit.scenario(),
		Fixture.json(Fixture.BATTLE),
		played.rng
	)
	MercPlay.play_out(battle, Fixture.rules(), Kit.MAX_ACTIONS)
	var result := EncounterBattle.result(battle)
	var events := played.wounds.resolve()
	var hook := world.result_hook
	world.result_hook = Callable()
	world.resolve_encounter(result)
	world.result_hook = hook
	hook.call(kind, result)
	return {"fought": true, "won": result.get("won", false), "triage": not events.is_empty()}


## Back to the hub and a rest or two, when anyone is left to walk.
static func _go_home(played: Played, stages: Dictionary) -> void:
	var world := played.world
	if played.company.is_wiped():
		return
	World.walk_toward(world, world.region.entrance(RegionGen.HUB_ID), HOME_LIMIT)
	for _day: int in REST_DAYS:
		world.rest()
	stages["paid"] = played.company.economy.pay_wages()


## One campaign's pieces on one Rng, the hub's hooks set; `kept` are the mercs left of the
## six (all when empty).
class Played:
	extends RefCounted
	var rng: Rng
	var world := WorldSim.new()
	var company: Company
	var wounds: CompanyWounds

	func _init(seed_value: int, triage: String, kept: Array[String]) -> void:
		rng = Rng.from_seed(seed_value)
		world.start(World.data(), rng)
		var lineups: Array = World.json(World.ENCOUNTERS).get("encounters", [])
		world.set_lineups(lineups)
		company = Company.start(Fixture.defs())
		for merc_id: String in company.fighting_order():
			if not kept.is_empty() and merc_id not in kept:
				company.bury(merc_id)
		if not kept.is_empty():
			company.appoint(kept[0])
		wounds = CompanyWounds.make(company, {}, rng, Kit.rules(triage), Kit.injury_defs())
		var site_ids: Array[String] = []
		for i: int in range(1, world.sites.size()):
			site_ids.append(world.sites[i].id)
		company.economy.refresh_board(world.day, site_ids, rng)
		world.day_hook = func(day: int) -> void:
			company.economy.on_day(company.roster.size(), day, site_ids, rng)
		world.result_hook = func(kind: String, result: Dictionary) -> void:
			if result.get("won", false) == true:
				company.economy.take_loot(kind, rng)
				company.economy.captives.take(world.day)
