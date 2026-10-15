extends "res://tests/lib/effect_case.gd"
## battle_surrender: surrender beside rout (Phase 4 P2, director ruling Q-C "cornered or
## leader down"). The slice's company against three bandits and their chief, who hangs back at
## the far edge, the band
## already shaken by its talked-down lookout (battle.json "gate" "shaken_morale"), seed
## 424242, both sides played by BattleAi. On: the balance's surrender rule: when the band
## breaks, men pinned by a company fighter beside them surrender and become the prisoners
## the hub's decision is about. Off: the Phase 2 rule (no one pinned, no one breaks at the
## captain's fall): every man still standing runs and no one is taken.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const FIELD := Vector2i(12, 8)
const COMPANY: Array[String] = ["orc", "vampyr", "recruit_placeholder"]
const COMPANY_CELLS: Array[Vector2i] = [Vector2i(2, 3), Vector2i(2, 5), Vector2i(1, 4)]
const ENEMIES: Array[String] = ["bandit_chief", "bandit", "bandit", "bandit"]
const ENEMY_CELLS: Array[Vector2i] = [
	Vector2i(11, 4), Vector2i(8, 2), Vector2i(8, 6), Vector2i(7, 4)
]
const MAX_TURNS := 400


func id() -> String:
	return "battle_surrender"


func run() -> Dictionary:
	var data := json(BATTLE_DATA)
	var rules: Dictionary = data.get("rules", {})
	var no_surrender := rules.duplicate(true)
	no_surrender["surrender"] = {"pinned_by": 0}
	no_surrender["morale_captain_fall"] = {"hold_resolve": 0}
	return {"on": _fight(data, rules), "off": _fight(data, no_surrender)}


func _fight(data: Dictionary, rules: Dictionary) -> String:
	var kinds: Dictionary = data.get("fighters", {})
	var gate: Dictionary = data.get("gate", {})
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
	var shaken: int = gate.get("shaken_morale", 0)
	battle.lower_morale(BattleUnit.ENEMY, shaken)
	var sight: int = rules.get("sight_cells", 0)
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		battle.apply(BattleAi.choose(battle, battle.current(), sight))
	var result := EncounterBattle.result(battle)
	var alive := BattleEnd.standing(battle.units, BattleUnit.ENEMY)
	return (
		"won %s, surrendered %s, prisoners %s, ran %s, %d enemies alive"
		% [result["won"], result["surrendered"], result["prisoners"], result["fled"], alive]
	)
