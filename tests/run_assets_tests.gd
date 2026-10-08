extends "res://tests/lib/runner.gd"
## Assets suite: every factory sprite sheet (mercs.sheet/1) under res://assets/, plus the
## pipeline's known-good fixture, passes the engine-side rules in tests/lib/sheet_check.gd
## (load, facings, frame, pivot, normal map). Each rule proves itself on a planted-bad copy
## of the good sheet, written to user:// at run time, that breaks that rule alone.
## Seeded by design: no randomness; planted copies are deterministic edits.
##   godot --headless --path . --script tests/run_assets_tests.gd

const SHEET_CHECK := preload("res://tests/lib/sheet_check.gd")
const ASSETS_ROOT := "res://assets"
const GOOD_SHEET := "res://tests/fixtures/pipeline/sheets/good/average_m_body_rest.json"
const SHEET_SCHEMA := "mercs.sheet/1"
const PLANT_DIR := "user://assets_suite"
const WRONG_FRAME_PX := 48
const WRONG_PIVOT_Y := 50
const SMALL_NORMAL_PX := 32


func suite_name() -> String:
	return "Assets"


func run_checks() -> void:
	var manifests := _discover()
	check(
		manifests.has(GOOD_SHEET),
		"discovery finds the good fixture sheet (%d sheets)" % manifests.size()
	)
	var offenders := PackedStringArray()
	for path: String in manifests:
		for problem: String in SHEET_CHECK.check(path):
			offenders.append("%s %s" % [path, problem])
	check(
		offenders.is_empty(),
		"every factory sheet passes the engine rules: %s" % "; ".join(offenders)
	)
	check(
		SHEET_CHECK.check(_plant("clean", {})).is_empty(),
		"an unchanged copy of the good sheet passes"
	)
	_check_rule("ENGINE-LOAD", _plant("load", {"image": "missing.png"}))
	_check_rule("ENGINE-FACINGS", _plant("facings", {"swap_facings": true}))
	_check_rule("ENGINE-FRAME", _plant("frame", {"frame_w": WRONG_FRAME_PX}))
	_check_rule("ENGINE-PIVOT", _plant("pivot", {"pivot_y": WRONG_PIVOT_Y}))
	_check_rule("ENGINE-NORMAL", _plant("normal", {"small_normal": true}))
	await process_frame


## The planted sheet is rejected, and only by the rule it breaks.
func _check_rule(rule: String, manifest_path: String) -> void:
	var problems := SHEET_CHECK.check(manifest_path)
	var only_rule := not problems.is_empty()
	for problem: String in problems:
		only_rule = only_rule and problem.begins_with(rule + ":")
	check(only_rule, "%s rejects its planted sheet, and only it: %s" % [rule, "; ".join(problems)])


func _discover() -> PackedStringArray:
	var found := PackedStringArray([GOOD_SHEET])
	if DirAccess.dir_exists_absolute(ASSETS_ROOT):
		_scan(ASSETS_ROOT, found)
	return found


func _scan(dir_path: String, found: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_scan(dir_path.path_join(sub), found)
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".json"):
			var path := dir_path.path_join(file)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				var manifest: Dictionary = parsed
				if manifest.get("schema", "") == SHEET_SCHEMA:
					found.append(path)


## Copies the good sheet into user://assets_suite/<name>/ with one deliberate change.
func _plant(name: String, change: Dictionary) -> String:
	var dir := PLANT_DIR.path_join(name)
	DirAccess.make_dir_recursive_absolute(dir)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOOD_SHEET))
	var manifest: Dictionary = parsed if parsed is Dictionary else {}
	var source := GOOD_SHEET.get_base_dir().path_join(str(manifest.get("image", "")))
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	image.save_png(dir.path_join("sheet.png"))
	manifest["image"] = change.get("image", "sheet.png")
	if change.has("frame_w"):
		manifest["frame_w"] = change["frame_w"]
	if change.has("pivot_y"):
		var pivot: Dictionary = manifest.get("pivot", {})
		pivot["y"] = change["pivot_y"]
	if change.has("swap_facings"):
		var facings: Array = manifest.get("facings", [])
		var first: Variant = facings[0]
		facings[0] = facings[1]
		facings[1] = first
	if change.has("small_normal"):
		var normal := Image.create(SMALL_NORMAL_PX, SMALL_NORMAL_PX, false, Image.FORMAT_RGBA8)
		normal.save_png(dir.path_join("normal.png"))
		manifest["normal_image"] = "normal.png"
	var path := dir.path_join("sheet.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	return path
