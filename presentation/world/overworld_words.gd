class_name OverworldWords
extends RefCounted
## The overworld's encounter words (data/text/en.json), split from OverworldDirector: what a
## standing encounter says and offers, and what the last one came to. Reads the sim, decides
## nothing.


## Why a step was refused, in words: the edge of the land, water, or a town's walls.
static func blocked(world: WorldSim, direction: Vector2i) -> String:
	var target := world.band + direction
	if not world.region.inside(target):
		return Text.t("world.panel.blocked_edge")
	if world.region.terrain(target) == TileRegion.Terrain.TOWN:
		return Text.t("world.panel.blocked_building")
	return Text.t("world.panel.blocked_water")


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
## and, while the supplies cover a patrol's toll, the toll (`toll_id`). With a `company` the
## captain may sit out: a second fight choice (`sit_out_id`) when a field sergeant can stand in,
## and the body says what each choice does to the company's nerve before it is made.
static func encounter(
	world: WorldSim,
	fight_id: String,
	toll_id: String,
	company: Company = null,
	sit_out_id: String = ""
) -> Dictionary:
	var kind := str(world.encounter.get("type", ""))
	var params := {"day": world.day, "toll": world.toll_cost()}
	var body := Text.t("world.encounter.%s.body" % kind, params)
	var choices: Array[Dictionary] = [
		{"id": fight_id, "label": Text.t("world.encounter.%s.fight" % kind, params)}
	]
	if company != null and sit_out_id != "" and FieldCommand.can_sit_out(company):
		var captain := company.name_of(company.captain_id)
		body += "\n" + deploy_lines(company)
		choices.append(
			{"id": sit_out_id, "label": Text.t("world.deploy.sit_out", {"captain": captain})}
		)
	if world.toll_cost() > 0 and world.supplies >= world.toll_cost():
		choices.append({"id": toll_id, "label": Text.t("world.encounter.%s.toll" % kind, params)})
	return {
		"title": Text.t("world.encounter.%s.title" % kind),
		"body": body,
		"choices": choices,
	}


## What each choice of the captain's place does, in words, before the fight: one line for
## leading, one for sitting out (the sergeant, the morale dip, the captain's lost experience).
static func deploy_lines(company: Company) -> String:
	var captain := company.name_of(company.captain_id)
	var out := FieldCommand.preview(company, true)
	return (
		Text.t("world.deploy.line_lead", {"captain": captain})
		+ "\n"
		+ (
			Text
			. t(
				"world.deploy.line_out",
				{
					"sergeant": company.name_of(str(out["leader"])),
					"captain": captain,
					"dip": out["dip"],
				}
			)
		)
	)


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
