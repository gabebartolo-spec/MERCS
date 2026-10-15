class_name TermsPanel
extends RefCounted
## The terms screen (Phase 5 C8, docs/plans/phase5_contracts.md; the talk itself is C2's Terms):
## the player's ask for one posted contract (the price, and how much of it now against the rest
## on return), the merc who steps in once with his odds shown before the roll, and the
## employer's last reply in words with the numbers it was judged on. Pressing Make the offer
## calls Economy.negotiate; nothing here decides a reply or rolls. It words the screen as
## HubPanel rows (left: the ask; right: the employer) and takes the panel's terms buttons; the
## hub shows it in place of the board while a talk is open. Words: data/text/en.json
## "hub.terms.*"; click steps: data/balance/hub.json "terms".

## The panel actions this screen answers (HubPanel names a button "<action>_<id>").
const ACTIONS: Array[String] = ["price", "advance", "speaker", "offer", "counter", "back"]
const UP := "up"
const DOWN := "down"
const NOBODY := "none"
const PERCENT := 100

## The contract being talked over ("" when no talk is open).
var contract_id := ""
## The ask as it stands: the whole price and the coin of it wanted now.
var price := 0
var advance := 0
## The merc picked to step in on the next offer ("" for nobody).
var speaker := ""
## The employer's last reply (Economy.negotiate), {} before the first offer.
var last: Dictionary = {}

var _company: Company = null
var _world: WorldSim = null
var _steps := {}
## The contract as last seen on the board: a walked contract leaves it, and the screen still
## words what was lost.
var _seen: Dictionary = {}


## company: the game's (its economy holds the board); world: where the sites are; steps:
## data/balance/hub.json "terms".
func setup(company: Company, world: WorldSim, steps: Dictionary) -> void:
	_company = company
	_world = world
	_steps = steps


func is_open() -> bool:
	return contract_id != ""


## Opens the talk on a posted contract: the ask starts at the employer's own terms (his counter
## when he made one, else the posted pay, nothing up front).
func open(id: String) -> void:
	var row := _row(id)
	if row.is_empty():
		return
	contract_id = id
	_seen = row.duplicate()
	price = Merc.whole(row.get("counter_price", row.get("reward", 0)))
	advance = Merc.whole(row.get("counter_advance", 0))
	speaker = ""
	last = {}


func close() -> void:
	contract_id = ""
	last = {}


## A terms button was pressed. Returns the reply when an offer was made ("accept", "counter",
## "walk"), else "". rng: the world's Rng ("terms" stream, rolled only by a step-in).
func act(action: String, id: String, rng: Rng, day: int) -> String:
	match action:
		"price":
			_move_price(id == UP)
		"advance":
			_move_advance(id == UP)
		"speaker":
			speaker = "" if id == NOBODY or id == speaker else id
		"counter":
			price = Merc.whole(last.get("counter_price", price))
			advance = Merc.whole(last.get("counter_advance", advance))
			return _offer(rng, day)
		"offer":
			return _offer(rng, day)
		"back":
			close()
	return ""


func _offer(rng: Rng, day: int) -> String:
	_seen = _row(contract_id).duplicate()
	var ask := {"price": price, "advance": advance, "speaker": speaker, "day": day}
	last = _company.economy.negotiate(_company, contract_id, ask, rng)
	speaker = ""
	return str(last.get("reply", ""))


func _move_price(up: bool) -> void:
	var row := _row(contract_id)
	var reward := Merc.whole(row.get("terms_posted", row.get("reward", 0)))
	var step := maxi(1, reward * _step("price_step_pct") / PERCENT)
	price = maxi(step, price + (step if up else -step))
	advance = mini(advance, price)


func _move_advance(up: bool) -> void:
	var step := maxi(1, price * _step("advance_step_pct") / PERCENT)
	advance = clampi(advance + (step if up else -step), 0, price)


## The ask: what the contract is, who posted it and why he pays what he does, the price and
## advance with their buttons, who steps in, and the offer.
func left_rows() -> Array[Dictionary]:
	var row := _row(contract_id)
	var params := _params(row)
	var rows: Array[Dictionary] = [
		HubPanel.line(HubPanel.HEADING, Text.t("hub.terms.title", params)),
		HubPanel.line(HubPanel.LABEL, Text.t("hub.terms.posted", params)),
		HubPanel.line(HubPanel.NOTE, Text.t("hub.terms.employer", params)),
		HubPanel.line(HubPanel.HEADING, Text.t("hub.terms.ask_title")),
		HubPanel.line(HubPanel.LABEL, Text.t("hub.terms.ask", params)),
	]
	var open := _talking(row)
	rows.append(_pair("price", "hub.terms.price_up", "hub.terms.price_down", open))
	rows.append(_pair("advance", "hub.terms.advance_up", "hub.terms.advance_down", open))
	rows.append(HubPanel.line(HubPanel.NOTE, Text.t("hub.terms.advance_note")))
	rows.append(HubPanel.button_row("offer", contract_id, Text.t("hub.terms.offer"), open))
	return rows


## Who steps in, the employer's last reply in words, the step-in's roll, and the way back.
func right_rows() -> Array[Dictionary]:
	var row := _row(contract_id)
	var rows := _speaker_rows(row, _talking(row))
	rows.append(HubPanel.line(HubPanel.HEADING, Text.t("hub.terms.reply_title")))
	var held: Variant = last.get("check", {})
	var check: Dictionary = held if held is Dictionary else {}
	if not check.is_empty():
		rows.append(HubPanel.line(HubPanel.LABEL, _check_words(check)))
	var reply := str(last.get("reply", ""))
	if reply == "":
		rows.append(HubPanel.line(HubPanel.NOTE, Text.t("hub.terms.reply_none")))
	else:
		var params := _params(row)
		params.merge(last, true)
		rows.append(HubPanel.line(HubPanel.LABEL, Text.t("hub.terms.reply." + reply, params)))
		if reply == Terms.COUNTER and _talking(row):
			var take := Text.t("hub.terms.take_counter", params)
			rows.append(HubPanel.button_row("counter", contract_id, take, true))
	rows.append(HubPanel.button_row("back", "board", Text.t("hub.terms.back"), true))
	return rows


## Who steps in: one button per merc with his odds before the roll, and nobody; once a merc
## has spoken on this contract, a line saying so instead.
func _speaker_rows(row: Dictionary, open: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		HubPanel.line(HubPanel.HEADING, Text.t("hub.terms.speaker_title"))
	]
	if row.has("step_in"):
		var spoke := {"name": _company.name_of(str(row["step_in"]))}
		rows.append(HubPanel.line(HubPanel.NOTE, Text.t("hub.terms.speaker_spent", spoke)))
		return rows
	rows.append(HubPanel.line(HubPanel.NOTE, Text.t("hub.terms.speaker_body")))
	var terms := _company.economy.terms
	for merc: Merc in _company.roster:
		var params := {"name": _company.name_of(merc.id), "odds": terms.odds(merc.id)}
		var key := "hub.terms.speaker_picked" if merc.id == speaker else "hub.terms.speaker_pick"
		rows.append(HubPanel.button_row("speaker", merc.id, Text.t(key, params), open))
		if merc.id == speaker:
			var hope := "hub.terms.speaker_hope." + merc.sex
			rows.append(HubPanel.line(HubPanel.NOTE, Text.t(hope, params)))
	var none_key := "hub.terms.speaker_none_picked" if speaker == "" else "hub.terms.speaker_none"
	rows.append(HubPanel.button_row("speaker", NOBODY, Text.t(none_key), open))
	return rows


func _check_words(check: Dictionary) -> String:
	var params := check.duplicate()
	params["name"] = _company.name_of(str(check.get("merc", "")))
	var key := "hub.terms.check_won" if check.get("success") == true else "hub.terms.check_lost"
	return Text.t(key, params)


func _params(row: Dictionary) -> Dictionary:
	var faction := str(row.get("faction", ""))
	var terms := _company.economy.terms
	return {
		"job": Text.t("hub.job." + str(row.get("job", ""))),
		"faction": _company.economy.book.faction_name(faction),
		"site": OverworldMap.site_name(_world.site(str(row.get("site", "")))),
		"reward": Merc.whole(row.get("terms_posted", row.get("reward", 0))),
		"deadline": Merc.whole(row.get("deadline", 0)),
		"reputation": terms.reputation(faction),
		"need": terms.need(faction),
		"price": price,
		"advance": advance,
		"rest": price - advance,
	}


## Whether the contract is still open to talks: on the board and not yet taken.
func _talking(row: Dictionary) -> bool:
	var posted := not _company.economy.book.contract(str(row.get("id", ""))).is_empty()
	return posted and row.get("accepted") != true


## The contract on the board; once it has left (the employer walked), as last seen.
func _row(id: String) -> Dictionary:
	var found := _company.economy.book.contract(id)
	if found.is_empty() and _seen.get("id") == id:
		return _seen
	return found


func _step(key: String) -> int:
	var value: Variant = _steps.get(key)
	return Merc.whole(value) if value is int or value is float else 0


static func _pair(action: String, up_key: String, down_key: String, open: bool) -> Dictionary:
	var items: Array[Dictionary] = [
		HubPanel.button_row(action, DOWN, Text.t(down_key), open),
		HubPanel.button_row(action, UP, Text.t(up_key), open),
	]
	return {"kind": HubPanel.BUTTONS, "items": items}
