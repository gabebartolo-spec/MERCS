# Phase 2 gate: structural audit evidence

Evidence for the Concept Lead's structural audit (`docs/08_ROADMAP.md`, Phase 2 "Gate"). This
is not a verdict: it lists, per audit item, the command run, what it printed and where the
proof lives, then every gap found. Collected on 2026-10-15 at main `a7705b5` (the last code
commit is `2ea4632`; its CI `tests` run 38724581064 is green), on the studio PC, Godot 4.7.2,
every Godot process headless with its own APPDATA.

New in this PR, tooling only (nothing in the game loads it):
- `tools/audit/gate_replay.gd`: one scripted campaign (the campaign suite's,
  `tests/lib/campaign_kit.gd`, grown by a captain's appointment and a three-day epilogue) played
  in steps, with modes `full` (uninterrupted), `split` (play to a checkpoint, write the save,
  quit) and `resume` (a fresh process reads the save through `SaveModel.from_dict`, as the game
  does, and plays on to the end).
- `tools/audit/gate_replay.sh`: runs every comparison below in parallel Godot processes and
  prints the md5 table. `GODOT=<console exe> tools/audit/gate_replay.sh <out_dir>`; 15 s here.

## Summary

| Audit item | Result | Gaps |
|---|---|---|
| Save, reload and continue from every milestone's state | 16 of 16 reloads in a separate process end in the uninterrupted run's save, byte for byte | M4 mid-fight only with Ironman On (by design, Save is refused in a fight); see gaps 1, 2 |
| The same seed replays the same campaign | Two processes, same final md5 (Ironman Off and On); another seed differs | One scripted route; see gap 3 |
| Every system has a passing player-effect fixture | 17 of 17 effect cases plus `ironman_quit` pass | 8 systems have suite checks but no on/off effect fixture; see gap 4 |
| All content in `data/` under schema | 21 of 21 JSON files validate | Balance files share one shape-only schema; see gap 5 |
| Lints and floors green | 31 of 31 suites at or above floor, harness self-test, 9 of 10 project lints, gdlint, gdformat, floors, shards | `worktrees` lint is red on this PC (machine state, not code); see gap 6 |

## 1. Save, reload and continue (separate processes)

Command: `GODOT=.../Godot_v4.7.2-stable_win64_console.exe tools/audit/gate_replay.sh <out_dir>`.
For each checkpoint, process 1 plays seed 424308 to the checkpoint and writes the save; process 2
reads that file, rebuilds the run (world, Rng streams, company with its economy, wounds block,
story block, the hub's hooks), plays the rest and writes the final save. The uninterrupted run
(process 3) is the reference. Ironman Off reference md5 `e9bcf2f69b8a5b71f72c6b8d206a59de`,
Ironman On `71ccf4609087662b92a0e368b4745416` (2,800 bytes; final state day 5, at the hub,
captain Vampyr, merc_4 dead, recruit_1 hired, purse 8, morale 65, storylet fired on day 2).

| Checkpoint (state saved) | What the save holds there | Ironman Off | Ironman On |
|---|---|---|---|
| `m1_world` | day 0, band 3 tiles out of the gate at (45,27), one ambush party placed, board of 3 | pass | pass |
| `m2_encounter` | the ambush standing (band at (44,26)), the starting six, orc captain | pass | pass |
| `m4_fight_mid` | Ironman fight save: the fight's start plus 20 of 41 actions (`FightRecord`) | n/a | pass |
| `m4_fight_fall` | the same, 36 actions: the first company merc is down, triage not yet run | n/a | pass |
| `m5_triage` | after the fight: merc_4 dead, chronicle 1, roster 5, loot taken (13 coin), prisoner waiting | pass | pass |
| `m6_hub` | contract accepted, recruit_1 hired (roster 6), prisoner released, purse 68, morale 65 | pass | pass |
| `m3_office` | the office handed to the Vampyr (`Company.appoint`, as the C screen does) | pass | pass |
| `m7_memory` | home, two days' rest at the hub, wages paid; the death's memories on the company | pass | pass |
| `m7_storylet` | `st_unspoken_loss` fired (story block), merc_3 +1 xp from the attempt | pass | pass |

Also printed by every resume (`AUDIT reload_writes_same_save`): the run rebuilt from the save
writes the save it read (canonical JSON, the fight key aside): `true` for all 16.
The mid-fight resumes print `AUDIT replayed 20 of 20` and `36 of 36 recorded actions`.

**Negative controls (the comparison can fail).** Same harness, a tampered save resumed:
every Rng stream position of `cp_m5_triage.json` moved by 1 gives final md5
`2c33c63bb2786f540b7383db40f0073a`; `cp_m7_storylet.json` with its `story` block removed (the
storylet then fires again in the epilogue) gives `3eb2c6358c91bf7aa9478b95da57721f`. Both differ
from the reference `e9bcf2f6...`, so a missing or wrong piece of state shows up.

**In-process proofs already on main** (each passes in the full run below):

| State | Proof |
|---|---|
| M1 world, band tile, parties (generated parties moving) | `tests/run_save_tests.gd:98` continue after reload, `:113` through JSON, `:325` band and parties |
| M2 encounter standing | `tests/run_save_tests.gd:280`; GUI: road suite "a save taken with an encounter standing reopens on its panel" |
| M3 company, captain, xp | `tests/run_save_tests.gd:217`, `tests/run_company_tests.gd:162` appoint (saved state changes) |
| M4 Ironman mid-fight, real game | `tests/run_ironman_resume_tests.gd` (a fresh game on the same save, twice, same turn, log and Rng) |
| M5 wounds, chronicle, the dead | `tests/run_injury_tests.gd:342`, `tests/run_wiring_tests.gd:236`, `:262` no save revives the dead |
| M6 economy | `tests/run_economy_company_tests.gd:207`, `:236` older save |
| M7 memory and storylet | `tests/run_story_tests.gd:307`, `:296` same seed same check after reload |
| Old saves | `tests/fixtures/save/v0.json`, `v1.json`, `v2.json`, `v2_ironman.json` (save, campaign, ironman suites) |

## 2. The same seed replays the same campaign

Same command. Two `full` runs of seed 424308 in two Godot processes, final save md5 compared;
seed 424316 must differ. The campaign walked every stage in all four runs (`AUDIT stages`:
placed, met, fought, triage, won, contract, hired, prisoner, appointed, paid, rested_at_hub,
storylet all true; `storylet_again` false, it fires once).

| Ironman | Seed 424308, process A | Seed 424308, process B | Seed 424316 |
|---|---|---|---|
| Off | `e9bcf2f69b8a5b71f72c6b8d206a59de` | `e9bcf2f69b8a5b71f72c6b8d206a59de` (same) | `3f664ac614ec53501b517c9c05ba05c5` (differs) |
| On | `71ccf4609087662b92a0e368b4745416` | `71ccf4609087662b92a0e368b4745416` (same) | `23470dd3709fc8c4cb70fb90a1edc9ea` (differs) |

In-process on main: `tests/run_campaign_tests.gd` (`_check_replay`, `_check_other_seed`: the
same campaign twice in one process, byte for byte), plus per system: sim_world same region,
sim_encounters same parties, battle same event log, economy same board and loot, injury same
triage, story same check.

## 3. Player-effect fixtures

Command: `tools/run_tests.sh effect` (part of the full run): `Effect tests: 19 checks, 0
failures` (17 cases, "every script is a case", "the expected systems are covered",
`tests/run_effect_tests.gd:12`). Each case prints `EFFECT <id>: <on> vs <off>`; quoted short.

| Milestone, system | Fixture (`tests/effect/`) | On | Off |
|---|---|---|---|
| M1 region generator | `world_map.gd` | seed 424242: gate (45,31), road 117, water 71 | seed 424243: gate (45,17), road 80, water 55 |
| M1 day tick | `world_tick.gd` | 16 supplies on day 7 | 30 supplies on day 7 |
| M1 walking costs days | `walk_drain.gd` | 30 steps: day 2, 26 supplies | 0 steps: day 0, 30 supplies |
| M2 encounter type | `encounter_road.gd` | ambush, enemy first, 2 bandits | patrol, toll 5, 2 watchmen |
| M2 parties on the map | `encounter_toll.gd` | 24 supplies at (45,31) | 30 supplies at (42,31) |
| M2 party sight (not psychic) | `party_sight.gd` | chasing: 1 step away | wandering: 3 steps away |
| M3 the cast | `company_merc.gd` | orc won with 13 hp, 20 attacks | Vampyr lost, blood price, 8 attacks |
| M4 blocking (terrain feature) | `battle_blocking.gd` | first blow on the guard | first blow on the chief |
| M4 morale and rout | `battle_rout.gd` | rout: 2 losers standing | no rout: 0 standing |
| M5 permanent injury | `permanent_injury.gd` | lost after 35 turns | won after 22 turns |
| M5 death, chronicle, memory | `death_memory.gd` | 1 chronicle, 1 memory on a comrade | 0, 0 |
| M5 wiring, succession | `wiring_hook.gd` | 5 mercs, captain orc, 1 dead | 6 mercs, captain Vampyr, 0 dead |
| M5 the dead stay dead | `wiring_death_reload.gd` | next fight: 5, orc leads | next fight: 6, Vampyr leads |
| M6 wages | `hub_wages.gd` | morale 72, owing 12 | morale 40, owing 84 |
| M6 prisoner | `hub_prisoner.gd` | roster 7, morale 63 | roster 6, morale 65 |
| M7 storylet by memory | `storylet_memory.gd` | fires, 2 effects | nothing offered |
| Campaign end | `campaign_end.gd` | ended, 0 alive | goes on, 1 alive |
| Ironman (D-087) | `tests/run_ironman_tests.gd:206` (not in `effect/`) | reload: 5 mercs (dead stay dead) | reload: 6 (pre-fight save) |

**Systems with no on/off effect fixture** (each has passing suite checks, which show the
rule works but not as a same-seed on/off player-visible difference):

| System (milestone) | Covered instead by |
|---|---|
| Experience bar and moves by level (M3) | `tests/run_company_tests.gd:207` |
| Captain's office, appointment (M3) | `tests/run_company_tests.gd:162`; succession is in `wiring_hook` |
| Turn order and intent (M4) | `tests/battle/skeleton_checks.gd:77`, `:106` |
| Non-psychic battle AI (M4) | `tests/run_battle_tests.gd:221` ("waits when it sees no one"); the map's is `party_sight` |
| Temporary injury (M5) | `tests/run_injury_tests.gd:122`, `tests/run_wiring_tests.gd:211` |
| Contracts from faction pressure (M6) | `tests/run_economy_tests.gd:223` |
| Loot and generic equipment (M6) | `tests/run_economy_tests.gd:279`; `tests/run_economy_company_tests.gd:53` (a blade changes the numbers) |
| Hiring (M6) | `tests/run_economy_company_tests.gd:94` |

## 4. Content in `data/` under schema

Command: `tools/run_tests.sh data`: `Data tests: 139 checks, 0 failures`. The suite
(`tests/run_data_tests.gd:53`) maps `data/<name>.json` to `data/schema/<name>.schema.json` and
`data/<dir>/*.json` to `<dir>.schema.json`, and checks: every file has a schema, every file
validates, ids unique per collection; then each known-good fixture in
`tests/fixtures/data/valid/` passes and each known-bad one in `invalid/` fails for its reason.

21 JSON files, 14 schemas, 0 unschemed, 0 invalid: `backgrounds caps encounters equipment
factions injuries locations mercs recruits scenarios storylets traits` (own schema each),
`balance/{battle,company,economy,injury,overworld,slice,stage,world}.json` (`balance`),
`text/en.json` (`text`). The 8 `data/balance/*.md` files are the knob explanations, not content.
Caps: lint `content_counts` "11 collections within their caps (phase 2)"; player words: lint
`strings` "38 ui and presentation files", no literal player text.

## 5. Lints and floors

| Command | Output |
|---|---|
| `GODOT=<console exe> tools/run_tests.sh` (import, 31 suites, harness self-test) | see the table below; all 31 suites pass, harness self-test pass, exit 0 |
| `bash tools/lint/run_all.sh` | layering (70 scripts), magic_numbers, strings, content_counts, no_weights (787 files), function_limits (133 scripts), lint self-test 12 of 12, pixels, pipeline 24 of 24: PASS. `worktrees`: FAIL, 8 then 9 live worktrees on this PC (gap 6) |
| `bash tools/check_floors.sh` | every floor unchanged, exit 0 |
| `bash tools/check_ci_shards.sh` | "31 suites in 1 shards, each exactly once" |
| gdlint and gdformat `--check` on the CI file list (142 files) | "Success: no problems found"; "142 files would be left unchanged"; file names snake_case |

Full run, checks per suite (floor in `tests/expected_checks.txt`; every suite at its floor):

| Suite | Checks | Suite | Checks | Suite | Checks |
|---|---|---|---|---|---|
| data | 139 | smoke | 30 | stage | 43 |
| stage_scale | 11 | stage_light | 8 | assets | 13 |
| slice | 16 | battle | 23 | loop | 8 |
| sim_world | 11 | sim_encounters | 11 | save | 12 |
| effect | 19 | overworld | 14 | road | 8 |
| company | 12 | company_battle | 5 | inspect | 9 |
| injury | 29 | economy | 34 | economy_company | 44 |
| hub | 12 | hub_fight | 1 | story | 60 |
| story_gui | 17 | wiring | 15 | campaign_end | 11 |
| campaign | 6 | panels | 11 | ironman | 12 |
| ironman_resume | 16 |  |  |  |  |

31 suites, 660 checks, 0 failures; every suite exactly at its floor. Harness self-test: pass. Summary line: "All checks passed." (exit 0).

## 6. Gaps, said plainly

1. **No player save in a fight or a triage with Ironman Off.** By design (panels suite: Save is
   refused mid-fight and with the triage up); quitting mid-fight loses the fight back to the
   last map save. With Ironman On a fight resumes at its turn (M4 rows above).
2. **The scripted campaign clears the region's own parties** and places one ambush, as the
   campaign suite does; wandering and chasing parties across a reload are proved in process
   only (`tests/run_save_tests.gd:325`), not by the cross-process harness.
3. **One scripted route.** The replay covers one walk, one won ambush with one death, the hub's
   choices, one appointment, rests and the storylet. Not covered by any whole-campaign replay:
   a lost fight and the fall-back, a patrol's toll, a hamlet or wild site, a second fight, a
   level-up, gear equipped, a contract completed or expired, the campaign's end.
4. **Eight systems have no on/off effect fixture** (table in section 3): experience bar,
   captain's office, turn order and intent, battle AI sight, temporary injury, contracts by
   pressure, loot and gear, hiring. The roadmap's per-milestone fixtures (M1 to M7 as written)
   all exist; these are systems inside milestones that only have rule checks.
5. **Balance files are under a shape-only schema** (`data/schema/balance.schema.json`: any
   snake_case number, bool, number list or group). A misspelt or missing balance key passes
   the schema; only the code and tests that read it would notice.
6. **`worktrees` lint red locally:** 8, then 9, live worktrees on the shared PC against a cap of 4
   (machine state; this audit's own worktree is one and is removed after). CI checks out one.
7. **Ironman resume in this harness is the sim path** (`FightRecord`, `SaveModel`); the game's
   own quit-and-reopen path is proved by `tests/run_ironman_resume_tests.gd` in process.
8. Every harness process prints `ERROR: 13 resources still in use at exit` (engine shutdown
   notice from a `--script` run; no `SCRIPT ERROR`, no effect on the saves).

## 7. Not exercised

- The game's screens in this harness (it is sim only; the GUI suites in the full run cover the
  screens at 1920x1080 with real input).
- Any seed other than 424308 and 424316 for the whole campaign.
- A save edited by hand, half-written or corrupt beyond the two tampered controls above, other
  than what the save suite's defaults and refusal checks cover.
- Linux or CI runners for the harness (run on the studio PC only; the suites run in CI).
