class_name StoryTags
extends RefCounted
## The tags a storylet is cast over (Phase 2 M7), all derived, none stored. Strings, so data
## can name them:
##   character      "species:<s>", "captain", "placeholder" (from the merc's data and the office)
##   memory         "memory:<key>" for each memory sentence the merc holds
##   relationship   between two mercs, not a tag: Memory.shared(), asked as
##                  "shares_memory_with:<role>" in a casting rule
##   world          "hook:<rest|arrival>", "day:<n>"
##   location       "location:<site id>", "kind:<hub|hamlet|wild>"
## A casting rule's "require" list is these strings; a leading "!" asks for the tag's absence.

const SHARES_PREFIX := "shares_memory_with:"
const NOT_PREFIX := "!"
const CAPTAIN := "captain"


static func of_merc(merc: Merc, captain_id: String, memory: Memory) -> Array[String]:
	var tags: Array[String] = []
	if merc.species != "":
		tags.append("species:%s" % merc.species)
	if merc.id == captain_id:
		tags.append(CAPTAIN)
	if merc.placeholder:
		tags.append("placeholder")
	for entry: Dictionary in memory.of(merc.id):
		var tag := "memory:%s" % str(entry.get("key", ""))
		if not tags.has(tag):
			tags.append(tag)
	return tags


## context: {"hook": String, "day": int, "site": site id, "site_kind": String}.
static func of_context(context: Dictionary) -> Array[String]:
	return [
		"hook:%s" % str(context.get("hook", "")),
		"day:%d" % Injury.num(context, "day"),
		"location:%s" % str(context.get("site", "")),
		"kind:%s" % str(context.get("site_kind", ""))
	]
