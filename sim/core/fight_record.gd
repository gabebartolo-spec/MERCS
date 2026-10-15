class_name FightRecord
extends RefCounted
## Ironman's record of a fight on the road (D-087: quitting can't undo a death or a lost fight).
## It holds the save as it stood when Fight was chosen (SaveModel.to_dict: the world with its
## encounter marked fighting, the Rng, the company and the wounds, all at the fight's start) and
## every action the battle has taken since, in order, both sides'. The save on disk during the
## fight is that start with the actions under the optional key "fight" (saved()); a reload reads
## the start as any save and the actions back (read()), builds the same battle from the same
## Rng and replays them (replay()), so the fight resumes at the very turn it was left. No disk
## access, no Rng draw: replaying runs the battle's own rules again.

## The save's optional key: {"actions": [action, ...]}, absent outside a fight.
const KEY := "fight"
const ACTIONS := "actions"

## The save as it stood when the fight began.
var start := {}
## The actions applied since, each as JSON keeps it (a cell as [x, y]).
var actions: Array[Dictionary] = []


## A record from the fight's starting save and the actions already taken (a resumed fight's).
static func make(starting_save: Dictionary, taken: Array[Dictionary] = []) -> FightRecord:
	var record := FightRecord.new()
	record.start = starting_save.duplicate(true)
	for action: Dictionary in taken:
		record.record(action)
	return record


## One more action the battle applied (Battle.apply's input, a cell as Vector2i).
func record(action: Dictionary) -> void:
	var plain := {}
	for key: Variant in action:
		var value: Variant = action[key]
		if value is Vector2i:
			var cell: Vector2i = value
			plain[str(key)] = [cell.x, cell.y]
		else:
			plain[str(key)] = value
	actions.append(plain)


## What the save on disk holds during the fight: the start with the actions so far.
func saved() -> Dictionary:
	var out := start.duplicate(true)
	out[KEY] = {ACTIONS: actions.duplicate(true)}
	return out


## The actions a save holds, in Battle.apply's form (a cell as Vector2i); [] when none.
static func read(saved: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var found: Variant = saved.get(KEY, {})
	var block: Dictionary = found if found is Dictionary else {}
	var listed: Variant = block.get(ACTIONS, [])
	if not listed is Array:
		return out
	var entries: Array = listed
	for entry: Variant in entries:
		if entry is Dictionary:
			var plain: Dictionary = entry
			out.append(_action(plain))
	return out


## Applies the actions to a freshly built battle in order; the number applied. It stops at the
## first one the battle refuses (a save from another build), leaving the fight where it stands.
static func replay(battle: Battle, taken: Array[Dictionary]) -> int:
	var applied := 0
	for action: Dictionary in taken:
		if battle.is_over() or battle.apply(action).is_empty():
			break
		applied += 1
	return applied


## An action read back from JSON: ids as text, a cell [x, y] as Vector2i.
static func _action(plain: Dictionary) -> Dictionary:
	var action := {}
	for key: Variant in plain:
		var value: Variant = plain[key]
		if value is Array:
			var pair: Array = value
			action[str(key)] = Vector2i(_whole(pair, 0), _whole(pair, 1))
		else:
			action[str(key)] = str(value)
	return action


static func _whole(pair: Array, index: int) -> int:
	if index >= pair.size():
		return 0
	var value: Variant = pair[index]
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0
