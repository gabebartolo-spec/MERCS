extends "res://tests/lib/effect_case.gd"
## battle_rout: morale as the main non-HP ending (vision pillar 4, D-066). The slice's
## company (orc, Vampyr, recruit) against the bandit chief and three bandits, both sides
## played by BattleAi, seed 424242: with the balance's rout lines the fight ends when one
## side's morale breaks, its fighters still standing; with the rout lines at 0 it runs until
## one side has no one left up (and no one breaks at his captain's fall: hold_resolve 0).

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const FIELD := Vector2i(12, 8)
const COMPANY: Array[String] = ["orc", "vampyr", "recruit_placeholder"]
const COMPANY_CELLS: Array[Vector2i] = [Vector2i(2, 3), Vector2i(2, 5), Vector2i(1, 4)]
const ENEMIES: Array[String] = ["bandit_chief", "bandit", "bandit", "bandit"]
const ENEMY_CELLS: Array[Vector2i] = [
	Vector2i(9, 4), Vector2i(8, 2), Vector2i(8, 6), Vector2i(7, 4)
]
const MAX_TURNS := 400


func id() -> String:
	return "battle_rout"


func run() -> Dictionary:
	var data := json(BATTLE_DATA)
	var rules: Dictionary = data.get("rules", {})
	var unbreakable := rules.duplicate(true)
	var sides: Dictionary = unbreakable.get("morale_sides", {})
	for side: Variant in sides:
		var block: Dictionary = sides[side]
		block["rout_below"] = 0
	unbreakable["morale_captain_fall"] = {"hold_resolve": 0}
	return {"on": _fight(data, rules), "off": _fight(data, unbreakable)}


func _fight(data: Dictionary, rules: Dictionary) -> String:
	var kinds: Dictionary = data.get("fighters", {})
	var fighters: Array[BattleUnit] = []
	for i: int in COMPANY.size():
		var stats: Dictionary = kinds.get(COMPANY[i], {})
		fighters.append(BattleUnit.make(COMPANY[i], BattleUnit.COMPANY, COMPANY_CELLS[i], stats))
	for i: int in ENEMIES.size():
		var stats: Dictionary = kinds.get(ENEMIES[i], {})
		var unit_id := "%s_%d" % [ENEMIES[i], i]
		fighters.append(BattleUnit.make(unit_id, BattleUnit.ENEMY, ENEMY_CELLS[i], stats))
	var battle := Battle.new()
	battle.setup(rules, {"size": FIELD}, fighters, Rng.from_seed(SEED))
	var sight: int = rules.get("sight_cells", 0)
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		battle.apply(BattleAi.choose(battle, battle.current(), sight))
	var loser := BattleUnit.ENEMY if battle.winner == BattleUnit.COMPANY else BattleUnit.COMPANY
	var standing := battle.units.filter(
		func(u: BattleUnit) -> bool: return u.side == loser and not u.down
	)
	return (
		"winner side %d, routed side %d, %d of the losing side still standing"
		% [battle.winner, battle.routed, standing.size()]
	)
