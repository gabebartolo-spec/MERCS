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
- `sky`: flat background grey.

## light
- `elevation_degrees`: the key light's angle above the horizon (45°).
- `azimuth_degrees`: the key light's yaw; negative is from camera-left (06_STYLE_ART.md §3).
- `color_rgb`, `energy`: warm white key colour and strength.
- `ambient_grey`, `ambient_energy`: the flat ambient sky colour and strength.

## camera
- `fov_degrees`: perspective field of view (35°).
- `distance_m`: the rail's distance from the look-at point on the street centre line (12 m).
- `look_at_height_m`: the camera looks at a point this high above the ground (1 m).
- `near_m`, `far_m`: clip planes.

## sprite
- `merc_height_m`: the body height the sprite's pixel height represents (1.78 m; pixel_size = merc_height_m / sprite_height_px).
- `texture_width_px`: width of the generated capsule texture; its height is the exported sprite height.
- `fill_grey`, `outline_grey`: the capsule's fill and 1-px outline grey levels.
- `walk_speed_m_s`: how fast the placeholder walks its loop.
- `path_xz`: the walk loop as x, z pairs in metres; the loop closes back to the first point.

## pixel
- `logical_width_px`, `logical_height_px`: the whole-screen mode SubViewport size (640 × 360).
- `integer_scale`: the whole-screen scale to the 1920 × 1080 window (3).

## capture
- `settle_frames`: frames rendered before a still is saved.
- `clip_seconds`, `clip_fps`: the image-sequence length and rate.
- `crop_width_px`, `crop_height_px`, `crop_scale`: the region centred on the sprite that is also saved, and its upscale.
