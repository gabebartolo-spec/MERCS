class_name GrudgeParties
extends RefCounted
## A grudge sends hunter parties (Phase 5 C4, the hunter half; director Q-13, Q-15, Q-16).
## A faction holds a grudge only after the company walked away from one of its contracts
## having taken an advance of half the pay or more (Standing.abandoned). Each such broken deal
## sends one party of hunters ("sent" counts parties, Standing.hunter_calls): a plain
## WorldParty that sets out from the broken job's site (the hub when the deal's site is not
## known), placed near it on the Rng "grudge" stream, and searches, sees and chases on sight
## like any party. It is not psychic (rule 6, lead ruling 2026-10-16): where it starts never
## depends on where the band is, beyond never standing within a step of it. Its
## strength is the grudge's growth when it was sent, and picks its line-up from
## data/encounters.json "enc_hunters" (one more man per step, inside C7's caps): the grudge
## grows, the hunters grow. Lead call (2026-10-16): a hunter party fights once, won or lost,
## then leaves the map for good; the grudge stays. Every merc who fought it remembers the
## fight, naming the broken deal and the captain who broke that deal ("memory.grudge.hunted.*").
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
## steps from the entrance of the deal's site (the hub's when that site is unknown),
## place_tries rolls on the "grudge" stream, then the first free one in a row-by-row scan.
## deal: {"deal": contract id, "strength": the grudge's growth, "site": site id}; knobs: the
## "hunters" block of data/balance/world.json "parties". Its id, "" when no tile was free.
static func place(on: WorldSim, deal: Dictionary, knobs: Dictionary, rng: Rng) -> String:
	var span := Vector3i(
		_num(knobs, "start_min_tiles"), _num(knobs, "start_max_tiles"), _num(knobs, "place_tries")
	)
	var at := _roll_tile(on, _origin(on, str(deal.get("site", ""))), span, rng)
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
		var site := str(standing.broken_deal(deal).get("site", ""))
		if not world.send_hunters(deal, growth, site).is_empty():
			standing.hunters_sent(faction)
	return fought


## A fight's result was applied (WorldSim.resolve_encounter): a hunter party just fought is
## settled. The settled fights.
func on_result(_result: Dictionary) -> Array[Dictionary]:
	return _settle_fought()


## Every hunter party the band has fought (WorldSim sends a fought party away: its away day is
## set) leaves the map for good, and each merc who fights for the company remembers the fight,
## won or lost as the world's log has it, naming the deal and the captain who broke it (the
## captain of that deal, not whoever leads now).
func _settle_fought() -> Array[Dictionary]:
	var fought: Array[Dictionary] = []
	for party: WorldParty in world.parties.duplicate():
		if party.type != TYPE or party.away_until <= 0:
			continue
		world.parties.erase(party)
		var deal := party.id.trim_prefix(PREFIX)
		var broken := company.economy.standing.broken_deal(deal)
		var faction := str(broken.get("faction", ""))
		var outcome := _last_outcome()
		fought.append({"deal": deal, "faction": faction, "outcome": outcome, "day": world.day})
		if memory == null:
			continue
		var params := {"about": broken.get("captain", ""), "deal": deal, "faction": faction}
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


## Where a deal's hunters set out from: the entrance of its site, else the hub's (the first site).
static func _origin(on: WorldSim, site_id: String) -> Vector2i:
	var site := on.site(site_id)
	if site == null and not on.sites.is_empty():
		site = on.sites[0]
	return on.region.entrance(site.id) if site != null else on.band


## A free tile `span.x` to `span.y` steps from `centre`, `span.z` rolls on the "grudge" stream;
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


## Walkable, off every site, not under another party, `span.x` to `span.y` steps from `centre`,
## and more than a step from the band (so nothing is raised the moment it appears).
static func _fits(on: WorldSim, at: Vector2i, centre: Vector2i, span: Vector3i) -> bool:
	var gap := TileRegion.gap(at, centre)
	if TileRegion.gap(at, on.band) <= 1 or gap < span.x or gap > span.y:
		return false
	if not on.region.passable(at) or not on.region.site_at(at).is_empty():
		return false
	return on.parties.all(func(other: WorldParty) -> bool: return other.tile != at)


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key)
	return Merc.whole(value) if value is int or value is float else 0
