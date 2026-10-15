extends RefCounted
## Shared by the campaign_end suite and its effect case: a company cut down to the orc alone,
## and one road fight of it, with the triage cut so that a downed merc dies or lives.

const Kit := preload("res://tests/lib/wiring_kit.gd")
const Fixture := preload("res://tests/lib/company_fixture.gd")
const LAST := "orc"
## The five who fell before (name the chronicle keeps, day, cause).
const EARLIER_DAY := 3
const EARLIER_CAUSE := "bandit_0"


## The starting six with everyone but the orc buried and written in the chronicle of `made`.
static func lone_orc(rng: Rng, outcome: String) -> CompanyWounds:
	var held := Kit.led_by(LAST)
	var gone: Array[String] = []
	for id: String in held.fighting_order():
		if id != LAST:
			gone.append(id)
	var made := Kit.wounds(rng, outcome, {}, held)
	for id: String in gone:
		held.bury(id)
		made.chronicle().record_death(id, EARLIER_DAY, EARLIER_CAUSE)
		made.memory().record(id, Memory.KEY_FIGHT_FELL, {"about": id}, EARLIER_DAY)
	return made


## One fight of the orc alone; the events the triage gave.
static func fight(seed_value: int, outcome: String) -> Dictionary:
	var rng := Rng.from_seed(seed_value)
	var made := lone_orc(rng, outcome)
	var result := Kit.fight(made, rng, true)
	return {"wounds": made, "rng": rng, "events": result["events"]}


static func has_event(events: Array[Dictionary], type: String) -> bool:
	for event: Dictionary in events:
		if event.get("type") == type:
			return true
	return false
