class_name StoryBook
extends RefCounted
## The storylets of a run (Phase 2 M7): which one is eligible now, who it is cast with, the
## visible check, and what each branch does. Set `company`, `memory`, `state` and `rng`
## (the run's Rng, so the roll and the casting pick are seeded and saved with it), then
## load_defs(data/storylets.json).
##   offer(context)  -> {} when none is eligible, else {"id", "cast", "attempts", "day"}:
##                      eligibility is deterministic; a choice between casts is one roll on
##                      the Rng "story_cast" stream; nothing is rolled for the check yet.
##   choose(offer, role) -> the check rolled in the open (Checks, Rng "story") for the cast
##                      member of that role, then the branch's effects applied and the
##                      storylet marked fired.
## context: {"hook": "rest"|"arrival", "day", "site", "site_kind"} (see StoryTags).

const CAST_STREAM := "story_cast"

var company: Company = null
var memory: Memory = Memory.new()
var state: StoryletState = StoryletState.new()
var rng: Rng = null

var _defs: Array[Dictionary] = []


## data: the parsed data/storylets.json.
func load_defs(data: Dictionary) -> void:
	_defs.clear()
	var listed: Variant = data.get("storylets", [])
	if listed is Array:
		var all: Array = listed
		for entry: Variant in all:
			if entry is Dictionary:
				var def: Dictionary = entry
				_defs.append(def)


func offer(context: Dictionary) -> Dictionary:
	if company == null or rng == null:
		return {}
	for def: Dictionary in _defs:
		var found := casts_for(def, context)
		if found.is_empty():
			continue
		var pick := 0 if found.size() == 1 else rng.roll(CAST_STREAM, 0, found.size() - 1)
		return {
			"id": str(def.get("id", "")),
			"cast": found[pick],
			"attempts": Storylet.attempts(def, found[pick], company),
			"day": Injury.num(context, "day"),
		}
	return {}


## Every cast that makes `def` eligible in this context (empty: not eligible). No rolling.
func casts_for(def: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	var day := Injury.num(context, "day")
	var once: bool = def.get("once", false) == true
	if not state.ready(str(def.get("id", "")), day, once, Injury.num(def, "cooldown_days")):
		return none
	if company == null or not Storylet.trigger_met(def, context):
		return none
	var tags := {}
	for merc: Merc in company.roster:
		tags[merc.id] = StoryTags.of_merc(merc, company.captain_id, memory)
	return Casting.new(tags, memory).casts(Storylet.roles(def))


## The player picks who attempts (a role of the offer). {} for a role the offer lacks.
## Else {"id", "role", "merc", "roll", "skill", "need", "success", "odds", "branch",
## "line_key", "effects"}.
func choose(made: Dictionary, role: String) -> Dictionary:
	var def := definition(str(made.get("id", "")))
	var picked := {}
	var options: Variant = made.get("attempts", [])
	for raw: Variant in options if options is Array else []:
		var option: Dictionary = raw if raw is Dictionary else {}
		if option.get("role", "") == role:
			picked = option
	if def.is_empty() or picked.is_empty() or rng == null:
		return {}
	var result := Checks.attempt(
		rng,
		Injury.num(picked, "die_sides"),
		Injury.num(picked, "skill"),
		Injury.num(picked, "difficulty")
	)
	var branch := Storylet.SUCCESS if result.get("success", false) == true else Storylet.FAILURE
	var day := Injury.num(made, "day")
	var cast: Dictionary = made.get("cast", {})
	result["id"] = str(def.get("id", ""))
	result["role"] = role
	result["merc"] = str(picked.get("merc", ""))
	result["odds"] = Injury.num(picked, "odds")
	result["branch"] = branch
	result["line_key"] = Storylet.line_key(def, branch)
	result["effects"] = Storylet.apply(def, branch, cast, company, memory, day)
	state.mark(str(def.get("id", "")), day)
	return result


func definition(storylet_id: String) -> Dictionary:
	for def: Dictionary in _defs:
		if def.get("id", "") == storylet_id:
			return def
	return {}
