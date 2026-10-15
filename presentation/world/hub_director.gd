class_name HubDirector
extends Node
## The hub on screen (Phase 2 milestone 6): wages due and paid, the contract board, the
## placeholder recruits to inspect and hire, the pack of generic gear to put on a merc, and
## after a won fight on the road the loot line and each prisoner's three fates. The Economy
## (held by the Company) and the WorldSim are the sim's and shared with the rest of the game;
## this registers two small hooks on the world (a day passes; a fight's result is applied),
## words what the sim decides (Text.t, data/text/en.json) and shows it in HubPanel. Wages,
## contracts and hiring are done at the hub only; the pack and a prisoner anywhere. Hiding the
## panel (set_open) keeps everything as it is.
## Phase 5 C8: the board names each contract's job and its pay is talked over on the terms
## screen (TermsPanel) before it is taken; a taken contract can be walked away from
## (ContractRows); wages and dues are shown by merc (WageRows). The armoury (C6) plugs in
## through `armoury_rows` and `armoury_act`.

## The hub's actions that commit a decision: under Ironman each is saved at once (`autosave`).
const COMMITS: Array[String] = ["pay", "hire", "equip", "prisoner", ContractRows.ABANDON_YES]
## Panel actions that begin with this go to the armoury hook.
const ARMOURY := "armoury"
const HUB_DATA := "res://data/balance/hub.json"

var company: Company = null
var world: WorldSim = null
var rng: Rng = null
var panel: HubPanel = null
## The contracts' jobs on the map (Phase 5 C1): placed when a contract is taken, judged after
## every day and every fight.
var jobs: Jobs = null
## The overworld's autosave (OverworldDirector.autosave: writes only under Ironman), called after
## each committed action so a quit cannot give the decision back (D-087).
var autosave := Callable()
## The terms screen: open while a contract's pay is being talked over.
var talk := TermsPanel.new()
## The armoury screen (Phase 5 C6, built apart): `armoury_rows` returns its rows for the right
## column; `armoury_act` takes (action, id) for every panel action that begins "armoury".
## Unset, the hub has no armoury.
var armoury_rows := Callable()
var armoury_act := Callable()

var _layer: CanvasLayer = null
var _inspected := ""
var _wearer := ""
var _reaction := ""
## The taken contract whose walking away is being asked about ("" for none).
var _confirm := ""
var _share_pct := 0


## Builds the hub for the game's company and world (its overworld must exist), hooked to the
## world's days and fights, hidden, owned by `game`. An empty board is posted at once.
static func attach(game: SliceGame) -> HubDirector:
	var hub := HubDirector.new()
	game.add_child(hub)
	var map := game.overworld_director()
	hub.begin(game.company_director().company, map.world, map.rng)
	hub.autosave = map.autosave
	return hub


func begin(shared: Company, sim: WorldSim, stream: Rng) -> void:
	company = shared
	world = sim
	rng = stream
	_wearer = company.captain_id
	world.day_hook = _on_day
	world.result_hook = _on_result
	var found: Variant = OverworldDirector.world_data().get("jobs", {})
	var knobs: Dictionary = found if found is Dictionary else {}
	jobs = Jobs.make(world, company, knobs)
	talk.setup(company, world, _block(_read(HUB_DATA), "terms"))
	var wages := _block(_read(CompanyDirector.ECONOMY_DATA), "wages")
	_share_pct = Merc.whole(wages.get("share_pct", 0))
	if company.economy.board.is_empty():
		company.economy.refresh_board(world.day, _site_ids(), rng)
	_layer = CanvasLayer.new()
	_layer.layer = 2
	add_child(_layer)
	panel = HubPanel.new()
	_layer.add_child(panel)
	panel.acted.connect(_on_action)
	set_open(false)


func is_open() -> bool:
	return _layer != null and _layer.visible


## Shows the hub (redrawn) or hides it; nothing is lost either way.
func set_open(open: bool) -> void:
	if _layer == null:
		return
	_layer.visible = open
	talk.close()
	_confirm = ""
	if open:
		_show()


func economy() -> Economy:
	return company.economy


func _on_day(day: int) -> void:
	_judge().on_day(day)
	company.economy.on_day(company.roster, day, _site_ids(), rng)
	if is_open():
		_show()


## A fight's result was applied: a win leaves loot, and the men the enemy surrendered as
## prisoners (EncounterBattle.result "prisoners"; a wipe or a rout leaves none: Phase 4 ruling
## Q-C; Phase 5 C5), and opens the hub.
func _on_result(kind: String, result: Dictionary) -> void:
	_judge().on_result(result)
	if result.get("won", false) != true:
		return
	company.economy.take_loot(kind, rng)
	var taken := EncounterBattle.taken(result)
	if not taken.is_empty():
		company.economy.captives.take(world.day, taken)
	_reaction = ""
	set_open(true)


func _on_action(action: String, id: String) -> void:
	if _routed(action, id):
		return
	var economy := company.economy
	match action:
		"pay":
			economy.pay_wages()
		"inspect":
			_inspected = id
		"hire":
			economy.hire(company, id)
		"wearer":
			_next_wearer()
		"equip":
			economy.equip(company, _wearer, id)
		"prisoner":
			_decide(id)
		"close":
			set_open(false)
			return
	if action in COMMITS and autosave.is_valid():
		autosave.call()
	_show()


## The buttons another screen answers: the terms screen's while a talk is open (true: it has
## redrawn), the armoury hook's, and the board's contract buttons.
func _routed(action: String, id: String) -> bool:
	if talk.is_open() and action in TermsPanel.ACTIONS:
		_on_terms(action, id)
		return true
	if action.begins_with(ARMOURY) and armoury_act.is_valid():
		armoury_act.call(action, id)
	match action:
		ContractRows.TALK:
			talk.open(id)
		ContractRows.ABANDON:
			_confirm = id
		ContractRows.ABANDON_NO:
			_confirm = ""
		ContractRows.ABANDON_YES:
			_abandon(id)
	return false


## A terms button: an offer the employer accepts takes the contract on as a job (its party on
## the map) and is remembered; every offer is a decision, saved at once under Ironman.
func _on_terms(action: String, id: String) -> void:
	var contract := talk.contract_id
	var reply := talk.act(action, id, rng, world.day)
	if reply == Terms.ACCEPT and jobs.take(contract):
		_remember_contract()
	if reply != "" and autosave.is_valid():
		autosave.call()
	_show()


## Walks away from a taken contract (Economy.abandon): the captain's line is shown.
func _abandon(id: String) -> void:
	_confirm = ""
	var economy := company.economy
	if economy.abandon(id, company, world.day):
		_react(economy.chronicle[economy.chronicle.size() - 1])


## The contract taken, one memory sentence on every merc of the company (the shared store).
func _remember_contract() -> void:
	var shared := StoryDirector.memory_of(self)
	if shared == null:
		return
	var ids: Array[String] = []
	for merc: Merc in company.roster:
		ids.append(merc.id)
	shared.on_choice(ids, Memory.KEY_CONTRACT, world.day)


## The jobs, about to judge: a judged job leaves its sentence in the shared memory store.
func _judge() -> Jobs:
	jobs.memory = StoryDirector.memory_of(self)
	return jobs


func _decide(choice: String) -> void:
	var economy := company.economy
	var before := economy.chronicle.size()
	if economy.decide_prisoner(company, choice, world.day):
		var lines: Array[String] = []
		for line: Dictionary in economy.chronicle.slice(before):
			lines.append(_memory_line(line))
		_reaction = "\n".join(lines)


## The line the merc a chronicle entry names remembers (named from the data even when he is
## gone, never by a roster lookup that a dead or empty id would break).
func _memory_line(entry: Dictionary) -> String:
	var name := company.name_of(str(entry.get("merc", "")))
	return Text.t("hub.memory." + str(entry.get("key", "")), {"name": name})


func _react(entry: Dictionary) -> void:
	_reaction = _memory_line(entry)


func _next_wearer() -> void:
	var ids: Array[String] = []
	for merc: Merc in company.roster:
		ids.append(merc.id)
	_wearer = ids[(maxi(0, ids.find(_wearer)) + 1) % ids.size()]


## Every site but the hub (the first): where a contract can send the company.
func _site_ids() -> Array[String]:
	var ids: Array[String] = []
	for i: int in range(1, world.sites.size()):
		ids.append(world.sites[i].id)
	return ids


func _at_hub() -> bool:
	return not world.sites.is_empty() and world.at == world.sites[0].id


func _show() -> void:
	if talk.is_open():
		panel.show_rows(talk.left_rows(), talk.right_rows())
		return
	if company.member(_wearer) == null:
		_wearer = company.captain_id
	var left: Array[Dictionary] = _wages_rows()
	left.append_array(ContractRows.rows(company, world, _at_hub(), _confirm))
	if _at_hub():
		left.append_array(_recruit_rows())
	else:
		left.append(_label(Text.t("hub.away")))
	var right: Array[Dictionary] = []
	if _reaction != "":
		right.append(_label(_reaction))
	right.append_array(_prisoner_rows())
	right.append_array(WageRows.rows(company, _share_pct))
	right.append_array(_pack_rows())
	if armoury_rows.is_valid():
		var extra: Variant = armoury_rows.call()
		if extra is Array:
			for row: Variant in extra:
				if row is Dictionary:
					right.append(row)
	right.append(_button("close", "hub", Text.t("hub.close"), true))
	panel.show_rows(left, right)


func _wages_rows() -> Array[Dictionary]:
	var economy := company.economy
	var params := {
		"day": world.day,
		"purse": economy.purse,
		"morale": economy.morale,
		"owed": economy.owed,
		"days": economy.unpaid_days,
		"per_day": economy.wage_per_day(company.roster),
		"count": company.roster.size(),
	}
	var rows: Array[Dictionary] = [HubPanel.line(HubPanel.HEADING, Text.t("hub.title", params))]
	rows.append(_label(Text.t("hub.status", params)))
	if economy.owed <= 0:
		rows.append(_label(Text.t("hub.wages.clear", params)))
		return rows
	rows.append(_label(Text.t("hub.wages.owed", params)))
	var can_pay := _at_hub() and economy.purse >= economy.owed
	rows.append(_button("pay", "wages", Text.t("hub.pay", params), can_pay))
	return rows


func _recruit_rows() -> Array[Dictionary]:
	var economy := company.economy
	var rows: Array[Dictionary] = [
		_label(Text.t("hub.recruits.title", {"cost": economy.hire_cost()}))
	]
	var open := economy.offers()
	if open.is_empty():
		rows.append(_label(Text.t("hub.recruits.none")))
	for def: Dictionary in open:
		var id := str(def.get("id", ""))
		var params := {"name": str(def.get("name", ""))}
		rows.append(_button("inspect", id, Text.t("hub.recruit.inspect", params), true))
		var can_hire := economy.purse >= economy.hire_cost() and not _full()
		rows.append(_button("hire", id, Text.t("hub.recruit.hire", params), can_hire))
	if _full():
		rows.append(_label(Text.t("hub.recruits.full")))
	var seen := company.preview(_inspected)
	if seen != null:
		rows.append(_label("\n".join(CompanyDirector.lines(seen))))
	return rows


func _prisoner_rows() -> Array[Dictionary]:
	var economy := company.economy
	var rows: Array[Dictionary] = []
	if not economy.last_loot.is_empty() and not economy.prisoner.is_empty():
		rows.append(_label(_loot_line(economy.last_loot)))
	if economy.prisoner.is_empty():
		return rows
	rows.append(HubPanel.line(HubPanel.HEADING, Text.t("hub.prisoner.title")))
	rows.append(_label(Text.t("hub.prisoner.body")))
	for choice: String in Economy.CHOICES:
		var params := {"coin": economy.captives.ransom_coin()}
		rows.append(_button("prisoner", choice, Text.t("hub.prisoner." + choice, params), true))
	return rows


func _pack_rows() -> Array[Dictionary]:
	var economy := company.economy
	var rows: Array[Dictionary] = [HubPanel.line(HubPanel.HEADING, Text.t("hub.pack.title"))]
	if economy.inventory.is_empty():
		rows.append(_label(Text.t("hub.pack.empty")))
		return rows
	var params := {"name": company.name_of(_wearer)}
	rows.append(_button("wearer", "next", Text.t("hub.wearer", params), true))
	var shown: Array[String] = []
	for item: String in economy.inventory:
		if item in shown:
			continue
		shown.append(item)
		rows.append(_button("equip", item, Text.t("hub.item.equip", _item_words(item)), true))
	return rows


## The loot line: coin, the supplies the fight won (from the world's log), the gear.
func _loot_line(loot: Dictionary) -> String:
	var item := str(loot.get("item", ""))
	var gear := Text.t("hub.loot.none") if item == "" else str(_item_words(item)["item"])
	var params := {"coin": loot.get("coin", 0), "supplies": _last_supplies(), "item": gear}
	return Text.t("hub.loot", params)


func _item_words(item_id: String) -> Dictionary:
	var def: Variant = company.economy.items().get(item_id, {})
	var found: Dictionary = def if def is Dictionary else {}
	var bonuses: Array[String] = []
	var added: Variant = found.get("bonus", {})
	if added is Dictionary:
		var numbers: Dictionary = added
		for stat: Variant in numbers:
			var key := "company.stat." + str(stat)
			bonuses.append(Text.t(key, {"value": "%+d" % Merc.whole(numbers[stat])}))
	return {"item": str(found.get("name", item_id)), "bonus": ", ".join(bonuses)}


func _last_supplies() -> int:
	for i: int in range(world.log.size() - 1, -1, -1):
		if world.log[i].get("step") == "encounter":
			return Merc.whole(world.log[i].get("supplies", 0))
	return 0


func _full() -> bool:
	return company.roster.size() >= company.cap()


static func _label(text: String) -> Dictionary:
	return HubPanel.line(HubPanel.LABEL, text)


static func _button(action: String, id: String, text: String, enabled: bool) -> Dictionary:
	return HubPanel.button_row(action, id, text, enabled)


static func _block(data: Dictionary, key: String) -> Dictionary:
	var found: Variant = data.get(key, {})
	return found if found is Dictionary else {}


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
