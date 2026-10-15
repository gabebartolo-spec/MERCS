extends "res://tests/lib/runner.gd"
## Story suite (Phase 2 M7: memories and the one storylet). Sim: a memory sentence is recorded
## with its params and survives a save; fights and choices write one on each merc who took
## part (the slice loop wired to it); tags are derived (character, memory, world, location)
## and the relationship is a shared memory; casting fills the roles deterministically; the
## visible check shows its odds before the roll and rolls on the seeded "story" stream; both
## branches change state (the failure moves forward); the storylet fires for a company that
## holds the memory and not for one that does not, and only once; the fired state and the
## memories round-trip through a JSON save and a reloaded run rolls the same. GUI (real
## key taps and mouse clicks at 1920x1080): resting on the map shows the scene with the odds,
## a click on an attempt shows the roll and outcome, Continue returns to the map, the memory
## shows on the F4 inspect screen, and a company without the memory sees no scene.
## Seeded by design: Rng.from_seed with pinned seeds; the GUI run uses the balance seed.
##   godot --headless --path . --script tests/run_story_tests.gd

const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const WORLD_BALANCE := "res://data/balance/world.json"
const STORYLETS := "res://data/storylets.json"
const CAPS := "res://data/caps.json"
const TEXT := "res://data/text/en.json"
const SCENARIOS := "res://data/scenarios.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const SEED := 424242
const OTHER_SEED := 424243
const STORY_ID := "st_unspoken_loss"
const DEAD := "fallen_comrade"
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
const SEED_SEARCH := 60
const SAMPLES := 400
const MAX_TURNS := 400
const REST_CONTEXT := {"hook": "rest", "day": 3, "site": "site_hub", "site_kind": "hub"}


func suite_name() -> String:
	return "Story"


func run_checks() -> void:
	_check_memory_records()
	_check_tags_and_relationship()
	_check_casting()
	_check_odds()
	_check_state()
	_check_eligibility()
	_check_branches()
	_check_save()
	_check_text_and_data()
	_check_loop_memories()
	root.size = WINDOW_SIZE
	_clear_save()
	await _check_gui()
	await _check_gui_without_memory()
	_clear_save()


# --- helpers ------------------------------------------------------------------------


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _defs() -> Dictionary:
	var fighters: Variant = _json(BATTLE_DATA).get("fighters", {})
	return {
		"mercs": _json("res://data/mercs.json"),
		"fighters": fighters if fighters is Dictionary else {},
		"company": _json("res://data/balance/company.json"),
	}


## A book over the starting company; with_memory writes the death of a comrade on everyone.
func _book(seed_value: int, with_memory: bool) -> StoryBook:
	var book := StoryBook.new()
	book.company = Company.start(_defs())
	book.rng = Rng.from_seed(seed_value)
	book.load_defs(_json(STORYLETS))
	if with_memory:
		var ids: Array[String] = []
		for merc: Merc in book.company.roster:
			ids.append(merc.id)
		book.memory.on_death(DEAD, ids, 2, Memory.KEY_COMRADE_DIED)
	return book


## A book whose offer was made and whose first attempt rolled `want_success`, found by seed.
func _rolled(want_success: bool) -> Dictionary:
	for seed_value: int in range(1, SEED_SEARCH):
		var book := _book(seed_value, true)
		var made := book.offer(REST_CONTEXT)
		var result := book.choose(made, "mourner")
		if result.get("success", false) == want_success:
			return {"book": book, "offer": made, "result": result, "seed": seed_value}
	return {}


# --- sim ----------------------------------------------------------------------------


func _check_memory_records() -> void:
	var memory := Memory.new()
	memory.record("a", "memory.fight_won", {"site": "x"}, 4)
	memory.record("", "memory.fight_won", {}, 4)
	memory.record("a", "", {}, 4)
	var held := memory.of("a")
	check(held.size() == 1, "an empty id or key writes nothing, a good one writes one")
	check(
		held[0].get("key") == "memory.fight_won" and held[0].get("day") == 4,
		"a record keeps its key and day"
	)
	var params: Dictionary = held[0].get("params", {})
	check(params.get("site") == "x" and params.has("about"), "a record keeps its params")
	held[0]["key"] = "changed"
	check(memory.of("a")[0].get("key") == "memory.fight_won", "of() hands out copies")
	var back := Memory.restore(JSON.parse_string(JSON.stringify(memory.state())))
	check(back.of("a") == memory.of("a"), "params and day survive state, JSON and restore")
	var old := Memory.restore({"b": [{"key": "memory.dissent", "about": "c", "day": 2}]})
	check(old.of("b")[0].get("params", {}).get("about") == "c", "a memory from before params reads")
	var fights := Memory.new()
	fights.on_fight(["z", "a", "z"], false, ["z"], 5)
	check(
		fights.has_key("a", Memory.KEY_FIGHT_LOST) and fights.has_key("z", Memory.KEY_FIGHT_LOST),
		"a fight writes won or lost on every merc who fought, once"
	)
	check(
		fights.has_key("z", Memory.KEY_FIGHT_FELL) and not fights.has_key("a", Memory.KEY_FIGHT_FELL),
		"only a merc who went down remembers going down"
	)
	fights.on_choice(["a"], Memory.KEY_FATE_PREFIX + "spare", 6)
	check(fights.has_key("a", "memory.fate_spare"), "a choice writes its sentence")


func _check_tags_and_relationship() -> void:
	var book := _book(SEED, true)
	var orc := book.company.member("orc")
	var tags := StoryTags.of_merc(orc, book.company.captain_id, book.memory)
	check(tags.has("species:orc") and tags.has("captain"), "character tags: species and captain")
	check(tags.has("memory:memory.comrade_died"), "memory tags come from the memories held")
	check(
		StoryTags.of_merc(book.company.member("vampyr"), "orc", book.memory).has("captain") == false,
		"only the captain has the captain tag"
	)
	var world := StoryTags.of_context(REST_CONTEXT)
	check(
		world.has("hook:rest") and world.has("day:3"), "world tags: the hook and the day (%s)" % [world]
	)
	check(world.has("location:site_hub") and world.has("kind:hub"), "location tags: site and kind")
	check(book.memory.shared("orc", "vampyr"), "two who stood at one death share a memory")
	check(not book.memory.shared("orc", "orc"), "a merc does not share a memory with themselves")
	var lone := Memory.new()
	lone.write("a", "memory.comrade_died", "x", 1)
	lone.write("b", "memory.comrade_died", "y", 1)
	check(not lone.shared("a", "b"), "the same sentence about two different deaths is not shared")


func _check_casting() -> void:
	var book := _book(SEED, true)
	var found := book.casts_for(book.definition(STORY_ID), REST_CONTEXT)
	var count := book.company.roster.size()
	check(found.size() == count * (count - 1), "every pair of different mercs is a cast (%d)" % found.size())
	check(
		found.all(func(cast: Dictionary) -> bool: return cast["mourner"] != cast["friend"]),
		"no merc fills two roles"
	)
	var again := _book(SEED, true).casts_for(book.definition(STORY_ID), REST_CONTEXT)
	check(again == found, "the same company gives the same casts in the same order")
	var rules := [{"role": "a", "require": ["captain"]}, {"role": "b", "require": ["!captain"]}]
	var tags := {"x": ["captain"], "y": []}
	var cast := Casting.new(tags, Memory.new()).casts(rules)
	check(cast == [{"a": "x", "b": "y"}], "a role can ask for a tag, another for its absence")
	check(
		_book(SEED, false).casts_for(book.definition(STORY_ID), REST_CONTEXT).is_empty(),
		"no memory of a death, no cast"
	)


func _check_odds() -> void:
	var table_ok := true
	for skill: int in range(0, 14):
		var wins := 0
		for roll: int in range(1, 11):
			if roll >= 11 - skill:
				wins += 1
		table_ok = table_ok and Checks.odds(10, skill, 11) == wins * 10
	check(table_ok, "odds are the share of the die that reaches the need, for every skill")
	check(Checks.odds(10, 6, 11) == 60, "a d10 at skill 6 against 11 is 60 percent")
	check(Checks.odds(10, 0, 20) == 0 and Checks.odds(10, 20, 5) == 100, "impossible and certain")
	var rng := Rng.from_seed(SEED)
	var wins := 0
	for _i: int in SAMPLES:
		if Checks.attempt(rng, 10, 6, 11).get("success", false) == true:
			wins += 1
	var seen := wins * 100 / SAMPLES
	check(absi(seen - 60) <= 8, "rolled over %d tries the odds shown hold (%d percent)" % [SAMPLES, seen])
	var book := _book(SEED, true)
	var made := book.offer(REST_CONTEXT)
	var shown: Array = made.get("attempts", [])
	check(
		shown.size() == 2 and shown.all(func(a: Dictionary) -> bool: return a.has("odds")),
		"the offer carries the odds of each way to attempt, before any roll"
	)
	var streams: Dictionary = book.rng.state().get("streams", {})
	check(not streams.has("story"), "making the offer rolls nothing on the check's stream")


func _check_state() -> void:
	var state := StoryletState.new()
	check(state.ready("st_a", 1, true, 0), "a storylet never fired is ready")
	state.mark("st_a", 5)
	check(not state.ready("st_a", 99, true, 0), "a once-only storylet never comes back")
	check(not state.ready("st_a", 6, false, 3), "a cooldown holds it for its days")
	check(state.ready("st_a", 8, false, 3), "and lets it go after them")
	var back := StoryletState.restore(JSON.parse_string(JSON.stringify(state.state())))
	check(back.has_fired("st_a") and not back.ready("st_a", 6, false, 3), "state survives JSON")
	check(StoryletState.restore({}).fired.is_empty(), "no block reads as nothing fired")


func _check_eligibility() -> void:
	var with_memory := _book(SEED, true).offer(REST_CONTEXT)
	var without := _book(SEED, false).offer(REST_CONTEXT)
	check(with_memory.get("id") == STORY_ID, "the company with the memory is offered the storylet")
	check(without.is_empty(), "the company without it, on the same seed and day, is not")
	var again := _book(SEED, true).offer(REST_CONTEXT)
	check(again == with_memory, "the same seed offers the same cast")
	var other := _book(OTHER_SEED, true).offer(REST_CONTEXT)
	var differs := false
	for seed_value: int in range(1, SEED_SEARCH):
		differs = differs or _book(seed_value, true).offer(REST_CONTEXT).get("cast") != with_memory.get("cast")
	check(differs and not other.is_empty(), "another seed can pick another cast")
	var book := _book(SEED, true)
	check(book.offer({"hook": "arrival", "day": 3, "site": "s", "site_kind": "hub"}).is_empty(), "wrong hook")
	check(book.offer({"hook": "rest", "day": 0, "site": "s", "site_kind": "hub"}).is_empty(), "too early")
	check(book.offer({"hook": "rest", "day": 3, "site": "s", "site_kind": "wild"}).is_empty(), "wrong place")
	var made := book.offer(REST_CONTEXT)
	book.choose(made, "friend")
	check(book.offer(REST_CONTEXT).is_empty(), "after it fires it does not come back")


func _check_branches() -> void:
	var won := _rolled(true)
	var lost := _rolled(false)
	check(not won.is_empty() and not lost.is_empty(), "pinned seeds reach both outcomes")
	var win_result: Dictionary = won.get("result", {})
	var lose_result: Dictionary = lost.get("result", {})
	check(win_result.get("branch") == "success" and lose_result.get("branch") == "failure", "branches")
	var win_book: StoryBook = won.get("book")
	var lose_book: StoryBook = lost.get("book")
	var win_cast: Dictionary = won["offer"]["cast"]
	var lose_cast: Dictionary = lost["offer"]["cast"]
	check(
		win_book.memory.has_key(win_cast["mourner"], "memory.grief_eased"),
		"success writes its memory on the mourner"
	)
	check(
		lose_book.memory.has_key(lose_cast["mourner"], "memory.grief_deepened"),
		"failure moves forward: it writes a memory too"
	)
	check(
		lose_book.company.member(lose_cast["mourner"]).xp == 1
		and win_book.company.member(win_cast["mourner"]).xp == 2,
		"failure still teaches (1 xp), success more (2 xp)"
	)
	check(lose_result.get("effects", []).size() > 0, "the failing branch reports what it changed")
	check(lose_book.state.has_fired(STORY_ID), "failing still counts as fired: no dead end, no repeat")
	var fresh := _book(int(won["seed"]), true)
	var made := fresh.offer(REST_CONTEXT)
	var attempt: Dictionary = made["attempts"][0]
	var expected := Checks.attempt(
		Rng.restore(Rng.from_seed(int(won["seed"])).state()), 10, attempt["skill"], attempt["difficulty"]
	)
	check(
		expected.get("roll") != null and fresh.choose(made, "mourner").get("success") == win_result.get("success"),
		"the same seed rolls the same check"
	)
	check(_book(SEED, true).choose({"id": STORY_ID}, "mourner").is_empty(), "no attempt, no roll")


func _check_save() -> void:
	var book := _book(SEED, true)
	var made := book.offer(REST_CONTEXT)
	var world_balance := _json(WORLD_BALANCE)
	var world := WorldSim.new()
	world.start(world_balance, book.rng)
	var saved := SaveModel.to_dict(
		world, book.rng, book.company, {"memories": book.memory.state()}
	)
	var json := JSON.stringify(saved)
	var uninterrupted := book.choose(made, "mourner")
	SaveModel.with_story(saved, book.state.state())
	var model := SaveModel.from_dict(JSON.parse_string(json), world_balance, _defs())
	var reloaded := StoryBook.new()
	reloaded.company = model.company
	reloaded.rng = model.rng
	reloaded.memory = Memory.restore(model.wounds.get("memories", {}))
	reloaded.load_defs(_json(STORYLETS))
	check(
		reloaded.choose(made, "mourner").get("roll") == uninterrupted.get("roll"),
		"a run reloaded from a save rolls the same check as one that went on"
	)
	var with_story := SaveModel.from_dict(
		JSON.parse_string(JSON.stringify(SaveModel.with_story(saved, book.state.state()))),
		world_balance
	)
	var kept := StoryletState.restore(with_story.story)
	check(kept.has_fired(STORY_ID), "the storylets fired come back from the save")
	reloaded.state = kept
	check(reloaded.offer(REST_CONTEXT).is_empty(), "and a fired once-only storylet is not offered again")
	check(
		SaveModel.from_dict({"version": 2}, world_balance).story.is_empty(),
		"a save without the story block reads as nothing fired"
	)
	check(reloaded.memory.of("orc").size() == 1, "the memories come back from the save")


func _check_text_and_data() -> void:
	var def: Dictionary = _json(STORYLETS)["storylets"][0]
	var strings := _json(TEXT)
	var keys: Array[String] = []
	keys.append_array([def["title_key"], def["scene_key"]])
	for branch: String in ["success", "failure"]:
		keys.append(def[branch]["line_key"])
		for effect: Dictionary in def[branch]["effects"]:
			if effect.has("key"):
				keys.append(effect["key"])
	for attempt: Dictionary in def["check"]["attempts"]:
		keys.append(attempt["label_key"])
	var missing := keys.filter(func(key: String) -> bool: return not strings.has(key))
	check(missing.is_empty(), "every text key the storylet names is in en.json: %s" % [missing])
	var marked := keys.all(
		func(key: String) -> bool:
			return not (key.contains(".scene") or key.contains(".success") or key.contains(".failure"))
			or str(strings[key]).contains("placeholder - the director writes this")
	)
	check(marked, "the storylet's words are marked as the director's to write")
	var cap: int = _json(CAPS)["caps"]["storylets"]
	check(_json(STORYLETS)["storylets"].size() == cap and cap == 1, "one storylet, as the cap says")
	check(
		def["success"]["effects"].size() > 0 and def["failure"]["effects"].size() > 0,
		"both branches change state"
	)


func _check_loop_memories() -> void:
	var scenario: Dictionary = _json(SCENARIOS)["scenarios"][0]
	var loop := SliceLoop.new()
	loop.memory = Memory.new()
	loop.day = 7
	loop.start(scenario, _json(BATTLE_DATA), Rng.from_seed(SEED))
	loop.advance()
	loop.hire(false)
	loop.accept_contract()
	check(loop.memory.has_key("orc", Memory.KEY_CONTRACT), "taking the contract is remembered")
	loop.advance()
	loop.fight()
	var rules: Dictionary = _json(BATTLE_DATA).get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	for _turn: int in MAX_TURNS:
		if loop.battle.is_over():
			break
		loop.battle.apply(BattleAi.choose(loop.battle, loop.battle.current(), sight))
	loop.end_battle()
	var key := Memory.KEY_FIGHT_WON if loop.battle.winner == BattleUnit.COMPANY else Memory.KEY_FIGHT_LOST
	check(
		loop.memory.has_key("orc", key) and loop.memory.has_key("vampyr", key),
		"the fight is remembered by each merc who fought, as won or lost"
	)
	check(loop.memory.of("orc")[0].get("day") == 7, "with the world's day")
	if loop.stage == SliceLoop.Stage.AFTERMATH:
		loop.choose_fate("spare")
		check(loop.memory.has_key("orc", "memory.fate_spare"), "the prisoner's fate is remembered")
	var silent := SliceLoop.new()
	silent.start(scenario, _json(BATTLE_DATA), Rng.from_seed(SEED))
	silent.advance()
	silent.hire(false)
	silent.accept_contract()
	check(silent.memory == null, "without a memory store the loop is as before")


# --- GUI ----------------------------------------------------------------------------


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


func _check_gui() -> void:
	var game := await _spawn()
	var story := game.get_node("StoryDirector") as StoryDirector
	check(story != null, "the game attaches a story director")
	var ids: Array[String] = []
	for merc: Merc in game.company_director().company.roster:
		ids.append(merc.id)
	story.memory.on_death(DEAD, ids, 2, Memory.KEY_COMRADE_DIED)
	await _tap(KEY_M)
	var map := game.overworld_director()
	await _frames(LAYOUT_FRAMES)
	await _click_button(map.panel.button_for("rest"))
	await _frames(LAYOUT_FRAMES)
	check(story.is_open(), "resting with the memory shows the storylet")
	var body := story.panel.shown_body()
	check(body.contains("placeholder - the director writes this"), "the scene says it is a placeholder")
	var cast: Dictionary = story.offer.get("cast", {})
	var mourner := game.company_director().company.member(str(cast.get("mourner", "")))
	check(mourner != null and body.contains(mourner.display_name), "the scene names the cast")
	var attempt := story.panel.button_for("attempt:mourner")
	check(attempt != null and attempt.text.contains("%"), "the choice shows its odds before the roll")
	check(not map.panel.visible, "the map's own choices are out of the way")
	check(not (game.get("_hud") as CanvasLayer).visible, "the key help is hidden while it is up")
	var before := mourner.xp
	await _click_button(attempt)
	await _frames(LAYOUT_FRAMES)
	check(story.panel.shown_body().contains("Rolled"), "after the click the roll and outcome show")
	check(story.result.has("branch") and mourner.xp > before, "the branch changed the company")
	await _click_button(story.panel.button_for("close"))
	await _frames(LAYOUT_FRAMES)
	check(not story.is_open() and map.panel.visible, "Continue returns to the map's choices")
	await _click_button(map.panel.button_for("rest"))
	await _frames(LAYOUT_FRAMES)
	check(not story.is_open(), "a second rest does not repeat it")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_C)
	var director := game.company_director()
	await _click_button(director.panel.row_for(mourner.id))
	await _frames(LAYOUT_FRAMES)
	var lines := director.panel.lines_text()
	check(lines.contains("Memories:") and lines.contains("fell on day"), "the inspect screen shows memories")
	check(
		lines.contains("placeholder - the director writes this"), "and the storylet's own memory (%s)" % lines
	)
	game.queue_free()
	await process_frame


func _check_gui_without_memory() -> void:
	_clear_save()
	var game := await _spawn()
	var story := game.get_node("StoryDirector") as StoryDirector
	await _tap(KEY_M)
	var map := game.overworld_director()
	await _frames(LAYOUT_FRAMES)
	await _click_button(map.panel.button_for("rest"))
	await _frames(LAYOUT_FRAMES)
	check(not story.is_open(), "the same rest in a company without the memory shows no storylet")
	check(map.panel.visible, "and the map's choices stay")
	game.queue_free()
	await process_frame


func _clear_save() -> void:
	var path := SAVE_SYSTEM.SAVE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _click_button(button: Button) -> void:
	await _frames(LAYOUT_FRAMES)
	if button == null or not is_instance_valid(button):
		check(false, "a button to click was there")
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


func _tap(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
