extends RefCounted
## The subset of JSON Schema (draft 2020-12) that the files in data/schema/ use, for the
## data suite. A schema keyword outside the subset is reported as an error, so a schema
## can never ask for a rule that is silently not checked. A "_comment" key is ignored
## wherever it appears in data (05_STYLE_CODE.md "Data"). Godot's JSON parser returns
## every number as a float, so "integer" means a number with no fractional part.

const SUPPORTED: Array[String] = [
	"type",
	"properties",
	"required",
	"additionalProperties",
	"patternProperties",
	"items",
	"pattern",
	"minimum",
	"minLength",
	"$ref",
]
const ANNOTATIONS: Array[String] = ["$schema", "$id", "$defs", "$comment", "title", "description"]
const COMMENT_KEY := "_comment"
const DEFS_PREFIX := "#/$defs/"

var _root: Dictionary = {}
var _errors: Array[String] = []


## Every way `instance` breaks `schema`; an empty list means it is valid.
func validate(instance: Variant, schema: Dictionary) -> Array[String]:
	_root = schema
	_errors = []
	_check(instance, schema, "$")
	return _errors


func _check(value: Variant, schema: Dictionary, at: String) -> void:
	for keyword: String in schema:
		if not (keyword in SUPPORTED or keyword in ANNOTATIONS):
			_fail(at, "schema keyword '%s' is not supported by tests/lib/json_schema.gd" % keyword)
	if schema.has("$ref"):
		_check(value, _resolve(str(schema["$ref"])), at)
	if schema.has("type") and not _type_matches(value, schema["type"]):
		_fail(at, "expected %s, got %s" % [schema["type"], _type_name(value)])
		return
	if value is String:
		var text: String = value
		_check_string(text, schema, at)
	elif value is float or value is int:
		var number: float = value
		_check_number(number, schema, at)
	elif value is Array:
		var items: Array = value
		_check_array(items, schema, at)
	elif value is Dictionary:
		var object: Dictionary = value
		_check_object(object, schema, at)


func _resolve(ref: String) -> Dictionary:
	var defs: Dictionary = _root.get("$defs", {})
	var target: Variant = defs.get(ref.trim_prefix(DEFS_PREFIX))
	if not ref.begins_with(DEFS_PREFIX) or not target is Dictionary:
		_fail("$ref", "cannot resolve '%s' (only '%s<name>' is supported)" % [ref, DEFS_PREFIX])
		return {}
	var resolved: Dictionary = target
	return resolved


func _type_matches(value: Variant, spec: Variant) -> bool:
	var names: Array = []
	if spec is Array:
		names = spec
	else:
		names = [spec]
	for type_name: Variant in names:
		if _is_type(value, str(type_name)):
			return true
	return false


func _is_type(value: Variant, type_name: String) -> bool:
	match type_name:
		"object":
			return value is Dictionary
		"array":
			return value is Array
		"string":
			return value is String
		"boolean":
			return value is bool
		"null":
			return value == null
		"number":
			return value is float or value is int
		"integer":
			return _is_integer(value)
	_fail("type", "unknown type name '%s'" % type_name)
	return false


func _is_integer(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var number: float = value
	return number == floorf(number)


func _type_name(value: Variant) -> String:
	if value is Dictionary:
		return "object"
	if value is Array:
		return "array"
	if value is String:
		return "string"
	if value is bool:
		return "boolean"
	if value == null:
		return "null"
	return "number"


func _check_string(text: String, schema: Dictionary, at: String) -> void:
	if schema.has("minLength"):
		var min_length: float = schema["minLength"]
		if text.length() < min_length:
			_fail(at, "'%s' is shorter than %d characters" % [text, min_length])
	if schema.has("pattern"):
		var pattern: String = schema["pattern"]
		if not _matches(pattern, text):
			_fail(at, "'%s' does not match %s" % [text, pattern])


func _check_number(number: float, schema: Dictionary, at: String) -> void:
	if not schema.has("minimum"):
		return
	var minimum: float = schema["minimum"]
	if number < minimum:
		_fail(at, "%s is less than the minimum %s" % [number, minimum])


func _check_array(items: Array, schema: Dictionary, at: String) -> void:
	if not schema.has("items"):
		return
	var item_schema: Dictionary = schema["items"]
	for i: int in items.size():
		_check(items[i], item_schema, "%s[%d]" % [at, i])


func _check_object(object: Dictionary, schema: Dictionary, at: String) -> void:
	var required: Array = schema.get("required", [])
	for key: Variant in required:
		if not object.has(key):
			_fail(at, "missing required key '%s'" % key)
	var properties: Dictionary = schema.get("properties", {})
	var patterns: Dictionary = schema.get("patternProperties", {})
	for key: String in object:
		if key == COMMENT_KEY:
			continue
		var at_key := "%s.%s" % [at, key]
		var matched := false
		if properties.has(key):
			var property_schema: Dictionary = properties[key]
			_check(object[key], property_schema, at_key)
			matched = true
		for pattern: String in patterns:
			if _matches(pattern, key):
				var pattern_schema: Dictionary = patterns[pattern]
				_check(object[key], pattern_schema, at_key)
				matched = true
		if not matched:
			_check_additional(object[key], schema, at_key)


func _check_additional(value: Variant, schema: Dictionary, at: String) -> void:
	if not schema.has("additionalProperties"):
		return
	var extra: Variant = schema["additionalProperties"]
	if extra is Dictionary:
		var extra_schema: Dictionary = extra
		_check(value, extra_schema, at)
	elif extra is bool and not extra:
		_fail(at, "unexpected key")


func _matches(pattern: String, text: String) -> bool:
	var regex := RegEx.create_from_string(pattern)
	if regex == null or not regex.is_valid():
		_fail("pattern", "invalid regular expression %s" % pattern)
		return false
	return regex.search(text) != null


func _fail(at: String, message: String) -> void:
	_errors.append("%s: %s" % [at, message])
