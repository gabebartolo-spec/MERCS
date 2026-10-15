extends RefCounted
## The ironman_resume suite's gap checks, run by tests/run_ironman_resume_tests.gd (D-087: a quit
## can't undo a committed choice): walking into an encounter, a storylet's attempt and the
## captain's appointment each survive a quit with Ironman On, and a fight's recorded action keeps
## its number, flag and fraction through the save's JSON. Seeded by design: world seed 424270,
## the ambush met three steps out.

const InputKit := preload("res://tests/lib/input_kit.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const End := preload("res://tests/lib/end_kit.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SEED := 4
const NEAR := 3
const TAP_LIMIT := 8
const SETTLE := 4

var _tree: SceneTree = null
var _check: Callable


func setup(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check


func run() -> void:
	await meeting()
	await storylet()
	await offer()
	await stale_offer()
	await captain()
	await captain_unmapped()
	action_types()


## Ironman On: walking into an encounter is saved, so a quit can't put the band back before it.
func meeting() -> void:
	_clear_save()
	_save_world(true, "ambush")
	var game := await _spawn()
	await InputKit.tap(_tree, KEY_M)
	var director := game.overworld_director()
	var start := director.world.band
	await _walk_into(director)
	var met := not director.world.encounter.is_empty() and director.world.band != start
	var stood := director.world.band
	await _quit(game)
	var again := await _reopen()
	var back := again.overworld_director().world
	_check.call(
		met and not back.encounter.is_empty() and back.band == stood,
		"Ironman On, quit after walking into an ambush: the meeting stands"
	)
	await _quit(again)


## Ironman On: a storylet's attempt (its roll and effects) is saved, so a quit can't reroll it.
func storylet() -> void:
	_clear_save()
	_save_home()
	var game := await _spawn()
	var story := game.get_node("StoryDirector") as StoryDirector
	var ids: Array[String] = []
	for merc: Merc in game.company_director().company.roster:
		ids.append(merc.id)
	story.memory.on_death("fallen_comrade", ids, 2, Memory.KEY_COMRADE_DIED)
	await InputKit.tap(_tree, KEY_M)
	var director := game.overworld_director()
	await InputKit.click(_tree, director.panel.button_for(OverworldDirector.REST))
	await InputKit.frames(_tree, InputKit.LAYOUT_FRAMES)
	var cast: Dictionary = story.offer.get("cast", {})
	var mourner := game.company_director().company.member(str(cast.get("mourner", "")))
	var attempt := story.panel.button_for("attempt:mourner")
	if mourner == null or attempt == null:
		_check.call(false, "resting with a comrade's death in memory offered the storylet")
		await _quit(game)
		return
	await InputKit.click(_tree, attempt)
	var rolled: Dictionary = story.result
	var xp := mourner.xp
	var rng_after := director.rng.state()
	await _quit(game)
	var again := await _reopen()
	var back := again.company_director().company.member(mourner.id)
	_check.call(
		not rolled.is_empty() and back != null and back.xp == xp,
		"Ironman On, quit after a storylet attempt: its xp (%d) stays" % xp
	)
	_check.call(
		again.overworld_director().rng.state() == rng_after,
		"and the Rng stands where the roll left it, so it can't be rerolled"
	)
	await _quit(again)


## Ironman On: a storylet offered (its cast drawn from the Rng) is saved, so a quit can't have the
## next rest draw another cast: the reload stands on the same offer and the same Rng.
func offer() -> void:
	_clear_save()
	_save_home()
	var game := await _spawn()
	var story := game.get_node("StoryDirector") as StoryDirector
	var ids: Array[String] = []
	for merc: Merc in game.company_director().company.roster:
		ids.append(merc.id)
	story.memory.on_death("fallen_comrade", ids, 2, Memory.KEY_COMRADE_DIED)
	await InputKit.tap(_tree, KEY_M)
	var director := game.overworld_director()
	await InputKit.click(_tree, director.panel.button_for(OverworldDirector.REST))
	await InputKit.frames(_tree, InputKit.LAYOUT_FRAMES)
	var shown := JSON.stringify(story.offer.get("cast", {}), "", true)
	var rng_after := director.rng.state()
	var up := story.is_open() and not story.offer.is_empty()
	var fresh := _labels(story)
	await _quit(game)
	var again := await _reopen()
	var back := again.get_node("StoryDirector") as StoryDirector
	_check.call(
		up and back.is_open() and JSON.stringify(back.offer.get("cast", {}), "", true) == shown,
		"Ironman On, quit with a storylet offered: the reload shows the same offer and cast"
	)
	_check.call(
		again.overworld_director().rng.state() == rng_after,
		"and the Rng stands where the cast pick left it"
	)
	var reloaded := _labels(back)
	_check.call(
		not fresh.is_empty() and reloaded == fresh,
		(
			"the reloaded offer's choice labels read exactly like the fresh ones (%s | %s)"
			% [fresh, reloaded]
		)
	)
	await _quit(again)


## Ironman On: a save holding an offer for a storylet that no longer exists is dropped, not
## resumed: the run loads with the map usable and no offer up.
func stale_offer() -> void:
	_clear_save()
	_save_home()
	var game := await _spawn()
	var story := game.get_node("StoryDirector") as StoryDirector
	var ids: Array[String] = []
	for merc: Merc in game.company_director().company.roster:
		ids.append(merc.id)
	story.memory.on_death("fallen_comrade", ids, 2, Memory.KEY_COMRADE_DIED)
	await InputKit.tap(_tree, KEY_M)
	var director := game.overworld_director()
	await InputKit.click(_tree, director.panel.button_for(OverworldDirector.REST))
	await InputKit.frames(_tree, InputKit.LAYOUT_FRAMES)
	story.offer["id"] = "st_removed"
	director.autosave()
	await _quit(game)
	var again := await _reopen()
	var back := again.get_node("StoryDirector") as StoryDirector
	_check.call(
		not back.is_open() and back.offer.is_empty() and again.overworld_director().panel.visible,
		"a saved offer for a storylet that no longer exists is dropped: no offer, the map panel up"
	)
	await _quit(again)


func _labels(story: StoryDirector) -> Array[String]:
	var out: Array[String] = []
	var shown := story.panel
	var listed: Array = story.offer.get("attempts", [])
	for raw: Variant in listed:
		var option: Dictionary = raw if raw is Dictionary else {}
		var role := str(option.get("role", ""))
		var button := shown.button_for(StoryDirector.ATTEMPT_PREFIX + role)
		out.append(button.text if button != null else "(none)")
	return out


## Ironman On: appointing the captain survives a quit.
func captain() -> void:
	_clear_save()
	_save_home()
	var game := await _spawn()
	await InputKit.tap(_tree, KEY_M)
	await InputKit.tap(_tree, KEY_M)
	await InputKit.tap(_tree, KEY_C)
	var screen := game.company_director()
	var other := ""
	for merc: Merc in screen.company.roster:
		if merc.id != screen.company.captain_id:
			other = merc.id
			break
	await InputKit.click(_tree, screen.panel.row_for(other))
	await InputKit.click(_tree, screen.panel.appoint_button())
	var named := screen.company.captain_id == other
	await _quit(game)
	var again := await _reopen()
	_check.call(
		named and again.company_director().company.captain_id == other,
		"Ironman On, quit after appointing %s captain: the office stays" % other
	)
	await _quit(again)


## Ironman On: the captain appointed before the map was ever opened is saved too.
func captain_unmapped() -> void:
	_clear_save()
	_save_home()
	var game := await _spawn()
	await InputKit.tap(_tree, KEY_C)
	var screen := game.company_director()
	var other := ""
	for merc: Merc in screen.company.roster:
		if merc.id != screen.company.captain_id:
			other = merc.id
			break
	await InputKit.click(_tree, screen.panel.row_for(other))
	await InputKit.click(_tree, screen.panel.appoint_button())
	var named := screen.company.captain_id == other
	await _quit(game)
	var again := await _reopen()
	_check.call(
		named and again.company_director().company.captain_id == other,
		"Ironman On, quit after appointing %s captain with the map never opened: it stays" % other
	)
	await _quit(again)


## A fight's recorded action keeps its number and its flag through the save's JSON.
func action_types() -> void:
	var record := FightRecord.make({}, [])
	record.record(
		{
			"type": "move",
			"to": Vector2i(2, 3),
			"steps": 4,
			"bold": true,
			"ratio": 0.5,
			"near": 2.000001
		}
	)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(record.saved()))
	var back := FightRecord.read(parsed)
	var kept := back.size() == 1
	var action: Dictionary = back[0] if kept else {}
	var steps: Variant = action.get("steps")
	var bold: Variant = action.get("bold")
	var ratio: Variant = action.get("ratio")
	var near: Variant = action.get("near")
	_check.call(
		kept and str(action.get("to")) == "(2, 3)" and str(action.get("type")) == "move",
		"a recorded action keeps its text and its cell through the save"
	)
	_check.call(
		typeof(steps) == TYPE_INT and str(steps) == "4", "a recorded whole number comes back an int"
	)
	_check.call(
		typeof(bold) == TYPE_BOOL and str(bold) == "true", "a recorded flag comes back a bool"
	)
	_check.call(
		typeof(ratio) == TYPE_FLOAT and str(ratio) == "0.5",
		"a recorded fraction comes back a float"
	)
	_check.call(
		typeof(near) == TYPE_FLOAT and str(near) == "2.000001",
		"a recorded near-whole fraction (2.000001) is not rounded to an int"
	)


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
		await InputKit.tap(_tree, code)


func _reopen() -> SliceGame:
	var game := await _spawn()
	await InputKit.tap(_tree, KEY_M)
	await InputKit.frames(_tree, SETTLE)
	return game


func _quit(game: SliceGame) -> void:
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
