class_name LoopDirector
extends Node
## Plays the slice's one pass of the core loop on screen (docs/specs/art_direction_slice.md
## §2a): reads the sim SliceLoop's stage and log, shows the matching grey-box panel, turns
## the player's choice into the SliceLoop step, and hands the battle to BattleView. Travel
## turns the street to dusk and rain. Content comes from data/scenarios.json and
## data/balance/battle.json, words from data/text/en.json. The sim decides every outcome.

signal ended

const SCENARIOS := "res://data/scenarios.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const SCENARIO_ID := "scn_slice_loop"
const CONTINUE := "continue"

var loop := SliceLoop.new()
var panel: LoopPanel = null
var view: BattleView = null

var _stage: StreetStage = null
var _origin := Vector2i.ZERO
var _gate_result := {}


## Starts the pass from a seed; origin is the street cell under battle cell (0, 0).
func begin(stage: StreetStage, origin: Vector2i, seed_value: int) -> void:
	_stage = stage
	_origin = origin
	var battle_data := _json(BATTLE_DATA)
	loop.start(_scenario(), battle_data, Rng.from_seed(seed_value))
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = LoopPanel.new()
	layer.add_child(panel)
	panel.chosen.connect(_on_choice)
	_show()


func in_battle() -> bool:
	return loop.stage == SliceLoop.Stage.BATTLE and view != null


func _on_choice(choice_id: String) -> void:
	if in_battle():
		return
	# A talk attempt already began the battle in the sim; its result panel's press shows it.
	if loop.stage == SliceLoop.Stage.BATTLE:
		_start_battle()
		return
	match loop.stage:
		SliceLoop.Stage.RECRUIT:
			loop.hire(choice_id == "hire")
		SliceLoop.Stage.CONTRACT:
			loop.accept_contract()
		SliceLoop.Stage.TRAVEL:
			_stage.set_conditions(StageLighting.TimeOfDay.DUSK, true)
			loop.advance()
		SliceLoop.Stage.GATE:
			_gate(choice_id)
			return
		SliceLoop.Stage.AFTERMATH:
			loop.choose_fate(choice_id)
		SliceLoop.Stage.DONE:
			ended.emit()
			return
		_:
			loop.advance()
	_show()


## The gate: a talk attempt shows its roll first; the next press starts the battle.
func _gate(choice_id: String) -> void:
	if choice_id == "fight":
		loop.fight()
		_start_battle()
	else:
		_gate_result = loop.talk_down(choice_id)
		var key := (
			"slice.gate.success" if _gate_result.get("success", false) else "slice.gate.failure"
		)
		var params := _gate_result.duplicate()
		params["name"] = Text.t("cast.%s.name" % choice_id)
		panel.present(Text.t("slice.gate.title"), Text.t(key, params), _continue())


func _start_battle() -> void:
	view = BattleView.new()
	add_child(view)
	var rules: Dictionary = _json(BATTLE_DATA).get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	view.street_stage = _stage
	view.panel = panel
	view.begin(loop.battle, _origin, sight)
	view.finished.connect(_on_battle_over)


func _on_battle_over() -> void:
	loop.end_battle()
	_show()


## The panel for the current stage.
func _show() -> void:
	match loop.stage:
		SliceLoop.Stage.ARRIVE:
			_say("arrive", _continue())
		SliceLoop.Stage.RECRUIT:
			_recruit_card()
		SliceLoop.Stage.CONTRACT:
			_say("contract", [{"id": "accept", "label": Text.t("slice.button.accept")}])
		SliceLoop.Stage.TRAVEL:
			_say("travel", _continue())
		SliceLoop.Stage.GATE:
			_gate_panel()
		SliceLoop.Stage.AFTERMATH:
			_fate_panel()
		SliceLoop.Stage.RETURN:
			panel.present(Text.t("slice.return.title"), _injury_line(), _continue())
		SliceLoop.Stage.CAMP:
			_say("camp", _continue())
		SliceLoop.Stage.DONE:
			_say("done", [{"id": "end", "label": Text.t("slice.button.end")}])


func _say(stage_key: String, choices: Array[Dictionary]) -> void:
	panel.present(
		Text.t("slice.%s.title" % stage_key), Text.t("slice.%s.body" % stage_key), choices
	)


func _recruit_card() -> void:
	var fighters: Dictionary = _json(BATTLE_DATA).get("fighters", {})
	var stats: Dictionary = fighters.get(loop.recruit, {})
	var params := stats.duplicate()
	params["name"] = Text.t("cast.%s.name" % loop.recruit)
	(
		panel
		. present(
			Text.t("slice.recruit.title"),
			Text.t("slice.recruit.body", params),
			[
				{"id": "hire", "label": Text.t("slice.button.hire")},
				{"id": "pass", "label": Text.t("slice.button.pass")},
			]
		)
	)


func _gate_panel() -> void:
	var choices: Array[Dictionary] = []
	var suggested := loop.suggested_speaker()
	var fighters: Dictionary = _json(BATTLE_DATA).get("fighters", {})
	for merc: String in loop.company:
		var stats: Dictionary = fighters.get(merc, {})
		var mark := Text.t("slice.gate.suggested") if merc == suggested else ""
		var params := {
			"name": Text.t("cast.%s.name" % merc),
			"presence": stats.get("presence", 0),
			"suggested": mark
		}
		choices.append({"id": merc, "label": Text.t("slice.gate.talk", params)})
	choices.append({"id": "fight", "label": Text.t("slice.gate.fight")})
	_say("gate", choices)


func _fate_panel() -> void:
	var choices: Array[Dictionary] = []
	for choice: Variant in loop.choices():
		choices.append({"id": str(choice), "label": Text.t("slice.fate.%s" % choice)})
	_say("fate", choices)


func _injury_line() -> String:
	for entry: Dictionary in loop.log:
		if entry.get("step") == "injury":
			return Text.t(
				str(entry.get("key", "")), {"name": Text.t("cast.%s.name" % entry.get("merc", ""))}
			)
	return Text.t("slice.return.unhurt")


func _continue() -> Array[Dictionary]:
	return [{"id": CONTINUE, "label": Text.t("slice.button.continue")}]


func _scenario() -> Dictionary:
	var all: Array = _json(SCENARIOS).get("scenarios", [])
	for entry: Variant in all:
		var scenario: Dictionary = entry if entry is Dictionary else {}
		if scenario.get("id") == SCENARIO_ID:
			return scenario
	return {}


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
