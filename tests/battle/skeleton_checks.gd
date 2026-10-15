extends RefCounted
## The battle suite's Phase 2 milestone 4 checks (D-064, D-066), run by
## tests/run_battle_tests.gd: eight facings; the turn order presentation reads; rounds and
## the enemy's intent, planned from what it sees and kept when it acts; the four-move
## loadout; the hit event and its hook; blocking (the one terrain feature); shaken before
## rout; the whole event log. Seeded by design: every roll comes from Rng.from_seed(SEED).

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const GRID := Vector2i(10, 8)
const WIDE := Vector2i(40, 40)
const FAR_CELL := Vector2i(30, 30)
const SURE_HIT := 100
const MAX_TURNS := 200

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_facing()
	_check_turn_order()
	_check_intent()
	_check_ai_keeps_plan()
	_check_loadout()
	_check_hit_hook()
	_check_blocking()
	_check_shaken()
	_check_log()


func _rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var rules: Variant = data.get("rules", {})
	return rules if rules is Dictionary else {}


func _battle(fighters: Array[BattleUnit], size: Vector2i) -> Battle:
	var battle := Battle.new()
	battle.setup(_rules(), {"size": size, "blocked": {}}, fighters, Rng.from_seed(SEED))
	return battle


func _unit(unit_id: String, side: int, at: Vector2i, stats: Dictionary) -> BattleUnit:
	return BattleUnit.make(unit_id, side, at, stats)


func _types(events: Array[Dictionary]) -> Array:
	return events.map(func(e: Dictionary) -> String: return str(e.get("type", "")))


func _check_facing() -> void:
	var c := _unit("c", BattleUnit.COMPANY, Vector2i(1, 1), {"initiative": 2, "attack": SURE_HIT})
	var b := _unit("b", BattleUnit.ENEMY, Vector2i(4, 3), {"hp": SURE_HIT})
	var battle := _battle([c, b], GRID)
	var start_ok := c.facing == Vector2i(1, 1) and b.facing == Vector2i(-1, -1)
	var walked := battle.apply({"type": Battle.ACTION_MOVE, "to": Vector2i(3, 3)})
	var after_walk := c.facing
	battle.apply({"type": Battle.ACTION_WAIT})
	var struck := battle.apply({"type": Battle.ACTION_ATTACK, "target": "b"})
	var told: bool = walked[0].get("facing") == after_walk and struck[0].get("facing") == c.facing
	_check.call(
		(
			start_ok
			and after_walk == Vector2i(1, 1)
			and c.facing == Vector2i.RIGHT
			and BattleUnit.FACINGS.has(b.facing)
			and BattleUnit.FACINGS.size() == 8
			and told
		),
		"a fighter faces the nearest foe, then along each walk and at each target, one of eight"
	)


func _check_turn_order() -> void:
	var fighters: Array[BattleUnit] = []
	for i: int in 2:
		fighters.append(_unit("c%d" % i, BattleUnit.COMPANY, Vector2i(1, i), {"initiative": 3}))
		fighters.append(_unit("b%d" % i, BattleUnit.ENEMY, Vector2i(8, i), {"initiative": 2}))
	var battle := _battle(fighters, GRID)
	var first := _order_ids(battle)
	battle.apply({"type": Battle.ACTION_WAIT})
	var second := _order_ids(battle)
	battle.unit("b1").down = true
	var third := _order_ids(battle)
	_check.call(
		first == "c0,c1,b0,b1" and second == "c1,b0,b1,c0" and third == "c1,b0,c0",
		(
			"the turn order reads ahead from the current fighter, each standing one once (%s|%s|%s)"
			% [first, second, third]
		)
	)


func _order_ids(battle: Battle) -> String:
	var ids: Array[String] = []
	for fighter: BattleUnit in battle.turn_order():
		ids.append(fighter.id)
	return ",".join(ids)


## e1 stands beside a sturdy and a hurt company fighter; e2 sees them from afar; e3 sees no
## one. Company fighters act first; e1 acts, its plan is spent; the next round re-plans.
func _check_intent() -> void:
	var fast := {"initiative": 5, "hp": 10}
	var fighters: Array[BattleUnit] = [
		_unit("ca", BattleUnit.COMPANY, Vector2i(3, 1), fast),
		_unit("cb", BattleUnit.COMPANY, Vector2i(5, 2), {"initiative": 5, "hp": 4}),
		_unit("e1", BattleUnit.ENEMY, Vector2i(4, 1), {"initiative": 1}),
		_unit("e2", BattleUnit.ENEMY, Vector2i(8, 6), {"initiative": 1}),
		_unit("e3", BattleUnit.ENEMY, FAR_CELL, {"initiative": 1}),
	]
	var battle := _battle(fighters, WIDE)
	var plans := "%s %s %s" % [_plan(battle, "e1"), _plan(battle, "e2"), _plan(battle, "e3")]
	var planned := plans == "attack:cb advance:cb hold:" and battle.round_number == 1
	battle.apply({"type": Battle.ACTION_WAIT})
	battle.apply({"type": Battle.ACTION_WAIT})
	var sight: int = _rules().get("sight_cells", 0)
	var acted := battle.apply(BattleAi.choose(battle, battle.current(), sight))
	var spent := battle.intent("e1").is_empty() and battle.intents().size() == 2
	battle.apply({"type": Battle.ACTION_WAIT})
	var turned := battle.apply({"type": Battle.ACTION_WAIT})
	var replanned := battle.round_number == 2 and _types(turned).count(Battle.EVENT_INTENT) == 3
	_check.call(
		planned and acted[0].get("target") == "cb" and spent and replanned,
		"each enemy plans its round from what it sees (%s); acting spends it; rounds replan" % plans
	)


func _plan(battle: Battle, unit_id: String) -> String:
	var plan := battle.intent(unit_id)
	return "%s:%s" % [plan.get("kind", ""), plan.get("target", "")]


## The enemy plans to advance on the closest fighter; that fighter steps back so another is
## now closer; on its turn the enemy still walks towards the one it planned for.
func _check_ai_keeps_plan() -> void:
	var fighters: Array[BattleUnit] = [
		_unit("x", BattleUnit.COMPANY, Vector2i(4, 1), {"initiative": 5}),
		_unit("y", BattleUnit.COMPANY, Vector2i(8, 6), {"initiative": 4}),
		_unit("e", BattleUnit.ENEMY, Vector2i(8, 1), {"initiative": 1}),
	]
	var battle := _battle(fighters, GRID)
	var planned := _plan(battle, "e")
	battle.apply({"type": Battle.ACTION_MOVE, "to": Vector2i(1, 1)})
	battle.apply({"type": Battle.ACTION_WAIT})
	var sight: int = _rules().get("sight_cells", 0)
	var choice := BattleAi.choose(battle, battle.current(), sight)
	var to: Vector2i = choice.get("to", Vector2i(8, 1))
	var x := battle.unit("x").cell
	var y := battle.unit("y").cell
	_check.call(
		planned == "advance:x" and BattleGrid.gap(to, x) < BattleGrid.gap(to, y),
		"the enemy carries out the plan it showed (%s), walking to %s" % [planned, to]
	)


func _check_loadout() -> void:
	var rules := _rules()
	var cap: int = rules.get("loadout_max", 0)
	var many: Array = ["charge", "blood_price", "m3", "m4", "m5"]
	var orc := _unit("o", BattleUnit.COMPANY, Vector2i(1, 1), {"moves": many, "initiative": 2})
	var bandit := _unit("b", BattleUnit.ENEMY, Vector2i(2, 1), {"hp": SURE_HIT})
	var battle := _battle([orc, bandit], GRID)
	var kept := orc.moves.size() == cap and orc.knows("charge") and not orc.knows("m5")
	orc.teach("blood_price", false)
	var unlearnt := battle.apply({"type": "blood_price", "target": "b"}).is_empty()
	var undefined := battle.apply({"type": "m3", "target": "b"}).is_empty()
	var used := not battle.apply({"type": "charge", "target": "b"}).is_empty()
	_check.call(
		cap == 4 and kept and unlearnt and undefined and used,
		"a fighter takes at most %d learnt moves; only a learnt move in data can be used" % cap
	)


func _check_hit_hook() -> void:
	var seen: Array[Dictionary] = []
	var hook := func(hit: Dictionary) -> Array:
		seen.append(hit)
		return [{"type": "injury", "unit": hit.get("target")}]
	var hooked := _duel()
	hooked.set_hit_hook(hook)
	var events := hooked.apply({"type": Battle.ACTION_ATTACK, "target": "b"})
	var plain := _duel().apply({"type": Battle.ACTION_ATTACK, "target": "b"})
	var types := _types(events)
	var at := types.find(Battle.EVENT_HIT)
	var hit: Dictionary = events[at] if at >= 0 else {}
	var damage: int = hit.get("damage", 0)
	_check.call(
		(
			hit.get("unit") == "a"
			and hit.get("target") == "b"
			and hit.get("cell") == Vector2i(2, 1)
			and damage > 0
			and seen.size() == 1
			and seen[0].get("damage") == hit.get("damage")
			and types[at + 1] == "injury"
			and str(plain) == str(_without(events, "injury"))
		),
		"a hit is an event (attacker, target, damage, cell); its hook may add injury %s" % [types]
	)


func _without(events: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.get("type") != kind:
			out.append(event)
	return out


func _duel() -> Battle:
	var fighters: Array[BattleUnit] = [
		_unit("a", BattleUnit.COMPANY, Vector2i(1, 1), {"initiative": 2, "attack": SURE_HIT}),
		_unit("b", BattleUnit.ENEMY, Vector2i(2, 1), {"hp": SURE_HIT}),
	]
	return _battle(fighters, GRID)


## A bandit three cells from the back-liner can reach him; with a front-liner standing
## between them, the bandit's walk ends beside the front-liner and the back-liner is safe.
func _check_blocking() -> void:
	var open_reach := _bandit_reach(false)
	var blocked_reach := _bandit_reach(true)
	var back := Vector2i(1, 2)
	_check.call(
		_near(open_reach, back) and not _near(blocked_reach, back),
		"a front-liner in front of the back-liner ends a walk beside him: the back-liner is safe"
	)


func _near(cells: Array, to: Vector2i) -> bool:
	for cell: Vector2i in cells:
		if BattleGrid.adjacent(cell, to):
			return true
	return false


func _bandit_reach(with_front_liner: bool) -> Array:
	var fighters: Array[BattleUnit] = [
		_unit("back", BattleUnit.COMPANY, Vector2i(1, 2), {}),
		_unit("bandit", BattleUnit.ENEMY, Vector2i(5, 2), {}),
	]
	if with_front_liner:
		fighters.append(_unit("front", BattleUnit.COMPANY, Vector2i(3, 2), {}))
	var battle := _battle(fighters, Vector2i(10, 5))
	return battle.reachable(battle.unit("bandit")).keys()


## Losing one bandit shakes the band once (a shaken event), the fight goes on; a second loss
## shakes it no further and, above the rout line, still does not end it.
func _check_shaken() -> void:
	var killer := {"initiative": 5, "attack": SURE_HIT, "damage": SURE_HIT}
	var fighters: Array[BattleUnit] = [
		_unit("c", BattleUnit.COMPANY, Vector2i(2, 2), killer),
		_unit("b1", BattleUnit.ENEMY, Vector2i(3, 2), {"hp": 1}),
		_unit("b2", BattleUnit.ENEMY, Vector2i(3, 3), {"hp": 1}),
		_unit("b3", BattleUnit.ENEMY, FAR_CELL, {"hp": 1}),
	]
	var battle := _battle(fighters, WIDE)
	var first := battle.apply({"type": Battle.ACTION_ATTACK, "target": "b1"})
	var shaken_now := battle.is_shaken(BattleUnit.ENEMY) and not battle.is_over()
	while battle.current().id != "c":
		battle.apply({"type": Battle.ACTION_WAIT})
	var second := battle.apply({"type": Battle.ACTION_ATTACK, "target": "b2"})
	_check.call(
		(
			_types(first).count(BattleMorale.EVENT_SHAKEN) == 1
			and shaken_now
			and _types(second).count(BattleMorale.EVENT_SHAKEN) == 0
			and not battle.is_over()
		),
		"a side below its shaken line is shaken once and fights on until its rout line"
	)


## The log is the setup's events then every apply()'s, and the same seed writes the same log.
func _check_log() -> void:
	var logs: Array[String] = []
	var whole := true
	for _run: int in 2:
		var fighters: Array[BattleUnit] = []
		for i: int in 3:
			var at := Vector2i(1, 2 + i)
			fighters.append(_unit("c%d" % i, BattleUnit.COMPANY, at, {"hp": 10, "damage": 5}))
			fighters.append(_unit("b%d" % i, BattleUnit.ENEMY, Vector2i(8, 2 + i), {"hp": 8}))
		var battle := _battle(fighters, GRID)
		var built: Array[Dictionary] = battle.log.duplicate()
		var sight: int = _rules().get("sight_cells", 0)
		for _turn: int in MAX_TURNS:
			if battle.is_over():
				break
			built.append_array(battle.apply(BattleAi.choose(battle, battle.current(), sight)))
		whole = whole and str(built) == str(battle.log)
		logs.append(str(battle.log))
	var types := logs[0]
	_check.call(
		(
			whole
			and logs[0] == logs[1]
			and types.contains('"type": "round"')
			and types.contains('"type": "intent"')
			and types.contains('"type": "hit"')
		),
		"the log holds the setup's and every action's events, rounds, intents and hits; it replays"
	)
