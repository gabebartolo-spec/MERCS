extends "res://tests/lib/effect_case.gd"
## battle_captain: the captain's fall (Phase 4 P2, director ruling Q-D "large morale fall").
## The slice's company (orc, Vampyr, recruit) against the bandit chief and three bandits,
## seed 424242, both sides played by BattleAi after one scripted opening: the Vampyr, first
## to act, lands a sure killing blow on the man beside him. On: he kills the chief; off: he
## kills a bandit given the chief's health. The chief's fall breaks every bandit below the
## hold resolve at once and the fight ends sooner, with men taken.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const FIELD := Vector2i(12, 8)
const COMPANY: Array[String] = ["orc", "vampyr", "recruit_placeholder"]
const COMPANY_CELLS: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5)]
const ENEMIES: Array[String] = ["bandit_chief", "bandit", "bandit", "bandit"]
const ENEMY_CELLS: Array[Vector2i] = [
	Vector2i(4, 4), Vector2i(4, 3), Vector2i(8, 2), Vector2i(8, 6)
]
const SURE := 100
const MAX_TURNS := 400


func id() -> String:
	return "battle_captain"


func run() -> Dictionary:
	var data := json(BATTLE_DATA)
	return {"on": _fight(data, "bandit_chief_0"), "off": _fight(data, "bandit_1")}


func _fight(data: Dictionary, victim: String) -> String:
	var rules: Dictionary = data.get("rules", {})
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
	var target := battle.unit(victim)
	target.hp = battle.unit("bandit_chief_0").hp
	var striker := battle.current()
	striker.next_attack_bonus = SURE
	striker.next_damage_bonus = SURE
	battle.apply({"type": Battle.ACTION_ATTACK, "target": victim})
	var sight: int = rules.get("sight_cells", 0)
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		battle.apply(BattleAi.choose(battle, battle.current(), sight))
	return (
		"%s's first blow kills %s; over in round %d, winner side %d, %d taken, %d ran"
		% [
			striker.id,
			victim,
			battle.round_number,
			battle.winner,
			battle.prisoners.size(),
			battle.fled.size()
		]
	)
