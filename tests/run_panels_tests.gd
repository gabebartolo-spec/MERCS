extends "res://tests/lib/runner.gd"
## Panels suite (the Phase 2 gate's gaps 2, 4 and 5): real letter keys and clicks at 1920x1080.
## Gap 2: while a road fight is on, or its triage stands, Save is refused (nothing is written;
## the triage panel says why and keeps its Continue). Gap 4: the hub (B) and the company screen
## (C) never stack, each opening closes the other, and while either is up the map's own panel
## and header stay out from under it; a battle's intent labels never sit on the panel's text.
## Gap 5: a chasing party's ring is a second ring outside the token, wider than the band's
## outline, in a colour no token or outline has.
## Seeded by design: world seed 424270 with a lone ambush (the wiring suite's); nothing rolls but
## the fight, which BattleAi plays.
##   godot --headless --path . --script tests/run_panels_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const World := preload("res://tests/lib/world_fixture.gd")
const InputKit := preload("res://tests/lib/input_kit.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const OUT := 3
const NEAR := 3
## The wiring suite's seed: an ambush whose fight puts an enemy's plan under the panel.
const FIGHT_SEED := 424270
const TAP_LIMIT := 8
const SETTLE := 8

var _clear_all := true
var _turns_seen := 0
var _apart := true
var _one_line_each := true
var _on_screen := true


func suite_name() -> String:
	return "Panels"


func run_checks() -> void:
	_clear_save()
	root.size = WINDOW_SIZE
	await _check_fight_and_screens()
	await _check_encounter_under_screen(KEY_B)
	await _check_encounter_under_screen(KEY_C)
	_check_chase_ring()
	_clear_save()


func _save_patrol_world() -> void:
	var rng := Rng.from_seed(FIGHT_SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	World.out_of_town(world, OUT)
	World.lone_party(world, "ambush", NEAR)
	(root.get_node(^"SaveSystem") as SAVE_SYSTEM).save_game(world, rng)


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


func _saved() -> bool:
	return FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH)


## A Save asked for through the panel's own signal, as its button would (the button is not
## offered in a fight or a triage; this is the path a stray click or key would take).
func _ask_save(director: OverworldDirector) -> void:
	director.panel.chosen.emit(OverworldDirector.SAVE)
	await InputKit.frames(self, SETTLE)


func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b)


## A new game on the saved ambush world, the map up, the save on disk gone (so a Save shows).
func _start_game() -> SliceGame:
	_save_patrol_world()
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	await InputKit.tap(self, KEY_M)
	_clear_save()
	return game


func _check_fight_and_screens() -> void:
	var game := await _start_game()
	var director := game.overworld_director()
	await _walk_into(director)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.FIGHT))
	if not director.in_fight():
		check(false, "walking into the ambush and clicking Fight starts the street battle")
		game.queue_free()
		return
	await InputKit.frames(self, SETTLE)
	await _ask_save(director)
	check(
		not _saved() and director.in_fight(),
		"Save asked for in the middle of a fight writes nothing and the fight goes on"
	)
	var direct := director.save_run()
	check(
		not direct and not _saved() and director.in_fight(),
		"save_run() called directly in the middle of a fight returns false and writes nothing"
	)
	_reset_readable()
	var won := await InputKit.finish_fight(self, director, _on_turn.bind(director))
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	check(
		_clear_all and _turns_seen > 0,
		(
			"over %d turns no enemy's intent label sat on the battle panel's text at 1920x1080"
			% _turns_seen
		)
	)
	_check_readable()
	await _check_triage_save(director)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.CONTINUE))
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	await _check_screens(game, won)
	game.queue_free()
	await process_frame


## An encounter that stands while the hub (B) or the company screen (C) is up: walking waits,
## and when the map is redrawn the panel with Fight stays out from under the screen, then comes
## back when the screen closes.
func _check_encounter_under_screen(code: Key) -> void:
	var game := await _start_game()
	var director := game.overworld_director()
	await InputKit.tap(self, code)
	var band := director.world.band
	await _walk_into(director)
	var held := director.world.band == band and director.world.encounter.is_empty()
	World.walk_toward(director.world, director.world.parties[0].tile, TAP_LIMIT)
	director.set_open(true)
	await InputKit.frames(self, SETTLE)
	var raised := not director.world.encounter.is_empty()
	var hidden := not director.panel.visible
	await InputKit.tap(self, code)
	await InputKit.frames(self, SETTLE)
	var back := (
		director.panel.visible and director.panel.button_for(OverworldDirector.FIGHT) != null
	)
	check(
		held and raised and hidden and back,
		(
			(
				"with screen %s up the keys do not walk, an encounter raised under it keeps the "
				+ "map's panel hidden and Fight returns when it closes (held %s, raised %s, hidden %s, back %s)"
			)
			% [OS.get_keycode_string(code), held, raised, hidden, back]
		)
	)
	game.queue_free()
	await process_frame
	_clear_save()


func _reset_readable() -> void:
	_clear_all = true
	_apart = true
	_one_line_each = true
	_on_screen = true
	_turns_seen = 0


func _check_readable() -> void:
	check(
		_apart,
		(
			"over %d turns no two fighters' sprites overlapped on screen (neighbouring cells too)"
			% _turns_seen
		)
	)
	check(
		_one_line_each and _on_screen,
		(
			"over %d turns each enemy's intent is one distinct line in the lane, fully on screen"
			% _turns_seen
		)
	)


func _check_triage_save(director: OverworldDirector) -> void:
	await _ask_save(director)
	var body := director.panel.shown_body()
	check(
		(
			not _saved()
			and director.panel.button_for(OverworldDirector.CONTINUE) != null
			and body.contains(Text.t("world.panel.save_busy"))
		),
		"Save asked for with the triage up writes nothing, says why and keeps Continue"
	)


## B, C and B again with real keys: one screen at a time, the map's own panel out from under.
func _check_screens(game: SliceGame, hub_was_open: bool) -> void:
	var director := game.overworld_director()
	if game.hub_open():
		await InputKit.tap(self, KEY_B)
	await InputKit.tap(self, KEY_B)
	var hub_first := _only(game, true)
	await InputKit.tap(self, KEY_C)
	var then_company := _only(game, false)
	await InputKit.tap(self, KEY_B)
	var then_hub := _only(game, true)
	await InputKit.frames(self, SETTLE)
	check(
		hub_first and then_company and then_hub,
		(
			"B opens the hub, C swaps it for the company screen, B swaps back (hub open at first: %s)"
			% hub_was_open
		)
	)
	check(
		not director.panel.visible and game.hub_director().panel.get_global_rect().size.x > 0.0,
		"with the hub up the map's own panel is out from under it"
	)
	await InputKit.tap(self, KEY_C)
	await InputKit.frames(self, SETTLE)
	check(
		_only(game, false) and not director.panel.visible,
		"with the company screen up the map's own panel is out from under it too"
	)
	await InputKit.tap(self, KEY_C)
	await InputKit.frames(self, SETTLE)
	check(
		not game.company_open() and not game.hub_open() and director.panel.visible,
		"closing the screens brings the map's panel back"
	)


## Exactly one of the two screens is open: the hub when `hub`, else the company's.
func _only(game: SliceGame, hub: bool) -> bool:
	return game.hub_open() == hub and game.company_open() != hub


## Before each company turn: every visible intent label stands clear of the panel.
func _on_turn(director: OverworldDirector) -> void:
	_turns_seen += 1
	if not _intents_clear_of_panel(director):
		_clear_all = false


func _intents_clear_of_panel(director: OverworldDirector) -> bool:
	var view := director.view
	var panel_rect := director.panel.get_global_rect()
	var lane := view.lane_rect()
	var texts := {}
	for unit: BattleUnit in view.battle.units:
		if unit.side != BattleUnit.ENEMY:
			continue
		var label := view.intent_label(unit.id)
		if label == null or not label.visible:
			continue
		if texts.has(label.text):
			_one_line_each = false
			printerr("duplicate intent line: %s" % label.text)
		texts[label.text] = true
	if not texts.is_empty() and not Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE)).encloses(lane):
		_on_screen = false
		printerr("intent lane %s leaves the screen" % lane)
	_check_apart(view)
	if not texts.is_empty() and _overlaps(lane, panel_rect):
		printerr("intent lane %s over panel %s" % [lane, panel_rect])
		return false
	return true


## No two standing fighters' sprite rectangles share a pixel.
func _check_apart(view: BattleView) -> void:
	var rects := view.sprite_rects()
	var ids := rects.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var a: BattleUnit = view.battle.unit(str(ids[i]))
			var b: BattleUnit = view.battle.unit(str(ids[j]))
			if a.down or b.down:
				continue
			var ra: Rect2 = rects[ids[i]]
			var rb: Rect2 = rects[ids[j]]
			if ra.intersects(rb):
				_apart = false
				printerr(
					"sprites overlap: %s %s %s and %s %s %s" % [a.id, a.cell, ra, b.id, b.cell, rb]
				)


func _check_chase_ring() -> void:
	var ring := OverworldMap.chase_ring()
	var outline := OverworldMap.outline()
	var colours: Array[Color] = [outline["colour"]]
	for key: String in ["band", "ambush", "patrol", "site"]:
		colours.append(OverworldMap.token_colour(key))
	var radius: float = ring["radius"]
	var ring_width: float = ring["width"]
	var outline_width: float = outline["width"]
	var token_radius: float = OverworldMap.token_radius("ambush")
	check(
		radius > token_radius and ring_width > outline_width and not colours.has(ring["colour"]),
		"a chasing party's ring lies outside its token, is wider than an outline, has its own colour"
	)


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))
