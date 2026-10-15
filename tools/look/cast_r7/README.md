# Cast fix round 7 (2026-10-16)

Record of how the PR #118 round-7 PNGs were made (copied from `cast_r6/`, then changed). Not a pipeline step:
`build_sprites.py` would overwrite them. Reruns are byte-identical (checked: sheets, normals, tokens and the
three goldens rebuild pixel for pixel).

Round 7 (critic r6), nothing else changed:
- Orc E/W ear (`heads.py`, E grid): the closed soot ring inside the skull is gone; the ear is one open step-1
  crease on its front edge (sheet E x88, W x87, y40-42) and no soot inside the head outline.
- Vampyr holes (`vamp_paint.fill_holes`): every transparent group not connected to the frame edge becomes soot 0
  (10 px: E 95-96,139; NE 91-92,52 and 97-98,145; NW 77-78,145; W 79-80,139); `patch_hole_normals` gives each the
  normal of its soot neighbour, alpha 255. Enclosed-hole check: 0 in every facing, both tokens unchanged.
- Vampyr E/W face (`vamp_paint.JAW_E`): a 2x1 skin_pale_1 brow notch (y45) over a 2x1 skin_pale_0 eye socket
  (y46) at x91-92, 3 px behind the profile edge; W gets it mirrored (x83-84).
- Golden (`remap_golden.py`): every old (40,48,22) pixel outside the orc goes to verdure_0, no neighbour rule, so
  main's verdure_0/verdure_1 forest-floor checker survives (blocks >= 25% old shade: luma main 50.5, r6 55.3,
  r7 47.8). 8x8 split blocks for (40,48,22): r6 441, r7 0.

Round 6 notes follow (unchanged).

Record of how the PR #118 round-6 PNGs were made (copied from `cast_r5/`, then changed). Not a pipeline step:
`build_sprites.py` would overwrite them. Reruns are byte-identical.

- Palette (lead rule 2026-10-16, relaxed): skin_orc is `#2e3428 #637251 #94a179 #afb88b #c1cb9c`. Step 2, the
  face mass, is L64 C22.7 hue 121: CIEDE2000 32.5 from verdure_mid_0 and 28.7 from verdure_2 (rule >= 15), 10.4
  from the nearest tuft verdure_4 (rule >= 10). A search over L48-66, C >= 20, hue 110-125 found no darker step
  that clears the tufts (the darkest is L62). Steps 3-4 pass too; steps 0-1 fail and appear only inside the face,
  never 8-adjacent to the silhouette (`orc_paint.guard_dark`). `de_table.py <sheets>` prints the table.
- Orc heads (`heads.py`): skulls, not boxes. Rounded crown (7/11/15 px over its first three rows), two brow
  arches that push the outline out 1 px (the lit arch step 4, the other step 3, a step-2 notch), 2x3 pointed
  ears angled up, eyes 4-5 px apart in step-1 sockets, a 3x2 nose with two nostrils, cheekbone and jaw-corner
  bumps, a straight 5-px mouth with the tusks crossing it (tip above, base below), a step-1 neck under the jaw
  (no full-width soot line onto the gorget). E: the top-back corner cut in a curve, the occiput bulging, the
  nape stepping in, the ear at the side, the jaw 3 px ahead of the brow. Each letter is a plane; its tone comes
  from the key light, so the mirrored W/SW/NW are lit from camera-left too. Step 2 is the face mass; step 4 only
  as a 1-px key edge and the lit brow arch (61 px over the eight heads).
- Orc token (`orc_token.py`): the head redrawn at half scale with the same features; the tusks cross a straight
  mouth (mouth line past each tusk, no upturned corners), a step-1 shadow over 2x1 eyes.
- Vampyr (`vamp_paint.py`): S/SE/SW breastplate tapered from 23 px (row 61) to 17 px (row 86), shaded in planes
  (lit upper chest iron 2, far upper chest iron 1, a curved iron-2 plackart line with iron 0 under it on the far
  side, iron 0 only as a 2-px core shadow on the far edge: 15% of the cuirass), three fauld lames (iron-2 rolled
  edge, iron 0 under it) sagging 1 px over the belly, the last with a V edge. The lining between arm and body
  is cape folds (shadow red with a lit fold widening to the hem), drawn before the legs. E/W: the skin_pale_0
  blob under the jaw replaced by a 1-px skin_pale_1 jaw line. N: the enclosed slit between arm and cape filled.
- Normal strips: `normals.py` (both silhouettes changed; alpha equals colour; the new plate pixels carry their
  plane normals).
- Goldens (`remap_golden.py`, from the repo root): the overworld rebuilt from main's approved golden; every old
  lit-grass pixel (66,74,38) goes to verdure_mid_0 with no neighbour rule (round 5's rule made a "#" lattice);
  the shade partner (40,48,22) keeps its rule (verdure_0 only in deep shade). Orc figures' skin round 5 -> round 6
  by index.
- `rehash.py` refreshes the sheet manifests; then `python tools/look/write_provenance.py`.

Rerun: set `CAST_R3_WORK` to a folder holding `orig/` (the round-2 PNGs from commit 7f972fd) and
`orc_matid.npy` (see cast_r3/README.md), then from that folder `python <here>/orc_paint.py S SE E NE N NW W SW`,
`vamp_paint.py` (same facings), `orc_token.py`, `vamp_token.py`; outputs land in the work folder.
