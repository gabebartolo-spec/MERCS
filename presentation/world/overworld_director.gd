class_name OverworldDirector
extends Node
## The walkable overworld (Phase 2): one WorldSim from data/balance/world.json and the
## hand-made stamps (data/locations.json), drawn as a tile map that follows the band
## (OverworldMap), walked a tile at a time by the held walking keys (walk()). A small panel
## keeps Rest and Save. Opens on the save on disk when there is one (SaveSystem), so a closed
## game continues where it was; otherwise on a fresh region from the balance seed. One
## director lives for the session: walking into the hub's gate hides the map and the street
## takes over; M on the street (toggle()) shows it again with the band where it was. A
## party within a step of the band raises its encounter and the panel offers Fight (and,
## for a patrol, the toll): Fight hides the map and runs the existing street battle
## (BattleView) on the stage, then the result goes back through WorldSim.resolve_encounter()
## and the map returns with the outcome. The sim decides every step, cost and roll; this
## only words and draws them. Words: data/text/en.json.

## Raised on Continue after the fight that killed the last merc of the company: the campaign
## is over and the game shows its last screen (CampaignEnd).
signal wiped(company: Company, chronicle: Chronicle, memory: Memory)

const WORLD_DATA := "res://data/balance/world.json"
const LOCATIONS := "res://data/locations.json"
const MAP_DATA := "res://data/balance/overworld.json"
const REST := "rest"
const SAVE := "save"
const FIGHT := "fight"
const TOLL := "toll"
const CONTINUE := "continue"
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
## What the company has suffered (injuries, the chronicle); the game's one, set with it.
var wounds: CompanyWounds = null
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
## The triage after a road fight, shown until Continue; empty when none stands.
var _triage := ""
## What waits for Continue: the hub's loot and prisoner (the world's result hook), so the
## triage comes first.
var _after_triage := Callable()
## Whether the hub or the company screen stands over the map, and whether the panel was up
## when it came (so closing the screen puts the panel back as it was).
var _covered := false
var _panel_was_up := false
## Set when the triage left nobody alive: the saved campaign is over and Continue ends it.
var _ended := false


## A director for the slice's street, added under `game` and begun (the map shown).
static func make(game: SliceGame) -> OverworldDirector:
	var director := OverworldDirector.new()
	director.adopt(game.company_director())
	director.street_stage = game.stage()
	var battle_origin := StageData.load_file(SliceGame.SLICE_DATA).floats(
		"loop", "battle_origin_xz"
	)
	director.origin = Vector2i(int(battle_origin[0]), int(battle_origin[1]))
	game.add_child(director)
	director.begin()
	return director


## Takes the company and its wounds from the company screen's director: the game's one.
func adopt(screen: CompanyDirector) -> void:
	company = screen.company
	wounds = screen.wounds


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
	if company == null:
		company = CompanyDirector.load_company(self)
	if wounds == null:
		wounds = CompanyDirector.load_wounds(self, company)
	wounds.bind(rng)
	var shared := StoryDirector.memory_of(self)
	if shared != null:
		wounds.adopt_memory(shared)
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
	elif in_fight() or _triage != "" or _ended:
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
		_show_triage()


## A screen (the hub, the company) stands over the map: the map's own panel and header step
## out from under it, and come back as they were when it closes.
func set_covered(covered: bool) -> void:
	if _layer == null or covered == _covered:
		return
	_covered = covered
	if covered:
		_panel_was_up = panel.visible
		panel.visible = false
	else:
		panel.visible = _panel_was_up
	map.show_header(not covered)


## The walking keys' direction this frame (Vector2i.ZERO when none is held): a fresh press
## steps at once, a held key repeats (data/balance/overworld.json "walk"). Nothing while the
## map is hidden, a fight is on or an encounter stands.
func walk(direction: Vector2i, delta: float) -> void:
	var held := not world.encounter.is_empty() or _triage != "" or _ended
	if not is_open() or in_fight() or held or direction == Vector2i.ZERO:
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
		var line := _blocked_line(direction)
		if panel.shown_body() != line:
			_show(line)
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


## Why a step was refused, in words: the edge of the land, water, or a town's walls.
func _blocked_line(direction: Vector2i) -> String:
	var target := world.band + direction
	if not world.region.inside(target):
		return Text.t("world.panel.blocked_edge")
	if world.region.terrain(target) == TileRegion.Terrain.TOWN:
		return Text.t("world.panel.blocked_building")
	return Text.t("world.panel.blocked_water")


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
		CONTINUE:
			_triage = ""
			if _ended:
				panel.visible = false
				wiped.emit(company, wounds.chronicle(), wounds.memory())
				return
			_show(_outcome_line())
			if _after_triage.is_valid():
				_after_triage.call()
			_after_triage = Callable()
		TOLL:
			world.pay_toll()
			_show(_outcome_line())
		REST:
			world.rest()
			_show(_place_line())
		SAVE:
			save_run()


## Writes the run to the save on disk and says so. Refused, with nothing written, while a
## fight is on or its triage stands: a fight lives only on screen (a save then would hold the
## world after the blow-by-blow it cannot replay), so the save waits for Continue. The fight's
## own panel is not touched (its buttons are the player's turn); the triage panel keeps its
## Continue and gains the line that says why. True when written.
func save_run() -> bool:
	if in_fight():
		return false
	if _triage != "":
		var choices: Array[Dictionary] = [{"id": CONTINUE, "label": Text.t("wiring.continue")}]
		var body := Text.t("world.panel.save_busy") + "\n" + _triage
		panel.present(Text.t("wiring.panel.title"), body, choices)
		return false
	var saved := _saves().save_game(world, rng, company, wounds.state())
	_show(Text.t("world.panel.saved" if saved else "world.panel.save_failed"))
	return saved


## Hides the map over the street and starts the battle the standing encounter leads into.
func _start_fight() -> void:
	if world.encounter.is_empty() or street_stage == null:
		return
	var battle_data := _json(BATTLE_DATA)
	wounds.day = world.day
	var battle := RoadFight.build(wounds, world.pending_encounter(), _scenario(), battle_data, rng)
	map.visible = false
	view = BattleView.new()
	add_child(view)
	view.street_stage = street_stage
	view.panel = panel
	view.unit_names = RoadFight.names(wounds)
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
	var events := wounds.resolve()
	var kind := str(world.encounter.get("type", ""))
	var hook := world.result_hook
	world.result_hook = Callable()
	world.resolve_encounter(result)
	world.result_hook = hook
	_after_triage = hook.bind(kind, result) if hook.is_valid() else Callable()
	map.visible = true
	if wounds.ended():
		_end_campaign()
	_triage = RoadFight.triage_body(_outcome_line(), events, wounds)
	_show(_outcome_line())
	_show_triage()


## The company is dead to the last merc: the save is marked ended at once (so closing the game
## here cannot resume it), the hub's loot and prisoner fall away, and Continue leads to the
## last screen.
func _end_campaign() -> void:
	_ended = true
	_after_triage = Callable()
	_saves().save_game(world, rng, company, wounds.state())


## The triage panel after a road fight: what happened to whom, and Continue to the map.
func _show_triage() -> void:
	if _triage == "":
		return
	var choices: Array[Dictionary] = [{"id": CONTINUE, "label": Text.t("wiring.continue")}]
	panel.present(Text.t("wiring.panel.title"), _triage, choices)


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
	wounds.day = world.day
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
