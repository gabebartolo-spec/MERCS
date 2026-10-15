# world.json — world sim knobs

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `sim/world/world_sim.gd` and
`sim/world/region_gen.gd` (Phase 2 M1a). The numbers are a first thin pass; the lead tunes them.

## world
- `seed`: the default Rng seed for a new world, so a fresh start replays the same region (like `loop.seed`).

## region
- `hamlets`: how many hamlets (`site_hamlet_1`…) the region has besides the hub (`site_hub`).
- `sites`: how many wild sites (`site_wild_1`…) the region has.
- `grid_w`, `grid_h`: the integer grid the sites sit on (columns × rows); no two sites share a cell.
- `road_min_days`, `road_max_days`: each road's length in travel days, rolled in this range inclusive.

## company
- `start_supplies`: the supplies a new company sets out with.
- `supplies_per_day`: what each day on the road or at rest costs; at 0 the company is starving (no further effect yet).

## encounters
Read by `sim/world/world_sim.gd` (Phase 2 M2). Rolled on the Rng stream `encounter.<from>.<to>` (one per road), never on `world`, so the map layout never shifts. The enemy line-ups per type are authored in `data/encounters.json`.
- `chance_per_day`: percent chance that each day on a road raises an encounter (0 turns encounters off). At most one per journey; the days after it are walked without a roll.
- `ambush.weight`, `patrol.weight`: relative odds of each type when one is raised.
- `ambush.win_supplies`, `patrol.win_supplies`: supplies looted when the company wins the fight.
- `ambush.loss_supplies`, `patrol.loss_supplies`: supplies lost when the company loses or routs (floored at 0); it then falls back to the site it left.
- `patrol.toll_supplies`: supplies that buy a pass without a fight (offered only while the company has that many).
