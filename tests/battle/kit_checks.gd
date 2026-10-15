extends RefCounted
## The battle suite's action-kit checks (Phase 4 P1a; director Q-A "1 weapon + 4 moves", Q-B
## "Sword, axe, spear, mace, bow", 2026-10-15), run by tests/run_battle_tests.gd: the catalogue
## (battle.json "rules" "actions") stays within the actions cap in data/caps.json and names the
## five weapon classes; a fighter's kit is his weapon action then at most four catalogued
## techniques; only the kit (and move, attack, wait) is legal; the spear's action reaches two
## cells, the others one, the bow's shot waits for P1c; a fight with the spear's action replays
## through FightRecord. Seeded by design: every roll comes from Rng.from_seed(SEED).

const BATTLE_DATA := "res://data/balance/battle.json"
const CAPS_DATA := "res://data/caps.json"
const SEED := 424242
const GRID := Vector2i(10, 8)
const SURE_HIT := 100
const MAX_TURNS := 200
const CLASSES: Array[String] = ["sword", "axe", "spear", "mace", "bow"]
## Move and wait are always open; counted against the cap with the catalogue (the strict read
## of "10 actions total").
const ALWAYS_OPEN := 2

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_catalogue()
	_check_kit_shape()
	_check_kit_legality()
	_check_reach()
	_check_bow_waits()
	_check_enemy_bow_ends()
	_check_weapon_replaces_attack()
	_check_base_ids_do_not_crowd()
	_check_replay()


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _rules() -> Dictionary:
	var rules: Variant = _json(BATTLE_DATA).get("rules", {})
	return rules if rules is Dictionary else {}


func _battle(fighters: Array[BattleUnit]) -> Battle:
	var battle := Battle.new()
	battle.setup(_rules(), {"size": GRID, "blocked": {}}, fighters, Rng.from_seed(SEED))
	return battle


func _unit(unit_id: String, side: int, at: Vector2i, stats: Dictionary) -> BattleUnit:
	return BattleUnit.make(unit_id, side, at, stats)


func _check_catalogue() -> void:
	var rules := BattleRules.new()
	rules.setup(_rules())
	var caps: Variant = _json(CAPS_DATA).get("caps", {})
	var cap_table: Dictionary = caps if caps is Dictionary else {}
	var cap: int = cap_table.get("actions", 0)
	var ids := rules.action_ids()
	var weapons := rules.actions(BattleRules.WEAPON)
	var classes_ok := CLASSES.all(func(c: String) -> bool: return weapons.has(c))
	var techniques_ok := rules.actions(BattleRules.TECHNIQUE).keys().all(
		func(m: Variant) -> bool: return rules.is_technique(str(m))
	)
	var catalogue: Variant = _rules().get("actions", {})
	var only_known := catalogue is Dictionary
	if catalogue is Dictionary:
		var block: Dictionary = catalogue
		only_known = block.keys().all(
			func(k: Variant) -> bool: return str(k) in BattleRules.CATEGORIES
		)
	_check.call(
		(
			cap == 10
			and ids.size() + ALWAYS_OPEN <= cap
			and weapons.size() == CLASSES.size()
			and classes_ok
			and techniques_ok
			and only_known
		),
		(
			(
				"the catalogue (%d actions, + move and wait) fits the cap of %d, names the five "
				+ "weapon classes, and every technique has its numbers"
			)
			% [ids.size(), cap]
		)
	)


func _check_kit_shape() -> void:
	var data := _json(BATTLE_DATA)
	var kinds: Dictionary = data.get("fighters", {})
	var orc_stats: Dictionary = kinds.get("orc", {})
	# The orc's data carries his axe (battle.json "gear", P1b), so his weapon action is "axe".
	var plain := _unit("o", BattleUnit.COMPANY, Vector2i(1, 1), orc_stats)
	var spear_stats := orc_stats.duplicate()
	spear_stats["weapon_class"] = "spear"
	var spearman := _unit("s", BattleUnit.COMPANY, Vector2i(1, 3), spear_stats)
	var odd := _unit("f", BattleUnit.COMPANY, Vector2i(1, 5), {"weapon_class": "flail"})
	var many: Array = ["move", "charge", "m3", "blood_price"]
	var learner := _unit("l", BattleUnit.COMPANY, Vector2i(1, 7), {"moves": many})
	var bandit := _unit("b", BattleUnit.ENEMY, Vector2i(8, 1), {})
	var battle := _battle([plain, spearman, odd, learner, bandit])
	var shapes := [battle.kit("o"), battle.kit("s"), battle.kit("f"), battle.kit("l")]
	var want := [
		["axe", "charge"], ["spear", "charge"], ["attack"], ["attack", "charge", "blood_price"]
	]
	_check.call(
		shapes == want and battle.kit("nobody").is_empty(),
		(
			(
				"a kit is the weapon action (the class's, else attack) then the catalogued "
				+ "techniques learnt, once each, never base actions or unknown moves: %s"
			)
			% [shapes]
		)
	)


func _check_kit_legality() -> void:
	var rules := _rules()
	var cap: int = rules.get("loadout_max", 0)
	var five: Array = ["charge", "blood_price", "charge", "blood_price", "charge"]
	var c := _unit("c", BattleUnit.COMPANY, Vector2i(1, 1), {"initiative": 3, "moves": five})
	c.weapon_class = "sword"
	var b := _unit("b", BattleUnit.ENEMY, Vector2i(2, 1), {"hp": SURE_HIT})
	var battle := _battle([c, b])
	var size_ok := battle.kit("c").size() <= 1 + cap
	var foreign := battle.apply({"type": "spear", "target": "b"}).is_empty()
	var uncatalogued := battle.apply({"type": "bow", "target": "b"}).is_empty()
	var sword := battle.apply({"type": "sword", "target": "b"})
	var struck: bool = not sword.is_empty() and sword[0].get("move") == "sword"
	_check.call(
		cap == 4 and size_ok and foreign and uncatalogued and struck,
		"only the kit is legal: a sword-bearer's sword strikes, a spear or bow he lacks is refused"
	)


## A spear strikes a foe two cells off; a sword and the plain blow do not; nobody reaches three.
func _check_reach() -> void:
	var results: Array[bool] = []
	for case: Array in [["spear", 2, true], ["spear", 3, false], ["sword", 2, false]]:
		var kind: String = case[0]
		var gap: int = case[1]
		var c := _unit("c", BattleUnit.COMPANY, Vector2i(1, 1), {"initiative": 3})
		c.weapon_class = kind
		var b := _unit("b", BattleUnit.ENEMY, Vector2i(1 + gap, 1), {"hp": SURE_HIT})
		var battle := _battle([c, b])
		var plain := battle.apply({"type": Battle.ACTION_ATTACK, "target": "b"}).is_empty()
		var events := battle.apply({"type": kind, "target": "b"})
		var reached: bool = not events.is_empty() and events[0].get("type") == "attack"
		var expected: bool = case[2] == true
		results.append(plain and reached == expected)
	_check.call(
		results.all(func(ok: bool) -> bool: return ok),
		(
			"a spear reaches two cells (not three); a sword and the plain blow reach one: %s"
			% [results]
		)
	)


func _check_bow_waits() -> void:
	var c := _unit("c", BattleUnit.COMPANY, Vector2i(1, 1), {"initiative": 3})
	c.weapon_class = "bow"
	var b := _unit("b", BattleUnit.ENEMY, Vector2i(2, 1), {"hp": SURE_HIT})
	var battle := _battle([c, b])
	var refused := battle.apply({"type": "bow", "target": "b"}).is_empty()
	var log_before := battle.log.size()
	var plain := battle.apply({"type": Battle.ACTION_ATTACK, "target": "b"}).is_empty()
	_check.call(
		battle.kit("c") == ["bow"] and refused and plain and battle.log.size() == log_before,
		(
			"a bow's shot is in the kit but refused until its line of fire exists (P1c); "
			+ "the plain blow is not open beside it (the weapon action replaces it)"
		)
	)


## An enemy archer beside a merc: his shot is refused until P1c, so BattleAi.act waits in its
## place (the battle view plays enemy turns through it) and the fight still runs to its end.
func _check_enemy_bow_ends() -> void:
	var c := _unit("c", BattleUnit.COMPANY, Vector2i(1, 1), {"attack": SURE_HIT})
	var b := _unit("b", BattleUnit.ENEMY, Vector2i(2, 1), {"initiative": 9})
	b.weapon_class = "bow"
	var battle := _battle([c, b])
	var enemy_turns := 0
	var stuck := false
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		if battle.current().side == BattleUnit.ENEMY:
			enemy_turns += 1
			stuck = stuck or BattleAi.act(battle, battle.current(), GRID.x).is_empty()
		else:
			battle.apply({"type": battle.kit("c")[0], "target": "b"})
	_check.call(
		battle.is_over() and enemy_turns > 0 and not stuck,
		"an enemy archer beside a merc waits in place of his refused shot; the fight still ends"
	)


## Director Q-A "1 weapon + 4 moves": a fighter with a weapon class has no plain attack beside
## his weapon action; one without a class keeps it; move and wait stay open for both.
func _check_weapon_replaces_attack() -> void:
	var classed := _unit("c", BattleUnit.COMPANY, Vector2i(1, 1), {"initiative": 9})
	classed.weapon_class = "sword"
	var bare := _unit("u", BattleUnit.COMPANY, Vector2i(1, 3), {"initiative": 8})
	var foe := _unit("b", BattleUnit.ENEMY, Vector2i(2, 2), {"hp": SURE_HIT, "initiative": 1})
	var battle := _battle([classed, bare, foe])
	var blow := {"type": Battle.ACTION_ATTACK, "target": "b"}
	var classed_plain := battle.apply(blow).is_empty()
	var classed_sword := not battle.apply({"type": "sword", "target": "b"}).is_empty()
	var bare_plain := not battle.apply(blow).is_empty()
	var move_open := not battle.apply({"type": Battle.ACTION_WAIT}).is_empty()
	_check.call(
		classed_plain and classed_sword and bare_plain and move_open,
		(
			"a classed fighter's plain attack is refused and his weapon action strikes; "
			+ "a classless one keeps the plain attack"
		)
	)


## A listed base id (move, attack, wait) must not push a learnt technique out of the kit: the
## catalogued techniques are filtered first, then capped at four.
func _check_base_ids_do_not_crowd() -> void:
	var listed: Array = ["move", "attack", "wait", "charge", "blood_price"]
	var learner := _unit("l", BattleUnit.COMPANY, Vector2i(1, 1), {"moves": listed})
	var foe := _unit("b", BattleUnit.ENEMY, Vector2i(8, 1), {})
	var battle := _battle([learner, foe])
	_check.call(
		(
			battle.kit("l") == ["attack", "charge", "blood_price"]
			and str(battle.unit("l").moves) == str(["charge", "blood_price"])
		),
		(
			"base ids listed among the moves do not crowd a learnt technique out: %s"
			% [battle.kit("l")]
		)
	)


## A seeded fight in which a spearman strikes over his front-liner replays through FightRecord.
func _check_replay() -> void:
	var first := _spear_fight()
	var played: Battle = first["battle"]
	var actions: Array[Dictionary] = first["actions"]
	var record := FightRecord.make({})
	for action: Dictionary in actions:
		record.record(action)
	var through: Variant = JSON.parse_string(JSON.stringify(record.saved()))
	var saved: Dictionary = through if through is Dictionary else {}
	var plain := FightRecord.read(saved)
	var again := _spear_line()
	var applied := FightRecord.replay(again, plain)
	var spear_blows := played.log.filter(
		func(e: Dictionary) -> bool: return e.get("type") == "attack" and e.get("move") == "spear"
	)
	_check.call(
		(
			not spear_blows.is_empty()
			and applied == actions.size()
			and JSON.stringify(again.log) == JSON.stringify(played.log)
		),
		(
			"a fight with %d spear blows replays through FightRecord to the same log"
			% spear_blows.size()
		)
	)


func _spear_line() -> Battle:
	var front := _unit("front", BattleUnit.COMPANY, Vector2i(3, 1), {"hp": 20, "initiative": 2})
	var spear := _unit("spear", BattleUnit.COMPANY, Vector2i(2, 1), {"initiative": 3})
	spear.weapon_class = "spear"
	var bandit := _unit("b", BattleUnit.ENEMY, Vector2i(4, 1), {"hp": 20, "initiative": 1})
	return _battle([front, spear, bandit])


func _spear_fight() -> Dictionary:
	var battle := _spear_line()
	var actions: Array[Dictionary] = []
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		var actor := battle.current()
		var action := {"type": Battle.ACTION_WAIT}
		if actor.id == "spear":
			action = {"type": "spear", "target": "b"}
		elif actor.id == "front":
			action = {"type": Battle.ACTION_ATTACK, "target": "b"}
		elif actor.id == "b":
			action = {"type": Battle.ACTION_ATTACK, "target": "front"}
		if battle.apply(action).is_empty():
			action = {"type": Battle.ACTION_WAIT}
			battle.apply(action)
		actions.append(action)
	return {"battle": battle, "actions": actions}
