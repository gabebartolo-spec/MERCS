extends "res://tests/lib/runner.gd"
## Road suite (Phase 2, encounters on the walkable overworld, on screen). Real input events
## reach the game through Input.parse_input_event: M and Escape taps, walking-key taps, real
## mouse clicks on the panel's buttons, with the root at 1920 x 1080. Each case saves a world
## on the balance seed with the band three tiles out of the hub's gate and one party placed
## near it, and the game's own first M loads it. Walking into a patrol raises it: the panel
## words it with Fight and the toll, the band is stopped (keys, M and Escape change
## nothing); Fight hides the map and starts the street battle (the company acts first), and
## when it ends the fighters leave the street, the result is applied and the map returns with
## the outcome in words. Paying the toll skips the fight and the patrol leaves the map. An
## ambush offers only Fight and the enemy strikes first. A party out of sight does not come
## for a band walking away. A save taken with an encounter standing reopens on its panel. In
## the fight BattleAi picks the company's moves; attacks and waits are real clicks.
## Seeded by design: the balance seed (data/balance/world.json).
##   godot --headless --path . --script tests/run_road_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const World := preload("res://tests/lib/world_fixture.gd")
const InputKit := preload("res://tests/lib/input_kit.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
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
	await _t("_test_patrol_met", [director])
	await _t("_test_encounter_holds", [director])
	var before := {
		"supplies": director.world.supplies,
		"band": director.world.band,
		"mercs": game.stage().extra_mercs.size(),
	}
	await _t("_test_fight_starts", [game, director])
	await _t("_test_fight_returns", [game, director, before])
	await _close(game)
	var tolled := await _game_with("patrol", NEAR)
	await _t("_test_toll", [tolled.overworld_director()])
	await _close(tolled)
	var ambushed := await _game_with("ambush", NEAR)
	await _t("_test_ambush", [ambushed.overworld_director()])
	await _close(ambushed)
	var avoided := await _game_with("ambush", FAR)
	await _t("_test_avoid", [avoided.overworld_director()])
	await _close(avoided)
	await _t("_test_saved_encounter")
	_clear_save()


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


## Saves a world on the balance seed, the band OUT tiles south of the hub's gate and one party
## of `kind` `gap` tiles from it, then opens the game and its map (the first M loads it).
func _game_with(kind: String, gap: int) -> SliceGame:
	var data := World.data()
	var world_block: Dictionary = data.get("world", {})
	var balance_seed: int = world_block.get("seed", 0)
	var rng := Rng.from_seed(balance_seed)
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
	await _tap(KEY_M)
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
		await _tap(_key_for(step))
		taps += 1
	await _frames(LAYOUT_FRAMES)
	return taps


## What the encounter panel should say for the standing encounter.
func _expected_body(director: OverworldDirector) -> String:
	var found := director.world.encounter
	var params := {"day": director.world.day, "toll": director.world.toll_cost()}
	var body := Text.t("world.encounter.%s.body" % found.get("type"), params)
	return body + "\n" + OverworldWords.deploy_lines(director.company)


func _test_patrol_met(director: OverworldDirector) -> void:
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
			and director.panel.button_for(OverworldDirector.FIGHT_SIT_OUT) != null
			and director.panel.button_for(OverworldDirector.REST) == null
		),
		(
			"%d taps walk the band into the patrol: panel words Fight, Fight sitting out, the toll"
			% taps
		)
	)


func _test_encounter_holds(director: OverworldDirector) -> void:
	var band := director.world.band
	for code: Key in [KEY_S, KEY_A, KEY_M, KEY_ESCAPE]:
		await _tap(code)
	check(
		(
			director.is_open()
			and director.world.band == band
			and str(director.world.encounter.get("type")) == "patrol"
			and director.panel.shown_body() == _expected_body(director)
		),
		"while the patrol stands, walking keys, M and Escape change nothing"
	)


## Fight hides the map on the street battle: the company's turn first, every fighter on the
## street, and M cannot close the map under the fight.
func _test_fight_starts(game: SliceGame, director: OverworldDirector) -> void:
	var mercs_before := game.stage().extra_mercs.size()
	var enemies: Array = director.world.encounter.get("enemies", [])
	await _click_button(director.panel.button_for(OverworldDirector.FIGHT))
	await _frames(LAYOUT_FRAMES)
	if not (director.in_fight() and not director.map.visible):
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
			"Fight hides the map on the street battle: %d fighters, the company first, M cannot close it"
			% battle.units.size()
		)
	)


## The fight to its end: fighters off the street, the result applied, the map back in words.
func _test_fight_returns(game: SliceGame, director: OverworldDirector, before: Dictionary) -> void:
	var won := await InputKit.finish_fight(self, director)
	await _frames(LAYOUT_FRAMES)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.CONTINUE))
	await _frames(LAYOUT_FRAMES)
	var world := director.world
	var expected := _after_fight(world, won, before)
	var mercs: int = before.get("mercs", -1)
	var place: Vector2i = expected.get("band")
	var supplies: int = expected.get("supplies")
	check(
		(
			not director.in_fight()
			and director.map.visible
			and game.stage().extra_mercs.size() == mercs
			and world.encounter.is_empty()
			and world.band == place
			and world.supplies == supplies
			and director.panel.shown_body() == str(expected.get("line"))
			and director.panel.button_for(OverworldDirector.SAVE) != null
		),
		(
			"the fight ended %s: fighters off the street, supplies %d, the band at %s, result in words"
			% ["won" if won else "lost", world.supplies, place]
		)
	)


## What a patrol fight that started from `before` should leave: {"supplies", "band", "line"}.
func _after_fight(world: WorldSim, won: bool, before: Dictionary) -> Dictionary:
	var supplies: int = before.get("supplies", 0)
	var loot: int = _knobs("patrol").get("win_supplies", 0)
	var lost: int = _knobs("patrol").get("loss_supplies", 0)
	var band: Vector2i = before.get("band", Vector2i.ZERO)
	var site := OverworldMap.site_name(world.site(world.haven))
	return {
		"supplies": supplies + loot if won else maxi(0, supplies - lost),
		"band": band if won else world.region.entrance(RegionGen.HUB_ID),
		"line":
		Text.t(
			"world.encounter.outcome.%s" % ("won" if won else "lost"),
			{"supplies": loot if won else mini(supplies, lost), "site": site}
		),
	}


func _test_toll(director: OverworldDirector) -> void:
	await _walk_into(director)
	var world := director.world
	var party := world.party(str(world.encounter.get("party", "")))
	var toll: int = _knobs("patrol").get("toll_supplies", 0)
	var supplies := world.supplies
	await _click_button(director.panel.button_for(OverworldDirector.TOLL))
	await _frames(LAYOUT_FRAMES)
	var paid_line := director.panel.shown_body()
	var band := world.band
	for step: Vector2i in KEY_BY_STEP:
		if world.region.passable(world.band + step):
			await _tap(_key_for(step))
			break
	check(
		(
			party != null
			and not director.in_fight()
			and world.encounter.is_empty()
			and world.supplies == supplies - toll
			and not director.map.party_marker(party.id).visible
			and world.band != band
			and paid_line == Text.t("world.encounter.outcome.paid", {"supplies": toll, "site": ""})
		),
		(
			"Pay the toll: no fight, %d supplies paid, the patrol leaves the map, the band walks on"
			% toll
		)
	)


func _test_ambush(director: OverworldDirector) -> void:
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
		await InputKit.finish_fight(self, director)
	await _frames(LAYOUT_FRAMES)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.CONTINUE))
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
			"walking into bandits: only Fight, the enemy strikes first, and the map returns (%s)"
			% entry.get("outcome")
		)
	)


## Bandits beyond their sight do not come for a band walking away from them.
func _test_avoid(director: OverworldDirector) -> void:
	var world := director.world
	var party := world.parties[0]
	var away := world.band - party.tile
	var step := Vector2i(0, signi(away.y)) if away.y != 0 else Vector2i(signi(away.x), 0)
	var walked := 0
	for _tap_index: int in NEAR:
		var band := world.band
		await _tap(_key_for(step))
		walked += 1 if world.band != band else 0
	var sight: int = _knobs("ambush", "parties").get("sight_tiles", 0)
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


## A save written with an encounter standing: the next session's first M reopens on it.
func _test_saved_encounter() -> void:
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
	await _tap(KEY_M)
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


## One type's block of a data/balance/world.json section ("encounters" or "parties").
func _knobs(kind: String, section: String = "encounters") -> Dictionary:
	var block: Dictionary = World.data().get(section, {})
	var found: Variant = block.get(kind, {})
	return found if found is Dictionary else {}


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _key_for(step: Vector2i) -> Key:
	var code: Key = KEY_BY_STEP.get(step, KEY_NONE)
	return code


func _frames(count: int) -> void:
	await InputKit.frames(self, count)


func _click_button(button: Button) -> void:
	await InputKit.click(self, button)


func _tap(code: Key) -> void:
	await InputKit.tap(self, code)
