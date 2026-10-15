# Cast fix round 4 (2026-10-16)

Record of how the PR #118 round-4 PNGs were made: hand-placed polygons and lines on each frame's pixel grid,
palette ramps only, one key from camera-left (06 section 3). Not a pipeline step: `build_sprites.py` would
overwrite them. Reruns are byte-identical.

- Orc (`orc_paint.py`): director 2026-10-16, "bulk and green-grey skin". The round-2 alpha (7f972fd) is the
  outer mask of every facing: one barrel volume fills it below the neck, then legs, fauld, belt, arms,
  pauldrons and boots are drawn on top and clipped to it. The head is kept from the render and laid back on
  top; its lit top takes skin step 4; tusks in bone 3, 2 px wide and 3 px tall. Plates take a 1-px iron 4
  edge where the key hits them. skin_orc is the critic's green-grey ramp with steps 2-3 lifted toward grey-blue
  (lead rule: CIEDE2000 >= 12 and dE76 >= 15 against every grass colour, including verdure_mid_0); the sheet
  uses steps 2-4 only (`de_table.py` prints the table).
- Vampyr (`vamp_paint.py`): slim sloped spaulders, a narrow waist over two small tassets, collar closed in
  iron 0 by the face, a cape whose folds fan from the blades over an uneven hem; S/SE/NE/N and mirrors are
  clipped to the round-2 alpha grown by 1 px.
- Both sheets: an orphan-pixel pass (`px.despeckle_sheet`; outline, inner lines and tusks kept); normal strips
  from `normals.py` (alpha equals colour).
- Tokens (`orc_token.py`, `vamp_token.py`): the finished SE frame at half scale (2x2 vote), outline redone.
- average_m (`avg_paint.py`): arm line down the forearm and a 1-px gap at the hand on SE/SW (the normal
  strip's alpha follows), E arm with one line and the thigh in two planes.
- Goldens (`remap_golden.py`, run from the repo root): orc figures' skin to the new ramp by index; overworld
  lit grass flattened from a verdure_1/2 checker to verdure_2 (a stop-gap until the B7 tile re-render).
- `rehash.py` refreshes the sheet manifests' pixel and palette hashes.

Rerun: set `CAST_R3_WORK` to a folder holding `orig/` (the round-2 PNGs from commit 7f972fd) and `orc_matid.npy` (see cast_r3/README.md), then from that
folder `python <here>/orc_paint.py S SE E NE N NW W SW`, `vamp_paint.py` (same facings), `orc_token.py`,
`vamp_token.py`, `avg_paint.py`; outputs land in the work folder.
