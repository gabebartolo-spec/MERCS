extends SceneTree
## Captures the Phase 2 gate frames at the window's real size (docs/audits/phase2_gate/):
## the street, the map with a party in its sight ring, a road fight, the triage panel, the
## hub panel and the C company screen with a memory shown. Plays the game with real key
## events and mouse clicks (the world is the wiring suite's seed 424270 ambush, played by
## BattleAi). Needs a window, not --headless. Each text-heavy panel also saves a crop of its
## rectangle at 2x with nearest filtering. Not a test: it asserts nothing, it takes pictures.
##
##   APPDATA=<scratch> godot --path . --windowed --resolution 3840x2160 --position 8000,8000 \
##     --script tools/capture/capture_gate.gd -- --out=docs/audits/phase2_gate

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const BASE_WIDTH := 1920.0
const GUI_SEED := 424270
const NEAR := 3
const SIGHT_GAP := 4
const SETTLE := 12
const FIGHT_FRAMES := 6000
const TURNS_BEFORE_SHOT := 5
const CROP_SCALE := 2

var _out := "docs/audits/phase2_gate"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	_clear_save()
	var game := await _spawn()
	await _frames(SETTLE)
	_shot("01_street")
	_clear_save()
	game.queue_free()
	await process_frame
	_save_world(SIGHT_GAP, true)
	game = await _spawn()
	await _tap(KEY_M)
	await _tap(KEY_S)
	await _frames(SETTLE)
	_shot("02_map_party_in_sight")
	var director := game.overworld_director()
	_clear_save()
	director.world.parties[0].chasing = true
	_save_world(NEAR, false)
	game.queue_free()
	await process_frame
	game = await _spawn()
	await _tap(KEY_M)
	director = game.overworld_director()
	await _walk_into(director)
	await _frames(SETTLE)
	_shot("03_ambush_panel", director.panel)
	await _click(director.panel.button_for(OverworldDirector.FIGHT))
	await _frames(SETTLE)
	await _finish_fight(director, TURNS_BEFORE_SHOT)
	_shot("04_road_fight")
	await _finish_fight(director, 0)
	await _frames(SETTLE)
	_shot("05_triage", director.panel)
	await _click(director.panel.button_for(OverworldDirector.CONTINUE))
	await _frames(SETTLE)
	if not game.hub_open():
		await _tap(KEY_B)
	await _frames(SETTLE)
	_shot("06_hub", game.hub_director().panel)
	await _tap(KEY_ESCAPE)
	director.set_open(false)
	await _tap(KEY_C)
	await _frames(SETTLE)
	var company := game.company_director()
	await _click(company.panel.row_for("orc"))
	await _frames(SETTLE)
	_shot("07_company_memories", company.panel)
	await _tap(KEY_C)
	await _tap(KEY_B)
	await _frames(SETTLE)
	_shot("08_hub_street", game.hub_director().panel)
	_clear_save()
	quit()


func _scale() -> float:
	return float(root.size.x) / BASE_WIDTH


## Saves the full frame; with a panel, also its rectangle cropped at 2x, nearest.
func _shot(shot_name: String, panel: Control = null) -> void:
	var image := root.get_texture().get_image()
	image.save_png("%s/%s_4k.png" % [_out, shot_name])
	if panel == null:
		return
	var rect := panel.get_global_rect()
	var area := (
		Rect2i(Vector2i(rect.position * _scale()), Vector2i(rect.size * _scale()))
		. intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	)
	var crop := image.get_region(area)
	crop.resize(
		crop.get_width() * CROP_SCALE, crop.get_height() * CROP_SCALE, Image.INTERPOLATE_NEAREST
	)
	crop.save_png("%s/%s_crop2x.png" % [_out, shot_name])


func _save_world(gap: int, chasing: bool) -> void:
	var rng := Rng.from_seed(GUI_SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	World.out_of_town(world, NEAR)
	var party := World.lone_party(world, "ambush", gap)
	party.chasing = chasing
	_saves().save_game(world, rng)


func _walk_into(director: OverworldDirector) -> void:
	var world := director.world
	var keys := {
		Vector2i(0, -1): KEY_W, Vector2i(0, 1): KEY_S, Vector2i(-1, 0): KEY_A, Vector2i(1, 0): KEY_D
	}
	for _count: int in 8:
		if not world.encounter.is_empty() or world.parties.is_empty():
			return
		var to := world.parties[0].tile - world.band
		var step := Vector2i(signi(to.x), 0) if to.x != 0 else Vector2i(0, signi(to.y))
		var code: Key = keys.get(step, KEY_NONE)
		await _tap(code)


## Plays the company's turns by clicks until the battle is over, or `turns` company turns.
func _finish_fight(director: OverworldDirector, turns: int) -> void:
	var battle := director.view.battle
	var rules: Dictionary = Kit.json(Fixture.BATTLE).get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	var played := 0
	for _frame: int in FIGHT_FRAMES:
		if battle.is_over() or (turns > 0 and played >= turns):
			break
		var actor := battle.current()
		if actor.side != BattleUnit.COMPANY:
			await process_frame
			continue
		var action := BattleAi.choose(battle, actor, sight)
		var kind := str(action.get("type", ""))
		if kind == Battle.ACTION_MOVE:
			var to: Vector2i = action.get("to", Vector2i.ZERO)
			director.view.click_cell(director.origin + to)
			await process_frame
		else:
			var choice_id := Battle.ACTION_WAIT
			if kind == Battle.ACTION_ATTACK:
				choice_id = "%s:%s" % [Battle.ACTION_ATTACK, action.get("target")]
			await _click(director.panel.button_for(choice_id))
		played += 1


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _spawn() -> SliceGame:
	var game: SliceGame = (load(SLICE_SCENE) as PackedScene).instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _click(button: Button) -> void:
	await _frames(3)
	if button == null or not is_instance_valid(button):
		print("capture_gate: no button to click")
		return
	var at := button.get_global_rect().get_center() * _scale()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		await process_frame


func _tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
