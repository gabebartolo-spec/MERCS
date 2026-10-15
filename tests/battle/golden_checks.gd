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
const GOLDEN := {
	1: "27b1856d92bcf510c9944a68fea785ae59693e8c6742395d3b9f90e19597ed24",
	7: "0105597e7e6401adf60e7c300551a30b0ddfeb8495e72e44cc119180d712c56f",
	1337: "b3c52e1c0ef44ef3c93cdefa8f7d25487f0820bc0a5da8077963acf607ba3671",
	424242: "bf3230ebe0f05c1c125434487cc22361175371a00855f470d2d66a0fe74de4d7",
	90210: "f27a6f66edc03844567d284ffc0f6913bc2766dc4a6d1f2ec15c8495d674168e",
	2026: "f2cb429cb889c0d7abe14b9615f77a8df23049e6bfb4f68f6de85e3eee60f35e",
	31: "5ad182d7120fcb7398d00848f21169381697c88b7bd587e06ca761e831cf7ad0",
}
## The same seven fights with every fighter's "gear" taken away hash to main's pins from before
## equipment physics (Phase 4 P1b): gear changes numbers, never the rolls or their order.
const GEARLESS := {
	1: "3299931e9bdb761e4059482a56a893ea1cc7edd80068325ddfa4b3cd166c509c",
	7: "7568529f025b8ea2c47b985b30b29e5e221424b06cd42bfa23c4783ec7ef2150",
	1337: "036b27068c601f3442f239d5e186a8064d14023fd0d74b38c96996d091f1b538",
	424242: "a1b6cca7a1fba6c46516214e263cf2c1ccd37ecdd2b1ed581c583549305f43b3",
	90210: "99c70224e351a57618f1687ead0e8d972c3cfa1901fbebb269198a1ab91b87a9",
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
		BattleGear.EVENT_SHIELD_BROKEN
	]
	var all_seen := covered.all(func(key: String) -> bool: return seen.has(key))
	_check.call(
		all_seen,
		(
			"the golden fights cover rout, wipe, both moves, hook, shaken, ambush, surrender, "
			+ "captain's fall, a split shield"
		)
	)


## Gear changes numbers, never rolls: without gear every fight is main's from before P1b.
func _check_gearless() -> void:
	var same := true
	for seed_value: int in GEARLESS:
		var fight := _fight(seed_value, true)
		var battle: Battle = fight["battle"]
		same = same and _digest(battle) == str(GEARLESS[seed_value])
	_check.call(same, "with every fighter's gear removed the golden fights hash as before P1b")


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
