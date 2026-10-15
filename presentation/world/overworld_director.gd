class_name OverworldDirector
extends Node
## The walkable overworld (Phase 2): one WorldSim from data/balance/world.json and the
## hand-made stamps (data/locations.json), drawn as a tile map that follows the band
## (OverworldMap), walked a tile at a time by the held walking keys (walk()). A small panel
## keeps Rest and Save. Opens on the save on disk when there is one (SaveSystem), so a closed
## game continues where it was; otherwise on a fresh region from the balance seed. One
## director lives for the session: walking into the hub's gate hides the map and the street
## takes over; F2 on the street (toggle()) shows it again with the band where it was. A
## party within a step of the band raises its encounter and the panel offers Fight (and,
## for a patrol, the toll): Fight hides the map and runs the existing street battle
## (BattleView) on the stage, then the result goes back through WorldSim.resolve_encounter()
## and the map returns with the outcome. The sim decides every step, cost and roll; this
## only words and draws them. Words: data/text/en.json.

const WORLD_DATA := "res://data/balance/world.json"
const LOCATIONS := "res://data/locations.json"
const MAP_DATA := "res://data/balance/overworld.json"
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
## Set before begin(): the street the fight is drawn on and the street cell under battle
## cell (0, 0).
var street_stage: StreetStage = null
var origin := Vector2i.ZERO
## The street battle while one is on screen, else null.
var view: BattleView = null

var _layer: CanvasLayer = null
var _walk: StageData = null
var _walking := false
var _wait_s := 0.0


## A director for the slice's street, added under `game` and begun (the map shown).
static func make(game: SliceGame) -> OverworldDirector:
	var director := OverworldDirector.new()
	director.company = game.company_director().company
	director.street_stage = game.stage()
	var battle_origin := StageData.load_file(SliceGame.SLICE_DATA).floats("loop", "battle_origin_xz")
	director.origin = Vector2i(int(battle_origin[0]), int(battle_origin[1]))
	game.add_child(director)
	director.begin()
	return director


## data/balance/world.json with the hand-made stamps: what WorldSim and SaveModel read.
static func world_data() -> Dictionary:
	var data := _json(WORLD_DATA)
	var stamps: Array = _json(LOCATIONS).get("locations", [])
	data["locations"] = stamps
	return data


## Continues the save on disk, or starts a fresh region, and shows the map and the panel.
func begin() -> void:
	var data := world_data()
	if _saves().has_save():
		var model := _saves().load_game(data)
		if model.ok:
			world = model.world
			rng = model.rng
	if world == null:
		rng = Rng.from_seed(int(StageData.load_file(WORLD_DATA).num("world", "seed")))
		world = WorldSim.new()
		world.start(data, rng)
	var lineups: Array = _json(ENCOUNTER_DATA).get("encounters", [])
	world.set_lineups(lineups)
	_walk = StageData.load_file(MAP_DATA)
	_layer = CanvasLayer.new()
	add_child(_layer)
	map = OverworldMap.new()
	_layer.add_child(map)
	panel = LoopPanel.new()
	_layer.add_child(panel)
	panel.chosen.connect(_on_choice)
	_show(_place_line())


## Whether the map is on screen; the run lives on while it is hidden.
func is_open() -> bool:
	return _layer != null and _layer.visible


## Whether a street battle from an encounter is on screen.
func in_fight() -> bool:
	return view != null


## Shows the map (the street was left), or, when it is up, goes back to the street if the
## band stands on the hub's gate with nothing standing in its way; elsewhere the panel says
## where the street is reached. A fight keeps the screen.
func toggle() -> void:
	if not is_open():
		set_open(true)
	elif in_fight():
		return
	elif world.at == RegionGen.HUB_ID and world.encounter.is_empty():
		set_open(false)
	elif world.encounter.is_empty():
		_show(Text.t("world.panel.not_at_gate"))


## Shows the map (redrawn) or hides it, keeping the run. The map cannot close under a fight.
func set_open(open: bool) -> void:
	if _layer == null or (in_fight() and not open):
		return
	_layer.visible = open
	_walking = false
	if open:
		_show(_place_line())


## The walking keys' direction this frame (Vector2i.ZERO when none is held): a fresh press
## steps at once, a held key repeats (data/balance/overworld.json "walk"). Nothing while the
## map is hidden, a fight is on or an encounter stands.
func walk(direction: Vector2i, delta: float) -> void:
	if not is_open() or in_fight() or not world.encounter.is_empty() or direction == Vector2i.ZERO:
		_walking = false
		return
	if not _walking:
		_walking = true
		_wait_s = _walk.num("walk", "first_repeat_s")
		_step(direction)
		return
	_wait_s -= delta
	if _wait_s <= 0.0:
		_wait_s += _walk.num("walk", "repeat_s")
		_step(direction)


## One step in the sim, then what it led to: an encounter's panel, the street at the hub's
## gate, a site's line, or the map redrawn.
func _step(direction: Vector2i) -> void:
	if not world.step(direction):
		return
	if not world.encounter.is_empty():
		_walking = false
		_show("")
	elif world.at == RegionGen.HUB_ID:
		set_open(false)
	elif panel.shown_body() != _place_line():
		_show(_place_line())
	else:
		map.show_world(world)


## What the panel says where the band stands: a site's line at a site, else how to walk.
func _place_line() -> String:
	var here := world.site(world.at)
	if here == null or here.kind == WorldSite.Kind.HUB:
		return Text.t("world.panel.body")
	return Text.t("world.panel.at_site", {"site": OverworldMap.site_name(here)})


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
			_show(_place_line())
		SAVE:
			var saved := _saves().save_game(world, rng, company)
			_show(Text.t("world.panel.saved" if saved else "world.panel.save_failed"))


## Hides the map over the street and starts the battle the standing encounter leads into.
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
		var here := world.site(world.haven)
		var params := {
			"supplies": absi(change), "site": OverworldMap.site_name(here) if here != null else ""
		}
		return Text.t("world.encounter.outcome.%s" % outcome, params)
	return _place_line()


## Redraws the map and shows the panel: the standing encounter's, or the body with Rest and
## Save.
func _show(body: String) -> void:
	map.show_world(world)
	if not world.encounter.is_empty():
		_show_encounter()
		return
	var choices: Array[Dictionary] = [
		{"id": REST, "label": Text.t("world.choice.rest")},
		{"id": SAVE, "label": Text.t("world.choice.save")},
	]
	panel.present(Text.t("world.panel.title"), body, choices)


## The standing encounter's panel: what it is, and its choices. An ambush has only the
## fight; a patrol also offers the toll while the supplies cover it.
func _show_encounter() -> void:
	var kind := str(world.encounter.get("type", ""))
	var params := {"day": world.day, "toll": world.toll_cost()}
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
