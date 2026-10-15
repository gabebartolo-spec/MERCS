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
          "Orc and Vampyr stage-1 blockouts rendered by the sprite pipeline (CC0 MPFB bodies, Blender primitives "
          "for kit), reduced to core + heartland.",
          ["tools/pipeline/render_character.py", "tools/pipeline/pixelate.py", "tools/pipeline/pack_sheets.py",
           "tools/look/build_sprites.py"], [blender, mpfb, py], "prototype sprites for the golden references")
    write(REPO / "assets" / "look_target" / "kit",
          "Street and map kits modelled by script in Blender (primitives only), faces named pal:<ramp>:<step>.",
          ["tools/look/build_look_kit.py"], [blender, py], "prototype kit for the golden references")
    write(REPO / "assets" / "golden",
          "Golden references (06 section 8), 1x logical (960 x 540): look_target.gd captures of the real "
          "StreetStage at 3840 x 2160 (exact 4x4 blocks), one pixel kept per block. Changes only by a director "
          "decision in DECISIONS.md.",
          ["tools/look/look_target.gd", "tools/look/look_map.gd", "tools/look/palette_post.gdshader",
           "tools/look/build_look_kit.py",
           "tools/look/build_sprites.py"], [blender, mpfb, py, "Godot Engine"], approved)


if __name__ == "__main__":
    main()
