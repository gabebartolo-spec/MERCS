class_name TriageText
extends RefCounted
## The words for what happened to the company after a fight on the road: each downed merc's
## outcome, a death with its chronicle line, and the succession. Takes the events
## CompanyWounds.resolve() returned and the sim objects they name; holds no player text of
## its own (data/text/en.json, "wiring.*", "chronicle.*", "succession.*").


## One line per event, in the order the sim gave them; a quiet fight says so.
static func lines(events: Array[Dictionary], wounds: CompanyWounds) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in events:
		match str(event.get("type", "")):
			"triage":
				out.append(_triage(event, wounds))
			"death":
				out.append(_death(event, wounds.company))
			"succession":
				out.append(_succession(event, wounds.company))
	if out.is_empty():
		out.append(Text.t("wiring.none"))
	return out


## A name for a fighter id: a merc by his name (the dead keep theirs), an enemy by its kind.
static func name_of(fighter_id: String, held: Company) -> String:
	if fighter_id == "":
		return Text.t("wiring.cause_unknown")
	if held.name_of(fighter_id) != fighter_id:
		return held.name_of(fighter_id)
	var kind := fighter_id.rstrip("0123456789").trim_suffix("_")
	return Text.t("enemy.%s.name" % kind)


static func _triage(event: Dictionary, wounds: CompanyWounds) -> String:
	var def := wounds.injury_def(str(event.get("injury", "")))
	var outcome := str(event.get("outcome", ""))
	var params := {
		"name": name_of(str(event.get("merc", "")), wounds.company),
		"injury": Text.t(str(def.get("name_key", ""))),
		"day": wounds.day + Injury.num(def, "days"),
		"role": Text.t(str(def.get("role_key", ""))) if def.has("role_key") else ""
	}
	return Text.t("wiring.outcome.%s" % outcome, params)


static func _death(event: Dictionary, held: Company) -> String:
	return Text.t(
		"chronicle.death",
		{
			"name": name_of(str(event.get("merc", "")), held),
			"day": Injury.num(event, "day"),
			"cause": name_of(str(event.get("cause", "")), held)
		}
	)


static func _succession(event: Dictionary, held: Company) -> String:
	var line := Text.t(
		"succession.new_captain", {"name": name_of(str(event.get("captain", "")), held)}
	)
	if str(event.get("dissent", "")) != "":
		line += (
			" "
			+ Text.t("succession.dissent", {"name": name_of(str(event.get("dissent", "")), held)})
		)
	return line
