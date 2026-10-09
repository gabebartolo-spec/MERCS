class_name Text
extends RefCounted
## Player-visible text by key from data/text/en.json (04_GUARDRAILS.md B12): code never
## holds a string a player reads. t("slice.frame_time", {"ms": "16.6"}) fills {ms}. A
## missing key reads as the key itself, so a gap shows on screen instead of crashing.

const TEXT_PATH := "res://data/text/en.json"

static var _strings: Dictionary = {}
static var _loaded := false


static func t(key: String, params: Dictionary = {}) -> String:
	if not _loaded:
		_load()
	var value: Variant = _strings.get(key, key)
	var text: String = value if value is String else key
	return text.format(params) if not params.is_empty() else text


static func _load() -> void:
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH))
	if parsed is Dictionary:
		_strings = parsed
	else:
		push_warning("text data missing or invalid: %s" % TEXT_PATH)
