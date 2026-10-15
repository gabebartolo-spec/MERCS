class_name BattleIntents
extends RefCounted
## The enemy's plans for the round under way (D-066: visible intent). At the start of each
## round every standing enemy plans from what it can see (BattleAi.intent) and the plan is
## logged as an "intent" event the player reads before the enemy acts; a plan is kept until
## its fighter acts. No rolls.

const EVENT_INTENT := "intent"

var _plans := {}


## A new round's plans: each standing enemy in the order, from what it sees within sight.
## Appends one intent event per plan.
func plan_round(battle: Battle, order: Array[BattleUnit], sight: int) -> Array[Dictionary]:
	_plans.clear()
	var events: Array[Dictionary] = []
	for fighter: BattleUnit in order:
		if fighter.side == BattleUnit.ENEMY and fighter.can_act():
			var plan := BattleAi.intent(battle, fighter, sight)
			_plans[fighter.id] = plan
			var event := plan.duplicate()
			event["type"] = EVENT_INTENT
			events.append(event)
	return events


## The fighter's plan for this round, a copy; {} when it has none.
func plan(unit_id: String) -> Dictionary:
	var found: Dictionary = _plans.get(unit_id, {})
	return found.duplicate()


func has_plan(unit_id: String) -> bool:
	return _plans.has(unit_id)


## The fighter has acted: his plan is carried out.
func done(unit_id: String) -> void:
	_plans.erase(unit_id)
