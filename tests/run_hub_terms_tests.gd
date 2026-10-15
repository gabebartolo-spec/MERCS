extends "res://tests/lib/runner.gd"
## Hub terms suite (Phase 5 C8: TermsPanel, ContractRows, WageRows on HubPanel). Real input
## reaches the game through Input.parse_input_event at 1920x1080, each click at the control's
## screen centre (InputKit.click): the board names each contract's job; a click opens the terms
## screen with the posted pay as the ask and each merc's step-in odds shown before any roll (the
## Vampyr's bargaining trait from data/traits.json reaches the live game: his odds beat a merc
## without one); asking past the paymaster's limit brings a counter in words and the contract
## stays posted; picking the Vampyr and taking the counter rolls his step-in, shows the roll and
## spends his turn; asking far past the limit makes the paymaster walk (the contract leaves the
## board, the name falls); an accepted offer with half the pay up front takes the contract as a
## job (its party on the map or its hold begun, the company remembers it); walking away from it
## asks first, then grows the faction's grudge and shows the captain's line; a rested day shows
## each merc's wage and what he is owed; a prisoner decided with no captain in office names
## nobody and does not crash; the armoury hook takes its own button's click; every button sits
## on the screen. Seeded: data/balance/world.json.
##   godot --headless --path . --script tests/run_hub_terms_tests.gd
## Captures of each screen (a rendering run, not headless; the director's look review):
##   godot --path . --resolution 1920x1080 --script tests/run_hub_terms_tests.gd -- --shots=<dir>

const InputKit := preload("res://tests/lib/input_kit.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const WINDOW_SIZE := Vector2i(1920, 1080)
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")
## The merc whose placeholder bargaining trait is the strongest (data/traits.json).
const TALKER := "vampyr"
## A merc with no bargaining trait.
const PLAIN := "merc_3"
## Ask-more clicks that carry the ask past the limit (a counter) and far past it (a walk).
const COUNTER_CLICKS := 3
const WALK_CLICKS := 10
## More-now clicks that make the advance half the price (a sizeable advance, Q-16).
const HALF_CLICKS := 2
const ARMOURY_ID := "armoury_test"
const SHOTS_ARG := "--shots="

var _game: SliceGame = null
var _armoury_hits: Array[String] = []


func suite_name() -> String:
	return "HubTerms"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	if _shots_dir() != "":
		# The desktop trims a window by its frame: ask for that much more so the picture is
		# exactly 1920x1080.
		root.borderless = true
		await process_frame
		root.size = WINDOW_SIZE * 2 - root.size
	_clear_save()
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	_game = packed.instantiate() as SliceGame
	root.add_child(_game)
	await process_frame
	await _open_hub()
	_ensure_two_contracts()
	await _check_board_names_jobs()
	var first := str(_economy().board[0]["id"])
	var second := str(_economy().board[1]["id"])
	await _check_terms_screen(first)
	await _check_counter(first)
	await _check_step_in(first)
	await _check_walk(first)
	await _check_accept(second)
	await _check_abandon(second)
	await _check_wages()
	await _check_prisoner_without_captain()
	await _check_armoury_hook()
	_game.queue_free()
	await process_frame
	_clear_save()


func _hub() -> HubDirector:
	return _game.hub_director()


func _economy() -> Economy:
	return _hub().company.economy


func _panel() -> HubPanel:
	return _hub().panel


func _click(action: String, id: String) -> void:
	await InputKit.click(self, _panel().button_for(action, id))


func _open_hub() -> void:
	await InputKit.tap(self, KEY_B)
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)


## The board a seed posts can hold one contract; the suite needs two, so it posts again (a
## later board, same streams) until it has them.
func _ensure_two_contracts() -> void:
	var hub := _hub()
	var day := hub.world.day
	var sites: Array[String] = []
	for i: int in range(1, hub.world.sites.size()):
		sites.append(hub.world.sites[i].id)
	while _economy().board.size() < 2:
		day += 1
		_economy().refresh_board(day, sites, hub.rng)
	hub.set_open(true)


func _job_words(row: Dictionary) -> String:
	var template := _economy().book.job_template(str(row.get("job", "")))
	return Text.t(str(template.get("words", "")))


func _check_board_names_jobs() -> void:
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	var named := 0
	var shown: Array[String] = []
	for label: Node in _panel().find_children("*", "Label", true, false):
		shown.append((label as Label).text)
	for row: Dictionary in _economy().board:
		var button := _panel().button_for(ContractRows.TALK, str(row["id"]))
		var line := Text.t(
			"hub.contract.posted", ContractRows.words(_hub().company, _hub().world, row)
		)
		var own := button != null and button.text == Text.t("hub.contract.talk")
		if own and line.begins_with(_job_words(row)) and line in shown:
			named += 1
	var count := _economy().board.size()
	check(
		named == count and named >= 2,
		"the board words each job, Talk terms its own button: %d of %d" % [named, count]
	)
	_check_on_screen("board")
	await _shot("1_board")


func _check_terms_screen(id: String) -> void:
	await _click(ContractRows.TALK, id)
	var terms := _economy().terms
	var talker := _panel().button_for("speaker", TALKER)
	var talker_odds := terms.odds(TALKER)
	var reward := Merc.whole(_economy().book.contract(id)["reward"])
	check(
		(
			_hub().talk.is_open()
			and _hub().talk.price == reward
			and _hub().talk.advance == 0
			and talker != null
			and talker.text.contains("%d%%" % talker_odds)
			and talker_odds > terms.odds(PLAIN)
			and _panel().shown_text().contains(Text.t("hub.terms.reply_none"))
			and _panel().button_for(ContractRows.TALK, id) == null
		),
		(
			(
				"a click on a contract opens its terms: ask %d (the posted pay), the Vampyr's odds %d%%"
				% [reward, talker_odds]
			)
			+ (
				" shown before any roll against %d%% for a merc without a bargaining trait"
				% terms.odds(PLAIN)
			)
		)
	)
	_check_on_screen("terms")
	await _shot("2_terms_open")


func _check_counter(id: String) -> void:
	for _click_count: int in COUNTER_CLICKS:
		await _click("price", TermsPanel.UP)
	await _click("offer", id)
	var last := _hub().talk.last
	var words := Text.t("hub.terms.reply.counter", last)
	check(
		(
			str(last.get("reply", "")) == Terms.COUNTER
			and _panel().shown_text().contains(words)
			and _panel().button_for("counter", id) != null
			and str(_economy().book.contract(id).get("accepted")) != "true"
		),
		(
			"asking %d clicks past the posted pay brings a counter in words: %s"
			% [COUNTER_CLICKS, words]
		)
	)


func _check_step_in(id: String) -> void:
	await _click("speaker", TALKER)
	var picked := _panel().button_for("speaker", TALKER).text
	await _shot("3_counter_talker_picked")
	var lines := _economy().chronicle.size()
	await _click("counter", id)
	var check_row: Dictionary = _hub().talk.last.get("check", {})
	var spoke := Text.t("hub.terms.speaker_spent", {"name": _hub().company.name_of(TALKER)})
	var entry: Dictionary = _economy().chronicle[-1] if _economy().chronicle.size() > lines else {}
	await _shot("4_step_in_rolled")
	check(
		(
			picked.contains("%d%%" % _economy().terms.odds(TALKER))
			and str(check_row.get("merc", "")) == TALKER
			and _panel().shown_text().contains("rolled %d" % Merc.whole(check_row.get("roll", -1)))
			and _panel().shown_text().contains(spoke)
			and _panel().button_for("speaker", TALKER) == null
			and str(entry.get("merc", "")) == TALKER
		),
		(
			"the Vampyr steps in on a click: rolled %s, needed %s, %s; his turn is spent and remembered"
			% [check_row.get("roll"), check_row.get("need"), _hub().talk.last.get("reply")]
		)
	)


func _check_walk(id: String) -> void:
	var talk := _hub().talk
	if talk.last.get("reply") == Terms.ACCEPT:
		push_error("the step-in took the contract: no walk to show on this seed")
	var faction := str(_economy().book.contract(id).get("faction", ""))
	var name_before := _economy().standing.reputation(faction)
	for _click_count: int in WALK_CLICKS:
		await _click("price", TermsPanel.UP)
	await _click("offer", id)
	await _shot("5_walked")
	check(
		(
			str(talk.last.get("reply", "")) == Terms.WALK
			and _economy().book.contract(id).is_empty()
			and _economy().standing.reputation(faction) < name_before
			and _panel().shown_text().contains(_lead("hub.terms.reply.walk"))
			and _panel().button_for("offer", id).disabled
		),
		"asking far past the limit makes the paymaster walk: the contract leaves, the name falls"
	)
	await _click("back", "board")


func _check_accept(id: String) -> void:
	await _click(ContractRows.TALK, id)
	for _click_count: int in HALF_CLICKS:
		await _click("advance", TermsPanel.UP)
	var purse := _economy().purse
	await _click("offer", id)
	if str(_hub().talk.last.get("reply", "")) == Terms.COUNTER:
		await _click("counter", id)
	var asked := _hub().talk.advance
	await _shot("6_accepted")
	var row := _economy().book.contract(id)
	var shared := StoryDirector.memory_of(_hub())
	var remembered := (
		shared == null
		or shared.of(_hub().company.captain_id).any(
			func(m: Dictionary) -> bool: return str(m.get("key")) == Memory.KEY_CONTRACT
		)
	)
	check(
		(
			str(_hub().talk.last.get("reply", "")) == Terms.ACCEPT
			and str(row.get("accepted")) == "true"
			and (row.has("job_party") or row.has("held"))
			and _economy().purse == purse + asked
			and remembered
		),
		(
			"an offer with %d of %d up front, accepted, takes the contract as a job (%s started)"
			% [asked, Merc.whole(row.get("reward", 0)), row.get("job")]
		)
	)
	await _click("back", "board")


func _check_abandon(id: String) -> void:
	var row := _economy().book.contract(id)
	var faction := str(row.get("faction", ""))
	await _click(ContractRows.ABANDON, id)
	var params := ContractRows.words(_hub().company, _hub().world, row)
	var warned := (
		_panel().shown_text().contains(Text.t("hub.abandon.warn", params))
		and _panel().shown_text().contains(Text.t("hub.abandon.grudge", params))
		and not _economy().book.contract(id).is_empty()
	)
	_check_on_screen("abandon")
	await _shot("7_abandon_asked")
	await _click(ContractRows.ABANDON_YES, id)
	var captain := _hub().company.name_of(_hub().company.captain_id)
	var line := Text.t("hub.memory.standing.grudge", {"name": captain})
	await _shot("8_abandoned")
	check(
		(
			warned
			and _economy().book.contract(id).is_empty()
			and not _economy().standing.grudge(faction).is_empty()
			and _panel().shown_text().contains(line)
		),
		"walking away asks first and says the grudge; a click on Walk away grows it: %s" % line
	)


func _check_wages() -> void:
	await InputKit.tap(self, KEY_ESCAPE)
	await InputKit.tap(self, KEY_M)
	var map := _game.overworld_director()
	await InputKit.pick_mode(self, map)
	await InputKit.click(self, map.panel.button_for(OverworldDirector.REST))
	await InputKit.tap(self, KEY_M)
	await _open_hub()
	var company := _hub().company
	var captain := company.member(company.captain_id)
	var due := Merc.whole(_economy().payroll.dues.get(captain.id, 0))
	var params := {
		"name": company.name_of(captain.id),
		"level": captain.level(),
		"wage": _economy().payroll.day_wage(captain),
		"due": due,
	}
	var line := Text.t("hub.wages.merc_owed", params)
	check(
		due > 0 and _panel().shown_text().contains(line),
		"a rested day shows each merc's wage by level and what he is owed: %s" % line
	)


func _check_prisoner_without_captain() -> void:
	var company := _hub().company
	_economy().captives.take(_hub().world.day)
	var office := company.captain_id
	company.captain_id = ""
	_hub().set_open(true)
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	await _shot("9_wages_dues_prisoner")
	await _click("prisoner", Economy.RELEASE)
	var line := Text.t("hub.memory.prisoner.release", {"name": ""})
	check(
		_economy().prisoner.is_empty() and _panel().shown_text().contains(line),
		"a prisoner let go with no captain in office names nobody and does not crash"
	)
	company.captain_id = office


func _check_armoury_hook() -> void:
	var hub := _hub()
	hub.armoury_rows = func() -> Array[Dictionary]:
		return [HubPanel.button_row(ARMOURY_ID, "open", "armoury", true)]
	hub.armoury_act = func(action: String, id: String) -> void: _armoury_hits.append(action + id)
	hub.set_open(true)
	await _click(ARMOURY_ID, "open")
	check(
		_armoury_hits == [ARMOURY_ID + "open"],
		"the armoury hook's own button takes a real click: %s" % [_armoury_hits]
	)
	hub.armoury_rows = Callable()
	hub.armoury_act = Callable()


## Every button the hub shows sits inside the 1920x1080 screen.
func _check_on_screen(screen: String) -> void:
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	var view := Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE))
	var off: Array[String] = []
	var total := 0
	for node: Node in _panel().find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_queued_for_deletion() or not button.is_visible_in_tree():
			continue
		total += 1
		if not view.encloses(button.get_global_rect()):
			off.append(str(button.name))
	check(
		off.is_empty() and total > 0,
		"the %s screen's %d buttons sit on the 1920x1080 screen, off: %s" % [screen, total, off]
	)


## Saves the screen as <name>.png when the run was given --shots=<dir> (and renders).
func _shot(shot_name: String) -> void:
	if _shots_dir() == "":
		return
	await InputKit.frames(self, InputKit.LAYOUT_FRAMES)
	var image := root.get_texture().get_image()
	image.save_png(_shots_dir().path_join(shot_name + ".png"))


func _shots_dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SHOTS_ARG):
			return arg.trim_prefix(SHOTS_ARG)
	return ""


## A text's words before its first {placeholder}.
func _lead(key: String) -> String:
	var words := Text.t(key)
	return words.substr(0, words.find("{"))


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))
