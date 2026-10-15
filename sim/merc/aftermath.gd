class_name Aftermath
extends RefCounted
## Down, then triage (Phase 2 M5): after a fight, every company merc the battle log shows
## down is resolved by one seeded roll into a wound, a temporary injury, a permanent injury
## or death. A death goes in the chronicle, writes a memory on every surviving comrade and,
## if it was the captain, names a successor and one dissenting voice. Takes the battle log
## (a list of event dictionaries: "down" and "attack" events) and a dictionary of merc
## states keyed by id; changes that dictionary in place (the dead are removed from it, the
## chronicle keeps them) and returns the events presentation words. No Merc class needed.

## Set before resolve(): the stores to write to, the balance and the injury list.
var chronicle: Chronicle = Chronicle.new()
var memory: Memory = Memory.new()
var captain_id := ""
var day := 0
## Filled by restore(): the living's injury records from the save.
var injuries := {}

var _rng: Rng = null
var _rules := {}
var _defs: Array = []


## rules: data/balance/injury.json; defs: data/injuries.json "injuries".
func _init(rng: Rng, rules: Dictionary, defs: Array) -> void:
	_rng = rng
	_rules = rules
	_defs = defs


## Resolves every company merc (one in `mercs`) that a "down" event names. Events come back
## in id order: {"type": "triage", "merc", "outcome", "injury"}, {"type": "death", "merc",
## "day", "cause"} and {"type": "succession", ...} (see Succession).
func resolve(battle_log: Array, mercs: Dictionary) -> Array[Dictionary]:
	var downed: Array[String] = []
	for entry: Variant in battle_log:
		var event: Dictionary = entry if entry is Dictionary else {}
		var unit := str(event.get("unit", ""))
		if event.get("type", "") == "down" and mercs.has(unit) and not chronicle.is_dead(unit):
			downed.append(unit)
	var outcomes := Injury.triage(downed, _rng, _dict(_rules, "triage"))
	var events: Array[Dictionary] = []
	var dead: Array[String] = []
	for merc_id: Variant in outcomes:
		var outcome := str(outcomes[merc_id])
		if outcome == Injury.OUTCOME_DEAD:
			dead.append(str(merc_id))
			events.append(_die(str(merc_id), _cause(battle_log, str(merc_id)), mercs))
		else:
			events.append(_hurt(str(merc_id), outcome, mercs))
	for merc_id: String in dead:
		_mourn(merc_id, mercs, events)
	return events


## Everything a save needs: the chronicle, the memories, the captain and every merc's
## injuries, as plain data (SaveModel carries it as the "wounds" block).
func state(mercs: Dictionary) -> Dictionary:
	return {
		"chronicle": chronicle.state(),
		"memories": memory.state(),
		"captain": captain_id,
		"injuries": Injury.state(mercs)
	}


## An Aftermath that continues where state() was taken (an empty block gives empty stores);
## `injuries` on the result holds the restored injuries of the living, {id: [records]}.
static func restore(saved: Dictionary, rng: Rng, rules: Dictionary, defs: Array) -> Aftermath:
	var aftermath := Aftermath.new(rng, rules, defs)
	aftermath.chronicle = Chronicle.restore(_dict(saved, "chronicle"))
	aftermath.memory = Memory.restore(_dict(saved, "memories"))
	aftermath.captain_id = str(saved.get("captain", ""))
	aftermath.injuries = Injury.restore(_dict(saved, "injuries"), aftermath.chronicle)
	return aftermath


func _hurt(merc_id: String, outcome: String, mercs: Dictionary) -> Dictionary:
	var injury_id := str(Injury.definition_of_kind(_defs, outcome).get("id", ""))
	var merc: Dictionary = mercs[merc_id]
	mercs[merc_id] = Injury.apply(merc, injury_id, day, _defs)
	return {"type": "triage", "merc": merc_id, "outcome": outcome, "injury": injury_id}


func _die(merc_id: String, cause: String, mercs: Dictionary) -> Dictionary:
	chronicle.record_death(merc_id, day, cause)
	mercs.erase(merc_id)
	return {"type": "death", "merc": merc_id, "day": day, "cause": cause}


## The memories and the succession a death leaves behind, once every death of the fight is
## in the chronicle (so a successor is never one who also fell).
func _mourn(dead_id: String, mercs: Dictionary, events: Array[Dictionary]) -> void:
	var was_captain := dead_id == captain_id
	var key := Memory.KEY_CAPTAIN_DIED if was_captain else Memory.KEY_COMRADE_DIED
	memory.on_death(dead_id, mercs.keys(), day, key)
	if not was_captain:
		return
	var candidates: Array[Dictionary] = []
	for merc_id: Variant in mercs:
		var merc: Dictionary = mercs[merc_id]
		var stats: Dictionary = _dict(merc, "stats")
		candidates.append({"id": str(merc_id), "resolve": Injury.num(stats, "resolve")})
	var event := Succession.after_death(
		dead_id, captain_id, candidates, _dict(_rules, "succession"), day
	)
	captain_id = str(event.get("captain", ""))
	memory.write(str(event.get("dissent", "")), Memory.KEY_DISSENT, captain_id, day)
	events.append(event)


## The unit that last hit this merc in the log ("" when the log does not say).
func _cause(battle_log: Array, merc_id: String) -> String:
	var cause := ""
	for entry: Variant in battle_log:
		var event: Dictionary = entry if entry is Dictionary else {}
		if event.get("type", "") == "attack" and event.get("target", "") == merc_id:
			if event.get("hit", false) == true:
				cause = str(event.get("unit", ""))
	return cause


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}
