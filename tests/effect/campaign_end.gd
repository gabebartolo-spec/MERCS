extends "res://tests/lib/effect_case.gd"
## campaign_end: the company cut down to the orc, one road fight on seed 424271. Where the
## triage kills him the campaign ends (the wipe event, an ended company); where he lives the
## campaign goes on with the same chronicle of earlier dead and one merc alive.

const End := preload("res://tests/lib/end_kit.gd")
const SEED := 424271


func id() -> String:
	return "campaign_end"


func run() -> Dictionary:
	return {"on": _outcome("dead"), "off": _outcome("wound")}


func _outcome(triage: String) -> String:
	var fought := End.fight(SEED, triage)
	var made: CompanyWounds = fought["wounds"]
	var events: Array[Dictionary] = fought["events"]
	return (
		"%s, %d alive, %d in the chronicle"
		% [
			"campaign ended" if End.has_event(events, "campaign_end") else "campaign goes on",
			made.company.roster.size(),
			made.chronicle().entries.size()
		]
	)
