"""Write the provenance manifests for the look-target files (docs/10_LICENSING_REGISTER.md).

  python tools/look/write_provenance.py

One provenance.json per folder: assets/palette/, assets/palette/biomes/, assets/look_target/kit/,
assets/look_target/heartland/sprites/ and assets/golden/, each listing its files with SHA-256, the scripts that made them, the
licence rows (all CLEARED: Blender, MPFB, Python) and no models: no generative model touched any of them.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DATE = "2026-10-15"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(folder: Path, doc: str, produced_by: list[str], rows: list[str], status: str) -> None:
    files = {p.name: sha(p) for p in sorted(folder.iterdir())
             if p.is_file() and p.suffix in (".json", ".png", ".gpl", ".glb") and p.name != "provenance.json"}
    data = {
        "_doc": doc,
        "asset": folder.relative_to(REPO / "assets").as_posix(),
        "files": files,
        "produced_by": {s: sha(REPO / s)[:16] for s in produced_by},
        "models": [],
        "licence_rows": rows,
        "seed": None,
        "status": status,
        "created": DATE,
    }
    (folder / "provenance.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("PROVENANCE", folder.relative_to(REPO).as_posix(), len(files), "files")


def main() -> None:
    py, blender, mpfb = "Python, Pillow, NumPy", "Blender", "MPFB (MakeHuman Plugin for Blender)"
    approved = "APPROVED: look target B 'Peat and Ochre', director 2026-10-15"
    write(REPO / "assets" / "palette", "Core palette (06 section 2): ramps every biome shares.",
          ["tools/look/make_palettes.py"], [py], approved)
    write(REPO / "assets" / "palette" / "biomes", "Biome palettes; heartland is look option B with its light.",
          ["tools/look/make_palettes.py"], [py], approved)
    write(REPO / "assets" / "look_target" / "heartland" / "sprites",
          "Orc and Vampyr stage-1 blockouts rendered by the sprite pipeline (CC0 MPFB bodies; plate as shells "
          "conformed to the body plus Blender primitives, kit_extras.py), reduced to core + heartland with the "
          "outline on the silhouette only, speckle merged and the tokens hand-edited (token_edits.json). "
          "Cast fix after the slop audit of 2026-10-15. Round 3 (2026-10-16): bodies, tokens and normal strips "
          "hand-repainted part by part in palette ramps (tools/look/cast_r3/); heads kept from the render. Round 4 "
          "(2026-10-16, tools/look/cast_r4/): the orc repainted inside the round-2 alpha (bulk back), skin on the "
          "green-grey skin_orc ramp, tusks in bone 3 (director: 'bulk and green-grey skin'); the Vampyr in his own "
          "armour (slim spaulders, no fauld box) with a fanned cape; tokens are the SE frames at half scale. Round 5 "
          "(2026-10-16, tools/look/cast_r5/): the orc's heads hand-placed as planes (broad jaw, brow shelf, mouth, "
          "tusks from the lower jaw), skin on the moss-hue skin_orc ramp, plate one iron step darker; the Vampyr's "
          "armour darker with a cuirass ridge and the cape lining showing at the front; the orc token head by hand.",
          ["tools/pipeline/render_character.py", "tools/pipeline/kit_extras.py", "tools/pipeline/pixelate.py",
           "tools/pipeline/pack_sheets.py", "tools/pipeline/kits/orc_s1_blockout.json",
           "tools/pipeline/kits/vampyr_s1_blockout.json", "tools/look/build_sprites.py",
           "tools/look/token_edits.json"], [blender, mpfb, py],
          "prototype sprites for the golden references; cast fix awaiting the director's look approval")
    write(REPO / "assets" / "look_target" / "kit",
          "Street and map kits modelled by script in Blender (primitives only), faces named pal:<ramp>:<step>.",
          ["tools/look/build_look_kit.py"], [blender, py], "prototype kit for the golden references")
    write(REPO / "assets" / "golden",
          "Golden references (06 section 8), 1x logical (960 x 540): look_target.gd captures of the real "
          "StreetStage at 3840 x 2160 (exact 4x4 blocks), one pixel kept per block. Changes only by a director "
          "decision in DECISIONS.md. 2026-10-16 (director: grey-olive orc skin): grass pixels in the old skin_orc "
          "colours moved to their nearest verdure step, the orc figures' skin to the new ramp by index "
          "(tools/look/cast_r3/remap_golden.py). Round 4 (2026-10-16): the orc figures' skin follows the "
          "green-grey ramp by index; overworld lit grass flattened from a verdure_1/2 checker to verdure_2 "
          "(lead call, stop-gap until the B7 tile re-render; director to approve) (tools/look/cast_r4/remap_golden.py). "
          "Round 5 (2026-10-16): overworld rebuilt from the approved golden with its lit grass on verdure_mid_0 and "
          "no dark rims; orc figures' skin on the round-5 ramp by index; director to approve "
          "(tools/look/cast_r5/remap_golden.py).",
          ["tools/look/look_target.gd", "tools/look/look_map.gd", "tools/look/palette_post.gdshader",
           "tools/look/build_look_kit.py",
           "tools/look/build_sprites.py", "tools/look/cast_r3/remap_golden.py",
           "tools/look/cast_r4/remap_golden.py", "tools/look/cast_r5/remap_golden.py"],
          [blender, mpfb, py, "Godot Engine"],
          approved)


if __name__ == "__main__":
    main()
