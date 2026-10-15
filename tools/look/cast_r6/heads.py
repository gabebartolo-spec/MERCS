"""Orc heads, round 6 (critic r5: a skull, not a box): hand-placed grids, one per source facing; the mirrors
reuse them.

A rounded crown (7, 11, 15 px across its first three rows), two brow arches that push the outline out 1 px,
2x3 pointed ears angled up, a 3x2 nose with two nostrils, eyes 4-5 px apart under a step-1 brow shadow, a
broad jaw wider than the skull with square corners, a straight mouth with the tusks rising from the lower jaw
past it, and a neck under the jaw (no full-width soot line onto the gorget). E: the back of the skull is a
curve (cut top-back corner, occiput bulge, nape stepping in), the ear sits at the side.

Each grid letter is a PLANE of the head, not a tone: its tone comes from the plane's normal and the key light
(draw.LIGHT, flipped for the mirrored facings, so W/SW/NW are lit from camera-left too), and its normal goes to
the normal strip. Step 2 is the face mass; step 4 only as a 1-px key edge (q) and the lit brow arch (a).
Codes: ' ' not head; 'K' soot 0; 'e' eye (soot 0); 'u' skin step 1 (brow shadow, sockets, nostrils, under the
lip, neck; lead ruling 2026-10-16: never on a pixel that touches the silhouette, orc_paint.guard_dark);
'y'/'x' tusk, left/right column (bone 3 lit, bone 2 shaded).
Planes (tone unmirrored / mirrored): q key edge top-left 4/2, o top-right 2/4, t crown top 3/3, l left side 3/2,
r right side 2/3, h left-front 3/2, p right-front 2/3, f front 2/2, a brow arch left 4/3, c brow arch right 3/4,
n nose 3/3, w lower front 2/2, g underside 2/2.
"""

PLANES = {
    'q': (-0.5, -0.6, 0.62), 't': (0.0, -0.8, 0.6), 'o': (0.5, -0.6, 0.62),
    'l': (-0.8, 0.0, 0.6), 'h': (-0.3, 0.0, 0.95), 'f': (0.0, 0.0, 1.0), 'p': (0.3, 0.0, 0.95),
    'r': (0.8, 0.0, 0.6), 'w': (0.0, 0.4, 0.92), 'g': (0.0, 0.8, 0.6),
    'a': (-0.1, -0.5, 0.8), 'c': (0.1, -0.5, 0.8), 'n': (0.0, -0.3, 0.95),
    'u': (0.0, 0.3, 0.95), 'e': (0.0, 0.3, 0.95), 'K': (0.0, 0.0, 1.0),
    'y': (-0.5, 0.0, 0.87), 'x': (0.5, 0.0, 0.87),
}
SKIN = (['E', 'D', 'C'], [0.87, 0.75])      # plane tone: step 4 at d >= 0.87, step 3 at d >= 0.75, else step 2
TUSK = (['y', 'x'], [0.6])                  # bone 3 lit, bone 2 shaded
FIXED = {'K': 'K', 'e': 'K', 'u': 'B'}

# facing -> (x0, y0, rows)
HEADS = {
    0: (74, 36, [                       # S: crown 7/11/15, brow out 1, ears 2 px out, jaw 21 px, neck
        "           KKKKKKK           ",
        "         KKqqqtttoKK         ",
        "       KKqqtttttttooKK       ",
        "   K  KqqhhhhhffffffpoK  K   ",
        "  KlKKhhhaaaafffccccpprKKrK  ",
        "  KlfKhhhhhhhhfppppppprKfrK  ",
        "  KlfKfhhuuuufnfuuuupprKfrK  ",
        "   KfKfhhueeufnfueeupprKfK   ",
        "    KhhffffffnnnffffffprK    ",
        "    KhhffffffunuffffffprK    ",
        "    KfffffyxfffffyxfffprK    ",
        "    KfffffyxKKKKKyxfffprK    ",
        "   KhhffffyxfffffyxffffprK   ",
        "   KhwwwwwwwwwwwwwwwwwwwrK   ",
        "   KfwwwwwwwwwwwwwwwwwwwrK   ",
        "   KKKKKuuuuuuuuuuuuuKKKKK   ",
        "       KuuuuuuuuuuuuuK       ",
    ]),
    1: (78, 35, [                       # SE: three-quarter, face to the right, near ear at the left
        "         KKKKKKK           ",
        "       KKqqqtttoKK         ",
        "     KKqqtttttttooKK       ",
        "    KqhhhhffffffffooK      ",
        "  K KlhhhaaaaaffcccccK     ",
        " KlKKlhhhhhhhhffpppppK     ",
        " KlfKfhhhfuuuufnuuuuK      ",
        " KlfKfhhhfueeufnueepK      ",
        "  KfKfhhhffffffnnnppK      ",
        "   KhhhhhffffffunuppK      ",
        "   KhfffffyxfffffyxppK     ",
        "   KffffffyxKKKKKyxppK     ",
        "  KhhfffffyxfffffyxpprK    ",
        "  KhwwwwwwwwwwwwwwwwwrK    ",
        "  KfwwwwwwwwwwwwwwwwwrK    ",
        "  KKKKuuuuuuuuuuuKKKKKK    ",
        "     KuuuuuuuuuuuK         ",
    ]),
    2: (78, 33, [                       # E: profile; back of the skull a curve, ear at the side, jaw 3 px ahead
        "         KKKKKKK           ",
        "       KKqqqttttKK         ",
        "     KKqqtttttttooK        ",
        "    KqlhhhhffffffooK       ",
        "   KqlhhhhfffffffooK       ",
        "   KlhhhhfffffccccccK      ",
        "   KlhhhhKfffffuuuupK      ",
        "  KlhhhhKhKfffffuepK       ",
        "  KlhhhhKhuufffffunnK      ",
        "  KlhhhhKhuuffffffnnnK     ",
        "  KlhhhhfKufffffffnunK     ",
        "  KlffffffKfffffffyxK      ",
        "  KlfffffffffffKKKyxppK    ",
        "   KlfffffffffffffyxpppK   ",
        "    KfwwwwwwwwwwwwwwwwwK   ",
        "    KfwwwwwwwwwwwwwwwwwK   ",
        "     KuuuuuuuKKKKKKKKKKK   ",
        "     KuuuuuuuK             ",
    ]),
    3: (80, 28, [                       # NE: back three-quarter; ears, jaw corner, tusk tip
        "         KKKKKKK          ",
        "       KKqqttttoKK        ",
        "     KKqqtttttttooK       ",
        "    KqlhhhfffffffooK      ",
        "   KqlhhhfffffffffooK     ",
        " K KlhhhhfffffffffprK K   ",
        "KlKKlhhhhfffffffffprKKrK  ",
        "KlfKlhhhhfffffffffprKfrK  ",
        "KlfKlhhhhfffffffffprKfrK  ",
        " KfKlhhhhfffffffffprKfK   ",
        "  KKlhhhffffffffffpppK    ",
        "   KlhhhfffffffffpprrrK   ",
        "   KlhhhfffffffffppppxrK  ",
        "   KlhhhfffffffffppppxrK  ",
        "   KlffffffffffffgggggK   ",
        "   KKlfffffffwwwwwKKKK    ",
        "    KKuuuuuuuuuuuKK       ",
        "     KuuuuuuuuuuuK        ",
    ]),
    4: (74, 26, [                       # N: the back of the head, ears both sides, jaw corners wider, neck
        "           KKKKKKK           ",
        "         KKqqttttoKK         ",
        "       KKqqtttttttooKK       ",
        "      KqlhhhffffffppooK      ",
        "     KqlhhhffffffffpppoK     ",
        "   K KlhhhhffffffffppprK K   ",
        "  KlKKlhhhhffffffffppprKKrK  ",
        "  KlfKlhhhhffffffffppprKfrK  ",
        "  KlfKlhhhhffffffffppprKfrK  ",
        "   KfKlhhhhffffffffppprKfK   ",
        "    KKlhhhhffffffffppprKK    ",
        "    KlhhhhffffffffffppprK    ",
        "    KlhhhhffffffffffppprK    ",
        "    KlffffwwwwwwwwwwppprK    ",
        "    KlwwwwwwwwwwwwwwwwwrK    ",
        "    KKKKKuuuuuuuuuuuKKKKK    ",
        "        KuuuuuuuuuuuK        ",
        "        KuuuuuuuuuuuK        ",
    ]),
}

if __name__ == '__main__':
    for f, (x0, y0, rows) in HEADS.items():
        ws = {len(r) for r in rows}
        print(f, x0, y0, 'widths', ws)
