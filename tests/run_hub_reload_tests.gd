extends "res://tests/lib/runner.gd"
## Hub reload suite (Phase 5 C8, defect A): a board the player emptied (every contract taken and
## walked away from) must still be empty after the game is closed and reopened. Reopening used
## to post a fresh contract (HubDirector.begin), so a run played on and a run reloaded diverged.
## This suite starts two NEW godot processes of itself: one plays and saves, one reads the save.
##   godot --headless --path . --script tests/run_hub_reload_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SCRIPT := "res://tests/run_hub_reload_tests.gd"
const PHASE_ARG := "--phase="
const EMPTY_MARK := "RELOAD_BOARD_EMPTY"

var _game: SliceGame = null


func suite_name() -> String:
	return "HubReload"


func run_checks() -> void:
	await _t("_test_phases")


func _test_phases() -> void:
	var phase := _phase()
	if phase == "write":
		await _write_phase()
	elif phase == "read":
		await _read_phase()
	else:
		_driver()


func _phase() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PHASE_ARG):
			return arg.trim_prefix(PHASE_ARG)
	return ""


## Runs the two phases, each in its own process, one after the other.
func _driver() -> void:
	_clear_save()
	var wrote := _child("write")
	var wrote_out: String = wrote["out"]
	var wrote_code: int = wrote["code"]
	check(
		wrote_code == 0 and wrote_out.contains(EMPTY_MARK), "process 1 emptied the board and saved"
	)
	check(_saves_exist(), "process 1 left a save on disk")
	var read := _child("read")
	var read_code: int = read["code"]
	check(read_code == 0, "process 2 (a new process) read the save with the board still empty")
	_clear_save()


func _child(phase: String) -> Dictionary:
	var output: Array = []
	var args := PackedStringArray(
		[
			"--headless",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			SCRIPT,
			"--",
			PHASE_ARG + phase
		]
	)
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"code": code, "out": "".join(output)}


func _spawn() -> void:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	_game = packed.instantiate() as SliceGame
	root.add_child(_game)
	await process_frame


func _write_phase() -> void:
	await _spawn()
	var hub := _game.hub_director()
	var economy := hub.company.economy
	var ids: Array[String] = []
	for row: Dictionary in economy.board:
		ids.append(str(row["id"]))
	for id: String in ids:
		economy.accept(id)
		economy.abandon(id, hub.company, hub.world.day)
	check(economy.board.is_empty(), "every contract was taken and walked away from")
	var map := _game.overworld_director()
	var saved := _saves().save_game(map.world, map.rng, hub.company)
	check(saved, "the run saved")
	if economy.board.is_empty() and saved:
		print(EMPTY_MARK)


func _read_phase() -> void:
	await _spawn()
	var hub := _game.hub_director()
	check(
		hub.company.economy.board.is_empty(),
		"the reopened game's board is still empty (no contract posted on load)"
	)


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _saves_exist() -> bool:
	return FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH)


func _clear_save() -> void:
	if _saves_exist():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))
