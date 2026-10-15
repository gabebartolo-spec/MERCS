extends RefCounted
## The ironman_resume suite's runtime save-order guard, run by tests/run_ironman_resume_tests.gd:
## no state change without a following save (CampaignSaves "Save order"; tests/lib/save_watch.gd).
## Three scripted Ironman campaigns check every input they make:
##   at the hub: three prisoner fates, wages, a hire, gear, a contract, Close, a new captain,
##   the map, rests until a storylet, its attempt and Close, and Save;
##   on the march: sixteen steps over two days, then a rest;
##   on the road: the walk into an ambush, Fight, every company turn, the triage, B over it,
##   Continue and the prisoners' fates.
## Then the guard itself is shown to catch each way a change can miss its save (the review of
## #148's lint-fooling forms, r148/lintfool): a change later in the same call, a deferred call, a
## short timer, a later frame's poll, and a change parked until a view input (main's loot bug as a
## lambda). Buttons are pressed by their `pressed` signal, so every listener runs.
## Seeded by design: world seed 424270, the suite's own ambush three steps out.

const InputKit := preload("res://tests/lib/input_kit.gd")
const Kit := preload("res://tests/lib/wiring_kit.gd")
const End := preload("res://tests/lib/end_kit.gd")
const World := preload("res://tests/lib/world_fixture.gd")
const SaveWatch := preload("res://tests/lib/save_watch.gd")
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SEED := 424270
const NEAR := 3
const TAP_LIMIT := 8
const PURSE := 600
const OWED := 40
const REST_LIMIT := 12
const WALK_STEPS := 16
const GEAR := "wpn_iron_blade"
const CAPTIVES: Array[String] = ["bandit_0", "bandit_1", "bandit_2"]
const DECISION := SaveWatch.DECISION
const VIEW := SaveWatch.VIEW
const WALK := SaveWatch.WALK

var _tree: SceneTree = null
var _check: Callable
## Buttons a scenario meant to press but found missing or disabled (a scenario that skips its
## inputs would pass for nothing).
var _missed: Array[String] = []


func setup(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	_check = check


func run() -> void:
	await at_the_hub()
	await on_the_march()
	await on_the_road(false)
	await caught_in_a_call()
	await on_the_road(true)


func at_the_hub() -> void:
	var game := await _home()
	var watch := _watch(game)
	await InputKit.tap(_tree, KEY_B)
	await watch.settle("B: the hub", VIEW)
	var hub := game.hub_director()
	for choice: String in Economy.CHOICES:
		await _press(hub.panel.button_for("prisoner", choice))
		await watch.settle("prisoner " + choice, DECISION)
	await _press(hub.panel.button_for("pay", "wages"))
	await watch.settle("pay wages", DECISION)
	for prefix: String in ["hire_", "equip_", "accept_"]:
		await _press(_first(hub.panel, prefix))
		await watch.settle(prefix, DECISION)
	await _press(hub.panel.button_for("close", "hub"))
	await watch.settle("close the hub", VIEW)
	game.company_director().panel.appoint_requested.emit(_not_captain(game))
	await watch.settle("appoint a captain", DECISION)
	await InputKit.tap(_tree, KEY_M)
	await watch.settle("M: the map", VIEW)
	var map := game.overworld_director()
	var story := game.get_node("StoryDirector") as StoryDirector
	for _rest: int in REST_LIMIT:
		await _press(map.panel.button_for(OverworldDirector.REST))
		await watch.settle("rest", DECISION)
		if story.is_open():
			break
	var fired := story.is_open()
	await _press(_attempt(story.panel))
	await watch.settle("storylet attempt", DECISION)
	await _press(story.panel.button_for(StoryDirector.CLOSE))
	await watch.settle("storylet close", VIEW)
	await _press(map.panel.button_for(OverworldDirector.SAVE))
	await watch.settle("save by hand", DECISION)
	_verdict(watch, fired, "at the hub, prisoners to a storylet")
	await _quit(game)


func on_the_march() -> void:
	var game := await _road_start(false)
	var watch := _watch(game)
	var map := game.overworld_director()
	var day := map.world.day
	for step: int in WALK_STEPS:
		await InputKit.tap(_tree, KEY_S if step % 2 == 0 else KEY_D)
		await watch.settle("step %d" % step, WALK)
	var walked := map.world.day > day
	await _press(map.panel.button_for(OverworldDirector.REST))
	await watch.settle("rest", DECISION)
	_verdict(
		watch,
		walked,
		"on the march, %d steps over days %d to %d" % [WALK_STEPS, day, map.world.day]
	)
	await _quit(game)


## A won ambush played through. With `parked`, the hub's loot is parked for Continue as main had it
## (lintfool lambda_park, bindv_park, field_alias): the guard must flag Continue.
func on_the_road(parked: bool) -> void:
	var game := await _road_start(true)
	var watch := _watch(game)
	var map := game.overworld_director()
	await _walk_into(map, watch)
	await _press(map.panel.button_for(OverworldDirector.FIGHT))
	await watch.settle("fight", DECISION)
	var battle := map.view.battle
	var sight := _sight()
	for _frame: int in InputKit.FIGHT_FRAMES:
		if battle.is_over():
			break
		var actor := battle.current()
		if actor.side == BattleUnit.COMPANY:
			await InputKit._company_turn(_tree, map, BattleAi.choose(battle, actor, sight))
			await watch.settle("turn of " + actor.id, DECISION)
		else:
			await _tree.process_frame
	await watch.settle("the fight's end", DECISION)
	if parked:
		var show: Callable = map._after_triage
		var economy := map.company.economy
		var stream := map.rng
		map._after_triage = func() -> void:
			economy.take_loot("ambush", stream, {"won": true})
			show.call()
		watch.problems.clear()
	await InputKit.tap(_tree, KEY_B)
	await watch.settle("B over the triage", VIEW)
	await _press(map.panel.button_for(OverworldDirector.CONTINUE))
	await watch.settle("continue", VIEW)
	if parked:
		(
			_check
			. call(
				watch.problems.size() == 1 and watch.problems[0].begins_with("continue"),
				"the save-order guard flags a change parked until Continue (main's loot bug as a lambda)"
			)
		)
	else:
		var hub := game.hub_director()
		var button := hub.panel.button_for("prisoner", Economy.RANSOM)
		while button != null:
			await _press(button)
			await watch.settle("ransom", DECISION)
			button = hub.panel.button_for("prisoner", Economy.RANSOM)
		_verdict(watch, battle.winner == BattleUnit.COMPANY, "on the road, a won ambush")
	await _quit(game)


## The guard catches a change that misses its save: after a rest, a change made later in the same
## call (lintfool semicolon, caller, if_show, return_call, panel_side, show_named, store_write,
## emit_after), a deferred one (deferred, await_late), a short timer (timer) and a later frame's
## poll of the memories (poll_alias, poll_two_level, poll_world).
func caught_in_a_call() -> void:
	var game := await _home()
	await InputKit.tap(_tree, KEY_M)
	var map := game.overworld_director()
	var watch := _watch(game)
	var memory := (game.get_node("StoryDirector") as StoryDirector).memory
	var economy := map.company.economy
	var faults := {
		"later in the same call": func() -> void: economy.purse += 1,
		"a deferred call": func() -> void: (func() -> void: economy.purse += 1).call_deferred(),
		"a short timer":
		func() -> void: _tree.create_timer(0.05).timeout.connect(func() -> void: economy.owed += 1),
		"a later frame's poll": func() -> void: _poll_once(memory),
	}
	for form: String in faults:
		await _press(map.panel.button_for(OverworldDirector.REST))
		var fault: Callable = faults[form]
		fault.call()
		var before := watch.problems.size()
		await watch.settle("rest + " + form, DECISION)
		_check.call(watch.problems.size() == before + 1, "the save-order guard flags " + form)
	await _quit(game)


## A memory written one frame later, as a poll in _process would.
func _poll_once(memory: Memory) -> void:
	await _tree.process_frame
	memory.record("ghost", Memory.KEY_CONTRACT, {}, 1)


func _verdict(watch: SaveWatch, reached: bool, where: String) -> void:
	var counts := [where, watch.inputs, watch.problems.size(), _missed, watch.summary()]
	print("SAVE WATCH %s: %d inputs, %d problems, missed %s\n%s" % counts)
	var pressed_all := _missed.is_empty()
	_missed.clear()
	_check.call(
		reached and pressed_all and watch.problems.is_empty(),
		(
			"Ironman On, %s: every change is saved before the next input (%d inputs)"
			% [where, watch.inputs]
		)
	)


func _watch(game: SliceGame) -> SaveWatch:
	var watch := SaveWatch.new()
	watch.watch(_tree, game)
	return watch


## The band at the hub, Ironman On, with prisoners held, wages owed, gear in the pack and a
## comrade's death remembered (so a rest can offer the storylet).
func _home() -> SliceGame:
	_clear_save()
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	var made := Kit.wounds(rng, "", {}, Kit.led_by(End.LAST))
	var economy := made.company.economy
	economy.purse = PURSE
	economy.owed = OWED
	economy.captives.take(world.day, CAPTIVES)
	economy.inventory.append(GEAR)
	var ids: Array[String] = []
	for merc: Merc in made.company.roster:
		ids.append(merc.id)
	made.memory().on_death("fallen_comrade", ids, 0, Memory.KEY_COMRADE_DIED)
	_saves().ironman = true
	_saves().save_game(world, rng, made.company, made.state())
	var game := await _spawn()
	game.hub_director()
	await InputKit.frames(_tree, InputKit.LAYOUT_FRAMES)
	return game


## Out of town, Ironman On, the map open; with `ambush`, a lone ambush three steps out.
func _road_start(ambush: bool) -> SliceGame:
	_clear_save()
	var rng := Rng.from_seed(SEED)
	var world := WorldSim.new()
	world.start(World.data(), rng)
	world.parties.clear()
	World.out_of_town(world, NEAR)
	if ambush:
		World.lone_party(world, "ambush", NEAR)
	var made := Kit.wounds(rng, "", {}, Kit.led_by(End.LAST))
	_saves().ironman = true
	_saves().save_game(world, rng, made.company, made.state())
	var game := await _spawn()
	await InputKit.tap(_tree, KEY_M)
	await InputKit.frames(_tree, InputKit.LAYOUT_FRAMES)
	return game


func _walk_into(map: OverworldDirector, watch: SaveWatch) -> void:
	var world := map.world
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
		await watch.settle("step to the ambush", WALK)


func _sight() -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(InputKit.BATTLE_DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var rules: Dictionary = data.get("rules", {})
	return rules.get("sight_cells", 0)


func _not_captain(game: SliceGame) -> String:
	var company := game.company_director().company
	for merc: Merc in company.roster:
		if merc.id != company.captain_id:
			return merc.id
	return ""


func _attempt(panel: LoopPanel) -> Button:
	for node: Node in panel.find_children("*", "Button", true, false):
		var id := str(node.get_meta(LoopPanel.META_ID, ""))
		if id.begins_with(StoryDirector.ATTEMPT_PREFIX):
			return node as Button
	return null


func _first(panel: Node, prefix: String) -> Button:
	for node: Node in panel.find_children("*", "Button", true, false):
		var button := node as Button
		if str(button.name).begins_with(prefix) and not button.disabled:
			return button
	return null


## The button's pressed signal, as a click raises it (every listener runs), after the layout.
func _press(button: Button) -> void:
	await InputKit.frames(_tree, InputKit.LAYOUT_FRAMES)
	if button != null and is_instance_valid(button) and not button.disabled:
		button.pressed.emit()
	else:
		_missed.append(str(button.name) if button != null else "(none)")
	await _tree.process_frame


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
