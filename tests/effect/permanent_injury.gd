extends "res://tests/lib/effect_case.gd"
## permanent_injury: the same orc, the same bandit chief and the same seed, once with the
## lost eye on the orc (its stat change applied through Injury.effective_stats) and once
## without: the fight ends differently.

const BATTLE := "res://data/balance/battle.json"
const INJURIES := "res://data/injuries.json"
const SEED := 424242
const DAY := 10
const GRID := Vector2i(3, 1)
const TURN_LIMIT := 200


func id() -> String:
	return "permanent_injury"


func run() -> Dictionary:
	var defs: Variant = json(INJURIES).get("injuries", [])
	var list: Array = defs if defs is Array else []
	var battle: Dictionary = json(BATTLE)
	var fighters: Dictionary = battle.get("fighters", {})
	var orc: Dictionary = fighters.get("orc", {})
	var merc := {"id": "orc", "stats": orc, "injuries": []}
	var hurt := Injury.apply(merc, "inj_lost_eye", DAY, list)
	return {"on": _fight(battle, hurt, list), "off": _fight(battle, merc, list)}


func _fight(battle: Dictionary, merc: Dictionary, defs: Array) -> String:
	var fighters: Dictionary = battle.get("fighters", {})
	var chief: Dictionary = fighters.get("bandit_chief", {})
	var rules: Dictionary = battle.get("rules", {})
	var stats := Injury.effective_stats(merc, DAY, defs)
	var units: Array[BattleUnit] = [
		BattleUnit.make("orc", BattleUnit.COMPANY, Vector2i(0, 0), stats),
		BattleUnit.make("chief", BattleUnit.ENEMY, Vector2i(1, 0), chief)
	]
	var fight := Battle.new()
	fight.setup(rules, {"size": GRID}, units, Rng.from_seed(SEED))
	var turns := 0
	while not fight.is_over() and turns < TURN_LIMIT:
		var actor := fight.current()
		fight.apply({"type": "attack", "target": "chief" if actor.id == "orc" else "orc"})
		turns += 1
	var orc_hp := fight.unit("orc").hp
	var chief_hp := fight.unit("chief").hp
	return (
		"winner %d after %d turns, orc hp %d, chief hp %d" % [fight.winner, turns, orc_hp, chief_hp]
	)
