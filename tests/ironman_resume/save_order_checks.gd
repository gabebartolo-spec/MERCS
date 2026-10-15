extends RefCounted
## The ironman_resume suite's save-order checks, run by tests/run_ironman_resume_tests.gd (D-087:
## with Ironman On a quit resumes the exact state). The rule they guard (CampaignSaves): an
## autosave is written only after every state change its decision makes, so quitting at the
## autosave and reopening reaches the same run as playing on. Each check makes a decision twice:
## once played on until the run settles (the uninterrupted run), once quit at the autosave and
## reopened in a NEW Godot process (reload_probe.gd); the two runs must match whole (world, Rng,
## company and economy, wounds and memories, storylets fired).
##   a prisoner's fate decided at the hub: the memory it leaves on the merc who reacts;
##   a won road fight quit at its triage: the loot, the prisoners and the jobs judged.
## Seeded by design: world seed 424270, the suite's own ambush three steps out.

const InputKit := preload("res://tests/lib/input_kit.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const End := preload("res://tests/lib/end_kit.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const Probe := preload("res://tests/ironman_resume/reload_probe.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const PROBE_SCRIPT := "res://tests/ironman_resume/reload_probe.gd"
const SEED := 424270
const NEAR := 3
const TAP_LIMIT := 8
const SETTLE := 6
const FIXED_FPS := "60"

var _tree: SceneTree = null
var _check: Callable


func setup(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check


func run() -> void:
	await prisoner_memory()
	await fight_loot()


## A prisoner's fate, decided at the hub: quit at its autosave, the reopened run holds the
## memory the fate left, as the run played on does.
func prisoner_memory() -> void:
	var runs: Array[String] = []
	var gained: Array[int] = []
	for quit_at_autosave: bool in [false, true]:
		_clear_save()
		_save_home()
		var game := await _spawn()
		var hub := game.hub_director()
		hub.world.result_hook.call("ambush", {"won": true, "prisoners": ["bandit_0"]})
		hub.show_result()
		await InputKit.frames(_tree, InputKit.LAYOUT_FRAMES)
		var story := game.get_node("StoryDirector") as StoryDirector
		var before := _memory_count(story.memory)
		await InputKit.click(_tree, hub.panel.button_for("prisoner", Economy.RANSOM))
		if quit_at_autosave:
			await _quit(game)
			var reopened := _reopen_elsewhere()
			runs.append(str(reopened.get("state", "")))
			gained.append(Merc.whole(reopened.get("memories", -1)) - before)
		else:
			await InputKit.frames(_tree, SETTLE)
			runs.append(Probe.snapshot(game))
			gained.append(_memory_count(story.memory) - before)
			await _quit(game)
	print("SAVE ORDER prisoner: memories gained %s; runs %s" % [gained, _hashes(runs)])
	_check.call(
		gained[0] > 0 and gained[1] == gained[0],
		"Ironman On, quit at a prisoner's autosave: the fate's memory is in the save (new process)"
	)
	_check.call(
		not runs[0].is_empty() and runs[1] == runs[0],
		"Ironman On, quit at a prisoner's autosave: the reopened run matches the run played on"
	)


## A won road fight, quit while its triage stands: the reopened run holds the loot, the
## prisoners and the judged jobs, as the run that pressed Continue does.
func fight_loot() -> void:
	var runs: Array[String] = []
	var won: Array[bool] = []
	var purses: Array[int] = []
	var shown := false
	for quit_at_autosave: bool in [false, true]:
		var game := await _fight_start()
		var director := game.overworld_director()
		won.append(await InputKit.finish_fight(_tree, director))
		await InputKit.frames(_tree, SETTLE)
		if quit_at_autosave:
			await _quit(game)
			var reopened := _reopen_elsewhere()
			runs.append(str(reopened.get("state", "")))
			purses.append(Merc.whole(reopened.get("purse", -1)))
		else:
			var waited := not game.hub_open()
			await InputKit.click(_tree, director.panel.button_for(OverworldDirector.CONTINUE))
			await InputKit.frames(_tree, SETTLE)
			shown = waited and game.hub_open()
			runs.append(Probe.snapshot(game))
			purses.append(director.company.economy.purse)
			await _quit(game)
	print("SAVE ORDER fight: won %s; purses %s; runs %s" % [won, purses, _hashes(runs)])
	_check.call(
		won == [true, true] and purses[1] == purses[0],
		"Ironman On, quit at a won fight's triage: the loot is in the save (new process)"
	)
	_check.call(
		not runs[0].is_empty() and runs[1] == runs[0],
		"Ironman On, quit at a won fight's triage: the reopened run matches the run that went on"
	)
	_check.call(shown, "the hub opens on the won fight's result at Continue, not over the triage")


## The save on disk opened by a new Godot process (reload_probe.gd): {"state": its snapshot,
## "memories": how many memories it holds, "purse": the company's purse}; {} when it failed.
func _reopen_elsewhere() -> Dictionary:
	var args: PackedStringArray = [
		"--headless",
		"--fixed-fps",
		FIXED_FPS,
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		PROBE_SCRIPT,
	]
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), args, output)
	for chunk: Variant in output:
		for line: String in str(chunk).split("\n"):
			if line.begins_with(Probe.LINE):
				var text := line.trim_prefix(Probe.LINE).strip_edges()
				var parsed: Variant = JSON.parse_string(text)
				var whole: Dictionary = parsed if parsed is Dictionary else {}
				return {
					"state": text,
					"memories": _saved_memories(whole),
					"purse": _saved_purse(whole),
				}
	print("SAVE ORDER probe exited %d without a state line" % code)
	return {}


func _saved_memories(whole: Dictionary) -> int:
	var restored := Memory.restore(_dict(_dict(whole.get("wounds", {})).get("memories", {})))
	return _memory_count(restored)


func _saved_purse(whole: Dictionary) -> int:
	var economy := _dict(_dict(whole.get("company", {})).get("economy", {}))
	return Merc.whole(economy.get("purse", -1))


func _memory_count(memory: Memory) -> int:
	var count := 0
	var held := memory.state()
	for merc: Variant in held:
		var lines: Variant = held[merc]
		if lines is Array:
			var listed: Array = lines
			count += listed.size()
	return count


func _hashes(runs: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for run: String in runs:
		out.append(run.md5_text() if not run.is_empty() else "(none)")
	return out


## A fresh session on the saved world (Ironman On, the lone ambush), the fight begun.
func _fight_start() -> SliceGame:
	_clear_save()
	_save_world()
	var game := await _spawn()
	await InputKit.tap(_tree, KEY_M)
	var director := game.overworld_director()
	await _walk_into(director)
	await InputKit.click(_tree, director.panel.button_for(OverworldDirector.FIGHT))
	return game


func _save_world() -> void:
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	World.out_of_town(world, NEAR)
	World.lone_party(world, "ambush", NEAR)
	var made := Kit.wounds(rng, "", {}, Kit.led_by(End.LAST))
	_saves().ironman = true
	_saves().save_game(world, rng, made.company, made.state())


func _save_home() -> void:
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	var made := Kit.wounds(rng, "", {}, Kit.led_by(End.LAST))
	_saves().ironman = true
	_saves().save_game(world, rng, made.company, made.state())


func _walk_into(director: OverworldDirector) -> void:
	var world := director.world
	var keys := {
		Vector2i(0, -1): KEY_W, Vector2i(0, 1): KEY_S, Vector2i(-1, 0): KEY_A, Vector2i(1, 0): KEY_D
	}
	for _tap_count: int in TAP_LIMIT:
		if not world.encounter.is_empty() or world.parties.is_empty():
			return
		var to := world.parties[0].tile - world.band
		var step := Vector2i(signi(to.x), 0) if to.x != 0 else Vector2i(0, signi(to.y))
		var code: Key = keys.get(step, KEY_NONE)
		await InputKit.tap(_tree, code)


## The game closed as a player closes it: nothing more is written.
func _quit(game: SliceGame) -> void:
	game.queue_free()
	await _tree.process_frame


func _saves() -> SAVE_SYSTEM:
	return _tree.root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	_tree.root.add_child(game)
	await _tree.process_frame
	return game


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
