extends RefCounted
## GATE TEST: randomness owner stub. Hosts gate violations 1 and 6; never merge.
class_name Rng

var x = 3  # GATE-1 untyped declaration
const DRIFT: float = 0.37  # GATE-6 magic number in sim


func next_seed(seed_value: int) -> int:
	return seed_value + 1
