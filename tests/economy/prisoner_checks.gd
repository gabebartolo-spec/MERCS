extends RefCounted
## The economy-company suite's prisoner checks (Phase 5 C5, prisoners from the fight), run by
## tests/run_economy_company_tests.gd. The prisoners are the enemies a real fight reports as
## surrendered (EncounterBattle.taken), held one behind another and decided one at a time.
## Three fates (director Q-12: no recruit fate); each leaves a different company; a ransom is
## priced by the man's fighter type. Each fate is remembered by the captain and by the living
## merc, not the captain, with the strongest reaction to it (economy.json "prisoner"
## "reactions", placeholders; ties by id; nobody listed, the captain alone). The line of
## prisoners rides in the save as an optional key; an old save, one holding a recruit
## decision among them, loads and goes on; a reload in the middle of the line continues
## exactly as an uninterrupted run.
## Seeded by design: the fight is battle_surrender's (seed 424242); nothing else rolls.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const V2_FIXTURE := "res://tests/fixtures/save/v2.json"
const WORLD_BALANCE := "res://data/balance/world.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const DAY := 3
const FIELD := Vector2i(12, 8)
const COMPANY: Array[String] = ["orc", "vampyr", "recruit_placeholder"]
const COMPANY_CELLS: Array[Vector2i] = [Vector2i(2, 3), Vector2i(2, 5), Vector2i(1, 4)]
const ENEMIES: Array[String] = ["bandit_chief", "bandit", "bandit", "bandit"]
const ENEMY_CELLS: Array[Vector2i] = [
	Vector2i(11, 4), Vector2i(8, 2), Vector2i(8, 6), Vector2i(7, 4)
]
const MAX_TURNS := 400
## Any ceiling: these probes only read who reacts.
const MAX_MORALE := 100
const PAIR: Array[String] = ["bandit_chief_0", "bandit_1"]

var _check: Callable
var _rules: Dictionary = {}


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	var economy_rules: Dictionary = Fixture.defs()["economy"]
	_rules = economy_rules.get("prisoner", {})
	_check_data()
	_check_from_the_fight()
	_check_three_fates()
	_check_who_reacts()
	_check_line_and_refusals()
	_check_save_key_optional()
	_check_old_save_with_recruit()
	_check_reload_continue()


func _check_data() -> void:
	var priced: Dictionary = _rules.get("ransom_by_fighter", {})
	var fighters: Dictionary = Fixture.json(BATTLE_DATA).get("fighters", {})
	var bad := priced.keys().filter(
		func(kind: Variant) -> bool: return not fighters.has(kind) or Merc.whole(priced[kind]) <= 0
	)
	_check.call(
		Economy.CHOICES == ["release", "ransom", "execute"] and not _rules.has("recruit_morale"),
		"three fates, release, ransom and execute: recruiting waits for the director (Q-12)"
	)
	(
		_check
		. call(
			(
				not priced.is_empty()
				and bad.is_empty()
				and _rules.get("reactions_placeholder") == true
			),
			(
				"ransoms are priced by real fighter types (bad: %s); the reactions are flagged placeholder"
				% [bad]
			)
		)
	)


## battle_surrender's seeded fight: the men it reports as surrendered are the prisoners.
func _check_from_the_fight() -> void:
	var result := EncounterBattle.result(_fight())
	var taken := EncounterBattle.taken(result)
	var company := _company()
	company.economy.captives.take(DAY, taken)
	var kinds: Array[String] = []
	for held: Dictionary in company.economy.captives.held:
		kinds.append(str(held.get("kind", "")))
	var first := company.economy.prisoner
	_check.call(
		(
			result["won"] == true
			and not taken.is_empty()
			and company.economy.captives.held.size() == taken.size()
			and str(first.get("id", "")) == str(taken[0])
			and Merc.whole(first.get("day", 0)) == DAY
			and kinds.all(
				func(kind: String) -> bool: return kind == "bandit" or kind == "bandit_chief"
			)
		),
		"every man the fight reports surrendered is a prisoner, by id and type: %s" % [taken]
	)
	var price := _priced("bandit") if kinds[0] == "bandit" else _priced("bandit_chief")
	_check.call(
		company.economy.captives.ransom_coin() == price,
		"the waiting man's ransom is his fighter type's price (%d)" % price
	)


## Each fate on the same pair of prisoners leaves a different company.
func _check_three_fates() -> void:
	var start := _company().economy
	var after := {}
	for choice: String in Economy.CHOICES:
		after[choice] = _decide_pair(choice)
	var base := Vector2i(start.purse, start.morale)
	var released: Vector2i = after["release"]
	var ransomed: Vector2i = after["ransom"]
	var executed: Vector2i = after["execute"]
	var ransom := _priced("bandit_chief") + _priced("bandit")
	_check.call(
		released.y > base.y and released.x == base.x,
		"releasing lifts morale and changes no coin: %s" % [released]
	)
	_check.call(
		ransomed.x == base.x + ransom and ransomed.y < released.y,
		"ransoming brings each man's price (%d) and less morale than releasing" % ransom
	)
	_check.call(
		executed.y < base.y and executed.x == base.x, "executing costs the company its morale"
	)
	_check.call(
		released != ransomed and ransomed != executed and released != executed,
		"the three fates leave three company states"
	)


## Both men of PAIR given `choice`: the company's (purse, morale) after.
func _decide_pair(choice: String) -> Vector2i:
	var company := _company()
	var economy := company.economy
	economy.captives.take(DAY, PAIR)
	var decided := 0
	while economy.decide_prisoner(company, choice, DAY + 1):
		decided += 1
	var last := economy.chronicle[economy.chronicle.size() - 1]
	var ok := (
		decided == PAIR.size()
		and economy.prisoner.is_empty()
		and str(last["merc"]) == company.captain_id
		and str(last["key"]) == "prisoner." + choice
		and economy.chronicle.size() == PAIR.size() * 2
	)
	_check.call(ok, "%s: each man in turn, the reacting merc's line then the captain's" % choice)
	return Vector2i(economy.purse, economy.morale)


## The strongest reaction remembers: either sign, never the captain, never the dead, ties by id.
func _check_who_reacts() -> void:
	var company := _company()
	var captives := company.economy.captives
	var reactions: Dictionary = _rules.get("reactions", {})
	for choice: String in Economy.CHOICES:
		var listed: Dictionary = reactions.get(choice, {})
		var expected := _strongest(company, listed)
		_check.call(
			expected != "" and captives.reacting(company, choice) == expected,
			"%s: %s, the strongest reaction on the roster, remembers it" % [choice, expected]
		)
	var probe := Prisoners.new()
	var tied := {"orc": 9, "vampyr": -5, "merc_3": 5, "merc_4": 4}
	probe.setup({"reactions": {"release": tied}}, MAX_MORALE)
	_check.call(
		probe.reacting(company, "release") == "merc_3",
		"the captain (9) never reacts for the company; a tie of 5 and -5 goes to the lower id"
	)
	company.bury("merc_3")
	_check.call(probe.reacting(company, "release") == "vampyr", "a dead merc does not")
	var nobody := _company()
	nobody.economy.captives.setup({}, MAX_MORALE)
	nobody.economy.captives.take(DAY)
	nobody.economy.decide_prisoner(nobody, "release", DAY)
	_check.call(
		(
			nobody.economy.chronicle.size() == 1
			and str(nobody.economy.chronicle[0]["merc"]) == nobody.captain_id
		),
		"with nobody listed, only the captain remembers"
	)


func _check_line_and_refusals() -> void:
	var company := _company()
	var economy := company.economy
	_check.call(not economy.decide_prisoner(company, "release", 1), "no prisoner, no decision")
	economy.captives.take(1, PAIR)
	economy.captives.take(2, ["watchman_0"])
	_check.call(
		(
			not economy.decide_prisoner(company, "hang", 2)
			and not economy.decide_prisoner(company, Prisoners.RECRUIT, 2)
			and economy.captives.held.size() == 3
			and economy.chronicle.is_empty()
		),
		"an unknown fate and the dropped recruit fate are refused: all three men still wait"
	)
	economy.decide_prisoner(company, "release", 2)
	economy.decide_prisoner(company, "release", 2)
	_check.call(
		(
			str(economy.prisoner.get("id", "")) == "watchman_0"
			and economy.captives.ransom_coin() == _priced("watchman")
		),
		"a later fight's men wait behind the first fight's, decided in the order taken"
	)
	var phase_2 := _company().economy
	phase_2.captives.take(1)
	phase_2.captives.take(9)
	_check.call(
		phase_2.captives.held.size() == 1 and Merc.whole(phase_2.prisoner["day"]) == 1,
		"with no men named (the Phase 2 rule) a second prisoner does not stack"
	)


func _check_save_key_optional() -> void:
	var one := _company()
	one.economy.captives.take(DAY, ["bandit_0"])
	var held := _company()
	held.economy.captives.take(DAY, PAIR)
	var saved := _through_json(held.state())
	var back := Company.restore(saved, Fixture.defs())
	_check.call(
		(
			not one.economy.state().has("prisoners_behind")
			and _through_json(back.state()) == saved
			and back.economy.captives.held.size() == PAIR.size()
			and str(back.economy.prisoner.get("kind", "")) == "bandit_chief"
		),
		"one man saves as before C5; a line of men rides in prisoners_behind and comes back"
	)


## An old save that holds a recruit decision (Phase 2: a chronicle line and the memory) and a
## nameless waiting prisoner loads, words both, and decides on with the flat ransom.
func _check_old_save_with_recruit() -> void:
	var old := Fixture.json(V2_FIXTURE)
	var economy_saved: Dictionary = old["company"]["economy"]
	var chronicle: Array = economy_saved["chronicle"]
	chronicle.append({"day": 4, "merc": "orc", "key": "prisoner.recruit"})
	economy_saved["prisoner"] = {"day": 4}
	var model := SaveModel.from_dict(old, Fixture.json(WORLD_BALANCE), Fixture.defs())
	var economy := model.company.economy if model.ok else null
	var lines := (
		Text.t("hub.memory.prisoner.recruit", {"name": "Orc"}) + Text.t("memory.fate_recruit")
	)
	_check.call(
		(
			economy != null
			and economy.chronicle.back()["key"] == "prisoner.recruit"
			and not lines.contains("prisoner.recruit")
			and not lines.contains("fate_recruit")
			and economy.captives.held.size() == 1
		),
		"an old save holding a recruit decision loads and its lines still read"
	)
	if economy == null:
		return
	var purse := economy.purse
	_check.call(
		(
			economy.decide_prisoner(model.company, "ransom", 5)
			and economy.purse == purse + Merc.whole(_rules["ransom_coin"])
		),
		"its nameless prisoner is ransomed at the flat price"
	)


func _check_reload_continue() -> void:
	var straight := _company()
	straight.economy.captives.take(DAY, PAIR)
	straight.economy.decide_prisoner(straight, "ransom", DAY)
	var reloaded := Company.restore(_through_json(straight.state()), Fixture.defs())
	straight.economy.decide_prisoner(straight, "execute", DAY)
	reloaded.economy.decide_prisoner(reloaded, "execute", DAY)
	_check.call(
		_through_json(reloaded.state()) == _through_json(straight.state()),
		"save between two prisoners, reload, decide the second: same as never stopping"
	)


func _strongest(company: Company, listed: Dictionary) -> String:
	var best := ""
	var top := 0
	var ids: Array[String] = []
	for merc: Merc in company.roster:
		ids.append(merc.id)
	ids.sort()
	for merc_id: String in ids:
		var strength := absi(Merc.whole(listed.get(merc_id, 0)))
		if merc_id != company.captain_id and strength > top:
			best = merc_id
			top = strength
	return best


func _fight() -> Battle:
	var data := Fixture.json(BATTLE_DATA)
	var rules: Dictionary = data.get("rules", {})
	var kinds: Dictionary = data.get("fighters", {})
	var fighters: Array[BattleUnit] = []
	for i: int in COMPANY.size():
		var stats: Dictionary = kinds.get(COMPANY[i], {})
		fighters.append(BattleUnit.make(COMPANY[i], BattleUnit.COMPANY, COMPANY_CELLS[i], stats))
	for i: int in ENEMIES.size():
		var stats: Dictionary = kinds.get(ENEMIES[i], {})
		var unit_id := "%s_%d" % [ENEMIES[i], i]
		fighters.append(BattleUnit.make(unit_id, BattleUnit.ENEMY, ENEMY_CELLS[i], stats))
	var battle := Battle.new()
	battle.setup(rules, {"size": FIELD}, fighters, Rng.from_seed(SEED))
	var gate: Dictionary = data.get("gate", {})
	battle.lower_morale(BattleUnit.ENEMY, Merc.whole(gate.get("shaken_morale", 0)))
	var sight := Merc.whole(rules.get("sight_cells", 0))
	for _turn: int in MAX_TURNS:
		if battle.is_over():
			break
		battle.apply(BattleAi.choose(battle, battle.current(), sight))
	return battle


func _priced(kind: String) -> int:
	var priced: Dictionary = _rules.get("ransom_by_fighter", {})
	return Merc.whole(priced.get(kind, 0))


func _company() -> Company:
	return Company.start(Fixture.defs())


func _through_json(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}
