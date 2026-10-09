# stage.json — grey-box capture stage knobs

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `presentation/world/street_stage.gd`
and `tools/capture/capture_stage.gd`. Spec: `docs/specs/phase1_visual_proof.md` §2.

## street
- `width_m`, `depth_m`: the street footprint along X and Z, centred on the origin (40 × 20 m).
- `cell_size_m`: GridMap cell edge; every cell position below is in these units.
- `ground_thickness_m`: the ground tile box height; its top sits at y = 0.
- `house_size_m`: one placeholder house box, width × height × depth.
- `house_cells_xz`: the six house cells as x, z pairs: four along the far side of the street, two at the near corners outside the camera's view at the default rail (the near centre is under the camera).
- `well_size_m`, `well_cell`: the well box and its cell; the walk path passes it.
- `cart_size_m`, `cart_cell`: the cart box and its cell.
- `door_size_m`, `door_cell`, `door_offset_z_m`: the interior door marker, a thin box on the street face of the far house left of the alley; the offset slides it from its cell centre (cells are centred at +0.5) to sit just proud of that face; positive is toward the camera.

## shades
- `ground`, `house`, `well`, `cart`, `door`: grey level (0–1) of each placeholder box's material.
- `interior_wall`: grey of the interior room's wall boxes.
- `sky`: flat background grey.

## light
- `elevation_degrees`: the key light's angle above the horizon (45°).
- `azimuth_degrees`: the key light's yaw; negative is from camera-left (06_STYLE_ART.md §3).
- `color_rgb`, `energy`: warm white key colour and strength.
- `ambient_grey`, `ambient_energy`: the flat ambient sky colour and strength.

## dusk
The slice's T key steps day → dusk → night (`StageLighting`). Low warm sun from camera-left, rosy ambient.
- `light`: the key and ambient as in `rain_night.light` (`ambient_rgb` a colour).
- `sky_rgb`, `sprite_tint_rgb`: dusk background and the unshaded sprite's tint. Torches burn at dusk and night.

## rain_night
Night for `StageLighting` too; rain is a separate toggle there.
Used when the stage's `lighting` export is RAIN_NIGHT (sample set 2, spec §4); DAY uses `light` and `shades.sky`.
- `light`: the moonlight key and ambient, as in `light` above, but `ambient_rgb` is a colour (cool blue) instead of a grey.
- `sky_rgb`: the flat night background colour.
- `sprite_tint_rgb`: the sprite is unshaded, so night darkens it by this modulate colour instead of by light; without it the merc glows like day.
- `torch`: one warm `OmniLight3D` by the well: `position_m`, `color_rgb`, `energy`, `range_m`. Geometry only; the unshaded sprite does not pick it up.
- `rain`: falling streaks (`GPUParticles3D`): `amount`, the emission box `centre_m` and `area_m` (full size, metres), `fall_m_s`, `lifetime_s`, `streak_m` (quad width × height), `color_rgb`, and the fixed particle `seed` so captures repeat.

## camera
- `fov_degrees`: perspective field of view (35°).
- (no distance knob) the rail's distance from the look-at point is derived by `StreetStage.rail_distance_m()` so one sprite texel covers one logical pixel there: `merc_height_m × cos(pitch) / sprite_height_px × logical_height_px / (2 × tan(fov / 2))`, about 17.3 m at 35° and 48 px. It follows the pitch and height under test, matching `tools/pipeline/camera_rig.json`.
- `look_at_height_m`: the camera looks at a point this high above the ground (1 m).
- `near_m`, `far_m`: clip planes.

## sprite
- `merc_height_m`: the standing body height (1.78 m, `reference_height_m` in the camera rig). One texel (pixel_size) is `merc_height_m × cos(pitch) / sprite_height_px` of the image plane, and the sprite is stretched by `1 / cos(pitch)` on Y so the figure stands this tall in the world and foreshortens back to `sprite_height_px` on screen.
- `texture_width_px`: width of the generated capsule texture; its height is the exported sprite height.
- `fill_grey`, `outline_grey`: the capsule's fill and 1-px outline grey levels.
- `walk_speed_m_s`: how fast the placeholder walks its loop.
- `path_xz`: the walk loop as x, z pairs in metres; the loop closes back to the first point. Laid out for the director's 55° / 56 px camera (2026-10-08), which sees about x −7…7 and z −6…3 of the street: the merc passes behind the well (z −0.5), round its right side and back in front of it (z 2.5).

## pixel
- `logical_width_px`, `logical_height_px`: the whole-screen mode SubViewport size (640 × 360).
- `integer_scale`: the whole-screen scale to the 1920 × 1080 window (3).

## capture
- `settle_frames`: frames rendered before a still is saved.
- `clip_seconds`, `clip_fps`: the image-sequence length and rate.
- `crop_width_px`, `crop_height_px`, `crop_scale`: the window-pixel region centred on the standing figure that is also saved, and its upscale. 320 × 180 (the spec's 160 × 90 predates the derived rail and cut a 48 px figure, 144 window px tall, in half).

## interior
The one grey-box interior of the art direction slice, built far off the street (x 100) so the street camera never shows it.
- `origin_cell`: its near-left floor cell; `size_cells`: x × z floor cells including the walls round the edge.
- `wall_height_m`: wall box height.
- `exit_cell`: the gap in the near wall; stepping on it returns to the street in front of the door. `entry_cell`: where the door puts a figure inside.
