# 06 — Art style bible and consistency contracts

The look: detailed pixel-art humans inside perspective low-poly 3D environments. Pokémon Black/White
in camera and composition, feudal political fantasy in palette and tone. This file fixes the
numbers that a machine can check and the references a human judges against. Every value marked
**[D]** is a director decision still open (see `11_OPEN_QUESTIONS.md`); the Art agent's first job
is to produce the labelled options for those.

## 1. The three contracts

Consistency comes from contracts, not from prompts.

| Contract | What it fixes | Validator |
|----------|---------------|-----------|
| **Render contract** | one base body, one skeleton, one camera rig, one light rig, one post-process | `validate_sprite.py` |
| **Palette contract** | one master palette of named ramps; every shipped pixel is on it | `validate_palette.py` |
| **Portrait contract** | one framing, one size, one style LoRA, one seed policy, cleared models only | `validate_portrait.py` |

## 2. Palette contract

Master palette `assets/palette/mercs_master.gpl` (GIMP format, also exported JSON). Target 48–64
colours in named ramps of 5–6 steps each **[D: final count after samples]**:

| Ramp | Purpose |
|------|---------|
| `soil` wet earth, mud | ground, leather lowlights |
| `slate` cold greys | stone, steel shadow, sky |
| `soot` blacks and near-blacks | outlines, iron, charred wood |
| `iron` desaturated steel | mail, plate, blades |
| `timber` weathered browns | wood, leather |
| `bone` warm off-whites | linen, skin highlights, bone |
| `cloth_faded` dull reds, blues, greens | commoner clothing |
| `verdure_cold` blue-greens | vegetation |
| `skin_1 … skin_6` | six skin ramps; sprites are rendered in one neutral skin ramp and the shader maps it to the merc's ramp by palette index (never free colour) |
| `heraldry_*` | saturated faction colours: crimson/gold, blue/white, black/yellow (3 factions in the slice) |
| `blood` | two reds and a brown for dried |
| `fire` | torch and ember accents |

Rules: heraldry ramps are the only high-saturation colours and appear only on faction cloth,
shields and banners. World and bodies stay in the muted ramps. Blood is a shipped overlay colour,
not part of base sprites. The UI uses a 10-colour subset defined in `UiKit.gd` that is drawn from
the same file.

## 3. Render contract (characters)

| Parameter | Value | Note |
|-----------|-------|------|
| Base body | MakeHuman/MPFB CC0 mesh, three builds: `slight`, `average`, `giant` **[D]** | one rig, three proportions |
| Skeleton | Mixamo-compatible naming (so the free Mixamo library retargets cleanly), 65 bones max | frozen in Phase 1; never regenerated |
| Sockets | `hand_r`, `hand_l`, `back`, `hip_l`, `head`, `chest_badge` | every equipment mesh attaches here |
| Camera | orthographic, pitch **35°** **[D: 30/35/40 samples]**, 8 facings at 45° steps, facing 0 = toward camera | same pitch as the game camera |
| Character height | **48 px** at 1× for `average` (slight 44, giant 56) **[D: 40/48/56 samples]** | world units: 1 m ≈ 27 px (48 px / 1.78 m); the figure follows the chosen height |
| Render size | 4× (192 px tall) then integer downscale | downscale is nearest after a 2-px-equivalent pre-blur, then quantise to palette |
| Lighting | one key (sun, 45° elevation, from camera-left), one fill at 20 %, no cast shadows on the sprite | shadows are a separate blob sprite in-engine |
| Outline | 1-px `soot` outline added in post, inner-line only where the silhouette would merge | deterministic script |
| Frame size | 64×64 cell for average, 72×72 giant; pivot at feet centre, recorded per strip | packer enforces no clipping |
| Animation set, Phase 1 | idle (4f), walk (8f), attack_1h (6f), hit (3f), death (6f), down (1f) per facing | from the Mixamo library, retargeted in Blender, cleaned by script |
| Layers | body, hair/head, torso, legs, helmet, weapon, offhand, injury_overlay, cloak/insignia | each layer rendered separately with the same camera and frame timing, so they align by construction |
| Skin | rendered in a fixed neutral skin ramp, recoloured by shader to one of six skin ramps | palette indices, never free colour |

## 4. Injury and gore overlays

- Injury overlays are rendered layers on the same rig: `eye_patch_l/r`, `scar_face_1..3`,
  `missing_hand_l/r` (swaps the arm mesh and removes the weapon socket), `limp` (selects an
  alternate locomotion clip), `bandage_head`, `bandage_arm`.
- Blood is three escalating overlay sprites per facing (`blood_1..3`), tinted from the `blood`
  ramp, applied in-engine over the torso layer.
- Battlefield blood is a decal pool of 6 stain sprites placed at logged impact points. Bodies stay
  as `down` frames until the battle ends.
- Dismemberment: a layer swap at a named frame plus a spawned gore object. No unique gore sheets.

## 5. Portrait contract (the one generative asset class)

| Parameter | Value |
|-----------|-------|
| Size | 256×320 shipped, generated at 1024×1280 and downscaled with the same pixel post as sprites **[D: pixelated vs painterly portraits — needs samples]** |
| Framing | head and shoulders, 3/4 view toward camera-left, neutral background from `slate` ramp |
| Base model | FLUX.2 klein 4B (Apache-2.0) or SDXL base (OpenRAIL++-M), decided by Phase 2 sample quality; Qwen-Image and Anima are banned |
| Style lock | one style LoRA trained on 40–60 director-approved portraits produced from the base model itself (no scraped art, no artist names in prompts) |
| Identity | each merc's portrait seed is stored in the save; injury states are inpainted from the same seed with masks, so the face stays the same face |
| Prompt | a template filled from merc data (age band, build, skin ramp, hair, scars, faction cloth); no free text from an agent |
| Validator | palette compliance after quantise, framing box, no text artefacts (OCR check), no extra limbs (pose-estimate check), provenance manifest present |
| Gate | every batch of 20 portraits goes to the director as a labelled contact sheet; rejects are regenerated with a new seed, never hand-edited |

## 6. Environment contract

- Low-poly 3D, textures at the sprite's pixels-per-metre (≈ 27 at 48 px) texel density, painted from
  the master palette (textures are quantised at export).
- Modular kit per biome: ground tiles, walls, roofs, doors, props, foliage cards. One `GridMap`
  mesh library per biome.
- Flat shading with a single sun and soft ambient; vertex colour for grime and moss. Fog and
  weather are engine post-effects tuned to the palette.
- Hunyuan3D or Tripo output is silhouette reference for props only; shipped meshes are modelled or
  kitbashed in Blender so topology and texel density obey the contract.

## 7. UI contract

- One kit: `ui/UiKit.gd` owns colours (from the palette file), the type scale, spacing, radii (max
  2 px), rules and lines.
- Editorial and flat: typography, alignment and rules make hierarchy. No rounded-card stacks,
  pills, gradients, glows, glassmorphism, drop shadows or icon soup.
- Fonts: one pixel UI face and one serif display face, both SIL OFL; chosen by the director from a
  labelled sheet in Phase 1 **[D]**.
- Copy: plain feudal English a sergeant would say. Sentence case. No system words ("buff",
  "proc", "RNG") in player text.
- Faction identity is colour and heraldry, never UI chrome.

## 8. Golden references

`assets/golden/` holds, once approved: `street_day.png`, `street_rain_night.png`,
`merc_sheet_average.png`, `merc_sheet_giant.png`, `portrait_sheet_01.png`, `battle_frame.png`,
`inspect_screen.png`. Every asset PR shows its output beside the relevant golden image. A golden
image changes only by director decision recorded in DECISIONS.md.

## 9. The review test

Cover the title. Is this still recognisably MERCS: muted feudal world, heraldic punches of colour,
readable pixel people with real weight, editorial UI? If it could be any AI-generated fantasy RPG,
it is not done.
