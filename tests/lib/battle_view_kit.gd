extends RefCounted
## Shared by the battle view suite and the blood capture tool: the slice's fight on the street
## stage, as slice_game.gd builds it (street stage at whole logical pixels, the loop example's
## fight, the grey-box panel, a BattleView), with the hand-made merc sheet standing in for every
## fighter. The caller owns the returned nodes.

const STAGE_SCENE := preload("res://presentation/world/street_stage.tscn")
const SCENARIOS := "res://data/scenarios.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const SLICE_DATA := "res://data/balance/slice.json"
const SCENARIO_ID := "scn_slice_loop"
const SHEET := "res://assets/sprites/mercs/average_m/average_m_body_rest.json"
const FACING := "S"
const LOGICAL_HEIGHT := 540


## A mounted fight's parts.
class Mounted:
	extends RefCounted
	var loop: SliceLoop = null
	var stage: StreetStage = null
	var panel: LoopPanel = null
	var view: BattleView = null
	var layer: CanvasLayer = null
	var origin := Vector2i.ZERO


static func json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## A block's sub-dictionary, {} when absent.
static func section(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}


## The loop example's fight, begun and not yet played.
static func fight(seed_value: int) -> SliceLoop:
	var scenario := {}
	var list: Variant = json(SCENARIOS).get("scenarios", [])
	if list is Array:
		var scenarios: Array = list
		for entry: Variant in scenarios:
			var row := section({"row": entry}, "row")
			if row.get("id") == SCENARIO_ID:
				scenario = row
	var loop := SliceLoop.new()
	loop.start(scenario, json(BATTLE_DATA), Rng.from_seed(seed_value))
	loop.advance()
	loop.hire(true)
	loop.accept_contract()
	loop.advance()
	loop.fight()
	return loop


## How far the AI sees (battle.json "rules" "sight_cells").
static func sight() -> int:
	return Merc.whole(section(json(BATTLE_DATA), "rules").get("sight_cells", 0))


## The fight on the street: {loop, stage, panel, view, layer, origin}.
static func mount(tree: SceneTree, seed_value: int) -> Mounted:
	var loop := fight(seed_value)
	var stage := STAGE_SCENE.instantiate() as StreetStage
	stage.auto_walk = false
	stage.integer_scale = maxi(1, roundi(float(tree.root.size.y) / LOGICAL_HEIGHT))
	tree.root.add_child(stage)
	stage.use_sheet(SHEET, FACING)
	stage.merc().visible = false
	var layer := CanvasLayer.new()
	tree.root.add_child(layer)
	var panel := LoopPanel.new()
	layer.add_child(panel)
	var origin_xz := StageData.load_file(SLICE_DATA).floats("loop", "battle_origin_xz")
	var origin := Vector2i(int(origin_xz[0]), int(origin_xz[1]))
	var view := BattleView.new()
	tree.root.add_child(view)
	view.street_stage = stage
	view.panel = panel
	view.begin(loop.battle, origin, sight())
	stage.focus_on(view.centre())
	var mounted := Mounted.new()
	mounted.loop = loop
	mounted.stage = stage
	mounted.panel = panel
	mounted.view = view
	mounted.layer = layer
	mounted.origin = origin
	return mounted


## Takes a mounted fight off the tree (the caller has already cleared the view).
static func unmount(mounted: Mounted) -> void:
	mounted.view.queue_free()
	mounted.layer.queue_free()
	mounted.stage.queue_free()
