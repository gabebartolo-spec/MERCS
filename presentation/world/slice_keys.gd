class_name SliceKeys
extends RefCounted
## The slice's command keys: each action's key is the text "key.<action>" (data/text/en.json).
## Letters only: the director's keyboard has no working function keys (2026-10-15: "remove
## the F2 stuff, function buttons dont work on my keyboard"), and the smoke suite fails on
## any function key in presentation or ui. Escape always closes the open panel.

const CLOSE := &"close"
const ACTIONS: Array[StringName] = [
	&"map", &"company", &"hub", &"loop", &"help", &"frame_time", &"time_of_day", &"rain"
]

var _by_code: Dictionary = {}


## actions: the command names; each key is read as OS.find_keycode_from_string reads it ("M").
func _init(actions: Array[StringName]) -> void:
	for action: StringName in actions:
		var code := OS.find_keycode_from_string(Text.t("key." + action))
		if code != KEY_NONE:
			_by_code[code] = action
	_by_code[KEY_ESCAPE] = CLOSE


## The action a key stands for, or &"" when it is not a command key.
func action(code: int) -> StringName:
	var found: Variant = _by_code.get(code, &"")
	return found if found is StringName else &""


## The key bound to an action, KEY_NONE when none is.
func key_for(action_name: StringName) -> int:
	for code: int in _by_code:
		if _by_code[code] == action_name:
			return code
	return KEY_NONE
