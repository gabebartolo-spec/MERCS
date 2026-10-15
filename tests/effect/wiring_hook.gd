extends "res://tests/lib/effect_case.gd"
## wiring_hook: the same road fight on the same seed (424333, MercPlay on both sides, the
## slice band), the company's hit hook set or not. The fight itself is identical; what the
## company is afterwards differs: with the hook the captain falls in the triage, the office
## passes on and the chronicle has him, without it everyone is as before.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const SEED := 424333


func id() -> String:
	return "wiring_hook"


func run() -> Dictionary:
	return {"on": _after(true), "off": _after(false)}


func _after(hooked: bool) -> String:
	var rng := Rng.from_seed(SEED)
	var made := Kit.wounds(rng, "", {}, Kit.led_by("vampyr"))
	var result := Kit.fight(made, rng, hooked)
	var battle: Battle = result["battle"]
	return (
		"winner %d, %d mercs, captain %s, %d in the chronicle, %d dead"
		% [
			battle.winner,
			made.company.roster.size(),
			made.company.captain_id,
			made.chronicle().entries.size(),
			made.company.fallen.size()
		]
	)
