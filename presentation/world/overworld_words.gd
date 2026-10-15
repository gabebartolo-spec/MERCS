class_name OverworldWords
extends RefCounted
## The overworld's encounter words (data/text/en.json), split from OverworldDirector: what a
## standing encounter says and offers, and what the last one came to. Reads the sim, decides
## nothing.


## The last encounter log entry in words: what the company won, lost or paid; `otherwise` when
## there is none.
static func outcome(world: WorldSim, otherwise: String) -> String:
	for i: int in range(world.log.size() - 1, -1, -1):
		var entry := world.log[i]
		if entry.get("step") != "encounter":
			continue
		var change: int = entry.get("supplies", 0)
		var here := world.site(world.haven)
		var params := {
			"supplies": absi(change), "site": OverworldMap.site_name(here) if here != null else ""
		}
		return Text.t("world.encounter.outcome.%s" % str(entry.get("outcome", "")), params)
	return otherwise


## The standing encounter as {"title", "body", "choices"}: the fight (its choice id `fight_id`)
## and, while the supplies cover a patrol's toll, the toll (`toll_id`).
static func encounter(world: WorldSim, fight_id: String, toll_id: String) -> Dictionary:
	var kind := str(world.encounter.get("type", ""))
	var params := {"day": world.day, "toll": world.toll_cost()}
	var choices: Array[Dictionary] = [
		{"id": fight_id, "label": Text.t("world.encounter.%s.fight" % kind, params)}
	]
	if world.toll_cost() > 0 and world.supplies >= world.toll_cost():
		choices.append({"id": toll_id, "label": Text.t("world.encounter.%s.toll" % kind, params)})
	return {
		"title": Text.t("world.encounter.%s.title" % kind),
		"body": Text.t("world.encounter.%s.body" % kind, params),
		"choices": choices,
	}


## The campaign's first question, Ironman first: {"title", "body", "choices"}.
static func ironman(on_id: String, off_id: String) -> Dictionary:
	return {
		"title": Text.t("world.ironman.title"),
		"body": Text.t("world.ironman.body"),
		"choices":
		[
			{"id": on_id, "label": Text.t("world.ironman.on")},
			{"id": off_id, "label": Text.t("world.ironman.off")},
		],
	}


## The scenario `id` in the scenarios file's data, or {}.
static func scenario(data: Dictionary, id: String) -> Dictionary:
	var all: Array = data.get("scenarios", [])
	for entry: Variant in all:
		var found: Dictionary = entry if entry is Dictionary else {}
		if found.get("id") == id:
			return found
	return {}


## Puts words made here ({"title", "body", "choices"}) on `panel`.
static func show(panel: LoopPanel, words: Dictionary) -> void:
	var listed: Array = words.get("choices", [])
	var choices: Array[Dictionary] = []
	choices.assign(listed)
	panel.present(str(words.get("title", "")), str(words.get("body", "")), choices)
