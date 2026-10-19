extends RefCounted
## Every test function ran and made at least one check. This replaced the check-count
## floors (director 2026-10-19, github-hygiene §4): a new test counts itself, so no PR
## edits a shared file of counts and two PRs never conflict over one.
##
## A suite (tests/lib/runner.gd) calls each test through `_t`:
##
##   await _t("_test_rules")
##   var found: Array = await _t("_test_lookup", [key])   # what it returns
##
## and the base prints `Ran.line(...)`: "<Suite> tests: K of M functions, N checks,
## F failures". The line fails, by name, every `_test_*` method the suite defines but
## never called; tools/run_tests.sh fails a suite whose line is short of functions or
## carries no function count at all.

const _CALLED := "_tests_called"


## Runs suite.test(args...), records that it ran, and fails it by name when it made no
## check: an empty loop or an early return no longer passes quietly.
static func one(suite: Object, test: String, args: Array = []) -> Variant:
	var called: Array = suite.get_meta(_CALLED, [])
	called.append(test)
	suite.set_meta(_CALLED, called)
	if not suite.has_method(test):
		_fail(suite, "%s is called but not defined" % test)
		return null
	var before: int = _checks(suite)
	var result: Variant = await suite.callv(test, args)
	if _checks(suite) == before:
		_fail(suite, "%s made no checks" % test)
	return result


## The suite's summary line. Every `_test_*` method the suite defines and never ran
## through one() fails here, by name, first.
static func line(label: String, suite: Object) -> String:
	var called: Array = suite.get_meta(_CALLED, [])
	var ran: int = 0
	var defined: Array[String] = defined_tests(suite)
	for test: String in defined:
		if called.has(test):
			ran += 1
		else:
			_fail(suite, '%s is never called: add await _t("%s") to run_checks()' % [test, test])
	return (
		"%s tests: %d of %d functions, %d checks, %d failures"
		% [label, ran, defined.size(), _checks(suite), _failures(suite).size()]
	)


## Every `_test_*` method the suite's own script defines. A suite that extends another
## suite (stage_scale extends stage) is not asked to call the base suite's tests.
static func defined_tests(suite: Object) -> Array[String]:
	var names: Array[String] = []
	var script: Script = suite.get_script()
	if script == null:
		return names
	var inherited: Array[String] = []
	var base: Script = script.get_base_script()
	while base != null:
		for base_method: Dictionary in base.get_script_method_list():
			var base_name: String = base_method["name"]
			inherited.append(base_name)
		base = base.get_base_script()
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("_test_") or names.has(method_name):
			continue
		if not inherited.has(method_name):
			names.append(method_name)
	return names


static func _checks(suite: Object) -> int:
	var value: Variant = suite.get("_checks")
	if value is int:
		return value
	return 0


static func _failures(suite: Object) -> Array:
	var value: Variant = suite.get("_failures")
	if value is Array:
		return value
	return []


static func _fail(suite: Object, message: String) -> void:
	_failures(suite).append(message)
	printerr("FAIL: " + message)
