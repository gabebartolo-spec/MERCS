# Phase 0 gate result (Concept Lead, 2026-10-08)

Verdict: **PASS WITH NOTES** (D-027). Evidence: broken PR #10 (draft, never merged), clean PR #11,
build artefact from run 37658475432 (MERCS.exe, 104 MB) launched windowed and headless.

## Planted violations: rejected (12 of 16)

| # | Violation | Rejected by |
|---|-----------|-------------|
| 1 | untyped `var` | Godot parse (warning as error) → `test` |
| 2 | clock read in sim | layering SIM-CLOCK → `project-lints` |
| 3 | `get_node` in sim | layering SIM-ENGINE → `project-lints` |
| 4 | `randi()` outside rng.gd | layering SIM-RANDOM → `project-lints` |
| 5 | sim preloads ui | layering LAYER-IMPORT → `project-lints` |
| 6 | magic number in sim | magic_numbers warning (by design until Phase 3), visible in log |
| 7 | player text literal in ui | strings TEXT-LITERAL → `project-lints` |
| 8 | colour literal outside UiKit | magic_numbers COLOUR-LITERAL → `project-lints` |
| 9 | data entry missing a required key | `data` suite schema check → `test` |
| 10 | content over cap | content_counts CAP-OVER → `project-lints` |
| 11 | STATUS.md over 150 lines | `doc-caps` |
| 15 | extra autoload | `smoke` suite → `test` |

## Not rejected (4 of 16) → follow-ups, required before Phase 1 code merges

| # | Gap | Follow-up (STATUS Phase 0 items 10–12) |
|---|-----|-----------------------------------------|
| 12 | a check floor lowered | `tests.yml`: compare `tests/expected_checks.txt` against `main`; fail if any floor decreased (guardrail B6 becomes a machine rule) |
| 13 | fake AWS key not caught | test design flaw: `AKIAIOSFODNN7EXAMPLE` is on gitleaks' allowlist. Re-test with a non-allowlisted fake secret; if still missed, add a custom rule |
| 14 | `.safetensors` committed | LFS tripwire fired (pointer) but nothing failed. `assets.yml` provenance validator (Phase 1 Art item) must fail on any `.safetensors`/`.ckpt`/`.gguf` in the repo; until then Merge & CI review |
| 16 | 401-line GDScript | no gdlint job yet (STATUS item 8). Add gdlint + gdformat with `max-file-lines` 400 |

## Side findings
- `build.yml` passed on the broken PR in 34 s: export and headless launch never compile `sim/` or count autoloads. Make the `windows` job depend on `test`, or only run on `main`.
- The harness self-test message "the harness no longer catches what it must" is misleading when suites are simply red; reword to name the failing suite.
- Screenshot taken at 1280×720 (window fit); viewport setting unchanged at 1920×1080.

## Clean path
PR #11 (one STATUS line): `test`, `plan`, `doc-caps`, `gitleaks`, `project-lints` green; shards skipped as docs-only. Build exe launches to the empty main scene; headless run loads `res://ui/screens/main.tscn` with no errors.

## Phase 1 may start
Art Factory may begin Phase 1 items 1 (rig freeze) and samples now; Dev Lead begins the grey-box street after items 8 and 10–12 are merged.
