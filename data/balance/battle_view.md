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
Counted in applied actions since the hit. Blood goes fresh red, then dark red (the blood ramp's two reds; its brown is not used). Splats never vanish before the fight ends.
- `wet_after_actions`, `dry_after_actions`: where it turns dark red and where it settles (same colours; the oldest tone).

## flash
- `hit_s`: seconds a wounded fighter shows its bone-white flash frame (placeholder until the Art agent's hit frames).
- `death_s`: the same for the fighter who falls; then the sprite goes and the body stays.

## pool
The death pool under a fallen fighter's torso (same two blood reds, drying with the splats).
- `damage`: the blow size the pool's blot is grown from (a big one).
- `seed`: added to the fall's order to seed the pool's shape.

## body
- `cell_width_m`: the width of a cell's footprint; a lying body lies along this cell's diagonal at full figure size (never shrunk).
- `feet_half_m`: half the ground a standing fighter's feet cover; a body never lies over it.
- `probe_m`: the step used to measure how the camera foreshortens the ground at a mark, so its pixels match the figures'.

## lift
- `pool_m`: the death pool, lowest (under the body).
- `splat_m`, `body_m`: metres above the ground the splats and bodies lie, both above the side ring's top (0.022 m) so the ring does not hide them; the body is lower so blood lies over it.

## spray (P6c, director 2026-10-16: blood flies along the blow and stains where it lands; lead QC round 1)
Read by `presentation/battle/battle_spray.gd` and `battle_drop_aim.gd`. Drops are flat squares that face the camera, in the blood ramp's two reds, at the figures' pixel size. They leave the hit point at torso height, burst out past the silhouette along the blow as it shows on screen and up, then fall onto the splat: each lands on one of its splat's own pixels (from the splat's side down the blow), and the splat shows when the first lands. Over the struck figure a drop is drawn just behind it, so it never paints over the body. Every drop's variation is seeded from its hit (round, hit number, attacker, target); no clock, no sim stream.
- `drops_base`, `drops_per_damage`, `drops_max`: drops a hit throws = base + damage x per-damage, capped (10 to 16).
- `drop_px_max`: a drop is a square of 1 to this many logical pixels a side (mixed sizes).
- `torso_share`: the hit point's height, as a share of the struck figure's drawn height above its feet.
- `push_m`: how far (metres in the figure's picture plane, at the burst's peak) a drop flies out along the blow (0.9: far enough that drops thrown sideways are past the silhouette by their 3rd frame, checked in the impact suite).
- `arc_m`: how far (same plane) it rises at the burst's peak before it falls.
- `cone_deg`: each drop's burst is turned by a seeded angle up to this many degrees either side of the blow on screen, so the drops spray rather than fly in a line.
- `reach_min`: each drop flies a seeded share of push_m and arc_m between this and 1, so they spread.
- `behind_m`: how far behind the struck figure's plane a drop is drawn while it is over the figure's picture.
- `flight_s`: visual seconds from leaving the hit point to landing (the burst peaks a quarter of the way through, so a drop is clear of the silhouette within about 3 frames).
- `delay_spread_s`: each drop leaves up to this many visual seconds after the blow (seeded).

## hit_stop (P6c)
Read by `presentation/battle/battle_impact.gd`. A big hit holds the battle picture (flash, flying blood, the pause before the enemy's next turn) for a few rendered frames. It runs on the battle view's own visual clock: the sim is never paused or slowed and `Engine.time_scale` is never touched, so the battle log is the same with it on or off. The player's toggle is the Settings autoload's `hit_stop` (default on); both must be on.
- `on`: hit-stop at all.
- `min_damage`: a hit of at least this damage holds (0: unused).
- `max_hp_share`: a hit of at least this share of the target's full health holds (0: unused).
- `frames`: rendered frames the picture holds (frames, not seconds, so it is the same on every machine). Director 2026-10-16 03:17: "Subtle, a few frames" (3 to 5), a catch felt more than seen; no screen shake.
