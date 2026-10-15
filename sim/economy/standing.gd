class_name Standing
extends RefCounted
## The company's name with each faction and the grudges it has earned (Economy's module, Phase 5
## C4; director Q-7: reputation per faction). One name and at most one grudge per faction.
## A completed contract mends the name; failing honestly only dents it; an employer who walks
## from an ask dents it (C2); abandoning a contract dents it more, and abandoning after taking
## a sizeable advance (standing.sizeable_advance percent of the pay or more, Q-13, Q-16) also
## grows that faction's grudge. The grudge's growth is the number the hunters it sends grow
## with (Q-15): each broken deal sends one hunter party, as strong as the grudge has grown
## (sim/world/grudge_parties.gd). Nothing here rolls. Rules: data/balance/economy.json "standing".

const PERCENT := 100

## faction id -> the company's name with it; a faction not here stands at standing.start.
var names: Dictionary = {}
## faction id -> its grudge: {"growth": n, "sent": n, "deals": [contract ids], "day": d,
## "captain": merc id}. growth: how far it has grown; sent: how many hunter parties went.
var grudges: Dictionary = {}

var _rules := {}


## rules: data/balance/economy.json "standing".
func setup(rules: Dictionary) -> void:
	_rules = rules


## The standing a save held ({} or missing reads as the new-game standing).
func load_state(saved: Dictionary) -> void:
	names = {}
	grudges = {}
	var named: Variant = saved.get("names", {})
	if named is Dictionary:
		var rows_named: Dictionary = named
		for faction: Variant in rows_named:
			names[str(faction)] = _clamped(_whole(rows_named[faction]))
	var held: Variant = saved.get("grudges", {})
	if held is Dictionary:
		var rows: Dictionary = held
		for faction: Variant in rows:
			if rows[faction] is Dictionary:
				grudges[str(faction)] = _grudge_row(rows[faction])


func state() -> Dictionary:
	return {"names": names.duplicate(), "grudges": grudges.duplicate(true)}


## Whether nothing has moved since a new game (the save then leaves the key out).
func is_new() -> bool:
	return names.is_empty() and grudges.is_empty()


## The company's name with a faction (C2's employer reads it).
func reputation(faction_id: String) -> int:
	return _whole(names.get(faction_id, _rule("start")))


## A faction's grudge record, a copy ({} when it holds none).
func grudge(faction_id: String) -> Dictionary:
	var held: Variant = grudges.get(faction_id, {})
	var row: Dictionary = held if held is Dictionary else {}
	return row.duplicate(true)


## A contract for this faction was completed: the name mends.
func completed(faction_id: String) -> void:
	_move(faction_id, _rule("complete_mend"))


## A contract for this faction failed honestly (the job was lost, not walked from): the name
## dents, nothing more (C1's jobs call it).
func failed(faction_id: String) -> void:
	_move(faction_id, -_rule("fail_dent"))


## The faction's employer walked from an ask pushed too far: the name dents (C2's terms).
func walked(faction_id: String) -> void:
	_move(faction_id, -_rule("walk_dent"))


## Whether the advance taken on this contract row is sizeable: standing.sizeable_advance
## percent of its pay or more. A row with no advance never is.
func sizeable(row: Dictionary) -> bool:
	var advance := _whole(row.get("advance", 0))
	var pay := _whole(row.get("reward", 0))
	return advance > 0 and advance * PERCENT >= pay * _rule("sizeable_advance")


## The company walked away from this accepted contract row on `day`, with `captain_id` in
## command. The name dents; after a sizeable advance the faction's grudge grows and records the
## deal and the captain. True when a grudge grew.
func abandoned(row: Dictionary, captain_id: String, day: int) -> bool:
	var faction := str(row.get("faction", ""))
	_move(faction, -_rule("abandon_dent"))
	if not sizeable(row):
		return false
	var grudge_row := _grudge_row(grudges.get(faction, {}))
	grudge_row["growth"] = _whole(grudge_row["growth"]) + _rule("grudge_growth")
	var deals: Array = grudge_row["deals"]
	deals.append(str(row.get("id", "")))
	grudge_row["day"] = day
	grudge_row["captain"] = captain_id
	grudges[faction] = grudge_row
	return true


## The factions owed a hunter party, in id order: one party per broken deal ("sent" counts
## parties), so a grudge whose deals outnumber the parties sent calls the next (GrudgeParties).
func hunter_calls() -> Array[String]:
	var due: Array[String] = []
	for faction: Variant in grudges:
		var row: Dictionary = grudges[faction]
		var deals: Array = row.get("deals", [])
		if deals.size() > _whole(row.get("sent", 0)):
			due.append(str(faction))
	due.sort()
	return due


## The next broken deal of a faction's grudge still owed its hunters, "" when none.
func next_hunt(faction_id: String) -> String:
	var row := grudge(faction_id)
	var deals: Array = row.get("deals", [])
	var sent := _whole(row.get("sent", 0))
	return str(deals[sent]) if sent < deals.size() else ""


## One more hunter party went for a faction's grudge (GrudgeParties). False when it holds none.
func hunters_sent(faction_id: String) -> bool:
	if not grudges.has(faction_id):
		return false
	var row: Dictionary = grudges[faction_id]
	row["sent"] = _whole(row.get("sent", 0)) + 1
	return true


## The faction whose grudge holds this broken deal, "" when none does.
func grudge_of(deal_id: String) -> String:
	for faction: Variant in grudges:
		var row: Dictionary = grudges[faction]
		var deals: Array = row.get("deals", [])
		if deals.has(deal_id):
			return str(faction)
	return ""


func _move(faction_id: String, by: int) -> void:
	if faction_id == "" or by == 0:
		return
	names[faction_id] = _clamped(reputation(faction_id) + by)


func _clamped(value: int) -> int:
	return clampi(value, _rule("min"), _rule("max"))


func _rule(key: String) -> int:
	return _whole(_rules.get(key, 0))


static func _grudge_row(saved: Variant) -> Dictionary:
	var row: Dictionary = saved if saved is Dictionary else {}
	var deals: Array[String] = []
	var held: Variant = row.get("deals", [])
	if held is Array:
		for id: Variant in held:
			deals.append(str(id))
	return {
		"growth": maxi(0, _whole(row.get("growth", 0))),
		"sent": maxi(0, _whole(row.get("sent", 0))),
		"deals": deals,
		"day": _whole(row.get("day", 0)),
		"captain": str(row.get("captain", "")),
	}


static func _whole(value: Variant) -> int:
	return Merc.whole(value) if value is int or value is float else 0
