extends RefCounted
## Shared by tests/world/grudge_party_checks.gd and the contract_hunters effect case (Phase 5
## C4, the hunter half): one company on one seed, every roll on one Rng, the hub's day hook set
## the way HubDirector sets it (the hunters sent before the day's wages), the map's own parties
## cleared. A deal is taken with an advance of `advance_pct` percent of its pay and walked away
## from (Economy.abandon); then a scripted play: fight whatever stands (every fight won, or
## every fight lost), else a step of the shortest walk toward the nearest hunter party on the
## map, else a rest. The play reads only the world (the script, not the hunters, knows where
## they are).

const World := preload("res://tests/lib/world_fixture.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const JobKit := preload("res://tests/lib/job_kit.gd")
const PERCENT := 100
const MOVES := 80


## A played company that took the first contract on the board with `advance_pct` percent of
## its pay up front and walked away from it on day 0; its hunters (if any) sent by a rest.
static func begin(seed_value: int, advance_pct: int) -> Played:
	var played := Played.new(seed_value)
	played.break_deal(advance_pct)
	played.world.rest()
	return played


## The play's save as the JSON text a save file holds.
static func save_text(played: Played) -> String:
	return JSON.stringify(SaveModel.to_dict(played.world, played.rng, played.company))


## A play loaded back from its save text (the hooks set again, as the hub does after a load).
static func load_back(played: Played) -> Played:
	var parsed: Variant = JSON.parse_string(save_text(played))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(saved, World.data(), Fixture.defs())
	var loaded := Played.new()
	loaded.rng = model.rng
	loaded.world = model.world
	loaded.world.set_lineups(Played.lineups())
	loaded.company = model.company
	loaded.site_ids = played.site_ids.duplicate()
	loaded.hook()
	return loaded


## Plays `moves` moves (or until a hunter fight was settled, when `until_settled`).
static func play(played: Played, won: bool, moves: int = MOVES, until_settled := true) -> void:
	for _move: int in moves:
		if until_settled and not played.settled.is_empty():
			return
		played.move(won)


## The pieces of one company's play, the hook set.
class Played:
	extends RefCounted
	var rng: Rng
	var world := WorldSim.new()
	var company: Company
	var memory := Memory.new()
	var hunters: GrudgeParties
	var site_ids: Array[String] = []
	## The broken deal's contract id and faction.
	var deal := ""
	var faction := ""
	## The hunter fights settled, in order; the hunter parties seen on the map; the fights met
	## with their enemy count ("hunters x3").
	var settled: Array[Dictionary] = []
	var seen: Array[String] = []
	var fights: Array[String] = []

	## A fresh start on the seed; none (reload) leaves the pieces to be set.
	func _init(seed_value: int = -1) -> void:
		if seed_value < 0:
			return
		rng = Rng.from_seed(seed_value)
		world.start(World.data(), rng)
		world.set_lineups(Played.lineups())
		world.parties.clear()
		company = Company.start(Fixture.defs())
		for i: int in range(1, world.sites.size()):
			site_ids.append(world.sites[i].id)
		company.economy.refresh_board(world.day, site_ids, rng)
		hook()

	static func lineups() -> Array:
		var found: Variant = World.json(World.ENCOUNTERS).get("encounters", [])
		return found if found is Array else []

	## The hunters and the hub's day hook on the world (after a reload too).
	func hook() -> void:
		hunters = GrudgeParties.make(world, company)
		hunters.memory = memory
		world.day_hook = func(day: int) -> void:
			settled.append_array(hunters.on_day(day))
			company.economy.on_day(company.roster, day, site_ids, rng)

	## The first contract on the board taken with `advance_pct` percent of its pay up front
	## and walked away from today.
	func break_deal(advance_pct: int) -> void:
		var row: Dictionary = company.economy.board[0]
		deal = str(row.get("id", ""))
		faction = str(row.get("faction", ""))
		company.economy.accept(deal)
		# Rounded up, so "half" of an odd pay is still half or more.
		row["advance"] = (Merc.whole(row.get("reward", 0)) * advance_pct + PERCENT - 1) / PERCENT
		company.economy.abandon(deal, company, world.day)

	## One move: a standing fight settled, else a step toward the nearest hunters, else a rest.
	func move(won: bool) -> void:
		note()
		if not world.encounter.is_empty():
			var enemies: Array = world.encounter.get("enemies", [])
			fights.append("%s x%d" % [world.encounter.get("type", ""), enemies.size()])
			world.resolve_encounter({"won": won})
			settled.append_array(hunters.on_result({"won": won}))
			note()
			return
		var target := _target()
		var step := JobKit.Played.first_step(world, target)
		if target == Jobs.NOWHERE or step == Vector2i.ZERO or not world.step(step):
			world.rest()
		note()

	## The hunter parties on the map now, added to `seen`.
	func note() -> void:
		for party: WorldParty in world.parties:
			if party.type == GrudgeParties.TYPE and party.id not in seen:
				seen.append(party.id)

	## The hunter parties on the map now (ids).
	func on_map() -> Array[String]:
		var ids: Array[String] = []
		for party: WorldParty in world.parties:
			if party.type == GrudgeParties.TYPE:
				ids.append(party.id)
		return ids

	func _target() -> Vector2i:
		for party: WorldParty in world.parties:
			if party.type == GrudgeParties.TYPE and party.active(world.day):
				return party.tile
		return Jobs.NOWHERE
