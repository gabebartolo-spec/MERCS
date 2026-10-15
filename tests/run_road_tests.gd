extends "res://tests/lib/runner.gd"
## Road suite (Phase 2, encounters on the walkable overworld, on screen). Real input events
## reach the game through Input.parse_input_event: F2 and Escape taps, walking-key taps, real
## mouse clicks on the panel's buttons, with the root at 1920 x 1080. Each case saves a world
## on the balance seed with the band three tiles out of the hub's gate and one party placed
## near it, and the game's own first F2 loads it. Walking into a patrol raises it: the panel
## words it with Fight and the toll, the band is stopped (keys, F2 and Escape change
## nothing); Fight hides the map and starts the street battle (the company acts first), and
## when it ends the fighters leave the street, the result is applied and the map returns with
## the outcome in words. Paying the toll skips the fight and the patrol leaves the map. An
## ambush offers only Fight and the enemy strikes first. A party out of sight does not come
## for a band walking away. A save taken with an encounter standing reopens on its panel. The
## company's moves in the fight use the sim's BattleAi for the choice; attacks and waits are
## real clicks, a move calls click_cell().
## Seeded by design: the balance seed (data/balance/world.json).
##   godot --headless --path . --script tests/run_road_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const World := preload("res://tests/lib/world_fixture.gd")
const BATTLE_DATA := "res://data/balance/battle.json"
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
const FIGHT_FRAMES := 6000
const OUT := 3
const NEAR := 3
## Beyond every party type's sight (data/balance/world.json "parties").
const FAR := 7
const TAP_LIMIT := 8
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const KEY_BY_STEP := {
	Vector2i(0, -1): KEY_W, Vector2i(0, 1): KEY_S, Vector2i(-1, 0): KEY_A, Vector2i(1, 0): KEY_D
}


func suite_name() -> String:
	return "Road"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_clear_save()
	var game := await _game_with("patrol", NEAR)
	var director := game.overworld_director()
	await _check_patrol_met(director)
	await _check_encounter_holds(director)
	var before := {
		"supplies": director.world.supplies,
		"band": director.world.band,
		"mercs": game.stage().extra_mercs.size(),
	}
	await _check_fight_starts(game, director)
	await _check_fight_returns(game, director, before)
	await _close(game)
	var tolled := await _game_with("patrol", NEAR)
	await _check_toll(tolled.overworld_director())
	await _close(tolled)
	var ambushed := await _game_with("ambush", NEAR)
	await _check_ambush(ambushed.overworld_director())
	await _close(ambushed)
	var avoided := await _game_with("ambush", FAR)
	await _check_avoid(avoided.overworld_director())
	await _close(avoided)
	await _check_saved_encounter()
	_clear_save()


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


## Saves a world on the balance seed, the band OUT tiles south of the hub's gate and one party
## of `kind` `gap` tiles from it, then opens the game and its map (the first F2 loads it).
func _game_with(kind: String, gap: int) -> SliceGame:
	var data := World.data()
	var world_block: Dictionary = data.get("world", {})
	var rng := Rng.from_seed(world_block.get("seed", 0))
	var world := WorldSim.new()
	world.start(data, rng)
	world.parties.clear()
	World.out_of_town(world, OUT)
	World.lone_party(world, kind, gap)
	_saves().save_game(world, rng)
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	await _tap(KEY_F2)
	await _frames(LAYOUT_FRAMES)
	return game


func _close(game: SliceGame) -> void:
	game.queue_free()
	await process_frame
	_clear_save()


## Taps the walking key toward the lone party until its encounter stands. The taps.
func _walk_into(director: OverworldDirector) -> int:
	var world := director.world
	var taps := 0
	while world.encounter.is_empty() and taps < TAP_LIMIT and not world.parties.is_empty():
		var to := world.parties[0].tile - world.band
		var step := Vector2i(signi(to.x), 0) if to.x != 0 else Vector2i(0, signi(to.y))
		await _tap(KEY_BY_STEP[step])
		taps += 1
	await _frames(LAYOUT_FRAMES)
	return taps


## What the encounter panel should say for the standing encounter.
func _expected_body(director: OverworldDirector) -> String:
	var found := director.world.encounter
	var params := {"day": director.world.day, "toll": director.world.toll_cost()}
	return Text.t("world.encounter.%s.body" % found.get("type"), params)


func _check_patrol_met(director: OverworldDirector) -> void:
	var taps := await _walk_into(director)
	var world := director.world
	var party := world.party(str(world.encounter.get("party", "")))
	var token := director.map.party_marker(party.id) if party != null else null
	check(
		(
			str(world.encounter.get("type")) == "patrol"
			and token != null
			and token.visible
			and TileRegion.gap(party.tile, world.band) <= 1
			and director.panel.shown_body() == _expected_body(director)
			and director.panel.button_for(OverworldDirector.FIGHT) != null
			and director.panel.button_for(OverworldDirector.TOLL) != null
			and director.panel.button_for(OverworldDirector.REST) == null
		),
		"%d taps walk the band into the patrol: the panel words it with Fight and the toll" % taps
	)


func _check_encounter_holds(director: OverworldDirector) -> void:
	var band := director.world.band
	for code: Key in [KEY_S, KEY_A, KEY_F2, KEY_ESCAPE]:
		await _tap(code)
	check(
		(
			director.is_open()
			and director.world.band == band
			and str(director.world.encounter.get("type")) == "patrol"
			and director.panel.shown_body() == _expected_body(director)
		),
		"while the patrol stands, walking keys, F2 and Escape change nothing"
	)


## Fight hides the map on the street battle: the company's turn first, every fighter on the
## street, and F2 cannot close the map under the fight.
func _check_fight_starts(game: SliceGame, director: OverworldDirector) -> void:
	var mercs_before := game.stage().extra_mercs.size()
	var enemies: Array = director.world.encounter.get("enemies", [])
	await _click_button(director.panel.button_for(OverworldDirector.FIGHT))
	await _frames(LAYOUT_FRAMES)
	if not (director.in_fight() and not director.map.visible):
		check(false, "Fight starts the street battle (it did not start)")
		return
	var battle := director.view.battle
	await _tap(KEY_F2)
	var on_street := game.stage().extra_mercs.size() - mercs_before
	check(
		(
			battle.units.size() == enemies.size() + 2
			and battle.current().side == BattleUnit.COMPANY
			and on_street == battle.units.size()
			and director.in_fight()
			and director.is_open()
		),
		(
			"Fight hides the map on the street battle: %d fighters, the company first, F2 cannot close it"
			% battle.units.size()
		)
	)


## The fight to its end: fighters off the street, the result applied, the map back in words.
func _check_fight_returns(game: SliceGame, director: OverworldDirector, before: Dictionary) -> void:
	var won := await _finish_fight(director)
	await _frames(LAYOUT_FRAMES)
	var world := director.world
	var supplies: int = before.get("supplies", 0)
	var loot: int = _knobs("patrol").get("win_supplies", 0)
	var lost: int = _knobs("patrol").get("loss_supplies", 0)
	var expected := supplies + loot if won else maxi(0, supplies - lost)
	var band: Vector2i = before.get("band", Vector2i.ZERO)
	var place := band if won else world.region.entrance(RegionGen.HUB_ID)
	var site := OverworldMap.site_name(world.site(world.haven))
	var line := Text.t(
		"world.encounter.outcome.%s" % ("won" if won else "lost"),
		{"supplies": loot if won else mini(supplies, lost), "site": site}
	)
	check(
		(
			not director.in_fight()
			and director.map.visible
			and game.stage().extra_mercs.size() == int(before.get("mercs", -1))
			and world.encounter.is_empty()
			and world.band == place
			and world.supplies == expected
			and director.panel.shown_body() == line
			and director.panel.button_for(OverworldDirector.SAVE) != null
		),
		(
			"the fight ended %s: fighters off the street, supplies %d, the band at %s, result in words"
			% ["won" if won else "lost", world.supplies, place]
		)
	)


func _check_toll(director: OverworldDirector) -> void:
	await _walk_into(director)
	var world := director.world
	var party := world.party(str(world.encounter.get("party", "")))
	var toll: int = _knobs("patrol").get("toll_supplies", 0)
	var supplies := world.supplies
	await _click_button(director.panel.button_for(OverworldDirector.TOLL))
	await _frames(LAYOUT_FRAMES)
	var band := world.band
	await _tap(KEY_S)
	check(
		(
			party != null
			and not director.in_fight()
			and world.encounter.is_empty()
			and world.supplies == supplies - toll
			and not director.map.party_marker(party.id).visible
			and world.band != band
			and (
				director.panel.shown_body()
				== Text.t("world.encounter.outcome.paid", {"supplies": toll, "site": ""})
			)
		),
		"Pay the toll: no fight, %d supplies paid, the patrol leaves the map, the band walks on" % toll
	)


func _check_ambush(director: OverworldDirector) -> void:
	await _walk_into(director)
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
	if director.in_fight():
		await _finish_fight(director)
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
		"walking into bandits: only Fight, the enemy strikes first, and the map returns (%s)" % entry.get("outcome")
	)


## Bandits beyond their sight do not come for a band walking away from them.
func _check_avoid(director: OverworldDirector) -> void:
	var world := director.world
	var party := world.parties[0]
	var away := world.band - party.tile
	var step := Vector2i(0, signi(away.y)) if away.y != 0 else Vector2i(signi(away.x), 0)
	var walked := 0
	for _tap_index: int in NEAR:
		var band := world.band
		await _tap(KEY_BY_STEP[step])
		walked += 1 if world.band != band else 0
	var sight: int = _party_knobs("ambush").get("sight_tiles", 0)
	check(
		(
			walked == NEAR
			and world.encounter.is_empty()
			and not party.chasing
			and TileRegion.gap(party.tile, world.band) > sight
		),
		(
			"bandits %d tiles off (sight %d) do not come for a band walking away: still %d off"
			% [FAR, sight, TileRegion.gap(party.tile, world.band)]
		)
	)


## A save written with an encounter standing: the next session's first F2 reopens on it.
func _check_saved_encounter() -> void:
	var met := await _game_with("ambush", NEAR)
	var director := met.overworld_director()
	await _walk_into(director)
	var standing := str(director.world.encounter.get("type"))
	_saves().save_game(director.world, director.rng)
	met.queue_free()
	await process_frame
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var fresh: SliceGame = packed.instantiate() as SliceGame
	root.add_child(fresh)
	await process_frame
	await _tap(KEY_F2)
	var reopened := fresh.overworld_director()
	await _frames(LAYOUT_FRAMES)
	check(
		(
			standing == "ambush"
			and str(reopened.world.encounter.get("type")) == "ambush"
			and reopened.panel.button_for(OverworldDirector.FIGHT) != null
			and reopened.panel.shown_body() == _expected_body(reopened)
		),
		"a save taken with an ambush standing reopens on its panel"
	)
	fresh.queue_free()
	await process_frame


## Plays the company's turns through the panel and waits out the enemy's until the battle is
## over. True when the company won.
func _finish_fight(director: OverworldDirector) -> bool:
	var battle := director.view.battle
	var rules: Dictionary = World.json(BATTLE_DATA).get("rules", {})
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


func _knobs(kind: String) -> Dictionary:
	var block: Dictionary = World.data().get("encounters", {})
	var found: Variant = block.get(kind, {})
	return found if found is Dictionary else {}


func _party_knobs(kind: String) -> Dictionary:
	var block: Dictionary = World.data().get("parties", {})
	var found: Variant = block.get(kind, {})
	return found if found is Dictionary else {}


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
