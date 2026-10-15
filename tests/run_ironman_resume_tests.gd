extends "res://tests/lib/runner.gd"
## Ironman resume suite (D-087: with Ironman On, quitting can't undo a death or a lost fight).
## A quit is the game freed and a fresh one spawned on the same save, as a closed game reopens.
## Mid-fight: the seeded fight is played until the first merc of the company is down, then quit;
## each of two reloads stands at the same point (units, hp, down, cells, facing, whose turn, the
## battle log's length, every Rng stream), and finishing the resumed fight ends in the same
## world, Rng, company and wounds as the uninterrupted fight. Every other decision is written
## the moment it is made: the toll paid, a rest day, wages paid, a hire and a prisoner's fate
## each survive a quit with Ironman On; with Ironman Off none of them writes anything.
## The commits the first pass left open (tests/ironman_resume/gap_checks.gd): meeting an
## encounter, a storylet attempt, the captain's appointment and a recorded action's types.
## Seeded by design: world seed 424270, a lone ambush or patrol three steps out, the battle played
## by BattleAi on both sides (InputKit), the start of the Ironman suite's own fight.
##   godot --headless --path . --script tests/run_ironman_resume_tests.gd

const InputKit := preload("res://tests/lib/input_kit.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const End := preload("res://tests/lib/end_kit.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const GapChecks := preload("res://tests/ironman_resume/gap_checks.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const WINDOW_SIZE := Vector2i(1920, 1080)
const SEED := 424270
const NEAR := 3
const TAP_LIMIT := 8
const SETTLE := 4
const REST_DAYS := 2
const RECRUIT := "recruit_1"


func suite_name() -> String:
	return "Ironman resume"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	var whole := await _uninterrupted()
	await _check_quit_after_a_fall(whole)
	await _check_toll(true)
	await _check_toll(false)
	await _check_rest_and_wages()
	await _check_hire()
	await _check_prisoner()
	var gaps := GapChecks.new()
	gaps.setup(self, Callable(self, "check"))
	await gaps.run()
	_clear_save()
	await process_frame


## The seeded fight played through with no quit: the battle at the first fall and the run's state
## after Continue.
func _uninterrupted() -> Dictionary:
	var game := await _fight_start("ambush")
	var director := game.overworld_director()
	await _play_until_a_fall(director)
	var at_fall := _battle_of(director)
	await _finish(director)
	var out := {"at_fall": at_fall, "state": _state_of(director)}
	await _quit(game)
	return out


func _check_quit_after_a_fall(whole: Dictionary) -> void:
	var game := await _fight_start("ambush")
	var director := game.overworld_director()
	var fallen := await _play_until_a_fall(director)
	var at_fall := _battle_of(director)
	await _quit(game)
	var reloads: Array[String] = []
	var finals: Array[String] = []
	for _reload: int in 2:
		var again := await _reopen()
		var back := again.overworld_director()
		reloads.append(_battle_of(back))
		var still_down := back.in_fight() and back.view.battle.unit(fallen).down
		reloads.append(str(still_down))
		if _reload == 1 and back.in_fight():
			await _finish(back)
			finals.append(_state_of(back))
		await _quit(again)
	var seen: Array[String] = []
	for entry: String in reloads:
		seen.append(entry.md5_text() if entry.length() > 5 else entry)
	print("RESUME %s fell; at the fall %s; reloads %s" % [fallen, at_fall.md5_text(), seen])
	check(
		(
			not fallen.is_empty()
			and at_fall == str(whole["at_fall"])
			and reloads == [at_fall, "true", at_fall, "true"]
		),
		(
			"Ironman On, quit after %s falls: each reload stands at the same turn, Rng and battle"
			% fallen
		)
	)
	check(
		finals == [str(whole["state"])] and not str(whole["state"]).is_empty(),
		"the resumed fight finished ends in the same world, Rng, company and wounds as unbroken"
	)


## Ironman On: the toll paid survives a quit. Off: paying writes nothing (the pre-fight save).
func _check_toll(ironman: bool) -> void:
	_clear_save()
	_save_world(ironman, "patrol")
	var before := _saved_text()
	var game := await _spawn()
	await InputKit.tap(self, KEY_M)
	var director := game.overworld_director()
	var supplies := director.world.supplies
	await _walk_into(director)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.TOLL))
	var paid := director.world.supplies
	await _quit(game)
	var again := await _reopen()
	var back := again.overworld_director()
	if ironman:
		check(
			paid < supplies and back.world.supplies == paid and back.world.encounter.is_empty(),
			"Ironman On, quit after paying the toll: supplies %d stay %d" % [supplies, paid]
		)
	else:
		check(
			paid < supplies and _saved_text() == before and back.world.supplies == supplies,
			"Ironman Off, quit after paying the toll: nothing was written, as before"
		)
	await _quit(again)


## Ironman On, at the hub: rest days on the map, then wages paid at the hub, each survive a quit.
func _check_rest_and_wages() -> void:
	_clear_save()
	_save_home()
	var game := await _spawn()
	await InputKit.tap(self, KEY_M)
	var director := game.overworld_director()
	var day := director.world.day
	for _day: int in REST_DAYS:
		await InputKit.click(self, director.panel.button_for(OverworldDirector.REST))
	await _quit(game)
	var again := await _reopen()
	var rested := again.overworld_director().world.day
	var owed := again.hub_director().economy().owed
	await InputKit.tap(self, KEY_M)
	await InputKit.tap(self, KEY_B)
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	var purse := again.hub_director().economy().purse
	await InputKit.click(self, again.hub_director().panel.button_for("pay", "wages"))
	var paid_purse := again.hub_director().economy().purse
	await _quit(again)
	var third := await _reopen()
	var economy := third.hub_director().economy()
	check(
		rested == day + REST_DAYS and owed > 0,
		(
			"Ironman On, quit after %d rests: the days (%d to %d) and wages owed stay"
			% [REST_DAYS, day, rested]
		)
	)
	check(
		owed > 0 and paid_purse < purse and economy.owed == 0 and economy.purse == paid_purse,
		"Ironman On, quit after paying wages at the hub: the purse and the debt stay paid"
	)
	await _quit(third)


## Ironman On, at the hub: a hire survives a quit.
func _check_hire() -> void:
	_clear_save()
	_save_home()
	var game := await _spawn()
	await InputKit.tap(self, KEY_B)
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	await InputKit.click(self, game.hub_director().panel.button_for("hire", RECRUIT))
	var hired := game.hub_director().company.member(RECRUIT) != null
	await _quit(game)
	var again := await _reopen()
	check(
		hired and again.hub_director().company.member(RECRUIT) != null,
		"Ironman On, quit after hiring at the hub: the hire stays on the roster"
	)
	await _quit(again)


## Ironman On: a surrendered bandit, decided at the hub, stays decided after a quit.
func _check_prisoner() -> void:
	_clear_save()
	_save_home()
	var game := await _spawn()
	var hub := game.hub_director()
	hub.world.result_hook.call("ambush", {"won": true, "prisoners": ["bandit_0"]})
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	var roster := hub.company.roster.size()
	await InputKit.click(self, hub.panel.button_for("prisoner", Economy.RECRUIT))
	var decided := hub.economy().prisoner.is_empty() and hub.company.roster.size() == roster + 1
	await _quit(game)
	var again := await _reopen()
	var back := again.hub_director()
	check(
		decided and back.economy().prisoner.is_empty() and back.company.roster.size() == roster + 1,
		"Ironman On, quit after the prisoner joins: the choice stays made"
	)
	await _quit(again)


## A fresh session on the saved world, the map opened, the fight begun (Ironman On).
func _fight_start(kind: String) -> SliceGame:
	_clear_save()
	_save_world(true, kind)
	var game := await _spawn()
	await InputKit.tap(self, KEY_M)
	var director := game.overworld_director()
	await _walk_into(director)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.FIGHT))
	return game


## Plays (company turns by real input, BattleAi's choice) until a company fighter is down; its id.
func _play_until_a_fall(director: OverworldDirector) -> String:
	var battle := director.view.battle
	var data := World.json(InputKit.BATTLE_DATA)
	var rules: Dictionary = data.get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	for _frame: int in InputKit.FIGHT_FRAMES:
		for fighter: BattleUnit in battle.units:
			if fighter.side == BattleUnit.COMPANY and fighter.down:
				return fighter.id
		if battle.is_over():
			return ""
		var actor := battle.current()
		if actor.side == BattleUnit.COMPANY:
			await InputKit._company_turn(self, director, BattleAi.choose(battle, actor, sight))
		else:
			await process_frame
	return ""


func _finish(director: OverworldDirector) -> void:
	await InputKit.finish_fight(self, director)
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.CONTINUE))
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)


## The battle on screen as text: each unit's id, side, cell, hp, facing and down, the turn order,
## whose turn, the battle log's length and every Rng stream; empty when no fight is on.
func _battle_of(director: OverworldDirector) -> String:
	if not director.in_fight():
		return ""
	var battle := director.view.battle
	var units: Array = []
	for fighter: BattleUnit in battle.units:
		units.append(
			[fighter.id, fighter.side, fighter.cell, fighter.hp, fighter.facing, fighter.down]
		)
	var order: Array = []
	for fighter: BattleUnit in battle.turn_order():
		order.append(fighter.id)
	var whole := [units, order, battle.current().id, battle.log.size(), director.rng.state()]
	return JSON.stringify(whole, "", true)


func _state_of(director: OverworldDirector) -> String:
	var whole := {
		"world": director.world.state(),
		"rng": director.rng.state(),
		"company": director.company.state(),
		"wounds": director.wounds.state(),
	}
	return JSON.stringify(whole, "", true)


## The saved world: the band near a lone party of `kind`, the starting six, Ironman as given.
func _save_world(ironman: bool, kind: String) -> void:
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	World.out_of_town(world, NEAR)
	World.lone_party(world, kind, NEAR)
	var made := Kit.wounds(rng, "", {}, Kit.led_by(End.LAST))
	_saves().ironman = ironman
	_saves().save_game(world, rng, made.company, made.state())


## The saved world: the band at the hub, no party on the map, the starting six, Ironman On.
func _save_home() -> void:
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	var made := Kit.wounds(rng, "", {}, Kit.led_by(End.LAST))
	_saves().ironman = true
	_saves().save_game(world, rng, made.company, made.state())


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
		await InputKit.tap(self, code)


## A fresh session on the save, the map opened (a fight on it resumes there).
func _reopen() -> SliceGame:
	var game := await _spawn()
	await InputKit.tap(self, KEY_M)
	await InputKit.frames(self, SETTLE)
	return game


## The game closed as a player closes it: nothing more is written.
func _quit(game: SliceGame) -> void:
	game.queue_free()
	await process_frame


func _saved_text() -> String:
	if not FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		return ""
	return FileAccess.get_file_as_string(SAVE_SYSTEM.SAVE_PATH)


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game
