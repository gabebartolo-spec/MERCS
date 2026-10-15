extends "res://tests/lib/effect_case.gd"
## turn_order: initiative decides who acts first, and so who wins. The orc and a bandit chief
## side by side on seed 424242, every fighter attacking on its turn: once with the orc's
## initiative one above the chief's (he opens), once one below (the chief opens). The
## read-ahead turn order and the blow that lands first differ, and so may the end.

const BATTLE := "res://data/balance/battle.json"
const SEED := 424242
const GRID := Vector2i(3, 1)
const TURN_LIMIT := 200


func id() -> String:
	return "turn_order"


func run() -> Dictionary:
	var fast := json(BATTLE)
	var slow := json(BATTLE)
	var fighters: Dictionary = slow["fighters"]
	var orc: Dictionary = fighters["orc"]
	var chief: Dictionary = fighters["bandit_chief"]
	orc["initiative"] = Merc.whole(chief["initiative"]) - 1
	var quick_fighters: Dictionary = fast["fighters"]
	var quick_orc: Dictionary = quick_fighters["orc"]
	quick_orc["initiative"] = Merc.whole(chief["initiative"]) + 1
	return {"on": _fight(fast), "off": _fight(slow)}


func _fight(data: Dictionary) -> String:
	var fighters: Dictionary = data["fighters"]
	var orc: Dictionary = fighters["orc"]
	var chief: Dictionary = fighters["bandit_chief"]
	var rules: Dictionary = data["rules"]
	var units: Array[BattleUnit] = [
		BattleUnit.make("orc", BattleUnit.COMPANY, Vector2i(0, 0), orc),
		BattleUnit.make("chief", BattleUnit.ENEMY, Vector2i(1, 0), chief),
	]
	var fight := Battle.new()
	fight.setup(rules, {"size": GRID}, units, Rng.from_seed(SEED))
	var order: Array[String] = []
	for fighter: BattleUnit in fight.turn_order():
		order.append(fighter.id)
	var first_blow := ""
	var turns := 0
	while not fight.is_over() and turns < TURN_LIMIT:
		var actor := fight.current()
		var events := fight.apply(
			{"type": "attack", "target": "chief" if actor.id == "orc" else "orc"}
		)
		if first_blow == "" and not events.is_empty():
			first_blow = actor.id
		turns += 1
	return (
		"order %s, first blow by %s, winner %d after %d turns, orc hp %d"
		% [",".join(order), first_blow, fight.winner, turns, fight.unit("orc").hp]
	)
