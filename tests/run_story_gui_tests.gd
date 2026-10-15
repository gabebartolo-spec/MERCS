extends "res://tests/lib/runner.gd"
## Story GUI suite (Phase 2 M7), real key taps and mouse clicks at 1920x1080: resting on the
## map with a company that holds the memory of a comrade's death shows the storylet scene
## (cast named, the way to attempt it with its odds, the placeholder marking), the map's own
## choices and the key help out of the way; a click on an attempt shows the roll and the
## outcome and changes the company; Continue returns to the map; a second rest does not
## repeat it; the C company screen shows the merc's memories; the same rest in a company
## without the memory shows nothing.
## Seeded by design: the balance seed (data/balance/world.json) and Rng.from_seed.
##   godot --headless --path . --script tests/run_story_gui_tests.gd

const InputKit := preload("res://tests/lib/input_kit.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
const DEAD := "fallen_comrade"
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3


func suite_name() -> String:
	return "Story GUI"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_clear_save()
	await _check_gui()
	await _check_gui_without_memory()
	_clear_save()


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
	_mourn(game, story)
	await _tap(KEY_M)
	var map := game.overworld_director()
	await InputKit.pick_mode(self, map)
	await _click_button(map.panel.button_for("rest"))
	await _frames(LAYOUT_FRAMES)
	check(story.is_open(), "resting with the memory shows the storylet")
	var body := story.panel.shown_body()
	check(
		body.contains("placeholder - the director writes this"),
		"the scene says it is a placeholder"
	)
	var cast: Dictionary = story.offer.get("cast", {})
	var mourner := game.company_director().company.member(str(cast.get("mourner", "")))
	check(mourner != null and body.contains(mourner.display_name), "the scene names the cast")
	var attempt := story.panel.button_for("attempt:mourner")
	check(
		attempt != null and attempt.text.contains("%"), "the choice shows its odds before the roll"
	)
	check(not map.panel.visible, "the map's own choices are out of the way")
	check(_help_hidden(game), "the key help is hidden while the scene is up")
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
	await _check_decision(game, story)
	await _check_inspect(game, mourner.id)
	game.queue_free()
	await process_frame


## The hub's prisoner decision (an economy chronicle line) becomes a memory of the captain.
func _check_decision(game: SliceGame, story: StoryDirector) -> void:
	var company := game.company_director().company
	company.economy.captives.take(5)
	var reactor := company.economy.captives.reacting(company, "release")
	company.economy.decide_prisoner(company, "release", 5)
	await _frames(LAYOUT_FRAMES)
	var captain := company.captain_id
	check(
		story.memory.has_key(captain, "memory.fate_release"),
		"a prisoner decision at the hub is remembered by the captain"
	)
	check(
		reactor != "" and story.memory.has_key(reactor, "memory.fate_release"),
		"and by the merc who reacts most strongly to it (%s, Phase 5 C5)" % reactor
	)
	var count := story.memory.of(captain).size()
	await _frames(LAYOUT_FRAMES)
	check(story.memory.of(captain).size() == count, "and only once")
	await _check_broken_deal(company, story)
	_check_chronicle_words()
	_check_hunted_words(company)


## Every chronicle line the economy can write (a prisoner's fate, a walked deal with or without a
## grudge, a step-in won or lost) and every hunter fight's memory has words in data/text/en.json.
func _check_chronicle_words() -> void:
	var keys: Array[String] = []
	for choice: String in Prisoners.CHOICES:
		keys.append(StoryDirector.memory_key("prisoner." + choice))
	for line: String in [
		Economy.KEY_ABANDON, Economy.KEY_GRUDGE, Terms.KEY_STEP_WON, Terms.KEY_STEP_LOST
	]:
		keys.append(StoryDirector.memory_key(line))
	for outcome: String in ["won", "lost"]:
		keys.append(GrudgeParties.MEMORY_PREFIX + outcome)
	var bare: Array[String] = []
	for key: String in keys:
		if Text.t(key) == key:
			bare.append(key)
	check(bare.is_empty(), "every memory the economy's chronicle makes has words: bare %s" % [bare])


## A hunter fight's memory reads with the captain's name in it, every placeholder filled.
func _check_hunted_words(company: Company) -> void:
	var captain := company.member(company.captain_id)
	var params := {"about": captain.id, "deal": "ctr_walked", "faction": "fac_placeholder_a"}
	var entry := {"key": GrudgeParties.MEMORY_PREFIX + "won", "params": params, "day": 7}
	var said := MemoryWords.line(entry, company)
	check(
		said.contains(captain.display_name) and not said.contains("{"),
		"a hunter fight is remembered with the captain's name: %s" % said
	)


## A deal walked from after the whole pay up front (a chronicle line "standing.grudge") becomes
## the captain's memory, and that memory has words on screen (not its bare key).
func _check_broken_deal(company: Company, story: StoryDirector) -> void:
	var deal := {"id": "ctr_walked", "faction": "fac_placeholder_a", "site": "site_1"}
	deal.merge({"reward": 100, "advance": 100, "deadline": 20, "accepted": true})
	company.economy.board.append(deal)
	company.economy.abandon("ctr_walked", company, 6)
	await _frames(LAYOUT_FRAMES)
	var key := "memory.standing.grudge"
	check(
		story.memory.has_key(company.captain_id, key) and Text.t(key) != key,
		"a deal broken at the hub is remembered by the captain, in words"
	)


func _mourn(game: SliceGame, story: StoryDirector) -> void:
	var ids: Array[String] = []
	for merc: Merc in game.company_director().company.roster:
		ids.append(merc.id)
	story.memory.on_death(DEAD, ids, 2, Memory.KEY_COMRADE_DIED)


func _help_hidden(game: SliceGame) -> bool:
	var hud: Variant = game.get("_hud")
	if hud is CanvasLayer:
		var layer: CanvasLayer = hud
		return not layer.visible
	return false


func _check_inspect(game: SliceGame, merc_id: String) -> void:
	await _tap(KEY_ESCAPE)
	await _tap(KEY_C)
	var director := game.company_director()
	await _click_button(director.panel.row_for(merc_id))
	await _frames(LAYOUT_FRAMES)
	var lines := director.panel.lines_text()
	check(
		lines.contains("Memories:") and lines.contains("fell on day"),
		"the inspect screen shows memories"
	)
	check(
		lines.contains("placeholder - the director writes this"),
		"and the storylet's own memory (%s)" % lines
	)


func _check_gui_without_memory() -> void:
	_clear_save()
	var game := await _spawn()
	var story := game.get_node("StoryDirector") as StoryDirector
	await _tap(KEY_M)
	var map := game.overworld_director()
	await _frames(LAYOUT_FRAMES)
	await InputKit.pick_mode(self, map)
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
