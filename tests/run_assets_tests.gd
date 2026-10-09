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
const PACK_FILE := "user://assets_suite/exported_sheet.pck"
const PACK_ROOT := "res://exported_sheet"
const FACING := "S"


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
	_check_exported_load()
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
	_copy_normal(manifest, dir)
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


## Copies the good sheet's normal map, when it names one, so a planted copy only breaks
## the rule it is meant to.
func _copy_normal(manifest: Dictionary, dir: String) -> void:
	var normal_name := str(manifest.get("normal_image", ""))
	if normal_name.is_empty():
		return
	var source := GOOD_SHEET.get_base_dir().path_join(normal_name)
	var normal := Image.load_from_file(ProjectSettings.globalize_path(source))
	if normal != null:
		normal.save_png(dir.path_join(normal_name))


## The Phase 1 gate runs from an export, where res:// is a .pck holding imported textures and
## no PNG files. The sheet's pixels must still reach the screen: imported textures load, and
## SheetFrame.from_manifest finds a sheet that exists only inside a pack.
func _check_exported_load() -> void:
	var manifest := _manifest(GOOD_SHEET)
	var names: Array[String] = [
		str(manifest.get("image", "")), str(manifest.get("normal_image", ""))
	]
	var imported_ok := true
	for image_name: String in names:
		var path := GOOD_SHEET.get_base_dir().path_join(image_name)
		var file_image := Image.load_from_file(ProjectSettings.globalize_path(path))
		imported_ok = imported_ok and _same_pixels(_texture_image(path), file_image)
	check(imported_ok, "imported sheet and normal textures keep every visible pixel of their PNGs")
	var pack_manifest := _pack_sheet(names)
	var frame := SheetFrame.from_manifest(pack_manifest, FACING)
	check(frame != null, "SheetFrame loads a sheet that exists only inside a .pck")
	var loaded_ok := frame != null
	if frame != null:
		var sheet := Image.load_from_file(
			ProjectSettings.globalize_path(GOOD_SHEET.get_base_dir().path_join(names[0]))
		)
		loaded_ok = _same_pixels(frame.texture.get_image(), sheet)
	check(loaded_ok, "the sheet loaded from the .pck has the PNG's visible pixels")


func _manifest(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _texture_image(path: String) -> Image:
	var texture := load(path) as Texture2D
	return texture.get_image() if texture != null else null


## Packs the sheet the way an export does: manifest as is, each PNG replaced by a .remap to
## its imported texture, no PNG. Mounts the pack and returns the manifest's pack path.
func _pack_sheet(names: Array[String]) -> String:
	DirAccess.make_dir_recursive_absolute(PLANT_DIR)
	var packer := PCKPacker.new()
	packer.pck_start(PACK_FILE)
	var manifest_path := PACK_ROOT.path_join(GOOD_SHEET.get_file())
	packer.add_file(manifest_path, ProjectSettings.globalize_path(GOOD_SHEET))
	for image_name: String in names:
		var source := GOOD_SHEET.get_base_dir().path_join(image_name)
		var config := ConfigFile.new()
		config.load(source + ".import")
		var texture_path := str(config.get_value("remap", "path", ""))
		var remap_path := PLANT_DIR.path_join(image_name + ".remap")
		var remap := FileAccess.open(remap_path, FileAccess.WRITE)
		remap.store_string('[remap]\n\npath="%s"\n' % texture_path)
		remap.close()
		packer.add_file(PACK_ROOT.path_join(image_name) + ".remap", remap_path)
		packer.add_file(texture_path, ProjectSettings.globalize_path(texture_path))
	packer.flush()
	ProjectSettings.load_resource_pack(PACK_FILE)
	return manifest_path


## Same size and same pixels wherever the sheet is visible: Godot's import may rewrite the
## colour under fully transparent pixels (fix_alpha_border), which no player can see.
func _same_pixels(a: Image, b: Image) -> bool:
	if a == null or b == null or a.get_size() != b.get_size():
		return false
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	for y: int in a.get_height():
		for x: int in a.get_width():
			var pixel_a := a.get_pixel(x, y)
			var pixel_b := b.get_pixel(x, y)
			if pixel_a.a != pixel_b.a or (pixel_a.a > 0.0 and pixel_a != pixel_b):
				return false
	return true
