class_name Palette
extends RefCounted
## The one lookup for every colour the game draws (06_STYLE_ART.md section 2): a reference
## "ramp:index" ("soot:1", "verdure:3") names a step of a ramp in the core palette
## (assets/palette/core.json) or the biome's (assets/palette/biomes/heartland.json). Data files
## and presentation code hold references, never hex or RGB. This file is the colour owner: the
## palette test lets literal colours live here only.

const LOOK_PATH := "res://data/balance/look_ui.json"
const CORE_PATH := "res://assets/palette/core.json"
const SEPARATOR := ":"
## Relative luminance weights and constants of the WCAG 2 contrast ratio.
const LUMA := Vector3(0.2126, 0.7152, 0.0722)
const LINEAR_CUTOFF := 0.04045
const LINEAR_SLOPE := 12.92
const GAMMA_OFFSET := 0.055
const GAMMA_SCALE := 1.055
const GAMMA := 2.4
const FLARE := 0.05
## Not palette colours: a fully clear pixel, and "no tint" for a modulate.
const CLEAR := Color(0.0, 0.0, 0.0, 0.0)
const NO_TINT := Color(1.0, 1.0, 1.0, 1.0)

static var _ramps: Dictionary = {}
static var _look: Dictionary = {}
static var _loaded := false


## The colour a reference names. An unknown reference is an error and reads as magenta-free
## black (the palette test fails on it long before a player sees it).
static func colour(ref: String) -> Color:
	_load()
	var parts := ref.split(SEPARATOR)
	if parts.size() == 2 and _ramps.has(parts[0]):
		var steps: Array = _ramps[parts[0]]
		var index := int(parts[1])
		if parts[1].is_valid_int() and index >= 0 and index < steps.size():
			return steps[index]
	push_error("palette: unknown colour reference '%s'" % ref)
	return CLEAR


## Whether a reference names a colour.
static func has(ref: String) -> bool:
	_load()
	var parts := ref.split(SEPARATOR)
	if parts.size() != 2 or not parts[1].is_valid_int() or not _ramps.has(parts[0]):
		return false
	var steps: Array = _ramps[parts[0]]
	return int(parts[1]) >= 0 and int(parts[1]) < steps.size()


## A UI role's colour (data/balance/look_ui.json "roles"), e.g. "text" or "panel_back".
static func role(name: String) -> Color:
	_load()
	var roles: Dictionary = _look.get("roles", {})
	return colour(str(roles.get(name, "")))


## The look file: roles, contrast pairs and the contrast floor.
static func look() -> Dictionary:
	_load()
	return _look


## Every colour in core + the biome, in file order (the flattened palette).
static func all_colours() -> Array[Color]:
	_load()
	var out: Array[Color] = []
	for ramp: String in _ramps:
		var steps: Array = _ramps[ramp]
		for step: Color in steps:
			out.append(step)
	return out


## Whether a colour is one of the palette's (to 8 bits per channel), or fully clear.
static func contains(candidate: Color) -> bool:
	if candidate.a == 0.0:
		return true
	for known: Color in all_colours():
		if known.to_rgba32() == Color(candidate, 1.0).to_rgba32():
			return true
	return false


## The WCAG 2 contrast ratio of two colours, 1 (none) to 21 (black on white).
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + FLARE) / (minf(la, lb) + FLARE)


static func _luminance(c: Color) -> float:
	return LUMA.x * _linear(c.r) + LUMA.y * _linear(c.g) + LUMA.z * _linear(c.b)


static func _linear(channel: float) -> float:
	if channel <= LINEAR_CUTOFF:
		return channel / LINEAR_SLOPE
	return pow((channel + GAMMA_OFFSET) / GAMMA_SCALE, GAMMA)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_look = _json(LOOK_PATH)
	_add_ramps(_json(CORE_PATH))
	_add_ramps(_json(str(_look.get("biome", ""))))


static func _add_ramps(file: Dictionary) -> void:
	var ramps: Variant = file.get("ramps", [])
	if not ramps is Array:
		return
	var list: Array = ramps
	for entry: Variant in list:
		if not entry is Dictionary:
			continue
		var ramp: Dictionary = entry
		var steps: Array[Color] = []
		var hexes: Variant = ramp.get("colours", [])
		if hexes is Array:
			var hex_list: Array = hexes
			for hex: Variant in hex_list:
				steps.append(Color.html(str(hex)))
		_ramps[str(ramp.get("name", ""))] = steps


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("palette: cannot read %s" % path)
	return {}
