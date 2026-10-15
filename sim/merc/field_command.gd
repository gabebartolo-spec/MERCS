class_name FieldCommand
extends RefCounted
## Who commands the company's next fight, and what that choice costs (Phase 4, P4; director
## 2026-10-15, Q-F: "No XP, small morale dip"). The captain may sit out a fight: the field
## sergeant, the most experienced of the rest (ties go in roster order), leads in their place,
## the captain is not fielded and so earns no experience from it, and the company starts the
## fight a little shakier. The cost is a number in data/balance/company.json "deploy", shown
## to the player before the fight (preview) and read by the battle through Battle.lower_morale
## (apply). Nothing here rolls, reads the clock or draws a Node. The choice lives on the
## Company (captain_out) and is saved with it, so a fight reloaded under Ironman is the same
## fight.


## The field sergeant: the non-captain with the most experience, else "" when the captain is
## the whole company.
static func sergeant(company: Company) -> String:
	var best: Merc = null
	for merc: Merc in company.roster:
		if merc.id != company.captain_id and (best == null or merc.xp > best.xp):
			best = merc
	return "" if best == null else best.id


## Whether the captain may sit out: there is a captain and someone to stand in.
static func can_sit_out(company: Company) -> bool:
	return company.captain() != null and sergeant(company) != ""


## Chooses the captain's place in the next fight. False (and no change) when asked to sit out
## and nobody can stand in.
static func set_out(company: Company, out: bool) -> bool:
	if out and not can_sit_out(company):
		return false
	company.captain_out = out
	return true


## Whether the captain is sitting out the next fight (the choice stands and can be honoured).
static func is_out(company: Company) -> bool:
	return company.captain_out and can_sit_out(company)


## Who leads the next fight: the captain, or the sergeant when the captain sits out.
static func leader_id(company: Company) -> String:
	return sergeant(company) if is_out(company) else company.captain_id


## What a choice costs, from the data, before the fight: {"leader": id, "dip": morale the
## company starts the fight without}. Fight experience is not paid here (D-095: survive and
## kills, CompanyWounds); a captain who sits out is not fielded, so it never reaches him.
## `out` is the choice being weighed, not the standing one.
static func preview(company: Company, out: bool) -> Dictionary:
	var sits := out and can_sit_out(company)
	return {
		"leader": sergeant(company) if sits else company.captain_id,
		"dip": _num(company, "captain_out_morale_dip") if sits else 0,
	}


## Lays the standing choice on a battle that is set up and not begun: the company's morale
## dips by the previewed amount. Logged like any morale change, so a replay is the same.
static func apply(company: Company, battle: Battle) -> void:
	var dip: int = preview(company, is_out(company))["dip"]
	if dip > 0:
		battle.lower_morale(BattleUnit.COMPANY, dip)


## The choice is spent with the fight: the captain leads the next one unless asked again.
static func finish(company: Company) -> void:
	company.captain_out = false


static func _num(company: Company, key: String) -> int:
	return Merc.whole(company.deploy.get(key, 0))
