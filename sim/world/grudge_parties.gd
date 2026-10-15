class_name GrudgeParties
extends RefCounted
## A grudge sends hunter parties (Phase 5 C4, the hunter half; director Q-13, Q-15, Q-16).
## A faction holds a grudge only after the company walked away from one of its contracts
## having taken an advance of half the pay or more (Standing.abandoned). Each such broken deal
## sends one party of hunters ("sent" counts parties, Standing.hunter_calls): a plain
## WorldParty that starts away from the band on the Rng "grudge" stream and wanders, sees and
## chases on sight like any party (it is not psychic: it is never told where the band is). Its
## strength is the grudge's growth when it was sent, and picks its line-up from
## data/encounters.json "enc_hunters" (one more man per step, inside C7's caps): the grudge
## grows, the hunters grow. Lead call (2026-10-16): a hunter party fights once, won or lost,
## then leaves the map for good; the grudge stays. Every merc who fought it remembers the
## fight, naming the broken deal and the captain who broke it ("memory.grudge.hunted.*").
## Its walking and placement numbers: data/balance/world.json "parties" "hunters". Nothing
## here is saved: the parties ride on the world's save, the grudges on the economy's.

const STREAM := "grudge"
## The party type and the encounter type it raises.
const TYPE := "hunters"
## A hunter party's id: this prefix and the broken deal's contract id.
const PREFIX := "hunters_"
const MEMORY_PREFIX := "memory.grudge.hunted."
const NOWHERE := Vector2i(-1, -1)

var world: WorldSim = null
var company: Company = null
## Where a hunter fight is remembered; null: nobody remembers it (a bare sim check).
var memory: Memory = null


static func make(on: WorldSim, owner: Company) -> GrudgeParties:
	var hunters := GrudgeParties.new()
	hunters.world = on
	hunters.company = owner
	return hunters


## Puts a broken deal's hunters on the map: a free tile start_min_tiles to start_max_tiles
## steps from the band, place_tries rolls on the "grudge" stream, then the first free one in a
## row-by-row scan. deal: {"deal": contract id, "strength": the grudge's growth}; knobs: the
## "hunters" block of data/balance/world.json "parties". Its id, "" when no tile was free.
static func place(on: WorldSim, deal: Dictionary, knobs: Dictionary, rng: Rng) -> String:
	var span := Vector3i(
		_num(knobs, "start_min_tiles"), _num(knobs, "start_max_tiles"), _num(knobs, "place_tries")
	)
	var at := _roll_tile(on, span, rng)
	if at == NOWHERE:
		return ""
	var party := WorldParty.make(PREFIX + str(deal.get("deal", "")), TYPE, at)
	party.strength = maxi(1, _num(deal, "strength"))
	on.parties.append(party)
	return party.id


## A day has passed (after the jobs are judged, so a deal abandoned today sends its hunters
## today): a fought hunter party is settled, then each grudge owed a party sends one. The
## settled fights, {"deal", "faction", "outcome", "day"}.
func on_day(_day: int) -> Array[Dictionary]:
	var fought := _settle_fought()
	var standing := company.economy.standing
	for faction: String in standing.hunter_calls():
		var deal := standing.next_hunt(faction)
		var growth := _num(standing.grudge(faction), "growth")
		if not world.send_hunters(deal, growth).is_empty():
			standing.hunters_sent(faction)
	return fought


## A fight's result was applied (WorldSim.resolve_encounter): a hunter party just fought is
## settled. The settled fights.
func on_result(_result: Dictionary) -> Array[Dictionary]:
	return _settle_fought()


## Every hunter party the band has fought (WorldSim sends a fought party away: its away day is
## set) leaves the map for good, and each merc who fights for the company remembers the fight,
## won or lost as the world's log has it, naming the deal and the captain who broke it.
func _settle_fought() -> Array[Dictionary]:
	var fought: Array[Dictionary] = []
	for party: WorldParty in world.parties.duplicate():
		if party.type != TYPE or party.away_until <= 0:
			continue
		world.parties.erase(party)
		var deal := party.id.trim_prefix(PREFIX)
		var faction := company.economy.standing.grudge_of(deal)
		var outcome := _last_outcome()
		fought.append({"deal": deal, "faction": faction, "outcome": outcome, "day": world.day})
		if memory == null:
			continue
		var captain := str(company.economy.standing.grudge(faction).get("captain", ""))
		var params := {"about": captain, "deal": deal, "faction": faction}
		for merc_id: String in company.fighting_order():
			memory.record(merc_id, MEMORY_PREFIX + outcome, params, world.day)
	return fought


## How the last hunter fight in the world's log ended: "won" or "lost".
func _last_outcome() -> String:
	for index: int in range(world.log.size() - 1, -1, -1):
		var entry: Dictionary = world.log[index]
		if entry.get("step") == "encounter" and entry.get("type") == TYPE:
			return str(entry.get("outcome", ""))
	return ""


## A free tile `span.x` to `span.y` steps from the band, `span.z` rolls on the "grudge" stream;
## the first in a row-by-row scan when every roll misses; NOWHERE when none is free.
static func _roll_tile(on: WorldSim, span: Vector3i, rng: Rng) -> Vector2i:
	var centre := on.band
	for _try: int in span.z:
		var at := (
			centre + Vector2i(rng.roll(STREAM, -span.y, span.y), rng.roll(STREAM, -span.y, span.y))
		)
		if _fits(on, at, span):
			return at
	for y: int in range(centre.y - span.y, centre.y + span.y + 1):
		for x: int in range(centre.x - span.y, centre.x + span.y + 1):
			if _fits(on, Vector2i(x, y), span):
				return Vector2i(x, y)
	return NOWHERE


## Walkable, off every site, not under another party, and `span.x` to `span.y` steps from the
## band (never within a step of it, so nothing is raised the moment it appears).
static func _fits(on: WorldSim, at: Vector2i, span: Vector3i) -> bool:
	var gap := TileRegion.gap(at, on.band)
	if gap <= 1 or gap < span.x or gap > span.y:
		return false
	if not on.region.passable(at) or not on.region.site_at(at).is_empty():
		return false
	return on.parties.all(func(other: WorldParty) -> bool: return other.tile != at)


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key)
	return Merc.whole(value) if value is int or value is float else 0
