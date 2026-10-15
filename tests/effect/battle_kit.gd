extends "res://tests/lib/effect_case.gd"
## battle_kit: the action kit (Phase 4 P1a; director Q-A, 2026-10-15: "1 weapon + 4 moves").
## A fighter may use only what his kit holds: his weapon's action and the learnt moves the
## catalogue (battle.json "rules" "actions") lists, at most four. The Vampyr and the orc hold
## a street against a bandit chief and two bandits; each company fighter uses the first
## technique in his kit that he can, else a plain blow. Seed 424243: with the blood price in
## the Vampyr's kit he spends his health for harder blows and the chief falls; with it out of
## the catalogue (he still knows it) his kit is a plain blow, the orc falls and the band wins.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424243
const FIELD := Vector2i(10, 3)
const MAX_TURNS := 300
const COMPANY_X := 3
const BLOOD_PRICE := BattleUnit.MOVE_BLOOD_PRICE


func id() -> String:
	return "battle_kit"


func run() -> Dictionary:
	return {"on": _fight(true), "off": _fight(false)}


func _fight(in_kit: bool) -> String:
	var data := json(BATTLE_DATA)
	var kinds: Dictionary = data.get("fighters", {})
	var plain: Dictionary = data.get("rules", {})
	var rules := plain.duplicate(true)
	if not in_kit:
		var actions: Dictionary = rules.get("actions", {})
		var techniques: Dictionary = actions.get("technique", {})
		techniques.erase(BLOOD_PRICE)
	var fighters: Array[BattleUnit] = [
		_make(kinds, "vampyr", "vampyr", Vector2i(3, 1)),
		_make(kinds, "orc", "orc", Vector2i(3, 0)),
		_make(kinds, "bandit_chief", "chief", Vector2i(4, 1)),
		_make(kinds, "bandit", "b1", Vector2i(4, 0)),
		_make(kinds, "bandit", "b2", Vector2i(4, 2)),
	]
	var battle := Battle.new()
	battle.setup(rules, {"size": FIELD}, fighters, Rng.from_seed(SEED))
	var falls: Array[String] = []
	var prices := 0
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		var events := battle.apply(_choose(battle, battle.current()))
		if events.is_empty():
			events = battle.apply({"type": Battle.ACTION_WAIT})
		for event: Dictionary in events:
			if event.get("type") == "down":
				falls.append(str(event.get("unit")))
			if event.get("type") == BLOOD_PRICE:
				prices += 1
	return (
		"blood prices paid %d; falls %s; winner side %d, round %d"
		% [prices, ",".join(falls), battle.winner, battle.round_number]
	)


## The company stands at x 3, the band at x 4.
func _make(kinds: Dictionary, kind: String, unit_id: String, at: Vector2i) -> BattleUnit:
	var stats: Dictionary = kinds.get(kind, {})
	var side := BattleUnit.COMPANY if at.x == COMPANY_X else BattleUnit.ENEMY
	return BattleUnit.make(unit_id, side, at, stats)


## The first kit action that can strike the weakest foe beside the fighter, else a plain blow,
## else wait.
func _choose(battle: Battle, actor: BattleUnit) -> Dictionary:
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
	if actor.side == BattleUnit.COMPANY:
		for kind: String in battle.kit(actor.id):
			if battle.move_def(kind).is_empty():
				continue
			if BattleRules.read(battle.move_def(kind), "hp_cost") < actor.hp:
				return {"type": kind, "target": pick.id}
	return {"type": Battle.ACTION_ATTACK, "target": pick.id}
