class_name RoadFight
extends RefCounted
## The hand-off between the overworld and a fight on the road (Phase 2 wiring): builds the
## battle with the company's living mercs (CompanyWounds) in place of the slice scenario's
## pair and the hit hook set, and words the triage after it. The sim decides everything; this
## only joins the pieces and the words. Words: data/text/en.json.


## The street battle for the pending encounter, the company fielded and the hook listening.
static func build(
	wounds: CompanyWounds,
	pending: Dictionary,
	scenario: Dictionary,
	battle_data: Dictionary,
	rng: Rng
) -> Battle:
	var cells := EncounterBattle.company_cells(scenario)
	var units := wounds.units(cells, BattleUnit.COMPANY)
	var battle := EncounterBattle.build(pending, scenario, battle_data, rng, units)
	battle.set_hit_hook(wounds.hit_hook)
	return battle


## The names the battle view should draw for the fielded mercs: {unit id: name}.
static func names(wounds: CompanyWounds) -> Dictionary:
	var named := {}
	for merc_id: String in wounds.fielded:
		named[merc_id] = wounds.company.name_of(merc_id)
	return named


## What the triage panel says: the fight's outcome line, then a line per downed merc, a
## death, the succession.
static func triage_body(
	outcome_line: String, events: Array[Dictionary], wounds: CompanyWounds
) -> String:
	var lines: Array[String] = [outcome_line]
	lines.append_array(TriageText.lines(events, wounds))
	return "\n".join(lines)
