extends "res://tests/lib/runner.gd"
## Ironman suite (director, 2026-10-15: "Ironman as an option", a toggle at campaign start, default
## On). Save: the optional "ironman" key round-trips through JSON; the v0, v1 and v2 fixtures load
## as Off; a v2 save with the key (fixtures/save/v2_ironman.json) loads as On. GUI (real clicks and
## letter keys at 1920x1080): a fresh campaign asks first, offers Ironman first, and nothing walks
## until it is answered; the answer is in the save and a fresh session does not ask again. Player
## effect (EFFECT ironman_quit): the same seeded fight with Ironman On and Off, quitting at the
## triage and again after Continue; On reloads with the dead dead, Off reloads the pre-fight
## save. Determinism: the same seed with Ironman On and Off ends in the same world, Rng positions
## and company (an autosave only reads state), and a game reloaded from the autosave continues
## exactly as the uninterrupted one.
## Seeded by design: world seed 4 and a lone ambush, played by BattleAi; the triage is cut so
## data's triage rolls on the injury stream, as in the wiring suite's fight; the fixtures are files.
##   godot --headless --path . --script tests/run_ironman_tests.gd

const InputKit := preload("res://tests/lib/input_kit.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const End := preload("res://tests/lib/end_kit.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const FIXTURES := "res://tests/fixtures/save/"
const WINDOW_SIZE := Vector2i(1920, 1080)
const SEED := 4
const NEAR := 3
const TAP_LIMIT := 8
const SETTLE := 4
const REST_DAYS := 3


func suite_name() -> String:
	return "Ironman"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_check_key_and_fixtures()
	await _check_choice_at_start()
	var on := await _fight(true)
	await _check_reload_continues(on)
	var off := await _fight(false)
	_check_quit_after_fight(on, off)
	_check_same_outcomes(on, off)
	_check_xp_saved(on, off)
	await _check_quit_mid_fight()
	var last: SliceGame = off["game"]
	last.queue_free()
	_clear_save()
	await process_frame


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _check_key_and_fixtures() -> void:
	var rng := Rng.from_seed(SEED)
	var world := World.world(SEED)
	var plain := SaveModel.to_dict(world, rng)
	var strict := SaveModel.to_dict(world, rng, null, {}, false, true)
	var through_json: Dictionary = JSON.parse_string(JSON.stringify(strict))
	var back := SaveModel.from_dict(through_json, World.data())
	var without_json: Dictionary = JSON.parse_string(JSON.stringify(plain))
	var without := SaveModel.from_dict(without_json, World.data())
	check(
		(
			back.ok
			and back.ironman
			and without.ok
			and not without.ironman
			and not plain.has("ironman")
		),
		"the ironman key is written only when on, comes back from JSON and reads Off when absent"
	)
	var old: Array[bool] = []
	for name: String in ["v0", "v1", "v2"]:
		old.append(SaveModel.from_dict(_json(FIXTURES + name + ".json"), World.data()).ironman)
	var on_fixture := SaveModel.from_dict(_json(FIXTURES + "v2_ironman.json"), World.data())
	check(
		old == [false, false, false] and on_fixture.ok and on_fixture.ironman,
		"the v0, v1 and v2 fixtures load as Off, the v2 fixture with the key as On: %s" % [old]
	)


func _check_choice_at_start() -> void:
	_clear_save()
	var game := await _spawn()
	await InputKit.tap(self, KEY_M)
	var director := game.overworld_director()
	await InputKit.frames(self, SETTLE)
	var first := director.panel.button_for(OverworldDirector.IRONMAN_ON)
	var second := director.panel.button_for(OverworldDirector.IRONMAN_OFF)
	var band := director.world.band
	await InputKit.tap(self, KEY_S)
	var asks := (
		first != null
		and second != null
		and first.get_index() < second.get_index()
		and director.panel.button_for(OverworldDirector.REST) == null
		and director.world.band == band
		and not director.ironman
	)
	check(asks, "a fresh campaign asks first, Ironman listed first, and the band does not walk")
	await InputKit.click(self, first)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.SAVE))
	check(
		director.ironman and _saved_text().contains('"ironman": true'),
		"clicking Ironman turns it on, the map's choices appear and Save writes the key"
	)
	game.queue_free()
	await process_frame
	var again := await _spawn()
	await InputKit.tap(self, KEY_M)
	var back := again.overworld_director()
	await InputKit.frames(self, SETTLE)
	check(
		back.ironman and back.panel.button_for(OverworldDirector.IRONMAN_ON) == null,
		"a fresh session continues the save as Ironman and does not ask again"
	)
	again.queue_free()
	await process_frame
	_clear_save()


## The saved world: the band near a lone ambush, the starting six; the save carries `ironman`.
func _save_world(ironman: bool, kind: String = "ambush") -> void:
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	World.out_of_town(world, NEAR)
	World.lone_party(world, kind, NEAR)
	var made := Kit.wounds(rng, "", {}, Kit.led_by(End.LAST))
	_saves().ironman = ironman
	_saves().save_game(world, rng, made.company, made.state())


## One fight from the saved world, the game left running. Returns what is on disk before it, as
## the fight starts, at the triage and after Continue, and the run's final state.
func _fight(ironman: bool) -> Dictionary:
	_clear_save()
	_save_world(ironman)
	var before := _saved_text()
	var game := await _spawn()
	await InputKit.tap(self, KEY_M)
	var director := game.overworld_director()
	await _walk_into(director)
	await InputKit.click(self, director.panel.button_for(OverworldDirector.FIGHT))
	var at_start := _saved_text()
	await InputKit.finish_fight(self, director)
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	var at_triage := _saved_text()
	await InputKit.click(self, director.panel.button_for(OverworldDirector.CONTINUE))
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	var died: Array[String] = []
	for id: String in _roster_of(before):
		if director.company.member(id) == null:
			died.append(id)
	return {
		"died": died,
		"wiped": director.wounds.ended(),
		"game": game,
		"before": before,
		"at_start": at_start,
		"at_triage": at_triage,
		"after": _saved_text(),
		"state": _state_of(director),
	}


func _state_of(director: OverworldDirector) -> String:
	var whole := {
		"world": director.world.state(),
		"rng": director.rng.state(),
		"company": director.company.state(),
		"wounds": director.wounds.state(),
	}
	return JSON.stringify(whole, "", true)


## The mercs a save on disk would field, by id.
func _roster_of(text: String) -> Array[String]:
	var saved: Dictionary = JSON.parse_string(text)
	var model := SaveModel.from_dict(saved, World.data(), CompanyDirector.defs())
	var ids: Array[String] = []
	if model.company != null:
		for merc: Merc in model.company.roster:
			ids.append(merc.id)
	return ids


func _check_quit_after_fight(on: Dictionary, off: Dictionary) -> void:
	var start := _roster_of(str(on["before"]))
	var died: Array[String] = on["died"]
	var wiped: bool = on["wiped"]
	check(
		not died.is_empty() and died.size() < start.size() and not wiped,
		"the seeded fight kills %s of %s and the campaign goes on" % [died, start]
	)
	var after_on := _roster_of(str(on["after"]))
	var triage_on := _roster_of(str(on["at_triage"]))
	var after_off := _roster_of(str(off["after"]))
	var dead_stay_dead := not died.is_empty()
	for id: String in died:
		dead_stay_dead = dead_stay_dead and not after_on.has(id) and not triage_on.has(id)
	print("EFFECT ironman_quit: On reloads with %s, Off reloads with %s" % [after_on, after_off])
	check(
		dead_stay_dead and after_on != after_off,
		"Ironman On, quit at the triage or after Continue: the dead stay dead"
	)
	check(
		str(off["at_start"]) == str(off["before"]) and str(off["after"]) == str(off["before"]),
		"Ironman Off, quit after the fight: the pre-fight save comes back, nothing written"
	)
	check(
		(
			after_off == start
			and str(on["at_start"]) != str(on["before"])
			and str(on["at_start"]).contains('"ironman": true')
		),
		"Ironman Off reloads everyone who was alive; On wrote a save as the fight started"
	)


## D-095: the fight's experience is committed with the triage, so with Ironman On a quit at the
## triage or after Continue reloads every survivor with it; Off reloads the pre-fight numbers.
func _check_xp_saved(on: Dictionary, off: Dictionary) -> void:
	var before := _xp_of(str(on["before"]))
	var at_triage := _xp_of(str(on["at_triage"]))
	var after := _xp_of(str(on["after"]))
	var survivors := 0
	var kept := true
	for id: String in after:
		survivors += 1
		kept = kept and Merc.whole(after[id]) > Merc.whole(before.get(id, 0))
		kept = kept and at_triage.get(id, -1) == after[id]
	check(
		survivors > 0 and kept,
		"Ironman On, quit at the triage or after Continue: every survivor keeps the fight's XP"
	)
	check(
		_xp_of(str(off["after"])) == _xp_of(str(off["before"])),
		"Ironman Off, quit after the fight: the pre-fight experience comes back"
	)


## {merc id: xp} a save on disk holds for the living.
func _xp_of(text: String) -> Dictionary:
	var saved: Dictionary = JSON.parse_string(text)
	var model := SaveModel.from_dict(saved, World.data(), CompanyDirector.defs())
	var held := {}
	if model.company != null:
		for merc: Merc in model.company.roster:
			held[merc.id] = merc.xp
	return held


func _check_same_outcomes(on: Dictionary, off: Dictionary) -> void:
	check(
		str(on["state"]) == str(off["state"]) and not str(on["state"]).is_empty(),
		"same seed, Ironman On and Off: the world, every Rng stream and the company end identical"
	)


## Ironman On, a patrol met (the toll on offer), Fight chosen, the game closed mid-fight: each
## reload goes straight into the very same battle (units, hp, cells, turn order, every Rng stream)
## and does not offer the toll again.
func _check_quit_mid_fight() -> void:
	_clear_save()
	_save_world(true, "patrol")
	var first := await _spawn()
	await InputKit.tap(self, KEY_M)
	var director := first.overworld_director()
	await _walk_into(director)
	var toll_offered := director.panel.button_for(OverworldDirector.TOLL) != null
	await InputKit.click(self, director.panel.button_for(OverworldDirector.FIGHT))
	var started := _battle_of(director)
	first.queue_free()
	await process_frame
	var again: Array[String] = []
	for _quit: int in 2:
		var game := await _spawn()
		await InputKit.tap(self, KEY_M)
		await InputKit.frames(self, SETTLE)
		var reloaded := game.overworld_director()
		again.append(_battle_of(reloaded))
		var toll_back := reloaded.panel.button_for(OverworldDirector.TOLL) != null
		again.append(str(toll_back))
		game.queue_free()
		await process_frame
	check(
		toll_offered and not started.is_empty() and again == [started, "false", started, "false"],
		"Ironman On, quit mid-fight: each reload is the same battle and the toll is not offered"
	)
	_clear_save()


## The battle on screen as text: each unit's id, side, cell, hp and facing, the turn order and the
## Rng; empty when no fight is on.
func _battle_of(director: OverworldDirector) -> String:
	if not director.in_fight():
		return ""
	var battle := director.view.battle
	var units: Array = []
	for fighter: BattleUnit in battle.units:
		units.append([fighter.id, fighter.side, fighter.cell, fighter.hp, fighter.facing])
	var order: Array = []
	for fighter: BattleUnit in battle.turn_order():
		order.append(fighter.id)
	return JSON.stringify([units, order, director.rng.state()])


## Game A goes on from the autosave's moment; game B is a fresh session reading that file. Both
## rest the same days and match.
func _check_reload_continues(on: Dictionary) -> void:
	var game: SliceGame = on["game"]
	var uninterrupted: OverworldDirector = game.overworld_director()
	var reloaded_game := await _spawn()
	await InputKit.tap(self, KEY_M)
	var reloaded := reloaded_game.overworld_director()
	await InputKit.frames(self, SETTLE)
	var same_start := _state_of(uninterrupted) == _state_of(reloaded)
	for _day: int in REST_DAYS:
		uninterrupted.world.rest()
		reloaded.world.rest()
	check(
		same_start and _state_of(uninterrupted) == _state_of(reloaded),
		(
			"a game reloaded from the autosave starts where the first stood and %d rests match"
			% REST_DAYS
		)
	)
	game.queue_free()
	reloaded_game.queue_free()
	await process_frame


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
