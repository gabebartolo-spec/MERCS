class_name StoryletState
extends RefCounted
## Which storylets have fired and when (Phase 2 M7): the ids fired, in order, and the day each
## last fired. A storylet that fires once never comes back; one with a cooldown waits that
## many days. Saved as the optional "story" key of the save; a save without it reads as
## nothing fired, so no version bump. Nothing here rolls.

var fired: Array[String] = []
var last_day: Dictionary = {}


func mark(storylet_id: String, day: int) -> void:
	if not fired.has(storylet_id):
		fired.append(storylet_id)
	last_day[storylet_id] = day


func has_fired(storylet_id: String) -> bool:
	return fired.has(storylet_id)


## Whether the storylet may be offered on `day`: not fired already when `once`, and the
## cooldown (days) past since it last fired.
func ready(storylet_id: String, day: int, once: bool, cooldown_days: int) -> bool:
	if not has_fired(storylet_id):
		return true
	if once:
		return false
	return day - Injury.num(last_day, storylet_id) >= cooldown_days


func state() -> Dictionary:
	return {"fired": fired.duplicate(), "last_day": last_day.duplicate()}


static func restore(saved: Dictionary) -> StoryletState:
	var restored := StoryletState.new()
	var ids: Variant = saved.get("fired", [])
	var days: Variant = saved.get("last_day", {})
	var by_id: Dictionary = days if days is Dictionary else {}
	if ids is Array:
		var list: Array = ids
		for raw: Variant in list:
			restored.mark(str(raw), Injury.num(by_id, str(raw)))
	return restored
