class_name Jobs
extends RefCounted
## A contract is a job (Phase 5 C1, docs/plans/phase5_contracts.md; win and lose as the
## director decided, Q-9). Each posted contract carries a job type (data/jobs.json, drawn by
## ContractBook); taking it puts the job's party on the map, and the job is judged done or
## failed from what the world shows:
## - clear_bandits: a camp near the site; beating it is done. A lost fight leaves it standing.
## - escort: the charge walks with the band; standing at the site with him at a day's end is
##   done; losing any fight on the way fails.
## - hold: standing at the site `hold_days` days in a row brings raiders; beating them is
##   done, losing to them fails. Leaving the site before they come starts the count again.
## - hunt: the quarry near the site; beating him is done. A lost fight lets him walk on.
## Every job fails once its deadline has passed. Done pays the contract (Economy.complete);
## either way the job's party leaves the map and every merc who fights for the company
## (Company.fighting_order) remembers the job ("memory.job.<type>.<done|failed>").
## The parties are ordinary WorldParty records (they see, chase and raise their encounter
## like any other: not psychic); their walking numbers are in data/balance/world.json
## "parties", the placement and hold numbers in its "jobs". Placement rolls on the Rng "jobs"
## stream. The job's progress rides on the accepted contract (ContractBook), so it is saved
## with the board; nothing here is saved.

const STREAM := "jobs"
## A job party's id: this prefix and the contract's id.
const PREFIX := "job_"
const CLEAR := "clear_bandits"
const ESCORT := "escort"
const HOLD := "hold"
const HUNT := "hunt"
const DONE := "done"
const FAILED := "failed"
const MEMORY_PREFIX := "memory.job."
const NOWHERE := Vector2i(-1, -1)

var world: WorldSim = null
var company: Company = null
## Where a judged job is remembered; null: nobody remembers it (a bare sim check).
var memory: Memory = null

var _knobs := {}


## The jobs of `owner`'s contracts on the world `on`; knobs: data/balance/world.json "jobs".
static func make(on: WorldSim, owner: Company, knobs: Dictionary) -> Jobs:
	var jobs := Jobs.new()
	jobs.world = on
	jobs.company = owner
	jobs._knobs = knobs
	return jobs


## Where a job's party stands when it is put on the map: an escort's charge beside the band;
## a hold's raiders raid_min_tiles to raid_max_tiles from the site's entrance; a camp or a
## quarry near_min_tiles to near_max_tiles from it. Its id, "" when no free tile was found
## in place_tries rolls. contract: the board record plus "party" (its WorldParty type).
static func place(on: WorldSim, contract: Dictionary, knobs: Dictionary, rng: Rng) -> String:
	var party_type := str(contract.get("party", ""))
	var site := on.site(str(contract.get("site", "")))
	if party_type.is_empty() or site == null:
		return ""
	var job := str(contract.get("job", ""))
	var at := on.band
	if job != ESCORT:
		var key := "raid" if job == HOLD else "near"
		var span := Vector3i(
			_num(knobs, key + "_min_tiles"),
			_num(knobs, key + "_max_tiles"),
			_num(knobs, "place_tries")
		)
		at = _roll_tile(on, on.region.entrance(site.id), span, rng)
	if at == NOWHERE:
		return ""
	var id := PREFIX + str(contract.get("id", ""))
	on.parties.append(WorldParty.make(id, party_type, at))
	return id


## Takes a posted contract on: accepted, and its job's party put on the map (a hold's comes
## later). False (and no change) when Economy.accept refuses it.
func take(contract_id: String) -> bool:
	var economy := company.economy
	if not economy.accept(contract_id):
		return false
	var row := economy.book.contract(contract_id)
	var job := str(row.get("job", ""))
	if job == HOLD:
		row["held"] = 0
	elif not job.is_empty():
		_put(row)
	return true


## A day has passed (call before Economy.on_day, which would let the contract lapse
## unjudged): every taken job judged by its deadline, an escort by where the band stands, a
## hold's days counted. The verdicts, {"id", "job", "verdict", "day"}.
func on_day(day: int) -> Array[Dictionary]:
	var verdicts: Array[Dictionary] = []
	for row: Dictionary in _taken():
		var verdict := _judge_day(row, day)
		if not verdict.is_empty():
			verdicts.append(_settle(row, verdict))
	_clear_strays()
	return verdicts


## A fight's result was applied (WorldSim.resolve_encounter; {"won": bool}): a job whose
## party was just fought is judged, and a lost fight fails an escort. The verdicts.
func on_result(result: Dictionary) -> Array[Dictionary]:
	var won: bool = result.get("won", false) == true
	var verdicts: Array[Dictionary] = []
	for row: Dictionary in _taken():
		var verdict := _judge_fight(row, won)
		if not verdict.is_empty():
			verdicts.append(_settle(row, verdict))
	return verdicts


func _judge_day(row: Dictionary, day: int) -> String:
	if _num(row, "deadline") < day:
		return FAILED
	var site := str(row.get("site", ""))
	var job := str(row.get("job", ""))
	if job == ESCORT:
		var charge := world.party(str(row.get("job_party", "")))
		if charge != null and world.at == site and PartyMoves.contact(charge, world.band):
			return DONE
	elif job == HOLD and str(row.get("job_party", "")).is_empty():
		row["held"] = _num(row, "held") + 1 if world.at == site else 0
		if _num(row, "held") >= _num(_knobs, "hold_days"):
			_put(row)
	return ""


## The settled party is the one whose away day moved (WorldSim sends the party it fought
## away, won or lost); the day last seen is kept on the contract.
func _judge_fight(row: Dictionary, won: bool) -> String:
	var job := str(row.get("job", ""))
	if job == ESCORT:
		return "" if won else FAILED
	var party := world.party(str(row.get("job_party", "")))
	if party == null or party.away_until == _num(row, "away"):
		return ""
	row["away"] = party.away_until
	if won:
		return DONE
	return FAILED if job == HOLD else ""


## The job's party on the map, its id kept on the contract.
func _put(row: Dictionary) -> void:
	var contract := row.duplicate()
	var template := company.economy.book.job_template(str(row.get("job", "")))
	contract["party"] = str(template.get("party", ""))
	row["job_party"] = world.place_job(contract)
	row["away"] = 0


func _settle(row: Dictionary, verdict: String) -> Dictionary:
	var id := str(row.get("id", ""))
	var job := str(row.get("job", ""))
	var party := world.party(str(row.get("job_party", "")))
	if party != null:
		world.parties.erase(party)
	if verdict == DONE:
		_pay(id)
	else:
		company.economy.book.drop(id)
		_dent(str(row.get("faction", "")))
	if memory != null:
		memory.on_choice(company.fighting_order(), MEMORY_PREFIX + job + "." + verdict, world.day)
	return {"id": id, "job": job, "verdict": verdict, "day": world.day}


## Done: the contract pays, and the mercs who fought it are named for their share (Phase 5
## C3, #135: Economy.complete(id, fought)). Guarded until C3 merges; whichever of the two
## merges second makes it a plain call.
func _pay(id: String) -> void:
	var economy := company.economy
	if economy.get_method_argument_count("complete") > 1:
		economy.callv("complete", [id, company.fighting_order()])
	else:
		economy.complete(id)


## A job failed honestly (deadline or a lost fight): the employer's name for the company is
## dented (Phase 5 C4, Economy.standing.failed). Guarded until C4 (#134) merges; whichever
## of the two merges second makes it a plain call.
func _dent(faction_id: String) -> void:
	var found: Variant = company.economy.get("standing")
	if found is Object:
		var standing: Object = found
		if standing.has_method("failed"):
			standing.call("failed", faction_id)


## The accepted contracts that are jobs, in board order (a copy: settling one changes the board).
func _taken() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in company.economy.board:
		if row.get("accepted") == true and not str(row.get("job", "")).is_empty():
			rows.append(row)
	return rows


## A job party whose contract is no longer taken (it lapsed, or was given up) leaves the map.
func _clear_strays() -> void:
	for party: WorldParty in world.parties.duplicate():
		if not party.id.begins_with(PREFIX):
			continue
		var row := company.economy.book.contract(party.id.trim_prefix(PREFIX))
		if row.get("accepted") != true:
			world.parties.erase(party)


## A free tile `span.x` to `span.y` steps from `centre`, `span.z` rolls on the "jobs" stream;
## the first in a row-by-row scan when every roll misses; NOWHERE when none is free.
static func _roll_tile(on: WorldSim, centre: Vector2i, span: Vector3i, rng: Rng) -> Vector2i:
	for _try: int in span.z:
		var at := (
			centre + Vector2i(rng.roll(STREAM, -span.y, span.y), rng.roll(STREAM, -span.y, span.y))
		)
		if _fits(on, at, centre, span):
			return at
	for y: int in range(centre.y - span.y, centre.y + span.y + 1):
		for x: int in range(centre.x - span.y, centre.x + span.y + 1):
			if _fits(on, Vector2i(x, y), centre, span):
				return Vector2i(x, y)
	return NOWHERE


## Walkable, off every site, not under another party, out of the band's reach (more than a
## step away, so nothing is raised the moment it appears), and `span.x` to `span.y` steps from
## `centre`.
static func _fits(on: WorldSim, at: Vector2i, centre: Vector2i, span: Vector3i) -> bool:
	var gap := TileRegion.gap(at, centre)
	if gap < span.x or gap > span.y or TileRegion.gap(at, on.band) <= 1:
		return false
	if not on.region.passable(at) or not on.region.site_at(at).is_empty():
		return false
	return on.parties.all(func(other: WorldParty) -> bool: return other.tile != at)


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key)
	return Merc.whole(value) if value is int or value is float else 0
