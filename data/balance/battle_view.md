# battle_view.json - hits, blood and bodies on the battle field

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `presentation/battle/battle_marks.gd` and `battle_fx.gd`. Director ruling Q-G (2026-10-15): "At every hit" - a splat on every wound, drying over the fight; bodies stay until it ends. Presentation only: it reads the sim's `hit` and `down` events and decides nothing. Colours are palette references in the code (core `blood` ramp, `bone`, `soot`), not here.

## splat
- `half_px`: a splat's picture is (2 x half_px + 1) logical pixels square.
- `base_area_px`, `area_per_damage_px`, `max_area_px`: the main blot's area in pixels = base + damage x per-damage, capped.
- `satellite_from_damage`: from this damage a hit also throws one satellite clump; from twice it, two.
- `satellite_area_px`, `satellite_min_px`: a satellite clump's area, and the fewest pixels it may keep (a smaller one is dropped: no single-pixel speckle).
- `satellite_ring_px`: how far from the centre a satellite lands.
- `jitter_px`: how far (logical pixels, each way across) a splat sits from its cell's centre; the cell is about 65 pixels wide.
- `jitter_front_px`: how far toward the camera it falls (so it shows past the feet, not under them).
- `seed_mul`: the splat's shape seed = hit number x this + damage; no clock, no roll on the sim's streams.

## age
Counted in applied actions since the hit. Blood goes fresh red, then dark red, then dried brown. Splats never vanish before the fight ends.
- `wet_after_actions`, `dry_after_actions`: where it turns dark and where it turns brown.

## flash
- `hit_s`: seconds a wounded fighter shows its bone-white flash frame (placeholder until the Art agent's hit frames).
- `death_s`: the same for the fighter who falls; then the sprite goes and the body stays.

## lift
- `splat_m`, `body_m`: metres above the ground the splats and bodies lie, both above the side ring's top (0.022 m) so the ring does not hide them; the body is lower so blood lies over it.
