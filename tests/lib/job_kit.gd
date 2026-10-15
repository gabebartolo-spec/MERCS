extends RefCounted
## Shared by tests/world/job_checks.gd, the contract_jobs effect case and route_kit's "job"
## route (Phase 5 C1): one company on one seed, every roll on one Rng, the hub's hooks set
## the way HubDirector sets them (the jobs judged before the day's wages and expiry), the
## first contract on the board made a job of a given type (its deadline set wide so the walk
## fits), taken or left, and a scripted play: fight whatever stands (every fight won, or
## every fight lost), else a step of the shortest walk toward the job's party (not an
## escort's charge), else toward the contract's site, else rest there. Seeded by the caller;
## the play reads only the world.

const World := preload("res://tests/lib/world_fixture.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
## The deadline the fixture contract is given: far enough for a walk, a hold and its fight.
const WIDE := 40
const MOVES := 120


## A played company: `taken` decides whether the first contract is taken as a job; an empty
## `job_type` keeps the job and the deadline it was posted with.
static func begin(seed_value: int, job_type: String, taken: bool) -> Played:
	var played := Played.new(seed_value)
	var row: Dictionary = played.company.economy.board[0]
	if not job_type.is_empty():
		row["job"] = job_type
		row["deadline"] = WIDE
	played.contract = row.duplicate()
	if taken:
		played.jobs.take(str(row.get("id", "")))
	played.note()
	return played


## The play's save as the JSON text a save file holds.
static func save_text(played: Played) -> String:
	return JSON.stringify(SaveModel.to_dict(played.world, played.rng, played.company))


## A play loaded back from its save text (the world, the Rng and the company; the jobs and
## the hooks set again, as the hub does after a load), to continue where it was saved.
static func load_back(played: Played) -> Played:
	var parsed: Variant = JSON.parse_string(save_text(played))
	var saved: Dictionary = parsed if parsed is Dictionary else {}
	var model := SaveModel.from_dict(saved, World.data(), Fixture.defs())
	var loaded := Played.new()
	loaded.rng = model.rng
	loaded.world = model.world
	var lineups: Array = World.json(World.ENCOUNTERS).get("encounters", [])
	loaded.world.set_lineups(lineups)
	loaded.company = model.company
	loaded.site_ids = played.site_ids.duplicate()
	loaded.contract = played.contract.duplicate()
	var knobs: Dictionary = World.data().get("jobs", {})
	loaded.hook(Jobs.make(loaded.world, loaded.company, knobs))
	return loaded


## Plays up to `moves` moves, or until the job is judged; every fight ends `won`.
static func play(played: Played, won: bool, moves: int = MOVES) -> void:
	for _move: int in moves:
		if not played.verdicts.is_empty():
			return
		played.move(won)


## The pieces of one company's play, the hooks set.
class Played:
	extends RefCounted
	var rng: Rng
	var world := WorldSim.new()
	var company: Company
	var memory := Memory.new()
	var jobs: Jobs
	var site_ids: Array[String] = []
	## The first contract as posted (before it was taken).
	var contract: Dictionary = {}
	## What the jobs judged, in order; the party types that stood on the map; the fights met.
	var verdicts: Array[Dictionary] = []
	var seen: Array[String] = []
	var fights: Array[String] = []

	## A fresh start on the seed; none (reload) leaves the pieces to be set.
	func _init(seed_value: int = -1) -> void:
		if seed_value < 0:
			return
		rng = Rng.from_seed(seed_value)
		world.start(World.data(), rng)
		var lineups: Array = World.json(World.ENCOUNTERS).get("encounters", [])
		world.set_lineups(lineups)
		world.parties.clear()
		company = Company.start(Fixture.defs())
		for i: int in range(1, world.sites.size()):
			site_ids.append(world.sites[i].id)
		company.economy.refresh_board(world.day, site_ids, rng)
		var knobs: Dictionary = World.data().get("jobs", {})
		hook(Jobs.make(world, company, knobs))

	## Sets the jobs and the hub's hooks on the world (after a reload too).
	func hook(made: Jobs) -> void:
		jobs = made
		jobs.memory = memory
		world.day_hook = func(day: int) -> void:
			verdicts.append_array(jobs.on_day(day))
			company.economy.on_day(company.roster, day, site_ids, rng)

	## One move: a standing fight settled, else a step toward the job, else a rest.
	func move(won: bool) -> void:
		if not world.encounter.is_empty():
			fights.append(str(world.encounter.get("type", "")))
			world.resolve_encounter({"won": won})
			verdicts.append_array(jobs.on_result({"won": won}))
			note()
			return
		var target := _target()
		var step := Played.first_step(world, target)
		if world.band == target or step == Vector2i.ZERO or not world.step(step):
			world.rest()
		note()

	## The first step of a shortest walk (breadth first, the fixed step order) from the band
	## to `target`; ZERO when the band is there or cannot reach it.
	static func first_step(on: WorldSim, target: Vector2i) -> Vector2i:
		var first := {on.band: Vector2i.ZERO}
		var queue: Array[Vector2i] = [on.band]
		while not queue.is_empty():
			var at: Vector2i = queue.pop_front()
			if at == target:
				return first[at]
			for step: Vector2i in TileRegion.STEPS:
				var next := at + step
				if not first.has(next) and on.region.passable(next):
					first[next] = step if at == on.band else first[at]
					queue.append(next)
		return Vector2i.ZERO

	## The party types on the map now, added to `seen`.
	func note() -> void:
		for party: WorldParty in world.parties:
			if party.type not in seen:
				seen.append(party.type)

	func _target() -> Vector2i:
		var party := world.party(str(_row().get("job_party", "")))
		if party != null and party.type != "charge" and party.active(world.day):
			return party.tile
		return world.region.entrance(str(contract.get("site", "")))

	func _row() -> Dictionary:
		return company.economy.book.contract(str(contract.get("id", "")))
