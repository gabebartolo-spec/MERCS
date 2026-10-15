extends "res://tests/lib/effect_case.gd"
## battle_sight: the enemy fights only what it can see (not psychic). The road fight's band
## against the starting six on seed 424242, the company played by MercPlay in both runs and the
## enemy by BattleAi: once with the data's sight, once blind past one cell. A blind enemy
## waits for the company to walk up; a seeing one closes in, so the fight reads differently.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const BLIND := 1


func id() -> String:
	return "battle_sight"


func run() -> Dictionary:
	var sight := Merc.whole(Fixture.rules().get("sight_cells", 0))
	return {"on": _fight(sight), "off": _fight(BLIND)}


func _fight(enemy_sight: int) -> String:
	var rng := Rng.from_seed(SEED)
	var made := Kit.wounds(rng, "wound")
	var data := Fixture.json(Fixture.BATTLE)
	var cells := EncounterBattle.company_cells(Kit.scenario())
	var units := made.units(cells, BattleUnit.COMPANY)
	var battle := EncounterBattle.build(Kit.pending(), Kit.scenario(), data, rng, units)
	var rules := Fixture.rules()
	var enemy_moves := 0
	var turns := 0
	while not battle.is_over() and turns < Kit.MAX_ACTIONS:
		var actor := battle.current()
		var action := (
			MercPlay.choose(battle, actor, rules)
			if actor.side == BattleUnit.COMPANY
			else BattleAi.choose(battle, actor, enemy_sight)
		)
		var events := battle.apply(action)
		if events.is_empty():
			events = battle.apply({"type": Battle.ACTION_WAIT})
		elif actor.side == BattleUnit.ENEMY and action.get("type") == Battle.ACTION_MOVE:
			enemy_moves += 1
		turns += 1
	return (
		"winner %d after %d actions, round %d, %d enemy advances"
		% [battle.winner, turns, battle.round_number, enemy_moves]
	)
