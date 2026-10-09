extends "res://tests/lib/runner.gd"
## Slice suite: the art direction slice, milestone M1 (docs/specs/art_direction_slice.md
## §3, §4). Real input events reach the game through Input.parse_input_event, never a
## handler call: held keys walk the merc cell by cell, a left click on the ground walks it
## there, houses and the well block it, the camera follows in whole logical pixels, the
## street door leads into the interior and back, T steps the time of day and lights the
## torch, R toggles the rain, F1 hides the help, and the crowd walks the same way twice.
## Seeded by design: no randomness; the runner's --fixed-fps 60 makes every delta 1/60 s.
##   godot --headless --path . --script tests/run_slice_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SLICE_DATA := "res://data/balance/slice.json"
const SETTLE_FRAMES := 240
const HOLD_FRAMES := 30
const CROWD_FRAMES := 120
## Holding D for HOLD_FRAMES (0.5 s at 2.2 m/s) commits to a second cell before release.
const HELD_CELLS := 2
const CLICK_TARGET := Vector2i(-3, 0)
const WELL_CELL := Vector2i(4, 1)
const TEXEL_TOLERANCE := 1e-4
const CLIP_DIR := "user://slice_clip"
const LAYOUT_FRAMES := 3
const WINDOW_SIZE := Vector2i(1920, 1080)
const CLIP_CELL := 8
const CLIP_FRAMES := 3
const CLIP_FPS := 4.0


func suite_name() -> String:
	return "Slice"


func run_checks() -> void:
	var game := await _spawn()
	_check_boot(game)
	await _check_keys(game)
	await _check_click(game)
	_check_blocking(game)
	_check_camera(game)
	await _check_doors(game)
	await _check_conditions(game)
	await _check_crowd_repeats(game)
	_check_clip_playback()
	await _check_loop_panels()


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


func _check_boot(game: SliceGame) -> void:
	var start := _start_cell()
	var routes := 0
	while not _crowd_route(routes + 1).is_empty():
		routes += 1
	check(
		game.player.cell == start and game.crowd.size() == routes and routes > 0,
		(
			"the slice boots with the merc on %s and %d crowd mercs (got %s, %d)"
			% [start, routes, game.player.cell, game.crowd.size()]
		)
	)


func _check_keys(game: SliceGame) -> void:
	var start := game.player.cell
	await _press_key(KEY_D, true)
	for _frame: int in HOLD_FRAMES:
		await process_frame
	await _press_key(KEY_D, false)
	await _settle(game)
	var expected := start + Vector2i(HELD_CELLS, 0)
	check(
		game.player.cell == expected and game.player.facing == "E",
		(
			"holding D walks the merc east to %s facing E (got %s, %s)"
			% [expected, game.player.cell, game.player.facing]
		)
	)


func _check_click(game: SliceGame) -> void:
	var stage := game.stage()
	var centre := Vector3(CLICK_TARGET.x + 0.5, 0.0, CLICK_TARGET.y + 0.5)
	var window := stage.camera().unproject_position(centre) * stage.screen_scale()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = window
	click.global_position = window
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await _settle(game)
	check(
		game.player.cell == CLICK_TARGET,
		(
			"a left click on the ground walks the merc to %s (got %s)"
			% [CLICK_TARGET, game.player.cell]
		)
	)


func _check_blocking(game: SliceGame) -> void:
	var walker := game.player
	check(
		not walker.is_walkable(WELL_CELL) and not walker.walk_to(WELL_CELL),
		"the well's cell is blocked and cannot be walked to"
	)
	var data := game.stage().stage_data
	var house := data.floats("street", "house_cells_xz")
	var house_cell := Vector2i(int(house[0]), int(house[1]))
	check(not walker.is_walkable(house_cell), "a house's cell is blocked")


func _check_camera(game: SliceGame) -> void:
	var stage := game.stage()
	var rail := stage.camera().get_parent() as Node3D
	var texel := stage.texel_m()
	var z_step := texel / sin(deg_to_rad(stage.pitch_degrees))
	var at := game.player.position_m()
	var on_grid := (
		absf(rail.position.x / texel - roundf(rail.position.x / texel)) < TEXEL_TOLERANCE
		and absf(rail.position.z / z_step - roundf(rail.position.z / z_step)) < TEXEL_TOLERANCE
	)
	var follows := absf(rail.position.x - at.x) <= texel and absf(rail.position.z - at.y) <= z_step
	check(
		on_grid and follows,
		(
			"the camera follows the merc and moves in whole logical pixels (rail %s, merc %s)"
			% [rail.position, at]
		)
	)


func _check_doors(game: SliceGame) -> void:
	var data := game.stage().stage_data
	var door := data.cell("street", "door_cell")
	var entry := data.cell("interior", "entry_cell")
	var exit := data.cell("interior", "exit_cell")
	game.player.walk_to(Vector2i(door.x, door.z))
	await _settle(game)
	var inside := game.player.cell == Vector2i(entry.x, entry.z)
	game.player.walk_to(Vector2i(exit.x, exit.z))
	await _settle(game)
	var back := game.player.cell == Vector2i(door.x, door.z + 1)
	check(
		inside and back,
		"the street door leads into the interior and its exit back out in front of the door"
	)


func _check_conditions(game: SliceGame) -> void:
	var stage := game.stage()
	var world := stage.world()
	await _tap(KEY_T)
	var dusk := stage.time_of_day == StageLighting.TimeOfDay.DUSK
	var torch := world.get_node_or_null(NodePath(StageWeather.TORCH_NAME)) != null
	await _tap(KEY_T)
	var night := stage.time_of_day == StageLighting.TimeOfDay.NIGHT
	await _tap(KEY_T)
	var day := stage.time_of_day == StageLighting.TimeOfDay.DAY
	var no_torch := world.get_node_or_null(NodePath(StageWeather.TORCH_NAME)) == null
	check(
		dusk and torch and night and day and no_torch,
		"T steps day, dusk, night and back; torches burn at dusk"
	)
	await _tap(KEY_R)
	var raining := world.get_node_or_null(NodePath(StageWeather.RAIN_NAME)) != null
	await _tap(KEY_R)
	var dry := world.get_node_or_null(NodePath(StageWeather.RAIN_NAME)) == null
	check(raining and dry and stage.rain == false, "R starts and stops the rain")
	var help := _first_label(game)
	var shown := help != null and help.visible
	await _tap(KEY_F1)
	check(
		shown and help != null and not help.visible, "the key help shows at start and F1 hides it"
	)


func _check_crowd_repeats(first: SliceGame) -> void:
	first.queue_free()
	# Both enter the tree in the same frame, so they see the same deltas.
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var a: SliceGame = packed.instantiate() as SliceGame
	var b: SliceGame = packed.instantiate() as SliceGame
	root.add_child(a)
	root.add_child(b)
	await process_frame
	var moved := false
	var same := true
	var starts: Array[Vector2] = []
	for walker: GridWalker in a.crowd:
		starts.append(walker.position_m())
	for _frame: int in CROWD_FRAMES:
		await process_frame
	for i: int in a.crowd.size():
		same = same and a.crowd[i].position_m().is_equal_approx(b.crowd[i].position_m())
		moved = moved or not a.crowd[i].position_m().is_equal_approx(starts[i])
	check(moved and same, "the crowd walks its routes, the same way in two runs")
	a.queue_free()
	b.queue_free()


## A planted walk sheet (2 facings x 3 frames, 4 fps, looping) in user://: frames come out
## by facing and time, looping; a sheet missing a frame of a facing drops that facing.
func _check_clip_playback() -> void:
	DirAccess.make_dir_recursive_absolute(CLIP_DIR)
	var image := Image.create(CLIP_CELL * CLIP_FRAMES, CLIP_CELL * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	image.save_png(CLIP_DIR.path_join("walk.png"))
	var frames: Array = []
	for row: int in 2:
		for column: int in CLIP_FRAMES:
			var cell := {
				"x": column * CLIP_CELL, "y": row * CLIP_CELL, "w": CLIP_CELL, "h": CLIP_CELL
			}
			cell["facing"] = "S" if row == 0 else "E"
			cell["frame"] = column
			frames.append(cell)
	var manifest := {"image": "walk.png", "fps": CLIP_FPS, "loop": true, "frames": frames}
	var path := CLIP_DIR.path_join("walk.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var clip := SheetClip.load_manifest(path)
	var third := clip.frame_at("E", 2.0 / CLIP_FPS) if clip != null else null
	var wrapped := clip.frame_at("E", (CLIP_FRAMES + 2.0) / CLIP_FPS) if clip != null else null
	check(
		(
			third != null
			and third.region.position == Vector2(2 * CLIP_CELL, CLIP_CELL)
			and wrapped == third
		),
		"a walk sheet plays each facing's frames at its fps and loops"
	)
	frames.pop_back()
	manifest["frames"] = frames
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var partial := SheetClip.load_manifest(path)
	check(
		(
			partial != null
			and partial.frame_count("S") == CLIP_FRAMES
			and partial.frame_count("E") == 0
		),
		"a facing missing a frame is dropped, the complete one kept"
	)


## F5 opens the loop example; real mouse clicks on its panel buttons walk it from the
## arrival to the recruit card, hire, the contract and the road at dusk in the rain.
func _check_loop_panels() -> void:
	# The headless window is tiny; give it the game's size so the panel lies on screen.
	root.size = WINDOW_SIZE
	var game := await _spawn()
	await _tap(KEY_F5)
	var director := game.loop_director()
	var opened := director != null and director.loop.stage == SliceLoop.Stage.ARRIVE
	check(opened and director.panel.visible, "F5 opens the loop example on its arrival panel")
	if not opened:
		return
	for choice: String in ["continue", "hire", "accept", "continue"]:
		for _frame: int in LAYOUT_FRAMES:
			await process_frame
		await _click_button(director.panel.button_for(choice))
	var loop := director.loop
	check(
		(
			loop.stage == SliceLoop.Stage.GATE
			and loop.company.has(loop.recruit)
			and game.stage().time_of_day == StageLighting.TimeOfDay.DUSK
			and game.stage().rain
		),
		"clicking through the panels hires, takes the contract, reaches the road at dusk in rain"
	)
	game.queue_free()


func _click_button(button: Button) -> void:
	# A freshly shown panel lays its buttons out over the next frames.
	for _frame: int in LAYOUT_FRAMES:
		await process_frame
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


func _press_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _tap(code: Key) -> void:
	await _press_key(code, true)
	await _press_key(code, false)


func _settle(game: SliceGame) -> void:
	for _frame: int in SETTLE_FRAMES:
		if not game.player.is_moving():
			return
		await process_frame


func _first_label(node: Node) -> Label:
	for child: Node in node.get_children():
		if child is Label:
			return child as Label
		var found := _first_label(child)
		if found != null:
			return found
	return null


func _slice_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLICE_DATA))
	return parsed if parsed is Dictionary else {}


func _start_cell() -> Vector2i:
	var player: Dictionary = _slice_data().get("player", {})
	var start: Array = player.get("start_cell_xz", [0, 0])
	var x: float = start[0]
	var z: float = start[1]
	return Vector2i(int(x), int(z))


func _crowd_route(index: int) -> Array:
	var crowd: Dictionary = _slice_data().get("crowd", {})
	var route: Variant = crowd.get("route_%d" % index, [])
	return route if route is Array else []
