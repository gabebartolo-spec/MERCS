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
## Re-pinned, all seven, by Phase 4 P5 (claude/p4-p5-ai): the enemy no longer picks the foe
## beside it with the least exact health (rule 6) but the one it saw wounded, ties by id
## (BattleKnowledge), so plans, blows and the fights after them move.
## Re-pinned by Phase 4 P2 (morale, surrender, the captain's fall) on top of P5: seeds 1, 7,
## 1337, 424242, 90210 and 2026 now end with the broken band's men running or surrendering
## (and the chief's fall breaking his shaky bandits first); seed 31 is unchanged.
## Re-pinned, all seven, by Phase 4 P1b (equipment physics) on top of P2/P5 and the kit
## follow-ups: every line-up wears gear (armour soaks, shields, plate is slow, axes split
## shields; the chief now carries a mace) and the weapon action replaces the plain attack, so
## every fight moves on purpose. GEARLESS below proves gear moves numbers, never rolls.
## Re-pinned by Phase 4 P1c (reach: the enemy strikes whatever its weapon reaches): seeds 1, 7,
## 1337 and 31, the watch's fights, move because the watchmen's spears now strike from two
## cells over a friend's shoulder; 424242, 90210 and 2026 (bandits, no spears) are unchanged.
## Seed 9 added by P1c: the watch fight in which the orc's axe still splits a shield.
## Re-pinned by the stall fix (claude/p4-ai-path): seeds 1, 1337, 424242, 90210 and 9 move
## because a walker now picks the cell with the fewest steps to his target around the walls,
## not the nearest in a straight line (the first move that differs sits beside a wall); the
## memory of a foe out of sight moves none of them. 7, 2026 and 31 are unchanged.
const GOLDEN := {
	1: "6cde8c2a5d03e772be1fe1c2b39036ea0c7c3de9f6434e83d17f1c60ac74f4ac",
	7: "9210a2da2567c762a778735a4708c1e68fc6c4d9da8cbdc78012b11cbe1b4820",
	1337: "30ef5f7ffc40a6b70a3604cf0abafecaba4e42689ce218173a53e915ced04907",
	424242: "21cd486b938acdc0016a24f4d915cdb63986719fbcf9e7dabe6c506945ac6f01",
	90210: "a6a6ecb962abb31ddc75062432eeeea458809ba1bb0075d3cbfc90b2bb118957",
	2026: "f2cb429cb889c0d7abe14b9615f77a8df23049e6bfb4f68f6de85e3eee60f35e",
	31: "ae3c9cb57c2012d6d0e46fae3305a48ab114387d3421d8107d9c9d458e258cb7",
	9: "adb75a319d33c1db878e4a2f10e25163106f26dc90f518daa7344b13a9b5c72f",
}
## The same seven fights with every fighter's "gear" taken away hash to main's pins from before
## equipment physics (Phase 4 P1b): gear changes numbers, never the rolls or their order.
## Seeds 1, 7, 1337, 424242 and 90210 re-pinned by the stall fix (the walk round walls, as
## GOLDEN above); 2026 and 31 still hash as before P1b.
const GEARLESS := {
	1: "4272dce176f24f691163c42ba8496df414c701d843f23f946beff11e051ae39a",
	7: "784137f43ce967094ba747ace6e9e54c4a244b85707344c28abacf2e80f94bd9",
	1337: "714f07b4c4d3a744253788438cf8d07dac2e610f2777a7a49ceb7a6d5b576c5b",
	424242: "855147942675c49943a8f2d3d32d52219887a295495479d4158df3f9e115fdbe",
	90210: "3982a519c923999367c4785343db965657cafc57a4fcbe782b3dfe843e72cdc9",
	2026: "5cd2331f919abb9568429914bd493e439fdb776daa16bdcbfc3d3e372cbc4c63",
	31: "ac55cc7c4e59ae637676de3c515542566de606443c76050c5fed73a1103cb975",
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
	_check_gearless()
	var covered := [
		"rout",
		"wipe",
		"charge",
		"blood_price",
		MARK,
		"shaken",
		"ambush",
		"surrender",
		"captain_fall",
		BattleGear.EVENT_SHIELD_BROKEN,
		"spear"
	]
	var all_seen := covered.all(func(key: String) -> bool: return seen.has(key))
	_check.call(
		all_seen,
		(
			"the golden fights cover rout, wipe, both moves, hook, shaken, ambush, surrender, "
			+ "captain's fall, a split shield, a spear's blow"
		)
	)


## Gear changes numbers, never rolls: without gear every fight is main's from before P1b.
func _check_gearless() -> void:
	var same := true
	for seed_value: int in GEARLESS:
		var fight := _fight(seed_value, true)
		var battle: Battle = fight["battle"]
		same = same and _digest(battle) == str(GEARLESS[seed_value])
	_check.call(same, "with every fighter's gear removed the golden fights hash as pinned")


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
func _build(seed_value: int, gearless := false) -> Battle:
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
		var own_data: Dictionary = stats[key]
		var own := _worn(own_data, gearless)
		var at := Vector2i(1 + i % 2, 1 + i)
		fighters.append(BattleUnit.make("c%d" % i, BattleUnit.COMPANY, at, own))
	var band: Array[String] = ["bandit_chief", "bandit"]
	if seed_value % 2 == 1:
		band = ["watch_sergeant", "watchman"]
	for i: int in 6:
		var key: String = band[0] if i == 0 else band[1]
		var theirs_data: Dictionary = stats[key]
		var theirs := _worn(theirs_data, gearless)
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


## A fighter's data, with its "gear" taken away when gearless.
func _worn(fighter: Dictionary, gearless: bool) -> Dictionary:
	if not gearless:
		return fighter
	var bare := fighter.duplicate()
	bare.erase(BattleGear.GEAR_KEY)
	return bare


## A hook that rolls nothing and marks each blow that puts a fighter down.
func _hook(hit: Dictionary) -> Array:
	if hit.get("down") == true:
		return [{"type": MARK, "target": hit["target"]}]
	return []


## Plays a seed's fight to its end; {"battle", "actions"} (the actions the battle accepted).
func _fight(seed_value: int, gearless := false) -> Dictionary:
	var battle := _build(seed_value, gearless)
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
	# The weapon action (the plain attack without a class, P1a): the blood price in its place.
	if fighter.knows(BattleUnit.MOVE_BLOOD_PRICE) and kind == battle.kit(fighter.id)[0]:
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
		elif (
			kind
			in [
				MARK,
				"shaken",
				Battle.EVENT_SURRENDER,
				Battle.EVENT_CAPTAIN_FALL,
				BattleGear.EVENT_SHIELD_BROKEN
			]
		):
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
