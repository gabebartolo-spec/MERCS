# slice.json — art direction slice knobs

One line per knob (docs/05_STYLE_CODE.md "Data"). Read by `presentation/world/slice_game.gd`.
Spec: `docs/specs/art_direction_slice.md`. Street geometry, lights and weather stay in `stage.json`.

## pixel
The logical screen and the merc's height are the stage's (`stage.json` "pixel", 960 × 540, 84 px); the slice only picks the largest whole scale that fits the window (×2 at 1080p, ×4 at 4K).

## player
- `start_cell_xz`: the street cell the merc starts on.
- `walk_speed_m_s`: the merc's walking speed, cell to cell.

## crowd
- `walk_speed_m_s`: the other mercs' walking speed.
- `route_1` … `route_5`: each crowd merc's waypoints as x, z cell pairs, walked in order and looped; a single pair is a merc standing still. All on free street cells.

## hud
- `frame_time_smoothing`: how much of each new frame's time the F3 readout takes in (0–1; smaller is steadier).
