extends "res://tests/lib/effect_case.gd"
## battle_gear: equipment physics (Phase 4 P1b, director's rulings D-092). Two seeded fights
## from data/balance/battle.json, both sides played by BattleAi, seed 424242, the only change
## being one piece of gear:
## - the orc against three bandits with swords, in his plate (on) or in nothing (off): plate
##   turns their cuts and slows him, so the fight runs differently;
## - the orc against the watchman behind his shield, swinging his axe (on) or a sword (off):
##   the axe splits the shield, the sword never does.
## The case reads only fighter data and the event log ("shield_broken" events), so with the
## gear rules absent both halves read the same and the case fails.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const FIELD := Vector2i(10, 6)
const MAX_TURNS := 300
const ORC_CELL := Vector2i(2, 3)
const BANDIT_CELLS: Array[Vector2i] = [Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4)]
const WATCH_CELL := Vector2i(3, 3)


func id() -> String:
	return "battle_gear"


func run() -> Dictionary:
	var data := json(BATTLE_DATA)
	var rules: Dictionary = data.get("rules", {})
	var kinds: Dictionary = data.get("fighters", {})
	var orc: Dictionary = kinds.get("orc", {})
	var bare := orc.duplicate(true)
	bare["gear"] = {"axe": true}
	var with_sword := orc.duplicate(true)
	with_sword["gear"] = {"sword": true, "plate": true}
	return {
		"on": _plate_fight(rules, kinds, orc) + "; " + _shield_fight(rules, kinds, orc),
		"off": _plate_fight(rules, kinds, bare) + "; " + _shield_fight(rules, kinds, with_sword),
	}


func _plate_fight(rules: Dictionary, kinds: Dictionary, orc: Dictionary) -> String:
	var fighters: Array[BattleUnit] = [BattleUnit.make("orc", BattleUnit.COMPANY, ORC_CELL, orc)]
	var bandit: Dictionary = kinds.get("bandit", {})
	for i: int in BANDIT_CELLS.size():
		fighters.append(BattleUnit.make("b%d" % i, BattleUnit.ENEMY, BANDIT_CELLS[i], bandit))
	var battle := _play(rules, fighters)
	var standing := fighters.filter(
		func(u: BattleUnit) -> bool: return u.side == BattleUnit.ENEMY and not u.down
	)
	return (
		"orc vs bandits: winner side %d, orc %d hp, %d bandits standing, round %d"
		% [battle.winner, fighters[0].hp, standing.size(), battle.round_number]
	)


func _shield_fight(rules: Dictionary, kinds: Dictionary, orc: Dictionary) -> String:
	var watchman: Dictionary = kinds.get("watchman", {})
	var fighters: Array[BattleUnit] = [
		BattleUnit.make("orc", BattleUnit.COMPANY, ORC_CELL, orc),
		BattleUnit.make("w", BattleUnit.ENEMY, WATCH_CELL, watchman),
	]
	var battle := _play(rules, fighters)
	var splits := battle.log.filter(
		func(e: Dictionary) -> bool: return str(e.get("type", "")) == "shield_broken"
	)
	var held := "split" if not splits.is_empty() else "held"
	return "watchman's shield %s, winner side %d" % [held, battle.winner]


func _play(rules: Dictionary, fighters: Array[BattleUnit]) -> Battle:
	var battle := Battle.new()
	battle.setup(rules, {"size": FIELD}, fighters, Rng.from_seed(SEED))
	var sight: int = rules.get("sight_cells", 0)
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		battle.apply(BattleAi.choose(battle, battle.current(), sight))
	return battle
