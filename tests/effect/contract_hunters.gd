extends "res://tests/lib/effect_case.gd"
## contract_hunters (Phase 5 C4, the hunter half): a badly broken deal sends men after the
## company. The same company and seed (424242) take the board's first contract and walk away
## from it, once with half its pay up front (the sizeable advance, director Q-13, Q-16) and once
## with a third: both dent the name the same, but only the first puts a hunter party on the map,
## which sees the band, closes and raises a fight the company remembers by the broken deal. The
## same scripted play (tests/lib/hunter_kit.gd, every fight won) walks both.

const HunterKit := preload("res://tests/lib/hunter_kit.gd")
const SEED := 424242
const HALF := 50
const THIRD := 33


func id() -> String:
	return "contract_hunters"


func run() -> Dictionary:
	return {"on": _play(HALF), "off": _play(THIRD)}


func _play(advance_pct: int) -> String:
	var played := HunterKit.begin(SEED, advance_pct)
	HunterKit.play(played, true)
	var lines: Array[String] = []
	for merc_id: String in played.company.fighting_order():
		for entry: Dictionary in played.memory.of(merc_id):
			var params: Dictionary = entry.get("params", {})
			lines.append("%s %s (deal %s)" % [merc_id, entry.get("key"), params.get("deal", "")])
	return (
		"name with %s %d, hunters %s, fights %s, memories %s"
		% [
			played.faction,
			played.company.economy.standing.reputation(played.faction),
			played.seen,
			played.fights,
			lines
		]
	)
