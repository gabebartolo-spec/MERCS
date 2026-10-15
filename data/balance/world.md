# world.json — world sim knobs

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/world/world_sim.gd`,
`sim/world/region_gen.gd`, `sim/world/tile_gen.gd` and `sim/world/party_moves.gd` (Phase 2). The numbers are a first thin pass; the lead tunes them.

## world
- `seed`: the default Rng seed for a new world, so a fresh start replays the same region (like `loop.seed`).

## region
- `hamlets`: how many hamlets (`site_hamlet_1`…) the region has besides the hub (`site_hub`).
- `sites`: how many wild sites (`site_wild_1`…) the region has.
- `grid_w`, `grid_h`: the integer grid the sites sit on (columns × rows); no two sites share a cell.
- `road_min_days`, `road_max_days`: rolled for each road in this range (M1's travel days). Since the band walks, a road's real length is its tiles; the roll stays so the same seed keeps the same layout.

## tiles
The map the band walks (`sim/world/tile_gen.gd`, on the Rng stream `world` after the layout).
- `cell_tiles`: tiles per side of one layout cell; the map is `grid_w` x `grid_h` cells of this many tiles.
- `site_offset_tiles`: where a site's entrance sits inside its cell, from the cell's top-left corner (both axes).
- `forests`, `hills`, `lakes`: how many round patches of forest, hills and water are laid on the plain.
- `blob_min_radius`, `blob_max_radius`: each patch's radius in tiles, rolled in this range inclusive.

## terrain_cost
- `road`, `plain`, `forest`, `hill`: the units one step onto that terrain costs the band (and a party). Water and town walls cannot be walked.

## march
- `units_per_day`: units of walking that make one day (a day's tick and its supplies); a rest is one day.

## company
- `start_supplies`: the supplies a new company sets out with.
- `supplies_per_day`: what each day walking or at rest costs; at 0 the company is starving (no further effect yet).

## parties
The parties walking the map (`sim/world/party_moves.gd`, on the Rng stream `parties`). A type's block is named for the encounter it raises (`data/encounters.json` "type").
- `min_spawn_tiles`: a party starts at least this many steps from the hub's entrance.
- `spawn_tries`: random tiles tried per party before it is left out (on water or too close).
- `budget_cap`: the most walking units a party can save up between moves.
- `<type>.count`: how many parties of the type walk the map.
- `<type>.sight_tiles`: how many steps away it sees the band (a diagonal counts one); within it the party walks toward the band, beyond it it wanders.
- `<type>.speed_pct`: its walking units per 100 of the band's (100: as fast as the band on the same ground).
- `<type>.wander_tiles`: how far from its home tile it wanders while it does not see the band.
- `<type>.return_days`: days a party is off the map after the band fought it or paid it; then it is back at its home tile.
- Job parties (Phase 5 C1, `data/jobs.json` "party"): `camp` (clear bandits), `charge` (escort: the man the company walks with), `raiders` (hold: the fight that comes), `quarry` (hunt). They have no `count`: none walks the map until a contract's job puts it there (`sim/world/jobs.gd`), so the spawn draws nothing for them. Placeholder numbers.
- Hunters (Phase 5 C4, `sim/world/grudge_parties.gd`): `hunters` is the party a broken deal sends (one per deal abandoned after an advance of half the pay or more). No `count`. `hunters.start_min_tiles` / `start_max_tiles`: how far from the band it is put (rolled `place_tries` times on the Rng stream `grudge`, then the first free tile in a scan); it then wanders and chases on sight like any party. `hunters.return_days` only needs to be above 0: a fought hunter party leaves the map for good (lead call, 2026-10-16). Its line-up is `enc_hunters`' n-th, n the grudge's growth when it was sent (the last line-up past the end). Placeholder numbers.

## encounters
Read by `sim/world/world_sim.gd`. A party within a step of the band raises its type's encounter; its line-up is rolled on the Rng stream `encounter`, never on `world`, so the map layout never shifts. The enemy line-ups per type are authored in `data/encounters.json`.
- `ambush.win_supplies`, `patrol.win_supplies`: supplies looted when the company wins the fight.
- `ambush.loss_supplies`, `patrol.loss_supplies`: supplies lost when the company loses or routs (floored at 0); it then falls back to the last site it stood at.
- `patrol.toll_supplies`: supplies that buy a pass without a fight (offered only while the company has that many).

## jobs
Phase 5 C1, read by `sim/world/jobs.gd` (placement on the Rng stream `jobs`). Placeholder numbers until the director plays it.
- `near_min_tiles`, `near_max_tiles`: a camp or a quarry is put this many steps (at least, at most) from its contract's site entrance.
- `place_tries`: random tiles tried before a job's party is left off the map.
- `hold_days`: days in a row the company must stand at the site of a hold before the fight comes.
- `raid_min_tiles`, `raid_max_tiles`: how many steps from the site the raiders of a hold appear.
