"""Refresh the pixel and palette hashes in the sheet manifests after a hand repaint (run from the repo root)."""
import json
import sys
from pathlib import Path
REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / 'tools' / 'pipeline'))
from pngio import read_png
from palette_lib import load_palette
SHEETS = ['assets/look_target/heartland/sprites/orc_look_heartland.json',
          'assets/look_target/heartland/sprites/vampyr_look_heartland.json',
          'assets/sprites/mercs/average_m/average_m_body_rest.json']
for rel in SHEETS:
    p = REPO / rel; d = json.loads(p.read_text(encoding='utf-8'))
    png = p.with_suffix('.png'); nrm = p.with_name(p.stem + '_normal.png')
    d['image_pixel_sha256'] = read_png(png).pixel_sha256()
    if 'normal_image_pixel_sha256' in d: d['normal_image_pixel_sha256'] = read_png(nrm).pixel_sha256()
    d['palette']['sha256'] = load_palette(REPO / d['palette']['file']).sha256
    raw = p.read_bytes(); nl = '\r\n' if b'\r\n' in raw else '\n'
    p.write_text(json.dumps(d, indent=2) + '\n', encoding='utf-8', newline=nl)
    print(rel, d['image_pixel_sha256'][:12])
