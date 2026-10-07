# 10 — Licensing register

Rule: nothing touches the product (ships, trains a model that ships, or seeds a shipped asset)
unless its row says **CLEARED**. **PENDING** means usable for throwaway concept work only.
**BANNED** means not even that. The Art agent owns model and tool rows; the Merge & CI agent owns
the "recorded" column; the Concept Lead audits the register at every gate.

Status as verified by the Concept Lead on 2026-10-08 from the sources listed. Licences change:
each row is re-checked when its version changes.

## Engine, tools and libraries

| Item | Version | Licence | Status | Notes |
|------|---------|---------|--------|-------|
| Godot Engine | 4.7.2 | MIT | CLEARED | export templates include third-party notices to ship in the game's credits |
| gdtoolkit (gdlint/gdformat) | latest | MIT | CLEARED | dev only |
| Blender | 5.2 | GPL-2.0+ | CLEARED | outputs are yours; the tool is not shipped |
| MPFB (MakeHuman Plugin for Blender) | 2.0.x | code AGPL/GPL; **base mesh and targets CC0** | CLEARED | ship rendered sprites freely; do not ship the plugin |
| Mixamo (Adobe) | service | Adobe General Terms: free, royalty-free use in games; no redistribution of raw clips/characters | CLEARED | clips stay in the vault, never in the repo; credit Adobe Mixamo in credits as courtesy |
| ComfyUI | 0.39.1 (updated 2026-10-08) | GPL-3.0 | CLEARED | tool only |
| StabilityMatrix | current | AGPL-3.0 | CLEARED | launcher only |
| comfy-cli / comfy-mcp | 1.22 | GPL-3.0 / per repo | CLEARED | tool only |
| Python, Pillow, NumPy | 3.14 | PSF / HPND / BSD | CLEARED | |
| Node.js, Three.js (if lab is ever built) | 24 / r17x | MIT | CLEARED | not in slice |
| Ollama | current | MIT | CLEARED | tool only |
| Tripo3D (paid credits, 25,000 on hand) | API v3 / Studio | Tripo terms, paid tier: full commercial rights, no attribution; rights to the input image are not granted, so inputs must be ours | CLEARED (D-014) | equipment, props and concept meshes only; more than 500 credits in a session needs a yes; log credits used per batch |
| Tripo3D Godot bridge add-on | latest | per repo (check before enabling) | PENDING | enable only if the Dev Lead wants it; not required |
| gitleaks | latest | MIT | CLEARED | CI only |
| Steamworks SDK | at store time | Steam Partner terms | PENDING | director accepts at store-page time |

## Generative models on this machine

| Model | File | Licence | Status | Source checked |
|-------|------|---------|--------|----------------|
| Qwen-Image 2.1 (DiT + text encoders + VAE) | `DiffusionModels/qwen_image_2.1_int8_convrot.safetensors` and `TextEncoders/qwen3.5_9b…`, `qwen3vl_8b…`, `VAE/qwen_image_2.1_vae_bf16` | Qwen Research Licence: non-commercial without a separate agreement | **BANNED** | HF model card and licence file; press coverage of the licence change from the Apache 2.0 Qwen-Image 1.x line. All four files sent to Recycle Bin 2026-10-08 (D-015) |
| Anima 1.0 Turbo | `StableDiffusion/anima_turboV11.safetensors` | CircleStone Labs Non-Commercial Licence (derivative of NVIDIA Cosmos-Predict2) | **BANNED** | HF model card. Civitai model 2458426 / version 3263843. Sent to Recycle Bin 2026-10-08 |
| pixelArtDiffusionXL spriteShaper | `StableDiffusion/pixelArtDiffusionXL_spriteShaper.safetensors` | base SDXL: CreativeML OpenRAIL++-M (commercial OK); fine-tune permissions on Civitai not yet quoted | PENDING | Civitai model 277680 / version 364043 (local metadata); SHA256 `7adffa28d400…9f04a93`. Civitai API and site answer `REGION_BLOCKED` from this machine (2026-10-08), so the permissions block cannot be read. Stays PENDING, concept only (D-017) |
| pixel-art-xl v1.1 LoRA | `Lora/pixel-art-xl-v1.1.safetensors` | Civitai per-model; the same author (nerijs) publishes it on HF as `nerijs/pixel-art-xl` under CreativeML OpenRAIL-M | PENDING | SHA256 `bbf3d8defbfb…445de274` matched Civitai model 120096 / version 135931 by hash; Civitai permissions block then `REGION_BLOCKED`. The HF file is the same size but a different hash (`4234637cb80c…e353eef7`), so the HF licence supports but does not prove this file. Concept only (D-017) |
| Pixel Art Sprite Sheet LoRA | `Lora/Pixel_Art_Sprite_Sheet_space_candy_media.safetensors` | Civitai per-model | PENDING | SHA256 `9a4d682f6873…6f45051e`; Civitai lookup `REGION_BLOCKED`; no HF mirror found. Concept only (D-017) |
| Hunyuan3D-2mv | `StableDiffusion/hunyuan3d-dit-v2-mv_fp16.safetensors` | Tencent Hunyuan 3D 2.0 Community Licence: commercial OK under 1M MAU; **not valid in EU, UK, South Korea** | CLEARED for reference/blockout meshes only | HF licence file; developer is in Australia; never ship a raw Hunyuan mesh |
| Realistic Vision 6.0 | `StableDiffusion/realisticVisionV60B1_v51HyperVAE.safetensors` | SD1.5 OpenRAIL-M | CLEARED but unused | sent to Recycle Bin 2026-10-08 (D-015) |

## Models found in ComfyUI's own `models/` folder (outside the vault; fetched earlier via comfy-mcp)

Found 2026-10-08 under `Data/Packages/ComfyUI/models/` on C:. Licence tags read from the HF repo metadata, not yet from the licence files, so every row is PENDING. Not on the Phase 1 path.

| Model | File | Licence (HF tag) | Status | Source checked |
|-------|------|------------------|--------|----------------|
| TRELLIS.2 4B (image-to-3D) | `diffusion_models/trellis_2_int8_convrot.safetensors` (5.3 GB) | MIT (`microsoft/TRELLIS.2-4B`, repack `Comfy-Org/TRELLIS.2`) | PENDING | HF metadata 2026-10-08 |
| Pixal3D TRELLIS.2 VAEs | `vae/trellis_2_shape_vae_bf16`, `vae/trellis_2_texture_vae_bf16` (2.0 GB) | MIT (`Comfy-Org/Pixal3D`, base `TencentARC/Pixal3D`) | PENDING | HF metadata 2026-10-08 |
| DINOv3 ViT-L | `clip_vision/dino_v3_L_naf_fp32.safetensors` (1.2 GB) | upstream is Meta's DINOv3 Licence (`license:other`, gated); the `Comfy-Org/Pixal3D` repack is tagged MIT, which does not override Meta's terms | PENDING | HF metadata 2026-10-08; read Meta's licence before any use |
| MoGe-2 ViT-L normal | `geometry_estimation/moge_2_vitl_normal_fp16.safetensors` (0.7 GB) | MIT (`Ruicheng/moge-2-vitl-normal`, repack `Comfy-Org/MoGe`) | PENDING | HF metadata 2026-10-08 |
| BiRefNet | `background_removal/birefnet.safetensors` (0.4 GB) | MIT (`Comfy-Org/BiRefNet`) | PENDING (row below is CLEARED for the upstream; this repack is unverified) | HF metadata 2026-10-08 |

## Generative models recommended for download (not yet installed; each needs a director yes if >10 GB)

| Model | Size | Licence | Status | Role |
|-------|------|---------|--------|------|
| FLUX.2 [klein] 4B | ~8 GB fp8 + text encoder | Apache-2.0 | CLEARED on download (verify the HF licence file at download) | portrait base; multi-reference editing for injury inpainting |
| SDXL 1.0 base + refiner | 7 + 6 GB | CreativeML OpenRAIL++-M | CLEARED (use restrictions are standard; no illegal/harmful content) | fallback portrait base; LoRA training base |
| BiRefNet | ~1 GB | MIT | CLEARED | background removal for concept cut-outs |
| Wan 2.2 TI2V 5B | 10 GB | Apache-2.0 | CLEARED but PARKED | no production need |

## Local LLMs (dev tooling only; never ship, never generate shipped text)

| Model | Licence | Status |
|-------|---------|--------|
| gpt-oss:20b | Apache-2.0 | CLEARED for lint/batch tooling |
| qwen3.6:35b-a3b-coding | Apache-2.0 (verify tag on the Ollama page) | CLEARED for lint/batch tooling |
| gemma4:26b | Gemma Terms of Use (commercial allowed with use restrictions) | CLEARED for lint/batch tooling |

## Content inputs

| Input | Rule |
|-------|------|
| Prompts | no artist names, no game or film titles, no living people |
| Reference images for concepting | the director's own photos/sketches, CC0, or public-domain sources; record the source in the concept manifest |
| Training data for the portrait style LoRA | only images generated from CLEARED models in this project and approved by the director; no scraped art |
| Fonts | SIL OFL only; licence file committed beside the font |
| Audio | original, CC0, or CC-BY with attribution file; no CC-NC, no "royalty-free" packs without a written licence |
| Names and places | generated and curated by the team; no real nobility or living persons |
| Mixamo clips | used only as baked sprite frames; never redistributed as clips |

## Provenance manifest (required beside every file in `assets/`)

```json
{
  "asset": "characters/average/torso_mail_hauberk.png",
  "produced_by": "tools/pipeline/render_character.py@<git sha>",
  "inputs": {"body": "average.blend@<hash>", "clip": "mixamo:walk@<hash>", "mesh": "mail_hauberk.blend@<hash>"},
  "models": [],
  "licence_rows": ["MPFB", "Mixamo", "Blender"],
  "seed": null,
  "palette_version": "v1",
  "created": "2026-10-20T10:00:00+11:00"
}
```

`validate_provenance.py` fails any asset whose `licence_rows` includes a row not marked CLEARED
here, or whose `models` list names a BANNED file.
