extends RefCounted
## The terms screen after the company walked out on a faction (tests/run_hub_terms_tests.gd,
## director 2026-10-16 "Walk out, no more advances"). Real clicks at 1920x1080.

const InputKit := preload("res://tests/lib/input_kit.gd")
## Later boards posted while looking for a closed and an open faction contract.
const NO_ADVANCE_BOARDS := 12

var _tree: SceneTree = null
var _hub: HubDirector = null
var _panel: HubPanel = null
var _shot: Callable
var _closed := ""
var _closed_id := ""
var _open_id := ""


## After a walk-out (an abandoned job) on one faction: a contract of that faction shows the
## no-advance line and its advance buttons are off (a click changes nothing); a contract of a
## faction the company did not walk out on shows no line and live buttons.
func run(tree: SceneTree, hub: HubDirector, check: Callable, shot: Callable) -> void:
	_tree = tree
	_hub = hub
	_panel = hub.panel
	_shot = shot
	for faction: String in hub.company.economy.standing.no_advance:
		_closed = faction
	_find_contracts()
	hub.set_open(true)
	await InputKit.frames(tree, InputKit.LAYOUT_FRAMES)
	var ok := _closed != "" and _closed_id != "" and _open_id != ""
	if ok:
		var closed_ok := await _closed_screen()
		var open_ok := await _open_screen()
		ok = closed_ok and open_ok
	var words := "after a walk-out on %s: the terms say %s, advance buttons off; open ones do not"
	check.call(ok, words % [_closed, Text.t("hub.terms.no_advance")])


## One posted contract of the closed faction and one of another (later boards if need be).
func _find_contracts() -> void:
	var economy := _hub.company.economy
	var day := _hub.world.day
	var sites: Array[String] = []
	for i: int in range(1, _hub.world.sites.size()):
		sites.append(_hub.world.sites[i].id)
	for _tries: int in NO_ADVANCE_BOARDS:
		_closed_id = ""
		_open_id = ""
		for row: Dictionary in economy.board:
			_note(row)
		if _closed_id != "" and _open_id != "":
			return
		day += 1
		economy.refresh_board(day, sites, _hub.rng)


func _note(row: Dictionary) -> void:
	var id := str(row["id"])
	var closed := str(row.get("faction", "")) == _closed
	if closed and _closed_id == "":
		_closed_id = id
	elif not closed and _open_id == "":
		_open_id = id


## The closed faction's terms: the line shows, both advance buttons are off, a click is nothing.
func _closed_screen() -> bool:
	await _click(ContractRows.TALK, _closed_id)
	var up := _panel.button_for("advance", TermsPanel.UP)
	var down := _panel.button_for("advance", TermsPanel.DOWN)
	await _shot.call("10_terms_no_advance")
	var shown := _panel.shown_text().contains(Text.t("hub.terms.no_advance"))
	var off := up != null and down != null and up.disabled and down.disabled
	await _click("advance", TermsPanel.UP)
	var none := _hub.talk.advance == 0
	await _click("back", "board")
	return shown and off and none


## An open faction's terms: no line, live buttons, a click moves the advance.
func _open_screen() -> bool:
	await _click(ContractRows.TALK, _open_id)
	var up := _panel.button_for("advance", TermsPanel.UP)
	var down := _panel.button_for("advance", TermsPanel.DOWN)
	await _shot.call("11_terms_advance_open")
	var shown := _panel.shown_text().contains(Text.t("hub.terms.no_advance"))
	var live := up != null and down != null and not up.disabled and not down.disabled
	await _click("advance", TermsPanel.UP)
	var moved := _hub.talk.advance > 0
	await _click("back", "board")
	return not shown and live and moved


func _click(action: String, id: String) -> void:
	await InputKit.click(_tree, _panel.button_for(action, id))
