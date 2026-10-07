extends RefCounted
## GATE TEST: sim clock stub. Hosts gate violations 2 and 4; never merge.
class_name SimClock


func now_msec() -> int:
	return Time.get_ticks_msec()  # GATE-2 clock read in sim


func roll() -> int:
	return randi()  # GATE-4 randi() outside rng.gd
