extends "res://tests/lib/runner.gd"
## Inspect suite (Phase 2 milestone 3: CompanyDirector, CompanyPanel, the SaveSystem autoload).
## Real input events reach the game through Input.parse_input_event, never a handler call: a
## real C tap opens the company with a row per merc and the captain marked; a real click on a
## roster row shows that merc's name, level, role words, stats, moves at their level, own gear
## line, the three generic slots and the experience bar; the initiative shown is the one he
## acts at in a fight (his plate's slowness counted, Phase 4 P1b); a placeholder says so; a
## real click on the office button makes them captain (the row marks move, the button goes);
## a held key does not walk the merc while it is open; hide and show keeps the screen; the captain
## chosen here is in the save the overworld writes and a fresh session shows it; Escape hides.
## Seeded by design: nothing here rolls; the world uses the balance seed.
##   godot --headless --path . --script tests/run_inspect_tests.gd

const InputKit := preload("res://tests/lib/input_kit.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const WORLD_BALANCE := "res://data/balance/world.json"
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
const HOLD_FRAMES := 30
const BLOOD_PRICE_XP := 4
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")


func suite_name() -> String:
	return "Inspect"


func run_checks() -> void:
	# The headless window is tiny; give it the game's size so the panel lies on screen.
	root.size = WINDOW_SIZE
	_clear_save()
	var game := await _spawn()
	await _check_open(game)
	await _check_pick(game)
	_check_initiative(game)
	await _check_placeholder(game)
	await _check_experience_bar(game)
	await _check_walking_paused(game)
	await _check_appoint(game)
	await _check_hide_keeps_screen(game)
	await _check_saved_captain(game)
	game.queue_free()
	await process_frame
	var fresh := await _spawn()
	await _check_fresh_session(fresh)
	fresh.queue_free()
	await process_frame
	_clear_save()


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


func _check_open(game: SliceGame) -> void:
	await _tap(KEY_C)
	var director := game.company_director()
	if director == null:
		check(false, "C opens the company (no director)")
		return
	await _frames(LAYOUT_FRAMES)
	var panel := director.panel
	var rows := 0
	for merc: Merc in director.company.roster:
		rows += 1 if panel.row_for(merc.id) != null else 0
	var orc_row := panel.row_for("orc")
	check(
		(
			panel.is_visible_in_tree()
			and rows == 6
			and orc_row != null
			and orc_row.text.contains(Text.t("company.mark.captain").strip_edges())
			and not panel.row_for("vampyr").text.contains(
				Text.t("company.mark.captain").strip_edges()
			)
			and panel.header_text() == "The Orc, level 1"
		),
		(
			"C opens the company: a row for each of the %d mercs, the orc marked captain and shown"
			% rows
		)
	)


## A real click on the Vampyr's row: his name, level, role, stats, moves and gear on show.
func _check_pick(game: SliceGame) -> void:
	var panel := game.company_director().panel
	await _click_button(panel.row_for("vampyr"))
	var lines := panel.lines_text()
	var vampyr := game.company_director().company.member("vampyr")
	check(
		(
			panel.shown_id() == "vampyr"
			and panel.header_text() == "The Vampyr, level 1"
			and lines.contains(vampyr.role)
			and lines.contains(Text.t("company.stat.resolve", {"value": vampyr.stat("resolve")}))
			and lines.contains(Text.t("company.stat.hp", {"value": vampyr.stat("hp")}))
			and lines.contains(Text.t("company.move.blood_price"))
			and lines.contains("Moves: Move, Attack, Blood price")
			and lines.contains(Text.t("company.next.move", {"move": Text.t("company.move.charge")}))
			and lines.contains(Text.t("company.gear", {"gear": vampyr.stage_1_gear[0]}))
			and lines.contains(
				Text.t("company.slot.weapon", {"gear": Text.t("company.slot.empty")})
			)
			and lines.contains(
				Text.t("company.slot.armour", {"gear": Text.t("company.slot.empty")})
			)
			and lines.contains(
				Text.t("company.slot.trinket", {"gear": Text.t("company.slot.empty")})
			)
		),
		(
			"clicking the Vampyr's row shows his role, stats, moves at his level, gear line "
			+ "and the three slots"
		)
	)


## One source for initiative: the screen shows what the Vampyr acts at once a battle has set
## him up (his plate counted), not his bare stat.
func _check_initiative(game: SliceGame) -> void:
	var lines := game.company_director().panel.lines_text()
	var vampyr := game.company_director().company.member("vampyr")
	var unit := vampyr.to_battle_unit(BattleUnit.COMPANY, Vector2i.ZERO, true)
	var foe := BattleUnit.make("foe", BattleUnit.ENEMY, Vector2i(3, 3), {})
	var found: Variant = _json("res://data/balance/battle.json").get("rules", {})
	var rules: Dictionary = found if found is Dictionary else {}
	var battle := Battle.new()
	battle.setup(
		rules, {"size": Vector2i(4, 4)}, [unit, foe] as Array[BattleUnit], Rng.from_seed(1)
	)
	check(
		(
			unit.initiative != vampyr.stat("initiative")
			and lines.contains(Text.t("company.stat.initiative", {"value": unit.initiative}))
			and not lines.contains(
				Text.t("company.stat.initiative", {"value": vampyr.stat("initiative")})
			)
		),
		(
			"the Vampyr's initiative on the company screen is the %d he acts at (plate counted)"
			% [unit.initiative]
		)
	)


func _check_placeholder(game: SliceGame) -> void:
	var panel := game.company_director().panel
	await _click_button(panel.row_for("merc_3"))
	var lines := panel.lines_text()
	check(
		(
			panel.header_text() == "Unnamed 3, level 1"
			and lines.contains(Text.t("company.placeholder"))
			and lines.contains("To be written by the director")
			and lines.contains(Text.t("company.gear_none"))
		),
		"a placeholder merc says it is one, with the director's 'to be written' role"
	)


## The bar is the experience into this level over the level's width; it moves with the sim.
func _check_experience_bar(game: SliceGame) -> void:
	var director := game.company_director()
	var panel := director.panel
	await _tap(KEY_C)
	game.company_director().company.gain("vampyr", BLOOD_PRICE_XP)
	await _tap(KEY_C)
	await _click_button(panel.row_for("vampyr"))
	var bar := panel.bar()
	var xp: Dictionary = _json("res://data/balance/company.json").get("xp", {})
	var level_xp: Array = xp.get("level_xp", [])
	var two := Merc.whole(level_xp[1])
	check(
		(
			bar.value == float(BLOOD_PRICE_XP)
			and bar.max_value == float(two)
			and bar.is_visible_in_tree()
		),
		(
			(
				"the experience bar shows %d of %d (level 2, from data) for the Vampyr after the sim "
				% [int(bar.value), two]
			)
			+ "gave him %d" % BLOOD_PRICE_XP
		)
	)


func _check_walking_paused(game: SliceGame) -> void:
	var start := game.player.cell
	await _hold(KEY_D)
	check(
		game.player.cell == start and not game.player.is_moving(),
		"holding D does not walk the merc while the company is open"
	)


## A real click on the office button: the sim's captain changes and the rows follow.
func _check_appoint(game: SliceGame) -> void:
	var director := game.company_director()
	var panel := director.panel
	var before := JSON.stringify(game.company_director().company.state())
	await _click_button(panel.appoint_button())
	var mark := Text.t("company.mark.captain").strip_edges()
	check(
		(
			game.company_director().company.captain_id == "vampyr"
			and JSON.stringify(game.company_director().company.state()) != before
			and panel.row_for("vampyr").text.contains(mark)
			and not panel.row_for("orc").text.contains(mark)
			and not panel.appoint_button().visible
		),
		(
			"clicking 'make captain' gives the Vampyr the office: the sim, the row marks and "
			+ "the button follow"
		)
	)


func _check_hide_keeps_screen(game: SliceGame) -> void:
	var director := game.company_director()
	await _tap(KEY_C)
	var hidden := is_instance_valid(director) and not director.is_open()
	await _tap(KEY_C)
	check(
		(
			hidden
			and game.company_director() == director
			and director.is_open()
			and director.company.captain_id == "vampyr"
		),
		"C hides the company and shows it again: the same screen, the Vampyr still captain"
	)


## The captain picked here is in the save the overworld writes (a real click on its Save).
func _check_saved_captain(game: SliceGame) -> void:
	await _tap(KEY_C)
	await _tap(KEY_M)
	var overworld := game.overworld_director()
	await InputKit.pick_mode(self, overworld)
	await _click_button(overworld.panel.button_for(OverworldDirector.SAVE))
	var model := _saves().load_game(_json(WORLD_BALANCE), CompanyDirector.defs())
	check(
		(
			model.ok
			and model.company != null
			and model.company.captain_id == "vampyr"
			and model.company.member("vampyr").xp == BLOOD_PRICE_XP
		),
		"the overworld's Save writes the company: the Vampyr captain with his experience"
	)
	await _tap(KEY_M)


func _check_fresh_session(game: SliceGame) -> void:
	await _tap(KEY_C)
	await _frames(LAYOUT_FRAMES)
	var director := game.company_director()
	var panel := director.panel
	var shown := panel.header_text()
	await _tap(KEY_ESCAPE)
	check(
		(
			director.company.captain_id == "vampyr"
			and panel.row_for("vampyr").text.contains(Text.t("company.mark.captain").strip_edges())
			and shown == "The Vampyr, level 1"
			and not director.is_open()
		),
		(
			"a fresh session opens the company from the save (the Vampyr captain, shown "
			+ "first); Escape hides it"
		)
	)


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


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
	await _frames(HOLD_FRAMES)
	await _press_key(code, false)
