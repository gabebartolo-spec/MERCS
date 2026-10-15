extends "res://tests/lib/runner.gd"
## Road suite (Phase 2 M2: an encounter on the road, on screen). Real input events reach the
## game through Input.parse_input_event: M and Escape taps, real mouse clicks on the panel's
## buttons. On the balance seed the road to the second hamlet raises a patrol: the panel says
## what it is with Fight and Pay the toll, the company stays where it was, M and Escape keep
## the encounter; Fight closes the map and starts the street battle (the company acts first),
## and when it ends the fighters leave the street, the result is applied and the triage panel
## opens (Continue returns to the map, with the outcome in words). Paying the toll skips the
## fight. A saved world on another seed
## has an ambush on its first road: only Fight, the enemy strikes first. A save taken with an
## encounter standing reopens on its panel. The company's moves in the fight use the sim's
## BattleAi for the choice; attacks and waits are real clicks, a move calls click_cell().
## Seeded by design: the balance seed (data/balance/world.json) and Rng.from_seed(424243).
##   godot --headless --path . --script tests/run_road_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const BALANCE := "res://data/balance/world.json"
const ENCOUNTERS := "res://data/encounters.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
const FIGHT_FRAMES := 6000
const AMBUSH_SEED := 424243
## The second hamlet's road raises a patrol on the balance seed.
const PATROL_ROAD := "site_hamlet_2"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")


func suite_name() -> String:
	return "Road"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_clear_save()
	var game := await _spawn()
	await _tap(KEY_M)
	var director := game.overworld_director()
	await _check_patrol_raised(director)
	await _check_encounter_holds(game, director)
	var before := {
		"supplies": director.world.supplies,
		"days_left": director.world.encounter.get("days_left", 0),
		"to": director.world.encounter.get("to", ""),
		"mercs": game.stage().extra_mercs.size(),
	}
	await _check_fight_starts(game, director)
	await _check_fight_returns(game, director, before)
	game.queue_free()
	await process_frame
	_clear_save()
	var tolled := await _spawn()
	await _tap(KEY_M)
	await _check_toll(tolled.overworld_director())
	tolled.queue_free()
	await process_frame
	_clear_save()
	await _check_ambush()
	await _check_saved_encounter()
	_clear_save()


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


## What the encounter panel should say for the standing encounter.
func _expected_body(director: OverworldDirector) -> String:
	var found := director.world.encounter
	var site := OverworldMap.site_name(director.world.site(str(found.get("to", ""))))
	var params := {"site": site, "day": director.world.day, "toll": director.world.toll_cost()}
	return Text.t("world.encounter.%s.body" % found.get("type"), params)


func _check_patrol_raised(director: OverworldDirector) -> void:
	await _click_button(director.panel.button_for(PATROL_ROAD))
	await _frames(LAYOUT_FRAMES)
	var found := director.world.encounter
	check(
		(
			str(found.get("type")) == "patrol"
			and director.world.at == RegionGen.HUB_ID
			and director.panel.shown_body() == _expected_body(director)
			and director.panel.button_for(OverworldDirector.FIGHT) != null
			and director.panel.button_for(OverworldDirector.TOLL) != null
			and director.panel.button_for(OverworldDirector.REST) == null
			and director.panel.button_for(PATROL_ROAD) == null
		),
		(
			"clicking the road to %s raises a patrol: the panel words it with Fight and the toll"
			% PATROL_ROAD
		)
	)


func _check_encounter_holds(game: SliceGame, director: OverworldDirector) -> void:
	await _tap(KEY_M)
	var hidden := not director.is_open()
	await _tap(KEY_M)
	await _tap(KEY_ESCAPE)
	var escaped := not director.is_open()
	await _tap(KEY_M)
	check(
		(
			hidden
			and escaped
			and director.is_open()
			and game.overworld_director() == director
			and str(director.world.encounter.get("type")) == "patrol"
			and director.panel.shown_body() == _expected_body(director)
		),
		"M and Escape hide the map and bring it back on the same standing encounter"
	)


## Fight closes the map on the street battle: the company's turn first, every fighter on the
## street, and M cannot close the map under the fight.
func _check_fight_starts(game: SliceGame, director: OverworldDirector) -> void:
	var mercs_before := game.stage().extra_mercs.size()
	var enemies: Array = director.world.encounter.get("enemies", [])
	await _click_button(director.panel.button_for(OverworldDirector.FIGHT))
	await _frames(LAYOUT_FRAMES)
	var started := director.in_fight() and not director.map.visible
	if not started:
		check(false, "Fight starts the street battle (it did not start)")
		return
	var battle := director.view.battle
	await _tap(KEY_M)
	var on_street := game.stage().extra_mercs.size() - mercs_before
	check(
		(
			battle.units.size() == enemies.size() + director.wounds.fielded.size()
			and battle.current().side == BattleUnit.COMPANY
			and on_street == battle.units.size()
			and director.in_fight()
			and director.is_open()
		),
		(
			"Fight closes the map on the street battle: %d fighters, the company first, M cannot close it"
			% battle.units.size()
		)
	)


## The supplies the company should hold after a patrol fight that started from `before`.
func _supplies_after(won: bool, before: Dictionary) -> int:
	var supplies: int = before.get("supplies", 0)
	var days_left: int = before.get("days_left", 0)
	var loot: int = _knobs("patrol").get("win_supplies", 0)
	var lost: int = _knobs("patrol").get("loss_supplies", 0)
	return supplies + loot - _per_day() * days_left if won else maxi(0, supplies - lost)


## The outcome line the panel should show after a patrol fight.
func _outcome_words(director: OverworldDirector, won: bool, before: Dictionary) -> String:
	var supplies: int = before.get("supplies", 0)
	var loot: int = _knobs("patrol").get("win_supplies", 0)
	var lost: int = _knobs("patrol").get("loss_supplies", 0)
	var site := OverworldMap.site_name(director.world.site(director.world.at))
	return Text.t(
		"world.encounter.outcome.%s" % ("won" if won else "lost"),
		{"supplies": loot if won else mini(supplies, lost), "site": site}
	)


## The fight to its end: fighters off the street, the result applied, the map back in words.
func _check_fight_returns(game: SliceGame, director: OverworldDirector, before: Dictionary) -> void:
	var won := await _finish_fight(director)
	await _frames(LAYOUT_FRAMES)
	await _click_button(director.panel.button_for(OverworldDirector.CONTINUE))
	await _frames(LAYOUT_FRAMES)
	var expected := _supplies_after(won, before)
	var mercs: int = before.get("mercs", -1)
	var place := str(before.get("to", "")) if won else RegionGen.HUB_ID
	var entry: Dictionary = director.world.log.back()
	var line := _outcome_words(director, won, before)
	check(
		(
			not director.in_fight()
			and director.map.visible
			and game.stage().extra_mercs.size() == mercs
			and director.world.encounter.is_empty()
			and str(entry.get("step")) == "encounter"
			and director.world.at == place
			and director.world.supplies == expected
			and director.panel.shown_body() == line
			and director.panel.button_for(OverworldDirector.SAVE) != null
		),
		(
			"the fight ended %s: fighters off the street, supplies %d, company at %s, result in words"
			% ["won" if won else "lost", director.world.supplies, place]
		)
	)


func _check_toll(director: OverworldDirector) -> void:
	var toll: int = _knobs("patrol").get("toll_supplies", 0)
	var supplies := director.world.supplies
	await _click_button(director.panel.button_for(PATROL_ROAD))
	await _frames(LAYOUT_FRAMES)
	var drain := _per_day()
	var days_left: int = director.world.encounter.get("days_left", 0)
	await _click_button(director.panel.button_for(OverworldDirector.TOLL))
	await _frames(LAYOUT_FRAMES)
	var entry: Dictionary = director.world.log.back()
	var days: int = director.world.site(PATROL_ROAD).days_to(RegionGen.HUB_ID)
	var spent := drain * days
	check(
		(
			not director.in_fight()
			and director.world.at == PATROL_ROAD
			and director.world.encounter.is_empty()
			and str(entry.get("outcome")) == "paid"
			and director.world.supplies == supplies - toll - spent
			and days_left >= 0
			and (
				director.panel.shown_body()
				== Text.t("world.encounter.outcome.paid", {"supplies": toll, "site": ""})
			)
		),
		"Pay the toll: no fight, %d supplies paid, the road goes on to %s" % [toll, PATROL_ROAD]
	)


## A saved world on the ambush seed, loaded by the game's own first M.
func _check_ambush() -> void:
	var rng := Rng.from_seed(AMBUSH_SEED)
	var world := WorldSim.new()
	world.start(_json(BALANCE), rng)
	var road := world.destinations()[0]
	_saves().save_game(world, rng)
	await _ambush_on(road)


func _ambush_on(road: String) -> void:
	var game := await _spawn()
	await _tap(KEY_M)
	var director := game.overworld_director()
	await _click_button(director.panel.button_for(road))
	await _frames(LAYOUT_FRAMES)
	var found := str(director.world.encounter.get("type"))
	var only_fight := (
		director.panel.button_for(OverworldDirector.FIGHT) != null
		and director.panel.button_for(OverworldDirector.TOLL) == null
	)
	await _click_button(director.panel.button_for(OverworldDirector.FIGHT))
	await _frames(LAYOUT_FRAMES)
	var enemy_first := (
		director.in_fight() and director.view.battle.current().side == BattleUnit.ENEMY
	)
	await _finish_fight(director)
	await _frames(LAYOUT_FRAMES)
	await _click_button(director.panel.button_for(OverworldDirector.CONTINUE))
	await _frames(LAYOUT_FRAMES)
	var entry: Dictionary = director.world.log.back()
	check(
		(
			found == "ambush"
			and only_fight
			and enemy_first
			and not director.in_fight()
			and director.map.visible
			and director.world.encounter.is_empty()
			and str(entry.get("step")) == "encounter"
		),
		(
			"the ambush on %s offers only Fight, the enemy strikes first, and the map returns (%s)"
			% [road, entry.get("outcome")]
		)
	)
	game.queue_free()
	await process_frame
	_clear_save()


## A save written with an encounter standing: the next session's first M reopens on it.
func _check_saved_encounter() -> void:
	var rng := Rng.from_seed(AMBUSH_SEED)
	var world := WorldSim.new()
	world.start(_json(BALANCE), rng)
	var lineups: Array = _json(ENCOUNTERS).get("encounters", [])
	world.set_lineups(lineups)
	world.travel_to(world.destinations()[0])
	_saves().save_game(world, rng)
	var game := await _spawn()
	await _tap(KEY_M)
	var director := game.overworld_director()
	await _frames(LAYOUT_FRAMES)
	check(
		(
			not world.encounter.is_empty()
			and str(director.world.encounter.get("type")) == str(world.encounter.get("type"))
			and director.panel.button_for(OverworldDirector.FIGHT) != null
			and director.panel.shown_body() == _expected_body(director)
		),
		"a save taken with a %s standing reopens on its panel" % world.encounter.get("type")
	)
	game.queue_free()
	await process_frame


## Plays the company's turns through the panel and waits out the enemy's until the battle is
## over. True when the company won.
func _finish_fight(director: OverworldDirector) -> bool:
	var view := director.view
	var battle := view.battle
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


func _per_day() -> int:
	var company: Dictionary = _json(BALANCE).get("company", {})
	return company.get("supplies_per_day", 0)


func _knobs(kind: String) -> Dictionary:
	var block: Dictionary = _json(BALANCE).get("encounters", {})
	var found: Variant = block.get(kind, {})
	return found if found is Dictionary else {}


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
