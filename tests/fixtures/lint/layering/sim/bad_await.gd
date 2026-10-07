extends RefCounted
# One planted violation per line, marked PLANT <RULE>.
# Look-alike: the word await in a comment, a string and an identifier.

signal done

var await_count: int = 0
var label: String = "await done"


func wait_for_it() -> void:
	await done  # PLANT SIM-AWAIT
