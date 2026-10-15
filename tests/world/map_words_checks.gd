extends RefCounted
## What the map shows of every party and encounter type, run by tests/run_overworld_tests.gd
## (Phase 5 C4 review): every party type in data/balance/world.json "parties" has a token colour
## (data/balance/overworld.json "colours", a palette reference), so none is invisible; every
## encounter type in data/encounters.json has its panel's title, body and fight words in
## data/text/en.json, so no panel shows a bare key.

const WORLD_DATA := "res://data/balance/world.json"
const OVERWORLD_DATA := "res://data/balance/overworld.json"
const ENCOUNTERS_DATA := "res://data/encounters.json"
const PANEL_PARTS: Array[String] = ["title", "body", "fight"]

var _check: Callable


## check: the runner's check(condition, expectation).
func run(check: Callable) -> void:
	_check = check
	_check_party_colours()
	_check_encounter_words()


func _check_party_colours() -> void:
	var parties: Dictionary = _json(WORLD_DATA).get("parties", {})
	var colours: Dictionary = _json(OVERWORLD_DATA).get("colours", {})
	var missing: Array[String] = []
	for type: Variant in parties:
		if not parties[type] is Dictionary:
			continue
		var ref := str(colours.get(type, ""))
		if ref.is_empty() or Palette.colour(ref) == Palette.CLEAR:
			missing.append(str(type))
	_check.call(
		missing.is_empty(),
		"every party type has a token colour on the map (missing %s)" % [missing]
	)


func _check_encounter_words() -> void:
	var bare: Array[String] = []
	for held: Variant in _json(ENCOUNTERS_DATA).get("encounters", []):
		var encounter: Dictionary = held if held is Dictionary else {}
		for part: String in PANEL_PARTS:
			var key := "world.encounter.%s.%s" % [encounter.get("type", ""), part]
			if Text.t(key) == key:
				bare.append(key)
	_check.call(bare.is_empty(), "every encounter type has its panel words (bare %s)" % [bare])


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
