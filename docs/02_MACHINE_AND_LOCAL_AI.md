# 02 — Machine profile and local AI feasibility

Measured on 2026-10-08 by the Concept Lead. The Art agent re-probes before any install over 10 GB
and writes `tools/machine_profile.json` (schema at the end of this file).

## Hardware

| Part | Value | What it means for the project |
|------|-------|-------------------------------|
| CPU | AMD Ryzen 7 9700X, 8 cores / 16 threads | Blender CPU bakes and parallel headless Godot suites are comfortable; 8 cores is the limit for "several agents at once" |
| GPU | NVIDIA RTX 4070 SUPER, **12 GB VRAM** (12,282 MiB), driver 617.14 | the deciding number: the 12–16 GB tier of the animation research brief |
| RAM | 32 GB DDR5-6000 (2×16) | enough for one image model loaded plus Blender plus Godot; not enough to also hold a 20B+ local LLM comfortably while rendering |
| Storage | C: 931 GB NVMe, **84 GB free**; D: 931 GB NVMe, **375 GB free** | C: is nearly full. All model weights, vaults and renders go on D:. Move the StabilityMatrix install to D: before adding models |
| OS | Windows 11 Home 10.0.26200 | Godot, Blender and ComfyUI all run natively; CUDA via the NVIDIA driver (no separate toolkit installed) |
| Board | MSI B650M Gaming Plus WiFi | no second GPU slot worth planning around |

## Installed and relevant

| Tool | Version / location | Status |
|------|--------------------|--------|
| Godot | 4.7.2 stable, `C:\Users\DANTE\Desktop\Godot_v4.7.2-stable_win64.exe\` | engine of record |
| Blender | 5.2, `C:\Program Files\Blender Foundation\Blender 5.2` | headless render and bake layer; MPFB add-on already used on AFL |
| Unity | 6000.3.23f1 only (the director's Orc-Survivor project) | not used by MERCS; the other four editors were uninstalled 2026-10-08 (D-016) |
| ComfyUI | v0.39.1 (updated 2026-10-08) via StabilityMatrix at `C:\Users\DANTE\Documents\SPRITE STUFF\StabilityMatrix-win-x64\Data\Packages\ComfyUI`; comfy-cli 1.22.0; comfy-mcp configured | no custom node packs installed |
| Forge Neo | same StabilityMatrix | not needed; ComfyUI is the single control plane |
| Ollama | gpt-oss:20b (13 GB), gemma4:26b (18 GB), qwen3.6:35b-a3b-coding (22 GB) | optional dev-time tools only, see below |
| Node.js | 24.21 | validators and the optional Three.js lab |
| Python | 3.14.7 | pipeline scripts; Blender ships its own Python |
| Git / LFS / gh | git 2.x, git-lfs 3.7.1, gh logged in as gabebartolo-spec | repo tooling ready |
| Codex CLI, Obsidian | installed | not part of the workflow |

## Model inventory on disk (StabilityMatrix `Data/Models`)

Since 2026-10-08 `Data/Models` is a directory junction to `D:\MERCS-vault\models`; the files live on D:.
Banned and unused files below were deleted the same day (D-015, D-018); rows are kept as history.

| File | Size | Licence (see 10_LICENSING_REGISTER) | Verdict |
|------|------|--------------------------------------|---------|
| `DiffusionModels/qwen_image_2.1_int8_convrot.safetensors` + Qwen text encoders + VAE | 7.3 + 9.5 + 9.4 + 0.7 GB | Qwen Research Licence: **non-commercial** | **BANNED**. Deleted 2026-10-08 (Recycle Bin emptied by the director) |
| `StableDiffusion/anima_turboV11.safetensors` | 4.2 GB | CircleStone non-commercial | **BANNED**. Deleted 2026-10-08 (Recycle Bin emptied by the director) |
| `StableDiffusion/pixelArtDiffusionXL_spriteShaper.safetensors` | 6.9 GB | SDXL base is CreativeML OpenRAIL++-M; Civitai fine-tune permissions must be read and recorded | PENDING (Civitai region-blocked, D-017); concept sheets only |
| `Lora/pixel-art-xl-v1.1.safetensors`, `Lora/Pixel_Art_Sprite_Sheet_space_candy_media.safetensors` | 0.2 GB each | Civitai, per-model permissions | PENDING; concept only (D-017). The "Pony pixel LoRA" was a broken HTML download, removed (D-018) |
| `StableDiffusion/hunyuan3d-dit-v2-mv_fp16.safetensors` | 4.9 GB | Tencent Hunyuan 3D Community Licence: commercial OK under 1M MAU, not valid in EU/UK/South Korea | CLEARED for prop and silhouette reference generation (Australia-based developer) |
| `StableDiffusion/realisticVisionV60B1_v51HyperVAE.safetensors` | 2.1 GB | SD1.5 OpenRAIL-M | deleted 2026-10-08 (Recycle Bin emptied by the director) |

## What runs locally on 12 GB VRAM, and what it is for

| Workload | Feasible? | Route | Role in MERCS |
|----------|-----------|-------|---------------|
| Blender EEVEE/Workbench sprite renders, 8 facings × N frames | Yes, seconds per frame | headless `blender -b -P` | **the canonical character pipeline** |
| Deterministic pixelisation and palette quantisation | Yes, CPU | Python/Pillow/NumPy | canonical |
| SDXL-class image generation (1024²) | Yes, ~5–10 s per image | ComfyUI | concept sheets, heraldry ideation, texture ideas |
| FLUX.2 klein 4B (Apache-2.0) at 1024² | Yes, fits ~13 GB with fp8/offload; benchmark | ComfyUI | **portrait generation and inpainting candidate** (commercially clean) |
| SDXL LoRA training (style LoRA, ~40 images) | Yes, 1–3 h with gradient checkpointing | kohya-ss / OneTrainer | portrait style lock |
| Hunyuan3D-2 multiview shape generation | Yes, ~30 s per mesh (measured on AFL) | ComfyUI | silhouette reference for props and equipment; never shipped meshes |
| UniRig local auto-rigging | Yes (8 GB floor) | standalone | not needed if the base body is rigged once by hand |
| Wan 2.2 TI2V 5B video | Fits (fp16 ~10 GB), slow | ComfyUI | **parked**: no production need |
| Wan 2.2 14B / Wan Animate 2 | Only quantised + offloaded, impractically slow | — | **parked** |
| LTX-2.5 | No (32 GB floor) | — | out |
| FreeMoCap local mocap | CPU/GPU light, needs 2+ webcams | standalone | optional later for bespoke motion; not in the slice |
| Local LLM inference (qwen3.6 35B-A3B, gpt-oss 20B) | Yes with CPU offload, 10–30 tok/s | Ollama | optional batch tooling only |

## Local LLMs: honest assessment

The three Ollama models are not on the critical path. Opus 5.5 writes the code; local models are
slower, weaker and would compete for the same 12 GB the art pipeline needs. Their only sanctioned
uses, all optional and all offline-batch:

1. **Storylet lint** (`tools/lint/storylet_lint.py`): check every authored storylet for tag
   consistency, pronoun agreement with casting, and tone words from the banned list. Cheap, private,
   repeatable; output is a report, never an edit.
2. **Name and place generators** for data tables (seeded, run once, output committed and curated).
3. **ComfyUI prompt expansion** for concept sheets, so the Art agent's prompt templates stay short.

Rule: a local LLM never writes GDScript that lands in `main`, and never runs while a Blender or
ComfyUI batch is using the GPU.

## Cloud and paid tools (director approval required for each, logged in DECISIONS.md)

| Tool | Cost signal | When it would be worth asking |
|------|-------------|-------------------------------|
| Tripo | **25,000 paid credits on hand (D-014)**; up to 500 per session without asking | equipment, prop and concept meshes; the base body stays CC0 |
| Cloud GPU (RunPod etc.) | hourly | if a portrait LoRA needs more than 12 GB, or video R&D is ever revived |
| GitHub LFS overage | US$0.07/GiB-month storage, US$0.0875/GiB bandwidth beyond 10 GiB | when committed binaries pass ~8 GiB; see 09 |
| Steam Direct | US$100 once | at store-page time, not before |

## `tools/machine_profile.json` schema

```json
{
  "probed_at": "2026-10-08T00:00:00+11:00",
  "gpu": {"name": "NVIDIA GeForce RTX 4070 SUPER", "vram_mib": 12282, "driver": "617.14"},
  "ram_gib": 32,
  "disk": {"C": {"free_gib": 84}, "D": {"free_gib": 375}},
  "comfyui": {
    "core": "v0.38.0",
    "custom_nodes": [],
    "models_root": "D:/MERCS-vault/models",
    "models_root_link": "how StabilityMatrix reaches models_root (e.g. a directory junction)"
  },
  "vault": "D:/MERCS-vault",
  "blender": "5.2",
  "godot": "4.7.2-stable",
  "unity_editors": ["6000.3.23f1"],
  "vram_tier": "12-16",
  "notes": "C: nearly full; models live on D:"
}
```

The Art agent updates this file in the same PR as any install and prints a one-line diff in the
PR body.
