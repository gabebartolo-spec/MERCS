extends RefCounted
# One planted violation per line, marked PLANT <RULE>.
# Look-alikes: randi() in a comment, "randf()" in a string, seed and shuffle as names.

var label: String = "randf() and randi() and seed(1) are only words here"
var seed_value: int = 0
var shuffled_count: int = 0


func configure(seed: int, count: int) -> int:
	return seed + count


func derive() -> Rng:
	return Rng.new()


func rolls(deck: Array) -> void:
	var a: int = randi()  # PLANT SIM-RANDOM
	var b: float = randf()  # PLANT SIM-RANDOM
	var c: int = randi_range(1, 6)  # PLANT SIM-RANDOM
	var d: float = randf_range(0.0, 1.0)  # PLANT SIM-RANDOM
	var e: float = randfn(0.0, 1.0)  # PLANT SIM-RANDOM
	randomize()  # PLANT SIM-RANDOM
	seed(42)  # PLANT SIM-RANDOM
	var f: Array = rand_from_seed(7)  # PLANT SIM-RANDOM
	var g: RandomNumberGenerator = null  # PLANT SIM-RANDOM
	deck.shuffle()  # PLANT SIM-RANDOM
	var h = deck.pick_random()  # PLANT SIM-RANDOM
