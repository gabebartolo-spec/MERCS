extends "res://tests/lib/runner.gd"
## Story suite (Phase 2 M7: memories and the one storylet), sim side. Memory sentences record
## with their params and survive a save; fights and choices write one on each merc who took
## part (the slice loop); tags are derived and a relationship is a shared memory; casting is
## deterministic; the check shows its odds before the roll and rolls on the seeded "story"
## stream; both branches change state (failure moves forward); the storylet fires for a company
## with the memory and not one without, once; fired state and memories round-trip a JSON save
## and a reloaded run rolls the same. The screen is the story_gui suite.
## Seeded by design: Rng.from_seed with pinned seeds.
##   godot --headless --path . --script tests/run_story_tests.gd

const WORLD_BALANCE := "res://data/balance/world.json"
const STORYLETS := "res://data/storylets.json"
const CAPS := "res://data/caps.json"
const TEXT := "res://data/text/en.json"
const BATTLE_DATA := "res://data/balance/battle.json"
const SEED := 424242
const OTHER_SEED := 424243
const STORY_ID := "st_unspoken_loss"
const DEAD := "fallen_comrade"
const SEED_SEARCH := 60
const SAMPLES := 400
const REST_CONTEXT := {"hook": "rest", "day": 3, "site": "site_hub", "site_kind": "hub"}


func suite_name() -> String:
	return "Story"


func run_checks() -> void:
	await _t("_test_memory_records")
	await _t("_test_tags_and_relationship")
	await _t("_test_casting")
	await _t("_test_odds")
	await _t("_test_state")
	await _t("_test_eligibility")
	await _t("_test_branches")
	await _t("_test_save")
	await _t("_test_text_and_data")
	await process_frame


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


func _test_memory_records() -> void:
	var memory := Memory.new()
	memory.record("a", "memory.fight_won", {"site": "x"}, 4)
	memory.record("", "memory.fight_won", {}, 4)
	memory.record("a", "", {}, 4)
	var held := memory.of("a")
	check(held.size() == 1, "an empty id or key writes nothing, a good one writes one")
	check(
		str(held[0].get("key")) == "memory.fight_won" and _i(held[0].get("day")) == 4,
		"a record keeps its key and day"
	)
	var params: Dictionary = held[0].get("params", {})
	check(str(params.get("site")) == "x" and params.has("about"), "a record keeps its params")
	held[0]["key"] = "changed"
	check(str(memory.of("a")[0].get("key")) == "memory.fight_won", "of() hands out copies")
	var back := Memory.restore(_d(JSON.parse_string(JSON.stringify(memory.state()))))
	check(back.of("a") == memory.of("a"), "params and day survive state, JSON and restore")
	var old := Memory.restore({"b": [{"key": "memory.dissent", "about": "c", "day": 2}]})
	check(
		str(_d(old.of("b")[0].get("params")).get("about")) == "c",
		"a memory from before params reads"
	)
	var fights := Memory.new()
	fights.on_fight(["z", "a", "z"], false, ["z"], 5)
	check(
		fights.has_key("a", Memory.KEY_FIGHT_LOST) and fights.has_key("z", Memory.KEY_FIGHT_LOST),
		"a fight writes won or lost on every merc who fought, once"
	)
	check(
		(
			fights.has_key("z", Memory.KEY_FIGHT_FELL)
			and not fights.has_key("a", Memory.KEY_FIGHT_FELL)
		),
		"only a merc who went down remembers going down"
	)
	fights.on_choice(["a"], Memory.KEY_FATE_PREFIX + "spare", 6)
	check(fights.has_key("a", "memory.fate_spare"), "a choice writes its sentence")


func _test_tags_and_relationship() -> void:
	var book := _book(SEED, true)
	var orc := book.company.member("orc")
	var tags := StoryTags.of_merc(orc, book.company.captain_id, book.memory)
	check(tags.has("species:orc") and tags.has("captain"), "character tags: species and captain")
	check(tags.has("memory:memory.comrade_died"), "memory tags come from the memories held")
	check(
		(
			StoryTags.of_merc(book.company.member("vampyr"), "orc", book.memory).has("captain")
			== false
		),
		"only the captain has the captain tag"
	)
	var world := StoryTags.of_context(REST_CONTEXT)
	check(
		world.has("hook:rest") and world.has("day:3"),
		"world tags: the hook and the day (%s)" % [world]
	)
	check(world.has("location:site_hub") and world.has("kind:hub"), "location tags: site and kind")
	check(book.memory.shared("orc", "vampyr"), "two who stood at one death share a memory")
	check(not book.memory.shared("orc", "orc"), "a merc does not share a memory with themselves")
	var lone := Memory.new()
	lone.write("a", "memory.comrade_died", "x", 1)
	lone.write("b", "memory.comrade_died", "y", 1)
	check(not lone.shared("a", "b"), "the same sentence about two different deaths is not shared")


func _test_casting() -> void:
	var book := _book(SEED, true)
	var found := book.casts_for(book.definition(STORY_ID), REST_CONTEXT)
	var count := book.company.roster.size()
	check(
		found.size() == count * (count - 1),
		"every pair of different mercs is a cast (%d)" % found.size()
	)
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


func _test_odds() -> void:
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
	check(
		absi(seen - 60) <= 8,
		"rolled over %d tries the odds shown hold (%d percent)" % [SAMPLES, seen]
	)
	var book := _book(SEED, true)
	var made := book.offer(REST_CONTEXT)
	var shown: Array = made.get("attempts", [])
	check(
		shown.size() == 2 and shown.all(func(a: Dictionary) -> bool: return a.has("odds")),
		"the offer carries the odds of each way to attempt, before any roll"
	)
	var streams: Dictionary = book.rng.state().get("streams", {})
	check(not streams.has("story"), "making the offer rolls nothing on the check's stream")


func _test_state() -> void:
	var state := StoryletState.new()
	check(state.ready("st_a", 1, true, 0), "a storylet never fired is ready")
	state.mark("st_a", 5)
	check(not state.ready("st_a", 99, true, 0), "a once-only storylet never comes back")
	check(not state.ready("st_a", 6, false, 3), "a cooldown holds it for its days")
	check(state.ready("st_a", 8, false, 3), "and lets it go after them")
	var back := StoryletState.restore(_d(JSON.parse_string(JSON.stringify(state.state()))))
	check(back.has_fired("st_a") and not back.ready("st_a", 6, false, 3), "state survives JSON")
	check(StoryletState.restore({}).fired.is_empty(), "no block reads as nothing fired")


func _test_eligibility() -> void:
	var with_memory := _book(SEED, true).offer(REST_CONTEXT)
	var without := _book(SEED, false).offer(REST_CONTEXT)
	check(
		str(with_memory.get("id")) == STORY_ID,
		"the company with the memory is offered the storylet"
	)
	check(without.is_empty(), "the company without it, on the same seed and day, is not")
	var again := _book(SEED, true).offer(REST_CONTEXT)
	check(again == with_memory, "the same seed offers the same cast")
	var other := _book(OTHER_SEED, true).offer(REST_CONTEXT)
	var differs := false
	for seed_value: int in range(1, SEED_SEARCH):
		differs = (
			differs
			or _book(seed_value, true).offer(REST_CONTEXT).get("cast") != with_memory.get("cast")
		)
	check(differs and not other.is_empty(), "another seed can pick another cast")
	var book := _book(SEED, true)
	check(
		book.offer({"hook": "arrival", "day": 3, "site": "s", "site_kind": "hub"}).is_empty(),
		"wrong hook"
	)
	check(
		book.offer({"hook": "rest", "day": 0, "site": "s", "site_kind": "hub"}).is_empty(),
		"too early"
	)
	check(
		book.offer({"hook": "rest", "day": 3, "site": "s", "site_kind": "wild"}).is_empty(),
		"wrong place"
	)
	var made := book.offer(REST_CONTEXT)
	book.choose(made, "friend")
	check(book.offer(REST_CONTEXT).is_empty(), "after it fires it does not come back")


func _test_branches() -> void:
	var won := _rolled(true)
	var lost := _rolled(false)
	check(not won.is_empty() and not lost.is_empty(), "pinned seeds reach both outcomes")
	var win_result: Dictionary = won.get("result", {})
	var lose_result: Dictionary = lost.get("result", {})
	check(
		str(win_result.get("branch")) == "success" and str(lose_result.get("branch")) == "failure",
		"branches"
	)
	var win_book: StoryBook = won.get("book")
	var lose_book: StoryBook = lost.get("book")
	var win_cast := _d(_d(won.get("offer")).get("cast"))
	var lose_cast := _d(_d(lost.get("offer")).get("cast"))
	var win_mourner := str(win_cast.get("mourner"))
	var lose_mourner := str(lose_cast.get("mourner"))
	check(
		win_book.memory.has_key(win_mourner, "memory.grief_eased"),
		"success writes its memory on the mourner"
	)
	check(
		lose_book.memory.has_key(lose_mourner, "memory.grief_deepened"),
		"failure moves forward: it writes a memory too"
	)
	check(
		(
			lose_book.company.member(lose_mourner).xp == 1
			and win_book.company.member(win_mourner).xp == 2
		),
		"failure still teaches (1 xp), success more (2 xp)"
	)
	check(_a(lose_result.get("effects")).size() > 0, "the failing branch reports what it changed")
	check(
		lose_book.state.has_fired(STORY_ID), "failing still counts as fired: no dead end, no repeat"
	)
	_check_same_seed(won)


func _check_same_seed(won: Dictionary) -> void:
	var win_result := _d(won.get("result"))
	var fresh := _book(_i(won.get("seed")), true)
	var again := fresh.choose(fresh.offer(REST_CONTEXT), "mourner")
	check(
		_i(again.get("roll")) == _i(win_result.get("roll")) and str(again.get("success")) == "true",
		"the same seed rolls the same check"
	)
	check(_book(SEED, true).choose({"id": STORY_ID}, "mourner").is_empty(), "no attempt, no roll")


func _test_save() -> void:
	var book := _book(SEED, true)
	var made := book.offer(REST_CONTEXT)
	var world_balance := _json(WORLD_BALANCE)
	var world := WorldSim.new()
	world.start(world_balance, book.rng)
	var saved := SaveModel.to_dict(world, book.rng, book.company, {"memories": book.memory.state()})
	var json := JSON.stringify(saved)
	var uninterrupted := book.choose(made, "mourner")
	SaveModel.with_story(saved, book.state.state())
	var model := SaveModel.from_dict(_d(JSON.parse_string(json)), world_balance, _defs())
	var reloaded := StoryBook.new()
	reloaded.company = model.company
	reloaded.rng = model.rng
	reloaded.memory = Memory.restore(_d(model.wounds.get("memories")))
	reloaded.load_defs(_json(STORYLETS))
	check(
		_i(reloaded.choose(made, "mourner").get("roll")) == _i(uninterrupted.get("roll")),
		"a run reloaded from a save rolls the same check as one that went on"
	)
	var with_story := SaveModel.from_dict(
		_d(JSON.parse_string(JSON.stringify(SaveModel.with_story(saved, book.state.state())))),
		world_balance
	)
	var kept := StoryletState.restore(with_story.story)
	check(kept.has_fired(STORY_ID), "the storylets fired come back from the save")
	reloaded.state = kept
	check(
		reloaded.offer(REST_CONTEXT).is_empty(),
		"and a fired once-only storylet is not offered again"
	)
	check(
		SaveModel.from_dict({"version": 2}, world_balance).story.is_empty(),
		"a save without the story block reads as nothing fired"
	)
	check(reloaded.memory.of("orc").size() == 1, "the memories come back from the save")


func _test_text_and_data() -> void:
	var def := _d(_a(_json(STORYLETS).get("storylets"))[0])
	var strings := _json(TEXT)
	var keys: Array[String] = [str(def.get("title_key")), str(def.get("scene_key"))]
	for branch: String in ["success", "failure"]:
		keys.append(str(_d(def.get(branch)).get("line_key")))
		for effect: Variant in _a(_d(def.get(branch)).get("effects")):
			if _d(effect).has("key"):
				keys.append(str(_d(effect).get("key")))
	for attempt: Variant in _a(_d(def.get("check")).get("attempts")):
		keys.append(str(_d(attempt).get("label_key")))
	var missing := keys.filter(func(key: String) -> bool: return not strings.has(key))
	check(missing.is_empty(), "every text key the storylet names is in en.json: %s" % [missing])
	var marked := true
	for key: String in keys:
		var is_words := (
			key.contains(".scene") or key.contains(".success") or key.contains(".failure")
		)
		if is_words:
			marked = (
				marked and str(strings.get(key)).contains("placeholder - the director writes this")
			)
	check(marked, "the storylet's words are marked as the director's to write")
	var cap := _i(_d(_json(CAPS).get("caps")).get("storylets"))
	check(
		_a(_json(STORYLETS).get("storylets")).size() == cap and cap == 1,
		"one storylet, as the cap says"
	)
	check(
		(
			_a(_d(def.get("success")).get("effects")).size() > 0
			and _a(_d(def.get("failure")).get("effects")).size() > 0
		),
		"both branches change state"
	)


static func _d(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _a(value: Variant) -> Array:
	return value if value is Array else []


static func _i(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return -1
