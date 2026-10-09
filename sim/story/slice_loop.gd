class_name SliceLoop
extends RefCounted
## One scripted pass through the core loop for the art direction slice
## (docs/specs/art_direction_slice.md §2a; data/scenarios.json scn_slice_loop): arrive, inspect
## and hire (or pass on) a recruit, take the contract, travel, meet the bandit lookout (talk
## him down with a visible check, or fight), the battle, the fate of a yielding enemy, the
## return with one lasting injury, camp. A sketch: shallow on systems, inside the hard rules.
## Presentation reads stage and log and calls the step for the stage it shows; the sim
## decides every outcome. Seeded: the same seed and choices give the same log.

enum Stage { ARRIVE, RECRUIT, CONTRACT, TRAVEL, GATE, BATTLE, AFTERMATH, RETURN, CAMP, DONE }

const INJURY_STREAM := "story"

var stage := Stage.ARRIVE
var company: Array[String] = []
var recruit := ""
## What happened, in order, as ids and numbers for presentation to word:
## {"step": "hired"|"passed"|"contract"|"gate"|"battle"|"fate"|"injury"|"camp", ...}.
var log: Array[Dictionary] = []
var battle: Battle = null

var _scenario := {}
var _fighters := {}
var _rules := {}
var _gate := {}
var _rng: Rng = null
var _talked_down := false


## scenario: one entry of data/scenarios.json; battle_data: data/balance/battle.json.
func start(scenario: Dictionary, battle_data: Dictionary, rng: Rng) -> void:
	_scenario = scenario
	_fighters = _dict(battle_data, "fighters")
	_rules = _dict(battle_data, "rules")
	_gate = _dict(battle_data, "gate")
	_rng = rng
	company.clear()
	for id: Variant in _list(scenario, "company"):
		company.append(str(id))
	recruit = str(scenario.get("recruit", ""))
	stage = Stage.ARRIVE
	log.clear()


## The passive stages move on: arrive, travel, return and camp.
func advance() -> void:
	match stage:
		Stage.ARRIVE:
			stage = Stage.RECRUIT
		Stage.TRAVEL:
			stage = Stage.GATE
		Stage.RETURN:
			_return_home()
			stage = Stage.CAMP
		Stage.CAMP:
			log.append({"step": "camp"})
			stage = Stage.DONE


func hire(yes: bool) -> void:
	if stage != Stage.RECRUIT:
		return
	if yes:
		company.append(recruit)
	log.append({"step": "hired" if yes else "passed", "merc": recruit})
	stage = Stage.CONTRACT


func accept_contract() -> void:
	if stage == Stage.CONTRACT:
		log.append({"step": "contract", "id": str(_scenario.get("id", ""))})
		stage = Stage.TRAVEL


## The company member the check suggests (highest presence); the player may pick anyone.
func suggested_speaker() -> String:
	var skills := {}
	for id: String in company:
		skills[id] = _stat(id, "presence")
	return Checks.best(skills)


## One company member tries to talk the lookout down. Success: he slips away and the band
## starts shaken. Failure: he raises the alarm and fights with the band. Either way: battle.
func talk_down(speaker: String) -> Dictionary:
	if stage != Stage.GATE or speaker not in company:
		return {}
	var result := Checks.attempt(
		_rng,
		_num(_gate, "die_sides"),
		_stat(speaker, "presence"),
		_num(_gate, "talk_down_difficulty")
	)
	_talked_down = result.get("success", false) == true
	var entry := result.duplicate()
	entry.merge({"step": "gate", "speaker": speaker})
	log.append(entry)
	_begin_battle()
	return result


## Skip the talk and fight the whole band, lookout included.
func fight() -> void:
	if stage == Stage.GATE:
		log.append({"step": "gate", "speaker": "", "success": false})
		_talked_down = false
		_begin_battle()


## Call once battle.is_over(): a yielding band leads to the aftermath choice.
func end_battle() -> void:
	if stage != Stage.BATTLE or battle == null or not battle.is_over():
		return
	var won := battle.winner == BattleUnit.COMPANY
	log.append({"step": "battle", "won": won, "surrendered": battle.surrendered})
	stage = Stage.AFTERMATH if won and battle.surrendered == BattleUnit.ENEMY else Stage.RETURN


func choices() -> Array:
	return _list(_scenario, "aftermath_choices")


func choose_fate(choice: String) -> void:
	if stage == Stage.AFTERMATH and choice in choices():
		log.append({"step": "fate", "choice": choice})
		stage = Stage.RETURN


func _begin_battle() -> void:
	var setup := _dict(_scenario, "battle")
	var fighters: Array[BattleUnit] = []
	var cells := _list(setup, "company_cells")
	for i: int in mini(company.size(), cells.size()):
		fighters.append(_unit(company[i], company[i], BattleUnit.COMPANY, cells[i]))
	var index := 0
	var enemies := _list(setup, "enemies")
	if not _talked_down:
		enemies.append(_dict(setup, "lookout"))
	for entry: Variant in enemies:
		var enemy: Dictionary = entry if entry is Dictionary else {}
		var kind := str(enemy.get("fighter", ""))
		fighters.append(
			_unit("%s_%d" % [kind, index], kind, BattleUnit.ENEMY, enemy.get("cell", []))
		)
		index += 1
	battle = Battle.new()
	battle.setup(_rules, {"size": _cell(setup.get("grid", []))}, fighters, _rng)
	if _talked_down:
		battle.lower_morale(BattleUnit.ENEMY, _num(_gate, "shaken_morale"))
	stage = Stage.BATTLE


## The most hurt company member who was wounded keeps one lasting injury (Rng "story").
func _return_home() -> void:
	if battle == null:
		return
	var marked: BattleUnit = null
	for fighter: BattleUnit in battle.units:
		if fighter.side != BattleUnit.COMPANY or not fighter.wounded:
			continue
		if (
			marked == null
			or fighter.hp < marked.hp
			or (fighter.hp == marked.hp and fighter.id < marked.id)
		):
			marked = fighter
	var keys := _list(_scenario, "injury_keys")
	if marked != null and not keys.is_empty():
		var pick := _rng.roll(INJURY_STREAM, 0, keys.size() - 1)
		log.append({"step": "injury", "merc": marked.id, "key": str(keys[pick])})


func _unit(unit_id: String, kind: String, side: int, at: Variant) -> BattleUnit:
	return BattleUnit.make(unit_id, side, _cell(at), _dict(_fighters, kind))


func _stat(kind: String, key: String) -> int:
	return _num(_dict(_fighters, kind), key)


static func _cell(value: Variant) -> Vector2i:
	var pair: Array = value if value is Array else []
	if pair.size() < 2:
		return Vector2i.ZERO
	var x: float = pair[0] if pair[0] is float or pair[0] is int else 0.0
	var y: float = pair[1] if pair[1] is float or pair[1] is int else 0.0
	return Vector2i(roundi(x), roundi(y))


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}


static func _list(block: Dictionary, key: String) -> Array:
	var value: Variant = block.get(key, [])
	if not value is Array:
		return []
	var items: Array = value
	return items.duplicate()
