class_name Rng
extends RefCounted
## The only source of randomness in MERCS (05_STYLE_CODE.md "Randomness", D-021). One seed
## per save; each system draws from its own named stream (stream("battle"), stream("world"),
## stream("merc_gen")), seeded from the save seed and the stream's name, so a new system or
## an extra roll in one system never shifts the rolls of another. Not an autoload: sim
## objects receive their Rng. state() and Rng.restore() carry every stream through a save.

var seed_value := 0

var _streams := {}


static func from_seed(save_seed: int) -> Rng:
	var rng := Rng.new()
	rng.seed_value = save_seed
	return rng


## The generator for one system; the same name always returns the same generator.
func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var generator := RandomNumberGenerator.new()
		generator.seed = ("%d:%s" % [seed_value, stream_name]).hash()
		_streams[stream_name] = generator
	var found: RandomNumberGenerator = _streams[stream_name]
	return found


## An integer from low to high inclusive, from one stream.
func roll(stream_name: String, low: int, high: int) -> int:
	return stream(stream_name).randi_range(low, high)


## Every stream's position, for a save: {"seed": int, "streams": {name: state}}.
func state() -> Dictionary:
	var states := {}
	for stream_name: Variant in _streams:
		var generator: RandomNumberGenerator = _streams[stream_name]
		states[stream_name] = generator.state
	return {"seed": seed_value, "streams": states}


## An Rng that continues exactly where state() was taken.
static func restore(saved: Dictionary) -> Rng:
	var seed_read: Variant = saved.get("seed", 0)
	var save_seed: int = seed_read if seed_read is int else 0
	var rng := Rng.from_seed(save_seed)
	var states: Variant = saved.get("streams", {})
	if states is Dictionary:
		var by_name: Dictionary = states
		for stream_name: Variant in by_name:
			var position: Variant = by_name[stream_name]
			if position is int:
				var at: int = position
				rng.stream(str(stream_name)).state = at
	return rng
