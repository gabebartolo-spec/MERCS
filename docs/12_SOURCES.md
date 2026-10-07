# 12 — Sources consulted by the Concept Lead (2026-10-08)

Licence and platform facts in this pack were checked against these. Re-verify a row in
`10_LICENSING_REGISTER.md` whenever the item's version changes.

## Engines and platforms
- Unity pricing and plan changes (runtime fee cancelled Sept 2024; Personal free under US$200k; Pro US$2,310/yr/seat in 2026): https://unity.com/runtime-fee · https://unity.com/pricing-updates · https://enginesdatabase.com/blog/state-of-unity-licensing-in-2026/
- Godot 4.7 release (June 2026; AreaLight3D, HDR, MeshLibrary editor; C# production-ready on desktop): https://gamedev.net/news/godot-47-released-r4011/ · https://godotengine.org/
- Godot AnimatedSprite3D: https://docs.godotengine.org/en/stable/classes/class_animatedsprite3d.html
- Godot glTF import and retargeting: https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/retargeting_3d_skeletons.html

## Models and tools
- Qwen-Image 2.1 licence change to a research-only licence: https://www.eesel.ai/blog/qwen-image-2-1 · https://aiweekly.co/alerts/alibaba-ships-qwen-image-21-7b-dit-with-native-2048x2048-and-rgba-drops-apache
- Anima non-commercial licence (CircleStone Labs; derivative of NVIDIA Cosmos-Predict2): https://huggingface.co/circlestone-labs/Anima/blob/main/README.md
- FLUX.2 [klein] 4B Apache-2.0: https://bfl.ai/blog/flux2-klein-towards-interactive-visual-intelligence · https://help.bfl.ai/articles/8642316687-flux-2-klein-fast-generation-guide
- Tencent Hunyuan 3D 2.x Community Licence (territory exclusions, 1M MAU threshold): https://huggingface.co/tencent/Hunyuan3D-2/blob/main/LICENSE · https://scancode-licensedb.aboutcode.org/tencent-hunyuan-3d-2.0-cla.html
- Tripo commercial terms (free tier CC-BY, paid tiers full rights): https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially · https://www.tripo3d.ai/blog/commercial-use-ai-3d-models
- Mixamo terms for commercial games: https://community.adobe.com/t5/mixamo-discussions/mixamo-faq-licensing-royalties-ownership-eula-and-tos/m-p/13234775
- Wan 2.2 VRAM requirements (5B TI2V fits 12 GB): https://wan27.org/blog/wan-2-2-requirements-guide
- Comfy-Org comfy-mcp: https://github.com/Comfy-Org/comfy-mcp
- AnimateDiff, IP-Adapter, ControlNet, BiRefNet, SAM 2, MMPose, UniRig, FreeMoCap, LTX-2.5, MDM/SinMDM, GVHMR: see the source register S1–S45 in the director's "AI Game Animation: Local-First Research & Automation Brief" (2026-10-07), which this pack adopts for the animation research baseline.

## Hosting
- GitHub LFS quotas and metered billing (10 GiB free storage and bandwidth; US$0.07/GiB-month, US$0.0875/GiB): https://docs.github.com/en/enterprise-cloud@latest/billing/concepts/product-billing/git-lfs
- GitHub Actions free minutes for private repos (2,000/month on Free): https://docs.github.com/en/billing

## Director's briefs (in `docs/source-briefs/`)
- `Mercenary_Collector_RPG_Claude_Design_Brief.docx` (2026-10-07): the original concept, systems and production brief this pack was built from.
- `Mercenary_Collector_Three_Pillars_Claude_Brief.docx` (2026-10-08): the three-pillar synthesis; adds the company-as-player model, chronicle, triage, retreat and regional pools (D-TBD-three-pillars).

## Comparable games (reception signals from the director's design brief, directional only)
Pokémon Black/White, Battle Brothers, Wildermyth, RimWorld, Cassette Beasts, Monster Sanctuary,
Darkest Dungeon, XCOM 2, Baldur's Gate 3, Esoteric Ebb, Jagged Alliance 3, Into the Breach,
Octopath Traveler II. Links in the brief's §26.

## Internal evidence
- `C:\Users\DANTE\Documents\GitHub\Afl-auto-battler` (956 commits, 2026-09-22 to 2026-10-07): CLAUDE.md, ROADMAP §0.4a and §1, `.claude/skills/*`, `docs/SYSTEM_REALITY_AUDIT.md`, `docs/DESIGN_AUDIT.md`.
- `C:\Users\DANTE\Documents\GitHub\ard-asset-pipeline`: README, `tools/blender/*`, `workflows/*`, `runs/*/manifest.json`.
- `C:\Users\DANTE\Documents\GitHub\agent-handoffs`: lead.md, medium.md, low.md, backlog.md.
- Hardware probe via WMI, nvidia-smi and comfy-mcp `server_info`, 2026-10-08.
