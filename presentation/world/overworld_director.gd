class_name OverworldDirector
extends Node
## The overworld on screen (Phase 2 M1b): one WorldSim from data/balance/world.json, drawn
## as a flat map over the street (OverworldMap), and the company's day chosen through a
## LoopPanel list: a road to each neighbouring site, a day's rest, or a save. Opens on the
## save on disk when there is one (SaveSystem), so a closed game continues where it was;
## otherwise on a fresh region from the balance seed. One director lives for the session:
## hiding the map (set_open) keeps the run; only "Save" writes it to disk. The sim decides
## every day and every cost; this only words and draws them. Words: data/text/en.json.

const WORLD_DATA := "res://data/balance/world.json"
const REST := "rest"
const SAVE := "save"
## The SaveSystem autoload by its script: a headless --script run (the test suites) knows
## no autoload by name, but every run has it in the tree.
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SAVE_SYSTEM_PATH := ^"/root/SaveSystem"

var world: WorldSim = null
var rng: Rng = null
var panel: LoopPanel = null
var map: OverworldMap = null

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


## Shows the map (redrawn with the day's choices) or hides it, keeping the run.
func set_open(open: bool) -> void:
	if _layer == null:
		return
	_layer.visible = open
	if open:
		_show(Text.t("world.panel.body"))


func _on_choice(choice_id: String) -> void:
	match choice_id:
		REST:
			world.rest()
			_show(Text.t("world.panel.body"))
		SAVE:
			var saved := _saves().save_game(world, rng)
			_show(Text.t("world.panel.saved" if saved else "world.panel.save_failed"))
		_:
			world.travel_to(choice_id)
			_show(Text.t("world.panel.body"))


## Redraws the map and lists the day's choices: each road out, a rest, a save.
func _show(body: String) -> void:
	map.show_world(world)
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


func _saves() -> SAVE_SYSTEM:
	return get_node(SAVE_SYSTEM_PATH) as SAVE_SYSTEM


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
