class_name Economy
extends RefCounted
## The company's money and mood (Phase 2 milestone 6): a purse of coin, the wages that fall
## due every day and the morale that falls when they are not paid, the contract board, the
## loot and the generic gear in the pack, the hub's placeholder recruits and the prisoner a
## won fight leaves. Held by the Company, so it rides in the company's save; nothing here
## reads a node, the clock or a file. What it rolls (contracts, loot) comes from the Rng it is
## handed, on named streams. Numbers are in data/balance/economy.json.
##
## This file is the facade every caller uses (Phase 5 C0, docs/plans/phase5_contracts.md); the
## parts each package grows live in modules:
## - ContractBook (contract_book.gd, `book`): the board, accept, complete, expire;
## - Prisoners (prisoners.gd, `captives`): the waiting prisoner and the four choices;
## - Terms (terms.gd, `terms`): the ask, the employer's reply, the step-in (C2).
## The facade keeps at most 14 public methods; a package prefers a module or a field read
## through state() over a new one.
##
## defs: {"economy": data/balance/economy.json, "factions": data/factions.json, "equipment":
## data/equipment.json, "recruits": data/recruits.json, "traits": data/traits.json}. Missing
## data reads as nothing: no coin, no wages, no board, no recruits, no gear, no bargaining.

const RELEASE := Prisoners.RELEASE
const RANSOM := Prisoners.RANSOM
const EXECUTE := Prisoners.EXECUTE
const RECRUIT := Prisoners.RECRUIT
const CHOICES: Array[String] = Prisoners.CHOICES

var purse := 0
## Wages fallen due and not yet paid, and the days since the debt was last cleared.
var owed := 0
var unpaid_days := 0
var morale := 0
## The contract board (contract(id), expire(day), faction_name(id) are read there).
var book := ContractBook.new()
## The prisoner a won fight leaves (take(day), ransom_coin(), can_recruit() are read there).
var captives := Prisoners.new()
## Negotiation (negotiate(); reputation(id), odds(merc_id), judge() are read there).
var terms := Terms.new()
## The posted contracts: Contracts records plus "id" ("ctr_<n>"). Held by the book.
var board: Array[Dictionary]:
	get:
		return book.board
	set(value):
		book.board = value
## Generic gear ids in the pack, unequipped (one entry per piece).
var inventory: Array[String] = []
## Recruit ids ever hired, so a recruit who is later lost is never offered again.
var hired: Array[String] = []
## The prisoner waiting for a decision, or {} ({"day": d}). Held by the captives.
var prisoner: Dictionary:
	get:
		return captives.waiting
	set(value):
		captives.waiting = value
## The last loot, {"coin", "item"}, for presentation to word.
var last_loot: Dictionary = {}
## One line per decision, as ids for presentation to word: {"day", "merc", "key"}; merc is the
## one who remembers it, by id.
var chronicle: Array[Dictionary] = []

var _rules := {}
var _items := {}
var _recruits: Array[Dictionary] = []


## A new economy at the first day: the starting purse and morale, an empty board.
static func make(defs: Dictionary) -> Economy:
	var economy := Economy.new()
	economy._read(defs)
	economy.purse = economy._rule("purse", "start")
	economy.morale = economy._rule("morale", "start")
	return economy


## The economy a save held; anything it lacks (an older save has none) keeps the new-game value.
static func restore(saved: Dictionary, defs: Dictionary) -> Economy:
	var economy := Economy.make(defs)
	economy.purse = maxi(0, _num(saved, "purse", economy.purse))
	economy.owed = maxi(0, _num(saved, "owed", 0))
	economy.unpaid_days = maxi(0, _num(saved, "unpaid_days", 0))
	economy.morale = clampi(_num(saved, "morale", economy.morale), 0, economy._max_morale())
	economy.book.next_contract = maxi(1, _num(saved, "next_contract", 1))
	economy.book.board_day = _num(saved, "board_day", 0)
	for row: Dictionary in _rows(saved, "board"):
		economy.board.append(_whole_row(row))
	for id: String in _ids(saved, "inventory"):
		if economy._items.has(id):
			economy.inventory.append(id)
	economy.hired.append_array(_ids(saved, "hired"))
	economy.prisoner = _whole_row(_dict(saved, "prisoner"))
	economy.last_loot = _whole_row(_dict(saved, "last_loot"))
	for row: Dictionary in _rows(saved, "chronicle"):
		economy.chronicle.append(_whole_row(row))
	economy.terms.restore(_dict(saved, "standing_stub"))
	return economy


func state() -> Dictionary:
	var held := {
		"purse": purse,
		"owed": owed,
		"unpaid_days": unpaid_days,
		"morale": morale,
		"board": board.duplicate(true),
		"next_contract": book.next_contract,
		"board_day": book.board_day,
		"inventory": inventory.duplicate(),
		"hired": hired.duplicate(),
		"prisoner": prisoner.duplicate(),
		"last_loot": last_loot.duplicate(),
		"chronicle": chronicle.duplicate(true),
	}
	if not terms.stub_reputation.is_empty():
		held["standing_stub"] = terms.state()
	return held


## Generic gear definitions by id (data/equipment.json), for the mercs who wear them.
func items() -> Dictionary:
	return _items


## The coin wages cost each day for a roster of this size.
func wage_per_day(roster_size: int) -> int:
	return roster_size * _rule("wages", "per_merc_per_day")


## A day has passed. The day's wages fall due; wages unpaid past the grace cost morale; old
## contracts lapse; and a fresh board is posted when none stands or the last has aged out.
## site_ids: the places a contract may name; rng: the world's Rng ("contracts" stream).
func on_day(roster_size: int, day: int, site_ids: Array[String], rng: Rng) -> void:
	owed += wage_per_day(roster_size)
	unpaid_days += 1
	if unpaid_days > _rule("wages", "grace_days"):
		morale = maxi(0, morale - _rule("wages", "morale_loss_per_day"))
	book.expire(day)
	if board.is_empty() or day - book.board_day >= _rule("contracts", "refresh_days"):
		refresh_board(day, site_ids, rng)


## Pays the whole debt, or nothing when the purse falls short. Clearing it ends the run of
## unpaid days and lifts morale a little. False when nothing is owed or the purse cannot.
func pay_wages() -> bool:
	if owed <= 0 or purse < owed:
		return false
	purse -= owed
	owed = 0
	unpaid_days = 0
	morale = mini(_max_morale(), morale + _rule("wages", "paid_recovery"))
	return true


## Posts a new board on `day`: the contracts already accepted stay, the rest are replaced.
func refresh_board(day: int, site_ids: Array[String], rng: Rng) -> void:
	book.refresh_board(day, site_ids, rng)


## Takes a posted contract on. False (and no change) when it is not on the board or already taken.
func accept(id: String) -> bool:
	return book.accept(id)


## Completes an accepted contract: it pays its reward and leaves the board. False otherwise.
func complete(id: String) -> bool:
	var row := book.complete(id)
	if row.is_empty():
		return false
	purse += _num(row, "reward", 0)
	return true


## Negotiates a posted contract's terms (Terms). ask: {"price": total coin, "advance": the
## coin of it paid now (the rest on return), "speaker": the merc id who steps in or "",
## "day": today}; rng: the world's Rng ("terms" stream, rolled only by a step-in). The
## employer accepts (the contract is taken, the advance paid), counters (his terms are kept on
## the contract) or walks (it leaves the board, the name falls). Returns the reply and why.
func negotiate(company: Company, id: String, ask: Dictionary, rng: Rng) -> Dictionary:
	var talk := ask.duplicate()
	talk["rng"] = rng
	return terms.negotiate(self, company, id, talk)


## Loot from a won fight of this encounter type: coin to the purse, a piece of gear to the
## pack. Rolled on the Rng "loot" stream. Returns {"coin", "item"}.
func take_loot(kind: String, rng: Rng) -> Dictionary:
	var ids: Array[String] = []
	for id: Variant in _items:
		ids.append(str(id))
	last_loot = Loot.roll(_dict(_rules, "loot"), kind, ids, rng)
	purse += _num(last_loot, "coin", 0)
	var item := str(last_loot.get("item", ""))
	if item != "":
		inventory.append(item)
	return last_loot.duplicate()


## The recruits on offer: unhired entries of data/recruits.json, in order, up to the offer count.
func offers() -> Array[Dictionary]:
	var open: Array[Dictionary] = []
	for def: Dictionary in _recruits:
		if str(def.get("id", "")) not in hired and open.size() < _rule("recruits", "offers"):
			open.append(def)
	return open


func hire_cost() -> int:
	return _rule("recruits", "cost")


## Hires an offered recruit for the coin. False (and no change) when the recruit is not on
## offer, the purse falls short or the roster is full.
func hire(company: Company, recruit_id: String) -> bool:
	var on_offer := offers().any(func(d: Dictionary) -> bool: return d.get("id") == recruit_id)
	if not on_offer or purse < hire_cost() or not company.add(recruit_id):
		return false
	purse -= hire_cost()
	hired.append(recruit_id)
	return true


## Puts a piece of gear from the pack on a merc, in the slot it fills. Whatever was in the slot
## returns to the pack. False (and no change) when the pack has none or the merc is not on
## the roster.
func equip(company: Company, merc_id: String, item_id: String) -> bool:
	var merc := company.member(merc_id)
	var def := _dict(_items, item_id)
	if merc == null or item_id not in inventory or def.is_empty():
		return false
	var slot := str(def.get("slot", ""))
	if slot not in Merc.SLOTS:
		return false
	var before := str(merc.gear.get(slot, ""))
	inventory.erase(item_id)
	if before != "":
		inventory.append(before)
	merc.gear[slot] = item_id
	return true


## Decides the waiting prisoner: release, ransom, execute or recruit (Prisoners.decide). False
## (and the prisoner still waits) when none waits, the choice is unknown, or a recruit cannot
## join.
func decide_prisoner(company: Company, choice: String, day: int) -> bool:
	return captives.decide(self, company, choice, day)


func _max_morale() -> int:
	return _rule("morale", "max")


func _rule(group: String, key: String) -> int:
	return _num(_dict(_rules, group), key, 0)


func _read(defs: Dictionary) -> void:
	_rules = _dict(defs, "economy")
	var factions := _rows(_dict(defs, "factions"), "factions")
	_recruits = _rows(_dict(defs, "recruits"), "recruits")
	for def: Dictionary in _rows(_dict(defs, "equipment"), "equipment"):
		_items[str(def.get("id", ""))] = def
	book.setup(_dict(_rules, "contracts"), factions)
	captives.setup(_dict(_rules, "prisoner"), _recruits, _max_morale())
	terms.setup(_dict(_rules, "terms"), factions, _rows(_dict(defs, "traits"), "traits"))


static func _num(block: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = block.get(key)
	return Merc.whole(value) if value is int or value is float else fallback


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}


static func _rows(block: Dictionary, key: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var value: Variant = block.get(key, [])
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				var row: Dictionary = entry
				rows.append(row)
	return rows


static func _ids(block: Dictionary, key: String) -> Array[String]:
	var ids: Array[String] = []
	var value: Variant = block.get(key, [])
	if value is Array:
		for entry: Variant in value:
			ids.append(str(entry))
	return ids


## A saved record with its numbers whole again (JSON hands back floats).
static func _whole_row(row: Dictionary) -> Dictionary:
	var fixed := {}
	for key: Variant in row:
		var value: Variant = row[key]
		fixed[str(key)] = Merc.whole(value) if value is float else value
	return fixed
