---
name: mercs-art-pipeline
description: How MERCS art is made and what a code agent may change about it - one CC0 base body, modular equipment, the sheet and manifest contract, the render, palette and portrait contracts, portraits as the only generative asset, the validators, the licensing register, the director's look gate, and why GPU jobs belong to the Art agent. Use it whenever you touch assets/, tools/pipeline/, CharacterSheets.gd, a sprite or portrait loader, UiKit colours, an overlay or decal, or anything a player would see differently - even for a one-line change.
---

# The art pipeline, for a code agent

MERCS characters are rendered, not generated: AI accelerates a deterministic pipeline and never
replaces one (`docs/07_ASSET_PIPELINE.md`). The Art Factory agent owns `tools/pipeline/`, `assets/`,
ComfyUI, Blender, the validators and the licence rows for models and tools, and is the only agent that
starts a GPU job (`agent-briefs/ART_AGENT.md`; CLAUDE.md "Machine rules"). The Dev Lead owns the code
that reads the assets. Read the section you need in `docs/06_STYLE_ART.md` (the contracts) and
`docs/07_ASSET_PIPELINE.md` (the stages), not the whole files.

## How a character is made

**Paused for refocus (director, 2026-10-09, `D-TBD-art-refocus`).** The cast is now 25 hand-made
mercs, including non-humans, each with three stage looks and their own gear line, so the
single-base-body route below is under review. Do not build new work on it until P1-ART-REFOCUS is
approved; the camera, light, pixel post, palette, packing and validator steps are not in question.

One CC0 base body (MPFB; builds `slight`, `average`, `giant`) on one frozen Mixamo-named skeleton ->
equipment meshes modelled or kitbashed to six sockets -> Blender headless batch (`render_character.py`:
8 facings, clips, layers, fixed camera and light rig, at 4x) -> pixel post (`pixelate.py`: downscale,
quantise to the master palette, 1-px outline) -> pack (`pack_sheets.py`: strips per layer and facing,
pivots, reach, manifest, provenance) -> validators -> the Godot assets fixture -> the director's gate
-> `assets/characters/`. Layers render separately on the same camera and timing, so they align by
construction (`06` section 3).

Portraits are the one generative asset class: a prompt template filled from merc data -> ComfyUI with a
CLEARED model and the project's style LoRA at a fixed seed -> pixel post -> `validate_portrait.py` -> the
director's gate -> `assets/portraits/`. Diffusion never produces a sprite frame (guardrail D1).

## The contracts, and what checks them

Render contract (`validate_sprite.py`), palette contract (`validate_palette.py`), portrait contract
(`validate_portrait.py`) and provenance (`validate_provenance.py`, every file under `assets/`). They run in
CI on every asset PR (`assets.yml`). Values marked **[D]** in `06` are open director decisions (pitch,
character height, pixel mode, palette size, portrait style, fonts): ask, never assume.

## May

- Load character layers through `CharacterSheets.gd`, which is generated from the manifests, and read strip
  rects, pivots, reach and cue frames from it; place and time layers from sim events.
- Present injuries and blood from sim events: the injury overlays, the `blood_1..3` overlays tinted from
  the `blood` ramp, and decals placed at logged impact points; bodies stay as `down` frames until the
  battle ends (`06` section 4). The sim decides; presentation reads (CLAUDE.md rule 3).
- Keep what the save needs as stable ids and seeds, such as each merc's portrait seed (`06` section 5).
- Read validator output in CI and pass it to the Art agent; add tests that load and play what exists;
  capture review images at game scale.

## Ask first (the Art agent; the director for anything a player would see differently)

- A new facing, clip, layer, socket, overlay or body build. Counts are capped per phase; one outside the
  phase count is a director decision (guardrail A2; `agent-briefs/DEV_LEAD_OPUS.md` "You never").
- Any sheet, manifest, palette ramp, camera or light rig, or `pixelate.json` change. Pixel-post parameters
  are a decision because every sheet is rebuilt (`07` section 2.5).
- Anything that recolours skin at draw time: `06` section 2 says the six skin ramps are "never recoloured
  by shader" and section 3 says skin is "recoloured by shader to one of six skin ramps". Ask which holds.
- Any colour, font, radius or rule in `ui/UiKit.gd` (a look: `06` section 7).
- Any new model, tool, font, audio file or reference image: its licence is checked first against
  `docs/10_LICENSING_REGISTER.md` (a CLEARED row, or its "Content inputs" rules).

## Never

- Hand-edit `CharacterSheets.gd` or a PNG under `assets/`: rebuild from the pipeline (`07` section 2.6).
- Hard-code frame rectangles, cell sizes or pivots: they come from the manifests.
- Start ComfyUI, a Blender render or any GPU job (CLAUDE.md "Machine rules"); the Art agent announces
  its jobs in STATUS.md.
- Ship an unapproved look. Green CI is not approval, nor is a teammate's "looks fine".
- Put a colour literal in `ui/` outside `UiKit.gd` (guardrail D3) or a player-visible string in code (B12).
- Use a BANNED model for anything, "just for concepts" included.

## Licensing

Nothing enters `assets/` or `tools/` unless its row in `docs/10_LICENSING_REGISTER.md` says CLEARED
(CLAUDE.md rule 7). PENDING is for throwaway concept work only. BANNED (Qwen-Image 2.1, Anima) touches
nothing. Fonts are SIL OFL with the licence file beside them; audio is original, CC0 or CC-BY with an
attribution file; prompts carry no artist names, game titles or living people; the style LoRA trains only
on director-approved output of CLEARED models in this project, never scraped art. Every file in `assets/`
has a provenance manifest (tool, seed, licence rows) and `validate_provenance.py` fails on a row that is
not CLEARED. Mixamo clips stay in the vault (`D:\MERCS-vault\`), never the repo. Tripo and Hunyuan3D meshes
are silhouettes to retopologise, never shipped raw and never a replacement for the CC0 body or the rig.
Spend needs a decision entry (CLAUDE.md rule 8; Tripo credits: D-014).

## The director's look gate

Every look is the director's: figures, poses, kit, portraits, fonts, palette, UI chrome. A PR that changes
how anything looks stays a prototype until the director has seen it, with labelled images in the same
message as the question (`agent-briefs/DIRECTOR_QUESTION_PROTOCOL.md`), contact sheet beside the golden
image in `assets/golden/`. A golden image changes only by a decision in `docs/DECISIONS.md` (`06` section 8).
The test: cover the title; if it could be any AI-generated fantasy RPG, it is not done (`06` section 9).

## Learnings

Proven findings for this project live in `references/learnings.md`. Read it before using this
skill; add to it only what proved effective, with evidence.
