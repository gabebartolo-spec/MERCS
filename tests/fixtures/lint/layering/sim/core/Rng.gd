class_name Rng
extends RefCounted
## Randomness owner: the one sim file allowed to touch Godot's generators.
## Look-alike: SIM-RANDOM stays silent here (the path lowercases to sim/core/rng.gd).

var _gen: RandomNumberGenerator = RandomNumberGenerator.new()


func reseed(value: int) -> void:
	_gen.seed = value
	seed(value)
	randomize()


func roll(deck: Array) -> int:
	deck.shuffle()
	return randi() + int(randf_range(0.0, 1.0)) + int(deck.pick_random())
