# Art handoff, 2026-10-15 AEDT
Start from this file, CLAUDE.md, your brief, and the Lead ("main") messages. Load art-qa-critic before any visual review.

## State: LOOK B LOCKED (director picked B "Peat and Ochre", 2026-10-15). PR open, awaiting review/merge. No jobs running.
Branch `claude/art-look-target` (worktree `MERCS-wt/art-look`), PR "art: lock look B Peat and Ochre as master palette
and golden references". Lock-B layout (supersedes the option paths below):
- `assets/palette/core.{json,gpl}` (44 colours that never change: soot, iron, bone, skins, cloth, heraldry, blood,
  fire) + `assets/palette/biomes/heartland.{json,gpl}` (slate, soil, timber, verdure + the light block; names its
  core; .gpl holds core + biome). palette_lib and validate_pixels load a biome as core + biome.
- Goldens `assets/golden/{street_day,street_rain_night,overworld_map}.png` at 1x logical (960x540) + provenance.
- Sprites `assets/look_target/heartland/sprites/`; options A and C (palette, look.json, sprites) under
  `docs/audits/look_target/options/{A,C}/`; light values for all three in `tools/look/look_options.json`.
- look_target.gd defaults to heartland; `--palette= --light= --sprites= --tag=` runs A or C. Night rain is frozen after
  its preprocess, so night frames are now byte-identical run to run (they were not: 1.1% of pixels moved).
- check_assets_pixels.py checks assets/look_target/heartland and assets/golden against heartland; self-test 24/24.
- Pipeline default pixelate.json still points at master_draft (average_m sheet + fixtures): switching is a separate step.

## Desloppify (director 2026-10-15 "NO SLOP"), branch claude/art-desloppify, no PR; awaiting a fresh critic
- Round 1 (6bcfc1a): C = dither 0, 6 near-dup colours separated, water ramp (68 colours, cap 72), map tufts/pebbles.
  Evidence D:/MERCS-vault/renders/desloppify_2026-10-15/ (board_*.png, x1/, scan_summary.json).
- Round 2 (lead QC of C = FIX), evidence D:/MERCS-vault/renders/desloppify_2026-10-15/round2/: board_{day,night,map}.png
  (C | D | E at 1x + two 4x crops + slop_scan line), x1/, frames_4k/, scan_summary.json, qc/ (self-QC crops), render.sh,
  board.py, iso_map.py (isolated-pixel heat map).
  - D (5c85605) = C + lead FIX 1-3: street verge detail modelled as palette faces (tools/look/kit_ground.py: door path,
    well apron, cart ruts turning onto the road with standing water, lobed puddle-dark spots, stone clumps where stones
    gather, tufts at wall/fence feet; open ground quiet); irregular cobbles (gutter rows, repair patch, lost stones),
    uneven kerbs; map grass bare + hand-placed DRESSING in look_map.gd (lush from woods/shore, dry on verges/hill feet,
    tuft clumps at edges, 5 stone clusters iron 2 on a soil 2 seat); night wall torch lit (flame + omni 0.55/3.5 m,
    offset 0.3 m off the wall, no ringed hotspot), lantern range 9.5 -> 6.5 m (heartland light block).
  - E (df9a7db) = D + own list: flat setts 4 mm over grout + hard shadow filter (day isolated 2.93% -> 0.90%,
    mean cluster 23 -> 72 px); map road packed earth with wandering verges (3 variants, no marks), road stub at the
    west junction; ragged forest floor; hills without slate cap + bedded outcrop; stone house coursed (base, quoins).
  - slop_scan (isolated % / mean cluster): day C 2.85/24, D 2.93/23, E 0.90/72; night C 0.85/58, D 0.51/83,
    E 0.32/135; map C 1.05/58, D 0.81/75, E 0.81/77. 0 near-dups, 0 off-palette on all. D/E street frames identical
    except E's setts/shadows/masonry; re-render after a no-op refactor byte-identical (deterministic).
  - Open (not fixed): left lake's square inlet corner (needs corner bank pieces); hills still read as faceted
    pyramids; single-px cluster share stays 43-65% (flat-shaded geometry edges); orc fused head is the cast builder's.
- Goldens unchanged: check_assets_pixels and pipeline self-test fail on them vs the new palette until the director
  picks (then copy round2/x1/<pick>_*.png to assets/golden and write_provenance for golden).
- Render: round2/render.sh <V> <scene> (own APPDATA per run, PID logged); 3 in parallel ~1 min. Kit: Blender
  build_look_kit.py then Godot --import (headless) before rendering.

## Water fix (lead QC 2026-10-15: map water read as an asphalt road with a lane marking)
- Cause: water was slate 1 lit by the warm sun (snapped to brown-greys), straight tile edges with a soil kerb,
  and a hairline crack between tiles showing the sky (bone 3) as one long pale line.
- Fix: water faces are `pal:cloth_faded:2:flat` (unlit, exactly the palette's one blue-slate; `:flat` suffix
  handled in look_target.gd `_recolour`); glints are short broken dash pairs (slate 2, flat); tiles scaled 1.002
  so they overlap (no crack); ragged mud-and-rush banks (kit `bank_0..2`, `bank_half_pos/neg`) on every
  water edge that meets land, and shore tiles `tile_shore_0..2` (water south half, bank across the middle).
- Map layout moved to `tools/look/look_map.gd` (look_target.gd was at the 400-line cap). Street goldens untouched.
- Before/after 2x crops: `D:/MERCS-vault/renders/look_2026-10-15/water_fix/`. Gates: lints 10/10, pixels and
  palette pass (0 off-palette, 48 colours), assets suite 13/13, gdlint/gdformat clean.
- Side effect: the 1.002 tile overlap moves about 1,800 pixels above the water by a pixel (tuft edges).

## Task (director 2026-10-15: "establish an aesthetic and stick to it")
Golden references + one master palette + one render rig, validated. 2-3 labelled options, each a coherent palette +
lighting + post set, shown as: street day, street night + rain (4K, real Godot build), overworld strip at map scale.

## What exists
- Boards (one per option, 3 frames side by side at exactly 2x logical): `docs/audits/look_target/option_{A,B,C}.png`.
  Raw 3840x2160 frames: `D:/MERCS-vault/renders/look_2026-10-15/frames_4k/{A,B,C}_{day,night,map}.png`.
- Palettes: `assets/palette/options/<X>/palette.json|.gpl|swatch.png` (64 colours, 14 named ramps, OKLab-spaced
  between hand-set anchors), `look.json` (day/night light, torch, rain, dither), `pixelate.json` (pipeline config with
  the option's palette). A "Ash and Hearth" (muted, cool), B "Peat and Ochre" (warm, earthy, ordered dither),
  C "Clear Day" (wider values, hue-shifted ramps, violet shadows).
- One rig, `tools/look/`: make_palettes.py; build_sprites.py (pixelate.py to skin_neutral, then a new
  render_character.py `--pass matid` gives each pixel's material and the shading step moves to that material's ramp:
  orc skin_orc, Vampyr skin_pale, plate iron or a blackened composite, cape a wine composite; map tokens are the same
  render reduced by 8); build_look_kit.py (Blender, primitives only: timber and stone houses, well, cart, barrels,
  fence, lantern post, cobbles, mud; map tiles plain/road/forest/hill/water/shore, town marker, banner poles; faces
  named `pal:<ramp>:<step>`); look_target.gd (the real StreetStage in a 3840x2160 SubViewport, grey boxes swapped for
  the kit, light from look.json, every pixel snapped to the palette by palette_post.gdshader in OKLab, with a distance
  penalty on heraldry/blood/fire so lit wood never turns crimson); make_boards.py; write_provenance.py.
- `tools/pipeline/validate_palette.py`: palette 48-64 colours, and every opaque pixel on it. All 9 frames and all
  sprites: 0 off-palette pixels. Negative check: A_day against palette B fails (8.3 M pixels).
- Capture is deterministic: A_day re-captured after gdformat was byte-identical.
- Kits edited for the look target: orc breastplate/cuisses/greaves/vambraces enlarged (body poked through); Vampyr
  breastplate enlarged, tassets raised, two cape cones replaced by one `cape`, collar now plate; a `material` field on
  pieces (cloth/timber; default iron). Weapons left off (the axe's check A is still open).
- Licensing register: three rows added (palettes, kit, sprites), all CLEARED inputs; provenance.json in each folder.

## How to rerun
- Characters: Blender `-b --factory-startup --python-exit-code 1 -P tools/pipeline/render_character.py -- --body
  orc|vampyr --out D:/MERCS-vault/renders/look_2026-10-15/<body>_4x_<pass> --kit <kit> --kit-keep <pieces, no weapons>
  --pass color|normal|matid|parts`; then `python tools/look/build_sprites.py --renders D:/MERCS-vault/renders/look_2026-10-15`.
- Kit: Blender ... `-P tools/look/build_look_kit.py -- --out assets/look_target/kit`, then Godot `--import` (headless).
- Frame: `APPDATA=<scratch> godot_quiet.sh --render --path . --windowed --resolution 3840x2160 --position 8000,8000
  --script tools/look/look_target.gd -- --option=A --scene=day|night|map --out=<png>` (APPDATA on the command only).
- Then validate_palette.py, make_boards.py, write_provenance.py.

## Known limits (said in the report)
- Figures are stage-1 blockouts (primitive plate, bare feet, no weapons); the orc's stoop is his bodies.json posture.
- Options A and C map water still reads as flat grey slate (not re-rendered); banner poles lean with the perspective camera.
- Map tokens are unlit (no normal maps); street sprites are lit.
- A fresh realism critic (art-qa-critic section 0) has NOT been run: I cannot spawn agents. The Lead should.

## Findings for the lead (evidence attached; the Lead decides what is recorded)
- Caught a defect: a flat material-ID (matid) pass showed the orc's chest and thighs and the Vampyr's chest poking
  through blockout plate, invisible in the clay colour pass (`D:/MERCS-vault/renders/look_2026-10-15/iter/`); fixed.
- Caught a defect: per-face colour hashed on tile-local coordinates repeated the same light/dark triangles on every
  map tile (a carpet pattern); fixed with one colour per tile plus turned tiles.
- Caught a defect: whole-frame nearest-palette snapping turned torch-lit barrels heraldry crimson (06: heraldry only
  on faction cloth); fixed with a per-ramp distance penalty in the post shader.
- Tooling: a 3840x2160 window on this desktop comes out 3836x2158 even borderless; render into a 3840x2160
  SubViewport and save its texture (0 non-uniform 4x4 blocks measured).
- Tooling: Blender's glTF export makes default materials double-sided, so a face wound downward still draws, dark;
  wind every generated face upward.

## Rules learnt the hard way (keep under 10 lines)
- MPFB targets are shape keys: measure evaluated_get(depsgraph). The MPFB rig is offset (location z 0.75).
- Blender 4D Vector.normalized() scales by its xyz length only: normalize a Quaternion as a Quaternion.
- Moving or rotating the hips drags planted feet: re-solve the legs (IK) onto the clip's ankles.
- Gear in body clay reads as anatomy: review kit in the layers or matid pass, at 2x.
- Blender returns exit 0 on a Python traceback unless --python-exit-code 1 is passed.
- Typed GDScript here treats Variant-to-typed as an error: read JSON values into typed locals.
- Only Merge & CI edits STATUS.md and DECISIONS.md. Director: no mixels; send 1x and 2x as separate files.
