class_name Casting
extends RefCounted
## Casting rules (Phase 2 M7): a storylet names roles, each with a "require" list of tags
## (see StoryTags), and the company's mercs fill them. casts() lists every way to fill all
## roles with different mercs, in id order, so which casts exist is deterministic; picking
## one of several is the caller's seeded roll. A role may ask for a relationship with an
## earlier role ("shares_memory_with:mourner"). No casts means the storylet is not eligible.

var _tags: Dictionary = {}
var _memory: Memory = null
var _ids: Array[String] = []
var _roles: Array = []
var _found: Array[Dictionary] = []


## tags_by_merc: {merc id: Array[String]} (StoryTags.of_merc), memory: the relationship store.
func _init(tags_by_merc: Dictionary, memory: Memory) -> void:
	_tags = tags_by_merc
	_memory = memory
	for key: Variant in tags_by_merc:
		_ids.append(str(key))
	_ids.sort()


## Every complete cast of `roles` ([{"role": name, "require": [tags]}]) as {role: merc id}.
func casts(roles: Array) -> Array[Dictionary]:
	_roles = roles
	_found = []
	if not roles.is_empty():
		_fill(0, {})
	return _found


func _fill(index: int, so_far: Dictionary) -> void:
	if index >= _roles.size():
		_found.append(so_far.duplicate())
		return
	var rule: Dictionary = _roles[index] if _roles[index] is Dictionary else {}
	var role := str(rule.get("role", ""))
	for merc_id: String in _ids:
		if so_far.values().has(merc_id) or not _fits(merc_id, rule, so_far):
			continue
		so_far[role] = merc_id
		_fill(index + 1, so_far)
		so_far.erase(role)


func _fits(merc_id: String, rule: Dictionary, so_far: Dictionary) -> bool:
	var needs: Variant = rule.get("require", [])
	if not needs is Array:
		return true
	var held: Array = _tags.get(merc_id, [])
	for raw: Variant in needs:
		var need := str(raw)
		if need.begins_with(StoryTags.SHARES_PREFIX):
			var other := str(so_far.get(need.trim_prefix(StoryTags.SHARES_PREFIX), ""))
			if other == "" or not _memory.shared(merc_id, other):
				return false
		elif need.begins_with(StoryTags.NOT_PREFIX):
			if held.has(need.trim_prefix(StoryTags.NOT_PREFIX)):
				return false
		elif not held.has(need):
			return false
	return true
