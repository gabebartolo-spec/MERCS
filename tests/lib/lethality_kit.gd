extends RefCounted
## The lethality ledger's campaigns (Phase 5 C7; tools/audit/lethality.gd prints the report,
## tests/run_campaign_tests.gd checks it replays). One campaign on one seed: the starting six
## walk out, meet a party (the types in TYPES, in turn), fight it with the whole company as the
## game does (RoadFight: up to six fielded, the rest in reserve; MercPlay on both sides; the
## real triage of data/balance/injury.json, so a merc put down may die), rest REST_DAYS, hire
## from the hub's offers while the roster is under its cap (eight), and go again, until
## FIGHTS_MAX fights or nobody is left. It REPORTS named deaths per fight, enemies per fight and
## fights per campaign against the director's target (1 named death per 4 fights, Q-14); it
## tunes nothing. Every roll is on the one Rng of the seed, so the same seeds give the same
## report.

const World := preload("res://tests/lib/world_fixture.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
## The party met in each fight, in turn: the road's two (ambush, patrol) and the three a
## contract's job puts on the map (camp, raiders, quarry).
const TYPES: Array[String] = ["ambush", "patrol", "raiders", "camp", "quarry"]
const FIGHTS_MAX := 12
const TRIES_PER_FIGHT := 3
const REST_DAYS := 2
const NEAR := 3
const OUT := 3
const WALK_LIMIT := 40
const BATTLE := "res://data/balance/battle.json"
## The director's target is read per four fights (Q-14: 1 named death per 4 fights).
const PER_FOUR := 4.0


## The slice's own street fight (scn_slice_loop: the orc and the Vampyr against its band and
## lookout, MercPlay on both sides) on seeds first..last: {"fights", "won", "down": {unit id:
## fights he went down in}}. The lead's flag (#127): the Vampyr in plate never falls there.
static func slice(first: int, last: int) -> Dictionary:
	var data := Fixture.json(BATTLE)
	var won := 0
	var down := {}
	for seed_value: int in range(first, last + 1):
		var battle := EncounterBattle.build(
			Kit.pending(), Kit.scenario(), data, Rng.from_seed(seed_value)
		)
		MercPlay.play_out(battle, Fixture.rules(), Kit.MAX_ACTIONS)
		won += 1 if battle.winner == BattleUnit.COMPANY else 0
		for unit: BattleUnit in battle.units:
			if unit.side == BattleUnit.COMPANY and unit.down:
				_bump(down, unit.id)
	return {"fights": last - first + 1, "won": won, "down": down}


## One campaign: {"seed", "fights", "won", "enemies", "rabble_fights", "deaths", "downs",
## "fielded", "reserve", "days", "wiped", "dead": {merc id: fights}, "down_by": {merc id: n},
## "fought_by": {merc id: n}}. `fights_max` caps the fights (FIGHTS_MAX when 0).
static func run(seed_value: int, fights_max: int = 0) -> Dictionary:
	var played := Played.new(seed_value)
	var rabble := _rabble_kinds()
	var report := {
		"seed": seed_value,
		"fights": 0,
		"won": 0,
		"enemies": 0,
		"rabble_fights": 0,
		"deaths": 0,
		"downs": 0,
		"fielded": 0,
		"reserve": 0,
		"days": 0,
		"wiped": false,
		"dead": {},
		"down_by": {},
		"fought_by": {}
	}
	var wanted := fights_max if fights_max > 0 else FIGHTS_MAX
	var tries := 0
	while _n(report["fights"]) < wanted and tries < wanted * TRIES_PER_FIGHT:
		if played.company.is_wiped():
			break
		var kind := TYPES[(_n(report["fights"]) + tries) % TYPES.size()]
		tries += 1
		if not _meet(played, kind):
			played.world.rest()
			continue
		_fight(played, report, rabble)
		for _day: int in REST_DAYS:
			played.world.rest()
		_hire(played)
	report["wiped"] = played.company.is_wiped()
	report["days"] = played.world.day
	return report


## Sums campaigns into the ledger: totals, and named deaths per fight and per 4 fights.
static func ledger(first_seed: int, count: int, fights_max: int = 0) -> Dictionary:
	var rows: Array[Dictionary] = []
	var total := {"campaigns": count, "fights": 0, "won": 0, "enemies": 0, "rabble_fights": 0}
	total.merge({"deaths": 0, "downs": 0, "fielded": 0, "reserve": 0, "wiped": 0})
	var dead := {}
	var down_by := {}
	var fought_by := {}
	for n: int in count:
		var row := run(first_seed + n, fights_max)
		rows.append(row)
		for key: String in ["fights", "won", "enemies", "rabble_fights", "deaths", "downs"]:
			_add(total, key, _n(row[key]))
		_add(total, "fielded", _n(row["fielded"]))
		_add(total, "reserve", _n(row["reserve"]))
		_add(total, "wiped", 1 if row["wiped"] == true else 0)
		_add_all(dead, row["dead"])
		_add_all(down_by, row["down_by"])
		_add_all(fought_by, row["fought_by"])
	var fights := float(maxi(1, _n(total["fights"])))
	total["deaths_per_fight"] = _n(total["deaths"]) / fights
	total["deaths_per_4_fights"] = PER_FOUR * _n(total["deaths"]) / fights
	total["enemies_per_fight"] = _n(total["enemies"]) / fights
	total["fights_per_campaign"] = _n(total["fights"]) / float(maxi(1, count))
	total["fielded_per_fight"] = _n(total["fielded"]) / fights
	total["reserve_per_fight"] = _n(total["reserve"]) / fights
	return {"total": total, "dead": dead, "down_by": down_by, "fought_by": fought_by, "rows": rows}


## One party of `kind` placed NEAR the band (out of the gate first, from a site) and walked
## into. True when its encounter stands.
static func _meet(played: Played, kind: String) -> bool:
	var world := played.world
	world.parties.clear()
	if not world.at.is_empty():
		World.out_of_town(world, OUT)
	var party := World.lone_party(world, kind, NEAR)
	if party != null:
		World.walk_toward(world, party.tile, WALK_LIMIT)
	return not world.encounter.is_empty()


## The standing encounter fought to its end with the company, triaged, the world told.
static func _fight(played: Played, report: Dictionary, rabble: Dictionary) -> void:
	var world := played.world
	played.wounds.day = world.day
	var kind := str(world.encounter.get("type", ""))
	var pending := world.pending_encounter()
	var enemies: Array = pending.get("enemies", [])
	var battle := RoadFight.build(
		played.wounds, pending, Kit.scenario(), Fixture.json(BATTLE), played.rng
	)
	var fielded := played.wounds.fielded.duplicate()
	MercPlay.play_out(battle, Fixture.rules(), Kit.MAX_ACTIONS)
	var result := EncounterBattle.result(battle)
	var events := played.wounds.resolve()
	var hook := world.result_hook
	world.result_hook = Callable()
	world.resolve_encounter(result)
	world.result_hook = hook
	hook.call(kind, result)
	_add(report, "fights", 1)
	_add(report, "won", 1 if result.get("won", false) == true else 0)
	_add(report, "enemies", enemies.size())
	_add(report, "rabble_fights", 1 if _all_rabble(enemies, rabble) else 0)
	_add(report, "fielded", fielded.size())
	_add(report, "reserve", played.company.roster.size() + _deaths(events) - fielded.size())
	for merc_id: String in fielded:
		_bump(report["fought_by"], merc_id)
	for event: Dictionary in events:
		if event.get("type") == "triage":
			_add(report, "downs", 1)
			_bump(report["down_by"], str(event.get("merc")))
		elif event.get("type") == "death":
			_add(report, "deaths", 1)
			_bump(report["dead"], str(event.get("merc")))


## Hires the hub's first offers while the roster is under its cap and the purse allows.
static func _hire(played: Played) -> void:
	var economy := played.company.economy
	for offer: Dictionary in economy.offers():
		if played.company.roster.size() >= played.company.cap():
			return
		economy.hire(played.company, str(offer.get("id", "")))


static func _deaths(events: Array[Dictionary]) -> int:
	var count := 0
	for event: Dictionary in events:
		count += 1 if event.get("type") == "death" else 0
	return count


static func _rabble_kinds() -> Dictionary:
	var kinds := {}
	var fighters: Dictionary = Fixture.json(BATTLE).get("fighters", {})
	for kind: String in fighters:
		var row: Dictionary = fighters[kind]
		if row.get("rabble", false) == true:
			kinds[kind] = true
	return kinds


static func _all_rabble(enemies: Array, rabble: Dictionary) -> bool:
	for entry: Variant in enemies:
		var row: Dictionary = entry
		if not rabble.has(str(row.get("fighter", ""))):
			return false
	return not enemies.is_empty()


static func _bump(counts: Variant, key: String) -> void:
	if counts is Dictionary:
		var found: Dictionary = counts
		_add(found, key, 1)


static func _add(counts: Dictionary, key: String, amount: int) -> void:
	counts[key] = _n(counts.get(key, 0)) + amount


static func _add_all(into: Dictionary, counts: Variant) -> void:
	if not counts is Dictionary:
		return
	var found: Dictionary = counts
	for key: String in found:
		_add(into, key, _n(found[key]))


static func _n(value: Variant) -> int:
	return Merc.whole(value)


## One campaign's pieces on one Rng, the hub's hooks set: the starting six, the real triage.
class Played:
	extends RefCounted
	var rng: Rng
	var world := WorldSim.new()
	var company: Company
	var wounds: CompanyWounds

	func _init(seed_value: int) -> void:
		rng = Rng.from_seed(seed_value)
		world.start(World.data(), rng)
		var lineups: Array = World.json(World.ENCOUNTERS).get("encounters", [])
		world.set_lineups(lineups)
		company = Company.start(Fixture.defs())
		wounds = CompanyWounds.make(company, {}, rng, Kit.rules(), Kit.injury_defs())
		var site_ids: Array[String] = []
		for i: int in range(1, world.sites.size()):
			site_ids.append(world.sites[i].id)
		company.economy.refresh_board(world.day, site_ids, rng)
		world.day_hook = func(day: int) -> void:
			company.economy.on_day(company.roster, day, site_ids, rng)
		world.result_hook = func(kind: String, result: Dictionary) -> void:
			if result.get("won", false) == true:
				company.economy.take_loot(kind, rng, result)
