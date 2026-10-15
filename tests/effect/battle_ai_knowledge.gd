extends "res://tests/lib/effect_case.gd"
## battle_ai_knowledge: the enemy is not psychic (CLAUDE.md rule 6, Phase 4 P5). A watchman
## stands between two company fighters who hold their ground: a frail one, unhurt, with less
## health left, and a tough one he saw take a wound, with more. A third, badly hurt, lies low
## at the far end of the street, beyond the watchman's sight. On: the watchman plays BattleAi,
## which knows only what he sees: he cuts down the man he saw bleed first, then the other, and
## never learns of the straggler. Off: the same watchman with full information (exact health,
## the whole field): he finishes the frail one first, then walks the street to the straggler.
## Seed 424242.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const ENEMY_CELL := Vector2i(5, 1)
const FRAIL_CELL := Vector2i(4, 1)
const BLOODIED_CELL := Vector2i(6, 1)
const ROWS := 3
const STRAGGLER_HP := 1
const MAX_TURNS := 300


func id() -> String:
	return "battle_ai_knowledge"


func run() -> Dictionary:
	return {"on": _fight(true), "off": _fight(false)}


func _fight(knowing_only_sight: bool) -> String:
	var data := json(BATTLE_DATA)
	var rules: Dictionary = data.get("rules", {})
	var sight := BattleRules.read(rules, "sight_cells")
	var bloodied := _make(data, "bloodied", BLOODIED_CELL, "orc")
	bloodied.hp = bloodied.max_hp - 1
	bloodied.wounded = true
	var straggler_cell := Vector2i(ENEMY_CELL.x + sight + 1, 1)
	var straggler := _make(data, "straggler", straggler_cell, "bandit")
	straggler.hp = STRAGGLER_HP
	straggler.wounded = true
	var fighters: Array[BattleUnit] = [
		_make(data, "watchman", ENEMY_CELL, "watchman"),
		_make(data, "frail", FRAIL_CELL, "bandit"),
		bloodied,
		straggler,
	]
	var battle := Battle.new()
	var field := Vector2i(straggler_cell.x + 1, ROWS)
	battle.setup(rules, {"size": field}, fighters, Rng.from_seed(SEED))
	var downs: Array[String] = []
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		var actor := battle.current()
		var action := {"type": Battle.ACTION_WAIT}
		if actor.side == BattleUnit.ENEMY:
			action = (
				BattleAi.choose(battle, actor, sight)
				if knowing_only_sight
				else _psychic(battle, actor)
			)
		for event: Dictionary in battle.apply(action):
			if event.get("type") == "down":
				downs.append(str(event.get("unit")))
	return (
		"the watchman cuts down %s; the straggler %s"
		% [", ".join(downs), "falls" if straggler.down else "lives"]
	)


## A fighter of battle.json "fighters" by kind, never a leader (no morale side effects); the
## watchman is the enemy, everyone else the company.
func _make(data: Dictionary, unit_id: String, at: Vector2i, kind: String) -> BattleUnit:
	var kinds: Dictionary = data.get("fighters", {})
	var found: Dictionary = kinds.get(kind, {})
	var stats := found.duplicate()
	stats.erase("leader")
	var side := BattleUnit.ENEMY if unit_id == "watchman" else BattleUnit.COMPANY
	return BattleUnit.make(unit_id, side, at, stats)


## Full information: strike the foe beside him with the least exact health, else walk at the
## foe with the least health anywhere on the field.
func _psychic(battle: Battle, actor: BattleUnit) -> Dictionary:
	var beside: BattleUnit = null
	var anywhere: BattleUnit = null
	for other: BattleUnit in battle.units:
		if other.side == actor.side or other.down:
			continue
		if anywhere == null or other.hp < anywhere.hp:
			anywhere = other
		if BattleGrid.adjacent(actor.cell, other.cell) and (beside == null or other.hp < beside.hp):
			beside = other
	if beside != null:
		return {"type": Battle.ACTION_ATTACK, "target": beside.id}
	if anywhere == null:
		return {"type": Battle.ACTION_WAIT}
	return _walk_toward(battle, actor, anywhere)


## The reachable cell nearest the goal (sorted, first best), else a wait.
func _walk_toward(battle: Battle, actor: BattleUnit, goal: BattleUnit) -> Dictionary:
	var best := actor.cell
	var cells: Array = battle.reachable(actor).keys()
	cells.sort()
	for cell: Vector2i in cells:
		if BattleGrid.gap(cell, goal.cell) < BattleGrid.gap(best, goal.cell):
			best = cell
	if best == actor.cell:
		return {"type": Battle.ACTION_WAIT}
	return {"type": Battle.ACTION_MOVE, "to": best}
