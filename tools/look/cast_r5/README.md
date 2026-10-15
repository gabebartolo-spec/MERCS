# Cast fix round 5 (2026-10-16)

Record of how the PR #118 round-5 PNGs were made (copied from `cast_r4/`, then changed). Not a pipeline step:
`build_sprites.py` would overwrite them. Reruns are byte-identical.

- Palette: verdure_mid_0 and heather taken from commit 99a1de4 (tiles-b6, palette files only); skin_orc is
  `#2e3428 #485240 #7e8a73 #97a58b #b9c9ab`, steps 2-4 on one moss hue line (128-130). Steps 2-4 pass the lead
  rule against every grass colour (CIEDE2000 >= 12, dE76 >= 15; step 2 is 24.3 from verdure_mid_0, 20.9 from
  verdure_2); steps 0-1 fail it and appear only inside the face, never 8-adjacent to the silhouette
  (`orc_paint.guard_dark`). `de_table.py` prints the table.
- Orc (`orc_paint.py`, `heads.py`): the heads are hand-placed grids of planes (broad jaw wider than the skull,
  brow shelf in step 4 over a 1-px step-1 line, 2x1 soot eyes, nose, mouth line, bone tusks from the lower jaw
  past the lip); each plane's tone comes from the key light, so the mirrored W/SW/NW are lit from camera-left
  too. The heads are exempt from the round-2 alpha. Plate one iron step darker (body iron 2, lit iron 3, shadow
  iron 1, iron 4 only as the key edge).
- Vampyr (`vamp_paint.py`): armour one step darker, a medial ridge on the S/SE/SW cuirass between a lit and a
  shadow plane, the cape lining (cloth_faded 0) 3-5 px wide down both sides of the body from shoulder to hem,
  N cape folds that start at the blades, widen to the hem and stop at different heights.
- Tokens: SE frame at half scale; the orc head is then painted by hand (`orc_token.TOKEN_HEAD`).
- Normal strips: `normals.py` (both silhouettes changed; alpha equals colour).
- Goldens (`remap_golden.py`, from the repo root): the overworld rebuilt from main's approved golden, its lit
  grass on verdure_mid_0 and the old shade partner on verdure_1 (verdure_0 only in deep shade), so no dark rims;
  the orc figures' skin on the round-5 ramp by index.
- `rehash.py` refreshes the sheet manifests; then `python tools/look/write_provenance.py`.

Rerun: set `CAST_R3_WORK` to a folder holding `orig/` (the round-2 PNGs from commit 7f972fd) and
`orc_matid.npy` (see cast_r3/README.md), then from that folder `python <here>/orc_paint.py S SE E NE N NW W SW`,
`vamp_paint.py` (same facings), `orc_token.py`, `vamp_token.py`; outputs land in the work folder.
