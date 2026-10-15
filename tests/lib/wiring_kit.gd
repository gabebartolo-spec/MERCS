extends RefCounted
## Shared by the wiring suite and the wiring_* effect cases (Phase 2 wiring): a company with
## its wounds on one Rng, and one road fight fought by MercPlay on both sides against the
## slice scenario's band, with the hit hook set or not.

const Fixture := preload("res://tests/lib/company_fixture.gd")
const INJURY_RULES := "res://data/balance/injury.json"
const INJURIES := "res://data/injuries.json"
const MAX_ACTIONS := 400
const DAY := 10


static func json(path: String) -> Dictionary:
	return Fixture.json(path)


## injury.json with the triage cut so that every roll gives `outcome` ("" keeps the data).
static func rules(outcome: String = "") -> Dictionary:
	var made := json(INJURY_RULES).duplicate(true)
	var triage: Dictionary = made["triage"]
	if outcome == "dead":
		triage = {"die_sides": 100, "wound_upto": 0, "temporary_upto": 0, "permanent_upto": 0}
	elif outcome != "":
		triage = {"die_sides": 100, "wound_upto": 0, "temporary_upto": 0, "permanent_upto": 0}
		triage["%s_upto" % outcome] = 100
	made["triage"] = triage
	return made


static func injury_defs() -> Array:
	var listed: Variant = json(INJURIES).get("injuries", [])
	return listed if listed is Array else []


## The starting six with their wounds, on `rng`.
static func wounds(rng: Rng, outcome: String = "", saved: Dictionary = {}) -> CompanyWounds:
	var held := Company.start(Fixture.defs())
	var made := CompanyWounds.make(held, saved, rng, rules(outcome), injury_defs())
	made.day = DAY
	return made


static func scenario() -> Dictionary:
	var list := Fixture.rows(json(Fixture.SCENARIOS), "scenarios")
	var first: Dictionary = list[0]
	return first


## The encounter the fights use: the scenario's band, the lookout with them.
static func pending() -> Dictionary:
	var setup := Fixture.sect(scenario(), "battle")
	var band := Fixture.rows(setup, "enemies").duplicate()
	band.append(setup["lookout"])
	return {"enemies": band, "enemy_first": false}


## One road fight to its end. With `hooked` the battle's hit hook is the wounds'; the
## triage is resolved either way, so the difference is the hook's alone. Returns
## {"battle", "events": triage events}.
static func fight(made: CompanyWounds, rng: Rng, hooked: bool) -> Dictionary:
	var data := json(Fixture.BATTLE)
	var cells := EncounterBattle.company_cells(scenario())
	var units := made.units(cells, BattleUnit.COMPANY)
	var battle := EncounterBattle.build(pending(), scenario(), data, rng, units)
	if hooked:
		battle.set_hit_hook(made.hit_hook)
	MercPlay.play_out(battle, Fixture.rules(), MAX_ACTIONS)
	return {"battle": battle, "events": made.resolve()}


## A save written as JSON text and read back: {"company", "wounds"} block as a model gives.
static func reloaded(made: CompanyWounds, rng: Rng) -> SaveModel:
	var balance := json("res://data/balance/world.json")
	var world := WorldSim.new()
	world.start(balance, rng)
	var text := JSON.stringify(SaveModel.to_dict(world, rng, made.company, made.state()))
	var parsed: Dictionary = JSON.parse_string(text)
	return SaveModel.from_dict(parsed, balance, Fixture.defs())
