# Cast fix round 3: hand repaint (2026-10-16)

The orc and Vampyr sheets, their tokens and normal strips, and the average_m edits for PR #118 round 3 were
painted with these scripts: every part is a hand-placed polygon or line on the frame's pixel grid, shaded in
palette ramps only, one key light from camera-left (06 section 3); heads are kept from the round-2 render.
They are the record of how the shipped PNGs were made, not a pipeline step: `build_sprites.py` would
overwrite them.

Rerun: set `CAST_R3_WORK` to a folder holding `orig/` (the round-2 PNGs from commit 7f972fd) and
`orc_matid.npy` (the round-2 orc matid pass reduced to 1x, `build_sprites.matid_labels`), then from that folder
`python <here>/orc_paint.py S SE E NE N NW W SW`, `vamp_paint.py` (same facings), `orc_token.py`,
`vamp_token.py`, `avg_paint.py`; outputs land in the work folder. `remap_golden.py <dir of old goldens>`
moves grass off skin_orc (director 2026-10-16: grey-olive orc skin).
