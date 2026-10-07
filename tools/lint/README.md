# tools/lint: project lints

Five lints that enforce guardrails a formatter cannot. Python 3.11+ standard library only,
plus one bash script. Run them all with `bash tools/lint/run_all.sh` (pass/fail table, exit 1
on any failure). Each Python lint takes `--root DIR` (default: this repo).

Output is one line per finding, `<path>:<line>: <RULE-ID> <message>` (`warning <RULE-ID>` for
warnings, line 0 for whole-file findings), plus `::error`/`::warning` annotations when
`GITHUB_ACTIONS` is set. Exit 1 on any error, otherwise exit 0 and print `ok: ...`.
Findings come from code only: comments and string contents never trigger a rule, except the
rules about strings.

| Lint | Guardrail | Rule ids |
|---|---|---|
| `layering.py` | B3, B2, 05 Layering | `LAYER-IMPORT` `LAYER-CLASS` `LAYER-AUTOLOAD` `SIM-EXTENDS` `SIM-ENGINE` `SIM-CLOCK` `SIM-AWAIT` `SIM-RANDOM` |
| `magic_numbers.py` | B9, D3 | `MAGIC-NUMBER` (warning before Phase 3, error from it) `COLOUR-LITERAL` |
| `strings.py` | B12 | `TEXT-LITERAL` `TEXT-SCENE` |
| `content_counts.py` | A2 | `CAP-OVER` `CAP-MISSING` `CAP-FILE` |
| `worktrees.sh` | C1 | `WT-OVER` (error), `WT-UNCOUNTED` `WT-PRUNABLE` (warnings) |

Each lint's docstring (`worktrees.sh` header) is the full rule list. Decisions worth knowing:

- Layers are `data` -> `sim` -> `presentation` -> `ui`; autoloads come from `project.godot`.
- The randomness owner is the file whose lowercased path is `sim/core/rng.gd`; the colour
  owner is the file whose lowercased path without underscores is `ui/uikit.gd`.
  Both `Rng.gd` and `rng.gd`, `UiKit.gd` and `ui_kit.gd` match.
- `COLOUR-LITERAL` looks at `ui/` only (D3). `&"..."` and `^"..."` literals are never
  flagged as colours or player text: they are the escape hatch for identifiers.
- `strings.py` treats the print family, `push_warning`, `push_error`, `assert` and any
  `Debug.<method>(...)` call as developer text, never player text.
- Content collections are `data/<name>.json` or `data/<name>/*.json`; `data/schema/`,
  `data/text/`, `data/balance/` and `caps.json` are not collections.
- Worktrees: `<parent of main>/MERCS-wt/*` and the app's `<main>/.claude/worktrees/*` both
  count, at most 4 together (D-021 item 3). Prunable (stale) entries do not count.
- A repo with no `sim/`, `ui/`, `data/` or `project.godot` yet passes with `ok: 0 ...`.

## Self-test

`python tools/lint/test_lints.py` runs every lint against a deliberately broken fixture in
`tests/fixtures/lint/<name>/`, a mini repo with one planted violation per line (marked
`# PLANT <RULE>` in scripts) and look-alikes that must not be flagged. The fixture's
`expected.txt` lists `RULE path:line` for each planted error; the set of errors the lint
reports must equal it exactly (missing = recall failure, extra = precision failure).
`expected_warnings.txt` does the same for warnings. `worktrees/*.txt` are captured
`git worktree list --porcelain` listings fed through `WORKTREE_LIST`.

To change a rule: plant the new violation (and its look-alike) in the fixture, update
`expected.txt`, watch the self-test fail, then change the lint. A rule without a planted
violation is not proven.

The fixtures hold broken scripts on purpose. `tests/fixtures/lint/.gdignore` keeps Godot
from importing them; `gdlint`, `gdformat` and the data-schema validators must exclude
`tests/fixtures/` too.
