# Phase 2 gate pack: what to play and what to look for

Built on main 674c749 plus the blocked-step fix in this PR. Captures are 3840x2160 (a 4K
TV); `*_crop2x.png` is the text panel cut out and doubled with nearest filtering.
Regenerate them with `tools/capture/capture_gate.gd` (the command is in its header).

## What to play (the loop, in order)

1. **Arrive.** The game opens on the street. Walk the merc with WASD or the arrows. (`01_street_4k.png`)
2. **Walk the map.** Press M. WASD or the arrows walk the company one tile a step; hold to keep
   walking. Roads are quick, forest and hills slow. Every day on the map eats supplies (top left).
   Walk into water, a town's walls or the edge of the land: the panel now tells you why you stopped.
3. **Meet a party.** Red dots are bandits, blue are patrols. A dark outline on a party means it has
   seen you and is coming. Bandits strike first; a patrol offers a fight or a toll in supplies.
   (`02_map_party_in_sight_4k.png`, `03_ambush_panel_*`)
4. **Fight.** Press Fight. Six against the road party on the street. The turn order is along the
   bottom, each enemy's plan floats over it. Click a cell to move, or a button to act.
   Morale breaks a side before every body drops. (`04_road_fight_4k.png`)
5. **Triage.** After the fight the panel says who went down and what became of them: a wound, a
   temporary injury, a permanent injury, or a death with its chronicle line. (`05_triage_*`)
6. **Return to the hub (B).** Walk back into the hub's gate, or press Continue after a fight:
   loot and the prisoner come up at the hub. B opens or closes the hub. (`06_hub_*`, `08_hub_street_*`)
7. **Pay wages.** At the hub. Leave them unpaid past two days and morale falls 4 a day.
8. **Take a contract.** The hub's board (one to three, posted from the two factions' pressure).
9. **Hire.** Three recruits are offered at 25 coin each (roster cap 12).
10. **Decide a prisoner.** After a won fight: let them go, ransom (20 coin), execute, or offer a
    place. Each moves the company's morale differently.
11. **See the storylet fire.** Rest (map panel, "Rest a day") at the hub or a hamlet from day 1,
    with a comrade's death in the company's memory. A quiet hour appears with the odds shown
    before the roll; you pick who tries. The words are placeholders (see below).
12. **C company.** Press C, click a merc: stats, gear, role words, and Memories, the sentence
    each fight and choice left on them. (`07_company_memories_*`)

Save on the map panel (Save). The next start continues it.

## Keys (letters only)

| Key | Does |
|---|---|
| M | the map (and back to the street when standing on the hub's gate) |
| C | the company screen |
| B | the hub |
| L | the loop example (the older arrive, travel, camp demo) |
| H | key help on or off |
| G | frame time on or off |
| T, R | time of day, rain (street only) |
| WASD or arrows | walk the street merc, or the band on the map |
| Escape | close the open panel; on the hub's gate, leave the map |

## Every veto call from #80-#93, as one table

Values read from `data/` on this commit. "Where" is the file to edit (no code change needed
unless it says sim).

| # | Call made without you | PR | Now | Where |
|---|---|---|---|---|
| 1 | One encounter per journey at most | #80 | superseded by parties on the map (#93) | `data/balance/world.json` `parties` |
| 2 | Each road or party has its own random stream, so a different road gives a different encounter | #80 | on | sim (`encounter.<from>.<to>`) |
| 3 | Loss: walked days stay spent, fall back to the last site, supplies floored at 0 | #80, #93 | on | sim |
| 4 | Ambush has one Fight button; the enemy then acts first for the first turn only | #80 | on | `data/encounters.json` `enemy_first` |
| 5 | Toll offered only while supplies cover it | #80 | toll 5 supplies | `world.json` `encounters.patrol.toll_supplies` |
| 6 | Win loots and loss costs supplies | #80 | ambush +4 / -6, patrol +6 / -4 | `world.json` `encounters` |
| 7 | Placeholder foes: watchman, watch sergeant | #80 | in | `data/balance/battle.json` |
| 8 | Caps raised: encounters 2, locations 2 | #80, #93 | 2 and 2 | `data/caps.json` |
| 9 | Enemy turn line says "The enemy acts" | #80 | in | `data/text/en.json` |
| 10 | Triage odds wound, temporary, permanent, death | #82 | 40/30/20/10 percent | `data/balance/injury.json` `triage` |
| 11 | Injury stat changes (arm -2 for 5 days, eye -3 attack) and role words | #82 | in | `data/injuries.json` |
| 12 | Succession: highest resolve; dissent is the runner-up | #82 | on | `data/balance/injury.json` `succession` |
| 13 | A permanent injury's role text is words only, nothing reads it yet | #82 | words only | `data/injuries.json` |
| 14 | Blocking (every standing fighter blocks) as the one terrain feature | #85 | on | sim (`sim/battle/`) |
| 15 | Intents planned each round; a marker vanishes once the enemy acts | #85 | on | sim |
| 16 | Enemies target the closest foe they see | #85 | on | sim (`BattleAi`) |
| 17 | Shaken below 75, rout below 35 morale, same for both sides | #85 | 75 / 35 | `data/balance/battle.json` `morale_sides` |
| 18 | Storylet check: d10 vs 11; mourner tries by resolve, friend by presence | #89 | on | `data/storylets.json` |
| 19 | Storylet fires only on Rest at hub or hamlet, from day 1, once per run | #89 | on | `data/storylets.json` `trigger`, `once` |
| 20 | Success gives the mourner 2 xp, failure 1; no morale or injury effect | #89 | on | `data/storylets.json` |
| 21 | One short factual memory sentence per merc per fight or choice | #89 | on | `data/text/en.json` `memory.*` |
| 22 | All living mercs up to six are fielded, no pick screen | #90 | on | `data/scenarios.json` `road_cells` |
| 23 | A temporarily injured merc still fights with the penalty | #90 | on | sim |
| 24 | Only a blow that puts a merc down triggers triage | #90 | on | sim |
| 25 | A downed merc dies one time in ten | #90 | 10 percent | `injury.json` (the 90 to 100 band) |
| 26 | If every merc dies there is no game-over screen | #90 | none | open |
| 27 | Map 56 x 42 tiles (8 x 6 cells of 7) | #93 | in | `world.json` `region`, `tiles` |
| 28 | Walking cost: road 2, plain 3, forest 5, hill 6; a day is 24 units | #93 | in | `world.json` `terrain_cost`, `march` |
| 29 | Diagonal steps allowed, cost as straight | #93 | on | sim |
| 30 | Parties: 3 bandits (sight 5), 2 patrols (sight 4, 80% speed), start 10+ tiles from the hub | #93 | in | `world.json` `parties` |
| 31 | You see every party at any distance (no fog); parties are limited by sight | #93 | on | presentation |
| 32 | Contact is the same or a neighbouring tile; walking into bandits is an ambush | #93 | on | sim |
| 33 | A settled party is away 6 days (bandits) or 4 (patrol) | #93 | 6 / 4 | `world.json` `return_days` |
| 34 | Only the hub cuts to a street; hamlets say "nothing here has work for it yet" | #93 | on | `data/text/en.json` |
| 35 | Chasing is greedy (no pathfinding); water and walls shake a party off | #93 | on | sim |
| 36 | The map regenerates from the seed, not stored; a balance change redraws it under a save | #93 | on | sim |
| 37 | Walking keys: first repeat 0.25 s, then every 0.12 s | #93 | in | `data/balance/overworld.json` `walk` |
| 38 | Economy first numbers (purse 80, wages 2 a day, grace 2 days, morale 60, recruit 25, ransom 20) | #87 | in | `data/balance/economy.json` |

#87 had no veto section; row 38 is added here because its numbers are first guesses for you to tune.

## Placeholders you must author

- **Mercs 3 to 6** (`merc_3` to `merc_6`, shown as "Unnamed 3" to "Unnamed 6"): names, stats, role
  words, moves, gear line. `data/mercs.json` (marked placeholder), words in `data/text/en.json`.
- **Recruits** (`recruit_1` to `recruit_6`, "Recruit 1" and so on): `data/recruits.json`.
- **Two factions** (`fac_placeholder_a`, `fac_placeholder_b`, "Faction A" and "Faction B"): names,
  what they want, why they press the road. `data/factions.json`.
- **Storylet words:** `storylet.unspoken_loss.title`, `.scene`, `.attempt_mourner`,
  `.attempt_friend`, `.success`, `.failure`, and `memory.grief_eased`, `memory.shared_words`,
  `memory.grief_deepened` in `data/text/en.json` (9 entries marked placeholder).
- The orc and the Vampyr are the two authored mercs; the look is the grey bald placeholder body.

## Suite counts (full local run on this branch, `tools/run_tests.sh`, all pass)

| Suite | Checks | Suite | Checks | Suite | Checks |
|---|---|---|---|---|---|
| data | 139 | battle | 23 | company | 12 |
| smoke | 30 | loop | 8 | company_battle | 5 |
| stage | 43 | sim_world | 11 | inspect | 9 |
| stage_scale | 11 | sim_encounters | 11 | injury | 29 |
| stage_light | 8 | save | 12 | economy | 34 |
| assets | 13 | effect | 18 | economy_company | 44 |
| slice | 16 | overworld | 14 (was 11) | hub | 12 |
| road | 8 | hub_fight | 1 | story | 60 |
| story_gui | 17 | wiring | 15 | | |

26 suites, 603 checks, 0 failures. Also green: the harness self-test, `tools/lint/run_all.sh`
(10 of 10), `tools/check_floors.sh`, `tools/check_ci_shards.sh`, gdlint and gdformat on the files
touched. The `overworld` floor rises 11 to 14 (the three new blocked-step checks).

## Player-effect fixtures (`tests/effect/`, run by the effect suite)

Same seed, system on and off, visibly different. Outcomes are what the suite prints; the
fixture's header says exactly what is toggled.

| Fixture | System | Outcome A | Outcome B |
|---|---|---|---|
| world_map | M1 region | seed 424242: gate (45,31), 117 road, 176 forest, 71 water | seed 424243: gate (45,17), 80 road, 185 forest, 55 water |
| world_tick | M1 day tick | drain on: 16 supplies on day 7 | drain 0: 30 supplies |
| walk_drain | M1 walking | 30 steps: day 2, 26 supplies | 0 steps: day 0, 30 supplies |
| encounter_road | M2 parties | ambush, enemy first, 2 bandits | patrol, toll 5, 2 watchmen |
| encounter_toll | M2 on the map | band stopped, 24 supplies, fell back to (45,31) | no party: arrives at (42,31) with 30 |
| party_sight | parties | in sight: closes to 1 step | out of sight: 3 steps, wandering |
| company_merc | M3 the cast | won with 13 hp left, 20 attacks | lost with 0 hp, blood price paid, 8 attacks |
| battle_blocking | M4 blocking | blocked: first blow falls on the guard | not blocked: falls on the chief |
| battle_rout | M4 morale | rout on: ends with 2 of the losers standing | rout off: runs to the last fighter |
| permanent_injury | M5 | with the lost eye: lost after 35 turns | without: won after 22 turns |
| death_memory | M5 | 1 chronicle entry, memory on a comrade | none, none |
| wiring_hook | M5 wiring | one dead, captain orc, 5 mercs, chronicle 1 | all six, no chronicle |
| wiring_death_reload | M5 wiring | next fight led by orc, five mercs | next fight led by the Vampyr, six mercs |
| hub_wages | M6 | paid: morale 72 | ignored a week: morale 40, owing 84 |
| hub_prisoner | M6 | recruit: roster 7, morale 63 | release: roster 6, morale 65 |
| storylet_memory | M7 | memory held: storylet fires, 2 effects | no memory: nothing offered |

For the two wiring rows I copied the suite's own order; read each fixture's header for which
side is "on". The rows' outcomes are the point, not the order.

## Structural self-check (the gate's audit, honest)

**Save, reload, continue from each milestone's state.** The save holds the world, the random
streams, the company with its economy, the wounds block and the story block; `SaveSystem`
writes it from the map's Save button.

| Milestone state | Proved by |
|---|---|
| M1 world, band tile, parties | save: "a run continued from a save that went through JSON matches the uninterrupted run"; "the band's tile and the parties come back" |
| M2 an encounter standing | save: "a pending encounter survives a save through JSON and the run continues as the uninterrupted one" |
| M3 company, captain, xp | save: "a save with a company round-trips through JSON"; company: the v0 fixture migrates |
| M4 battle | not saved: a fight lives only on screen, Save is not offered during one (gap 2) |
| M5 wounds, chronicle, the dead | wiring: "no save revives the dead", save round trip; effect wiring_death_reload; wiring GUI "a new session: the dead are never fielded" |
| M6 purse, morale, board, pending loot and prisoner | economy_company: "the company, with its economy, round-trips equal through JSON"; "the economy rides in the save model" |
| M7 memories, storylet fired | story: "state survives JSON"; "a run reloaded from a save rolls the same check as one that went on" |
| Old saves | save: v0 and v1 fixtures (`tests/fixtures/save/`) migrate; economy_company: an older save reads with the new-game purse |

**Same seed, same campaign.** Proved per system, not as one whole run: sim_world ("same seed
lays out the same tile map"), sim_encounters ("same seed and walk move the same parties"),
battle ("replays to the same event log"), economy (same board, same loot), injury ("same seed,
same triage"), story ("same seed rolls the same check"), loop (replays to the same log).

**Every system has a fixture:** the 16 above cover milestones 1 to 7.

**Content in `data/` under schema:** the data suite (139 checks; schemas in `data/schema/`;
known-bad fixtures rejected); lint `content_counts` (11 collections within their caps) and
`strings` (no player words in code).

**Lints and floors:** all green (above).

### Gaps, said plainly

1. **No whole-campaign replay check.** Nothing plays arrive, walk, fight, triage, hub and storylet
   twice on one seed and compares the two end states. The parts are each pinned; the seams are
   covered only by the wiring suite's single GUI run (seed 424270). A candidate depth-pass test.
2. **No save in the middle of a fight or a triage.** Save exists only on the map panel; closing
   the game mid-fight loses the fight (the earlier map save stands).
3. **No old-save fixture for version 2** (the current one); only v0 and v1 are on file. Missing
   keys read with defaults (tested), but a real v2 file is not.
4. **Memory sentences show the id, not the name** ("I stood beside merc_4 when he fell on day 0",
   `07_company_memories_crop2x.png`). A real defect, not fixed here (outside this PR's one fix).
5. **Panels overlap in play.** C opened over the hub's post-fight screen (or the hub over the map)
   stacks two panels; the hub panel has no backing and its text collides with the map's "Day,
   Supplies" label (`06_hub_crop2x.png`). In the fight, the intent labels ("Attacks Unnamed 4")
   sit on the top panel's text (`04_road_fight_4k.png`). Readable at 4K, but messy.
6. **The "seen you" ring is a 1 px dark outline**, and the band's own token has the same outline,
   so a chasing party barely reads as different from a wandering one
   (`02_map_party_in_sight_4k.png`). Your eye should judge it.
7. **Every merc is the same grey bald placeholder body**, so you tell them apart in a fight only
   by name. Expected until Phase 1, but it is what you will see.
8. The hub screen captured is the post-fight one (loot and prisoner); the contracts, recruits and
   wages rows are not in a picture.
9. Not exercised: a hamlet or wild site's gate (only its line), a patrol's toll through the GUI, a
   loss and fall-back through the GUI, the storylet through the GUI in this pack (the story_gui
   suite covers it at 1920x1080), any size other than 1920x1080 and 3840x2160.
