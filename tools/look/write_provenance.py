"""Write the provenance manifests for the look-target files (docs/10_LICENSING_REGISTER.md).

  python tools/look/write_provenance.py

One provenance.json per folder: assets/palette/options/<X>/, assets/look_target/kit/ and
assets/look_target/<X>/sprites/, each listing its files with SHA-256, the scripts that made them, the
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


def write(folder: Path, doc: str, produced_by: list[str], rows: list[str]) -> None:
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
        "status": "DRAFT look-target option, not approved by the director",
        "created": DATE,
    }
    (folder / "provenance.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("PROVENANCE", folder.relative_to(REPO).as_posix(), len(files), "files")


def main() -> None:
    for key in "ABC":
        write(REPO / "assets" / "palette" / "options" / key,
              f"Look-target palette option {key}: hand-set ramp anchors, steps spaced in OKLab by script.",
              ["tools/look/make_palettes.py", "tools/look/build_sprites.py"], ["Python, Pillow, NumPy"])
        write(REPO / "assets" / "look_target" / key / "sprites",
              f"Look-target option {key} sprites: the orc and Vampyr stage-1 blockouts rendered by the sprite "
              "pipeline (CC0 MPFB bodies, Blender primitives for kit), reduced to the option's palette.",
              ["tools/pipeline/render_character.py", "tools/pipeline/pixelate.py", "tools/pipeline/pack_sheets.py",
               "tools/look/build_sprites.py"],
              ["Blender", "MPFB (MakeHuman Plugin for Blender)", "Python, Pillow, NumPy"])
    write(REPO / "assets" / "look_target" / "kit",
          "Look-target environment kits: street and map tiles modelled by script in Blender (primitives only), "
          "faces named pal:<ramp>:<step> and coloured from a palette in Godot.",
          ["tools/look/build_look_kit.py"], ["Blender", "Python, Pillow, NumPy"])


if __name__ == "__main__":
    main()
