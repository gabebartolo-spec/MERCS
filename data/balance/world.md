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
