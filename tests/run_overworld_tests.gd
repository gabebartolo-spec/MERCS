extends "res://tests/lib/runner.gd"
## Overworld suite (Phase 2 M1b: OverworldDirector, OverworldMap, the SaveSystem autoload).
## Real input events reach the game through Input.parse_input_event, never a handler call:
## a real M tap opens the map with a marker per site and the day's choices; a held key does
## not walk the merc while it is open; real clicks on the panel's buttons take a road (the
## day moves by the road's days and the company's ring moves to the new site), rest a day,
## and save; the map hidden by M and shown again keeps the run (the same director, its day
## and site); the save on disk under the run's own user dir reads back equal; M hides the
## map and walking resumes; a fresh session's first M continues the save instead of starting
## fresh; Escape hides it. Seeded by design: the balance seed only (data/balance/world.json).
##   godot --headless --path . --script tests/run_overworld_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const BALANCE := "res://data/balance/world.json"
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
	await _check_travel(game)
	await _check_rest(game)
	await _check_hidden_keeps_run(game)
	await _check_save_and_load(game)
	await _check_close(game)
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
	await _tap(KEY_M)
	var director := game.overworld_director()
	if director == null:
		check(false, "M opens the overworld map (no director)")
		return
	for _frame: int in LAYOUT_FRAMES:
		await process_frame
	var world := director.world
	var markers := _marker_count(director)
	check(
		(
			director.map.is_visible_in_tree()
			and markers == world.sites.size()
			and markers > 0
			and world.day == 0
			and world.at == RegionGen.HUB_ID
			and _choices_shown(director)
		),
		(
			"M opens the map on day 0 at the hub: %d markers for %d sites, a road, rest and save"
			% [markers, world.sites.size()]
		)
	)


func _marker_count(director: OverworldDirector) -> int:
	var markers := 0
	for site: WorldSite in director.world.sites:
		if director.map.marker_for(site.id) != null:
			markers += 1
	return markers


## The panel is up with a button for the first road out, for a rest and for a save.
func _choices_shown(director: OverworldDirector) -> bool:
	var panel := director.panel
	return (
		panel.visible
		and panel.button_for(director.world.destinations()[0]) != null
		and panel.button_for(OverworldDirector.REST) != null
		and panel.button_for(OverworldDirector.SAVE) != null
	)


func _check_walking_paused(game: SliceGame) -> void:
	var start := game.player.cell
	await _hold(KEY_D)
	check(
		game.player.cell == start and not game.player.is_moving(),
		"holding D does not walk the merc while the map is open"
	)


## A real click on the first road's button: the day moves by the road's days, the company
## is at the new site and its ring sits on that site's marker.
func _check_travel(game: SliceGame) -> void:
	var director := game.overworld_director()
	var world := director.world
	var from := world.site(world.at)
	var to := world.destinations()[0]
	var days := from.days_to(to)
	var day_before := world.day
	await _click_button(director.panel.button_for(to))
	for _frame: int in LAYOUT_FRAMES:
		await process_frame
	var marker := director.map.marker_for(to)
	var ring := director.map.company_marker()
	var ring_on_site := (
		marker != null
		and ring.visible
		and ring.get_global_rect().get_center().is_equal_approx(
			marker.get_global_rect().get_center()
		)
	)
	check(
		world.at == to and world.day == day_before + days and days > 0 and ring_on_site,
		(
			"clicking the road to %s moves the company there in %d days (day %d) and its ring"
			% [to, days, world.day]
		)
	)


func _check_rest(game: SliceGame) -> void:
	var director := game.overworld_director()
	var day_before := director.world.day
	var at_before := director.world.at
	await _click_button(director.panel.button_for(OverworldDirector.REST))
	check(
		director.world.day == day_before + 1 and director.world.at == at_before,
		"clicking rest passes one day in the same place"
	)


## A real click on save writes the file under this run's own user dir; load_game reads a
## world equal to the one on screen.
func _check_save_and_load(game: SliceGame) -> void:
	var director := game.overworld_director()
	await _click_button(director.panel.button_for(OverworldDirector.SAVE))
	var path := ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH)
	var in_user_dir := path.begins_with(OS.get_user_data_dir())
	var model := _saves().load_game(_json(BALANCE))
	# JSON sorts a dictionary's keys, so both states are compared in that same canonical form.
	var equal := (
		model.ok and JSON.stringify(model.world.state()) == JSON.stringify(director.world.state())
	)
	check(
		(
			_saves().has_save()
			and FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH)
			and in_user_dir
			and equal
			and model.ok
			and model.rng.seed_value == director.rng.seed_value
		),
		(
			"clicking save writes %s under the run's user dir (%s) and it loads back equal (%s)"
			% [path, in_user_dir, equal]
		)
	)


## A day passed, the map hidden with M and shown again: the same director, with the day and
## the site it had, not a reload from disk or a fresh start. (A rest, not a road: a long road
## may raise an encounter, which has its own suite, road.)
func _check_hidden_keeps_run(game: SliceGame) -> void:
	var director := game.overworld_director()
	var to := director.world.at
	await _click_button(director.panel.button_for(OverworldDirector.REST))
	var day := director.world.day
	await _tap(KEY_M)
	var hidden := is_instance_valid(director) and not director.is_open()
	await _tap(KEY_M)
	var same := is_instance_valid(director) and game.overworld_director() == director
	check(
		(
			hidden
			and same
			and director.is_open()
			and director.world.day == day
			and director.world.at == to
		),
		(
			"the map hidden by M and shown again keeps the run: the same director on day %d at %s"
			% [day, to]
		)
	)


func _check_close(game: SliceGame) -> void:
	await _tap(KEY_M)
	var director := game.overworld_director()
	var closed := director == null or not director.is_open()
	var start := game.player.cell
	await _hold(KEY_D)
	await _settle(game)
	check(
		closed and game.player.cell != start,
		"M hides the map and holding D walks the merc again (%s -> %s)" % [start, game.player.cell]
	)


func _check_continue_from_save(game: SliceGame) -> void:
	var model := _saves().load_game(_json(BALANCE))
	await _tap(KEY_M)
	var director := game.overworld_director()
	var continued := (
		director != null
		and model.ok
		and JSON.stringify(director.world.state()) == JSON.stringify(model.world.state())
		and director.world.day > 0
	)
	await _tap(KEY_ESCAPE)
	var hidden := director == null or not director.is_open()
	check(
		continued and hidden,
		(
			"a fresh session's first M continues the save on disk (day %d) and Escape hides the map"
			% model.world.day
		)
	)


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


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
