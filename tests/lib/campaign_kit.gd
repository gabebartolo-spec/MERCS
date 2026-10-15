extends RefCounted
## One scripted campaign on one seed, for the campaign suite: the walk out of the hub, a party
## met and fought with the whole company (the hit hook, the triage, the dead buried), the hub's
## hooks (wages falling due, the won fight's loot and prisoner), the hub's choices (wages,
## contract, hire, the prisoner), the walk home, a rest at the hub and the storylet it may
## offer. The same wiring the game's directors do, with no scene: every roll is on the one Rng
## of `seed_value`, so two runs of one seed must end in the same save. Returns
## {"save": the final save as JSON text, "stages": {stage: bool}, "company", "memory"}.

const World := preload("res://tests/lib/world_fixture.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const STORYLETS := "res://data/storylets.json"
const OUT := 3
const NEAR := 3
const WALK_LIMIT := 40
const HOME_LIMIT := 60
const REST_DAYS := 2
const SPARE := "release"
## The triage cut so that a merc put down dies: the campaign then always has a death to remember.
const FATE := "dead"


static func run(seed_value: int) -> Dictionary:
	var played := Played.new(seed_value)
	var stages := {}
	# The walk: out of the gate, a lone ambush near, walked into.
	played.world.parties.clear()
	World.out_of_town(played.world, OUT)
	var party := World.lone_party(played.world, "ambush", NEAR)
	if party != null:
		World.walk_toward(played.world, party.tile, WALK_LIMIT)
	stages["met"] = not played.world.encounter.is_empty()
	stages.merge(_fight(played))
	stages.merge(_hub(played))
	# Home and a rest at the hub: the storylet, if the dead left a memory for it.
	var world := played.world
	World.walk_toward(world, world.region.entrance(RegionGen.HUB_ID), HOME_LIMIT)
	for _day: int in REST_DAYS:
		if world.at == RegionGen.HUB_ID:
			world.rest()
	stages["paid"] = played.company.economy.pay_wages()
	stages["rested_at_hub"] = world.at == RegionGen.HUB_ID
	var state := StoryletState.new()
	stages["storylet"] = stages["rested_at_hub"] and _storylet(played, state)
	var saved := SaveModel.to_dict(world, played.rng, played.company, played.wounds.state())
	saved = SaveModel.with_story(saved, state.state())
	return {
		"save": JSON.stringify(saved),
		"stages": stages,
		"company": played.company,
		"memory": played.memory
	}


## The hub's choices after the fight: a contract, a hire, the waiting prisoner.
static func _hub(played: Played) -> Dictionary:
	var stages := {}
	var economy := played.company.economy
	if not economy.board.is_empty():
		var first: Dictionary = economy.board[0]
		stages["contract"] = economy.accept(str(first.get("id", "")))
	var offers := economy.offers()
	if not offers.is_empty():
		var recruit: Dictionary = offers[0]
		stages["hired"] = economy.hire(played.company, str(recruit.get("id", "")))
	if not economy.prisoner.is_empty():
		var day := played.world.day
		stages["prisoner"] = economy.decide_prisoner(played.company, SPARE, day)
		# The memory the story director writes from the hub's chronicle line.
		var key := Memory.KEY_FATE_PREFIX + SPARE
		played.memory.record(played.company.captain_id, key, {}, day)
	return stages


## A rest at the hub: the storylet on offer, if any, attempted by its first role.
static func _storylet(played: Played, state: StoryletState) -> bool:
	var book := StoryBook.new()
	book.company = played.company
	book.memory = played.memory
	book.state = state
	book.rng = played.rng
	book.load_defs(World.json(STORYLETS))
	var world := played.world
	var context := {"hook": "rest", "day": world.day, "site": world.at, "site_kind": "hub"}
	var offer := book.offer(context)
	if offer.is_empty():
		return false
	var attempts: Array = offer.get("attempts", [])
	var pick: Dictionary = attempts[0]
	book.choose(offer, str(pick.get("role", "")))
	return true


## The standing encounter fought through to its end, the way the overworld director does it.
static func _fight(played: Played) -> Dictionary:
	var world := played.world
	if world.encounter.is_empty():
		return {"fought": false, "triage": false, "won": false}
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
	return {"fought": true, "triage": not events.is_empty(), "won": result.get("won", false)}


## The pieces of one campaign: the world and the company on one Rng, the hub's hooks set.
class Played:
	extends RefCounted
	var rng: Rng
	var world := WorldSim.new()
	var company: Company
	var memory := Memory.new()
	var wounds: CompanyWounds

	func _init(seed_value: int) -> void:
		rng = Rng.from_seed(seed_value)
		world.start(World.data(), rng)
		var lineups: Array = World.json(World.ENCOUNTERS).get("encounters", [])
		world.set_lineups(lineups)
		company = Company.start(Fixture.defs())
		wounds = CompanyWounds.make(company, {}, rng, Kit.rules(FATE), Kit.injury_defs())
		wounds.adopt_memory(memory)
		var site_ids: Array[String] = []
		for i: int in range(1, world.sites.size()):
			site_ids.append(world.sites[i].id)
		company.economy.refresh_board(world.day, site_ids, rng)
		world.day_hook = func(day: int) -> void:
			company.economy.on_day(company.roster, day, site_ids, rng)
		world.result_hook = func(kind: String, result: Dictionary) -> void:
			if result.get("won", false) == true:
				company.economy.take_loot(kind, rng)
				if not EncounterBattle.taken(result).is_empty():
					company.economy.captives.take(world.day)
