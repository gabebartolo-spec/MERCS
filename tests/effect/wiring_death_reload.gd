extends "res://tests/lib/effect_case.gd"
## wiring_death_reload: the road fight of seed 424264, saved as JSON and read back, then the
## next fight's line-up from the reloaded company. With the hook the captain died: the reloaded
## company never fields him and another captain leads; without it the captain is fielded as
## captain again.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const SEED := 424264


func id() -> String:
	return "wiring_death_reload"


func run() -> Dictionary:
	return {"on": _next_fight(true), "off": _next_fight(false)}


func _next_fight(hooked: bool) -> String:
	var rng := Rng.from_seed(SEED)
	var made := Kit.wounds(rng, "", {}, Kit.led_by("vampyr"))
	Kit.fight(made, rng, hooked)
	var model := Kit.reloaded(made, rng)
	var back := Kit.wounds(model.rng, "", model.wounds, model.company)
	var ids: Array[String] = []
	for unit: BattleUnit in back.units(EncounterBattle.company_cells(Kit.scenario()), 0):
		ids.append("%s%s" % [unit.id, "*" if unit.is_leader else ""])
	return "next fight: %s" % ", ".join(ids)
