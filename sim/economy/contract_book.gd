class_name ContractBook
extends RefCounted
## The contract board (Economy's module, Phase 5 C0): the posted contracts, their ids, the day
## the board was last posted, and accept, complete and expire. The board is drawn by Contracts
## on the Rng "contracts" stream it is handed; the reward a completed contract pays is the
## caller's to add to the purse. Rules: data/balance/economy.json "contracts".

## The posted contracts: Contracts records plus "id" ("ctr_<n>").
var board: Array[Dictionary] = []
## The number the next contract's id takes, and the day the board was last posted.
var next_contract := 1
var board_day := 0

var _rules := {}
var _factions: Array[Dictionary] = []


## rules: data/balance/economy.json "contracts"; factions: data/factions.json "factions".
func setup(rules: Dictionary, factions: Array[Dictionary]) -> void:
	_rules = rules
	_factions = factions


## Posts a new board on `day`: the contracts already accepted stay, the rest are replaced.
func refresh_board(day: int, site_ids: Array[String], rng: Rng) -> void:
	board = board.filter(func(row: Dictionary) -> bool: return row.get("accepted") == true)
	for row: Dictionary in Contracts.post(_rules, _factions, site_ids, day, rng):
		row["id"] = "ctr_%d" % next_contract
		next_contract += 1
		board.append(row)
	board_day = day


func contract(id: String) -> Dictionary:
	for row: Dictionary in board:
		if row.get("id") == id:
			return row
	return {}


## Takes a posted contract on. False (and no change) when it is not on the board or already taken.
func accept(id: String) -> bool:
	var row := contract(id)
	if row.is_empty() or row.get("accepted") == true:
		return false
	row["accepted"] = true
	return true


## Takes an accepted contract off the board and returns its row (the caller pays the reward),
## or {} (and no change) when it is not on the board or not accepted.
func complete(id: String) -> Dictionary:
	var row := contract(id)
	if row.is_empty() or row.get("accepted") != true:
		return {}
	board.erase(row)
	return row


## Removes the contracts whose deadline is before `day`; the ids removed.
func expire(day: int) -> Array[String]:
	var lapsed: Array[String] = []
	for row: Dictionary in board.duplicate():
		if _num(row, "deadline", 0) < day:
			lapsed.append(str(row.get("id", "")))
			board.erase(row)
	return lapsed


## A faction's name from data/factions.json ("" when unknown).
func faction_name(faction_id: String) -> String:
	for def: Dictionary in _factions:
		if def.get("id") == faction_id:
			return str(def.get("name", ""))
	return ""


static func _num(block: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = block.get(key)
	return Merc.whole(value) if value is int or value is float else fallback
