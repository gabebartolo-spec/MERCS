extends "res://tests/lib/effect_case.gd"
## captain_office: who holds the office changes the fight. The starting six on seed 424271,
## one road fight with the same hit hook and triage, led once by the orc and once by the
## Vampyr: the leader's fall costs the band more morale, so the fight and who is left differ.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const SEED := 424271


func id() -> String:
	return "captain_office"


func run() -> Dictionary:
	return {"on": _outcome("orc"), "off": _outcome("vampyr")}


func _outcome(captain: String) -> String:
	var rng := Rng.from_seed(SEED)
	var made := Kit.wounds(rng, "wound", {}, Kit.led_by(captain))
	var fought := Kit.fight(made, rng, true)
	var battle: Battle = fought["battle"]
	var fallen := 0
	for unit: BattleUnit in battle.units:
		if unit.side == BattleUnit.COMPANY and unit.down:
			fallen += 1
	return (
		"winner %d, round %d, %d of the band down, %d events logged"
		% [battle.winner, battle.round_number, fallen, battle.log.size()]
	)
