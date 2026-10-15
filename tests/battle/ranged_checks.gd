extends RefCounted
## The battle suite's reach checks (Phase 4 P1c; director 2026-10-16: "Build ranged next",
## spears "Yes, 2 cells", hit over a friend's shoulder), run by tests/run_battle_tests.gd: the
## straight line between two cells (BattleGrid.line_clear) is stopped by walls and props, never
## by a fighter, and reads the same both ways; a diagonal step between two walls is stopped,
## as a man's step is (a corner gap, a staircase wall); a bow shoots a foe within its reach
## (battle.json "rules" "actions" "weapon" "bow" "reach") over anyone's head, refused past it or
## through a wall; a spear strikes over an ally's shoulder two cells off, never through a wall;
## Battle.targets names exactly the foes the weapon action can strike now; the enemy shoots
## and thrusts from reach at what it sees and never at what it cannot (rule 6); a bow fight
## replays through FightRecord. Seeded by design: every roll comes from Rng.from_seed(SEED).

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const GRID := Vector2i(12, 8)
const SURE_HIT := 100
const MAX_TURNS := 200
const ROW := 3

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_lines()
	_check_corners()
	_check_bow_reach()
	_check_bow_walls()
	_check_spear_over_ally()
	_check_targets()
	_check_ai_shoots_what_it_sees()
	_check_replay()


func _rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var rules: Variant = data.get("rules", {})
	return rules if rules is Dictionary else {}


func _bow_reach() -> int:
	var rules := BattleRules.new()
	rules.setup(_rules())
	return rules.reach("bow")


func _battle(fighters: Array[BattleUnit], blocked: Dictionary) -> Battle:
	var battle := Battle.new()
	battle.setup(_rules(), {"size": GRID, "blocked": blocked}, fighters, Rng.from_seed(SEED))
	return battle


func _armed(unit_id: String, side: int, at: Vector2i, weapon: String) -> BattleUnit:
	var fighter := BattleUnit.make(unit_id, side, at, {"initiative": 9, "hp": SURE_HIT})
	fighter.weapon_class = weapon
	return fighter


func _target(at: Vector2i) -> BattleUnit:
	return BattleUnit.make("b", BattleUnit.ENEMY, at, {"hp": SURE_HIT, "initiative": 1})


## True when the weapon action on "b" was taken (an attack event first), false when refused.
func _struck(battle: Battle, kind: String) -> bool:
	var events := battle.apply({"type": kind, "target": "b"})
	return not events.is_empty() and events[0].get("type") == "attack"


func _check_lines() -> void:
	var grid := BattleGrid.new()
	var wall := Vector2i(3, ROW)
	grid.setup({"size": GRID, "blocked": {wall: true}})
	var a := Vector2i(1, ROW)
	var straight_blocked := not grid.line_clear(a, Vector2i(6, ROW))
	var around := grid.line_clear(a, Vector2i(6, ROW + 2))
	var beside := grid.line_clear(Vector2i(2, ROW), Vector2i(4, ROW + 1))
	var both_ways := (
		grid.line_clear(Vector2i(2, ROW), Vector2i(4, ROW + 1))
		== grid.line_clear(Vector2i(4, ROW + 1), Vector2i(2, ROW))
	)
	var corner := {Vector2i(3, ROW): true, Vector2i(3, ROW + 1): true}
	grid.setup({"size": GRID, "blocked": corner})
	var squeezed := not grid.line_clear(Vector2i(2, ROW), Vector2i(4, ROW + 1))
	var next_to := grid.line_clear(Vector2i(2, ROW), Vector2i(3, ROW + 2))
	_check.call(
		straight_blocked and around and beside and both_ways and squeezed and next_to,
		(
			"a wall stops the straight line through it, not one past it; a line run exactly "
			+ (
				"between two cells passes if either is open and reads the same both ways: %s"
				% [[straight_blocked, around, beside, both_ways, squeezed, next_to]]
			)
		)
	)


## Lead's ruling on review of #139: a diagonal step of the line between two walls (both side
## cells walled, the rule BattleGrid.steps_from holds a man to) stops it: a corner gap, a
## staircase wall. One side open lets it through, as it lets a man.
func _check_corners() -> void:
	var grid := BattleGrid.new()
	grid.setup({"size": GRID, "blocked": {Vector2i(2, 1): true, Vector2i(1, 2): true}})
	var gap_shut := not grid.line_clear(Vector2i(1, 1), Vector2i(3, 3))
	var gap_back := not grid.line_clear(Vector2i(3, 3), Vector2i(1, 1))
	grid.setup({"size": GRID, "blocked": {Vector2i(2, 1): true}})
	var one_open := grid.line_clear(Vector2i(1, 1), Vector2i(3, 3))
	var stairs := {}
	for i: int in 6:
		stairs[Vector2i(5 - i, i)] = true
	grid.setup({"size": GRID, "blocked": stairs})
	var stairs_shut := not grid.line_clear(Vector2i(1, 1), Vector2i(4, 4))
	var archer := _armed("c", BattleUnit.COMPANY, Vector2i(1, 1), "bow")
	var shot := _struck(_battle([archer, _target(Vector2i(4, 4))], stairs), "bow")
	_check.call(
		gap_shut and gap_back and one_open and stairs_shut and not shot,
		(
			"a line through a corner gap or a staircase wall is stopped both ways, one open side "
			+ (
				"lets it pass, and the bow's shot through the stairs is refused: %s"
				% [[gap_shut, gap_back, one_open, stairs_shut, not shot]]
			)
		)
	)


## The bow reaches its reach in data over a friend's and a foe's head, and not one cell more.
func _check_bow_reach() -> void:
	var far := _bow_reach()
	var results: Array[bool] = []
	for gap: int in [1, 2, far, far + 1]:
		var archer := _armed("c", BattleUnit.COMPANY, Vector2i(1, ROW), "bow")
		var friend := _armed("f", BattleUnit.COMPANY, Vector2i(2, ROW), "sword")
		var foe := _armed("e", BattleUnit.ENEMY, Vector2i(3, ROW), "sword")
		var fighters: Array[BattleUnit] = [archer, _target(Vector2i(1 + gap, ROW)), friend, foe]
		if gap <= 2:
			fighters = [archer, _target(Vector2i(1 + gap, ROW))]
		results.append(_struck(_battle(fighters, {}), "bow") == (gap <= far))
	_check.call(
		far > 2 and results.all(func(ok: bool) -> bool: return ok),
		(
			"a bow shoots a foe from 1 to its reach (%d) cells, over heads, not one more: %s"
			% [far, results]
		)
	)


## Failing first: the same shot lands in the open and is refused with a wall in its line.
func _check_bow_walls() -> void:
	var open := _battle(
		[_armed("c", BattleUnit.COMPANY, Vector2i(1, ROW), "bow"), _target(Vector2i(5, ROW))], {}
	)
	var walled := _battle(
		[_armed("c", BattleUnit.COMPANY, Vector2i(1, ROW), "bow"), _target(Vector2i(5, ROW))],
		{Vector2i(3, ROW): true}
	)
	var log_before := walled.log.size()
	var lands := _struck(open, "bow")
	var refused := not _struck(walled, "bow") and walled.log.size() == log_before
	_check.call(
		lands and refused,
		(
			"a bow's shot lands in the open and a wall in its line refuses it whole: %s"
			% [[lands, refused]]
		)
	)


## A spearman behind a friend strikes the foe the friend faces; a wall between stops him.
func _check_spear_over_ally() -> void:
	var results: Array[bool] = []
	for walled: bool in [false, true]:
		var spear := _armed("c", BattleUnit.COMPANY, Vector2i(2, ROW), "spear")
		var friend_at := Vector2i(3, ROW + 1) if walled else Vector2i(3, ROW)
		var friend := _armed("f", BattleUnit.COMPANY, friend_at, "sword")
		friend.initiative = 1
		var blocked := {Vector2i(3, ROW): true} if walled else {}
		var fighters: Array[BattleUnit] = [spear, friend, _target(Vector2i(4, ROW))]
		results.append(_struck(_battle(fighters, blocked), "spear") == (not walled))
	_check.call(
		results.all(func(ok: bool) -> bool: return ok),
		"a spear strikes over a friend's shoulder two cells off, not through a wall: %s" % [results]
	)


## Battle.targets: the foes the fighter's weapon action strikes from where he stands.
func _check_targets() -> void:
	var archer := _armed("c", BattleUnit.COMPANY, Vector2i(1, ROW), "bow")
	var swordsman := _armed("s", BattleUnit.COMPANY, Vector2i(1, ROW + 3), "sword")
	swordsman.initiative = 1
	var shot := _target(Vector2i(4, ROW))
	var hidden := BattleUnit.make("h", BattleUnit.ENEMY, Vector2i(4, 1), {})
	var beside := BattleUnit.make("n", BattleUnit.ENEMY, Vector2i(2, ROW + 3), {})
	var far := BattleUnit.make("x", BattleUnit.ENEMY, Vector2i(GRID.x - 1, ROW), {})
	var fighters: Array[BattleUnit] = [archer, swordsman, shot, hidden, beside, far]
	var battle := _battle(fighters, {Vector2i(2, 2): true, Vector2i(3, 2): true})
	var mine := battle.targets("c")
	var sword := battle.targets("s")
	_check.call(
		mine == ["b", "n"] and sword == ["n"] and battle.targets("nobody").is_empty(),
		"targets lists the foes in reach and in line (archer %s, swordsman %s)" % [mine, sword]
	)


## An enemy archer shoots a merc it sees from reach rather than walking; one whose sight is
## shorter than the gap does not shoot (rule 6: the AI is not psychic). The battle's own
## sight_cells is the same, so the archer who never saw him has no memory of him either.
func _check_ai_shoots_what_it_sees() -> void:
	var results: Array[String] = []
	for sight: int in [GRID.x, 3]:
		var archer := _armed("e", BattleUnit.ENEMY, Vector2i(6, ROW), "bow")
		var merc := BattleUnit.make("m", BattleUnit.COMPANY, Vector2i(1, ROW), {"initiative": 1})
		var rules := _rules()
		rules["sight_cells"] = sight
		var fighters: Array[BattleUnit] = [archer, merc]
		var battle := Battle.new()
		battle.setup(rules, {"size": GRID, "blocked": {}}, fighters, Rng.from_seed(SEED))
		results.append(str(BattleAi.choose(battle, archer, sight).get("type", "")))
	(
		_check
		. call(
			results[0] == "bow" and results[1] == Battle.ACTION_WAIT,
			(
				"an enemy archer shoots a merc it sees from five cells and holds when it cannot see him: %s"
				% [results]
			)
		)
	)


## A seeded fight with archers and spearmen played by BattleAi replays through FightRecord.
func _check_replay() -> void:
	var played := _skirmish()
	var battle: Battle = played["battle"]
	var actions: Array[Dictionary] = played["actions"]
	var again := _skirmish_setup()
	var record := FightRecord.make({}, actions)
	var through: Variant = JSON.parse_string(JSON.stringify(record.saved()))
	var saved: Dictionary = through if through is Dictionary else {}
	var applied := FightRecord.replay(again, FightRecord.read(saved))
	var shots := battle.log.filter(
		func(e: Dictionary) -> bool: return e.get("type") == "attack" and e.get("move") == "bow"
	)
	_check.call(
		(
			not shots.is_empty()
			and applied == actions.size()
			and JSON.stringify(again.log) == JSON.stringify(battle.log)
		),
		"a fight with %d bow shots replays through FightRecord to the same log" % shots.size()
	)


func _skirmish_setup() -> Battle:
	var fighters: Array[BattleUnit] = [
		_armed("c0", BattleUnit.COMPANY, Vector2i(1, 2), "bow"),
		_armed("c1", BattleUnit.COMPANY, Vector2i(2, 3), "sword"),
		_armed("c2", BattleUnit.COMPANY, Vector2i(1, 3), "spear"),
		_armed("e0", BattleUnit.ENEMY, Vector2i(9, 2), "bow"),
		_armed("e1", BattleUnit.ENEMY, Vector2i(8, 3), "axe"),
	]
	for fighter: BattleUnit in fighters:
		fighter.hp = 10
		fighter.max_hp = 10
	return _battle(fighters, {Vector2i(5, 1): true})


func _skirmish() -> Dictionary:
	var battle := _skirmish_setup()
	var actions: Array[Dictionary] = []
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		var applied := BattleAi.act(battle, battle.current(), GRID.x)
		if applied.is_empty():
			break
		actions.append(applied)
	return {"battle": battle, "actions": actions}
