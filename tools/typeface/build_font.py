"""Build MERCS Ledger, the game's own pixel typeface, from its hand-drawn glyph source.

Director, 2026-10-15: "yeah better to make a unique one". The glyphs are drawn as text
bitmaps (tools/typeface/ledger/<style>.txt, one block per glyph, '#' = ink); this script
turns every ink cell into an exact square of the font grid, so at an integer multiple of
the grid (14, 28, 42, 56 px) the font renders with no blended pixels at all.
Adapted from the director's own builder for Aussie Rules Dynasties (ARD Signwriter).

    python tools/typeface/build_font.py --style Regular --out assets/fonts/MERCSLedger-Regular.ttf

Grid: 100 font units per pixel, 14 pixels to the em, so 1400 units per em; the line is
17 px (ascent 13, descent 4: about 1.9 x the cap height, room for accents). Cap height 9 px, x-height 6 px, ascenders 10 px, descenders 3 px.
Optional file beside the source: <style>.kern.txt, lines "T o -1" (whole pixels).
Prints what it built and what a reviewer should know: characters the game shows that the
font lacks, digits that are not all one width (numbers would jitter as they change).
It also runs the touch test (kern_check.py) on the cut's own kern file and fails on any contact.
Needs fontTools and skia-pathops (pip install fonttools skia-pathops).

Size rule for the PR that wires the face into the theme (not wired here): the font is only clean
at multiples of 14 px. Body text 28 px, headings (Display) 42 px at 1080p logical (56 / 84 px on
the 4K TV). Any other size blends: the theme's current default_font_size = 24 blends about 1650
pixels per line. That PR should add a smoke check that every font size it sets is % 14 == 0, and
turn subpixel positioning off (hinting none) so glyphs land on whole pixels.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import pathops
from fontTools.agl import UV2AGL
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0

ROOT = Path(__file__).resolve().parents[2]
UNIT = 100        # font units per grid pixel
BASELINE_ROW = 10  # the last row of ink that sits on the baseline
EM_PX = 14          # font size = EM_PX x scale: 14, 28, 42, 56 px
ASCENT_PX, DESCENT_PX = 13, 4  # line = 17 px, about 1.9 x cap height
CAP_PX, XH_PX = 9, 6
# Beyond what en.json shows today: what names, numbers and later text will want.
EXTRA = (
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    ".,:;!?'\"()[]{}-/\\|%+=<>*#&$@_~^"
    "‘’“”–—−·…×←→↑↓°"
    "éèêëáàâäíìîïóòôö"
    "úùûüñç"
)
DIGITS = "0123456789"
FIXED_DATE = 3874867200  # 2026-10-15 in the font epoch (seconds since 1904-01-01); never the build time


def parse_key(tok: str):
    """A code point (int) for a character or U+XXXX, else the mark's name (str)."""
    if tok.upper().startswith("U+") and len(tok) > 2:
        return int(tok[2:], 16)
    if len(tok) == 1:
        return ord(tok)
    return tok


def read_source(path: Path):
    """{key: (top_row, rows, adv, lsb)} and [(cp, base, mark)] from a glyph source file."""
    glyphs, composes = {}, []
    cur = None
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.rstrip()
        if line.startswith("@ "):
            parts = line[2:].split()
            key, top = parse_key(parts[0]), int(parts[1])
            opts = dict(p.split("=") for p in parts[2:])
            if key in glyphs:
                raise ValueError("%s:%d: %r drawn twice" % (path, n, parts[0]))
            cur = {"top": top, "rows": [], "adv": opts.get("adv"), "lsb": int(opts.get("lsb", 0))}
            glyphs[key] = cur
        elif line.startswith("= "):
            cp, base, mark = line[2:].split()
            composes.append((parse_key(cp), parse_key(base), parse_key(mark)))
            cur = None
        elif cur is not None and line and set(line) <= {"#", "."}:
            if cur["rows"] and len(line) != len(cur["rows"][0]):
                raise ValueError("%s:%d: row width %d, glyph is %d wide" % (path, n, len(line), len(cur["rows"][0])))
            cur["rows"].append(line)
        elif line and not line.startswith("#"):
            raise ValueError("%s:%d: cannot read %r" % (path, n, line))
    out = {}
    for key, g in glyphs.items():
        width = len(g["rows"][0]) if g["rows"] else 0
        adv = int(g["adv"]) if g["adv"] else g["lsb"] + width + 1
        if g["top"] + len(g["rows"]) > BASELINE_ROW + 4:
            raise ValueError("%r runs below the descent" % (key,))
        out[key] = (g["top"], g["rows"], adv, g["lsb"])
    return out, composes


def compose(glyphs, cp, base, mark):
    """A base glyph with a mark centred over (or under) it, as one bitmap."""
    btop, brows, badv, blsb = glyphs[base]
    mtop, mrows, _, _ = glyphs[mark]
    bw, mw = len(brows[0]), len(mrows[0])
    dx = (bw - mw + 1) // 2
    # A mark wider than its base (a diaeresis over the Display's dotless i) widens the glyph.
    left, right = min(0, dx), max(bw, dx + mw)
    top, bottom = min(btop, mtop), max(btop + len(brows), mtop + len(mrows))
    grid = [["."] * (right - left) for _ in range(bottom - top)]
    for src_top, rows, ox in ((btop, brows, -left), (mtop, mrows, dx - left)):
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch == "#":
                    grid[src_top - top + r][ox + c] = "#"
    return top, ["".join(r) for r in grid], badv + (right - left - bw), blsb


def outline(top, rows, lsb):
    """One clean TrueType outline: every ink cell an exact grid square, unioned."""
    path = pathops.Path()
    pen = path.getPen()
    for r, row in enumerate(rows):
        y0 = (BASELINE_ROW - (top + r)) * UNIT
        c = 0
        while c < len(row):
            if row[c] != "#":
                c += 1
                continue
            start = c
            while c < len(row) and row[c] == "#":
                c += 1
            x0, x1 = (lsb + start) * UNIT, (lsb + c) * UNIT
            pen.moveTo((x0, y0))
            pen.lineTo((x1, y0))
            pen.lineTo((x1, y0 + UNIT))
            pen.lineTo((x0, y0 + UNIT))
            pen.closePath()
    path = pathops.simplify(path, fix_winding=True, keep_starting_points=False)
    tt = TTGlyphPen(None)
    path.draw(Cu2QuPen(tt, max_err=1.0, reverse_direction=True))
    xs = [lsb + i for row in rows for i, ch in enumerate(row) if ch == "#"]
    return tt.glyph(), (min(xs) * UNIT if xs else 0)


def notdef():
    pen = TTGlyphPen(None)
    w, h, t = 5 * UNIT, CAP_PX * UNIT, UNIT
    for (x0, y0, x1, y1), rev in (((0, 0, w, h), False), ((t, t, w - t, h - t), True)):
        pts = [(x0, y0), (x0, y1), (x1, y1), (x1, y0)]
        if rev:
            pts.reverse()
        pen.moveTo(pts[0])
        for p in pts[1:]:
            pen.lineTo(p)
        pen.closePath()
    return pen.glyph()


def write_provenance(folder: Path) -> None:
    """assets/fonts/provenance.json, the manifest every assets/ folder carries."""
    def sha(p: Path) -> str:
        return hashlib.sha256(p.read_bytes()).hexdigest()
    me = Path(__file__).resolve()
    sources = sorted((me.parent / "ledger").glob("*.txt"))
    doc = {
        "_doc": "MERCS Ledger, the game's own pixel typeface (D-092). Drawn by hand as text bitmaps "
                "in tools/typeface/ledger/, built to exact grid squares by tools/typeface/build_font.py.",
        "asset": "fonts",
        "files": {p.name: sha(p) for p in sorted(folder.iterdir()) if p.name != "provenance.json"
                  and not p.name.endswith(".import")},
        "produced_by": {p.relative_to(ROOT).as_posix(): sha(p)[:16] for p in [me, me.parent / "kern_check.py"] + sources},
        "models": [],
        "licence_rows": ["Python, Pillow, NumPy", "fontTools, skia-pathops"],
        "seed": None,
        "status": "PROPOSED: director gate (look approval) pending",
        "created": "2026-10-15",
    }
    (folder / "provenance.json").write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8", newline="\n")


def glyph_name(cp: int) -> str:
    return UV2AGL.get(cp, "uni%04X" % cp)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--style", default="Regular")
    ap.add_argument("--src", default="", help="glyph source; default tools/typeface/ledger/<style>.txt")
    ap.add_argument("--out", required=True)
    ap.add_argument("--family", default="MERCS Ledger")
    ap.add_argument("--version", default="1.000")
    args = ap.parse_args()
    src = Path(args.src) if args.src else Path(__file__).parent / "ledger" / ("%s.txt" % args.style.lower())
    drawn, composes = read_source(src)
    for cp, base, mark in composes:
        drawn[cp] = compose(drawn, cp, base, mark)

    glyphs = {".notdef": notdef()}
    metrics = {".notdef": (6 * UNIT, 0)}
    cmap = {}
    for key, (top, rows, adv, lsb) in drawn.items():
        if not isinstance(key, int):
            continue  # marks only build composites
        name = glyph_name(key)
        if rows:
            g, xmin = outline(top, rows, lsb)
        else:
            g, xmin = TTGlyphPen(None).glyph(), 0
        glyphs[name] = g
        metrics[name] = (adv * UNIT, xmin)
        cmap[key] = name

    order = [".notdef"] + sorted(n for n in glyphs if n != ".notdef")
    upm = EM_PX * UNIT
    asc, desc = ASCENT_PX * UNIT, -DESCENT_PX * UNIT
    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=asc, descent=desc)
    family_ps = args.family.replace(" ", "")
    fb.setupNameTable({
        "familyName": args.family,
        "styleName": args.style,
        "uniqueFontIdentifier": "%s-%s %s" % (family_ps, args.style, args.version),
        "fullName": "%s %s" % (args.family, args.style),
        "psName": "%s-%s" % (family_ps, args.style),
        "version": "Version %s" % args.version,
        "copyright": "MERCS. Original design, drawn for the game. Owned by the project.",
    })
    fb.setupOS2(sTypoAscender=asc, sTypoDescender=desc, sTypoLineGap=0,
                usWinAscent=asc, usWinDescent=-desc, sxHeight=XH_PX * UNIT, sCapHeight=CAP_PX * UNIT,
                fsType=0, usWeightClass=700 if "bold" in args.style.lower() else 400)
    fb.setupPost()

    pairs = 0
    kern_file = src.with_name("%s.kern.txt" % src.stem)
    if kern_file.exists():
        lines, table = [], {}
        for raw in kern_file.read_text(encoding="utf-8").splitlines():
            if not raw.strip() or raw.startswith("#"):
                continue
            a, b, v = raw.split()
            na, nb = cmap.get(parse_key(a)), cmap.get(parse_key(b))
            if not (na and nb):
                raise ValueError("kern pair %r names a missing glyph" % raw)
            lines.append("  pos %s %s %d;" % (na, nb, int(v) * UNIT))
            table[(na, nb)] = int(v) * UNIT
        if lines:
            # GPOS for HarfBuzz (Godot); a legacy 'kern' table too, for FreeType-only renderers.
            addOpenTypeFeaturesFromString(fb.font, "feature kern {\n%s\n} kern;\n" % "\n".join(lines))
            kern = newTable("kern")
            kern.version = 0
            sub = KernTable_format_0()
            sub.version, sub.coverage, sub.format = 0, 1, 0
            sub.kernTable = table
            kern.kernTables = [sub]
            fb.font["kern"] = kern
            pairs = len(lines)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    # Same source, same bytes: a fixed date instead of the build time.
    fb.font["head"].created = fb.font["head"].modified = FIXED_DATE
    fb.font.recalcTimestamp = False
    fb.save(str(out))
    if out.resolve().parent == (ROOT / "assets" / "fonts").resolve():
        write_provenance(out.parent)

    shown = json.loads((ROOT / "data" / "text" / "en.json").read_text(encoding="utf-8"))
    needed = set("".join(v for k, v in shown.items() if not k.startswith("_"))) | set(EXTRA)
    missing = sorted(c for c in needed if c not in "\n" and ord(c) not in cmap)
    widths = sorted({metrics[cmap[ord(d)]][0] for d in DIGITS if ord(d) in cmap})
    print("built %s: %d glyphs, %d kern pairs, %d px em (cap %d, x-height %d), upm %d" % (
        out, len(cmap), pairs, EM_PX, CAP_PX, XH_PX, upm))
    if len(widths) > 1:
        print("  digits are not one width %s: numbers will shift as they change" % widths)
    if missing:
        print("  MISSING %d characters: %s" % (len(missing), "".join(missing)))
        return 1
    if not args.src:
        from kern_check import contacts
        bad = contacts(args.style)
        if bad:
            print("  %d CONTACTS (kern_check.py --style %s): %s" % (
                len(bad), args.style, " ".join("%s%s" % (a, b) for a, b, _, _ in bad[:20])))
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
