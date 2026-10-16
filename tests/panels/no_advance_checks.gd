extends RefCounted
## The terms screen after the company walked out on a faction (tests/run_hub_terms_tests.gd,
## director 2026-10-16 "Walk out, no more advances"). Real clicks at 1920x1080.

const InputKit := preload("res://tests/lib/input_kit.gd")
## Later boards posted while looking for a closed and an open faction contract.
const NO_ADVANCE_BOARDS := 12


## After a walk-out (an abandoned job) on one faction: a contract of that faction shows the
## no-advance line and its advance buttons are off (a click changes nothing); a contract of a
## faction the company did not walk out on shows no line and live buttons.
func run(tree: SceneTree, hub: HubDirector, check: Callable, shot: Callable) -> void:
	var economy := hub.company.economy
	var panel := hub.panel
	var closed_faction := ""
	for faction: String in economy.standing.no_advance:
		closed_faction = faction
	var day := hub.world.day
	var sites: Array[String] = []
	for i: int in range(1, hub.world.sites.size()):
		sites.append(hub.world.sites[i].id)
	var closed_id := ""
	var open_id := ""
	for _tries: int in NO_ADVANCE_BOARDS:
		closed_id = ""
		open_id = ""
		for row: Dictionary in economy.board:
			var id := str(row["id"])
			if str(row.get("faction", "")) == closed_faction and closed_id == "":
				closed_id = id
			elif str(row.get("faction", "")) != closed_faction and open_id == "":
				open_id = id
		if closed_id != "" and open_id != "":
			break
		day += 1
		economy.refresh_board(day, sites, hub.rng)
	hub.set_open(true)
	await InputKit.frames(tree, InputKit.LAYOUT_FRAMES)
	var line := Text.t("hub.terms.no_advance")
	var ok := closed_faction != "" and closed_id != "" and open_id != ""
	if ok:
		await _click(tree, panel, ContractRows.TALK, closed_id)
		var up := panel.button_for("advance", TermsPanel.UP)
		var down := panel.button_for("advance", TermsPanel.DOWN)
		await shot.call("10_terms_no_advance")
		var shown_closed := panel.shown_text().contains(line)
		var off := up != null and down != null and up.disabled and down.disabled
		await _click(tree, panel, "advance", TermsPanel.UP)
		var still_none := hub.talk.advance == 0
		await _click(tree, panel, "back", "board")
		await _click(tree, panel, ContractRows.TALK, open_id)
		up = panel.button_for("advance", TermsPanel.UP)
		down = panel.button_for("advance", TermsPanel.DOWN)
		await shot.call("11_terms_advance_open")
		var shown_open := panel.shown_text().contains(line)
		var live := up != null and down != null and not up.disabled and not down.disabled
		await _click(tree, panel, "advance", TermsPanel.UP)
		var moved := hub.talk.advance > 0
		await _click(tree, panel, "back", "board")
		ok = shown_closed and off and still_none and not shown_open and live and moved
	var words := "after a walk-out on %s: the terms say %s, advance buttons off; open ones do not"
	check.call(ok, words % [closed_faction, line])


func _click(tree: SceneTree, panel: HubPanel, action: String, id: String) -> void:
	await InputKit.click(tree, panel.button_for(action, id))
