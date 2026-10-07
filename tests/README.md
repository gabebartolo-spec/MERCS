# Tests

Godot 4.7.2. One command runs everything CI runs (import, every suite, the harness
self-test) and prints a pass/fail table:

```sh
GODOT=/path/to/godot tools/run_tests.sh            # everything
GODOT=/path/to/godot tools/run_tests.sh data smoke # some suites
```

On the studio PC, use the console build so output reaches the shell:
`GODOT="C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`.
Every run gets its own user data and editor settings (APPDATA and the XDG dirs point at a
temp dir), so two agents' runs never share saves, settings or caches.

## Rules

- A suite is one file, `tests/run_<suite>_tests.gd`, extending `tests/lib/runner.gd`. It
  calls `check(condition, expectation)` once per check and the base prints
  `<Suite> tests: N checks, M failures`; a failed check prints `FAIL: <expectation>`.
- Every suite has a floor in `expected_checks.txt`. A suite reporting fewer checks fails
  ("checks went missing"), a suite with no floor fails, and floors only go up (B6).
  Count checks per rule, not per data entry or per file, so content changes never move
  a floor. Fixtures and schemas are the exception: each adds checks of its own, so adding
  one raises the `data` count, and its floor goes up in the same PR.
- A suite whose log shows `SCRIPT ERROR`, `Parse Error` or `Compile Error` fails even if
  every check it reached passed.
- Seeds are pinned; nothing reads the clock. A suite with no randomness says
  `## Seeded by design: <why>`.
- A new suite needs a floor here and a line in `tools/ci_shards.txt` (the plan job fails
  otherwise), and goes into `ALL_SUITES` in `tools/run_tests.sh`.
- `tests/fixtures/` holds known-good and known-bad inputs. A folder with a `.gdignore`
  holds deliberately broken scripts the editor and the smoke suite must not load.

## Suites

| Suite | Covers | Floor |
|---|---|---:|
| `data` | Every file in `data/` has a schema in `data/schema/` and validates; ids are unique per collection; the validator accepts each known-good and rejects each known-bad fixture in `fixtures/data/` for the reason the fixture names | 88 |
| `smoke` | The main scene opens headless and stays up; exactly the five sanctioned autoloads (D-021); the typing warnings stay errors and the renderer and viewport stay as set; every script compiles | 24 |

The harness self-test (`tools/test_run_tests.sh`) proves the runner fails a suite short
of its floor or without one, and that an untyped declaration
(`fixtures/compile/untyped_var.gd`) does not compile.
