extends "res://tests/lib/effect_case.gd"
## loot_gear: loot is gear, and gear changes a fight. Ten won patrols on seed 424242 drop
## coin and pieces into the pack; the same merc then fights the same band on the same seed
## once with the pack's gear put on and once with it left in the pack.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424242
const FIGHT_SEED := 424271
const WINS := 10
const WHO := "merc_3"


func id() -> String:
	return "loot_gear"


func run() -> Dictionary:
	return {"on": _fight(true), "off": _fight(false)}


func _fight(wears: bool) -> String:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	var rng := Rng.from_seed(SEED)
	for _win: int in WINS:
		economy.take_loot("patrol", rng)
	var pack := economy.inventory.duplicate()
	if wears:
		for item: String in pack:
			economy.equip(company, WHO, item)
	var fight := Fixture.fight(company, WHO, FIGHT_SEED)
	var log: Array[Dictionary] = fight["log"]
	var merc := company.member(WHO)
	return (
		"%d in pack, %s %s with %d hp left in %d events; dmg %d def %d hp %d"
		% [
			economy.inventory.size(),
			WHO,
			"won" if fight["won"] else "lost",
			fight["hp"],
			log.size(),
			merc.stat("damage"),
			merc.stat("defense"),
			merc.stat("hp")
		]
	)
