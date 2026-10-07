# Phase 1 spec — visual and factory proof

Owner: Art Factory (samples, pipeline) and Dev Lead (street scene, fixtures). Gate signer: the
director. This spec turns `08_ROADMAP.md` Phase 1 into experiments with fixed inputs and a fixed
capture layout, so every director question arrives as the same kind of labelled image.

## 1. Order of work

1. **Rig freeze** (Art): MPFB `average` body at 1.78 m, Mixamo-named skeleton, sockets, rest-pose
   hash into `tools/pipeline/rig_contract.json`. Nothing else starts until this is committed.
2. **Grey-box street** (Dev): a 40 × 20 m street in a `GridMap` with placeholder cubes for houses,
   a well, a cart, one interior door, a perspective camera on a rail, and one `Sprite3D` placeholder
   (a 48 px capsule) walking a loop. This is the capture stage for every sample below.
3. **Sample set 1, camera pitch and height** (Art renders, Dev captures): see §3.
4. **Sample set 2, pixel mode** (Dev): see §4.
5. **Sample set 3, palette size and fonts** (Art): see §5.
6. Director answers Q4–Q9 from the three sheets.
7. **Full factory** (Art): three equipment combinations, giant, two overlays, six clips, eight
   facings, validators, `rebuild_all.sh`.
8. **Real street** (Dev + Art): modular kit replaces grey boxes, rain and night variants, torchlight,
   depth sorting and occlusion proven by fixture.
9. Golden images committed; gate.

## 2. The capture stage (fixed for all samples)

- Resolution 1920 × 1080, integer scale 3 (so the logical canvas is 640 × 360 in whole-screen
  pixel mode). Captures are saved at 1920 × 1080 and also as a 2× crop of a 160 × 90 region
  centred on the walking sprite.
- Camera: perspective, FOV 35°, rail 12 m from the street centre line, pitch per sample, looking
  at a point 1 m above ground.
- Lighting: one `DirectionalLight3D` at 45° elevation, warm white, shadows on for geometry, off
  for sprites; ambient from a flat grey sky.
- Sprite: `Sprite3D`, `billboard = BILLBOARD_FIXED_Y`, `texture_filter = NEAREST`,
  `alpha_cut = ALPHA_CUT_DISCARD`, `pixel_size` chosen so 48 texture pixels = 1.78 m
  (pixel_size = 1.78 / 48 = 0.0371), `shaded = false`, `double_sided = false`. Position snapped
  to the pixel grid each frame in whole-screen mode.
- Three-second clip: the sprite walks left to right past the well while the camera is still.

## 3. Sample set 1 — pitch and height (nine captures + three clips)

Grid of pitch {30°, 35°, 40°} × height {40, 48, 56 px}. Each cell is labelled in the image
top-left in 48 px text: `A1 30°/40px` … `C3 40°/56px`. The sprite is a placeholder render of the
frozen rig in the Mixamo walk, body only, from the matching pitch, so feet perspective is honest.

What the director is judging: does the street feel like a place you walk through, and does the
person read as a person at a glance. Costs to state under the sheet: lower pitch shows more wall
and less ground (battle grid harder to read); larger height shows more detail and fewer fighters
per screen.

Recommendation printed on the sheet: B2 (35°, 48 px).

## 4. Sample set 2 — pixel mode (two captures + two clips, same pitch and height as recommended)

- **Mode A, whole screen.** The 3D scene renders into a `SubViewport` at 640 × 360 with
  `texture_filter = NEAREST`, scaled 3× to the window. Sprites snap to the viewport pixel grid.
  Everything, including fog and torchlight, is crunchy and unified.
- **Mode B, crisp world.** The 3D scene renders at 1920 × 1080; sprites are drawn with nearest
  filtering at exact 3× and their world position is snapped so texels land on screen pixels.
  Buildings and shadows are smooth; people are pixel art.

Capture both in day and in rain-night. Clip both walking past the well, because shimmer only
shows in motion. Measure and print on the sheet: frame time at 1920 × 1080 for each mode.

Recommendation printed on the sheet: A, for seam-hiding and cheaper consistency. The Dev Lead
documents the chosen mode's exact node setup in `01_ENGINE_DECISION.md` after the answer.

## 5. Sample set 3 — palette size and fonts

- Palette: the same rendered sprite and a 256 × 256 crop of a painted wall texture quantised to
  48, 56 and 64 colours, side by side, labelled, with the ramp swatches below each.
- Fonts: six candidate OFL faces (three pixel UI faces, three serifs) rendered as the inspect
  screen header block: a name, an epithet, a background sentence and three trait words, at game
  scale and 2×. Labelled A–F. Licence file path printed under each.

Recommendations printed: 56 colours; fonts per the Art agent's judgement after rendering.

## 6. Factory acceptance (after the answers)

| Check | Pass condition |
|-------|----------------|
| Alignment | every layer of every clip and facing shares frame count and pivot within 0 px |
| Palette | 100 % of opaque pixels on the master palette; heraldry only on permitted layers |
| Clipping | no frame touches its cell edge |
| Overlay | eye-patch and missing-hand overlays align on all 8 facings across idle and walk |
| Rebuild | `rebuild_all.sh` from a clean checkout plus the vault completes in under 30 minutes and produces byte-identical PNGs on a second run |
| Engine | `run_assets_tests.gd` loads every manifest, plays every clip, asserts `CharacterSheets.gd` matches |
| Street | a merc walking behind the well is occluded; two mercs crossing sort correctly; rain and night variants capture without a changed sprite |

## 7. What is not in Phase 1

No gameplay, no UI beyond the font sample, no portraits (Phase 2), no second body build beyond
`giant`, no facings beyond eight, no clips beyond the six, no diffusion anywhere.
