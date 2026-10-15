# Contracts and the road: work packages

Director, 2026-10-16: the next depth pass after combat is **Contracts and the road**. Source: the
director interview of 2026-10-16 02:40-02:50 (to be logged as D-096.. by the Merge & CI agent),
`docs/00_VISION.md` (pillar 9, Economy, Core loop steps 3, 4, 7 and 8), `docs/08_ROADMAP.md`
Phase 2 milestones 2 and 6 (the baseline this deepens), Phase 7 and Phase 8 (the roadmap sections
this pass draws on). This file splits the pass into packages builders can take in parallel; it
decides no taste or balance. Every package ends at the Phase 2 rule: its player-effect fixture
passes (same seed, system on and off, a visibly different outcome), then the director plays it.

Numbering: the roadmap's Phase 5 is "Consequence depth". The director chose this pass to come
next, so the file is `phase5_contracts.md`; the Merge & CI agent reorders the roadmap's depth
passes in a board PR (no package here edits `docs/08_ROADMAP.md`).

## The director's rulings (verbatim, 2026-10-16)

- "Next depth pass after combat: Contracts and the road."
- "Prisoners: ransom, recruit, release, execute (all four)."
- "Loot: yes, worn (battered) gear from fallen enemies."
- "Armour: strong but costly; costs = slower to act + price and upkeep (not fatigue, not movement)."
- "Lethality: a named-merc death every few fights. Company cap 8. Typical fight roughly even, 4-8 enemies."
- "Contracts: all four types (clear bandits, escort, hold a place, hunt a man). Wages: daily wage + share.
  Pay terms are NEGOTIATED ("you must negotiate"): terms (split + price) employer accepts/counters/walks by
  reputation and need, plus a merc may step in once using traits. Push too hard -> he walks, name dented.
  Failure/abandon: reputation and grudges (badly broken deals send men after you)."

Nothing below goes beyond these lines. Where they leave a rule open, the package builds the
mechanism on placeholder numbers and the rule waits in "Open questions for the director".
"Slower to act" for armour is combat (Phase 4 P1b, `battle_gear.gd`); this pass owns only the
price and upkeep half.

## Why each part earns its place (the mercs are the game)

| Part | What the player sees about a merc |
|---|---|
| Negotiation step-in | one merc talks for the company; win or lose, he remembers it and so do they (a memory sentence on him and on those who watched) |
| Daily wage + share | a merc is paid what he is worth; a shorted share is felt by named men, not a bar |
| Reputation and grudges | men sent after the company because of a deal the captain broke; who was captain is remembered |
| Prisoners | the captain's call on a beaten man, and who in the company liked it |
| Worn loot and armour cost | the orc's plate is a bill the company pays every day to keep him alive |
| Four job types | each job puts different mercs forward (the hunter, the holder, the escort) |
| 4-8 enemies, cap 8, a named death every few fights | a small company where every loss has a name |

A part that cannot write a memory or change a named merc's state is cut, not polished.

## What exists (reuse, do not rebuild)

| Piece | File | State on main |
|---|---|---|
| Contract board | `sim/economy/contracts.gd` (56 lines) | posts 1-3 records `{faction, site, reward, deadline, accepted}` weighted by faction pressure, `contracts` stream |
| Economy | `sim/economy/economy.gd` (336 lines) | purse, flat wages (`per_merc_per_day`), morale, board, accept / complete / expire, loot, hire, equip, one prisoner with four choices. **20 of 20 public methods used** |
| Loot | `sim/economy/loot.gd` | coin plus a random item from `data/equipment.json` by encounter type, `loot` stream |
| Hub UI | `presentation/world/hub_director.gd` (310 lines), `hub_panel.gd` | board, accept, pay, hire, equip, prisoner choice |
| World | `sim/world/world_sim.gd` (369 lines, 13 public) | day tick, sites and roads, parties that wander and chase on sight (`world_party.gd`, `party_moves.gd`), encounters and toll |
| Encounters | `data/encounters.json`, `sim/world/encounter_battle.gd` | ambush and patrol, line-ups of 2-3 enemies |
| Company | `sim/merc/company.gd` (14 public), `data/balance/company.json` | roster cap 12 |
| Story | `sim/story/checks.gd` (visible check, odds shown), `sim/merc/memory.gd` (`record`, `on_choice`) | traits: `data/traits.json` is **empty** |
| Replays | `tests/lib/campaign_kit.gd`, `tests/lib/route_kit.gd` | five whole-campaign routes replayed |

Gap that matters most: **no live code calls `Economy.complete()`**. Accepting a contract changes
nothing in the world today; a contract is a line on the board. The first job of this pass is to
make a contract a real job.

## Caps every package obeys

4 job types; 1 board; 2 factions (unchanged); company cap 8; road fights of 4-8 soldiers or up to
12-16 rabble; one reputation track and one grudge per faction (Q-7); one step-in per negotiation; prisoners
only from a surrender or rout the battle reports. Caps go in `data/caps.json` (`jobs: 4`, and the
enemy caps of C7) so the content-count lint enforces them. No trade, crafting, gladiator
events or banditry (Vision "many ways to earn" stays Q18).

## Shared files: the only overlaps, and how they stay mechanical

- `sim/economy/economy.gd` is full (20 public). **C0 splits it first**, byte-identical, into a
  facade plus modules; the facade then keeps at most 14 public methods, leaving 6. Budgeted: C2
  `negotiate(id, ask, speaker_id)`, C4 `abandon(id)`, C6 `buy(company, item_id)`; three spare. A
  package prefers a new field read through `state()` or a module over a new facade method.
- `sim/world/world_sim.gd` is at 369 of 400 lines with 7 public slots. New world behaviour lives
  in new files; `world_sim.gd` gains at most two call lines and two public methods: C1
  `place_job(contract)`, C4 `send_hunters(faction_id)`. Four spare.
- `data/balance/economy.json` and `economy.md`: one block per package, never another's. C1 none
  (`data/jobs.json`); C2 `terms`; C3 `wages` (replaces the flat knob, same block name); C4
  `standing`; C5 `prisoner`; C6 `loot`, `armoury`.
- `data/balance/world.json`: C1 `jobs`; C4 `parties.hunters`; C7 `encounters` line-up sizes.
- `data/text/en.json`: keys prefixed by package (`hub.terms.*`, `hub.wages.*`, `hub.job.*`, ...).
- `tests/expected_checks.txt`, `tests/README.md`, `tools/run_tests.sh`, `tools/ci_shards.txt`,
  `tests/run_effect_tests.gd` expected-system list: one line per package; merge order resolves.
- `tests/economy/golden_checks.gd` (C0): a package that changes the five routes **on purpose**
  re-pins the hashes it moves in the same PR, with a one-line reason and a before/after table; a
  package meant to be neutral for old routes adds a route and leaves the old hashes alone.

## Determinism rules for every package

- New randomness gets its own stream so old routes replay unchanged: `jobs` (job type and
  placement), `terms` (the step-in check), `grudge` (where hunters start). The board keeps the
  `contracts` stream in its current draw order; the job type is drawn after, on `jobs`.
- Loot changes its draw (C6), so it re-pins on purpose; nothing else touches the `loot` stream.
- The step-in is a visible check (`Checks.attempt`, odds shown before the roll, pillar 7) on the
  `terms` stream, never on `story`, so storylet replays are untouched.
- The employer's reply (accept, counter, walk) is a rule over reputation, need and the ask:
  computed, not rolled. The player can read why.
- Saves: every new field is an optional key with a default; an old-save fixture loads; reload
  and continue equals uninterrupted (`mercs-sim-review`). If the inventory's shape must change
  for worn gear (C6), that package adds a `Format` value and a `_migrate` step, never a silent
  reinterpretation.

## Packages

Sizes are agent-days. "Starts now" means no unmerged dependency.

### C0 — Split the economy and pin the campaign routes — 1 day — starts now

- Files: `sim/economy/economy.gd` (facade), new `sim/economy/contract_book.gd` (board, accept,
  complete, expire), new `sim/economy/prisoners.gd` (the waiting prisoner and the four choices),
  new `tests/economy/golden_checks.gd` (the five `route_kit`/`campaign_kit` routes on two seeds,
  save text hashed and pinned).
- No behaviour change: the golden hashes are taken before the split and must hold after.
- Review: mercs-sim-review. Blocks every sim package below.

### C1 — A contract is a job: the four types (sim) — 3 days — after C0

- Files: new `sim/world/jobs.gd` (places a job on the map and judges done or failed, per type),
  `sim/economy/contract_book.gd` (the record gains `job`), `sim/world/world_sim.gd` (`place_job`,
  one call in the tick), `tests/world/job_checks.gd` (new), `tests/effect/contract_jobs.gd` (new).
- Reuse: a bandit camp and a quarry are `WorldParty` records with new types (they already
  wander, see and chase, `party_moves.gd`); an escort's charge is a party that walks with the
  band; a hold is a stay at a site counted by the day tick; the fights are the existing
  encounter path into the battle.
- Data: new `data/jobs.json` + `data/schema/jobs.schema.json` (four templates: id, type, words
  key, which party type it places); `world.json` `jobs` (placeholder days and distances); cap
  `jobs: 4`.
- Completing a job calls `Economy.complete()` (the missing link). Each job writes a memory line
  on the mercs who fought it.
- Fixture `contract_jobs`: same seed, each type accepted vs not: a party appears on the map, a
  fight is raised at the place, the purse differs at the end.
- Q-9 decided as proposed (see Decided). The mechanism can be built on clear bandits first.

### C2 — Terms and negotiation (sim) — 3 days — after C0

- Files: new `sim/economy/terms.gd` (an ask is price + split; the employer's reply from
  reputation, the faction's need and the ask: accept, counter or walk), `economy.gd`
  (`negotiate`), `tests/economy/terms_checks.gd` (new), `tests/effect/contract_terms.gd` (new).
- Need = the faction's existing `pressure` (`data/factions.json`); no new world number.
- Step-in: once per negotiation, one merc the player picks makes a visible check from his
  bargaining trait (`Checks.attempt` on the `terms` stream); success moves the employer's
  limit, failure moves it back. It writes a memory on that merc either way.
- Push too hard: an ask past the walk line ends the offer (the contract leaves the board) and
  dents the name (calls C4's standing; until C4 merges, a stub number on the economy).
- Data: `economy.json` `terms` (placeholder bands as whole numbers); the bargaining trait per
  merc in `data/traits.json` + `data/mercs.json` once Q-8 is answered.
- Fixture `contract_terms`: same seed and ask, high vs low reputation: accepted vs countered;
  with a step-in vs without: a different reply; past the line: the employer walks and the
  reputation is lower.
- Q-6 decided: the split is advance vs on return. Q-8 decided: a bargaining trait per merc that the
  director names (placeholders until then).

### C3 — Wages: daily wage plus a share (sim) — 2 days — after C0

- Files: new `sim/economy/payroll.gd` (each merc's daily wage, the share owed when a contract
  pays, who is owed what), `economy.gd` (`on_day` and `complete` call it; no new public method),
  `tests/economy/payroll_checks.gd` (new), `tests/effect/wages_share.gd` (new).
- Data: `economy.json` `wages` gains `share_pct` and the per-merc daily wage source (Q-5);
  `data/text/en.json` `hub.wages.*`.
- The existing unpaid-wages morale fall stays; a share left unpaid counts as owed wages.
- Fixture `wages_share`: same seed and contract, share paid vs withheld: a different purse and a
  different morale a week later.
- Decided: the share is of contract pay only (Q-3), splits by level (Q-4: each merc's cut is
  weighted by his level, among those who fought the job), and the daily wage is by level (Q-5).

### C4 — Reputation and grudges (sim) — 2 days — after C0 (hunter half after C1)

- Files: new `sim/economy/standing.gd` (the company's name; grudges by faction; what dents and
  mends them), `economy.gd` (`abandon`), new `sim/world/grudge_parties.gd` (a broken deal sends
  a hunter party: a `WorldParty` that starts away from the band on the `grudge` stream and
  chases on sight like any other; it is not psychic), `world_sim.gd` (`send_hunters`),
  `tests/economy/standing_checks.gd`, `tests/effect/contract_grudge.gd` (new).
- Data: `economy.json` `standing`; `world.json` `parties.hunters`; `data/encounters.json`
  `enc_hunters` (line-ups inside C7's caps, growing with the grudge).
- The captain at the time of the broken deal gets the memory; the hunters' fight names the deal.
- Fixture `contract_grudge`: same seed, a contract completed vs abandoned: abandoned leaves a
  lower name, a hunter party on the map and a fight it raises; completed leaves neither.
- Q-7 decided: reputation per faction, so `standing.gd` keeps one name and one grudge for each
  faction. Q-13 decided: only abandoning after taking a sizeable advance sends hunters; "sizeable"
  is the data knob `standing.sizeable_advance` (new Q-16). Failing honestly dents the name only.
  Q-15: hunters grow with the grudge.

### C5 — Prisoners from the fight (sim) — 2 days — after C0 and Phase 4 P2

- Files: `sim/economy/prisoners.gd` (from C0: prisoners are the enemies the battle reports as
  surrendered, not one per won fight), `tests/economy/prisoner_checks.gd`,
  `tests/effect/hub_prisoner.gd` (extended: each of the four fates leaves a different company).
- Reads `EncounterBattle.result()` (Phase 4 P2 owns that file and its `surrender` event); this
  package does not edit it.
- Data: `economy.json` `prisoner` gains ransom coin by fighter type; the morale numbers per fate
  stay where they are.
- Each fate writes a memory on the captain and on the merc whose reaction is strongest (the
  existing `Memory.on_choice`).
- Q-12 decided: no prisoner recruiting in this pass. **C5 drops the recruit fate for now**; ransom,
  release and execute stay (three fates). The Phase 2 recruit-from-pool path is removed from the
  prisoner choice and its fixture rows; recruiting waits until the director designs it.

### C6 — Worn loot, armour price and upkeep (sim + data) — 2 days — after C0 and Phase 4 P1b

- Files: `sim/economy/loot.gd` (loot is drawn from the gear the fallen enemies carried, marked
  worn), new `sim/economy/armoury.gd` (price, daily upkeep of worn armour on the roster, buying),
  `economy.gd` (`buy`; upkeep added to the day's bill in `on_day`),
  `tests/economy/armoury_checks.gd`, `tests/effect/loot_gear.gd` (extended),
  `tests/effect/armour_upkeep.gd` (new).
- Data: `data/equipment.json` + schema gain `price`, `upkeep` and the worn form (P1b owns these
  files until it merges; this package waits); `economy.json` `loot` rows by fighter, `armoury`.
- Fixtures: `armour_upkeep`: same seed, the orc in plate vs leather: the purse after ten days
  differs by the upkeep; `loot_gear`: beating a mail-wearing enemy yields worn mail, beating an
  unarmoured one does not.
- Q-10 decided: towns buy and sell. Q-11 decided: worn = one point weaker, worth less.

### C7 — The road: 4-8 enemies, company cap 8, the lethality ledger — 2 days — after Phase 4 P2

- Files: `data/encounters.json` (line-ups of 4-8, chosen by place and day, never by the
  company's strength: vision, "encounters do not scale"), `data/scenarios.json` (enemy cells for
  up to 8), `data/balance/company.json` `roster.cap: 8`, `data/caps.json`, new
  `tools/audit/lethality.gd` (plays N seeded campaigns with `merc_play.gd` and reports named
  deaths per fight, enemies per fight and fights per campaign), `tests/run_road_tests.gd`.
- Golden: the battle golden seeds and the campaign routes move (larger line-ups); re-pin with
  the reason.
- The ledger reports; it tunes nothing. The director reads the number against "a named-merc
  death every few fights" and the lead tunes `injury.json` / `battle.json` from his answer.
- Fixture: none of its own (data). The ledger is itself checked: the same seeds give the same
  report twice.
- **Rabble (Q-1).** A separate, weak enemy kind in `data/` (ill-armed, low skill, break fast),
  with its own line-ups: proper soldiers come 4-8 a fight, rabble up to 12-16. Caps in
  `data/caps.json`: `enemies_soldiers: 8`, `enemies_rabble: 16`. The combat cap of 6 a side is
  raised for the enemy side only; the company fields up to 6 (Q-2), 2 in reserve.
- **Perf check.** A 6 v 16 fight is added to the existing perf suite (no new harness): it must
  stay inside the suite's current frame and sim-time budgets; if it does not, report the numbers
  to the lead, do not trim the cap.
- Q-14 decided: ledger held to 1 named death per 4 fights.

### C8 — The hub: board, terms, wages, prisoners, armoury (presentation) — 3 days — after C2, C3

- Files: new `presentation/world/terms_panel.gd` (the ask, the employer's reply in words, the
  step-in pick with its odds shown before the roll), `presentation/world/hub_panel.gd`,
  `presentation/world/hub_director.gd` (one hook per screen; it is at 310 lines, so new screens
  go in new files), `data/text/en.json` `hub.*`, `tests/run_hub_tests.gd` (real clicks at the
  control's screen position, 1920x1080).
- A UiKit (`ui/ui_kit.gd`) is named in the style guide and does not exist; if the look-B UI work
  has brought one by then, C8 uses it, otherwise it keeps the hub panel's current widgets.
- Evidence: a capture pair per screen (club-coloured mercs), lead's art QA first.

## Order and parallel lanes

```
now:    C0
next:   C1  C2  C3  C4(name half)            [Phase 4 P1b, P2 merging]
then:   C4(hunters, C1)  C5(P2)  C6(P1b)  C7(P2)
last:   C8 (C2+C3)   then the gate below
```

Disjoint file sets for the "next" lane (beyond the shared append-only files above):

| Package | Owns |
|---|---|
| C1 | `sim/world/jobs.gd`*, `data/jobs.json`* (+ schema*), `contract_book.gd`, job tests* |
| C2 | `sim/economy/terms.gd`*, `data/traits.json`, terms tests* |
| C3 | `sim/economy/payroll.gd`*, payroll tests* |
| C4 | `sim/economy/standing.gd`*, `sim/world/grudge_parties.gd`*, standing tests* |

(* new file.) C2 and C3 each add one line to `economy.gd`'s facade; C1 and C4 each add one to
`world_sim.gd`. Total about 20 agent-days; with four builders the sim lanes finish in about five
days, C8 and the gate after.

## Gate (Director)

One run of the loop: take a contract of each type the board offers, negotiate one (with a merc
stepping in), fight 4-8 enemies on the road, decide a surrendered prisoner's fate, loot a worn
piece, pay the wages and the share, buy or keep armour against its upkeep, and abandon one deal
and be hunted for it. Plus the structural audit: every package's fixture passes; the five
campaign routes and two new ones (a negotiated contract, an abandoned one) replay identically
in two processes; the lethality ledger's report is attached. PASS, PASS WITH NOTES or FAIL is
the director's.

## Decided (director, 2026-10-16 ~02:55; quotes word for word)

| Q | Answer | Folded into |
|---|---|---|
| Q-1 | "enemies up to 12 or even 16 if theyre rabble". Rabble = a separate weak kind (ill-armed, low skill, break fast); proper soldiers come 4-8 | C7: rabble kind, enemy caps, 6 v 16 perf check |
| Q-2 | Up to 6 deploy, 2 in reserve | C7 |
| Q-3 | Share of contract pay only | C3 |
| Q-4 | Share splits BY LEVEL | C3 |
| Q-5 | Daily wage by level | C3 |
| Q-6 | Split = advance vs on return | C2 |
| Q-7 | Reputation PER FACTION | C4, caps |
| Q-8 | A bargaining trait per merc that the director names (placeholders until then) | C2 |
| Q-9 | Job win/lose as proposed | C1 |
| Q-10 | Towns buy and sell | C6 |
| Q-11 | Worn = one point weaker, worth less | C6 |
| Q-12 | "Not until you design it" | C5: recruit fate dropped; ransom, release, execute stay |
| Q-13 | Hunters only "if you took a sizeable amount of upfront money and abandon the job" | C4; "sizeable" is Q-16 |
| Q-14 | Lethality target 1 named death per 4 fights | C7 ledger |
| Q-15 | Hunters grow with the grudge | C4 |

Note on the Vision of the interview rulings above: the line "Prisoners: ransom, recruit, release,
execute (all four)" is narrowed by Q-12 to three for this pass.

## Open questions for the director (one decision each; recommended option first)

- **Q-16 What is a "sizeable" advance (from Q-13)?** It is a data knob,
  `economy.json` `standing.sizeable_advance`, so the number is not in code. Recommended: an
  advance of at least half the contract's pay (stored as a percent). Other: a flat coin amount; any
  advance above zero. Until answered the builder uses the placeholder and C4's fixture reads it
  from data.
