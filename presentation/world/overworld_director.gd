class_name OverworldDirector
extends Node
## The overworld on screen (Phase 2 M1b): one WorldSim from data/balance/world.json, drawn
## as a flat map over the street (OverworldMap), and the company's day chosen through a
## LoopPanel list: a road to each neighbouring site, a day's rest, or a save. Opens on the
## save on disk when there is one (SaveSystem), so a closed game continues where it was;
## otherwise on a fresh region from the balance seed. One director lives for the session:
## hiding the map (set_open) keeps the run; only "Save" writes it to disk. The sim decides
## every day and every cost; this only words and draws them. Words: data/text/en.json.
## An encounter on the road (M2) swaps the choices for its own: Fight closes the map and runs
## the existing street battle (BattleView) on the stage SliceGame hands in, then the result
## goes back through WorldSim.resolve_encounter() and the map reopens with the outcome.

const WORLD_DATA := "res://data/balance/world.json"
const REST := "rest"
const SAVE := "save"
const FIGHT := "fight"
const TOLL := "toll"
const ENCOUNTER_DATA := "res://data/encounters.json"
const SCENARIOS := "res://data/scenarios.json"
const SCENARIO_ID := "scn_slice_loop"
const BATTLE_DATA := "res://data/balance/battle.json"
## The SaveSystem autoload by its script: a headless --script run (the test suites) knows
## no autoload by name, but every run has it in the tree.
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SAVE_SYSTEM_PATH := ^"/root/SaveSystem"

var world: WorldSim = null
var rng: Rng = null
var panel: LoopPanel = null
var map: OverworldMap = null
## The company saved with the world (the game's one Company, set by the owner before begin()).
var company: Company = null
## Set by SliceGame before begin(): the street the fight is drawn on and the street cell
## under battle cell (0, 0).
var street_stage: StreetStage = null
var origin := Vector2i.ZERO
## The street battle while one is on screen, else null.
var view: BattleView = null

var _balance: Dictionary = {}
var _layer: CanvasLayer = null


## Continues the save on disk, or starts a fresh region, and shows the map and the choices.
func begin() -> void:
	_balance = _json(WORLD_DATA)
	var numbers := StageData.load_file(WORLD_DATA)
	if _saves().has_save():
		var model := _saves().load_game(_balance)
		if model.ok:
			world = model.world
			rng = model.rng
	if world == null:
		rng = Rng.from_seed(int(numbers.num("world", "seed")))
		world = WorldSim.new()
		world.start(_balance, rng)
	var lineups: Array = _json(ENCOUNTER_DATA).get("encounters", [])
	world.set_lineups(lineups)
	_layer = CanvasLayer.new()
	add_child(_layer)
	map = OverworldMap.new()
	map.setup(Vector2i(int(numbers.num("region", "grid_w")), int(numbers.num("region", "grid_h"))))
	_layer.add_child(map)
	panel = LoopPanel.new()
	_layer.add_child(panel)
	panel.chosen.connect(_on_choice)
	_show(Text.t("world.panel.body"))


## Whether the map is on screen; the run lives on while it is hidden.
func is_open() -> bool:
	return _layer != null and _layer.visible


## Whether a street battle from an encounter is on screen.
func in_fight() -> bool:
	return view != null


## Shows the map (redrawn with the day's choices) or hides it, keeping the run. A fight
## in progress keeps the screen: the map cannot be closed under it.
func set_open(open: bool) -> void:
	if _layer == null or (in_fight() and not open):
		return
	_layer.visible = open
	if open:
		_show(Text.t("world.panel.body"))


func _on_choice(choice_id: String) -> void:
	if in_fight():
		return
	match choice_id:
		FIGHT:
			_start_fight()
		TOLL:
			world.pay_toll()
			_show(_outcome_line())
		REST:
			world.rest()
			_show(Text.t("world.panel.body"))
		SAVE:
			var saved := _saves().save_game(world, rng, company)
			_show(Text.t("world.panel.saved" if saved else "world.panel.save_failed"))
		_:
			world.travel_to(choice_id)
			_show(Text.t("world.panel.body"))


## Closes the map over the street and starts the battle the standing encounter leads into.
func _start_fight() -> void:
	if world.encounter.is_empty() or street_stage == null:
		return
	var battle_data := _json(BATTLE_DATA)
	var battle := EncounterBattle.build(world.pending_encounter(), _scenario(), battle_data, rng)
	map.visible = false
	view = BattleView.new()
	add_child(view)
	view.street_stage = street_stage
	view.panel = panel
	var rules: Dictionary = battle_data.get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	view.begin(battle, origin, sight)
	view.finished.connect(_on_fight_over)


## The battle ended: the fighters leave the street, the sim applies the result, the map returns.
func _on_fight_over() -> void:
	var result := EncounterBattle.result(view.battle)
	view.clear()
	view.queue_free()
	view = null
	world.resolve_encounter(result)
	map.visible = true
	_show(_outcome_line())


## The last encounter log entry in words: what the company won, lost or paid.
func _outcome_line() -> String:
	for i: int in range(world.log.size() - 1, -1, -1):
		var entry := world.log[i]
		if entry.get("step") != "encounter":
			continue
		var outcome := str(entry.get("outcome", ""))
		var change: int = entry.get("supplies", 0)
		var params := {
			"supplies": absi(change), "site": OverworldMap.site_name(world.site(world.at))
		}
		return Text.t("world.encounter.outcome.%s" % outcome, params)
	return Text.t("world.panel.body")


## Redraws the map and lists the day's choices: each road out, a rest, a save.
func _show(body: String) -> void:
	map.show_world(world)
	if not world.encounter.is_empty():
		_show_encounter()
		return
	var choices: Array[Dictionary] = []
	var here := world.site(world.at)
	for site_id: String in world.destinations():
		var days := here.days_to(site_id)
		var params := {"site": OverworldMap.site_name(world.site(site_id)), "days": days}
		var key := "world.choice.travel_one" if days == 1 else "world.choice.travel"
		choices.append({"id": site_id, "label": Text.t(key, params)})
	choices.append({"id": REST, "label": Text.t("world.choice.rest")})
	choices.append({"id": SAVE, "label": Text.t("world.choice.save")})
	panel.present(Text.t("world.panel.title"), body, choices)


## The standing encounter's panel: what it is, and its choices. An ambush has only the
## fight; a patrol also offers the toll while the supplies cover it.
func _show_encounter() -> void:
	var kind := str(world.encounter.get("type", ""))
	var params := {
		"site": OverworldMap.site_name(world.site(str(world.encounter.get("to", "")))),
		"day": world.day,
		"toll": world.toll_cost()
	}
	var choices: Array[Dictionary] = [
		{"id": FIGHT, "label": Text.t("world.encounter.%s.fight" % kind, params)}
	]
	if world.toll_cost() > 0 and world.supplies >= world.toll_cost():
		choices.append({"id": TOLL, "label": Text.t("world.encounter.%s.toll" % kind, params)})
	panel.present(
		Text.t("world.encounter.%s.title" % kind),
		Text.t("world.encounter.%s.body" % kind, params),
		choices
	)


func _scenario() -> Dictionary:
	var all: Array = _json(SCENARIOS).get("scenarios", [])
	for entry: Variant in all:
		var scenario: Dictionary = entry if entry is Dictionary else {}
		if scenario.get("id") == SCENARIO_ID:
			return scenario
	return {}


func _saves() -> SAVE_SYSTEM:
	return get_node(SAVE_SYSTEM_PATH) as SAVE_SYSTEM


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
