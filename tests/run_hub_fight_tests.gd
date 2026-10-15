extends "res://tests/lib/runner.gd"
## Hub fight suite (Phase 2 milestone 6: HubDirector hooked to the road's fight). A real fight
## on the road (real clicks on the map's Fight and the battle's buttons) ends with the hub
## open on a prisoner and the loot exactly when the company won, and shut when it lost.
## Seeded by design: the balance seed (data/balance/world.json); nothing else rolls.
##   godot --headless --path . --script tests/run_hub_fight_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const BATTLE_DATA := "res://data/balance/battle.json"
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
const FIGHT_FRAMES := 6000
const PATROL_ROAD := "site_hamlet_2"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")


func suite_name() -> String:
	return "HubFight"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_clear_save()
	await _check_real_fight()
	_clear_save()


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


func _tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


## A real fight on the road: the hub opens on a prisoner exactly when the company won.
func _check_real_fight() -> void:
	var game := await _spawn()
	await _tap(KEY_M)
	var director := game.overworld_director()
	await _click_button(director.panel.button_for(PATROL_ROAD))
	await _click_button(director.panel.button_for(OverworldDirector.FIGHT))
	var won := await _finish_fight(director)
	await _frames(LAYOUT_FRAMES)
	var hub := game.hub_director()
	check(
		(
			game.hub_open() == won
			and hub.company.economy.prisoner.is_empty() != won
			and (not won or hub.panel.button_for("prisoner", Economy.RELEASE) != null)
		),
		(
			"a real fight on the road ended %s: the hub is %s"
			% ["won" if won else "lost", "open on a prisoner" if won else "left shut"]
		)
	)
	game.queue_free()
	await process_frame


func _finish_fight(director: OverworldDirector) -> bool:
	var battle := director.view.battle
	var rules: Dictionary = _json(BATTLE_DATA).get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	for _frame: int in FIGHT_FRAMES:
		if battle.is_over():
			break
		var actor := battle.current()
		if actor.side == BattleUnit.COMPANY:
			await _company_turn(director, BattleAi.choose(battle, actor, sight))
		else:
			await process_frame
	return battle.winner == BattleUnit.COMPANY


func _company_turn(director: OverworldDirector, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		director.view.click_cell(director.origin + to)
		await process_frame
		return
	var choice_id := Battle.ACTION_WAIT
	if kind == Battle.ACTION_ATTACK:
		choice_id = "%s:%s" % [Battle.ACTION_ATTACK, action.get("target")]
	await _click_button(director.panel.button_for(choice_id))


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _click_button(button: Button) -> void:
	await _frames(LAYOUT_FRAMES)
	if button == null or not is_instance_valid(button):
		return
	var at := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		await process_frame
