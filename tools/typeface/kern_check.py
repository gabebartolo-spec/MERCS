"""Spacing checks for MERCS Ledger, run on the glyph source itself (whole pixels, no renderer).

    python tools/typeface/kern_check.py --style Display            # touch test + baseline list
    python tools/typeface/kern_check.py --style Display --air "Fa Fo Pa LO AV"

Touch test: every pair of drawn characters is set at its advance plus its kern, and any ink of
the left glyph within one pixel (8 neighbours: edge or corner) of ink of the right glyph is a
contact. Zero contacts are allowed; build_font.py runs this and fails the build on any.
Air: the mean horizontal gap, in pixels, between the two glyphs over the x-height band
(rows 5-10) where both have ink. Reference values: nn and HH (the straight pairs).
Each cut is checked with its own kern file, so the Display's table is tested on Display widths.
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_font as bf  # noqa: E402

XBAND = range(5, bf.BASELINE_ROW + 1)


def load(style: str):
    src = Path(__file__).parent / "ledger" / ("%s.txt" % style.lower())
    drawn, composes = bf.read_source(src)
    for cp, base, mark in composes:
        drawn[cp] = bf.compose(drawn, cp, base, mark)
    glyphs = {k: v for k, v in drawn.items() if isinstance(k, int)}
    kern = {}
    kf = src.with_name("%s.kern.txt" % src.stem)
    if kf.exists():
        for raw in kf.read_text(encoding="utf-8").splitlines():
            if raw.strip() and not raw.startswith("#"):
                a, b, v = raw.split()
                kern[(bf.parse_key(a), bf.parse_key(b))] = int(v)
    return glyphs, kern


def ink(g, x0=0):
    """{row: (min x, max x, set of x)} of a glyph placed with its origin at x0."""
    top, rows, adv, lsb = g
    out = {}
    for r, row in enumerate(rows):
        xs = {x0 + lsb + i for i, ch in enumerate(row) if ch == "#"}
        if xs:
            out[top + r] = xs
    return out


def contact(ga, gb, k):
    """'edge', 'corner' or None for glyph a followed by glyph b with kern k (pixels)."""
    a, b = ink(ga), ink(gb, ga[2] + k)
    found = None
    for r, xs in a.items():
        for dr in (-1, 0, 1):
            ys = b.get(r + dr)
            if not ys:
                continue
            for x in xs:
                for dx in (-1, 0, 1):
                    if x + dx in ys:
                        if dr == 0 or dx == 0:
                            return "edge"  # side by side, stacked, or overlapping
                        found = "corner"
    return found


def air(ga, gb, k, band=XBAND):
    a, b = ink(ga), ink(gb, ga[2] + k)
    gaps = [min(b[r]) - max(a[r]) - 1 for r in band if r in a and r in b]
    return sum(gaps) / len(gaps) if gaps else None


def contacts(style: str):
    """[(a, b, kern, kind)] for every pair of drawn characters that touches."""
    glyphs, kern = load(style)
    keys = [c for c in sorted(glyphs) if c > 32 and c != 0xA0 and glyphs[c][1]]
    bad = []
    for a in keys:
        for b in keys:
            k = kern.get((a, b), 0)
            kind = contact(glyphs[a], glyphs[b], k)
            if kind:
                bad.append((chr(a), chr(b), k, kind))
    return bad


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--style", default="Regular")
    ap.add_argument("--air", default="", help="space-separated pairs: air at kern 0, -1, -2 and contact")
    a = ap.parse_args()
    glyphs, kern = load(a.style)
    if a.air:
        for pair in a.air.split():
            ga, gb = glyphs[ord(pair[0])], glyphs[ord(pair[1])]
            cur = kern.get((ord(pair[0]), ord(pair[1])), 0)
            cells = []
            for k in (0, -1, -2):
                v = air(ga, gb, k)
                cells.append("k%+d air %s %s" % (k, "-" if v is None else "%.1f" % v, contact(ga, gb, k) or "clear"))
            print("%s  now %+d | %s" % (pair, cur, " | ".join(cells)))
        return 0
    bad = contacts(a.style)
    print("%s: %d glyphs, %d kern pairs, %d contacts" % (a.style, len(glyphs), len(kern), len(bad)))
    for row in bad:
        print("  %s%s kern %+d: %s" % row)
    floating = [chr(c) for c, (top, rows, _, _) in sorted(glyphs.items())
                if rows and top <= 2 and top + len(rows) - 1 == bf.BASELINE_ROW - 1]
    print("cap-height glyphs that stop one row above the baseline: %s" % (" ".join(floating) or "none"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
