class_name CompanyWounds
extends RefCounted
## The company meets the wound ladder (Phase 2, the wiring of milestones 3, 4 and 5): a fight
## fields the living roster (the captain leading, a merc's numbers as injuries leave them),
## a hook on the battle's hits notes every company merc a blow puts down, and after the fight
## those mercs are triaged by Aftermath on the Rng "injury" stream: wound, temporary or
## permanent injury, or death. The dead leave the Company for good (Company.bury), the
## chronicle and the comrades' memories are written, and if the captain fell the succession
## hands the office on. state() is the save's "wounds" block (chronicle, memories, captain,
## injuries); the company's own state is the "company" block. Never rolls the battle stream,
## never reads the clock: the day is given. No Node, no file access.

## The game's one company, shared with the screens.
var company: Company = null
## The day of the world, set by the caller before fielding, resolving or reading injuries.
var day := 0
## The ids fielded in the fight now; a hit on any other id is not a company merc's.
var fielded: Array[String] = []

var _after: Aftermath = null
var _memory: Memory = null
var _rules := {}
var _defs: Array = []
var _injuries := {}
var _downed: Array[Dictionary] = []
## Enemies each fielded merc has put down this fight: {merc id: count} (experience, D-095).
var _kills := {}


## rules: data/balance/injury.json; defs: data/injuries.json "injuries"; saved: the "wounds"
## block of a save ({} for none). The dead of the chronicle are buried out of the company, so
## no save can bring one back.
static func make(
	held: Company, saved: Dictionary, rng: Rng, rules: Dictionary, defs: Array
) -> CompanyWounds:
	var wounds := CompanyWounds.new()
	wounds.company = held
	wounds._rules = rules
	wounds._defs = defs
	wounds._take(Aftermath.restore(saved, rng, rules, defs))
	for entry: Dictionary in wounds._after.chronicle.entries:
		held.bury(str(entry.get("merc", "")))
	return wounds


## Carries on with another Rng (the world's, once the save is read): the stores stay.
func bind(rng: Rng) -> void:
	_take(Aftermath.restore(state(), rng, _rules, _defs))


## The fighters of the next fight: the living roster, the captain first, one per cell, each
## with the numbers their injuries leave. Starts a fresh note of who falls.
func units(cells: Array[Vector2i], side: int) -> Array[BattleUnit]:
	var mercs := _mercs()
	var ids: Array[String] = []
	var fit := {}
	for merc_id: String in company.fighting_order():
		if ids.size() < cells.size():
			ids.append(merc_id)
			fit[merc_id] = Injury.effective_stats(_row(mercs, merc_id), day, _defs)
	fielded = ids
	_downed.clear()
	_kills.clear()
	return company.battle_units(ids, cells, side, fit)


## The battle's hit hook (Battle.set_hit_hook): a blow that puts a company merc down is
## noted for the triage and logged as an "injury" event right after the hit. Rolls nothing.
func hit_hook(hit: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var target := str(hit.get("target", ""))
	var actor := str(hit.get("unit", ""))
	if hit.get("down", false) == true and actor in fielded and not target in fielded:
		_kills[actor] = Merc.whole(_kills.get(actor, 0)) + 1
	if hit.get("down", false) == true and target in fielded and not is_noted(target):
		_downed.append({"merc": target, "by": str(hit.get("unit", ""))})
		events.append({"type": "injury", "unit": target, "by": str(hit.get("unit", ""))})
	return events


func is_noted(merc_id: String) -> bool:
	for note: Dictionary in _downed:
		if note.get("merc", "") == merc_id:
			return true
	return false


## Down, then triage: every merc the hook noted is rolled (wound, temporary, permanent or
## dead), the dead buried and mourned, the succession applied. Returns Aftermath's events in
## id order: "triage", "death" and "succession"; last, "campaign_end" when that left nobody
## alive in the company.
func resolve() -> Array[Dictionary]:
	var battle_log: Array = []
	for note: Dictionary in _downed:
		battle_log.append(
			{"type": "attack", "unit": note["by"], "target": note["merc"], "hit": true}
		)
		battle_log.append({"type": "down", "unit": note["merc"]})
	_after.day = day
	_after.captain_id = company.captain_id
	var mercs := _mercs()
	var events := _after.resolve(battle_log, mercs)
	_injuries.clear()
	for merc_id: Variant in mercs:
		var list := Injury.records(_row(mercs, str(merc_id)))
		if not list.is_empty():
			_injuries[str(merc_id)] = list
	for event: Dictionary in events:
		_apply(event)
	_downed.clear()
	events.append_array(_award())
	_kills.clear()
	fielded = []
	if company.is_wiped():
		events.append({"type": "campaign_end", "day": day, "fallen": company.fallen.duplicate()})
	return events


## Experience from the fight (D-095, data/balance/company.json "xp"): every fielded merc who
## lived through it gets "per_fight", and "per_kill" for each enemy they put down. The dead
## (already buried) get nothing, a merc who was not fielded was not here. Returns
## {"type": "xp", "merc", "gain", "level", "raised"} per merc, in fielding order. Rolls nothing.
func _award() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for merc_id: String in fielded:
		var merc := company.member(merc_id)
		if merc == null:
			continue
		var gain := company.xp_for_fight(Merc.whole(_kills.get(merc_id, 0)))
		var raised := merc.gain(gain)
		events.append(
			{"type": "xp", "merc": merc_id, "gain": gain, "level": merc.level(), "raised": raised}
		)
	return events


## Whether the campaign is over: every merc of the company is dead (Company.is_wiped).
func ended() -> bool:
	return company.is_wiped()


## The save's "wounds" block.
func state() -> Dictionary:
	return _after.state(_mercs())


func chronicle() -> Chronicle:
	return _after.chronicle


## The memories the company holds, the dead's included.
func memory() -> Memory:
	return _after.memory


func memories_of(merc_id: String) -> Array[Dictionary]:
	return _after.memory.of(merc_id)


## A living merc's injuries still in force: [{"id", "kind", "name_key", "until_day" (absent
## for a permanent one), "role_key" (permanent ones)}], in the order they happened.
func injuries_of(merc_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for record: Dictionary in Injury.records(_row(_mercs(), merc_id)):
		var def := Injury.definition(_defs, str(record.get("id", "")))
		var row := {
			"id": str(record.get("id", "")),
			"kind": str(def.get("kind", "")),
			"name_key": str(def.get("name_key", "")),
			"role_key": str(def.get("role_key", ""))
		}
		if record.has("until_day"):
			row["until_day"] = Injury.num(record, "until_day")
		rows.append(row)
	return rows


## One injury's definition from data/injuries.json ({} when unknown).
func injury_def(injury_id: String) -> Dictionary:
	return Injury.definition(_defs, injury_id)


## The sprite layer ids of a living merc's permanent injuries.
func layers_of(merc_id: String) -> Array[String]:
	return Injury.layers(_row(_mercs(), merc_id), _defs)


## The game's one Memory (the story director's): deaths and dissent are written on it, so
## the storylets see them. The wounds block then saves that same store.
func adopt_memory(shared: Memory) -> void:
	_memory = shared
	_after.memory = shared


func _take(next: Aftermath) -> void:
	_after = next
	if _memory != null:
		_after.memory = _memory
	_injuries = next.injuries.duplicate(true)


func _apply(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"death":
			company.bury(str(event.get("merc", "")))
			_injuries.erase(str(event.get("merc", "")))
		"succession":
			var successor := str(event.get("captain", ""))
			if successor != "":
				company.appoint(successor)


## The roster as Aftermath and Injury read it: {id: {"id", "stats", "injuries"}}, with the
## injuries that have healed by `day` dropped.
func _mercs() -> Dictionary:
	var mercs := {}
	for merc: Merc in company.roster:
		var row := {"id": merc.id, "stats": merc.stats, "injuries": _injuries.get(merc.id, [])}
		mercs[merc.id] = Injury.expire(row, day)
	return mercs


static func _row(mercs: Dictionary, merc_id: String) -> Dictionary:
	var row: Variant = mercs.get(merc_id, {})
	return row if row is Dictionary else {}
