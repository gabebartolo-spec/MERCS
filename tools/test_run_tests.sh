#!/usr/bin/env bash
# The harness must not report green when it should not. Through tools/run_tests.sh:
#   1. the quick smoke suite                                 -> must pass
#   2. a fixture with a _test_ function nobody calls         -> must fail ("functions short")
#   3. a fixture with a _test_ function that makes no check  -> must fail, by name
# (the fixtures are tests/fixtures/run_<name>_tests.gd), and, with Godot directly, that the
# project's typing rules hold:
#   4. tests/fixtures/compile/untyped_var.gd must fail to parse ("has no static type")
#   5. tests/fixtures/compile/typed_ok.gd must parse
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bad=0

if SUITES_ONLY=1 tools/run_tests.sh smoke > "$tmp/out.txt" 2>&1; then echo "ok: the smoke suite passes"; else
	echo "FAIL: the smoke suite should pass"
	cat "$tmp/out.txt"
	bad=1
fi
# The fixtures reuse the import the first run made.
if QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh uncalled > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a suite with an uncalled test function passed"
	bad=1
elif grep -q "functions short" "$tmp/out.txt" && grep -q "_test_x is never called" "$tmp/out.txt"; then
	echo "ok: an uncalled test function fails the run, by name"
else
	echo "FAIL: the uncalled fixture failed without saying why"
	cat "$tmp/out.txt"
	bad=1
fi
if QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh nocheck > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a test function with no check passed"
	bad=1
elif grep -q "_test_empty made no checks" "$tmp/out.txt"; then
	echo "ok: a test function with no check fails the run, by name"
else
	echo "FAIL: the no-check fixture failed without saying why"
	cat "$tmp/out.txt"
	bad=1
fi

native_path() {  # Godot on Windows needs a Windows path in APPDATA
	if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}
check_parse() {  # script, expect (fail|pass); isolated like every run
	APPDATA="$(native_path "$tmp")" XDG_DATA_HOME="$tmp/data" XDG_CONFIG_HOME="$tmp/config" \
		"$GODOT" --headless --path . --check-only --script "$1" > "$tmp/parse.txt" 2>&1
	local code=$?
	if [ "$2" = fail ] && [ "$code" != 0 ] && grep -q "has no static type" "$tmp/parse.txt"; then
		echo "ok: $1 is rejected (untyped declaration)"
	elif [ "$2" = pass ] && [ "$code" = 0 ]; then
		echo "ok: $1 parses"
	else
		echo "FAIL: $1 should $2 to parse (exit $code)"
		cat "$tmp/parse.txt"
		bad=1
	fi
}
check_parse tests/fixtures/compile/untyped_var.gd fail
check_parse tests/fixtures/compile/typed_ok.gd pass
# merge_eligibility.sh (D-071): the decision logic reads fixtures, offline.
me() {  # fixture, expect (eligible | a reason substring)
	local out code=0
	out=$(bash tools/merge_eligibility.sh --fixture "tests/fixtures/merge_eligibility/$1.json" 2>&1) || code=$?
	if [ "$2" = eligible ] && [ "$code" = 0 ] && [[ "$out" == "eligible 99 "* ]]; then
		echo "ok: merge_eligibility $1 is eligible"
	elif [ "$2" != eligible ] && [ "$code" != 0 ] && [[ "$out" == *"$2"* ]]; then
		echo "ok: merge_eligibility $1 is refused ($out)"
	else
		echo "FAIL: merge_eligibility $1 should give '$2' (exit $code): $out"
		bad=1
	fi
}
me eligible eligible
me draft "is a draft"
me wrong_head_check "has no run on head"
me skipped_shards_code_pr "must run the Godot shards"
me missing_evidence "missing the '## Evidence' section"
me gdlint_red "gdlint"
exit "$bad"
