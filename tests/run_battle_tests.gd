extends "res://tests/lib/runner.gd"
## Battle suite: the sim core the art direction slice's loop example stands on
## (docs/specs/art_direction_slice.md §2a; sim/core/rng.gd, sim/battle/). Rng streams are
## independent and survive a save; a seeded fight replays to the same event log and another
## seed gives another; moves respect range, walls and other fighters; attacks need an
## adjacent enemy; a hit wounds and a fighter at 0 hp goes down and costs morale (more for a
## leader); low morale surrenders with fighters still standing; the enemy waits when it
## sees no one. Seeded by design: every roll comes from Rng.from_seed with a fixed seed.
##   godot --headless --path . --script tests/run_battle_tests.gd

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const OTHER_SEED := 7
const GRID := Vector2i(10, 8)
const MAX_TURNS := 200
const STREAM_PROBE := 32
const SURE_HIT := 100
const FAR := Vector2i(9, 7)


func suite_name() -> String:
	return "Battle"


func run_checks() -> void:
	_check_rng()
	_check_replay()
	_check_moves()
	_check_attacks()
	_check_morale_and_surrender()
	_check_ai_sight()
	await process_frame


func _rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var rules: Variant = data.get("rules", {})
	return rules if rules is Dictionary else {}


func _check_rng() -> void:
	var a := Rng.from_seed(SEED)
	var b := Rng.from_seed(SEED)
	b.roll("world", 1, SURE_HIT)
	var same := true
	for _i: int in STREAM_PROBE:
		same = same and a.roll(Battle.STREAM, 1, SURE_HIT) == b.roll(Battle.STREAM, 1, SURE_HIT)
	check(same, "a roll on the world stream does not shift the battle stream")
	var saved := a.state()
	var next := a.roll(Battle.STREAM, 1, SURE_HIT)
	var restored := Rng.restore(saved)
	check(
		restored.roll(Battle.STREAM, 1, SURE_HIT) == next,
		"an Rng restored from state() continues exactly"
	)


## Three company fighters against four bandits in the open; both sides played by the AI.
func _skirmish(seed_value: int) -> Battle:
	var fighters: Array[BattleUnit] = []
	var mine := {"hp": 10, "attack": 2, "defense": 2, "damage": 5, "initiative": 3}
	var theirs := {"hp": 8, "attack": 1, "defense": 1, "damage": 4, "initiative": 2}
	for i: int in 3:
		fighters.append(BattleUnit.make("c%d" % i, BattleUnit.COMPANY, Vector2i(1, 2 + i), mine))
	for i: int in 4:
		fighters.append(BattleUnit.make("b%d" % i, BattleUnit.ENEMY, Vector2i(8, 1 + i), theirs))
	fighters[0].is_leader = true
	var battle := Battle.new()
	battle.setup(_rules(), {"size": GRID, "blocked": {}}, fighters, Rng.from_seed(seed_value))
	return battle


func _play_out(battle: Battle) -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	var sight: int = _rules().get("sight_cells", 0)
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		log.append_array(battle.apply(BattleAi.choose(battle, battle.current(), sight)))
	return log


func _check_replay() -> void:
	var first := _skirmish(SEED)
	var log_a := _play_out(first)
	var log_b := _play_out(_skirmish(SEED))
	var log_c := _play_out(_skirmish(OTHER_SEED))
	check(
		first.is_over() and not log_a.is_empty() and str(log_a) == str(log_b),
		"a seeded fight runs to an end and replays to the same event log"
	)
	check(str(log_a) != str(log_c), "another seed gives another fight")


func _check_moves() -> void:
	var battle := _skirmish(SEED)
	var actor := battle.current()
	var start := actor.cell
	var move_cells: int = _rules().get("move_cells", 0)
	var too_far := start + Vector2i(move_cells + 1, 0)
	var rejected := battle.apply({"type": Battle.ACTION_MOVE, "to": too_far}).is_empty()
	var onto_ally := (
		battle.apply({"type": Battle.ACTION_MOVE, "to": start + Vector2i.DOWN}).is_empty()
	)
	var blocked := Battle.new()
	var lone: Array[BattleUnit] = [BattleUnit.make("x", BattleUnit.COMPANY, Vector2i.ZERO, {})]
	blocked.setup(
		_rules(), {"size": GRID, "blocked": {Vector2i(1, 0): true}}, lone, Rng.from_seed(SEED)
	)
	var into_wall := not blocked.reachable(lone[0]).has(Vector2i(1, 0))
	var moved := battle.apply({"type": Battle.ACTION_MOVE, "to": start + Vector2i.RIGHT})
	check(
		(
			rejected
			and onto_ally
			and into_wall
			and not moved.is_empty()
			and actor.cell == start + Vector2i.RIGHT
		),
		"a move goes only to free cells within move_cells, never into walls or other fighters"
	)


func _check_attacks() -> void:
	var battle := _skirmish(SEED)
	var actor := battle.current()
	var far_target := battle.unit("b0")
	check(
		battle.apply({"type": Battle.ACTION_ATTACK, "target": far_target.id}).is_empty(),
		"an attack on an enemy who is not adjacent is refused"
	)
	far_target.cell = actor.cell + Vector2i.RIGHT
	actor.attack = SURE_HIT
	far_target.hp = 1
	var events := battle.apply({"type": Battle.ACTION_ATTACK, "target": far_target.id})
	var kinds: Array = events.map(func(e: Dictionary) -> String: return str(e.get("type", "")))
	check(
		far_target.down and far_target.wounded and kinds.has("down") and kinds.has("morale"),
		"a hit to 0 hp wounds the target, downs them and costs their side morale (%s)" % [kinds]
	)


func _check_morale_and_surrender() -> void:
	var rules := _rules()
	var battle := _skirmish(SEED)
	var start: int = battle.morale(BattleUnit.COMPANY)
	var leader := battle.unit("c0")
	var bandit := battle.unit("b0")
	bandit.cell = leader.cell + Vector2i.RIGHT
	while battle.current() != bandit:
		battle.apply({"type": Battle.ACTION_WAIT})
	bandit.attack = SURE_HIT
	leader.hp = 1
	battle.apply({"type": Battle.ACTION_ATTACK, "target": leader.id})
	var lost: int = start - battle.morale(BattleUnit.COMPANY)
	var leader_loss: int = rules.get("morale_loss_leader_down", 0)
	check(
		lost == leader_loss and leader.down,
		"the leader going down costs the leader's morale loss (%d), not %d" % [leader_loss, lost]
	)
	_check_surrender(rules, leader_loss)


## A shaken band starts just above surrender, so losing its leader breaks it while one
## bandit still stands.
func _check_surrender(rules: Dictionary, leader_loss: int) -> void:
	var shaken := rules.duplicate()
	var surrender_below: int = rules.get("surrender_below", 0)
	shaken["morale_start"] = surrender_below + leader_loss - 1
	var surrender := Battle.new()
	var pair: Array[BattleUnit] = [
		BattleUnit.make(
			"c",
			BattleUnit.COMPANY,
			Vector2i(0, 0),
			{"attack": SURE_HIT, "damage": SURE_HIT, "initiative": 2}
		),
		BattleUnit.make("b1", BattleUnit.ENEMY, Vector2i(1, 0), {"hp": 1}),
		BattleUnit.make("b2", BattleUnit.ENEMY, Vector2i(5, 5), {"hp": 1}),
	]
	pair[1].is_leader = true
	surrender.setup(shaken, {"size": GRID, "blocked": {}}, pair, Rng.from_seed(SEED))
	var events := surrender.apply({"type": Battle.ACTION_ATTACK, "target": "b1"})
	var surrendered := events.any(func(e: Dictionary) -> bool: return e.get("type") == "surrender")
	check(
		(
			surrendered
			and surrender.is_over()
			and surrender.surrendered == BattleUnit.ENEMY
			and not surrender.unit("b2").down
		),
		"a side whose morale falls below surrender_below surrenders with a fighter still standing"
	)


func _check_ai_sight() -> void:
	var battle := Battle.new()
	var pair: Array[BattleUnit] = [
		BattleUnit.make("b", BattleUnit.ENEMY, Vector2i.ZERO, {"initiative": 2}),
		BattleUnit.make("c", BattleUnit.COMPANY, FAR, {}),
	]
	battle.setup(_rules(), {"size": GRID + Vector2i(SURE_HIT, SURE_HIT)}, pair, Rng.from_seed(SEED))
	var blind := BattleAi.choose(battle, pair[0], 1)
	var seeing := BattleAi.choose(battle, pair[0], SURE_HIT)
	check(
		(
			str(blind.get("type")) == Battle.ACTION_WAIT
			and str(seeing.get("type")) == Battle.ACTION_MOVE
		),
		"the enemy waits when it sees no one and closes in when it does (not psychic)"
	)
