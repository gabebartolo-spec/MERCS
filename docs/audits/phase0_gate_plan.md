# Phase 0 gate plan (Concept Lead, 2026-10-08)

The Phase 0 gate (`08_ROADMAP.md`) passes when a deliberately broken PR is rejected by CI on
every count below and a clean PR merges and produces a Windows build that launches to an empty
main scene. This file is the checklist the Dev Lead executes once items 1–7 are merged, and the
record the Concept Lead signs.

## A. The broken PR (`claude/gate-broken`, never merged)

One commit containing all of the following. Expected result: `lint` and `test` both red, with
each failure named in the job log.

| # | Violation | File to touch | Expected rejecting check |
|---|-----------|---------------|--------------------------|
| 1 | Untyped declaration `var x = 3` | `sim/core/Rng.gd` (temporary) | `test` (Godot parse: untyped warning as error) |
| 2 | Clock read in sim: `Time.get_ticks_msec()` | `sim/core/Clock.gd` | `lint` → `layering.py` |
| 3 | `get_node("..")` in sim | `sim/core/Ids.gd` | `lint` → `layering.py` |
| 4 | `randi()` outside `Rng.gd` | `sim/core/Clock.gd` | `lint` → `layering.py` |
| 5 | Import upward: `ui/` script preloaded from `sim/` | `sim/core/Ids.gd` | `lint` → `layering.py` |
| 6 | Magic number `0.37` in `sim/` | `sim/core/Rng.gd` | `lint` → `magic_numbers.py` (warning in Phase 0–2: must appear in log) |
| 7 | Player-visible literal `"You died"` in `ui/` outside `Text.t()` | `ui/UiKit.gd` | `lint` → `strings.py` |
| 8 | Literal colour `Color(0.2, 0.3, 0.4)` outside `UiKit.gd` | `ui/screens/Main.gd` | `lint` → `strings.py` or dedicated colour rule |
| 9 | `data/backgrounds.json` entry missing a required key | `data/backgrounds.json` | `lint` → schema validation; `test` → `data` suite |
| 10 | Content over cap (13 backgrounds when `caps.json` says 12) | `data/backgrounds.json`, `data/caps.json` | `lint` → `content_counts.py` |
| 11 | `docs/STATUS.md` padded to 151 lines | `docs/STATUS.md` | `lint` → `doc_caps.py` |
| 12 | Check floor lowered by one | `tests/expected_checks.txt` | `test` → floor comparison |
| 13 | A fake key `AKIAIOSFODNN7EXAMPLE` in a comment | `tools/README.md` | `lint` → gitleaks |
| 14 | A `.safetensors` file (1 KB dummy) | `assets/dummy.safetensors` | LFS tripwire: Merge & CI review; `assets.yml` provenance validator when it exists |
| 15 | A seventh autoload added | `project.godot` | `test` → autoload count check in `smoke` suite |
| 16 | A 401-line GDScript file | `sim/core/Big.gd` | `lint` → gdlint `max-file-lines` |

## B. The clean PR

A one-line change to `docs/STATUS.md` (state line). Expected: `lint` and `test` green, squash
merge by Merge & CI, `build.yml` artefact downloadable, the `.exe` launches to the empty main
scene at 1920×1080 (screenshot attached to the gate record).

## C. Machine and repo checks (Concept Lead, by inspection)

- Live worktrees ≤ 4 (`tools/lint/worktrees.sh` output).
- `D:\MERCS-vault\` exists with the five folders; StabilityMatrix models root points there;
  banned files absent from the models root; `tools/machine_profile.json` matches `nvidia-smi`.
- Licence register: no PENDING row still lacking quoted permission text; Tripo row at D-014.
- Six skills present and AFL-free; four handoff seeds under 120 lines.
- Branch protection: PR required, `test` required, squash only, delete on merge, no force push.

## D. Sign-off

Recorded in `DECISIONS.md` as `D-0xx · Concept Lead · Phase 0 gate PASS/FAIL` with links to
the broken PR, the clean PR, the build artefact and the screenshot.
