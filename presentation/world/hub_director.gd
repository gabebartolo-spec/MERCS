class_name HubDirector
extends Node
## The hub on screen (Phase 2 milestone 6): wages due and paid, the contract board, the
## placeholder recruits to inspect and hire, the pack of generic gear to put on a merc, and
## after a won fight on the road the loot line and the prisoner's four choices. The Economy
## (held by the Company) and the WorldSim are the sim's and shared with the rest of the game;
## this registers two small hooks on the world (a day passes; a fight's result is applied),
## words what the sim decides (Text.t, data/text/en.json) and shows it in HubPanel. Wages,
## contracts and hiring are done at the hub only; the pack and a prisoner anywhere. Hiding the
## panel (set_open) keeps everything as it is.

## The hub's actions that commit a decision: under Ironman each is saved at once (`autosave`).
const COMMITS: Array[String] = ["pay", "accept", "hire", "equip", "prisoner"]

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

var _layer: CanvasLayer = null
var _inspected := ""
var _wearer := ""
var _reaction := ""


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
	if open:
		_show()


func economy() -> Economy:
	return company.economy


func _on_day(day: int) -> void:
	_judge().on_day(day)
	company.economy.on_day(company.roster.size(), day, _site_ids(), rng)
	if is_open():
		_show()


## A fight's result was applied: a win leaves loot, and one prisoner when the enemy
## surrendered men (EncounterBattle.result "prisoners"; a wipe or a rout leaves none: Phase 4
## ruling Q-C), and opens the hub.
func _on_result(kind: String, result: Dictionary) -> void:
	_judge().on_result(result)
	if result.get("won", false) != true:
		return
	company.economy.take_loot(kind, rng)
	if not EncounterBattle.taken(result).is_empty():
		company.economy.captives.take(world.day)
	_reaction = ""
	set_open(true)


func _on_action(action: String, id: String) -> void:
	var economy := company.economy
	match action:
		"pay":
			economy.pay_wages()
		"accept":
			if jobs.take(id):
				_remember_contract()
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
	if economy.decide_prisoner(company, choice, world.day):
		var last := economy.chronicle[economy.chronicle.size() - 1]
		var name := company.member(str(last.get("merc", ""))).display_name
		_reaction = Text.t("hub.memory." + str(last.get("key", "")), {"name": name})


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
	if company.member(_wearer) == null:
		_wearer = company.captain_id
	var left: Array[Dictionary] = _wages_rows()
	if _at_hub():
		left.append_array(_contract_rows())
		left.append_array(_recruit_rows())
	else:
		left.append(_label(Text.t("hub.away")))
	var right: Array[Dictionary] = _prisoner_rows()
	right.append_array(_pack_rows())
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
		"per_day": economy.wage_per_day(company.roster.size()),
		"count": company.roster.size(),
	}
	var rows: Array[Dictionary] = [_label(Text.t("hub.title", params))]
	rows.append(_label(Text.t("hub.status", params)))
	if economy.owed <= 0:
		rows.append(_label(Text.t("hub.wages.clear", params)))
		return rows
	rows.append(_label(Text.t("hub.wages.owed", params)))
	var can_pay := _at_hub() and economy.purse >= economy.owed
	rows.append(_button("pay", "wages", Text.t("hub.pay", params), can_pay))
	return rows


func _contract_rows() -> Array[Dictionary]:
	var economy := company.economy
	var rows: Array[Dictionary] = [_label(Text.t("hub.contracts.title"))]
	if economy.board.is_empty():
		rows.append(_label(Text.t("hub.contracts.none")))
	for row: Dictionary in economy.board:
		var site := world.site(str(row.get("site", "")))
		var params := {
			"faction": _faction_name(str(row.get("faction", ""))),
			"site": OverworldMap.site_name(site),
			"reward": row.get("reward", 0),
			"deadline": row.get("deadline", 0),
		}
		var taken: bool = row.get("accepted") == true
		var key := "hub.contract.taken" if taken else "hub.contract.accept"
		rows.append(_button("accept", str(row.get("id", "")), Text.t(key, params), not taken))
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
		if _reaction != "":
			rows.append(_label(_reaction))
		return rows
	rows.append(_label(Text.t("hub.prisoner.title")))
	rows.append(_label(Text.t("hub.prisoner.body")))
	for choice: String in Economy.CHOICES:
		var params := {"coin": economy.captives.ransom_coin()}
		var open := (
			choice != Economy.RECRUIT or economy.captives.can_recruit(company, economy.hired)
		)
		rows.append(_button("prisoner", choice, Text.t("hub.prisoner." + choice, params), open))
	return rows


func _pack_rows() -> Array[Dictionary]:
	var economy := company.economy
	var rows: Array[Dictionary] = [_label(Text.t("hub.pack.title"))]
	if economy.inventory.is_empty():
		rows.append(_label(Text.t("hub.pack.empty")))
		return rows
	var wearer := company.member(_wearer)
	var params := {"name": wearer.display_name}
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


func _faction_name(faction_id: String) -> String:
	return company.economy.book.faction_name(faction_id)


func _full() -> bool:
	return company.roster.size() >= company.cap()


static func _label(text: String) -> Dictionary:
	return {"kind": HubPanel.LABEL, "text": text}


static func _button(action: String, id: String, text: String, enabled: bool) -> Dictionary:
	return {"kind": HubPanel.BUTTON, "action": action, "id": id, "text": text, "enabled": enabled}
