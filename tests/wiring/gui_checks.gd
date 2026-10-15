extends RefCounted
## The wiring suite's GUI checks, run by tests/run_wiring_tests.gd: real clicks and letter keys
## at 1920x1080 through the whole game: walk into an ambush, Fight, the triage panel (the
## chronicle line, no key help), Continue, the C screen marking the fallen, Save, and a fresh
## session that never fields the dead. Seeded by design: the ambush met by walking on world
## seed 424270, played by BattleAi.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const LAYOUT_FRAMES := 3
const FIGHT_FRAMES := 6000
const GUI_SEED := 424270
const NEAR := 3
const TAP_LIMIT := 8
const World := preload("res://tests/lib/world_fixture.gd")
## Who dies in that fight (BattleAi plays the company, the injury stream rolls the triage).
const FALLEN: Array[String] = ["merc_4"]

var _tree: SceneTree = null
var _check: Callable


## tree: the runner's SceneTree; check: the runner's check(condition, expectation).
func setup(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check


func _cells() -> Array[Vector2i]:
	return EncounterBattle.company_cells(Kit.scenario())


func _ids(units: Array[BattleUnit]) -> Array[String]:
	var ids: Array[String] = []
	for unit: BattleUnit in units:
		ids.append(unit.id)
	return ids


func _cast() -> int:
	return Fixture.rows(Fixture.json(Fixture.MERCS), "mercs").size()


func run() -> void:
	_clear_save()
	_save_ambush_world()
	var game := await _spawn()
	await _tap(KEY_M)
	var director := game.overworld_director()
	await _walk_into(director)
	await _click_button(director.panel.button_for(OverworldDirector.FIGHT))
	await _frames(LAYOUT_FRAMES)
	var fielded: Array[String] = director.wounds.fielded.duplicate()
	var fought := director.in_fight() and fielded.size() == _cells().size()
	_check.call(
		fought and fielded[0] == "orc" and director.view.battle.unit("orc").is_leader,
		"Fight on the road fields the company, the orc captain first: %s" % [fielded]
	)
	await _finish_fight(director)
	await _frames(LAYOUT_FRAMES)
	await _check_triage_panel(game, director)
	await _continue_and_save(game, director)


func _continue_and_save(game: SliceGame, director: OverworldDirector) -> void:
	await _click_button(director.panel.button_for(OverworldDirector.CONTINUE))
	await _frames(LAYOUT_FRAMES)
	_check.call(
		(
			director.panel.button_for(OverworldDirector.CONTINUE) == null
			and director.panel.button_for(OverworldDirector.SAVE) != null
			and director.map.visible
		),
		"Continue returns to the map with its choices"
	)
	# A won fight opens the hub over the map; its panel covers Save, so the hub is shut first.
	if game.hub_open():
		await _tap(KEY_B)
		await _frames(LAYOUT_FRAMES)
	await _click_button(director.panel.button_for(OverworldDirector.SAVE))
	await _check_company_screen(game)
	game.queue_free()
	await _tree.process_frame
	await _check_fresh_session()
	_clear_save()


## A saved world with the band three tiles out of the hub's gate and a lone ambush near it.
func _save_ambush_world() -> void:
	var rng := Rng.from_seed(GUI_SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	World.out_of_town(world, NEAR)
	World.lone_party(world, "ambush", NEAR)
	_saves().save_game(world, rng)


## Taps the walking keys toward the lone party until its encounter stands.
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
		await _tap(code)


func _check_triage_panel(game: SliceGame, director: OverworldDirector) -> void:
	var body := director.panel.shown_body()
	var lines_ok := true
	for entry: Dictionary in director.wounds.chronicle().entries:
		var merc_id := str(entry.get("merc", ""))
		var cause := TriageText.name_of(str(entry.get("cause", "")), director.company)
		var line := Text.t(
			"chronicle.death",
			{
				"name": director.company.name_of(merc_id),
				"day": Merc.whole(entry.get("day", -1)),
				"cause": cause
			}
		)
		lines_ok = lines_ok and body.contains(line)
	var shared := StoryDirector.memory_of(director)
	var hud: CanvasLayer = game.get(&"_hud")
	_check.call(
		(
			director.panel.button_for(OverworldDirector.CONTINUE) != null
			and director.panel.button_for(OverworldDirector.SAVE) == null
			and _fallen(director.wounds) == FALLEN
			and lines_ok
			and shared != null
			and not shared.of("orc").is_empty()
			and hud != null
			and not hud.visible
		),
		(
			"triage panel: each death with its chronicle line, Continue only, no key help: %s"
			% body.replace("\n", " | ")
		)
	)


## The ids in the chronicle, sorted.
func _fallen(wounds: CompanyWounds) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in wounds.chronicle().entries:
		ids.append(str(entry.get("merc", "")))
	ids.sort()
	return ids


func _check_company_screen(game: SliceGame) -> void:
	if game.hub_open():
		await _tap(KEY_ESCAPE)
	# The band is not at the gate, so M cannot close the map; hide it to reach the screen.
	game.overworld_director().set_open(false)
	await _tap(KEY_C)
	await _frames(LAYOUT_FRAMES)
	var screen := game.company_director()
	var panel := screen.panel
	var rows := panel.row_for(FALLEN[0])
	var name := screen.company.name_of(FALLEN[0])
	var gone := rows != null and rows.text == Text.t("company.fallen.row", {"name": name})
	await _click_button(rows)
	await _frames(LAYOUT_FRAMES)
	var shown := panel.header_text() == Text.t("company.fallen.title", {"name": name})
	_check.call(
		(
			gone
			and shown
			and screen.company.member(FALLEN[0]) == null
			and screen.company.roster.size() == _cast() - FALLEN.size()
			and panel.lines_text().contains(Text.t("company.fallen.gone"))
			and panel.row_for("orc").text.contains(Text.t("company.mark.captain"))
		),
		"the C screen marks the fallen gone, with the chronicle line, and the captain still marked"
	)
	await _tap(KEY_C)


func _check_fresh_session() -> void:
	var game := await _spawn()
	var screen := game.company_director()
	var units := screen.wounds.units(_cells(), BattleUnit.COMPANY)
	var shared := StoryDirector.memory_of(game.company_director())
	_check.call(
		(
			_fallen(screen.wounds) == FALLEN
			and screen.company.fallen.size() == FALLEN.size()
			and FALLEN.all(func(id: String) -> bool: return not _ids(units).has(id))
			and units.size() == _cast() - FALLEN.size()
			and shared != null
			and not shared.of("orc").is_empty()
		),
		"a new session: the dead are never fielded, chronicle and shared memories are back"
	)
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


## Plays the company's turns by clicks and waits out the enemy's, until the battle is over.
func _finish_fight(director: OverworldDirector) -> void:
	var battle := director.view.battle
	var rules: Dictionary = Kit.json(Fixture.BATTLE).get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	for _frame: int in FIGHT_FRAMES:
		if battle.is_over():
			break
		var actor := battle.current()
		if actor.side == BattleUnit.COMPANY:
			await _company_turn(director, BattleAi.choose(battle, actor, sight))
		else:
			await _tree.process_frame


func _company_turn(director: OverworldDirector, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		director.view.click_cell(director.origin + to)
		await _tree.process_frame
		return
	var choice_id := Battle.ACTION_WAIT
	if kind == Battle.ACTION_ATTACK:
		choice_id = "%s:%s" % [Battle.ACTION_ATTACK, action.get("target")]
	await _click_button(director.panel.button_for(choice_id))


func _frames(count: int) -> void:
	for _frame: int in count:
		await _tree.process_frame


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
		await _tree.process_frame


func _tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await _tree.process_frame
