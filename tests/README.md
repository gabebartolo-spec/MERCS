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
| `stage` | The Phase 1 grey-box capture stage (`presentation/world/street_stage.tscn`) loads with its street, light, camera and sprite as `data/balance/stage.json` says; `pitch_degrees` moves the camera; the sprite's `pixel_size` follows its height; CRISP and WHOLE_SCREEN pixel modes instantiate (640 × 360 SubViewport scaled 3×, sprite snapped to its pixel grid); the walk loop completes; DAY vs RAIN_NIGHT lighting (torch, fixed-seed rain, sprite tint) | 43 |
| `stage_scale` | The stage's scale contract: at the look-at point one sprite texel spans one logical pixel across and up for every sample-set-1 pitch (30/35/40°) and height (40/48/56 px), matching `tools/pipeline/camera_rig.json`; the sprite stands with its pivot on the ground; a factory sheet (`mercs.sheet/1`) shows one frame per facing and refuses an unknown facing; CONSTANT depth scale keeps a texel one pixel off the look-at depth, PERSPECTIVE lets a nearer merc grow; `stand_at` holds the feet | 11 |
| `stage_light` | Lit sprites: a frame with a normal map (sheet `normal_image` or the capsule's) draws with a shaded, normal-mapped, nearest, Y-billboard material and no night tint; the capsule's normals face camera, right and up correctly; with `lit_sprites` off or no normal map the sprite is unshaded and tinted at night; a sheet whose normal map is missing is refused | 8 |
| `assets` | Every factory sprite sheet (`mercs.sheet/1`) under `assets/`, plus the pipeline's good fixture, passes the engine-side rules in `tests/lib/sheet_check.gd`: it loads in Godot for every facing, its facings, frame size and pivot match `tools/pipeline/camera_rig.json`, and a named normal map loads at the sheet's size. Each rule rejects a planted-bad copy, and only that rule fires. Pixel rules stay with `tools/pipeline/validate_sheet.py` | 8 |
| `slice` | Art direction slice M1: real key and click events walk the merc on the grid; houses and the well block it; the camera follows in whole logical pixels; the door leads into the interior and back; T / R / F1 switch time of day, rain and help; the crowd repeats exactly; walk and idle sheets play by facing and time, looping; F5 opens the loop example and real clicks on its panel buttons walk it to the road at dusk in rain | 15 |
| `battle` | Sim core for the slice's loop example: Rng streams are independent and survive a save; a seeded fight replays to the same log and another seed differs; moves respect range, walls and fighters; attacks need an adjacent enemy; a hit to 0 hp downs and costs morale (more for the leader); low morale surrenders with fighters standing; the enemy waits when it sees no one; the orc's charge and the Vampyr's blood price; visible checks roll in the open | 14 |
| `loop` | The slice's one pass of the core loop (`SliceLoop`, `data/scenarios.json`): a seeded pass reaches camp through every stage and replays the same; hiring adds the recruit; a talked-down lookout leaves the band shaken and short one, failing or fighting brings him in; no aftermath choice without a surrender; a wounded merc comes home with an injury | 4 |
| `sim_world` | The world between battles (`WorldSim`, `RegionGen`, `WorldSite`; `data/balance/world.json`): the same seed lays out the same region and another seed a different one; counts and ids match the balance; every site has its own grid cell and is reachable from the hub by two-way roads of the balance's length; travel off the roads is refused and changes nothing; a road costs its days and each day's supplies; supplies stop at 0 and starving is marked; a restored state continues as the uninterrupted run | 9 |
| `sim_encounters` | Encounters on the road (`WorldSim`, `EncounterBattle`; `data/encounters.json`, `data/balance/world.json` "encounters"): a day on a road raises an encounter on its own Rng stream and stops the travel where it is, with travel and rest waiting; a chance of 0 raises none, on the same map; a win loots supplies and the road goes on, a loss costs supplies and falls back to the site left (settled once); a patrol's toll buys the way past, refused when short and for an ambush; an ambush gives the enemy the first turn, a patrol the company; the same seed raises the same encounters and never rolls the world stream | 8 |
| `save` | The save model (`SaveModel`): `to_dict` → `from_dict` → `to_dict` round-trips; a 64-bit Rng stream position comes back from JSON exact (positions are saved as strings); a run continued after reload (in memory and through JSON) matches the uninterrupted run; a save missing optional keys reads with defaults; a newer version is refused with an error code; the version 0 fixture (`fixtures/save/v0.json`) migrates and keeps its state; a pending encounter survives a save through JSON and the run continues as the uninterrupted one; a save without the encounter key loads with none | 9 |
| `effect` | The player-effect fixtures (04_GUARDRAILS.md A1): every case in `effect/` runs the same seed with its system on and off and prints `EFFECT <id>: <on> vs <off>`; the two must differ. One check per case (`world_tick`: the supply drain; `world_map`: the seeded region; `encounter_road`: another road, another encounter; `encounter_toll`: encounters on against a chance of 0), one that every script there is a case, one that the expected systems are covered; a new case raises the floor like a fixture; `permanent_injury`: the lost eye changes a battle result; `death_memory`: a death chronicle entry and comrade memory survive a save | 8 |
| `overworld` | The overworld on screen (`OverworldDirector`, `OverworldMap`, the `SaveSystem` autoload): a real F2 tap opens the map with a marker per site and the day's road, rest and save choices; a held key does not walk the merc while it is open; real clicks on the panel's buttons take a road (the day moves by the road's days, the company's ring moves to the new site), rest a day and save; the map hidden by F2 and shown again keeps the run (same director, day and site); the save on disk (`user://save_v1.json`, under the run's own user dir) loads back equal; F2 hides the map and walking resumes; a fresh session's first F2 continues the save instead of starting fresh, and Escape hides it | 8 |
| `road` | An encounter on the road, on screen (`OverworldDirector`, `BattleView`, real F2/Escape taps and panel clicks): the road to the second hamlet raises a patrol whose panel words it with Fight and the toll, the company staying put, and F2 or Escape keep it; Fight closes the map on the street battle with the company first and F2 cannot close it, and the finished fight leaves the street, applies the result and reopens the map with the outcome in words; the toll skips the fight; a saved world's ambush offers only Fight and the enemy strikes first; a save taken with an encounter standing reopens on its panel | 7 |
| `injury` | The wound ladder (`Injury`, `Aftermath`, `Chronicle`, `Memory`, `Succession` in `sim/merc/`; `data/injuries.json`, `data/balance/injury.json`): exactly one wound, one temporary and one permanent injury, worded in `en.json`; the triage thresholds cut the die where the balance says; the same seed gives the same triage in any id order and a company meets every outcome; a temporary injury ends on its day, a permanent one stays and shows in stats, sprite layer and role; after a fight a death is in the chronicle with its cause, writes a memory on every survivor and, for the captain, names a successor and one dissenting voice (a fallen successor is passed over); a dead id cannot be recorded twice or restored; chronicle, memories and injuries survive a save (through JSON) and an old save reads with empty ones | 29 |

The harness self-test (`tools/test_run_tests.sh`) proves the runner fails a suite short
of its floor or without one, and that an untyped declaration
(`fixtures/compile/untyped_var.gd`) does not compile.
