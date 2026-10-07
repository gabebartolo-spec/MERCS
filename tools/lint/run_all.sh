#!/usr/bin/env bash
# run_all.sh: every project lint on this repo, then the lint self-test, as one pass/fail table.
#
# Runs layering, magic_numbers, strings and content_counts on the repo root, worktrees.sh on
# the live `git worktree list`, and finally test_lints.py (each lint against its broken
# fixture). Prints the failing checks' full output below the table and exits non-zero if any
# check failed. Works from any directory; set PYTHON to pick the interpreter.
#
# Usage: bash tools/lint/run_all.sh

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
cd "$root" || exit 2
export PYTHONDONTWRITEBYTECODE=1 # keep tools/lint/__pycache__ out of the working tree

pick_python() {
  local candidate
  for candidate in "${PYTHON:-}" python3 python; do
    if [ -n "$candidate" ] && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

py="$(pick_python)" || {
  echo "run_all.sh: Python 3.11 or newer not found (set PYTHON to its path)" >&2
  exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

names=()
results=()
warnings=()
details=()
logs=()
failed=0

run_step() { # run_step <name> <command...>
  local name="$1" log status
  shift
  log="$tmp/$name.log"
  "$@" >"$log" 2>&1
  status=$?
  names+=("$name")
  logs+=("$log")
  warnings+=("$(grep -c ': warning ' "$log")")
  details+=("$(tail -n 1 "$log" | cut -c1-70)")
  if [ "$status" -eq 0 ]; then
    results+=("PASS")
  else
    results+=("FAIL")
    failed=$((failed + 1))
  fi
}

run_step layering "$py" tools/lint/layering.py
run_step magic_numbers "$py" tools/lint/magic_numbers.py
run_step strings "$py" tools/lint/strings.py
run_step content_counts "$py" tools/lint/content_counts.py
run_step worktrees bash tools/lint/worktrees.sh
run_step self-test "$py" tools/lint/test_lints.py

printf '%-15s %-6s %-5s %s\n' CHECK RESULT WARN DETAIL
for i in "${!names[@]}"; do
  printf '%-15s %-6s %-5s %s\n' "${names[i]}" "${results[i]}" "${warnings[i]}" "${details[i]}"
done

if [ "$failed" -gt 0 ]; then
  for i in "${!names[@]}"; do
    if [ "${results[i]}" = "FAIL" ]; then
      printf '\n--- %s output ---\n' "${names[i]}"
      cat "${logs[i]}"
    fi
  done
  printf '\n%d of %d checks failed\n' "$failed" "${#names[@]}"
  exit 1
fi
printf '\nall %d checks passed\n' "${#names[@]}"
