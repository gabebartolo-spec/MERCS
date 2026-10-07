---
name: mercs-godot-tests
description: How to run, add and debug MERCS Godot test suites and CI without tripping over other agents on the same PC - the tools/run_tests.sh interface, isolated user data, check floors, pinned seeds, one Godot process per agent, killing by recorded PID, and reading a red CI run (tests.yml plan, shards, aggregate test). Use it whenever you run tools/run_tests.sh or a Godot --script, add or change a suite or a floor in tests/expected_checks.txt, read a red or cancelled CI run, or see a failure that might not be your change's fault - even if you think you already know how to run the tests.
---

# Running Godot tests in MERCS

Three Claude Code chats share one Windows PC, one GPU and one Godot install. Most mystery failures
come from that sharing or from unseeded randomness, not from the change under test. This is the
routine that avoids both.

## The command

```bash
GODOT="C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" \
  tools/run_tests.sh data smoke
```

`GODOT` is the console build of the engine of record, so output reaches the shell; if the install
moves, `docs/02_MACHINE_AND_LOCAL_AI.md` has the path. The script:
1. imports the project and fails on any SCRIPT ERROR, Parse Error or Compile Error;
2. runs each named suite, `tests/run_<suite>_tests.gd`, with `--headless --fixed-fps 60` and a time
   limit (`SUITE_TIMEOUT`, default 900 s);
3. with no suite named, also runs the harness self-test, `tools/test_run_tests.sh`.

It prints a pass/fail table and exits non-zero on failure. `SUITES_ONLY=1` and `EXTRAS_ONLY=1` split
the work the way CI does.

- **Isolated user data.** Every run gets its own temp user-data dir (APPDATA and the XDG dirs), so two
  agents never share saves or settings. A Godot run outside the script (a direct `--script`, a
  capture) must set `APPDATA=<your scratch dir>` itself (CLAUDE.md "Machine rules").
- **Name the suites you touched** (one to three while iterating); a full run is for wide changes or for
  checking `main`. Phase 0 suites: `data` (every data file validates against its schema in
  `data/schema/`, and the validator rejects the known-bad fixtures in `tests/fixtures/data/`) and
  `smoke` (the main scene opens headless, exactly the five sanctioned autoloads (D-021), a project-settings
  guard, every script compiles with typing warnings as errors). Later suites: `docs/05_STYLE_CODE.md`
  "Tests".
- **One Godot process per agent at a time.** Long runs go in the background; record the task id and the
  Godot PID. Never kill Godot by image name (`taskkill /IM`, `Stop-Process -Name`): other agents' runs
  die too. Stop only what you started: the background task by its id, or a recorded PID
  (`Stop-Process -Id <pid>`). To tell your Godot from another agent's, check its parent process and
  command line (`Get-CimInstance Win32_Process` shows both).
- **Lints:** `bash tools/lint/run_all.sh` runs layering, magic_numbers, strings, content_counts and
  worktrees plus their fixture self-test. Run it before you push.
- **A fresh worktree** has no `.godot/` (it is git-ignored), so its first run imports the whole project.
  Runs rewrite `*.import` files; revert that churn before you commit, stage files by name, and read
  `git diff --cached --stat`: `git diff --name-only | grep '\.import$' | xargs -r git checkout --`

## Adding a suite or checks

- Runner: `tests/run_<suite>_tests.gd`, extending `tests/lib/runner.gd`: override `suite_name()` and
  `run_checks()` and call `check(condition, expectation)` once per check; the base prints
  `<Suite> tests: N checks, M failures` and quits non-zero on failure. Model it on
  `tests/run_smoke_tests.gd`.
- Register a new suite in four places: `ALL_SUITES` in `tools/run_tests.sh`; one line in
  `tools/ci_shards.txt` (a short shard; Merge & CI rebalances when a shard passes 10 minutes); a floor
  in `tests/expected_checks.txt` as `<suite> <floor>`; a row in the suites table of `tests/README.md`. Then run `bash tools/check_ci_shards.sh`: every
  suite in `ALL_SUITES` must sit in exactly one shard.
- **Floors only go up** (guardrail B6). A suite under its floor fails ("checks went missing"); a suite
  with no floor fails. Count checks per rule, not per data entry or file (one check whose message names every
  offender), so adding or removing content never moves a floor. Set a new suite's floor to its real count; when you add checks to an existing
  suite, raise only that suite's line by your increment. Never lower a floor, widen a threshold, delete
  a test or skip a lint to get green. A threshold change needs a line in `docs/DECISIONS.md` and a
  Concept Lead ack.
- **Seeds:** pin them (`docs/05_STYLE_CODE.md` "Randomness"); a test that reads the clock is a bug
  (CLAUDE.md rule 2). A suite with no randomness says `## Seeded by design: <why>` in its header.
- **Autoloads in a `--script`:** if a suite fails to compile with "Identifier not found" on an autoload
  (`GameData`, `EventBus`, ...), it named the autoload before the autoloads existed. `load()` it inside the
  run method after the first frame, and give typed variables to values returned from a `load()`ed script.
- **New checks prove themselves:** show each failing on a known-bad fixture before trusting it.

## When a test fails

Work through these before blaming your change:
1. **Did it fail on `main` too?** Run the same suite isolated on a scratch worktree of `origin/main`. It
   counts toward the four-worktree cap; remove it afterwards.
2. **Is someone else running Godot?** List processes (`Get-CimInstance Win32_Process`, filter on Godot) and
   read their command lines. A save- or settings-looking failure during another run is shared user
   data: rerun with your own `APPDATA`.
3. **Does it pass on a rerun?** Then it is nondeterministic: find the unseeded randomness or clock read
   and pin it. A flaky check is a seed to fix, not a rerun to hope for.
4. **A SCRIPT ERROR fails the run even when every check passed** (guardrail B4). Fix it; do not mute it.

After two similar failed fixes, stop patching and gather different evidence: a minimal reproduction,
the last good commit, the runtime state (CLAUDE.md rule 10).

## CI

- `.github/workflows/tests.yml`: `plan` (runs `tools/check_ci_shards.sh`; skips the Godot jobs for
  docs-only and draft PRs) -> shard jobs from `tools/ci_shards.txt` plus one harness self-test job ->
  the aggregate `test`, the required check, which still reports (green) when the Godot jobs were skipped. While shards
  run, "no `test` result yet" is normal.
- Read a failure with `gh run view <id> --log-failed`. A job cancelled with no steps never started
  (runner trouble or a newer push); that is not a test result.
- Run the suites locally and push when the work is ready, not to see what CI says: every agent waits on
  the same runners. `build.yml` exports the Windows build on every push to main and uploads
  `MERCS-windows`; a red build is as urgent as a red `test`.
- A failure report to its owner gives: branch, commit, run id, failing suite and check, whether it
  also fails on `main`, and who acts next.
