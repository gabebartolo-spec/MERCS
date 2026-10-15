class_name LineupPick
extends RefCounted
## Which enemies an encounter brings (Phase 5 C7): one of its type's line-ups
## (data/encounters.json), chosen by place and day, never by the company's strength (vision,
## "encounters do not scale"; director 2026-10-16). A line-up written as a plain list of
## fighters can come anywhere on any day; one written as {"fighters", "places", "from_day"}
## comes only when the band stands on one of its "places" (terrain names, TileRegion
## TERRAIN_KEYS) and only from "from_day" on. One of those allowed is rolled on the
## "encounter" stream. Nothing here reads the company. No Node, no clock.

const KEY_FIGHTERS := "fighters"
const KEY_PLACES := "places"
const KEY_FROM_DAY := "from_day"


## The fighters of the line-up rolled for an encounter met on `place` on `day`, or [] when the
## type has no line-up. When the data allows none there, every line-up is in the draw (the
## data checks keep each type with one that stands anywhere from day 0).
static func pick(lineups: Array, place: String, day: int, rng: Rng) -> Array:
	var open := allowed(lineups, place, day)
	if open.is_empty():
		for lineup: Variant in lineups:
			open.append(fighters_of(lineup))
	if open.is_empty():
		return []
	var chosen: Array = open[rng.roll(WorldSim.ENCOUNTER_STREAM, 0, open.size() - 1)]
	return chosen


## The fighters of every line-up that may come on `place` on `day`, in data order.
static func allowed(lineups: Array, place: String, day: int) -> Array:
	var open: Array = []
	for lineup: Variant in lineups:
		if comes(lineup, place, day):
			open.append(fighters_of(lineup))
	return open


## Whether one line-up may come on `place` on `day`.
static func comes(lineup: Variant, place: String, day: int) -> bool:
	if not lineup is Dictionary:
		return lineup is Array
	var narrowed: Dictionary = lineup
	if day < Merc.whole(narrowed.get(KEY_FROM_DAY, 0)):
		return false
	var places: Variant = narrowed.get(KEY_PLACES, [])
	if not places is Array:
		return true
	var listed: Array = places
	return listed.is_empty() or listed.has(place)


## A line-up's list of fighters ({"fighter", "cell"} entries), in either form.
static func fighters_of(lineup: Variant) -> Array:
	if lineup is Array:
		var plain: Array = lineup
		return plain
	if not lineup is Dictionary:
		return []
	var narrowed: Dictionary = lineup
	var listed: Variant = narrowed.get(KEY_FIGHTERS, [])
	if not listed is Array:
		return []
	var fighters: Array = listed
	return fighters
