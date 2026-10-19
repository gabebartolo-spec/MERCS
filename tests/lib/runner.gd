extends SceneTree
## Base for every suite runner. A suite is one file, tests/run_<suite>_tests.gd, that
## starts with `extends "res://tests/lib/runner.gd"`, overrides suite_name() and
## run_checks(), keeps its tests in `_test_*` methods that run_checks() calls through
## `await _t("_test_name")`, and calls check() once per check. The base prints
## "<Suite> tests: K of M functions, N checks, F failures" (tests/functions_ran.gd;
## tools/run_tests.sh reads that line) and quits non-zero when any check failed. A
## `_test_*` method never called, or one that made no check, is a failure by name; there
## is no floor file to keep (director 2026-10-19, github-hygiene §4).
##   godot --headless --path . --script tests/run_<suite>_tests.gd

const Ran := preload("res://tests/functions_ran.gd")

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	# Autoloads are in the tree once the first frame has run.
	await process_frame
	await run_checks()
	print(Ran.line(suite_name(), self))
	quit(0 if _failures.is_empty() else 1)


## The name in the summary line, e.g. "Data".
func suite_name() -> String:
	return "Unnamed"


## Each suite overrides this: one `await _t("_test_x")` per test function.
func run_checks() -> void:
	await process_frame


## Runs one test function; it must make at least one check (tests/functions_ran.gd).
func _t(test: String, args: Array = []) -> Variant:
	return await Ran.one(self, test, args)


## Records one check. `expectation` says what should be true; a failure prints
## "FAIL: <expectation>" so tools/run_tests.sh and CI can show it without the full log.
func check(condition: bool, expectation: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(expectation)
		printerr("FAIL: " + expectation)
