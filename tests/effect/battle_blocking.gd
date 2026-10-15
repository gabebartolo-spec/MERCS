extends "res://tests/lib/effect_case.gd"
## battle_blocking: the one terrain feature of Phase 2 (D-066), a front-liner who blocks: a
## walk ends beside a standing opponent. On a street three cells wide the orc charges for
## the bandit chief (his charge walks, then strikes); a bandit guard stands either in front
## of the chief, between them, or behind him. Both bandits hold their ground and strike
## whoever comes beside them. Seed 424242: with the guard in front, every way round him ends
## beside him, so the orc's charge cannot reach the chief and his first blow falls on the
## guard; with the guard behind, the charge reaches the chief. Without blocking the orc would
## walk round the guard and the two would read the same.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const FIELD := Vector2i(10, 3)
const ORC_CELL := Vector2i(2, 1)
const CHIEF_CELL := Vector2i(6, 1)
const IN_FRONT := Vector2i(5, 1)
const BEHIND := Vector2i(7, 1)
const MAX_TURNS := 300


func id() -> String:
	return "battle_blocking"


func run() -> Dictionary:
	return {"on": _fight(IN_FRONT), "off": _fight(BEHIND)}


func _fight(guard_cell: Vector2i) -> String:
	var data := json(BATTLE_DATA)
	var kinds: Dictionary = data.get("fighters", {})
	var rules: Dictionary = data.get("rules", {})
	var orc: Dictionary = kinds.get("orc", {})
	var chief: Dictionary = kinds.get("bandit_chief", {})
	var guard: Dictionary = kinds.get("bandit", {})
	var fighters: Array[BattleUnit] = [
		BattleUnit.make("orc", BattleUnit.COMPANY, ORC_CELL, orc),
		BattleUnit.make("chief", BattleUnit.ENEMY, CHIEF_CELL, chief),
		BattleUnit.make("guard", BattleUnit.ENEMY, guard_cell, guard),
	]
	var battle := Battle.new()
	battle.setup(rules, {"size": FIELD}, fighters, Rng.from_seed(SEED))
	var first_blow := ""
	var first_down := ""
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		var actor := battle.current()
		var action := _hold(battle, actor)
		if actor.side == BattleUnit.COMPANY:
			action = _charge(battle, actor)
		for event: Dictionary in battle.apply(action):
			if event.get("type") == Battle.ACTION_ATTACK and first_blow == "":
				first_blow = str(event.get("target"))
			if event.get("type") == "down" and first_down == "":
				first_down = str(event.get("unit"))
	return (
		"the orc's first blow falls on the %s; the %s falls first; winner side %d"
		% [first_blow, first_down, battle.winner]
	)


## The orc charges the chief when a charge can reach him, else the guard, else waits.
func _charge(battle: Battle, orc: BattleUnit) -> Dictionary:
	for target_id: String in ["chief", "guard"]:
		var target := battle.unit(target_id)
		if target.down:
			continue
		var landing: Variant = _landing(battle, orc, target)
		if landing is Vector2i:
			return {"type": BattleUnit.MOVE_CHARGE, "to": landing, "target": target_id}
	return {"type": Battle.ACTION_WAIT}


## The first cell (in sorted order) the orc stands on or can walk to beside the target.
func _landing(battle: Battle, orc: BattleUnit, target: BattleUnit) -> Variant:
	if BattleGrid.adjacent(orc.cell, target.cell):
		return orc.cell
	var cells: Array = battle.reachable(orc).keys()
	cells.sort()
	for cell: Vector2i in cells:
		if BattleGrid.adjacent(cell, target.cell):
			return cell
	return null


## Holding ground: strike the most hurt enemy beside you, else wait.
func _hold(battle: Battle, actor: BattleUnit) -> Dictionary:
	var pick: BattleUnit = null
	for other: BattleUnit in battle.units:
		if other.side == actor.side or other.down:
			continue
		if not BattleGrid.adjacent(actor.cell, other.cell):
			continue
		if pick == null or other.hp < pick.hp:
			pick = other
	if pick == null:
		return {"type": Battle.ACTION_WAIT}
	return {"type": Battle.ACTION_ATTACK, "target": pick.id}
