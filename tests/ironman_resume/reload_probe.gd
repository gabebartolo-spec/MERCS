extends SceneTree
## A fresh Godot process on the save on disk, as a closed game reopens (Ironman save order,
## tests/ironman_resume/save_order_checks.gd): the slice game spawned, the map opened, a few
## frames let pass, and the run printed on one line (`LINE` then snapshot()'s JSON). Not a suite.
##   godot --headless --path . --script tests/ironman_resume/reload_probe.gd

const InputKit := preload("res://tests/lib/input_kit.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const LINE := "SAVE_ORDER_STATE "
const SETTLE := 6


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	await InputKit.tap(self, KEY_M)
	await InputKit.frames(self, SETTLE)
	print(LINE + snapshot(game))
	quit(0)


## The run as the save would hold it: world, Rng, company (with its economy), wounds (with the
## memories), and the storylets fired. Empty before the map and the story director exist.
static func snapshot(game: SliceGame) -> String:
	var map := game.overworld_director()
	var story := game.get_node_or_null("StoryDirector") as StoryDirector
	if map == null or story == null:
		return ""
	var whole := {
		"world": map.world.state(),
		"rng": map.rng.state(),
		"company": map.company.state(),
		"wounds": map.wounds.state(),
		"story": story.state.state(),
	}
	return JSON.stringify(whole, "", true)
