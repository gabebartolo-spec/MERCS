extends "res://tests/lib/runner.gd"
## Overworld suite (Phase 2, the walkable overworld: OverworldDirector, OverworldMap, the
## SaveSystem autoload). Real input events reach the game through Input.parse_input_event,
## never a handler call, with the root at 1920 x 1080. A real F2 leaves the street for the map:
## a marker per site, the band's token at the view's centre on the hub's gate, Rest and Save
## and no travel buttons; a held key does not walk the street's merc while it is open; a tap
## of S walks the band one tile and the map scrolls under it; a held S repeats, a tile at a
## time; a click on Rest passes a day in place; F2 away from the gate keeps the map and says
## where the street is; walking back into the hub's gate cuts to the street, where D walks the
## merc again; F2 from the street shows the same run; a click on Save writes the save, which
## reads back equal; a fresh session's first F2 continues it and Escape on the gate goes back
## to the street. Seeded by design: the balance seed only (data/balance/world.json).
##   godot --headless --path . --script tests/run_overworld_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
const HOLD_FRAMES := 30
const SETTLE_FRAMES := 240
## The SaveSystem autoload, by its script: a --script run knows no autoload by name.
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")


func suite_name() -> String:
	return "Overworld"


func run_checks() -> void:
	# The headless window is tiny; give it the game's size so the panel lies on screen.
	root.size = WINDOW_SIZE
	_clear_save()
	var game := await _spawn()
	await _check_open(game)
	await _check_walking_paused(game)
	await _check_tap_walks(game)
	await _check_hold_repeats(game)
	await _check_rest(game)
	await _check_not_at_gate(game)
	await _check_gate_cuts_to_street(game)
	await _check_hidden_keeps_run(game)
	await _check_save_and_load(game)
	game.queue_free()
	await process_frame
	var fresh := await _spawn()
	await _check_continue_from_save(fresh)
	fresh.queue_free()
	await process_frame
	_clear_save()


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


func _check_open(game: SliceGame) -> void:
	await _tap(KEY_F2)
	var director := game.overworld_director()
	if director == null:
		check(false, "F2 opens the overworld map (no director)")
		return
	await _frames(LAYOUT_FRAMES)
	var world := director.world
	var markers := 0
	for site: WorldSite in world.sites:
		markers += 1 if director.map.marker_for(site.id) != null else 0
	var panel := director.panel
	check(
		(
			director.map.is_visible_in_tree()
			and markers == world.sites.size()
			and world.day == 0
			and world.band == world.region.entrance(RegionGen.HUB_ID)
			and _token_centred(director)
			and panel.button_for(OverworldDirector.REST) != null
			and panel.button_for(OverworldDirector.SAVE) != null
			and panel.button_for(world.sites[1].id) == null
		),
		(
			(
				"F2 opens the map on day 0, the band's token centred on the hub's gate, %d markers,"
				+ " Rest and Save and no travel buttons"
			)
			% markers
		)
	)


## The band's token sits at the map's centre (the view follows the band).
func _token_centred(director: OverworldDirector) -> bool:
	var token := director.map.company_marker().get_global_rect().get_center()
	var middle := director.map.get_global_rect().get_center()
	return token.distance_to(middle) <= 1.0


func _check_walking_paused(game: SliceGame) -> void:
	var start := game.player.cell
	var band := game.overworld_director().world.band
	await _hold(KEY_D)
	check(
		game.player.cell == start and not game.player.is_moving(),
		"holding D does not walk the street's merc while the map is open (band %s)" % band
	)


## A tap of S: one tile south out of the gate, a day's units started, the map scrolled.
func _check_tap_walks(game: SliceGame) -> void:
	var director := game.overworld_director()
	var world := director.world
	var before := world.band
	var hub := director.map.marker_for(RegionGen.HUB_ID).get_global_rect().get_center()
	await _tap(KEY_S)
	await _frames(LAYOUT_FRAMES)
	var hub_after := director.map.marker_for(RegionGen.HUB_ID).get_global_rect().get_center()
	var tile_px := hub.y - hub_after.y
	check(
		(
			world.band == before + Vector2i(0, 1)
			and world.march > 0
			and tile_px > 0.0
			and _token_centred(director)
		),
		(
			"a tap of S walks the band one tile south (%s) and the map scrolls %d px under it"
			% [world.band, tile_px]
		)
	)


## Holding S walks on a tile at a time: more than one step, never more than one per frame,
## each a single tile.
func _check_hold_repeats(game: SliceGame) -> void:
	var world := game.overworld_director().world
	var before := world.band
	await _hold(KEY_S)
	var walked := world.band - before
	check(
		walked.x == 0 and walked.y > 1 and walked.y < HOLD_FRAMES,
		(
			"holding S for %d frames walks the band on %d tiles, a tile at a time"
			% [HOLD_FRAMES, walked.y]
		)
	)


func _check_rest(game: SliceGame) -> void:
	var director := game.overworld_director()
	var day_before := director.world.day
	var band_before := director.world.band
	await _click_button(director.panel.button_for(OverworldDirector.REST))
	check(
		director.world.day == day_before + 1 and director.world.band == band_before,
		"clicking Rest passes one day in the same place"
	)


func _check_not_at_gate(game: SliceGame) -> void:
	var director := game.overworld_director()
	await _tap(KEY_F2)
	await _tap(KEY_ESCAPE)
	check(
		director.is_open() and director.panel.shown_body() == Text.t("world.panel.not_at_gate"),
		"F2 and Escape away from the hub's gate keep the map and say the street is through the gate"
	)


## Walks north back to the gate by taps of W: the map hides and the street is played again.
func _check_gate_cuts_to_street(game: SliceGame) -> void:
	var director := game.overworld_director()
	var world := director.world
	var gate := world.region.entrance(RegionGen.HUB_ID)
	var taps := 0
	while world.band != gate and taps < HOLD_FRAMES and director.is_open():
		await _tap(KEY_W)
		taps += 1
	var start := game.player.cell
	await _hold(KEY_D)
	await _settle(game)
	check(
		(
			taps > 0
			and world.band == gate
			and world.at == RegionGen.HUB_ID
			and not director.is_open()
			and game.player.cell != start
		),
		(
			"%d taps of W walk the band back into the hub's gate: the map hides and D walks the street"
			% taps
		)
	)


## F2 on the street shows the same run, the band on the gate, the day as it was.
func _check_hidden_keeps_run(game: SliceGame) -> void:
	var director := game.overworld_director()
	var day := director.world.day
	await _tap(KEY_F2)
	await _frames(LAYOUT_FRAMES)
	check(
		(
			game.overworld_director() == director
			and director.is_open()
			and director.world.day == day
			and director.world.band == director.world.region.entrance(RegionGen.HUB_ID)
			and _token_centred(director)
		),
		"F2 from the street shows the same run again: day %d, the band on the hub's gate" % day
	)


## A real click on Save writes the file under this run's own user dir; load_game reads a
## world equal to the one on screen.
func _check_save_and_load(game: SliceGame) -> void:
	var director := game.overworld_director()
	await _click_button(director.panel.button_for(OverworldDirector.SAVE))
	var path := ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH)
	var in_user_dir := path.begins_with(OS.get_user_data_dir())
	var model := _saves().load_game(OverworldDirector.world_data())
	# JSON sorts a dictionary's keys, so both states are compared in that same canonical form.
	var equal := (
		model.ok and JSON.stringify(model.world.state()) == JSON.stringify(director.world.state())
	)
	check(
		(
			_saves().has_save()
			and in_user_dir
			and equal
			and model.rng.seed_value == director.rng.seed_value
		),
		(
			"clicking Save writes %s under the run's user dir (%s) and it loads back equal (%s)"
			% [path, in_user_dir, equal]
		)
	)


func _check_continue_from_save(game: SliceGame) -> void:
	var model := _saves().load_game(OverworldDirector.world_data())
	await _tap(KEY_F2)
	var director := game.overworld_director()
	var continued := (
		director != null
		and model.ok
		and JSON.stringify(director.world.state()) == JSON.stringify(model.world.state())
		and director.world.day > 0
	)
	await _tap(KEY_ESCAPE)
	var hidden := director != null and not director.is_open()
	check(
		continued and hidden,
		(
			(
				"a fresh session's first F2 continues the save (day %d) and Escape on the gate"
				+ " goes back to the street"
			)
			% model.world.day
		)
	)


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _click_button(button: Button) -> void:
	# A freshly shown panel lays its buttons out over the next frames.
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


func _hold(code: Key) -> void:
	await _press_key(code, true)
	for _frame: int in HOLD_FRAMES:
		await process_frame
	await _press_key(code, false)


func _settle(game: SliceGame) -> void:
	for _frame: int in SETTLE_FRAMES:
		if not game.player.is_moving():
			return
		await process_frame
