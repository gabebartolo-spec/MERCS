extends "res://tests/lib/effect_case.gd"
## hub_prisoner: the prisoners from the fight (Phase 5 C5). The starting company after a won
## fight in which a bandit chief and a bandit surrendered (EncounterBattle.result "prisoners"),
## each man then given one of the three fates (release, ransom, execute: director Q-12 left
## recruiting out). On: both men are the prisoners, a ransom is priced by each man's fighter
## type, and each fate is remembered by the captain and by the merc who reacts most strongly
## (economy.json "prisoner" "reactions", placeholders). Off: the Phase 2 rule: one nameless
## prisoner per won fight, a flat ransom, and only the captain remembers.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const DAY := 3
const TAKEN: Array[String] = ["bandit_chief_0", "bandit_1"]


func id() -> String:
	return "hub_prisoner"


func run() -> Dictionary:
	var defs := Fixture.defs()
	var phase_2 := defs.duplicate(true)
	var rules: Dictionary = phase_2["economy"]["prisoner"]
	rules.erase("ransom_by_fighter")
	rules.erase("reactions")
	return {"on": _fates(defs, TAKEN), "off": _fates(phase_2, [])}


## Each fate in turn on a fresh company: coin, morale and who remembers it.
func _fates(defs: Dictionary, taken: Array[String]) -> String:
	var parts: Array[String] = []
	for choice: String in Economy.CHOICES:
		var company := Company.start(defs)
		var economy := company.economy
		economy.captives.take(DAY, taken)
		while economy.decide_prisoner(company, choice, DAY):
			pass
		var who: Array[String] = []
		for line: Dictionary in economy.chronicle:
			who.append(str(line.get("merc", "")))
		parts.append(
			(
				"%s: coin %d, morale %d, remembered by %s"
				% [choice, economy.purse, economy.morale, ",".join(who)]
			)
		)
	return "; ".join(parts)
