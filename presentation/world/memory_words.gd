class_name MemoryWords
extends RefCounted
## A memory in words (Phase 2 M7): the sentence a Memory entry stands for, from its text key
## in data/text/en.json, filled with the entry's params, its day and the name of the merc it
## is about. Names come from the company; a merc no longer in it (dead) reads by id.


static func line(entry: Dictionary, company: Company) -> String:
	var held: Variant = entry.get("params", {})
	var params: Dictionary = (held as Dictionary).duplicate() if held is Dictionary else {}
	var about := str(params.get("about", entry.get("about", "")))
	var merc := company.member(about) if company != null else null
	params["name"] = merc.display_name if merc != null else about
	params["day"] = Injury.num(entry, "day")
	return Text.t(str(entry.get("key", "")), params)


static func lines(entries: Array[Dictionary], company: Company) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in entries:
		out.append(line(entry, company))
	return out
