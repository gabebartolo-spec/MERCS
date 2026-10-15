extends "res://tests/lib/effect_case.gd"
## battle_blocking: the one terrain feature of Phase 2 (D-066), a front-liner who blocks.
## The orc and the Vampyr hold the line on an open street against three bandits (the
## company strikes whoever stands beside it, else waits; the bandits play BattleAi). Seed
## 424242, the orc standing two cells in front of the Vampyr (no cell touches both, so a
## bandit's walk ends beside the orc) against the orc standing behind him: which of them
## takes the first blow, and whether the Vampyr is still standing at the end, differ.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const FIELD := Vector2i(10, 5)
const BACK_LINER := Vector2i(1, 2)
const IN_FRONT := Vector2i(3, 2)
const BEHIND := Vector2i(0, 2)
const BANDITS: Array[Vector2i] = [Vector2i(7, 1), Vector2i(7, 3), Vector2i(8, 2)]
const MAX_TURNS := 300


func id() -> String:
	return "battle_blocking"


func run() -> Dictionary:
	return {"on": _fight(IN_FRONT), "off": _fight(BEHIND)}


func _fight(orc_cell: Vector2i) -> String:
	var data := json(BATTLE_DATA)
	var kinds: Dictionary = data.get("fighters", {})
	var rules: Dictionary = data.get("rules", {})
	var orc: Dictionary = kinds.get("orc", {})
	var vampyr: Dictionary = kinds.get("vampyr", {})
	var fighters: Array[BattleUnit] = [
		BattleUnit.make("orc", BattleUnit.COMPANY, orc_cell, orc),
		BattleUnit.make("vampyr", BattleUnit.COMPANY, BACK_LINER, vampyr),
	]
	for i: int in BANDITS.size():
		var stats: Dictionary = kinds.get("bandit", {})
		fighters.append(BattleUnit.make("bandit_%d" % i, BattleUnit.ENEMY, BANDITS[i], stats))
	var battle := Battle.new()
	battle.setup(rules, {"size": FIELD}, fighters, Rng.from_seed(SEED))
	var sight: int = rules.get("sight_cells", 0)
	var first_blow := ""
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		var actor := battle.current()
		var action := (
			BattleAi.choose(battle, actor, sight)
			if actor.side == BattleUnit.ENEMY
			else _hold(battle, actor)
		)
		for event: Dictionary in battle.apply(action):
			if event.get("type") != Battle.EVENT_HIT or first_blow != "":
				continue
			var struck := battle.unit(str(event.get("target", "")))
			if struck.side == BattleUnit.COMPANY:
				first_blow = struck.id
	var struck_first := first_blow if first_blow != "" else "no one"
	var vampyr_hp := battle.unit("vampyr").hp
	return (
		"first blow on %s; vampyr %d hp, orc %d hp; winner side %d"
		% [struck_first, vampyr_hp, battle.unit("orc").hp, battle.winner]
	)


## Holding the line: strike the most hurt enemy beside you, else wait.
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
