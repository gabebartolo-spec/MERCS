extends "res://tests/lib/effect_case.gd"
## temporary_injury: a temporary wound weakens the merc in the next fight, until it heals.
## The starting six on seed 424271: one road fight whose triage leaves every downed merc with
## a temporary injury, then the next road fight on a fresh Rng (seed 424272), once the day
## after (the wounds still on) and once after they have healed.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const FIRST := 424251
const SECOND := 424272
const HEAL_DAYS := 60


func id() -> String:
	return "temporary_injury"


func run() -> Dictionary:
	return {"on": _next_fight(0), "off": _next_fight(HEAL_DAYS)}


func _next_fight(days_later: int) -> String:
	var rng := Rng.from_seed(FIRST)
	var made := Kit.wounds(rng, "temporary")
	Kit.fight(made, rng, true)
	var hurt := 0
	for merc_id: String in made.company.fighting_order():
		hurt += made.injuries_of(merc_id).size()
	made.day += days_later
	var again := Rng.from_seed(SECOND)
	var data := Fixture.json(Fixture.BATTLE)
	var cells := EncounterBattle.company_cells(Kit.scenario())
	var units := made.units(cells, BattleUnit.COMPANY)
	var attack := 0
	for unit: BattleUnit in units:
		attack += unit.attack
	var battle := EncounterBattle.build(Kit.pending(), Kit.scenario(), data, again, units)
	var log := MercPlay.play_out(battle, Fixture.rules(), Kit.MAX_ACTIONS)
	return (
		"%d wounds before, band attack %d, winner %d in round %d, %d events"
		% [hurt, attack, battle.winner, battle.round_number, log.size()]
	)
