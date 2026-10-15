extends "res://tests/lib/runner.gd"
## Hub suite (Phase 2 milestone 6: HubDirector, HubPanel, B). Real input reaches the game
## through Input.parse_input_event at 1920x1080: a real B opens the hub with wages, a contract
## board, three recruits and the pack, and walking pauses; real rest clicks on the map make
## wages fall due and a real click pays them; real clicks talk a contract's terms and take it,
## inspect and hire
## a placeholder recruit (the F4 company shows the hire); a won fight (the world's result
## applied) opens the hub on the loot line and the prisoner's four buttons, and a real click
## on one decides it and shows the line the captain remembers; the wearer button and an equip
## click put gear on a merc and the battle numbers follow; away from the hub the wages,
## contracts and recruits give way to a line saying so; every button sits on the 1920x1080
## screen; the overworld's Save writes the economy and a fresh session reads it. Seeded: world.json.
##   godot --headless --path . --script tests/run_hub_tests.gd

const InputKit := preload("res://tests/lib/input_kit.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const WORLD_BALANCE := "res://data/balance/world.json"
const ECONOMY := "res://data/balance/economy.json"
const WINDOW_SIZE := Vector2i(1920, 1080)
const LAYOUT_FRAMES := 3
const HOLD_FRAMES := 30
const REST_DAYS := 3
const HAMLET := "site_hamlet_1"
const BLADE := "wpn_iron_blade"
const SAVE_SYSTEM := preload("res://presentation/autoload/save_system.gd")

var _game: SliceGame = null


func suite_name() -> String:
	return "Hub"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	_clear_save()
	_game = await _spawn()
	await _check_open()
	await _check_wages_by_clicks()
	await _check_contract_and_hire()
	await _check_win_opens_prisoner()
	await _check_equip()
	await _check_prisoner_click()
	await _check_away()
	await _check_save()
	_game.queue_free()
	await process_frame
	_clear_save()


func _spawn() -> SliceGame:
	var packed: PackedScene = load(SLICE_SCENE) as PackedScene
	var game: SliceGame = packed.instantiate() as SliceGame
	root.add_child(game)
	await process_frame
	return game


func _hub() -> HubDirector:
	return _game.hub_director()


func _economy() -> Economy:
	return _hub().company.economy


func _rules() -> Dictionary:
	return _json(ECONOMY)


func _w(value: Variant) -> int:
	return Merc.whole(value)


func _check_open() -> void:
	await _tap(KEY_B)
	await _frames(LAYOUT_FRAMES)
	var panel := _hub().panel
	var economy := _economy()
	var accepts := _count(ContractRows.TALK, economy.board)
	var hires := _count("hire", economy.offers())
	var start := _game.player.cell
	await _hold(KEY_D)
	check(
		(
			_game.hub_open()
			and panel.is_visible_in_tree()
			and panel.shown_text().contains(Text.t("hub.wages.clear"))
			and panel.shown_text().contains(Text.t("hub.status", _status()))
			and accepts == economy.board.size()
			and not economy.board.is_empty()
			and hires == _w(_rules()["recruits"]["offers"])
			and panel.shown_text().contains(Text.t("hub.pack.empty"))
			and _game.player.cell == start
		),
		(
			"B opens the hub: wages paid up, %d contracts, %d recruits, an empty pack; walking waits"
			% [accepts, hires]
		)
	)


## How many of these records (each with an "id") have a button for the action.
func _count(action: String, records: Array[Dictionary]) -> int:
	var found := 0
	for record: Dictionary in records:
		found += 1 if _hub().panel.button_for(action, str(record["id"])) != null else 0
	return found


func _status() -> Dictionary:
	return {"purse": _economy().purse, "morale": _economy().morale}


func _rest_on_the_map() -> void:
	await _tap(KEY_ESCAPE)
	await _tap(KEY_M)
	var map_panel := _game.overworld_director().panel
	await InputKit.pick_mode(self, _game.overworld_director())
	for _day: int in REST_DAYS:
		await _click_button(map_panel.button_for(OverworldDirector.REST))
	await _tap(KEY_M)
	await _tap(KEY_B)
	await _frames(LAYOUT_FRAMES)


func _check_wages_by_clicks() -> void:
	await _rest_on_the_map()
	var panel := _hub().panel
	var economy := _economy()
	var rules := _rules()
	var per_day := economy.wage_per_day(_hub().company.roster)
	var owed_words := Text.t(
		"hub.wages.owed",
		{"owed": per_day * REST_DAYS, "per_day": per_day, "count": 6, "days": REST_DAYS}
	)
	var pay := panel.button_for("pay", "wages")
	check(
		(
			economy.owed == per_day * REST_DAYS
			and panel.shown_text().contains(owed_words)
			and pay != null
			and not pay.disabled
		),
		(
			"%d rest clicks on the map make %d coin of wages fall due, shown with a Pay button"
			% [REST_DAYS, per_day * REST_DAYS]
		)
	)
	var purse := economy.purse
	var low := economy.morale
	await _click_button(pay)
	check(
		(
			economy.owed == 0
			and economy.purse == purse - per_day * REST_DAYS
			and economy.morale == low + _w(rules["wages"]["paid_recovery"])
			and panel.shown_text().contains(Text.t("hub.wages.clear"))
			and panel.button_for("pay", "wages") == null
		),
		"a real click on Pay takes the wages from the purse, lifts morale, and the line clears"
	)


func _check_contract_and_hire() -> void:
	var panel := _hub().panel
	var economy := _economy()
	var id := str(economy.board[0]["id"])
	await _click_button(panel.button_for(ContractRows.TALK, id))
	await _click_button(panel.button_for("offer", id))
	await _click_button(panel.button_for("back", "board"))
	check(
		(
			str(economy.book.contract(id)["accepted"]) == "true"
			and panel.button_for(ContractRows.TALK, id) == null
			and panel.button_for(ContractRows.ABANDON, id) != null
		),
		"real clicks talk a contract's terms and offer the posted pay: it is taken, walk-away shown"
	)
	await _click_button(panel.button_for("inspect", "recruit_1"))
	check(
		(
			panel.shown_text().contains(Text.t("company.placeholder"))
			and panel.shown_text().contains("To be written by the director")
			and _hub().company.member("recruit_1") == null
		),
		"a real click on Inspect shows the placeholder recruit's lines without hiring them"
	)
	var purse := economy.purse
	await _click_button(panel.button_for("hire", "recruit_1"))
	var company_panel := _game.company_director().panel
	_game.company_director().set_open(true)
	await _frames(LAYOUT_FRAMES)
	check(
		(
			_hub().company.roster.size() == 7
			and economy.purse == purse - economy.hire_cost()
			and panel.button_for("hire", "recruit_1") == null
			and company_panel.row_for("recruit_1") != null
		),
		"a real click on Hire spends the cost and the hire is on the F4 roster"
	)
	_game.company_director().set_open(false)


## The world applies a won fight with a surrender, as the overworld does: loot and a prisoner.
func _check_win_opens_prisoner() -> void:
	await _tap(KEY_ESCAPE)
	var world := _hub().world
	world.encounter = {"type": "patrol", "from": world.at, "to": world.at, "days_left": 0}
	var purse := _economy().purse
	world.resolve_encounter({"won": true, "surrendered": true, "prisoners": ["watchman_0"]})
	await _frames(LAYOUT_FRAMES)
	var panel := _hub().panel
	var loot := _economy().last_loot
	var line_words := Text.t("hub.loot").substr(0, Text.t("hub.loot").find("{"))
	check(
		(
			_game.hub_open()
			and _economy().purse == purse + _w(loot["coin"])
			and panel.shown_text().contains(line_words)
			and panel.shown_text().contains(str(_w(loot["coin"])) + " coin")
			and not _economy().prisoner.is_empty()
			and _prisoner_buttons() == Economy.CHOICES.size()
		),
		(
			"a won fight opens the hub on the loot line and the prisoner's %d buttons"
			% Economy.CHOICES.size()
		)
	)
	await _check_all_on_screen()


func _prisoner_buttons() -> int:
	var found := 0
	for choice: String in Economy.CHOICES:
		found += 1 if _hub().panel.button_for("prisoner", choice) != null else 0
	return found


func _check_all_on_screen() -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE))
	var off: Array[String] = []
	for action: String in [
		"pay", "talk", "abandon", "inspect", "hire", "prisoner", "equip", "wearer"
	]:
		for id: String in _ids():
			var button := _hub().panel.button_for(action, id)
			if button != null and not screen.encloses(button.get_global_rect()):
				off.append("%s_%s" % [action, id])
	check(off.is_empty(), "every hub button sits on the 1920x1080 screen, off: %s" % [off])


func _ids() -> Array[String]:
	var ids: Array[String] = ["wages", "next", BLADE]
	ids.append_array(Economy.CHOICES)
	for def: Dictionary in _economy().offers():
		ids.append(str(def["id"]))
	for row: Dictionary in _economy().board:
		ids.append(str(row["id"]))
	return ids


func _check_equip() -> void:
	var economy := _economy()
	economy.inventory.append(BLADE)
	_hub().set_open(true)
	await _frames(LAYOUT_FRAMES)
	var panel := _hub().panel
	var company := _hub().company
	var ids: Array[String] = ["vampyr"]
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var before := company.battle_units(ids, cells, BattleUnit.COMPANY)[0].damage
	await _click_button(panel.button_for("wearer", "next"))
	var wearer_words := Text.t("hub.wearer", {"name": company.member("vampyr").display_name})
	var named := panel.button_for("wearer", "next").text == wearer_words
	await _click_button(panel.button_for("equip", BLADE))
	var after := company.battle_units(ids, cells, BattleUnit.COMPANY)[0].damage
	check(
		(
			named
			and str(company.member("vampyr").gear["weapon"]) == BLADE
			and after == before + 1
			and not economy.inventory.has(BLADE)
			and panel.button_for("equip", BLADE) == null
		),
		(
			"the wearer button names the next merc and Equip puts the blade on him: damage %d to %d"
			% [before, after]
		)
	)


func _check_prisoner_click() -> void:
	var economy := _economy()
	var company := _hub().company
	var roster := company.roster.size()
	var morale := economy.morale
	await _click_button(_hub().panel.button_for("prisoner", Economy.RECRUIT))
	var line := Text.t(
		"hub.memory.prisoner.recruit", {"name": company.member(company.captain_id).display_name}
	)
	check(
		(
			company.roster.size() == roster + 1
			and economy.morale == morale + _w(_rules()["prisoner"]["recruit_morale"])
			and economy.prisoner.is_empty()
			and _hub().panel.shown_text().contains(line)
			and _prisoner_buttons() == 0
		),
		"a real click on Recruit adds a placeholder, lifts morale and shows the line remembered"
	)


func _check_away() -> void:
	_hub().world.at = HAMLET
	_hub().set_open(true)
	await _frames(LAYOUT_FRAMES)
	var panel := _hub().panel
	var board_id := str(_economy().board[0]["id"])
	check(
		(
			panel.shown_text().contains(Text.t("hub.away"))
			and panel.button_for(ContractRows.TALK, board_id) == null
			and panel.button_for("hire", "recruit_2") == null
			and panel.button_for("pay", "wages") == null
		),
		"away from the hub there are no wages, contracts or recruits to act on, only a line saying so"
	)
	_hub().world.at = RegionGen.HUB_ID
	await _tap(KEY_B)


func _check_save() -> void:
	await _tap(KEY_M)
	await _click_button(_game.overworld_director().panel.button_for(OverworldDirector.SAVE))
	var model := _saves().load_game(_json(WORLD_BALANCE), CompanyDirector.defs())
	var saved := _economy()
	check(
		(
			model.ok
			and model.company != null
			and model.company.economy.purse == saved.purse
			and model.company.economy.morale == saved.morale
			and model.company.economy.hired == saved.hired
			and model.company.economy.board.size() == saved.board.size()
			and model.company.member("recruit_1") != null
			and str(model.company.member("vampyr").gear["weapon"]) == BLADE
		),
		"the overworld's Save writes the economy: purse, morale, hires, board and the blade"
	)
	await _tap(KEY_M)


func _saves() -> SAVE_SYSTEM:
	return root.get_node(^"SaveSystem") as SAVE_SYSTEM


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_SYSTEM.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_SYSTEM.SAVE_PATH))


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


func _click_button(button: Button) -> void:
	await InputKit.click(self, button)


func _press_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _tap(code: Key) -> void:
	await _press_key(code, true)
	await _press_key(code, false)


func _hold(code: Key) -> void:
	await _press_key(code, true)
	await _frames(HOLD_FRAMES)
	await _press_key(code, false)
