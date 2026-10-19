extends "res://tests/lib/runner.gd"
## A fixture for tools/test_run_tests.sh, not a suite (tools/run_tests.sh only finds
## tests/run_*_tests.gd): `_test_x` is defined and never called, so the run must fail
## with "functions short" and name it.


func suite_name() -> String:
	return "Uncalled fixture"


func run_checks() -> void:
	await _t("_test_called")


func _test_called() -> void:
	check(true, "this one runs")


func _test_x() -> void:
	check(true, "this one is never called")
