extends RefCounted
## The battle suite's golden logs, run by tests/run_battle_tests.gd: several seeded fights
## (6 v 6, or two lone recruits who are wiped out) on a street with walls, played to their end
## by a fixed chooser (the enemy's line, the orc's charge, the Vampyr's blood price, an illegal
## try now and then), each with a hit hook, some with an ambush or a band already shaken. Each
## fight's whole event log and end state hash to a pinned SHA-256: a change to the battle that
## is meant to keep behaviour (a refactor, a split into modules) must leave every hash as it
## is. A rule or balance change that moves a hash updates GOLDEN in the same PR and says why.
## The recorded actions replayed through FightRecord into a fresh battle give the same log
## (Ironman's resume path).
## Seeded by design: every roll comes from Rng.from_seed with a pinned seed.

const BATTLE_DATA := "res://data/balance/battle.json"
const GRID := Vector2i(12, 8)
const MAX_TURNS := 300
const ILLEGAL_EVERY := 7
## Pinned before the battle.gd split (claude/p4-plan-split); seed -> SHA-256 of the fight.
## Re-pinned by Phase 4 P2 (morale, surrender, the captain's fall): seeds 1, 1337, 424242, 90210
## and 2026 end the same way (same winner, same round) but the broken band's end now says who
## ran and who surrendered, and in seed 1 the chief's fall breaks his shaky bandits first.
const GOLDEN := {
	1: "62c7974dab16e161d64cfd244a853c9cebfc4673599e1b7079ac93469caead5a",
	7: "cb8f59423e39e245274404ec1f16e030741fc4e4a219c594cedf06a6bc1ea249",
	1337: "47650130c1973c04fcabaf050f293083ccb9350c1d0e13567c0458dee299a5e5",
	424242: "8d703a69cbb60fd2f40778bdd9fbf79d9eb3d85c35962d4297c241408175aa11",
	90210: "9f3a31d990b2a0e92741e635738a7cfbfc5a8f584b978056c1a7bd99b9dfdf89",
	2026: "e8c66eb084e07e191a254f384db16085a4c2c431909c57db42fcf17c2e438769",
	31: "4f7c3ae850981a983eddbf65fbc8195fc28e1b8ae6e91dde4fbbab2be3b145b2",
}
const MARK := "golden_mark"

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	var hashes_ok := true
	var replay_ok := true
	var seen := {}
	for seed_value: int in GOLDEN:
		var fight := _fight(seed_value)
		var battle: Battle = fight["battle"]
		var digest := _digest(battle)
		print("GOLDEN seed=%d sha256=%s" % [seed_value, digest])
		hashes_ok = hashes_ok and digest == str(GOLDEN[seed_value])
		var actions: Array[Dictionary] = fight["actions"]
		var again := _build(seed_value)
		var applied := FightRecord.replay(again, _through_json(actions))
		replay_ok = replay_ok and applied == actions.size() and _digest(again) == digest
		_note_coverage(battle, seen)
	_check.call(hashes_ok, "every golden fight's event log and end state hash as pinned")
	_check.call(replay_ok, "each golden fight's actions replayed into a fresh battle match it")
	var covered := [
		"rout",
		"wipe",
		"charge",
		"blood_price",
		MARK,
		"shaken",
		"ambush",
		"surrender",
		"captain_fall"
	]
	var all_seen := covered.all(func(key: String) -> bool: return seen.has(key))
	(
		_check
		. call(
			all_seen,
			"the golden fights cover rout, wipe, both moves, hook, shaken, ambush, surrender, captain's fall"
		)
	)


func _rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var rules: Variant = data.get("rules", {})
	return rules if rules is Dictionary else {}


func _fighters(data: Dictionary) -> Dictionary:
	var found: Variant = data.get("fighters", {})
	return found if found is Dictionary else {}


## The same setup for a seed every time: the seed also picks the walls, the enemy band and
## whether it is an ambush or the band starts shaken.
func _build(seed_value: int) -> Battle:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var stats := _fighters(data)
	var fighters: Array[BattleUnit] = []
	var mine: Array[String] = ["orc", "vampyr", "recruit_placeholder"]
	var company_size := 6
	if seed_value % 4 == 3:
		mine = ["recruit_placeholder"]
		company_size = 2
	for i: int in company_size:
		var key: String = mine[mini(i, mine.size() - 1)]
		var own: Dictionary = stats[key]
		var at := Vector2i(1 + i % 2, 1 + i)
		fighters.append(BattleUnit.make("c%d" % i, BattleUnit.COMPANY, at, own))
	var band: Array[String] = ["bandit_chief", "bandit"]
	if seed_value % 2 == 1:
		band = ["watch_sergeant", "watchman"]
	for i: int in 6:
		var key: String = band[0] if i == 0 else band[1]
		var theirs: Dictionary = stats[key]
		var at := Vector2i(10 - i % 2, 1 + i)
		fighters.append(BattleUnit.make("e%d" % i, BattleUnit.ENEMY, at, theirs))
	var blocked := {}
	for i: int in 3:
		blocked[Vector2i(4 + (seed_value + i) % 4, (seed_value % 7 + i * 2) % GRID.y)] = true
	for unit: BattleUnit in fighters:
		blocked.erase(unit.cell)
	var battle := Battle.new()
	battle.setup(_rules(), {"size": GRID, "blocked": blocked}, fighters, Rng.from_seed(seed_value))
	battle.set_hit_hook(_hook)
	if seed_value % 3 == 1:
		battle.give_first_turn(BattleUnit.ENEMY)
	if seed_value % 5 == 0:
		battle.lower_morale(BattleUnit.ENEMY, 30)
	return battle


## A hook that rolls nothing and marks each blow that puts a fighter down.
func _hook(hit: Dictionary) -> Array:
	if hit.get("down") == true:
		return [{"type": MARK, "target": hit["target"]}]
	return []


## Plays a seed's fight to its end; {"battle", "actions"} (the actions the battle accepted).
func _fight(seed_value: int) -> Dictionary:
	var battle := _build(seed_value)
	var actions: Array[Dictionary] = []
	for turn: int in MAX_TURNS:
		if battle.is_over():
			break
		if turn % ILLEGAL_EVERY == 3:
			battle.apply({"type": Battle.ACTION_ATTACK, "target": "nobody"})
		var action := _choose(battle, battle.current())
		if battle.apply(action).is_empty():
			action = {"type": Battle.ACTION_WAIT}
			battle.apply(action)
		actions.append(action)
	return {"battle": battle, "actions": actions}


func _choose(battle: Battle, fighter: BattleUnit) -> Dictionary:
	var sight: int = _rules().get("sight_cells", 0)
	var plain := BattleAi.choose(battle, fighter, sight)
	var kind := str(plain.get("type", ""))
	if fighter.knows(BattleUnit.MOVE_BLOOD_PRICE) and kind == Battle.ACTION_ATTACK:
		if fighter.hp > 6:
			return {"type": Battle.ACTION_BLOOD_PRICE, "target": plain["target"]}
	if fighter.knows(BattleUnit.MOVE_CHARGE) and kind == Battle.ACTION_MOVE:
		var charge := _charge(battle, fighter)
		if not charge.is_empty():
			return charge
	return plain


## A walk to the first free cell (sorted) beside any foe, and a strike on that foe.
func _charge(battle: Battle, fighter: BattleUnit) -> Dictionary:
	var cells: Array = battle.reachable(fighter).keys()
	cells.sort()
	for cell: Vector2i in cells:
		for other: BattleUnit in battle.units:
			if other.side != fighter.side and not other.down:
				if BattleGrid.adjacent(cell, other.cell):
					return {"type": Battle.ACTION_CHARGE, "target": other.id, "to": cell}
	return {}


## The actions as a save keeps them and reads them back (a cell as [x, y] and back).
func _through_json(actions: Array[Dictionary]) -> Array[Dictionary]:
	var record := FightRecord.make({}, actions)
	var text := JSON.stringify(record.saved())
	var back: Variant = JSON.parse_string(text)
	var saved: Dictionary = back if back is Dictionary else {}
	return FightRecord.read(saved)


## SHA-256 of the whole log and the end state (winner, rout, round, morale, every fighter).
func _digest(battle: Battle) -> String:
	var state: Array = [battle.winner, battle.routed, battle.surrendered, battle.round_number]
	for side: int in BattleUnit.SIDES:
		state.append([battle.morale(side), battle.is_shaken(side)])
	for unit: BattleUnit in battle.units:
		state.append([unit.id, unit.hp, unit.cell, unit.facing, unit.down, unit.wounded])
	return (var_to_str(battle.log) + var_to_str(state)).sha256_text()


func _note_coverage(battle: Battle, seen: Dictionary) -> void:
	if battle.routed >= 0:
		seen["rout"] = true
	elif battle.is_over():
		seen["wipe"] = true
	for event: Dictionary in battle.log:
		var kind := str(event.get("type", ""))
		if kind == Battle.ACTION_ATTACK:
			seen[str(event.get("move", ""))] = true
		elif kind in [MARK, "shaken", Battle.EVENT_SURRENDER, Battle.EVENT_CAPTAIN_FALL]:
			seen[kind] = true
	var first := _first_act(battle)
	var actor := battle.unit(str(first.get("unit", "")))
	if actor != null and actor.side == BattleUnit.ENEMY:
		seen["ambush"] = true


## The first move or attack of the fight.
func _first_act(battle: Battle) -> Dictionary:
	for event: Dictionary in battle.log:
		if str(event.get("type", "")) in [Battle.ACTION_MOVE, Battle.ACTION_ATTACK]:
			return event
	return {}
