extends "res://tests/lib/effect_case.gd"
## contracts_pressure: faction pressure steers the board. Thirty boards on seed 424242 posted
## with the data's factions (A presses 70, B 30) and with the pressures swapped: who posts the
## contracts, and so who the player works for, follows the pressure.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const BOARDS := 30
const SITES: Array[String] = ["site_1", "site_2", "site_3"]


func id() -> String:
	return "contracts_pressure"


func run() -> Dictionary:
	return {"on": _boards(false), "off": _boards(true)}


func _boards(swapped: bool) -> String:
	var defs := Fixture.defs()
	if swapped:
		var block: Dictionary = defs["factions"]
		var rows: Array = block["factions"]
		var first: Dictionary = rows[0]
		var second: Dictionary = rows[1]
		var held: Variant = first["pressure"]
		first["pressure"] = second["pressure"]
		second["pressure"] = held
	var economy := Economy.make(defs)
	var rng := Rng.from_seed(SEED)
	var counts := {}
	for day: int in BOARDS:
		economy.refresh_board(day, SITES, rng)
		for row: Dictionary in economy.board:
			var who := str(row.get("faction", ""))
			counts[who] = Merc.whole(counts.get(who, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort()
	return ", ".join(keys.map(func(key: String) -> String: return "%s %d" % [key, counts[key]]))
