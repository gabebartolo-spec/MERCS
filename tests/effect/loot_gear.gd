extends "res://tests/lib/effect_case.gd"
## loot_gear: loot is the gear the fallen enemies carried, worn (Phase 5 C6, director Q-11: one
## point weaker, worth less), and gear changes a fight. Ten won patrols on seed 424243: once
## over fallen watchmen (spear and mail, data/balance/battle.json), once over fallen men who
## carried nothing. The pack is put on merc_3, who then fights the same band on the same seed.
## Beating a mail-wearing enemy yields worn mail; beating an unarmoured one does not.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424243
const FIGHT_SEED := 424271
const WINS := 10
const WHO := "merc_3"
const ARMED := "watchman"
const BARE := "recruit_placeholder"


func id() -> String:
	return "loot_gear"


func run() -> Dictionary:
	return {"on": _fight(ARMED), "off": _fight(BARE)}


func _fight(beaten: String) -> String:
	var company := Company.start(Fixture.defs())
	var economy := company.economy
	var rng := Rng.from_seed(SEED)
	for _win: int in WINS:
		economy.take_loot("patrol", rng, _won_over(beaten))
	var pack := economy.inventory.duplicate()
	for item: String in pack:
		economy.equip(company, WHO, item)
	var fight := Fixture.fight(company, WHO, FIGHT_SEED)
	var log: Array[Dictionary] = fight["log"]
	var merc := company.member(WHO)
	return (
		"pack %s, %s %s with %d hp left in %d events; dmg %d def %d hp %d"
		% [
			pack,
			WHO,
			"won" if fight["won"] else "lost",
			fight["hp"],
			log.size(),
			merc.stat("damage"),
			merc.stat("defense"),
			merc.stat("hp")
		]
	)


## A won fight's result with one fallen enemy of `kind`: the classes he carried, as
## EncounterBattle.result reports them ("fallen_gear").
static func _won_over(kind: String) -> Dictionary:
	var unit := BattleUnit.make(kind + "_0", BattleUnit.ENEMY, Vector2i.ZERO, Fixture.fighter(kind))
	var carried: Array[String] = []
	for named: String in [unit.weapon_class, unit.armour_class]:
		if named != "":
			carried.append(named)
	return {"won": true, "fallen_gear": carried}
