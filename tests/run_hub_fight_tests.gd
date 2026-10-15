extends "res://tests/lib/runner.gd"
## Hub fight suite (Phase 2 milestone 6: HubDirector hooked to the road's fight). A real fight
## on the walkable map (a saved world on the balance seed with a patrol three tiles from the
## band; real key taps walk into it, real clicks on Fight and the battle's buttons) ends with
## the hub open on a prisoner and the loot exactly when the company won, and shut when it lost;
## the triage panel comes first and the hub opens on its Continue.
## Seeded by design: the balance seed (data/balance/world.json); nothing else rolls.
##   godot --headless --path . --script tests/run_hub_fight_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const World := preload("res://tests/lib/world_fixture.gd")
const InputKit := preload("res://tests/lib/input_kit.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const OUT := 3
const NEAR := 3
const TAP_LIMIT := 8
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")


func suite_name() -> String:
	return "HubFight"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_clear_save()
	await _check_real_fight()
	_clear_save()


## A saved world with the band three tiles out of the hub's gate and a lone patrol near it.
func _save_patrol_world() -> void:
	var data := World.data()
	var world_block: Dictionary = data.get("world", {})
	var balance_seed: int = world_block.get("seed", 0)
	var rng := Rng.from_seed(balance_seed)
	var world := WorldSim.new()
	world.start(data, rng)
	world.parties.clear()
	World.out_of_town(world, OUT)
	World.lone_party(world, "patrol", NEAR)
	(root.get_node(^"SaveSystem") as SAVE_SYSTEM).save_game(world, rng)


## Taps A or D, W or S toward the lone party until its encounter stands.
func _walk_into(director: OverworldDirector) -> void:
	var world := director.world
	var keys := {
		Vector2i(0, -1): KEY_W, Vector2i(0, 1): KEY_S, Vector2i(-1, 0): KEY_A, Vector2i(1, 0): KEY_D
	}
	for _tap: int in TAP_LIMIT:
		if not world.encounter.is_empty() or world.parties.is_empty():
			return
		var to := world.parties[0].tile - world.band
		var step := Vector2i(signi(to.x), 0) if to.x != 0 else Vector2i(0, signi(to.y))
		var code: Key = keys.get(step, KEY_NONE)
		await InputKit.tap(self, code)


## A real fight on the map: the hub opens on a prisoner exactly when the company won.
func _check_real_fight() -> void:
	_save_patrol_world()
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	await InputKit.tap(self, KEY_M)
	var director := game.overworld_director()
	await _walk_into(director)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.FIGHT))
	if not director.in_fight():
		check(false, "walking into the patrol and clicking Fight starts the street battle")
		game.queue_free()
		return
	var won := await InputKit.finish_fight(self, director)
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	# The triage panel comes first; the loot and the prisoner wait for Continue.
	var triage_first := not game.hub_open()
	await InputKit.click(self, director.panel.button_for(OverworldDirector.CONTINUE))
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	var hub := game.hub_director()
	check(
		(
			triage_first
			and game.hub_open() == won
			and hub.company.economy.prisoner.is_empty() != won
			and (not won or hub.panel.button_for("prisoner", Economy.RELEASE) != null)
		),
		(
			"a real fight on the map ended %s: the hub is %s"
			% ["won" if won else "lost", "open on a prisoner" if won else "left shut"]
		)
	)
	game.queue_free()
	await process_frame


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))
