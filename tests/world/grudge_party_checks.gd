extends RefCounted
## The hunter checks (Phase 5 C4, the hunter half), run by tests/run_sim_world_tests.gd: a
## grudge sends hunter parties. Only a deal walked from after an advance of half the pay or
## more sends one (Q-13, Q-16), one party per broken deal ("sent" counts parties); it starts
## away from the band on the "grudge" stream and walks the same whether the band is here or
## there while it cannot see it (not psychic); its line-up grows with the grudge (Q-15); it
## fights once, won or lost, then leaves for good and the company remembers the deal (lead
## call); a play saved and loaded mid-hunt ends as the uninterrupted one; the parties that are
## not hunters save as before. Seeded by design: tests/lib/hunter_kit.gd on SEED.

const HunterKit := preload("res://tests/lib/hunter_kit.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SEED := 424242
const HALF := 50
const THIRD := 33
## The enemy count of enc_hunters' line-ups, by strength 1, 2, 3, and past the last.
const SIZES: Array[int] = [3, 4, 5, 5]
const BLIND_DAYS := 3
const AFTER_DAYS := 10
const SPLIT := 6
## The seeds the reachability check walks.
const REACH_SEEDS := 20
const JobKit := preload("res://tests/lib/job_kit.gd")
const BATTLE := "res://data/balance/battle.json"
const SCENARIOS := "res://data/scenarios.json"

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_sent()
	_check_start_ignores_band()
	_check_reachable()
	_check_captain_per_deal()
	_check_not_sent(THIRD, false)
	_check_not_sent(HALF, true)
	_check_one_per_deal()
	_check_lineups()
	_check_in_sight()
	_check_not_psychic()
	_check_fights_once(true)
	_check_fights_once(false)
	_check_reload_continues()
	_check_old_parties()


func _knobs() -> Dictionary:
	var parties: Dictionary = World.data().get("parties", {})
	return parties.get(GrudgeParties.TYPE, {})


func _hunters(played: HunterKit.Played) -> Array[WorldParty]:
	var found: Array[WorldParty] = []
	for party: WorldParty in played.world.parties:
		if party.type == GrudgeParties.TYPE:
			found.append(party)
	return found


func _check_sent() -> void:
	var played := HunterKit.Played.new(SEED)
	played.break_deal(HALF)
	var origin := _origin(played)
	played.world.rest()
	var found := _hunters(played)
	var grudge := played.company.economy.standing.grudge(played.faction)
	var gap := TileRegion.gap(found[0].tile, origin) if found.size() == 1 else -1
	var knobs := _knobs()
	(
		_check
		. call(
			(
				found.size() == 1
				and found[0].id == GrudgeParties.PREFIX + played.deal
				and found[0].strength == 1
				and gap >= Merc.whole(knobs.get("start_min_tiles"))
				and gap <= Merc.whole(knobs.get("start_max_tiles"))
				and grudge.get("sent") == 1
				and played.company.economy.standing.hunter_calls().is_empty()
			),
			(
				"walked from after half up front: one party that day, %d-%d from the site (%s at %d, %s)"
				% [knobs.get("start_min_tiles"), knobs.get("start_max_tiles"), found, gap, grudge]
			)
		)
	)


## The entrance of the broken deal's site, where its hunters set out from (the job's site).
static func _origin(played: HunterKit.Played) -> Vector2i:
	var broken := played.company.economy.standing.broken_deal(played.deal)
	return played.world.region.entrance(str(broken.get("site", "")))


## Rule 6 (lead ruling): where the hunters start never depends on where the band is. The same
## seed and deal with the band at its gate or across the map: the same start tile.
func _check_start_ignores_band() -> void:
	var here := HunterKit.Played.new(SEED)
	var there := HunterKit.Played.new(SEED)
	for played: HunterKit.Played in [here, there]:
		played.break_deal(HALF)
	var reach := Merc.whole(_knobs().get("start_max_tiles")) + 1
	there.world.band = _far_tile(there.world, _origin(there), reach)
	var tiles: Array[Vector2i] = []
	for played: HunterKit.Played in [here, there]:
		played.world.rest()
		var found := _hunters(played)
		tiles.append(found[0].tile if found.size() == 1 else GrudgeParties.NOWHERE)
	_check.call(
		tiles[0] != GrudgeParties.NOWHERE and tiles[0] == tiles[1],
		"the hunters set out from the same tile wherever the band is (got %s)" % [tiles]
	)


## On every seed of a spread, the hunters start on a tile the band can walk to (and so they can
## walk to the band).
func _check_reachable() -> void:
	var stranded: Array[int] = []
	for seed_value: int in range(SEED, SEED + REACH_SEEDS):
		var played := HunterKit.Played.new(seed_value)
		played.break_deal(HALF)
		played.world.rest()
		var found := _hunters(played)
		if (
			found.size() != 1
			or JobKit.Played.first_step(played.world, found[0].tile) == Vector2i.ZERO
		):
			stranded.append(seed_value)
	_check.call(
		stranded.is_empty(),
		(
			"on %d seeds the hunters start where the band can reach (stranded %s)"
			% [REACH_SEEDS, stranded]
		)
	)


## The memory names the captain who broke that deal, not whoever leads when the hunters come:
## the orc breaks the first deal and dies, his successor breaks a second with the same faction,
## and the first deal's hunters are remembered as the orc's.
func _check_captain_per_deal() -> void:
	var played := HunterKit.Played.new(SEED)
	var first_captain := played.company.captain_id
	played.break_deal(HALF)
	var first_deal := played.deal
	played.world.rest()
	played.company.bury(first_captain)
	played.company.appoint(played.company.fighting_order()[0])
	var second: Dictionary = played.company.economy.board[0]
	second["faction"] = played.faction
	played.break_deal(HALF)
	var second_captain := played.company.captain_id
	for _move: int in HunterKit.MOVES * 2:
		if played.settled.any(func(one: Dictionary) -> bool: return one.get("deal") == first_deal):
			break
		played.move(true)
	var about := ""
	for merc_id: String in played.company.fighting_order():
		for entry: Dictionary in played.memory.of(merc_id):
			var params: Dictionary = entry.get("params", {})
			if params.get("deal") == first_deal:
				about = str(params.get("about", ""))
	_check.call(
		second_captain != first_captain and about == first_captain,
		(
			"the first deal's hunters are remembered as %s's deal, not %s's (got %s)"
			% [first_captain, second_captain, about]
		)
	)


## A smaller advance, or the deal completed, sends nobody.
func _check_not_sent(advance_pct: int, completes: bool) -> void:
	var played := HunterKit.Played.new(SEED)
	if completes:
		var row: Dictionary = played.company.economy.board[0]
		played.company.economy.accept(str(row.get("id", "")))
		row["advance"] = Merc.whole(row.get("reward", 0)) * advance_pct / HunterKit.PERCENT
		played.company.economy.complete(str(row.get("id", "")))
	else:
		played.break_deal(advance_pct)
	for _day: int in AFTER_DAYS:
		played.world.rest()
	_check.call(
		_hunters(played).is_empty(),
		(
			"no hunters after %s with %d%% up front"
			% ["a completed deal" if completes else "a deal walked from", advance_pct]
		)
	)


## Two broken deals: two parties, the second as strong as the grudge has grown.
func _check_one_per_deal() -> void:
	var played := HunterKit.Played.new(SEED)
	played.break_deal(HALF)
	played.world.rest()
	played.break_deal(HALF)
	played.world.rest()
	played.world.rest()
	var strengths: Array[int] = []
	for party: WorldParty in _hunters(played):
		strengths.append(party.strength)
	var grudge := played.company.economy.standing.grudge(played.faction)
	_check.call(
		strengths == [1, 2] and grudge.get("sent") == 2,
		(
			"each broken deal sends one party, the next stronger with the grudge (got %s, %s)"
			% [strengths, grudge]
		)
	)


## A hunter party a step from the band raises enc_hunters' line-up of its strength (no roll).
func _check_lineups() -> void:
	var sizes: Array[int] = []
	var unrolled := true
	for strength: int in range(1, SIZES.size() + 1):
		var played := HunterKit.Played.new(SEED)
		var party := WorldParty.make(GrudgeParties.PREFIX + "ctr_x", GrudgeParties.TYPE, Vector2i())
		party.strength = strength
		party.tile = _neighbour(played.world)
		played.world.parties.append(party)
		var before: Dictionary = played.rng.state()
		played.world.rest()
		var enemies: Array = played.world.encounter.get("enemies", [])
		sizes.append(enemies.size())
		unrolled = unrolled and played.rng.state() == before
	_check.call(sizes == SIZES, "the hunters grow with the grudge: %s, got %s" % [SIZES, sizes])
	_check.call(unrolled, "a hunter line-up is picked by strength, nothing rolled")


## Every hunter in every enc_hunters line-up starts within the battle's sight_cells of the
## company's nearest road cell, so the fight opens with each side in the other's sight.
func _check_in_sight() -> void:
	var rules: Dictionary = World.json(BATTLE).get("rules", {})
	var sight := Merc.whole(rules.get("sight_cells"))
	var scenarios: Array = World.json(SCENARIOS).get("scenarios", [])
	var slice: Dictionary = scenarios[0]
	var road := EncounterBattle.company_cells(slice)
	var worst := -1
	for encounter: Dictionary in World.json(World.ENCOUNTERS).get("encounters", []):
		if encounter.get("type") != GrudgeParties.TYPE:
			continue
		for lineup: Array in encounter.get("lineups", []):
			for enemy: Dictionary in lineup:
				var raw: Array = enemy.get("cell", [])
				var cell := Vector2i(Merc.whole(raw[0]), Merc.whole(raw[1]))
				var nearest := -1
				for mine: Vector2i in road:
					var gap := BattleGrid.gap(cell, mine)
					nearest = gap if nearest < 0 else mini(nearest, gap)
				worst = maxi(worst, nearest)
	_check.call(
		sight > 0 and not road.is_empty() and worst >= 0 and worst <= sight,
		"every hunter deploys within sight_cells (%d) of the company: farthest %d" % [sight, worst]
	)


## The hunters walk the same whether the band stands near them or far, while they cannot see it.
func _check_not_psychic() -> void:
	var near := HunterKit.Played.new(SEED)
	var far := HunterKit.Played.new(SEED)
	var site := _farthest_site(near.world)
	for played: HunterKit.Played in [near, far]:
		played.world.send_hunters("ctr_x", 1, site)
	var party_near := _hunters(near)[0]
	var sight := Merc.whole(_knobs().get("sight_tiles"))
	far.world.band = _far_tile(far.world, _hunters(far)[0].tile, sight)
	var walked_near: Array[Vector2i] = []
	var walked_far: Array[Vector2i] = []
	# Day by day while the near band is still out of the party's sight (its last day's walk
	# may end in sight, so only the days before that are compared).
	for _day: int in BLIND_DAYS:
		if TileRegion.gap(party_near.tile, near.world.band) <= sight:
			break
		near.world.rest()
		far.world.rest()
		walked_near.append(party_near.tile)
		walked_far.append(_hunters(far)[0].tile)
	walked_near.pop_back()
	walked_far.pop_back()
	_check.call(
		not walked_near.is_empty() and walked_near == walked_far,
		(
			"a hunter party that cannot see the band walks the same wherever it is (got %s vs %s)"
			% [walked_near, walked_far]
		)
	)


## One fight, won or lost: the party leaves for good, the grudge stays, and every merc who
## fought remembers the deal and the captain who broke it.
func _check_fights_once(won: bool) -> void:
	var played := HunterKit.begin(SEED, HALF)
	HunterKit.play(played, won)
	var outcome := "won" if won else "lost"
	var settled: Dictionary = played.settled[0] if played.settled.size() == 1 else {}
	var remembered := _remembered(played, outcome)
	for _day: int in AFTER_DAYS:
		played.world.rest()
	var grudge := played.company.economy.standing.grudge(played.faction)
	_check.call(
		(
			settled.get("outcome") == outcome
			and settled.get("deal") == played.deal
			and remembered
			and _hunters(played).is_empty()
			and played.fights.size() == 1
			and grudge.get("growth") == 1
		),
		(
			"a hunter fight %s: fought once, gone for good, grudge kept, deal remembered (%s, %s)"
			% [outcome, settled, played.fights]
		)
	)


## Whether every merc who fights for the company last remembers the hunter fight `outcome`,
## naming the deal, its faction and the captain who broke it.
static func _remembered(played: HunterKit.Played, outcome: String) -> bool:
	for merc_id: String in played.company.fighting_order():
		var lines := played.memory.of(merc_id)
		var last: Dictionary = lines.back() if not lines.is_empty() else {}
		var params: Dictionary = last.get("params", {})
		var named: bool = (
			params.get("deal") == played.deal
			and (
				params.get("about")
				== played.company.economy.standing.broken_deal(played.deal).get("captain")
			)
			and params.get("faction") == played.faction
		)
		if last.get("key") != GrudgeParties.MEMORY_PREFIX + outcome or not named:
			return false
	return true


func _check_reload_continues() -> void:
	var straight := HunterKit.begin(SEED, HALF)
	HunterKit.play(straight, true, HunterKit.MOVES, false)
	var first := HunterKit.begin(SEED, HALF)
	HunterKit.play(first, true, SPLIT, false)
	var reloaded := HunterKit.load_back(first)
	reloaded.deal = first.deal
	HunterKit.play(reloaded, true, HunterKit.MOVES - SPLIT, false)
	_check.call(
		(
			HunterKit.save_text(reloaded) == HunterKit.save_text(straight)
			and not straight.fights.is_empty()
		),
		(
			"a hunt saved and loaded mid-way ends in the uninterrupted save (fights %s)"
			% [straight.fights]
		)
	)


## A party that is not a hunter saves as before (no strength key); an old party loads at 0.
func _check_old_parties() -> void:
	var party := WorldParty.make("party_0", "ambush", Vector2i(1, 2))
	var saved := party.to_dict()
	var loaded := WorldParty.from_dict(saved)
	_check.call(
		not saved.has("strength") and loaded.strength == 0,
		"a party that is not a hunter saves and loads as before (got %s)" % [saved]
	)


## The site whose entrance lies farthest from the band (so hunters sent from it start unseen).
static func _farthest_site(world: WorldSim) -> String:
	var best := ""
	var best_gap := -1
	for site: WorldSite in world.sites:
		var gap := TileRegion.gap(world.region.entrance(site.id), world.band)
		if gap > best_gap:
			best = site.id
			best_gap = gap
	return best


## A walkable neighbour of the band (the first in the fixed step order).
static func _neighbour(world: WorldSim) -> Vector2i:
	for step: Vector2i in TileRegion.STEPS:
		var at := world.band + step
		if world.region.passable(at) and world.region.site_at(at).is_empty():
			return at
	return world.band


## A walkable tile more than twice `sight` steps from `from` (the first in a row-by-row scan).
static func _far_tile(world: WorldSim, from: Vector2i, sight: int) -> Vector2i:
	for y: int in world.region.height:
		for x: int in world.region.width:
			var at := Vector2i(x, y)
			if TileRegion.gap(at, from) > 2 * sight and world.region.passable(at):
				return at
	return world.band
