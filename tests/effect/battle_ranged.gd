extends "res://tests/lib/effect_case.gd"
## battle_ranged: striking from a distance (Phase 4 P1c; director 2026-10-16: "Build ranged
## next", spears "Yes, 2 cells"). Two seeded fights from data/balance/battle.json, seed 424242:
## the enemy played by BattleAi, the company holding its line (each merc strikes a foe his
## weapon reaches, Battle.targets, else waits), the only change being the reach of the weapons
## (battle.json "rules" "actions" "weapon": on as in data, off with every reach cut to 1):
## - a company archer behind a swordsman against two bandits: on, he lands arrows from range;
## - a spearman behind a swordsman in a one-cell alley against the bandit chief: on, he strikes
##   over his friend's shoulder.
## A third line probes the wall: a bow's shot through a wall is refused either way. The case
## reads only fighter data and the event log, so with ranged reach absent both halves read the
## same and the case fails.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const FIELD := Vector2i(10, 6)
const MAX_TURNS := 300
const ROW := 3
const OFF_REACH := 1
## The spear's alley: one cell wide, so the chief comes at the swordsman's face and the
## spearman stands behind him.
const ALLEY := Vector2i(10, 1)


func id() -> String:
	return "battle_ranged"


func run() -> Dictionary:
	var data := json(BATTLE_DATA)
	var rules: Dictionary = data.get("rules", {})
	var kinds: Dictionary = data.get("fighters", {})
	var off := rules.duplicate(true)
	var actions: Dictionary = off.get("actions", {})
	var weapons: Dictionary = actions.get("weapon", {})
	for weapon: Variant in weapons:
		var def: Dictionary = weapons[weapon]
		def["reach"] = OFF_REACH
	return {"on": _outcome(rules, kinds), "off": _outcome(off, kinds)}


func _outcome(rules: Dictionary, kinds: Dictionary) -> String:
	return "%s; %s; %s" % [_archer(rules, kinds), _spear(rules, kinds), _wall(rules, kinds)]


func _fighter(kinds: Dictionary, kind: String, gear: Dictionary) -> Dictionary:
	var stats: Dictionary = kinds.get(kind, {})
	var out := stats.duplicate(true)
	out["gear"] = gear
	return out


func _archer(rules: Dictionary, kinds: Dictionary) -> String:
	var archer := _fighter(kinds, "recruit_placeholder", {"bow": true, "leather": true})
	var sword := _fighter(kinds, "recruit_placeholder", {"sword": true, "leather": true})
	var bandit: Dictionary = kinds.get("bandit", {})
	var fighters: Array[BattleUnit] = [
		BattleUnit.make("archer", BattleUnit.COMPANY, Vector2i(1, ROW), archer),
		BattleUnit.make("sword", BattleUnit.COMPANY, Vector2i(3, ROW), sword),
		BattleUnit.make("b0", BattleUnit.ENEMY, Vector2i(8, ROW - 1), bandit),
		BattleUnit.make("b1", BattleUnit.ENEMY, Vector2i(8, ROW + 1), bandit),
	]
	var played := _play(rules, fighters, "archer", {"size": FIELD})
	var battle: Battle = played["battle"]
	return (
		"archer: %d arrows landed from range, winner side %d, round %d"
		% [played["from_range"], battle.winner, battle.round_number]
	)


func _spear(rules: Dictionary, kinds: Dictionary) -> String:
	var spear := _fighter(kinds, "recruit_placeholder", {"spear": true, "leather": true})
	var sword := _fighter(kinds, "recruit_placeholder", {"sword": true, "leather": true})
	var bandit: Dictionary = kinds.get("bandit_chief", {})
	var fighters: Array[BattleUnit] = [
		BattleUnit.make("spear", BattleUnit.COMPANY, Vector2i(2, 0), spear),
		BattleUnit.make("sword", BattleUnit.COMPANY, Vector2i(3, 0), sword),
		BattleUnit.make("chief", BattleUnit.ENEMY, Vector2i(8, 0), bandit),
	]
	var played := _play(rules, fighters, "spear", {"size": ALLEY})
	var battle: Battle = played["battle"]
	return (
		"spear: %d blows landed over a shoulder, sword %d hp, winner side %d"
		% [played["from_range"], fighters[1].hp, battle.winner]
	)


func _wall(rules: Dictionary, kinds: Dictionary) -> String:
	var archer := _fighter(kinds, "recruit_placeholder", {"bow": true})
	var bandit: Dictionary = kinds.get("bandit", {})
	var fighters: Array[BattleUnit] = [
		BattleUnit.make("archer", BattleUnit.COMPANY, Vector2i(1, ROW), archer),
		BattleUnit.make("b0", BattleUnit.ENEMY, Vector2i(5, ROW), bandit),
	]
	fighters[0].initiative = fighters[1].initiative + 1
	var battle := Battle.new()
	var field := {"size": FIELD, "blocked": {Vector2i(3, ROW): true}}
	battle.setup(rules, field, fighters, Rng.from_seed(SEED))
	var refused := battle.apply({"type": "bow", "target": "b0"}).is_empty()
	return "shot through a wall %s" % ("refused" if refused else "taken")


## Plays the fight, the enemy by BattleAi, the company holding its line; counts the shooter's
## blows that landed (a "hit" event) from two cells or more.
func _play(
	rules: Dictionary, fighters: Array[BattleUnit], shooter: String, field: Dictionary
) -> Dictionary:
	var battle := Battle.new()
	battle.setup(rules, field, fighters, Rng.from_seed(SEED))
	var sight: int = rules.get("sight_cells", 0)
	var from_range := 0
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		var actor := battle.current()
		var choice := BattleAi.choose(battle, actor, sight)
		if actor.side == BattleUnit.COMPANY:
			choice = _hold_the_line(battle, actor)
		var target := battle.unit(str(choice.get("target", "")))
		var far := target != null and BattleGrid.gap(actor.cell, target.cell) > 1
		var events := battle.apply(choice)
		if events.is_empty():
			events = battle.apply({"type": Battle.ACTION_WAIT})
		var landed := events.any(
			func(e: Dictionary) -> bool: return e.get("type") == BattleResolver.EVENT_HIT
		)
		if actor.id == shooter and far and landed:
			from_range += 1
	return {"battle": battle, "from_range": from_range}


## A merc holding his place: his weapon action on the first foe it reaches, else a wait.
func _hold_the_line(battle: Battle, actor: BattleUnit) -> Dictionary:
	var reach := battle.targets(actor.id)
	if reach.is_empty():
		return {"type": Battle.ACTION_WAIT}
	return {"type": battle.kit(actor.id)[0], "target": reach[0]}
