class_name SaveModel
extends RefCounted
## The save as a plain dictionary: the format version, the Rng's position and the world's
## state. to_dict() builds it from a run; from_dict() reads one back, migrating an older
## version step by step, filling defaults for anything missing and refusing a version newer
## than this build knows. No disk access: writing and reading files is presentation's.

const VERSION := 1
## The error codes from_dict() can leave in `error` (empty when ok).
const ERROR_TOO_NEW := "save_version_too_new"

var ok := false
var error := ""
var world: WorldSim = null
var rng: Rng = null


## The Rng's seed and stream positions are written as strings: they are 64-bit ints, and
## JSON holds a number as a double, exact only up to 2^53.
static func to_dict(world_sim: WorldSim, source: Rng) -> Dictionary:
	return {"version": VERSION, "rng": _rng_as_text(source.state()), "world": world_sim.state()}


## balance: data/balance/world.json (the defaults for what the save does not hold). A save
## with no version is read as version 0, the first (unversioned) shape.
static func from_dict(saved: Dictionary, balance: Dictionary) -> SaveModel:
	var model := SaveModel.new()
	if _num(saved, "version") > VERSION:
		model.error = ERROR_TOO_NEW
		return model
	var current := _migrate(saved)
	if current.has("rng"):
		model.rng = Rng.restore(_whole_rng(_dict(current, "rng")))
	else:
		model.rng = Rng.from_seed(_num(_dict(balance, "world"), "seed"))
	model.world = WorldSim.restore(_dict(current, "world"), balance, model.rng)
	model.ok = true
	return model


## Brings a save of any older version up to VERSION one step at a time, on a copy.
static func _migrate(saved: Dictionary) -> Dictionary:
	var current := saved.duplicate(true)
	var version := _num(current, "version")
	while version < VERSION:
		match version:
			0:
				pass  # 0 -> 1: the first versioned shape; the keys are the same, nothing to move.
		# Each later step goes here as one more arm: `N:` rewrites the N shape into N + 1.
		version += 1
		current["version"] = version
	return current


static func _rng_as_text(state: Dictionary) -> Dictionary:
	var streams := {}
	var positions: Dictionary = _dict(state, "streams")
	for name: Variant in positions:
		streams[str(name)] = str(_num(positions, str(name)))
	return {"seed": str(_num(state, "seed")), "streams": streams}


## The Rng block with its seed and stream positions whole again for Rng.restore(), which
## takes ints only: a string holds the exact int64; an int is one; a float is the shape
## saves had before positions were strings, rounded (exact up to 2^53).
static func _whole_rng(block: Dictionary) -> Dictionary:
	var streams := {}
	var saved: Dictionary = _dict(block, "streams")
	for name: Variant in saved:
		streams[str(name)] = _num(saved, str(name))
	return {"seed": _num(block, "seed"), "streams": streams}


## A whole number from a block: an int, a float rounded, or a string of digits read exactly.
static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	if value is String:
		var text: String = value
		return text.to_int() if text.is_valid_int() else 0
	return 0


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}
