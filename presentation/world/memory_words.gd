class_name MemoryWords
extends RefCounted
## A memory in words (Phase 2 M7): the sentence a Memory entry stands for, from its text key
## in data/text/en.json, filled with the entry's params, its day and the name of the merc it
## is about. Names come from the company, which keeps the dead's names too
## (Company.name_of); the id only when the data has no name for it.


static func line(entry: Dictionary, company: Company) -> String:
	var held: Variant = entry.get("params", {})
	var params := {}
	if held is Dictionary:
		var kept: Dictionary = held
		params = kept.duplicate()
	var about := str(params.get("about", entry.get("about", "")))
	params["name"] = company.name_of(about) if company != null else about
	params["day"] = Injury.num(entry, "day")
	return Text.t(str(entry.get("key", "")), params)


static func lines(entries: Array[Dictionary], company: Company) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in entries:
		out.append(line(entry, company))
	return out
