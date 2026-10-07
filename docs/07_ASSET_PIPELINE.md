# 07 — Asset and animation pipeline

Principle: **AI accelerates a deterministic pipeline; it never replaces one.** Characters are
rendered, not generated. Generation is confined to concepting, portraits and prop silhouettes,
and everything that ships passes a validator and the director.

## 1. Pipeline map

```
                 ┌──────────────── concept (optional) ────────────────┐
  prompt template → ComfyUI (cleared model) → contact sheet → director picks → reference image
                 └─────────────────────────────────────────────────────┘
                                  │ (reference only)
 CC0 base body (MPFB) ─┐          ▼
 3 builds, 1 skeleton  ├→ Blender: equipment meshes modelled/kitbashed to sockets
 Mixamo clip library ──┘          │
                                  ▼
            Blender headless batch (tools/pipeline/render_character.py)
            8 facings × clips × layers, fixed camera + light rig, 4× size
                                  │
                                  ▼
            Pixel post (tools/pipeline/pixelate.py): downscale → quantise → outline
                                  │
                                  ▼
            Pack (pack_sheets.py): strips per layer, pivots, reach, JSON manifest, provenance
                                  │
                                  ▼
            Validate (validate_sprite.py, validate_palette.py): clip, align, palette, counts
                                  │
                                  ▼
            Godot import fixture (tests/run_assets_tests.gd): every strip loads, plays, aligns
                                  │
                                  ▼
            Director gate (labelled contact sheet + 3-second clip) → assets/characters/
```

Portraits: `merc data → prompt template → ComfyUI (FLUX.2 klein 4B or SDXL + style LoRA, fixed
seed) → pixel post → validate_portrait.py → director gate → assets/portraits/`.

Environments: `concept (optional) → Blender modular kit (palette-quantised textures) → GLB →
Godot GridMap library → capture fixture → director gate`.

## 2. Stage contracts

### 2.1 Base body and rig (Phase 1, done once)
- Source: MPFB (MakeHuman Plugin for Blender) base mesh, CC0. Three builds saved as
  `tools/pipeline/bodies/{slight,average,giant}.blend` with heights 1.65 / 1.78 / 2.02 m.
- Skeleton: Mixamo naming, frozen; `tools/pipeline/rig_contract.json` lists bone names, rest pose
  hash and socket transforms. CI fails if a `.blend` export changes the hash.
- Why not Tripo/UniRig per character: all mercs are humans; variety is equipment, build, hair,
  injury and portrait. One rig means every clip and every equipment mesh works for everyone.

### 2.2 Motion library
- Source: Mixamo (free with an Adobe account; usable in commercial games, not redistributable as
  raw files, so clips live in the vault, not the repo). Phase 1 set, six clips matching
  `06_STYLE_ART.md` §3: idle, walk, attack_1h, hit, death, down. Phase 3 adds run, attack_2h,
  attack_polearm, shoot_bow, block, death_back, flee, surrender.
- Retarget in Blender by script (`retarget_clip.py`), clean curves, normalise root to in-place,
  bake at 12 fps for sprites. Each clip has a cue JSON (`hit_frame`, `release_frame`).
- Bespoke motion (a limp walk, a one-handed re-grip) comes from editing library clips in Blender
  by script with reference footage, or from FreeMoCap if two webcams exist. Text-only invented
  biomechanics are not accepted.
- Generative video (Wan, AnimateDiff) is parked. Revisit only after Phase 8 and only as a
  reference source, never as frames.

### 2.3 Equipment meshes
- Modelled or kitbashed in Blender to the socket contract. Tripo (paid credits, D-014) is the
  first source for equipment and prop blockouts; Hunyuan3D-2mv is the free local fallback. Either
  output is retopologised before use because fused topology breaks layer rendering. Credits used
  are logged per batch; more than 500 in a session needs the director's yes.
- Each item is one `.blend` collection plus `data/equipment.json` entry with its render layer and
  socket. Phase counts cap the catalogue.

### 2.4 Render batch
- `render_character.py --body average --layers body,torso:mail_hauberk,weapon:arming_sword
  --clips idle,walk,attack_1h --facings 8` writes `vault/renders/<hash>/...` at 4× with the fixed
  camera (`camera_rig.json`) and light rig. Deterministic: same inputs, same bytes.
- Workbench or EEVEE flat shading with no anti-aliasing at the 4× stage; the pixel post does the
  reduction.

### 2.5 Pixel post
- Pre-blur radius 0.5 px at 4×, nearest-neighbour downscale, quantise to the master palette with
  per-ramp protection (skin pixels only map to the neutral skin ramp), 1-px outline, alpha
  threshold. All parameters in `pixelate.json`; changing them is a decision because every sheet
  must be rebuilt.

### 2.6 Packing and manifests
- Strips per layer and facing; pivot at feet; per-frame reach for weapon hit boxes. Output
  `assets/characters/<build>/<layer>.png` plus `manifest.json` (strip rects, pivots, cue frames,
  palette version, render hash, clip source, tool versions). `CharacterSheets.gd` is generated from
  manifests and never edited by hand.
- Provenance manifest per asset: model/tool, version, seed, licence row id, inputs' hashes.

### 2.7 Validators (CI on every asset PR)
- `validate_sprite.py`: no empty frames, no clipping, all layers share frame counts and pivots,
  outline present, size per build.
- `validate_palette.py`: every opaque pixel is in the master palette; heraldry ramps only on
  permitted layers.
- `validate_portrait.py`: size, framing box, palette, OCR finds no text, pose-estimate finds one
  face, provenance names a CLEARED model and the current style LoRA hash.
- `validate_provenance.py`: every file under `assets/` has a manifest; every manifest's licence
  row is CLEARED in `10_LICENSING_REGISTER.md`.

### 2.8 Godot fixture
- `tests/run_assets_tests.gd` loads every manifest, instantiates each layer, plays every clip
  through, asserts frame alignment across layers and that `CharacterSheets.gd` matches the PNGs.
- A capture script renders the golden scenes and the current sheet for the director.

## 3. Concept generation (optional, never shipped)
- ComfyUI with a CLEARED model only. Prompt templates in `tools/pipeline/prompts/`. Fixed seeds.
  Output goes to `vault/concepts/`, never to `assets/`.
- Uses: heraldry ideas, clothing silhouettes, architecture sheets, weather moods. Hunyuan3D for
  prop silhouettes.
- The Art agent never uses artist names, game names or living people in prompts.

## 4. Control plane
- ComfyUI through comfy-mcp (`server_info` first, then `run_workflow(wait=False)` → `job` →
  `fetch_outputs`). Workflows are API-format JSON in `tools/pipeline/workflows/` with slot
  overrides; no manual node clicking in production.
- Blender headless: `blender -b <file> -P <script> -- <args>`. Scripts are idempotent and log to
  `vault/logs/`.
- Models and the vault live on `D:\MERCS-vault\` (see 09). Move StabilityMatrix's models root
  there before Phase 1.

## 5. Phase 1 proof (the asset factory gate)
Done when: one `average` merc in three equipment combinations plays idle/walk/attack/hit/death in
all 8 facings inside the Phase 1 street scene; a `giant` in one combination does the same; one
eye-patch and one missing-hand overlay align; the whole set rebuilds from a clean checkout plus
the vault with one command in under 30 minutes; validators pass; the director has approved the
look from labelled captures (pitch, height, pixel mode).

## 6. Measurement the Art agent reports every batch
Usable asset rate after retries, manual minutes per accepted asset, render minutes per sheet,
validator failure reasons (histogram), VRAM peak, and the licence row of every model used.
