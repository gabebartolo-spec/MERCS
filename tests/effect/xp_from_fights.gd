extends "res://tests/lib/effect_case.gd"
## xp_from_fights (D-095): the starting six fight the same four road fights on one seed
## (424271, every downed merc only wounded so nobody dies), then a fifth, with experience from
## fights on (data/balance/company.json) or switched off. On: the company has levelled, so the
## fifth fight differs (growth and moves); off: everyone is still level 1.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const SEED := 424271
const FIGHTS := 4


func id() -> String:
	return "xp_from_fights"


func run() -> Dictionary:
	return {"on": after(true)["text"], "off": after(false)["text"]}


## {"text": the summary, "raised": mercs past level 1 after four fights, "company": the Company}.
static func after(earning: bool) -> Dictionary:
	var defs := Fixture.defs().duplicate(true)
	if not earning:
		var balance: Dictionary = defs["company"]
		var bar: Dictionary = balance["xp"]
		bar["per_fight"] = 0
		bar["per_kill"] = 0
	var rng := Rng.from_seed(SEED)
	var held := Company.start(defs)
	var made := Kit.wounds(rng, "wound", {}, held)
	for _i: int in FIGHTS:
		Kit.fight(made, rng, true)
		made.day += 30
	var levels: Array[String] = []
	var raised := 0
	for merc: Merc in held.roster:
		levels.append("%s L%d %dxp" % [merc.id, merc.level(), merc.xp])
		raised += 1 if merc.level() > 1 else 0
	var fifth: Dictionary = Kit.fight(made, rng, true)
	var battle: Battle = fifth["battle"]
	return {
		"text":
		(
			"after four: %s; fifth fight winner %d, %d events"
			% [", ".join(levels), battle.winner, battle.log.size()]
		),
		"company": held,
		"raised": raised,
		"fifth": battle
	}
