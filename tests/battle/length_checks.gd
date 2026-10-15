extends RefCounted
## The battle suite's fight-length audit, run by tests/run_battle_tests.gd: no fight stalls.
## battle.json "fight_length" holds how many seeded fights to play and the most actions one
## may take. Each fight is a random 4 v 4 on a 12 x 8 street with random walls, every weapon
## class mixed in, both sides deployed within sight of a foe (as every scenario is, a data
## check), the enemy played by BattleAi and the company by MercPlay; every one must end inside
## the cap. Before the fix (review of #139) some stalled: a fighter behind a wall found no
## straight step closer and waited forever, and one who lost sight of every foe waited too.
## Two small scenes pin the two rules that fixed it: the walk goes round a wall, and a
## fighter who lost sight walks to where he last saw a foe. A data check holds the third: every
## authored deployment (scenarios.json, encounters.json) starts each fighter within sight of a
## foe, because one who has never seen a foe holds.
## Seeded by design: fight n is set up and rolled from FIRST_SEED + n.

const BATTLE_DATA := "res://data/balance/battle.json"
const SCENARIOS := "res://data/scenarios.json"
const ENCOUNTERS := "res://data/encounters.json"
## The scenario's company deployments: the slice's own pair, and the road's six in order.
const COMPANY_KEYS: Array[String] = ["company_cells", "road_cells"]
const FIRST_SEED := 1000
const GRID := Vector2i(12, 8)
const SIDE_SIZE := 4
## Deployment columns: the company on the left, the enemy on the right, never further apart
## than sight_cells (8), so everyone starts seeing a foe.
const COMPANY_COLUMNS := Vector2i(1, 2)
const ENEMY_COLUMNS := Vector2i(7, 9)
const WALL_COLUMNS := Vector2i(3, 8)
const WALLS := 8
const FIGHTER_HP := 8
const INITIATIVE := Vector2i(1, 9)
const WEAPONS: Array[String] = ["bow", "spear", "sword", "axe", "mace"]
## The wall scene: a watchman behind a wall from the field's edge, his foe straight beyond it;
## the way round is longer than one walk, so no straight step gets closer.
const WALL_FIELD := Vector2i(9, 8)
const WALL_CELLS: Array[Vector2i] = [
	Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)
]
const BEHIND := Vector2i(3, 2)
const BEYOND := Vector2i(6, 2)
## The memory scene: a long street, the enemy at one end, the company archer stepping away.
const LONG_FIELD := Vector2i(20, 3)
const WATCHER := Vector2i(1, 1)
const SEEN_AT := Vector2i(8, 1)
## Past sight_cells (8) from where he was seen, so the watchman there sees him no more.
const GONE_TO := Vector2i(17, 1)

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_no_fight_stalls()
	_check_deployments_in_sight()
	_check_walks_round_a_wall()
	_check_walks_to_last_seen()


func _data() -> Dictionary:
	return _json(BATTLE_DATA)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _rules() -> Dictionary:
	var rules: Variant = _data().get("rules", {})
	return rules if rules is Dictionary else {}


func _check_no_fight_stalls() -> void:
	var audit: Dictionary = _data().get("fight_length", {})
	var fights: int = audit.get("fights", 0)
	var cap: int = audit.get("turn_cap", 0)
	var rules := _rules()
	var sight := BattleRules.read(rules, "sight_cells")
	var stalled: Array[int] = []
	var blind_starts: Array[int] = []
	for n: int in fights:
		var battle := _random_fight(rules, FIRST_SEED + n)
		if not _everyone_sees_a_foe(battle, sight):
			blind_starts.append(FIRST_SEED + n)
		for _turn: int in cap:
			if battle.is_over():
				break
			var actor := battle.current()
			var choice: Dictionary
			if actor.side == BattleUnit.ENEMY:
				choice = BattleAi.choose(battle, actor, sight)
			else:
				choice = MercPlay.choose(battle, actor, rules)
			if battle.apply(choice).is_empty():
				battle.apply({"type": Battle.ACTION_WAIT})
		if not battle.is_over():
			stalled.append(FIRST_SEED + n)
	var ended := fights > 0 and cap > 0 and blind_starts.is_empty() and stalled.is_empty()
	var said := (
		"all %d seeded random fights on a walled street end within %d actions" % [fights, cap]
	)
	_check.call(ended, "%s (stalled seeds %s; blind starts %s)" % [said, stalled, blind_starts])


## Fight seed: SIDE_SIZE a side on free cells of their columns, random walls between, a random
## weapon each; set up and rolled from the same seed.
func _random_fight(rules: Dictionary, seed_value: int) -> Battle:
	var rng := Rng.from_seed(seed_value)
	var taken := {}
	var fighters: Array[BattleUnit] = []
	for side: int in BattleUnit.SIDES:
		var columns := COMPANY_COLUMNS if side == BattleUnit.COMPANY else ENEMY_COLUMNS
		for i: int in SIDE_SIZE:
			var at := Vector2i(rng.roll("p", columns.x, columns.y), rng.roll("p", 0, GRID.y - 1))
			while taken.has(at):
				at = Vector2i(rng.roll("p", columns.x, columns.y), rng.roll("p", 0, GRID.y - 1))
			taken[at] = true
			fighters.append(_fighter(rng, side, i, at))
	var walls := {}
	for _w: int in WALLS:
		var cell := Vector2i(rng.roll("w", WALL_COLUMNS.x, WALL_COLUMNS.y), rng.roll("w", 0, 7))
		if not taken.has(cell):
			walls[cell] = true
	var battle := Battle.new()
	battle.setup(rules, {"size": GRID, "blocked": walls}, fighters, Rng.from_seed(seed_value))
	return battle


func _fighter(rng: Rng, side: int, index: int, at: Vector2i) -> BattleUnit:
	var prefix := "c" if side == BattleUnit.COMPANY else "e"
	var stats := {"hp": FIGHTER_HP, "initiative": rng.roll("i", INITIATIVE.x, INITIATIVE.y)}
	var fighter := BattleUnit.make("%s%d" % [prefix, index], side, at, stats)
	fighter.max_hp = FIGHTER_HP
	fighter.weapon_class = WEAPONS[rng.roll("k", 0, WEAPONS.size() - 1)]
	return fighter


func _everyone_sees_a_foe(battle: Battle, sight: int) -> bool:
	for fighter: BattleUnit in battle.units:
		if BattleKnowledge.seen(battle, fighter, sight).is_empty():
			return false
	return true


func _pair(field: Vector2i, walls: Dictionary, enemy_at: Vector2i, foe_at: Vector2i) -> Battle:
	var fighters: Array[BattleUnit] = [
		BattleUnit.make("e", BattleUnit.ENEMY, enemy_at, {"initiative": 2}),
		BattleUnit.make("c", BattleUnit.COMPANY, foe_at, {"initiative": 1}),
	]
	var battle := Battle.new()
	battle.setup(_rules(), {"size": field, "blocked": walls}, fighters, Rng.from_seed(FIRST_SEED))
	return battle


## Every straight step from behind the wall is no closer to the foe (the old walk waited
## there for ever); the fewest-steps walk goes round the wall's end.
func _check_walks_round_a_wall() -> void:
	var walls := {}
	for cell: Vector2i in WALL_CELLS:
		walls[cell] = true
	var battle := _pair(WALL_FIELD, walls, BEHIND, BEYOND)
	var watchman := battle.unit("e")
	var choice := BattleAi.choose(battle, watchman, BattleRules.read(_rules(), "sight_cells"))
	var to: Vector2i = choice.get("to", BEHIND)
	_check.call(
		str(choice.get("type")) == Battle.ACTION_MOVE and to.y > BEHIND.y,
		(
			"an enemy behind a wall walks round its end toward the foe, not stand waiting (%s)"
			% [choice]
		)
	)


## The archer walks out of sight; the watchman, who saw him, walks to where he saw him, and
## holds once he finds the spot empty. One who never saw a foe holds (the lead's ruling A).
func _check_walks_to_last_seen() -> void:
	var sight := BattleRules.read(_rules(), "sight_cells")
	var battle := _pair(LONG_FIELD, {}, WATCHER, SEEN_AT)
	var watchman := battle.unit("e")
	var archer := battle.unit("c")
	var saw := watchman.last_seen
	battle.apply({"type": Battle.ACTION_WAIT})
	archer.cell = GONE_TO
	battle.apply({"type": Battle.ACTION_WAIT})
	var lost := BattleKnowledge.seen(battle, watchman, sight).is_empty()
	var choice := BattleAi.choose(battle, watchman, sight)
	watchman.cell = SEEN_AT
	BattleKnowledge.remember(battle, sight)
	var after := BattleAi.choose(battle, watchman, sight)
	_check.call(
		(
			saw == SEEN_AT
			and lost
			and str(choice.get("type")) == Battle.ACTION_MOVE
			and watchman.last_seen == BattleUnit.NOWHERE
			and str(after.get("type")) == Battle.ACTION_WAIT
		),
		(
			"an enemy who lost sight walks to where he last saw a foe (%s), then holds there (%s)"
			% [choice, after]
		)
	)


## Every authored deployment starts with each fighter seeing a foe (sight_cells): the slice's
## fight (with and without its lookout) and every encounter line-up, against the company on
## the first one to all of its cells. A fighter who has never seen a foe holds (the lead's
## ruling, 2026-10-16), so a blind start would be a fight that never begins.
func _check_deployments_in_sight() -> void:
	var sight := BattleRules.read(_rules(), "sight_cells")
	var lineups: Array[Array] = []
	for encounter: Dictionary in _list(_json(ENCOUNTERS), "encounters"):
		for lineup: Array in _list(encounter, "lineups"):
			lineups.append(lineup)
	var blind: Array[String] = []
	var checked := 0
	for scenario: Dictionary in _list(_json(SCENARIOS), "scenarios"):
		var setup: Dictionary = scenario.get("battle", {})
		var own := _list(setup, "enemies")
		var with_lookout := own.duplicate()
		with_lookout.append(setup.get("lookout", {}))
		var sides: Array[Array] = [own, with_lookout]
		sides.append_array(lineups)
		for key: String in COMPANY_KEYS:
			var company := _cells(_list(setup, key))
			for enemies: Array in sides:
				blind.append_array(_blind(company, _cells(_placed(enemies)), sight))
				checked += company.size()
	var said := "every authored deployment (%d) starts each fighter in sight of a foe" % checked
	_check.call(checked > 0 and blind.is_empty(), "%s (%d cells; blind %s)" % [said, sight, blind])


## The company stood on its first n cells, for every n: who sees no foe.
func _blind(company: Array[Vector2i], foes: Array[Vector2i], sight: int) -> Array[String]:
	var out: Array[String] = []
	for n: int in range(1, company.size() + 1):
		var deployed := company.slice(0, n)
		for cell: Vector2i in deployed:
			if not _sees_one(cell, foes, sight):
				out.append("company %s of %d vs %s" % [cell, n, foes])
		for cell: Vector2i in foes:
			if not _sees_one(cell, deployed, sight):
				out.append("enemy %s vs company of %d" % [cell, n])
	return out


func _sees_one(from: Vector2i, others: Array[Vector2i], sight: int) -> bool:
	for other: Vector2i in others:
		if BattleGrid.gap(from, other) <= sight:
			return true
	return false


func _cells(entries: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for entry: Variant in entries:
		var pair: Array = entry if entry is Array else []
		if pair.size() == 2:
			out.append(Vector2i(int(str(pair[0])), int(str(pair[1]))))
	return out


## The cells of a list of {"fighter", "cell"} placements.
func _placed(enemies: Array) -> Array:
	var out: Array = []
	for entry: Variant in enemies:
		var placement: Dictionary = entry if entry is Dictionary else {}
		out.append(placement.get("cell", []))
	return out


func _list(block: Dictionary, key: String) -> Array:
	var read: Variant = block.get(key, [])
	return read if read is Array else []
