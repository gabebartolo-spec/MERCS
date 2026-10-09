class_name Checks
extends RefCounted
## Visible checks (vision pillars 5 and 7): the player picks who attempts, then the dice
## decide, in the open. A check rolls one die on the Rng "story" stream; it succeeds when the
## roll plus the attempter's skill reaches the difficulty. Who attempts is itself the
## roleplay, so best() only suggests the company member with the highest skill. The result
## carries every number so presentation can show the roll, never hide it.

const STREAM := "story"


## {"roll": int, "skill": int, "need": int, "success": bool}; need is the roll required.
static func attempt(rng: Rng, die_sides: int, skill: int, difficulty: int) -> Dictionary:
	var roll := rng.roll(STREAM, 1, die_sides)
	var need := difficulty - skill
	return {"roll": roll, "skill": skill, "need": need, "success": roll >= need}


## The id with the highest skill in {id: skill}; ties go to the lowest id. "" when empty.
static func best(skills: Dictionary) -> String:
	var pick := ""
	var top := 0
	for key: Variant in skills:
		var id := str(key)
		var skill: int = skills[key]
		if pick.is_empty() or skill > top or (skill == top and id < pick):
			pick = id
			top = skill
	return pick
