extends RefCounted
## The battle suite's checks that the enemy is not psychic (CLAUDE.md rule 6, Phase 4 P5), run
## by tests/run_battle_tests.gd: a fighter decides only from what it could see (opponents
## within sight_cells, and whether each looks wounded), never from exact health, the other
## numbers or anyone out of sight. The enemy strikes the foe it saw bleed, not the one with
## less hidden health; changing hidden numbers changes nothing it decides; a foe out of sight
## is neither planned for nor walked toward; a company merc playing his moves (MercPlay) reads
## the same knowledge; and the AI's files read no hidden number at all.
## Seeded by design: every roll comes from Rng.from_seed(SEED); the checks roll nothing.

const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const FIELD := Vector2i(16, 3)
const ENEMY_CELL := Vector2i(5, 1)
const FRAIL_CELL := Vector2i(4, 1)
const BLOODIED_CELL := Vector2i(6, 1)
const NEAR_CELL := Vector2i(9, 1)
const BEYOND_SIGHT := 1
## Health a hidden-number variant sets: far below and far above anything in battle.json.
const LOW := 1
const HIGH := 99
const AI_FILES: Array[String] = [
	"res://sim/battle/battle_ai.gd",
	"res://sim/battle/battle_knowledge.gd",
]
## Reads of numbers an opponent cannot see; none may appear in the AI's files.
const HIDDEN_READS := "\\.(hp|max_hp|attack|defense|damage|initiative|presence|moves)\\b"

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_strikes_the_seen_wound()
	_check_hidden_numbers_change_nothing()
	_check_out_of_sight()
	_check_merc_reads_the_same()
	_check_no_hidden_reads()


func _data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_DATA))
	return parsed if parsed is Dictionary else {}


func _rules() -> Dictionary:
	var rules: Variant = _data().get("rules", {})
	return rules if rules is Dictionary else {}


func _sight() -> int:
	return BattleRules.read(_rules(), "sight_cells")


## A fighter of battle.json "fighters" by kind, never a leader (no morale side effects).
func _make(unit_id: String, side: int, at: Vector2i, kind: String) -> BattleUnit:
	var kinds: Dictionary = _data().get("fighters", {})
	var found: Dictionary = kinds.get(kind, {})
	var stats := found.duplicate()
	stats.erase("leader")
	return BattleUnit.make(unit_id, side, at, stats)


## A watchman between a frail, unhurt company fighter (less health, unseen) and a tough one
## the watchman saw wounded (more health left).
func _between() -> Battle:
	var bloodied := _make("bloodied", BattleUnit.COMPANY, BLOODIED_CELL, "orc")
	bloodied.hp = bloodied.max_hp - 1
	bloodied.wounded = true
	var frail := _make("frail", BattleUnit.COMPANY, FRAIL_CELL, "bandit")
	var fighters: Array[BattleUnit] = [
		_make("watchman", BattleUnit.ENEMY, ENEMY_CELL, "watchman"), frail, bloodied
	]
	var battle := Battle.new()
	battle.setup(_rules(), {"size": FIELD}, fighters, Rng.from_seed(SEED))
	return battle


func _decide(battle: Battle) -> String:
	var watchman := battle.unit("watchman")
	var plan := BattleAi.intent(battle, watchman, _sight())
	var act := BattleAi.choose(battle, watchman, _sight())
	return "%s %s / %s %s" % [plan["kind"], plan["target"], act["type"], act.get("target", "")]


func _check_strikes_the_seen_wound() -> void:
	var decided := _decide(_between())
	_check.call(
		decided == "attack bloodied / attack bloodied",
		"the enemy plans and strikes the foe it saw wounded, not the one with less hidden health"
	)


## The same scene with every hidden number changed (health high and low, the other numbers
## swapped, a wound kept as a wound) and an unseen fighter added beyond sight.
func _check_hidden_numbers_change_nothing() -> void:
	var plain := _decide(_between())
	var same := true
	for health: int in [LOW, HIGH]:
		var battle := _between()
		var frail := battle.unit("frail")
		var bloodied := battle.unit("bloodied")
		frail.hp = HIGH - health + LOW
		frail.max_hp = HIGH
		bloodied.hp = health
		bloodied.max_hp = HIGH
		frail.damage = health
		frail.attack = health
		bloodied.defense = health
		bloodied.initiative = health
		same = same and _decide(battle) == plain
	_check.call(same, "hidden numbers (exact health, attack, defence, damage) change no choice")


## A watchman with a wounded foe just beyond sight behind him and an unhurt one in sight.
func _check_out_of_sight() -> void:
	var sight := _sight()
	var at := Vector2i(sight + BEYOND_SIGHT + 1, 1)
	var watchman := _make("watchman", BattleUnit.ENEMY, at, "watchman")
	var near := _make("near", BattleUnit.COMPANY, at + NEAR_CELL - ENEMY_CELL, "bandit")
	var hidden := _make("hidden", BattleUnit.COMPANY, Vector2i(0, 1), "bandit")
	hidden.hp = LOW
	hidden.wounded = true
	var fighters: Array[BattleUnit] = [watchman, near, hidden]
	var battle := Battle.new()
	var field := Vector2i(near.cell.x + 1, FIELD.y)
	battle.setup(_rules(), {"size": field}, fighters, Rng.from_seed(SEED))
	var plan := BattleAi.intent(battle, watchman, sight)
	var act := BattleAi.choose(battle, watchman, sight)
	var to: Vector2i = act.get("to", at)
	var closer := BattleGrid.gap(to, near.cell) < BattleGrid.gap(at, near.cell)
	_check.call(
		str(plan.get("target")) == "near" and str(act.get("type")) == Battle.ACTION_MOVE and closer,
		"a wounded foe out of sight is neither planned for nor walked toward; the seen one is"
	)


## The Vampyr pays his blood price on a foe he saw bleed, never on health he cannot see.
func _check_merc_reads_the_same() -> void:
	var rules := _rules()
	var vampyr := _make("vampyr", BattleUnit.COMPANY, FRAIL_CELL, "vampyr")
	var foe := _make("foe", BattleUnit.ENEMY, ENEMY_CELL, "bandit_chief")
	var fighters: Array[BattleUnit] = [vampyr, foe]
	var battle := Battle.new()
	battle.setup(rules, {"size": FIELD}, fighters, Rng.from_seed(SEED))
	foe.hp = LOW
	var unhurt := str(MercPlay.choose(battle, vampyr, rules).get("type"))
	foe.hp = foe.max_hp - LOW
	foe.wounded = true
	var bleeding := str(MercPlay.choose(battle, vampyr, rules).get("type"))
	_check.call(
		unhurt == Battle.ACTION_ATTACK and bleeding == Battle.ACTION_BLOOD_PRICE,
		"the Vampyr spends his blood on a foe he saw wounded, not on hidden low health"
	)


func _check_no_hidden_reads() -> void:
	var pattern := RegEx.create_from_string(HIDDEN_READS)
	var found: Array[String] = []
	for path: String in AI_FILES:
		var source := FileAccess.get_file_as_string(path)
		for line: String in source.split("\n"):
			if not line.strip_edges().begins_with("#") and pattern.search(line) != null:
				found.append("%s: %s" % [path.get_file(), line.strip_edges()])
	if not found.is_empty():
		print("HIDDEN READS: %s" % "; ".join(found))
	_check.call(found.is_empty(), "the AI's files read no hidden number (health, attack, moves)")
