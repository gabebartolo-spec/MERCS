class_name MercPlay
extends RefCounted
## How a company merc plays a turn, from the moves they have learnt (the vision: a merc's
## moves are how they fight). The enemy's plain line (BattleAi) is the base; a merc with
## "charge" runs at a foe in sight and strikes in the same turn instead of closing in over
## two; a merc with "blood_price" pays his own health only on a foe beside him he saw wounded
## (never one his weapon reaches further off: the move is a blow beside him),
## and only while he can afford it. Deterministic and not psychic (rule 6): he knows of a foe
## only what BattleKnowledge gives BattleAi (who is within sight_cells, whether he looks
## wounded), knows his own health, and rolls nothing.


## Plays the fight to its end (or max_turns actions), every fighter by choose(); returns every
## event in order. An action the battle refuses is replaced by a wait so the fight always moves.
static func play_out(battle: Battle, rules: Dictionary, max_turns: int) -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	for _turn: int in max_turns:
		if battle.is_over():
			break
		var events := battle.apply(choose(battle, battle.current(), rules))
		if events.is_empty():
			events = battle.apply({"type": Battle.ACTION_WAIT})
		log.append_array(events)
	return log


## rules: data/balance/battle.json "rules" (sight_cells; the blood price from its "moves").
static func choose(battle: Battle, fighter: BattleUnit, rules: Dictionary) -> Dictionary:
	var sight := Merc.whole(rules.get("sight_cells", 0))
	var plain := BattleAi.choose(battle, fighter, sight)
	if fighter.can_blood_price and plain.get("type") == battle.kit(fighter.id)[0]:
		var target := battle.unit(str(plain["target"]))
		var beside := BattleGrid.adjacent(fighter.cell, target.cell)
		if (
			beside
			and _worth_the_price(fighter, target, battle.move_def(BattleUnit.MOVE_BLOOD_PRICE))
		):
			return {"type": Battle.ACTION_BLOOD_PRICE, "target": target.id}
	if fighter.can_charge and plain.get("type") == Battle.ACTION_MOVE:
		var charge := _charge(battle, fighter, sight)
		if not charge.is_empty():
			return charge
	return plain


## The Vampyr times his all-ins: he pays only to press a foe he saw wounded (he cannot see
## how much health is left) and only while the price leaves him standing with health to
## spare (his own, which he knows). price: battle.json "rules" "moves" "blood_price".
static func _worth_the_price(fighter: BattleUnit, target: BattleUnit, price: Dictionary) -> bool:
	var cost := Merc.whole(price.get("hp_cost", 0))
	var bleeding := BattleKnowledge.looks(target) == BattleKnowledge.WOUNDED
	return bleeding and fighter.hp > cost + cost


## Walk to a free cell beside a foe in sight and strike, when one is in reach: the most
## hurt-looking such foe (BattleKnowledge), the first in the battle's order between equals.
static func _charge(battle: Battle, fighter: BattleUnit, sight: int) -> Dictionary:
	var cells: Array = battle.reachable(fighter).keys()
	cells.sort()
	var best: Dictionary = {}
	var best_looks := BattleKnowledge.UNHURT
	for foe: BattleUnit in BattleKnowledge.seen(battle, fighter, sight):
		for cell: Vector2i in cells:
			if BattleGrid.gap(cell, foe.cell) != 1:
				continue
			if best.is_empty() or BattleKnowledge.looks(foe) > best_looks:
				best = {"type": Battle.ACTION_CHARGE, "to": cell, "target": foe.id}
				best_looks = BattleKnowledge.looks(foe)
			break
	return best
