extends "res://tests/lib/runner.gd"
## Data suite (05_STYLE_CODE.md "Data"). Every JSON file under data/ has a schema in
## data/schema/ and validates against it, and ids are unique within a collection.
## The validator proves itself on fixtures: every schema has at least one known-good
## file in tests/fixtures/data/valid/ that must pass and one known-bad file in
## tests/fixtures/data/invalid/ that must fail for the reason its "_comment" names
## ("expect: <part of the error>").
## Seeded by design: nothing here is random.
##   godot --headless --path . --script tests/run_data_tests.gd

const JsonSchema := preload("res://tests/lib/json_schema.gd")
const DATA_DIR := "res://data"
const SCHEMA_DIR := "res://data/schema"
const FIXTURE_DIR := "res://tests/fixtures/data"
const SCHEMA_SUFFIX := ".schema.json"
const EXPECT_PREFIX := "expect: "

var _schemas: Dictionary = {}
var _parse_errors: Array[String] = []


func suite_name() -> String:
	return "Data"


func run_checks() -> void:
	_load_schemas()
	_check_data_files()
	_check_fixtures("valid")
	_check_fixtures("invalid")
	_check_unsupported_keyword_is_reported()
	check(_parse_errors.is_empty(), "every data, schema and fixture file is valid JSON: %s" % [_parse_errors])


func _load_schemas() -> void:
	for file: String in DirAccess.get_files_at(SCHEMA_DIR):
		if not file.ends_with(SCHEMA_SUFFIX):
			continue
		var path := SCHEMA_DIR.path_join(file)
		var parsed: Variant = _parse(path)
		check(parsed is Dictionary, "%s is a JSON object" % path)
		if parsed is Dictionary:
			_schemas[file.trim_suffix(SCHEMA_SUFFIX)] = parsed
	check(not _schemas.is_empty(), "%s holds schemas" % SCHEMA_DIR)


## data/<name>.json uses schema <name>; data/<dir>/<file>.json uses schema <dir>.
## One check per rule, not per file or entry: adding or removing content never moves
## the floor, and a failure names every file that broke the rule.
func _check_data_files() -> void:
	var files := _data_files()
	var unschemed: Array[String] = []
	var invalid: Array[String] = []
	var repeated: Array[String] = []
	var seen_ids: Dictionary = {}
	for path: String in files:
		var schema_name := path.trim_prefix(DATA_DIR + "/").get_slice("/", 0).trim_suffix(".json")
		if not _schemas.has(schema_name):
			unschemed.append(path)
			continue
		var document: Variant = _parse(path)
		var schema: Dictionary = _schemas[schema_name]
		for error: String in JsonSchema.new().validate(document, schema):
			invalid.append("%s %s" % [path, error])
		# Ids are unique across every file of a collection (data/storylets/*.json).
		var ids: Dictionary = seen_ids.get(schema_name, {})
		for id: String in _collection_ids(document, schema_name):
			if ids.has(id):
				repeated.append("%s in %s and %s" % [id, ids[id], path])
			ids[id] = path
		seen_ids[schema_name] = ids
	check(files.size() > 0, "%s holds data files" % DATA_DIR)
	check(unschemed.is_empty(), "every data file has a schema in %s, missing: %s" % [SCHEMA_DIR, unschemed])
	check(invalid.is_empty(), "every data file validates against its schema: %s" % [invalid])
	check(repeated.is_empty(), "every id is unique within its collection, repeated: %s" % [repeated])


func _data_files() -> Array[String]:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(DATA_DIR):
		if file.ends_with(".json"):
			files.append(DATA_DIR.path_join(file))
	for dir: String in DirAccess.get_directories_at(DATA_DIR):
		if dir == "schema":
			continue
		for file: String in DirAccess.get_files_at(DATA_DIR.path_join(dir)):
			if file.ends_with(".json"):
				files.append(DATA_DIR.path_join(dir).path_join(file))
	return files


## Fixture files are named <schema>.<case>.json.
func _check_fixtures(kind: String) -> void:
	var dir := FIXTURE_DIR.path_join(kind)
	var covered: Dictionary = {}
	for file: String in DirAccess.get_files_at(dir):
		var path := dir.path_join(file)
		var schema_name := file.get_slice(".", 0)
		check(_schemas.has(schema_name), "fixture %s names a schema that exists" % path)
		if not _schemas.has(schema_name):
			continue
		covered[schema_name] = true
		var document: Variant = _parse(path)
		var errors := _validate(document, schema_name)
		if kind == "valid":
			check(errors.is_empty(), "known-good %s passes: %s" % [path, errors])
		else:
			_check_rejected(path, document, errors)
	for schema_name: String in _schemas:
		check(covered.has(schema_name), "schema %s has a %s fixture in %s" % [schema_name, kind, dir])


func _check_rejected(path: String, document: Variant, errors: Array[String]) -> void:
	var comment := ""
	if document is Dictionary:
		var object: Dictionary = document
		comment = str(object.get("_comment", ""))
	var expected := comment.trim_prefix(EXPECT_PREFIX)
	check(comment.begins_with(EXPECT_PREFIX), "known-bad %s says what it breaks (\"_comment\": \"expect: ...\")" % path)
	var found := false
	for error: String in errors:
		found = found or expected in error
	check(found, "known-bad %s is rejected with '%s', got %s" % [path, expected, errors])


func _check_unsupported_keyword_is_reported() -> void:
	var errors := JsonSchema.new().validate({}, {"type": "object", "maxProperties": 3})
	check(errors.size() == 1 and "not supported" in errors[0], "an unsupported schema keyword is an error, got %s" % [errors])


## Schema errors plus duplicate ids inside the document.
func _validate(document: Variant, schema_name: String) -> Array[String]:
	var schema: Dictionary = _schemas[schema_name]
	var errors := JsonSchema.new().validate(document, schema)
	var ids: Dictionary = {}
	for id: String in _collection_ids(document, schema_name):
		if ids.has(id):
			errors.append("duplicate id '%s'" % id)
		ids[id] = true
	return errors


## The ids of a collection document ({"<schema>": [{"id": ...}, ...]}); empty otherwise.
func _collection_ids(document: Variant, schema_name: String) -> Array[String]:
	var ids: Array[String] = []
	if not document is Dictionary:
		return ids
	var object: Dictionary = document
	var entries: Variant = object.get(schema_name)
	if not entries is Array:
		return ids
	var list: Array = entries
	for entry: Variant in list:
		if entry is Dictionary:
			var fields: Dictionary = entry
			if fields.get("id") is String:
				ids.append(str(fields["id"]))
	return ids


## Parse problems are collected and checked once at the end (run_checks).
func _parse(path: String) -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_parse_errors.append("%s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
