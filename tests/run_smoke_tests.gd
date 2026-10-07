extends "res://tests/lib/runner.gd"
## Smoke suite (08_ROADMAP.md Phase 0). The main scene opens headless and stays up;
## exactly the five sanctioned autoloads are registered (04_GUARDRAILS.md B8, D-021: a
## new autoload is a decision); the settings that keep the engine strict cannot be
## relaxed quietly; and every script in the project compiles with typing warnings
## treated as errors (the import step alone does not compile scripts).
## Seeded by design: nothing here is random.
##   godot --headless --path . --script tests/run_smoke_tests.gd

const AUTOLOADS: Array[String] = ["Debug", "EventBus", "GameData", "SaveSystem", "Settings"]
const AUTOLOAD_DIR := "*res://presentation/autoload/"
const FRAMES_UP := 3
const WARNING_AS_ERROR := 2
const STRICT_WARNINGS: Array[String] = [
	"debug/gdscript/warnings/untyped_declaration",
	"debug/gdscript/warnings/unsafe_property_access",
	"debug/gdscript/warnings/unsafe_method_access",
	"debug/gdscript/warnings/unsafe_cast",
	"debug/gdscript/warnings/unsafe_call_argument",
]
const PROJECT_SETTINGS: Dictionary = {
	"rendering/renderer/rendering_method": "forward_plus",
	"display/window/size/viewport_width": 1920,
	"display/window/size/viewport_height": 1080,
}


func suite_name() -> String:
	return "Smoke"


func run_checks() -> void:
	_check_settings()
	_check_autoloads()
	_check_scripts_compile()
	await _check_main_scene()


func _check_settings() -> void:
	for key: String in STRICT_WARNINGS:
		var level: int = ProjectSettings.get_setting(key, 0)
		check(level == WARNING_AS_ERROR, "%s is an error (2), not %d" % [key, level])
	for key: String in PROJECT_SETTINGS:
		var value: Variant = ProjectSettings.get_setting(key)
		var same: bool = value == PROJECT_SETTINGS[key]
		check(same, "%s is %s, not %s" % [key, PROJECT_SETTINGS[key], value])


func _check_autoloads() -> void:
	var names: Array[String] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var key: String = property["name"]
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	names.sort()
	check(names == AUTOLOADS, "the autoloads are exactly %s, not %s" % [AUTOLOADS, names])
	for autoload: String in AUTOLOADS:
		var path: String = ProjectSettings.get_setting("autoload/" + autoload, "")
		check(path.begins_with(AUTOLOAD_DIR), "autoload %s is a singleton under %s, not %s" % [autoload, AUTOLOAD_DIR, path])
		var node: Node = root.get_node_or_null(autoload)
		check(node != null, "autoload %s is in the tree" % autoload)


## One check for all scripts, so adding or deleting a script never moves the floor;
## a failure names every script that did not compile.
func _check_scripts_compile() -> void:
	var paths: Array[String] = []
	_collect_scripts("res://", paths)
	var broken: Array[String] = []
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			broken.append(path)
	check(paths.size() > 0, "the project has scripts to compile")
	check(broken.is_empty(), "all %d scripts compile with typing warnings as errors, broken: %s" % [paths.size(), broken])


## Like the editor, skips folders holding a .gdignore (tests/fixtures/compile/ keeps a
## deliberately broken script there) and hidden folders such as .godot/.
func _collect_scripts(dir_path: String, into: Array[String]) -> void:
	if FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "gd":
			into.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with("."):
			_collect_scripts(dir_path.path_join(sub), into)


func _check_main_scene() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	check(ResourceLoader.exists(path), "the main scene is set and exists, not '%s'" % path)
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path) as PackedScene
	check(packed != null and packed.can_instantiate(), "%s loads as a scene" % path)
	if packed == null or not packed.can_instantiate():
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	for _frame: int in FRAMES_UP:
		await process_frame
	check(scene.is_inside_tree(), "%s stays up for %d frames" % [path, FRAMES_UP])
	scene.queue_free()
	await process_frame
