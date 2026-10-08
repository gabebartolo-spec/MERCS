class_name StageData
extends RefCounted
## Typed reads from data/balance/stage.json for the Phase 1 capture stage. A section
## name may nest with "/" ("rain_night/rain"); a missing or mistyped value reads as 0,
## an empty list or black, so a broken data file shows up in the stage suite, not as a crash.

var _root: Dictionary = {}


static func load_file(path: String) -> StageData:
	var data := StageData.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		data._root = parsed
	else:
		push_warning("stage data missing or invalid: %s" % path)
	return data


func section(name: String) -> Dictionary:
	var block: Dictionary = _root
	for part: String in name.split("/"):
		var next: Variant = block.get(part, {})
		if not next is Dictionary:
			return {}
		block = next
	return block


func num(name: String, key: String) -> float:
	var value: Variant = section(name).get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0


func floats(name: String, key: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var value: Variant = section(name).get(key, [])
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			if item is float or item is int:
				var number: float = item
				out.append(number)
	return out


func vec3(name: String, key: String) -> Vector3:
	var v := floats(name, key)
	if v.size() < 3:
		return Vector3.ZERO
	return Vector3(v[0], v[1], v[2])


func cell(name: String, key: String) -> Vector3i:
	return Vector3i(vec3(name, key))


func grey(name: String, key: String) -> Color:
	var g := num(name, key)
	return Color(g, g, g)


func rgb(name: String, key: String) -> Color:
	var v := vec3(name, key)
	return Color(v.x, v.y, v.z)
