class_name Storylet
extends RefCounted
## One authored storylet, read from data/storylets.json (Phase 2 M7; schema
## data/schema/storylets.schema.json), as pure functions on its definition. A storylet has
## a trigger (hook, earliest day, location kinds), casting rules (roles over tags), a
## visible check (die, difficulty, and who may attempt it with which stat) and two branches,
## success and a fail-forward failure, each a list of effects that change state (a memory
## sentence on a cast merc, experience). Both branches change something: failing is never a
## dead end. StoryBook runs it; the words are in data/text/en.json, the director's to write.

const SUCCESS := "success"
const FAILURE := "failure"


## Whether the context ({"hook", "day", "site", "site_kind"}) meets the trigger.
static func trigger_met(def: Dictionary, context: Dictionary) -> bool:
	var trigger := _dict(def, "trigger")
	var tags := StoryTags.of_context(context)
	if not tags.has("hook:%s" % str(trigger.get("hook", ""))):
		return false
	if Injury.num(context, "day") < Injury.num(trigger, "min_day"):
		return false
	var kinds := _list(trigger, "location_kinds")
	return (
		kinds.is_empty()
		or kinds.any(func(kind: Variant) -> bool: return tags.has("kind:%s" % str(kind)))
	)


static func roles(def: Dictionary) -> Array:
	return _list(def, "cast")


## The ways the cast may attempt the check, shown before the roll:
## [{"role", "merc", "stat", "skill", "difficulty", "die_sides", "need", "odds"}].
static func attempts(def: Dictionary, cast: Dictionary, company: Company) -> Array[Dictionary]:
	var check := _dict(def, "check")
	var difficulty := Injury.num(check, "difficulty")
	var sides := Injury.num(check, "die_sides")
	var out: Array[Dictionary] = []
	for raw: Variant in _list(check, "attempts"):
		var option: Dictionary = raw if raw is Dictionary else {}
		var role := str(option.get("role", ""))
		var merc := company.member(str(cast.get(role, "")))
		if merc == null:
			continue
		var stat := str(option.get("stat", ""))
		var skill := merc.stat(stat)
		var entry := {"role": role, "merc": merc.id, "stat": stat, "skill": skill}
		entry["difficulty"] = difficulty
		entry["die_sides"] = sides
		entry["need"] = difficulty - skill
		entry["odds"] = Checks.odds(sides, skill, difficulty)
		out.append(entry)
	return out


## The branch's text key for its outcome line.
static func line_key(def: Dictionary, branch: String) -> String:
	return str(_dict(def, branch).get("line_key", ""))


## Applies a branch's effects to the company and the memories; returns what was done:
## {"kind": "memory", "merc", "key", "about"} and {"kind": "xp", "merc", "amount"}.
static func apply(
	def: Dictionary, branch: String, cast: Dictionary, company: Company, memory: Memory, day: int
) -> Array[Dictionary]:
	var done: Array[Dictionary] = []
	for raw: Variant in _list(_dict(def, branch), "effects"):
		var effect: Dictionary = raw if raw is Dictionary else {}
		var merc_id := str(cast.get(str(effect.get("role", "")), ""))
		if merc_id == "":
			continue
		if effect.get("kind", "") == "memory":
			var about := str(cast.get(str(effect.get("about_role", "")), ""))
			var key := str(effect.get("key", ""))
			memory.record(merc_id, key, {"about": about, "storylet": str(def.get("id", ""))}, day)
			done.append({"kind": "memory", "merc": merc_id, "key": key, "about": about})
		elif effect.get("kind", "") == "xp":
			var amount := Injury.num(effect, "amount")
			company.gain(merc_id, amount)
			done.append({"kind": "xp", "merc": merc_id, "amount": amount})
	return done


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}


static func _list(block: Dictionary, key: String) -> Array:
	var value: Variant = block.get(key, [])
	return value if value is Array else []
