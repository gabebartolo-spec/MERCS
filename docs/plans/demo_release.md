# MERCS Demo Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.
> Every task also follows CLAUDE.md, `mercs-pr`, `mercs-proof-evidence` and `mercs-godot-tests`.

**Goal:** A downloadable Windows demo of MERCS: one company, one region, about 60-90 minutes from a new
company to a demo-end screen, handed to invited outside players, with their feedback flowing back to the director.

**Architecture:** No new systems. The demo is the Phase 2-5 game already on main, plus a thin shell
(main menu, settings, a data-driven demo end, versioned saves, a crash log), the remaining art through its
critic and look gates, a tagged CI release, and a closed itch.io page. Everything content-shaped
(names, demo length, version) lives in `data/`.

**Tech Stack:** Godot 4.7.2 (GDScript, static typing), `tools/run_tests.sh` suites with floors,
GitHub Actions (`tests.yml`, `lint.yml`, `build.yml`), Python art scripts in `D:/MERCS-vault`, itch.io + butler.

**Spec:** none written yet. This plan argues from `docs/00_VISION.md`, `docs/08_ROADMAP.md` Phase 9 (the
60-90 minute loop, save/load, settings, main menu, audio placeholder, start and end state, outside
playtests, licence audit) and `docs/DECISIONS.md` (D-044 84 px at 960x540, D-087 Ironman, D-091..D-117).
Task 0 turns the open choices into director decisions before any code.

## Lead's pushback (read first)

The roadmap forbids scaling before the Phase 9 success test, and a public demo is a Phase 10 item
("Steam page and build pipeline"). A public demo now would show unfinished art: the cast was rejected
on 2026-10-16 (D-117) and only the Orc is being redone. **Recommended:** make this demo the Phase 9
outside playtest: a closed itch.io page (download key or restricted access) for a few invited players.
Same build work, no public exposure, and its feedback is exactly the evidence the success test needs.
A public or Steam demo becomes a later decision after his PASS. Task 0 asks him.

## Global Constraints

- No runtime AI, ever (CLAUDE.md hard rule 1). Licensing: nothing ships unless `docs/10_LICENSING_REGISTER.md` lists it CLEARED.
- No spend without the director's written yes in `docs/DECISIONS.md` (itch.io closed page is free; Steam Direct is a fee and needs a yes).
- Agents never enter credentials: the director creates the itch.io account, the butler API key and any GitHub secret himself.
- Godot 4.7.2; Windows first; logical screen 960x540, x2 at 1080p, x4 at 4K (D-044); the director plays on a 4K TV.
- Determinism: every sim path seeded; tests never use the clock. Mortality is final; Ironman (D-087) save order kept (autosave last, `tools/lint/save_order.py`).
- Data, not code: names, demo length, version, audio volumes in `data/` with schemas; no magic numbers.
- Floors only rise (`tests/expected_checks.txt`); a new check is shown failing first; GUI tests click real controls (`tests/lib/input_kit.gd`).
- Art: hand-painted figures (D-117), fresh critic with real photos, lead QC at 1x/2x judging the read first, director look gate per screen or figure.
- Only board PRs edit `docs/STATUS.md` and `docs/DECISIONS.md`.

## Review Focus

1. **First launch on a clean PC** (no `user://` folder, no settings file): the game must start at the main menu, not crash. Pinned in Task 7.
2. **A save from an older playtest build:** must load (migration) or say plainly it can't, never crash or silently start fresh. Pinned in Task 8.
3. **Quitting mid-fight under Ironman, then Continue:** resumes the same fight state. Pinned in Task 8 (new-process test).
4. **4K TV and windowed 1080p:** integer scaling, no mixels, every control on screen at 3840x2160 and 1920x1080. Pinned in Task 6.
5. **The whole company dies before the demo end:** the end screen shows the chronicle and offers New company; no softlock. Pinned in Task 9.

---

### Task 0: Director decisions for the demo (gate; no code)

**Files:** none (answers go to the next board PR as D-entries).

- [ ] **Step 1: Ask, one question at a time, via `ask-the-director`, recommended option first:**
  - DD-1 Audience: closed itch.io page for invited players (rec.) / public free itch.io / Steam Next Fest (fee).
  - DD-2 Length: demo ends on day 30 (rec., about 60-90 min by the ledger's pace) / after N contracts / no cap.
  - DD-3 Cast: the two original mercs plus Wren, Gauda, Ambrose, Yaro, all hand-painted (rec.) / ship only the mercs whose art passed, the rest hired later.
  - DD-4 Feedback: an in-game "Send feedback" line pointing to an itch.io comments/forum page (rec.) / a form link he provides.
  - DD-5 Title and version shown: "MERCS (demo) v0.1.0" (rec.) / his words.
  - DD-6 Faction and place names: his pick from `MERCS-builds/faction_place_candidates_2026-10-16.md` (already queued).
- [ ] **Step 2: Record each answer verbatim in the scratch rulings and the next board PR.**
- [ ] **Step 3: Stop if DD-1 is a public or paid release: re-plan Task 16-17 with him before continuing.**

Done when: six answers recorded. Everything below assumes the recommended options.

---

## Track A: content the demo shows

### Task 1: Real names, and a lint that no placeholder can reach the player

**Files:**
- Modify: `data/factions.json`, `data/text/en.json` (site words), `sim/world/region_gen.gd` (only if names are built there)
- Create: `tools/lint/placeholders.py`; wire into `tools/lint/run_all.sh`
- Test: `tests/run_data_tests.gd` (new check), lint self-test case in `tools/lint/`

**Interfaces:** Produces `placeholders.py <paths...>` exit 1 on any hit; used by `lint.yml` via `run_all.sh`.

- [ ] **Step 1: Write the lint with the failing case.** Pattern (case-sensitive): `Faction [A-Z]\b|Hamlet \d|Wild site \d|Unnamed \d|The hub\b|TODO|PLACEHOLDER` over `data/**/*.json` values. Run it on main.
  Expected: FAIL listing `fac_placeholder_a`, `site_hamlet_*`, `site_wild_*`, `The hub`.
- [ ] **Step 2: Put the director's DD-6 names into data** (ids stay; display words change). The 3 hamlets and 3 wild sites take names from his chosen scheme's list in data, drawn by seed.
- [ ] **Step 3: Run `python tools/lint/placeholders.py data` and `tools/run_tests.sh`.** Expected: PASS; data suite floor +1.
- [ ] **Step 4: Recapture the hub board and terms screens** (`run_hub_terms_tests.gd -- --shots=`) and attach to the PR.
- [ ] **Step 5: Commit, PR (Review needed: none; Director gate: done, DD-6 words).**

### Task 2: Mercs 3-6 become full mercs

**Files:** `data/mercs.json`, `data/traits.json` (Hungry, Shrewd, Flatterer, Gambler), `data/schemas/*`; test `tests/effect/` one fixture per trait.

**Interfaces:** Consumes the bargaining step-in from C2 (`data/traits.json` keys). Produces four trait ids used by the terms screen.

- [ ] **Step 1: Write four effect fixtures** (`tests/effect/trait_<name>.gd`), each a seeded negotiation with the trait on vs off, asserting the drafted behaviour from `merc_candidates_2026-10-16.md`: Hungry asks supplies before coin; Shrewd small steady gain and walks if cheated; Flatterer more from nobles, less from commoners; Gambler wide swing (double or nothing). Run: FAIL (traits unknown).
- [ ] **Step 2: Add the traits and the four mercs' weapon, armour and accent from the drafts** (stats and moves stay placeholders the director tunes after playtest; say so in the PR).
- [ ] **Step 3: Run effect + data + hub_terms suites.** Expected: PASS; on vs off differ in each fixture.
- [ ] **Step 4: Commit, PR (Review needed: mercs-sim-review).**

### Task 3: The cast, hand-painted (longest pole)

**Files:** vault `D:/MERCS-vault/renders/cast_paint_2026-10-16/` per merc; repo `assets/look_target/heartland/sprites/<merc>_*.png|json`, normals, tokens.

**Interfaces:** Each merc delivers the sheet contract of `mercs-art-pipeline` (8 facings, frame 176, pivot (88,152), manifest json, normal map, token), passing `tools/pipeline/validate_sheet.py`.

- [ ] **Step 1: Orc S and SE to SHIP** (round 6 paused: front polish, boards, fresh critic).
- [ ] **Step 2: Director look gate on the Orc** (one question, labelled 1x/2x on grass, r7 beside).
- [ ] **Step 3: Orc's other 6 facings** (mirror E/W where the kit allows; NE/N/NW painted), critic per facing pair.
- [ ] **Step 4: Repeat Steps 1-3 for the Vampyr, then Wren, Gauda, Ambrose, Yaro** (DD-3), one merc per life, director gate per merc.
- [ ] **Step 5: Wire each passed merc into the sheet + token, run `tests/run_look_tests.gd` and `run_assets_tests.gd`.** Expected: PASS; goldens re-pinned with "director look gate <date>".
- [ ] **Step 6: Close #118 as superseded** once the Orc and Vampyr land.

### Task 4: Terrain tiles in the game

**Files:** vault `tile_trial_2026-10-15/B11_claude/`; repo palette (`assets/palette/biomes/heartland.json`), overworld tiles, golden.

- [ ] **Step 1: Finish B11 heather** (re-pick v2-v5 under B10 limits; rebuild twice, hashes equal; non-heather unchanged).
- [ ] **Step 2: Fresh critic with the moorland photos; fix until SHIP.**
- [ ] **Step 3: Director look gate on the tile board** (1x and 2x, beside the current golden).
- [ ] **Step 4: Palette PR (heather ramp, `heather_0` 70,40,58) and tiles wired into the overworld; golden re-pinned with his yes; look + assets suites PASS.**

### Task 5: Styled hub screens (contracts, wages, armoury buy/sell)

**Files:** `presentation/world/hub_panel.gd`, `terms_panel.gd`, `contract_rows.gd`, new `armoury_panel.gd`; UI kit; test `tests/run_hub_terms_tests.gd`, new `tests/run_armoury_tests.gd`.

**Interfaces:** Consumes C6 buy/sell sim (`Economy` town trade). Produces `ArmouryPanel.open(row: Dictionary) -> void`.

- [ ] **Step 1: Write the armoury GUI test** (real clicks): buy a worn item lowers coin by its price and adds it to the pack; sell returns 50%; a button out of coin is disabled. Run: FAIL (no panel).
- [ ] **Step 2: Build the armoury panel and restyle the hub panels to Look B** (`ui_look.gd`, Ledger typeface).
- [ ] **Step 3: Run hub, hub_terms, armoury suites.** Expected: PASS.
- [ ] **Step 4: Screen-critic on captures at 1920x1080 and 3840x2160; fix; director look gate.**
- [ ] **Step 5: Commit, PR (Director gate: done with his words).**

---

## Track B: the demo shell

### Task 6: Main menu and screen scaling

**Files:** `ui/screens/main.tscn` + new `ui/screens/main_menu.gd`; `data/text/en.json` (menu words); test new `tests/run_menu_tests.gd`, floor `menu`.

**Interfaces:** Produces `MainMenu.continue_available() -> bool` (true iff `SaveSystem` has a readable save) and signals `new_company`, `continue_run`, `open_settings`, `quit`.

- [ ] **Step 1: Write the failing GUI test:** at 1920x1080 and 3840x2160, the menu shows New company, Continue (disabled with no save), Settings, Quit, and the version line from `data/build.json`; clicking New company loads `slice_game.tscn`; every control's rect is inside the viewport.
- [ ] **Step 2: Run it.** Expected: FAIL (main.tscn has no menu).
- [ ] **Step 3: Build the menu with the UI kit; version text from `data/build.json` `{"title": "MERCS (demo)", "version": "0.1.0"}`.**
- [ ] **Step 4: Run menu suite + smoke.** Expected: PASS.
- [ ] **Step 5: Commit, PR (look gate: menu capture at both sizes).**

### Task 7: Settings screen and a clean first launch

**Files:** `presentation/autoload/settings.gd`, new `ui/screens/settings_panel.gd`; test `tests/run_settings_tests.gd`.

**Interfaces:** Produces `Settings.get_value(key: String) -> Variant`, `Settings.set_value(key: String, v: Variant) -> void`, persisted in `user://settings.json`; keys `window_mode` ("fullscreen"|"windowed"), `master_volume` (0-100), `ironman_default` (bool).

- [ ] **Step 1: Failing tests:** (a) with an empty `user://`, launching shows the main menu and writes defaults; (b) set windowed + volume 40, quit, a NEW process reads windowed + 40; (c) a corrupt `settings.json` falls back to defaults and logs one warning, no crash.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement; defaults in `data/settings_defaults.json`.**
- [ ] **Step 4: Run.** Expected: PASS (3 checks, new floor).
- [ ] **Step 5: Commit, PR.**

### Task 8: Saves the demo can trust

**Files:** `sim/core/save_model.gd` (version, migrations), `presentation/autoload/save_system.gd`, fixtures `tests/fixtures/save/`; tests `run_save_tests.gd`, `run_ironman_resume_tests.gd`.

- [ ] **Step 1: Failing tests:** (a) every fixture save from earlier builds loads or returns a typed "too old" result the menu shows as a sentence; (b) Ironman: begin a fight, quit at the autosave, NEW process Continue resumes the same fight (same enemies, same turn); (c) a half-written save (truncated file) is detected and the previous autosave is used.
- [ ] **Step 2: Run.** Expected: (a) or (c) FAIL until handled.
- [ ] **Step 3: Implement the "too old" result and atomic writes (write temp, rename).**
- [ ] **Step 4: Run save + ironman_resume + campaign suites.** Expected: PASS.
- [ ] **Step 5: Commit, PR (Review needed: mercs-sim-review).**

### Task 9: The demo end

**Files:** `data/balance/demo.json` `{"enabled": true, "last_day": 30}` (DD-2) + schema; `presentation/world/campaign_end.gd`; text in `data/text/en.json`; test `tests/run_campaign_end_tests.gd`.

**Interfaces:** Consumes `CampaignEnd.record_lines(company, chronicle, memory) -> Array[String]`. Produces `CampaignEnd.open_demo_end(game: Node) -> CampaignEnd`.

- [ ] **Step 1: Failing tests:** (a) a seeded run reaching `last_day` opens the demo-end screen with the chronicle lines and the buttons New company and Main menu; (b) a company wiped before `last_day` opens the normal end screen with the same buttons; (c) with `enabled: false` day 31 plays on.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement; the demo end deletes no save (the chronicle stays readable from Continue).**
- [ ] **Step 4: Run campaign_end + campaign suites.** Expected: PASS.
- [ ] **Step 5: Commit, PR.**

### Task 10: Audio placeholder pass

**Files:** `assets/audio/` (CLEARED sources only), `docs/10_LICENSING_REGISTER.md` rows, new `presentation/autoload/audio.gd` (bus volumes from Settings); test `tests/run_audio_tests.gd`.

- [ ] **Step 1: Pick 6 sounds** (UI click, hit, ranged loose, death sting, day ambience, hub ambience) from CC0 or original sources; add register rows; Merge & CI marks them CLEARED.
- [ ] **Step 2: Failing test:** each event on the EventBus plays its stream; master volume 0 plays nothing audible (bus muted).
- [ ] **Step 3: Implement; Run.** Expected: PASS.
- [ ] **Step 4: Motion/audio clip to the director (one question: keep / quieter / replace).**

### Task 11: Version, crash log and feedback line

**Files:** `data/build.json` (Task 6), `presentation/autoload/debug.gd`, main menu feedback line; `build.yml` writes the git sha into the exported build.

- [ ] **Step 1: Failing test:** an error pushed through `Debug` writes `user://logs/mercs_<date>.log` with version + sha; the main menu shows "Found a bug? <DD-4 link>".
- [ ] **Step 2: Implement; Run.** Expected: PASS.

---

## Track C: proof the demo is ready

### Task 12: Headless demo soak

**Files:** `tests/soak/demo_soak.gd` (not in the default suite; run by hand and in a manual CI job).

- [ ] **Step 1: 100 seeded campaigns (seeds 424200-424299) played by MercPlay to the demo end.** Expected: 0 script errors, 0 softlocks, every run ends on the demo-end or company-wiped screen.
- [ ] **Step 2: Report:** named deaths per 4 fights (target ~1, D-115), runs wiped before day 30, coin at the end, contracts taken. Attach to the PR; the director reads balance, the lead does not declare it settled.

### Task 13: Roadmap Phase 9 integration check

- [ ] **Step 1: Fixture removes three roster members one at a time;** assert something other than combat power changes (memories, bargaining, chronicle lines). Expected: PASS, or the demo is not ready (back to the failing system).

### Task 14: Director playtest of the gate build

- [ ] **Step 1: Build from main via `build.yml` (manual dispatch), copy to `MERCS-builds/<date>_demo-rc1_<sha>/`.**
- [ ] **Step 2: He plays; record every comment the same evening in a dated roadmap chapter (his words, owner, PR, status).**
- [ ] **Step 3: Fix list to zero blocking items; repeat rc2.. until he says ship.**

### Task 15: Licence and drift audit

- [ ] **Step 1: Every file under `assets/` traced to a CLEARED register row; anything else removed.**
- [ ] **Step 2: Concept Lead drift audit against `docs/00_VISION.md`; findings fixed or recorded as his decision.**

---

## Track D: release

### Task 16: Tagged release build in CI

**Files:** `.github/workflows/build.yml` (a `release` job on tags `v*-demo`), `tools/release/package.sh`.

- [ ] **Step 1: On tag `v0.1.0-demo`: export Windows release, run the existing launch smoke on the exe, zip `MERCS-demo-0.1.0-win64.zip` (exe + pck + README.txt with controls and the feedback link), attach to a GitHub release (draft).**
- [ ] **Step 2: Prove it on a throwaway tag (`v0.0.1-demo-test`), download the zip, run it on this PC from a fresh folder with an empty APPDATA.** Expected: main menu shows "MERCS (demo) v0.0.1"; delete the test release after.

### Task 17: itch.io closed page and upload

- [ ] **Step 1: The director creates the itch.io project (restricted/closed) and a butler API key; he stores the key as GitHub secret `BUTLER_API_KEY` himself.**
- [ ] **Step 2: Lead drafts page copy (plain words, what the demo is, how long, known issues, feedback link) and 4-6 captures from the real game (no debug overlays); director approves the words and images.**
- [ ] **Step 3: Add a `butler push out/windows <user>/mercs:windows-demo --userversion 0.1.0` step to the release job (secret only).**
- [ ] **Step 4: Push the real tag `v0.1.0-demo`; download from itch.io via a tester key on a clean folder; play to the main menu and one fight.**

### Task 18: Invite testers and close the loop

- [ ] **Step 1: The director sends the keys (we never message on his behalf).**
- [ ] **Step 2: Each tester report goes into the playtest roadmap chapter; Phase 9 success-test question asked of each tester in the director's words.**
- [ ] **Step 3: Patches carry his named fix first (`patch-carries-the-named-fix`); bump `data/build.json` version per upload.**

---

## Order and rough size (agent-days, a guess not a promise)

Task 0 (his time) -> Tracks A and B in parallel (A: Task 3 is the long pole, ~6 mercs x 1-2 days; B: Tasks 6-11 ~4 days)
-> Task 12-13 (~1) -> Task 14 (his playtests, 1-3 rounds) -> Task 15 (~0.5) -> Tasks 16-18 (~1 + his account setup).
